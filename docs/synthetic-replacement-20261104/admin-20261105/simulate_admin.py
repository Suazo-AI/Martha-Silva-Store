"""Bounded sequential offline specification. Not SAVIA. Stdlib only."""
import sys
sys.dont_write_bytecode = True  # imported historical source must remain untouched
import argparse
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import random
import subprocess
import time
from oracle import verify

HERE = Path(__file__).resolve().parent
BASE = HERE.parent / 'simulate.py'
spec = importlib.util.spec_from_file_location('historical_model', BASE)
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)
BLUSA, JEAN, ZERO = 'MOCK-BLUSA-M', 'MOCK-JEAN-30', 'MOCK-VESTIDO-S'
SEEDS = [7, 19, 41, 83, 131, 251, 509, 1021]


def dump(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class Admin:
    """Proposed admin contracts, separated from unchanged historical Model."""
    def __init__(self):
        self.model = base.Model()
        self.fixture = dict(items=copy.deepcopy(self.model.state['items']), opening=10000,
                            reviewers=['MOCK-MANAGER', 'MOCK-SUBSTITUTE'],
                            withdrawers=['MOCK-MANAGER'], cashier='MOCK-CAJA-A')
        self.state = dict(pending={}, settled={}, settled_total=0, withdrawals=0,
                          incidents={}, reviews={}, closes={}, audit=[])

    def snapshot(self):
        return copy.deepcopy(dict(model=self.model.state, admin=self.state))

    def apply(self, a):
        m, s, op = self.model, self.state, a['op']
        reject = base.Rejected
        if op == 'sale':
            return m.sale(a['key'], a['lines'], a['payments'], a.get('actor', 'MOCK-CAJA-A'), a.get('credit', False))
        if op == 'purchase':
            return m.purchase(a['id'], a['sku'], a['qty'], 10000)
        if op == 'receive':
            return m.receive(a['key'], a['purchase'], a['qty'])
        if op == 'return':
            return m.return_line(a['key'], a['sale'], a['sku'], a['qty'])
        if op == 'collect':
            return m.collect(a['key'], a['sale'], a['amount'])
        if op == 'pending':
            if a['key'] in s['pending']:
                if s['pending'][a['key']] != a['amount']:
                    raise reject('transfer_conflict')
                return
            if type(a['amount']) is not int or a['amount'] <= 0:
                raise reject('invalid_amount')
            s['pending'][a['key']] = a['amount']
        elif op == 'settle':
            if a['key'] in s['settled']:
                return
            if a['key'] not in s['pending']:
                raise reject('unknown_transfer')
            s['settled'][a['key']] = s['pending'][a['key']]
            s['settled_total'] += s['pending'][a['key']]
        elif op == 'withdraw':
            if a['actor'] not in self.fixture['withdrawers']:
                raise reject('forbidden_withdrawal')
            if type(a['amount']) is not int or a['amount'] <= 0:
                raise reject('invalid_amount')
            s['withdrawals'] += a['amount']
        elif op == 'incident':
            if a['id'] in s['incidents']:
                raise reject('duplicate_incident')
            if a['actor'] != self.fixture['cashier'] or a['qty'] != 1 or a['sku'] != ZERO:
                raise reject('unsupported_incident')
            s['incidents'][a['id']] = {k: a[k] for k in ('sku', 'size', 'location', 'qty', 'actor', 'shift', 'moment', 'sale_reference')}
            s['incidents'][a['id']].update(cause='open', owner='MOCK-REVIEW-QUEUE', next_review='NEXT-CLOSE-ASSUMPTION', delivered=True, financial_posting=False, stock_posting=False)
        elif op == 'review':
            inc = s['incidents'][a['id']]
            if a['actor'] not in self.fixture['reviewers'] or a['actor'] == inc['actor']:
                raise reject('forbidden_review')
            if a['shift'] != inc['shift']:
                raise reject('wrong_shift')
            s['reviews'][a['id']] = {k: a[k] for k in ('actor', 'evidence', 'shift')}
        elif op == 'close':
            if a['actor'] not in self.fixture['reviewers'] or a['actor'] == self.fixture['cashier']:
                raise reject('forbidden_close')
            if not a['evidence']:
                raise reject('missing_evidence')
            if a['shift'] in s['closes']:
                raise reject('already_closed')
            expected = self.fixture['opening'] + m.state['cash'] - s['withdrawals']
            s['closes'][a['shift']] = dict(actor=a['actor'], evidence=a['evidence'], counted=a['counted'], expected=expected, difference=a['counted'] - expected, cause='open' if a['counted'] != expected else 'no_cash_difference')
        else:
            raise reject('unsupported')
        s['audit'].append(copy.deepcopy(a))


class Case:
    def __init__(self, name):
        self.name, self.admin, self.journal, self.assertions = name, Admin(), [], 0

    def step(self, action, expected='applied', error=None, lost_output=False):
        before = self.admin.snapshot()
        observed, actual_error = None, None
        try:
            result = self.admin.apply(action)
            observed = 'replay' if before == self.admin.snapshot() else 'applied'
        except base.Rejected as exc:
            observed, actual_error = 'rejected', str(exc)
            result = None
        after = self.admin.snapshot()
        row = dict(action=action, expected=expected, observed=observed, error=actual_error,
                   whole_state_unchanged=before == after, lost_output=lost_output,
                   committed=observed == 'applied', response='lost_after_commit' if lost_output else 'returned')
        self.journal.append(row)
        errors = verify(self.admin.fixture, self.journal, self.admin.model.state, self.admin.state)
        self.assertions += 1
        if error is not None and error != actual_error:
            errors.append('EXACT_REJECTION_CODE')
        if errors:
            raise AssertionError((self.name, len(self.journal), errors))
        return result

    def literal(self, condition, label):
        self.assertions += 1
        if not condition:
            raise AssertionError((self.name, label))

    def record(self):
        return dict(id=self.name, status='PASS_MODEL', assertions=self.assertions,
                    fixture=self.admin.fixture, journal=self.journal, final=self.admin.snapshot())


def sale(key='S', qty=1, cash=35000, credit=False, sku=BLUSA, actor='MOCK-CAJA-A'):
    return dict(op='sale', key=key, lines=[dict(sku=sku, qty=qty)], payments={'cash': cash}, credit=credit, actor=actor)


def incident():
    return dict(op='incident', id='MOCK-I1', sku=ZERO, size='S', location='MOCK-RACK', qty=1,
                actor='MOCK-CAJA-A', shift='MOCK-SHIFT-A', moment='SYNTHETIC-CLOSE-1', sale_reference='UNPOSTED-MOCK-SALE')


def review(actor='MOCK-MANAGER', evidence='MOCK-DELIVERY-NOTE', shift='MOCK-SHIFT-A'):
    return dict(op='review', id='MOCK-I1', actor=actor, evidence=evidence, shift=shift)


def close(actor='MOCK-MANAGER', evidence='MOCK-COUNT-SHEET', counted=10000, shift='MOCK-SHIFT-A'):
    return dict(op='close', actor=actor, evidence=evidence, counted=counted, shift=shift)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    # Bound writes even if invoked with an accidentally broad output path.
    if HERE not in out.parents or out.exists():
        parser.error('--out must be a NEW directory below admin-20261105')
    out.mkdir()
    started = time.monotonic()
    sources = [HERE / 'simulate_admin.py', HERE / 'oracle.py', HERE / 'MATRIX.json', HERE / 'ACCEPTANCE.md', BASE, HERE.parent / 'results.json', HERE.parent / 'README.md', HERE.parent / 'REVIEW.md']
    hashes = {str(p): sha(p) for p in sources}
    result = dict(task_id='savia-admin-simulation-20261105', status='RUNNING', source_sha=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=HERE, text=True).strip(),
                  identity=dict(host=platform.node(), harness='T3 Code / Codex', model='gpt-6.1-sol', effective_reasoning='high', settings_evidence='runtime context and agent-awareness; independent provider telemetry unavailable', isolation=str(HERE.parents[2]), python=platform.python_version(), tokens='unknown', cost='unknown'),
                  command=subprocess.list2cmdline([sys.executable, str(HERE / 'simulate_admin.py'), '--out', str(out)]), source_hashes_before=hashes,
                  historical=dict(scenarios=18, assertions=51, rerun=False), seeds=SEEDS, generated_actions=0, cases=[], controls=[], limitations=['Sequential offline specification only', 'No SAVIA runtime, SQL, bank, fiscal, latency, backup, real staffing or operational acceptance', 'C2/C9/C10 remain open'])
    def checkpoint(c):
        result['cases'].append(c.record())
        dump(out / 'RESULT.json', result)
    try:
        c = Case('A01-cash-shortfall')
        c.step(sale(qty=2, cash=70000))
        c.step(sale('CREDIT', cash=10000, credit=True))
        c.step(dict(op='collect', key='COL', sale='MOCK-V0002', amount=5000))
        c.step(dict(op='return', key='RET', sale='MOCK-V0001', sku=BLUSA, qty=1))
        c.step(dict(op='withdraw', actor='MOCK-CAJA-A', amount=2000), 'rejected', 'forbidden_withdrawal')
        c.step(dict(op='withdraw', actor='MOCK-MANAGER', amount=2000))
        c.step(close(counted=57500))
        c.literal(c.admin.state['closes']['MOCK-SHIFT-A']['expected'] == 58000 and c.admin.state['closes']['MOCK-SHIFT-A']['difference'] == -500, '10000+70000+10000+5000-35000-2000=58000; shortage=-500')
        checkpoint(c)
        c = Case('A02-transfer-pending')
        c.step(dict(op='pending', key='T', amount=12345))
        c.literal(c.admin.state['settled_total'] == 0, 'pending_not_settled')
        c.step(dict(op='pending', key='T', amount=12345), 'replay')
        c.step(dict(op='settle', key='T'))
        c.step(dict(op='settle', key='T'), 'replay')
        c.literal(c.admin.state['settled_total'] == 12345 and c.admin.model.state['transfer'] == 0, 'one_settlement_no_bank_integration')
        checkpoint(c)
        c = Case('A03-receipt-recovery')
        c.step(dict(op='purchase', id='P', sku=BLUSA, qty=3))
        r = dict(op='receive', key='R', purchase='P', qty=2)
        c.step(r, lost_output=True)
        c.step(r, 'replay')
        c.step(dict(op='receive', key='X', purchase='P', qty=2), 'rejected', 'over_receive')
        c.step(dict(op='receive', key='R2', purchase='P', qty=1))
        c.literal(c.admin.model.state['items'][BLUSA]['stock'] == 11, 'eight_plus_three')
        checkpoint(c)
        c = Case('A04-return-recovery')
        c.step(sale(qty=2, cash=70000))
        r = dict(op='return', key='R', sale='MOCK-V0001', sku=BLUSA, qty=1)
        c.step(r, lost_output=True)
        c.step(r, 'replay')
        c.step(dict(r, key='OVER', qty=2), 'rejected', 'over_return')
        c.step(dict(r, key='R2'))
        c.literal(c.admin.model.state['cash'] == 0 and c.admin.model.state['items'][BLUSA]['stock'] == 8, 'refund_stock_literal')
        checkpoint(c)
        c = Case('A05-collection-recovery')
        c.step(sale(cash=10000, credit=True))
        r = dict(op='collect', key='C', sale='MOCK-V0001', amount=5000)
        c.step(r, lost_output=True)
        c.step(r, 'replay')
        c.step(dict(r, key='OVER', amount=20001), 'rejected', 'over_collection')
        c.step(dict(r, key='C2', amount=20000))
        c.literal(c.admin.model.state['cash'] == 35000 and c.admin.model.state['receivable']['MOCK-V0001'] == 0, 'one_full_collection')
        checkpoint(c)
        c = Case('A06-physical-zero')
        c.step(sale(sku=ZERO, cash=120000), 'rejected', 'stock_difference_requires_reconciliation')
        c.step(incident())
        c.literal(c.admin.model.state['cash'] == 0 and not c.admin.model.state['sales'] and c.admin.model.state['items'][ZERO]['stock'] == 0, 'delivery_incident_without_posting')
        checkpoint(c)
        alternatives = []
        for case_id, actor in [('A07-reviewer-present', 'MOCK-MANAGER'), ('A08-authorized-substitute', 'MOCK-SUBSTITUTE')]:
            c = Case(case_id)
            c.step(incident())
            c.step(review(actor='MOCK-CAJA-A'), 'rejected', 'forbidden_review')
            c.step(review(actor=actor))
            c.step(close(actor=actor))
            c.literal(c.admin.state['incidents']['MOCK-I1']['cause'] == 'open', 'review_not_resolution')
            alternatives.append(c.admin.snapshot())
            checkpoint(c)
        # Same inputs, only the authorized review/close actor changes. Compare quantities/money and incident.
        assert alternatives[0]['model'] == alternatives[1]['model']
        assert alternatives[0]['admin']['incidents'] == alternatives[1]['admin']['incidents']
        result['alternative_comparison'] = 'Identical fixture, delivery, evidence, counted cash, stock and money; only reviewer identity differs. No empirical strategy ranking.'
        c = Case('A09-no-reviewer-or-evidence')
        c.step(incident())
        c.step(review(actor='MOCK-UNKNOWN'), 'rejected', 'forbidden_review')
        c.step(close(actor='MOCK-UNKNOWN'), 'rejected', 'forbidden_close')
        c.step(close(evidence=''), 'rejected', 'missing_evidence')
        c.step(review(evidence=''))
        c.literal(not c.admin.state['closes'] and c.admin.state['incidents']['MOCK-I1']['cause'] == 'open', 'unresolved_not_fabricated')
        checkpoint(c)
        c = Case('A10-interrupted-operation')
        a = sale()
        first = c.step(a, lost_output=True)
        second = c.step(a, 'replay')
        c.literal(first == second and first['id'] == 'MOCK-V0001', 'same_identity_after_lost_output')
        c.step(sale(qty=2, cash=70000), 'rejected', 'idempotency_conflict')
        checkpoint(c)
        c = Case('A11-tamper-preservation')
        c.step(sale())
        c.step(close(counted=44500))
        baseline = c.admin.snapshot()
        def process_verify(name, state):
            path = out / (name + '.json')
            dump(path, dict(fixture=c.admin.fixture, journal=c.journal, state=state))
            command = [sys.executable, str(HERE / 'oracle.py'), '--input', str(path)]
            run = subprocess.run(command, capture_output=True, text=True)
            return dict(command=subprocess.list2cmdline(command), exit_code=run.returncode, stdout=run.stdout.strip(), stderr=run.stderr.strip())
        result['baseline_verifier'] = process_verify('baseline-normal', baseline)
        c.literal(result['baseline_verifier']['exit_code'] == 0, 'baseline_process_pass')
        controls = [
            ('duplicate_cash_collection', 'MONEY_CASH', lambda x: x['model'].__setitem__('cash', x['model']['cash'] + 5000)),
            ('unauthorized_close', 'CLOSE_JOURNAL_AUTHORITY', lambda x: x['admin']['closes']['MOCK-SHIFT-A'].__setitem__('actor', 'MOCK-CAJA-A')),
            ('altered_stock', 'STOCK_JOURNAL', lambda x: x['model']['items'][BLUSA].__setitem__('stock', 99)),
            ('omitted_event', 'AUDIT_JOURNAL', lambda x: x['model']['audit'].pop()),
            ('silent_balance', 'CLOSE_JOURNAL_AUTHORITY', lambda x: x['admin']['closes']['MOCK-SHIFT-A'].__setitem__('difference', 0)),
        ]
        for name, invariant, mutate in controls:
            injected = copy.deepcopy(baseline)
            mutate(injected)
            errors = verify(c.admin.fixture, c.journal, injected['model'], injected['admin'])
            process = process_verify(name, injected)
            result['controls'].append(dict(id=name, expected_invariant=invariant, detected=errors, process=process, technique='corrupted offline output copy; NOT product mutation testing'))
            c.literal(process['exit_code'] == 1 and invariant in json.loads(process['stdout'])['errors'], 'negative_control_process_' + name)
            c.literal(invariant in errors, 'negative_control_detected_' + name)
        c.literal(c.admin.snapshot() == baseline and not verify(c.admin.fixture, c.journal, c.admin.model.state, c.admin.state), 'normal_state_restored_discrepancy_retained')
        c.literal(c.admin.state['closes']['MOCK-SHIFT-A']['difference'] == -500, 'original_shortage_survives_controls')
        result['restored_verifier'] = process_verify('restored-normal', c.admin.snapshot())
        c.literal(result['restored_verifier']['exit_code'] == 0, 'restored_process_pass')
        checkpoint(c)
        c = Case('A12-actor-shift-boundaries')
        c.step(incident())
        c.step(review(shift='MOCK-SHIFT-B'), 'rejected', 'wrong_shift')
        c.step(close(actor='MOCK-CAJA-A'), 'rejected', 'forbidden_close')
        c.step(sale())
        c.step(sale(actor='MOCK-CAJA-B'), 'rejected', 'idempotency_conflict')
        c.step(close())
        c.step(close(), 'rejected', 'already_closed')
        checkpoint(c)
        # Generated sequences extend A03/A05/A10, not additional scenario families.
        result['generated'] = []
        for seed in SEEDS:
            rng = random.Random(seed)
            c = Case('generated-A03-A05-A10-seed-' + str(seed))
            c.step(sale(cash=0, credit=True))
            c.step(dict(op='purchase', id='P', sku=BLUSA, qty=100))
            remaining, received = 35000, 0
            for i in range(32):
                if rng.randrange(2):
                    amount = rng.randint(1, 8000)
                    a = dict(op='collect', key='G' + str(i), sale='MOCK-V0001', amount=amount)
                    valid = amount <= remaining
                    c.step(a, 'applied' if valid else 'rejected', None if valid else 'over_collection')
                    if valid:
                        remaining -= amount
                else:
                    qty = rng.randint(1, 9)
                    valid = received + qty <= 100
                    c.step(dict(op='receive', key='G' + str(i), purchase='P', qty=qty), 'applied' if valid else 'rejected', None if valid else 'over_receive')
                    if valid:
                        received += qty
                result['generated_actions'] += 1
            result['generated'].append(c.record())
            dump(out / 'RESULT.json', result)
        assert result['generated_actions'] <= 1024
        result.update(status='RETURNED_PASS_MODEL_NOT_ACCEPTED', exit_code=0,
                      family_count=len(result['cases']), assertions=sum(x['assertions'] for x in result['cases'] + result['generated']),
                      transitions=sum(len(x['journal']) for x in result['cases'] + result['generated']),
                      source_hashes_after={str(p): sha(p) for p in sources}, elapsed_seconds=round(time.monotonic() - started, 3))
        assert result['source_hashes_before'] == result['source_hashes_after']
        dump(out / 'RESULT.json', result)
        print(json.dumps({k: result[k] for k in ('status', 'family_count', 'assertions', 'transitions', 'generated_actions', 'exit_code')}))
    except Exception as exc:
        result.update(status='PARTIAL_FAILED', exit_code=1, failure=repr(exc))
        if 'c' in locals():
            result['failure_case'] = c.record()
        dump(out / 'RESULT.json', result)
        raise


if __name__ == '__main__':
    main()
