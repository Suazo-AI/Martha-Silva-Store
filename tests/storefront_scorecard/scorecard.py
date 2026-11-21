"""Storefront scorecard: one compact JSON per run for the finish loop.

Judge-owned and frozen by MANIFEST.sha256; builders run it and never change it.
Usage: python tests/storefront_scorecard/scorecard.py --out <file.json> [--port N] [--skip-stages] [--skip-vitals]
It builds a scratch dist with prepare.py, serves it with the /* headers from _headers
(missing paths get 404.html with status 404 when it exists, like Cloudflare's "404-page"),
and drives a real Chrome through agent-browser. Local and unthrottled: vitals are a relative ratchet only.
"""
import argparse, base64, functools, hashlib, http.server, json, re, shutil, statistics, subprocess, sys, tempfile, threading, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
AB = shutil.which('agent-browser')
PRICE_OK = re.compile(r'^[−-]?\$\d{1,3}(,\d{3})*\.\d{2}$')
PRICE_TOKEN = re.compile(r'[−-]?(?:US\$|USD\s?|C\$|\$)\s?\d[\d,]*(?:\.\d+)?')
SRC_JS = ('app.js', 'demo-api.js', 'integration-adapters.js')
EN_RE = (r"/[áéíóúñ¿¡]|\b(de|la|el|los|las|para|con|tu|tus|ver|buscar|comprar|talla|bolsa|pedido|ayuda|cerrar|agregar|"
         r"guardar|novias|vestidos|nuestra|entrega|prueba|tienda|categorías)\b/i")

PROBE = r"""(()=>{const d=document,vis=e=>{const r=e.getBoundingClientRect();return r.width>0&&r.height>0&&getComputedStyle(e).visibility!=='hidden'};
const re=%s,es=new Set();
if(d.documentElement.lang==='en'){const w=d.createTreeWalker(d.body,NodeFilter.SHOW_TEXT);let n;
while(n=w.nextNode()){const t=n.textContent.trim(),p=n.parentElement;if(!t||t.length<2||!p||p.closest('[translate=no],script,style,[aria-hidden=true]'))continue;if(!vis(p))continue;if(re.test(t))es.add('T:'+t.slice(0,50))}
d.querySelectorAll('[placeholder],[aria-label],img[alt],[title]').forEach(e=>{if(e.closest('[translate=no]'))return;['placeholder','aria-label','alt','title'].forEach(a=>{const v=e.getAttribute(a);if(v&&re.test(v))es.add(a+':'+v.slice(0,50))})})}
const tokens=(d.body.innerText.match(%s)||[]).map(s=>s.replace(/\s+/g,' ').trim());
const ctl=[...d.querySelectorAll('button,a[href],input:not([type=hidden]),select,textarea,summary')].filter(vis);
const small=ctl.filter(e=>{const r=e.getBoundingClientRect();return r.width<24||r.height<24}).map(e=>e.outerHTML.slice(0,70));
const imgs=[...d.images];
return JSON.stringify({path:location.pathname,lang:d.documentElement.lang,title:d.title,h1:d.querySelectorAll('h1').length,
overflowX:d.documentElement.scrollWidth>innerWidth+1,broken:imgs.filter(i=>i.complete&&i.currentSrc&&i.naturalWidth===0).length,
small:small.length,smallSample:small.slice(0,3),es:[...es].slice(0,20),tokens,
anims:d.getAnimations().filter(a=>a.playState==='running').length,
gsapChildren:window.gsap?gsap.globalTimeline.getChildren(true,true,true).length:null})})()""" % (EN_RE, PRICE_TOKEN.pattern.replace('/', r'\/').join(['/', '/g']))

RES = r"""(()=>{const g={js:0,css:0,font:0,img:0,other:0},n=performance.getEntriesByType('resource');
for(const r of n){const u=r.name.split('?')[0],b=r.encodedBodySize||r.transferSize||0;
const k=/\.m?js$/.test(u)?'js':/\.css$/.test(u)?'css':/\.(woff2?|ttf|otf)$/.test(u)?'font':/\.(webp|avif|jpe?g|png|gif|svg)$/.test(u)||r.initiatorType==='img'?'img':'other';g[k]+=b}
const nav=performance.getEntriesByType('navigation')[0];g.html=nav?nav.encodedBodySize:0;g.requests=n.length+1;return JSON.stringify(g)})()"""

STATIC_INTRO = r"""JSON.stringify([...document.querySelectorAll('[data-intro]')].filter(e=>+getComputedStyle(e).opacity<0.99).length)"""


class Server:
    def __init__(self, root, port):
        headers, block = [], None
        for line in (root / '_headers').read_text(encoding='utf-8').splitlines():
            if not line.strip() or line.startswith('#'):
                continue
            if not line[0].isspace():
                block = line.strip()
            elif block == '/*' and ':' in line:
                k, v = line.strip().split(':', 1)
                headers.append((k.strip(), v.strip()))
        page404 = root / '404.html'

        class H(http.server.SimpleHTTPRequestHandler):
            def end_headers(self):
                for k, v in headers:
                    self.send_header(k, v)
                super().end_headers()

            def send_error(self, code, message=None, explain=None):
                if code == 404 and page404.is_file():
                    body = page404.read_bytes()
                    self.send_response(404)
                    self.send_header('Content-Type', 'text/html; charset=utf-8')
                    self.send_header('Content-Length', str(len(body)))
                    self.end_headers()
                    if self.command != 'HEAD':
                        self.wfile.write(body)
                    return
                super().send_error(code, message, explain)

            def log_message(self, *a):
                pass

        self.httpd = http.server.ThreadingHTTPServer(('127.0.0.1', port), functools.partial(H, directory=str(root)))
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()

    def close(self):
        self.httpd.shutdown()


class Browser:
    def __init__(self, session):
        self.s = ['--session', session]

    def ab(self, *args, timeout=90):
        # Output goes to a file, not a pipe: the agent-browser daemon inherits the handles and would keep a pipe open forever.
        with tempfile.TemporaryFile() as f:
            try:
                subprocess.run([AB, *self.s, *args], stdin=subprocess.DEVNULL, stdout=f, stderr=subprocess.STDOUT, timeout=timeout)
            except subprocess.TimeoutExpired:
                return f'TIMEOUT {args[0]}'
            f.seek(0)
            return f.read().decode('utf-8', 'replace').strip()

    def click(self, sel):
        self.ev(f'document.querySelector({json.dumps(sel)})?.scrollIntoView({{block:"center"}});1')
        return self.ab('click', sel)

    def ev(self, js):
        out = self.ab('eval', '-b', base64.b64encode(js.encode('utf-8')).decode())
        try:
            v = json.loads(out)
            return json.loads(v) if isinstance(v, str) and v[:1] in '{[' else v
        except Exception:
            return out


def offline(repo, dist):
    """Byte parity, CRLF and static price tokens on the scratch dist."""
    static = repo / 'build-inputs/static'
    want = {p.relative_to(static).as_posix(): p for p in static.rglob('*') if p.is_file()}
    for name in SRC_JS:
        want[name] = repo / 'src' / name
    have = {p.relative_to(dist).as_posix(): p for p in dist.rglob('*') if p.is_file()}
    diff = sorted(k for k in want.keys() | have.keys() if k not in want or k not in have or want[k].read_bytes() != have[k].read_bytes())
    crlf = sorted(p.name for p in dist.glob('*') if p.suffix in ('.html', '.js', '.css') and b'\r\n' in p.read_bytes())
    bad, total, pages = {}, 0, sorted(p for p in dist.glob('*.html'))
    for page in pages:
        text = re.sub(r'(?is)<(script|style)\b.*?</\1>', ' ', page.read_text(encoding='utf-8'))
        for tok in PRICE_TOKEN.findall(re.sub(r'<[^>]+>', ' ', text).replace('&nbsp;', ' ')):
            total += 1
            if not PRICE_OK.match(tok.replace(' ', '')):
                bad[tok] = bad.get(tok, 0) + 1
    budget = {}
    for name in ('index.html', 'catalogo.html', 'producto-negro.html'):
        html = (dist / name).read_text(encoding='utf-8')
        js = re.findall(r'<script[^>]*\bsrc="/?([^"?]+)', html)
        css = re.findall(r'<link[^>]*rel="stylesheet"[^>]*href="/?([^"?]+)', html)
        size = lambda refs: sum((dist / r).stat().st_size for r in refs if (dist / r).is_file())
        budget[name] = {'html': len(html.encode('utf-8')), 'js': size(js), 'jsFiles': len(js), 'css': size(css), 'cssFiles': len(css)}
    return {'pages': len(pages), 'budget': budget, 'publicFiles': len(have), 'parityDiff': len(diff), 'paritySample': diff[:5], 'crlf': crlf,
            'staticPriceTokens': total, 'staticPriceBad': sum(bad.values()), 'staticPriceBadSample': sorted(bad.items(), key=lambda x: -x[1])[:5]}


def stages(repo):
    node, py = shutil.which('node'), sys.executable
    env_node = {'NODE_PATH': str(repo / 'tests/frontend-deps/node_modules')}
    js_files = sorted(str(p.relative_to(repo)) for pat in ('src/*.js', 'dist/*.js', 'tests/*.cjs', 'tests/*.test.js') for p in repo.glob(pat))
    staff = sorted(str(p.relative_to(repo)) for p in (repo / 'dev/savia-staff-ui').glob('*.test.mjs'))
    plan = [
        ('staff-ui', [[node, '--test', *staff]]),
        ('snapshot-build', [[py, 'tests/build.py']]),
        ('fixture', [[py, '-c', 'import sys,pathlib;sys.path.insert(0,"tests");import check;check.check_fixture(pathlib.Path("."))']]),
        ('headers+release', [[py, 'tests/static_headers.py'], [py, 'tests/test_release_snapshot.py']]),
        ('backend', [[node, '--test', 'tests/backend.cjs']]),
        ('adapters', [[node, '--test', 'tests/integration-adapters.test.js']]),
        ('catalog-migration', [[node, '--test', 'tests/catalog-migration.cjs']]),
        ('original-catalog', [[node, '--test', 'tests/original-catalog.cjs']]),
        ('responsive-images', [[py, 'tests/responsive_images.py']]),
        ('responsive-fonts', [[py, 'tests/responsive_fonts.py']]),
        ('editorial', [[node, '--test', 'tests/luxury-editorial.cjs']]),
        ('asset-audit', [[py, 'tests/asset-audit.py']]),
        ('test-check', [[py, 'tests/test_check.py']]),
        ('sync', [[py, 'tests/test_sync_progress.py']]),
        ('delivery', [[py, 'tests/test_delivery_status.py'], [py, 'tools/delivery_status.py', '--check']]),
        ('catalog-staging', [[py, 'tests/catalog-staging.py']]),
        ('frontend-runtime', [[node, 'tests/frontend-runtime.cjs']]),
        ('localization-runtime', [[node, 'tests/localization-runtime.cjs']]),
        ('structure', [[py, 'tests/structure.py']]),
        ('syntax', [[node, '--check', f] for f in js_files]),
    ]
    import os
    env = {**os.environ, **env_node}
    env.pop('FRONTEND_APP', None)
    env.pop('FRONTEND_API', None)
    out = {}
    for name, cmds in plan:
        code, tail = 0, ''
        for cmd in cmds:
            p = subprocess.run(cmd, cwd=repo, env=env, capture_output=True, text=True, encoding='utf-8', errors='replace')
            if p.returncode:
                code, tail = p.returncode, (p.stdout + p.stderr).strip().splitlines()[-1:]
                break
        out[name] = code if not code else {'exit': code, 'last': tail[0][:160] if tail else ''}
    return out


def console_counts(b):
    log = b.ab('console') + '\n' + b.ab('errors')
    lines = [l for l in log.splitlines() if l.strip()]
    pick = lambda pat: [l[:140] for l in lines if re.search(pat, l, re.I)]
    err, warn = pick(r'\berror\b|refused|violat'), pick(r'\bwarn')
    b.ab('console', '--clear'), b.ab('errors', '--clear')
    return err, warn


def run_flow(b, base, width, lang, axe_on):
    """Real-click journey; probes every state. Returns purchase result plus per-state findings."""
    states, axe = {}, {}
    q = '?lang=en' if lang == 'en' else ''
    b.ab('set', 'viewport', str(width), '844' if width < 500 else '900')
    b.ab('open', base + '/' + q)
    time.sleep(1)
    b.ev('localStorage.clear();sessionStorage.clear();' + ('localStorage.setItem("martha-language-v1","en");' if lang == 'en' else '') + '1')
    b.ab('console', '--clear'), b.ab('errors', '--clear')
    errs, warns = [], []

    def probe(label, do_axe=False, wait=0.0):
        print(f'{width}{lang} {label}', file=sys.stderr, flush=True)
        time.sleep(wait)
        states[label] = b.ev(PROBE)
        if do_axe and axe_on:
            try:
                r = json.loads(b.ab('a11y', '--json', timeout=180))['data']
                axe[label] = [(v['id'], v['impact'], v['nodeCount']) for v in r['violations']]
            except Exception as e:
                axe[label] = [('axe-run-failed', 'n/a', str(e)[:60])]
        e, w = console_counts(b)
        errs.extend(f'{label}: {x}' for x in e)
        warns.extend(f'{label}: {x}' for x in w)

    def page(path, label, do_axe=True):
        b.ab('open', base + path + (('&' if '?' in path else '?') + 'lang=en' if lang == 'en' else ''))
        time.sleep(1.5)
        b.ev('(async()=>{for(let y=0;y<document.body.scrollHeight;y+=700){scrollTo(0,y);await new Promise(r=>setTimeout(r,40))}scrollTo(0,0);return 1})()')
        probe(label, do_axe, 0.6)

    for path, label in (('/', 'home'), ('/catalogo.html', 'catalog'), ('/producto-negro.html', 'product'),
                        ('/producto-novias-velo.html', 'product-bridal'), ('/ayuda.html', 'help'), ('/admin.html', 'admin'),
                        ('/no-existe-xyz.html', '404')):
        page(path, label)
    states['404']['status'] = b.ev(f'fetch({json.dumps(base + "/no-existe-xyz.html")}).then(r=>r.status)')
    if width < 1024:
        b.ab('open', base + '/' + q); time.sleep(1.2)
        b.click('[data-menu-toggle]'); probe('menu', False, 0.7); b.ab('press', 'Escape')
    b.ab('open', base + '/catalogo.html' + q); time.sleep(1.4)
    b.click('[data-filters-open]'); probe('filter-dialog', False, 0.7)
    size_l = b.ev('JSON.stringify((()=>{const o=document.querySelector("select[name=size] option[value=L]");return o?{disabled:o.disabled,label:o.textContent.trim()}:null})())')
    if isinstance(size_l, dict) and not size_l.get('disabled'):
        b.ab('select', 'select[name=size]', 'L'); time.sleep(0.3)
        b.click('[data-filters-apply]'); time.sleep(1.2)
        size_l['results'] = b.ev('document.querySelectorAll("[data-catalog-grid] .plp-card, [data-catalog-grid] [data-product-card]").length')
        b.ab('open', base + '/catalogo.html' + q); time.sleep(1.4)
    else:
        b.ab('press', 'Escape'); time.sleep(0.3)
    b.click('[data-sort-toggle]'); probe('sort-open', False, 0.5); b.ab('press', 'Escape')
    b.click('[data-catalog-grid] [data-quick]'); probe('quick-add', False, 0.7); b.ab('press', 'Escape')
    b.ab('open', base + '/producto-negro.html' + q); time.sleep(1.5)
    b.click('button.gallery-photo[data-gallery-index="0"]'); probe('zoom', False, 0.8); b.ab('press', 'Escape'); time.sleep(0.3)
    b.click('[data-size-guide]'); probe('size-guide', False, 0.8); b.ab('press', 'Escape'); time.sleep(0.3)
    b.click('[data-product-form] [data-add]'); probe('add-no-size', False, 0.6)
    b.click('[data-product-form] label.size-option:not(.sold-out)'); b.click('[data-product-form] [data-add]')
    probe('mini-bag', False, 1.3)
    page('/bolsa.html', 'bag')
    b.ab('open', base + '/checkout.html' + q); time.sleep(1.5)
    b.click('[data-checkout-form] button.button'); probe('contact-errors', True, 0.6)
    for k, v in {'name': 'Ana Ficticia', 'email': 'ana@example.test', 'phone': '+505 8888 0000'}.items():
        b.ab('fill', f'[data-checkout-form] [name="{k}"]', v)
    b.click('[data-checkout-form] button.button'); probe('delivery', True, 1.2)
    for k, v in {'line1': 'Calle de prueba 1', 'city': 'Managua', 'department': 'Managua', 'coupon': 'PRUEBA10'}.items():
        b.ab('fill', f'[data-checkout-form] [name="{k}"]', v)
    b.click('[data-checkout-form] button.button'); probe('review', True, 1.4)
    total = b.ev('(document.querySelector("[data-checkout-root]")||document.body).innerText.match(/(?:Total)[^\\n]*\\n?[^\\n]*/i)?.[0]||""')
    b.click('[data-create-order]'); probe('payment', True, 1.8)
    b.click('[data-test-payment="approved"]'); time.sleep(2.2)
    probe('order', True, 0.3)
    order = b.ev('JSON.stringify({path:location.pathname,demo:/DEMO-\\d+/.test(document.body.innerText)})')
    ok = isinstance(order, dict) and order.get('path', '').endswith('pedido.html') and order.get('demo')
    return {'purchase': bool(ok), 'reviewTotal': total, 'sizeL': size_l, 'states': states, 'axe': axe, 'errors': errs, 'warnings': warns}


def perf(b, base):
    out = {}
    b.ab('set', 'viewport', '390', '844')
    for path in ('/', '/catalogo.html', '/producto-negro.html'):
        b.ab('open', base + path); time.sleep(2)
        out[path] = {'requests': (b.ev(RES) or {}).get('requests') if isinstance(b.ev(RES), dict) else None}
    b.ab('set', 'media', 'light', 'reduced-motion')
    for path in ('/', '/catalogo.html', '/producto-negro.html'):
        b.ab('open', base + path); time.sleep(1.5)
        out[path]['reducedMotionHidden'] = b.ev(STATIC_INTRO)
        out[path]['reducedMotionAnims'] = b.ev('document.getAnimations().filter(a=>a.playState==="running").length')
    b.ab('set', 'media', 'light')
    return out


def vitals(b, base, runs=3):
    out = {}
    b.ab('set', 'viewport', '390', '844')
    for path in ('/', '/catalogo.html', '/producto-negro.html'):
        vals = {'lcp': [], 'cls': [], 'fcp': [], 'ttfb': []}
        for _ in range(runs):
            b.ev('localStorage.clear();sessionStorage.clear();1')
            try:
                d = json.loads(b.ab('vitals', base + path, '--json', timeout=120))
                d = d.get('data', d)
                for k in vals:
                    v = d.get(k)
                    if isinstance(v, dict):
                        v = v.get('startTime', v.get('score'))
                    if v is not None:
                        vals[k].append(float(v))
            except Exception:
                pass
        out[path] = {k: round(statistics.median(v), 3) if v else None for k, v in vals.items()}
    return out


def summarize(flows):
    s = {'purchase': {}, 'axeByImpact': {}, 'axeIds': {}, 'enSpanish': 0, 'enSample': [], 'priceBad': 0, 'priceSample': [],
         'overflow': [], 'broken': 0, 'h1Bad': [], 'small390': 0, 'consoleErrors': 0, 'consoleWarnings': 0, 'consoleSample': []}
    for key, f in flows.items():
        s['purchase'][key] = f['purchase']
        for label, v in f['axe'].items():
            for vid, imp, n in v:
                s['axeByImpact'][imp] = s['axeByImpact'].get(imp, 0) + 1
                s['axeIds'][vid] = s['axeIds'].get(vid, 0) + 1
        for label, st in f['states'].items():
            if not isinstance(st, dict):
                continue
            if key.endswith('en'):
                s['enSpanish'] += len(st['es'])
                s['enSample'] += [f'{key} {label} {x}' for x in st['es']][:3]
            bad = [t for t in st['tokens'] if not PRICE_OK.match(t.replace(' ', ''))]
            s['priceBad'] += len(bad)
            s['priceSample'] += [f'{key} {label} {t}' for t in bad[:2]]
            if st['overflowX']:
                s['overflow'].append(f'{key} {label}')
            s['broken'] += st['broken']
            if st['h1'] != 1 and label not in ('menu', 'filter-dialog', 'sort-open', 'quick-add', 'zoom', 'size-guide', 'add-no-size', 'mini-bag'):
                s['h1Bad'].append(f'{key} {label}:{st["h1"]}')
            if key.startswith('390'):
                s['small390'] += st['small']
        s['consoleErrors'] += len(f['errors'])
        s['consoleWarnings'] += len(f['warnings'])
        s['consoleSample'] += (f['errors'] + f['warnings'])[:3]
    for k in ('enSample', 'priceSample', 'consoleSample'):
        s[k] = sorted(set(s[k]))[:8]
    return s


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    ap.add_argument('--port', type=int, default=18431)
    ap.add_argument('--repo', default=str(ROOT))
    ap.add_argument('--skip-stages', action='store_true')
    ap.add_argument('--skip-vitals', action='store_true')
    ap.add_argument('--no-axe', action='store_true')
    a = ap.parse_args()
    repo = Path(a.repo).resolve()
    tmp = Path(tempfile.mkdtemp(prefix='scorecard-'))
    dist = tmp / 'dist'
    subprocess.run([sys.executable, '-B', 'prepare.py', '--output', str(dist)], cwd=repo, check=True, capture_output=True)
    result = {'repo': str(repo), 'head': subprocess.run(['git', 'rev-parse', '--short', 'HEAD'], cwd=repo, capture_output=True, text=True).stdout.strip(),
              'offline': offline(repo, dist)}
    srv = Server(dist, a.port)
    base = f'http://127.0.0.1:{a.port}'
    b = Browser(f'score{a.port}')
    try:
        b.ab('set', 'media', 'light')
        flows = {}
        for width in (390, 1440):
            for lang in ('es', 'en'):
                flows[f'{width}{lang}'] = run_flow(b, base, width, lang, not a.no_axe)
        result['summary'] = summarize(flows)
        result['sizeL'] = {k: f['sizeL'] for k, f in flows.items()}
        result['reviewTotal'] = {k: f['reviewTotal'] for k, f in flows.items()}
        result['status404'] = {k: f['states'].get('404', {}).get('status') if isinstance(f['states'].get('404'), dict) else None for k, f in flows.items()}
        result['perf'] = perf(b, base)
        if not a.skip_vitals:
            result['vitals'] = vitals(b, base)
    finally:
        b.ab('close')
        srv.close()
    if not a.skip_stages:
        result['stages'] = stages(repo)
    full = Path(a.out)
    full.write_text(json.dumps({**result, 'flows': flows}, ensure_ascii=False, indent=1), encoding='utf-8')
    shutil.rmtree(tmp, ignore_errors=True)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
