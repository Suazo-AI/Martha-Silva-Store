"""Exercise integrated demo navigation with real keyboard input; fictional API only."""
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('shell', ROOT / 'savia/demo/site/verify.py')
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)
s.SESSION = 'savia-nav-primary-20261116'
server = s.ThreadingHTTPServer(('127.0.0.1', 0), s.functools.partial(s.Quiet, directory=str(ROOT / 'savia/.out/demo-site')))
s.threading.Thread(target=server.serve_forever, daemon=True).start()
origin = f'http://127.0.0.1:{server.server_port}'
checks = []

def check(name, js):
    assert s.evaluate(js), name
    checks.append(name)

try:
    s.browser('open', origin)
    s.browser('wait', '#demo-entry')
    s.browser('click', '[data-demo-role=OWNER]')
    for width, height in [(1440, 900), (390, 844)]:
        s.browser('set', 'viewport', width, height)
        s.browser('open', origin + '/#/historial')
        s.browser('wait', '#history-search')
        s.browser('wait', '--load', 'networkidle')
        # The router intentionally preserves previously opened work groups.
        s.evaluate("document.querySelectorAll('#nav details').forEach(group => group.open = false)")
        s.evaluate("document.querySelector('#nav a[data-route=historial]').focus()")
        s.browser('press', 'Tab')
        check(f'{width}-tab-summary', "document.activeElement.matches('#nav summary')")
        s.browser('press', 'Enter')
        check(f'{width}-enter-opens', "document.activeElement.matches('#nav details[open] > summary')")
        s.browser('press', 'Tab')
        check(f'{width}-tab-link-retained', "document.activeElement.matches('#nav details[open] a[data-route=recepcion]')")
        s.browser('press', 'Shift+Tab')
        s.browser('press', 'Space')
        check(f'{width}-space-closes', "document.activeElement.matches('#nav details:not([open]) > summary')")
        s.browser('press', 'Enter')
        s.browser('press', 'Tab')
        s.browser('press', 'Enter')
        s.browser('wait', '--fn', "location.hash === '#/recepcion' && !!document.querySelector('#nav a[data-route=recepcion][aria-current=page]')")
        check(f'{width}-keyboard-route-visible', "document.querySelector('#nav a[data-route=recepcion]').closest('details').open && document.documentElement.scrollWidth === innerWidth")
        s.browser('open', origin + '/#/historial')
        s.browser('wait', '#history-search')
        # Exercise the actual attachment and real browser keyboard events, with a separate owned field.
        s.evaluate("""(async () => {
          const {attachScanField} = await import('/scan.mjs');
          const input = document.createElement('input'); input.id='primary-scan';
          document.querySelector('#screen').append(input);
          window.primaryCodes=[];
          window.primaryDetach=attachScanField(input, code=>window.primaryCodes.push(code));
        })()""")
        s.browser('fill', '#primary-scan', '0000123456789')
        s.browser('press', 'Enter')
        check(f'{width}-manual-scanner', "window.primaryCodes.join(',') === '0000123456789' && document.querySelector('#primary-scan').value === ''")
        s.evaluate("window.primaryDetach();document.querySelector('#primary-scan').remove()")
    assert not s.browser('errors')['errors']
    assert not [x for x in s.browser('console')['messages'] if x.get('type') == 'error']
finally:
    s.browser('close')
    server.shutdown()
    server.server_close()
    (Path(__file__).parent / 'primary-keyboard.json').write_text(json.dumps({'checks': checks, 'count': len(checks), 'fictional_api_only': True, 'server_closed': True}, indent=2), encoding='utf-8')
print(f'{len(checks)} keyboard/scanner browser checks passed')
