"""Real invented API acceptance via agent-browser; no deployed service."""
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('shell', ROOT / 'savia/demo/site/verify.py')
s = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s)
s.SESSION = 'savia-entry-20261116-real'
server = s.ThreadingHTTPServer(('127.0.0.1',0),s.functools.partial(s.Quiet,directory=str(ROOT/'savia/.out/demo-site')))
s.threading.Thread(target=server.serve_forever,daemon=True).start()
origin = f'http://127.0.0.1:{server.server_port}'
checks=[]
def check(name,js):
    value=s.evaluate(js)
    assert value, (name,value,s.evaluate("({active:document.activeElement.id,role:document.querySelector('#demo-role')?.value,current:document.querySelector('#demo-current-role')?.textContent,width:innerWidth,scroll:document.documentElement.scrollWidth,focus:sessionStorage.getItem('savia.demo.focus')})"))
    checks.append(name)
try:
    s.browser('open',origin)
    for width,height in [(1440,900),(390,844)]:
        s.browser('set','viewport',width,height)
        for role,route in [('MANAGER','venta'),('OWNER','venta'),('SELLER','comisiones'),('INVENTORY','recepcion')]:
            s.browser('open',origin)
            s.browser('wait','#demo-entry')
            check(f'{width}-{role}-keyboard-entry',"document.activeElement.matches('[data-demo-role=MANAGER]') && [...document.querySelectorAll('[data-demo-role]')].length===4 && !document.querySelector('input[type=password]')")
            s.browser('press','Tab')
            check(f'{width}-{role}-keyboard-next',"document.activeElement.matches('[data-demo-role=OWNER]')")
            if role=='MANAGER': s.browser('screenshot',Path(__file__).parent/f'entry-{width}.png')
            s.browser('click',f'[data-demo-role={role}]')
            s.browser('wait','--fn',f"location.hash === '#/{route}' && !!document.querySelector('#screen')?.children.length")
            s.browser('wait','--load','networkidle')
            check(f'{width}-{role}-entry-focus-role-layout',f"document.querySelector('#screen').contains(document.activeElement) && document.querySelector('#demo-role').value==='{role}' && document.querySelector('#demo-current-role').textContent.includes('Rol actual:') && document.documentElement.scrollWidth===innerWidth")
            if role=='MANAGER': s.browser('screenshot',Path(__file__).parent/f'manager-{width}.png')
            s.browser('reload')
            s.browser('wait','--fn',f"document.querySelector('#demo-role').value==='{role}' && !document.querySelector('#login-user') && !document.querySelector('#demo-entry')")
            checks.append(f'{width}-{role}-reload')
            s.evaluate("localStorage.setItem('unrelated.entry.sentinel','keep');sessionStorage.setItem('unrelated.entry.sentinel','keep')")
            before=s.evaluate("JSON.stringify({local:{...localStorage},session:{...sessionStorage}})")
            s.browser('click','#demo-reset')
            check(f'{width}-{role}-reset-locked',"document.querySelector('#modal').open && document.activeElement.id==='confirm-no' && document.querySelector('#demo-role').disabled && document.querySelector('#demo-reset').disabled")
            s.browser('click','#confirm-no')
            assert before==s.evaluate("JSON.stringify({local:{...localStorage},session:{...sessionStorage}})")
            checks.append(f'{width}-{role}-cancel-all-storage-unchanged')
            s.browser('click','#logout')
            s.browser('wait','#demo-entry')
            s.browser('click',f'[data-demo-role={role}]')
            s.browser('wait','#logout')
            s.browser('click','#demo-reset')
            s.browser('click','#confirm-yes')
            s.browser('wait','#demo-entry')
            check(f'{width}-{role}-confirm-only-demo',"!sessionStorage.getItem('savia.token') && Object.keys(JSON.parse(localStorage.getItem('savia.demo.v1')).tokens).length===0 && localStorage.getItem('unrelated.entry.sentinel')==='keep' && sessionStorage.getItem('unrelated.entry.sentinel')==='keep'")
    # A failed login must leave all entry controls usable; retry takes the same path.
    s.evaluate("globalThis.entryFetch=fetch;globalThis.fetch=async (input,init)=>{if(String(input).includes('/auth/login'))throw new Error('entry injected failure');return entryFetch(input,init)}")
    s.browser('click','[data-demo-role=MANAGER]')
    s.browser('wait','--fn',"!document.querySelector('#demo-banner [role=alert]').hidden")
    check('login-error-controls-recover',"[...document.querySelectorAll('[data-demo-role],#demo-reset,#demo-role')].every(x=>!x.disabled) && document.querySelector('#demo-banner [role=alert]').textContent.includes('Vuelva a intentar')")
    s.evaluate('globalThis.fetch=entryFetch')
    s.evaluate("globalThis.fetch=async(input,init)=>{if(String(input).includes('/auth/login')){sessionStorage.setItem('entry.login.calls',String(+(sessionStorage.getItem('entry.login.calls')||0)+1));await new Promise(r=>setTimeout(r,150));}return entryFetch(input,init)}")
    s.evaluate("document.querySelector('[data-demo-role=MANAGER]').click();document.querySelector('[data-demo-role=OWNER]').dispatchEvent(new Event('click'))")
    s.browser('wait','#logout')
    check('duplicate-entry-one-login',"sessionStorage.getItem('entry.login.calls')==='1' && document.querySelector('#demo-role').value==='MANAGER'")
    s.evaluate("globalThis.entryFetch=fetch;globalThis.fetch=async(input,init)=>{if(String(input).includes('/auth/login'))throw new Error('entry injected switch failure');return entryFetch(input,init)}")
    before_switch=s.evaluate("sessionStorage.getItem('savia.token')")
    s.browser('select','#demo-role','OWNER')
    s.browser('wait','--fn',"!document.querySelector('#demo-banner [role=alert]').hidden")
    assert before_switch==s.evaluate("sessionStorage.getItem('savia.token')")
    check('failed-switch-restores-selection-and-controls',"document.querySelector('#demo-role').value==='MANAGER' && !document.querySelector('#demo-role').disabled && !document.querySelector('#demo-reset').disabled")
    s.evaluate('globalThis.fetch=entryFetch')
    for role in ['OWNER','SELLER','INVENTORY','MANAGER']:
        s.browser('select','#demo-role',role)
        s.browser('wait','--fn',f"document.querySelector('#demo-role').value==='{role}' && !document.querySelector('#demo-role').disabled")
        checks.append(f'picker-switch-{role}')
    # Opening the confirmation twice cannot race or write anything.
    before=s.evaluate("JSON.stringify({local:{...localStorage},session:{...sessionStorage}})")
    s.evaluate("document.querySelector('#demo-reset').click();document.querySelector('#demo-reset').dispatchEvent(new Event('click'))")
    s.browser('wait','#confirm-no')
    s.browser('press','Escape')
    assert before==s.evaluate("JSON.stringify({local:{...localStorage},session:{...sessionStorage}})")
    checks.append('duplicate-reset-escape-preserves-all-storage')
    s.evaluate("const modal=document.querySelector('#modal');globalThis.entryShowModal=modal.showModal;modal.showModal=()=>{throw new Error('entry injected dialog failure')}")
    s.browser('click','#demo-reset')
    s.browser('wait','--fn',"!document.querySelector('#demo-banner [role=alert]').hidden")
    check('reset-error-controls-recover',"!document.querySelector('#demo-reset').disabled && !document.querySelector('#demo-role').disabled")
    s.evaluate("document.querySelector('#modal').showModal=entryShowModal")
    # Expire the fake server session, then trigger the app unauthorized handler.
    s.evaluate("(async()=>{await fetch('/api/v1/auth/logout',{method:'POST',headers:{Authorization:'Bearer '+sessionStorage.getItem('savia.token')}});const a=await import('/api.mjs');try{await a.me()}catch{}})()")
    s.browser('wait','#demo-entry')
    check('expired-session-entry',"!document.querySelector('#login-user') && document.activeElement.matches('[data-demo-role=MANAGER]')")
    for role in ['OWNER','MANAGER','INVENTORY','SELLER']:
        s.browser('open',origin+'/etiqueta/?entry=keep#keep')
        s.browser('wait','#demo-entry')
        s.browser('click',f'[data-demo-role={role}]')
        if role=='SELLER': s.browser('wait','#logout')
        else: s.browser('wait','#tag-session')
        check(f'etiqueta-{role}',"location.pathname==='/' && location.hash==='#/comisiones'" if role=='SELLER' else "location.pathname==='/etiqueta/' && location.search==='?entry=keep' && location.hash==='#keep' && document.activeElement.id==='root'")
        s.browser('click','#demo-reset')
        s.browser('click','#confirm-yes')
        s.browser('wait','#demo-entry')
    check('no-page-errors', 'true')
    assert not s.browser('errors')['errors']
    assert not [m for m in s.browser('console')['messages'] if m.get('type')=='error']
    urls=[r['url'] for r in s.browser('network','requests')['requests']]
    assert not [u for u in urls if u.startswith(('http:','https:')) and (not u.startswith(origin+'/') or '/api/v1' in u)]
finally:
    s.browser('close')
    server.shutdown()
    server.server_close()
    (Path(__file__).parent/'real-browser.json').write_text(json.dumps({'checks':checks,'count':len(checks),'server_stopped':True},indent=2),encoding='utf-8')
print(json.dumps({'checks':len(checks),'pass':True}))
