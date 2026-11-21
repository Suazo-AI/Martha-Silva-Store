#!/usr/bin/env python3
"""Rehearsal of the owner demo: signs in as each sample role and opens every screen of docs/pilot/DEMO.md.

  python savia/tools/pilot.py reset --demo      # invented history; replaces only SAVIA_DEV_pilot
  python savia/tools/pilot.py up --lan
  python savia/tools/demo_rehearsal.py          # read only: the demo data stays as it is

It writes nothing to the database. Screenshots go to savia/.out/demo/<UTC time>/.
It fails when a screen does not load, shows no data, or the browser reports an error.
Needs agent-browser and the five SAVIA_PILOT_PASSWORD_* variables that `pilot.py up` was started with.
"""
import importlib.util
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / ".out" / "demo" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
os.environ["SAVIA_E2E_SHOTS"] = str(OUT)
spec = importlib.util.spec_from_file_location("pilot_browser", ROOT / "web" / "tests" / "e2e_pilot.py")
browser = importlib.util.module_from_spec(spec)
spec.loader.exec_module(browser)

HAS_ROWS = "document.querySelectorAll('#screen article, #screen tbody tr, #screen .sale-item, #screen .panel').length > 0"
# user, then (route, screenshot name, what must be true before the screenshot, steps before waiting or None)
TOUR = [
    ("duena.muestra", [
        ("reporte", "01-duena-negocio-mes", "document.querySelector('#screen').textContent.includes('Venta neta')", [("select", "#report-period", "month")]),
        ("reporte", "02-duena-equipo-mes", "document.querySelector('#screen').textContent.includes('Vendedores')", [("select", "#report-period", "month"), ("click", "#tab-equipo")]),
        ("comisiones", "03-duena-comisiones", "document.querySelectorAll('#commissions article').length >= 2", [("select", "#commission-period", "month")]),
        ("aprobaciones", "04-duena-aprobaciones", "document.querySelectorAll('#approval-list article').length > 0", None),
        ("precios", "05-duena-precios", "document.querySelectorAll('#price-list article').length > 0", None),
        ("importar", "06-duena-importar", "document.querySelector('#screen input[type=file]')", None),
    ]),
    ("gerente.muestra", [
        ("venta", "07-gerente-venta", "document.querySelectorAll('#screen select').length > 0", None),
        ("caja", "08-gerente-caja", HAS_ROWS, None),
        ("historial", "09-gerente-historial", HAS_ROWS, None),
        ("excepciones", "10-gerente-excepciones", HAS_ROWS, None),
    ]),
    ("bodega.muestra", [
        ("recepcion", "11-bodega-recepcion", HAS_ROWS, None),
        ("inventario", "12-bodega-inventario", HAS_ROWS, None),
        ("calidad", "13-bodega-calidad", HAS_ROWS, None),
    ]),
    ("vendedor1.muestra", [
        ("comisiones", "14-vendedora-comisiones", "document.querySelectorAll('#commissions article').length === 1", None),
        ("reporte", "15-vendedora-equipo", "document.querySelector('#screen').textContent.includes('Vendedores')", None),
    ]),
]


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    if not browser.AB or not all(browser.PASSWORDS.values()):
        sys.exit("demo rehearsal: agent-browser and the five SAVIA_PILOT_PASSWORD_* variables are required")
    failed, started = [], time.time()
    browser.ab("open", browser.WEB + "/")
    try:
        browser.ab("set", "viewport", "1366", "768")
        browser.js("window.__errors=[];window.addEventListener('error',e=>window.__errors.push(String(e.message)));"
                   "const log=console.error;console.error=(...a)=>{window.__errors.push(a.join(' '));log(...a);};return 1;")
        for user, screens in TOUR:
            browser.login_ui(user)
            for route, name, ready, change in screens:
                try:
                    browser.js(f"location.hash='#/ajustes';return 1;")   # leave first, so the same route loads again
                    browser.wait_for("location.hash === '#/ajustes'", "neutral screen")
                    browser.js(f"location.hash='#/{route}';return 1;")
                    browser.wait_for(f"location.hash.startsWith('#/{route.split('?')[0]}') && document.querySelector('#screen').children.length", f"{route} opens")
                    for kind, *arguments in change or []:
                        (browser.select if kind == "select" else browser.click)(*arguments)
                    browser.wait_for(ready, f"{route} shows data", seconds=20)
                    time.sleep(0.4)
                    browser.shot(name)
                    print(f"ok   {user}: {route} -> {name}.png", flush=True)
                except Exception as error:  # every screen is tried; the rehearsal reports all that fail
                    failed.append(name)
                    print(f"FAIL {user}: {route}: {error}", flush=True)
        errors = browser.js("return JSON.stringify(window.__errors||[]);")
        errors = json.loads(errors) if isinstance(errors, str) else (errors or [])
    finally:
        browser.close_browser()
    total = sum(len(screens) for _, screens in TOUR)
    print(f"browser errors: {len(errors)}" + ("" if not errors else " " + "; ".join(errors[:3])))
    ok = not failed and not errors
    print(f"REHEARSAL {'PASS' if ok else 'FAIL'}: {total - len(failed)} of {total} screens in {time.time() - started:.0f}s. Screenshots: {OUT}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
