"""Local shell acceptance using agent-browser CLI, never Playwright."""
import base64
import functools
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import shutil
import subprocess
import threading
import tempfile
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = Path(__file__).parent / 'evidence'
SESSION = 'savia-shell-acceptance'
CLI = shutil.which('agent-browser.cmd') or shutil.which('agent-browser')


def browser(*args):
    # The daemon can inherit pipe handles. Files let the CLI exit independently.
    with tempfile.TemporaryFile() as stdout, tempfile.TemporaryFile() as stderr:
        result = subprocess.run([CLI, '--session', SESSION, '--json', *map(str, args)],
                                stdout=stdout, stderr=stderr, timeout=45)
        stdout.seek(0)
        data = json.loads(stdout.read().decode('utf-8'))
    if result.returncode or not data['success']:
        raise RuntimeError(f'agent-browser {args}: {data}')
    return data['data']


def evaluate(js):
    return browser('eval', '-b', base64.b64encode(js.encode()).decode())['result']


class Quiet(SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass


def main():
    EVIDENCE.mkdir(exist_ok=True)
    output = ROOT / '.out' / 'demo-site'
    files = [p.relative_to(output).as_posix() for p in output.rglob('*') if p.is_file()]
    assert '_headers' in files and 'index.html' in files and 'etiqueta/index.html' in files
    assert not any('/tests/' in '/' + p or '.test.' in p for p in files)
    for page in ('index.html', 'etiqueta/index.html'):
        text = (output / page).read_text(encoding='utf-8')
        assert text.count('src="/demo/site/boot.mjs"') == 1
        assert 'src="app.mjs"' not in text and 'src="etiqueta.mjs"' not in text
    server = ThreadingHTTPServer(('127.0.0.1', 0), functools.partial(Quiet, directory=str(output)))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    origin = f'http://127.0.0.1:{server.server_port}'
    results = {'build': {'pass': True, 'files': len(files)}, 'scenarios': [],
               'fixture_only': True, 'before_recording': 'NOT RUN', 'failures': []}
    recording = False
    try:
        browser('open', origin)
        browser('wait', '#login-user')
        browser('record', 'start', EVIDENCE / 'after.webm')
        recording = True
        for width, height in [(390, 844), (1440, 900)]:
            browser('set', 'viewport', width, height)
            for theme in ('light', 'dark'):
                browser('set', 'media', theme)
                for page in ('/', '/etiqueta/'):
                    browser('open', origin + page)
                    browser('wait', '#login-user')
                    for role, route, name in [('OWNER', 'venta', 'Dueña de muestra'), ('MANAGER', 'venta', 'Gerente de muestra'),
                                               ('SELLER', 'comisiones', 'Vendedora de muestra'), ('INVENTORY', 'recepcion', 'Bodega de muestra')]:
                        browser('select', '#demo-role', role)
                        browser('wait', '--fn', f"location.hash === '#/{route}' && document.querySelector('#operator-label')?.textContent.includes('{name}')")
                        browser('wait', '--load', 'networkidle')
                        state = evaluate("""(() => {
                          const banner = document.querySelector('#demo-banner');
                          const r = banner.getBoundingClientRect();
                          return {width: innerWidth, scrollWidth: document.documentElement.scrollWidth,
                            bannerVisible: r.top === 0 && r.right <= innerWidth && r.height > 0,
                            token: !!sessionStorage.getItem('savia.token'), title: document.title,
                            alerts: [...document.querySelectorAll('[role=alert]')].filter(x => x.offsetHeight && x.textContent).map(x => x.textContent)};
                        })()""")
                        assert state['width'] == state['scrollWidth'] and state['bannerVisible'] and state['token']
                        assert not state['alerts'], state
                        if role == 'OWNER' and page == '/':
                            browser('screenshot', EVIDENCE / f'home-{width}-{theme}.png')
                        if page == '/etiqueta/':
                            browser('open', origin + page)
                            browser('wait', '--load', 'networkidle')
                            assert evaluate("document.querySelector('#demo-banner').getBoundingClientRect().top === 0 && document.documentElement.scrollWidth === innerWidth && !document.querySelector('#login-user')")
                            if role == 'OWNER':
                                browser('screenshot', EVIDENCE / f'etiqueta-{width}-{theme}.png')
                        browser('click', '#demo-banner button')
                        browser('wait', '#login-user')
                        assert evaluate("!sessionStorage.getItem('savia.token') && !localStorage.getItem('shell.fixture.user')")
                        results['scenarios'].append({'viewport': [width, height], 'theme': theme, 'page': page,
                                                     'role': role, 'login_home_reset': True, **state})
        results['bridge'] = evaluate("""(async () => {
          const a = await fetch('/api/v1/shell-probe?q=1', {method:'POST',headers:{'X-Test':'yes'},body:'{"a":1}'});
          const json = await a.json();
          const form = new FormData(); form.append('tag','demo');
          const f = await (await fetch('/api/v1/shell-probe', {method:'POST',body:form})).json();
          const r = await (await fetch(new Request(location.origin+'/api/v1/shell-probe?q=2', {method:'POST',headers:{'X-Test':'request'},body:'request'}))).json();
          const empty = await fetch('/api/v1/auth/logout',{method:'POST'});
          return {json:json.path === '/shell-probe?q=1' && json.headers['x-test'] === 'yes' && json.body === '{"a":1}',
            form:f.body.tag === 'demo', request:r.body === 'request' && r.headers['x-test'] === 'request',
            empty:empty.status === 204 && await empty.text() === '', passThrough:(await fetch('/app.css')).ok};
        })()""")
        assert all(results['bridge'].values())
        results['errors'] = browser('errors')['errors']
        results['console_errors'] = [m for m in browser('console')['messages'] if m.get('type') == 'error']
        requests = browser('network', 'requests')['requests']
        urls = sorted({r['url'] for r in requests})
        results['network'] = {'requests': len(requests), 'urls': urls,
                              'external': [u for u in urls if urlparse(u).scheme in ('http', 'https') and not u.startswith(origin + '/')],
                              'api_http': [u for u in urls if '/api/v1' in u]}
        assert not results['errors'] and not results['console_errors']
        assert not results['network']['external'] and not results['network']['api_http']
        results['pass'] = True
    except Exception as error:
        results['pass'] = False
        results['failures'].append(str(error))
        raise
    finally:
        if recording:
            browser('record', 'stop')
        browser('close')
        server.shutdown()
        server.server_close()
        results['server_stopped'] = True
        (EVIDENCE / 'verification.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
        print(json.dumps({'pass': results.get('pass'), 'scenarios': len(results['scenarios']), 'failures': results['failures']}))


if __name__ == '__main__':
    main()
