from pathlib import Path
import subprocess, json, hashlib
root = Path(__file__).resolve().parent
repo = next(p for p in root.parents if (p / "savia/deploy/migrator/Program.cs").exists())
helper = repo / "savia/deploy/migrator/MigrationExecution.cs"
original = helper.read_bytes()
sdk = "C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/dotnet.exe"
text = original.decode()
controls = [
    ("missing-rollback", text.replace("try { await transaction.RollbackAsync(); }", "try { await Task.CompletedTask; }"), 1),
    ("missing-state-validation", text.replace("            await Validate(connection, transaction);", ""), 1),
    ("ledger-outside-transaction", text.replace("await Register(connection, transaction, migration);", "await Register(connection, null, migration);"), 1),
    ("final", text, 0),
]
results = []
try:
    for name, source, expected in controls:
        helper.write_bytes(source.encode())
        command = [sdk, "test", "savia/tests/Savia.Tests", "--no-restore", "--filter", "FullyQualifiedName~MigratorExecutionTests", "--logger", f"trx;LogFileName={name}.trx", "--results-directory", str(root), "-v", "q"]
        with (root / f"{name}.log").open("w") as log:
            result = subprocess.run(command, cwd=repo, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        results.append(dict(name=name, command=command, exit=result.returncode, expected_exit=expected))
        print(name, result.returncode, flush=True)
        if result.returncode != expected:
            raise SystemExit("Unexpected result; controls stopped without retry")
finally:
    helper.write_bytes(original)
    (root / "controls.json").write_text(json.dumps(dict(results=results, restored_sha256=hashlib.sha256(helper.read_bytes()).hexdigest(), restoration_exact=helper.read_bytes()==original), indent=2))
