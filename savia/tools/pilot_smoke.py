#!/usr/bin/env python3
"""End-to-end smoke test of the running Masaya pilot (start it with `python savia/tools/pilot.py up`).

Flow: sign in -> receive known and unknown codes -> register a product and item through the local
catalog API -> resolve one unknown and reject another -> approve -> post -> assert both item stocks ->
open till -> cash sale -> count -> close -> audit.usp_CheckConservation @Throw=1.

Exit 0 = pass. The staff password comes from SAVIA_PILOT_PASSWORD (or a hidden prompt); it is never printed.
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

DB = "SAVIA_DEV_pilot"
URL = os.environ.get("SAVIA_PILOT_URL", "http://127.0.0.1:5080")
BARCODE = "7500001000014"                             # seeded: Blusa de lino blanca S (MUESTRA)
DENOMINATIONS = [100000, 50000, 20000, 10000, 5000, 2000, 1000, 500, 100, 50, 25, 10, 5, 1]


class Fail(Exception):
    pass


def check(condition, message):
    if not condition:
        raise Fail(message)
    print(f"ok   {message}", flush=True)


def call(method, path, body=None, token=None, expect=(200, 204)):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(URL + path, data=data, method=method)
    request.add_header("Content-Type", "application/json")
    if token:
        request.add_header("Authorization", "Bearer " + token)
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
    password = os.environ.get("SAVIA_PILOT_PASSWORD") or (getpass.getpass("Sample staff password: ") if sys.stdin.isatty() else "")
    if not password:
        raise Fail("set SAVIA_PILOT_PASSWORD")
    status, _ = call("GET", "/health")
    check(status == 200, "GET /health 200")
    cashier, supervisor = login("cajera.muestra", password), login("supervisora.muestra", password)
    _, me = call("GET", "/api/v1/me", token=cashier)
    check(me["branchName"] == "Masaya" and me["locationId"], f"cashier signed in at {me['branchName']} / {me['locationName']}")

    # --- reception by barcode scan
    _, found = call("GET", f"/api/v1/catalog/search?q={BARCODE}", token=cashier)
    check(len(found) == 1 and found[0]["barcode"] == BARCODE, f"search finds {found[0]['sku'] if found else '?'}")
    item, price = found[0]["itemId"], found[0]["unitPriceMinor"]
    stock0 = on_hand(cashier, item)
    _, suppliers = call("GET", "/api/v1/suppliers", token=cashier)
    supplier = next(s["supplierId"] for s in suppliers if "MUESTRA" in s["name"])
    session, run = str(uuid.uuid4()), uuid.uuid4().hex[:8].upper()
    call("POST", "/api/v1/receiving/sessions", {"containerId": str(uuid.uuid4()), "scanSessionId": session,
         "reference": f"SMOKE-{run}", "supplierId": supplier, "deviceCode": "SMOKE"}, cashier)
    _, open_sessions = call("GET", "/api/v1/receiving/sessions", token=cashier)
    check(any(s["scanSessionId"] == session for s in open_sessions), "reception opened and listed")
    for _ in range(5):
        _, scan = call("POST", f"/api/v1/receiving/sessions/{session}/scans", {"scanId": str(uuid.uuid4()), "rawCode": BARCODE}, cashier)
        assert scan["matchStatus"] == "matched"
    unknown_code = "990" + str(uuid.uuid4().int)[:10]
    _, unknown = call("POST", f"/api/v1/receiving/sessions/{session}/scans", {"scanId": str(uuid.uuid4()), "rawCode": unknown_code}, cashier)
    check(unknown["matchStatus"] == "unknown", "unknown code recorded as unknown")
    _, lines = call("GET", f"/api/v1/receiving/sessions/{session}/lines", token=cashier)
    matched = [l for l in lines if l["matchStatus"] == "matched"]
    pending = [l for l in lines if l["matchStatus"] != "matched"]
    check(len(matched) == 1 and matched[0]["itemId"] == item and matched[0]["quantity"] == 5, "one line of the seeded item with quantity 5")
    check(len(pending) == 1 and pending[0]["rawCode"] == unknown_code and pending[0]["itemId"] is None, "unknown code is unresolved")
    status, problem = call("POST", f"/api/v1/receiving/sessions/{session}/approve", token=supervisor, expect=(409,))
    check(problem["code"] == "receiving.unresolved_codes", "approval refused while a code is unresolved (409)")

    # --- local pilot catalog registers the code through the same API as the browser
    new_product, new_item = str(uuid.uuid4()), str(uuid.uuid4())
    call("POST", "/api/v1/catalog/products", {"productId": new_product, "name": f"Producto smoke {run} MUESTRA"}, supervisor)
    call("POST", "/api/v1/catalog/items", {"itemId": new_item, "productId": new_product,
         "sku": f"MAS-SMOKE-{run}", "variantName": f"Producto smoke {run} MUESTRA", "currencyCode": "NIO",
         "unitPriceMinor": 49900, "unitCostMinor": 20000, "barcode": unknown_code}, supervisor)
    check(on_hand(cashier, new_item) == 0, "new catalog item has no stock before posting")
    call("POST", f"/api/v1/receiving/sessions/{session}/scans/{unknown['scanId']}/resolve",
         {"itemId": new_item, "reason": "Codigo registrado en el piloto (smoke)"}, supervisor)
    _, rejected = call("POST", f"/api/v1/receiving/sessions/{session}/scans",
         {"scanId": str(uuid.uuid4()), "rawCode": "REJECT-" + run, "quantity": 7}, cashier)
    check(rejected["matchStatus"] == "unknown", "second unknown code recorded for rejection")
    reject_url = f"/api/v1/receiving/sessions/{session}/scans/{rejected['scanId']}/reject"
    call("POST", reject_url, {"reason": "Etiqueta ilegible MUESTRA"}, supervisor)
    call("POST", reject_url, {"reason": "Etiqueta ilegible MUESTRA"}, supervisor)
    _, lines = call("GET", f"/api/v1/receiving/sessions/{session}/lines", token=cashier)
    check(any(l["itemId"] == new_item and l["matchStatus"] == "matched" and l["quantity"] == 1 for l in lines),
          "supervisor resolved the unknown code after API catalog registration")
    check(any(l["scanId"] == rejected["scanId"] and l["matchStatus"] == "rejected" for l in lines),
          "second unknown retained as rejected; retry is safe")
    _, progress = call("GET", f"/api/v1/receiving/sessions/{session}", token=supervisor)
    check(progress["unitsPendingReview"] == 0, "rejected units do not need review")
    call("POST", f"/api/v1/receiving/sessions/{session}/approve", token=supervisor)
    _, receipt = call("POST", f"/api/v1/receiving/sessions/{session}/post", token=supervisor)
    check(bool(receipt["receiptId"]), "approved and posted")
    check(on_hand(cashier, new_item) == 1, "API-registered item stock rose from 0 to 1; rejected units excluded")
    stock1 = on_hand(cashier, item)
    check(stock1 == stock0 + 5, f"stock rose by 5 ({stock0} -> {stock1})")

    # --- till: open, sell 2 for cash, count, close
    status, current = call("GET", "/api/v1/cash/tills/current", token=cashier, expect=(200, 404))
    if status == 200:
        till = current["tillId"]
        print(f"note reusing open till {till} left by an earlier run")
    else:
        _, registers = call("GET", "/api/v1/cash/registers", token=cashier)
        till = str(uuid.uuid4())
        call("POST", "/api/v1/cash/tills", {"tillId": till, "registerId": registers[0]["registerId"],
             "currencyCode": "NIO", "openingMinor": 100000}, cashier)
    _, current = call("GET", "/api/v1/cash/tills/current", token=cashier)
    check(current["tillId"] == till and current["status"] == "open", "till open for the cashier")
    total = 2 * price
    call("POST", "/api/v1/sales", {"saleId": str(uuid.uuid4()), "tillId": till, "currencyCode": "NIO",
         "lines": [{"lineNumber": 1, "itemId": item, "quantity": 2, "unitPriceMinor": price}],
         "tenders": [{"tenderNumber": 1, "tenderKind": "cash", "amountMinor": total, "receivedMinor": total, "changeMinor": 0}]}, cashier)
    stock2 = on_hand(cashier, item)
    check(stock2 == stock1 - 2, f"cash sale of 2 dropped stock by 2 ({stock1} -> {stock2})")
    _, summary = call("GET", f"/api/v1/cash/tills/{till}/summary", token=cashier)
    check(summary["cashSalesMinor"] >= total, f"till summary expects {summary['expectedCashMinor']}")
    count_id = str(uuid.uuid4())
    call("POST", f"/api/v1/cash/tills/{till}/counts", {"cashCountId": count_id, "lines": count_lines(summary["expectedCashMinor"])}, cashier)
    _, closure = call("POST", f"/api/v1/cash/tills/{till}/close", {"closureId": str(uuid.uuid4()), "cashCountId": count_id}, supervisor)
    check(closure["expectedMinor"] == summary["expectedCashMinor"] and closure["differenceMinor"] == 0,
          f"till closed: expected {closure['expectedMinor']}, counted {closure['countedMinor']}, difference 0")
    status, _ = call("GET", "/api/v1/cash/tills/current", token=cashier, expect=(404,))
    check(status == 404, "no open till after close")

    sql("EXEC audit.usp_CheckConservation @Throw=1;")
    check(True, f"audit.usp_CheckConservation @Throw=1 passed on {DB}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Fail as error:
        print(f"FAIL {error}", flush=True)
        sys.exit(1)
