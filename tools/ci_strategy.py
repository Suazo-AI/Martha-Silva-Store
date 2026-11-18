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


def valid_path(path: str) -> bool:
    """Only safe repository-relative paths; never shell-interpolate file names."""
    if not path or len(path) > 4096 or "\\" in path or "\x00" in path:
        return False
    if any(ord(c) < 32 for c in path):
        return False
    parsed = PurePosixPath(path)
    return not parsed.is_absolute() and all(part not in (".", "..", "") for part in path.split("/"))


def classify(paths: list[str]) -> dict:
    if not paths:
        raise ValueError("No changed paths: refuse empty PR test selection")
    if len(paths) > 10000:
        raise ValueError("Too many changed paths")
    if any(not valid_path(p) for p in paths):
        raise ValueError("Unsafe path in git diff")
    areas: set[str] = set()
    critical: list[str] = []
    unknown: list[str] = []
    for p in sorted(set(paths)):
        if p.startswith(("savia/db/", "savia/src/", "savia/infra/", "savia/tools/db/")):
            area = "savia-core"
        elif p.startswith(("savia/web/", "savia/tests/", "savia/tools/")):
            area = "savia-web"
        elif p.startswith(("backend/", "contracts/")):
            area = "backend"
        elif p.startswith((".github/", ".githooks/", "tools/", "skills/")) or p in ("AGENTS.md", "global.json", "package.json", "package-lock.json", "wrangler.jsonc"):
            area = "platform"
        elif p.startswith(("src/", "dist/", "build-inputs/", "assets/", "tests/")) or p in ("prepare.py", "README.md"):
            area = "storefront"
        elif p.startswith(("docs/", "research/", "evidence/")):
            area = "docs"
        else:
            area = "platform"
            unknown.append(p)
        areas.add(area)
        if area in ("savia-core", "backend") or CRITICAL.search(p) or (area == "platform" and not p.startswith("skills/ci-strategy/")):
            critical.append(p)

    risk = "critical" if critical or unknown else ("normal" if areas - {"docs"} else "docs")
    storefront = "storefront" in areas
    savia = bool(areas & {"savia-web", "savia-core"})
    return {
        "schema": 1,
        "risk": risk,
        "areas": sorted(areas),
        "changed_paths": sorted(set(paths)),
        "critical_paths": sorted(set(critical)),
        "unmapped_paths": sorted(set(unknown)),
        "run_storefront": storefront,
        "run_savia": savia,
        "requires_full": risk == "critical",
        "pr_budget_seconds": 300,
        "advisory_only": True,
        "release_allowed": False,
        "reason": "All release and agent execution gates require separate evidence and approval",
    }


def changed_paths(base: str, head: str) -> list[str]:
    if not (SHA.fullmatch(base) and SHA.fullmatch(head)):
        raise ValueError("Base and head must be full commit SHA values")
    process = subprocess.run(
        ["git", "diff", "--name-only", "-z", "--find-renames", base, head],
        check=True, capture_output=True,
    )
    return [v.decode("utf-8", "strict") for v in process.stdout.split(b"\0") if v]


def evaluate_release(receipt: dict) -> tuple[bool, list[str]]:
    """Fail closed: evidence cannot be inferred from a successful PR check."""
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
        if len(matches) != 1 or matches[0].get("status") != "completed" or matches[0].get("conclusion") != "success" or matches[0].get("head_sha") != sha:
            issues.append(f"required green check missing or stale: {required}")
    if receipt.get("review_approved") is not True:
        issues.append("human approval missing")
    if receipt.get("rollback_drilled") is not True:
        issues.append("rollback drill missing")
    if receipt.get("commercial_acceptance") is not True:
        issues.append("business acceptance missing")
    if receipt.get("telemetry_ready") is not True:
        issues.append("telemetry not ready")
    if receipt.get("sql_real_verified") is not True:
        issues.append("real SQL proof missing")
    if receipt.get("payment_sandbox_verified") is not True:
        issues.append("payment sandbox proof missing")
    return not issues, issues


def static_checks(root: Path, paths: list[str]) -> list[str]:
    """Syntax-only, dependency-free G1 check; no imported or executed application code."""
    errors: list[str] = []
    code_paths = [p for p in paths if Path(p).suffix in (".py", ".js", ".cjs", ".mjs", ".json")]
    if len(code_paths) > 500:
        return ["More than 500 syntax paths: explicit review required"]
    for name in code_paths:
        if not valid_path(name):
            errors.append(f"Unsafe path: {name!r}")
            continue
        target = root / name
        if target.is_symlink():
            errors.append(f"Refusing symlink: {name}")
            continue
        if not target.exists():  # deletion is covered by impact classification
            continue
        if not target.is_file() or target.stat().st_size > 2_000_000:
            errors.append(f"Non-file or oversized input: {name}")
            continue
        try:
            if target.suffix == '.py':
                ast.parse(target.read_text(encoding='utf-8'), filename=name)
            elif target.suffix == '.json':
                json.loads(target.read_text(encoding='utf-8'))
            else:
                completed = subprocess.run(['node', '--check', str(target)],
                                           capture_output=True, text=True, timeout=20)
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
    print(json.dumps({"eligible_for_manual_review": ok, "issues": issues}, indent=2))
    # Not a deployment command. No file or service is mutated.
    return 0 if ok else 2


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
