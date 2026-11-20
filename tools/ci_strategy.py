#!/usr/bin/env python3
"""Conservative, dependency-free planning for a four-gate CI strategy.

This tool does not merge, deploy, publish issues, run paid agents or call APIs.
It only classifies changed paths and verifies supplied release evidence.
"""
from __future__ import annotations

import argparse
import ast
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

SHA = re.compile(r"^[a-fA-F0-9]{40}$")
CRITICAL = re.compile(
    r"(?:auth|permission|role|security|csrf|token|secret|payment|refund|"
    r"checkout|order|reservation|stock|inventory|sync|migration|migrat|"
    r"cash|credit|transaction|webhook|deploy|release|infra|workflow|"
    r"docker|database|schema|audit|ledger|owner|rollback)", re.I,
)
GATE3_CHECKS = (
    "build-and-guards",
    "Portable checks (ubuntu-latest)",
    "Portable checks (windows-latest)",
    "Complete backend suite on disposable SQL Server",
    "Real API + disposable SQL golden path",
)
ALLOWED_AREAS = ("storefront", "savia-web", "savia-core", "backend", "platform", "docs")


EXECUTABLE = {".py", ".js", ".cjs", ".mjs", ".sh", ".ps1", ".sql", ".ts", ".tsx", ".cs"}
RELEASE_BLOCKER = "unverified_external_provenance: receipt, checks, artifact and sign-offs are self-asserted"
REPO = "Suazo-AI/Martha-Silva-Store"


def valid_path(path: str) -> bool:
    """Reject control characters, traversal, hidden path confusion and absolute paths."""
    if not isinstance(path, str) or not path or len(path) > 4096:
        return False
    if "\\" in path or any(ord(c) < 32 or ord(c) == 127 for c in path):
        return False
    if any(c in path for c in ("\u202a", "\u202b", "\u202c", "\u202d", "\u202e",
                                "\u2066", "\u2067", "\u2068", "\u2069")):
        return False
    parsed = PurePosixPath(path)
    return not parsed.is_absolute() and all(part not in ("", ".", "..") for part in path.split("/"))


def classify(paths: list[str]) -> dict:
    """Conservative mapping: unknown and cross-cutting changes cannot be fast-only.

    This is a planning tool, not permission to skip existing required checks.
    """
    if not isinstance(paths, list) or not paths or len(paths) > 10000:
        raise ValueError("Invalid or empty change list; refuse fast-only selection")
    if any(not valid_path(p) for p in paths):
        raise ValueError("Unsafe path in git diff")
    unique = sorted(set(paths))
    if len({p.casefold() for p in unique}) != len(unique):
        raise ValueError("Case-insensitive path collision")
    areas: set[str] = set()
    critical: list[str] = []
    unknown: list[str] = []
    docs_code: list[str] = []
    for p in unique:
        ext = PurePosixPath(p).suffix.lower()
        risk = False
        if p.startswith(("savia/db/", "savia/src/", "savia/infra/", "savia/deploy/", "savia/tools/db/")):
            area, risk = "savia-core", True
        elif p.startswith(("savia/web/", "savia/demo/", "savia/tests/", "savia/tools/")):
            area = "savia-web"
            risk = (p.startswith(("savia/demo/", "savia/tools/")) or ext == ".cs")
            # Production JS or API behavior can implement payments even without keywords.
            if p.startswith("savia/web/") and "/tests/" not in p:
                risk = True
        elif p.startswith(("savia/docs/",)):
            area = "savia-docs"
            if ext in EXECUTABLE:
                docs_code.append(p)
        elif p.startswith(("backend/", "contracts/")):
            area, risk = "backend", True
        elif p.startswith((".github/", ".githooks/", "tools/", "skills/")) or p in (
            "AGENTS.md", "global.json", "package.json", "package-lock.json", "wrangler.jsonc",
        ):
            area = "platform"
            risk = not p.startswith(("skills/ci-strategy/files/", "skills/ci-strategy/notes.md"))
        elif p.startswith(("tests/golden-path/", "tests/browser-cash-", "tests/browser-supply-",
                           "tests/browser-mock-", "dev/savia-staff-ui/")):
            area = "savia-web"
            risk = True
        elif p.startswith(("src/", "dist/", "build-inputs/", "assets/", "tests/")) or p == "prepare.py":
            if p.startswith("tests/test_ci_strategy.py"):
                area, risk = "platform", True
            else:
                area = "storefront"
                risk = p.startswith(("src/", "dist/", "build-inputs/")) and ext in (
                    ".js", ".cjs", ".mjs", ".html"
                )
        elif p.startswith(("docs/", "research/", "evidence/")) or p == "README.md":
            area = "docs"
            if ext in EXECUTABLE:
                docs_code.append(p)
        else:
            area, risk = "platform", True
            unknown.append(p)

        if CRITICAL.search(p):
            risk = True
        areas.add(area)
        if risk:
            critical.append(p)
    # Cross-cutting changes and unknown paths exercise both fixed fast-test families.
    # Unknown paths always exercise both fixed suites rather than a silent skip.
    cross = bool(unknown) or any(
        p.startswith((".github/", ".githooks/", "tools/")) or p in (
            "AGENTS.md", "global.json", "package.json", "package-lock.json", "wrangler.jsonc"
        ) for p in unique
    )
    storefront = "storefront" in areas or "backend" in areas or cross
    savia = bool(areas & {"savia-web", "savia-core"}) or cross
    return {
        "schema": 2,
        "risk": "critical" if critical else ("normal" if areas - {"docs", "savia-docs"} else "docs"),
        "areas": sorted(areas),
        "changed_paths": unique,
        "critical_paths": sorted(set(critical)),
        "unmapped_paths": sorted(set(unknown)),
        "executable_documentation": sorted(set(docs_code)),
        "run_storefront": storefront,
        "run_savia": savia,
        "requires_full": bool(critical),
        "pr_budget_seconds": 300,
        "advisory_only": True,
        "release_allowed": False,
        "reason": "Selected tests do not certify full integration or release readiness",
    }


def changed_paths(base: str, head: str) -> list[str]:
    """Read byte-safe Git diff status; include both sides of every rename/copy."""
    if not (isinstance(base, str) and isinstance(head, str) and
            SHA.fullmatch(base) and SHA.fullmatch(head) and base != head):
        raise ValueError("Base/head must be distinct full commit SHA values")
    process = subprocess.run(
        ["git", "diff", "--name-status", "-z", "--find-renames", base, head],
        check=True, capture_output=True,
    )
    parts = [part.decode("utf-8", "strict") for part in process.stdout.split(b"\0") if part]
    paths: list[str] = []
    i = 0
    while i < len(parts):
        status = parts[i]
        i += 1
        count = 2 if status.startswith(("R", "C")) else 1
        if status[0] not in "ACDMRTU" or i + count > len(parts):
            raise ValueError(f"Invalid git status record: {status!r}")
        paths.extend(parts[i:i + count])
        i += count
    if not paths:
        raise ValueError("Git diff is empty: do not silently skip every test")
    return sorted(set(paths))


def evaluate_release(receipt: dict) -> tuple[bool, list[str]]:
    """A supplied JSON document is NOT external evidence; NEVER approve a release."""
    if not isinstance(receipt, dict):
        return False, ["release receipt must be a JSON object", RELEASE_BLOCKER]
    issues: list[str] = []
    sha = receipt.get("commit_sha")
    if not isinstance(sha, str) or not SHA.fullmatch(sha):
        issues.append("invalid commit_sha")
    if receipt.get("branch") != "main":
        issues.append("release source must be main")
    if receipt.get("artifact_sha") != sha:
        issues.append("artifact SHA does not match commit")
    checks = receipt.get("checks")
    if not isinstance(checks, list):
        issues.append("checks must be a list")
        checks = []
    for required in GATE3_CHECKS:
        matches = [c for c in checks if isinstance(c, dict) and c.get("name") == required]
        if (len(matches) != 1 or matches[0].get("status") != "completed"
                or matches[0].get("conclusion") != "success"
                or matches[0].get("head_sha") != sha):
            issues.append(f"required green check missing or stale: {required}")
    for field, message in (
        ("review_approved", "human approval missing"),
        ("rollback_drilled", "rollback drill missing"),
        ("commercial_acceptance", "business acceptance missing"),
        ("telemetry_ready", "telemetry not ready"),
        ("sql_real_verified", "real SQL proof missing"),
        ("payment_sandbox_verified", "payment sandbox proof missing"),
    ):
        if receipt.get(field) is not True:
            issues.append(message)
    issues.append(RELEASE_BLOCKER)
    return False, issues


def evaluate_gate2(g1: str, expected_storefront: str, expected_savia: str,
                   actual_storefront: str, actual_savia: str) -> list[str]:
    """A required check cannot be reported as green when it was actually skipped."""
    issues = []
    if g1 != "success":
        issues.append("G1 was not successful")
    for name, required, actual in (
        ("storefront", expected_storefront, actual_storefront),
        ("savia", expected_savia, actual_savia),
    ):
        if required not in ("true", "false"):
            issues.append(f"missing or invalid selection for {name}")
        elif required == "true" and actual != "success":
            issues.append(f"required {name} check is {actual}, not success")
        elif required == "false" and actual != "skipped":
            issues.append(f"unselected {name} job unexpectedly {actual}")
    return issues


def audit_remote_main(sha: str, get_json) -> dict:
    """Read-only provenance audit of public GitHub API data; no artifacts or approvals."""
    if not isinstance(sha, str) or not SHA.fullmatch(sha):
        raise ValueError("main SHA must be 40 hex characters")
    ref = get_json("/git/ref/heads/main")
    observed = ref.get("object", {}).get("sha")
    errors = [] if observed == sha else ["main ref does not match requested SHA"]
    payload = get_json("/commits/" + sha + "/check-runs?per_page=100")
    runs = payload.get("check_runs", [])
    if not isinstance(runs, list) or payload.get("total_count", 101) > 100:
        errors.append("check runs missing or truncated; inspect pagination manually")
        runs = [] if not isinstance(runs, list) else runs[:100]
    for name in GATE3_CHECKS:
        matching = [r for r in runs if isinstance(r, dict) and r.get("name") == name]
        if (len(matching) != 1
                or matching[0].get("head_sha") != sha
                or matching[0].get("status") != "completed"
                or matching[0].get("conclusion") != "success"
                or (matching[0].get("app") or {}).get("slug") != "github-actions"):
            errors.append("unverified or missing main check: " + name)
    return {
        "commit_sha": sha,
        "main_ref_matches": observed == sha,
        "checks_verified": not errors,
        "release_allowed": False,
        "artifacts_verified": False,
        "external_business_approvals_verified": False,
        "errors": errors,
        "note": "GitHub API check metadata is insufficient for a release or artifact attestation",
    }


def remote_get(path: str) -> dict:
    """Hardcoded GitHub API origin. Optional token is never printed or persisted."""
    import urllib.request
    endpoint = "https://api.github.com/repos/" + REPO + path
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "Martha-CI-Strategy-ReadOnly",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    token = os.environ.get("GH_TOKEN")
    if token:
        headers["Authorization"] = "Bearer " + token
    request = urllib.request.Request(endpoint, headers=headers, method="GET")
    with urllib.request.urlopen(request, timeout=15) as response:
        if response.status != 200 or response.headers.get("Content-Length", "0").isdigit() and int(response.headers.get("Content-Length", "0")) > 2000000:
            raise ValueError("GitHub API returned unsafe status or oversized payload")
        return json.loads(response.read(2000001).decode("utf-8"))


def static_checks(root: Path, paths: list[str]) -> list[str]:
    """Syntax-only G1 check. No imported/executed app code and no symlink escape."""
    errors: list[str] = []
    code_paths = [p for p in paths if PurePosixPath(p).suffix in (".py", ".js", ".cjs", ".mjs", ".json")]
    if len(code_paths) > 500:
        return ["More than 500 syntax paths: explicit review required"]
    resolved_root = root.resolve(strict=True)
    for name in code_paths:
        if not valid_path(name):
            errors.append(f"Unsafe path: {name!r}")
            continue
        target = root.joinpath(*name.split("/"))
        if any(part.is_symlink() for part in (root.joinpath(*name.split("/")[:i])
                                               for i in range(1, len(name.split("/")) + 1))):
            errors.append(f"Refusing symlink path: {name}")
            continue
        if not target.exists():  # deleted files are still included in impact risk
            continue
        if not target.resolve().is_relative_to(resolved_root):
            errors.append(f"Path escapes checkout: {name}")
            continue
        if not target.is_file() or target.stat().st_size > 2_000_000:
            errors.append(f"Non-file or oversized input: {name}")
            continue
        try:
            if target.suffix == ".py":
                ast.parse(target.read_text(encoding="utf-8"), filename=name)
            elif target.suffix == ".json":
                json.loads(target.read_text(encoding="utf-8"))
            else:
                completed = subprocess.run(
                    ["node", "--check", str(target)],
                    capture_output=True, text=True, timeout=20,
                )
                if completed.returncode != 0:
                    errors.append(f"JavaScript syntax failed: {name}")
        except (SyntaxError, UnicodeError, OSError, ValueError, subprocess.TimeoutExpired):
            errors.append(f"Syntax or file error: {name}")
    return errors


def do_static(args: argparse.Namespace) -> int:
    paths = changed_paths(args.base, args.head)
    issues = static_checks(Path.cwd(), paths)
    print(json.dumps({"checked_paths": len(paths), "syntax_issues": issues}))
    return 2 if issues else 0


def do_plan(args: argparse.Namespace) -> int:
    if args.files_json:
        paths = json.loads(Path(args.files_json).read_text(encoding="utf-8"))
        if not isinstance(paths, list) or not all(isinstance(p, str) for p in paths):
            raise ValueError("--files-json must contain an array of paths")
    else:
        paths = changed_paths(args.base, args.head)
    result = classify(paths)
    if args.base and args.head:
        result["base_sha"], result["head_sha"] = args.base, args.head
    print(json.dumps(result, indent=2, sort_keys=True))
    if args.output:
        with Path(args.output).open("a", encoding="utf-8") as f:
            for k in ("run_storefront", "run_savia", "requires_full"):
                f.write(f"{k}={str(result[k]).lower()}\n")
            f.write("risk=" + result["risk"] + "\n")
    return 0


def do_release(args: argparse.Namespace) -> int:
    receipt = json.loads(Path(args.receipt).read_text(encoding="utf-8"))
    if not isinstance(receipt, dict):
        raise ValueError("Receipt must be a JSON object")
    ok, issues = evaluate_release(receipt)
    print(json.dumps({"policy_consistent": len(issues) == 1 and issues[0] == RELEASE_BLOCKER,
                      "release_authorized": False, "issues": issues}, indent=2))
    # Always deny self-attested receipts; audit-main can verify GitHub checks only.
    return 2


def do_gate2(args: argparse.Namespace) -> int:
    issues = evaluate_gate2(args.g1, args.storefront_selected, args.savia_selected,
                            args.storefront_result, args.savia_result)
    print(json.dumps({"selected_tests_passed": not issues, "issues": issues}))
    return 2 if issues else 0


def do_audit_main(args: argparse.Namespace) -> int:
    result = audit_remote_main(args.sha, remote_get)
    print(json.dumps(result, indent=2))
    return 0 if result["checks_verified"] else 2


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    plan = sub.add_parser("plan", help="Select fast checks and require critical safety gates")
    plan.add_argument("--base")
    plan.add_argument("--head")
    plan.add_argument("--files-json")
    plan.add_argument("--output", help="GITHUB_OUTPUT path; appends fixed safe keys")
    plan.set_defaults(fn=do_plan)
    static = sub.add_parser("static", help="Syntax-only checks for changed Python, JS and JSON")
    static.add_argument("--base", required=True)
    static.add_argument("--head", required=True)
    static.set_defaults(fn=do_static)
    release = sub.add_parser("release-check", help="Offline, read-only receipt verifier")
    release.add_argument("--receipt", required=True)
    release.set_defaults(fn=do_release)
    gate2 = sub.add_parser("gate2-check", help="Fail if any selected G2 job is skipped")
    gate2.add_argument("--g1", required=True)
    gate2.add_argument("--storefront-selected", required=True)
    gate2.add_argument("--savia-selected", required=True)
    gate2.add_argument("--storefront-result", required=True)
    gate2.add_argument("--savia-result", required=True)
    gate2.set_defaults(fn=do_gate2)
    audit = sub.add_parser("audit-main", help="Read GitHub check runs; NEVER approve deploy")
    audit.add_argument("--sha", required=True)
    audit.set_defaults(fn=do_audit_main)
    args = parser.parse_args(argv)
    try:
        if args.command == "plan" and not args.files_json and not (args.base and args.head):
            raise ValueError("Supply --files-json or both --base and --head")
        return args.fn(args)
    except (ValueError, UnicodeError, OSError, subprocess.CalledProcessError, json.JSONDecodeError) as exc:
        print(f"CI_STRATEGY_FAIL_CLOSED: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
