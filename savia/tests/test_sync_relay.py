"""Client sync relay (tools/load/sync_relay.py): unit contract, plus a two-server integration run.

Unit tests need nothing but Python (pyodbc only for the connection-error sentinel).
The integration test runs when SAVIA_RELAY_IT=1 and needs, on this machine only:
  SAVIA_SQL_CONTAINER=savia-sqlserver-load   store server, after generate.py at SAVIA_RELAY_SCALE / SAVIA_RELAY_SEED
  SAVIA_RELAY_HUB_CONTAINER=savia-sqlserver-relayhub   a second, separate SQL Server container (the hub)
Both containers publish 1433 on 127.0.0.1. The hub is reached only through a plain ODBC string built in-process.
It drops and recreates SAVIA_SIM_load_hub on the hub container and restores the presync stores in the store container.
Outputs go to savia/.out/relay-it/.
"""
import argparse
import importlib.util
import io
import json
import os
import re
import struct
import subprocess
import sys
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("sync_relay", ROOT / "tools/load/sync_relay.py")
relay = importlib.util.module_from_spec(spec)
spec.loader.exec_module(relay)
OUT = ROOT / ".out" / "relay-it"
SENTINEL = "Sentinel-Pw-7f3c91"


def have_pyodbc():
    return importlib.util.find_spec("pyodbc") is not None


class UnitTests(unittest.TestCase):
    def test_token_struct_is_length_prefixed_utf16le(self):
        packed = relay.token_struct("eyJ0b2tlbg")
        raw = "eyJ0b2tlbg".encode("utf-16-le")
        self.assertEqual(struct.unpack("<I", packed[:4])[0], len(raw))
        self.assertEqual(packed[4:], raw)

    def test_split_go_matches_sqlcmd_batches(self):
        text = "CREATE TABLE t(x int);\r\nGO\r\nSELECT 'GO' AS x; -- GO inside a line\ngo  \nPRINT 1;\nGO -- end\n"
        self.assertEqual([b.strip() for b in relay.split_go(text)],
                         ["CREATE TABLE t(x int);", "SELECT 'GO' AS x; -- GO inside a line", "PRINT 1;"])

    def test_token_refuses_string_with_credentials(self):
        for cs in ("Server=x;UID=u;PWD=p", "Server=x;Authentication=ActiveDirectoryPassword", "Server=x;Trusted_Connection=yes"):
            with self.assertRaises(relay.RelayError):
                relay.connect(cs, token="tok")

    def test_scrub_removes_every_secret(self):
        self.assertEqual(relay.scrub("a SECRET b TOKEN", ["SECRET", "TOKEN", None]), "a *** b ***")

    @unittest.skipUnless(have_pyodbc(), "pyodbc not installed")
    def test_failed_connection_never_echoes_string_or_token(self):
        cs = (f"Driver={{ODBC Driver 18 for SQL Server}};Server=127.0.0.1,1;Database=x;UID=sa;PWD={{{SENTINEL}}};"
              "Encrypt=yes;TrustServerCertificate=yes;Connection Timeout=2")
        env = dict(os.environ, SAVIA_HUB_ODBC=cs)
        env.pop("SAVIA_HUB_ACCESS_TOKEN", None)
        p = subprocess.run([sys.executable, str(ROOT / "tools/load/sync_relay.py"), "hub-load", "--seed", "x", "--scale", "0.1",
                            "--out", str(OUT / "sentinel.json")], env=env, capture_output=True, text=True, timeout=120)
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("connect failed", p.stdout + p.stderr)
        self.assertNotIn(SENTINEL, p.stdout + p.stderr)
        self.assertFalse((OUT / "sentinel.json").exists())

    def test_parity_logic(self):
        same = {"[sales].[Sales]": {"rows": 3, "sha256": "aa"}, "[sales].[SaleLines]": {"rows": 4, "sha256": "bb"}}
        store_db, hub_db = object(), object()

        def digests(store, hub):
            return lambda db, node: store if db is store_db else hub

        with patch.object(relay, "local_node", return_value="N"):
            with patch.object(relay, "table_digests", digests(same, dict(same))):
                self.assertTrue(relay.parity(store_db, hub_db)["ok"])
            bad = dict(same, **{"[sales].[Sales]": {"rows": 3, "sha256": "zz"}})
            with patch.object(relay, "table_digests", digests(same, bad)):
                r = relay.parity(store_db, hub_db)
                self.assertFalse(r["ok"])
                self.assertIn("checksum differs", r["problems"][0])
            with patch.object(relay, "table_digests", digests(same, {"[sales].[Sales]": same["[sales].[Sales]"]})):
                self.assertFalse(relay.parity(store_db, hub_db)["ok"])  # a table missing on one side
            empty = {k: {"rows": 0, "sha256": None} for k in same}
            with patch.object(relay, "table_digests", digests(empty, dict(empty))):
                self.assertFalse(relay.parity(store_db, hub_db)["ok"])  # nothing compared is not a pass


def docker_env(container, key):
    p = subprocess.run(["docker", "exec", container, "printenv", key], capture_output=True, text=True)
    return p.stdout.strip()


def hub_conn_str(container, db):
    port = re.search(r"127\.0\.0\.1:(\d+)", subprocess.run(["docker", "port", container, "1433/tcp"],
                                                          capture_output=True, text=True).stdout).group(1)
    pw = docker_env(container, "MSSQL_SA_PASSWORD").replace("}", "}}")
    return (f"Driver={{ODBC Driver 18 for SQL Server}};Server=127.0.0.1,{port};Database={db};UID=sa;PWD={{{pw}}};"
            "Encrypt=yes;TrustServerCertificate=yes")


@unittest.skipUnless(os.environ.get("SAVIA_RELAY_IT") == "1", "integration run: set SAVIA_RELAY_IT=1 (two local containers)")
class TwoServerRelayTest(unittest.TestCase):
    def test_relay_end_to_end_with_parity_and_negative_control(self):
        hub_c = os.environ["SAVIA_RELAY_HUB_CONTAINER"]
        store_c = os.environ["SAVIA_SQL_CONTAINER"]
        self.assertNotEqual(hub_c, store_c, "store and hub must be different servers")
        self.assertTrue(re.fullmatch(r"savia-sqlserver-[a-z0-9-]+", hub_c))
        seed, scale = os.environ.get("SAVIA_RELAY_SEED", "relay-20261123"), float(os.environ.get("SAVIA_RELAY_SCALE", "0.03"))
        OUT.mkdir(parents=True, exist_ok=True)
        evidence = {"store_container": store_c, "hub_container": hub_c, "seed": seed, "scale": scale}

        def save():
            (OUT / "integration.json").write_text(json.dumps(evidence, indent=1, default=str), encoding="utf-8")

        # 1. an empty hub database on the hub server (local setup only; on Azure the database already exists)
        p = subprocess.run(["docker", "exec", hub_c, "bash", "-c",
                            '/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -C -b -Q '
                            '"IF DB_ID(N\'SAVIA_SIM_load_hub\') IS NOT NULL BEGIN ALTER DATABASE [SAVIA_SIM_load_hub] SET SINGLE_USER '
                            'WITH ROLLBACK IMMEDIATE; DROP DATABASE [SAVIA_SIM_load_hub]; END; CREATE DATABASE [SAVIA_SIM_load_hub];"'],
                           capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        os.environ["SAVIA_HUB_ODBC"] = hub_conn_str(hub_c, "SAVIA_SIM_load_hub")
        os.environ.pop("SAVIA_HUB_ACCESS_TOKEN", None)
        hub = relay.hub()
        self.assertNotEqual(hub.scalar("SELECT @@SERVERNAME;"),
                            relay.connect(relay.store_conn_str("master")).scalar("SELECT @@SERVERNAME;"))

        # 2. base catalog over the plain connection; it must equal the hub generate.py built with BACKUP/RESTORE
        template = relay.connect(relay.store_conn_str("SAVIA_SIM_load_hub"))
        evidence["hub_load"] = relay.hub_load(hub, seed, scale, created_at=relay.generated_created_at(template))
        save()
        mine, theirs = relay.catalog_fingerprint(hub), relay.catalog_fingerprint(template)
        evidence["hub_catalog"] = {"relay_hub": mine, "generate_hub": theirs}
        save()
        self.assertEqual(mine, theirs)
        evidence["aligned"] = relay.align_reference(hub, template)
        save()
        self.assertTrue(set(evidence["aligned"]) <= {"[catalog].[Sizes]", "[catalog].[Colors]", "[sourcing].[Suppliers]",
                                                     "[catalog].[Products]", "[catalog].[Items]", "[catalog].[ItemIdentifiers]",
                                                     "[crm].[Customers]"}, evidence["aligned"])
        self.assertLess(sum(v["source_only"] for v in evidence["aligned"].values()), 50, "only fixture rows may differ")
        self.assertEqual(relay.align_reference(hub, template), {}, "hub-owned synced rows must now equal the template")
        self.assertEqual(relay.local_node(hub).upper(), relay.CLOUD)

        # 3. stores as freshly installed nodes (the same preparation sync_measure.py does)
        sys.path.insert(0, str(ROOT / "tools" / "load"))
        import sync_measure
        with redirect_stdout(io.StringIO()):
            sync_measure.restore(["a", "b", "c"], "presync", fresh_install=True)

        # 4. initial push, smallest store first, each through the client
        stores = {k: relay.store(k) for k in "abc"}
        evidence["push"] = {}
        for k in "cba":
            r = relay.relay(stores[k], hub, f"{k}->hub")
            evidence["push"][k] = r
            save()
            self.assertNotIn("error", r, r.get("error"))
            self.assertTrue(r["finished"])
            self.assertGreater(r["rows"], 0)
        self.assertGreaterEqual(evidence["push"]["a"]["page_count"], 2, "the dataset must force the page loop")

        # 5. an empty round moves nothing
        r = relay.relay(stores["a"], hub, "a->hub empty")
        evidence["empty_round"] = r
        self.assertTrue(r["finished"])
        self.assertEqual(r["rows"], 0)

        # 6. parity per store, then through the CLI (exit code is the contract)
        evidence["parity"] = {k: relay.parity(stores[k], hub) for k in "abc"}
        save()
        for k in "abc":
            self.assertTrue(evidence["parity"][k]["ok"], evidence["parity"][k]["problems"])
        cli = subprocess.run([sys.executable, str(ROOT / "tools/load/sync_relay.py"), "parity", "--store", "a",
                              "--out", str(OUT / "parity_a.json")], capture_output=True, text=True, timeout=600)
        evidence["parity_cli_exit"] = cli.returncode
        self.assertEqual(cli.returncode, 0, cli.stdout[-2000:] + cli.stderr[-2000:])
        self.assertIn("PARITY OK", cli.stdout)

        # 7. negative control: one changed column on one hub row owned by store A must fail parity
        key = hub.rows("SELECT TOP(1) CONVERT(varchar(36),b.LocationId),CONVERT(varchar(36),b.ItemId),b.Pool "
                       "FROM inventory.StockBalances b WHERE b.LocationId='A0000000-0000-0000-0000-0000000000A1' ORDER BY b.ItemId;")[0]
        where = "LocationId=? AND ItemId=? AND Pool=?"
        n = hub.scalar(f"UPDATE inventory.StockBalances SET OnHand=OnHand+1 WHERE {where};SELECT @@ROWCOUNT;", *key)
        try:
            self.assertEqual(n, 1)
            cli = subprocess.run([sys.executable, str(ROOT / "tools/load/sync_relay.py"), "parity", "--store", "a",
                                  "--out", str(OUT / "parity_a_negative.json")], capture_output=True, text=True, timeout=600)
            evidence["negative_control"] = {"updated_rows": n, "cli_exit": cli.returncode,
                                            "summary": cli.stdout.strip().splitlines()[-1]}
            save()
            self.assertEqual(cli.returncode, 1)
            self.assertIn("[inventory].[StockBalances]: store", cli.stdout)
            self.assertIn("checksum differs", cli.stdout)
        finally:
            hub.rows(f"UPDATE inventory.StockBalances SET OnHand=OnHand-1 WHERE {where};", *key)
        self.assertTrue(relay.parity(stores["a"], hub)["ok"], "parity must recover once the row is restored")

        # 8. the other direction through the same client: A pulls B and C from the hub
        r = relay.relay(hub, stores["a"], "hub->a")
        evidence["pull_a"] = r
        save()
        self.assertTrue(r["finished"], r.get("error"))
        self.assertGreater(r["rows"], 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
