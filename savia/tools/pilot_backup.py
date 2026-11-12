#!/usr/bin/env python3
"""Respaldos locales del piloto; no imprime ni lee la contraseña de SQL Server."""
import argparse
import hashlib
import json
import re
import subprocess
import sys
import uuid
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

from db import saviadb

ROOT = Path(__file__).resolve().parents[1]
BACKUPS = ROOT / ".out" / "pilot" / "backups"
REMOTE = f"{saviadb.DATA_DIR}/backups"
TABLES = ("sales.Sales", "inventory.StockMovements", "sales.CashEntries")
RESTORE_TEST = "SAVIA_DEV_restoretest"


def checked(result, step):
    code, output = result
    if code:
        # Do not relay arbitrary Docker/server diagnostics, which can contain secrets.
        raise RuntimeError(f"{step}: exit {code}; revise Docker y SQL Server localmente.")
    return output


def sql(text, db="master", **kwargs):
    return checked(saviadb.run_sql(db, text, **kwargs), "SQL")


def literal(value):
    return "N'" + str(value).replace("'", "''") + "'"


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def backup_folder():
    # Refuse redirects, including Windows junctions, before retention can remove files.
    expected = ROOT.resolve() / ".out" / "pilot" / "backups"
    if BACKUPS.resolve() != expected:
        raise RuntimeError("La carpeta de respaldos no puede redirigirse fuera de su ruta.")
    ignored = subprocess.run(["git", "check-ignore", "--quiet", "--", str(BACKUPS / "probe.bak")],
                             cwd=ROOT.parent, capture_output=True)
    if ignored.returncode:
        raise RuntimeError("git check-ignore no confirma la exclusión de savia/.out/pilot/backups/.")
    BACKUPS.mkdir(parents=True, exist_ok=True)
    return BACKUPS


def counts(db):
    result = {}
    for table in TABLES:
        value = saviadb.scalar(db, f"SELECT COUNT_BIG(*) FROM {table};")
        result[table] = int(value)
    return result


@contextmanager
def uploaded(path):
    remote = f"{REMOTE}/upload-{uuid.uuid4().hex}.bak"
    checked(saviadb.docker(["exec", saviadb.CONTAINER, "mkdir", "-p", REMOTE]), "mkdir")
    try:
        checked(saviadb.docker(["cp", str(path), f"{saviadb.CONTAINER}:{remote}"]), "docker cp")
        checked(saviadb.docker(["exec", "-u", "0", saviadb.CONTAINER, "chmod", "644", remote]), "chmod")
        yield remote
    finally:
        checked(saviadb.docker(["exec", saviadb.CONTAINER, "rm", "-f", remote]), "limpieza de copia temporal")


def verify_sql(remote):
    sql(f"RESTORE VERIFYONLY FROM DISK={literal(remote)} WITH CHECKSUM;")


def restore_sql(remote, db, replace=False):
    saviadb.check_name(db)
    rows = sql(f"RESTORE FILELISTONLY FROM DISK={literal(remote)};", opts='-h -1 -s "|" -W')
    moves = []
    for row in rows.splitlines():
        parts = [part.strip() for part in row.split("|")]
        if len(parts) < 3 or parts[2] not in ("D", "L"):
            continue
        extension = "ldf" if parts[2] == "L" else "mdf"
        target = f"{saviadb.DATA_DIR}/{db}_ops_{len(moves)}.{extension}"
        moves.append(f"MOVE {literal(parts[0])} TO {literal(target)}")
    if not moves:
        raise RuntimeError("El respaldo no contiene archivos de datos reconocidos.")
    options = [*moves, "RECOVERY", "CHECKSUM"]
    if replace:
        options.append("REPLACE")
    sql(f"RESTORE DATABASE [{db}] FROM DISK={literal(remote)} WITH " + ", ".join(options) + ";")


@contextmanager
def restored_new(remote, db):
    saviadb.check_name(db)
    # CREATE reserves ownership. If it fails, never clean up a database owned by another run.
    sql(f"IF DB_ID({literal(db)}) IS NOT NULL THROW 59001, 'La base temporal ya existe.', 1; "
        f"CREATE DATABASE [{db}];")
    try:
        restore_sql(remote, db, replace=True)
        yield db
    finally:
        checked(saviadb.drop(db), "eliminar base temporal")


def prune():
    folder = backup_folder()
    # Only complete backups created by this tool participate; unrelated files remain untouched.
    pattern = re.compile(r"SAVIA_(?:DEV|T|SIM)_[A-Za-z0-9_]+_\d{8}T\d{12}Z_[a-f0-9]{8}\.bak")
    files = sorted((p for p in folder.glob("*.bak") if pattern.fullmatch(p.name)
                    and p.with_suffix(".json").is_file() and p.with_suffix(".sha256").is_file()),
                   key=lambda p: p.name.rsplit("_", 2)[1:], reverse=True)
    for path in files[14:]:
        for candidate in (path, path.with_suffix(".json"), path.with_suffix(".sha256")):
            if candidate.resolve().parent != folder.resolve() or candidate.is_symlink():
                raise RuntimeError("Retención rechazada: archivo fuera de la carpeta autorizada.")
            candidate.unlink()


def backup(db):
    saviadb.check_name(db)
    folder = backup_folder()
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    name = f"{db}_{stamp}_{uuid.uuid4().hex[:8]}.bak"
    remote = f"{REMOTE}/{name}"
    path = folder / name
    checked(saviadb.docker(["exec", saviadb.CONTAINER, "mkdir", "-p", REMOTE]), "mkdir")
    sql(f"BACKUP DATABASE [{db}] TO DISK={literal(remote)} WITH INIT, FORMAT, CHECKSUM;")
    verify_sql(remote)
    # Read the actual backup, never the live database that may already contain later sales.
    with restored_new(remote, "SAVIA_DEV_bkpmeta_" + uuid.uuid4().hex) as restored:
        saved_counts = counts(restored)
    checked(saviadb.docker(["cp", f"{saviadb.CONTAINER}:{remote}", str(path)]), "docker cp")
    sha = digest(path)
    metadata = {"version": 1, "database": db, "createdUtc": stamp, "file": name,
                "sha256": sha, "counts": saved_counts}
    path.with_suffix(".sha256").write_text(f"{sha}  {name}\n", encoding="utf-8")
    path.with_suffix(".json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    prune()
    print(f"BACKUP PASS {path}\nCOUNTS {json.dumps(saved_counts, sort_keys=True)}\nSHA256 {sha}\nGIT ignored PASS")
    return path


def local_file(value):
    path = Path(value).resolve(strict=True)
    if not path.is_file() or path.suffix.lower() != ".bak":
        raise RuntimeError("Se requiere un archivo .bak existente.")
    return path


def metadata_for(path):
    data = json.loads(path.with_suffix(".json").read_text(encoding="utf-8"))
    expected = path.with_suffix(".sha256").read_text(encoding="utf-8").split()[0]
    actual = digest(path)
    if not re.fullmatch(r"[a-f0-9]{64}", expected) or expected != actual or data["sha256"] != actual:
        raise RuntimeError("SHA-256 no coincide; respaldo corrupto o metadatos incorrectos.")
    if data.get("version") != 1 or set(data["counts"]) != set(TABLES):
        raise RuntimeError("Metadatos incompletos o incompatibles.")
    if any(type(value) is not int or value < 0 for value in data["counts"].values()):
        raise RuntimeError("Conteos inválidos en metadatos.")
    return data


def verify(path):
    metadata_for(path)
    with uploaded(path) as remote:
        verify_sql(remote)
    print(f"VERIFY PASS {path.name}")


def restore_test(path):
    data = metadata_for(path)
    with uploaded(path) as remote:
        verify_sql(remote)
        with restored_new(remote, RESTORE_TEST) as db:
            sql("DBCC CHECKDB WITH NO_INFOMSGS; EXEC audit.usp_CheckConservation @Throw=1;", db)
            actual = counts(db)
            print(f"EXPECTED {json.dumps(data['counts'], sort_keys=True)}")
            print(f"ACTUAL   {json.dumps(actual, sort_keys=True)}")
            if actual != data["counts"]:
                raise RuntimeError("Los conteos restaurados no coinciden con el respaldo.")
    print("restore-test PASS; CHECKDB PASS; conservation PASS; counts MATCH; temporal eliminada")


def restore(path, db, yes_replace):
    if not yes_replace:
        raise RuntimeError("Restauración rechazada: se requiere --yes-replace.")
    saviadb.check_name(db)
    data = metadata_for(path)
    with uploaded(path) as remote:
        verify_sql(remote)
        exists = saviadb.scalar("master", f"SELECT CASE WHEN DB_ID({literal(db)}) IS NULL THEN 0 ELSE 1 END;") == "1"
        if exists:
            safety = backup(db)
            print(f"SAFETY BACKUP {safety}")
            sql(f"ALTER DATABASE [{db}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;")
        try:
            restore_sql(remote, db, replace=exists)
            sql("DBCC CHECKDB WITH NO_INFOMSGS; EXEC audit.usp_CheckConservation @Throw=1;", db)
            if counts(db) != data["counts"]:
                raise RuntimeError("Los conteos restaurados no coinciden con el respaldo.")
        finally:
            if saviadb.scalar("master", f"SELECT CASE WHEN DB_ID({literal(db)}) IS NULL THEN 0 ELSE 1 END;") == "1":
                sql(f"ALTER DATABASE [{db}] SET MULTI_USER;")
    print(f"RESTORE PASS {db}")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("backup").add_argument("--db", default="SAVIA_DEV_pilot")
    commands.add_parser("list")
    for name in ("verify", "restore-test", "restore"):
        command = commands.add_parser(name)
        command.add_argument("file")
        if name == "restore":
            command.add_argument("--db", required=True)
            command.add_argument("--yes-replace", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.command == "backup":
            backup(args.db)
        elif args.command == "list":
            for path in sorted(backup_folder().glob("*.bak"), reverse=True):
                print(f"{path.name}\t{path.stat().st_size} bytes")
        elif args.command == "restore":
            # Refuse unsafe arguments before even inspecting the supplied backup.
            if not args.yes_replace:
                raise RuntimeError("Restauración rechazada: se requiere --yes-replace.")
            saviadb.check_name(args.db)
            restore(local_file(args.file), args.db, args.yes_replace)
        elif args.command == "verify":
            verify(local_file(args.file))
        else:
            restore_test(local_file(args.file))
        return 0
    except (Exception, SystemExit) as error:
        if isinstance(error, (RuntimeError, SystemExit)):
            print(f"ERROR: {error}", file=sys.stderr)
        else:
            print(f"ERROR: {type(error).__name__}; operación incompleta.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
