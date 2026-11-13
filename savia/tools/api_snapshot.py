#!/usr/bin/env python3
"""Pins the read side of the API before a refactor: every GET route, as each of the five roles.

  python savia/tools/api_snapshot.py save before.json      # pilot API up, database untouched afterwards
  python savia/tools/api_snapshot.py compare before.json   # after the refactor: exit 1 and the differences

It records the status and the body of every (role, route) pair, so it pins the data and the permission table.
Routes come from src/Savia.Api/*.cs; a new GET route is included without editing this file.
Use it for changes that must not alter behavior. It does not cover writes: smoke, e2e and .NET tests do.
Needs the five SAVIA_PILOT_PASSWORD_* variables that `pilot.py up` was started with.
"""
import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
API = os.environ.get("SAVIA_PILOT_URL", "http://127.0.0.1:5080").rstrip("/") + "/api/v1"
LOGINS = ("duena", "gerente", "vendedor1", "vendedor2", "bodega")
BARCODE = "7500001000014"


def queries(day):
    period = {"period": "month", "date": day}
    return {"/catalog/lookup": {"code": BARCODE}, "/catalog/search": {"q": "blusa"}, "/catalog/values": {"q": ""},
            "/receiving/sessions": {"open": "false", "limit": "50"}, "/sales": {"page": "1", "pageSize": "25"},
            "/customers": {"q": "ma"}, "/credits/search": {"q": "ma"}, "/reports/day": {"date": day},
            "/reports/receiving-quality": {"from": day[:8] + "01", "to": day},
            **{route: period for route in ("/reports/summary", "/reports/summary.csv", "/reports/commissions",
                                           "/reports/commissions.csv", "/reports/kpi/business", "/reports/kpi/business.csv",
                                           "/reports/kpi/team", "/reports/kpi/team.csv")}}


def get(path, token=None):
    request = urllib.request.Request(API + path, headers={"Authorization": f"Bearer {token}"} if token else {})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return response.status, response.read()
    except urllib.error.HTTPError as error:
        return error.code, error.read()


def login(name):
    body = json.dumps({"loginName": f"{name}.muestra", "password": os.environ["SAVIA_PILOT_PASSWORD_" + name.upper()]}).encode()
    request = urllib.request.Request(API + "/auth/login", data=body, headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.loads(response.read())["token"]


def routes():
    found = set()
    for path in (ROOT / "src" / "Savia.Api").glob("*.cs"):
        found |= set(re.findall(r'api\.MapGet\(\s*"([^"]+)"', path.read_text(encoding="utf-8")))
    return sorted(found)


def first(token, path, key):
    """An id to fill a route parameter, taken from a list the manager can read."""
    status, body = get(path, token)
    data = json.loads(body) if status == 200 and body else None
    rows = data.get("items", []) if isinstance(data, dict) and "items" in data else data
    if isinstance(rows, dict):
        rows = [rows]
    return next((row[key] for row in rows or [] if isinstance(row, dict) and row.get(key)), "00000000-0000-0000-0000-000000000000")


def snapshot(day):
    tokens = {name: login(name) for name in LOGINS}
    manager = tokens["gerente"]
    ids = {"saleId": first(manager, "/sales?page=1&pageSize=25", "saleId"),
           "sessionId": first(manager, "/receiving/sessions?open=false&limit=50", "scanSessionId"),
           "tillId": first(manager, "/cash/registers", "openTillId")}
    extra, result = queries(day), {}
    for template in routes():
        bare = re.sub(r"\{(\w+)(?::\w+)?\}", lambda m: ids.get(m.group(1), "00000000-0000-0000-0000-000000000000"), template)
        query = extra.get(template)
        path = bare + ("?" + urllib.parse.urlencode(query) if query else "")
        for name, token in tokens.items():
            status, body = get(path, token)
            try:
                value = json.loads(body) if body else None
                if isinstance(value, dict):
                    value.pop("traceId", None)
            except ValueError:
                value = "sha256:" + hashlib.sha256(body).hexdigest()
            result[f"{name} GET {template}"] = {"status": status, "body": value}
    return {"date": day, "ids": ids, "calls": result}


def main(argv):
    if len(argv) != 2 or argv[0] not in ("save", "compare"):
        sys.exit(__doc__)
    target = Path(argv[1])
    if argv[0] == "save":
        data = snapshot(date.today().isoformat())
        target.write_text(json.dumps(data, indent=1, sort_keys=True, ensure_ascii=False) + "\n", encoding="utf-8")
        statuses = sorted({call["status"] for call in data["calls"].values()})
        print(f"snapshot: {len(data['calls'])} calls ({len(routes())} routes x {len(LOGINS)} roles), statuses {statuses} -> {target}")
        return 0
    before = json.loads(target.read_text(encoding="utf-8"))
    after = snapshot(before["date"])
    keys = sorted(set(before["calls"]) | set(after["calls"]))
    different = [key for key in keys if before["calls"].get(key) != after["calls"].get(key)]
    for key in different[:40]:
        old, new = before["calls"].get(key), after["calls"].get(key)
        print(f"DIFF  {key}: status {old and old['status']} -> {new and new['status']}"
              + ("" if (old and old["status"]) != (new and new["status"]) else " (body changed)"))
    print(f"SNAPSHOT {'DIFFERENT' if different else 'SAME'}: {len(keys) - len(different)} of {len(keys)} calls identical")
    return 1 if different else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
