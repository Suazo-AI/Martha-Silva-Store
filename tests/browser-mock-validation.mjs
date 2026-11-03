// Real browser, real frontend bytes, synthetic HTTP responses. No SQL or external providers.
// node tests/browser-mock-validation.mjs <installed-playwright-directory> <evidence-directory>
import {createServer} from 'node:http';
import {readFile,writeFile,mkdir,readdir,stat} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const [pwPath,outArg]=process.argv.slice(2);
if(!pwPath||!outArg) throw Error('Explicit installed Playwright and output directories required.');
const out=path.resolve(outArg); await mkdir(out,{recursive:true});
const {chromium}=await import(pathToFileURL(path.join(pwPath,'index.mjs')).href);
const {expect}=await import(pathToFileURL(path.join(pwPath,'test.mjs')).href);
expect.setTimeout?.(5000);
const sha=b=>createHash('sha256').update(b).digest('hex');
const sources={};
for(const name of ['app.mjs','client.mjs','login.mjs','login.html','index.html','styles.css']){
  sources[`dev/savia-staff-ui/${name}`]=sha(await readFile(path.join(root,'dev/savia-staff-ui',name)));
}
const mime={'.html':'text/html','.js':'text/javascript','.mjs':'text/javascript','.css':'text/css','.json':'application/json','.svg':'image/svg+xml','.jpg':'image/jpeg','.jpeg':'image/jpeg','.png':'image/png','.webp':'image/webp','.woff2':'font/woff2','.mp4':'video/mp4'};
const server=createServer(async(req,res)=>{
  try{
    const u=new URL(req.url,'http://127.0.0.1');
    const staff=u.pathname.startsWith('/internal/');
    const base=path.join(root,staff?'dev/savia-staff-ui':'dist');
    let rel=decodeURIComponent(staff?u.pathname.slice('/internal/'.length):u.pathname.slice(1));
    if(!rel) rel='index.html'; if(staff&&rel==='login')rel='login.html';
    const target=path.resolve(base,rel);
    if(!target.startsWith(base+path.sep)) {res.writeHead(403);res.end();return;}
    const bytes=await readFile(target);
    res.writeHead(200,{'Content-Type':mime[path.extname(target)]||'application/octet-stream','Cache-Control':'no-store'});res.end(bytes);
  }catch{res.writeHead(404);res.end('Not found');}
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const origin=`http://127.0.0.1:${server.address().port}`;
const results=[],runtime=[],externalRequests=[],networkFailures=[];
const testMatch=process.env.MARTHA_BROWSER_TEST_MATCH;
const browser=await chromium.launch({channel:'chrome',headless:true,args:['--disable-background-networking']});
const id=n=>`00000001-0000-0000-0000-${String(n).padStart(12,'0')}`;
const actor={id:id(1),role:'Owner',enabled:true,loginName:'synthetic',displayName:'Synthetic Owner',version:id(9)};
const item={id:id(2),sku:'SYN-S',name:'Synthetic dress S',active:true,unitPriceMinor:10000,currency:'NIO'};
const place={id:id(3),branchId:id(4),name:'Synthetic branch A',active:true};
const body={locationId:place.id,customerId:null,lines:[{itemId:item.id,quantity:1}]};
const receipt={saleId:id(5),actorId:actor.id,locationId:place.id,customerId:null,currency:'NIO',totalMinor:10000,state:'recorded',paymentStatus:'not_processed',createdAt:'2026-11-03T12:00:00Z',lines:[{saleLineId:id(6),itemId:item.id,sku:item.sku,name:item.name,quantity:1,returnedQuantity:0,unitPriceMinor:10000,totalMinor:10000}]};
const party={id:id(10),name:'Synthetic customer <img src=x onerror=alert(1)>',active:true,kind:'customer',email:'synthetic@example.invalid',phone:''};
async function save(){await writeFile(path.join(out,'browser-results.json'),JSON.stringify({observedUtc:new Date().toISOString(),host:process.env.COMPUTERNAME,layer:'Real Chromium browser; mocked staff API; public browser-local demo',origin,sourceHashes:sources,results,runtime,externalRequests,networkFailures},null,2));}
async function test(name,fn){
  if(testMatch&&!name.includes(testMatch))return;
  const start=Date.now();try{const detail=await fn();results.push({name,status:'PASS',durationMs:Date.now()-start,...(detail?{detail}:{})});}
  catch(e){results.push({name,status:'FAIL',durationMs:Date.now()-start,error:e.message});}
  await save(); console.log(`${results.at(-1).status} ${name}`);
}
async function setup(options={}){
  const ctx=await browser.newContext({viewport:options.mobile?{width:390,height:844}:{width:1440,height:1000},serviceWorkers:'block'});
  const page=await ctx.newPage();page.setDefaultTimeout(5000);
  const state={session:options.session!==false,role:options.role||'Owner',sales:[],calls:[],...options};
  const currentActor=()=>({...actor,role:state.role});
  const json=(route,data,status=200)=>route.fulfill({status,contentType:'application/json',body:JSON.stringify(data)});
  page.on('pageerror',e=>runtime.push({test:state.label||'',error:e.message}));
  page.on('requestfailed',r=>networkFailures.push({test:state.label||'',path:new URL(r.url()).pathname,error:r.failure()?.errorText}));
  await ctx.route('**/*',async route=>{
    const req=route.request(),u=new URL(req.url());
    if(u.origin!==origin){externalRequests.push({origin:u.origin,path:u.pathname});return route.abort();}
    if(!u.pathname.startsWith('/internal/api/'))return route.continue();
    const method=req.method(),p=u.pathname;
    // Synthetic passwords/tokens remain in memory; only safe request metadata is written.
    state.calls.push({method,path:p,query:u.search,hasCsrf:!!req.headers()['x-csrf-token'],key:req.headers()['idempotency-key']||null});
    if(state.override){const handled=await state.override({route,req,u,p,method,state,json});if(handled)return;}
    if(p.endsWith('/security/csrf'))return json(route,{headerName:'X-CSRF-TOKEN',token:'synthetic-csrf-only'});
    if(p.endsWith('/security/login')){state.session=true;return json(route,{staff:currentActor(),expiresAt:'2026-11-04T12:00:00Z'});}
    if(p.endsWith('/security/logout')){state.session=false;return route.fulfill({status:204,body:''});}
    if(!state.session)return json(route,{code:'unauthenticated'},401);
    if(p.endsWith('/security/me'))return json(route,currentActor());
    const skip=Number(u.searchParams.get('skip')||0),take=Number(u.searchParams.get('take')||50);
    if(p.includes('/directory/')){
      const kind=p.split('/').at(-1);let rows=kind==='items'?[item]:kind==='locations'?[place]:[party];
      if(state.empty)rows=[];
      if(state.many&&kind==='parties')rows=Array.from({length:53},(_,i)=>({...party,id:id(100+i),name:`Synthetic customer ${i+1}`}));
      const q=u.searchParams.get('q');if(q)rows=rows.filter(x=>x.name.includes(q)||x.sku?.includes(q));
      return json(route,{items:rows.slice(skip,skip+take),total:rows.length,skip,take});
    }
    if(p.endsWith('/commerce/inventory'))return json(route,{items:state.empty?[]:[{itemId:item.id,locationId:place.id,onHand:3-state.sales.length,reserved:0,available:3-state.sales.length}],total:state.empty?0:1,skip,take});
    if(p.endsWith('/commerce/sales')&&method==='POST'){
      const key=req.headers()['idempotency-key'];const payload=req.postDataJSON();state.sales.push({key,payload});
      return json(route,receipt);
    }
    if(p.includes('/operations/'))return json(route,{status:'completed',result:{success:true,value:receipt,error:null}});
    if(p.includes('/commerce/sales/'))return json(route,receipt);
    return json(route,{code:'unhandled_mock_route'},501);
  });
  return {ctx,page,state,json,close:()=>ctx.close()};
}
async function withStaff(options,fn){const s=await setup(options);try{return await fn(s);}finally{await s.close();}}
async function ready(s){await s.page.goto(origin+'/internal/');await expect(s.page.locator('#staff-shell')).toBeVisible();}
async function sales(s){await ready(s);await s.page.locator('[data-target="ventas"][data-action="nav"]').click();await expect(s.page.locator('#sale-submit')).toBeEnabled();}
try{
  await test('Login posts CSRF and verifies server identity before opening staff',()=>withStaff({session:false},async s=>{
    await s.page.goto(origin+'/internal/login');await expect(s.page.locator('#login-submit')).toBeEnabled();
    await s.page.locator('#login-name').fill('synthetic');await s.page.locator('#login-password').fill('Synthetic-Only-123!');await s.page.locator('#login-submit').click();
    await expect(s.page.locator('#staff-shell')).toBeVisible();assert.equal(s.state.calls.find(x=>x.path.endsWith('/login')).hasCsrf,true);
    assert.ok(s.state.calls.some(x=>x.path.endsWith('/me')));
  }));
  for(const code of [401,429,503])await test(`Login HTTP ${code} stays closed with visible error`,()=>withStaff({session:false,override:async({route,p,json})=>{if(p.endsWith('/login')){await json(route,{code:'synthetic_failure'},code);return true;}}},async s=>{
    await s.page.goto(origin+'/internal/login');await expect(s.page.locator('#login-submit')).toBeEnabled();await s.page.locator('#login-name').fill('synthetic');await s.page.locator('#login-password').fill('Synthetic-Only-123!');await s.page.locator('#login-submit').click();await expect(s.page.locator('#login-error')).toBeVisible();assert.equal(new URL(s.page.url()).pathname,'/internal/login');
  }));
  await test('Anonymous session exposes no staff data',()=>withStaff({session:false},async s=>{await s.page.goto(origin+'/internal/');await expect(s.page.locator('#auth-required')).toBeVisible();await expect(s.page.locator('#staff-shell')).toBeHidden();assert.equal(s.state.calls.filter(x=>x.path.includes('/directory/')).length,0);}));
  for(const role of ['Owner','Manager','Cashier','Inventory'])await test(`${role} navigation and sale permissions in browser`,()=>withStaff({role},async s=>{
    await ready(s);await expect(s.page.locator('[data-target="clientes"][data-action="nav"]'))[role==='Owner'?'toBeVisible':'toBeHidden']();
    await s.page.locator('[data-target="ventas"][data-action="nav"]').click();await expect(s.page.locator('#sale-item option')).toHaveCount(1);
    await expect(s.page.locator('#sale-submit'))[role==='Inventory'?'toBeDisabled':'toBeEnabled']();
    if(role!=='Owner')assert.equal(s.state.calls.filter(x=>x.path.endsWith('/parties')).length,0);
  }));
  await test('Customer pagination and search use actual network query',()=>withStaff({many:true},async s=>{
    await ready(s);await expect(s.page.locator('#clients-rows tr')).toHaveCount(50);await s.page.locator('[data-page-next="clientes"]').click();await expect(s.page.locator('#clients-rows tr')).toHaveCount(3);
    assert.ok(s.state.calls.some(x=>x.query.includes('skip=50')));
    await s.page.locator('#clients-search').fill('customer 53');await s.page.locator('#clients-search-form button').click();await expect(s.page.locator('#clients-rows tr')).toHaveCount(1);await expect(s.page.locator('#clients-rows')).toContainText('customer 53');
    assert.ok(s.state.calls.some(x=>x.query.includes('skip=0')&&x.query.includes('q=customer+53')));
  }));
  await test('Customer text is escaped instead of executing HTML',()=>withStaff({},async s=>{await ready(s);await expect(s.page.locator('#clients-rows')).toContainText('<img');assert.equal(await s.page.locator('#clients-rows img').count(),0);}));
  await test('Empty catalog disables sale without inventing stock',()=>withStaff({empty:true,role:'Cashier'},async s=>{await ready(s);await s.page.locator('[data-target="ventas"][data-action="nav"]').click();await expect(s.page.locator('#sale-submit')).toBeDisabled();assert.equal(s.state.sales.length,0);}));
  await test('Sale sends no price, preserves key, displays receipt and updated stock',()=>withStaff({},async s=>{
    await sales(s);await s.page.locator('#sale-submit').click();await expect(s.page.locator('#sale-receipt')).toBeVisible();assert.deepEqual(s.state.sales[0].payload,body);assert.match(s.state.sales[0].key,/^[a-f0-9-]{36}$/);assert.equal(s.state.sales.length,1);assert.ok(s.state.calls.find(x=>x.method==='POST'&&x.path.endsWith('/sales')).hasCsrf);
    await s.page.reload();await s.page.locator('[data-target="ventas"][data-action="nav"]').click();await expect(s.page.locator('#sale-receipt')).toBeVisible();assert.equal(s.state.sales.length,1);
  }));
  await test('Rapid double submit sends one request',()=>withStaff({override:async({route,p,method,state,req,json})=>{if(p.endsWith('/sales')&&method==='POST'){state.sales.push({key:req.headers()['idempotency-key'],payload:req.postDataJSON()});await new Promise(r=>setTimeout(r,150));await json(route,receipt);return true;}}},async s=>{
    await sales(s);await s.page.locator('#sale-submit').evaluate(el=>{el.click();el.click();});await expect(s.page.locator('#sale-receipt')).toBeVisible();assert.equal(s.state.sales.length,1);
  }));
  await test('Lost response recovers original operation without second POST',()=>withStaff({override:async({route,p,method,state,req})=>{if(p.endsWith('/sales')&&method==='POST'){state.sales.push({key:req.headers()['idempotency-key'],payload:req.postDataJSON()});await route.abort('failed');return true;}}},async s=>{
    await sales(s);await s.page.locator('#sale-submit').click();await expect(s.page.locator('#sale-recover')).toBeEnabled();await expect(s.page.locator('#sale-submit')).toBeDisabled();await s.page.locator('#sale-recover').click();await expect(s.page.locator('#sale-receipt')).toBeVisible();assert.equal(s.state.sales.length,1);assert.equal(s.state.calls.find(x=>x.path.includes('/operations/')).key,s.state.sales[0].key);
  }));
  for(const status of [401,403,500])await test(`Sale HTTP ${status} never shows invented success`,()=>withStaff({override:async({route,p,method,json})=>{if(p.endsWith('/sales')&&method==='POST'){await json(route,{code:'rejected'},status);return true;}}},async s=>{
    await sales(s);await s.page.locator('#sale-submit').click();if(status===401){await expect(s.page.locator('#auth-required')).toBeVisible();await expect(s.page.locator('#stock-table')).toBeEmpty();}else{await expect(s.page.locator('#sale-status')).toContainText('sin confirmar');}
    await expect(s.page.locator('#sale-receipt')).toBeHidden();assert.equal(s.state.sales.length,0);
  }));
  await test('Malformed receipt leaves operation recoverable and blocks new sale',()=>withStaff({override:async({route,p,method,json})=>{if(p.endsWith('/sales')&&method==='POST'){await json(route,{...receipt,totalMinor:1});return true;}}},async s=>{await sales(s);await s.page.locator('#sale-submit').click();await expect(s.page.locator('#sale-status')).toContainText('contrato');await expect(s.page.locator('#sale-submit')).toBeDisabled();await expect(s.page.locator('#sale-receipt')).toBeHidden();}));
  await test('Confirmed rejected recovery unlocks only the rejected attempt',()=>withStaff({override:async({route,p,method,json})=>{if(p.endsWith('/sales')&&method==='POST'){await route.abort();return true;}if(p.includes('/operations/')){await json(route,{status:'completed',result:{success:false,value:null,error:'stock_unavailable'}});return true;}}},async s=>{await sales(s);await s.page.locator('#sale-submit').click();await expect(s.page.locator('#sale-recover')).toBeEnabled();await s.page.locator('#sale-recover').click();await expect(s.page.locator('#sale-submit')).toBeEnabled();await expect(s.page.locator('#sale-receipt')).toBeHidden();}));
  await test('Logout uses CSRF, clears private view and returns to login',()=>withStaff({},async s=>{await ready(s);await s.page.locator('[data-action="logout"]').click();await s.page.waitForURL('**/internal/login');assert.ok(s.state.calls.find(x=>x.path.endsWith('/logout')).hasCsrf);assert.equal(s.state.session,false);}));
  await test('Stale confirmed receipt 404 must not permanently block a fresh sale (N5)',()=>withStaff({role:'Cashier',override:async({route,p,json})=>{if(p.endsWith('/sales/'+receipt.saleId)){await json(route,{code:'not_found'},404);return true;}}},async s=>{
    await s.page.goto(origin+'/internal/login');await s.page.evaluate(({key,value})=>sessionStorage.setItem(key,value),{key:`savia.sale.receipt.${actor.id}`,value:receipt.saleId});await ready(s);await s.page.locator('[data-target="ventas"][data-action="nav"]').click();
    await expect(s.page.locator('#sale-item option')).toHaveCount(1);await expect(s.page.locator('#sale-status')).toContainText('servidor');
    const observation=await s.page.evaluate(()=>({status:document.querySelector('#sale-status').textContent,submitDisabled:document.querySelector('#sale-submit').disabled,recoverDisabled:document.querySelector('#sale-recover').disabled,retryDisabled:document.querySelector('#sale-retry').disabled}));
    await writeFile(path.join(out,'stale-receipt-observation.json'),JSON.stringify(observation,null,2));await s.page.screenshot({path:path.join(out,'stale-receipt.png'),fullPage:true});
    assert.equal(observation.submitDisabled,false,'Confirmed receipt became unavailable; new authorized sale is locked, with no recoverable pending operation.');
  }));
  await test('Unimplemented purchasing and customer creation remain visibly unavailable',()=>withStaff({},async s=>{await ready(s);await expect(s.page.locator('[data-action="new-client"]')).toBeDisabled();await s.page.locator('[data-target="abastecimiento"][data-action="nav"]').click();await expect(s.page.locator('#purchasing-pending-note')).toBeVisible();return 'Coverage observation only: these workflows are not implemented in the frontend.';}));
  for(const mobile of [false,true])await test(`Staff visible screens have no document overflow at ${mobile?'390':'1440'}px`,()=>withStaff({mobile},async s=>{
    await ready(s);const measurements=[];for(const view of ['clientes','inventario','ventas','abastecimiento']){await s.page.locator(`[data-target="${view}"][data-action="nav"]`).click();const dims=await s.page.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth}));measurements.push({view,...dims});assert.ok(dims.scroll<=dims.width+1,JSON.stringify(measurements));}return measurements;
  }));
  await test('All 47 public pages mount in Chromium with no uncaught JavaScript errors',async()=>{
    const s=await setup({});const before=runtime.length;const pages=(await readdir(path.join(root,'dist'))).filter(x=>x.endsWith('.html'));assert.equal(pages.length,47);
    try{for(const name of pages){const response=await s.page.goto(origin+'/'+name);assert.equal(response.status(),200,name);await s.page.waitForLoadState('networkidle');assert.ok(await s.page.locator('main').count(),name);}assert.deepEqual(runtime.slice(before),[]);return {pages:pages.length};}finally{await s.close();}
  });
  await test('Public product, bag, translation and synthetic checkout approval work in browser',async()=>{
    const s=await setup({mobile:true});try{
      await s.page.goto(origin+'/producto-dorado.html');await expect(s.page.locator('[data-add]')).toBeEnabled();await s.page.locator('[name="variant"]:not(:disabled)').first().check();await s.page.locator('[data-add]').click();await expect(s.page.locator('#mini-bag')).toBeVisible();
      await s.page.goto(origin+'/bolsa.html');await expect(s.page.locator('main [data-quantity]').first()).toHaveValue('1');
      await expect(s.page.locator('[data-storefront-integration-hidden]')).toBeHidden();
      await s.page.locator('[data-language="en"]').click();await expect(s.page.locator('html')).toHaveAttribute('lang','en');
      await s.page.goto(origin+'/checkout.html');await expect(s.page.locator('[data-checkout-form="contact"]')).toBeVisible();
      await s.page.locator('[name="name"]').fill('Synthetic Browser Customer');await s.page.locator('[name="email"]').fill('browser-test@example.invalid');await s.page.locator('[name="phone"]').fill('88888888');await s.page.locator('[data-checkout-form="contact"] button').click();
      await expect(s.page.locator('[data-checkout-form="delivery"]')).toBeVisible();await s.page.locator('[name="line1"]').fill('Synthetic address, no shipment');await s.page.locator('[name="city"]').fill('Managua');await s.page.locator('[name="department"]').fill('Managua');await s.page.locator('[data-checkout-form="delivery"] button').click();
      await s.page.locator('[data-create-order]').click();await s.page.locator('[data-test-payment="approved"]').click();await s.page.waitForURL('**/pedido.html**');await expect(s.page.locator('[data-order-root]')).toContainText('Synthetic Browser Customer');
      const rendered=await s.page.locator('[data-order-root]').innerText();await writeFile(path.join(out,'public-checkout-observation.json'),JSON.stringify({urlPath:new URL(s.page.url()).pathname,rendered},null,2));
      assert.match(rendered,/paid|pagado|approved|aprobado/i);return 'Browser-local demo only; no payment, email or external order sent.';
    }finally{await s.close();}
  });
  await test('Staff source bytes unchanged during browser run',async()=>{for(const [file,hash] of Object.entries(sources))assert.equal(sha(await readFile(path.join(root,file))),hash,file);});
  for(const outcome of ['declined','cancelled'])await test(`Public synthetic payment ${outcome} releases reservation and permits rebuilding order`,async()=>{
    const s=await setup({});try{
      await s.page.goto(origin+'/producto-dorado.html');await expect(s.page.locator('[data-add]')).toBeEnabled();await s.page.locator('[name="variant"]:not(:disabled)').first().check();await s.page.locator('[data-add]').click();await expect(s.page.locator('#mini-bag')).toBeVisible();
      await s.page.goto(origin+'/checkout.html');await s.page.locator('[name="name"]').fill('Synthetic Negative Checkout');await s.page.locator('[name="email"]').fill('negative@example.invalid');await s.page.locator('[name="phone"]').fill('88888888');await s.page.locator('[data-checkout-form="contact"] button').click();
      await s.page.locator('[name="line1"]').fill('Synthetic only');await s.page.locator('[name="city"]').fill('Managua');await s.page.locator('[name="department"]').fill('Managua');await s.page.locator('[data-checkout-form="delivery"] button').click();await s.page.locator('[data-create-order]').click();await s.page.locator(`[data-test-payment="${outcome}"]`).click();
      await s.page.waitForURL('**/pedido.html**');await expect(s.page.locator('[data-rebuild-order]')).toBeVisible();await expect(s.page.locator('[data-order-root]')).toContainText('reserva se liberó');await s.page.locator('[data-rebuild-order]').click();await s.page.waitForURL('**/bolsa.html**');await expect(s.page.locator('main [data-quantity]').first()).toHaveValue('1');
      return 'Local demo reservation/payment state only; no external provider.';
    }finally{await s.close();}
  });
  for(const mobile of [false,true])await test(`Public gallery actual geometry and controls at ${mobile?'390':'1440'}px`,async()=>{
    const s=await setup({mobile});try{
      await s.page.emulateMedia({reducedMotion:'reduce'});await s.page.goto(origin+'/producto-dorado.html');await s.page.waitForLoadState('networkidle');
      await s.page.locator('[data-gallery-next]:visible').first().click();
      await expect(s.page.locator('.gallery-thumbnails [data-gallery-go="1"]')).toHaveAttribute('aria-current','true');
      await expect.poll(()=>s.page.locator('[data-gallery-viewport]').evaluate(el=>el.scrollLeft)).toBeGreaterThan(0);
      const geometry=await s.page.locator('[data-gallery-viewport]').evaluate(el=>({left:el.scrollLeft,width:el.clientWidth,scrollWidth:el.scrollWidth}));
      await s.page.locator('[data-gallery-prev]:visible').first().click();await expect(s.page.locator('.gallery-thumbnails [data-gallery-go="0"]')).toHaveAttribute('aria-current','true');
      // Mobile has a leading clone. Check visible alignment, not an assumed zero scroll offset.
      await expect.poll(()=>s.page.locator('[data-gallery-viewport]').evaluate(el=>Math.abs(el.querySelector('.gallery-photo,.gallery-video').getBoundingClientRect().left-el.getBoundingClientRect().left-el.clientLeft))).toBeLessThan(2);
      return geometry;
    }finally{await s.close();}
  });
}finally{await save();await browser.close();await new Promise(r=>server.close(r));}
console.log(JSON.stringify({passed:results.filter(x=>x.status==='PASS').length,failed:results.filter(x=>x.status==='FAIL').length,output:out}));
process.exitCode=results.some(x=>x.status==='FAIL')?1:0;
