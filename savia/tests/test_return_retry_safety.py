"""Offline source contracts only. These tests never execute or parse T-SQL."""
import hashlib
import importlib.util
import re
import unittest
from pathlib import Path
from unittest.mock import patch
ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / 'db/migrations/V029__return_retry_safety.sql'
SQL = MIGRATION.read_text(encoding='utf-8')

def procedures(sql):
    return re.split(r'CREATE OR ALTER PROCEDURE ', sql)[1:]

def assert_identity_batch_boundary(sql):
    batches = re.split(r'(?im)^[ \t]*GO[ \t]*$', sql)
    columns = [i for i, batch in enumerate(batches) if 'ADD RequestIdentityVersion smallint NULL, RequestIdentityHash varbinary(32) NULL;' in batch]
    constraints = [i for i, batch in enumerate(batches) if 'ADD CONSTRAINT CK_Reversals_RequestIdentity CHECK(' in batch]
    if len(columns) != 1 or len(constraints) != 1 or columns[0] >= constraints[0]:
        raise AssertionError('new identity columns require a separate earlier batch')

def assert_identity_coverage(sql):
    expected = [
        ['@SaleId', '@BranchId', '@LocationId', '@OriginNodeId', '@TillId', '@Reason', '@Outcome', '@Reference', '@ExchangeSaleId', '@DifferenceKind', '@DifferenceReference',
         'SaleLineId,Quantity,RestockPool', 'LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor', 'TenderNumber,TenderKind,AmountMinor,CreditId,ReceivedMinor,ChangeMinor,Reference', 'LineNumber,SellerId'],
        ['@SaleId', '@BranchId', '@ReturnLocationId', '@OriginNodeId', '@TillId', '@Reason', '@CreditId', '@CustomerId', 'SaleLineId,Quantity,RestockPool']]
    for proc, fields in zip(procedures(sql), expected, strict=True):
        identity = proc[proc.index('DECLARE @identityJson'):proc.index('DECLARE @identityHash')]
        for field in fields:
            if field not in identity:
                raise AssertionError('identity missing ' + field)
        for excluded in ['@ActorId', '@ApprovedBy', 'TaxRateBps', 'ufn_ReturnWindowDays']:
            if excluded in identity:
                raise AssertionError('identity includes live policy/credential ' + excluded)

def assert_lock_and_enabled_contract(sql):
    for proc in procedures(sql):
        if "@identityResource nvarchar(255)=CONCAT(N'savia.return.',CONVERT(nvarchar(36),@ReversalId))" not in proc:
            raise AssertionError('shared reversal application resource missing')
        prefix = proc[:proc.index('-- NULL legacy identity')]
        name = proc.splitlines()[0].replace('[', '').replace(']', '').strip()
        staff_ids = {
            'sales.usp_PostReturnOutcome': ['@ActorId'],
            'sales.usp_PostCreditReturn': ['@ActorId', '@ApprovedBy'],
        }.get(name)
        if staff_ids is None:
            raise AssertionError('unexpected return procedure: ' + name)
        for staff in staff_ids:
            predicates = re.findall(r'WHERE a.StaffId=' + staff + r'[^)]*', prefix)
            if not predicates or any('s.IsEnabled=1' not in p or 'a.IsActive=1' not in p for p in predicates):
                raise AssertionError('enabled staff and active access missing: ' + staff)

class ReturnRetrySourceTests(unittest.TestCase):
    def test_new_columns_bind_in_an_earlier_batch(self):
        assert_identity_batch_boundary(SQL)

    def test_negative_same_batch_identity_constraint(self):
        mutated = re.sub(r'(RequestIdentityHash varbinary\(32\) NULL;\s*)GO[ \t]*\n', r'\1', SQL, count=1, flags=re.IGNORECASE)
        self.assertNotEqual(SQL, mutated)
        with self.assertRaisesRegex(AssertionError, 'separate earlier batch'):
            assert_identity_batch_boundary(mutated)

    def test_shared_lock_and_enabled_staff(self):
        assert_lock_and_enabled_contract(SQL)

    def test_negative_split_endpoint_namespace(self):
        mutated = SQL.replace("N'savia.return.'", "N'savia.return.credit.'", 1)
        self.assertNotEqual(SQL, mutated)
        with self.assertRaisesRegex(AssertionError, 'shared reversal'):
            assert_lock_and_enabled_contract(mutated)

    def test_negative_omitted_enabled_staff(self):
        mutated = SQL.replace(' AND s.IsEnabled=1', '')
        self.assertNotEqual(SQL, mutated)
        with self.assertRaisesRegex(AssertionError, 'enabled staff'):
            assert_lock_and_enabled_contract(mutated)

    def test_negative_omitted_credit_approver_enabled(self):
        predicate = 'WHERE a.StaffId=@ApprovedBy AND s.IsEnabled=1'
        self.assertEqual(1, SQL.count(predicate))
        mutated = SQL.replace(predicate, 'WHERE a.StaffId=@ApprovedBy', 1)
        with self.assertRaisesRegex(AssertionError, '@ApprovedBy'):
            assert_lock_and_enabled_contract(mutated)

    def test_all_financial_fields_projected(self):
        assert_identity_coverage(SQL)

    def test_negative_control_pool_omission_is_detected(self):
        mutated = SQL.replace('SELECT SaleLineId,Quantity,RestockPool FROM @Lines', 'SELECT SaleLineId,Quantity FROM @Lines')
        self.assertNotEqual(SQL, mutated)
        with self.assertRaisesRegex(AssertionError, 'RestockPool'):
            assert_identity_coverage(mutated)

    def test_authorization_serialization_and_replay_before_eligibility(self):
        for proc in procedures(SQL):
            self.assertLess(proc.index('sys.sp_getapplock'), proc.index('DECLARE @lockedTill'))
            self.assertLess(proc.index('CanApproveReturns=1'), proc.index('-- NULL legacy identity'))
            self.assertLess(proc.index('COMMIT; RETURN;'), proc.index("t.Status='open'"))
            self.assertIn('RequestIdentityVersion=1 AND RequestIdentityHash=@identityHash', proc)
            self.assertIn('THROW 51538', proc)
            self.assertIn('@ActorId,1,@identityHash)', proc)
            self.assertNotIn('SET RequestIdentity', proc)
            self.assertIn('IF @@TRANCOUNT>0 ROLLBACK; THROW;', proc)
            self.assertLess(proc.index('WHERE Id=@TillId;'), proc.index('WHERE ParentTillId=@TillId;'))

    def test_deterministic_arrays_and_explicit_nulls(self):
        for proc in procedures(SQL):
            self.assertIn('ORDER BY SaleLineId FOR JSON PATH,INCLUDE_NULL_VALUES', proc)
            self.assertIn('FOR JSON PATH,INCLUDE_NULL_VALUES,WITHOUT_ARRAY_WRAPPER', proc)
        outcome = procedures(SQL)[0]
        for table, order in [('NewLines', 'LineNumber'), ('NewTenders', 'TenderNumber'), ('identitySellers', 'LineNumber')]:
            self.assertIn(f'FROM @{table} ORDER BY {order} FOR JSON PATH,INCLUDE_NULL_VALUES', outcome)
        self.assertIn('IF @FxJson IS NOT NULL THROW 52102', outcome)

    def test_actual_migration_uses_existing_atomic_envelope(self):
        spec = importlib.util.spec_from_file_location('return_db', ROOT / 'tools/db/saviadb.py')
        db = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(db)
        calls = []
        with patch.object(db, 'migration_files', return_value=[MIGRATION]), patch.object(db, 'scalar', return_value='none'), patch.object(db, 'run_sql', side_effect=lambda name, sql: (calls.append(sql) or (0, ''))):
            self.assertEqual(0, db.migrate('SAVIA_T_return_offline')[0])
        actual = [c for c in calls if 'ALTER TABLE sales.SaleReversals' in c]
        self.assertEqual(1, len(actual))
        for required in ['SET XACT_ABORT ON; BEGIN TRAN;', "VALUES('V029'", 'XACT_STATE()', 'COMMIT;', hashlib.sha256(MIGRATION.read_bytes().replace(b'\r\n', b'\n')).hexdigest()]:
            self.assertIn(required, actual[0])

if __name__ == '__main__':
    unittest.main()
