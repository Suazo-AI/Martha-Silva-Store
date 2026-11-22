// DOM simulation only: no real browser, layout, or network execution.
const {JSDOM,VirtualConsole}=require('./frontend-deps/node_modules/jsdom');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../dist');
const tick=()=>new Promise(r=>setTimeout(r,10));
async function boot(page,setup=()=>{}) {
 const errors=[],vc=new VirtualConsole();vc.on('jsdomError',e=>errors.push(e.message));
 const dom=new JSDOM(fs.readFileSync(path.join(root,page),'utf8'),{url:'https://demo.test/'+page,runScripts:'outside-only',pretendToBeVisual:true,virtualConsole:vc});
 const w=dom.window;w.matchMedia=()=>({matches:false,addEventListener(){}});w.IntersectionObserver=class{observe(){}disconnect(){}};w.CSS={escape:s=>s};
 w.HTMLElement.prototype.scrollIntoView=function(){};w.HTMLElement.prototype.scrollTo=function(){};w.scrollTo=()=>{};
 w.HTMLMediaElement.prototype.pause=function(){};w.HTMLDialogElement.prototype.showModal=function(){this.open=true;this.querySelector('button,input,select')?.focus()};w.HTMLDialogElement.prototype.close=function(){this.open=false;this.dispatchEvent(new w.Event('close'))};
 const beforeApp=setup(w);for(const f of ['catalog.js',process.env.FRONTEND_API || 'store-api.js','integration-adapters.js',process.env.FRONTEND_APP || 'app.js']){if(f===(process.env.FRONTEND_APP || 'app.js')&&typeof beforeApp==='function')beforeApp(w);w.eval(fs.readFileSync(path.resolve(root,f),'utf8'));}
 await tick();return {dom,w,d:w.document,errors,close:()=>dom.window.close()};
}
const tests=[];function test(name,run){tests.push([name,run])}
test('every actual page template mounts without JS errors',async()=>{const pages=fs.readdirSync(root).filter(f=>f.endsWith('.html'));assert.deepEqual(pages.sort(),JSON.parse(fs.readFileSync(path.resolve(__dirname,'site-pages.json'),'utf8')));for(const page of pages){const b=await boot(page);assert.deepEqual(b.errors,[],page);assert.equal(b.d.querySelector('main [data-error]:not([hidden])')?.textContent,undefined,page);b.close()}});
test('invalid favorites shape cannot break catalog mounting',async()=>{for(const val of ['{}','42','"oops"']){const b=await boot('catalogo.html',w=>w.localStorage.setItem('martha-favorites',val));assert.equal(b.d.querySelectorAll('.product-card').length,b.w.STORE_CATALOG.products.length);assert.equal(b.d.querySelector('main [data-error]:not([hidden])'),null);b.close()}});
test('catalog Back restores filter controls and result set',async()=>{const b=await boot('catalogo.html');const color=b.d.querySelector('[name=color]');color.value='Dorado';color.dispatchEvent(new b.w.Event('change',{bubbles:true}));assert.equal(b.d.querySelectorAll('.product-card').length,b.w.STORE_CATALOG.products.filter(p=>p.color==='Dorado').length);b.w.history.back();await tick();await tick();assert.equal(b.w.location.search,'');assert.equal(color.value,'');assert.equal(b.d.querySelectorAll('.product-card').length,b.w.STORE_CATALOG.products.length);b.close()});
test('product zoom closes with focus on originating photo',async()=>{const b=await boot('producto-dorado.html');const trigger=b.d.querySelector('[data-zoom]');trigger.focus();trigger.click();assert.ok(b.d.querySelector('#image-dialog').open);b.d.querySelector('#image-dialog [data-close-dialog]').click();assert.equal(b.d.activeElement,trigger);b.close()});
test('quantity stock failure is visible within mini-bag and rolls back selection',async()=>{const b=await boot('producto-dorado.html');b.d.querySelector('[name=variant]').checked=true;b.d.querySelector('[data-add]').click();await tick();const modal=b.d.querySelector('#mini-bag');assert.ok(modal.open);let qty=modal.querySelector('[data-quantity]');qty.focus();qty.value='10';qty.dispatchEvent(new b.w.Event('change',{bubbles:true}));await tick();assert.ok(modal.querySelector('[data-error]:not([hidden])'),'error must be visible in active modal');assert.equal(modal.querySelector('[data-quantity]').value,'1');assert.equal(b.d.activeElement,modal.querySelector('[data-quantity]'));b.close()});
test('successful quantity edit keeps mini-bag focus',async()=>{const b=await boot('producto-dorado.html');b.d.querySelector('[name=variant]').checked=true;b.d.querySelector('[data-add]').click();await tick();const modal=b.d.querySelector('#mini-bag');let qty=modal.querySelector('[data-quantity]');qty.focus();qty.value='2';qty.dispatchEvent(new b.w.Event('change',{bubbles:true}));await tick();assert.equal(modal.querySelector('[data-quantity]').value,'2');assert.equal(b.d.activeElement,modal.querySelector('[data-quantity]'));assert.equal(b.d.querySelector('[data-bag-count]').textContent,'2');b.close()});
test('admin refresh logout login remain functional',async()=>{const b=await boot('admin.html');assert.ok(b.d.querySelector('#admin-stock'));b.d.querySelector('[data-admin-refresh]').click();await tick();assert.ok(b.d.querySelector('#admin-stock'));b.d.querySelector('[data-admin-logout]').click();await tick();const form=b.d.querySelector('[data-admin-login]');assert.ok(form);form.dispatchEvent(new b.w.Event('submit',{bubbles:true,cancelable:true}));await tick();assert.ok(b.d.querySelector('#admin-stock'));b.close()});
test('rapid repeated add clicks produce only one cart mutation',async()=>{const b=await boot('producto-dorado.html');b.d.querySelector('[name=variant]').checked=true;const add=b.d.querySelector('[data-add]');add.click();add.click();await tick();assert.equal(b.d.querySelector('[data-bag-count]').textContent,'1');assert.equal((await b.w.marthaStoreApi('/api/cart')).lines[0].quantity,1);b.close()});
test('sort, empty filter, reset, and Forward agree with URL',async()=>{const b=await boot('catalogo.html');b.d.querySelector('[data-sort="price-desc"]').click();assert.equal(b.w.STORE_CATALOG.products.find(p=>p.id===b.d.querySelector('.product-card').dataset.id).price_minor,Math.max(...b.w.STORE_CATALOG.products.map(p=>p.price_minor)));const size=b.d.querySelector('[name=size]');size.value='L';size.dispatchEvent(new b.w.Event('change',{bubbles:true}));assert.equal(b.d.querySelectorAll('.product-card').length,0);b.d.querySelector('[data-filter-reset]').click();assert.equal(b.d.querySelectorAll('.product-card').length,b.w.STORE_CATALOG.products.length);assert.equal(b.w.location.search,'?sort=price-desc');b.w.history.back();await tick();await tick();assert.equal(size.value,'L');b.w.history.forward();await tick();await tick();assert.equal(size.value,'');assert.equal(b.d.querySelectorAll('.product-card').length,b.w.STORE_CATALOG.products.length);b.close()});
test('malformed checkout storage shape recovers at contact form',async()=>{for(const value of ['null','[]','42']){const b=await boot('checkout.html',w=>{w.sessionStorage.setItem('martha-savia-checkout-v1',value);w.eval(fs.readFileSync(path.join(root,'catalog.js'),'utf8'));w.eval(fs.readFileSync(path.join(root,'store-api.js'),'utf8'));w.eval(fs.readFileSync(path.join(root,'integration-adapters.js'),'utf8'));w.MarthaIntegrations.createLocalAdapter({mode:'savia',catalog:w.STORE_CATALOG,storage:w.localStorage,createStoreApi:w.createMarthaStoreApi})('/api/cart/items',{variant_id:'dorado-S',quantity:1});});assert.ok(b.d.querySelector('[data-checkout-form="contact"]'));assert.equal(b.d.querySelector('main [data-error]:not([hidden])'),null);b.close()}});
test('B3 add to bag shows a timed added state, restores the idle label and keeps one line',async()=>{const b=await boot('producto-dorado.html');b.d.querySelector('[name=variant]').checked=true;const add=b.d.querySelector('[data-add]');add.click();add.click();await tick();assert.equal(add.dataset.state,'added');assert.equal(add.textContent.trim(),'Agregada');assert.equal(add.querySelector('svg').getAttribute('aria-hidden'),'true');assert.equal(b.d.querySelectorAll('#toast').length,1);assert.equal((await b.w.marthaStoreApi('/api/cart')).lines[0].quantity,1);await new Promise(r=>setTimeout(r,1700));assert.equal(add.dataset.state,undefined);assert.equal(add.textContent.trim(),'Agregar a la bolsa');assert.equal(add.querySelector('svg'),null);b.close()});
test('remove final item keeps dialog open and close returns to add trigger',async()=>{const b=await boot('producto-dorado.html');b.d.querySelector('[name=variant]').checked=true;const add=b.d.querySelector('[data-add]');add.focus();add.click();await tick();const modal=b.d.querySelector('#mini-bag');const remove=modal.querySelector('[data-remove-item]');remove.focus();remove.click();await tick();assert.ok(modal.open);assert.equal(modal.querySelectorAll('.cart-line').length,0);assert.equal(b.d.activeElement,modal.querySelector('[data-close-dialog]'));modal.querySelector('[data-close-dialog]').click();assert.equal(b.d.activeElement,add);b.close()});

test('memory-only cart and order survive BFCache when localStorage is blocked',async()=>{
 const b=await boot('producto-dorado.html',w=>Object.defineProperty(w,'localStorage',{get(){throw new w.DOMException('blocked','SecurityError')}}));
 try {
  b.d.querySelector('[name=variant]').checked=true;b.d.querySelector('[data-add]').click();await tick();
  assert.equal(b.d.querySelector('[data-bag-count]').textContent,'1');
  const quote=await b.w.marthaStoreApi('/api/quote',{delivery_zone:'managua'});
  const order=(await b.w.marthaStoreApi('/api/orders',{quote_id:quote.id,idempotency_key:'memory-key',contact:{name:'Fixture',email:'fixture@example.invalid',phone:'000'},address:{line1:'Fixture',city:'Fixture',department:'Managua'},newsletter:false})).order;
  assert.match(order.code,/^MS-\d{4}$/);
  b.w.dispatchEvent(new b.w.PageTransitionEvent('pageshow',{persisted:true}));await tick();
  assert.equal((await b.w.marthaStoreApi('/api/orders/'+order.id)).order.id,order.id);
  assert.equal(b.d.querySelector('main [data-error]:not([hidden])'),null);
  assert.deepEqual(b.errors,[]);
 } finally { b.close() }
});
test('missing integration module fails closed',async()=>{const b=await boot('producto-dorado.html',w=>()=>{delete w.MarthaIntegrations;});assert.equal(b.d.querySelector('[data-add]').disabled,true);assert.match(b.d.querySelector('main [data-error]').textContent,/No pudimos cargar la compra/);b.close()});
test('mount does not automatically create or recover a simulated order',async()=>{let writes=0;const b=await boot('checkout.html',w=>()=>{w.sessionStorage.setItem('martha-savia-checkout-v1',JSON.stringify({quote_id:'savia~missing',order_key:'stable-test-key'}));const create=w.MarthaIntegrations.createLocalAdapter;w.MarthaIntegrations={...w.MarthaIntegrations,createLocalAdapter:options=>{const inner=create(options);return async(...args)=>{if(args[0]==='/api/orders')writes++;return inner(...args)}}};});assert.equal(writes,0);assert.ok(b.d.querySelector('[data-recover-order]'));b.close()});

test('changing size cannot re-enable purchases while the integration is unavailable',async()=>{
 const b=await boot('producto-dorado.html',w=>()=>{delete w.MarthaIntegrations;});
 try {
  const size=b.d.querySelector('input[name=variant]:not(:disabled)');size.checked=true;size.dispatchEvent(new b.w.Event('change',{bubbles:true}));
  assert.equal(b.d.querySelector('[data-add]').disabled,true);
  const sticky=b.d.querySelector('[data-sticky-add]');if(sticky)assert.equal(sticky.disabled,true);
 } finally { b.close() }
});
async function twoSizeCart(){return boot('bolsa.html',w=>()=>{
 const api=w.MarthaIntegrations.createLocalAdapter({mode:'savia',catalog:w.STORE_CATALOG,storage:w.localStorage,createStoreApi:w.createMarthaStoreApi});
 for(const size of ['S','M'])api('/api/cart/items',{variant_id:'dorado-'+size,quantity:1});
});}
test('cart controls have distinct accessible names for different sizes',async()=>{
 const b=await twoSizeCart();
 try {
  for(const selector of ['[data-quantity]','[data-remove-item]','[data-move-favorite]']){
   const controls=[...b.d.querySelectorAll('[data-cart-lines] '+selector)];assert.equal(controls.length,2);
   const labels=controls.map(e=>e.getAttribute('aria-label')||e.textContent);
   assert.equal(new Set(labels).size,2);assert.match(labels[0],/talla S/i);assert.match(labels[1],/talla M/i);
  }
 } finally { b.close() }
});
test('removing a cart line preserves focus and announces the change',async()=>{
 const b=await twoSizeCart();
 try {
  const remove=()=>b.d.querySelector('[data-cart-lines] [data-remove-item]');
  remove().focus();remove().click();await tick();
  assert.ok(b.d.querySelector('[data-cart-lines]').contains(b.d.activeElement));
  assert.notEqual(b.d.activeElement,b.d.body);assert.match(b.d.querySelector('#toast').textContent,/retirad[ao]/i);
  remove().focus();remove().click();await tick();
  assert.equal(b.d.activeElement,b.d.querySelector('[data-cart-lines] .empty-state a'));
 } finally { b.close() }
});
test('checkout moves keyboard focus to the next step heading',async()=>{
 const b=await boot('checkout.html',w=>()=>{
  const api=w.MarthaIntegrations.createLocalAdapter({mode:'savia',catalog:w.STORE_CATALOG,storage:w.localStorage,createStoreApi:w.createMarthaStoreApi});
  api('/api/cart/items',{variant_id:'dorado-S',quantity:1});
 });
 try {
  for(const [name,value] of Object.entries({name:'Persona ficticia',email:'ux@example.test',phone:'88888888'}))b.d.querySelector(`[name=${name}]`).value=value;
  b.d.querySelector('[data-checkout-form=contact]').dispatchEvent(new b.w.Event('submit',{bubbles:true,cancelable:true}));await tick();
  assert.equal(b.d.activeElement,b.d.querySelector('#checkout-stage-title'));
  assert.ok(b.d.querySelector('[data-checkout-form=delivery]'));
  b.d.querySelector('[data-checkout-back=contact]').click();
  assert.equal(b.d.activeElement,b.d.querySelector('#checkout-stage-title'));
 } finally { b.close() }
});
test('mini-bag empty state after remove or favorite hides checkout and restores on a new add',async()=>{
 for(const action of ['[data-remove-item]','[data-move-favorite]']){
  const b=await boot('producto-dorado.html');
  try {
   const add=b.d.querySelector('[data-add]');
   b.d.querySelector('input[name=variant]:not(:disabled)').checked=true;add.click();await tick();
   const modal=b.d.querySelector('#mini-bag'),checkout=modal.querySelector('a[href="/checkout.html"]'),total=modal.querySelector('[data-mini-bag-total]');
   assert.ok(modal.open);assert.equal(checkout.hidden,false);assert.equal(total.hidden,false);
   modal.querySelector(action).focus();modal.querySelector(action).click();await tick();
   assert.ok(modal.open);assert.equal(modal.querySelectorAll('.cart-line').length,0);
   assert.equal(modal.querySelector('#mini-bag-title').textContent,'Bolsa vacía');
   assert.match(modal.querySelector('[data-mini-bag-lines]').textContent,/No quedan prendas/);
   assert.ok(modal.querySelector('[data-mini-bag-lines] a[href="/catalogo.html"]'));
   assert.equal(checkout.hidden,true);assert.equal(checkout.getAttribute('aria-disabled'),'true');assert.equal(total.hidden,true);
   assert.equal((await b.w.marthaStoreApi('/api/cart')).lines.length,0);
   modal.querySelector('[data-close-dialog]').click();assert.equal(modal.open,false);
   add.click();await tick();
   assert.ok(modal.open);assert.equal(modal.querySelectorAll('.cart-line').length,1);
   assert.equal(modal.querySelector('#mini-bag-title').textContent,'Agregada a tu bolsa');
   assert.equal(checkout.hidden,false);assert.equal(checkout.hasAttribute('aria-disabled'),false);assert.equal(total.hidden,false);
  } finally { b.close() }
 }
});

test('favorite visible label toggles with state without replacing SVG or accessible content',async()=>{
 const b=await boot('producto-dorado.html');
 try {
  const button=b.d.querySelector('[data-favorite="dorado"]');
  const text=[...button.childNodes].find(node=>node.nodeType===b.w.Node.TEXT_NODE&&node.textContent.includes('Guardar en favoritos'));
  assert.ok(text);
  const label=b.d.createElement('span');label.textContent=text.textContent;text.replaceWith(label);
  const svg=b.d.createElementNS('http://www.w3.org/2000/svg','svg'),title=b.d.createElementNS('http://www.w3.org/2000/svg','title');
  title.textContent='Guardar en favoritos: icono';svg.append(title);button.prepend(svg);
  const accessible=b.d.createElement('span');accessible.className='sr-only';accessible.textContent='Indicador accesible adicional';button.append(accessible);
  button.click();await tick();
  assert.equal(label.textContent.trim(),'Quitar de favoritos');assert.equal(button.getAttribute('aria-pressed'),'true');assert.match(button.getAttribute('aria-label'),/^Quitar de favoritos:/);
  assert.equal(button.querySelector('svg'),svg);assert.equal(title.textContent,'Guardar en favoritos: icono');assert.equal(accessible.textContent,'Indicador accesible adicional');
  button.click();await tick();
  assert.equal(label.textContent.trim(),'Guardar en favoritos');assert.equal(button.getAttribute('aria-pressed'),'false');assert.match(button.getAttribute('aria-label'),/^Guardar en favoritos:/);
  assert.equal(button.querySelector('svg'),svg);assert.equal(svg.getAttribute('fill'),'none');assert.equal(accessible.textContent,'Indicador accesible adicional');
 } finally { b.close() }
});

test('stock notes show availability for scarce and last-unit sizes and stay empty until a size is chosen',async()=>{
 const b=await boot('producto-dorado.html');
 try {
  const product=b.w.STORE_CATALOG.products.find(p=>p.id==='dorado');
  const variant=product.variants.find(v=>v.stock>=2);assert.ok(variant);
  const choose=async()=>{const input=[...b.d.querySelectorAll('input[name=variant]')].find(input=>input.value===variant.id);assert.ok(input);assert.equal(input.disabled,false);input.checked=true;input.dispatchEvent(new b.w.Event('change',{bubbles:true}));await tick();};
  assert.equal(b.d.querySelector('[data-stock-note]').textContent.trim(),'');
  await choose();assert.match(b.d.querySelector('[data-stock-note]').textContent,/disponible/);
  // Exercise a real demo state transition in this disposable jsdom session.
  // The recovered catalog file is never edited; it has no last-unit fixture.
  await b.w.marthaStoreApi('/api/admin/login',{});
  await b.w.marthaStoreApi('/api/admin/inventory',{variant_id:variant.id,quantity:1,reason:'Last-unit display regression in disposable demo'});
  const current=await b.w.marthaStoreApi('/api/catalog');
  assert.equal(current.products.find(p=>p.id==='dorado').variants.find(v=>v.id===variant.id).stock,1);
  b.w.dispatchEvent(new b.w.PageTransitionEvent('pageshow',{persisted:true}));await tick();
  await choose();
  assert.match(b.d.querySelector('[data-stock-note]').textContent,/^Última unidad$/);
 } finally { b.close() }
});

(async()=>{let failed=0;for(const [name,run]of tests){try{await run();console.log('PASS',name)}catch(e){failed++;console.error('FAIL',name,e.message)}}console.log(`${tests.length-failed}/${tests.length} DOM simulation tests passed`);process.exit(failed?1:0)})();
