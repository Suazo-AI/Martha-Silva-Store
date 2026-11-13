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
SESSION = "savia-e2e"
SUPERVISOR = "supervisora.muestra"
CASHIER = "cajera.muestra"
OWNER = "duena.muestra"
PASSWORDS = {
    CASHIER: os.environ.get("SAVIA_PILOT_PASSWORD_CAJERA"),
    SUPERVISOR: os.environ.get("SAVIA_PILOT_PASSWORD_SUPERVISORA"),
    OWNER: os.environ.get("SAVIA_PILOT_PASSWORD_DUENA"),
}
CODE = "7500001000014"
SHOTS = Path(__file__).resolve().parents[2] / "docs" / "pilot" / "screens"
AB = shutil.which("agent-browser")
if AB and Path(AB).suffix.lower() in (".cmd", ".bat"):
    # The npm CMD shim reparses quotes/metacharacters in eval. Invoke the same CLI's Rust binary.
    native = Path(AB).parent / "node_modules" / "agent-browser" / "bin" / "agent-browser-win32-x64.exe"
    if native.is_file():
        AB = str(native)
results = []

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
    try:
        ab("close")
    except StepFailed as error:
        failure = error
    # On Windows the daemon can exit before acknowledging close (10060).
    # Verify the actual postcondition. A live session still fails the run.
    deadline = time.monotonic() + timeout
    while True:
        sessions = json.loads(ab("session", "list", "--json"))["data"]["sessions"]
        active = any(s == SESSION or isinstance(s, dict) and (s.get("name") == SESSION or s.get("session") == SESSION) for s in sessions)
        if not active:
            break
        if time.monotonic() >= deadline:
            raise failure or StepFailed("agent-browser session remains active after close")
        time.sleep(0.1)
    if failure:
        print("browser close acknowledgement lost; session list confirms it stopped", flush=True)


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


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    if not AB or not all(PASSWORDS.values()):
        print("Need agent-browser and SAVIA_PILOT_PASSWORD_CAJERA / _SUPERVISORA / _DUENA.", file=sys.stderr)
        return 2
    if not WEB.startswith(("http://127.0.0.1:", "http://localhost:")):
        raise StepFailed("Only local pilot URLs are allowed")
    status, body = call("POST", "/auth/login", {"loginName": SUPERVISOR, "password": PASSWORDS[SUPERVISOR]})
    check(status == 200, f"API login status {status}")
    token = body["token"]
    item = call("GET", f"/catalog/lookup?code={CODE}", token=token)[1][0]
    item_id = item["itemId"]
    run = uuid.uuid4().hex[:10]
    unknown, rejected = "990" + str(uuid.uuid4().int)[:10], "REJECT-" + run
    state = {"stock0": on_hand(token, item_id)}
    ab("open", WEB + "/")
    ab("set", "viewport", "1024", "768")
    js("sessionStorage.clear(); localStorage.clear(); return true;")
    ab("reload")
    ab("console", "--clear")
    ab("errors", "--clear")

    def read(path):
        status, body = call("GET", path, token=token)
        check(status == 200, f"GET {path} -> {status} {body}")
        return body

    def inventory(expected, name):
        go("inventario", "#stock-body")
        fill("#inv-search", item["sku"])
        selector = f"#stock-body tr[data-item='{item_id}'] td.onhand"
        wait_for("document.querySelector('#inv-count')?.textContent && !document.querySelector('#inv-refresh').disabled", "stock response")
        api_stock = on_hand(token, item_id)
        check(api_stock == expected, f"API stock {api_stock}, expected {expected}")
        api_rows = read(f"/stock?itemId={item_id}")
        if api_rows:
            check(text(selector) == str(api_stock), f"screen stock {text(selector)} vs API {api_stock}")
        else:
            check(api_stock == 0 and text(selector) is None, "API has no stock row but screen invents one")
            check("Sin resultados" in text('#stock-body') or "no reporta existencias" in text('#stock-body'), "empty API stock needs an empty screen state")
        shot(name)
        return f"screen=API stock {api_stock}"

    def s_login():
        shot("ingreso-1")
        login_ui(SUPERVISOR)
        me = read("/me")
        check(me["displayName"] in text("#operator-label"), "operator differs from /me")
        check(me["branchName"] == text("#branch-label"), "branch differs from /me")
        return "supervisora.muestra; branch and operator match /me"

    def s_scan():
        go("recepcion", "#rec-supplier")
        supplier = read("/suppliers")[0]
        select("#rec-supplier", supplier["supplierId"])
        fill("#rec-reference", "WEB-" + run)
        shot("recepcion-1")
        click("#screen form button[type=submit]")
        wait_for("document.querySelector('#scan-input')", "scan field")
        state["session"] = js("return JSON.parse(localStorage.getItem('savia.device.reception')).sessionId;")
        # Four plain-input/Enter readings and one scanner burst with no focused input.
        for _ in range(4):
            fill("#scan-input", CODE)
            ab("press", "Enter")
        js("document.activeElement.blur(); return true;")
        ab("press", "Tab")
        # Synchronous key bursts emulate keyboard wedge events, including input loss of focus.
        js("document.activeElement.blur(); for (const key of " + json.dumps(CODE) + ") document.body.dispatchEvent(new KeyboardEvent('keydown',{key,bubbles:true})); document.body.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true,cancelable:true})); return true;")
        wait_for("document.querySelector('#rec-lines .qty')?.textContent === '5'", "single line quantity 5")
        lines = read(f"/receiving/sessions/{state['session']}/lines")
        screen = js("return [...document.querySelectorAll('#rec-lines .rline')].map(r=>({code:r.dataset.code,quantity:Number(r.querySelector('.qty').textContent)}));")
        check(len(lines) == len(screen) == 1 and lines[0]["quantity"] == screen[0]["quantity"] == 5,
              f"one grouped line expected: API {lines}, screen {screen}")
        check(screen[0]["code"] == lines[0]["rawCode"] == CODE, "barcode differs")
        progress = read(f"/receiving/sessions/{state['session']}")
        check(text("#rec-totals") == f"1 código · {progress['matchedUnits']} piezas", "totals differ from progress")
        shot("recepcion-2")
        return "5 readings, one line, quantity 5; includes scan without focus"

    def s_unknowns():
        fill("#scan-input", unknown)
        ab("press", "Enter")
        row = f"#rec-lines [data-code='{unknown}']"
        wait_for(f"document.querySelector({json.dumps(row)})", "unknown line")
        lines = read(f"/receiving/sessions/{state['session']}/lines")
        pending = next(l for l in lines if l["rawCode"] == unknown)
        check(pending["matchStatus"] == "unknown" and "Sin registrar" in text(row), "unknown status differs")
        shot("recepcion-3-codigo-nuevo")
        click(row + " button")
        wait_for("document.querySelector('dialog[open] #reg-name')", "registration dialog")
        fill("#reg-name", "Producto web " + run + "")
        fill("#reg-price", "499")
        fill("#reg-cost", "200")
        shot("recepcion-4-registrar")
        click("#modal button[type=submit]")
        wait_for("!document.querySelector('dialog[open]')", "registration resolved")
        wait_for(f"document.querySelector({json.dumps(row)})?.dataset.status === 'matched'", "resolved line")
        registered = read("/catalog/lookup?code=" + unknown)[0]
        state["new_item"] = registered["itemId"]
        lines = read(f"/receiving/sessions/{state['session']}/lines")
        resolved = next(l for l in lines if l["rawCode"] == unknown)
        check(resolved["itemId"] == registered["itemId"] and text(row + " .qty") == str(resolved["quantity"]), "resolved screen differs from API")
        check(on_hand(token, registered["itemId"]) == 0, "registration created stock")
        fill("#scan-input", rejected)
        ab("press", "Enter")
        row = f"#rec-lines [data-code='{rejected}']"
        wait_for(f"document.querySelector({json.dumps(row)})", "second unknown")
        click(row + " button:last-child")
        wait_for("document.querySelector('dialog[open] #reject-reason')", "reject dialog")
        fill("#reject-reason", "Etiqueta ilegible")
        shot("recepcion-rechazar")
        click("#modal button[type=submit]")
        wait_for(f"document.querySelector({json.dumps(row)})?.dataset.status === 'rejected'", "rejected line")
        lines = read(f"/receiving/sessions/{state['session']}/lines")
        reject = next(l for l in lines if l["rawCode"] == rejected)
        check(reject["matchStatus"] == "rejected" and "rechazada" in text(row), "rejected screen differs from API")
        check(text(row + " .qty") == str(reject["quantity"]), "rejected quantity differs")
        shot("recepcion-3")
        return "registered original scan matched; rejected scan retained; no stock created"

    def s_post():
        go("recepcion/revisar", "#approve")
        progress = read(f"/receiving/sessions/{state['session']}")
        check(text("#rev-matched") == str(progress["matchedUnits"]) == "6", "review matched quantity differs")
        shot("revisar-1")
        click("#approve")
        wait_for("document.querySelector('#post')", "approved reception")
        check(read(f"/receiving/sessions/{state['session']}")["status"] == "approved" and text("#rev-status") == "Aprobada", "approval status differs")
        check(on_hand(token, item_id) == state["stock0"], "stock changed before post")
        click("#post")
        wait_for("document.querySelector('#post-stock')", "post result")
        for id_, expected in [(item_id, state["stock0"] + 5), (state["new_item"], 1)]:
            actual = on_hand(token, id_)
            check(actual == expected and text(f"#post-stock [data-item='{id_}']") == str(actual), "post stock differs")
        check(read(f"/receiving/sessions/{state['session']}")["status"] == "posted", "API session not posted")
        jobs = read("/labels/jobs")
        mine = [j for j in jobs if j["itemId"] in (item_id, state["new_item"])]
        check(js("return document.querySelectorAll('#label-jobs tbody tr').length;") == len(mine), "label rows differ")
        state["stock1"] = state["stock0"] + 5
        shot("revisar-2")
        return "approved then posted: seeded stock +5, new item +1, rejected +0"

    def s_till():
        login_ui(CASHIER)
        go("venta", "#till-register")
        register = next(r for r in read("/cash/registers") if not r["openTillId"])
        select("#till-register", register["registerId"])
        fill("#open-den-100000", "1")
        shot("abrir-caja")
        click("#screen form button[type=submit]")
        wait_for("document.querySelector('#sale-search')", "sale screen")
        state["till"] = js("return JSON.parse(localStorage.getItem('savia.device.till'));")
        summary = read(f"/cash/tills/{state['till']['tillId']}/summary")
        check(summary["openingMinor"] == state["till"]["openingMinor"] == 100000, "opening differs")
        check(sum(l['denominationMinor']*l['quantity'] for l in summary['openingLines']) == 100000, 'opening denomination read-back differs')
        check(text("#till-state")  .startswith("Caja abierta") and summary["status"] == "open", "till status differs")
        return "cajera.muestra opened till; API opening 100000"

    def s_sale():
        for _ in range(2):
            fill("#sale-search", CODE)
            ab("press", "Enter")
        wait_for(f"document.querySelector('#qty-{item_id}')?.value === '2'", "ticket quantity 2")
        check(text("#total") == money(2 * read('/catalog/lookup?code=' + CODE)[0]["unitPriceMinor"]), "ticket price differs")
        # This CLI omits native DisclosureTriangle nodes from refs, even in a full snapshot.
        # Use its semantic text action for this native disclosure; all form controls use fresh refs.
        ab("snapshot", "--json")
        ab("find", "text", "Cliente y anticipos (opcional)", "click")
        fill("#sale-customer-search", "Clienta")
        click("#sale-customer-panel > button")
        wait_for("document.querySelector('#sale-customers button')", "customer search")
        click("#sale-customers button:first-child")
        wait_for("document.querySelector('#sale-customer-status')?.className === 'ok'", "customer selected")
        fill("#received", "3000")
        shot("venta-2")
        click("#pay")
        wait_for("!document.querySelector('#receipt').hidden", "sale receipt")
        sale_id = re.search(r"Venta ([0-9a-fA-F-]{36})", text("#receipt")).group(1)
        state["cash_sale"] = sale_id
        sale = read("/sales/" + sale_id)
        check(sale["customerId"] is not None, "customer was not attached to cash sale")
        check(text("#receipt-total") == money(sale["totalMinor"]), "receipt total differs")
        check(text("#receipt-change") == money(300000 - sale["totalMinor"]), "change differs")
        check(on_hand(token, item_id) == state["stock1"] - 2, "sale stock differs")
        shot("venta-3")
        return f"sale of 2; screen=API total {sale['totalMinor']}; change {300000 - sale['totalMinor']}"

    def s_card():
        fill("#sale-search", CODE)
        ab("press", "Enter")
        wait_for(f"document.querySelector('#qty-{item_id}')?.value === '1'", "card ticket")
        fill(f"#qty-{item_id}", "2")
        ab("press", "Tab")
        wait_for(f"document.querySelector('#total')?.textContent === {json.dumps(money(2 * item['unitPriceMinor']))}", "edited ticket quantity")
        fill(f"#qty-{item_id}", "1")
        ab("press", "Tab")
        wait_for(f"document.querySelector('#total')?.textContent === {json.dumps(money(item['unitPriceMinor']))}", "restored ticket quantity")
        select("#payment-0-kind", "transfer")
        check(js("return document.querySelector('#pay').disabled;"), "transfer accepted without reference")
        fill("#payment-0-reference", "TRANSFER-" + run)
        check(not js("return document.querySelector('#pay').disabled;"), "transfer with reference unavailable")
        check(text("#balance") == money(0), "transfer must not produce cash change")
        shot("venta-transferencia")
        click("#split-payment")
        select("#payment-0-kind", "cash")
        fill("#payment-0-amount", "299")
        fill("#received", "500")
        fill("#payment-1-amount", "300")
        fill("#payment-1-reference", "AUTH-SPLIT-" + run)
        check(text("#balance") == money(20100), "split payment preview must apply change to cash only")
        shot("venta-dividida")
        click("#payment-rows .payment-row:last-child button")
        select("#payment-0-kind", "card")
        fill("#payment-0-reference", "AUTH-" + run)
        before = read(f"/cash/tills/{state['till']['tillId']}/summary")
        check(text("#balance") == money(0), "card must not produce cash change")
        check(not js("return Boolean(document.querySelector('#received'));"), "card must not ask for cash received")
        shot("venta-tarjeta")
        click("#pay")
        wait_for("!document.querySelector('#receipt').hidden", "card receipt")
        sale_id = re.search(r"Venta ([0-9a-fA-F-]{36})", text("#receipt")).group(1)
        state["card_sale"] = sale_id
        sale = read("/sales/" + sale_id)
        check(text("#receipt-total") == money(sale["totalMinor"]), "card receipt total differs")
        check(text("#receipt-change") == money(0), "card receipt change must be zero")
        after = read(f"/cash/tills/{state['till']['tillId']}/summary")
        check(after["expectedCashMinor"] == before["expectedCashMinor"], "card changed expected cash")
        check(on_hand(token, item_id) == state["stock1"] - 3, "card stock differs")
        return "card sale persisted; stock -1; expected cash unchanged; change zero"

    def s_history():
        go("historial", "#history-search")
        fill("#history-search", state["cash_sale"])
        ab("press", "Enter")
        selector = f"#history-rows [data-sale='{state['cash_sale']}']"
        wait_for(f"document.querySelector({json.dumps(selector)})", "history receipt match")
        check(js("return document.querySelectorAll('#history-rows article').length;") == 1, "receipt search must have one sale")
        check(item["sku"] in text(selector) and "Talla" in text(selector), "history garment details missing")
        check(not js("return Boolean(document.querySelector('img'));"), "history contains image")
        shot("historial")
        click(selector + " button.primary")
        wait_for("document.querySelector('#reprint')", "receipt screen")
        sale = read("/sales/" + state["cash_sale"])
        check(text("#receipt-total") == money(sale["totalMinor"]), "history receipt differs from API")
        check(item["sku"] in text("#receipt"), "receipt garment details missing")
        # Invoke the action with a local print spy so headless Chrome does not open a blocking dialog.
        js("window.__printCalls=0; window.print=()=>window.__printCalls++; return true;")
        click("#reprint")
        check(js("return window.__printCalls;") == 1, "Reimprimir did not invoke browser print")
        check(js("const walk = rules => [...rules].flatMap(r=>[r,...(r.cssRules ? walk(r.cssRules) : [])]); return [...document.styleSheets].flatMap(s=>walk(s.cssRules)).some(r=>r.type===CSSRule.PAGE_RULE && r.style.size.startsWith('80mm'));"),
              "browser did not accept the receipt's 80 mm page size")
        shot("recibo")
        go("historial", "#history-search")
        fill("#history-search", item["sku"])
        ab("press", "Enter")
        wait_for(f"document.querySelector({json.dumps(selector)})", "SKU history match")
        # History searches the sale's recorded garment name, not a later catalog label.
        fill("#history-search", sale["lines"][0]["name"])
        ab("press", "Enter")
        wait_for(f"document.querySelector({json.dumps(selector)})", "garment name history match")
        return "receipt, SKU and garment search; text details; receipt total=API; Reimprimir invokes print"

    def s_return():
        go("historial", "#history-search")
        fill("#history-search", state["cash_sale"])
        ab("press", "Enter")
        selector = f"#history-rows [data-sale='{state['cash_sale']}']"
        wait_for(f"document.querySelector({json.dumps(selector)})", "sale to return")
        click(selector + " button:last-child")
        wait_for("document.querySelector('#return-qty-1')", "return line")
        fill("#return-qty-1", "1")
        fill("#return-reason", "Cambio de talla")
        select("#refund-method", "credit")
        before = read(f"/cash/tills/{state['till']['tillId']}/summary")
        js("window.scrollTo(0,0); return true;")
        check(js("const r=document.querySelector('#return-submit').getBoundingClientRect(); return r.top>=0 && r.bottom<=innerHeight;"),
              "return confirmation must be visible at 1024x768 without scrolling")
        shot("devolucion")
        click("#return-submit")
        wait_for("document.querySelector('dialog[open] #approval-user')", "supervisor approval")
        shot("devolucion-aprobacion")
        profile = SESSION + "-approval"
        ab("auth", "save", profile, "--url", WEB + "/", "--username", SUPERVISOR,
           "--password-stdin", "--username-selector", "#approval-user", "--password-selector", "#approval-pass",
           "--submit-selector", "#modal button[type=submit]", secret_input=PASSWORDS[SUPERVISOR])
        try:
            ab("auth", "login", profile, "--no-navigate")
        finally:
            ab("auth", "delete", profile)
        wait_for("!document.querySelector('#return-result').hidden", "return result")
        wait_for("document.querySelector('#return-cash')", "return cash read-back")
        after = read(f"/cash/tills/{state['till']['tillId']}/summary")
        check(after["cashRefundsMinor"] == before["cashRefundsMinor"], "credit return must not create a cash refund")
        check(after["expectedCashMinor"] == before["expectedCashMinor"], "credit return must not change expected cash")
        returned = next(row for row in read("/sales/" + state["cash_sale"])["reversals"] if row["reversalId"] == text("#return-id"))
        state["credit"] = returned["creditId"]
        check(returned["creditMinor"] == item["unitPriceMinor"] and returned["lines"][0]["quantity"] == 1, "return record differs")
        check(text("#return-total") == money(item["unitPriceMinor"]), "return total differs")
        check(money(after["expectedCashMinor"]) in text("#return-cash"), "return cash screen differs from API")
        stock = on_hand(token, item_id)
        check(stock == state["stock1"] - 2, "return did not restock exactly 1")
        check(text(f"#return-result [data-item='{item_id}']").endswith(str(stock)), "return stock screen differs from API")
        check("cajera" in text("#operator-label").lower(), "approval replaced cashier session")
        shot("devolucion-resultado")
        return "one unit restocked; store credit issued; cash unchanged; stock and cash screen=API; cashier session retained"

    def s_customers():
        go("clientes", "#customer-search")
        fill("#customer-search", "Clienta")
        ab("press", "Enter")
        wait_for("document.querySelector('#customer-rows button')", "seeded customers")
        customer_id = js("return document.querySelector('#customer-rows tr').dataset.customer;")
        click("#customer-rows tr:first-child button")
        wait_for("!document.querySelector('#customer-balance').hidden", "customer credit balance")
        credits = [row for row in read("/credits/search?q=Clienta") if row["customerId"] == customer_id]
        check(any(row["creditId"] == state["credit"] for row in credits), "new return credit missing from API")
        for credit in credits:
            selector = f"#customer-balance [data-credit='{credit['creditId']}'][data-branch='{credit['branchId']}']"
            check(text(selector + " .credit-balance") == money(credit["availableMinor"]), "customer balance differs from API")
            check(credit["branchName"] in text(selector), "credit branch missing")
        shot("clientes")
        return "sample customer credit read from API"

    def s_credit_sale():
        go("venta", "#sale-search")
        fill("#sale-search", CODE)
        ab("press", "Enter")
        wait_for(f"document.querySelector('#qty-{item_id}')?.value === '1'", "credit ticket")
        select("#payment-0-kind", "credit")
        fill("#sale-customer-search", "Clienta")
        click("#sale-customer-panel > button")
        wait_for("document.querySelector('#sale-customers button')", "credit customer search")
        click("#sale-customers button:first-child")
        wait_for("document.querySelector('#sale-customer-status')?.className === 'ok'", "credit customer selected")
        select("#payment-0-credit", state["credit"])
        before = read(f"/cash/tills/{state['till']['tillId']}/summary")
        check(text("#balance") == money(0), "credit must not produce change")
        shot("venta-anticipo")
        click("#pay")
        wait_for("!document.querySelector('#receipt').hidden", "credit sale receipt")
        sale_id = re.search(r"Venta ([0-9a-fA-F-]{36})", text("#receipt")).group(1)
        sale = read("/sales/" + sale_id)
        check(sale["tenders"][0]["creditId"] == state["credit"], "sale did not redeem selected credit")
        check(text("#receipt-total") == money(sale["totalMinor"]) and text("#receipt-change") == money(0), "credit receipt differs")
        credits = read("/credits/search?q=Clienta")
        check(not any(row["creditId"] == state["credit"] for row in credits), "fully redeemed credit remains available")
        after = read(f"/cash/tills/{state['till']['tillId']}/summary")
        check(after["expectedCashMinor"] == before["expectedCashMinor"], "credit redemption changed cash")
        check(on_hand(token, item_id) == state["stock1"] - 3, "credit sale stock differs")
        return "selected customer credit redeemed atomically; stock -1; cash unchanged; change zero"

    def s_report():
        go("reporte", "#day-report")
        wait_for("document.querySelector('#report-sale-count')", "day report totals")
        date = js("return document.querySelector('#report-date').value;")
        report = read("/reports/day?date=" + date)
        for row in report["totals"]:
            check(text("#report-total-" + row["currencyCode"]) == money(row["totalMinor"]), "day report gross total differs")
        check(text("#report-sale-count") == str(report["salesCount"]), "day report sale count differs")
        check(text("#report-unit-count") == str(report["unitsSold"]), "day report units differ")
        for row in report["tenders"]:
            selector = f"#report-tenders [data-kind='{row['tenderKind']}'][data-currency='{row['currencyCode']}']"
            check(text(selector + " td:last-child") == money(row["totalMinor"]), "day report tender differs")
        for row in report["returns"]:
            check(money(row["creditMinor"]) in text(f"#report-returns [data-reversal='{row['reversalId']}']"), "day report return differs")
        for till in report["tills"]:
            for key in ("expectedMinor", "countedMinor", "differenceMinor", "saleGrossMinor", "returnGrossMinor", "netSalesMinor"):
                expected = "—" if till[key] is None else money(till[key])
                check(text(f"#day-report [data-till='{till['tillId']}'] [data-field='{key}']") == expected, f"day report {key} differs")
        check(report["salesCount"] >= 2, "day report missed new sales")
        for period in ['week','month','year']:
            select('#report-period',period)
            wait_for(f"document.querySelector('#summary-totals')?.dataset.period === '{period}'", 'period report')
            summary=read('/reports/summary?period='+period+'&date='+date)
            for key in ['salesCount','unitsSold','customersServed','newCustomers','stockExceptionsCount']:
                check(text('#summary-'+key)==str(summary[key]),period+' '+key+' differs from API')
            for key in ['grossMinor','discountsMinor','netMinor','returnsMinor','averageTicketMinor']:
                check(text('#summary-'+key)==money(summary[key]),period+' '+key+' differs from API')
        shot('reportes')
        return 'day, week, month and year totals equal API values'

    def s_count():
        go("caja", "#counted")
        summary = read(f"/cash/tills/{state['till']['tillId']}/summary")
        expected = summary["expectedCashMinor"]
        check(text("#expected") == money(expected), "expected cash differs from summary")
        remaining = expected
        denominations = js("return [...document.querySelectorAll('.denoms input')].map(e=>Number(e.id.slice(4)));")
        for d in denominations:
            q, remaining = divmod(remaining, d)
            if q:
                fill(f"#den-{d}", str(q))
        check(remaining == 0 and text("#counted") == money(expected), "count differs from API expected")
        check(not js("return Boolean(document.querySelector('#close-till'))"), "cashier sees manager close action")
        click("#save-count")
        wait_for("document.querySelector('#screen .ok')", "saved count")
        state["count"] = js("return JSON.parse(localStorage.getItem('savia.device.count.' + " + json.dumps(state['till']['tillId']) + "));")
        shot("cierre")
        login_ui(SUPERVISOR)
        go("caja", "#close-till")
        check(text("#counted") == text("#expected") == money(expected), "supervisor did not recover cashier count")
        click("#close-till")
        wait_for("document.querySelector('#closure')", "closure result")
        status, closure = call("POST", f"/cash/tills/{state['till']['tillId']}/close",
            {"closureId":state["count"]["pending"]["closureId"], "cashCountId":state["count"]["pending"]["cashCountId"]}, token=token)
        check(status == 200, f"close read-back status {status}: {closure}")
        check(text("#closure-expected") == money(closure["expectedMinor"]), "closure expected differs")
        check(text("#closure-counted") == money(closure["countedMinor"]), "closure counted differs")
        check(closure["differenceMinor"] == 0 and text("#closure-difference") == "Cuadra: " + money(closure["differenceMinor"]), "closure difference differs")
        summary = read(f"/cash/tills/{state['till']['tillId']}/summary")
        check(summary["status"] == "closed" and summary["closureId"] == closure["closureId"], "closed summary differs")
        shot("caja-2")
        return "cashier count; supervisor closure; screen=API difference 0"

    def s_grid():
        wait_for("document.querySelector('#cards .product')", "catalog cards")
        products = read('/catalog/items')
        garment = next(p for p in products if any(v['itemId'] == item_id for v in p['variants']))
        state['product_id'] = garment['productId']
        check(len(products) >= 7, 'catalog missing seeded garments')
        check(js("return !document.querySelector('#cards .product:disabled');"), 'out-of-stock card must stay selectable')
        check(js("return document.querySelector('.catalog').getBoundingClientRect().right <= document.querySelector('.ticket').getBoundingClientRect().left + 1;"), 'ticket must stay beside catalog')
        check(not js("return document.querySelector('#palette-picker') !== null;"), 'palette is outside Ajustes')
        shot('venta-grid')
        select('#sale-type', 'Blusas')
        check(js("return [...document.querySelectorAll('#cards .product')].every(e=>e.dataset.type === 'Blusas');"), 'type filter failed')
        select('#sale-size', 'S')
        shot('venta-filtros')
        select('#sale-size', '')
        click(f"#cards [data-product='{garment['productId']}']")
        wait_for("document.querySelector('#sale-sizes')", 'size picker')
        check('disponibles' in text('#sale-sizes') and 'Sin existencia' in text('#sale-sizes'), 'size stocks missing')
        shot('venta-tallas')
        click(f"#sale-sizes [data-item='{item_id}']")
        check(js(f"return document.querySelector('#qty-{item_id}').value === '1';"), 'tap did not add garment')
        shot('venta')
        check(js("const a=document.querySelector('#ticket-lines').getBoundingClientRect(), l=document.querySelector('#ticket-lines .tline').getBoundingClientRect(); return l.top>=a.top && l.bottom<=a.bottom+1;"), 'single ticket line controls are clipped')
        layout_check()
        fill(f'#discount-{item_id}', '5')
        ab('press', 'Tab')
        fill('#ticket-discount', '5')
        ab('press', 'Tab')
        expected = item['unitPriceMinor'] * 90 // 100
        check(text('#total') == money(expected), 'combined line and ticket discount preview')
        click('#park-ticket')
        check(not js("return document.querySelector('#ticket-lines .tline') !== null;"), 'park did not clear ticket')
        # The parked ticket also survives a reload of the same open till.
        ab('reload')
        wait_for("document.querySelector('#saved-tickets')", 'ticket actions after reload')
        click('#saved-tickets')
        wait_for("document.querySelector('.restore-ticket')", 'saved ticket')
        click('.restore-ticket')
        wait_for(f"document.querySelector('#qty-{item_id}')", 'restored line')
        check(text('#total') == money(expected), 'restored discount differs')
        click('#empty-ticket')
        check(js(f"return document.querySelector('#qty-{item_id}') !== null;"), 'empty must require confirmation')
        click('#confirm-empty-yes')
        check(not js("return document.querySelector('#ticket-lines .tline') !== null;"), 'confirmed empty failed')
        select('#sale-type', '')
        shot('venta-encabezado')
        return 'grid tap, size/stock, type/size filters, combined discount, park/reload/restore, in-page empty'

    def s_settings():
        go('ajustes', '#palette-picker')
        ab('snapshot', '-i')
        ab('find', 'label', 'Malva', 'check')
        check(js("return document.documentElement.dataset.palette === 'malva';"), 'palette did not change')
        ab('reload')
        wait_for("document.querySelector('#palette-picker')", 'settings reload')
        check(js("return document.documentElement.dataset.palette === 'malva' && document.querySelector('input[value=malva]').checked;"), 'palette not persisted')
        check(js("return document.querySelector('a[href=\"/scanner/scanner-test.html\"]') !== null;"), 'scanner link missing')
        check('Datos de prueba' in text('#sample-notice'), 'sample notice absent')
        shot('ajustes')
        ab('snapshot', '-i')
        ab('find', 'label', 'Bosque', 'check')
        return 'Ajustes palette survives reload; sample notice and local scanner link'

    def count_lines(amount):
        lines=[]
        for d in read('/cash/denominations'):
            q,amount=divmod(amount,d)
            lines.append({'denominationMinor':d,'quantity':q})
        check(amount==0,'cash cannot be counted in supported denominations')
        return lines

    def s_zero_stock():
        product_id,new_id=str(uuid.uuid4()),str(uuid.uuid4())
        code='ZERO-'+run
        status,_=call('POST','/catalog/products',{'productId':product_id,'name':'Prenda física '+run},token=token)
        check(status==204,'zero-stock product registration')
        status,_=call('POST','/catalog/items',{'itemId':new_id,'productId':product_id,'sku':code,'variantName':'Prenda física talla única '+run,
            'currencyCode':'NIO','unitPriceMinor':20000,'unitCostMinor':10000,'barcode':code},token=token)
        check(status==204,'zero-stock item registration')
        login_ui(CASHIER)
        go('venta','#till-register')
        click('#screen form button[type=submit]')
        wait_for("document.querySelector('#cards .product')",'zero-stock catalog')
        till=js("return JSON.parse(localStorage.getItem('savia.device.till'));")
        fill('#sale-search',code)
        check('Sin existencia en sistema' in text('#cards'),'zero stock state missing')
        click(f"#cards [data-product='{product_id}']")
        wait_for("document.querySelector('#confirm-stock')",'physical-stock confirmation')
        check('Confirmar que la prenda está en la tienda' in text('#modal'),'physical confirmation message')
        click('#confirm-stock')
        wait_for(f"document.querySelector('#qty-{new_id}')",'zero-stock ticket line')
        fill('#received','200')
        shot('venta-excepcion')
        click('#pay')
        wait_for("!document.querySelector('#receipt').hidden",'zero-stock receipt')
        sale_id=re.search(r'Venta ([0-9a-fA-F-]{36})',text('#receipt')).group(1)
        exceptions=read('/stock/exceptions')
        mine=[e for e in exceptions if uuid.UUID(e['saleId'])==uuid.UUID(sale_id)]
        check(len(mine)==1 and mine[0]['quantityShort']==1 and uuid.UUID(mine[0]['itemId'])==uuid.UUID(new_id),'one zero-stock exception expected')
        check(on_hand(token,new_id)==0,'adjustment and sale must conserve stock')
        login_ui(SUPERVISOR)
        go('excepciones','#stock-exceptions')
        row=f"[data-exception='{mine[0]['id']}']"
        fill(row+' input','Revisado: existencia física confirmada')
        shot('excepciones')
        click(row+' button')
        wait_for(f"document.querySelector({json.dumps(row)})?.dataset.reviewed === 'true'",'exception review persisted')
        reviewed=next(e for e in read('/stock/exceptions') if e['id']==mine[0]['id'])
        check(reviewed['reviewedBy'] and reviewed['reviewNote']=='Revisado: existencia física confirmada','review audit missing')
        count_id=str(uuid.uuid4())
        status,_=call('POST',f"/cash/tills/{till['tillId']}/counts",{'cashCountId':count_id,'lines':count_lines(20000)},token=token)
        check(status==204,'exception till count')
        status,closure=call('POST',f"/cash/tills/{till['tillId']}/close",{'closureId':str(uuid.uuid4()),'cashCountId':count_id},token=token)
        check(status==200 and closure['differenceMinor']==0,'exception till close')
        return 'zero-system-stock sale, one traced exception, manager review and zero final stock'

    def s_discount_sale():
        login_ui(CASHIER)
        go('venta', '#till-register')
        select('#till-register', next(r['registerId'] for r in read('/cash/registers') if not r['openTillId']))
        fill('#open-den-100000', '0')
        click('#screen form button[type=submit]')
        wait_for("document.querySelector('#cards .product')", 'discount catalog')
        till = js("return JSON.parse(localStorage.getItem('savia.device.till'));")
        click(f"#cards [data-product='{state['product_id']}']")
        wait_for("document.querySelector('#sale-sizes')", 'discount size picker')
        click(f"#sale-sizes [data-item='{item_id}']")
        fill('#ticket-discount', '20')
        ab('press', 'Tab')
        fill('#received', '1000')
        before = read(f"/cash/tills/{till['tillId']}/summary")
        auth_status, auth_body = call('POST','/auth/login',{'loginName':CASHIER,'password':PASSWORDS[CASHIER]})
        check(auth_status == 200, 'cashier server discount test login failed')
        discount = item['unitPriceMinor'] // 5
        amount = item['unitPriceMinor'] - discount
        refused_status, refused = call('POST','/sales',{'saleId':str(uuid.uuid4()),'tillId':till['tillId'],'currencyCode':'NIO',
          'lines':[{'lineNumber':1,'itemId':item_id,'quantity':1,'unitPriceMinor':item['unitPriceMinor'],'discountMinor':discount}],
          'tenders':[{'tenderNumber':1,'tenderKind':'cash','amountMinor':amount,'receivedMinor':amount,'changeMinor':0}]},token=auth_body['token'])
        check(refused_status == 403 and refused['code'] == 'sale.discount_approval_required','server accepted unapproved 20 percent')
        call('POST','/auth/logout',token=auth_body['token'])
        click('#pay')
        wait_for("document.querySelector('#modal').open && document.querySelector('#approval-user')", 'discount supervisor sign-in')
        # No credentials: Cancel refuses the sale without changing stock or cash.
        click('#modal button[type=button]')
        after = read(f"/cash/tills/{till['tillId']}/summary")
        check(after['saleCount'] == before['saleCount'] == 0, 'unapproved 20 percent was sold')
        fill('#ticket-discount', '10')
        ab('press', 'Tab')
        click('#pay')
        wait_for("document.querySelector('#modal').open && document.querySelector('#approval-reason')", 'all discounts require approval')
        fill('#approval-reason','Atención autorizada por supervisión')
        fill('#approval-discount-0','120')
        profile=SESSION+'-approval'
        ab('auth','save',profile,'--url',WEB+'/','--username',SUPERVISOR,'--password-stdin',
           '--username-selector','#approval-user','--password-selector','#approval-pass',
           '--submit-selector','#modal form button[type=submit]',secret_input=PASSWORDS[SUPERVISOR])
        try:
            ab('auth','login',profile,'--no-navigate')
        finally:
            ab('auth','delete',profile)
        wait_for("!document.querySelector('#receipt').hidden", 'manager approved receipt')
        sale_id = re.search(r"Venta ([0-9a-fA-F-]{36})", text('#receipt')).group(1)
        sale = read('/sales/' + sale_id)
        check(sale['discountMinor'] == 12000, 'SQL did not persist the amount selected by the manager')
        check(sale['cashierId'] == till['cashierId'], 'discount changed seller')
        check(sale['discountApprovedBy'] and sale['discountReason']=='Atención autorizada por supervisión','approval audit missing')
        shot('venta-descuento')
        # Parked work must be discarded when this till closes.
        js("localStorage.setItem('savia.device.parkedTickets', JSON.stringify({tillId:" + json.dumps(till['tillId']) + ",tickets:[{id:'closure-probe'}]})); return true;")
        count_id = str(uuid.uuid4())
        status, _ = call('POST', f"/cash/tills/{till['tillId']}/counts", {'cashCountId':count_id,'lines':count_lines(sale['totalMinor'])}, token=token)
        check(status == 204, 'discount count failed')
        status, closure = call('POST', f"/cash/tills/{till['tillId']}/close", {'closureId':str(uuid.uuid4()),'cashCountId':count_id}, token=token)
        check(status == 200 and closure['differenceMinor'] == 0, 'discount till closure failed')
        go('ajustes', '#palette-picker')
        check(js("return localStorage.getItem('savia.device.parkedTickets') === null;"), 'closed-till parked ticket survived synchronization')
        return 'cashier discount rejected; cancel preserves till; manager approved discount and reason persisted; closed-till drafts cleared'

    def s_no_sample():
        for route, ready in [('venta','#till-register'),('inventario','#stock-body'),('historial','#history-search'),('clientes','#customer-search'),('ajustes','#sample-notice')]:
            go(route, ready)
            check(js("return ![...document.querySelectorAll('body *')].some(e=>e.children.length===0 && e.getClientRects().length && !e.closest('#sample-notice') && /MUESTRA/i.test(e.textContent));"), 'visible MUESTRA outside Ajustes: ' + route)
        return 'no visible MUESTRA on staff screens'

    steps = [("login", s_login), ("inventory before", lambda: inventory(state["stock0"], "inventario-1")),
        ("five scans", s_scan), ("register and reject", s_unknowns),
        ("inventory unchanged", lambda: inventory(state["stock0"], "inventario-pending")),
        ("approve and post", s_post), ("inventory after post", lambda: inventory(state["stock1"], "inventario-2")),
        ("cashier open till", s_till), ("catalog grid and tickets", s_grid), ("cash sale", s_sale), ("card sale", s_card),
        ("history and receipt", s_history), ("return one unit", s_return), ("customers and credit", s_customers), ("credit sale", s_credit_sale),
        ("count and close", s_count), ("day report", s_report),
        ("final inventory", lambda: inventory(state["stock1"] - 3, "inventario-3")), ("settings persistence", s_settings), ("cashier discounts", s_discount_sale), ("physical stock exception", s_zero_stock), ("no sample labels", s_no_sample)]
    try:
        for name, fn in steps:
            if not step(name, fn):
                shot("failure")
                break
    finally:
        console = json.loads(ab("console", "--json"))["data"]["messages"]
        errors = json.loads(ab("errors", "--json"))["data"]["errors"]
        console_errors = [m for m in console if m["type"] in ("error", "assert")]
        print(f"console errors: {len(console_errors)}; page errors: {len(errors)}", flush=True)
        for e in console_errors + errors:
            print(str(e)[:400])
        results.append(("console", "FAIL" if console_errors or errors else "PASS", "zero required"))
        close_browser()
    print(f"SUMMARY: {sum(v == 'PASS' for _,v,_ in results)} passed; {sum(v == 'FAIL' for _,v,_ in results)} failed", flush=True)
    return 1 if any(v == "FAIL" for _,v,_ in results) else 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except StepFailed as error:
        print(f"FAIL {error}", file=sys.stderr)
        sys.exit(1)
