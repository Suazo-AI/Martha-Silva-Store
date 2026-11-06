"""Offline guards for the opt-in stock extension; no runtime or SQL starts."""
import ast
import copy
import unittest
import contextlib
import io
import tempfile
from unittest.mock import patch
from test_golden_path_safety import GP, HARNESS
from test_golden_path_browser_safety import checkpoint, SALE, KEY
class StockControls(unittest.TestCase):
    def test_invalid_stock_flags_refuse_before_harness_or_runtime(self):
        for flags in [[], ['--mode', 'browser'], ['--supply']]:
            with self.subTest(flags=flags), tempfile.TemporaryDirectory() as out, \
                    patch.object(GP, 'GoldenPath') as runtime, contextlib.redirect_stderr(io.StringIO()) as error:
                with self.assertRaises(SystemExit) as refused:
                    GP.main(['--out', out, '--stock-exception', *flags])
                self.assertEqual(refused.exception.code, 2)
                self.assertIn('--stock-exception requires --supply --mode browser', error.getvalue())
                runtime.assert_not_called()

    def test_workflow_keeps_stock_opt_in_and_rejects_invalid_inputs_before_sql(self):
        workflow=(HARNESS.parents[2]/'.github/workflows/golden-path.yml').read_text(encoding='utf-8')
        stock=workflow.split('      stock_exception:', 1)[1].split('\npermissions:', 1)[0]
        self.assertIn('type: boolean', stock)
        self.assertIn('default: false', stock)
        self.assertIn("github.event_name == 'workflow_dispatch' && inputs.stock_exception == true", workflow)
        refusal=workflow.index('Refuse invalid combined-journey inputs before runtime')
        self.assertLess(refusal, workflow.index('Start disposable SQL'))
        guard=workflow[refusal:workflow.index('Evidence and cleanup failure regressions')]
        self.assertIn('[ "$RUN_STOCK_EXCEPTION" = "true" ] && [ "$RUN_SUPPLY_RECEIPT" != "true" ]', guard)
        self.assertIn('exit 1', guard)
        self.assertIn('then receipt_args+=(--stock-exception); fi', workflow)

    def test_stock_is_explicit_opt_in_and_requires_combined_browser_path(self):
        tree=ast.parse(HARNESS.read_text(encoding='utf-8'))
        calls=[n for n in ast.walk(tree) if isinstance(n,ast.Call) and any(isinstance(a,ast.Constant) and a.value=='--stock-exception' for a in n.args)]
        self.assertEqual(len(calls),1)
        self.assertEqual({k.arg:ast.literal_eval(k.value) for k in calls[0].keywords}['action'],'store_true')
        self.assertIn("args.stock_exception and (not args.supply or args.mode != 'browser')",HARNESS.read_text(encoding='utf-8'))
        self.assertEqual(len(GP.BROWSER_STEPS)+len(GP.SUPPLY_STEPS),17)
        self.assertEqual(len(GP.STOCK_STEPS),5)
        self.assertIn('exception_movements',GP.ALWAYS_ZERO)
    def test_exception_accounting_does_not_weaken_purchase_or_ordinary_oracles(self):
        source=(HARNESS.parent/'GoldenPath.Sql/Program.cs').read_text(encoding='utf-8')
        ordinary=source[source.index('(SELECT COUNT(*) FROM savia_internal.SaleLines l\n'):source.index('AS lines_without_exactly_one_movement')]
        self.assertIn('l.ExceptionReason IS NULL',ordinary)
        receipt=source[source.index('(SELECT COUNT(*) FROM savia_internal.PurchaseReceiptLines l JOIN'):source.index('AS receipt_movement_mismatch')]
        self.assertNotIn('ExceptionReason',receipt)
    def test_review_path_accepts_only_uuid_and_sanitized_identity(self):
        e=checkpoint(GP.STOCK_STEPS[0],3)
        e['notes'].update(sale_id=SALE,key=KEY)
        e['notes']['network']=[dict(method='POST',path=f'/internal/api/commerce/sales/{SALE}/stock-reviews',status=200,key=KEY,response_lost=False)]
        self.assertEqual(GP.browser_checkpoint(e,GP.STOCK_STEPS[0],set())['sale_id'],SALE)
        for bad in ['x'*36,'-'*36,SALE+'/private']:
            invalid=copy.deepcopy(e);invalid['notes']['network'][0]['path']=f'/internal/api/commerce/sales/{bad}/stock-reviews'
            with self.assertRaises(GP.HarnessError):GP.browser_checkpoint(invalid,GP.STOCK_STEPS[0],set())
if __name__=='__main__':unittest.main()
