"""Independent projection from fixture + declared actions. Never imports Model."""
import copy
import hashlib
import json


def canonical(x):
    return json.dumps(x, sort_keys=True, ensure_ascii=False, separators=(',', ':')).encode()


def verify(fixture, journal, state, admin):
    errors = []
    def check(ok, name):
        if not ok:
            errors.append(name)
    stock = {k: v['stock'] for k, v in fixture['items'].items()}
    cash, transfer = 0, 0
    balances, sales, orders, returns, ids = {}, {}, {}, {}, {}
    events = []
    pending, settled, incidents, reviews, closes = {}, {}, {}, {}, {}
    withdrawals = 0
    for row in journal:
        a = row['action']
        op, outcome = a['op'], row['expected']
        # Expectations are fixture declarations, not taken from a model result.
        check(row['observed'] == outcome, 'OUTCOME')
        if outcome != 'applied':
            check(row['whole_state_unchanged'], 'REJECT_OR_REPLAY_ATOMIC')
            continue
        if op == 'sale':
            sid = 'MOCK-V%04d' % (len(sales) + 1)
            total = sum(fixture['items'][x['sku']]['price'] * x['qty'] for x in a['lines'])
            sales[sid] = copy.deepcopy(a)
            balances[sid] = total - sum(a['payments'].values())
            ids[a['key']] = sid
            for line in a['lines']:
                stock[line['sku']] -= line['qty']
            cash += a['payments'].get('cash', 0)
            transfer += a['payments'].get('transfer', 0)
            events.append(('sale', a.get('actor', 'MOCK-CAJA-A'), {'id': sid, 'key': a['key'], 'total': total}))
        elif op == 'purchase':
            orders[a['id']] = dict(sku=a['sku'], ordered=a['qty'], received=0)
            events.append(('purchase', 'MOCK-INVENTARIO', {'id': a['id'], 'qty': a['qty']}))
        elif op == 'receive':
            order = orders[a['purchase']]
            order['received'] += a['qty']
            check(0 < order['received'] <= order['ordered'], 'RECEIPT_LIMIT')
            stock[order['sku']] += a['qty']
            events.append(('receive', 'MOCK-INVENTARIO', {'order': a['purchase'], 'qty': a['qty'], 'key': a['key']}))
        elif op == 'return':
            unit = fixture['items'][a['sku']]['price']
            amount = unit * a['qty']
            rk = (a['sale'], a['sku'])
            returns[rk] = returns.get(rk, 0) + a['qty']
            sold = sum(x['qty'] for x in sales[a['sale']]['lines'] if x['sku'] == a['sku'])
            check(returns[rk] <= sold, 'RETURN_LIMIT')
            stock[a['sku']] += a['qty']
            cash -= amount
            events.append(('return', 'MOCK-MANAGER', {'sale': a['sale'], 'sku': a['sku'], 'qty': a['qty'], 'refund': amount}))
        elif op == 'collect':
            cash += a['amount']
            balances[a['sale']] -= a['amount']
            check(balances[a['sale']] >= 0, 'RECEIVABLE_NONNEGATIVE')
            events.append(('collection', 'MOCK-CAJA-A', {'sale': a['sale'], 'amount': a['amount']}))
        elif op == 'pending':
            pending[a['key']] = a['amount']
        elif op == 'settle':
            settled[a['key']] = pending[a['key']]
        elif op == 'withdraw':
            check(a['actor'] in fixture['withdrawers'], 'WITHDRAW_AUTHORITY')
            withdrawals += a['amount']
        elif op == 'incident':
            incidents[a['id']] = {k: a[k] for k in ('sku', 'size', 'location', 'qty', 'actor', 'shift', 'moment', 'sale_reference')}
            incidents[a['id']].update(cause='open', owner='MOCK-REVIEW-QUEUE', next_review='NEXT-CLOSE-ASSUMPTION', delivered=True, financial_posting=False, stock_posting=False)
        elif op == 'review':
            inc = incidents[a['id']]
            check(a['actor'] in fixture['reviewers'] and a['actor'] != inc['actor'], 'REVIEW_AUTHORITY')
            check(a['shift'] == inc['shift'], 'SHIFT_BOUNDARY')
            reviews[a['id']] = {k: a[k] for k in ('actor', 'evidence', 'shift')}
            # Review is not cause resolution. Even evidence here only supports review.
        elif op == 'close':
            check(a['actor'] in fixture['reviewers'] and a['actor'] != fixture['cashier'], 'CLOSE_AUTHORITY')
            check(bool(a['evidence']), 'CLOSE_EVIDENCE')
            expected_cash = fixture['opening'] + cash - withdrawals
            closes[a['shift']] = dict(actor=a['actor'], evidence=a['evidence'], counted=a['counted'], expected=expected_cash, difference=a['counted'] - expected_cash, cause='open' if a['counted'] != expected_cash else 'no_cash_difference')
    check(state['cash'] == cash, 'MONEY_CASH')
    check(state['transfer'] == transfer, 'MONEY_MODEL_TRANSFER')
    check({k: v['stock'] for k, v in state['items'].items()} == stock, 'STOCK_JOURNAL')
    check(state['receivable'] == balances, 'RECEIVABLE_JOURNAL')
    check(len(state['sales']) == len(sales), 'SALE_UNIQUENESS')
    check(len(state['operations']) == len(ids), 'OPERATION_UNIQUENESS')
    check([(e['kind'], e['actor'], e['payload']) for e in state['audit']] == events, 'AUDIT_JOURNAL')
    previous = '0' * 64
    for n, e in enumerate(state['audit'], 1):
        body = {k: v for k, v in e.items() if k != 'hash'}
        check(e['sequence'] == n and e['previous'] == previous and e['hash'] == hashlib.sha256(canonical(body)).hexdigest(), 'AUDIT_CHAIN')
        previous = e['hash']
    check(admin['pending'] == pending and admin['settled'] == settled, 'TRANSFER_JOURNAL')
    check(admin['settled_total'] == sum(settled.values()), 'TRANSFER_UNIQUENESS')
    check(admin['withdrawals'] == withdrawals, 'WITHDRAW_JOURNAL')
    check(admin['incidents'] == incidents, 'INCIDENT_PRESERVATION')
    check(admin['reviews'] == reviews, 'REVIEW_JOURNAL_AUTHORITY')
    check(admin['closes'] == closes, 'CLOSE_JOURNAL_AUTHORITY')
    check(admin['audit'] == [r['action'] for r in journal if r['expected'] == 'applied' and r['action']['op'] in ('pending', 'settle', 'withdraw', 'incident', 'review', 'close')], 'ADMIN_AUDIT')
    return sorted(set(errors))


if __name__ == '__main__':
    import argparse
    from pathlib import Path
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=Path, required=True)
    args = parser.parse_args()
    data = json.loads(args.input.read_text(encoding='utf-8'))
    errors = verify(data['fixture'], data['journal'], data['state']['model'], data['state']['admin'])
    print(json.dumps(dict(errors=errors, status='FAIL' if errors else 'PASS')))
    raise SystemExit(1 if errors else 0)
