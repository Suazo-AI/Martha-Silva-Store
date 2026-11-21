"""Storefront gap audit driver. agent-browser, local static server, no product edits."""
import json, shutil, subprocess, sys, time
from pathlib import Path

AB = shutil.which('agent-browser')
BASE = 'http://127.0.0.1:18420'
OUT = Path(__file__).parent
SHOTS = OUT / 'shots'; SHOTS.mkdir(exist_ok=True)
S = ['--session', 'sf']
results = {'pages': [], 'flows': []}


def ab(*args, timeout=60):
    p = subprocess.run([AB, *S, *args], capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=timeout)
    return (p.stdout + p.stderr).strip()


def ev(js):
    import base64
    out = ab('eval', '-b', base64.b64encode(js.encode('utf-8')).decode())
    try:
        v = json.loads(out)
        return json.loads(v) if isinstance(v, str) and v[:1] in '{[' else v
    except Exception:
        return out


AUDIT = r"""(()=>{const d=document,vis=e=>{const r=e.getBoundingClientRect();return r.width>0&&r.height>0&&getComputedStyle(e).visibility!=='hidden'};
const imgs=[...d.images];const ctl=[...d.querySelectorAll('button,a[href],input,select,textarea')].filter(vis);
const name=e=>(e.getAttribute('aria-label')||e.getAttribute('title')||e.innerText||e.value||'').trim()||e.querySelector('img[alt]:not([alt=""])')||(e.id&&d.querySelector('label[for="'+e.id+'"]'))||e.closest('label')||e.getAttribute('aria-labelledby');
const small=ctl.filter(e=>{const r=e.getBoundingClientRect();return (r.width<24||r.height<24)&&!['INPUT'].includes(e.tagName)});
const txt=d.body.innerText;const es=['Agregar a la bolsa','Elegí','Talla','Comprar','Envío','Colección','Bolsa','Pedido','Continuar','Pago de prueba','Resumen'];
return JSON.stringify({title:d.title,lang:d.documentElement.lang,h1:d.querySelectorAll('h1').length,
overflowX:d.documentElement.scrollWidth>innerWidth+1,scrollWidth:d.documentElement.scrollWidth,innerWidth,
images:imgs.length,broken:imgs.filter(i=>i.complete&&i.currentSrc&&i.naturalWidth===0).map(i=>i.currentSrc).slice(0,5),
noAlt:imgs.filter(i=>!i.hasAttribute('alt')).length,unnamed:ctl.filter(e=>!name(e)).map(e=>e.outerHTML.slice(0,90)).slice(0,5),unnamedCount:ctl.filter(e=>!name(e)).length,
smallTargets:small.length,smallSample:small.slice(0,4).map(e=>e.outerHTML.slice(0,80)),
spanishInEn:es.filter(w=>txt.includes(w)),skip:!!d.querySelector('a[href="#main"],a.skip-link,[class*=skip]'),main:!!d.querySelector('main')})})()"""

PAGES = ['/', '/catalogo.html', '/producto-negro.html', '/producto-novias-velo.html', '/bolsa.html', '/checkout.html',
         '/pedido.html', '/ayuda.html', '/admin.html', '/cuenta.html', '/no-existe.html']


def audit(path, width, lang=None):
    url = BASE + path + (('?' if '?' not in path else '&') + 'lang=' + lang if lang else '')
    ab('console', '--clear'); ab('errors', '--clear')
    ab('set', 'viewport', str(width), '900' if width > 500 else '844')
    ab('open', url)
    time.sleep(1.2)
    ev('(async()=>{for(let y=0;y<document.body.scrollHeight;y+=600){scrollTo(0,y);await new Promise(r=>setTimeout(r,60))}scrollTo(0,0);return 1})()')
    time.sleep(0.8)
    a = ev(AUDIT)
    status = ev(f'fetch({json.dumps(url)},{{method:"HEAD"}}).then(r=>r.status)')
    name = (path.strip('/').replace('.html', '') or 'home').replace('/', '_') + f'-{width}' + (f'-{lang}' if lang else '')
    ab('screenshot', str(SHOTS / f'{name}.png'))
    rec = {'path': path, 'width': width, 'lang': lang or 'es', 'http': status, 'audit': a,
           'console': ab('console'), 'errors': ab('errors'), 'shot': f'shots/{name}.png'}
    results['pages'].append(rec)
    print(name, status, json.dumps(a, ensure_ascii=False)[:300] if isinstance(a, dict) else a, flush=True)


def flow(width, lang=None):
    steps = []
    def step(label, js, wait=1.0):
        r = ev(js); time.sleep(wait); steps.append({'step': label, 'result': r}); print(' ', width, label, str(r)[:200], flush=True)
    ab('set', 'viewport', str(width), '900' if width > 500 else '844')
    ab('open', BASE + '/?lang=' + (lang or 'es'))
    time.sleep(1)
    ev('localStorage.clear();sessionStorage.clear();1')
    ab('console', '--clear'); ab('errors', '--clear')
    ab('open', BASE + '/catalogo.html' + ('?lang=en' if lang else ''))
    time.sleep(1.2)
    step('catalog cards', 'document.querySelectorAll("[data-catalog-grid] .plp-card").length')
    step('open product', 'location.href="/producto-negro.html'+('?lang=en' if lang else '')+'";1', 1.8)
    step('select size', '(()=>{const i=[...document.querySelectorAll("[data-product-form] input[name=variant]")].find(i=>!i.disabled);if(!i)return "no enabled size";i.click();return i.value})()', 0.5)
    step('add to bag', '(()=>{const b=document.querySelector("[data-product-form] [data-add]");if(!b)return "no add button";b.click();return b.innerText.trim()})()', 1.5)
    step('mini bag lines', '(()=>{const l=document.querySelector("[data-mini-bag-lines]");const dlg=l&&l.closest("dialog");return JSON.stringify({open:!!(dlg&&dlg.open),text:(l?l.innerText:"").slice(0,120),total:(document.querySelector("[data-mini-bag-total]")||{}).innerText})})()')
    ab('screenshot', str(SHOTS / f'flow-minibag-{width}{"-en" if lang else ""}.png'))
    step('go bag', 'location.href="/bolsa.html";1', 1.6)
    step('bag summary', '(document.querySelector("[data-cart-summary]")||{innerText:"none"}).innerText.slice(0,160)')
    step('go checkout', 'location.href="/checkout.html";1', 1.6)
    fill = lambda fields: '(()=>{const f=document.querySelector("[data-checkout-form]");if(!f)return "no form";' + ''.join(
        f'f.elements[{json.dumps(k)}].value={json.dumps(v)};' for k, v in fields.items()) + 'f.requestSubmit();return f.dataset.checkoutForm})()'
    step('submit empty contact', '(()=>{const f=document.querySelector("[data-checkout-form]");f.requestSubmit();return [...f.querySelectorAll("[aria-invalid=true]")].length+" invalid; error="+(f.querySelector("[data-error]")||{}).textContent})()', 0.6)
    step('contact', fill({'name': 'Ana Ficticia', 'email': 'ana@example.test', 'phone': '+505 8888 0000'}), 1.0)
    step('delivery', fill({'line1': 'Calle de prueba 1', 'city': 'Managua', 'department': 'Managua', 'coupon': 'PRUEBA10'}), 1.5)
    step('review text', '(document.querySelector("[data-checkout-root]")||{}).innerText.slice(0,240)')
    ab('screenshot', str(SHOTS / f'flow-review-{width}{"-en" if lang else ""}.png'))
    step('create order', '(()=>{const b=document.querySelector("[data-create-order]");if(!b)return "no create button";b.click();return 1})()', 1.8)
    step('payment step', '(document.querySelector("[data-checkout-root]")||{}).innerText.slice(0,200)')
    step('approve test payment', '(()=>{const b=document.querySelector("[data-test-payment=approved]");if(!b)return "no payment button";b.click();return 1})()', 2.2)
    step('order page', 'JSON.stringify({url:location.pathname+location.search,text:(document.querySelector("main")||{}).innerText.slice(0,240)})')
    ab('screenshot', str(SHOTS / f'flow-order-{width}{"-en" if lang else ""}.png'))
    results['flows'].append({'width': width, 'lang': lang or 'es', 'steps': steps, 'console': ab('console'), 'errors': ab('errors')})


if __name__ == '__main__':
    for w in (390, 1440):
        for p in PAGES:
            audit(p, w)
        for p in ('/', '/catalogo.html', '/producto-negro.html', '/checkout.html'):
            audit(p, w, 'en')
    for w in (390, 1440):
        flow(w)
    flow(390, 'en')
    (OUT / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=1), encoding='utf-8')
    print('DONE')
