#!/usr/bin/env python3
"""CP4 simulator: one cloud and three branches, each node its own database on the local dev SQL Server.

Nodes never read each other's database. Rows move only as JSON payloads:
the sender reads Change Tracking in one SNAPSHOT transaction, the receiver applies with MERGE
and advances its (fork, version) cursor after every table is applied (ADR-001 D5, F1, F5, F8).
Topology: hub. A branch sends only the rows it owns. The cloud relays every row except the target's own.
Every synced row has one owner (ownership map, ADR-001 critique), so a receiver never merges two writers.

Oracles after convergence:
  R1    every synced table has the same rows on all four databases (SHA-256 per table; diff on failure)
  CONS  audit.usp_CheckConservation returns zero violations on every node
  plus the scenario's own checks.

Usage (from the repository root):
  python savia/tools/db/simulator.py scenario basic|cancel_vs_dispatch|restore|restore_naive
  python savia/tools/db/simulator.py random --seed 7 --steps 120
Exit 0 = every oracle passed. Databases SAVIA_SIM_cloud/_a/_b/_c are recreated on each run.
"""
import argparse
import json
import random
import re
import sys
import time
import uuid
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import saviadb as db  # noqa: E402

NODES = ["cloud", "a", "b", "c"]
BRANCHES = ["a", "b", "c"]
DBN = {n: f"SAVIA_SIM_{n}" for n in NODES}
BAK = f"{db.DATA_DIR}/SAVIA_SIM_a_old.bak"
PRICE = 120000  # catalog price of the fixture 'item' (NIO minor units)

# Synced tables in apply order (parents first) and the SQL that names the owning branch of row t.
# None = the row's own NodeId names its owner node (V009 transition rows; the cloud owns approvals and cancels).
_TILL_BRANCH = "(SELECT r.BranchId FROM sales.CashRegisters r WHERE r.Id={})"
_SALE_BRANCH = "(SELECT s.BranchId FROM sales.Sales s WHERE s.Id=t.SaleId)"
_LOC_BRANCH = "(SELECT l.BranchId FROM core.Locations l WHERE l.Id=t.LocationId)"
TABLES = [
    ("sales.CashTills", _TILL_BRANCH.format("t.RegisterId")),
    ("sales.Sales", "t.BranchId"),
    ("sales.SaleLines", _SALE_BRANCH),
    ("sales.SaleReversals", "t.BranchId"),
    ("sales.SaleReversalLines", "(SELECT r.BranchId FROM sales.SaleReversals r WHERE r.Id=t.ReversalId)"),
    ("credits.Credits", "t.IssuingBranchId"),
    ("credits.CreditAllocations", "t.BranchId"),
    ("credits.CreditMovements", "t.BranchId"),
    ("credits.CreditRedemptions", "t.BranchId"),
    ("sales.SaleTenders", _SALE_BRANCH),
    ("sales.CashEntries", _TILL_BRANCH.format("(SELECT k.RegisterId FROM sales.CashTills k WHERE k.Id=t.TillId)")),
    ("inventory.StockBalances", _LOC_BRANCH),
    ("inventory.StockMovements", _LOC_BRANCH),
    ("credits.TransferRequests", None),
    ("credits.TransferApprovals", None),
    ("credits.TransferCancellations", None),
    ("credits.TransferDispatches", None),
    ("credits.TransferReceipts", None),
]

EMIT = """
SELECT N'@@SIMB@@'+SUBSTRING(@out,(n-1)*3000+1,3000)+N'@@SIME@@'
FROM (SELECT TOP (CONVERT(int,CEILING(DATALENGTH(ISNULL(@out,N''))/6000.0))) ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS n
      FROM sys.all_columns a CROSS JOIN sys.all_columns b) x ORDER BY n;"""


class SqlError(Exception):
    def __init__(self, node, out):
        m = re.search(r"Msg (\d+)", out)
        self.number = int(m.group(1)) if m else 0
        super().__init__(f"{node}: {out.strip()[-1200:]}")


def owner_node(expr):
    if expr is None:
        return "t.NodeId"
    return f"(SELECT n.Id FROM sync.Nodes n WHERE n.Kind='branch' AND n.BranchId={expr})"


def lit(s):
    return "N'" + s.replace("'", "''") + "'"


def bt(name):
    schema, table = name.split(".")
    return f"[{schema}].[{table}]"


class Sim:
    def __init__(self, seed, out=print):
        self.rng = random.Random(seed)
        self.seed = seed
        self.say = out
        self.online = {b: True for b in BRANCHES}
        self.blocked = set()       # restored branches that may not operate until recovered
        self.stats = Counter()
        self.failures = []

    # ---------- plumbing ----------
    def sql(self, node, text):
        code, out = db.run_sql(DBN[node], "SET NOCOUNT ON; SET XACT_ABORT ON;\n" + text, opts="-x -y 0")
        self.stats["sql_calls"] += 1
        if code != 0:
            raise SqlError(node, out)
        return out

    def fetch(self, node, text):
        """text must assign nvarchar(max) @out (declared here)."""
        out = self.sql(node, "DECLARE @out nvarchar(max);\n" + text + EMIT)
        chunks = re.findall(r"@@SIMB@@(.*?)@@SIME@@", out)
        return json.loads("".join(chunks)) if chunks else None

    def guid(self):
        return str(uuid.UUID(int=self.rng.getrandbits(128), version=4)).upper()  # SQL Server returns upper case

    def i(self, name):
        return f"'{self.ids[name]}'"

    def node_id(self, n):
        return self.ids["nodeCloud" if n == "cloud" else "node" + n.upper()]

    # ---------- setup ----------
    def setup(self):
        template = db.ensure_template()
        for n in NODES:
            code, out = db.clone(DBN[n], template)
            if code != 0:
                raise SystemExit(f"clone {n}: {out}")
        rows = self.fetch("cloud", "SET @out=(SELECT Name AS n,Id AS i FROM test.Ids FOR JSON PATH);")
        self.ids = {r["n"]: r["i"] for r in rows}
        for n in NODES:
            self.sql(n, f"EXEC sync.usp_SetLocalNode @NodeId='{self.node_id(n)}';")
        self.load_meta()
        self.till = {}
        for b in BRANCHES:
            self.till[b] = self.guid()
            K = b.upper()
            self.sql(b, f"""
EXEC test.SeedStock @ItemId={self.i('item')},@LocationId={self.i('loc' + K)},@Quantity=500;
EXEC sales.usp_OpenTill @TillId='{self.till[b]}',@RegisterId={self.i('register' + K)},@CashierId={self.i('cashier' + K)},
     @CurrencyCode='NIO',@OpeningMinor=100000,@OriginNodeId='{self.node_id(b)}';""")
        self.credits = [self.guid(), self.guid()]
        for c in self.credits:
            self.sql("a", f"EXEC test.SeedCredit @CreditId='{c}';")
        self.say(f"setup: 4 databases, tills open, 500 units per branch, credits {self.credits} (120000 each at A)")

    def load_meta(self):
        values = ",".join(f"(N'{t}')" for t, _ in TABLES)
        rows = self.fetch("cloud", f"""
SET @out=(SELECT v.tn AS t,
  (SELECT d.name AS n,d.system_type_name AS ty FROM sys.dm_exec_describe_first_result_set(N'SELECT * FROM '+v.tn,NULL,0) d
    WHERE d.system_type_name NOT IN ('timestamp','rowversion') ORDER BY d.column_ordinal FOR JSON PATH) AS c,
  (SELECT c.name AS n FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
     JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
    WHERE i.object_id=OBJECT_ID(v.tn) AND i.is_primary_key=1 ORDER BY ic.key_ordinal FOR JSON PATH) AS k
 FROM (VALUES {values}) v(tn) FOR JSON PATH);""")
        self.meta = {r["t"]: ([(c["n"], c["ty"]) for c in r["c"]], [k["n"] for k in r["k"]]) for r in rows}

    # ---------- sync ----------
    def pull(self, tgt, src, mode="normal"):
        """tgt pulls from src. mode normal | all (restored branch rebuilds from the cloud, no owner filter)."""
        state = self.fetch(src, """
DECLARE @s TABLE(NodeId uniqueidentifier,ForkGuid uniqueidentifier,CurrentVersion bigint,TableName sysname,MinValidVersion bigint);
INSERT @s EXEC sync.usp_GetSourceState;
SET @out=(SELECT * FROM @s FOR JSON PATH, INCLUDE_NULL_VALUES);""")
        st = {r["TableName"]: r for r in state}
        fork = state[0]["ForkGuid"]
        src_node = self.node_id(src)
        def mv(t):
            v = st[bt(t)]["MinValidVersion"]
            return "NULL" if v is None else str(v)
        calls = "\n".join(
            f"INSERT @r EXEC sync.usp_ClassifyCursor @PeerNodeId='{src_node}',@TableName=N'{bt(t)}',"
            f"@SourceForkGuid='{fork}',@SourceCurrentVersion={st[bt(t)]['CurrentVersion']},@SourceMinValidVersion={mv(t)};\n"
            f"INSERT @c(t,a,f) SELECT N'{bt(t)}',a,f FROM @r; DELETE @r;"
            for t, _ in TABLES)
        plan = self.fetch(tgt, f"""
DECLARE @r TABLE(a varchar(20),f bigint); DECLARE @c TABLE(t sysname,a varchar(20),f bigint);
{calls}
SET @out=(SELECT t,a,f FROM @c FOR JSON PATH, INCLUDE_NULL_VALUES);""")
        plan = {p["t"]: p for p in plan}
        if mode == "all":
            for p in plan.values():
                p["a"], p["f"] = "rebuild", None

        # Sender: one SNAPSHOT transaction for every table (F5).
        parts, keys = [], []
        for k, (t, owner) in enumerate(TABLES):
            cols, pk = self.meta[t]
            sel = ",".join(f"t.[{c}]" for c, _ in cols)
            if mode == "all":
                flt = "1=1"
            elif src == "cloud":
                flt = f"{owner_node(owner)}<>@target"
            else:
                flt = f"{owner_node(owner)}=@me"
            p = plan[bt(t)]
            if p["a"] == "incremental":
                on = " AND ".join(f"ct.[{c}]=t.[{c}]" for c in pk)
                parts.append(f"""
IF CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID(N'{t}'))>{p['f']} THROW 51891,'Cambios ya depurados durante la sincronizacion.',1;
IF EXISTS(SELECT 1 FROM CHANGETABLE(CHANGES {t},{p['f']}) ct WHERE ct.SYS_CHANGE_OPERATION='D')
  THROW 51892,'Borrado fisico en una tabla sincronizada ({t}).',1;
SET @j{k}=(SELECT {sel} FROM CHANGETABLE(CHANGES {t},{p['f']}) ct JOIN {t} t ON {on}
           WHERE ct.SYS_CHANGE_VERSION<=@to AND {flt} FOR JSON PATH, INCLUDE_NULL_VALUES);""")
            else:
                parts.append(f"SET @j{k}=(SELECT {sel} FROM {t} t WHERE {flt} FOR JSON PATH, INCLUDE_NULL_VALUES);")
            keys.append(f"JSON_QUERY(ISNULL(@j{k},N'[]')) AS [t{k}]")
        decl = ",".join(f"@j{k} nvarchar(max)" for k in range(len(TABLES)))
        payload = self.fetch(src, f"""
SET TRANSACTION ISOLATION LEVEL SNAPSHOT; BEGIN TRANSACTION;
DECLARE @me uniqueidentifier=(SELECT NodeId FROM sync.LocalNode),@target uniqueidentifier='{self.node_id(tgt)}',
  @fork uniqueidentifier=(SELECT recovery_fork_guid FROM sys.database_recovery_status WHERE database_id=DB_ID()),
  @to bigint=CHANGE_TRACKING_CURRENT_VERSION(),{decl};
IF @fork<>'{fork}' THROW 51890,'El fork del emisor cambio durante la sincronizacion.',1;
{''.join(parts)}
SET @out=(SELECT @fork AS fork,@to AS [to],{','.join(keys)} FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
COMMIT;""")

        # Receiver: apply every table, then advance every cursor, in one transaction (F8).
        stmts, sent = [], 0
        for k, (t, _) in enumerate(TABLES):
            rows = payload[f"t{k}"]
            if not rows:
                continue
            sent += len(rows)
            cols, pk = self.meta[t]
            names = [c for c, _ in cols]
            with_ = ",".join(f"[{c}] {ty}" for c, ty in cols)
            on = " AND ".join(f"t.[{c}]=s.[{c}]" for c in pk)
            nonpk = [c for c in names if c not in pk]
            upd = ""
            if nonpk:
                upd = (f"WHEN MATCHED AND EXISTS(SELECT {','.join(f's.[{c}]' for c in nonpk)} "
                       f"EXCEPT SELECT {','.join(f't.[{c}]' for c in nonpk)}) THEN UPDATE SET "
                       + ",".join(f"t.[{c}]=s.[{c}]" for c in nonpk))
            stmts.append(f"""
SET @j={lit(json.dumps(rows, ensure_ascii=False))};
MERGE {t} WITH (HOLDLOCK) AS t USING (SELECT * FROM OPENJSON(@j) WITH ({with_})) AS s ON {on}
{upd}
WHEN NOT MATCHED BY TARGET THEN INSERT ({','.join(f'[{c}]' for c in names)}) VALUES ({','.join(f's.[{c}]' for c in names)});
SET @changed+=@@ROWCOUNT;""")
        adv = "\n".join(
            f"EXEC sync.usp_AdvancePeerCursor @PeerNodeId='{src_node}',@TableName=N'{bt(t)}',"
            f"@ForkGuid='{payload['fork']}',@Version={payload['to']};" for t, _ in TABLES)
        res = self.fetch(tgt, f"""
DECLARE @j nvarchar(max),@changed int=0;
BEGIN TRANSACTION;
{''.join(stmts)}
{adv}
COMMIT;
SET @out=CONCAT(N'[',@changed,N']');""")
        changed = res[0]
        actions = Counter(p["a"] for p in plan.values())
        self.stats["rows_sent"] += sent
        self.stats["rows_changed"] += changed
        self.stats["pulls"] += 1
        if sent or any(a != "incremental" for a in actions):
            self.say(f"  sync {src}->{tgt} [{mode}] sent={sent} changed={changed} plan={dict(actions)}")
        return changed

    def sync_round(self):
        changed = 0
        for b in BRANCHES:
            if self.online[b] and b not in self.blocked:
                changed += self.pull("cloud", b)
        for b in BRANCHES:
            if self.online[b] and b not in self.blocked:
                changed += self.pull(b, "cloud")
        return changed

    def converge(self, max_rounds=6):
        for r in range(max_rounds):
            if self.sync_round() == 0:
                return r + 1
        raise AssertionError(f"no convergence after {max_rounds} rounds")

    # ---------- operations (each runs on one node, like a real cashier or manager) ----------
    def op(self, node, label, text):
        if node in self.blocked:
            self.stats["blocked_op"] += 1
            self.say(f"  {label} at {node}: BLOCKED (restored, not recovered)")
            return False
        try:
            self.sql(node, text)
            self.stats[f"ok_{label}"] += 1
            return True
        except SqlError as e:
            if 50000 <= e.number <= 59999:
                self.stats[f"rejected_{label}_{e.number}"] += 1
                return False
            raise

    def sale(self, b, credit=None, credit_amount=0):
        K, sale = b.upper(), self.guid()
        cash = PRICE - credit_amount
        tenders = []
        if cash:
            tenders.append(f"({len(tenders) + 1},'cash',{cash},NULL,{cash},0)")
        if credit_amount:
            tenders.append(f"({len(tenders) + 1},'credit',{credit_amount},'{credit}',NULL,NULL)")
        return self.op(b, "redeem" if credit_amount else "sale", f"""
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,{self.i('item')},1,{PRICE},0);
INSERT @tenders(TenderNumber,TenderKind,AmountMinor,CreditId,ReceivedMinor,ChangeMinor) VALUES {','.join(tenders)};
EXEC sales.usp_PostSale @SaleId='{sale}',@BranchId={self.i('branch' + K)},@LocationId={self.i('loc' + K)},
     @CashierId={self.i('cashier' + K)},@CurrencyCode='NIO',@CustomerId={self.i('customer')},@TillId='{self.till[b]}',
     @OriginNodeId='{self.node_id(b)}',@Lines=@lines,@Tenders=@tenders;""")

    def request(self, at, credit, frm, to, amount, tid=None):
        tid = tid or self.guid()
        ok = self.op(at, "request", f"""
EXEC credits.usp_TransferRequest @TransferId='{tid}',@CreditId='{credit}',@FromBranchId={self.i('branch' + frm.upper())},
     @ToBranchId={self.i('branch' + to.upper())},@AmountMinor={amount},@RequestedBy={self.i('cashier' + at.upper())},
     @Reason=N'Clienta pide el saldo en otra sucursal',@NodeId='{self.node_id(at)}';""")
        return tid if ok else None

    def approve(self, tid):
        return self.op("cloud", "approve", f"EXEC credits.usp_TransferApprove @TransferId='{tid}',"
                                           f"@ApproverId={self.i('manager')},@NodeId='{self.node_id('cloud')}';")

    def cancel(self, tid):
        return self.op("cloud", "cancel", f"EXEC credits.usp_TransferCancel @TransferId='{tid}',@ActorId={self.i('manager')},"
                                          f"@Reason=N'Cancelada en la nube',@NodeId='{self.node_id('cloud')}';")

    def dispatch(self, b, tid):
        return self.op(b, "dispatch", f"EXEC credits.usp_TransferDispatch @TransferId='{tid}',"
                                      f"@ActorId={self.i('cashier' + b.upper())},@NodeId='{self.node_id(b)}';")

    def receive(self, b, tid):
        return self.op(b, "receive", f"EXEC credits.usp_TransferReceive @TransferId='{tid}',"
                                     f"@ActorId={self.i('cashier' + b.upper())},@NodeId='{self.node_id(b)}';")

    def view(self, node):
        return self.fetch(node, """
SET @out=(SELECT (SELECT v.TransferId AS id,v.CreditId AS credit,b1.Code AS frm,b2.Code AS [to],v.AmountMinor AS amount,v.[Status] AS st,
                         CONVERT(int,v.CancelOverridden) AS ov
                  FROM credits.vw_TransferStatus v JOIN core.Branches b1 ON b1.Id=v.FromBranchId JOIN core.Branches b2 ON b2.Id=v.ToBranchId
                  FOR JSON PATH, INCLUDE_NULL_VALUES) AS transfers,
                 (SELECT a.CreditId AS credit,b.Code AS branch,a.AvailableMinor AS av FROM credits.CreditAllocations a
                    JOIN core.Branches b ON b.Id=a.BranchId WHERE a.Status='active' FOR JSON PATH) AS alloc
          FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);""") or {}

    # ---------- oracles ----------
    def table_hashes(self, node):
        q = " UNION ALL ".join(
            f"SELECT N'{t}' AS t,(SELECT COUNT_BIG(*) FROM {t}) AS n,"
            f"CONVERT(char(64),HASHBYTES('SHA2_256',(SELECT {','.join(f'[{c}]' for c, _ in self.meta[t][0])} FROM {t} "
            f"ORDER BY {','.join(f'[{c}]' for c in self.meta[t][1])} FOR JSON PATH, INCLUDE_NULL_VALUES)),2) AS h"
            for t, _ in TABLES)
        return {r["t"]: (r["n"], r.get("h")) for r in self.fetch(node, f"SET @out=(SELECT * FROM ({q}) x FOR JSON PATH);")}

    def rows(self, node, t):
        cols, pk = self.meta[t]
        data = self.fetch(node, f"SET @out=(SELECT {','.join(f'[{c}]' for c, _ in cols)} FROM {t} FOR JSON PATH, INCLUDE_NULL_VALUES);")
        return {tuple(r[c] for c in pk): r for r in (data or [])}

    def check_r1(self):
        hashes = {n: self.table_hashes(n) for n in NODES}
        bad = []
        for t, _ in TABLES:
            seen = {n: hashes[n][t] for n in NODES}
            if len(set(seen.values())) > 1:
                ref = self.rows("cloud", t)
                for n in BRANCHES:
                    if seen[n] == seen["cloud"]:
                        continue
                    other = self.rows(n, t)
                    for key in sorted(set(ref) | set(other), key=str):
                        a, b = ref.get(key), other.get(key)
                        if a != b:
                            diff = "missing" if a is None or b is None else ",".join(
                                f"{c}: cloud={a[c]} {n}={b[c]}" for c in a if a[c] != b[c])
                            bad.append(f"{t} key={key} node={n}: {diff}")
        total = sum(v[0] for v in hashes["cloud"].values())
        if bad:
            self.fail("R1 replicas identical", bad[:8] + ([f"... {len(bad)} differences"] if len(bad) > 8 else []))
        else:
            self.say(f"PASS R1: {len(TABLES)} tables, {total} rows, identical SHA-256 on cloud, a, b, c")

    def check_conservation(self):
        for n in NODES:
            v = self.fetch(n, """
DECLARE @v TABLE(CheckName varchar(60),KeyText nvarchar(200),Expected bigint,Actual bigint);
INSERT @v EXEC audit.usp_CheckConservation @Throw=0;
SET @out=(SELECT * FROM @v FOR JSON PATH, INCLUDE_NULL_VALUES);""")
            if v:
                self.fail(f"CONS conservation on {n}", [f"{r['CheckName']} {r['KeyText']} expected={r['Expected']} actual={r['Actual']}"
                                                        for r in v[:6]] + [f"({len(v)} violations)"])
            else:
                self.say(f"PASS CONS on {n}: 0 violations")

    def expect(self, what, cond, detail=""):
        if cond:
            self.say(f"PASS {what}")
        else:
            self.fail(what, [detail])

    def fail(self, what, lines):
        self.failures.append(what)
        self.say(f"FAIL {what}")
        for line in lines:
            self.say(f"     {line}")

    def finish(self):
        self.check_r1()
        self.check_conservation()
        ops = {k: v for k, v in sorted(self.stats.items()) if not k.startswith(("rows", "sql", "pulls"))}
        self.say(f"stats: pulls={self.stats['pulls']} rows_sent={self.stats['rows_sent']} "
                 f"rows_changed={self.stats['rows_changed']} sql_calls={self.stats['sql_calls']} ops={ops}")
        self.say("RESULT " + ("PASS" if not self.failures else f"FAIL ({len(self.failures)}): " + "; ".join(self.failures)))
        return 0 if not self.failures else 1


# ---------- scenarios ----------
def scenario_basic(s):
    s.say("scenario basic: one sale per branch, one credit transfer A->B, everything online")
    for b in BRANCHES:
        s.sale(b)
    s.converge()
    tid = s.request("b", s.credits[0], "a", "b", 50000)
    s.converge()
    s.approve(tid)
    s.converge()
    s.dispatch("a", tid)
    s.converge()
    s.receive("b", tid)
    rounds = s.converge()
    s.say(f"converged in {rounds} rounds")
    v = {t["id"]: t for t in s.view("c")["transfers"]}
    s.expect("branch C sees the transfer received", v[tid]["st"] == "received", str(v.get(tid)))
    alloc = {(x["credit"], x["branch"]): x["av"] for x in s.view("c")["alloc"]}
    s.expect("C sees A=70000 and B=50000", alloc.get((s.credits[0], "T_A")) == 70000 and alloc.get((s.credits[0], "T_B")) == 50000,
             str(alloc))


def scenario_cancel_vs_dispatch(s):
    s.say("scenario cancel_vs_dispatch: the cloud cancels while A, offline, dispatches (Jason: dispatch wins)")
    tid = s.request("b", s.credits[0], "a", "b", 50000)
    s.converge()
    s.approve(tid)
    s.converge()  # A sees the approval
    s.online["a"] = False
    s.cancel(tid)
    s.converge()  # B and C see the cancel; A does not
    dispatched = s.dispatch("a", tid)
    s.expect("A, offline, can dispatch the approved transfer", dispatched)
    s.online["a"] = True
    s.converge()
    t = {x["id"]: x for x in s.view("cloud")["transfers"]}[tid]
    s.expect("cloud: in transit with the cancel overridden", t["st"] == "in_transit" and t["ov"] == 1, str(t))
    s.expect("B receives after the late dispatch", s.receive("b", tid))
    s.converge()
    for n in NODES:
        t = {x["id"]: x for x in s.view(n)["transfers"]}[tid]
        s.expect(f"{n}: received, cancel overridden", t["st"] == "received" and t["ov"] == 1, str(t))
    # Control: once A has seen the cancel, A cannot dispatch.
    t2 = s.request("a", s.credits[1], "a", "c", 20000)
    s.converge()
    s.approve(t2)
    s.cancel(t2)
    s.converge()
    s.expect("A, online after the cancel, cannot dispatch (51726)", not s.dispatch("a", t2)
             and s.stats["rejected_dispatch_51726"] == 1, str(dict(s.stats)))


def _restore_setup(s):
    tid = s.request("b", s.credits[0], "a", "b", 50000)
    s.converge()
    s.approve(tid)
    s.converge()
    for b in BRANCHES:
        s.sale(b)
    s.converge()
    code, out = db.run_sql("master", f"BACKUP DATABASE [{DBN['a']}] TO DISK=N'{BAK}' WITH INIT, FORMAT;")
    if code != 0:
        raise SystemExit(out)
    s.say("  backup of A taken (A still holds 120000 of credit 1)")
    s.dispatch("a", tid)  # A: 120000 -> 70000 after the backup
    s.sale("a")
    s.converge()
    s.receive("b", tid)
    s.converge()
    s.sale("a")  # this sale never leaves A: it is lost with the restore
    lost_sale_count = int(s.fetch("a", "SET @out=CONCAT(N'[',(SELECT COUNT(*) FROM sales.Sales WHERE BranchId="
                                       + s.i("branchA") + "),N']');")[0])
    code, out = db.run_sql("master", f"ALTER DATABASE [{DBN['a']}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; "
                                     f"RESTORE DATABASE [{DBN['a']}] FROM DISK=N'{BAK}' WITH REPLACE, RECOVERY; "
                                     f"ALTER DATABASE [{DBN['a']}] SET MULTI_USER;")
    if code != 0:
        raise SystemExit(out)
    s.say("  A restored from the old backup (A holds 120000 again locally)")
    return tid, lost_sale_count


def scenario_restore(s):
    s.say("scenario restore: A is restored from an old backup; it rebuilds from the cloud before it sends")
    tid, before = _restore_setup(s)
    s.blocked.add("a")
    s.expect("restored A may not sell before recovery", not s.sale("a"))
    s.pull("a", "cloud", mode="all")   # 1. rebuild every row from the cloud (the cloud's copy wins)
    s.blocked.discard("a")
    s.converge()                       # 2. the cloud's cursor for A says 'recover' (fork changed)
    alloc = {(x["credit"], x["branch"]): x["av"] for x in s.view("a")["alloc"]}
    s.expect("A shows 70000 after recovery, not the 120000 of the backup",
             alloc.get((s.credits[0], "T_A")) == 70000, str(alloc))
    s.expect("A cannot redeem the old 120000 (only 70000 remains)", not s.sale("a", s.credits[0], 120000))
    after = int(s.fetch("cloud", "SET @out=CONCAT(N'[',(SELECT COUNT(*) FROM sales.Sales WHERE BranchId="
                                 + s.i("branchA") + "),N']');")[0])
    s.say(f"  A sales before restore (local) = {before}; everywhere after recovery = {after}; "
          f"lost = {before - after} (written at A after its last sync)")
    s.expect("exactly the one unsynced sale is lost", before - after == 1, f"before={before} after={after}")


def scenario_restore_naive(s):
    s.say("scenario restore_naive (RED CONTROL): A is restored and syncs at once, without rebuilding from the cloud")
    _restore_setup(s)
    s.converge()


def scenario_random(s, steps):
    s.say(f"scenario random: seed={s.seed} steps={steps}")
    rng = s.rng
    for step in range(steps):
        r = rng.random()
        if r < 0.10:
            b = rng.choice(BRANCHES)
            s.online[b] = not s.online[b]
            s.say(f"[{step}] link {b} {'up' if s.online[b] else 'DOWN'}")
        elif r < 0.25:
            s.sync_round()
        elif r < 0.40:
            s.sale(rng.choice(BRANCHES))
        else:
            node = rng.choice(NODES)
            v = s.view(node)
            transfers, alloc = v.get("transfers") or [], v.get("alloc") or []
            code = {"T_A": "a", "T_B": "b", "T_C": "c"}
            if node == "cloud":
                cands = [t for t in transfers if t["st"] in ("requested", "approved")]
                if cands:
                    t = rng.choice(cands)
                    (s.approve if t["st"] == "requested" and rng.random() < 0.8 else s.cancel)(t["id"])
                continue
            mine = node.upper()
            acts = []
            for t in transfers:
                if t["st"] == "approved" and t["frm"] == "T_" + mine:
                    acts.append(("dispatch", t))
                if t["st"] == "in_transit" and t["to"] == "T_" + mine:
                    acts.append(("receive", t))
            have = [a for a in alloc if a["av"] > 0]
            if have and rng.random() < 0.5:
                a = rng.choice(have)
                if a["branch"] == "T_" + mine and rng.random() < 0.5:
                    s.sale(node, a["credit"], min(a["av"], rng.choice([10000, 30000, PRICE])))
                else:
                    others = [b for b in BRANCHES if "T_" + b.upper() != a["branch"]]
                    frm = code[a["branch"]]
                    to = node if node != frm else rng.choice(others)
                    s.request(node, a["credit"], frm, to, min(a["av"], rng.choice([5000, 20000, 50000])))
            elif acts:
                kind, t = rng.choice(acts)
                (s.dispatch if kind == "dispatch" else s.receive)(node, t["id"])
    for b in BRANCHES:
        s.online[b] = True
    s.say(f"all links up; converged in {s.converge()} rounds")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sc = sub.add_parser("scenario")
    sc.add_argument("name", choices=["basic", "cancel_vs_dispatch", "restore", "restore_naive"])
    sc.add_argument("--seed", type=int, default=1)
    rd = sub.add_parser("random")
    rd.add_argument("--seed", type=int, default=7)
    rd.add_argument("--steps", type=int, default=120)
    args = ap.parse_args()
    started = time.time()
    s = Sim(args.seed, out=lambda m: print(m, flush=True))
    s.setup()
    try:
        if args.cmd == "random":
            scenario_random(s, args.steps)
        else:
            globals()[f"scenario_{args.name}"](s)
    except (SqlError, AssertionError) as e:
        s.fail("run aborted", [str(e)])
    code = s.finish()
    print(f"elapsed {time.time() - started:.0f}s", flush=True)
    return code


if __name__ == "__main__":
    sys.exit(main())
