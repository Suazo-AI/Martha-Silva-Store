"""Real shell, reset and approval regression checks. Fictional HTTP only."""
import importlib.util
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).parent
spec = importlib.util.spec_from_file_location('shell', ROOT / 'savia/demo/site/verify.py')
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)
s.SESSION = 'savia-ux-corrections-20261116'
results = {'checks': [], 'fictional_only': True, 'passed': False}
servers = []


class Fixture(s.Quiet):
    def do_GET(self):
        if self.path.startswith('/shell?'):
            page = (ROOT / 'savia/web/index.html').read_text(encoding='utf-8')
            page = page.replace('href="app.css"', 'href="/savia/web/app.css"')
            page = page.replace('src="app.mjs"', 'src="/docs/savia-ux-20261116/corrections/shell-fixture.mjs"')
            data = page.encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        else:
            super().do_GET()


def serve(directory, handler=s.Quiet):
    server = s.ThreadingHTTPServer(('127.0.0.1', 0), s.functools.partial(handler, directory=str(directory)))
    s.threading.Thread(target=server.serve_forever, daemon=True).start()
    servers.append(server)
    return f'http://127.0.0.1:{server.server_port}'


def check(name, expression):
    value = s.evaluate(expression)
    results['checks'].append({'name': name, 'pass': bool(value), 'observed': value})


def frames():
    s.evaluate('new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))')


try:
    origin = serve(ROOT, Fixture)
    for mode in ['recovery-register-hold', 'recovery-register-fail', 'recovery-summary-hold', 'recovery-summary-fail']:
        s.browser('open', f'{origin}/shell?case={mode}')
        s.browser('wait', '--fn', 'globalThis.fixture?.booted && fixture.calls.some(c=>c.path==="/me")')
        frames()
        check(mode + '-shell-mounts-recovery', '!!document.querySelector("#consult-receipt")')
        if s.evaluate('!!document.querySelector("#consult-receipt")'):
            s.browser('click', '#consult-receipt')
            s.browser('wait', '#finish-recovery')
            check(mode + '-receipt-without-dependencies-or-repost', '''
              fixture.posts.length===0 && !fixture.calls.some(c=>c.path.startsWith('/cash/')) &&
              !!localStorage.getItem('savia.sale.pending.v1') && document.querySelector('#screen').textContent.includes('Venta registrada')
            ''')
        if s.evaluate('fixture.held'): s.evaluate('fixture.release()')
    for stage, action in [(stage, action) for stage in ['open', 'register', 'summary'] for action in ['navigation', 'logout', 'account']]:
        s.browser('open', f'{origin}/shell?case=mount-{stage}')
        s.browser('wait', '--fn', 'globalThis.fixture?.held')
        if action == 'navigation':
            s.evaluate('location.hash="#/historial"')
            s.browser('wait', '#history-search')
        else:
            s.browser('click', '#logout')
            s.browser('wait', '#login-user')
            if action == 'account':
                s.evaluate('location.hash="#/historial"')
                s.browser('fill', '#login-user', 'cuenta-b-ficticia')
                s.browser('fill', '#login-pass', 'ficticia')
                s.browser('click', '#access button[type=submit]')
                s.browser('wait', '#history-search')
        s.evaluate('''window.beforeRelease={screen:document.querySelector('#screen').innerHTML,title:document.title,
          operator:document.querySelector('#operator-label').textContent};
          localStorage.setItem('savia.device.till',JSON.stringify({tillId:'new-screen-sentinel'}));
          localStorage.setItem('savia.device.parkedTickets',JSON.stringify({tillId:'new-screen-sentinel',tickets:[]}));
          beforeRelease.till=localStorage.getItem('savia.device.till');
          beforeRelease.parked=localStorage.getItem('savia.device.parkedTickets');fixture.release()''')
        s.browser('wait', '--fn', 'fixture.released')
        frames()
        check(stage + '-' + action + '-retired-mount-cannot-overwrite', '''
          beforeRelease.screen===document.querySelector('#screen').innerHTML && beforeRelease.title===document.title &&
          beforeRelease.operator===document.querySelector('#operator-label').textContent && !document.querySelector('#till-register') &&
          beforeRelease.till===localStorage.getItem('savia.device.till') &&
          beforeRelease.parked===localStorage.getItem('savia.device.parkedTickets')
        ''')
        if action != 'logout':
            s.evaluate('globalThis.savia.handleScan("ROUTE-PROBE")')
            frames()
            check(stage + '-' + action + '-current-scanner-handle', '''
              document.querySelector('#history-search')?.value==='ROUTE-PROBE' &&
              fixture.calls.some(c=>c.path.includes('q=ROUTE-PROBE')) && fixture.posts.length===0
            ''')
        else:
            check(stage + '-logout-keeps-login-and-token-cleared', '!sessionStorage.getItem("savia.token") && !document.querySelector("#access").hidden && !document.querySelector("#shell").checkVisibility()')

    # Actual demo boot/reset, actual fake ledger; no shell fixture for this boundary.
    demo = serve(ROOT / 'savia/.out/demo-site')
    s.browser('open', demo)
    s.browser('wait', '#demo-entry')
    s.browser('click', '[data-demo-role=MANAGER]')
    s.browser('wait', '#sale-search')
    s.evaluate('''(async()=>{
      const api=await import('/api.mjs'), r=await import('/sale-recovery.mjs');
      const me=await api.me(), till=(await api.registers()).find(t=>t.openTillId);
      const item=(await api.lookup('AUR-1-S'))[0], seller=(await api.sellers())[0];
      const body={saleId:crypto.randomUUID(),tillId:till.openTillId,currencyCode:'NIO',
        lines:[{lineNumber:1,itemId:item.itemId,sellerId:seller.sellerId,quantity:1,unitPriceMinor:item.unitPriceMinor,discountMinor:0}],
        tenders:[{tenderNumber:1,tenderKind:'cash',amountMinor:item.unitPriceMinor,receivedMinor:item.unitPriceMinor,changeMinor:0}]};
      await api.postSale(body);
      const record={version:1,scope:r.actorScope(me),body,changeMinor:0};r.persistPending(record);
      window.savedRecord=record;localStorage.setItem('ux.unrelated','keep');sessionStorage.setItem('ux.unrelated','keep');
      window.storageBefore=JSON.stringify({local:{...localStorage},session:{...sessionStorage}});
    })()''')
    s.browser('click', '#demo-reset')
    s.browser('click', '#confirm-no')
    check('reset-cancel-preserves-pending-and-all-storage', 'storageBefore===JSON.stringify({local:{...localStorage},session:{...sessionStorage}})')
    s.browser('click', '#demo-reset')
    s.browser('click', '#confirm-yes')
    s.browser('wait', '#demo-entry')
    check('reset-clears-only-demo-pending', '!localStorage.getItem("savia.sale.pending.v1") && localStorage.getItem("ux.unrelated")==="keep" && sessionStorage.getItem("ux.unrelated")==="keep" && !sessionStorage.getItem("savia.token")')
    s.browser('click', '[data-demo-role=MANAGER]')
    s.browser('wait', '--fn', '!!document.querySelector("#sale-search, #consult-receipt")')
    check('reset-role-reentry-is-usable', '!!document.querySelector("#sale-search") && !document.querySelector("#consult-receipt")')
    s.evaluate('''(async()=>{
      localStorage.removeItem('savia.sale.pending.v1');
      const api=await import('/api.mjs'),r=await import('/sale-recovery.mjs'),me=await api.me();
      const record={version:1,scope:{...r.actorScope(me),origin:'https://real-savia.invalid'},changeMinor:0,
        body:{saleId:crypto.randomUUID(),tillId:crypto.randomUUID(),currencyCode:'NIO',
          lines:[{lineNumber:1,itemId:crypto.randomUUID(),sellerId:crypto.randomUUID(),quantity:1,unitPriceMinor:100,discountMinor:0}],
          tenders:[{tenderNumber:1,tenderKind:'cash',amountMinor:100}]}};
      r.persistPending(record);sessionStorage.setItem('ux.real-marker',localStorage.getItem(r.RECOVERY_KEY));
    })()''')
    s.browser('click', '#demo-reset')
    s.browser('click', '#confirm-yes')
    s.browser('wait', '#demo-entry')
    check('reset-preserves-real-origin-quarantine-byte-for-byte', 'localStorage.getItem("savia.sale.pending.v1")===sessionStorage.getItem("ux.real-marker")')
    results['passed'] = all(row['pass'] for row in results['checks'])
except BaseException as error:
    results['error'] = str(error)
    raise
finally:
    try:
        s.browser('close')
        results['browser_closed'] = True
    finally:
        for server in servers:
            server.shutdown()
            server.server_close()
        results['servers_closed'] = len(servers)
        target = OUT / ('red.json' if '--red' in sys.argv else 'browser.json')
        target.write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(json.dumps({'pass': results['passed'], 'checks': len(results['checks']), 'failed': [row['name'] for row in results['checks'] if not row['pass']]}))
sys.exit(0 if results['passed'] else 1)
