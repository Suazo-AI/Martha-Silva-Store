"""Combined UX proof with owned local servers and fictional data only."""
import importlib.util
import json
from pathlib import Path
import traceback
import sys

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).parent
spec = importlib.util.spec_from_file_location('shell', ROOT / 'savia/demo/site/verify.py')
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)
s.SESSION = 'savia-ux-primary-combined-20261116'
servers = []
result = {'fictional_only': True, 'mounted': [], 'keyboard': [], 'views': [], 'passed': False}


def serve(directory):
    server = s.ThreadingHTTPServer(('127.0.0.1', 0), s.functools.partial(s.Quiet, directory=str(directory)))
    s.threading.Thread(target=server.serve_forever, daemon=True).start()
    servers.append(server)
    return f'http://127.0.0.1:{server.server_port}'


def check(name, expression):
    value = s.evaluate(expression)
    assert value, (name, value)
    result['keyboard'].append(name)


try:
    if '--keyboard-only' not in sys.argv:
        fixture = serve(ROOT)
        s.browser('open', fixture + '/docs/savia-ux-20261116/sale/fixture.html')
        s.browser('wait', '#sale-search')
        result['mounted'] = s.evaluate("(async()=>{const {runSaleUX}=await import('/savia/web/tests/sale-ux.browser.mjs');return await runSaleUX()})()")
        assert len(result['mounted']) == 41
        assert not s.browser('errors')['errors']
    else:
        result['mounted_evidence'] = 'browser-first.json; not rerun'
    demo = serve(ROOT / 'savia/.out/demo-site')
    s.browser('open', demo)
    s.browser('wait', '#demo-entry')
    s.browser('click', '[data-demo-role=MANAGER]')
    for width, height in [(1440, 900), (390, 844)]:
        s.browser('set', 'viewport', width, height)
        s.browser('open', demo + '/#/venta')
        # A same-hash open preserves the current ticket and seller by design.
        s.browser('reload')
        s.browser('wait', '#sale-seller')
        s.browser('wait', '--load', 'networkidle')
        check(f'{width}-requires-explicit-seller', "document.querySelector('#sale-seller').value==='' && document.querySelector('#pay').disabled")
        s.browser('select', '#sale-seller', '10000000-0000-4000-8000-000000000003')
        s.evaluate("document.querySelector('#sale-advanced > summary').focus()")
        s.browser('press', 'Enter')
        check(f'{width}-enter-opens-advanced', "document.querySelector('#sale-advanced').open && document.activeElement.matches('#sale-advanced > summary')")
        s.browser('press', 'Space')
        check(f'{width}-space-closes-advanced', "!document.querySelector('#sale-advanced').open && document.activeElement.matches('#sale-advanced > summary')")
        s.browser('fill', '#sale-search', 'AUR-1-S')
        s.browser('press', 'Enter')
        s.browser('wait', '.tline')
        check(f'{width}-scan-enter-adds-once', "document.querySelectorAll('.tline').length===1 && document.querySelector('#sale-search').value==='' && document.querySelector('#ticket-lines').textContent.includes('AUR-1-S')")
        s.evaluate("document.querySelector('#nav details').open=false;document.querySelector('#nav details > summary').focus()")
        s.browser('press', 'Enter')
        check(f'{width}-nav-focus-with-sale-scanner', "document.activeElement.matches('#nav summary') && document.activeElement.parentElement.open")
        s.browser('press', 'Space')
        check(f'{width}-nav-space-with-sale-scanner', "document.activeElement.matches('#nav summary') && !document.activeElement.parentElement.open")
        s.browser('fill', '#received', '2000')
        check(f'{width}-cash-change-preview', "!document.querySelector('#pay').disabled && document.querySelector('#total').textContent.includes('1,800.00') && document.querySelector('#balance').textContent.includes('200.00')")
        s.browser('screenshot', OUT / f'sale-ready-{width}.png')
        before = s.evaluate("JSON.parse(localStorage.getItem('savia.demo.v1')).sales.length")
        s.evaluate("document.querySelector('#pay').focus()")
        s.browser('press', 'Enter')
        s.browser('wait', '#open-receipt')
        check(f'{width}-single-keyboard-sale', f"JSON.parse(localStorage.getItem('savia.demo.v1')).sales.length==={before+1} && !localStorage.getItem('savia.sale.pending.v1') && document.querySelector('#receipt').textContent.includes('Venta registrada')")
        check(f'{width}-posted-seller-and-money', "(()=>{const sale=JSON.parse(localStorage.getItem('savia.demo.v1')).sales.at(-1);return sale.totalMinor===180000 && sale.lines.length===1 && sale.lines[0].quantity===1 && sale.lines[0].sellerId==='10000000-0000-4000-8000-000000000003' && sale.tenders[0].receivedMinor===200000 && sale.tenders[0].changeMinor===20000})()")
        s.browser('screenshot', OUT / f'sale-receipt-{width}.png')
        check(f'{width}-no-horizontal-overflow', "document.documentElement.scrollWidth===innerWidth")
        result['views'].append({'width': width, 'height': height, 'receipt': s.evaluate("document.querySelector('#receipt').textContent")})
    assert not s.browser('errors')['errors']
    assert not [m for m in s.browser('console')['messages'] if m.get('type') == 'error']
    result['passed'] = True
except BaseException:
    result['error'] = traceback.format_exc()
    raise
finally:
    try:
        s.browser('close')
        result['browser_closed'] = True
    finally:
        for server in servers:
            server.shutdown()
            server.server_close()
        result['servers_closed'] = len(servers)
        (OUT / 'browser.json').write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({'mounted': len(result['mounted']), 'keyboard': len(result['keyboard']), 'passed': result['passed']}))
