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
 const beforeApp=setup(w);for(const f of ['catalog.js',process.env.FRONTEND_API || 'demo-api.js','integration-adapters.js',process.env.FRONTEND_APP || 'app.js']){if(f===(process.env.FRONTEND_APP || 'app.js')&&typeof beforeApp==='function')beforeApp(w);w.eval(fs.readFileSync(path.resolve(root,f),'utf8'));}
 await tick();return {dom,w,d:w.document,errors,close:()=>dom.window.close()};
}
const tests=[];function test(name,run){tests.push([name,run])}
test('all 47 actual page templates mount without JS errors',async()=>{const pages=fs.readdirSync(root).filter(f=>f.endsWith('.html'));assert.equal(pages.length,47);for(const page of pages){const b=await boot(page);assert.deepEqual(b.errors,[],page);assert.equal(b.d.querySelector('main [data-error]:not([hidden])')?.textContent,undefined,page);b.close()}});
test('invalid favorites shape cannot break catalog mounting',async()=>{for(const val of ['{}','42','"oops"']){const b=await boot('catalogo.html',w=>w.localStorage.setItem('martha-parity-favorites',val));assert.equal(b.d.querySelectorAll('.product-card').length,b.w.DEMO_CATALOG.products.length);assert.equal(b.d.querySelector('main [data-error]:not([hidden])'),null);b.close()}});
test('catalog Back restores filter controls and result set',async()=>{const b=await boot('catalogo.html');const color=b.d.querySelector('[name=color]');color.value='Dorado';color.dispatchEvent(new b.w.Event('change',{bubbles:true}));assert.equal(b.d.querySelectorAll('.product-card').length,b.w.DEMO_CATALOG.products.filter(p=>p.color==='Dorado').length);b.w.history.back();await tick();await tick();assert.equal(b.w.location.search,'');assert.equal(color.value,'');assert.equal(b.d.querySelectorAll('.product-card').length,b.w.DEMO_CATALOG.products.length);b.close()});
test('product zoom closes with focus on originating photo',async()=>{const b=await boot('producto-dorado.html');const trigger=b.d.querySelector('[data-zoom]');trigger.focus();trigger.click();assert.ok(b.d.querySelector('#image-dialog').open);b.d.querySelector('#image-dialog [data-close-dialog]').click();assert.equal(b.d.activeElement,trigger);b.close()});
test('quantity stock failure is visible within mini-bag and rolls back selection',async()=>{const b=await boot('producto-dorado.html');b.d.querySelector('[name=variant]').checked=true;b.d.querySelector('[data-add]').click();await tick();const modal=b.d.querySelector('#mini-bag');assert.ok(modal.open);let qty=modal.querySelector('[data-quantity]');qty.focus();qty.value='10';qty.dispatchEvent(new b.w.Event('change',{bubbles:true}));await tick();assert.ok(modal.querySelector('[data-error]:not([hidden])'),'error must be visible in active modal');assert.equal(modal.querySelector('[data-quantity]').value,'1');assert.equal(b.d.activeElement,modal.querySelector('[data-quantity]'));b.close()});
test('successful quantity edit keeps mini-bag focus',async()=>{const b=await boot('producto-dorado.html');b.d.querySelector('[name=variant]').checked=true;b.d.querySelector('[data-add]').click();await tick();const modal=b.d.querySelector('#mini-bag');let qty=modal.querySelector('[data-quantity]');qty.focus();qty.value='2';qty.dispatchEvent(new b.w.Event('change',{bubbles:true}));await tick();assert.equal(modal.querySelector('[data-quantity]').value,'2');assert.equal(b.d.activeElement,modal.querySelector('[data-quantity]'));assert.equal(b.d.querySelector('[data-bag-count]').textContent,'2');b.close()});
test('admin refresh logout login remain functional',async()=>{const b=await boot('admin.html');assert.ok(b.d.querySelector('#admin-stock'));b.d.querySelector('[data-admin-refresh]').click();await tick();assert.ok(b.d.querySelector('#admin-stock'));b.d.querySelector('[data-admin-logout]').click();await tick();const form=b.d.querySelector('[data-admin-login]');assert.ok(form);form.dispatchEvent(new b.w.Event('submit',{bubbles:true,cancelable:true}));await tick();assert.ok(b.d.querySelector('#admin-stock'));b.close()});
test('rapid repeated add clicks produce only one cart mutation',async()=>{const b=await boot('producto-dorado.html');b.d.querySelector('[name=variant]').checked=true;const add=b.d.querySelector('[data-add]');add.click();add.click();await tick();assert.equal(b.d.querySelector('[data-bag-count]').textContent,'1');assert.equal((await b.w.marthaStoreApi('/api/cart')).lines[0].quantity,1);b.close()});
test('sort, empty filter, reset, and Forward agree with URL',async()=>{const b=await boot('catalogo.html');b.d.querySelector('[data-sort="price-desc"]').click();assert.equal(b.w.DEMO_CATALOG.products.find(p=>p.id===b.d.querySelector('.product-card').dataset.id).price_minor,Math.max(...b.w.DEMO_CATALOG.products.map(p=>p.price_minor)));const size=b.d.querySelector('[name=size]');size.value='L';size.dispatchEvent(new b.w.Event('change',{bubbles:true}));assert.equal(b.d.querySelectorAll('.product-card').length,0);b.d.querySelector('[data-filter-reset]').click();assert.equal(b.d.querySelectorAll('.product-card').length,b.w.DEMO_CATALOG.products.length);assert.equal(b.w.location.search,'?sort=price-desc');b.w.history.back();await tick();await tick();assert.equal(size.value,'L');b.w.history.forward();await tick();await tick();assert.equal(size.value,'');assert.equal(b.d.querySelectorAll('.product-card').length,b.w.DEMO_CATALOG.products.length);b.close()});
test('malformed checkout storage shape recovers at contact form',async()=>{for(const value of ['null','[]','42']){const b=await boot('checkout.html',w=>{w.sessionStorage.setItem('martha-savia-checkout-v1',value);w.eval(fs.readFileSync(path.join(root,'catalog.js'),'utf8'));w.eval(fs.readFileSync(path.join(root,'demo-api.js'),'utf8'));w.eval(fs.readFileSync(path.join(root,'integration-adapters.js'),'utf8'));w.MarthaIntegrations.createDemoAdapter({mode:'savia',catalog:w.DEMO_CATALOG,storage:w.localStorage,createDemoApi:w.createMarthaDemoApi})('/api/cart/items',{variant_id:'dorado-S',quantity:1});});assert.ok(b.d.querySelector('[data-checkout-form="contact"]'));assert.equal(b.d.querySelector('main [data-error]:not([hidden])'),null);b.close()}});
test('remove final item keeps dialog open and close returns to add trigger',async()=>{const b=await boot('producto-dorado.html');b.d.querySelector('[name=variant]').checked=true;const add=b.d.querySelector('[data-add]');add.focus();add.click();await tick();const modal=b.d.querySelector('#mini-bag');const remove=modal.querySelector('[data-remove-item]');remove.focus();remove.click();await tick();assert.ok(modal.open);assert.equal(modal.querySelectorAll('.cart-line').length,0);assert.equal(b.d.activeElement,modal.querySelector('[data-close-dialog]'));modal.querySelector('[data-close-dialog]').click();assert.equal(b.d.activeElement,add);b.close()});

test('both integration models are explicitly local and unconfigured',async()=>{const b=await boot('index.html',w=>{w.fetch=()=>{throw new Error('unexpected network')}});assert.match(b.d.querySelector('[data-integration-status]').textContent,/SAVIA.*Simulación local/);assert.match(b.d.querySelector('[data-integration-description]').textContent,/API .NET sintética.*no está conectada/);b.d.querySelector('[data-integration-mode="sisfain"]').click();await tick();assert.match(b.d.querySelector('[data-integration-description]').textContent,/No contamos con un contrato ni una API verificada/);assert.match(b.d.querySelector('[data-integration-availability]').textContent,/Sin backend configurado/);assert.equal(b.d.querySelector('[data-integration-mode="sisfain"]').getAttribute('aria-pressed'),'true');b.close()});
test('switching integrations isolates and restores each simulated cart',async()=>{const b=await boot('producto-dorado.html');b.d.querySelector('[name=variant]').checked=true;b.d.querySelector('[data-add]').click();await tick();b.d.querySelector('#mini-bag [data-close-dialog]').click();assert.equal(b.d.querySelector('[data-bag-count]').textContent,'1');b.d.querySelector('[data-integration-mode="sisfain"]').click();await tick();assert.equal(b.d.querySelector('[data-bag-count]').textContent,'0');assert.equal(b.d.querySelector('[name=variant]').checked,false);b.d.querySelector('[name=variant]').checked=true;b.d.querySelector('[data-add]').click();await tick();b.d.querySelector('#mini-bag [data-close-dialog]').click();assert.equal((await b.w.marthaStoreApi('/api/cart')).integration_id,'sisfain');b.d.querySelector('[data-integration-mode="savia"]').click();await tick();assert.equal(b.d.querySelector('[data-bag-count]').textContent,'1');assert.equal((await b.w.marthaStoreApi('/api/cart')).integration_id,'savia');b.close()});
test('memory-only carts survive mode changes, retry and BFCache within the same page',async()=>{
 const b=await boot('producto-dorado.html',w=>Object.defineProperty(w,'localStorage',{get(){throw new w.DOMException('blocked','SecurityError')}}));
 try {
  b.d.querySelector('[name=variant]').checked=true;b.d.querySelector('[data-add]').click();await tick();
  b.d.querySelector('#mini-bag [data-close-dialog]').click();
  b.d.querySelector('[data-integration-mode="sisfain"]').click();await tick();
  assert.equal((await b.w.marthaStoreApi('/api/cart')).lines.length,0);
  await b.w.marthaStoreApi('/api/cart/items',{variant_id:'dorado-S',quantity:2});
  b.d.querySelector('[data-integration-mode="savia"]').click();await tick();
  assert.equal((await b.w.marthaStoreApi('/api/cart')).lines[0]?.quantity,1);
  assert.equal(b.d.querySelector('[data-bag-count]').textContent,'1');
  b.w.dispatchEvent(new b.w.PageTransitionEvent('pageshow',{persisted:true}));await tick();
  b.d.querySelector('[data-integration-retry]').click();await tick();
  assert.equal((await b.w.marthaStoreApi('/api/cart')).lines[0]?.quantity,1);
  b.w.sessionStorage.setItem('martha-integration-mode-v1','sisfain');
  b.w.dispatchEvent(new b.w.PageTransitionEvent('pageshow',{persisted:true}));await tick();
  const cart=await b.w.marthaStoreApi('/api/cart');
  assert.equal(cart.integration_id,'sisfain');assert.equal(cart.lines[0]?.quantity,2);
  assert.match(b.d.querySelector('[data-integration-availability]').textContent,/Datos temporales.*recargar/);
  assert.deepEqual(b.errors,[]);
 } finally { b.close() }
});
test('memory-only orders survive mode changes and an explicit reset stays scoped',async()=>{
 const instances=new Map();
 const b=await boot('producto-dorado.html',w=>{
  Object.defineProperty(w,'localStorage',{get(){throw new w.DOMException('blocked','SecurityError')}});
  return ()=>{
   const create=w.MarthaIntegrations.createDemoAdapter;
   w.MarthaIntegrations={...w.MarthaIntegrations,createDemoAdapter:options=>{const api=create(options);instances.set(options.mode,api);return api}};
  };
 });
 try {
  async function createOrder(key) {
   await b.w.marthaStoreApi('/api/cart/items',{variant_id:'dorado-S',quantity:1});
   const quote=await b.w.marthaStoreApi('/api/quote',{delivery_zone:'managua'});
   return (await b.w.marthaStoreApi('/api/orders',{quote_id:quote.id,idempotency_key:key,contact:{name:'Fixture',email:'test@example.invalid',phone:'000'},address:{line1:'Fixture',city:'Fixture',department:'Fixture'}})).order;
  }
  const saviaOrder=await createOrder('memory-savia-key');
  b.d.querySelector('[data-integration-mode="sisfain"]').click();await tick();
  assert.equal((await b.w.marthaStoreApi('/api/admin/orders')).orders.length,0);
  const sisfainOrder=await createOrder('memory-sisfain-key');
  b.d.querySelector('[data-integration-mode="savia"]').click();await tick();
  assert.equal((await b.w.marthaStoreApi('/api/orders/'+saviaOrder.id)).order.id,saviaOrder.id);
  instances.get('savia').reset();
  b.d.querySelector('[data-integration-mode="sisfain"]').click();await tick();
  assert.equal((await b.w.marthaStoreApi('/api/orders/'+sisfainOrder.id)).order.id,sisfainOrder.id);
  b.d.querySelector('[data-integration-mode="savia"]').click();await tick();
  assert.equal((await b.w.marthaStoreApi('/api/admin/orders')).orders.length,0);
  assert.equal((await b.w.marthaStoreApi('/api/cart')).lines.length,0);
  assert.deepEqual(b.errors,[]);
 } finally { b.close() }
});
test('memory-only model retry fails closed for a missing module and restores its state',async()=>{
 const b=await boot('producto-dorado.html',w=>Object.defineProperty(w,'localStorage',{get(){throw new w.DOMException('blocked','SecurityError')}}));
 try {
  await b.w.marthaStoreApi('/api/cart/items',{variant_id:'dorado-S',quantity:1});
  const module=b.w.MarthaIntegrations;delete b.w.MarthaIntegrations;
  b.d.querySelector('[data-integration-retry]').click();await tick();
  assert.match(b.d.querySelector('[data-integration-status]').textContent,/no disponible/);
  assert.equal(b.d.querySelector('[data-add]').disabled,true);
  b.w.MarthaIntegrations=module;b.d.querySelector('[data-integration-retry]').click();await tick();
  assert.match(b.d.querySelector('[data-integration-status]').textContent,/Simulación local/);
  assert.equal(b.d.querySelector('[data-add]').disabled,false);
  assert.equal((await b.w.marthaStoreApi('/api/cart')).lines[0]?.quantity,1);
  assert.equal(b.d.querySelector('main [data-error]:not([hidden])'),null);
  assert.deepEqual(b.errors,[]);
 } finally { b.close() }
});
test('checkout contact data and last-order hints never transfer between modes',async()=>{const b=await boot('checkout.html',w=>()=>{for(const mode of ['savia','sisfain'])w.MarthaIntegrations.createDemoAdapter({mode,catalog:w.DEMO_CATALOG,storage:w.localStorage,createDemoApi:w.createMarthaDemoApi})('/api/cart/items',{variant_id:'dorado-S',quantity:1});w.sessionStorage.setItem('martha-savia-checkout-v1',JSON.stringify({name:'Persona ficticia SAVIA'}));w.sessionStorage.setItem('martha-savia-last-order-v1','savia~example');});assert.equal(b.d.querySelector('[name=name]').value,'Persona ficticia SAVIA');b.d.querySelector('[data-integration-mode="sisfain"]').click();await tick();assert.equal(b.d.querySelector('[name=name]').value,'');assert.equal(b.w.sessionStorage.getItem('martha-sisfain-last-order-v1'),null);b.d.querySelector('[data-integration-mode="savia"]').click();await tick();assert.equal(b.d.querySelector('[name=name]').value,'Persona ficticia SAVIA');b.close()});
test('switching on order page removes the previous mode order URL',async()=>{const b=await boot('pedido.html',w=>w.history.replaceState(null,'','/pedido.html?id=savia~example'));b.d.querySelector('[data-integration-mode="sisfain"]').click();await tick();assert.equal(b.w.location.search,'');assert.match(b.d.querySelector('[data-order-root]').textContent,/No seleccionaste un pedido/);b.close()});
test('missing integration module fails closed and retry restores the model',async()=>{let module;const b=await boot('producto-dorado.html',w=>()=>{module=w.MarthaIntegrations;delete w.MarthaIntegrations;});assert.match(b.d.querySelector('[data-integration-status]').textContent,/no disponible/);assert.equal(b.d.querySelector('[data-add]').disabled,true);assert.match(b.d.querySelector('main [data-error]').textContent,/No se cargó/);b.w.MarthaIntegrations=module;b.d.querySelector('[data-integration-retry]').click();await tick();assert.equal(b.d.querySelector('[data-add]').disabled,false);assert.match(b.d.querySelector('[data-integration-status]').textContent,/Simulación local/);assert.equal(b.d.querySelector('main [data-error]:not([hidden])'),null);b.close()});
test('pending cart mutation locks mode selection and repeated clicks',async()=>{let release;const b=await boot('producto-dorado.html',w=>()=>{const create=w.MarthaIntegrations.createDemoAdapter;w.MarthaIntegrations={...w.MarthaIntegrations,createDemoAdapter:options=>{const inner=create(options);return async(...args)=>{if(args[0]==='/api/cart/items')await new Promise(resolve=>{release=resolve});return inner(...args)}}};});b.d.querySelector('[name=variant]').checked=true;const add=b.d.querySelector('[data-add]'),switcher=b.d.querySelector('[data-integration-mode="sisfain"]');add.click();add.click();assert.equal(switcher.disabled,true);switcher.click();b.w.dispatchEvent(new b.w.PageTransitionEvent('pageshow',{persisted:true}));release();await tick();assert.equal(b.d.querySelector('[data-integration-panel]').dataset.mode,'savia');assert.equal(b.d.querySelector('[data-bag-count]').textContent,'1');assert.equal(switcher.disabled,false);b.close()});
test('mount does not automatically create or recover a simulated order',async()=>{let writes=0;const b=await boot('checkout.html',w=>()=>{w.sessionStorage.setItem('martha-savia-checkout-v1',JSON.stringify({quote_id:'savia~missing',order_key:'stable-test-key'}));const create=w.MarthaIntegrations.createDemoAdapter;w.MarthaIntegrations={...w.MarthaIntegrations,createDemoAdapter:options=>{const inner=create(options);return async(...args)=>{if(args[0]==='/api/orders')writes++;return inner(...args)}}};});assert.equal(writes,0);assert.ok(b.d.querySelector('[data-recover-order]'));b.close()});

test('BFCache restore follows the selected mode in the same tab without creating orders',async()=>{const b=await boot('pedido.html',w=>w.history.replaceState(null,'','/pedido.html?id=savia~old'));b.w.sessionStorage.setItem('martha-integration-mode-v1','sisfain');b.w.dispatchEvent(new b.w.PageTransitionEvent('pageshow',{persisted:true}));await tick();assert.equal(b.d.querySelector('[data-integration-panel]').dataset.mode,'sisfain');assert.equal(b.w.location.search,'');assert.match(b.d.querySelector('[data-order-root]').textContent,/No seleccionaste un pedido/);b.close()});
(async()=>{let failed=0;for(const [name,run]of tests){try{await run();console.log('PASS',name)}catch(e){failed++;console.error('FAIL',name,e.message)}}console.log(`${tests.length-failed}/${tests.length} DOM simulation tests passed`);process.exit(failed?1:0)})();
