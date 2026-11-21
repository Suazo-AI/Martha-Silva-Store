"""Independent red probes of frozen, rejected input. Never runs the runner.

Only the pure resource_names function and the archive member predicate are
compiled. No imports, top-level code, transport, extraction or cleanup execute.
Exit 1 means the frozen candidate violates the three asserted requirements.
"""
import ast
import hashlib
import json
import sys
import tarfile
from pathlib import Path
from types import SimpleNamespace


def main():
    base = Path(__file__).resolve().parent
    source = base / "runner-inputs/tools/run_local_validation.py.txt"
    raw = source.read_bytes()
    binding = hashlib.sha256(raw.replace(b"\r\n", b"\n")).hexdigest()
    expected = "42bfdb8661a6b7285c2d55155c8afdc222fd4c7e30b03286eccd74ac9430650c"
    if binding != expected:
        print("Frozen rejected source binding changed; no probe executed.")
        return 2
    tree = ast.parse(raw.decode("utf-8"))
    names = next(n for n in tree.body if isinstance(n, ast.FunctionDef)
                 and n.name == "resource_names")
    export = next(n for n in tree.body if isinstance(n, ast.FunctionDef)
                  and n.name == "export_source")
    predicate = next(n.test for n in ast.walk(export) if isinstance(n, ast.If)
                     and ast.unparse(n.test).startswith("member.mode &"))
    namespace = {"__builtins__": {}, "hashlib": hashlib,
                 "Names": SimpleNamespace, "str": str}
    exec(compile(ast.Module(body=[names], type_ignores=[]), str(source), "exec"), namespace)
    first = vars(namespace["resource_names"]("savia-local-runtime-87ff7991967b"))
    second = vars(namespace["resource_names"]("savia-local-runtime-87ff7991967b"))
    checks = [{"id": "F1-fresh-resource-identity", "expected": "distinct run names",
               "actual": "identical run names" if first == second else "distinct run names",
               "passed": first != second}]
    for label, kind, mode in (("regular", tarfile.REGTYPE, 0o644),
                              ("directory", tarfile.DIRTYPE, 0o755)):
        member = tarfile.TarInfo("ordinary.txt" if label == "regular" else "ordinary/")
        member.type, member.mode = kind, mode
        rejected = eval(compile(ast.Expression(predicate), str(source), "eval"),
                        {"__builtins__": {}, "member": member})
        checks.append({"id": "F2-ordinary-" + label, "expected": "accepted",
                       "actual": "rejected" if rejected else "accepted", "passed": not rejected})
    report = {"status": "RED" if any(not c["passed"] for c in checks) else "GREEN",
              "source": source.relative_to(base).as_posix(), "sourceLfSha256": binding,
              "checks": checks, "passed": sum(c["passed"] for c in checks),
              "failed": sum(not c["passed"] for c in checks),
              "limits": "Pure extracted expressions only. No resource deletion, archive extraction, Docker, SQL or runner execution."}
    (base / "primary-red-probes.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": report["status"], "passed": report["passed"],
                      "failed": report["failed"], "report": "primary-red-probes.json"}))
    return 1 if report["failed"] else 0


if __name__ == "__main__":
    sys.exit(main())
