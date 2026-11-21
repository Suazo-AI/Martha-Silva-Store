"""Offline cash-v1 negative controls. Synthetic rows; no browser/API/SQL process."""
import copy
import hashlib
import json
import unittest
import uuid
from pathlib import Path
from test_golden_path_safety import GP, verifier


def ident(n): return str(uuid.UUID(int=n))


def fixture():
    actor, second, manager, location, item, other = [ident(n) for n in range(1,7)]
    users={'Cashier':{'id':actor},'Cashier2':{'id':second},'Manager':{'id':manager}}
    ids={'location':location,'items':[item,other], 'exception_item':ident(7)}
    commands=[]; entries=[]; tills=[]; closes=[]
    for i,kind in enumerate(('open','sale','sale','sale','open','refund','close','open','refund','close')):
        who=second if i==4 else manager if kind=='refund' else actor
        result=ident(100+i); effect=ident(200+i); till=commands[7 if i>=8 else 0]['result_id'] if i else result
        if kind=='open':
            amount=20000 if i==4 else 10000
            body=dict(locationId=location,currency='USD',openingMinor=amount);till=result
            tills.append(dict(Id=till,CashierId=who,LocationId=location,Currency='USD',Exponent=2))
            delta=amount;received=change=0;sale=reversal=None
        elif kind=='sale':
            lines=[dict(itemId=item,quantity=2 if i==1 else 1),dict(itemId=other,quantity=1)] if i!=3 else [dict(itemId=ids['exception_item'],quantity=1,exceptionReason='SINTETICO physical garment present',size='S')]
            received={1:6000,2:5000,3:2000}[i]; delta={1:5900,2:4650,3:1250}[i];change=received-delta;sale=result;reversal=None
            body=dict(tillId=till,customerId=None,lines=lines,currency='USD',receivedMinor=received)
        elif kind=='refund':
            body=dict(saleId=commands[1]['result_id'],payingTillId=till,currency='USD',reason='SINTETICO cash return',lines=[dict(saleLineId=ident(501),quantity=1)])
            delta=-1250;received=change=0;sale=body['saleId'];reversal=result
        else:
            counted=20450 if i==6 else 8750;expected=20550 if i==6 else 8750
            body=dict(tillId=till,countedMinor=counted); result=till
            closes.append(dict(Id=effect,TillId=till,ActorId=who,ExpectedMinor=expected,CountedMinor=counted,DifferenceMinor=counted-expected))
        commands.append(dict(kind=kind,actor=who,key=ident(300+i),body=body,result_id=result,effect_id=effect))
        if kind!='close': entries.append(dict(Id=effect,TillId=till,CashierId=second if i==4 else actor,ActorId=who,Kind='opening' if kind=='open' else kind,DeltaMinor=delta,ReceivedMinor=received,ChangeMinor=change,SaleId=sale,ReversalId=reversal))
    money=dict(CashEntries=entries,CashTills=tills,CashCloses=closes)
    return commands,money,users,ids


def records():
    commands,money,_,_=fixture(); result=[]
    for step in GP.CASH_STEPS:
        n=GP.CASH_LENGTHS[step]; selected=copy.deepcopy(commands[:n]); effects={c['effect_id'] for c in selected}; till_ids={c['result_id'] for c in selected if c['kind']=='open'}
        proof={k:True for k in GP.CASH_ORACLES}
        proof['money']={name:[copy.deepcopy(x) for x in rows if x['Id'] in (till_ids if name=='CashTills' else effects)] for name,rows in money.items()}
        network=[]
        added=selected[len(result[-1]['cash_commands']) if result else 0:]
        for c in added:
            path={'sale':'/internal/api/cash/sales','open':'/internal/api/cash/tills','refund':f"/internal/api/cash/sales/{c['body'].get('saleId')}/refunds",'close':f"/internal/api/cash/tills/{c['body'].get('tillId')}/close"}[c['kind']]
            network.append(dict(method='POST',path=path,status=200,key=c['key'],response_lost=step=='browser.response_loss_committed'))
        if step=='browser.recover_after_reload': network.append(dict(method='GET',path='/internal/api/operations/cash.sale',status=200,key=commands[2]['key'],response_lost=False))
        if step=='browser.cash_refund_refused': network.append(dict(method='POST',path=f"/internal/api/cash/sales/{commands[1]['result_id']}/refunds",status=403,key=ident(999),response_lost=False))
        if step in GP.SUPPLY_STEPS[1:3]: network.append(dict(method='POST',path=f'/internal/api/supply/purchase-orders/{ident(1000)}/receipts',status=200,key=ident(1001),response_lost=step==GP.SUPPLY_STEPS[2]))
        if step==GP.SUPPLY_STEPS[3]:network.append(dict(method='GET',path='/internal/api/operations/supply.receipt.create',status=200,key=ident(1001),response_lost=False))
        r=dict(step=step,dom=sorted(GP.BROWSER_DOM[step] | ({'shell'} if step in ('browser.cashier_login','browser.receipt_reload','browser.repeated_reload','browser.stock_reload') else set())),cash_commands=selected,cash_oracles=proof,sale_posts=sum(c['kind']=='sale' for c in selected),network=network,external_requests=0,runtime_errors=0)
        if step in GP.SUPPLY_STEPS[2:5]:r.update(key=ident(1001),receipt_id=ident(1002))
        if step=='browser.response_loss_committed': r['cash_pending_hash']=hashlib.sha256(json.dumps(commands[2]['body'],separators=(',',':')).encode()).hexdigest()
        if step in ('browser.start','browser.cashier_login'):
            r['source_hashes']={name:'a'*64 for name in GP.BROWSER_SOURCES}
        if step=='browser.start':r['runtime']={'chrome':'Chrome/130','node':'v22','playwright':'1.50'}
        if step in ('browser.response_loss_committed','browser.recover_after_reload','browser.repeated_reload'):
            r['sale_id']=commands[2]['result_id']
            if step!='browser.repeated_reload':r['key']=commands[2]['key']
        result.append(r)
    return result


def snapshot():
    commands,money,users,ids=fixture(); commands=commands[:2];ids['items'].append(ident(8))
    rows={'CashEntries':[], 'CashTills':[], 'CashCloses':[], 'Operations':[], 'Sales':[], 'SaleLines':[], 'StockMovements':[], 'StockBalances':[], 'SaleReversals':[], 'SaleReversalLines':[]}
    for e in money['CashEntries'][:2]:rows['CashEntries'].append({**e,'Currency':'USD','Exponent':2})
    rows['CashTills']=[{**money['CashTills'][0],'ClosedAt':None}]
    for i,c in enumerate(commands):
        body=c['body']
        if i==0: request={'LocationId':ids['location'],'Currency':'USD','OpeningMinor':10000}
        else: request={'TillId':commands[0]['result_id'],'CustomerId':None,'Lines':[{'ItemId':ids['items'][0],'Quantity':2},{'ItemId':ids['items'][1],'Quantity':1}],'Currency':'USD','ReceivedMinor':6000}
        rows['Operations'].append(dict(ActorId=c['actor'],Scope='cash.till.open' if i==0 else 'cash.sale',Key=c['key'],Fingerprint=hashlib.sha256(json.dumps(request,separators=(',',':')).encode()).hexdigest().upper(),ResultId=c['result_id'],EffectId=c['effect_id']))
    rows['Sales']=[dict(Id=commands[1]['result_id'],ActorId=users['Cashier']['id'],LocationId=ids['location'],Currency='USD',TotalMinor=5900,CustomerId=None,State='recorded',CreatedAt='2099-01-01')]
    for j,(qty,price) in enumerate(((2,1250),(1,3400))):
        rows['SaleLines'].append(dict(Id=ident(501+j),SaleId=commands[1]['result_id'],ItemId=ids['items'][j],Quantity=qty,ReturnedQuantity=0,UnitPriceMinor=price,TotalMinor=qty*price,Sku=GP.ITEMS[j][0],Name=GP.ITEMS[j][1],ExceptionReason=None,Size=None))
        rows['StockMovements'].append(dict(OperationId=commands[1]['result_id'],ItemId=ids['items'][j],ActorId=users['Cashier']['id'],LocationId=ids['location'],OnHandDelta=-qty,ReservedDelta=0,Kind='sale'))
    rows['StockBalances']=[dict(ItemId=item,LocationId=ids['location'],OnHand=amount,Reserved=0) for item,amount in zip(ids['items'],(8,9,10))]
    return commands,dict(ok=True,rows=rows,hashes={k:[] for k in ('CashEntries','CashCloses','Operations','StockMovements','SaleReversals','SaleReversalLines','StockExceptionReviews','Items','PurchaseReceipts','PurchaseReceiptLines')}),users,ids


def full_snapshot(step):
    """Separate persisted-row fixture for every refund/shift stage; never an API mock."""
    commands,money,users,ids=fixture();commands=commands[:GP.CASH_LENGTHS[step]];ids['items'].append(ident(8))
    effects={c['effect_id'] for c in commands};till_ids={c['result_id'] for c in commands if c['kind']=='open'}
    closed={c['body']['tillId'] for c in commands if c['kind']=='close'}
    rows={name:[] for name in ('CashEntries','CashCloses','CashTills','Operations','Sales','SaleLines','StockMovements','StockBalances','SaleReversals','SaleReversalLines')}
    for table in ('CashEntries','CashCloses','CashTills'):
        rows[table]=[copy.deepcopy(row) for row in money[table] if row['Id'] in (till_ids if table=='CashTills' else effects)]
    for row in rows['CashTills']: row['ClosedAt']='2099-01-01' if row['Id'] in closed else None
    for row in rows['CashEntries']: row.update(Currency='USD',Exponent=2)
    refunds=sum(c['kind']=='refund' for c in commands)
    pascal=lambda b:{k[0].upper()+k[1:]:[pascal(x) for x in v] if isinstance(v,list) else v for k,v in b.items()}
    for index,c in enumerate(commands):
        kind=c['kind'];b=c['body'];request={k:v for k,v in b.items() if k not in ('saleId',) and not (kind=='close' and k=='tillId')}
        serialized=pascal(request)
        if kind=='refund':serialized={'saleId':b['saleId'],'request':serialized}
        if kind=='close':serialized={'tillId':b['tillId'],'request':serialized}
        rows['Operations'].append(dict(ActorId=c['actor'],Scope={'open':'cash.till.open','sale':'cash.sale','refund':'cash.refund','close':'cash.till.close'}[kind],Key=c['key'],Fingerprint=hashlib.sha256(json.dumps(serialized,separators=(',',':')).encode()).hexdigest().upper(),ResultId=c['result_id'],EffectId=c['effect_id']))
        if kind=='sale':
            total={1:5900,2:4650,3:1250}[index]
            rows['Sales'].append(dict(Id=c['result_id'],ActorId=c['actor'],LocationId=ids['location'],Currency='USD',TotalMinor=total,CustomerId=None,State='partially_returned' if index==1 and refunds else 'recorded',CreatedAt='2099-01-01'))
            for j,line in enumerate(b['lines']):
                price=3400 if line['itemId']==ids['items'][1] else 1250
                line_id=ident(501+j if index==1 else 600+index*10+j)
                rows['SaleLines'].append(dict(Id=line_id,SaleId=c['result_id'],ItemId=line['itemId'],Quantity=line['quantity'],ReturnedQuantity=refunds if index==1 and j==0 else 0,UnitPriceMinor=price,TotalMinor=price*line['quantity'],Sku=GP.ITEMS[j][0],Name=GP.ITEMS[j][1],ExceptionReason=line.get('exceptionReason'),Size=line.get('size')))
                if index!=3:rows['StockMovements'].append(dict(OperationId=c['result_id'],ItemId=line['itemId'],ActorId=c['actor'],LocationId=ids['location'],OnHandDelta=-line['quantity'],ReservedDelta=0,Kind='sale'))
        if kind=='refund':
            rows['SaleReversals'].append(dict(Id=c['result_id'],SaleId=b['saleId'],ActorId=c['actor'],Kind='return',Reason=b['reason'],RecordedCreditMinor=1250))
            rows['SaleReversalLines'].append(dict(Id=ident(900+index),ReversalId=c['result_id'],SaleLineId=ident(501),Quantity=1,RecordedCreditMinor=1250))
            rows['StockMovements'].append(dict(OperationId=c['result_id'],ItemId=ids['items'][0],ActorId=c['actor'],LocationId=ids['location'],OnHandDelta=1,ReservedDelta=0,Kind='sale_return'))
    stage=GP.CASH_STEPS.index(step);supply=0 if stage<GP.CASH_STEPS.index(GP.SUPPLY_STEPS[1]) else 2 if stage<GP.CASH_STEPS.index(GP.SUPPLY_STEPS[2]) else 5
    sales=sum(c['kind']=='sale' for c in commands)
    quantities=(10-(0 if sales==0 else 2 if sales==1 else 3)+supply+refunds,10-min(sales,2),10)
    rows['StockBalances']=[dict(ItemId=item,LocationId=ids['location'],OnHand=q,Reserved=0) for item,q in zip(ids['items'],quantities)]
    hashes={k:[hashlib.sha256(json.dumps(row,sort_keys=True).encode()).hexdigest() for row in v] for k,v in rows.items()}
    for table in ('StockExceptionReviews','Items','PurchaseReceipts','PurchaseReceiptLines'):hashes[table]=[]
    return commands,dict(ok=True,rows=rows,hashes=hashes),users,ids


class CashControls(unittest.TestCase):
    def reject(self,value):
        with self.assertRaises(GP.HarnessError): GP.validate_cash_progress(value,complete=True)

    def test_full_offline_fixture_passes(self): GP.validate_cash_progress(records(),complete=True)
    def test_missing_each_checkpoint_rejected(self):
        for i in range(len(GP.CASH_STEPS)):
            value=records();del value[i];self.reject(value)
    def test_out_of_order_rejected(self):
        value=records();value[2],value[3]=value[3],value[2];self.reject(value)
    def test_missing_every_mandatory_oracle_rejected(self):
        for key in (*GP.CASH_ORACLES,'money'):
            value=records();del value[-1]['cash_oracles'][key];self.reject(value)
    def test_false_oracle_rejected(self):
        for key in GP.CASH_ORACLES:
            value=records();value[-1]['cash_oracles'][key]=False;self.reject(value)
    def test_duplicate_cash_effect_rejected(self):
        value=records();value[-1]['cash_oracles']['money']['CashEntries'].append(copy.deepcopy(value[-1]['cash_oracles']['money']['CashEntries'][0]));self.reject(value)
    def test_wrong_till_cashier_actor_sale_reversal_id_rejected(self):
        for key in ('TillId','CashierId','ActorId','SaleId','ReversalId','Id'):
            value=records();value[-1]['cash_oracles']['money']['CashEntries'][1][key]=ident(9000);self.reject(value)
    def test_changed_ledger_amounts_rejected(self):
        for key in ('DeltaMinor','ReceivedMinor','ChangeMinor'):
            value=records();value[-1]['cash_oracles']['money']['CashEntries'][1][key]+=1;self.reject(value)
    def test_wrong_close_arithmetic_rejected(self):
        for key in ('ExpectedMinor','CountedMinor','DifferenceMinor'):
            value=records();value[-1]['cash_oracles']['money']['CashCloses'][0][key]+=100;self.reject(value)
    def test_zero_shortage_rejected(self):
        value=records();value[-1]['cash_oracles']['money']['CashCloses'][0]['DifferenceMinor']=0;self.reject(value)
    def test_float_and_bool_amounts_rejected(self):
        for amount in (5900.0,True):
            value=records();value[-1]['cash_oracles']['money']['CashEntries'][1]['DeltaMinor']=amount;self.reject(value)
    def test_repost_rejected(self):
        value=records();value[8]['network'].append(dict(method='POST',path='/internal/api/cash/sales',status=200,key=ident(302),response_lost=False));self.reject(value)
    def test_loss_requires_real_200_and_original_key(self):
        for key,wrong in (('status',None),('response_lost',False),('key',ident(999))):
            value=records();value[7]['network'][0][key]=wrong;self.reject(value)
    def test_pending_body_hash_changed_rejected(self):
        value=records();value[7]['cash_pending_hash']='0'*64;self.reject(value)
    def test_recovery_requires_get_original_key(self):
        value=records();value[8]['network'][0]['key']=ident(999);self.reject(value)
    def test_cashier_refusal_requires_403(self):
        value=records();value[24]['network'][0]['status']=200;self.reject(value)
    def test_changed_command_body_or_actor_rejected(self):
        for key,wrong in (('actor',ident(999)),('key',ident(999))):
            value=records();value[-1]['cash_commands'][0][key]=wrong;self.reject(value)
    def test_independent_sql_rows_pass(self):
        c,s,u,i=snapshot(); GP.validate_cash_snapshot(c,s,u,i,None,'browser.sale_confirmed')
    def test_sql_guid_letter_case_does_not_change_identity(self):
        c,s,u,i=snapshot()
        for table in s['rows'].values():
            for row in table:
                for key,value in row.items():
                    if isinstance(value,str) and GP.UUID_PATTERN.fullmatch(value):row[key]=value.upper()
        GP.validate_cash_snapshot(c,s,u,i,None,'browser.sale_confirmed')
    def test_sql_identity_and_operation_result_mutants_rejected(self):
        for table,key in (('Operations','Fingerprint'),('Operations','ResultId'),('Operations','EffectId'),('Sales','ActorId'),('SaleLines','ItemId'),('CashEntries','TillId'),('StockMovements','OperationId'),('StockBalances','LocationId')):
            c,s,u,i=snapshot();s['rows'][table][-1][key]=ident(987)
            with self.assertRaises(GP.HarnessError):GP.validate_cash_snapshot(c,s,u,i,None,'browser.sale_confirmed')
    def test_sql_amounts_and_duplicate_effect_mutants_rejected(self):
        for table,key in (('Sales','TotalMinor'),('SaleLines','UnitPriceMinor'),('CashEntries','ReceivedMinor'),('CashEntries','ChangeMinor'),('StockBalances','OnHand'),('StockMovements','OnHandDelta')):
            c,s,u,i=snapshot();s['rows'][table][-1][key]+=1
            with self.assertRaises(GP.HarnessError):GP.validate_cash_snapshot(c,s,u,i,None,'browser.sale_confirmed')
        c,s,u,i=snapshot();s['rows']['CashEntries'].append(copy.deepcopy(s['rows']['CashEntries'][1]))
        with self.assertRaises(GP.HarnessError):GP.validate_cash_snapshot(c,s,u,i,None,'browser.sale_confirmed')
    def test_excluded_rows_preserved(self):
        c,s,u,i=snapshot();prior=copy.deepcopy(s);s['hashes']['Items']=['altered-row']
        with self.assertRaisesRegex(GP.HarnessError,'cash_unrelated_rows_changed'):GP.validate_cash_snapshot(c,s,u,i,prior,'browser.receipt_reload')

    def test_all_31_persisted_checkpoints_pass(self):
        prior=None
        for step in GP.CASH_STEPS:
            c,s,u,i=full_snapshot(step);GP.validate_cash_snapshot(c,s,u,i,prior,step);prior=s
    def test_refund_original_line_authorizer_and_paying_shift_mutants(self):
        for table,key in (('SaleReversalLines','SaleLineId'),('SaleReversals','SaleId'),('SaleReversals','ActorId'),('CashEntries','CashierId'),('CashEntries','TillId')):
            c,s,u,i=full_snapshot('browser.cash_later_refund');s['rows'][table][-1][key]=ident(9876)
            with self.assertRaises(GP.HarnessError):GP.validate_cash_snapshot(c,s,u,i,None,'browser.cash_later_refund')
    def test_earlier_close_and_other_cashier_till_preserved(self):
        for table,index,key,value in (('CashCloses',0,'DifferenceMinor',0),('CashTills',1,'ClosedAt','2099-changed'),('CashTills',0,'ClosedAt','2099-changed')):
            _,prior,_,_=full_snapshot('browser.cash_later_till');c,s,u,i=full_snapshot('browser.cash_later_refund');s['rows'][table][index][key]=value
            with self.assertRaises(GP.HarnessError):GP.validate_cash_snapshot(c,s,u,i,prior,'browser.cash_later_refund')
    def test_no_fabricated_exception_balance(self):
        c,s,u,i=full_snapshot('browser.stock_sale');s['rows']['StockBalances'].append(dict(ItemId=i['exception_item'],LocationId=i['location'],OnHand=0,Reserved=0))
        with self.assertRaises(GP.HarnessError):GP.validate_cash_snapshot(c,s,u,i,None,'browser.stock_sale')
    def test_no_extra_zero_balance_for_unrelated_item(self):
        c,s,u,i=full_snapshot('browser.cash_later_refund');s['rows']['StockBalances'].append(dict(ItemId=ident(9898),LocationId=i['location'],OnHand=0,Reserved=0))
        with self.assertRaises(GP.HarnessError):GP.validate_cash_snapshot(c,s,u,i,None,'browser.cash_later_refund')
    def test_consistently_changed_quantity_rejected_offline(self):
        value=records()
        for r in value:
            if len(r['cash_commands'])>1:r['cash_commands'][1]['body']['lines'][0]['quantity']=1
        self.reject(value)
    def test_supply_repost_and_recovery_identity_rejected(self):
        value=records();value[16]['network'].append(dict(method='POST',path=f'/internal/api/supply/purchase-orders/{ident(1000)}/receipts',status=200,key=ident(1001),response_lost=False));self.reject(value)
        value=records();value[15]['network'][0]['key']=ident(888);self.reject(value)
        value=records();value[15]['receipt_id']=ident(888);self.reject(value)

    def publication(self,mutate=None):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            src=Path(tmp)/'src';src.mkdir();dest=Path(tmp)/'dest'
            data=dict(mode='browser',outcome='PASS',cash_protocol=GP.CASH_PROTOCOL,browser={'protocol':GP.CASH_PROTOCOL,'runtime':{'chrome':'Chrome/130','node':'v22','playwright':'1.50'},'source_hashes':{name:'a'*64 for name in GP.BROWSER_SOURCES}},steps=records())
            for row in data['steps']:row.update(status='PASS',oracle_failures=[],oracles={**dict.fromkeys(GP.ALWAYS_ZERO,0),'migrations_applied':4,**GP.cash_counts(row['step'])})
            data['steps'].append(dict(step='teardown.stop_api_drop_database',status='PASS',database_dropped=True,private_dir_removed=True,browser_processes_absent=True,browser_ownership_confirmed=True,api_log_fail_or_crit=0,api_exit=0))
            if mutate:mutate(data)
            (src/'evidence.json').write_text(json.dumps(data));(src/'oracles.md').write_text('synthetic')
            (src/'evidence-approved').write_text(json.dumps(dict(schema=1,files={name:hashlib.sha256((src/name).read_bytes()).hexdigest() for name in verifier.FILES})))
            verifier.publish(src,dest)
            self.assertEqual((dest/'evidence.json').read_bytes(),(src/'evidence.json').read_bytes())
    def test_complete_synthetic_evidence_publishes_exact_bytes(self):self.publication()
    def test_every_global_sql_oracle_required_by_publication(self):
        for key in (*GP.ALWAYS_ZERO,'migrations_applied',*GP.cash_counts(GP.CASH_STEPS[-1])):
            with self.assertRaises(Exception):self.publication(lambda d,key=key:d['steps'][-2]['oracles'].pop(key))
    def test_cleanup_required_by_publication(self):
        with self.assertRaises(Exception):self.publication(lambda d:d['steps'].pop())
        for key in ('database_dropped','private_dir_removed','browser_processes_absent','browser_ownership_confirmed'):
            with self.assertRaises(Exception):self.publication(lambda d,key=key:d['steps'][-1].update({key:False}))

    def test_source_and_migration_inventory(self):
        self.assertIn('dev/savia-staff-ui/cash.mjs',GP.BROWSER_SOURCES)
        self.assertEqual(GP.MIGRATIONS[-1],'20261107221938_FirstCashRegister')
        self.assertEqual(len(GP.MIGRATIONS),4)
    def test_current_browser_requires_explicit_cash_before_runtime(self):
        import contextlib,io
        from unittest.mock import patch
        with patch.object(GP,'GoldenPath') as runtime,contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit): GP.main(['--mode','browser','--out','unused','--playwright-directory','unused'])
            runtime.assert_not_called()
    def test_publication_rejects_partial_pass_even_with_new_scan_marker(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            src=Path(tmp)/'src';src.mkdir();dest=Path(tmp)/'dest'
            data=dict(mode='browser',outcome='PASS',browser={'protocol':GP.CASH_PROTOCOL,'runtime':{'chrome':'Chrome/130','node':'v22','playwright':'1.50'},'source_hashes':{name:'a'*64 for name in GP.BROWSER_SOURCES}},steps=[])
            (src/'evidence.json').write_text(json.dumps(data));(src/'oracles.md').write_text('synthetic')
            (src/'evidence-approved').write_text(json.dumps(dict(schema=1,files={name:hashlib.sha256((src/name).read_bytes()).hexdigest() for name in verifier.FILES})))
            with self.assertRaises(Exception):verifier.publish(src,dest)
            self.assertEqual(list(dest.iterdir()),[])

if __name__=='__main__':unittest.main()
