#!/usr/bin/env python3
"""Arnés del camino dorado (C5): API real + SQL Server desechable + oráculos SQL.

Uso:  python3 tests/golden-path/golden_path.py --out DIR [--mode smoke|serve|browser] [--no-build]
Requiere MARTHA_TEST_SQL_CONNECTION (servidor desechable; la base indicada se ignora).
Solo biblioteca estándar de Python y el SDK .NET fijado en global.json. Linux/macOS (usa pty).

Nunca escribe en la salida ni en la evidencia: contraseñas, cookies, tokens CSRF ni la conexión.
Ver tests/golden-path/README.md.
"""
import argparse
import base64
try:
    import fcntl
except ImportError:
    fcntl = None
import hashlib
import http.client
import json
import os
try:
    import pty
except ImportError:
    pty = None
import re
import secrets
import select
import shutil
import signal
import socket
import ssl
import subprocess
import sys
import tempfile
try:
    import termios
except ImportError:
    termios = None
import time
try:
    import tty
except ImportError:
    tty = None
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
API_PROJECT = ROOT / 'backend/src/Martha.Store.Api'
HELPER_PROJECT = ROOT / 'tests/golden-path/GoldenPath.Sql'
DATABASE_PATTERN = re.compile(r'\ASaviaInternalTest_Golden_[a-f0-9]{32}\Z')
MIGRATIONS = ('20261025085402_InitialInternalSavia', '20261027224500_InternalBranchScope',
              '20261106071201_PhysicalStockException', '20261107221938_FirstCashRegister')
EXPECTED_MIGRATIONS = len(MIGRATIONS)
SEED_STOCK = 10
SALE_QUANTITY = 2
ITEMS = [('SINTETICO-GOLDEN-01', 'SINTETICO Golden artículo 1', 1250),
         ('SINTETICO-GOLDEN-02', 'SINTETICO Golden artículo 2', 3400),
         ('SINTETICO-GOLDEN-03', 'SINTETICO Golden artículo 3', 990)]
ROLES = ['Owner', 'Manager', 'Cashier', 'Inventory', 'Unassigned', 'Cashier2']
# Invariants that must hold after EVERY step once the schema exists.
ALWAYS_ZERO = ['exception_movements', 'lines_without_exactly_one_movement', 'sale_movements_not_matching_a_line',
               'balance_vs_movement_sum_mismatch', 'balance_vs_last_movement_mismatch',
               'negative_or_invalid_stock', 'negative_movement_after', 'duplicate_idempotency_keys',
               'items_without_synthetic_marker', 'receipt_movement_mismatch', 'orphan_receipt_movement', 'receipt_order_mismatch']
TABLE_COLUMNS = [('sales', 'ventas'), ('sale_operations', 'ops_venta'), ('movements', 'movs'),
                 ('sale_movements', 'movs_venta'), ('on_hand_total', 'existencia'),
                 ('balance_vs_movement_sum_mismatch', 'Σmov≠saldo'), ('negative_or_invalid_stock', 'negativos'),
                 ('duplicate_idempotency_keys', 'claves_dup'), ('active_sessions', 'sesiones')]
BROWSER_SCRIPT = ROOT / 'tests/golden-path/browser_path.mjs'
BROWSER_SOURCES = ['dev/savia-staff-ui/' + name for name in
                   ('app.mjs', 'client.mjs', 'login.mjs', 'login.html', 'index.html', 'styles.css', 'supply.mjs', 'cash.mjs')]
BROWSER_STEPS = ('browser.start', 'browser.cashier_login', 'browser.inventory',
                 'browser.sale_confirmed', 'browser.receipt_reload', 'browser.stock_after_sale',
                 'browser.response_loss_committed', 'browser.recover_after_reload',
                 'browser.repeated_reload', 'browser.stock_after_recovery', 'browser.logout')
BROWSER_READ_ONLY = ('sales', 'sale_lines', 'sale_movements', 'sale_operations',
                     'movements', 'operations', 'on_hand_total')
BROWSER_DOM = dict(zip(BROWSER_STEPS, (
    {'login_ready'}, {'shell', 'cashier', 'sale_enabled'}, {'inventory', 'stock_current'},
    {'receipt', 'sale_enabled'}, {'receipt', 'same_receipt', 'sale_enabled'}, {'inventory', 'stock_current'},
    {'pending', 'pending_key_preserved'}, {'receipt', 'same_receipt', 'sale_enabled'},
    {'receipt', 'same_receipt', 'sale_enabled'}, {'inventory', 'stock_current'}, {'logged_out'})))
STOCK_STEPS = ('browser.stock_sale', 'browser.stock_reload', 'browser.stock_review', 'browser.stock_review_reload', 'browser.stock_logout')
SUPPLY_STEPS = ('browser.supply_login', 'browser.supply_partial', 'browser.supply_loss',
                'browser.supply_recovered', 'browser.supply_reload', 'browser.supply_logout')
BROWSER_DOM.update({name: {'logged_out'} if name.endswith('logout') else {'shell'} for name in STOCK_STEPS})
BROWSER_DOM.update({name: {'logged_out'} if name.endswith('logout') else {'shell'} for name in SUPPLY_STEPS})

CASH_PROTOCOL = 'real-cash-v1'
CASH_OPEN = 'browser.cash_open'
CASH_TAIL = ('browser.cash_second_till', 'browser.cash_refund_refused', 'browser.cash_refunded',
             'browser.cash_closed_short', 'browser.cash_later_till', 'browser.cash_later_refund',
             'browser.cash_later_close', 'browser.cash_logout')
CASH_STEPS = (*BROWSER_STEPS[:2], CASH_OPEN, *BROWSER_STEPS[2:], *SUPPLY_STEPS, *STOCK_STEPS, *CASH_TAIL)
BROWSER_DOM.update({name: {'logged_out'} if name.endswith('logout') else {'shell'} for name in (CASH_OPEN, *CASH_TAIL)})


def supply_expected(step):
    """Independent fixture arithmetic: order 5 units at 700; deliveries 2 then 3.

    Sale path already left 25 units, 2 sales, 4 sale movements and 3 adjustments.
    Recovery changes no quantities or command/receipt counts.
    """
    expect(step in SUPPLY_STEPS, 'supply_unknown_step')
    n = 0 if step == SUPPLY_STEPS[0] else 1 if step == SUPPLY_STEPS[1] else 2
    received = (0, 2, 5)[n]
    return {'purchase_orders': 1, 'purchase_lines': 1, 'purchase_quantity': 5,
            'purchase_total': 3500, 'purchase_received': received,
            'purchase_open': int(n == 0), 'purchase_partial': int(n == 1), 'purchase_complete': int(n == 2),
            'purchase_receipts': n, 'purchase_receipt_lines': n, 'purchase_receipt_total': received * 700,
            'purchase_movements': n, 'purchase_operations': 1, 'receipt_operations': n,
            'sales': 2, 'sale_lines': 4, 'sale_movements': 4, 'sale_operations': 2,
            'movements': 7 + n, 'on_hand_total': 25 + received,
            'active_sessions': int(step != SUPPLY_STEPS[-1])}


def supply_identity(notes, fixture, previous, step):
    """Validate sanitized evidence against the owned fixture, never against product calculations."""
    expect(notes.get('order_id') == fixture['id'] and notes.get('actor_id') == fixture['actor']
           and notes.get('location_id') == fixture['locationId'], 'supply_attribution_mismatch')
    if step in SUPPLY_STEPS[1:5]:
        expect(all(UUID_PATTERN.fullmatch(notes.get(k, '')) for k in ('key', 'receipt_id')), 'supply_identity_invalid')
        if step in SUPPLY_STEPS[3:5]:
            expect(all(notes.get(k) == previous.get(k) for k in ('key', 'receipt_id')), 'supply_pending_identity_mismatch')
        if step == SUPPLY_STEPS[2]:
            expect(all(notes.get(k) != previous.get(k) for k in ('key', 'receipt_id')), 'supply_duplicate_identity')
    n = 0 if step == SUPPLY_STEPS[0] else 1 if step == SUPPLY_STEPS[1] else 2
    expect(notes.get('receipt_posts') == n, 'supply_repost')
    return notes


UUID_PATTERN = re.compile(r'\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\Z')


BROWSER_NOTE_FIELDS = {'dom', 'network', 'sale_posts', 'stock_total', 'stock_rows', 'quantity', 'total_minor',
               'key', 'sale_id', 'runtime', 'source_hashes', 'external_requests', 'runtime_errors', 'receipt_posts', 'receipt_id', 'order_id', 'actor_id', 'location_id', 'review_id', 'review_key', 'sale_line_id', 'cash_commands', 'cash_pending_hash'}


def browser_checkpoint(event, expected_step, secrets_seen):
    """An untrusted subprocess cannot add arbitrary strings to public evidence.

    Secret values travel only through the private pipe and join the existing final scanner.
    The rest of the protocol is an allowlist of fixed labels, counts, UUIDs and hashes.
    """
    def valid(condition):
        expect(condition, 'browser_protocol_invalid')
    valid(isinstance(event, dict) and set(event) == {'step', 'notes', 'secrets'})
    valid(event['step'] == expected_step)
    valid(isinstance(event['secrets'], list) and len(event['secrets']) <= 100)
    valid(all(isinstance(value, str) and len(value) <= 8192 for value in event['secrets']))
    secrets_seen.update(event['secrets'])
    notes = event['notes']
    if isinstance(notes, dict) and 'cash_commands' in notes:
        cash_commands(notes['cash_commands'])
        if 'cash_pending_hash' in notes:
            valid(isinstance(notes['cash_pending_hash'], str) and re.fullmatch(r'[a-f0-9]{64}', notes['cash_pending_hash']))
    valid(isinstance(notes, dict) and set(notes) <= BROWSER_NOTE_FIELDS
          and {'dom', 'network', 'sale_posts', 'external_requests', 'runtime_errors'} <= set(notes))
    dom_labels = {'login_ready', 'shell', 'cashier', 'inventory', 'receipt', 'pending',
                  'sale_enabled', 'pending_key_preserved', 'same_receipt', 'stock_current', 'logged_out'}
    required_dom = ({'shell'} if 'cash_commands' in notes and expected_step in ('browser.cashier_login', 'browser.receipt_reload', 'browser.repeated_reload', 'browser.stock_reload') else BROWSER_DOM[expected_step])
    valid(isinstance(notes['dom'], list) and all(value in dom_labels for value in notes['dom'])
          and required_dom <= set(notes['dom']))
    for key in ('sale_posts', 'stock_total', 'stock_rows', 'quantity', 'total_minor', 'external_requests', 'runtime_errors', 'receipt_posts'):
        if key in notes:
            valid(type(notes[key]) is int and 0 <= notes[key] <= 100000)
    for key in ('key', 'sale_id', 'receipt_id', 'order_id', 'actor_id', 'location_id', 'review_id', 'review_key', 'sale_line_id'):
        if key in notes:
            valid(isinstance(notes[key], str) and UUID_PATTERN.fullmatch(notes[key]) is not None)
    if 'runtime' in notes:
        valid(isinstance(notes['runtime'], dict) and set(notes['runtime']) == {'chrome', 'node', 'playwright'})
        valid(all(isinstance(v, str) and re.fullmatch(r'[A-Za-z0-9 .()_/-]{1,120}', v)
                  for v in notes['runtime'].values()))
    if 'source_hashes' in notes:
        valid(isinstance(notes['source_hashes'], dict) and set(notes['source_hashes']) == set(BROWSER_SOURCES))
        valid(all(isinstance(v, str) and re.fullmatch(r'[a-f0-9]{64}', v) for v in notes['source_hashes'].values()))
    paths = {'/internal/login', '/internal/', '/internal/app.mjs', '/internal/client.mjs',
             '/internal/login.mjs', '/internal/styles.css', '/internal/supply.mjs', '/internal/cash.mjs', '/internal/api/cash/context',
             '/internal/api/cash/tills', '/internal/api/cash/sales',
             '/internal/api/operations/cash.sale', '/internal/api/operations/cash.till.open',
             '/internal/api/operations/cash.refund', '/internal/api/operations/cash.till.close', '/internal/api/security/csrf',
             '/internal/api/security/login', '/internal/api/security/me', '/internal/api/security/logout',
             '/internal/api/directory/items', '/internal/api/directory/locations',
             '/internal/api/commerce/inventory', '/internal/api/commerce/sales',
             '/internal/api/operations/commerce.sale.record', '/internal/api/operations/supply.receipt.create',
             '/internal/api/supply/purchase-orders'}
    valid(isinstance(notes['network'], list) and len(notes['network']) <= 200)
    for request in notes['network']:
        valid(isinstance(request, dict) and set(request) == {'method', 'path', 'status', 'key', 'response_lost'})
        valid(request['method'] in ('GET', 'POST'))
        path = request['path']
        valid(isinstance(path, str) and (path in paths or re.fullmatch(r'/internal/api/cash/(?:sales/[0-9a-f-]{36}/(?:refunds|refund-context)|tills/[0-9a-f-]{36}/close)', path) or (path.startswith('/internal/api/commerce/sales/')
              and (UUID_PATTERN.fullmatch(path.rsplit('/', 1)[-1]) is not None or re.fullmatch(r'/internal/api/commerce/sales/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/stock-reviews',path))) or re.fullmatch(
                  r'/internal/api/supply/purchase-orders/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}(?:/receipts)?', path)))
        valid(request['status'] is None or (type(request['status']) is int and 100 <= request['status'] <= 599))
        valid(type(request['response_lost']) is bool)
        valid(request['key'] is None or (isinstance(request['key'], str) and UUID_PATTERN.fullmatch(request['key']) is not None))
    return notes


CASH_ORACLES = ('identities', 'amounts', 'unique_effects', 'stock_links', 'refund_links',
                'close_sum', 'preserved_rows', 'operation_requests')
CASH_LENGTHS = {name: (0 if i<2 else 1 if i<4 else 2 if i<7 else 3 if i<18 else 4 if i<23 else
                              (5,5,6,7,8,9,10,10)[i-23]) for i,name in enumerate(CASH_STEPS)}


def cash_commands(commands):
    expect(isinstance(commands, list) and len(commands) <= 10, 'cash_commands_invalid')
    for c in commands:
        expect(isinstance(c, dict) and set(c) == {'kind','actor','key','body','result_id','effect_id'}, 'cash_commands_invalid')
        expect(c['kind'] in ('open','sale','refund','close'), 'cash_commands_invalid')
        expect(all(isinstance(c[k], str) and UUID_PATTERN.fullmatch(c[k]) for k in ('actor','key','result_id','effect_id')), 'cash_commands_invalid')
        b=c['body']; expect(isinstance(b,dict), 'cash_commands_invalid')
        fields={'open': {'locationId','currency','openingMinor'}, 'sale': {'tillId','customerId','lines','currency','receivedMinor'},
                'refund': {'saleId','payingTillId','currency','reason','lines'}, 'close': {'tillId','countedMinor'}}[c['kind']]
        expect(set(b)==fields, 'cash_commands_invalid')
        for k,v in b.items():
            if k in ('locationId','tillId','saleId','payingTillId'): expect(isinstance(v,str) and UUID_PATTERN.fullmatch(v), 'cash_commands_invalid')
            elif k=='currency': expect(v=='USD','cash_commands_invalid')
            elif k=='customerId': expect(v is None,'cash_commands_invalid')
            elif k=='reason': expect(v=='SINTETICO cash return','cash_commands_invalid')
            elif k=='lines':
                expect(isinstance(v,list) and 1<=len(v)<=2,'cash_commands_invalid')
                for line in v:
                    expect(isinstance(line,dict) and set(line) in ({'itemId','quantity'}, {'saleLineId','quantity'}, {'itemId','quantity','exceptionReason','size'}),'cash_commands_invalid')
                    expect(type(line.get('quantity')) is int and 1<=line['quantity']<=2,'cash_commands_invalid')
                    for key,value in line.items():
                        if key.endswith('Id'): expect(isinstance(value,str) and UUID_PATTERN.fullmatch(value),'cash_commands_invalid')
                        if key=='size': expect(value=='S','cash_commands_invalid')
                        if key=='exceptionReason': expect(value=='SINTETICO physical garment present','cash_commands_invalid')
            else: expect(type(v) is int and 0<=v<=100000,'cash_commands_invalid')
    expect(len({c['key'] for c in commands})==len(commands), 'cash_duplicate_key')
    return commands


def _cash_counts(step):
    n=CASH_STEPS.index(step)
    if step in SUPPLY_STEPS: return supply_expected(step)
    if step in STOCK_STEPS: return {'sales':3,'sale_lines':5,'sale_movements':4,'sale_operations':3,
        'exception_lines':1,'stock_reviews':int(STOCK_STEPS.index(step)>=2),'exception_movements':0,'movements':9,'on_hand_total':30}
    if step in CASH_TAIL:
        refunds=int(CASH_TAIL.index(step)>=2)+int(CASH_TAIL.index(step)>=5)
        return {'sales':3,'sale_lines':5,'sale_movements':4,'sale_operations':3,'stock_reviews':1,
                'exception_movements':0,'on_hand_total':30+refunds,'movements':9+refunds}
    sales=2 if n>=CASH_STEPS.index('browser.response_loss_committed') else int(n>=CASH_STEPS.index('browser.sale_confirmed'))
    return {'sales':sales,'sale_lines':2*sales,'sale_movements':2*sales,'sale_operations':sales,
            'movements':3+2*sales,'on_hand_total':30-(0 if sales==0 else 3 if sales==1 else 5)}


def cash_counts(step):
    return {**_cash_counts(step), 'active_sessions':0 if step=='browser.start' or step.endswith('logout') else 1}


def validate_cash_snapshot(commands, snap, users, ids, prior, step):
    """Independent row oracle. Expected values originate in frozen requests/fixtures, never receipts."""
    cash_commands(commands)
    expect(len(commands)==CASH_LENGTHS[step], 'cash_command_sequence')
    expect(snap.get('ok') is True and isinstance(snap.get('rows'),dict) and isinstance(snap.get('hashes'),dict), 'cash_snapshot_invalid')
    rows=snap['rows']
    # SQL FOR JSON and API Guid formatting may differ in letter case.
    for table in rows.values():
        for row in table:
            for key,value in row.items():
                if isinstance(value,str) and UUID_PATTERN.fullmatch(value.lower()): row[key]=value.lower()
    entries=rows['CashEntries']; tills=rows['CashTills']; closes=rows['CashCloses']
    for table in ('CashEntries','CashCloses','Sales','SaleLines','SaleReversals','SaleReversalLines'):
        for row in rows[table]:
            expect(all(type(v) is int for k,v in row.items() if k.endswith('Minor') or k in ('Quantity','ReturnedQuantity','Exponent')), 'cash_integer_amount')
    ops=rows['Operations']; sales=rows['Sales']; lines=rows['SaleLines']; moves=rows['StockMovements']
    def one(table, **criteria):
        found=[r for r in table if all(r.get(k)==v for k,v in criteria.items())]
        expect(len(found)==1,'cash_row_identity'); return found[0]
    plan=[('open','Cashier'),('sale','Cashier'),('sale','Cashier'),('sale','Cashier'),('open','Cashier2'),
          ('refund','Manager'),('close','Cashier'),('open','Cashier'),('refund','Manager'),('close','Cashier')]
    expect(len(ops)==len(commands) and len(entries)==sum(c['kind']!='close' for c in commands)
           and len(tills)==sum(c['kind']=='open' for c in commands) and len(closes)==sum(c['kind']=='close' for c in commands), 'cash_duplicate_effect')
    for i,c in enumerate(commands):
        kind,role=plan[i]; b=c['body']; actor=users[role]['id']
        expect(c['kind']==kind and c['actor']==actor,'cash_actor_identity')
        scope={'open':'cash.till.open','sale':'cash.sale','refund':'cash.refund','close':'cash.till.close'}[kind]
        op=one(ops,ActorId=actor,Scope=scope,Key=c['key'],ResultId=c['result_id'],EffectId=c['effect_id'])
        # Reproduce the public contract's JSON serialization, not a handler's calculation.
        pascal=lambda body: {k[0].upper()+k[1:]: ([pascal(x) for x in v] if isinstance(v,list) else v) for k,v in body.items()}
        request={k:v for k,v in b.items() if not (kind=='refund' and k=='saleId') and not (kind=='close' and k=='tillId')}
        serialized=pascal(request)
        if kind=='refund': serialized={'saleId':b['saleId'],'request':serialized}
        if kind=='close': serialized={'tillId':b['tillId'],'request':serialized}
        fingerprint=hashlib.sha256(json.dumps(serialized,separators=(',',':'),ensure_ascii=True).encode()).hexdigest().upper()
        expect(op['Fingerprint']==fingerprint,'cash_request_binding')
        if kind=='open':
            amount=(10000,20000,10000)[[0,4,7].index(i)]
            expect(b=={'locationId':ids['location'],'currency':'USD','openingMinor':amount},'cash_open_request')
            t=one(tills,Id=c['result_id'],CashierId=actor,LocationId=ids['location'],Currency='USD',Exponent=2)
            e=one(entries,Id=c['effect_id'],TillId=t['Id'],CashierId=actor,ActorId=actor,Kind='opening',DeltaMinor=amount,ReceivedMinor=0,ChangeMinor=0,SaleId=None,ReversalId=None)
        else:
            till_id=commands[7 if i>=8 else 0]['result_id']
            expect(b.get('tillId',b.get('payingTillId'))==till_id,'cash_paying_till_identity')
            t=one(tills,Id=till_id,CashierId=users['Cashier']['id'],LocationId=ids['location'],Currency='USD',Exponent=2)
            if kind=='sale':
                quantity=2 if i==1 else 1
                expected_lines=([{'itemId':ids['exception_item'],'quantity':1,'exceptionReason':'SINTETICO physical garment present','size':'S'}] if i==3 else
                    [{'itemId':ids['items'][0],'quantity':quantity},{'itemId':ids['items'][1],'quantity':1}])
                total=1250 if i==3 else quantity*1250+3400
                tender={1:6000,2:5000,3:2000}[i]
                expect(b=={'tillId':till_id,'customerId':None,'lines':expected_lines,'currency':'USD','receivedMinor':tender},'cash_sale_request')
                sale=one(sales,Id=c['result_id'],ActorId=actor,LocationId=ids['location'],Currency='USD',TotalMinor=total,CustomerId=None)
                actual=[l for l in lines if l['SaleId']==sale['Id']]; expect(len(actual)==len(expected_lines),'cash_sale_lines')
                for line in expected_lines:
                    price=3400 if line['itemId']==ids['items'][1] else 1250
                    l=one(actual,ItemId=line['itemId'],Quantity=line['quantity'],UnitPriceMinor=price,TotalMinor=price*line['quantity'])
                    expected_returned=sum(x['kind']=='refund' for x in commands) if i==1 and line['itemId']==ids['items'][0] else 0
                    expect(l['ReturnedQuantity']==expected_returned,'cash_return_quantity')
                    debit=[m for m in moves if m['OperationId']==sale['Id'] and m['ItemId']==line['itemId'] and m['Kind']=='sale']
                    if i==3: expect(not debit,'cash_fabricated_inventory')
                    else: one(debit,ActorId=actor,LocationId=ids['location'],OnHandDelta=-line['quantity'],ReservedDelta=0)
                expected_state = ('returned' if all(l['ReturnedQuantity']==l['Quantity'] for l in actual)
                                  else 'partially_returned' if any(l['ReturnedQuantity'] for l in actual) else 'recorded')
                expect(sale.get('State') == expected_state, 'cash_sale_state')
                e=one(entries,Id=c['effect_id'],TillId=till_id,ActorId=actor,CashierId=actor,Kind='sale',SaleId=sale['Id'],DeltaMinor=total,ReceivedMinor=tender,ChangeMinor=tender-total,ReversalId=None)
            elif kind=='refund':
                original=one(lines,SaleId=commands[1]['result_id'],ItemId=ids['items'][0])
                expect(b=={'saleId':commands[1]['result_id'],'payingTillId':till_id,'currency':'USD','reason':'SINTETICO cash return','lines':[{'saleLineId':original['Id'],'quantity':1}]},'cash_refund_request')
                r=one(rows['SaleReversals'],Id=c['result_id'],SaleId=b['saleId'],ActorId=actor,Kind='return',Reason=b['reason'],RecordedCreditMinor=1250)
                one(rows['SaleReversalLines'],ReversalId=r['Id'],SaleLineId=original['Id'],Quantity=1,RecordedCreditMinor=1250)
                one(moves,OperationId=r['Id'],ItemId=original['ItemId'],LocationId=ids['location'],ActorId=actor,Kind='sale_return',OnHandDelta=1,ReservedDelta=0)
                e=one(entries,Id=c['effect_id'],TillId=till_id,CashierId=users['Cashier']['id'],ActorId=actor,Kind='refund',SaleId=b['saleId'],ReversalId=r['Id'],DeltaMinor=-1250,ReceivedMinor=0,ChangeMinor=0)
            else:
                expected=20550 if i==6 else 8750; counted=expected-100 if i==6 else expected
                expect(b['countedMinor']==counted and t['ClosedAt'] is not None,'cash_close_request')
                # Earlier close sums only entries that existed at its time. Closed till must never receive later entries.
                total=sum(e['DeltaMinor'] for e in entries if e['TillId']==till_id)
                expect(total==expected,'cash_independent_sum')
                one(closes,Id=c['effect_id'],TillId=till_id,ActorId=actor,ExpectedMinor=total,CountedMinor=counted,DifferenceMinor=counted-total)
                continue
        expect(e['Currency']=='USD' and e['Exponent']==2,'cash_currency_identity')
    stage=CASH_STEPS.index(step)
    supplied=0 if stage<CASH_STEPS.index(SUPPLY_STEPS[1]) else 2 if stage<CASH_STEPS.index(SUPPLY_STEPS[2]) else 5
    sold=sum(c['kind']=='sale' for c in commands)
    refunds=sum(c['kind']=='refund' for c in commands)
    expect(len(rows['StockBalances'])==len(ids['items'])==3,'cash_fabricated_inventory')
    for item,expected in ((ids['items'][0],10-(0 if sold==0 else 2 if sold==1 else 3)+supplied+refunds),(ids['items'][1],10-min(sold,2)),(ids['items'][2],10)):
        one(rows['StockBalances'],ItemId=item,LocationId=ids['location'],OnHand=expected,Reserved=0)
    expect(not any(b['ItemId']==ids['exception_item'] for b in rows['StockBalances']), 'cash_fabricated_inventory')
    expect(len(rows['SaleReversals'])==len(rows['SaleReversalLines'])==refunds,'cash_refund_duplicate')
    if len(commands)>=2:
        original=one(lines,SaleId=commands[1]['result_id'],ItemId=ids['items'][0])
        expect(original['ReturnedQuantity']==refunds,'cash_return_quantity')
    if prior:
        changed={'open':{'CashTills','CashEntries','Operations'}, 'sale':{'Sales','SaleLines','StockMovements','StockBalances','CashEntries','Operations'},
                 'refund':{'Sales','SaleLines','SaleReversals','SaleReversalLines','StockMovements','StockBalances','CashEntries','Operations'},'close':{'CashTills','CashCloses','Operations'}}
        previous_count=len(prior['rows']['Operations'])
        allowed=changed[commands[-1]['kind']] if len(commands)>previous_count else set()
        if step in SUPPLY_STEPS[1:3]: allowed={'Operations','PurchaseReceipts','PurchaseReceiptLines','PurchaseOrderLines','PurchaseOrders','StockMovements','StockBalances'}
        if step=='browser.stock_review': allowed={'Operations','StockExceptionReviews'}
        for table,hashes in prior['hashes'].items():
            if table not in allowed: expect(snap['hashes'][table]==hashes,'cash_unrelated_rows_changed')
        # Immutable ledger/earlier close and another cashier's till survive every command.
        for table in ('CashEntries','CashCloses','Operations','StockMovements','SaleReversals','SaleReversalLines','StockExceptionReviews','PurchaseReceipts','PurchaseReceiptLines'):
            expect(set(prior['hashes'][table])<=set(snap['hashes'][table]),'cash_history_changed')
        added=commands[previous_count:]
        returned_sales={c['body']['saleId'] for c in added if c['kind']=='refund'}
        returned_lines={l['saleLineId'] for c in added if c['kind']=='refund' for l in c['body']['lines']}
        closing={c['body']['tillId'] for c in added if c['kind']=='close'}
        affected_items={l['itemId'] for c in added if c['kind']=='sale' for l in c['body']['lines']}
        affected_items|={l['ItemId'] for l in rows['SaleLines'] if l['Id'] in returned_lines}
        if step in SUPPLY_STEPS[1:3]: affected_items.add(ids['items'][0])
        for table,excluded in (('Sales',returned_sales),('SaleLines',returned_lines),('CashTills',closing)):
            for old in prior['rows'][table]:
                if old['Id'] not in excluded:
                    expect(old in rows[table],'cash_unrelated_row_changed')
                else:
                    # Refunds may change quantity/state; every other persisted field is immutable.
                    mutable = {'Sales':{'State'}, 'SaleLines':{'ReturnedQuantity'}, 'CashTills':{'ClosedAt'}}[table]
                    current = one(rows[table], Id=old['Id'])
                    project = lambda row: {k:v for k,v in row.items() if k not in mutable}
                    expect(project(old) == project(current), 'cash_immutable_row_changed')
        for old in prior['rows']['StockBalances']:
            if old['ItemId'] not in affected_items: expect(old in rows['StockBalances'],'cash_unrelated_row_changed')
        for t in prior['rows']['CashTills']:
            if t['ClosedAt'] is not None or t['CashierId']==users['Cashier2']['id']:
                expect(t in tills,'cash_other_shift_changed')
    return {**{k:True for k in CASH_ORACLES}, 'money': cash_money(rows)}


def cash_money(rows):
    fields={'CashEntries':('Id','TillId','CashierId','ActorId','Kind','DeltaMinor','ReceivedMinor','ChangeMinor','SaleId','ReversalId'),
            'CashCloses':('Id','TillId','ActorId','ExpectedMinor','CountedMinor','DifferenceMinor'),
            'CashTills':('Id','CashierId','LocationId','Currency','Exponent')}
    return {table:[{k:r[k] for k in columns} for r in rows[table]] for table,columns in fields.items()}


def validate_cash_money(commands, money):
    expect(isinstance(money,dict) and set(money)=={'CashEntries','CashCloses','CashTills'},'cash_money_missing')
    expected_entries=[]; expected_closes=[]; expected_tills=[]
    for i,c in enumerate(commands):
        b=c['body']; kind=c['kind']; actor=c['actor']
        if kind=='open':
            expected_tills.append({'Id':c['result_id'],'CashierId':actor,'LocationId':b['locationId'],'Currency':'USD','Exponent':2})
            till=c['result_id'];cashier=actor;delta=(10000 if i!=4 else 20000);received=change=0;sale=reversal=None
            expect(b['openingMinor']==delta,'cash_opening_altered')
        else:
            till=commands[7 if i>=8 else 0]['result_id'];cashier=commands[0]['actor']
            expect(b.get('tillId',b.get('payingTillId'))==till,'cash_till_altered')
            if kind=='close':
                total=sum(e['DeltaMinor'] for e in expected_entries if e['TillId']==till)
                count=b['countedMinor']; difference=count-total
                expect(difference==(-100 if i==6 else 0),'cash_arithmetic_invalid')
                expected_closes.append({'Id':c['effect_id'],'TillId':till,'ActorId':actor,'ExpectedMinor':total,'CountedMinor':count,'DifferenceMinor':difference})
                continue
            if kind=='sale':
                delta={1:5900,2:4650,3:1250}[i];received={1:6000,2:5000,3:2000}[i];change=received-delta;sale=c['result_id'];reversal=None
            else:
                delta=-1250;received=change=0;sale=commands[1]['result_id'];reversal=c['result_id']
        expected_entries.append({'Id':c['effect_id'],'TillId':till,'CashierId':cashier,'ActorId':actor,'Kind':('opening' if kind=='open' else kind),
                                 'DeltaMinor':delta,'ReceivedMinor':received,'ChangeMinor':change,'SaleId':sale,'ReversalId':reversal})
    for name,expected in (('CashEntries',expected_entries),('CashCloses',expected_closes),('CashTills',expected_tills)):
        actual=money[name]
        expect(isinstance(actual,list) and len(actual)==len(expected),'cash_duplicate_effect')
        for row in actual:
            expect(isinstance(row,dict) and row in expected,'cash_money_mismatch')
            expect(all(type(v) is int for k,v in row.items() if k.endswith('Minor') or k=='Exponent'),'cash_integer_amount')
        expect(len({r['Id'] for r in actual})==len(actual),'cash_duplicate_effect')


def validate_cash_progress(records, complete=False):
    expect(len(records)<=len(CASH_STEPS) and [r['step'] for r in records]==list(CASH_STEPS[:len(records)]),'cash_checkpoint_order')
    if complete: expect(len(records)==len(CASH_STEPS),'cash_missing_checkpoints')
    previous=[]; observed=0; receipt_posts=0; supply_key=None; supply_receipt=None
    source_hashes = None
    for r in records:
        # Reuse the exact private-pipe admission schema for exported checkpoints.
        notes = {k:v for k,v in r.items() if k in BROWSER_NOTE_FIELDS}
        browser_checkpoint({'step':r['step'], 'notes':notes, 'secrets':[]}, r['step'], set())
        if r['step'] == 'browser.start':
            expect('runtime' in notes and 'source_hashes' in notes, 'cash_metadata_missing')
            source_hashes = notes['source_hashes']
        if r['step'] == 'browser.cashier_login':
            expect(notes.get('source_hashes') == source_hashes, 'cash_source_mismatch')
        expect(r.get('external_requests')==r.get('runtime_errors')==0,'cash_network_guard')
        commands=cash_commands(r.get('cash_commands'))
        expect(len(commands)==CASH_LENGTHS[r['step']] and commands[:len(previous)]==previous,'cash_command_sequence')
        for i,c in enumerate(commands):
            b=c['body']
            kind,actor=(( 'open',0),('sale',0),('sale',0),('sale',0),('open',4),('refund',5),('close',0),('open',0),('refund',5),('close',0))[i]
            expect(c['kind']==kind and c['actor']==commands[actor]['actor'],'cash_command_identity')
            if len(commands)>4: expect(commands[4]['actor']!=commands[0]['actor'],'cash_second_cashier_identity')
            if len(commands)>5: expect(commands[5]['actor'] not in (commands[0]['actor'],commands[4]['actor']),'cash_authorizer_identity')
            if c['kind']=='sale': expect(b['receivedMinor']=={1:6000,2:5000,3:2000}[i], 'cash_tender_altered')
            if c['kind']=='close': expect(b['countedMinor']==(20450 if i==6 else 8750),'cash_counted_altered')
            if i in (1,2):
                expect(len(b['lines'])==2 and b['lines'][0]['quantity']==(2 if i==1 else 1) and b['lines'][1]['quantity']==1
                       and b['lines'][0]['itemId']!=b['lines'][1]['itemId'],'cash_sale_quantity_altered')
                if i==2: expect([l['itemId'] for l in b['lines']]==[l['itemId'] for l in commands[1]['body']['lines']],'cash_item_identity')
            if i==3: expect(len(b['lines'])==1 and b['lines'][0]['quantity']==1 and b['lines'][0].get('size')=='S'
                            and b['lines'][0].get('exceptionReason')=='SINTETICO physical garment present','cash_exception_altered')
            if kind=='refund':
                expect(b['saleId']==commands[1]['result_id'] and len(b['lines'])==1 and b['lines'][0]['quantity']==1,'cash_refund_altered')
                if i==8: expect(b['lines']==commands[5]['body']['lines'],'cash_refund_line_identity')
        proof=r.get('cash_oracles',{})
        expect(set(proof)==set(CASH_ORACLES)|{'money'} and all(proof[k] is True for k in CASH_ORACLES),'cash_missing_oracle')
        validate_cash_money(commands,proof['money'])
        observed+=sum(x['method']=='POST' and x['path']=='/internal/api/cash/sales' for x in r['network'])
        expect(observed==sum(c['kind']=='sale' for c in commands)==r['sale_posts'],'cash_reposted_sale')
        if r['step']=='browser.response_loss_committed':
            expect(any(x['path']=='/internal/api/cash/sales' and x['status']==200 and x['response_lost'] and x['key']==commands[2]['key'] for x in r['network']),'cash_loss_not_committed')
            expect(r.get('cash_pending_hash')==hashlib.sha256(json.dumps(commands[2]['body'],separators=(',',':')).encode()).hexdigest(),'cash_pending_body_changed')
        if r['step'] in ('browser.response_loss_committed','browser.recover_after_reload','browser.repeated_reload'):
            expect(r.get('sale_id') == commands[2]['result_id'], 'cash_recovery_sale_mismatch')
            if r['step'] != 'browser.repeated_reload':
                expect(r.get('key') == commands[2]['key'], 'cash_recovery_key_mismatch')
        if r['step']=='browser.recover_after_reload':
            expect(any(x['method']=='GET' and x['path']=='/internal/api/operations/cash.sale' and x['status']==200 and x['key']==commands[2]['key'] for x in r['network']),'cash_recovery_not_observed')
        if r['step']=='browser.cash_refund_refused':
            expect(any(x['method']=='POST' and x['path'].endswith('/refunds') and x['status']==403 for x in r['network']),'cash_refusal_not_observed')
        if r['step'] in SUPPLY_STEPS[1:3]:
            expect(any(x['method']=='POST' and x['path'].endswith('/receipts') and x['status']==200 and x['response_lost']==(r['step']==SUPPLY_STEPS[2]) for x in r['network']),'cash_supply_commit_missing')
        receipt_posts+=sum(x['method']=='POST' and x['path'].endswith('/receipts') for x in r['network'])
        stage=CASH_STEPS.index(r['step'])
        expect(receipt_posts==(0 if stage<CASH_STEPS.index(SUPPLY_STEPS[1]) else 1 if stage<CASH_STEPS.index(SUPPLY_STEPS[2]) else 2),'cash_supply_reposted')
        if r['step']==SUPPLY_STEPS[2]:
            supply_key=r.get('key');supply_receipt=r.get('receipt_id')
            expect(supply_key and supply_receipt,'cash_supply_identity_missing')
        if r['step'] in SUPPLY_STEPS[3:5]:
            expect(r.get('key')==supply_key and r.get('receipt_id')==supply_receipt,'cash_supply_identity_changed')
        if r['step']==SUPPLY_STEPS[3]:
            expect(any(x['method']=='GET' and x['path']=='/internal/api/operations/supply.receipt.create' and x['key']==supply_key and x['status']==200 for x in r['network']),'cash_supply_recovery_missing')
        for c in commands[len(previous):]:
            path={'open':'/internal/api/cash/tills','sale':'/internal/api/cash/sales','refund':f"/internal/api/cash/sales/{c['body'].get('saleId')}/refunds",'close':f"/internal/api/cash/tills/{c['body'].get('tillId')}/close"}[c['kind']]
            expect(sum(x['method']=='POST' and x['path']==path and x['key']==c['key'] and x['status']==200 for x in r['network'])==1,'cash_command_http_missing')
        previous=commands


class HarnessError(Exception):
    """A failed expectation. Messages are fixed text plus counts or status codes, never secrets."""


class Stop(Exception):
    """SIGTERM/SIGINT received: tear down and exit."""


def _stop(signum, frame):
    raise Stop(signal.Signals(signum).name)


# ---------------------------------------------------------------------------------------------
# Process helpers
# ---------------------------------------------------------------------------------------------

def dotnet_path():
    found = shutil.which('dotnet')
    if not found:
        raise HarnessError('dotnet no está en PATH (SDK fijado en global.json)')
    return found


def child_env(extra=None):
    """Child environment without the raw server connection or sqlcmd password, unless re-added explicitly."""
    env = {k: v for k, v in os.environ.items()
           if k not in ('MARTHA_TEST_SQL_CONNECTION', 'SQLCMDPASSWORD', 'MSSQL_SA_PASSWORD')
           and not k.startswith('ConnectionStrings__')}
    env.update(extra or {})
    return env


class Helper:
    """GoldenPath.Sql: real EF migrator, branch insert, SQL oracles, TLS certificate and drop."""

    def __init__(self, dotnet, dll, connection):
        self.dotnet, self.dll, self.connection = dotnet, dll, connection

    def __call__(self, *args, allow_fail=False):
        env = child_env({'MARTHA_TEST_SQL_CONNECTION': self.connection})
        process = subprocess.Popen([self.dotnet, str(self.dll), *args], env=env,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            stdout, _ = process.communicate(timeout=300)
        except BaseException:
            # Stop our own helper before SQL cleanup, including on SIGINT/SIGTERM or timeout.
            # An interrupted create has no ownership acknowledgement; never infer a safe drop.
            process.kill()
            process.communicate()
            raise
        lines = [line for line in stdout.splitlines() if line.startswith('{')]
        result = json.loads(lines[-1]) if lines else {'ok': False, 'error': 'no_output', 'detail': f'exit_{process.returncode}'}
        if not isinstance(result, dict):
            raise HarnessError('respuesta SQL no válida; resultado sin confirmación')
        if (process.returncode != 0 or not result.get('ok')) and not allow_fail:
            raise HarnessError(f"herramienta SQL '{args[0]}' falló: {result.get('error')} / {result.get('detail')}")
        return result


def free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.bind(('127.0.0.1', 0))
        return probe.getsockname()[1]


def database_connection(server_connection, database):
    # SqlConnectionStringBuilder keeps the LAST occurrence of a keyword, so appending overrides any
    # database/MARS value in the supplied server connection without parsing or echoing it.
    return server_connection.strip().rstrip(';') + f';Initial Catalog={database};MultipleActiveResultSets=False'


def product_status(transcript):
    """Return only the console's fixed refusal/outcome sentences (they never contain typed values)."""
    lines = ''.join(transcript).replace('\r', '\n').split('\n')
    keep = [line.strip() for line in lines if line.strip().startswith(
        ('Refused', 'Cancelled', 'Owner creation outcome', 'Initial owner creation'))]
    return ' | '.join(line[:240] for line in keep)


def bootstrap_owner(dotnet, api_dll, env, login, display, password, timeout=120):
    """Drive the product's interactive Owner console (--internal-bootstrap-owner) through a private pty.

    Nothing read from the console is stored or printed: passwords are only typed, never echoed in clear.
    """
    fd, slave = pty.openpty()
    # Raw mode BEFORE the child starts: otherwise bytes typed before .NET configures the terminal are
    # translated by the line discipline (CR -> LF), which the console correctly rejects as Ctrl+Enter.
    tty.setraw(slave)
    pid = os.fork()
    if pid == 0:  # child: new session whose controlling terminal is the private pty
        try:
            os.close(fd)
            os.setsid()
            fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
            for target in (0, 1, 2):
                os.dup2(slave, target)
            if slave > 2:
                os.close(slave)
            os.chdir(api_dll.parent)
            os.execve(dotnet, [dotnet, str(api_dll), '--internal-bootstrap-owner'], env)
        finally:
            os._exit(127)
    os.close(slave)
    buffer = ''
    transcript = []  # in memory only; just fixed product status lines may be reported
    deadline = time.monotonic() + timeout

    def wait_for(marker):
        nonlocal buffer
        while marker not in buffer:
            if time.monotonic() > deadline:
                raise HarnessError(f'consola Owner: no apareció el aviso esperado ({marker[:24]}…)')
            ready, _, _ = select.select([fd], [], [], 1.0)
            if ready:
                try:
                    chunk = os.read(fd, 4096)
                except OSError:
                    chunk = b''
                if not chunk:
                    raise HarnessError('consola Owner terminó antes de completar el diálogo: '
                                       + (product_status(transcript) or 'sin mensaje de estado'))
                text = chunk.decode('utf-8', 'replace')
                buffer += text
                transcript.append(text)
        index = buffer.index(marker) + len(marker)
        consumed, buffer = buffer[:index], buffer[index:]
        return consumed

    def answer(text):
        os.write(fd, text.encode('ascii') + b'\r')

    try:
        wait_for('Type PRIVATE in uppercase'); wait_for('\n'); answer('PRIVATE')
        wait_for('New owner login'); wait_for('\n'); answer(login)
        wait_for('New owner display name'); wait_for('\n'); answer(display)
        wait_for('New password ('); wait_for('\n'); answer(password)
        wait_for('Repeat new password'); wait_for('\n'); answer(password)
        wait_for('Final authorization: type exactly ')
        phrase = wait_for('\n').strip()
        if not phrase.startswith('CREATE OWNER IN ') or not phrase.endswith('/' + env['GOLDEN_DATABASE']):
            raise HarnessError('consola Owner: frase de autorización inesperada')
        answer(phrase)
        wait_for('Initial owner creation committed')
    finally:
        status = None
        for _ in range(100):
            done, status = os.waitpid(pid, os.WNOHANG)
            if done:
                break
            time.sleep(0.1)
        else:
            os.kill(pid, signal.SIGKILL)
            os.waitpid(pid, 0)
        os.close(fd)
    code = os.waitstatus_to_exitcode(status) if status is not None else None
    if code != 0:
        raise HarnessError(f'consola Owner terminó con código {code} (0 = creado)')


# ---------------------------------------------------------------------------------------------
# HTTP actor (mirrors dev/savia-staff-ui/login.mjs + client.mjs: CSRF, login, renew, me, logout)
# ---------------------------------------------------------------------------------------------

class Actor:
    def __init__(self, port, cafile, secrets_seen):
        self.port = port
        self.context = ssl.create_default_context(cafile=str(cafile))  # verify the ephemeral cert, no bypass
        self.cookies = {}
        self.csrf = None
        self.secrets_seen = secrets_seen
        self.statuses = []

    def request(self, method, path, body=None, csrf=False, key=None):
        headers = {'Accept': 'application/json'}
        payload = None
        if body is not None:
            payload = json.dumps(body).encode('utf-8')
            headers['Content-Type'] = 'application/json'
        if csrf:
            headers['X-CSRF-TOKEN'] = self.csrf
        if key:
            headers['Idempotency-Key'] = key
        if self.cookies:
            headers['Cookie'] = '; '.join(f'{k}={v}' for k, v in self.cookies.items())
        connection = http.client.HTTPSConnection('127.0.0.1', self.port, context=self.context, timeout=60)
        try:
            connection.request(method, path, body=payload, headers=headers)
            response = connection.getresponse()
            raw = response.read()
            for header, value in response.getheaders():
                if header.lower() == 'set-cookie':
                    self._cookie(value)
            content_type = (response.getheader('Content-Type') or '').split(';')[0].strip().lower()
            data = json.loads(raw) if raw and content_type in ('application/json', 'application/problem+json') else None
            self.statuses.append(response.status)
            return response.status, data
        finally:
            connection.close()

    def _cookie(self, header):
        name, _, rest = header.partition('=')
        value = rest.split(';', 1)[0]
        expired = 'expires=thu, 01 jan 1970' in header.lower() or 'max-age=0' in header.lower()
        if expired or not value:
            self.cookies.pop(name.strip(), None)
        else:
            self.cookies[name.strip()] = value
            self.secrets_seen.add(value)

    def renew_csrf(self):
        status, data = self.request('GET', '/internal/api/security/csrf')
        expect(status == 200 and data and data.get('headerName') == 'X-CSRF-TOKEN', f'csrf HTTP {status}')
        self.csrf = data['token']
        self.secrets_seen.add(self.csrf)

    def login(self, login, password):
        self.renew_csrf()
        status, data = self.request('POST', '/internal/api/security/login',
                                    {'loginName': login, 'password': password}, csrf=True)
        if status != 200:
            return status, None
        self.renew_csrf()  # identity transition: a new authenticated token is required
        me_status, me = self.request('GET', '/internal/api/security/me')
        expect(me_status == 200 and me and me['id'] == data['staff']['id'], f'me tras login HTTP {me_status}')
        return status, me

    def post(self, path, body, key):
        self.renew_csrf()
        return self.request('POST', path, body, csrf=True, key=key)

    def logout(self):
        self.renew_csrf()
        status, _ = self.request('POST', '/internal/api/security/logout', csrf=True)
        self.csrf = None
        return status


def expect(condition, message):
    if not condition:
        raise HarnessError(message)


def new_key():
    return str(uuid.uuid4())


# ---------------------------------------------------------------------------------------------
# Harness
# ---------------------------------------------------------------------------------------------

class GoldenPath:
    def __init__(self, args):
        self.args = args
        self.out = Path(args.out).resolve()
        self.out.mkdir(parents=True, exist_ok=True)
        # Reusing --out must never let a prior run's approval publish stale evidence.
        for name in ('evidence.json', 'oracles.md', 'evidence-approved'):
            (self.out / name).unlink(missing_ok=True)
        self.private = Path(tempfile.mkdtemp(prefix='savia-golden-private-'))  # outside the evidence dir
        os.chmod(self.private, 0o700)
        self.server_connection = os.environ.get('MARTHA_TEST_SQL_CONNECTION', '')
        self.database = args.database or 'SaviaInternalTest_Golden_' + secrets.token_hex(16)
        self.run_id = secrets.token_hex(3)
        self.steps = []
        self.secrets_seen = set()
        self.api = None
        self.api_log = None
        self.database_created = False
        self.drop_needed = False
        self.creation_state = 'not_started'
        self.started = time.monotonic()
        self.ids = {}
        self.users = {}
        self.port = None
        self.previous = None
        self.browser_process = None
        self.browser_exit = None
        self.browser_groups = {}
        self.browser_ownership_confirmed = False
        self.browser_processes_absent = False
        self.browser_evidence = None

    # -- evidence ---------------------------------------------------------------------------
    def oracles(self):
        return self.helper('oracles', self.database)['counts']

    def step(self, name, action, expected=None, same_as_previous=()):
        """Run one step, then evaluate SQL oracles. expected: {count_name: value}."""
        began = time.monotonic()
        record = {'step': name, 'status': 'FAIL'}
        self.steps.append(record)
        try:
            notes = action() or {}
        finally:
            record['ms'] = round((time.monotonic() - began) * 1000)
        record.update(notes)
        if self.database_created:
            counts = self.oracles()
            record['oracles'] = counts
            failures = []
            if counts.get('migrations_applied') != EXPECTED_MIGRATIONS:
                failures.append('migrations_applied')
            failures += [k for k in ALWAYS_ZERO if counts.get(k) != 0]
            for key, value in (expected or {}).items():
                if counts.get(key) != value:
                    failures.append(f'{key}={counts.get(key)}≠{value}')
            for key in same_as_previous:
                if self.previous is None or counts.get(key) != self.previous.get(key):
                    failures.append(f'{key} cambió')
            record['oracle_failures'] = failures
            self.previous = counts
            if failures:
                raise HarnessError(f'oráculo SQL falló en {name}: {", ".join(failures)}')
        record['status'] = 'PASS'
        print(f'PASS {name} ({record["ms"]} ms)', flush=True)

    def write_evidence(self, outcome, error=None):
        evidence = {
            'harness': 'tests/golden-path/golden_path.py', 'card': 'C6' if self.args.mode == 'browser' else 'C5', 'mode': self.args.mode,
            'outcome': outcome, 'error': error,
            'database_name': self.database,  # random disposable name; not a credential
            'migration_method': 'EF IMigrator.MigrateAsync (release migrator; not EnsureCreated)',
            'owner_method': 'product console --internal-bootstrap-owner driven through a private pty',
            'branch_method': 'EF insert of InternalBranch by the harness (no HTTP endpoint creates branches)',
            'directory_stock_staff_method': 'HTTP as Owner: directory/locations, directory/items, commerce/adjustments, security/staff',
            'api': {'binding': '127.0.0.1 (https, ephemeral self-signed certificate)', 'process': 'dotnet Martha.Store.Api.dll'},
            'roles': ROLES,
            'supply_journey': getattr(self.args, 'supply', False),
            'total_ms': round((time.monotonic() - self.started) * 1000),
            'steps': self.steps,
            'not_proven': ([] if self.args.mode == 'browser' else ['real browser/UI (C6)']) + ['Windows/SUAZO-PC', 'production TLS/proxy', 'card/external payment providers' if getattr(self.args,'cash',False) else 'payments',
                           'concurrency/load', 'backup/restore', 'idempotent release SQL script'],
        }
        if getattr(self.args, 'cash', False):
            evidence['cash_protocol'] = CASH_PROTOCOL
        if self.args.mode == 'browser':
            evidence['browser'] = self.browser_evidence
            evidence['not_proven'] += ['mobile devices', 'visual acceptance', 'full accessibility audit']
        if outcome == 'PASS' and getattr(self.args, 'cash', False):
            validate_cash_progress([x for x in self.steps if x['step'] in CASH_STEPS], complete=True)
        table = self.table()
        # Scan the exact UTF-8 bytes before making either public file available.
        # Private staging is outside --out, so always() artifact steps cannot collect it.
        with tempfile.TemporaryDirectory(prefix='savia-evidence-private-', dir=self.out.parent) as directory:
            staged = Path(directory)
            os.chmod(staged, 0o700)
            (staged / 'evidence.json').write_text(json.dumps(evidence, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
            (staged / 'oracles.md').write_text(table + '\n', encoding='utf-8')
            self.scan_for_secrets(directory=staged)
            self.scan_for_secrets()
            manifest = {'schema': 1, 'files': {name: hashlib.sha256((staged / name).read_bytes()).hexdigest()
                                               for name in ('evidence.json', 'oracles.md')}}
            for name in manifest['files']:
                os.replace(staged / name, self.out / name)
            # Last write: CI verifies this manifest against exact bytes before publication.
            (self.out / 'evidence-approved').write_text(json.dumps(manifest) + '\n', encoding='utf-8')
        return table

    def table(self):
        header = ['paso', 'estado', 'ms'] + [label for _, label in TABLE_COLUMNS]
        lines = ['| ' + ' | '.join(header) + ' |', '|' + '---|' * len(header)]
        for record in self.steps:
            counts = record.get('oracles', {})
            cells = [record['step'], record['status'], str(record.get('ms', ''))]
            cells += [str(counts.get(key, '–')) for key, _ in TABLE_COLUMNS]
            lines.append('| ' + ' | '.join(cells) + ' |')
        if self.args.mode == 'browser' and self.browser_evidence:
            browser = self.browser_evidence
            lines += ['', '## C6: Chrome y eventos saneados', '',
                      'Runtime: ' + json.dumps(browser.get('runtime', {}), sort_keys=True), '',
                      'TLS: perfil privado; pin SPKI del certificado efímero; sin modificar almacenes.', '',
                      '| fuente | SHA-256 |', '|---|---|']
            for name, digest in browser['source_hashes'].items():
                lines.append(f'| {name} | {digest} |')
            lines += ['', '| paso | DOM comprobado | método/ruta/HTTP/clave |', '|---|---|---|']
            for record in self.steps:
                if not record['step'].startswith('browser.'):
                    continue
                requests = []
                for request in record.get('network', []):
                    label = f"{request['method']} {request['path']} HTTP {request['status']}"
                    if request['key']:
                        label += ' key=' + request['key']
                    if request['response_lost']:
                        label += ' (respuesta descartada tras commit)'
                    requests.append(label)
                lines.append('| ' + record['step'] + ' | ' + ', '.join(record.get('dom', []))
                             + ' | ' + '<br>'.join(requests) + ' |')
        return '\n'.join(lines)

    def scan_for_secrets(self, skip=(), directory=None):
        """Fail if any password, cookie, CSRF token or the connection leaked into the evidence directory."""
        needles = {s for s in self.secrets_seen if len(s) >= 8}
        if self.server_connection:
            needles.add(self.server_connection)
            for part in self.server_connection.split(';'):
                k, _, v = part.partition('=')
                if k.strip().lower() in ('password', 'pwd') and len(v.strip()) >= 4:
                    needles.add(v.strip())
        for path in (directory or self.out).rglob('*'):
            if path.is_file() and path.name not in skip:
                text = path.read_text(encoding='utf-8', errors='replace')
                for needle in needles:
                    if needle in text:
                        raise HarnessError(f'secreto detectado en la evidencia: {path.name}')
        return len(needles)

    # -- lifecycle ----------------------------------------------------------------------------
    def build(self):
        dotnet = dotnet_path()
        if not self.args.no_build:
            subprocess.run([dotnet, 'restore', str(HELPER_PROJECT), '--locked-mode'], check=True, cwd=ROOT)
            subprocess.run([dotnet, 'build', str(HELPER_PROJECT), '--no-restore', '-c', 'Release'], check=True, cwd=ROOT)
        self.api_dll = API_PROJECT / 'bin/Release/net10.0/Martha.Store.Api.dll'
        helper_dll = HELPER_PROJECT / 'bin/Release/net10.0/GoldenPath.Sql.dll'
        expect(self.api_dll.is_file() and helper_dll.is_file(), 'faltan binarios Release: compilar o quitar --no-build')
        self.dotnet = dotnet
        self.helper = Helper(dotnet, helper_dll, self.server_connection)

    def api_env(self):
        connection = database_connection(self.server_connection, self.database)
        self.secrets_seen.add(connection)
        return child_env({
            'ASPNETCORE_ENVIRONMENT': 'Development', 'DOTNET_ENVIRONMENT': 'Development',
            'InternalSavia__Enabled': 'true', 'Synthetic__Enabled': 'false',
            'InternalSavia__Cash__Currency': 'USD', 'InternalSavia__Cash__Exponent': '2',
            'ConnectionStrings__InternalSavia': connection,
            # Legacy Store context is not used by /internal; an invalid guarded name keeps it closed.
            'ConnectionStrings__Store': 'Database=Forbidden_GoldenPath_NoStore',
            'Kestrel__Certificates__Default__Path': str(self.out / 'cert.pem'),
            'Kestrel__Certificates__Default__KeyPath': str(self.private / 'tls' / 'key.pem'),
            'Logging__LogLevel__Default': 'Warning', 'Logging__LogLevel__Microsoft.Hosting.Lifetime': 'Information',
            'DOTNET_NOLOGO': '1', 'TERM': os.environ.get('TERM') or 'xterm',
            'GOLDEN_DATABASE': self.database,
        })

    def start_api(self):
        self.port = free_port()
        self.base_url = f'https://127.0.0.1:{self.port}'
        self.api_log = open(self.private / 'api.log', 'wb')
        self.api = subprocess.Popen([self.dotnet, str(self.api_dll), '--urls', self.base_url],
                                    cwd=self.api_dll.parent, env=self.api_env(), stdin=subprocess.DEVNULL,
                                    stdout=self.api_log, stderr=subprocess.STDOUT)
        probe = Actor(self.port, self.out / 'cert.pem', self.secrets_seen)
        deadline = time.monotonic() + 90
        while time.monotonic() < deadline:
            if self.api.poll() is not None:
                raise HarnessError(f'la API terminó al iniciar (código {self.api.returncode})')
            try:
                status, data = probe.request('GET', '/internal/api/readiness')
                # Anonymous readiness must be refused; any response proves the real process listens with TLS.
                expect(status == 401, f'readiness anónimo devolvió HTTP {status}, se esperaba 401')
                return {'http': [status], 'port_kind': 'loopback-free-port'}
            except (ConnectionError, OSError, http.client.HTTPException):
                time.sleep(0.5)
        raise HarnessError('la API no respondió en 90 s')

    def stop_api(self):
        if self.api and self.api.poll() is None:
            self.api.send_signal(signal.SIGTERM)
            try:
                self.api.wait(timeout=20)
            except subprocess.TimeoutExpired:
                self.api.kill()
                self.api.wait(timeout=10)
        if self.api_log:
            self.api_log.close()
        return self.api.returncode if self.api else None

    # -- scenario -----------------------------------------------------------------------------
    def setup(self):
        expect(self.server_connection, 'falta MARTHA_TEST_SQL_CONNECTION (SQL Server desechable)')
        expect(DATABASE_PATTERN.match(self.database), 'nombre de base rechazado: debe ser SaviaInternalTest_Golden_<32 hex>')
        self.build()
        self.helper('cert', str(self.private / 'tls'))
        shutil.move(str(self.private / 'tls' / 'cert.pem'), str(self.out / 'cert.pem'))

        def migrate():
            # Before a reply there is no proof whether CREATE committed or refused an
            # existing database. Teardown must report uncertainty, never not_created.
            self.creation_state = 'uncertain'
            result = self.helper('create', self.database, allow_fail=True)
            if result.get('detail') in ('database_already_exists', 'database_name_not_golden_disposable'):
                self.creation_state = 'refused'
                raise HarnessError(f"herramienta SQL rechazó la base: {result['detail']}")  # never drop it
            if result.get('ok') is not True:
                # A generic SQL error can occur during the pre-existence check itself.
                # Even a returned error is not proof that this run owns the database.
                raise HarnessError('creación SQL sin confirmación; propiedad de la base desconocida')
            self.drop_needed = True  # successful create acknowledgement from this run
            self.creation_state = 'acknowledged'
            self.database_created = True
            expect(result['pending'] == 0 and tuple(result['applied']) == MIGRATIONS, 'migraciones incompletas')
            return {'applied_migrations': result['applied'], 'method': result['method']}
        self.step('sql.migrate_release', migrate, {'staff': 0, 'migrations_applied': EXPECTED_MIGRATIONS})

        for role in ROLES:
            self.users[role] = {'loginName': f'golden.{role.lower()}.{self.run_id}',
                                'displayName': f'SINTETICO Golden {role}',
                                'password': 'Golden-' + secrets.token_urlsafe(24)}
            self.secrets_seen.add(self.users[role]['password'])

        def owner():
            u = self.users['Owner']
            bootstrap_owner(self.dotnet, self.api_dll, self.api_env(), u['loginName'], u['displayName'], u['password'])
            return {'console_exit': 0}
        self.step('owner.bootstrap_console', owner, {'staff': 1})

        self.ids['branch'] = str(uuid.uuid4())
        def branch():
            self.helper('branch', self.database, self.ids['branch'])
            return {'note': 'sin endpoint HTTP de sucursales en este candidato'}
        self.step('sql.branch_seed', branch, {'branches': 1})
        self.step('api.start_readiness_anonymous', self.start_api)

        self.owner = Actor(self.port, self.out / 'cert.pem', self.secrets_seen)

        def owner_login():
            status, me = self.owner.login(self.users['Owner']['loginName'], self.users['Owner']['password'])
            expect(status == 200 and me['role'] == 'Owner', f'login Owner HTTP {status}')
            ready_status, ready = self.owner.request('GET', '/internal/api/readiness')
            expect(ready_status == 200 and ready.get('status') == 'ready', f'readiness autenticado HTTP {ready_status}')
            return {'http': [status, ready_status], 'readiness': ready.get('status')}
        self.step('owner.login_readiness', owner_login, {'active_sessions': 1})

        def directory():
            codes = []
            status, location = self.owner.post('/internal/api/directory/locations',
                                               {'name': 'SINTETICO Golden bodega', 'active': True,
                                                'branchId': self.ids['branch']}, new_key())
            expect(status == 201 and location['branchId'] == self.ids['branch'], f'crear ubicación HTTP {status}')
            codes.append(status)
            self.ids['location'] = location['id']
            self.ids['items'] = []
            for sku, name, price in ITEMS:
                status, item = self.owner.post('/internal/api/directory/items',
                                               {'sku': sku, 'name': name, 'unitPriceMinor': price,
                                                'currency': 'USD', 'active': True}, new_key())
                expect(status == 201, f'crear artículo HTTP {status}')
                codes.append(status)
                self.ids['items'].append(item['id'])
            return {'http': codes}
        self.step('owner.seed_directory', directory, {'locations': 1, 'items': len(ITEMS), 'sales': 0})

        if getattr(self.args, 'stock_exception', False):
            def exception_fixture():
                status, item = self.owner.post('/internal/api/directory/items',
                    {'sku': 'SINTETICO-GOLDEN-EX', 'name': 'SINTETICO physical garment',
                     'unitPriceMinor': 1250, 'currency': 'USD', 'active': True}, new_key())
                expect(status == 201, 'stock_exception_item_failed')
                self.ids['exception_item'] = item['id']
                return {'http': status}
            self.step('owner.seed_exception_item', exception_fixture, {'items': len(ITEMS) + 1})

        def stock():
            codes = []
            for item_id in self.ids['items']:
                status, _ = self.owner.post('/internal/api/commerce/adjustments',
                                            {'itemId': item_id, 'locationId': self.ids['location'],
                                             'onHandDelta': SEED_STOCK, 'reason': 'SINTETICO carga inicial golden'},
                                            new_key())
                expect(status == 200, f'ajuste de stock HTTP {status}')
                codes.append(status)
            return {'http': codes}
        self.step('owner.seed_stock_adjustments', stock,
                  {'movements': len(ITEMS), 'adjustments': len(ITEMS), 'on_hand_total': SEED_STOCK * len(ITEMS)})

        def staff():
            codes = []
            for role in ROLES[1:]:
                u = self.users[role]
                body = {'loginName': u['loginName'], 'displayName': u['displayName'],
                        'role': 'Cashier' if role in ('Unassigned', 'Cashier2') else role, 'password': u['password'],
                        'branchId': None if role == 'Unassigned' else self.ids['branch']}
                status, created = self.owner.post('/internal/api/security/staff', body, None)
                expect(status == 200 and created['branchId'] == body['branchId'], f'crear personal {role} HTTP {status}')
                codes.append(status)
                u['id'] = created['id']
            return {'http': codes}
        self.step('owner.seed_staff', staff, {'staff': len(ROLES), 'unassigned_staff': 1})

        if getattr(self.args, 'supply', False):
            def purchase_fixture():
                status, supplier = self.owner.post('/internal/api/directory/parties',
                    {'kind': 'supplier', 'name': 'SINTETICO Golden supplier', 'active': True}, new_key())
                expect(status == 201, 'supply_supplier_create_failed')
                status, order = self.owner.post('/internal/api/supply/purchase-orders',
                    {'supplierId': supplier['id'], 'locationId': self.ids['location'], 'currency': 'USD',
                     'reference': 'SINTETICO Golden receipt',
                     'lines': [{'itemId': self.ids['items'][0], 'quantity': 5, 'unitCostMinor': 700}]}, new_key())
                expect(status == 200 and order['status'] == 'open' and order['totalMinor'] == 3500
                       and len(order['lines']) == 1 and order['lines'][0]['receivedQuantity'] == 0,
                       'supply_order_fixture_invalid')
                self.supply_fixture = {**order, 'actor': self.users['Inventory']['id']}
                return {'http': [201, 200]}
            self.step('owner.seed_purchase', purchase_fixture,
                      {'purchase_orders': 1, 'purchase_lines': 1, 'purchase_quantity': 5,
                       'purchase_received': 0, 'purchase_total': 3500, 'purchase_receipts': 0})

        def owner_scope():
            codes = []
            status, locations = self.owner.request('GET', '/internal/api/directory/locations')
            codes.append(status)
            expect(status == 200 and locations['total'] == 1, f'ubicaciones Owner HTTP {status}')
            status, inventory = self.owner.request('GET', f"/internal/api/commerce/inventory?locationId={self.ids['location']}&skip=0&take=100")
            codes.append(status)
            expect(status == 200 and inventory['total'] == len(ITEMS), f'inventario Owner HTTP {status}')
            status, staff_list = self.owner.request('GET', '/internal/api/security/staff')
            codes.append(status)
            expect(status == 200 and len(staff_list['items']) == len(ROLES), f'personal Owner HTTP {status}')
            codes.append(self.owner.logout())
            expect(codes[-1] == 204, f'logout Owner HTTP {codes[-1]}')
            status, _ = self.owner.request('GET', '/internal/api/security/me')
            codes.append(status)
            expect(status == 401, f'me tras logout Owner HTTP {status}')
            return {'http': codes, 'visible_locations': locations['total'], 'visible_stock_rows': inventory['total']}
        self.step('owner.scope_and_logout', owner_scope, {'active_sessions': 0})

    def role_scope(self, role, sale_expected_status=None):
        actor = Actor(self.port, self.out / 'cert.pem', self.secrets_seen)
        codes = []
        status, me = actor.login(self.users[role]['loginName'], self.users[role]['password'])
        codes.append(status)
        expected_role = 'Cashier' if role == 'Unassigned' else role
        expect(status == 200 and me['role'] == expected_role, f'login {role} HTTP {status}')
        status, locations = actor.request('GET', '/internal/api/directory/locations')
        codes.append(status)
        status2, inventory = actor.request('GET', f"/internal/api/commerce/inventory?locationId={self.ids['location']}&skip=0&take=100")
        codes.append(status2)
        visible = (locations or {}).get('total'), (inventory or {}).get('total')
        if role == 'Unassigned':
            expect(status == 200 and status2 == 200 and visible == (0, 0), f'sin asignación ve ubicaciones/stock: {visible}')
        else:
            expect(status == 200 and status2 == 200 and visible == (1, len(ITEMS)), f'{role} no ve su sucursal: {visible}')
        notes = {'visible_locations': visible[0], 'visible_stock_rows': visible[1]}
        if sale_expected_status is not None:
            status, problem = actor.post('/internal/api/commerce/sales', self.sale_body(), new_key())
            codes.append(status)
            expect(status == sale_expected_status, f'venta de {role}: HTTP {status}, se esperaba {sale_expected_status}')
            notes['sale_attempt'] = {'http': status, 'code': (problem or {}).get('code')}
        return actor, codes, notes

    def sale_body(self):
        return {'locationId': self.ids['location'], 'customerId': None,
                'lines': [{'itemId': self.ids['items'][0], 'quantity': SALE_QUANTITY}]}

    def smoke(self):
        """API-only unpaid-v2: fresh unpaid sale refusal and original-key failure recovery.

        The old successful-unpaid oracle remains below as historical_unpaid_smoke;
        cash rollout rejects creating that history. No old success is relabeled paid.
        """
        for role in ('Manager','Inventory','Unassigned'):
            def scope(role=role):
                actor,codes,notes=self.role_scope(role, sale_expected_status=403 if role!='Manager' else None)
                expect(actor.logout()==204,'api_unpaid_logout')
                return {'http':codes,**notes}
            self.step('api_unpaid.'+role.lower(),scope,{'sales':0,'sale_operations':0,'active_sessions':0})
        actor,_,_=self.role_scope('Cashier')
        key=new_key();body=self.sale_body()
        before=self.helper('cash-snapshot',self.database)
        def rejected():
            status,problem=actor.post('/internal/api/commerce/sales',body,key)
            expect(status==409 and problem.get('code')=='cash_payment_required','api_unpaid_refusal')
            return {'http':[status],'code':'cash_payment_required'}
        self.step('api_unpaid.fresh_rejected',rejected,{'sales':0,'sale_operations':1})
        after=self.helper('cash-snapshot',self.database)
        expect(all(before['hashes'][t]==after['hashes'][t] for t in before['hashes'] if t!='Operations'),'api_unpaid_business_write')
        for action in ('replay','conflict','recover'):
            def check(action=action):
                if action=='recover':
                    status,result=actor.request('GET','/internal/api/operations/commerce.sale.record',key=key)
                    expect(status==200 and result['status']=='completed' and result['result']=={'success':False,'value':None,'error':'cash_payment_required'},'api_unpaid_recovery')
                else:
                    request=json.loads(json.dumps(body))
                    if action=='conflict':request['lines'][0]['quantity']+=1
                    status,result=actor.post('/internal/api/commerce/sales',request,key)
                    expect(status==409 and result.get('code')==('idempotency_conflict' if action=='conflict' else 'cash_payment_required'),'api_unpaid_replay')
                current=self.helper('cash-snapshot',self.database)
                expect(current['hashes']==after['hashes'],'api_unpaid_readback_write')
                return {'http':[status]}
            self.step('api_unpaid.'+action,check,{'sales':0,'sale_operations':1},same_as_previous=('operations','movements','on_hand_total'))
        expect(actor.logout()==204,'api_unpaid_logout')

    def historical_unpaid_smoke(self):
        def manager():
            actor, codes, notes = self.role_scope('Manager')
            codes.append(actor.logout())
            expect(codes[-1] == 204, 'logout Manager')
            return {'http': codes, **notes}
        self.step('manager.login_scope_logout', manager, {'sales': 0, 'active_sessions': 0})

        def inventory():
            actor, codes, notes = self.role_scope('Inventory', sale_expected_status=403)
            codes.append(actor.logout())
            expect(codes[-1] == 204, 'logout Inventory')
            return {'http': codes, **notes}
        self.step('inventory.login_scope_sale_denied', inventory, {'sales': 0, 'sale_operations': 0, 'active_sessions': 0},
                  same_as_previous=('movements', 'operations'))

        def unassigned():
            actor, codes, notes = self.role_scope('Unassigned', sale_expected_status=403)
            codes.append(actor.logout())
            expect(codes[-1] == 204, 'logout sin asignación')
            return {'http': codes, **notes}
        self.step('unassigned.denied_scope_and_sale', unassigned, {'sales': 0, 'sale_operations': 0, 'active_sessions': 0},
                  same_as_previous=('movements', 'operations', 'on_hand_total'))

        self.cashier = None

        def cashier_login():
            self.cashier, codes, notes = self.role_scope('Cashier')
            return {'http': codes, **notes}
        self.step('cashier.login_scope', cashier_login, {'sales': 0, 'cashier_active_sessions': 1})

        self.sale_key = new_key()

        def sale():
            status, receipt = self.cashier.post('/internal/api/commerce/sales', self.sale_body(), self.sale_key)
            expect(status == 200, f'venta HTTP {status}')
            expect(receipt['paymentStatus'] == 'not_processed' and receipt['totalMinor'] == ITEMS[0][2] * SALE_QUANTITY,
                   'recibo inesperado')
            self.sale_id = receipt['saleId']
            return {'http': [status], 'total_minor': receipt['totalMinor'], 'lines': len(receipt['lines'])}
        self.step('cashier.sale_with_idempotency_key', sale,
                  {'sales': 1, 'sale_lines': 1, 'sale_movements': 1, 'sale_operations': 1,
                   'on_hand_total': SEED_STOCK * len(ITEMS) - SALE_QUANTITY})

        def replay():
            status, receipt = self.cashier.post('/internal/api/commerce/sales', self.sale_body(), self.sale_key)
            expect(status == 200 and receipt['saleId'] == self.sale_id, f'repetición HTTP {status} o venta distinta')
            return {'http': [status], 'same_sale_id': True}
        self.step('cashier.replay_same_key_no_effect', replay, {'sales': 1, 'sale_operations': 1},
                  same_as_previous=('movements', 'operations', 'on_hand_total', 'sale_lines'))

        def conflict():
            body = self.sale_body()
            body['lines'][0]['quantity'] = SALE_QUANTITY + 1
            status, problem = self.cashier.post('/internal/api/commerce/sales', body, self.sale_key)
            expect(status == 409 and (problem or {}).get('code') == 'idempotency_conflict', f'misma clave, otro cuerpo: HTTP {status}')
            return {'http': [status], 'code': problem.get('code')}
        self.step('cashier.same_key_other_body_conflict', conflict, {'sales': 1, 'sale_operations': 1},
                  same_as_previous=('movements', 'operations', 'on_hand_total'))

        def recover():
            status, data = self.cashier.request('GET', '/internal/api/operations/commerce.sale.record', key=self.sale_key)
            expect(status == 200 and data['status'] == 'completed' and data['result']['value']['saleId'] == self.sale_id,
                   f'recuperación HTTP {status}')
            return {'http': [status], 'recovered': 'completed'}
        self.step('cashier.recover_by_key', recover, {'sales': 1}, same_as_previous=('movements', 'operations'))

        def logout():
            codes = [self.cashier.logout()]
            status, _ = self.cashier.request('GET', '/internal/api/security/me')
            codes.append(status)
            expect(codes == [204, 401], f'logout cajero {codes}')
            return {'http': codes}
        self.step('cashier.logout', logout, {'sales': 1, 'cashier_active_sessions': 0, 'active_sessions': 0},
                  same_as_previous=('movements', 'operations', 'on_hand_total'))

    def serve(self):
        session = {
            'warning': 'Credenciales SINTÉTICAS de una base desechable. No copiar a Git ni a evidencia.',
            'base_url': self.base_url, 'login_url': self.base_url + '/internal/login',
            'ca_cert': str(self.out / 'cert.pem'), 'database_name': self.database,
            'branch_id': self.ids['branch'], 'location_id': self.ids['location'], 'item_ids': self.ids['items'],
            'users': {role: {'loginName': u['loginName'], 'password': u['password'],
                             'role': 'Cashier' if role in ('Unassigned', 'Cashier2') else role, 'assigned': role != 'Unassigned'}
                      for role, u in self.users.items()},
        }
        credentials = self.out / 'session.json'
        descriptor = os.open(credentials, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(descriptor, 'w', encoding='utf-8') as handle:
            json.dump(session, handle, indent=2, ensure_ascii=False)
        os.chmod(credentials, 0o600)
        ready = {'base_url': self.base_url, 'credentials_file': 'session.json', 'pid': os.getpid(),
                 'users': {role: u['loginName'] for role, u in self.users.items()}}
        (self.out / 'serve-ready.json').write_text(json.dumps(ready, indent=2) + '\n', encoding='utf-8')
        print(f'\nSERVE base_url={self.base_url}', flush=True)
        for role, u in self.users.items():
            print(f'SERVE user {role}: {u["loginName"]}', flush=True)
        print(f'SERVE credenciales (0600): {credentials}', flush=True)
        print('SERVE API y base activas. Terminar con Ctrl+C o SIGTERM para detener la API y borrar la base.', flush=True)
        while True:
            if self.api.poll() is not None:
                raise HarnessError(f'la API terminó durante serve (código {self.api.returncode})')
            time.sleep(1)

    @staticmethod
    def browser_process_identity(pid):
        # Linux /proc start time prevents a reused PID from authorizing a signal.
        fields = (Path('/proc') / str(pid) / 'stat').read_text().rsplit(')', 1)[1].split()
        return {'pid': pid, 'parent': int(fields[1]), 'group': int(fields[2]), 'start': fields[19]}

    def browser_group_members(self, group):
        members = {}
        for entry in Path('/proc').iterdir():
            if not entry.name.isdecimal():
                continue
            try:
                identity = self.browser_process_identity(int(entry.name))
            except FileNotFoundError:
                continue
            if identity['group'] == group:
                members[identity['pid']] = identity['start']
        return members

    def register_browser_group(self, pid, chrome=False):
        expect(type(pid) is int and pid > 1, 'browser_process_identity_invalid')
        identity = self.browser_process_identity(pid)
        expect(identity['group'] == pid, 'browser_process_group_invalid')
        if chrome:
            command = (Path('/proc') / str(pid) / 'cmdline').read_bytes().split(b'\0')
            profile = ('--user-data-dir=' + str(self.private / 'chrome-profile')).encode()
            expect(profile in command, 'browser_profile_ownership_invalid')
            parent = identity['parent']
            for _ in range(32):
                if parent == self.browser_process.pid:
                    break
                expect(parent > 1, 'browser_process_parent_invalid')
                parent = self.browser_process_identity(parent)['parent']
            expect(parent == self.browser_process.pid, 'browser_process_parent_invalid')
        self.browser_groups[pid] = {pid: identity['start']}
        self.browser_ownership_confirmed = chrome

    def stop_browser(self):
        """Retire registered Node/Chrome groups and require a final absence readback."""
        process = self.browser_process
        if not process:
            return self.browser_exit
        absent = False
        try:
            # Playwright detaches Chrome: retire its group before retiring Node.
            groups = list(reversed(self.browser_groups))
            for sig in (signal.SIGTERM, signal.SIGKILL):
                for group in groups:
                    members = self.browser_group_members(group)
                    if not members:
                        continue
                    known = self.browser_groups[group]
                    if not any(known.get(pid) == start for pid, start in members.items()):
                        continue  # Never signal a group whose ownership cannot be proved.
                    known.update(members)
                    try:
                        os.killpg(group, sig)
                    except ProcessLookupError:
                        pass
                for _ in range(50):
                    process.poll()  # Reap Node before checking /proc.
                    if all(not self.browser_group_members(group) for group in groups):
                        absent = True
                        break
                    time.sleep(0.1)
                if absent:
                    break
            self.browser_processes_absent = bool(absent and self.browser_ownership_confirmed)
        except (OSError, ValueError, IndexError):
            self.browser_processes_absent = False
        finally:
            self.browser_exit = process.poll()
            for pipe in (process.stdin, process.stdout):
                if pipe:
                    pipe.close()
            self.browser_process = None
        return self.browser_exit

    def browser(self):
        """Chrome UI actions, private checkpoint pipe, existing SQL oracle after every action."""
        node, openssl = shutil.which('node'), shutil.which('openssl')
        package = Path(self.args.playwright_directory).resolve()
        expect(node and openssl, 'browser_requires_existing_node_and_openssl')
        expect((package / 'index.mjs').is_file() and (package / 'package.json').is_file(),
               'browser_requires_existing_playwright_directory')
        # Chrome trusts this ephemeral public key only in its fresh, private profile.
        # No machine trust store mutation, ignoreHTTPSErrors or blanket TLS bypass.
        public_key = subprocess.run([openssl, 'x509', '-in', str(self.out / 'cert.pem'), '-pubkey', '-noout'],
                                    check=True, capture_output=True).stdout
        der = subprocess.run([openssl, 'pkey', '-pubin', '-outform', 'DER'], input=public_key,
                             check=True, capture_output=True).stdout
        pin = base64.b64encode(hashlib.sha256(der).digest()).decode('ascii')
        source_hashes = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in BROWSER_SOURCES}
        self.browser_evidence = {
            'transport': 'Chrome HTTPS to real API; CDP discards a committed HTTP 200 response once',
            'tls': 'isolated Chrome profile; ephemeral certificate SPKI allowlist; no trust store changes',
            'tls_spki_sha256': pin,
            'source_hashes': {**source_hashes,
                              'tests/golden-path/golden_path.py': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                              'tests/golden-path/browser_path.mjs': hashlib.sha256(BROWSER_SCRIPT.read_bytes()).hexdigest(),
                              'backend/src/Martha.Store.Api/bin/Release/net10.0/Martha.Store.Api.dll': hashlib.sha256(self.api_dll.read_bytes()).hexdigest()},
            'raw_trace_or_har_recorded': False,
        }
        config = {'base_url': self.base_url, 'profile': str(self.private / 'chrome-profile'), 'spki': pin,
                  'playwright_directory': str(package), 'source_hashes': source_hashes,
                  'cashier': self.users['Cashier'], 'location_id': self.ids['location'],
                  'item_id': self.ids['items'][0], 'sku': ITEMS[0][0], 'unit_price_minor': ITEMS[0][2],
                  'second_item_id': self.ids['items'][1], 'second_sku': ITEMS[1][0], 'second_unit_price_minor': ITEMS[1][2]}
        if getattr(self.args, 'supply', False):
            config.update(supply=self.supply_fixture, inventory=self.users['Inventory'])
        if getattr(self.args, 'stock_exception', False):
            config.update(stock_exception=True, exception_item_id=self.ids['exception_item'], manager=self.users['Manager'])
        if getattr(self.args, 'cash', False):
            config.update(cash=True, second_cashier=self.users['Cashier2'], manager=self.users['Manager'])
        process = subprocess.Popen([node, str(BROWSER_SCRIPT)], cwd=ROOT, env=child_env(),
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                   start_new_session=True)
        self.browser_process = process
        deadline = time.monotonic() + 300
        buffered = b''
        observed_posts, sale_keys, sale_ids = 0, [], []
        supply_previous, receipt_posts = {}, 0

        def send(value):
            process.stdin.write((json.dumps(value) + '\n').encode('utf-8'))
            process.stdin.flush()

        def receive():
            nonlocal buffered
            while b'\n' not in buffered:
                remaining = deadline - time.monotonic()
                expect(remaining > 0, 'browser_timeout')
                ready, _, _ = select.select([process.stdout], [], [], min(remaining, 1))
                if not ready:
                    expect(process.poll() is None, 'browser_exited_before_checkpoint')
                    continue
                chunk = os.read(process.stdout.fileno(), 65536)
                expect(chunk, 'browser_checkpoint_eof')
                buffered += chunk
                expect(len(buffered) <= 262144, 'browser_protocol_oversize')
            line, buffered = buffered.split(b'\n', 1)
            try:
                event = json.loads(line)
            except (ValueError, UnicodeError):
                raise HarnessError('browser_protocol_invalid') from None
            if isinstance(event, dict) and set(event) == {'error'}:
                # The child emits only its own fixed c6_* codes; raw exceptions stay private.
                code = event['error']
                allowed_errors = {'c6_config_missing', 'c6_origin_or_pin_invalid', 'c6_local_source_mismatch',
                                  'c6_browser_runtime_guard', 'c6_sql_checkpoint_refused', 'c6_server_receipt_invalid',
                                  'c6_confirmed_storage_invalid', 'c6_dom_stock_invalid', 'c6_receipt_reload_http',
                                  'c6_recovery_not_completed', 'c6_served_source_mismatch', 'c6_session_cookie_flags',
                                  'c6_sale_http', 'c6_loss_interception_failed', 'c6_pending_key_lost',
                                  'c6_recovery_key_or_post_count', 'c6_logout_or_post_count', 'c6_browser_failed',
                                  'c6_browser_process_identity', 'c6_logout_click', 'c6_logout_response',
                                  'c6_logout_http', 'c6_logout_navigation', 'c6_logout_form', 'c6_logout_me',
                                  'c6_supply_complete_invalid', 'c6_supply_identity_invalid',
                                  'c6_supply_logout_invalid', 'c6_supply_loss_failed',
                                  'c6_supply_loss_request_missing', 'c6_supply_loss_requires_commit',
                                  'c6_supply_partial_http', 'c6_supply_partial_invalid',
                                  'c6_supply_pending_changed', 'c6_supply_pending_identity_invalid',
                                  'c6_supply_pending_not_cleared', 'c6_supply_recovery_invalid',
                                  'c6_supply_reload_invalid', 'c6_supply_request_invalid',
                                  'c6_cash_open', 'c6_cash_change', 'c6_cash_receipt_identity',
                                  'c6_cash_request', 'c6_cash_lost_request', 'c6_cash_logout',
                                  'c6_cash_action', 'c6_cash_refund_not_refused',
                                  'c6_stock_sale_invalid', 'c6_stock_review_invalid'}
                code = code if code in allowed_errors else 'browser_protocol_invalid'
                if self.steps and self.steps[-1]['step'].startswith('browser.'):
                    self.steps[-1]['error_code'] = code
                raise HarnessError(code)
            return event

        try:
            self.register_browser_group(process.pid)
            send(config)
            ownership = receive()
            expect(isinstance(ownership, dict) and set(ownership) == {'owned_browser_pid'},
                   'browser_process_identity_invalid')
            self.register_browser_group(ownership['owned_browser_pid'], chrome=True)
            send({'ok': True})
            cash_state = None
            cash_records = []
            for name in (CASH_STEPS if getattr(self.args, 'cash', False) else (*BROWSER_STEPS, *(SUPPLY_STEPS if getattr(self.args, 'supply', False) else ()), *(STOCK_STEPS if getattr(self.args, 'stock_exception', False) else ()))):
                if getattr(self.args, 'cash', False):
                    event = receive()
                    notes = browser_checkpoint(event, name, self.secrets_seen)
                    snapshot = self.helper('cash-snapshot', self.database)
                    if name in SUPPLY_STEPS:
                        supply_identity(notes, self.supply_fixture, supply_previous, name)
                        if name in SUPPLY_STEPS[1:5]:
                            identity=self.helper('receipt-identity',self.database,notes['receipt_id'],notes['actor_id'],notes['order_id'],notes['location_id'],self.ids['items'][0],notes['key'],'2' if name==SUPPLY_STEPS[1] else '3')
                            expect(identity.get('matches')==1,'supply_sql_identity_mismatch')
                        supply_previous=notes
                    if name in STOCK_STEPS:
                        identity=self.helper('stock-identity',self.database,notes['sale_id'],self.users['Cashier']['id'],self.ids['exception_item'],self.ids['location'],notes['key'],self.users['Manager']['id'],notes.get('review_key',str(uuid.UUID(int=0))))
                        expect(identity.get('allocation_matches')==1 and identity.get('review_matches')==int(STOCK_STEPS.index(name)>=2),'stock_exception_sql_identity_mismatch')
                    proof = validate_cash_snapshot(notes['cash_commands'], snapshot, self.users, self.ids, cash_state, name)
                    cash_state = snapshot
                    notes['cash_oracles'] = proof
                    if name in ('browser.start', 'browser.cashier_login'):
                        expect(notes.get('source_hashes') == source_hashes, 'cash_source_mismatch')
                    if name == 'browser.start':
                        self.browser_evidence['runtime'] = notes['runtime']
                    cash_records.append({'step': name, **notes})
                    validate_cash_progress(cash_records)
                    self.step(name, lambda: notes, cash_counts(name))
                    send({'ok': True})
                    continue
                if name in STOCK_STEPS:
                    event = receive()
                    notes = browser_checkpoint(event, name, self.secrets_seen)
                    reviewed = STOCK_STEPS.index(name) >= 2
                    expect(notes['sale_posts'] == 3 and notes['external_requests'] == notes['runtime_errors'] == 0,
                           'stock_exception_network_invalid')
                    identity = self.helper('stock-identity', self.database, notes['sale_id'], self.users['Cashier']['id'],
                        self.ids['exception_item'], self.ids['location'], notes['key'],
                        self.users['Manager']['id'], notes.get('review_key', str(uuid.UUID(int=0))))
                    expect(identity.get('allocation_matches') == 1 and identity.get('review_matches') == int(reviewed),
                           'stock_exception_sql_identity_mismatch')
                    expected = {'sales': 3, 'sale_lines': 5, 'sale_movements': 4, 'sale_operations': 3,
                                'exception_lines': 1, 'stock_reviews': int(reviewed), 'exception_movements': 0,
                                'movements': 9, 'on_hand_total': 30, 'active_sessions': int(name != STOCK_STEPS[-1])}
                    self.step(name, lambda: notes, expected)
                    send({'ok': True})
                    continue
                if name in SUPPLY_STEPS:
                    self.steps.append({'step': name, 'status': 'FAIL'})
                    event = receive()
                    notes = browser_checkpoint(event, name, self.secrets_seen)
                    supply_identity(notes, self.supply_fixture, supply_previous, name)
                    requests = [r for r in notes['network'] if r['method'] == 'POST' and r['path'].endswith('/receipts')]
                    receipt_posts += len(requests)
                    expect(receipt_posts == notes['receipt_posts'] and notes['sale_posts'] == 2
                           and not any(r['method'] == 'POST' and r['path'] == '/internal/api/commerce/sales' for r in notes['network'])
                           and notes['runtime_errors'] == notes['external_requests'] == 0, 'supply_network_invalid')
                    if name in SUPPLY_STEPS[1:3]:
                        expect(len(requests) == 1 and requests[0]['key'] == notes['key']
                               and requests[0]['status'] == 200 and requests[0]['response_lost'] == (name == SUPPLY_STEPS[2]),
                               'supply_commit_not_observed')
                    if name == SUPPLY_STEPS[3]:
                        expect(any(r['method'] == 'GET' and r['path'] == '/internal/api/operations/supply.receipt.create'
                                   and r['key'] == notes['key'] and r['status'] == 200 for r in notes['network']),
                               'supply_recovery_not_observed')
                    if name in SUPPLY_STEPS[1:5]:
                        identity = self.helper('receipt-identity', self.database, notes['receipt_id'], notes['actor_id'],
                                               notes['order_id'], notes['location_id'], self.ids['items'][0], notes['key'],
                                               '2' if name == SUPPLY_STEPS[1] else '3')
                        expect(identity.get('matches') == 1, 'supply_sql_identity_mismatch')
                        notes['sql_identity_matches'] = identity['matches']
                    self.steps.pop()  # step() now owns this checkpoint and its SQL evidence.
                    self.step(name, lambda: notes, supply_expected(name),
                              same_as_previous=BROWSER_READ_ONLY if name in SUPPLY_STEPS[3:] else ())
                    supply_previous = notes
                    send({'ok': True})
                    continue
                sale_count = 2 if BROWSER_STEPS.index(name) >= BROWSER_STEPS.index('browser.response_loss_committed') else (
                    1 if BROWSER_STEPS.index(name) >= BROWSER_STEPS.index('browser.sale_confirmed') else 0)
                expected = {'sales': sale_count, 'sale_lines': 2 * sale_count, 'sale_movements': 2 * sale_count,
                            'sale_operations': sale_count, 'movements': len(ITEMS) + 2 * sale_count,
                            'on_hand_total': 30 - (0 if sale_count == 0 else 3 if sale_count == 1 else 5),
                            'active_sessions': 0 if name in ('browser.start', 'browser.logout') else 1}
                read_only = name in ('browser.receipt_reload', 'browser.stock_after_sale', 'browser.recover_after_reload',
                                    'browser.repeated_reload', 'browser.stock_after_recovery', 'browser.logout')
                def checkpoint(name=name, sale_count=sale_count):
                    nonlocal observed_posts
                    event = receive()
                    notes = browser_checkpoint(event, name, self.secrets_seen)
                    expect(notes['sale_posts'] == sale_count, 'browser_sale_post_count_mismatch')
                    if name == 'browser.start':
                        expect(notes.get('source_hashes') == source_hashes, 'browser_served_source_hash_mismatch')
                        expect('runtime' in notes, 'browser_runtime_missing')
                        self.browser_evidence['runtime'] = notes['runtime']
                    if name == 'browser.cashier_login':
                        expect(notes.get('source_hashes') == source_hashes, 'browser_served_source_hash_mismatch')
                    sale_requests = [request for request in notes['network']
                                     if request['method'] == 'POST' and request['path'] == '/internal/api/commerce/sales']
                    observed_posts += len(sale_requests)
                    expect(observed_posts == sale_count, 'browser_observed_sale_post_count_mismatch')
                    if name in ('browser.sale_confirmed', 'browser.response_loss_committed'):
                        quantity = 2 if name == 'browser.sale_confirmed' else 1
                        expect(len(sale_requests) == 1 and sale_requests[0]['status'] == 200
                               and sale_requests[0]['response_lost'] == (quantity == 1)
                               and sale_requests[0]['key'] == notes.get('key')
                               and notes.get('quantity') == quantity and notes.get('total_minor') == ITEMS[0][2] * quantity + ITEMS[1][2]
                               and 'sale_id' in notes and notes.get('key') not in sale_keys and notes['sale_id'] not in sale_ids,
                               'browser_sale_commit_evidence_invalid')
                        sale_keys.append(notes['key'])
                        sale_ids.append(notes['sale_id'])
                    if name in ('browser.receipt_reload', 'browser.recover_after_reload', 'browser.repeated_reload'):
                        expect(notes.get('sale_id') == sale_ids[-1], 'browser_reloaded_different_receipt')
                    if name == 'browser.recover_after_reload':
                        expect(notes.get('key') == sale_keys[-1] and any(
                            request['method'] == 'GET' and request['path'] == '/internal/api/operations/commerce.sale.record'
                            and request['key'] == sale_keys[-1] and request['status'] == 200 for request in notes['network']),
                            'browser_recovery_key_evidence_invalid')
                    if name in ('browser.inventory', 'browser.stock_after_sale', 'browser.stock_after_recovery'):
                        expect(notes.get('stock_rows') == len(ITEMS) and notes.get('stock_total') == expected['on_hand_total'],
                               'browser_stock_evidence_invalid')
                    expect(notes.get('external_requests', 0) == 0 and notes.get('runtime_errors', 0) == 0,
                           'browser_external_request_or_runtime_error')
                    return notes
                self.step(name, checkpoint, expected, same_as_previous=BROWSER_READ_ONLY if read_only else ())
                send({'ok': True})  # Never advance UI until the corresponding real SQL check passed.
            if getattr(self.args, 'cash', False):
                validate_cash_progress(cash_records, complete=True)
                self.browser_evidence['protocol'] = CASH_PROTOCOL
            expect(process.wait(timeout=max(1, min(20, deadline - time.monotonic()))) == 0,
                   'browser_process_failed')
            expect(not buffered, 'browser_unexpected_trailing_output')
            extra = process.stdout.read(1)
            expect(not extra, 'browser_unexpected_trailing_output')
        finally:
            self.stop_browser()

    def teardown(self):
        records = {}
        began = time.monotonic()
        if self.browser_process or self.browser_exit is not None:
            records['browser_exit'] = self.stop_browser()
            records['browser_ownership_confirmed'] = self.browser_ownership_confirmed
            records['browser_processes_absent'] = self.browser_processes_absent
        records['api_exit'] = self.stop_api() if self.api else None
        if self.drop_needed:
            dropped = self.helper('drop', self.database, allow_fail=True)
            exists = self.helper('exists', self.database, allow_fail=True)
            records['database_dropped'] = bool(dropped.get('ok')) and exists.get('exists') is False
        elif self.creation_state == 'uncertain':
            # A matching name alone is not ownership: do not drop a pre-existing
            # caller-specified DB after an interrupted refusal. Require operator review.
            records['database_dropped'] = False
            records['database_creation'] = 'unknown'
            records['operator_cleanup_required'] = True
        else:
            records['database_dropped'] = 'not_created'
            records['database_creation'] = self.creation_state
        for name in ('session.json', 'serve-ready.json'):
            (self.out / name).unlink(missing_ok=True)
        log = self.private / 'api.log'
        if log.is_file():
            # Only counts leave the private log: its text is never copied to evidence.
            lines = log.read_text(encoding='utf-8', errors='replace').splitlines()
            records['api_log_lines'] = len(lines)
            records['api_log_fail_or_crit'] = sum(1 for line in lines if line.startswith(('fail:', 'crit:')))
            records['api_log_warn'] = sum(1 for line in lines if line.startswith('warn:'))
            if self.args.keep_private_log:
                kept = Path(self.args.keep_private_log)
                shutil.copyfile(log, kept)
                os.chmod(kept, 0o600)
        shutil.rmtree(self.private, ignore_errors=True)
        records['private_dir_removed'] = not self.private.exists()
        records['ms'] = round((time.monotonic() - began) * 1000)
        return records


def load_connection(path):
    """Read only MARTHA_TEST_SQL_CONNECTION from a private KEY=VALUE file (optional 'export', quotes)."""
    for line in Path(path).read_text(encoding='utf-8').splitlines():
        key, sep, value = line.strip().removeprefix('export ').partition('=')
        if sep and key.strip() == 'MARTHA_TEST_SQL_CONNECTION':
            value = value.strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in '\'"':
                value = value[1:-1]
            os.environ['MARTHA_TEST_SQL_CONNECTION'] = value


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--out', required=True, help='directorio de evidencia saneada')
    parser.add_argument('--mode', choices=['smoke', 'serve', 'browser'], default='smoke')
    parser.add_argument('--playwright-directory', help='paquete Playwright ya instalado; obligatorio para --mode browser')
    parser.add_argument('--cash', action='store_true', help='cash-v1 combined browser protocol; requires supply and stock exception')
    parser.add_argument('--stock-exception', action='store_true', help='opt-in physical delivery and independent review; requires --supply and separately authorized runtime')
    parser.add_argument('--supply', action='store_true', help='combined sale + staff receipt journey; requires separate runtime authorization')
    parser.add_argument('--no-build', action='store_true', help='usar binarios Release ya compilados')
    parser.add_argument('--sql-env-file', help='archivo privado con MARTHA_TEST_SQL_CONNECTION=… (no se imprime)')
    parser.add_argument('--keep-private-log', help='copiar el log crudo de la API (0600) a esta ruta FUERA de --out')
    parser.add_argument('--database', help=argparse.SUPPRESS)  # only to test the refusal guard
    args = parser.parse_args(argv)
    if args.stock_exception and (not args.supply or args.mode != 'browser'):
        parser.error('--stock-exception requires --supply --mode browser')
    if args.supply and args.mode != 'browser':
        parser.error('--supply requires --mode browser')
    if args.cash and not (args.mode == 'browser' and args.supply and args.stock_exception):
        parser.error('--cash requires --mode browser --supply --stock-exception')
    if args.mode == 'browser' and not args.cash:
        parser.error('current frontend requires --cash; historical unpaid browser protocol is not executable acceptance')
    if args.mode == 'browser' and not args.playwright_directory:
        parser.error('--mode browser requiere --playwright-directory (no instala dependencias)')
    if args.keep_private_log and Path(args.keep_private_log).resolve().is_relative_to(Path(args.out).resolve()):
        parser.error('--keep-private-log debe quedar fuera de --out (el log crudo no es evidencia saneada)')
    if args.sql_env_file:
        load_connection(args.sql_env_file)
    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)
    harness = GoldenPath(args)
    outcome, error, code = 'FAIL', None, 1
    try:
        harness.setup()
        if args.mode in ('smoke', 'browser'):
            harness.smoke() if args.mode == 'smoke' else harness.browser()
            outcome, code = 'PASS', 0
        else:
            harness.serve()
    except Stop as stop:
        outcome, error, code = ('STOPPED', f'señal {stop}', 0) if args.mode == 'serve' else ('FAIL', f'señal {stop}', 1)
    except HarnessError as failure:
        error = str(failure)
    except subprocess.CalledProcessError as failure:
        error = f'comando terminó con código {failure.returncode}'
    except Exception as failure:  # never print exception text: it may carry values
        error = f'excepción {type(failure).__name__}'
    finally:
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        try:
            cleanup = harness.teardown()
        except Exception as failure:
            cleanup = {'error': type(failure).__name__}
        harness.steps.append({'step': 'teardown.stop_api_drop_database', 'ms': cleanup.get('ms'),
                              'status': 'PASS' if cleanup.get('database_dropped') in (True, 'not_created')
                              and cleanup.get('private_dir_removed') and not cleanup.get('api_log_fail_or_crit')
                              and (args.mode != 'browser' or cleanup.get('browser_processes_absent') is True)
                              else 'FAIL', **cleanup})
        if harness.steps[-1]['status'] != 'PASS':
            outcome, code = 'FAIL', 1
            error = error or 'retiro incompleto'
        try:
            table = harness.write_evidence(outcome, error)
            checked = harness.scan_for_secrets()
            print(f'Evidencia revisada: ningún secreto conocido ({checked} valores) en {harness.out}', flush=True)
        except Exception:
            outcome, code = 'FAIL', 1
            for name in ('evidence.json', 'oracles.md', 'evidence-approved'):
                (harness.out / name).unlink(missing_ok=True)
            # Do not echo the table/error/path when sanitization failed: it may carry secrets.
            print('FAIL: evidencia no aprobada; no se publica contenido.', file=sys.stderr, flush=True)
        else:
            print('\n' + table, flush=True)
            print(f'\n{outcome}: camino dorado ({args.mode}) en {round((time.monotonic() - harness.started))} s'
                  + (f' — {error}' if error else ''), flush=True)
        finally:
            shutil.rmtree(harness.private, ignore_errors=True)
            if harness.private.exists():
                code = 1
                print('FAIL: no se pudo retirar el directorio privado.', file=sys.stderr, flush=True)
    return code


if __name__ == '__main__':
    sys.exit(main())
