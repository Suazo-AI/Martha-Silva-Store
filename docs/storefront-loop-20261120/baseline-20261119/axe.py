import json, time
from drive import ab, ev
B='http://127.0.0.1:18421'; out={}
for w,h in ((390,844),(1440,900)):
  ab('set','viewport',str(w),str(h)); ab('open',B+'/'); time.sleep(1); ev('localStorage.clear();sessionStorage.clear();1')
  ab('open',B+'/producto-negro.html'); time.sleep(1.2); ab('click','[data-product-form] label.size-option:not(.sold-out)'); ab('click','[data-product-form] [data-add]'); time.sleep(1.2)
  for p in ['/','/catalogo.html','/producto-negro.html','/bolsa.html','/checkout.html','/pedido.html','/ayuda.html','/?lang=en','/catalogo.html?lang=en']:
    ab('open',B+p); time.sleep(1.5)
    r=json.loads(ab('a11y','--json',timeout=120))['data']
    out[f'{w} {p}']={'v':[(v['id'],v['impact'],v['nodeCount'],v['nodes'][0]['html'][:90]) for v in r['violations']],'incomplete':[(v['id'],v['nodeCount']) for v in r['incomplete']]}
    print(w,p,out[f'{w} {p}']['v'],out[f'{w} {p}']['incomplete'],flush=True)
json.dump(out,open('axe.json','w',encoding='utf-8'),ensure_ascii=False,indent=1)
