"""Unit tests for the four-node rehearsal: manifest rules, oracles and the fault proxy. No SQL, no API hosts.

  python -m unittest discover -s savia/tests -p "test_rehearsal.py"
"""
import http.client
import json
import os
import socket
import sys
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1] / "tools"
sys.path.insert(0, str(TOOLS / "rehearsal"))
import checks  # noqa: E402

IDS = {"branchA": "B0000000-0000-0000-0000-00000000000A", "branchB": "B0000000-0000-0000-0000-00000000000B",
       "branchC": "B0000000-0000-0000-0000-00000000000C", "locA": "10C00000-0000-0000-0000-00000000000A",
       "locB": "10C00000-0000-0000-0000-00000000000B", "locC": "10C00000-0000-0000-0000-00000000000C",
       "item": "17E40000-0000-0000-0000-000000000001"}
S1 = "5A1E0000-0000-4000-8000-00000000000A"
S2 = "5A1E0000-0000-4000-8000-00000000000B"


def manifest(**extra):
    m = {"scenario": "t", "sales": [{"key": "s1", "store": "a", "saleId": S1, "qty": 1,
                                     "tenders": [{"kind": "cash", "amount": 120000}]}],
         "store_totals": {"a": {"count": 1, "totalMinor": 120000}}}
    m.update(extra)
    return m


def sale_row(sale_id, branch="branchA", qty=1):
    return {"id": sale_id, "branch": IDS[branch], "total": qty * 120000, "nl": 1, "qty": qty, "nt": 1,
            "tsum": qty * 120000, "stock": -qty, "cash": qty * 120000}


def snaps(rows_by_node):
    return {n: {"sales": rows_by_node.get(n, []), "stock": [], "reversals": [], "credits": [], "alloc": [],
                "transfers": []} for n in checks.NODES}


def failed(results):
    return [(name, detail) for ok, name, detail in results if not ok]


class ManifestTest(unittest.TestCase):
    def test_shipped_manifests_are_valid(self):
        for path in sorted((TOOLS / "rehearsal" / "expected").glob("*.json")):
            m, sha = checks.load(path)
            self.assertEqual(checks.validate(m), [], path.name)
            self.assertEqual(len(sha), 64)

    def test_rejects_bad_manifests(self):
        cases = {
            "lower-case GUID": manifest(sales=[dict(manifest()["sales"][0], saleId=S1.lower())]),
            "tenders != total": manifest(sales=[dict(manifest()["sales"][0], tenders=[{"kind": "cash", "amount": 1}])]),
            "duplicate id": manifest(sales=[manifest()["sales"][0], dict(manifest()["sales"][0], key="s2")],
                                     store_totals={}),
            "totals mismatch": manifest(store_totals={"a": {"count": 2, "totalMinor": 120000}}),
            "unknown store": manifest(sales=[dict(manifest()["sales"][0], store="z")], store_totals={}),
            "credit names unknown return": manifest(sales=[dict(manifest()["sales"][0],
                                                                tenders=[{"kind": "credit", "credit": "x", "amount": 120000}])]),
        }
        for name, m in cases.items():
            self.assertNotEqual(checks.validate(m), [], name)


class EvaluateTest(unittest.TestCase):
    def test_exactly_once_on_every_node_passes(self):
        res = checks.evaluate(manifest(), IDS, snaps({n: [sale_row(S1)] for n in checks.NODES}))
        self.assertEqual(failed(res), [])

    def test_missing_expected_sale_fails_on_the_node_that_lacks_it(self):
        rows = {n: [sale_row(S1)] for n in ("cloud", "a", "b")}
        names = [name for name, _ in failed(checks.evaluate(manifest(), IDS, snaps(rows)))]
        self.assertIn("c: sale s1 present", names)
        self.assertIn("c: store a totals", names)

    def test_injected_sale_the_driver_never_made_fails(self):
        m = manifest()
        m["sales"].append({"key": "ghost", "store": "a", "saleId": S2, "qty": 1,
                           "tenders": [{"kind": "cash", "amount": 120000}]})
        names = [name for name, _ in failed(checks.evaluate(m, IDS, snaps({n: [sale_row(S1)] for n in checks.NODES})))]
        self.assertEqual(sorted(set(n.split(": ", 1)[1] for n in names)), ["sale ghost present"])

    def test_duplicate_effects_and_extra_sales_fail(self):
        doubled = dict(sale_row(S1), nl=2, stock=-2)
        res = checks.evaluate(manifest(), IDS, snaps({n: [doubled, sale_row(S2)] for n in checks.NODES}))
        names = [name for name, _ in failed(res)]
        self.assertIn("cloud: sale s1 once with its effects", names)
        self.assertIn("cloud: no sale outside the manifest", names)

    def test_wrong_branch_fails(self):
        res = checks.evaluate(manifest(store_totals={}), IDS, snaps({n: [sale_row(S1, "branchB")] for n in checks.NODES}))
        self.assertTrue(any("once with its effects" in name for name, _ in failed(res)))

    def test_absent_and_group(self):
        m = manifest(sales=[
            {"key": "x", "store": "a", "saleId": S1, "qty": 1, "tenders": [{"kind": "cash", "amount": 120000}],
             "group": "g"},
            {"key": "y", "store": "a", "saleId": S2, "qty": 1, "tenders": [{"kind": "cash", "amount": 120000}],
             "group": "g"}], store_totals={})
        self.assertEqual(checks.validate(m), [])
        one = checks.evaluate(m, IDS, snaps({n: [sale_row(S1)] for n in checks.NODES}),
                              {"x": {"ok": True}, "y": {"ok": False}})
        self.assertEqual(failed(one), [])
        both = checks.evaluate(m, IDS, snaps({n: [sale_row(S1), sale_row(S2)] for n in checks.NODES}))
        self.assertTrue(any("exactly one present" in name for name, _ in failed(both)))
        m2 = manifest(sales=[dict(manifest()["sales"][0], expect="absent")], store_totals={})
        self.assertTrue(failed(checks.evaluate(m2, IDS, snaps({"a": [sale_row(S1)]}), {"s1": {"ok": True}})))


class OracleTest(unittest.TestCase):
    def test_r1(self):
        same = {n: {"sales.Sales": (1, "x"), "sales.SaleLines": (1, "y")} for n in checks.NODES}
        self.assertEqual(checks.r1(same), [])
        same["b"] = {"sales.Sales": (2, "z"), "sales.SaleLines": (1, "y")}
        self.assertEqual(checks.r1(same), ["sales.Sales"])

    def test_conservation_pins(self):
        v = {"CheckName": "sale.outbox_event", "KeyText": "abc"}
        allow = [{"node": "a", "check": "sale.outbox_event", "key": "ABC", "why": "known"}]
        self.assertEqual(checks.conservation({"a": [v]}, allow), ([], []))
        unexpected, missing = checks.conservation({"b": [v]}, allow)
        self.assertEqual(len(unexpected), 1)
        self.assertEqual(missing, [("a", "sale.outbox_event", "ABC")])


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


class Upstream(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    seen = []

    def log_message(self, *_):
        pass

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length") or 0))
        Upstream.seen.append(body)
        data = json.dumps({"echo": body.decode()}).encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


class ProxyTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # harness sets SAVIA_SQL_CONTAINER and repoints simulator.DBN for its process; undo both in tearDownClass
        cls.env_before = os.environ.get("SAVIA_SQL_CONTAINER")
        cls.modules_before = set(sys.modules)
        cls.dbn_before = dict(sys.modules["simulator"].DBN) if "simulator" in sys.modules else None
        import harness  # imports saviadb and simulator; needs no container until a SQL call
        cls.harness = harness
        cls.up_port, cls.px_port = free_port(), free_port()
        cls.upstream = ThreadingHTTPServer(("127.0.0.1", cls.up_port), Upstream)
        threading.Thread(target=cls.upstream.serve_forever, daemon=True).start()
        cls.proxy = harness.Proxy("a", cls.px_port, cls.up_port).start()

    @classmethod
    def tearDownClass(cls):
        cls.proxy.stop()
        cls.upstream.shutdown()
        cls.upstream.server_close()
        if cls.env_before is None:
            os.environ.pop("SAVIA_SQL_CONTAINER", None)
        else:
            os.environ["SAVIA_SQL_CONTAINER"] = cls.env_before
        if cls.dbn_before is not None:
            sys.modules["simulator"].DBN.clear()
            sys.modules["simulator"].DBN.update(cls.dbn_before)
        for name in set(sys.modules) - cls.modules_before:
            if name in ("harness", "saviadb", "simulator"):
                del sys.modules[name]

    def post(self, path, body):
        conn = http.client.HTTPConnection("127.0.0.1", self.px_port, timeout=10)
        try:
            conn.request("POST", path, body=body, headers={"Content-Type": "application/json"})
            resp = conn.getresponse()
            return resp.status, resp.read()
        finally:
            conn.close()

    def setUp(self):
        self.proxy.mode, self.proxy.rules = "pass", []
        Upstream.seen.clear()

    def test_pass_relays(self):
        self.assertEqual(self.post("/x", b"hello"), (200, json.dumps({"echo": "hello"}).encode()))

    def test_down_cuts_the_link(self):
        self.proxy.mode = "down"
        with self.assertRaises((http.client.HTTPException, OSError)):
            self.post("/x", b"hello")
        self.assertEqual(Upstream.seen, [])
        self.assertEqual(self.proxy.log[-1]["status"], "cut")

    def test_tamper_request_fires_once(self):
        rule = self.proxy.add_rule(name="t", kind="tamper_request", path="/push", contains="AAA",
                                   fn=lambda b: b.replace(b"aaa", b"bbb"))
        self.post("/push", b"aaa")
        self.post("/push", b"aaa")
        self.assertEqual(Upstream.seen, [b"bbb", b"aaa"])
        self.assertTrue(rule["event"].is_set())
        self.assertEqual(rule["status"], 200)

    def test_tamper_response(self):
        self.proxy.add_rule(name="r", kind="tamper_response", path="/plan", on="response", contains="RECOVER",
                            fn=lambda d: d.replace(b"recover", b"reinit"))
        status, data = self.post("/plan", b"recover")
        self.assertEqual((status, json.loads(data)["echo"]), (200, "reinit"))

    def test_after_drops_the_answer_after_the_hub_applied_it(self):
        fired = []
        self.proxy.add_rule(name="kill", kind="after", path="/push", contains="", action=lambda: fired.append(1))
        with self.assertRaises((http.client.HTTPException, OSError)):
            self.post("/push", b"x")
        self.assertEqual((Upstream.seen, fired), ([b"x"], [1]))
        self.assertEqual(self.proxy.log[-1]["status"], "answer_dropped")


if __name__ == "__main__":
    unittest.main()
