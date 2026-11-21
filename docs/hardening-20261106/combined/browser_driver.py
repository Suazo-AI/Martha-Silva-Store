import subprocess,json,pathlib,sys
OUT=pathlib.Path(__file__).parent
mode=sys.argv[1]
records=[]
def call(*args):
    p=subprocess.run(['npx.cmd','-y','chrome-devtools-axi',*args],capture_output=True,text=True,encoding='utf8',errors='replace')
    records.append({'args':args,'exit':p.returncode,'stdout':p.stdout,'stderr':p.stderr})
    (OUT/('browser-'+mode+'.json')).write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf8')
    if p.returncode: raise RuntimeError(p.stdout+p.stderr)
    return p.stdout

def ev(code):return call('eval','async () => {'+code+'}')
def read(label):
    ev("return {label:"+json.dumps(label)+",url:location.href,size:[innerWidth,innerHeight],overflow:document.documentElement.scrollWidth>innerWidth,errors:[...document.querySelectorAll('[data-error]:not([hidden])')].map(x=>x.innerText),broken:[...document.images].filter(i=>i.complete&&i.currentSrc&&!i.naturalWidth).map(i=>i.currentSrc),text:document.querySelector('main')?.innerText.slice(0,800),resources:performance.getEntriesByType('resource').map(r=>({url:r.name,bytes:r.transferSize})),csp:window.__csp||[]};")
def click(selector):
    try:
        ev("const el=document.querySelector("+json.dumps(selector)+");if(!el)throw Error('Missing control');el.click();await new Promise(r=>setTimeout(r,700));return {url:location.href};")
    except RuntimeError as error:
        if selector!='[data-test-payment=approved]' or 'Execution context was destroyed' not in str(error): raise
        # Navigation destroys the evaluation context; subsequent order readback is the acceptance check.

def fill(values):
    ev('const values='+json.dumps(values)+";for(const [key,v] of Object.entries(values)){const el=document.querySelector('[name='+key+']');if(!el)throw Error(key);el.value=v;el.dispatchEvent(new Event('input',{bubbles:true}));el.dispatchEvent(new Event('change',{bubbles:true}));}return true;")
call('emulate','--viewport','1280x900x1' if mode=='desktop' else '390x844x1,mobile,touch')
if mode=='mobile':
    call('open','http://127.0.0.1:18313/')
    ev('localStorage.clear();sessionStorage.clear();return true;')
    # A fresh product navigation mounts a new model after clearing storage.
read('home');call('screenshot',str((OUT/(mode+'-home.png')).resolve()))
call('open','http://127.0.0.1:18313/catalogo.html');read('catalog')
call('open','http://127.0.0.1:18313/producto-dorado.html')
ev("window.__csp=[];document.addEventListener('securitypolicyviolation',e=>window.__csp.push({directive:e.violatedDirective,blocked:e.blockedURI}));return true;")
click('[name=variant]:not(:disabled)');click('[data-add]');read('mini-bag')
call('screenshot',str((OUT/(mode+'-bag.png')).resolve()));click('#mini-bag [data-close-dialog]')
call('open','http://127.0.0.1:18313/checkout.html')
fill({'name':'Persona Ficticia','email':'piloto@example.test','phone':'88888888'});click('[data-checkout-form=contact] button')
fill({'line1':'Direccion ficticia 123','city':'Managua','department':'Managua'});click('[data-checkout-form=delivery] button');read('review')
click('[data-create-order]');read('payment');call('screenshot',str((OUT/(mode+'-payment.png')).resolve()))
click('[data-test-payment=approved]');read('order');call('screenshot',str((OUT/(mode+'-order.png')).resolve()))
ev("if(!document.querySelector('.order-heading')?.innerText.includes('DEMO-0001'))throw Error('Missing expected demo order');return {heading:document.querySelector('.order-heading').innerText,notice:document.querySelector('main .notice').innerText};")
call('console');call('network');print(mode,'PASS',len(records),'commands')
