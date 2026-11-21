"""Real Docker rollback and retry tests for the V028 migration envelope."""
import importlib.util
import unittest
import uuid
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('usd_change_db', ROOT / 'tools/db/saviadb.py')
db = importlib.util.module_from_spec(spec)
spec.loader.exec_module(db)


class RecoveryTests(unittest.TestCase):
    """Each test owns its disposable SAVIA_T database in the development container."""
    def run_case(self, failure):
        name = 'SAVIA_T_v028_recovery_' + uuid.uuid4().hex[:12]
        all_files = db.migration_files()
        prior = [p for p in all_files if p.name < 'V028']
        candidate = ROOT / 'db/migrations/V028__usd_change.sql'
        self.assertTrue(candidate.exists(), 'V028 must exist')
        try:
            self.assertEqual(0, db.create(name)[0])
            with patch.object(db, 'migration_files', return_value=prior):
                self.assertEqual(0, db.migrate(name)[0])
            code, out = db.run_sql(name, (ROOT / 'db/tests/_fixture.sql').read_text(encoding='utf-8'))
            self.assertEqual(0, code, out)
            code, out = db.run_sql(name, """
DECLARE @till uniqueidentifier=NEWID(),@rate uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),
 @item uniqueidentifier=test.Id('item'),@loc uniqueidentifier=test.Id('locA'),
 @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
 @register uniqueidentifier=test.Id('registerA'),@branch uniqueidentifier=test.Id('branchA');
UPDATE catalog.Items SET UnitPriceMinor=216100,TaxRateBps=0 WHERE Id=@item;
EXEC test.SeedStock @item,@loc,20;
EXEC sales.usp_OpenTillCounted @till,@register,@cashier,'NIO',100000,@node,
 N'[{"denominationMinor":100,"quantity":1000}]',@UsdLinesJson=N'[{"denominationMinor":100,"quantity":0}]';
INSERT core.ExchangeRates(Id,CurrencyCode,EffectiveFrom,Rate,SetBy,Reason)
 VALUES(@rate,'USD',CAST(DATEADD(hour,-6,core.ufn_BusinessNow()) AS date),36.6243,test.Id('manager'),N'Test');
DECLARE @l sales.SaleLineRequest,@t sales.SaleTenderRequest;
INSERT @l VALUES(1,@item,1,216100,0); INSERT @t VALUES(1,'cash',216100,NULL,NULL,NULL,NULL);
DECLARE @fx nvarchar(max)=(SELECT 1 tenderNumber,'USD' foreignCurrencyCode,6000 foreignReceivedMinor,@rate exchangeRateId FOR JSON PATH);
EXEC sales.usp_PostSale @sale,@branch,@loc,@cashier,'NIO',@node,@l,@t,@TillId=@till,@FxJson=@fx;
""")
            self.assertEqual(0, code, out)
            snapshot_sql = """SELECT
 JSON_QUERY((SELECT * FROM sales.SaleTenders FOR JSON PATH)) tenders,
 JSON_QUERY((SELECT * FROM sales.CashEntries ORDER BY Id FOR JSON PATH)) entries,
 JSON_QUERY((SELECT * FROM dbo.SaviaMigrations ORDER BY Version FOR JSON PATH)) registry,
 JSON_QUERY((SELECT name,definition FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID('sales.SaleTenders') ORDER BY name FOR JSON PATH)) constraints
 FOR JSON PATH,WITHOUT_ARRAY_WRAPPER"""
            snapshot_sql = "SELECT CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varbinary(max),(" + snapshot_sql + "))),2)"
            rows_before = db.scalar(name, snapshot_sql)
            before = db.scalar(name, "SELECT OBJECT_DEFINITION(OBJECT_ID('sales.CK_Tenders_FX'))")
            if failure == 'registry':
                code, out = db.run_sql(name, "CREATE TRIGGER dbo.FailRegistry ON dbo.SaviaMigrations AFTER INSERT AS IF EXISTS(SELECT 1 FROM inserted WHERE Version='V028') THROW 59098,'forced registry failure',1;")
                self.assertEqual(0, code, out)
            original = db.run_sql
            def injected(database, script, **kwargs):
                if failure == 'index' and '-- savia:transactional' in script:
                    script = script.replace('DROP INDEX UX_CashEntries_Tender ON sales.CashEntries;',
                        "DROP INDEX UX_CashEntries_Tender ON sales.CashEntries;\nTHROW 59097,'forced index failure',1;")
                return original(database, script, **kwargs)
            with patch.object(db, 'run_sql', side_effect=injected):
                code, out = db.migrate(name)
            self.assertNotEqual(0, code, out)
            self.assertIn('59097' if failure == 'index' else '59098', out)
            self.assertEqual('1', db.scalar(name, "SELECT COUNT(*) FROM sys.indexes WHERE object_id=OBJECT_ID('sales.CashEntries') AND name='UX_CashEntries_Tender'"))
            self.assertEqual('0', db.scalar(name, "SELECT COUNT(*) FROM sys.columns WHERE object_id=OBJECT_ID('sales.SaleTenders') AND name='ForeignChangeMinor'"))
            self.assertEqual('0', db.scalar(name, "SELECT COUNT(*) FROM dbo.SaviaMigrations WHERE Version='V028'"))
            self.assertEqual(before, db.scalar(name, "SELECT OBJECT_DEFINITION(OBJECT_ID('sales.CK_Tenders_FX'))"))
            self.assertEqual(rows_before, db.scalar(name, snapshot_sql))
            if failure == 'registry':
                self.assertEqual(0, db.run_sql(name, 'DROP TRIGGER dbo.FailRegistry')[0])
            self.assertEqual(0, db.migrate(name)[0])
            self.assertEqual(0, db.migrate(name)[0])
            self.assertEqual('1', db.scalar(name, "SELECT COUNT(*) FROM dbo.SaviaMigrations WHERE Version='V028'"))
            self.assertEqual('1', db.scalar(name, "SELECT COUNT(*) FROM sales.SaleTenders WHERE ForeignChangeMinor IS NULL AND ChangeMinor=3600 AND RoundingMinor=46"))
            self.assertEqual(0, db.run_sql(name, 'EXEC audit.usp_CheckConservation @Throw=1')[0])
        finally:
            db.drop(name)

    def test_failure_after_index_drop(self):
        self.run_case('index')

    def test_registry_insert_failure(self):
        self.run_case('registry')


if __name__ == '__main__':
    unittest.main()
