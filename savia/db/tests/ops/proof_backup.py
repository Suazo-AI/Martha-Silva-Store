"""Prueba local aislada; nunca usa SAVIA_DEV_pilot ni la API."""
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
import pilot_backup as backup
from db import saviadb

SOURCE = "SAVIA_DEV_bkpsrc"
CLI = [sys.executable, str(ROOT / "tools" / "pilot_backup.py")]


def command(args, expected=0):
    process = subprocess.run([*CLI, *map(str, args)], capture_output=True, text=True)
    print(process.stdout.strip())
    print(process.stderr.strip())
    print(f"COMMAND pilot_backup.py {args[0]} EXIT {process.returncode}")
    assert (process.returncode == 0) == (expected == 0), "Resultado inesperado"


def main():
    # clone() replaces its target, so prove absence before invoking it.
    assert saviadb.scalar("master", f"SELECT COALESCE(DB_ID(N'{SOURCE}'),0);") == "0", "La base fuente ya existe"
    owned = False
    try:
        owned = True
        backup.checked(saviadb.clone(SOURCE), "clone")
        print(f"CLONE {SOURCE} PASS")
        seed = "DECLARE @sale uniqueidentifier=NEWID(); EXEC test.SeedSale @SaleId=@sale,@Key='A';"
        backup.sql(seed, SOURCE)
        before = backup.counts(SOURCE)
        path = backup.backup(SOURCE)
        backup.sql(seed, SOURCE)
        after = backup.counts(SOURCE)
        assert all(after[key] > before[key] for key in before)
        print(f"SOURCE AT BACKUP {json.dumps(before, sort_keys=True)}")
        print(f"SOURCE AFTER SALE {json.dumps(after, sort_keys=True)}")
        command(["list"])
        command(["verify", path])
        command(["restore-test", path])
        backup.sql(f"CREATE DATABASE [{backup.RESTORE_TEST}];")
        try:
            command(["restore-test", path], expected=1)
            assert saviadb.scalar("master", f"SELECT CASE WHEN DB_ID(N'{backup.RESTORE_TEST}') IS NULL THEN 0 ELSE 1 END;") == "1"
            print("EXISTING restoretest PRESERVED PASS")
        finally:
            backup.checked(saviadb.drop(backup.RESTORE_TEST), "drop reservation fixture")
        corrupt = path.with_name(path.stem + ".corrupt.bak")
        try:
            shutil.copyfile(path, corrupt)
            for suffix in (".json", ".sha256"):
                shutil.copyfile(path.with_suffix(suffix), corrupt.with_suffix(suffix))
            with corrupt.open("r+b") as stream:
                original = stream.read(4096)
                stream.seek(0)
                stream.write(bytes(value ^ 255 for value in original))
            command(["verify", corrupt], expected=1)
            # Also prove SQL VERIFYONLY refuses corruption even with matching hash metadata.
            sha = backup.digest(corrupt)
            data = json.loads(corrupt.with_suffix(".json").read_text(encoding="utf-8"))
            data["sha256"] = sha
            corrupt.with_suffix(".json").write_text(json.dumps(data), encoding="utf-8")
            corrupt.with_suffix(".sha256").write_text(f"{sha}  {corrupt.name}\n", encoding="utf-8")
            command(["verify", corrupt], expected=1)
        finally:
            for candidate in (corrupt, corrupt.with_suffix(".json"), corrupt.with_suffix(".sha256")):
                if candidate.exists():
                    candidate.unlink()
        command(["restore", path, "--db", SOURCE], expected=1)
        command(["restore", path, "--db", "master", "--yes-replace"], expected=1)
        command(["restore", path, "--db", SOURCE, "--yes-replace"])
        assert backup.counts(SOURCE) == before
        print("REAL RESTORE SAFETY BACKUP PASS; source counts MATCH")
        print("PROOF PASS")
    finally:
        if owned:
            backup.checked(saviadb.drop(SOURCE), "drop scratch")
            print(f"DROP {SOURCE} PASS")
        assert saviadb.scalar("master", f"SELECT COALESCE(DB_ID(N'{backup.RESTORE_TEST}'),0);") == "0"


if __name__ == "__main__":
    main()
