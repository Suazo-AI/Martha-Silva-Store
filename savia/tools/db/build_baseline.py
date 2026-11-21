#!/usr/bin/env python3
"""Build savia/db/migrations/V001__baseline.sql from the untouched handoff installer.

The handoff SQL is a draft that does not install on SQL Server 2022 as shipped.
This tool applies a short list of named, exact-match corrections so the difference
between the original and the baseline stays explicit and reviewable.

Every correction must match the original text exactly once, or the build fails.
Evidence for each correction: savia/docs/evidence/cp0-sql-install/README.md

Usage:
  python savia/tools/db/build_baseline.py          # write the baseline
  python savia/tools/db/build_baseline.py --check  # fail if the committed file is stale
"""
import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "db" / "handoff-20261112" / "SAVIA_DB_AzureSQL_Instalar_En_BD_Existente.sql"
SOURCE_SHA256 = "5ad497342c1c04aab9b6a4b96fc55dea3029967cf169b845452b3727f1da48d9"
TARGET = ROOT / "db" / "migrations" / "V001__baseline.sql"

HEADER = """/* SAVIA V001 baseline. GENERATED FILE: do not edit by hand.
   Source: db/handoff-20261112/SAVIA_DB_AzureSQL_Instalar_En_BD_Existente.sql
   Source SHA-256: {sha}
   Generator: tools/db/build_baseline.py (named corrections F-001..F-007).
   Run against an EMPTY database chosen by the caller. No CREATE DATABASE, USE or DROP. */
-- F-001: the draft never set these options; filtered indexes then fail with Msg 1934
-- and procedures would be stored with QUOTED_IDENTIFIER OFF.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO
"""

# (id, why, old, new). Each `old` must occur exactly once in the source.
CORRECTIONS = [
    ("F-002", "usp_PostSale: one closing parenthesis too many (Msg 102 near ')').",
     "LEN(LTRIM(RTRIM(Reference)))=0))))\n   THROW 51509",
     "LEN(LTRIM(RTRIM(Reference)))=0)))\n   THROW 51509"),
    ("F-003a", "usp_PostSale: EXEC arguments cannot be expressions; declare a negated quantity.",
     "   DECLARE @item uniqueidentifier,@qty int,@op uniqueidentifier,@mv uniqueidentifier;\n   DECLARE lineCursor",
     "   DECLARE @item uniqueidentifier,@qty int,@op uniqueidentifier,@mv uniqueidentifier,@negQty int;\n   DECLARE lineCursor"),
    ("F-003b", "usp_PostSale: pass the negated quantity as a variable (Msg 102 near '@qty').",
     "     SET @op=NEWID(); SET @mv=NULL;\n"
     "     EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@LocationId,\n"
     "       @Pool='store',@Kind='sale',@OnHandDelta=-@qty,",
     "     SET @op=NEWID(); SET @mv=NULL; SET @negQty=-@qty;\n"
     "     EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@LocationId,\n"
     "       @Pool='store',@Kind='sale',@OnHandDelta=@negQty,"),
    ("F-004", "usp_CloseTill: LineNo is a reserved keyword (Msg 156).",
     "INSERT INTO accounting.CloseDocumentLines(CloseDocumentId,LineNo,ConceptCode,ConceptName,AmountMinor)",
     "INSERT INTO accounting.CloseDocumentLines(CloseDocumentId,[LineNo],ConceptCode,ConceptName,AmountMinor)"),
    ("F-005", "usp_AllocateToWeb: negated EXEC argument (Msg 102 near '@Quantity').",
     "   DECLARE @out uniqueidentifier=NEWID(),@in uniqueidentifier=NEWID(),@mv uniqueidentifier=NULL;\n"
     "   EXEC inventory.usp_ApplyMovement @OperationId=@out,@ItemId=@ItemId,@LocationId=@LocationId,\n"
     "     @Pool='store',@Kind='allocate',@OnHandDelta=-@Quantity,",
     "   DECLARE @out uniqueidentifier=NEWID(),@in uniqueidentifier=NEWID(),@mv uniqueidentifier=NULL,@negQuantity int=-@Quantity;\n"
     "   EXEC inventory.usp_ApplyMovement @OperationId=@out,@ItemId=@ItemId,@LocationId=@LocationId,\n"
     "     @Pool='store',@Kind='allocate',@OnHandDelta=@negQuantity,"),
    ("F-006a", "usp_FulfillPaidOrder: declare a negated quantity.",
     "  DECLARE @reservation uniqueidentifier,@item uniqueidentifier,@qty int,@op uniqueidentifier,@mv uniqueidentifier;\n  DECLARE fulfillCursor",
     "  DECLARE @reservation uniqueidentifier,@item uniqueidentifier,@qty int,@op uniqueidentifier,@mv uniqueidentifier,@negQty int;\n  DECLARE fulfillCursor"),
    ("F-006b", "usp_FulfillPaidOrder: negated EXEC arguments (Msg 102 near '@qty').",
     "    SET @op=NEWID(); SET @mv=NULL;\n"
     "    EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@location,\n"
     "      @Pool='web',@Kind='fulfill',@OnHandDelta=-@qty,@ReservedDelta=-@qty,",
     "    SET @op=NEWID(); SET @mv=NULL; SET @negQty=-@qty;\n"
     "    EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@location,\n"
     "      @Pool='web',@Kind='fulfill',@OnHandDelta=@negQty,@ReservedDelta=@negQty,"),
    ("F-007", "usp_ReleaseQuarantine: negated EXEC argument (Msg 102 near '@Quantity').",
     "   DECLARE @op1 uniqueidentifier=NEWID(),@op2 uniqueidentifier=NEWID(),@mv uniqueidentifier=NULL;\n"
     "   EXEC inventory.usp_ApplyMovement @OperationId=@op1,@ItemId=@ItemId,@LocationId=@LocationId,\n"
     "     @Pool='quarantine',@Kind='transfer_out',@OnHandDelta=-@Quantity,",
     "   DECLARE @op1 uniqueidentifier=NEWID(),@op2 uniqueidentifier=NEWID(),@mv uniqueidentifier=NULL,@negQuantity int=-@Quantity;\n"
     "   EXEC inventory.usp_ApplyMovement @OperationId=@op1,@ItemId=@ItemId,@LocationId=@LocationId,\n"
     "     @Pool='quarantine',@Kind='transfer_out',@OnHandDelta=@negQuantity,"),
]


def build() -> str:
    raw = SOURCE.read_bytes().replace(b"\r\n", b"\n")   # stable on any checkout line-ending setting
    actual = hashlib.sha256(raw).hexdigest()
    if actual != SOURCE_SHA256:
        raise SystemExit(f"Source hash changed: {actual}. The handoff file must stay untouched.")
    text = raw.decode("utf-8-sig").replace("\r\n", "\n")
    for fix_id, _why, old, new in CORRECTIONS:
        count = text.count(old)
        if count != 1:
            raise SystemExit(f"{fix_id}: expected exactly 1 match in the source, found {count}.")
        text = text.replace(old, new)
    return HEADER.format(sha=SOURCE_SHA256) + text


def main() -> int:
    built = build()
    if "--check" in sys.argv:
        current = TARGET.read_text(encoding="utf-8").replace("\r\n", "\n") if TARGET.exists() else ""
        if current != built:
            print("STALE: V001__baseline.sql differs from the generator output.")
            return 1
        print("OK: V001__baseline.sql matches the generator output.")
        return 0
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(built, encoding="utf-8", newline="\n")
    print(f"Wrote {TARGET.relative_to(ROOT)} with {len(CORRECTIONS)} corrections plus F-001 header.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
