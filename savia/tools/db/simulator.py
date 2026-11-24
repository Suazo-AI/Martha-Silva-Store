#!/usr/bin/env python3
"""CP4 simulator: one cloud and three branches, each node its own database on the local dev SQL Server.

Nodes never read each other's database. Rows move only as JSON batches through the V032 procedures
(sync.usp_PlanJson, usp_ReadBatch, usp_ApplyBatch), the same code the P9 .NET transport runs:
the sender reads Change Tracking in one SNAPSHOT transaction, the receiver applies with MERGE
and advances its (fork, version) cursor after every table is applied (ADR-001 D5, F1, F5, F8).
Topology: hub. A branch sends only the rows it owns. The cloud relays every row except the target's own.
Every synced row has one owner (ownership map, ADR-001 critique), so a receiver never merges two writers.

Oracles after convergence:
  R1    every synced table has the same rows on all four databases (SHA-256 per table; diff on failure)
  CONS  audit.usp_CheckConservation returns zero violations on every node
  plus the scenario's own checks.

Usage (from the repository root):
  python savia/tools/db/simulator.py scenario basic|cancel_vs_dispatch|restore|restore_naive|replay|credit_status
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

EMIT = """
SELECT N'@@SIMB@@'+SUBSTRING(@out,(n-1)*3000+1,3000)+N'@@SIME@@'
FROM (SELECT TOP (CONVERT(int,CEILING(DATALENGTH(ISNULL(@out,N''))/6000.0))) ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS n
      FROM sys.all_columns a CROSS JOIN sys.all_columns b) x ORDER BY n;"""


class SqlError(Exception):
    def __init__(self, node, out):
        m = re.search(r"Msg (\d+)", out)
        self.number = int(m.group(1)) if m else 0
        super().__init__(f"{node}: {out.strip()[-1200:]}")


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
        self.stats = Counter()
        self.failures = []
        self.page_rows = None  # None keeps the V060 default page (5,000 rows per table)

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
        self.converge()  # every node starts from the same rows, so a branch can see another branch's credit

    def load_meta(self):
        """Synced tables in apply order, read from sync.SyncTables: the same list the sync procedures use."""
        rows = self.fetch("cloud", """
SET @out=(SELECT PARSENAME(st.TableName,2)+N'.'+PARSENAME(st.TableName,1) AS t,
  (SELECT d.name AS n,d.system_type_name AS ty FROM sys.dm_exec_describe_first_result_set(N'SELECT * FROM '+st.TableName,NULL,0) d
    WHERE d.system_type_name NOT IN ('timestamp','rowversion') AND d.is_computed_column=0 ORDER BY d.column_ordinal FOR JSON PATH) AS c,
  (SELECT c.name AS n FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
     JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
    WHERE i.object_id=OBJECT_ID(st.TableName) AND i.is_primary_key=1 ORDER BY ic.key_ordinal FOR JSON PATH) AS k
 FROM sync.SyncTables st ORDER BY st.ApplyOrder FOR JSON PATH);""")
        self.tables = [r["t"] for r in rows]
        self.meta = {r["t"]: ([(c["n"], c["ty"]) for c in r["c"]], [k["n"] for k in r["k"]]) for r in rows}

    # ---------- sync ----------
    # Every rule runs in the V032 procedures, the same code the .NET transport calls (P9-SPEC.md).
    def pull(self, tgt, src, mode="normal"):
        """tgt pulls from src. mode normal | all (restored branch rebuilds from the cloud, its own rows included).
        D-041: a pull is a run of pages; each page re-plans, so the receiver's pass state, not this loop, says where to resume."""
        changed = 0
        while True:
            changed += self.apply_batch(tgt, self.read_batch(tgt, src, mode))
            if not self.last_more:
                return changed

    def state(self, node):
        return self.fetch(node, "EXEC sync.usp_SourceStateJson @Json=@out OUTPUT;")

    def read_batch(self, tgt, src, mode="normal"):
        """Plan on the receiver, then read on the sender in one SNAPSHOT transaction. Returns the batch to apply."""
        state = self.state(src)
        sql_mode = "rebuild" if mode == "all" else "normal"
        plan = self.fetch(tgt, f"EXEC sync.usp_PlanJson @PeerNodeId='{self.node_id(src)}',@StateJson={lit(json.dumps(state))},"
                               f"@Mode='{sql_mode}',@Json=@out OUTPUT;")
        fork = f"'{self.state(tgt)['fork']}'" if sql_mode == "rebuild" else "NULL"
        page = f"@PageRows={self.page_rows}," if self.page_rows else ""
        payload = self.fetch(src, f"EXEC sync.usp_ReadBatch @TargetNodeId='{self.node_id(tgt)}',@PlanJson={lit(json.dumps(plan))},"
                                  f"@TargetForkGuid={fork},{page}@Json=@out OUTPUT;")
        return {"src": src, "mode": mode, "plan": {p["t"]: p for p in plan["tables"]}, "payload": payload}

    @staticmethod
    def rows_in(batch):
        return sum(len(t["rows"] or []) for t in batch["payload"]["tables"])

    def apply_batch(self, tgt, batch, fail_before_commit=False):
        """Receiver: usp_ApplyBatch applies every table, then advances every cursor, in one transaction (F8)."""
        src, mode, plan = batch["src"], batch["mode"], batch["plan"]
        res = self.fetch(tgt, f"""
BEGIN TRANSACTION;
EXEC sync.usp_ApplyBatch @PeerNodeId='{self.node_id(src)}',@BatchJson={lit(json.dumps(batch["payload"], ensure_ascii=False))},
     @Json=@out OUTPUT;
{"THROW 51899,'Fallo inyectado antes del COMMIT.',1;" if fail_before_commit else ""}
COMMIT;""")
        changed, sent = res["changed"], self.rows_in(batch)
        self.last_more = bool(res.get("more"))
        if self.last_more and not res.get("applied"):
            raise AssertionError(f"sync {src}->{tgt}: page not applied, the pull would loop")
        actions = Counter(p["a"] for p in plan.values())
        self.stats["rows_sent"] += sent
        self.stats["rows_changed"] += changed
        self.stats["pulls"] += 1  # one applied page
        if sent or any(a != "incremental" for a in actions):
            self.say(f"  sync {src}->{tgt} [{mode}] sent={sent} changed={changed} skipped={res['skipped']} plan={dict(actions)}")
        return changed

    def sync_round(self):
        changed = 0
        for b in BRANCHES:
            if self.online[b]:
                changed += self.pull("cloud", b)
        for b in BRANCHES:
            if self.online[b]:
                changed += self.pull(b, "cloud")
        return changed

    def converge(self, max_rounds=6):
        for r in range(max_rounds):
            if self.sync_round() == 0:
                return r + 1
        raise AssertionError(f"no convergence after {max_rounds} rounds")

    # ---------- operations (each runs on one node, like a real cashier or manager) ----------
    def op(self, node, label, text):
        try:
            self.sql(node, text)
            self.stats[f"ok_{label}"] += 1
            return True
        except SqlError as e:
            if 50000 <= e.number <= 59999:
                self.stats[f"rejected_{label}_{e.number}"] += 1
                self.say(f"  {label} at {node}: rejected {e.number} {str(e).strip().splitlines()[-1][:160]}")
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

    def close_till(self, b):
        """A supervisor closes branch b's till with a count of the opening float (the variance is not under test)."""
        K, count = b.upper(), self.guid()
        return self.op(b, "close", f"""
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES('{count}','{self.till[b]}',{self.i('cashier' + K)},'draft',{self.i('cashier' + K)});
INSERT INTO sales.CashCountLines(Id,CashCountId,DenominationMinor,Quantity) VALUES('{self.guid()}','{count}',100000,1);
EXEC sales.usp_SubmitCashCount @CashCountId='{count}',@ActorId={self.i('cashier' + K)};
EXEC sales.usp_CloseTill @ClosureId='{self.guid()}',@TillId='{self.till[b]}',@CashCountId='{count}',
     @ActorId={self.i('supervisor' + K)},@OriginNodeId='{self.node_id(b)}';""")

    def credit_status(self, node, credit):
        """The status every node derives for a credit (D-038: only the issuer writes credits.Credits.Status)."""
        return self.fetch(node, f"SET @out=(SELECT Status AS st FROM credits.vw_CreditStatus WHERE CreditId='{credit}' "
                                f"FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);")["st"]

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
            for t in self.tables)
        return {r["t"]: (r["n"], r.get("h")) for r in self.fetch(node, f"SET @out=(SELECT * FROM ({q}) x FOR JSON PATH);")}

    def rows(self, node, t):
        cols, pk = self.meta[t]
        data = self.fetch(node, f"SET @out=(SELECT {','.join(f'[{c}]' for c, _ in cols)} FROM {t} FOR JSON PATH, INCLUDE_NULL_VALUES);")
        return {tuple(r[c] for c in pk): r for r in (data or [])}

    def check_r1(self):
        hashes = {n: self.table_hashes(n) for n in NODES}
        bad = []
        for t in self.tables:
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
            self.say(f"PASS R1: {len(self.tables)} tables, {total} rows, identical SHA-256 on cloud, a, b, c")

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
    s.expect("C closes its till", s.close_till("c"))
    s.converge()  # the closure travels with the closed till, so no node sees a closed till without its closure (S8)


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
    s.expect("restored A reports recovering", s.state("a")["recovering"] is True, str(s.state("a")))
    s.expect("restored A may not sell before recovery (SQL refuses 51864)",
             not s.sale("a") and s.stats["rejected_sale_51864"] == 1, str(dict(s.stats)))
    s.pull("a", "cloud", mode="all")   # 1. rebuild every row from the cloud (the cloud's copy wins)
    s.expect("the rebuild lifts the lock", s.state("a")["recovering"] is False)
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


def scenario_credit_status(s):
    s.say("scenario credit_status (D-038): only the issuer writes a credit's status; every node derives the same status")
    whole, blocked = s.credits
    for credit in (whole, blocked):  # all of A's money moves to B, so B is the branch that spends it
        tid = s.request("b", credit, "a", "b", 120000)
        s.converge()
        s.approve(tid)
        s.converge()
        s.dispatch("a", tid)
        s.converge()
        s.receive("b", tid)
        s.converge()
    s.expect("B, not the issuer, spends the whole credit", s.sale("b", whole, PRICE))
    s.converge()
    for n in NODES:
        s.expect(f"{n}: the spent credit is exhausted", s.credit_status(n, whole) == "exhausted")
    # Concurrent: A, the issuer, blocks the other credit while B, offline, spends it.
    s.online["b"] = False
    s.expect("A blocks the credit", s.op("a", "block", f"EXEC credits.usp_BlockCredit @CreditId='{blocked}',@ActorId={s.i('supervisorA')};"))
    s.converge()
    s.expect("B, offline, still spends the credit it holds", s.sale("b", blocked, PRICE))
    s.online["b"] = True
    s.converge()
    for n in NODES:
        s.expect(f"{n}: the issuer's block wins", s.credit_status(n, blocked) == "blocked")


def scenario_restore_naive(s):
    s.say("scenario restore_naive (RED CONTROL): A is restored and syncs at once, without rebuilding from the cloud")
    _restore_setup(s)
    s.converge()


def _try_apply(s, tgt, batch, **kw):
    """Apply a captured batch again. Returns (changed, None) or (None, SQL error number)."""
    try:
        return s.apply_batch(tgt, batch, **kw), None
    except SqlError as e:
        return None, e.number


def _same(s, a, b, tables=("sales.Sales", "sales.CashTills", "inventory.StockBalances", "credits.CreditAllocations")):
    ha, hb = s.table_hashes(a), s.table_hashes(b)
    return [t for t in tables if ha[t] != hb[t]]


def scenario_replay(s):
    s.say("scenario replay (A-04): duplicate, late, crashed, unacknowledged and pre-restore batches from A to the cloud")
    s.sale("a")
    p1 = s.read_batch("cloud", "a")
    s.expect("first batch applies", (s.apply_batch("cloud", p1) or 0) > 0)
    changed, err = _try_apply(s, "cloud", p1)
    s.expect("duplicate batch: no error and 0 changes", err is None and changed == 0, f"changed={changed} error={err}")
    s.sale("a")
    s.apply_batch("cloud", s.read_batch("cloud", "a"))
    changed, err = _try_apply(s, "cloud", p1)
    s.expect("late batch (older than the cursor): no error and 0 changes", err is None and changed == 0,
             f"changed={changed} error={err}")
    diff = _same(s, "cloud", "a")
    s.expect("late batch did not move rows back", not diff, f"tables differ: {diff}")
    before = s.table_hashes("cloud")["sales.Sales"]
    s.sale("a")
    p3 = s.read_batch("cloud", "a")
    changed, err = _try_apply(s, "cloud", p3, fail_before_commit=True)
    s.expect("crash before COMMIT: nothing applied", err == 51899 and s.table_hashes("cloud")["sales.Sales"] == before,
             f"error={err}")
    changed, err = _try_apply(s, "cloud", p3)
    s.expect("retry after the crash applies", err is None and changed > 0, f"changed={changed} error={err}")
    s.sale("a")
    s.apply_batch("cloud", s.read_batch("cloud", "a"))  # committed, but A never hears back
    again = s.read_batch("cloud", "a")
    resent = s.rows_in(again)
    s.expect("lost acknowledgement: the next plan sends nothing old", resent == 0, f"rows={resent}")
    s.converge()
    code, out = db.run_sql("master", f"BACKUP DATABASE [{DBN['a']}] TO DISK=N'{BAK}' WITH INIT, FORMAT;")
    if code != 0:
        raise SystemExit(out)
    s.sale("a")
    p5 = s.read_batch("cloud", "a")  # in flight when A is restored; delivered after A recovered
    code, out = db.run_sql("master", f"ALTER DATABASE [{DBN['a']}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; "
                                     f"RESTORE DATABASE [{DBN['a']}] FROM DISK=N'{BAK}' WITH REPLACE, RECOVERY; "
                                     f"ALTER DATABASE [{DBN['a']}] SET MULTI_USER;")
    if code != 0:
        raise SystemExit(out)
    s.say("  A restored; it rebuilds from the cloud, then the old in-flight batch arrives")
    s.pull("a", "cloud", mode="all")
    s.converge()
    changed, err = _try_apply(s, "cloud", p5)
    s.expect("pre-restore batch after recovery is refused (51853 retired fork)", err == 51853, f"changed={changed} error={err}")
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
    sc.add_argument("name", choices=["basic", "cancel_vs_dispatch", "restore", "restore_naive", "replay", "credit_status"])
    sc.add_argument("--seed", type=int, default=1)
    sc.add_argument("--page-rows", type=int, help="rows per table per page (D-041); small values exercise paging")
    rd = sub.add_parser("random")
    rd.add_argument("--seed", type=int, default=7)
    rd.add_argument("--steps", type=int, default=120)
    args = ap.parse_args()
    started = time.time()
    s = Sim(args.seed, out=lambda m: print(m, flush=True))
    s.page_rows = getattr(args, "page_rows", None)
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
