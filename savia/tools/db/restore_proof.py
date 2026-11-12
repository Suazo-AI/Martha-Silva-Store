#!/usr/bin/env python3
"""F1 restore proof on the real engine (ADR-001 D5, critique F1 and E3).

A branch database is backed up, keeps working, and is then restored from the old backup.
After the restore it writes new rows. The proof checks, with V008:
  1. the recovery fork GUID changes on restore;
  2. Change Tracking versions are reused, so a version-only cursor misses the new rows;
  3. sync.usp_ClassifyCursor on the receiver answers 'recover', not 'incremental'.

Only creates and drops SAVIA_SIM_* databases and one backup file in the container.
Usage: python savia/tools/db/restore_proof.py      exit 0 = all three hold
"""
import sys
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import saviadb as db  # noqa: E402

SRC, RCV = "SAVIA_SIM_restore_src", "SAVIA_SIM_restore_rcv"
BAK = f"{db.DATA_DIR}/{SRC}_old.bak"
NODE_A = "test.Id('nodeA')"


def must(code_out, step):
    code, out = code_out
    if code != 0:
        raise SystemExit(f"{step} failed:\n{out}")
    return out


def open_till(name):
    till = str(uuid.uuid4())
    must(db.run_sql(SRC, f"""SET NOCOUNT ON;
DECLARE @t uniqueidentifier='{till}',@r uniqueidentifier=test.Id('registerA'),@c uniqueidentifier=test.Id('cashierA'),
        @n uniqueidentifier={NODE_A};
UPDATE sales.CashTills SET Status='closed',ClosedAt=SYSUTCDATETIME() WHERE RegisterId=@r AND Status='open';
EXEC sales.usp_OpenTill @TillId=@t,@RegisterId=@r,@CashierId=@c,@CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@n;"""),
         f"open till {name}")
    return till


def state():
    fork = db.scalar(SRC, "SELECT CONVERT(varchar(36),recovery_fork_guid) FROM sys.database_recovery_status WHERE database_id=DB_ID();")
    version = int(db.scalar(SRC, "SELECT CHANGE_TRACKING_CURRENT_VERSION();"))
    minv = int(db.scalar(SRC, "SELECT CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID('sales.CashTills'));"))
    return fork, version, minv


def main():
    template = db.ensure_template()
    for name in (SRC, RCV):
        must(db.clone(name, template), f"clone {name}")
    must(db.run_sql(SRC, f"DECLARE @n uniqueidentifier={NODE_A}; EXEC sync.usp_SetLocalNode @NodeId=@n;"),
         "set local node")

    open_till("t1")
    fork1, v1, _ = state()
    must(db.run_sql("master", f"BACKUP DATABASE [{SRC}] TO DISK=N'{BAK}' WITH INIT, FORMAT;"), "backup")

    open_till("t2")
    fork1b, v2, _ = state()
    # The receiver has applied everything up to v2 of fork1.
    must(db.run_sql(RCV, f"DECLARE @p uniqueidentifier={NODE_A}; "
                         f"EXEC sync.usp_AdvancePeerCursor @p,N'[sales].[CashTills]','{fork1}',{v2};"), "advance cursor")

    must(db.run_sql("master", f"ALTER DATABASE [{SRC}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; "
                              f"RESTORE DATABASE [{SRC}] FROM DISK=N'{BAK}' WITH REPLACE, RECOVERY; "
                              f"ALTER DATABASE [{SRC}] SET MULTI_USER;"), "restore old backup")
    _, v_restored, _ = state()
    t3 = open_till("t3 after restore")
    fork2, v3, minv = state()

    seen_by_version_only = int(db.scalar(SRC, f"SELECT COUNT(*) FROM CHANGETABLE(CHANGES sales.CashTills,{v2}) c "
                                              f"WHERE c.Id='{t3}';")) if v2 >= minv else -1
    action = db.scalar(RCV, f"DECLARE @p uniqueidentifier={NODE_A}; DECLARE @r TABLE(a varchar(16),f bigint); "
                            f"INSERT @r EXEC sync.usp_ClassifyCursor @p,N'[sales].[CashTills]','{fork2}',{v3},{minv}; "
                            f"SELECT a FROM @r;")

    rows = [("fork before backup", fork1), ("fork before restore", fork1b), ("fork after restore", fork2),
            ("version at backup", v1), ("version receiver has (cursor)", v2),
            ("version right after restore", v_restored), ("version after new till t3", v3),
            ("t3 visible to a version-only cursor at v2", seen_by_version_only),
            ("ClassifyCursor with (fork, version)", action)]
    for k, v in rows:
        print(f"{k:<45} {v}")
    checks = {
        "fork changes on restore": fork2 != fork1 and fork1 == fork1b,
        "versions are reused after restore (E3)": v_restored < v2 and v3 <= v2,
        "a version-only cursor misses the new till": seen_by_version_only == 0,
        "the (fork, version) cursor says recover": action == "recover",
    }
    for k, ok in checks.items():
        print(f"{'PASS' if ok else 'FAIL'}  {k}")
    for name in (SRC, RCV):
        db.drop(name)
    db.docker(["exec", db.CONTAINER, "rm", "-f", BAK])
    return 0 if all(checks.values()) else 1


if __name__ == "__main__":
    sys.exit(main())
