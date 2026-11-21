"""Source-bound cash evidence regressions; synthetic offline data only."""
import copy
import unittest
import test_golden_path_cash as cash
from test_golden_path_cash import full_snapshot, ident, GP


class PublicationRegressions(unittest.TestCase):
    def publication(self, mutate=None):
        cash.CashControls('test_complete_synthetic_evidence_publishes_exact_bytes').publication(mutate)

    def rejects(self, mutate):
        with self.assertRaises(Exception):
            self.publication(mutate)

    def test_positive(self): self.publication()

    def test_missing_mode(self):
        self.rejects(lambda d:(d.pop('mode'),d.update(steps=[])))

    def test_smoke_mode(self):
        self.rejects(lambda d:d.update(mode='smoke',steps=[]))

    def test_missing_dom(self): self.rejects(lambda d:d['steps'][0].pop('dom'))
    def test_missing_runtime(self): self.rejects(lambda d:d['steps'][0].pop('runtime'))
    def test_missing_source_map(self): self.rejects(lambda d:d['browser'].pop('source_hashes'))
    def test_missing_checkpoint_source(self): self.rejects(lambda d:d['steps'][1].pop('source_hashes'))
    def test_wrong_served_hash(self):
        self.rejects(lambda d:d['steps'][1]['source_hashes'].update({GP.BROWSER_SOURCES[0]:'b'*64}))
    def test_wrong_run_source(self):
        self.rejects(lambda d:d['browser']['source_hashes'].update({GP.BROWSER_SOURCES[0]:'b'*64}))
    def test_missing_run_runtime(self): self.rejects(lambda d:d['browser'].pop('runtime'))
    def test_invalid_api_exit(self): self.rejects(lambda d:d['steps'][-1].update(api_exit=True))
    def test_failure_cannot_be_relabelled_pass(self):
        self.rejects(lambda d:d.update(outcome='PASS',steps=[]))
    def test_wrong_recovered_sale(self):
        self.rejects(lambda d:d['steps'][8].update(sale_id=ident(987)))
    def test_wrong_recovered_key(self):
        self.rejects(lambda d:d['steps'][8].update(key=ident(987)))
    def test_unauthorized_network(self):
        self.rejects(lambda d:d['steps'][0]['network'].append(dict(method='POST',path='/internal/api/security/staff',status=200,key=ident(987),response_lost=False)))
    def test_missing_api_exit(self): self.rejects(lambda d:d['steps'][-1].pop('api_exit'))
    def test_null_api_exit(self): self.rejects(lambda d:d['steps'][-1].update(api_exit=None))
    def test_failure_export(self): self.publication(lambda d:d.update(outcome='FAIL',steps=[]))
    def test_historical_export(self):
        self.publication(lambda d:(d.pop('cash_protocol'),d.pop('browser'),d.update(mode='smoke',steps=[])))


class PreservationRegressions(unittest.TestCase):
    def test_returned_immutable_fields(self):
        for stage,prior_stage in (('browser.cash_refunded','browser.cash_refund_refused'),('browser.cash_later_refund','browser.cash_later_till')):
            _,baseline,_,_=full_snapshot(stage)
            mutations = [(table,field,'cancelled' if field=='State' else 'corrupt')
                         for table in ('Sales','SaleLines') for field in baseline['rows'][table][0]
                         if field != 'ReturnedQuantity']
            for table,field,value in mutations:
                with self.subTest(stage=stage,table=table,field=field):
                    _,prior,_,_=full_snapshot(prior_stage)
                    c,s,u,i=full_snapshot(stage)
                    s['rows'][table][0][field]=value
                    with self.assertRaises(GP.HarnessError): GP.validate_cash_snapshot(c,s,u,i,prior,stage)

    def test_state_uses_all_lines(self):
        for stage in ('browser.cash_refunded','browser.cash_later_refund'):
            with self.subTest(stage=stage):
                c,s,u,i=full_snapshot(stage)
                self.assertEqual(s['rows']['Sales'][0]['State'],'partially_returned')
                GP.validate_cash_snapshot(c,s,u,i,None,stage)
                s['rows']['Sales'][0]['State']='returned'
                with self.assertRaises(GP.HarnessError):GP.validate_cash_snapshot(c,s,u,i,None,stage)


if __name__=='__main__': unittest.main()
