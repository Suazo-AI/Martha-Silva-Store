"""Real local pilot browser flow, using agent-browser and direct API read-backs.

Start with pilot.py reset then up, with three per-account pilot passwords in the environment.
No mocked endpoints, optional steps, packages, external services or stored plaintext credentials.
Each run creates distinct sample codes and can run again against the same seeded pilot.
"""
from __future__ import annotations
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

WEB = os.environ.get("SAVIA_E2E_WEB", "http://127.0.0.1:5080").rstrip("/")
API = WEB + "/api/v1"
SESSION = "savia-owner-e2e"
SUPERVISOR = "gerente.muestra"
CASHIER = "gerente.muestra"
OWNER = "duena.muestra"
PASSWORDS = {name+'.muestra':os.environ.get('SAVIA_PILOT_PASSWORD_'+name.upper()) for name in ('duena','gerente','vendedor1','vendedor2','bodega')}

CODE = "7500001000014"
SHOTS = Path(__file__).resolve().parents[2] / "docs" / "pilot" / "screens"
AB = shutil.which("agent-browser")
if AB and Path(AB).suffix.lower() in (".cmd", ".bat"):
    # The npm CMD shim reparses quotes/metacharacters in eval. Invoke the same CLI's Rust binary.
    native = Path(AB).parent / "node_modules" / "agent-browser" / "bin" / "agent-browser-win32-x64.exe"
    if native.is_file():
        AB = str(native)
results = []
EXPECTED_NAMES = {}
BROWSER_RUNTIME = None

class StepFailed(Exception):
    pass

# ---------- browser ----------
def ab(*args: str, timeout: int = 45, secret_input: str | None = None) -> str:
    # Output goes to a temp file, not a pipe: the first command starts the agent-browser
    # daemon, which inherits the handles; a pipe would then never reach EOF.
    with tempfile.TemporaryFile() as out:
        try:
            code = subprocess.run([AB, "--session", SESSION, *args], stdout=out, stderr=subprocess.STDOUT,
                                  input=secret_input.encode() if secret_input is not None else None, timeout=timeout).returncode
        except subprocess.TimeoutExpired:
            raise StepFailed(f"agent-browser {' '.join(args[:2])} timed out after {timeout}s") from None
        out.seek(0)
        output = out.read().decode("utf-8", "replace").strip()
    if code != 0:
        raise StepFailed(f"agent-browser {args[0]}: {output}"[:1200])
    return output


def js(expression: str):
    """Evaluates JSON.stringify(expression) in the page and returns the Python value."""
    out = ab("eval", f"JSON.stringify((() => {{ {expression} }})() ?? null)")
    value = json.loads(out.splitlines()[-1])
    return json.loads(value) if isinstance(value, str) else value


def close_browser(timeout=5):
    failure = None
    for _ in range(2):
        try:
            ab("close", timeout=max(1, timeout))
            failure = None
            break
        except StepFailed as error:
            failure = error
    if failure:
        sessions = json.loads(ab("session", "list", "--json", timeout=max(1, timeout)))["data"]["sessions"]
        if any(s == SESSION or isinstance(s, dict) and (s.get("name") == SESSION or s.get("session") == SESSION) for s in sessions):
            stop_session_daemon()
    # On Windows the daemon can exit before acknowledging close (10060).
    # Verify the actual postcondition. A live session still fails the run.
    deadline = time.monotonic() + timeout
    while True:
        sessions = json.loads(ab("session", "list", "--json", timeout=max(1, timeout)))["data"]["sessions"]
        active = any(s == SESSION or isinstance(s, dict) and (s.get("name") == SESSION or s.get("session") == SESSION) for s in sessions)
        if not active:
            break
        if time.monotonic() >= deadline:
            raise failure or StepFailed("agent-browser session remains active after close")
        time.sleep(0.1)
    if failure:
        print("browser close acknowledgement lost; session list confirms it stopped", flush=True)


def stop_session_daemon():
    """Stop only this session's verified Rust daemon. Never kill other browser sessions."""
    if os.name != 'nt':
        return
    info=BROWSER_RUNTIME
    if info is None:
        try:
            info=json.loads(ab('session','info','--json',timeout=3))['data']
        except StepFailed:
            # A hung daemon cannot answer diagnostics. This exact session's PID record remains local.
            socket=Path.home()/'.agent-browser'
            try: pid=int((socket/(SESSION+'.pid')).read_text().strip())
            except (OSError,ValueError): raise StepFailed('Cannot identify this browser session daemon') from None
            info={'session':SESSION,'pid':pid,'socketDir':str(socket),'runtime':{'session':SESSION,'backgroundPid':pid}}
    runtime=info.get('runtime') or {}
    if info.get('session')!=SESSION or not isinstance(info.get('pid'),int) or runtime.get('session')!=SESSION or runtime.get('backgroundPid')!=info.get('pid'):
        raise StepFailed('Cannot identify this browser session daemon')
    socket=Path(info['socketDir']).resolve()
    pid_file=socket/(SESSION+'.pid')
    if pid_file.exists() and pid_file.read_text().strip()!=str(info['pid']):
        raise StepFailed('Browser session PID changed before cleanup')
    # The CLI identifies the named session. Recheck its exact executable before stopping that PID.
    script = r"""
$ErrorActionPreference='Stop'
$p=Get-CimInstance Win32_Process -Filter ('ProcessId = '+$env:SAVIA_BROWSER_CLEANUP_PID)
if(!$p){exit 0}
$actual=$p.ExecutablePath
if($actual.StartsWith('\\?\')){$actual=$actual.Substring(4)}
if($actual -eq $env:SAVIA_BROWSER_CLEANUP_EXE){
 $process=Get-Process -Id $p.ProcessId -ErrorAction Stop
 Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop
 if(!$process.WaitForExit(3000)){exit 3}
}else{exit 2}
"""
    process = subprocess.run(['powershell','-NoProfile','-NonInteractive','-Command',script],
        env={**os.environ,'SAVIA_BROWSER_CLEANUP_PID':str(info['pid']),'SAVIA_BROWSER_CLEANUP_EXE':str(Path(AB).resolve())},capture_output=True,timeout=10)
    if process.returncode:
        raise StepFailed('Could not stop the browser session daemon')
    # A forced stop leaves transport records behind. Remove only this verified PID's runtime files.
    socket=Path(info['socketDir']).resolve()
    pid_file=socket/(SESSION+'.pid')
    if pid_file.exists() and pid_file.read_text().strip()!=str(info['pid']):
        raise StepFailed('Browser session PID changed during cleanup')
    for suffix in ('pid','port','engine','stream','target','version'):
        path=(socket/(SESSION+'.'+suffix)).resolve()
        if path.parent!=socket:
            raise StepFailed('Browser runtime path is outside the socket directory')
        path.unlink(missing_ok=True)


def text(selector: str):
    return js(f"const e = document.querySelector({json.dumps(selector)}); return e ? e.textContent.trim() : null;")


def wait_for(predicate_js: str, what: str, seconds: float = 12):
    deadline = time.time() + seconds
    while time.time() < deadline:
        if js(f"return Boolean({predicate_js});"):
            return
        time.sleep(0.25)
    raise StepFailed(f"timed out waiting for {what}")


def go(route: str, ready_selector: str):
    js(f"location.hash = {json.dumps('#/' + route)}; return true;")
    wait_for(f"document.querySelector({json.dumps(ready_selector)})", f"{route} ({ready_selector})")


def action_ref(selector: str):
    """Take a fresh accessibility snapshot before each interaction, then use its ref."""
    target = js(f"const e=document.querySelector({json.dumps(selector)}); if (!e) return null; const label = [...(e.labels || [])].map(l=>{{const c=l.cloneNode(true);c.querySelectorAll('input,select,textarea,button').forEach(n=>n.remove());return c.textContent.trim();}}).join(' '); return {{name:e.getAttribute('aria-label') || label || e.textContent.trim(), role:['BUTTON','SUMMARY'].includes(e.tagName)?'button':e.tagName==='SELECT'?'combobox':e.type==='search'?'searchbox':e.type==='number'?'spinbutton':'textbox'}};")
    check(target is not None, f"No element for {selector}")
    refs = json.loads(ab("snapshot", "-i", "--json"))["data"]["refs"]
    matches = [key for key, node in refs.items() if node.get("name") == target["name"] and node.get("role") == target["role"]]
    check(len(matches) == 1, f"Expected one accessible ref for {selector}, found {len(matches)}")
    return "@" + matches[0]


def fill(selector: str, value: str):
    ab("fill", action_ref(selector), value)


def click(selector: str):
    ab("click", action_ref(selector))


def select(selector: str, value: str):
    ab("select", action_ref(selector), value)


def scan(selector: str, code: str):
    """A keyboard-wedge scanner: real keystrokes, then Enter, into the focused field."""
    ab("focus", selector)
    ab("keyboard", "type", code)
    ab("press", "Enter")


def layout_check():
    check(js("return !document.querySelector('img');"), 'product image found')
    check(js("return !document.body.textContent.includes('Sin foto');"), 'photo placeholder found')
    check(js("return [document.documentElement,document.body,document.querySelector('#screen'),document.querySelector('.ticket')].filter(Boolean).every(e=>e.scrollWidth<=e.clientWidth);"), 'page or ticket has horizontal overflow')
    check(js("return [...document.querySelectorAll('.ticket input,.ticket button')].filter(e=>e.getClientRects().length).every(e=>{const p=e.closest('.ticket').getBoundingClientRect(),r=e.getBoundingClientRect();return r.left>=p.left && r.right<=p.right+1;});"), 'ticket control is clipped horizontally')


def shot(name: str):
    layout_check()
    ab('set','viewport','1440','900')
    layout_check()
    ab('set','viewport','1024','768')
    SHOTS.mkdir(parents=True, exist_ok=True)
    ab("screenshot", str(SHOTS / f"{name}.png"))


# ---------- API read-backs ----------
def call(method: str, path: str, body=None, token: str | None = None):
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(API + path, data=data, method=method,
                                     headers={"Content-Type": "application/json", **({"Authorization": f"Bearer {token}"} if token else {})})
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            raw = response.read().decode() or "null"
            return response.status, json.loads(raw)
    except urllib.error.HTTPError as error:
        raw = error.read().decode()
        return error.code, (json.loads(raw) if raw else None)


def on_hand(token: str, item_id: str) -> int:
    status, rows = call("GET", f"/stock?itemId={item_id}", token=token)
    if status != 200:
        raise StepFailed(f"GET /stock -> {status}")
    return sum(r["onHand"] for r in rows)


def money(minor: int) -> str:
    sign = "-" if minor < 0 else ""
    whole, cents = divmod(abs(minor), 100)
    return f"{sign}C$ {whole:,}.{cents:02d}"


def lead(value):
    """Leading integer of a screen text such as '5piezas en total' or '0 · Agotado'."""
    match = re.match(r"\s*(\d+)", value or "")
    return match.group(1) if match else None


def check(condition: bool, message: str):
    if not condition:
        raise StepFailed(message)


def step(name: str, fn):
    try:
        detail = fn() or "ok"
        results.append((name, "PASS", detail))
        print(f"PASS  {name}: {detail}", flush=True)
        return True
    except StepFailed as error:
        results.append((name, "FAIL", str(error)))
        print(f"FAIL  {name}: {error}", flush=True)
        return False


def login_ui(user: str):
    # Credentials go through stdin into the CLI's encrypted vault, never arguments or snapshots.
    if js("return !document.querySelector('#shell').hidden;"):
        click("#logout")
    wait_for("document.querySelector('#login-user')", "login form")
    profile = SESSION + "-login"
    ab("auth", "save", profile, "--url", WEB + "/", "--username", user,
       "--password-stdin", "--username-selector", "#login-user", "--password-selector", "#login-pass",
       "--submit-selector", "#access button[type=submit]", secret_input=PASSWORDS[user])
    try:
        ab("auth", "login", profile, "--no-navigate")
    finally:
        ab("auth", "delete", profile)
    wait_for("!document.querySelector('#shell').hidden && document.querySelector('#screen').children.length", "signed-in shell")
    if user in EXPECTED_NAMES:
        wait_for("document.querySelector('#operator-label').textContent.startsWith("+json.dumps(EXPECTED_NAMES[user])+")",'signed-in operator')


def main() -> int:
    import datetime
    global BROWSER_RUNTIME
    sys.stdout.reconfigure(encoding='utf-8')
    check(AB and all(PASSWORDS.values()),'agent-browser and five environment passwords are required')
    tokens={}
    for name in PASSWORDS:
        status,body=call('POST','/auth/login',{'loginName':name,'password':PASSWORDS[name]})
        check(status==200,'API login '+name);tokens[name]=body['token']
        EXPECTED_NAMES[name]=body['displayName']
    owner=tokens['duena.muestra'];manager=tokens['gerente.muestra'];warehouse=tokens['bodega.muestra']
    today=(datetime.datetime.now(datetime.timezone.utc)-datetime.timedelta(hours=6)).date().isoformat()
    def get(path,token=manager):
        status,body=call('GET',path,token=token);check(status==200,f'GET {path} status {status}');return body
    def post(path,body=None,token=manager):
        status,result=call('POST',path,body,token);check(status in (200,204),f'POST {path} status {status}: {result if status not in (200,204) else "ok"}');return result
    errors=[]
    try:
        ab('open',WEB+'/');BROWSER_RUNTIME=json.loads(ab('session','info','--json',timeout=5))['data'];ab('set','viewport','1024','768')
        expected={
          'duena.muestra':{'venta','caja','historial','recepcion','inventario','clientes','ajustes','excepciones','reporte','aprobaciones','comisiones','precios','calidad'},
          'gerente.muestra':{'venta','caja','historial','recepcion','inventario','clientes','ajustes','excepciones','reporte','comisiones','calidad'},
          'vendedor1.muestra':{'ajustes','comisiones'},'vendedor2.muestra':{'ajustes','comisiones'},
          'bodega.muestra':{'recepcion','inventario','ajustes','calidad'},
        }
        for name,routes in expected.items():
            login_ui(name)
            visible=set(js("return [...document.querySelectorAll('#nav a')].filter(a=>!a.hidden).map(a=>a.dataset.route);"))
            check(visible==routes,'navigation '+name)
            if name.startswith('vendedor'):
                check(js("return document.querySelector('#till-state').hidden;"),'seller cannot see till')
                status,_=call('GET','/cash/registers',token=tokens[name]);check(status==403,'seller API till denied')
            print('PASS role '+name,flush=True)
        # A stock worker classifies real expected units; cancellation is read back before any write.
        suppliers=get('/suppliers',warehouse);catalog=get('/catalog/items')
        variants=[v for product in catalog for v in product['variants']]
        first=get('/catalog/search?q='+CODE)[0]
        other=next(v for v in variants if v['productName']!=first['productName'] and v['available']>=3)
        second=next(v for v in get('/catalog/search?q='+other['sku']) if v['itemId']==other['itemId'])
        session=str(uuid.uuid4())
        post('/receiving/sessions',{'containerId':str(uuid.uuid4()),'scanSessionId':session,'reference':'E2E-'+uuid.uuid4().hex[:8],'supplierId':suppliers[0]['supplierId']},warehouse)
        post(f'/receiving/sessions/{session}/scans',{'scanId':str(uuid.uuid4()),'rawCode':CODE,'quantity':5},warehouse)
        js('localStorage.setItem("savia.device.reception",'+json.dumps(json.dumps({'sessionId':session,'reference':'Calidad E2E'}))+');return true;')
        ab('reload')
        go('recepcion','.quality-check')
        fill('input[aria-label="Buena '+CODE+'"]','3');fill('input[aria-label="Dañada '+CODE+'"]','1');fill('input[aria-label="Faltante '+CODE+'"]','1')
        click('.save-quality');wait_for("document.querySelector('#confirm-yes')",'quality confirmation');shot('confirmacion')
        click('#confirm-no');check(get(f'/receiving/sessions/{session}/quality',warehouse)==[],'No volver leaves quality API unchanged')
        click('.save-quality');click('#confirm-yes');wait_for("document.querySelector('.quality-check [role=status]').textContent==='Calidad guardada.'",'quality persisted')
        check(get(f'/receiving/sessions/{session}/quality',warehouse)[0]['faltante']==1,'Si confirmar persists quality')
        shot('recepcion-calidad');print('PASS quality and both confirmation choices',flush=True)
        login_ui('gerente.muestra');post(f'/receiving/sessions/{session}/approve');post(f'/receiving/sessions/{session}/post')
        registers=get('/cash/registers');check(not registers[0]['openTillId'],'closed till before browser sale')
        till=str(uuid.uuid4());post('/cash/tills',{'tillId':till,'registerId':registers[0]['registerId'],'currencyCode':'NIO','openingMinor':100000,'lines':[{'denominationMinor':50000,'quantity':2}]})
        go('venta','#seller-chips');wait_for("document.querySelectorAll('#seller-chips button').length===2",'seller chips')
        wait_for("document.querySelector('#cards button.product')",'sale catalog')
        check(js("return !document.querySelector('#sale-customer-search');"),'no customer field in normal Venta')
        sellers=get('/sellers')
        click('#seller-chips button[data-seller="'+sellers[0]['sellerId']+'"]')
        js('savia.handleScan('+json.dumps(first['barcode'])+');return true;');wait_for("document.querySelectorAll('.tline').length===1",'first seller line')
        click('#seller-chips button[data-seller="'+sellers[1]['sellerId']+'"]')
        js('savia.handleScan('+json.dumps(second['barcode'])+');return true;');wait_for("document.querySelectorAll('.tline').length===2",'second seller line')
        shot('venta-vendedoras')
        amount=first['unitPriceMinor']+second['unitPriceMinor'];fill('#received',str(amount/100))
        click('#pay');wait_for("document.querySelector('#receipt') && !document.querySelector('#receipt').hidden",'sale receipt')
        saleid=js("return document.querySelector('#receipt .num.muted')?.textContent?.match(/[0-9a-f-]{36}/i)?.[0] ?? document.querySelector('#receipt').textContent.match(/[0-9a-f-]{36}/i)?.[0];")
        detail=get('/sales/'+saleid);check(detail['customerId'] is None,'normal sale API has no customer')
        check([l['sellerId'].lower() for l in detail['lines']]==[s['sellerId'].lower() for s in sellers],'ticket seller attribution persisted')
        # A return generates an advance; customer identity is used only for that advance.
        customers=get('/customers?q=Clienta')
        post('/sales/'+saleid+'/returns/credit',{'reversalId':str(uuid.uuid4()),'creditId':str(uuid.uuid4()),'tillId':till,'customerId':customers[0]['customerId'],'reason':'Cambio de talla E2E','lines':[{'saleLineId':detail['lines'][0]['saleLineId'],'quantity':1,'restockPool':'store'}]})
        go('comisiones','#commissions');wait_for("document.querySelectorAll('#commissions article').length===2",'commission rows')
        report=get('/reports/commissions?period=day&date='+today)
        for row in report:
            shown=text('#commissions [data-seller="'+row['sellerId']+'"] .commission-payable')
            check(shown=='Por pagar '+money(row['commissionPayableMinor']),'web commission equals API')
        shot('comisiones');print('PASS two sellers and return; commissions equal API',flush=True)
        # Only the owner edits values. Cancellation and acceptance both have authoritative API reads.
        values=get('/catalog/values?q='+first['sku']);old=values[0]
        status,_=call('POST','/catalog/items/'+first['itemId']+'/values',{'changeId':str(uuid.uuid4()),'priceMinor':old['priceMinor']+100,'costMinor':old['costMinor'],'reason':'No autorizado'},manager)
        check(status==403,'manager cannot change price')
        login_ui('duena.muestra');go('precios','#price-search');fill('#price-search',first['sku']);click('#screen button');wait_for("document.querySelectorAll('#price-list article').length===1",'one price result')
        newprice=old['priceMinor']+100
        fill('#price-list input[aria-label="Precio de '+first['sku']+'"]',str(newprice/100))
        fill('#price-list input[aria-label="Motivo de '+first['sku']+'"]','Precio aprobado E2E')
        click('.save-values');click('#confirm-no');check(get('/catalog/values?q='+first['sku'],owner)[0]['priceMinor']==old['priceMinor'],'cancel price leaves API unchanged')
        click('.save-values');click('#confirm-yes');wait_for("!document.querySelector('#modal').open",'price confirmation closed')
        deadline=time.monotonic()+10
        while get('/catalog/values?q='+first['sku'],owner)[0]['priceMinor']!=newprice:
            check(time.monotonic()<deadline,'price persisted');time.sleep(.1)
        shot('precios')
        newbody={'saleId':str(uuid.uuid4()),'tillId':till,'currencyCode':'NIO','lines':[{'lineNumber':1,'itemId':first['itemId'],'quantity':1,'unitPriceMinor':newprice,'sellerId':sellers[0]['sellerId']}],'tenders':[{'tenderNumber':1,'tenderKind':'card','amountMinor':newprice}]}
        post('/sales',newbody);check(get('/sales/'+newbody['saleId'])['lines'][0]['unitPriceMinor']==newprice,'next sale uses owner price')
        go('aprobaciones','#approval-list');wait_for("document.querySelector('#approval-list article')",'approvals');shot('aprobaciones')
        count=get('/cash/tills/'+till+'/summary')['expectedCashMinor'];denominations=get('/cash/denominations');remaining=count;lines=[]
        for d in denominations:
            q,remaining=divmod(remaining,d);lines.append({'denominationMinor':d,'quantity':q})
        check(remaining==0,'count exactly representable');countid=str(uuid.uuid4());post('/cash/tills/'+till+'/counts',{'cashCountId':countid,'lines':lines})
        post('/cash/tills/'+till+'/close',{'closureId':str(uuid.uuid4()),'cashCountId':countid})
        print('PASS owner price, approvals and till close',flush=True)
    except Exception as error:
        errors.append(str(error));print('FAIL '+str(error),flush=True)
        try: shot('failure')
        except Exception: pass
    finally:
        # Cleanup failures never replace the original flow failure.
        try:
            console=json.loads(ab('console','--json'))['data']['messages'];page=json.loads(ab('errors','--json'))['data']['errors']
            bad=[m for m in console if m['type'] in ('error','assert')]
            print(f'console errors: {len(bad)}; page errors: {len(page)}',flush=True)
            if bad or page:errors.append('browser console/page errors')
        except Exception as error:errors.append('console inspection: '+str(error))
        try: close_browser()
        except Exception as error: errors.append('cleanup: '+str(error))
    print('E2E '+('FAIL' if errors else 'PASS'),flush=True)
    for error in errors:print(error,flush=True)
    return 1 if errors else 0

if __name__=='__main__':sys.exit(main())
