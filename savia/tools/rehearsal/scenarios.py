"""Rehearsal scenarios. Each one drives the stores through the HTTP API the web uses, cuts links or kills
processes at fixed points, waits for the hosted SyncWorker loops to converge, then checks the manifest.

Transfers of credit have no HTTP route (no endpoint or web code calls usp_Transfer*); the driver runs those
procedures on the acting node's database and marks every such step 'sql:no-http-route'.
"""
import contextlib
import json
import re
import threading
import time
from pathlib import Path

import checks
import harness as h

EXPECTED = Path(__file__).resolve().parent / "expected"


class Run:
    def __init__(self, scenario, manifest_path, identity, run_dir, say=print):
        self.scenario, self.say = scenario, say
        self.manifest_path = Path(manifest_path)
        self.m, self.sha = checks.load(self.manifest_path)
        errors = checks.validate(self.m)
        if errors:
            raise SystemExit("manifest invalid:\n  " + "\n  ".join(errors))
        self.c = h.Cluster(run_dir, identity, say)
        self.outcomes, self.phases, self.events, self.controls = {}, [], [], []
        self.sales = {s["key"]: s for s in self.m["sales"]}
        self.returns = {r["key"]: r for r in self.m.get("returns", [])}
        self.transfers = {t["key"]: t for t in self.m.get("transfers", [])}
        self.till, self.t0 = {}, time.time()
        self.verdict, self.reason = None, ""

    # ---------- bookkeeping
    @contextlib.contextmanager
    def phase(self, name):
        t = time.time()
        self.say(f"  [{time.time() - self.t0:6.1f}s] {name}")
        try:
            yield
        finally:
            self.phases.append({"phase": name, "seconds": round(time.time() - t, 1)})

    def event(self, text, **data):
        self.events.append({"t": round(time.time() - self.t0, 1), "event": text, **data})
        self.say(f"  [{time.time() - self.t0:6.1f}s]   {text}" + (f" {data}" if data else ""))

    def control(self, name, ok, expected, actual):
        self.controls.append({"control": name, "ok": bool(ok), "expected": expected, "actual": actual})
        self.say(f"  {'PASS' if ok else 'FAIL'} control {name}: expected {expected}; actual {actual}")

    # ---------- setup
    def bring_up(self, skip_tills=()):
        with self.phase("setup: 4 databases, node credentials, staff passwords, seed stock"):
            self.c.setup()
        with self.phase("start hub and 3 store hosts"):
            self.c.start_all()
        with self.phase("open tills over HTTP"):
            for s in h.STORES:
                if s not in skip_tills:
                    self.open_till(s, self.tills(s)[0])
        with self.phase("first convergence"):
            ok, secs, diff = self.c.converge()
            if not ok:
                raise SystemExit(f"first convergence failed after {secs}s: {diff}")
            if not self.c.wait_rounds(h.STORES, 1, 30):
                raise SystemExit("a store logged no successful sync round")

    def tills(self, store):
        t = (self.m.get("tills") or {})[store]
        return t if isinstance(t, list) else [t]

    # ---------- operations over HTTP
    def open_till(self, store, till_id):
        status, body = h.call(self.c.hosts[store].base, "POST", "/api/v1/cash/tills",
                              {"tillId": till_id, "registerId": self.c.ids["register" + store.upper()],
                               "currencyCode": "NIO", "openingMinor": 100000,
                               "lines": [{"denominationMinor": 50000, "quantity": 2}]}, self.c.token(store))
        ok = status in (200, 201, 204)
        self.event(f"open till {store}", status=status, problem=_code(body))
        if ok:
            self.till[store] = till_id
        return ok

    def sale(self, key):
        s = self.sales[key]
        store = s["store"]
        tenders = []
        for i, t in enumerate(s["tenders"], 1):
            d = {"tenderNumber": i, "tenderKind": t["kind"], "amountMinor": t["amount"]}
            if t["kind"] == "cash":
                d.update(receivedMinor=t["amount"], changeMinor=0)
            if t["kind"] == "credit":
                d["creditId"] = self.returns[t["credit"]]["creditId"]
            tenders.append(d)
        body = {"saleId": s["saleId"], "tillId": self.till.get(store, self.tills(store)[0]), "currencyCode": "NIO",
                "lines": [{"lineNumber": 1, "itemId": self.c.ids["item"], "quantity": s["qty"],
                           "unitPriceMinor": s.get("price", 120000)}],
                "tenders": tenders}
        if s.get("customer"):
            body["customerId"] = self.c.ids["customer"]
        status, resp = h.call(self.c.hosts[store].base, "POST", "/api/v1/sales", body, self.c.token(store))
        ok = status in (200, 201, 204)
        self.outcomes[key] = {"ok": ok, "status": status, "detail": f"{status} {_code(resp)}".strip()}
        self.event(f"sale {key} at {store}", status=status, problem=_code(resp))
        return ok

    def return_credit(self, key):
        r = self.returns[key]
        s = self.sales[r["sale"]]
        store = s["store"]
        token = self.c.token(store, "super")
        status, detail = h.call(self.c.hosts[store].base, "GET", f"/api/v1/sales/{s['saleId']}", token=token)
        if status != 200:
            raise SystemExit(f"sale detail {r['sale']}: {status} {detail}")
        body = {"reversalId": r["reversalId"], "creditId": r["creditId"], "tillId": self.till[store],
                "customerId": self.c.ids["customer"], "reason": "Cambio de talla",
                "lines": [{"saleLineId": detail["lines"][0]["saleLineId"], "quantity": r["qty"], "restockPool": "store"}]}
        status, resp = h.call(self.c.hosts[store].base, "POST", f"/api/v1/sales/{s['saleId']}/returns/credit", body, token)
        ok = status in (200, 201, 204)
        self.outcomes[key] = {"ok": ok, "status": status, "detail": f"{status} {_code(resp)}".strip()}
        self.event(f"return {key} to credit at {store}", status=status, problem=_code(resp))
        if not ok:
            raise SystemExit(f"return {key}: {status} {resp}")
        return ok

    # ---------- transfer steps (sql:no-http-route)
    def transfer(self, key, step):
        t = self.transfers[key]
        i, tid = self.c.ids, t["transferId"]
        credit = self.returns[t["credit"]]["creditId"]
        if step == "request":
            at = t["requested_at"]
            node, text = at, (f"EXEC credits.usp_TransferRequest @TransferId='{tid}',@CreditId='{credit}',"
                              f"@FromBranchId='{i['branch' + t['from'].upper()]}',@ToBranchId='{i['branch' + t['to'].upper()]}',"
                              f"@AmountMinor={t['amount']},@RequestedBy='{i['cashier' + at.upper()]}',"
                              f"@Reason=N'Ensayo: saldo en otra tienda',@NodeId='{self.c.node_id(at)}';")
        elif step == "approve":
            node, text = "cloud", (f"EXEC credits.usp_TransferApprove @TransferId='{tid}',@ApproverId='{i['manager']}',"
                                   f"@NodeId='{self.c.node_id('cloud')}';")
        elif step == "cancel":
            node, text = "cloud", (f"EXEC credits.usp_TransferCancel @TransferId='{tid}',@ActorId='{i['manager']}',"
                                   f"@Reason=N'Ensayo: cancelada en el hub',@NodeId='{self.c.node_id('cloud')}';")
        elif step == "dispatch":
            node, text = t["from"], (f"EXEC credits.usp_TransferDispatch @TransferId='{tid}',"
                                     f"@ActorId='{i['cashier' + t['from'].upper()]}',@NodeId='{self.c.node_id(t['from'])}';")
        elif step == "receive":
            node, text = t["to"], (f"EXEC credits.usp_TransferReceive @TransferId='{tid}',"
                                   f"@ActorId='{i['cashier' + t['to'].upper()]}',@NodeId='{self.c.node_id(t['to'])}';")
        else:
            raise ValueError(step)
        try:
            self.c.sql.admin(node, text)
            ok, err = True, ""
        except h.sim.SqlError as e:
            ok, err = False, f"Msg {e.number}"
        self.outcomes[f"{key}.{step}"] = {"ok": ok, "detail": err or "ok", "path": "sql:no-http-route"}
        self.event(f"transfer {key} {step} at {node} (sql:no-http-route)", ok=ok, error=err)
        return ok

    # ---------- waits
    def converge(self, label="converge", timeout=180):
        with self.phase(label):
            ok, secs, diff = self.c.converge(timeout=timeout)
            self.event(f"{label}: {'converged' if ok else 'NOT converged'} in {secs}s", differing=diff)
            return ok

    def wait_log(self, node, pattern, after=0, timeout=40):
        """Wait until the host log of node has a line matching pattern beyond byte offset after."""
        deadline = time.time() + timeout
        while time.time() < deadline:
            text = self.c.hosts[node].text()[after:]
            m = re.search(pattern, text)
            if m:
                return self.c.secrets.scrub(text[m.start():m.start() + 300].splitlines()[0])
            time.sleep(0.5)
        return None

    def log_size(self, node):
        return len(self.c.hosts[node].text())

    # ---------- final checks
    def finish(self, converged=True, expect_converge=True):
        with self.phase("checks"):
            snaps = {n: self.c.sql.snapshot(n) for n in h.NODES}
            results = checks.evaluate(self.m, self.c.ids, snaps, self.outcomes)
            diff = checks.r1(self.c.sql.hashes())
            unexpected, pins_missing = checks.conservation(self.c.sql.conservation_rows(), self.m.get("conservation_allow"))
        results.append((not diff, "R1: 18 synced tables identical on hub, a, b, c", f"differ={diff}"))
        results.append((not unexpected, "CONS: audit.usp_CheckConservation has 0 violations on 4 nodes",
                        "; ".join(unexpected[:6])))
        if self.m.get("conservation_allow"):
            results.append((not pins_missing, "CONS: pinned known violations still present", f"missing={pins_missing}"))
        results.append((converged or not expect_converge, "sync converged", ""))
        for c in self.controls:
            results.append((c["ok"], f"control {c['control']}", f"expected {c['expected']}; actual {c['actual']}"))
        self.results = [{"ok": ok, "check": name, "detail": detail} for ok, name, detail in results]
        failed = [r for r in self.results if not r["ok"]]
        if self.verdict is None:
            self.verdict = "PASS" if not failed else "FAIL"
            self.reason = "" if not failed else "; ".join(f"{r['check']} ({r['detail']})" for r in failed[:4])
        return self.verdict

    def report(self):
        rounds = {}
        for s in h.STORES:
            lines = self.c.round_lines(s)
            ok = [l for l in lines if ": pulled" in l]
            other = [l for l in lines if ": pulled" not in l]
            rounds[s] = {"successful_rounds": len(ok), "rebuilt_rounds": sum(1 for l in ok if "rebuilt True" in l),
                         "not_successful": len(other), "distinct_warnings": sorted(set(re.sub(r"\d+", "#", l) for l in other))[:8],
                         "host_starts": self.c.hosts[s].starts}
        exchanges = {}
        for s, p in self.c.proxies.items():
            counts = {}
            for e in p.log:
                k = f"{e['path']} {e['status']}"
                counts[k] = counts.get(k, 0) + 1
            exchanges[s] = counts
        return {
            "scenario": self.scenario, "verdict": self.verdict, "reason": self.reason,
            "identity": self.c.identity,
            "manifest": {"path": self.manifest_path.relative_to(h.SAVIA).as_posix(), "sha256": self.sha},
            "seconds_total": round(time.time() - self.t0, 1), "phases": self.phases, "events": self.events,
            "checks": {"passed": sum(r["ok"] for r in self.results), "failed": sum(not r["ok"] for r in self.results),
                       "failures": [r for r in self.results if not r["ok"]]},
            "check_list": [f"{'PASS' if r['ok'] else 'FAIL'} {r['check']}" for r in self.results],
            "controls": self.controls, "outcomes": self.outcomes,
            "sync_rounds_from_host_logs": rounds, "hub_exchanges_seen_by_proxies": exchanges,
            "hub_rounds_log_errors": self.c.log_excerpt("cloud", r"fail|error|Exception", 4),
        }


def _code(body):
    if isinstance(body, dict):
        return body.get("code") or body.get("title") or ""
    return "" if body in (None, "") else str(body)[:120]


# ================================================================ scenarios
def offline_sales(r):
    r.bring_up()
    with r.phase("hub stopped; stores sell"):
        marks = {s: r.log_size(s) for s in h.STORES}
        r.c.hosts["cloud"].kill("hub stopped")
        for s in h.STORES:
            line = r.wait_log(s, r"could not reach the hub", marks[s])
            r.event(f"store {s} worker while hub is down", log=line)
        for key in ("a1", "a2", "b1", "b2", "c1", "c2"):
            r.sale(key)
        ids = [s["saleId"] for s in r.m["sales"]]
        r.event("hub database holds none of the offline sales", count=r.c.sql.count_sales("cloud", ids))
    with r.phase("hub restarted"):
        r.c.hosts["cloud"].start()
    ok = r.converge("converge after hub returns")
    return r.finish(ok)


def replay(r):
    r.bring_up()
    sale = r.sales
    with r.phase("A killed after the hub committed its push, before A hears the answer"):
        rule = r.c.proxies["a"].add_rule(name="kill A after push", kind="after", path="/sync/v1/push",
                                         contains=sale["ra1"]["saleId"], action=lambda: r.c.hosts["a"].kill("mid-round: hub answered push"))
        r.sale("ra1")
        fired = rule["event"].wait(45)
        r.event("kill point reached", fired=fired, hub_status=rule.get("status"))
        r.event("hub holds ra1 while A is dead", count=r.c.sql.count_sales("cloud", [sale["ra1"]["saleId"]]))
        r.c.hosts["a"].start()
    with r.phase("B killed after the hub answered a pull carrying ra2, before B applies it"):
        rule = r.c.proxies["b"].add_rule(name="kill B after pull", kind="after", path="/sync/v1/pull", on="response",
                                         contains=sale["ra2"]["saleId"], action=lambda: r.c.hosts["b"].kill("mid-round: hub answered pull"))
        r.sale("ra2")
        fired = rule["event"].wait(60)
        r.event("kill point reached", fired=fired, hub_status=rule.get("status"))
        r.event("B does not hold ra2 yet", count=r.c.sql.count_sales("b", [sale["ra2"]["saleId"]]))
        r.c.hosts["b"].start()
        r.sale("rc1")
    ok = r.converge("converge after restarts")
    return r.finish(ok)


def hub_restart(r):
    r.bring_up()
    with r.phase("hub killed after committing A's push, before answering"):
        rule = r.c.proxies["a"].add_rule(name="kill hub after push", kind="after", path="/sync/v1/push",
                                         contains=r.sales["h1"]["saleId"], action=lambda: r.c.hosts["cloud"].kill("mid-round: hub answered push"))
        r.sale("h1")
        fired = rule["event"].wait(45)
        r.event("kill point reached", fired=fired, hub_status=rule.get("status"))
        r.event("hub database holds h1 (committed before the crash)", count=r.c.sql.count_sales("cloud", [r.sales["h1"]["saleId"]]))
    with r.phase("stores sell while the hub is down"):
        r.sale("h2")
        r.sale("h3")
        time.sleep(h.INTERVAL + 1)
    with r.phase("hub restarted"):
        r.c.hosts["cloud"].start()
        r.sale("h4")
    ok = r.converge("converge after hub restart")
    return r.finish(ok)


def credit_transfer(r):
    r.bring_up()
    with r.phase("A sells two items and returns both to store credit (HTTP)"):
        r.sale("s1"); r.sale("s2")
        r.return_credit("r1"); r.return_credit("r2")
    r.converge("converge credits")
    with r.phase("t1: B asks for 50000 of r1; hub approves; A dispatches; B receives"):
        r.transfer("t1", "request"); r.converge("converge t1 request")
        r.transfer("t1", "approve"); r.converge("converge t1 approval")
        r.transfer("t1", "dispatch"); r.converge("converge t1 dispatch")
        r.transfer("t1", "receive"); r.converge("converge t1 receipt")
    with r.phase("B spends the received 50000 (HTTP)"):
        r.sale("sb1")
    with r.phase("concurrent spend: two sales at A each try the remaining 70000 of r1"):
        threads = [threading.Thread(target=r.sale, args=(k,)) for k in ("sx", "sy")]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
    with r.phase("t2 cancel vs dispatch: hub cancels while A, cut off, dispatches"):
        r.transfer("t2", "request"); r.converge("converge t2 request")
        r.transfer("t2", "approve"); r.converge("converge t2 approval")
        r.c.proxies["a"].mode = "down"
        r.transfer("t2", "cancel")
        dispatched = r.transfer("t2", "dispatch")
        r.control("offline A can dispatch an approved transfer the hub cancelled", dispatched, "dispatch ok", dispatched)
        r.c.proxies["a"].mode = "pass"
        r.converge("converge t2 dispatch vs cancel")
        r.transfer("t2", "receive")
    ok = r.converge("final convergence")
    return r.finish(ok)


def restore_sale_before_rebuild(r):
    """Red test for the recovery lock (P9 open question 2). Expected today: 2601 UX_OpenTill_Register at A's rebuild."""
    r.bring_up(skip_tills=("a",))
    with r.phase("backup A before its till opens; A opens a till and sells; hub has it"):
        h.backup("a", "before_till")
        r.open_till("a", r.tills("a")[0])
        r.sale("r1"); r.sale("r2")
    r.converge("converge before restore")
    with r.phase("A stopped, cut off and restored from the backup"):
        r.c.hosts["a"].kill("stopped for restore")
        r.c.proxies["a"].mode = "down"
        h.restore("a", "before_till")
        mark = r.log_size("a")
        r.c.hosts["a"].start()
    with r.phase("restored A opens a new till and sells before its first rebuild"):
        status, body = h.call(r.c.hosts["a"].base, "GET", "/api/v1/cash/registers", token=r.c.token("a"))
        r.event("old session token after the restore", status=status, problem=_code(body))
        r.c.tokens = {k: v for k, v in r.c.tokens.items() if k[0] != "a"}  # the cashier signs in again
        till_ok = r.open_till("a", r.tills("a")[1])
        r.event("new till on the restored store", ok=till_ok)
        r.sale("r3")
    with r.phase("link back: A's worker must rebuild"):
        r.c.proxies["a"].mode = "pass"
        # The API maps SQL 2601 to the generic problem db.duplicate, so the store log does not name the index.
        red = r.wait_log("a", r"Sync round refused: db\.duplicate|UX_OpenTill_Register|Msg 2601", mark, timeout=60)
        r.event("A rebuild outcome", red_line=red)
        q = ("SET @out=(SELECT Id AS till, RegisterId AS reg, Status AS st FROM sales.CashTills "
             f"WHERE RegisterId='{r.c.ids['registerA']}' AND Status='open' AND ParentTillId IS NULL FOR JSON PATH);")
        r.event("open tills on register A", hub=r.c.sql.fetch("cloud", q), restored_a=r.c.sql.fetch("a", q))
        sql_error = None
        if red:  # only after the worker failed: a successful pull would commit and do the rebuild for the worker
            try:  # the same rebuild pull in SQL; on error its transaction rolls back
                r.c.sql.pull("a", "cloud", "all")
            except Exception as e:  # noqa: BLE001
                text = str(e)
                line = next((l.strip() for l in text.splitlines() if "duplicate key" in l), text[-300:])
                sql_error = f"Msg {getattr(e, 'number', '?')}: {line}"
            r.event("rebuild pull reproduced in SQL", error=sql_error)
    ok = r.converge("converge after restore", timeout=60 if red else 180)
    verdict = r.finish(ok)
    pinned = bool(sql_error) and "UX_OpenTill_Register" in sql_error and "2601" in sql_error
    # The red may explain only these failures; anything else (a lost sale on hub, b or c) stays a FAIL.
    allowed = {"a: sale r1 present", "a: sale r2 present", "R1: 18 synced tables identical on hub, a, b, c",
               "CONS: pinned known violations still present", "sync converged"}
    other = [x["check"] for x in r.results if not x["ok"] and x["check"] not in allowed]
    r.event("failures outside the pinned red", checks=other)
    if red and pinned and not ok and not other:
        r.verdict, r.reason = "XFAIL", (f"expected red: the rebuild of restored A fails every round ({red}); "
                                        f"SQL: {sql_error}")
    elif verdict == "PASS":
        r.verdict, r.reason = "XPASS", "the recovery lock red test passed; remove the XFAIL marker"
    else:
        r.reason = "unexpected failure (not the pinned 2601): " + r.reason
    return r.verdict


def controls(r):
    r.bring_up()
    hub = r.c.hosts["cloud"].base
    a, b = r.c.node_id("a"), r.c.node_id("b")
    with r.phase("401: wrong node credentials"):
        cases = [("A real secret (positive control)", f"SaviaNode {a}.{r.c.node_secret['a']}", 200),
                 ("A with a wrong secret", f"SaviaNode {a}.{h.secrets.token_urlsafe(32)}", 401),
                 ("A id with B's secret", f"SaviaNode {a}.{r.c.node_secret['b']}", 401),
                 ("no Authorization header", None, 401)]
        for name, header, want in cases:
            status, body = h.call(hub, "GET", "/sync/v1/state", headers={"Authorization": header} if header else None)
            r.control(f"401 {name}", status == want and (want == 200 or _code(body) == "sync.unauthorized"),
                      f"{want}" + ("" if want == 200 else " sync.unauthorized"), f"{status} {_code(body)}")
    with r.phase("51851: A's push rewritten so a sale row names store B"):
        branch_a, branch_b = r.c.ids["branchA"], r.c.ids["branchB"]
        rule = r.c.proxies["a"].add_rule(name="foreign row", kind="tamper_request", path="/sync/v1/push",
                                         contains=r.sales["k1"]["saleId"],
                                         fn=lambda body: re.sub(re.escape(branch_a).encode(), branch_b.encode(), body, flags=re.I))
        mark = r.log_size("a")
        r.sale("k1")
        rule["event"].wait(45)
        line = r.wait_log("a", r"Sync round refused: \S+", mark, 20)
        r.control("51851 foreign row", rule.get("status") == 403 and "sync.foreign_row" in (rule.get("problem") or ""),
                  "403 sync.foreign_row", f"{rule.get('status')} {_problem_code(rule.get('problem'))}; store log: {line}")
    r.converge("converge after the refused push (the untampered retry)")
    with r.phase("51854: A restored; the proxy hides 'recover' so A pushes without a rebuild token"):
        r.c.hosts["a"].kill("stopped for restore")
        h.backup("a", "synced")
        h.restore("a", "synced")
        watch = r.c.proxies["a"].add_rule(name="first push after restore", kind="observe", path="/sync/v1/push", contains="")
        hide = r.c.proxies["a"].add_rule(
            name="hide recover", kind="tamper_response", path="/sync/v1/push/plan", contains="", limit=1000,
            fn=lambda data: data if watch["event"].is_set() else re.sub(rb'"a"\s*:\s*"recover"', b'"a":"reinit"', data))
        mark = r.log_size("a")
        r.c.hosts["a"].start()
        watch["event"].wait(45)
        hide["limit"] = 0
        r.control("51854 push from a restored fork without a rebuild token",
                  watch.get("status") == 409 and "sync.rebuild_required" in (watch.get("problem") or ""),
                  "409 sync.rebuild_required", f"{watch.get('status')} {_problem_code(watch.get('problem'))}")
        rebuilt = r.wait_log("a", r"Sync round: pulled \d+, pushed \d+, rebuilt True", mark, 40)
        r.control("restored A then rebuilds by itself (hosted loop)", rebuilt is not None, "rebuilt True", rebuilt)
        r.sale("k2")
    ok = r.converge("final convergence")
    return r.finish(ok)


def _problem_code(text):
    try:
        return json.loads(text).get("code")
    except (ValueError, TypeError, AttributeError):
        return (text or "")[:80]


SCENARIOS = {
    "offline_sales": offline_sales,
    "replay": replay,
    "credit_transfer": credit_transfer,
    "restore_sale_before_rebuild": restore_sale_before_rebuild,
    "hub_restart": hub_restart,
    "controls": controls,
}
