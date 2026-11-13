#!/usr/bin/env python3
"""End-to-end smoke test of the running Masaya pilot (start it with `python savia/tools/pilot.py up`).

Flow: sign in -> receive known and unknown codes -> register a product and item through the local
catalog API -> resolve one unknown and reject another -> approve -> post -> assert both item stocks ->
open till -> cash sale -> store-credit return + retry -> audit -> card sale + retry -> count -> close -> day report -> audit.

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
    global DENOMINATIONS
    passwords = pilot_passwords(("CAJERA", "SUPERVISORA"))
    status, _ = call("GET", "/health")
    check(status == 200, "GET /health 200")
    cashier = login("cajera.muestra", passwords["SAVIA_PILOT_PASSWORD_CAJERA"])
    supervisor = login("supervisora.muestra", passwords["SAVIA_PILOT_PASSWORD_SUPERVISORA"])
    _, DENOMINATIONS = call("GET", "/api/v1/cash/denominations", token=cashier)
    _, me = call("GET", "/api/v1/me", token=cashier)
    check(me["branchName"] == "Masaya" and me["locationId"], f"cashier signed in at {me['branchName']} / {me['locationName']}")

    # --- reception by barcode scan
    _, found = call("GET", f"/api/v1/catalog/search?q={BARCODE}", token=cashier)
    check(len(found) == 1 and found[0]["barcode"] == BARCODE, f"search finds {found[0]['sku'] if found else '?'}")
    item, price = found[0]["itemId"], found[0]["unitPriceMinor"]
    stock0 = on_hand(cashier, item)
    _, suppliers = call("GET", "/api/v1/suppliers", token=cashier)
    supplier = next(s["supplierId"] for s in suppliers if s["name"] == "Proveedor")
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
    call("POST", "/api/v1/catalog/products", {"productId": new_product, "name": f"Producto smoke {run}"}, supervisor)
    call("POST", "/api/v1/catalog/items", {"itemId": new_item, "productId": new_product,
         "sku": f"MAS-SMOKE-{run}", "variantName": f"Producto smoke {run}", "currencyCode": "NIO",
         "unitPriceMinor": 49900, "unitCostMinor": 20000, "barcode": unknown_code}, supervisor)
    check(on_hand(cashier, new_item) == 0, "new catalog item has no stock before posting")
    call("POST", f"/api/v1/receiving/sessions/{session}/scans/{unknown['scanId']}/resolve",
         {"itemId": new_item, "reason": "Codigo registrado en el piloto (smoke)"}, supervisor)
    _, rejected = call("POST", f"/api/v1/receiving/sessions/{session}/scans",
         {"scanId": str(uuid.uuid4()), "rawCode": "REJECT-" + run, "quantity": 7}, cashier)
    check(rejected["matchStatus"] == "unknown", "second unknown code recorded for rejection")
    reject_url = f"/api/v1/receiving/sessions/{session}/scans/{rejected['scanId']}/reject"
    call("POST", reject_url, {"reason": "Etiqueta ilegible"}, supervisor)
    call("POST", reject_url, {"reason": "Etiqueta ilegible"}, supervisor)
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
             "currencyCode": "NIO", "openingMinor": 100000, "lines":count_lines(100000)}, cashier)
    _, current = call("GET", "/api/v1/cash/tills/current", token=cashier)
    check(sum(l["denominationMinor"]*l["quantity"] for l in current["openingLines"]) == current["openingMinor"], "opening breakdown equals server total")
    check(current["tillId"] == till and current["status"] == "open", "till open for the cashier")
    _, catalog = call("GET", "/api/v1/catalog/items", token=cashier)
    check(any(p["type"] == "Blusas" and any(v["itemId"] == item for v in p["variants"]) for p in catalog), "grouped local catalog includes garment type and variants")
    _, customers = call("GET", "/api/v1/customers?q=Clienta", token=cashier)
    customer = next(c["customerId"] for c in customers if c["customerCode"] == "CLI-PILOTO")
    total = 2 * price
    sale = str(uuid.uuid4())
    call("POST", "/api/v1/sales", {"saleId": sale, "tillId": till, "currencyCode": "NIO", "customerId": customer,
         "lines": [{"lineNumber": 1, "itemId": item, "quantity": 2, "unitPriceMinor": price}],
         "tenders": [{"tenderNumber": 1, "tenderKind": "cash", "amountMinor": total, "receivedMinor": total, "changeMinor": 0}]}, cashier)
    stock2 = on_hand(cashier, item)
    check(stock2 == stock1 - 2, f"cash sale of 2 dropped stock by 2 ({stock1} -> {stock2})")
    _, detail = call("GET", f"/api/v1/sales/{sale}", token=cashier)
    return_body = {"reversalId": str(uuid.uuid4()), "creditId": str(uuid.uuid4()), "tillId": till,
                   "customerId": customer, "reason": "Cambio de talla smoke",
                   "lines": [{"saleLineId": detail["lines"][0]["saleLineId"], "quantity": 1, "restockPool": "store"}]}
    return_path = f"/api/v1/sales/{sale}/returns/credit"
    call("POST", return_path, return_body, cashier, expect=(403,))
    _, reversal = call("POST", return_path, return_body, supervisor)
    _, retry = call("POST", return_path, return_body, supervisor)
    check(reversal["reversalId"] == retry["reversalId"] and reversal["creditMinor"] == price,
          "supervisor store-credit return and identical retry")
    check(on_hand(cashier, item) == stock2 + 1, "return restores exactly one unit")
    sql("EXEC audit.usp_CheckConservation @Throw=1;")
    check(True, "conservation passes immediately after return")
    _, credits = call("GET", "/api/v1/credits/search?q=Clienta", token=cashier)
    check(any(c["creditId"] == return_body["creditId"] and c["availableMinor"] == price for c in credits), "customer credit is searchable")
    card = {"saleId": str(uuid.uuid4()), "tillId": till, "currencyCode": "NIO", "customerId": customer,
            "lines": [{"lineNumber": 1, "itemId": item, "quantity": 1, "unitPriceMinor": price}],
            "tenders": [{"tenderNumber": 1, "tenderKind": "card", "amountMinor": price, "reference": "AUTH-" + run}]}
    call("POST", "/api/v1/sales", card, cashier)
    call("POST", "/api/v1/sales", card, cashier)
    check(on_hand(cashier, item) == stock2, "card sale and retry consume exactly one unit")
    discounted = {"saleId":str(uuid.uuid4()),"tillId":till,"currencyCode":"NIO","discountReason":"Atencion autorizada smoke",
        "lines":[{"lineNumber":1,"itemId":item,"quantity":1,"unitPriceMinor":price,"discountMinor":price//2}],
        "tenders":[{"tenderNumber":1,"tenderKind":"cash","amountMinor":price-price//2,"receivedMinor":price-price//2,"changeMinor":0}]}
    _, refused = call("POST","/api/v1/sales",discounted,cashier,expect=(403,))
    check(refused["code"]=="sale.discount_approval_required","cashier discount rejected")
    call("POST","/api/v1/sales",discounted,cashier,approval=supervisor)
    _, approved = call("GET","/api/v1/sales/"+discounted["saleId"],token=cashier)
    check(approved["discountApprovedBy"] and approved["discountReason"]==discounted["discountReason"],"manager discount identity and reason recorded")
    check(approved["receiptNumber"] and approved["receiptNumber"]!=approved["saleId"],"sequential receipt number returned")
    physical_product,physical_item = str(uuid.uuid4()),str(uuid.uuid4())
    call("POST","/api/v1/catalog/products",{"productId":physical_product,"name":"Prenda fisica smoke "+run},supervisor)
    call("POST","/api/v1/catalog/items",{"itemId":physical_item,"productId":physical_product,"sku":"FIS-"+run,
        "variantName":"Prenda fisica smoke "+run,"currencyCode":"NIO","unitPriceMinor":20000,"unitCostMinor":10000,"barcode":"FIS-"+run},supervisor)
    physical_sale = {"saleId":str(uuid.uuid4()),"tillId":till,"currencyCode":"NIO","stockExceptionNote":"El sistema decia 0 y habia existencia fisica",
        "lines":[{"lineNumber":1,"itemId":physical_item,"quantity":1,"unitPriceMinor":20000}],
        "tenders":[{"tenderNumber":1,"tenderKind":"cash","amountMinor":20000,"receivedMinor":20000,"changeMinor":0}]}
    call("POST","/api/v1/sales",physical_sale,cashier)
    call("POST","/api/v1/sales",physical_sale,cashier)
    _, exceptions = call("GET","/api/v1/stock/exceptions",token=supervisor)
    exception = [e for e in exceptions if uuid.UUID(e["saleId"])==uuid.UUID(physical_sale["saleId"])]
    check(len(exception)==1 and exception[0]["quantityShort"]==1,"zero stock sale creates one shortage exception on retry")
    call("POST","/api/v1/stock/exceptions/"+exception[0]["id"]+"/review",{"reason":"Revisado smoke"},cashier,expect=(403,))
    call("POST","/api/v1/stock/exceptions/"+exception[0]["id"]+"/review",{"reason":"Revisado smoke"},supervisor)
    check(on_hand(cashier,physical_item)==0,"physical-stock adjustment and sale conserve zero stock")
    _, summary = call("GET", f"/api/v1/cash/tills/{till}/summary", token=cashier)
    check(summary["cashSalesMinor"] >= total, f"till summary expects {summary['expectedCashMinor']}")
    count_id = str(uuid.uuid4())
    call("POST", f"/api/v1/cash/tills/{till}/counts", {"cashCountId": count_id, "lines": count_lines(summary["expectedCashMinor"])}, cashier)
    _, closure = call("POST", f"/api/v1/cash/tills/{till}/close", {"closureId": str(uuid.uuid4()), "cashCountId": count_id}, supervisor)
    check(closure["expectedMinor"] == summary["expectedCashMinor"] and closure["differenceMinor"] == 0,
          f"till closed: expected {closure['expectedMinor']}, counted {closure['countedMinor']}, difference 0")
    status, _ = call("GET", "/api/v1/cash/tills/current", token=cashier, expect=(404,))
    check(status == 404, "no open till after close")
    from datetime import datetime, timedelta, timezone
    date = datetime.now(timezone.utc).astimezone(timezone(timedelta(hours=-6))).date().isoformat()
    _, report = call("GET", f"/api/v1/reports/day?date={date}", token=supervisor)
    check(any(t["tillId"] == till and t["differenceMinor"] == 0 and t["accountingDocumentId"] for t in report["tills"]),
          "day report includes balanced closure and accounting document")
    for period in ("day","week","month","year"):
        _, summary = call("GET",f"/api/v1/reports/summary?period={period}&date={date}",token=supervisor)
        check(summary["salesCount"]>=4 and summary["discountsMinor"]>=price//2 and summary["stockExceptionsCount"]>=1,
              period+" summary includes sales, manager discount and stock exception")
        check(sum(t["totalMinor"] for t in summary["tenders"])==summary["salesMinor"],period+" tenders equal sales")

    sql("EXEC audit.usp_CheckConservation @Throw=1;")
    check(True, f"audit.usp_CheckConservation @Throw=1 passed on {DB}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Fail as error:
        print(f"FAIL {error}", flush=True)
        sys.exit(1)
