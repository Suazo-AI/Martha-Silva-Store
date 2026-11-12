"""Real local pilot browser flow, using agent-browser and direct API read-backs.

Start with pilot.py reset then up, with SAVIA_PILOT_PASSWORD set in the environment.
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
PASSWORD = os.environ.get("SAVIA_PILOT_PASSWORD")
CODE = "7500001000014"
SHOTS = Path(__file__).resolve().parents[2] / "docs" / "pilot" / "screens"
AB = shutil.which("agent-browser")
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
        raise StepFailed(f"agent-browser {' '.join(args[:2])}: {output}"[:400])
    return output


def js(expression: str):
    """Evaluates JSON.stringify(expression) in the page and returns the Python value."""
    out = ab("eval", f"JSON.stringify((() => {{ {expression} }})() ?? null)")
    value = json.loads(out.splitlines()[-1])
    return json.loads(value) if isinstance(value, str) else value


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
    target = js(f"const e=document.querySelector({json.dumps(selector)}); if (!e) return null; return {{name:e.getAttribute('aria-label') || [...(e.labels || [])].map(l=>l.textContent.trim()).join(' ') || e.textContent.trim(), role:e.tagName==='BUTTON'?'button':e.tagName==='SELECT'?'combobox':e.type==='search'?'searchbox':'textbox'}};")
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


def shot(name: str):
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
       "--submit-selector", "#access button[type=submit]", secret_input=PASSWORD)
    try:
        ab("auth", "login", profile, "--no-navigate")
    finally:
        ab("auth", "delete", profile)
    wait_for("!document.querySelector('#shell').hidden && document.querySelector('#screen').children.length", "signed-in shell")


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    if not AB or not PASSWORD:
        print("Need agent-browser and SAVIA_PILOT_PASSWORD.", file=sys.stderr)
        return 2
    if not WEB.startswith(("http://127.0.0.1:", "http://localhost:")):
        raise StepFailed("Only local pilot URLs are allowed")
    status, body = call("POST", "/auth/login", {"loginName": SUPERVISOR, "password": PASSWORD})
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
        fill("#reg-name", "Producto web " + run + " MUESTRA")
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
        fill("#reject-reason", "Etiqueta ilegible MUESTRA")
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
        fill("#till-opening", "1000")
        shot("venta-1")
        click("#screen form button[type=submit]")
        wait_for("document.querySelector('#sale-search')", "sale screen")
        state["till"] = js("return JSON.parse(localStorage.getItem('savia.device.till'));")
        summary = read(f"/cash/tills/{state['till']['tillId']}/summary")
        check(summary["openingMinor"] == state["till"]["openingMinor"] == 100000, "opening differs")
        check(text("#till-state") == "Caja abierta" and summary["status"] == "open", "till status differs")
        return "cajera.muestra opened till; API opening 100000"

    def s_sale():
        for _ in range(2):
            fill("#sale-search", CODE)
            ab("press", "Enter")
        wait_for(f"document.querySelector('#qty-{item_id}')?.value === '2'", "ticket quantity 2")
        check(text("#total") == money(2 * read('/catalog/lookup?code=' + CODE)[0]["unitPriceMinor"]), "ticket price differs")
        fill("#received", "3000")
        shot("venta-2")
        click("#pay")
        wait_for("!document.querySelector('#receipt').hidden", "sale receipt")
        sale_id = re.search(r"Venta ([0-9a-fA-F-]{36})", text("#receipt")).group(1)
        sale = read("/sales/" + sale_id)
        check(text("#receipt-total") == money(sale["totalMinor"]), "receipt total differs")
        check(text("#receipt-change") == money(300000 - sale["totalMinor"]), "change differs")
        check(on_hand(token, item_id) == state["stock1"] - 2, "sale stock differs")
        shot("venta-3")
        return f"sale of 2; screen=API total {sale['totalMinor']}; change {300000 - sale['totalMinor']}"

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
        shot("caja-1")
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

    steps = [("login", s_login), ("inventory before", lambda: inventory(state["stock0"], "inventario-1")),
        ("five scans", s_scan), ("register and reject", s_unknowns),
        ("inventory unchanged", lambda: inventory(state["stock0"], "inventario-pending")),
        ("approve and post", s_post), ("inventory after post", lambda: inventory(state["stock1"], "inventario-2")),
        ("cashier open till", s_till), ("cash sale", s_sale), ("count and close", s_count),
        ("final inventory", lambda: inventory(state["stock1"] - 2, "inventario-3"))]
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
        ab("close")
    print(f"SUMMARY: {sum(v == 'PASS' for _,v,_ in results)} passed; {sum(v == 'FAIL' for _,v,_ in results)} failed", flush=True)
    return 1 if any(v == "FAIL" for _,v,_ in results) else 0

if __name__ == "__main__":
    try:
        sys.exit(main())
    except StepFailed as error:
        print(f"FAIL {error}", file=sys.stderr)
        sys.exit(1)
