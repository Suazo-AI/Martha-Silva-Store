"""Offline source guards only; never opens a connection or changes generated files."""
import hashlib
import json
import pathlib
import re
import subprocess

root = pathlib.Path(__file__).resolve().parents[4]
area = root / "backend/src/Martha.Store.Api/Internal/Migrations"
checks = []


def check(name, condition):
    assert condition, name
    checks.append(name)


manifest = json.loads((root / "docs/cash-register-20261107/backend-worker/source-hashes.json").read_text())
check("base HEAD", subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip() == manifest["base_sha"])
for item in manifest["files"]:
    data = (root / item["path"]).read_bytes()
    check("frozen RAW/LF: " + item["path"], hashlib.sha256(data).hexdigest() == item["sha256_raw"] and
          hashlib.sha256(data.replace(b"\r\n", b"\n")).hexdigest() == item["sha256_lf"])

files = list(area.glob("*_FirstCashRegister.cs"))
check("one generated migration", len(files) == 1)
migration = files[0].read_text(encoding="utf-8-sig")
up, down = migration.split("protected override void Down", 1)
tables = {"CashTills", "CashEntries", "CashCloses"}
check("Up creates exactly three frozen tables", set(re.findall(r'CreateTable\(\s+name: "([^"]+)"', up)) == tables and up.count("migrationBuilder.CreateTable(") == 3)
check("Up only additive table/index operations", re.findall(r"migrationBuilder\.(\w+)\(", up) == ["CreateTable"] * 3 + ["CreateIndex"] * 9)
check("Down drops only the three new tables", set(re.findall(r'DropTable\(\s+name: "([^"]+)"', down)) == tables and re.findall(r"migrationBuilder\.(\w+)\(", down) == ["DropTable"] * 3)
check("eight restrictive foreign keys", up.count("table.ForeignKey(") == 8 and up.count("onDelete: ReferentialAction.Restrict") == 8)
check("three primary keys and frozen custody alternate key", up.count("table.PrimaryKey(") == 3 and 'table.UniqueConstraint("AK_CashTills_Id_CashierId_Currency_Exponent", x => new { x.Id, x.CashierId, x.Currency, x.Exponent })' in up)
check("five expected check constraints", set(re.findall(r'table.CheckConstraint\("([^"]+)"', up)) == {"CK_CashTill_Currency", "CK_CashTill_Time", "CK_CashEntry_Bounds", "CK_CashEntry_Kind", "CK_CashClose_Amounts"})
check("bigint money and explicit currency/exponent", up.count('type: "bigint"') == 6 and up.count('type: "varchar(3)"') == 2 and up.count('Exponent = table.Column<int>') == 2 and up.count('collation: "Latin1_General_100_BIN2"') == 2)
check("bounds signs and counted variance", all(value in up for value in ["[DeltaMinor] BETWEEN -9000000000000 AND 9000000000000", "[ReceivedMinor]-[ChangeMinor]=[DeltaMinor]", "[Kind]='refund' AND [DeltaMinor]<0", "[DifferenceMinor]=[CountedMinor]-[ExpectedMinor]", "[Exponent] BETWEEN 0 AND 6"]))
indexes = re.findall(r'migrationBuilder.CreateIndex\(\s+(.*?)\);', up, re.S)
unique = {re.search(r'name: "([^"]+)"', x).group(1): x for x in indexes if "unique: true" in x}
expected_unique = {"IX_CashCloses_TillId": None, "IX_CashEntries_ReversalId": "[ReversalId] IS NOT NULL", "IX_CashEntries_SaleId": "[Kind]='sale'", "IX_CashEntries_TillId": "[Kind]='opening'", "IX_CashTills_CashierId": "[ClosedAt] IS NULL"}
check("five unique indexes and exact open/reference filters", set(unique) == set(expected_unique) and all(value is None or 'filter: "' + value + '"' in unique[key] for key, value in expected_unique.items()))
check("all operations target internal schema", up.count('schema: "savia_internal"') == 12 and up.count('principalSchema: "savia_internal"') == 8 and down.count('schema: "savia_internal"') == 3)

snapshot_path = area / "InternalDbContextModelSnapshot.cs"
snapshot = snapshot_path.read_text(encoding="utf-8-sig")
baseline = subprocess.check_output(["git", "show", "HEAD:backend/src/Martha.Store.Api/Internal/Migrations/InternalDbContextModelSnapshot.cs"], cwd=root).decode("utf-8-sig").replace("\r\n", "\n")
without_cash, count = re.subn(r'^            modelBuilder.Entity\("Martha.Store.Api.Internal.InternalCash(?:Close|Entry|Till)", b =>\n.*?^                \}\);\n\n', '', snapshot, flags=re.M | re.S)
check("snapshot only adds three cash entity definitions and their relations", count == 6 and without_cash == baseline)
expected_tables = {"BranchAssignmentAudit", "Branches", "CashCloses", "CashEntries", "CashTills", "Items", "Locations", "Operations", "Parties", "PurchaseOrderLines", "PurchaseOrders", "PurchaseReceiptLines", "PurchaseReceipts", "SaleLines", "SaleReversalLines", "SaleReversals", "Sales", "Sessions", "Staff", "StockAdjustments", "StockBalances", "StockExceptionReviews", "StockMovements"}
actual_tables = re.findall(r'b.ToTable\("([^"]+)", "savia_internal"', snapshot)
check("independent explicit inventory 23 total and 20 business", len(actual_tables) == 23 and set(actual_tables) == expected_tables and len(expected_tables - {"Staff", "Sessions", "BranchAssignmentAudit"}) == 20)
designer = files[0].with_name(files[0].stem + ".Designer.cs").read_text(encoding="utf-8-sig")
check("designer target matches generated snapshot body", designer.split("#pragma warning disable 612, 618", 1)[1] == snapshot.split("#pragma warning disable 612, 618", 1)[1])
print(json.dumps({"status": "PASS", "checks": len(checks), "frozen_bindings": len(manifest["files"]), "tables_total": 23, "tables_business": 20, "migration": files[0].name, "limits": "Source guards only; no SQL executed."}, indent=2))
