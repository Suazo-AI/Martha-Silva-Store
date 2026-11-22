#!/usr/bin/env python3
"""One command that runs every SAVIA v2 check and says what failed.

  python savia/tools/check.py            # everything
  python savia/tools/check.py --isolated # preserve a pilot owned by another checkout
  python savia/tools/check.py --quick    # skip the .NET build and tests and the container proof

Needs the dev database container (python savia/tools/db/saviadb.py up).
Needs the .NET SDK pinned in global.json. Set SAVIA_DOTNET to its dotnet executable
when the one on PATH is another version.
The container proof (savia/deploy/local_proof.py --build) runs when Docker and the dev container are up.
"""
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEV_CONTAINER = "savia-sqlserver-dev"
# Sync and vertical-slice tests again, connected as a login that is only in role savia_api_host (V035).
API_HOST_TESTS = ("FullyQualifiedName~Savia.Tests.Sync|FullyQualifiedName~Savia.Tests.VerticalSlice"
                  "|FullyQualifiedName~Savia.Tests.ApiHostLogin")
# Known location of SDK 10.0.402 on SUAZO-PC; other machines use PATH or SAVIA_DOTNET.
LOCAL_SDK = Path("C:/Users/Jason/.dotnet-sdk-10.0.402/dotnet.exe")


def dotnet():
    for candidate in (os.environ.get("SAVIA_DOTNET"), str(LOCAL_SDK) if LOCAL_SDK.exists() else None, shutil.which("dotnet")):
        if candidate:
            return candidate
    return None


def run(name, command, read_next, env=None):
    start = time.time()
    proc = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          env=dict(os.environ, **env) if env else None)
    seconds = time.time() - start
    text = proc.stdout.decode("utf-8", errors="replace").strip().splitlines()
    verdict = "PASS" if proc.returncode == 0 else "FAIL"
    print(f"{verdict:<5} {name}  ({seconds:.0f}s)" + ("" if proc.returncode == 0 else f"  -> read {read_next}"))
    if proc.returncode != 0:
        # Every FAIL line first (a long step can push it out of the tail), then the tail.
        failed = [line for line in text[:-12] if line.lstrip().startswith("FAIL")]
        print("      " + "\n      ".join(failed + text[-12:]))
    elif text:
        print("      " + text[-1][:200])
    return proc.returncode == 0


def dev_container_up():
    if shutil.which("docker") is None:
        return False
    proc = subprocess.run(["docker", "inspect", "-f", "{{.State.Running}}", DEV_CONTAINER],
                          stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return proc.returncode == 0 and proc.stdout.strip() == b"true"


def main():
    quick = "--quick" in sys.argv
    env = dict(os.environ, DOTNET_CLI_TELEMETRY_OPTOUT="1", DOTNET_NOLOGO="1", MSBUILDDISABLENODEREUSE="1")
    os.environ.update(env)
    py = sys.executable
    if "--isolated" in sys.argv:
        print("SKIP  pilot stop (--isolated: throwaway databases only)")
        ok = True
    else:
        ok = run("pilot stopped before checks", [py, "tools/pilot.py", "down"], "savia/tools/pilot.py")
    ok &= run("architecture rules", [py, "tools/rules.py"], "the file:line and the fix named in each message")
    ok &= run("baseline is generated from the handoff", [py, "tools/db/build_baseline.py", "--check"], "savia/tools/db/build_baseline.py")
    ok &= run("no DELETE or TRUNCATE on synced tables", [py, "tools/db/no_physical_delete.py"], "savia/tools/db/no_physical_delete.py")
    ok &= run("database container", [py, "tools/db/saviadb.py", "status"], "savia/README.md (Empezar)")
    ok &= run("T-SQL tests", [py, "tools/db/saviadb.py", "test", "--jobs", "4"], "savia/db/tests/README.md and savia/.out/dbtests/")
    if quick:
        print("SKIP  .NET build and tests (--quick)")
    elif dotnet() is None:
        print("FAIL  .NET SDK not found  -> set SAVIA_DOTNET (see global.json for the version)")
        ok = False
    else:
        ok &= run(".NET build", [dotnet(), "build", "Savia.slnx", "--no-restore", "-v", "q"], "the first error line above")
        ok &= run("C# format", [dotnet(), "format", "Savia.slnx", "--verify-no-changes", "--no-restore"],
                  "run: dotnet format Savia.slnx (savia/.editorconfig)")
        ok &= run(".NET tests on real SQL", [dotnet(), "test", "tests/Savia.Tests", "--no-build", "-v", "q"], "savia/tests/Savia.Tests/")
        ok &= run(".NET sync tests as the API host login",
                  [dotnet(), "test", "tests/Savia.Tests", "--no-build", "-v", "q", "--filter", API_HOST_TESTS],
                  "savia/tests/Savia.Tests/ApiHostLogin.cs and grants in savia/db/migrations/V035__api_host_role.sql",
                  env={"SAVIA_TEST_SQL_LOGIN": "api_host"})
    # Fixed database names, logins and port 5090: not for a run that must touch throwaway databases only.
    if quick or "--isolated" in sys.argv:
        print("SKIP  container proof (--quick or --isolated)")
    elif not dev_container_up():
        print(f"SKIP  container proof (Docker or {DEV_CONTAINER} not running)")
    else:
        ok &= run("container proof: images, migrator, API", [py, "deploy/local_proof.py", "--build"], "savia/deploy/local_proof.py")
    print("RESULT " + ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
