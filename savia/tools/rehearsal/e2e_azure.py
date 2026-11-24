#!/usr/bin/env python3
"""Point 5 of 2026-11-24: one web order end to end on a deployed hub (Azure Container App) and a local store host.

  prepare  --hub-url URL --hub-db NAME --hub-node-id ID --storefront-origin ORIGIN [--local-hub-for-test]
           ids, throwaway passwords and a node secret into state; the local store database, migrated and provisioned;
           the hub side provisioned through C:/Users/Jason/SaviaStore/run-job.ps1 (the caj-savia-migrate job)
  run      store host on 127.0.0.1:5081; dayzero steps 6-10 (import, arrive, receive, sale, consign); one public order
           sent twice with one Idempotency-Key; manual payment and fulfilment by the owner on the hub; checks
  report   --out PATH: the transcript as Markdown
  down     stop the hosts this run started, drop the local databases and login, delete the state

Reuses dayzero.py. The hub's SQL is not reachable from here, so hub evidence comes from the API, never from SQL.
On Azure every staff password is given through SAVIA_STAFF_PASSWORD (a temporary job secret), never printed into the
job log. The hub must run with Savia__Public__BotCheck=disabled: use a temporary copy of the hub, never production.
--local-hub-for-test runs the same flow with a local hub host (port 5412) to prove the driver before Azure.
"""
import argparse
import json
import os
import secrets
import subprocess
import sys
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dayzero as dz  # noqa: E402

dz.OUT = dz.SAVIA / ".out" / "e2e-azure"
dz.STATE, dz.TRANSCRIPT = dz.OUT / "state.json", dz.OUT / "transcript.json"
dz.APP_LOGIN = "savia_e2e_api"
dz.PORT = {"hub": 5412, "store": 5081}
RUN_JOB = Path(r"C:\Users\Jason\SaviaStore\run-job.ps1")
BRANCH = ["--branch-code", "E2E_TIENDA", "--branch-name", "Tienda e2e", "--store-name", "SAVIA e2e",
          "--location-code", "E2E_TIENDA_LOC", "--location-name", "Tienda e2e", "--register-code", "CAJAE2E",
          "--register-name", "Caja e2e"]


def configure(s):
    """Point dayzero's module globals at this run: databases, hub address, storefront origin."""
    dz.DBN = {"store": "SAVIA_DEV_e2e_store"}
    if s.get("localHub"):
        dz.DBN["hub"] = "SAVIA_DEV_e2e_hub"
    dz.STOREFRONT = s["storefront"]
    hub = s["hubUrl"]
    dz.base = lambda node: hub if node == "hub" else f"http://127.0.0.1:{dz.PORT[node]}"


def hub_migrator(r, *args, secret_env=None, secret=None):
    """One migrator mode on the hub database: the local migrator in a test run, else the Azure job."""
    if r.s.get("localHub"):
        return r.migrator("hub", *args, extra_env={secret_env: secret} if secret_env else None)
    quote = lambda v: "'" + str(v).replace("'", "''") + "'"
    cmd = f"& {quote(RUN_JOB)} -Database {quote(r.s['hubDb'])} -JobArgs @({', '.join(quote(a) for a in args)})"
    tmp = None
    if secret_env:
        tmp = dz.OUT / f"secret-{uuid.uuid4().hex}.txt"
        tmp.write_text(secret, encoding="ascii")
        cmd += f" -SecretFile {quote(tmp)} -SecretEnv {secret_env}"
    try:
        p = subprocess.run(["pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", cmd],
                           capture_output=True, text=True, timeout=1800, env=dz.clean_env())
    finally:
        if tmp:
            tmp.unlink(missing_ok=True)
    out = r.scrub(p.stdout + p.stderr)
    if p.returncode:
        raise SystemExit(f"hub job {args[0]}: exit {p.returncode}\n{out}")
    if "secret lines in workspace: 0" not in out:
        raise SystemExit(f"hub job {args[0]}: the workspace holds secret lines\n{out}")
    return out


def last_lines(out, n=3):
    return " | ".join(l for l in out.splitlines() if l.strip() and not l.startswith("execution"))[-400:]


# ---------------------------------------------------------------- prepare
def cmd_prepare(a):
    # --resume replays a prepare that stopped part-way with the same ids and secrets; every provisioning step
    # is a no-op for the same ids (V062), so only the databases are not created again.
    if dz.STATE.exists() != a.resume:
        raise SystemExit("a run is already prepared; run `down` first, or pass --resume" if not a.resume
                         else "nothing to resume; run prepare without --resume")
    for p in (dz.API_DLL, dz.MIGRATOR_DLL):
        if not p.exists():
            raise SystemExit(f"missing {p}; build it first (see dayzero.py --help)")
    r = dz.Run()
    if a.resume:
        local = r.s["localHub"]
        configure(r.s)
    else:
        r.t = []
        ids = {k: dz.new_id() for k in ("storeNode", "branch", "location", "register", "owner", "manager", "cashier")}
        ids["hubNode"] = a.hub_node_id.upper()
        local = a.local_hub_for_test
        r.s = {"ids": ids, "secrets": [], "staff": {}, "storefront": a.storefront_origin.rstrip("/"), "localHub": local,
               "hubUrl": f"http://127.0.0.1:{dz.PORT['hub']}" if local else a.hub_url.rstrip("/"), "hubDb": a.hub_db}
        r.s["appPassword"] = r.secret(secrets.token_urlsafe(18) + "aA1")
        for who, login, name in (("owner", "duena.e2e", "Duena e2e"), ("manager", "gerente.e2e", "Gerente e2e"),
                                 ("cashier", "cajera.e2e", "Cajera e2e")):
            r.s["staff"][who] = {"login": login, "name": name, "password": r.secret(secrets.token_urlsafe(14) + "aA1")}
        r.s["nodeSecret"] = r.secret(secrets.token_urlsafe(32))
        dz.save(dz.STATE, r.s)
        configure(r.s)
        dz.infra(r)  # local databases: the store, plus the hub in a test run

    i, st = r.s["ids"], r.s["staff"]
    branch_args = ["--provision-branch", "--branch-id", i["branch"], "--location-id", i["location"],
                   "--register-id", i["register"], *BRANCH]
    hub_node = ["--node-id", i["hubNode"], "--node-kind", "azure", "--node-code", "HUB"]
    store_node = ["--node-id", i["storeNode"], "--branch-id", i["branch"], "--node-code", "E2E_TIENDA"]

    def staff(who, role, branch):
        args = ["--provision-staff", "--staff-id", i[who], "--login", st[who]["login"], "--display-name", st[who]["name"],
                "--role", role, "--set-password"]
        if branch:
            args += ["--branch-id", i["branch"]] + (["--approver"] if role == "MANAGER" else [])
        return args

    lines = []
    if local:  # the Azure copy already holds its hub node
        lines.append("hub: " + hub_migrator(r, "--provision-node", "register", *hub_node).strip())
    lines.append("hub: " + last_lines(hub_migrator(r, *branch_args)))
    for who, role, branch in (("owner", "OWNER", False), ("manager", "MANAGER", True), ("cashier", "CASHIER", True)):
        lines.append("hub: " + last_lines(hub_migrator(r, *staff(who, role, branch), secret_env="SAVIA_STAFF_PASSWORD",
                                                       secret=st[who]["password"])))
    out = hub_migrator(r, "--provision-node", "create", *store_node, secret_env="SAVIA_NODE_SECRET", secret=r.s["nodeSecret"])
    if r.s["nodeSecret"] in out or dz.NODE_SECRET in out:
        raise SystemExit("the hub migrator printed the node secret")
    lines.append("hub: " + last_lines(out))

    lines.append("store: " + r.scrub(r.migrator("store", *branch_args)).strip())
    for who, role, branch in (("manager", "MANAGER", True), ("cashier", "CASHIER", True)):
        lines.append("store: " + dz.provision_staff(r, "store", who, role, branch, "given"))
    lines.append("store: " + dz.provision_staff(r, "store", "owner", "OWNER", False, None))
    for args in (hub_node, store_node):
        lines.append("store: " + r.migrator("store", "--provision-node", "register", *args).strip())
    r.record(1, "hub and store provisioned: branch, owner, manager, cashier, store node and its credential",
             "DONE", ("local migrator on the hub (test run)" if local else
                      f"caj-savia-migrate job on {r.s['hubDb']}, passwords and node secret as temporary job secrets")
             + "; local migrator on the store", lines)


# ---------------------------------------------------------------- run
def import_catalog(r):
    """dayzero step 6 without the one-time password change: on Azure the owner's password was given, not printed."""
    owner = r.login("hub", "owner")
    me = dz.call("hub", "GET", "/api/v1/me", token=owner)
    rows = [{"row": n + 2, "code": c, "sku": None, "name": name, "type": kind, "size": size, "color": color,
             "cost": cost, "price": price, "stock": None}
            for n, (c, name, kind, size, color, cost, price) in enumerate(dz.PRODUCTS)]
    request = {"batchId": dz.new_id(), "fileName": "e2e.csv", "rows": rows}
    preview = dz.call("hub", "POST", "/api/v1/catalog/import/preview", request, owner)
    result = dz.call("hub", "POST", "/api/v1/catalog/import", request, owner)
    items = {}
    for code, *_ in dz.PRODUCTS:
        status, body = dz.call("hub", "GET", f"/api/v1/catalog/lookup?code={code}", token=owner)
        items[code] = body[0]["itemId"] if status == 200 and body else None
    r.s["items"] = items
    dz.save(dz.STATE, r.s)
    price = dz.call("hub", "POST", f"/api/v1/catalog/items/{items['DZ-0002']}/values",
                    {"changeId": dz.new_id(), "priceMinor": dz.NEW_PRICE, "costMinor": 18000, "reason": "e2e: precio"}, owner)
    flag = me[1].get("mustChangePassword") if isinstance(me[1], dict) else None
    ok = me[0] == 200 and flag is False and result[0] == 200 and all(items.values()) and price[0] == 204
    r.record(6, "owner signs in on the hub; imports 3 products and sets a price", "DONE" if ok else "BLOCKED",
             "POST /auth/login, GET /me, /catalog/import/preview, /catalog/import, /catalog/lookup, /catalog/items/{id}/values",
             [f"GET /me {me[0]} mustChangePassword={flag}", f"preview {dz.short(*preview)}", f"import {dz.short(*result)}",
              f"items {items}", f"price DZ-0002 -> {dz.NEW_PRICE}: {dz.short(*price)}"])
    if not ok:
        raise SystemExit("step 6 blocked")


def available(sku):
    status, body = dz.call("hub", "GET", "/api/v1/public/catalog")
    rows = body.get("items", []) if isinstance(body, dict) else []
    return next((x.get("available") for x in rows if x.get("sku") == sku), None), rows


def order_pay_fulfill(r):
    owner = r.login("hub", "owner")
    sku_rows = available("")[1]
    sku = next((x["sku"] for x in sku_rows if x.get("available")), None)
    before = available(sku)[0] if sku else None
    body = {"lines": [{"sku": sku, "qty": 1}],
            "contact": {"name": "Compradora e2e", "email": "compradora.e2e@example.test", "phone": None},
            "shipping": {"zone": "managua", "address": "Calle de prueba 1", "city": "Managua", "notes": None},
            "provider": "manual", "locale": "es", "turnstileToken": None}
    headers = {"Idempotency-Key": str(uuid.uuid4()), "Origin": r.s["storefront"]}
    sent = [dz.call("hub", "POST", "/api/v1/public/orders", body, headers=headers) for _ in range(2)]
    for _, b in sent:
        if isinstance(b, dict) and b.get("accessToken"):
            r.secret(b["accessToken"])
    first = sent[0][1] if isinstance(sent[0][1], dict) else {}
    order_id, total = first.get("orderId"), first.get("totalMinor")
    same = bool(order_id) and order_id == (sent[1][1] or {}).get("orderId")
    reserved_after = available(sku)[0]
    r.s["order"] = {"id": order_id, "sku": sku}
    dz.save(dz.STATE, r.s)
    r.record(11, "public order (manual payment) sent twice with one Idempotency-Key: one order, one unit reserved",
             "DONE" if same and before is not None and reserved_after == before - 1 else "BLOCKED",
             "POST /api/v1/public/orders twice (Origin = storefront); GET /api/v1/public/catalog",
             [f"sku {sku}: available before {before}, after {reserved_after}",
              f"POST statuses {[s for s, _ in sent]}; same order id: {same}; status {first.get('status')}; "
              f"total {total} {first.get('currency')}"])
    if not same:
        raise SystemExit("order blocked")

    paid = dz.call("hub", "POST", f"/api/v1/web-orders/{order_id}/manual-payment",
                   {"amountMinor": total, "currency": first.get("currency"), "reference": "E2E-TRANSFER-1"}, owner)
    after_pay = order_row(owner, order_id)
    done = dz.call("hub", "POST", f"/api/v1/web-orders/{order_id}/fulfill", None, owner)
    after_fulfill = order_row(owner, order_id)
    token = next(b["accessToken"] for _, b in sent if isinstance(b, dict) and b.get("accessToken"))
    buyer = dz.call("hub", "GET", f"/api/v1/public/orders/{order_id}", headers={"X-Order-Token": token})
    ok = (paid[0] == 204 and done[0] == 204 and after_fulfill.get("status") == "fulfilled"
          and isinstance(buyer[1], dict) and buyer[1].get("status") == "fulfilled")
    r.record(12, "owner records the transfer and fulfils the order; the buyer's status page agrees", "DONE" if ok else "BLOCKED",
             "POST /web-orders/{id}/manual-payment, POST /web-orders/{id}/fulfill (OWNER, hub); "
             "GET /api/v1/public/orders/{id} with X-Order-Token",
             [f"manual-payment {dz.short(*paid)}; order status after it: {after_pay.get('status')}",
              f"fulfill {dz.short(*done)}; order status after it: {after_fulfill.get('status')}",
              f"buyer page status: {buyer[1].get('status') if isinstance(buyer[1], dict) else buyer}"])


def order_row(token, order_id):
    status, rows = dz.call("hub", "GET", "/api/v1/web-orders", token=token)
    return next((o for o in rows if str(o.get("id")).lower() == str(order_id).lower()), {}) if status == 200 else {}


def verify(r):
    sup = r.login("store", "manager")
    item = r.s["items"]["DZ-0002"]
    status, stock = dz.call("store", "GET", "/api/v1/stock", token=sup)
    on_hand = [x["onHand"] for x in stock if x["itemId"].upper() == item.upper()] if status == 200 else stock
    left = available(r.s["order"]["sku"])[0]
    ok = on_hand == [dz.RECEIVED - dz.WEB_UNITS] and left == dz.WEB_UNITS - 1
    r.record(13, "after the order: store stock and hub web availability", "DONE" if ok else "BLOCKED",
             "GET /api/v1/stock (store manager); GET /api/v1/public/catalog (hub)",
             [f"store DZ-0002 onHand {on_hand} (expected {dz.RECEIVED - dz.WEB_UNITS}: received {dz.RECEIVED}, "
              f"consigned {dz.WEB_UNITS}; web sales move hub stock only)",
              f"hub web available for {r.s['order']['sku']}: {left} (expected {dz.WEB_UNITS - 1})",
              "hub SQL evidence (StockBalances) is not read: the hub database is reachable only by the job"])


def cmd_run(_):
    r = dz.Run()
    configure(r.s)
    started = []
    if r.s.get("localHub"):
        started.append(r.start("hub"))
    mark = len(r.log_text("store"))
    started.append(r.start("store"))
    line = r.wait_log("store", r"Sync round(?: refused| could not reach| timed out| failed|: pulled)[^\r\n]*", mark, timeout=120)
    ok = bool(line and "pulled" in line)
    r.record(5, "store host starts against the hub; first sync round", "DONE" if ok else "BLOCKED",
             f"Savia.Api Kind=Branch on {dz.base('store')}, HubUrl {r.s['hubUrl']}", [f"pids {started}", f"first round: {line}"])
    if not ok:
        raise SystemExit("first sync round failed; see " + str(dz.OUT / "host-store.txt"))
    import_catalog(r)
    for step in (dz.step7_arrive, dz.step8_receive, dz.step9_sale, dz.step10_consign):
        step(r)
        if r.t[-1]["status"] != "DONE":
            raise SystemExit(f"step {r.t[-1]['step']} blocked")
    order_pay_fulfill(r)
    verify(r)
    print("\n".join(f"{e['step']}: {e['status']} {e['title']}" for e in r.t))


def cmd_report(a):
    entries = dz.load(dz.TRANSCRIPT, [])
    md = ["# e2e on a deployed hub: transcript", "", "| Step | Status | What | Tool | Evidence |", "| --- | --- | --- | --- | --- |"]
    for e in entries:
        ev = "<br>".join(x.replace("|", "\\|") for x in e["evidence"])
        md.append(f"| {e['step']} | {e['status']} | {e['title']} | {e['tool'].replace('|', '/')} | {ev} |")
    Path(a.out).write_text("\n".join(md) + "\n", encoding="utf-8", newline="\n")
    print(f"wrote {a.out} ({len(entries)} steps)")


def cmd_down(_):
    r = dz.Run()
    if r.s:
        configure(r.s)
    else:
        dz.DBN = {"store": "SAVIA_DEV_e2e_store", "hub": "SAVIA_DEV_e2e_hub"}
    stopped = [r.stop(n) for n in list(r.s.get("pids", {}))]
    for n in dz.DBN.values():
        dz.db.drop(n)
    dz.db.run_sql("master", f"IF SUSER_ID(N'{dz.APP_LOGIN}') IS NOT NULL DROP LOGIN [{dz.APP_LOGIN}];")
    dz.STATE.unlink(missing_ok=True)
    print(f"stopped {stopped}; dropped {list(dz.DBN.values())}; login {dz.APP_LOGIN} removed")
    if r.s and not r.s.get("localHub"):
        print(f"the operator removes the Azure app and database {r.s.get('hubDb')}")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    pr = sub.add_parser("prepare")
    pr.add_argument("--hub-url", default="")
    pr.add_argument("--hub-db", default="")
    pr.add_argument("--hub-node-id", default=str(uuid.uuid4()))
    pr.add_argument("--storefront-origin", default="")
    pr.add_argument("--local-hub-for-test", action="store_true")
    pr.add_argument("--resume", action="store_true", help="replay a prepare that stopped part-way")
    sub.add_parser("run")
    rp = sub.add_parser("report")
    rp.add_argument("--out", required=True)
    sub.add_parser("down")
    a = p.parse_args()
    if a.cmd == "prepare" and not a.resume and not a.storefront_origin:
        raise SystemExit("prepare needs --storefront-origin")
    if a.cmd == "prepare" and not a.resume and not a.local_hub_for_test and not (a.hub_url and a.hub_db):
        p.error("prepare needs --hub-url and --hub-db, or --local-hub-for-test")
    {"prepare": cmd_prepare, "run": cmd_run, "report": cmd_report, "down": cmd_down}[a.cmd](a)


if __name__ == "__main__":
    main()
