#!/usr/bin/env python3
"""End-to-end smoke test of the running Masaya pilot (start it with `python savia/tools/pilot.py up`).

Flow: five roles -> receive/classify -> owner registers a new code -> manager resolves/rejects ->
post -> two sellers and a card sale -> return advance -> commissions -> owner price -> till close -> audit.

Exit 0 = pass. Per-login passwords use the same environment variables and shared opt-in as pilot.py; never printed.
"""
import getpass
import json
import os
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "db"))
import saviadb                                        # noqa: E402
from pilot import pilot_passwords                     # noqa: E402

DB = "SAVIA_DEV_pilot"
URL = os.environ.get("SAVIA_PILOT_URL", "http://127.0.0.1:5080")
BARCODE = "7500001000014"                             # seeded: Blusa de lino blanca S (MUESTRA)
DENOMINATIONS = []


class Fail(Exception):
    pass


def check(condition, message):
    if not condition:
        raise Fail(message)
    print(f"ok   {message}", flush=True)


def call(method, path, body=None, token=None, expect=(200, 204), approval=None):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(URL + path, data=data, method=method)
    request.add_header("Content-Type", "application/json")
    if token:
        request.add_header("Authorization", "Bearer " + token)
    if approval:
        request.add_header("X-Savia-Approval", approval)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            status, raw = response.status, response.read()
    except urllib.error.HTTPError as error:
        status, raw = error.code, error.read()
    payload = json.loads(raw) if raw else None
    if status not in expect:
        raise Fail(f"{method} {path} -> {status} {payload}")
    return status, payload


def login(name, password):
    _, body = call("POST", "/api/v1/auth/login", {"loginName": name, "password": password})
    return body["token"]


def on_hand(token, item_id):
    _, rows = call("GET", f"/api/v1/stock?itemId={item_id}", token=token)
    return sum(r["onHand"] for r in rows if r["pool"] == "store")


def count_lines(amount):
    lines = []
    for d in DENOMINATIONS:
        n, amount = divmod(amount, d)
        if n:
            lines.append({"denominationMinor": d, "quantity": n})
    return lines


def sql(text):
    code, out = saviadb.run_sql(DB, text)
    if code != 0:
        raise Fail(f"SQL failed: {out.strip()[-400:]}")
    return out


def main():
    import datetime
    global DENOMINATIONS
    passwords=pilot_passwords()
    users={name:login(name.lower()+'.muestra',passwords['SAVIA_PILOT_PASSWORD_'+name]) for name in ('DUENA','GERENTE','VENDEDOR1','VENDEDOR2','BODEGA')}
    owner,manager,stock=users['DUENA'],users['GERENTE'],users['BODEGA']
    _,me=call('GET','/api/v1/me',token=manager)
    check(me['branchName']=='Masaya','five logins at Masaya')
    for name in ('VENDEDOR1','VENDEDOR2','BODEGA'):
        call('GET','/api/v1/cash/registers',token=users[name],expect=(403,))
    call('GET','/api/v1/approvals',token=manager,expect=(403,))
    _,items=call('GET','/api/v1/catalog/search?q='+BARCODE,token=manager)
    item,price=items[0]['itemId'],items[0]['unitPriceMinor']
    _,redacted=call('GET','/api/v1/catalog/lookup?code='+BARCODE,token=stock)
    check(redacted[0]['unitPriceMinor'] is None,'stock worker sees no price')
    _,suppliers=call('GET','/api/v1/suppliers',token=stock)
    session=str(uuid.uuid4());checkid=str(uuid.uuid4())
    stock_before=on_hand(manager,item)
    call('POST','/api/v1/receiving/sessions',{'containerId':str(uuid.uuid4()),'scanSessionId':session,'reference':'SMOKE-'+uuid.uuid4().hex[:8],'supplierId':suppliers[0]['supplierId']},stock)
    call('POST',f'/api/v1/receiving/sessions/{session}/scans',{'scanId':str(uuid.uuid4()),'rawCode':BARCODE,'quantity':6},stock)
    base='991'+str(uuid.uuid4().int%1000000000).zfill(9)
    newcode=base+str((-sum(int(c)*(1 if i%2==0 else 3) for i,c in enumerate(base)))%10)
    _,unknown=call('POST',f'/api/v1/receiving/sessions/{session}/scans',{'scanId':str(uuid.uuid4()),'rawCode':newcode},stock)
    check(unknown['matchStatus']=='unknown' and on_hand(manager,item)==stock_before,'scans create no stock before posting')
    productid,newitem=str(uuid.uuid4()),str(uuid.uuid4())
    call('POST','/api/v1/catalog/products',{'productId':productid,'name':'Accesorio de verificación'},owner)
    registration={'itemId':newitem,'productId':productid,'sku':'SMOKE-'+uuid.uuid4().hex[:10],'variantName':'Accesorio de tela azul','currencyCode':'NIO','unitPriceMinor':70000,'unitCostMinor':30000,'barcode':newcode}
    call('POST','/api/v1/catalog/items',registration,manager,expect=(403,))
    call('POST','/api/v1/catalog/items',registration,owner)
    call('POST',f'/api/v1/receiving/sessions/{session}/scans/{unknown["scanId"]}/resolve',{'itemId':newitem,'reason':'Código registrado por dueña'},manager)
    _,rejected=call('POST',f'/api/v1/receiving/sessions/{session}/scans',{'scanId':str(uuid.uuid4()),'rawCode':'ETIQUETA-ILEGIBLE-'+uuid.uuid4().hex[:8]},stock)
    call('POST',f'/api/v1/receiving/sessions/{session}/scans/{rejected["scanId"]}/reject',{'reason':'Etiqueta ilegible'},manager)
    quality={'checkId':checkid,'itemId':item,'buena':4,'danada':1,'manchada':0,'malOlor':0,'faltante':1,'reason':'Una dañada y una faltante'}
    call('POST',f'/api/v1/receiving/sessions/{session}/quality',quality,stock)
    call('POST',f'/api/v1/receiving/sessions/{session}/quality',quality,stock)
    call('POST',f'/api/v1/receiving/sessions/{session}/quality',{'checkId':str(uuid.uuid4()),'itemId':newitem,'buena':1,'danada':0,'manchada':0,'malOlor':0,'faltante':0,'reason':'Accesorio en buen estado'},stock)
    call('POST',f'/api/v1/receiving/sessions/{session}/approve',token=manager)
    call('POST',f'/api/v1/receiving/sessions/{session}/post',token=manager)
    check(on_hand(manager,item)==stock_before+4 and on_hand(manager,newitem)==1,'only good units become sellable stock')
    check(True,'quality and reception posted through real procedures')
    _,sellers=call('GET','/api/v1/sellers',token=manager)
    _,registers=call('GET','/api/v1/cash/registers',token=manager)
    check(not registers[0]['openTillId'],'smoke requires closed till')
    till=str(uuid.uuid4())
    call('POST','/api/v1/cash/tills',{'tillId':till,'registerId':registers[0]['registerId'],'currencyCode':'NIO','openingMinor':100000,'lines':[{'denominationMinor':50000,'quantity':2}]},manager)
    sale=str(uuid.uuid4());today=(datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(hours=6)).date().isoformat()
    path='/api/v1/reports/commissions?period=day&date='+today
    _,before=call('GET',path,token=manager)
    body={'saleId':sale,'tillId':till,'currencyCode':'NIO','lines':[{'lineNumber':1,'itemId':item,'quantity':2,'unitPriceMinor':price,'sellerId':sellers[0]['sellerId']},{'lineNumber':2,'itemId':item,'quantity':1,'unitPriceMinor':price,'sellerId':sellers[1]['sellerId']}],
      'tenders':[{'tenderNumber':1,'tenderKind':'card','amountMinor':price*3}]}
    call('POST','/api/v1/sales',body,manager);call('POST','/api/v1/sales',body,manager)
    _,detail=call('GET','/api/v1/sales/'+sale,token=manager)
    check(detail['customerId'] is None and len(detail['lines'])==2,'normal sale has two sellers and no customer; optional POS voucher')
    _,customers=call('GET','/api/v1/customers?q=Clienta',token=manager)
    returned={'reversalId':str(uuid.uuid4()),'creditId':str(uuid.uuid4()),'tillId':till,'customerId':customers[0]['customerId'],'reason':'Cambio de talla','lines':[{'saleLineId':detail['lines'][0]['saleLineId'],'quantity':1,'restockPool':'store'}]}
    call('POST',f'/api/v1/sales/{sale}/returns/credit',returned,manager)
    _,after=call('GET',path,token=manager)
    byid={row['sellerId']:row for row in before}
    for i,row in enumerate(sellers):
        current=next(x for x in after if x['sellerId']==row['sellerId'])
        earned=(price*(2 if i==0 else 1)*row['rateBps'])//10000
        reversed=earned//2 if i==0 else 0
        check(current['commissionPayableMinor']-byid[row['sellerId']]['commissionPayableMinor']==earned-reversed,'commission snapshot and return reversal agree')
    for name in ('VENDEDOR1','VENDEDOR2'):
        _,own=call('GET',path,token=users[name]);check(len(own)==1,'seller sees only own commissions')
    values={'changeId':str(uuid.uuid4()),'priceMinor':price+100,'costMinor':28000,'reason':'Precio aprobado smoke'}
    call('POST',f'/api/v1/catalog/items/{item}/values',values,manager,expect=(403,))
    call('POST',f'/api/v1/catalog/items/{item}/values',values,owner)
    call('POST',f'/api/v1/catalog/items/{item}/values',values,owner)
    _,DENOMINATIONS=call('GET','/api/v1/cash/denominations',token=manager)
    countid=str(uuid.uuid4())
    call('POST',f'/api/v1/cash/tills/{till}/counts',{'cashCountId':countid,'lines':[{'denominationMinor':50000,'quantity':2}]},manager)
    call('POST',f'/api/v1/cash/tills/{till}/close',{'closureId':str(uuid.uuid4()),'cashCountId':countid},manager)
    _,summary=call('GET','/api/v1/reports/summary?period=day&date='+today,token=manager)
    check('grossMarginMinor' in summary,'manager sees SQL gross margin')
    call('GET','/api/v1/approvals',token=owner)
    sql('EXEC audit.usp_CheckConservation @Throw=1;')
    check(True,'conservation has zero violations')
    print('PILOT SMOKE PASS')
    return 0

if __name__=='__main__':
    try: sys.exit(main())
    except Fail as error: print('FAIL '+str(error),file=sys.stderr);sys.exit(1)
