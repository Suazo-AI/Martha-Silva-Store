#!/usr/bin/env python3
"""SAVIA four-node rehearsal: one hub and three store API hosts as real processes over real HTTP on localhost,
each with its own database, each store running the hosted SyncWorker loop. See docs/sync/REHEARSAL.md.

Commands:
  up                          start the rehearsal SQL container (savia-sqlserver-rehearsal, 127.0.0.1:14341)
  down                        remove that container and its volume, then print docker ps -a
  run [SCENARIO|all] [--identity auto|sa|restricted] [--manifest FILE] [--evidence DIR]
                              run scenarios; exit 0 only when every verdict is PASS or XFAIL
  selftest                    offline_sales with an injected expected sale the driver never makes: must FAIL
  probe-identity              start the four hosts with a login that is only in savia_api_host and record the result

Build first (outputs are gitignored):
  dotnet build src/Savia.Api/Savia.Api.csproj -c Release -o .out/rehearsal/api
  dotnet build deploy/migrator/Savia.Migrator.csproj -c Release -o .out/rehearsal/migrator
"""
import argparse
import json
import subprocess
import sys
import time
import traceback
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "rehearsal"))
import checks  # noqa: E402
import harness as h  # noqa: E402
import scenarios as sc  # noqa: E402

EVIDENCE = h.SAVIA / "docs" / "evidence" / "rehearsal-20261121"
ORDER = list(sc.SCENARIOS)  # one list: a scenario added to scenarios.py runs in `run all`
GOOD = {"PASS", "XFAIL"}


def say(text):
    print(text, flush=True)


def run_dir(name):
    d = h.OUT / "runs" / f"{time.strftime('%Y%m%d-%H%M%S')}-{name}"
    d.mkdir(parents=True, exist_ok=True)
    return d


def write_evidence(directory, name, data, cluster):
    if directory is None:
        return
    directory.mkdir(parents=True, exist_ok=True)
    text = json.dumps(data, indent=1, ensure_ascii=False, default=str)
    (directory / f"{name}.json").write_text(cluster.secrets.scrub(text) + "\n", encoding="utf-8")


def run_one(name, manifest, identity, evidence):
    say(f"== {name} (identity {identity})")
    r = sc.Run(name, manifest, identity, run_dir(name), say)
    try:
        sc.SCENARIOS[name](r)
    except BaseException as e:  # noqa: BLE001 - every failure must be recorded, then the hosts stopped
        r.verdict, r.reason = "ERROR", f"{type(e).__name__}: {e}"
        r.events.append({"event": "traceback", "text": r.c.secrets.scrub(traceback.format_exc()[-1500:])})
        if not hasattr(r, "results"):
            r.results = []
    finally:
        r.c.close()
    report = r.report()
    report["host_logs"] = str(r.c.run_dir.relative_to(h.SAVIA).as_posix())
    write_evidence(evidence, name, report, r.c)
    say(f"   {r.verdict} in {report['seconds_total']}s  {r.reason[:600]}")
    return r.verdict, report


def probe_identity(evidence):
    """Start all four hosts as a login that is only in savia_api_host (granted by the migrator), as stores will."""
    say("== probe: restricted identity (savia_api_host only)")
    c = h.Cluster(run_dir("probe-identity"), "restricted", say)
    t0, result = time.time(), {}
    try:
        c.setup()
        result["roles_of_login"] = c.restricted_roles
        result["grant_log"] = c.grant_log
        c.start_all()
        result["hosts_ready"] = True
        status, body = h.call(c.hosts["a"].base, "POST", "/api/v1/cash/tills",
                              {"tillId": "D0000000-0000-4000-8000-0000000000A1", "registerId": c.ids["registerA"],
                               "currencyCode": "NIO", "openingMinor": 100000,
                               "lines": [{"denominationMinor": 50000, "quantity": 2}]}, c.token("a"))
        result["http_login_and_open_till"] = status
        ok, secs, diff = c.converge(timeout=60)
        result["converged"], result["seconds"], result["differing_tables"] = ok, secs, diff
    except BaseException as e:  # noqa: BLE001
        result["converged"] = False
        result["error"] = c.secrets.scrub(f"{type(e).__name__}: {e}")[-1200:]
    if not result.get("converged") and getattr(c, "sql", None) is not None:
        try:  # the API maps SQL errors to a generic db.error; this reads the exact one
            result["sql_repro_as_restricted_user"] = c.sql.as_user_repro(h.APP_LOGIN)
        except Exception as e:  # noqa: BLE001
            result["sql_repro_as_restricted_user"] = c.secrets.scrub(f"{type(e).__name__}: {e}")[-600:]
    c.close()
    errors = {}
    for n in h.NODES:
        if n in c.hosts:
            errors["hub" if n == "cloud" else n] = c.log_excerpt(n, r"denied|permission|SqlException|Sync round (refused|failed)|fail:", 5)
    result["log_errors"] = errors
    result["verdict"] = "restricted works" if result.get("converged") else "restricted FAILS; scenarios run as sa"
    result["seconds_total"] = round(time.time() - t0, 1)
    write_evidence(evidence, "identity_probe", result, c)
    say(f"   {result['verdict']}")
    return "restricted" if result.get("converged") else "sa"


def cmd_run(args):
    names = ORDER if args.scenario == "all" else [args.scenario]
    for n in names:
        if n not in sc.SCENARIOS:
            raise SystemExit(f"unknown scenario {n}; choose from {', '.join(ORDER)}")
    evidence = None if args.no_evidence else Path(args.evidence or EVIDENCE)
    h.container_up(say)
    identity = args.identity
    if identity == "auto":
        identity = probe_identity(evidence)
    summary = {}
    for n in names:
        manifest = Path(args.manifest) if args.manifest else sc.EXPECTED / f"{n}.json"
        verdict, report = run_one(n, manifest, identity, evidence)
        summary[n] = {"verdict": verdict, "seconds": report["seconds_total"], "reason": report["reason"][:400],
                      "checks_passed": report["checks"]["passed"], "checks_failed": report["checks"]["failed"]}
    h.drop_databases()
    if evidence is not None and len(names) > 1:
        (evidence / "summary.json").write_text(json.dumps({"identity": identity, "scenarios": summary}, indent=1) + "\n",
                                               encoding="utf-8")
    say("SUMMARY " + " ".join(f"{n}={v['verdict']}" for n, v in summary.items()))
    return 0 if all(v["verdict"] in GOOD for v in summary.values()) else 1


def cmd_selftest(args):
    """The harness must fail when an expected sale never happens. Inject one into a copy of a manifest."""
    src = sc.EXPECTED / "offline_sales.json"
    m, _ = checks.load(src)
    m["sales"].append({"key": "selftest_missing", "store": "b", "saleId": "5E1F7E57-0000-4000-8000-00000000BAD1",
                       "qty": 1, "tenders": [{"kind": "cash", "amount": 120000}]})
    m["store_totals"]["b"] = {"count": 3, "totalMinor": 480000}
    injected = h.OUT / "selftest-offline_sales.json"
    injected.parent.mkdir(parents=True, exist_ok=True)
    injected.write_text(json.dumps(m, indent=1), encoding="utf-8")
    evidence = None if args.no_evidence else Path(args.evidence or EVIDENCE)
    h.container_up(say)
    verdict, report = run_one("offline_sales", injected, args.identity if args.identity != "auto" else "sa", None)
    fails = [f["check"] for f in report["checks"]["failures"]]
    caught = (verdict == "FAIL" and any("sale selftest_missing present" in f for f in fails)
              and all("selftest_missing" in f or "store b totals" in f for f in fails))
    result = {"selftest": "missing expected sale must fail the run", "injected": m["sales"][-1],
              "run_verdict": verdict, "failed_checks": fails, "harness_caught_it": caught,
              "seconds_total": report["seconds_total"]}
    if evidence is not None:
        evidence.mkdir(parents=True, exist_ok=True)
        (evidence / "selftest_missing_sale.json").write_text(json.dumps(result, indent=1) + "\n", encoding="utf-8")
    h.drop_databases()
    say(f"SELFTEST {'PASS' if caught else 'FAIL'}: run verdict {verdict}; failed checks {len(fails)}")
    return 0 if caught else 1


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("up")
    sub.add_parser("down")
    for name in ("run", "selftest", "probe-identity"):
        s = sub.add_parser(name)
        if name == "run":
            s.add_argument("scenario", nargs="?", default="all")
            s.add_argument("--manifest")
        s.add_argument("--identity", choices=("auto", "sa", "restricted"), default="auto")
        s.add_argument("--evidence")
        s.add_argument("--no-evidence", action="store_true")
    args = p.parse_args()
    if args.cmd == "up":
        h.container_up(say)
        return 0
    if args.cmd == "down":
        for step in h.container_down():
            say(" ".join(str(x) for x in step))
        say(subprocess.run(["docker", "ps", "-a", "--format", "{{.Names}} {{.Status}} {{.Ports}}"],
                           capture_output=True, text=True).stdout)
        return 0
    if not h.API_DLL.exists():
        raise SystemExit(f"missing {h.API_DLL}; build it first (see --help)")
    if args.cmd == "probe-identity":
        h.container_up(say)
        probe_identity(None if args.no_evidence else Path(args.evidence or EVIDENCE))
        return 0
    return cmd_run(args) if args.cmd == "run" else cmd_selftest(args)


if __name__ == "__main__":
    sys.exit(main())
