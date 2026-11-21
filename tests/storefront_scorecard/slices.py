"""Track B slice checks for the finish loop. Judge-owned and frozen by MANIFEST.sha256.

Usage: python -X utf8 tests/storefront_scorecard/slices.py --out <file.json> [--port N] [--repo PATH] [--only grid,footer,title]
Reuses the scorecard server and browser. Each check returns {"pass": bool, ...evidence}.
"""
import argparse, json, re, subprocess, sys, tempfile, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from scorecard import Server, Browser, ROOT  # noqa: E402

COLS = "getComputedStyle(document.querySelector('[data-catalog-grid]')).gridTemplateColumns.split(' ').filter(Boolean).length"
MOVED = ("[...document.querySelectorAll('[data-catalog-grid] .plp-card')].slice(0,12)"
         ".filter(c=>{const t=getComputedStyle(c).transform;return t&&t!=='none'&&t!=='matrix(1, 0, 0, 1, 0, 0)'}).length")


def fresh(b, base, width, lang='es', reduced=False):
    b.ab('set', 'viewport', str(width), '844' if width < 500 else '900')
    b.ab('set', 'media', 'light', *(['reduced-motion'] if reduced else []))
    b.ab('open', base + '/ayuda.html'); time.sleep(0.8)
    b.ev('localStorage.clear();sessionStorage.clear();' + ('localStorage.setItem("martha-language-v1","en");' if lang == 'en' else '') + '1')


def grid(b, base):
    out = {}
    for width, key, pick in ((1440, 'cd', '2'), (390, 'cm', '1')):
        fresh(b, base, width)
        b.ab('open', base + '/catalogo.html'); time.sleep(1.5)
        before = b.ev(COLS)
        sel = f'[data-cols-key="{key}"][data-cols="{pick}"]'
        b.click(sel); time.sleep(0.12)
        moving = b.ev(MOVED)
        time.sleep(0.8)
        after = b.ev(COLS)
        stored = b.ev('localStorage.getItem("martha-grid-v1")')
        b.ab('open', base + '/catalogo.html'); time.sleep(1.5)
        reload_cols = b.ev(COLS)
        pressed = b.ev(f'document.querySelector({json.dumps(sel)}).getAttribute("aria-pressed")')
        fresh(b, base, width, reduced=True)
        b.ab('open', base + '/catalogo.html'); time.sleep(1.5)
        other = '4' if key == 'cd' else '2'
        b.click(f'[data-cols-key="{key}"][data-cols="{other}"]'); time.sleep(0.12)
        reduced_moving = b.ev(MOVED)
        overflow = b.ev('document.documentElement.scrollWidth>innerWidth+1')
        ok = (after == int(pick) and reload_cols == int(pick) and pressed == 'true' and isinstance(moving, int) and moving > 0
              and reduced_moving == 0 and stored not in (None, '', 'null') and overflow is False)
        out[str(width)] = {'pass': ok, 'before': before, 'after': after, 'reload': reload_cols, 'pressed': pressed,
                           'movingAt120ms': moving, 'reducedMoving': reduced_moving, 'stored': stored, 'overflowX': overflow}
    return {'pass': all(v['pass'] for v in out.values()), **out}


WORDMARK = r"""JSON.stringify((()=>{const w=document.querySelector('.site-footer .footer-wordmark'),f=document.querySelector('.site-footer');
if(!w||!f)return{missing:true};const cs=getComputedStyle(f),inner=f.clientWidth-parseFloat(cs.paddingLeft)-parseFloat(cs.paddingRight);
const r=document.createRange();r.selectNodeContents(w);const tw=r.getBoundingClientRect().width;
return{ratio:+(tw/inner).toFixed(3),ariaHidden:w.getAttribute('aria-hidden'),text:w.textContent.trim(),font:getComputedStyle(w).fontFamily,
overflowX:document.documentElement.scrollWidth>innerWidth+1}})())"""


def footer(b, base):
    out = {}
    for width in (320, 390, 768, 1024, 1440, 1920):
        fresh(b, base, width)
        b.ab('open', base + '/index.html'); time.sleep(1.2)
        b.ev('window.scrollTo(0,document.documentElement.scrollHeight);1'); time.sleep(1.0)
        m = b.ev(WORDMARK)
        ok = isinstance(m, dict) and not m.get('missing') and 0.98 <= m['ratio'] <= 1.0 and m['ariaHidden'] == 'true' \
            and m['text'].upper() == 'MARTHA SILVA' and 'Cormorant' in m['font'] and m['overflowX'] is False
        out[str(width)] = {'pass': ok, **(m if isinstance(m, dict) else {'raw': m})}
    fresh(b, base, 390, reduced=True)
    b.ab('open', base + '/index.html'); time.sleep(1.2)
    b.ev('window.scrollTo(0,document.documentElement.scrollHeight);1'); time.sleep(0.6)
    rm = b.ev(WORDMARK)
    out['reducedMotion'] = {'pass': isinstance(rm, dict) and not rm.get('missing'), **(rm if isinstance(rm, dict) else {})}
    news = b.ev('!!document.querySelector(".site-footer form[data-newsletter] input[type=email]")')
    out['newsletter'] = {'pass': news is True}
    for width in (390, 1440):  # every footer control must be clickable at some scroll position (P4 judge note)
        fresh(b, base, width)
        b.ab('open', base + '/index.html'); time.sleep(1.2)
        b.ev('window.__reach=new Set();1')
        total = b.ev('[...document.querySelectorAll(".site-footer a[href], .site-footer input, .site-footer button")].filter(e=>e.getClientRects().length).length')
        for back in range(0, 2600, 120):
            b.ev(f'window.scrollTo(0,document.documentElement.scrollHeight-innerHeight-{back});1'); time.sleep(0.2)
            b.ev(REACH)
        missed = b.ev('JSON.stringify([...document.querySelectorAll(".site-footer a[href], .site-footer input, .site-footer button")]'
                      '.map((e,i)=>window.__reach.has(i)||!e.getClientRects().length?null:(e.textContent||e.name||e.type).trim().slice(0,20)).filter(x=>x!==null))')
        missed = json.loads(missed) if isinstance(missed, str) else missed
        out[f'reach{width}'] = {'pass': isinstance(total, int) and total > 0 and missed == [], 'controls': total, 'missed': missed}
    return {'pass': all(v['pass'] for v in out.values()), **out}


REACH = ("[...document.querySelectorAll('.site-footer a[href], .site-footer input, .site-footer button')].forEach((e,i)=>{"
         "const r=e.getBoundingClientRect();if(r.width<1||r.bottom<=0||r.top>=innerHeight)return;"
         "const h=document.elementFromPoint(r.left+Math.min(5,r.width/2),r.top+r.height/2);if(h&&(h===e||e.contains(h)))window.__reach.add(i)});1")


def set_hidden(b, hidden):
    state = 'hidden' if hidden else 'visible'
    b.ev(f'Object.defineProperty(document,"visibilityState",{{value:"{state}",configurable:true}});'
         f'Object.defineProperty(document,"hidden",{{value:{str(hidden).lower()},configurable:true}});'
         'document.dispatchEvent(new Event("visibilitychange"));1')
    time.sleep(0.2)


def title(b, base):
    expect = {('es', False): 'Vuelve pronto · MARTHA SILVA', ('es', True): 'Tu bolsa te espera · MARTHA SILVA',
              ('en', False): 'Come back soon · MARTHA SILVA', ('en', True): 'Your bag is waiting · MARTHA SILVA'}
    out = {}
    for lang in ('es', 'en'):
        q = '?lang=en' if lang == 'en' else ''
        fresh(b, base, 1440, lang)
        b.ab('open', base + '/catalogo.html' + q); time.sleep(1.5)
        original = b.ev('document.title')
        set_hidden(b, True); away = b.ev('document.title')
        set_hidden(b, False); back = b.ev('document.title')
        b.ab('open', base + '/producto-negro.html' + q); time.sleep(1.5)
        b.click('[data-product-form] label.size-option:not(.sold-out)'); b.click('[data-product-form] [data-add]'); time.sleep(1.2)
        b.ab('press', 'Escape')
        page_title = b.ev('document.title')
        set_hidden(b, True); away_bag = b.ev('document.title')
        set_hidden(b, False); back_bag = b.ev('document.title')
        b.ab('open', base + '/catalogo.html' + q); time.sleep(1.5)
        nav_title = b.ev('document.title')
        set_hidden(b, True); set_hidden(b, False)
        nav_back = b.ev('document.title')
        ok = (away == expect[(lang, False)] and back == original and away_bag == expect[(lang, True)]
              and back_bag == page_title and nav_back == nav_title)
        out[lang] = {'pass': ok, 'original': original, 'away': away, 'back': back, 'awayBag': away_bag,
                     'backBag': back_bag, 'pageTitle': page_title, 'navBack': nav_back}
    return {'pass': all(v['pass'] for v in out.values()), **out}


PILL = r"""JSON.stringify((()=>{const vis=e=>{if(!e.getClientRects().length)return false;const s=getComputedStyle(e);return s.visibility!=='hidden'&&+s.opacity>0};
const t=[...document.querySelectorAll('[data-menu-toggle]')].filter(vis);if(t.length!==1)return{toggles:t.length};
let p=t[0];while(p&&p!==document.body&&getComputedStyle(p).position!=='fixed')p=p.parentElement;if(!p||p===document.body)return{toggles:1,fixed:false};
const r=p.getBoundingClientRect(),b=t[0].getBoundingClientRect(),s=getComputedStyle(p),bg=s.backgroundColor.match(/[\d.]+/g).map(Number);
const lum=c=>{const v=c/255;return v<=.03928?v/12.92:((v+.055)/1.055)**2.4},L=a=>.2126*lum(a[0])+.7152*lum(a[1])+.0722*lum(a[2]);
const fg=getComputedStyle(t[0]).color.match(/[\d.]+/g).map(Number),l1=L(fg),l2=L(bg),contrast=(Math.max(l1,l2)+.05)/(Math.min(l1,l2)+.05);
return{toggles:1,fixed:true,centerOff:Math.round(Math.abs((r.left+r.right)/2-innerWidth/2)),bottomGap:Math.round(innerHeight-r.bottom),
btnW:Math.round(b.width),btnH:Math.round(b.height),bg:s.backgroundColor,alpha:bg.length>3?bg[3]:1,dark:Math.max(...bg.slice(0,3))<=40,
backdrop:(s.backdropFilter||s.webkitBackdropFilter||'none'),contrast:+contrast.toFixed(2),pill:[r.left,r.top,r.right,r.bottom].map(Math.round)}})())"""
HIT = "((a,b)=>a&&b&&a.left<b.right&&b.left<a.right&&a.top<b.bottom&&b.top<a.bottom)"
OBSCURED = r"""JSON.stringify((()=>{const t=[...document.querySelectorAll('[data-menu-toggle]')].find(e=>e.getClientRects().length);let p=t;
while(p&&getComputedStyle(p).position!=='fixed')p=p.parentElement;if(!p)return['no pill'];const hit=%s,bad=[];
const els=[...document.querySelectorAll('a[href],button,input,select,textarea,[tabindex]:not([tabindex="-1"])')].filter(e=>!p.contains(e)&&!e.closest('dialog')&&e.getClientRects().length&&getComputedStyle(e).visibility!=='hidden');
els.forEach(e=>{e.focus({preventScroll:false});if(document.activeElement!==e)return;const r=e.getBoundingClientRect(),q=p.getBoundingClientRect();
if(hit(r,q))bad.push((e.textContent||e.name||e.tagName).trim().slice(0,24))});
document.activeElement.blur();return{checked:els.length,obscured:bad.slice(0,10),count:bad.length}})())""" % HIT


def pill(b, base):
    out = {}
    for width in (390, 1023):
        fresh(b, base, width)
        b.ab('open', base + '/index.html'); time.sleep(1.5)
        m = b.ev(PILL)
        ok = isinstance(m, dict) and m.get('fixed') is True and m['centerOff'] <= 2 and 0 <= m['bottomGap'] <= 48 \
            and m['btnW'] >= 44 and m['btnH'] >= 44 and m['alpha'] == 1 and m['dark'] and m['backdrop'] == 'none' and m['contrast'] >= 4.5
        out[f'closed{width}'] = {'pass': ok, **(m if isinstance(m, dict) else {'raw': m})}
    for width in (1024, 1440):
        fresh(b, base, width)
        b.ab('open', base + '/index.html'); time.sleep(1.2)
        m = b.ev(PILL)
        out[f'none{width}'] = {'pass': isinstance(m, dict) and m.get('toggles') == 0, **(m if isinstance(m, dict) else {})}
    # open, focus inside, Esc closes after the animation, focus returns, aria-expanded follows
    for reduced in (False, True):
        fresh(b, base, 390, reduced=reduced)
        b.ab('open', base + '/catalogo.html'); time.sleep(1.5)
        b.click('[data-menu-toggle]')
        early = b.ev('document.querySelector("#mobile-menu").open'); time.sleep(0.06)
        area_early = b.ev("(()=>{const r=document.querySelector('#mobile-menu').getBoundingClientRect();return Math.round(r.width*r.height)})()"); time.sleep(0.85)
        area_final = b.ev("(()=>{const r=document.querySelector('#mobile-menu').getBoundingClientRect();return Math.round(r.width*r.height)})()")
        opened = b.ev('JSON.stringify({open:document.querySelector("#mobile-menu").open,expanded:[...document.querySelectorAll("[data-menu-toggle]")].find(e=>e.getClientRects().length)?.getAttribute("aria-expanded"),'
                      'focusIn:document.querySelector("#mobile-menu").contains(document.activeElement),links:[...document.querySelectorAll("#mobile-menu a[href]")].filter(a=>a.getBoundingClientRect().height>0).length,'
                      'overflowX:document.documentElement.scrollWidth>innerWidth+1})')
        b.ab('press', 'Escape'); time.sleep(0.06)
        still_open = b.ev('document.querySelector("#mobile-menu").open'); time.sleep(0.85)
        closed = b.ev('JSON.stringify({open:document.querySelector("#mobile-menu").open,focusBack:document.activeElement?.matches("[data-menu-toggle]")||false,'
                      'expanded:[...document.querySelectorAll("[data-menu-toggle]")].find(e=>e.getClientRects().length)?.getAttribute("aria-expanded")})')
        ok = isinstance(opened, dict) and opened.get('open') and opened['expanded'] == 'true' and opened['focusIn'] and opened['links'] >= 4 \
            and not opened['overflowX'] and isinstance(closed, dict) and not closed['open'] and closed['focusBack'] and closed['expanded'] == 'false' \
            and early is True and isinstance(area_early, int) and isinstance(area_final, int) and area_final > 0             and ((area_early == area_final and still_open is False) if reduced else (area_early < 0.8 * area_final and still_open is True))
        out['dialogReduced' if reduced else 'dialog'] = {'pass': ok, 'openAtClick': early, 'areaAt60ms': area_early, 'areaFinal': area_final,
                                                          'openAt60msAfterEsc': still_open, 'opened': opened, 'closed': closed}
    # toast above the pill, focused elements never hidden behind it (WCAG 2.4.11)
    fresh(b, base, 390)
    b.ab('open', base + '/index.html'); time.sleep(1.5)
    over = b.ev('(()=>{const t=document.querySelector("#toast");t.textContent="Agregado a tu bolsa";t.classList.add("visible");return 1})()'); time.sleep(0.6)
    tp = b.ev('JSON.stringify((()=>{const t=document.querySelector("#toast").getBoundingClientRect();const g=[...document.querySelectorAll("[data-menu-toggle]")].find(e=>e.getClientRects().length);'
              'let p=g;while(p&&getComputedStyle(p).position!=="fixed")p=p.parentElement;const q=p?.getBoundingClientRect();return{toast:[t.left,t.top,t.right,t.bottom].map(Math.round),overlap:!!%s(t,q),above:!!q&&t.bottom<=q.top,pill:!!q}})())' % HIT)
    out['toast'] = {'pass': over == 1 and isinstance(tp, dict) and tp.get('pill') is True and tp.get('overlap') is False and tp.get('above') is True, **(tp if isinstance(tp, dict) else {})}
    for page in ('index.html', 'catalogo.html', 'producto-negro.html', 'bolsa.html'):
        fresh(b, base, 390)
        b.ab('open', base + '/' + page); time.sleep(1.5)
        ob = b.ev(OBSCURED)
        out['focus-' + page] = {'pass': isinstance(ob, dict) and ob['checked'] > 0 and ob['count'] == 0, **(ob if isinstance(ob, dict) else {'raw': ob})}
    return {'pass': all(v['pass'] for v in out.values()), **out}


SAMPLER = r"""(()=>{const X=window.__tx={frames:[],errors:[],loaf:[],text:null,done:false};
addEventListener('error',e=>X.errors.push(String(e.message||e)));addEventListener('unhandledrejection',e=>X.errors.push(String(e.reason)));
try{new PerformanceObserver(l=>l.getEntries().forEach(e=>X.loaf.push(Math.round(e.duration)))).observe({type:'long-animation-frame'})}catch(e){X.loaf=null}
const pts=[[.5,.97],[.5,.5],[.1,.9],[.9,.9],[.1,.5],[.9,.5],[.5,.12],[.08,.12],[.92,.12]],t0=performance.now();
const tick=()=>{const cs=[...document.querySelectorAll('[data-barba="container"]')],inc=cs.length>1?cs[cs.length-1]:null,f={t:Math.round(performance.now()-t0),n:cs.length,sy:Math.round(scrollY)};
if(inc){f.hits=pts.map(([x,y])=>{const e=document.elementFromPoint(innerWidth*x,innerHeight*y);return e&&inc.contains(e)?1:0});f.outTop=Math.round(cs[0].getBoundingClientRect().top);
if(X.text===null&&f.hits.some(Boolean)){X.h1=(inc.querySelector('h1')?.textContent||'').trim();X.text=X.h1+' | '+[...inc.querySelectorAll('button,a')].slice(0,30).map(e=>e.textContent.trim()).join(' | ')}}
X.frames.push(f);if(performance.now()-t0<2200)requestAnimationFrame(tick);else X.done=true};requestAnimationFrame(tick);return 1})()"""


def tx_eval(frames, start_sy, max_ms):
    part = [f for f in frames if f.get('hits') and 0 < sum(f['hits']) < 9]
    seen = [f for f in frames if f.get('hits') and sum(f['hits']) > 0]
    full = next((f for f in frames if f.get('hits') and sum(f['hits']) == 9), None) or next((f for f in frames if f['n'] == 1 and seen and f['t'] > seen[0]['t']), None)
    two = [f for f in frames if f['n'] == 2]
    out_still = (max(f['outTop'] for f in two) - min(f['outTop'] for f in two)) <= 1 if two else None
    pre_cover = [f for f in frames if not full or f['t'] < full['t']]
    no_early_reset = all(abs(f['sy'] - start_sy) <= 2 for f in pre_cover)
    bottom_first = bool(part) and part[0]['hits'][0] == 1 and part[0]['hits'][7] == 0
    dur = (full['t'] - seen[0]['t']) if (seen and full) else None
    areas = [sum(f['hits']) for f in frames if f.get('hits')]
    monotonic = all(b >= a for a, b in zip(areas, areas[1:]))
    return {'partialFrames': len(part), 'bottomFirst': bottom_first, 'windowMs': dur, 'outgoingStill': out_still,
            'noEarlyScrollReset': no_early_reset, 'monotonic': monotonic, 'ok': len(part) >= 2 and bottom_first and monotonic and dur is not None and dur <= max_ms
            and out_still is not False and no_early_reset}


def tx_nav(b, js_click, wait=2.4):
    b.ev(SAMPLER); b.ev(js_click); time.sleep(wait)
    return b.ev('JSON.stringify(window.__tx)')


def transition(b, base):
    from scorecard import EN_RE  # Spanish-word detector the scorecard already uses for enSpanish
    import re
    out = {}
    big = "[...document.querySelectorAll('main a[href*=\"producto-\"]')].filter(a=>{const r=a.getBoundingClientRect();return r.width>40&&r.height>100&&r.left>=0&&r.right<=innerWidth})"
    center = f"(()=>{{const a={big}[0];if(!a)return -1;scrollTo(0,a.getBoundingClientRect().top+scrollY-innerHeight/2+100);return 1}})()"
    pick = f"(()=>{{const a={big}.find(a=>{{const r=a.getBoundingClientRect();return r.top>innerHeight*.15&&r.bottom<innerHeight*.9}});if(!a)return 0;a.click();return 1}})()"
    for width, lang in ((1440, 'es'), (390, 'en')):
        fresh(b, base, width, lang)
        b.ab('open', base + '/index.html' + ('?lang=en' if lang == 'en' else '')); time.sleep(1.8)
        b.ev(center); time.sleep(0.6)
        sy = b.ev('Math.round(scrollY)')
        b.ev('window.__probe=1;1')
        tx = tx_nav(b, pick)
        tx = tx if isinstance(tx, dict) else {}
        ev = tx_eval(tx.get('frames', []), sy, 800)
        text = tx.get('text') or ''
        spanish = re.findall(EN_RE, text) if lang == 'en' else []
        final = b.ev('JSON.stringify({n:document.querySelectorAll("[data-barba=\\"container\\"]").length,path:location.pathname,sy:Math.round(scrollY),'
                     'gsap:window.gsap?gsap.globalTimeline.getChildren(true,true,true).length:0,probe:window.__probe===1,windows:document.querySelectorAll(".page-window").length,'
                     'clip:document.querySelector("main")?.closest("[data-barba=\\"container\\"]")?.style.clipPath||"",'
                     'focus:(()=>{const a=document.activeElement,m=document.querySelector("main");return !!a&&a.isConnected&&!!m&&(a===m||m.contains(a))})()})')
        loaf = tx.get('loaf') or []
        ok = ev['ok'] and not tx.get('errors') and isinstance(final, dict) and final['n'] == 1 and 'producto-' in final['path'] \
            and final['sy'] <= 2 and final['gsap'] == 0 and final['focus'] and final['probe'] and final['windows'] == 0 and not final['clip']             and not spanish and bool(tx.get('h1'))  # maxLoaf is recorded only: headless load noise reaches 173 ms on champion 008
        out[f'forward{width}{lang}'] = {'pass': ok, **ev, 'startY': sy, 'final': final, 'errors': tx.get('errors'), 'maxLoaf': max(loaf or [0]),
                                        'spanishInWindow': spanish[:5], 'windowText': text[:160]}
        # history back keeps the fade and restores the scroll
        tb = tx_nav(b, 'history.back();1')
        tb = tb if isinstance(tb, dict) else {}
        evb = tx_eval(tb.get('frames', []), 0, 800)
        back_y = b.ev('Math.round(scrollY)')
        okb = evb['partialFrames'] == 0 and isinstance(back_y, int) and abs(back_y - sy) <= 10 and not tb.get('errors')
        out[f'back{width}{lang}'] = {'pass': okb, 'partialFrames': evb['partialFrames'], 'restoredY': back_y, 'expectedY': sy, 'errors': tb.get('errors')}
    # reduced motion: instant swap, no window
    fresh(b, base, 390, reduced=True)
    b.ab('open', base + '/index.html'); time.sleep(1.8)
    b.ev(center); time.sleep(0.5)
    tr = tx_nav(b, pick); tr = tr if isinstance(tr, dict) else {}
    evr = tx_eval(tr.get('frames', []), 0, 800)
    out['reduced'] = {'pass': evr['partialFrames'] == 0 and not tr.get('errors') and 'producto-' in str(b.ev('location.pathname')), 'partialFrames': evr['partialFrames']}
    fresh(b, base, 390)
    b.ab('open', base + '/index.html'); time.sleep(1.8)
    b.ev('window.__probe=1;document.querySelector("[data-menu-toggle]")?.click();1'); time.sleep(1.2)
    b.ev("document.querySelector('#mobile-menu a[href*=catalogo]')?.click();1"); time.sleep(2.6)
    mm = b.ev('JSON.stringify({path:location.pathname,probe:window.__probe===1,menuOpen:!!document.querySelector("#mobile-menu")?.open,'
              'focus:(()=>{const a=document.activeElement,m=document.querySelector("main");return !!a&&a.isConnected&&!!m&&(a===m||m.contains(a))})(),active:document.activeElement?.tagName+"."+(document.activeElement?.className||"")})')
    out['menuNav390'] = {'pass': isinstance(mm, dict) and 'catalogo' in mm['path'] and mm['probe'] and not mm['menuOpen'] and mm['focus'], **(mm if isinstance(mm, dict) else {})}
    # a second click during the transition, then 10 navigations: no errors, one container, no live tweens
    fresh(b, base, 1440)
    b.ab('open', base + '/index.html'); time.sleep(1.8)
    b.ev(center); time.sleep(0.5)
    td = tx_nav(b, pick.replace('a.click();return 1', 'a.click();setTimeout(()=>document.querySelector(\'header a[href*="catalogo"]\')?.click(),120);return 1'))
    td = td if isinstance(td, dict) else {}
    mid = b.ev('JSON.stringify({n:document.querySelectorAll("[data-barba=\\"container\\"]").length,main:!!document.querySelector("main[data-page]"),path:location.pathname})')
    out['doubleClick'] = {'pass': not td.get('errors') and isinstance(mid, dict) and mid['n'] == 1 and mid['main'] and 'producto-' in mid['path'], 'errors': td.get('errors'), 'state': mid}
    b.ev('window.__probe=1;window.__navErr=[];addEventListener("error",e=>__navErr.push(String(e.message)));1')
    for i in range(5):
        b.ev('document.querySelector(\'header a[href*="catalogo"]\')?.click();1'); time.sleep(1.6)
        b.ev('document.querySelector(\'header a[href="/"], header a[href="/index.html"], header a.wordmark\')?.click();1'); time.sleep(1.6)
    time.sleep(1.0)
    leak = b.ev('JSON.stringify({n:document.querySelectorAll("[data-barba=\\"container\\"]").length,gsap:window.gsap?gsap.globalTimeline.getChildren(true,true,true).length:0,'
                'probe:window.__probe===1,windows:document.querySelectorAll(".page-window").length,errors:window.__navErr||null,path:location.pathname,fixed:[...document.querySelectorAll("[data-barba=\\"container\\"]")].map(c=>getComputedStyle(c).position)})')
    out['tenNavs'] = {'pass': isinstance(leak, dict) and leak['n'] == 1 and leak['gsap'] == 0 and leak['probe'] and leak['windows'] == 0 and leak['errors'] == [] and leak['fixed'] == ['static']
                      and leak['path'] in ('/', '/index.html'), **(leak if isinstance(leak, dict) else {})}
    return {'pass': all(v['pass'] for v in out.values()), **out}


LOADER_STATE = ('JSON.stringify({loading:document.documentElement.classList.contains("ms-loading"),'
                'node:!!document.querySelector(".ms-loader"),'
                'shown:(()=>{const l=document.querySelector(".ms-loader");if(!l)return false;const s=getComputedStyle(l),r=l.getBoundingClientRect();'
                'return s.display!=="none"&&s.visibility!=="hidden"&&+s.opacity>0.5&&r.width>=innerWidth-1&&r.height>=innerHeight-1})(),'
                'start:performance.getEntriesByName("ms-loader-start").length,'
                'span:(()=>{const a=performance.getEntriesByName("ms-loader-start")[0],b=performance.getEntriesByName("ms-loader-end")[0];return a&&b?Math.round(b.startTime-a.startTime):null})(),'
                'active:document.activeElement?.tagName,sy:Math.round(scrollY),intro:!!document.querySelector(".ho-slide [data-intro]"),'
                'lcp:window.__lcp||null,shift:window.__cls??null})')
VITALS = ('window.__lcp=null;window.__cls=0;try{new PerformanceObserver(l=>{const e=l.getEntries().at(-1);window.__lcp={t:Math.round(e.startTime),tag:e.element?.tagName||null,'
          'inLoader:!!e.element?.closest?.(".ms-loader"),hero:!!e.element?.closest?.(".ho-slide")}}).observe({type:"largest-contentful-paint",buffered:true});'
          'new PerformanceObserver(l=>l.getEntries().forEach(e=>{if(!e.hadRecentInput)window.__cls+=e.value})).observe({type:"layout-shift",buffered:true})}catch(e){}1')


def loader(b, base):
    import base64, hashlib, re
    out = {}
    # CSP: the inline gate is allowed by its exact hash, never by 'unsafe-inline'
    from urllib.request import urlopen
    with urlopen(base + '/index.html') as r:
        src, hdr = r.read().decode('utf-8'), r.headers.get('Content-Security-Policy', '')
    # executable inline scripts only: JSON-LD data blocks are not scripts and need no hash
    inline = [m for m in re.findall(r'<script(?![^>]*\bsrc=)(?![^>]*application/ld\+json)[^>]*>(.*?)</script>', src, re.S) if m.strip()]
    hashes = ["'sha256-" + base64.b64encode(hashlib.sha256(m.encode('utf-8')).digest()).decode() + "'" for m in inline]
    script_src = next((d for d in hdr.split(';') if d.strip().startswith('script-src')), '')
    out['csp'] = {'pass': len(inline) == 1 and hashes[0] in script_src and 'unsafe-inline' not in script_src and src.find('<script') < src.find('</head>'),
                  'inlineScripts': len(inline), 'scriptSrc': script_src.strip(), 'gateBytes': len(inline[0]) if inline else 0}
    runs = []
    for width in (1440, 390, 1440):
        fresh(b, base, width)
        b.ab('open', base + '/index.html')
        b.ev(VITALS); time.sleep(2.4)
        st = b.ev(LOADER_STATE); st = st if isinstance(st, dict) else {}
        runs.append(st)
    first = runs[0]
    lcps = sorted(r['lcp']['t'] for r in runs if r.get('lcp'))
    out['fresh'] = {'pass': all(r.get('start') == 1 and r.get('span') is not None and r['span'] <= 1650 and not r.get('node') and not r.get('loading')
                                and r.get('active') == 'BODY' and r.get('sy') == 0 and r.get('intro') for r in runs),
                    'runs': [{k: r.get(k) for k in ('start', 'span', 'node', 'loading', 'active', 'sy', 'intro')} for r in runs]}
    out['vitals'] = {'pass': len(lcps) == 3 and all(not r['lcp']['inLoader'] for r in runs if r.get('lcp')) and all((r.get('shift') or 0) <= 0.05 for r in runs) and lcps[1] <= 800,
                     'lcpMedian': lcps[1] if len(lcps) == 3 else None, 'lcpLimit': '800 ms (champion 010 median 312, range 240-536)', 'lcp': [r.get('lcp') for r in runs], 'shift': [r.get('shift') for r in runs]}
    # repeat visit and reload in the same session: no loader
    b.ab('open', base + '/index.html'); time.sleep(0.4)
    rep = b.ev(LOADER_STATE); rep = rep if isinstance(rep, dict) else {}
    b.ab('reload'); time.sleep(0.4)
    rel = b.ev(LOADER_STATE); rel = rel if isinstance(rel, dict) else {}
    out['repeat'] = {'pass': all(not x.get('loading') and not x.get('shown') and x.get('start') == 0 for x in (rep, rel)) and bool(rep) and bool(rel),
                     'repeat': {k: rep.get(k) for k in ('loading', 'shown', 'start')}, 'reload': {k: rel.get(k) for k in ('loading', 'shown', 'start')}}
    # reduced motion: none
    fresh(b, base, 390, reduced=True)
    b.ab('open', base + '/index.html'); time.sleep(0.4)
    red = b.ev(LOADER_STATE); red = red if isinstance(red, dict) else {}
    out['reduced'] = {'pass': bool(red) and not red.get('loading') and not red.get('shown') and red.get('start') == 0, **{k: red.get(k) for k in ('loading', 'shown', 'start')}}
    # Barba navigation into home: none
    fresh(b, base, 1440)
    b.ab('open', base + '/catalogo.html'); time.sleep(1.6)
    b.ev("document.querySelector('header a.wordmark')?.click();1"); time.sleep(2.0)
    bar = b.ev(LOADER_STATE); bar = bar if isinstance(bar, dict) else {}
    path = b.ev('location.pathname')
    out['barba'] = {'pass': bool(bar) and path in ('/', '/index.html') and not bar.get('loading') and not bar.get('shown') and bar.get('start') == 0,
                    'path': path, **{k: bar.get(k) for k in ('loading', 'shown', 'start')}}
    # app.js never runs: the gate and CSS alone paint the loader, and the CSS failsafe hides it after about 3 s
    fresh(b, base, 1440)
    b.ab('network', 'route', '**/app.js', '--abort')
    b.ab('open', base + '/index.html'); time.sleep(0.6)
    early = b.ev(LOADER_STATE); early = early if isinstance(early, dict) else {}
    time.sleep(3.2)
    late = b.ev(LOADER_STATE); late = late if isinstance(late, dict) else {}
    b.ab('network', 'unroute')
    out['failsafe'] = {'pass': bool(early.get('shown')) and bool(late) and not late.get('shown'),
                       'earlyShown': early.get('shown'), 'lateShown': late.get('shown')}
    # interrupt: a tap at the hidden hero CTA ends the loader at once, activates nothing, and the page then scrolls
    fresh(b, base, 390)
    b.ab('open', base + '/index.html'); time.sleep(0.25)
    before = b.ev(LOADER_STATE); before = before if isinstance(before, dict) else {}
    cta = b.ev("(()=>{const a=document.querySelector('.ho-slide[data-active] .ho-copy a');if(!a)return null;const r=a.getBoundingClientRect();return [Math.round(r.left+r.width/2),Math.round(r.top+r.height/2)]})()")
    if isinstance(cta, list):
        b.ab('mouse', 'move', str(cta[0]), str(cta[1])); b.ab('mouse', 'down'); b.ab('mouse', 'up')
    time.sleep(0.5)
    after = b.ev(LOADER_STATE); after = after if isinstance(after, dict) else {}
    path = b.ev('location.pathname')
    b.ab('mouse', 'wheel', '400'); time.sleep(0.6)
    sy = b.ev('Math.round(scrollY)')
    out['interrupt'] = {'pass': bool(before.get('shown')) and isinstance(cta, list) and not after.get('node') and not after.get('loading')
                        and after.get('span') is not None and path in ('/', '/index.html') and isinstance(sy, (int, float)) and sy > 0,
                        'shownBefore': before.get('shown'), 'cta': cta, 'node': after.get('node'), 'loading': after.get('loading'),
                        'span': after.get('span'), 'path': path, 'scrollAfterWheel': sy}
    # hand-off: while the grown layer is visible it shows the same files as the active hero slide
    runs = []
    for width in (1440, 390):
        fresh(b, base, width)
        b.ab('open', base + '/index.html')
        b.ev(HANDOFF); time.sleep(2.2)
        h = b.ev('JSON.stringify(window.__handoff||null)'); h = h if isinstance(h, dict) else {}
        runs.append({'width': width, **h})
    out['handoff'] = {'pass': all(r.get('samples', 0) > 0 and r.get('mismatch') == 0 for r in runs), 'runs': runs}
    return {'pass': all(v['pass'] for v in out.values()), **out}


HANDOFF = ("window.__handoff={samples:0,mismatch:0,first:null};(()=>{const f=s=>(s||'').split('/').slice(-2).join('/');"
           "const t=setInterval(()=>{const l=document.querySelector('.ms-loader-hero');if(!l){clearInterval(t);return}"
           "if(getComputedStyle(l).visibility!=='visible')return;"
           "const a=[...l.querySelectorAll('img')].filter(i=>getComputedStyle(i.parentNode).display!=='none').map(i=>f(i.currentSrc||i.src));"
           "const b=[...document.querySelectorAll('.ho-slide[data-active] .ho-m')].filter(m=>getComputedStyle(m).display!=='none').map(m=>f(m.querySelector('img')?.currentSrc)).slice(0,a.length);"
           "window.__handoff.samples++;if(!window.__handoff.first)window.__handoff.first={layer:a,slide:b};"
           "if(a.join()!==b.join()||!a.length)window.__handoff.mismatch++},16)})();1")


# ---- B1 SEO (P8). Frozen contract: docs/storefront-loop-20261120/packets/P8-seo.md ----
NONINDEX_PAGES = ('404.html', 'admin.html', 'bolsa.html', 'checkout.html', 'pedido.html')
FORBIDDEN_LD = ('aggregateRating', 'review', 'address', 'telephone', 'geo', 'openingHours', 'LocalBusiness', 'ClothingStore', 'email', 'faxNumber')
REPO = ROOT


def _catalog(text):
    data, _ = json.JSONDecoder().raw_decode(text, text.index('{'))
    return data


def _head(src):
    import html as H, re
    head = src.split('</head>')[0]
    metas = {}
    for tag in re.findall(r'<meta\b[^>]*>', head):
        key = re.search(r'\b(?:name|property)="([^"]+)"', tag); val = re.search(r'\bcontent="([^"]*)"', tag)
        if key: metas.setdefault(key.group(1), []).append(H.unescape(val.group(1)) if val else None)
    title = re.search(r'<title>(.*?)</title>', head, re.S)
    canon = [H.unescape(h) for h in re.findall(r'<link\b[^>]*rel="canonical"[^>]*href="([^"]*)"', head)]
    ld_all = re.findall(r'<script\b[^>]*application/ld\+json[^>]*>(.*?)</script>', src, re.S)
    ld_head = re.findall(r'<script\b[^>]*application/ld\+json[^>]*>(.*?)</script>', head, re.S)
    start, end = head.count('<!-- seo:start -->'), head.count('<!-- seo:end -->')
    region = head.split('<!-- seo:start -->')[-1].split('<!-- seo:end -->')[0] if start == 1 and end == 1 else ''
    return {'metas': metas, 'title': H.unescape(title.group(1).strip()) if title else '', 'canon': canon,
            'ld_all': ld_all, 'ld_head': ld_head, 'markers': (start, end), 'region': region}


def seo_audit(read, cfg):
    """read(name) -> text or None. Returns a list of failures; empty means the state matches the contract."""
    import re
    bad = []
    cat_text = read('catalog.js')
    if not cat_text: return ['catalog.js missing']
    cat = _catalog(cat_text); products = cat['products']; brand = cat['brand']['name']
    site = (cfg.get('siteUrl') or '').rstrip('/'); idx = bool(cfg.get('indexable'))
    U = lambda p: site + p
    path = lambda n: '/' if n == 'index.html' else '/' + n
    prod_pages = {f"producto-{p['slug']}.html": p for p in products}
    indexable = ['index.html', 'catalogo.html', 'ayuda.html', *prod_pages]
    descs, titles = {}, {}
    for name in [*indexable, *NONINDEX_PAGES]:
        src = read(name)
        if src is None: bad.append(f'{name}: missing'); continue
        h = _head(src); m = h['metas']
        if h['markers'] != (1, 1): bad.append(f'{name}: seo markers {h["markers"]}')
        want_robots = 'index,follow' if idx and name in indexable else 'noindex,nofollow'
        if m.get('robots') != [want_robots]: bad.append(f'{name}: robots {m.get("robots")} != {want_robots}')
        if name in NONINDEX_PAGES:
            if h['canon'] or h['ld_all']: bad.append(f'{name}: canonical or JSON-LD on a non-indexable page')
            continue
        d = (m.get('description') or [''])[0]
        if len(m.get('description') or []) != 1 or not 50 <= len(d) <= 160: bad.append(f'{name}: description len {len(d)}')
        descs.setdefault(d, []).append(name); titles.setdefault(h['title'], []).append(name)
        prod = prod_pages.get(name)
        want = {'og:title': h['title'], 'og:description': d, 'og:site_name': brand, 'og:type': 'product' if prod else 'website',
                'og:locale': 'es_NI', 'twitter:card': 'summary_large_image', 'twitter:title': h['title'], 'twitter:description': d}
        for k, v in want.items():
            if m.get(k) != [v]: bad.append(f'{name}: {k} {m.get(k)} != {v!r}')
        if site:
            img = U(prod['images'][0]) if prod else None
            if h['canon'] != [U(path(name))]: bad.append(f'{name}: canonical {h["canon"]}')
            if m.get('og:url') != [U(path(name))]: bad.append(f'{name}: og:url {m.get("og:url")}')
            ogi = m.get('og:image') or []
            if len(ogi) != 1 or not ogi[0].startswith(site + '/') or (img and ogi[0] != img): bad.append(f'{name}: og:image {ogi}')
            if m.get('twitter:image') != ogi[:1]: bad.append(f'{name}: twitter:image {m.get("twitter:image")}')
        else:
            for k in ('og:url', 'og:image', 'twitter:image'):
                if k in m: bad.append(f'{name}: {k} present without siteUrl')
            if h['canon']: bad.append(f'{name}: canonical present without siteUrl')
        if len(h['ld_all']) != 1 or len(h['ld_head']) != 1 or 'application/ld+json' not in h['region']:
            bad.append(f'{name}: JSON-LD blocks all={len(h["ld_all"])} head={len(h["ld_head"])}'); continue
        try: ld = json.loads(h['ld_head'][0])
        except ValueError as e: bad.append(f'{name}: JSON-LD invalid {e}'); continue
        raw = json.dumps(ld)
        for k in FORBIDDEN_LD:
            if re.search(r'"(?:@type": ")?' + k + r'"', raw): bad.append(f'{name}: forbidden {k}')
        for p in products:
            if p.get('source_url') and p['source_url'] in src: bad.append(f'{name}: source_url leaked')
        if ld.get('@context') != 'https://schema.org' or not isinstance(ld.get('@graph'), list): bad.append(f'{name}: no @context/@graph'); continue
        by = {}
        for node in ld['@graph']: by.setdefault(node.get('@type'), []).append(node)
        need = {'Organization', 'WebSite'} | ({'BreadcrumbList', 'ItemList'} if name == 'catalogo.html' else set()) | ({'BreadcrumbList', 'Product'} if prod else set())
        if not need <= set(by): bad.append(f'{name}: types {sorted(by)} missing {sorted(need - set(by))}'); continue
        if any(len(by[t]) != 1 for t in need): bad.append(f'{name}: duplicate types')
        org = by['Organization'][0]
        if org.get('name') != brand or sorted(org.get('sameAs') or []) != sorted(cat['brand'].get('social', {}).values()): bad.append(f'{name}: Organization name/sameAs')
        if site and org.get('url') != U('/'): bad.append(f'{name}: Organization url')
        if not site and ('url' in org or 'url' in by['WebSite'][0]): bad.append(f'{name}: url without siteUrl')
        if 'BreadcrumbList' in need:
            items = by['BreadcrumbList'][0].get('itemListElement') or []
            if [i.get('position') for i in items] != list(range(1, (3 if prod else 2) + 1)): bad.append(f'{name}: breadcrumb positions')
            elif items[-1].get('name') != (prod['name'] if prod else items[-1].get('name')) or items[0].get('item') != U('/'): bad.append(f'{name}: breadcrumb names/items')
        if name == 'catalogo.html':
            items = by['ItemList'][0].get('itemListElement') or []
            want_items = [(i + 1, U(path(f"producto-{p['slug']}.html")), p['name']) for i, p in enumerate(products)]
            if [(i.get('position'), i.get('url'), i.get('name')) for i in items] != want_items: bad.append('catalogo.html: ItemList != catalog order')
        if prod:
            pr = by['Product'][0]
            if pr.get('name') != prod['name'] or pr.get('sku') != prod['id'] or pr.get('image') != [U(i) for i in prod['images']]:
                bad.append(f'{name}: Product name/sku/image')
            offers = pr.get('offers') or []
            want_o = [(v['id'], f"{prod['price_minor'] / 100:.2f}", prod['currency'],
                       'https://schema.org/InStock' if v['stock'] > 0 else 'https://schema.org/OutOfStock', U(path(name))) for v in prod['variants']]
            got_o = [(o.get('sku'), f"{float(o.get('price', 'nan')):.2f}" if o.get('price') is not None else None, o.get('priceCurrency'),
                      o.get('availability'), o.get('url')) for o in offers if o.get('@type') == 'Offer']
            if got_o != want_o: bad.append(f'{name}: offers {got_o[:2]} != {want_o[:2]}')
    bad += [f'duplicate description on {v}' for v in descs.values() if len(v) > 1]
    bad += [f'duplicate title on {v}' for v in titles.values() if len(v) > 1]
    robots = read('robots.txt'); sitemap = read('sitemap.xml'); llms = read('llms.txt')
    lines = [l.strip() for l in (robots or '').splitlines()]
    if robots is None: bad.append('robots.txt missing')
    elif idx and site:
        if f'Sitemap: {site}/sitemap.xml' not in lines or 'Disallow: /' in lines: bad.append('robots.txt open state')
    elif 'User-agent: *' not in lines or 'Disallow: /' not in lines or any(l.lower().startswith('sitemap:') for l in lines): bad.append('robots.txt closed state')
    if idx and site:
        locs = set(re.findall(r'<loc>([^<]+)</loc>', sitemap or ''))
        if locs != {U(path(n)) for n in indexable}: bad.append(f'sitemap.xml locs {len(locs)} != {len(indexable)}')
    elif sitemap is not None: bad.append('sitemap.xml present without siteUrl+indexable')
    if llms is None or not llms.startswith('# ' + brand) or any(U(path(n)) not in llms for n in ('catalogo.html', *prod_pages)):
        bad.append('llms.txt missing, wrong title or missing page links')
    return bad


def seo(b, base):
    import hashlib, shutil
    from urllib.request import urlopen
    from urllib.error import HTTPError
    out = {}
    cfg_path = REPO / 'site.config.json'
    cfg = json.loads(cfg_path.read_text(encoding='utf-8')) if cfg_path.exists() else {}
    biz = cfg.get('business')
    out['config'] = {'pass': cfg.get('siteUrl') == '' and cfg.get('indexable') is False and isinstance(biz, dict) and not any(biz.values()),
                     'siteUrl': cfg.get('siteUrl'), 'indexable': cfg.get('indexable'), 'businessEmpty': isinstance(biz, dict) and not any(biz.values())}

    def served(name):
        try:
            with urlopen(base + '/' + name) as r: return r.read().decode('utf-8')
        except HTTPError: return None
    bad = seo_audit(served, cfg)
    out['served'] = {'pass': not bad, 'failures': bad[:20], 'count': len(bad)}
    gen = REPO / 'tools' / 'seo_generate.py'
    run = lambda root, cfgp, *extra: subprocess.run([sys.executable, '-B', str(gen), '--root', str(root), '--config', str(cfgp), *extra],
                                                   capture_output=True, text=True, encoding='utf-8', errors='replace').returncode
    chk = run(REPO, cfg_path, '--check') if gen.exists() else None
    out['check'] = {'pass': chk == 0, 'exit': chk}
    # flip on a scratch copy: sample data refuses indexing; live data emits the domain set; reverting restores the bytes
    tmp = Path(tempfile.mkdtemp(prefix='seo-flip-')); st = tmp / 'build-inputs' / 'static'; st.mkdir(parents=True)
    src_static = REPO / 'build-inputs' / 'static'
    for f in [*src_static.glob('*.html'), *(src_static / n for n in ('catalog.js', 'robots.txt', 'llms.txt', 'sitemap.xml'))]:
        if f.exists(): shutil.copy2(f, st / f.name)
    snap = lambda: {f.name: hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(st.iterdir())}
    flip = {}
    try:
        h0 = snap(); cfgp = tmp / 'cfg.json'
        cfgp.write_text(json.dumps(cfg), encoding='utf-8')
        open_cfg = dict(cfg, siteUrl='https://example.test', indexable=True)
        cfgp.write_text(json.dumps(open_cfg), encoding='utf-8')
        flip['sampleRefusedExit'] = run(tmp, cfgp) if gen.exists() else None
        flip['sampleUnchanged'] = snap() == h0
        cat_orig = (st / 'catalog.js').read_text(encoding='utf-8')
        (st / 'catalog.js').write_text(cat_orig.replace('"commercial_status":"sample"', '"commercial_status":"active"').replace('"mode":"local_test"', '"mode":"live"'), encoding='utf-8', newline='')
        flip['liveExit'] = run(tmp, cfgp) if gen.exists() else None
        rd = lambda n: (st / n).read_text(encoding='utf-8') if (st / n).exists() else None
        live_bad = seo_audit(rd, open_cfg)
        flip['liveFailures'] = live_bad[:20]; flip['liveFailureCount'] = len(live_bad)
        h1 = snap(); flip['liveCheckExit'] = run(tmp, cfgp, '--check') if gen.exists() else None
        run(tmp, cfgp); flip['liveIdempotent'] = snap() == h1
        (st / 'catalog.js').write_text(cat_orig, encoding='utf-8', newline='')
        cfgp.write_text(json.dumps(cfg), encoding='utf-8')
        flip['revertExit'] = run(tmp, cfgp) if gen.exists() else None
        after = snap(); flip['revertRestoresBytes'] = after == h0
        flip['revertDiff'] = sorted(k for k in set(h0) | set(after) if h0.get(k) != after.get(k))[:10]
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    out['flip'] = {'pass': flip.get('sampleRefusedExit') not in (0, None) and flip.get('sampleUnchanged') and flip.get('liveExit') == 0
                   and flip.get('liveFailureCount') == 0 and flip.get('liveCheckExit') == 0 and flip.get('liveIdempotent')
                   and flip.get('revertExit') == 0 and flip.get('revertRestoresBytes'), **flip}
    return {'pass': all(v['pass'] for v in out.values()), **out}


MX = r"""(()=>{if(window.__mx&&!window.__mx.stop)return 1;const X=window.__mx={anims:[],shifts:[],add:[],stop:false};const seen=new WeakSet(),t0=performance.now();
const grp=t=>{if(!t||!t.closest)return null;if(t.closest('[data-add]'))return'add';if(t.closest('[data-sticky-add]'))return'sticky';if(t.closest('.bag-link,[data-bag-count]'))return'bag';
if(t.closest('[data-favorite]'))return'fav';if(t.closest('#toast'))return'toast';if(t.closest('[data-product-error],[data-error],[data-sticky-error]'))return'error';
if(t.closest('[data-product-sizes],.plp-sizes,[data-sticky-size]'))return'size';return null};window.__mxg=grp;
const SKIP=['offset','computedOffset','easing','composite'];
try{new PerformanceObserver(l=>l.getEntries().forEach(e=>X.shifts.push({v:+e.value.toFixed(5),input:e.hadRecentInput,src:(e.sources||[]).map(s=>grp(s.node)||(s.node&&s.node.nodeName)||'?')}))).observe({type:'layout-shift'})}catch(e){X.shifts=null}
let last='';const tick=()=>{const now=Math.round(performance.now()-t0);for(const a of document.getAnimations()){if(seen.has(a))continue;seen.add(a);const ef=a.effect,t=ef&&ef.target,g=grp(t);if(!g)continue;
let kf=[];try{kf=ef.getKeyframes()}catch(e){}const ct=ef.getComputedTiming();
X.anims.push({t:now,g,vis:g==='toast'?t.closest('#toast').classList.contains('visible'):null,type:a.constructor.name,pseudo:ef.pseudoElement||null,props:[...new Set(kf.flatMap(k=>Object.keys(k)).filter(p=>!SKIP.includes(p)))],
dur:Math.round(ct.activeDuration||0),delay:Math.round(ef.getTiming().delay||0),tf:kf.map(k=>k.transform||(k.translate?'translate('+k.translate.split(' ').join(',')+')':'')||(k.scale?'scale('+k.scale+')':'')).filter(Boolean),op:kf.map(k=>k.opacity).filter(v=>v!==undefined)})}
const b=document.querySelector('[data-add]');if(b){const s=[b.getAttribute('data-state')||'',Math.round(b.getBoundingClientRect().width*10)/10,b.textContent.trim().replace(/\s+/g,' '),!!b.querySelector('svg[aria-hidden="true"]')].join('|');if(s!==last){last=s;X.add.push({t:now,s})}}
if(!X.stop)requestAnimationFrame(tick)};requestAnimationFrame(tick);return 1})()"""
MX_TAKE = 'JSON.stringify((()=>{const X=window.__mx;X.stop=true;return{anims:X.anims,shifts:X.shifts,add:X.add}})())'
SCALE = re.compile(r'scale(?:3d)?\(\s*(-?[\d.]+)|matrix\(\s*(-?[\d.]+)')
TY = re.compile(r'translateY\(\s*(-?[\d.]+)px|translate(?:3d)?\(\s*-?[\d.]+(?:px|%)?\s*,\s*(-?[\d.]+)px|matrix\((?:\s*-?[\d.e]+\s*,){5}\s*(-?[\d.e]+)')
MOTION_PROPS = {'transform', 'opacity', 'scale', 'translate'}
# :active press rules: the selector without :active must match the element or a child it wraps; its transform scales into [.97,.99]
PRESS = r"""JSON.stringify((()=>{const out={};const rules=[];const walk=l=>{for(const r of l){if(r.cssRules&&!r.selectorText)walk(r.cssRules);else if(r.selectorText&&r.selectorText.includes(':active'))rules.push(r)}};
for(const s of document.styleSheets){try{walk(s.cssRules)}catch(e){}}
for(const [k,sel] of Object.entries(%s)){const el=document.querySelector(sel);if(!el){out[k]=null;continue}let best=null;
for(const r of rules)for(const part of r.selectorText.split(',')){if(!part.includes(':active'))continue;const base=part.replace(/:active/g,'').trim();try{if(el.matches(base)||el.querySelector(base)){const m=/scale\(\s*([\d.]+)/.exec(r.style.transform||'')||(r.style.scale?[0,r.style.scale]:null);if(m)best=+m[1]}}catch(e){}}
const tr=getComputedStyle(el);out[k]={scale:best,transition:tr.transitionProperty+' / '+tr.transitionDuration}}return out})())"""
PRESS_TARGETS = {'add': '[data-add]', 'size': '[data-product-sizes] label', 'quick': '.plp-quick', 'sticky': '[data-sticky-add]'}
SIZE_PICK = "(()=>{const i=[...document.querySelectorAll('[data-product-sizes] input[name=variant]')].find(i=>!i.disabled);if(!i)return 0;(i.labels[0]||i).click();return 1})()"
COUNT = "Number(document.querySelector('[data-bag-count]')?.textContent||-1)"


def _mx_scales(a):
    return [float(m.group(1) or m.group(2)) for s in a['tf'] for m in SCALE.finditer(s)]


def _mx_ty(a):
    return [abs(float(next(x for x in m.groups() if x is not None))) for s in a['tf'] for m in TY.finditer(s)]


def _mx_run(b, actions, settle):
    b.ev(MX)
    for act in actions:
        b.click(act[1:]) if act.startswith('@') else b.ev(act)
        time.sleep(0.05)
    time.sleep(settle)
    return b.ev(MX_TAKE)


def micro(b, base):
    """B3 contract: feedback-only micro-interactions (transform/opacity, <=300 ms, reduced motion, no CLS)."""
    out, all_anims = {}, []
    prod = base + '/producto-negro.html'
    for width, lang in ((1440, 'es'), (390, 'en')):
        k = f'{width}{lang}'
        q = '?lang=en' if lang == 'en' else ''
        fresh(b, base, width, lang)
        b.ab('open', prod + q); time.sleep(1.6)
        press = b.ev(PRESS % json.dumps(PRESS_TARGETS))
        err = _mx_run(b, ['@[data-add]'], 0.7)
        size = _mx_run(b, [SIZE_PICK], 0.6)
        c0 = b.ev(COUNT)
        add = _mx_run(b, ['@[data-add]'], 2.3)
        c1 = b.ev(COUNT)
        fresh(b, base, width, lang)
        b.ab('open', base + '/catalogo.html' + q); time.sleep(1.6)
        p0 = b.ev('document.querySelector("[data-favorite]")?.getAttribute("aria-pressed")')
        fav = _mx_run(b, ['@[data-favorite]'], 5.5)
        p1 = b.ev('document.querySelector("[data-favorite]")?.getAttribute("aria-pressed")')
        b.ev('(()=>{const f=document.querySelector("[data-favorite]");for(let i=0;i<5;i++)f.click();return 1})()'); time.sleep(1.0)
        stuck = b.ev('JSON.stringify((()=>{const g=window.__mxg;return{running:document.getAnimations().filter(a=>a.playState==="running"&&g(a.effect&&a.effect.target)&&g(a.effect.target)!=="toast").length,'
                     'tf:[...document.querySelectorAll("[data-favorite],[data-favorite] *,[data-bag-count]")].filter(e=>{const t=getComputedStyle(e).transform;return t!=="none"&&t!=="matrix(1, 0, 0, 1, 0, 0)"}).length}})())')
        b.ab('open', base + '/bolsa.html' + q); time.sleep(1.6)
        dec = _mx_run(b, ['@[data-remove-item]'], 0.8)
        runs = {'error': err, 'size': size, 'add': add, 'fav': fav, 'dec': dec}
        for name, r in runs.items():
            if isinstance(r, dict):
                all_anims += [dict(a, run=name, k=k) for a in r['anims']]
        g = lambda r, grp: [a for a in (r['anims'] if isinstance(r, dict) else []) if a['g'] == grp]
        tl = add['add'] if isinstance(add, dict) else []
        on = next((e['t'] for e in tl if e['s'].startswith('added|')), None)
        off = next((e['t'] for e in tl if on is not None and e['t'] > on and not e['s'].startswith('added|')), None)
        widths = {e['s'].split('|')[1] for e in tl}
        added_txt = next((e['s'] for e in tl if e['s'].startswith('added|')), '')
        shifts = [s for r in runs.values() if isinstance(r, dict) and r['shifts'] for s in r['shifts']
                  if any(x in ('add', 'bag', 'fav', 'toast', 'size', 'sticky') for x in s['src'])]
        toast_in = [a for a in g(fav, 'toast') if a['vis']]
        toast_out = [a for a in g(fav, 'toast') if not a['vis']]
        items = {
            'press': isinstance(press, dict) and all(isinstance(press.get(x), dict) and press[x]['scale'] is not None and .97 <= press[x]['scale'] <= .99 for x in ('add', 'size')),
            'added_state': on is not None and off is not None and 1150 <= off - on <= 1900 and len(widths) == 1
                           and ('Added' if lang == 'en' else 'Agregada') in added_txt and added_txt.endswith('|true'),
            'bag_bump': c1 == c0 + 1 and any({'transform', 'scale'} & set(a['props']) and _mx_scales(a) and max(_mx_scales(a)) <= 1.2 for a in g(add, 'bag')),
            'bag_no_bump_on_decrease': isinstance(dec, dict) and not g(dec, 'bag'),
            'favorite': p0 != p1 and any({'transform', 'scale'} & set(a['props']) and _mx_scales(a) and max(_mx_scales(a)) <= 1.25 for a in g(fav, 'fav')),
            'toast': any({'transform', 'translate'} & set(a['props']) for a in toast_in) and all(not _mx_ty(a) or max(_mx_ty(a)) <= 12 for a in toast_in)
                     and any('opacity' in a['props'] for a in toast_in) and bool(toast_out) and all(set(a['props']) <= {'opacity'} for a in toast_out),
            'size': any({'transform', 'scale'} & set(a['props']) for a in g(size, 'size')),
            'error': any('opacity' in a['props'] for a in g(err, 'error')) and not any({'transform', 'translate'} & set(a['props']) for a in g(err, 'error')),
            'no_stuck': isinstance(stuck, dict) and stuck['running'] == 0 and stuck['tf'] == 0,
            'cls': not shifts,
        }
        out[k] = {'pass': all(items.values()), **items, 'pressRules': press, 'addTimeline': tl, 'count': [c0, c1], 'pressed': [p0, p1], 'shifts': shifts, 'stuck': stuck}
    # the add button's colour transition (background/color, 200 ms) predates B3 and is not an effect B3 adds
    legacy = lambda a: a['type'] == 'CSSTransition' and a['g'] in ('add', 'sticky') and set(a['props']) <= {'backgroundColor', 'color'} and a['dur'] <= 200
    bad = [a for a in all_anims if not legacy(a) and a['dur'] > 0 and (not set(a['props']) <= MOTION_PROPS or a['dur'] + a['delay'] > 300)]
    out['props_and_duration'] = {'pass': bool(all_anims) and not bad, 'count': len(all_anims), 'bad': bad[:12]}
    fresh(b, base, 390, reduced=True)
    b.ab('open', prod); time.sleep(1.6)
    b.ev(SIZE_PICK); time.sleep(0.2)
    c0 = b.ev(COUNT)
    add = _mx_run(b, ['@[data-add]'], 2.3)
    c1 = b.ev(COUNT)
    moving = [a for a in (add['anims'] if isinstance(add, dict) else []) if a['dur'] > 1]
    added = any(e['s'].startswith('added|') for e in (add['add'] if isinstance(add, dict) else []))
    out['reduced'] = {'pass': not moving and added and c1 == c0 + 1, 'moving': moving[:6], 'addedState': added, 'count': [c0, c1]}
    fresh(b, base, 1440)
    b.ab('open', prod); time.sleep(1.6)
    b.ev(SIZE_PICK); time.sleep(0.2)
    c0 = b.ev(COUNT)
    b.ev('document.querySelector("[data-add]").scrollIntoView({block:"center"});1'); b.ab('dblclick', '[data-add]'); time.sleep(2.0)
    c1 = b.ev(COUNT)
    out['double_click'] = {'pass': c1 == c0 + 1, 'count': [c0, c1]}
    return {'pass': all(v['pass'] for v in out.values()), **out}


CHECKS = {'grid': grid, 'footer': footer, 'title': title, 'pill': pill, 'transition': transition, 'loader': loader, 'seo': seo, 'micro': micro}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', required=True)
    ap.add_argument('--port', type=int, default=18490)
    ap.add_argument('--repo', default=str(ROOT))
    ap.add_argument('--only', default=','.join(CHECKS))
    a = ap.parse_args()
    repo = Path(a.repo).resolve()
    global REPO; REPO = repo
    dist = Path(tempfile.mkdtemp(prefix='slices-')) / 'dist'
    subprocess.run([sys.executable, '-B', 'prepare.py', '--output', str(dist)], cwd=repo, check=True, capture_output=True)
    srv = Server(dist, a.port)
    b = Browser(f'slices{a.port}')
    result = {}
    try:
        for name in a.only.split(','):
            print('slice', name, file=sys.stderr, flush=True)
            try:
                result[name] = CHECKS[name](b, f'http://127.0.0.1:{a.port}')
            except Exception as e:  # a crash is a failed check, never a pass
                result[name] = {'pass': False, 'error': repr(e)}
    finally:
        b.ab('close'); srv.close()
    result['pass'] = all(v.get('pass') for v in result.values() if isinstance(v, dict))
    Path(a.out).write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding='utf-8')
    print(json.dumps({k: (v.get('pass') if isinstance(v, dict) else v) for k, v in result.items()}))
    return 0


if __name__ == '__main__':
    sys.exit(main())
