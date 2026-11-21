"""Real app/router and modal lifecycle checks. Local fictional HTTP only."""
import importlib.util
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).parent
spec = importlib.util.spec_from_file_location('shell', ROOT / 'savia/demo/site/verify.py')
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)
s.SESSION = 'savia-ux-lookup-20261116'
result = {'fictional_only': True, 'checks': [], 'passed': False}
server = None


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


try:
    server = s.ThreadingHTTPServer(('127.0.0.1', 0), s.functools.partial(Fixture, directory=str(ROOT)))
    s.threading.Thread(target=server.serve_forever, daemon=True).start()
    origin = f'http://127.0.0.1:{server.server_port}'
    for width, height in [(1440, 900), (390, 844)]:
        s.browser('set', 'viewport', width, height)
        for action in ['active-control', 'navigation', 'logout', 'account']:
            s.browser('open', origin + '/shell?case=lookup')
            s.browser('wait', '#sale-search')
            s.browser('wait', '.product')
            s.browser('select', '#sale-seller', '00000000-0000-4000-8000-000000000006')
            s.evaluate('''window.lookupDone=false;window.lookupError=null;
              savia.handleScan('AMBIGUOUS').then(()=>lookupDone=true,error=>{lookupError=String(error);lookupDone=true});true''')
            s.browser('wait', '--fn', 'fixture.held')
            if action == 'navigation':
                s.evaluate('location.hash="#/historial"')
                s.browser('wait', '#history-search')
            elif action in ['logout', 'account']:
                s.browser('click', '#logout')
                s.browser('wait', '#login-user')
                if action == 'account':
                    s.evaluate('location.hash="#/historial"')
                    s.browser('fill', '#login-user', 'cuenta-b-ficticia')
                    s.browser('fill', '#login-pass', 'ficticia')
                    s.browser('click', '#access button[type=submit]')
                    s.browser('wait', '#history-search')
            if action != 'active-control':
                s.evaluate('''document.querySelector('#modal-body').textContent='REPLACEMENT CONTEXT';
                  document.querySelector('#history-search, #login-user').focus();
                  window.replacement={screen:document.querySelector('#screen').innerHTML,
                    operator:document.querySelector('#operator-label').textContent,token:sessionStorage.getItem('savia.token'),
                    focus:document.activeElement,dialog:document.querySelector('#modal-body').innerHTML};''')
            s.evaluate('fixture.release()')
            s.browser('wait', '--fn', 'lookupDone')
            s.evaluate('new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))')
            assert s.evaluate('lookupError===null'), (width, action, 'lookup-error')
            if action == 'active-control':
                s.browser('wait', '#sale-sizes')
                observed = s.evaluate('''({modal:document.querySelector('#modal').open,
                  pickerFocused:document.activeElement===document.querySelector('#sale-sizes button'),
                  buttons:document.querySelectorAll('#sale-sizes button').length,posts:fixture.posts.length})''')
                assert observed == {'modal': True, 'pickerFocused': True, 'buttons': 2, 'posts': 0}, observed
                s.browser('click', '#sale-sizes button:first-child')
                s.browser('wait', '.tline')
                assert s.evaluate('!document.querySelector("#modal").open && document.querySelectorAll(".tline").length===1 && fixture.posts.length===0')
            else:
                observed = s.evaluate('''({modalClosed:!document.querySelector('#modal').open,
                  screenUnchanged:document.querySelector('#screen').innerHTML===replacement.screen,
                  operatorUnchanged:document.querySelector('#operator-label').textContent===replacement.operator,
                  tokenUnchanged:sessionStorage.getItem('savia.token')===replacement.token,
                  dialogUnchanged:document.querySelector('#modal-body').innerHTML===replacement.dialog,
                  focusUnchanged:document.activeElement===replacement.focus,posts:fixture.posts.length})''')
                assert all(value for name, value in observed.items() if name != 'posts') and observed['posts'] == 0, observed
            errors = s.browser('errors')['errors']
            assert not errors, errors
            result['checks'].append({'viewport': [width, height], 'action': action, 'pass': True, 'observed': observed})
    result['passed'] = True
except BaseException as error:
    result['error'] = str(error)
    raise
finally:
    try:
        s.browser('close')
        result['browser_closed'] = True
    finally:
        if server:
            server.shutdown()
            server.server_close()
        result['server_closed'] = server is not None
        (OUT / 'browser.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(json.dumps({'passed': result['passed'], 'scenarios': len(result['checks'])}))
sys.exit(0 if result['passed'] else 1)
