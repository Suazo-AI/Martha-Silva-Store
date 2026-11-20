import time, json
from drive import ab, ev
from en_scan_js import JS
B='http://127.0.0.1:18421'; found={}
def scan(label):
  r=ev(JS); found[label]=r if isinstance(r,list) else [str(r)]; print(label, found[label], flush=True)
for w in (390,1440):
  ab('set','viewport',str(w),'844' if w<500 else '900'); ab('open',B+'/?lang=en'); time.sleep(1.2); ev('localStorage.clear();sessionStorage.clear();localStorage.setItem("martha-language-v1","en");1')
  for p in ['/','/catalogo.html','/producto-negro.html','/producto-novias-velo.html','/ayuda.html','/bolsa.html','/admin.html']:
    ab('open',B+p+'?lang=en'); time.sleep(1.6); scan(f'{w} {p}')
  ab('open',B+'/'); time.sleep(1.2)
  if w==390: ab('click','[data-menu-toggle]'); time.sleep(.6); scan(f'{w} menu dialog'); ab('press','Escape')
  ab('open',B+'/catalogo.html'); time.sleep(1.3)
  ab('click','[data-filters-open]'); time.sleep(.6); scan(f'{w} filter dialog'); ab('press','Escape'); time.sleep(.3)
  ab('click','[data-sort-toggle]'); time.sleep(.5); scan(f'{w} sort open'); ab('press','Escape')
  ab('click','[data-catalog-grid] .plp-card [data-quick]'); time.sleep(.6); scan(f'{w} quick-add picking')
  ab('click','[data-catalog-grid] .plp-card [data-favorite]'); time.sleep(.4); scan(f'{w} favorite toast')
  ab('open',B+'/producto-negro.html'); time.sleep(1.5)
  ab('click','button.gallery-photo[data-gallery-index="0"]'); time.sleep(.8); scan(f'{w} zoom dialog'); ab('press','Escape'); time.sleep(.3)
  ab('click','[data-size-guide]'); time.sleep(.8); scan(f'{w} size guide'); ab('press','Escape'); time.sleep(.3)
  ab('click','[data-product-form] [data-add]'); time.sleep(.6); scan(f'{w} add without size')
  ab('click','[data-product-form] label.size-option:not(.sold-out)'); ab('click','[data-product-form] [data-add]'); time.sleep(1.3); scan(f'{w} mini bag + toast')
  ab('open',B+'/bolsa.html'); time.sleep(1.4); scan(f'{w} bag filled')
  ab('open',B+'/checkout.html'); time.sleep(1.4); ab('click','[data-checkout-form] button.button'); time.sleep(.6); scan(f'{w} contact errors')
  for k,v in {'name':'Ana Ficticia','email':'ana@example.test','phone':'+505 8888 0000'}.items(): ab('fill',f'[data-checkout-form] [name="{k}"]',v)
  ab('click','[data-checkout-form] button.button'); time.sleep(1.2); scan(f'{w} delivery')
  for k,v in {'line1':'Calle de prueba 1','city':'Managua','department':'Managua','coupon':'PRUEBA10'}.items(): ab('fill',f'[data-checkout-form] [name="{k}"]',v)
  ab('click','[data-checkout-form] button.button'); time.sleep(1.4); scan(f'{w} review')
  ab('click','[data-create-order]'); time.sleep(1.8); scan(f'{w} payment')
  ab('click','[data-test-payment="approved"]' if w==390 else '[data-test-payment="declined"]'); time.sleep(2.2); scan(f'{w} order')
json.dump(found,open('en-scan2.json','w',encoding='utf-8'),ensure_ascii=False,indent=1)
