#!/usr/bin/env python3
"""One command that proves a change: every check, in order, with the evidence kept.

  python savia/tools/verify.py            # everything (about 25 minutes)
  python savia/tools/verify.py --quick    # rules, tool tests and web tests only (seconds)

Evidence goes to savia/.out/verify/<UTC time>/: one log per step and summary.json (commit, exit codes, seconds).
A step that cannot run here (no agent-browser, no local OCR) is SKIP with the reason, never a silent pass.
The pilot database SAVIA_DEV_pilot is dropped and rebuilt with invented demo history. The API is left stopped.
Missing SAVIA_PILOT_PASSWORD_* values are replaced by random ones for this run only; nothing is printed or stored.
"""
import json
import os
import secrets
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PY = sys.executable
LOGINS = ("DUENA", "GERENTE", "VENDEDOR1", "VENDEDOR2", "BODEGA")


def steps(quick):
    yield "rules", [PY, "tools/rules.py"], None
    yield "tool-tests", [PY, "-m", "unittest", "discover", "-s", "tests", "-p", "test_*.py"], None
    biome = ROOT / "node_modules" / "@biomejs" / "biome" / "bin" / "biome"
    yield "web-format-lint", ["node", str(biome), "check", "web"], None if biome.exists() else "Biome is not installed (npm ci in savia/)"
    yield "web-tests", ["node", "--test", "web/tests/*.test.mjs", "web/scanner/*.test.mjs"], None
    formal = ROOT / ".out" / "tools" / "formal" / "tla2tools.jar"
    yield "formal", [PY, "tools/formal.py", "check"], None if formal.exists() else "TLA+ tools are not installed (tools/formal.py setup)"
    if quick:
        return
    yield "check", [PY, "tools/check.py"], None
    yield "pilot-reset-demo", [PY, "tools/pilot.py", "reset", "--demo"], None
    yield "pilot-up", [PY, "tools/pilot.py", "up"], None
    yield "smoke", [PY, "tools/pilot_smoke.py"], None
    browser = None if shutil.which("agent-browser") else "agent-browser is not installed"
    yield "e2e-1", [PY, "web/tests/e2e_pilot.py"], browser
    yield "e2e-2", [PY, "web/tests/e2e_pilot.py"], browser
    yield "tag-live", [PY, "tools/tag_live.py"], None if (ROOT / ".ocr").is_dir() else "local OCR is not installed (tools/ocr/setup_ocr.py)"


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True).stdout.strip()


def main():
    quick = "--quick" in sys.argv
    out = ROOT / ".out" / "verify" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out.mkdir(parents=True)
    env = dict(os.environ, PYTHONIOENCODING="utf-8")
    for login in LOGINS:
        env.setdefault("SAVIA_PILOT_PASSWORD_" + login, "Aa1!" + secrets.token_urlsafe(18))
    results, blocked = [], False
    try:
        for number, (name, command, skip) in enumerate(steps(quick), 1):
            verdict, seconds, code = "SKIP", 0, None
            if blocked:
                verdict, skip = "BLOCKED", "an earlier step failed"
            elif not skip:
                start = time.time()
                step_env = dict(env, SAVIA_E2E_SHOTS=str(out / f"{number:02d}-{name}-screens"))
                with (out / f"{number:02d}-{name}.log").open("wb") as log:
                    code = subprocess.run(command, cwd=ROOT, env=step_env, stdout=log, stderr=subprocess.STDOUT).returncode
                seconds, verdict = round(time.time() - start), "PASS" if code == 0 else "FAIL"
                blocked = code != 0 and name in ("check", "pilot-reset-demo", "pilot-up")
            results.append({"step": name, "verdict": verdict, "exitCode": code, "seconds": seconds, "reason": skip})
            print(f"{verdict:<7} {name}  ({seconds}s)" + (f"  {skip}" if skip else "")
                  + (f"  -> read {out / f'{number:02d}-{name}.log'}" if verdict == "FAIL" else ""), flush=True)
    finally:
        if not quick:
            subprocess.run([PY, "tools/pilot.py", "down"], cwd=ROOT, env=env, capture_output=True)
    counts = {v: sum(r["verdict"] == v for r in results) for v in ("PASS", "FAIL", "SKIP", "BLOCKED")}
    ok = counts["FAIL"] == 0 and counts["BLOCKED"] == 0
    summary = {"result": "PASS" if ok else "FAIL", "mode": "quick" if quick else "full", "commit": git("rev-parse", "HEAD"),
               "uncommittedFiles": len(git("status", "--porcelain", "--", ".").splitlines()), "counts": counts, "steps": results}
    (out / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    not_run = counts["SKIP"] + counts["BLOCKED"]
    print(f"VERIFY {summary['result']}: {counts['PASS']} passed, {counts['FAIL']} failed, {not_run} not run"
          f"{' (quick mode: no database, API or browser)' if quick else ''}. Evidence: {out}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
