"""Pure manifest rules for the four-node rehearsal. No SQL, no processes: unit-tested in tests/test_rehearsal.py.

A manifest (expected/<scenario>.json) is written before the run. It fixes every id and amount the driver uses and
every effect the checks expect. The checks iterate over the manifest, so an expected sale that the driver never
performed is reported as missing (the self-test injects one).
"""
import hashlib
import json
import re
from pathlib import Path

STORES = ("a", "b", "c")
NODES = ("cloud", "a", "b", "c")
GUID = re.compile(r"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$")
EXPECT = ("present", "absent", "any")
TENDERS = ("cash", "card", "credit")


def load(path):
    path = Path(path)
    raw = path.read_bytes()
    return json.loads(raw.decode("utf-8")), hashlib.sha256(raw).hexdigest()


def up(value):
    return value.upper() if isinstance(value, str) else value


def sale_total(sale):
    return sale["qty"] * sale.get("price", 120000)


def sale_cash(sale):
    return sum(t["amount"] for t in sale["tenders"] if t["kind"] == "cash")


def validate(m):
    """Return a list of manifest errors (empty = valid)."""
    errors, ids, keys = [], set(), set()

    def guid(where, value):
        if not isinstance(value, str) or not GUID.match(value):
            errors.append(f"{where}: {value!r} is not an upper-case GUID")
        elif value in ids:
            errors.append(f"{where}: id {value} is used twice")
        else:
            ids.add(value)

    def key(where, value):
        if not isinstance(value, str) or not value:
            errors.append(f"{where}: missing key")
        elif value in keys:
            errors.append(f"{where}: key {value} is used twice")
        keys.add(value)

    for field in ("scenario", "sales"):
        if field not in m:
            errors.append(f"missing field {field}")
    for store, till in (m.get("tills") or {}).items():
        if store not in STORES:
            errors.append(f"tills: unknown store {store}")
        for i, t in enumerate(till if isinstance(till, list) else [till]):
            guid(f"tills.{store}[{i}]", t)
    for store, c in (m.get("closures") or {}).items():
        if store not in STORES:
            errors.append(f"closures: unknown store {store}")
        guid(f"closures.{store}.cashCountId", c.get("cashCountId"))
        guid(f"closures.{store}.usdCashCountId", c.get("usdCashCountId"))
        guid(f"closures.{store}.closureId", c.get("closureId"))
    returns = {r.get("key"): r for r in m.get("returns", [])}
    groups = {}
    for s in m.get("sales", []):
        where = f"sales.{s.get('key')}"
        key(where, s.get("key"))
        guid(where + ".saleId", s.get("saleId"))
        if s.get("store") not in STORES:
            errors.append(f"{where}: unknown store {s.get('store')}")
        if s.get("expect", "present") not in EXPECT:
            errors.append(f"{where}: expect must be one of {EXPECT}")
        if not isinstance(s.get("qty"), int) or s["qty"] < 1:
            errors.append(f"{where}: qty must be a positive integer")
            continue
        tenders = s.get("tenders") or []
        if not tenders:
            errors.append(f"{where}: no tenders")
        for t in tenders:
            if t.get("kind") not in TENDERS:
                errors.append(f"{where}: tender kind {t.get('kind')!r}")
            if t.get("kind") == "credit" and t.get("credit") not in returns:
                errors.append(f"{where}: credit tender names unknown return {t.get('credit')!r}")
        if sum(t.get("amount", 0) for t in tenders) != sale_total(s):
            errors.append(f"{where}: tenders {sum(t.get('amount', 0) for t in tenders)} != total {sale_total(s)}")
        if s.get("group"):
            groups.setdefault(s["group"], []).append(s)
    for name, members in groups.items():
        if len(members) < 2:
            errors.append(f"group {name}: needs at least two sales")
        if len({sale_total(x) for x in members}) > 1 or len({x["store"] for x in members}) > 1:
            errors.append(f"group {name}: members must share store and total")
    sales = {s.get("key"): s for s in m.get("sales", [])}
    for r in m.get("returns", []):
        where = f"returns.{r.get('key')}"
        key(where, r.get("key"))
        guid(where + ".reversalId", r.get("reversalId"))
        guid(where + ".creditId", r.get("creditId"))
        if r.get("sale") not in sales:
            errors.append(f"{where}: unknown sale {r.get('sale')!r}")
        elif r.get("creditMinor") != r.get("qty", 0) * sales[r["sale"]].get("price", 120000):
            errors.append(f"{where}: creditMinor must equal qty * price")
    for t in m.get("transfers", []):
        where = f"transfers.{t.get('key')}"
        key(where, t.get("key"))
        guid(where + ".transferId", t.get("transferId"))
        if t.get("credit") not in returns:
            errors.append(f"{where}: unknown credit {t.get('credit')!r}")
        if t.get("from") not in STORES or t.get("to") not in STORES or t.get("from") == t.get("to"):
            errors.append(f"{where}: bad from/to")
    for a in m.get("alloc", []):
        if a.get("credit") not in returns or a.get("store") not in STORES or not isinstance(a.get("available"), int):
            errors.append(f"alloc {a}: needs credit (return key), store and integer available")
    for store, total in (m.get("store_totals") or {}).items():
        mine = [s for s in m.get("sales", []) if s.get("store") == store and isinstance(s.get("qty"), int)]
        if any(s.get("expect") == "any" for s in mine):
            errors.append(f"store_totals.{store}: a store with an 'any' sale cannot have fixed totals")
            continue
        fixed = [s for s in mine if s.get("expect", "present") == "present" and not s.get("group")]
        count = len(fixed) + len({s["group"] for s in mine if s.get("group")})
        amount = sum(sale_total(s) for s in fixed) + sum(sale_total(g[0]) for n, g in groups.items() if g[0]["store"] == store)
        if total != {"count": count, "totalMinor": amount}:
            errors.append(f"store_totals.{store}: {total} != computed {{'count': {count}, 'totalMinor': {amount}}}")
    return errors


def evaluate(m, ids, snaps, outcomes=None):
    """Compare node snapshots with the manifest.

    ids: fixture names -> GUID (test.Ids). snaps: node -> snapshot (see harness.snapshot). outcomes: driver key ->
    {'ok': bool, ...} for operations the driver performed. Returns a list of (ok, check, detail).
    """
    results = []
    outcomes = outcomes or {}

    def add(ok, check, detail=""):
        results.append((bool(ok), check, detail))

    branch_of = {up(ids["branch" + s.upper()]): s for s in STORES}
    loc_of = {s: up(ids["loc" + s.upper()]) for s in STORES}
    item = up(ids["item"])
    returns = {r["key"]: r for r in m.get("returns", [])}
    expected_ids = {up(s["saleId"]) for s in m["sales"]}
    groups = {}
    for s in m["sales"]:
        if s.get("group"):
            groups.setdefault(s["group"], []).append(s)

    # 1. What the HTTP API answered while the driver ran.
    for s in m["sales"]:
        o = outcomes.get(s["key"])
        exp = s.get("expect", "present")
        if o is None:
            continue  # never performed: the node checks below report it if it was expected
        if exp == "present" and not s.get("group"):
            add(o["ok"], f"http {s['key']} accepted", o.get("detail", ""))
        elif exp == "absent":
            add(not o["ok"], f"http {s['key']} refused", o.get("detail", ""))
    for name, members in groups.items():
        done = [outcomes[x["key"]] for x in members if x["key"] in outcomes]
        if done:
            add(sum(1 for o in done if o["ok"]) == 1, f"http group {name}: exactly one accepted",
                "; ".join(f"{x['key']}={outcomes.get(x['key'], {}).get('detail', 'not run')}" for x in members))

    for node in NODES:
        snap = snaps[node]
        rows = {up(r["id"]): r for r in snap.get("sales") or []}
        # 2. Every expected sale once, with every effect; absent sales nowhere.
        for s in m["sales"]:
            sid, exp = up(s["saleId"]), s.get("expect", "present")
            row = rows.get(sid)
            label = f"{node}: sale {s['key']}"
            if s.get("group"):
                continue
            if exp == "absent":
                add(row is None, f"{label} absent", "" if row is None else "present")
                continue
            if row is None:
                add(exp == "any", f"{label} present", "missing")
                continue
            add(*_sale_effects(s, row, branch_of, label))
        for name, members in groups.items():
            present = [x for x in members if up(x["saleId"]) in rows]
            add(len(present) == 1, f"{node}: group {name} exactly one present", f"present={[x['key'] for x in present]}")
            for x in present:
                add(*_sale_effects(x, rows[up(x["saleId"])], branch_of, f"{node}: sale {x['key']}"))
        extra = sorted(set(rows) - expected_ids)
        add(not extra, f"{node}: no sale outside the manifest", f"extra={extra[:5]}")
        # 3. Per-store count and total.
        for store, want in (m.get("store_totals") or {}).items():
            mine = [r for r in rows.values() if branch_of.get(up(r["branch"])) == store]
            got = {"count": len(mine), "totalMinor": sum(r["total"] for r in mine)}
            add(got == want, f"{node}: store {store} totals", f"expected={want} actual={got}")
        # 4. Stock on hand per store.
        stock = {(up(r["loc"]), up(r["item"])): r["onhand"] for r in snap.get("stock") or []}
        for store, want in (m.get("on_hand") or {}).items():
            got = stock.get((loc_of[store], item))
            add(got == want, f"{node}: on hand at {store}", f"expected={want} actual={got}")
        # 5. Returns to credit and credit allocations.
        revs = {up(r["id"]) for r in snap.get("reversals") or []}
        credits = {up(c["id"]): c for c in snap.get("credits") or []}
        for r in m.get("returns", []):
            c = credits.get(up(r["creditId"]))
            add(up(r["reversalId"]) in revs and c is not None and c["orig"] == r["creditMinor"],
                f"{node}: return {r['key']} -> credit {r['creditMinor']}", f"credit={c}")
        alloc = {(up(a["credit"]), branch_of.get(up(a["branch"]))): a for a in snap.get("alloc") or []}
        for a in m.get("alloc", []):
            row = alloc.get((up(returns[a["credit"]]["creditId"]), a["store"]))
            got = None if row is None else row["av"]
            add(got == a["available"] and (row is None or not row.get("held")),
                f"{node}: credit {a['credit']} available at {a['store']}", f"expected={a['available']} actual={row}")
        # 6. Transfer outcomes.
        tv = {up(t["id"]): t for t in snap.get("transfers") or []}
        for t in m.get("transfers", []):
            row = tv.get(up(t["transferId"]))
            want = (t["status"], t.get("overridden", 0))
            got = None if row is None else (row["st"], row["ov"])
            add(got == want, f"{node}: transfer {t['key']} {want[0]}", f"expected={want} actual={got}")
    return results


def _sale_effects(s, row, branch_of, label):
    want = {"store": s["store"], "total": sale_total(s), "lines": 1, "qty": s["qty"], "tenders": len(s["tenders"]),
            "tender_sum": sale_total(s), "stock": -s["qty"], "cash": sale_cash(s)}
    got = {"store": branch_of.get(up(row["branch"])), "total": row["total"], "lines": row["nl"], "qty": row["qty"],
           "tenders": row["nt"], "tender_sum": row["tsum"], "stock": row["stock"], "cash": row["cash"]}
    if s.get("returned"):
        got.pop("stock"); want.pop("stock")  # the return puts the units back under the reversal, not the sale
    diff = {k: (want[k], got[k]) for k in want if want[k] != got[k]}
    return not diff, f"{label} once with its effects", "" if not diff else f"(expected, actual)={diff}"


def r1(hashes):
    """hashes: node -> {table: (count, sha)}. Returns a list of tables whose replicas differ."""
    tables = sorted(hashes["cloud"])
    return [t for t in tables if len({hashes[n].get(t) for n in NODES}) > 1]


def conservation(rows, allow):
    """rows: node -> list of violations from audit.usp_CheckConservation. allow: pinned known rows.

    Returns (unexpected, pinned_missing): violations not pinned, and pinned rows that did not appear.
    """
    pins = {(p["node"], p["check"], up(p["key"])) for p in allow or []}
    seen, unexpected = set(), []
    for node in NODES:
        for v in rows.get(node) or []:
            k = (node, v["CheckName"], up(v["KeyText"]))
            if k in pins:
                seen.add(k)
            else:
                unexpected.append(f"{node} {v['CheckName']} {v['KeyText']} expected={v.get('Expected')} actual={v.get('Actual')}")
    return unexpected, sorted(pins - seen)
