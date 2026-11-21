import {pathToFileURL} from 'node:url';
import path from 'node:path';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {serve,order,actor} from './fixtures/supply-browser.mjs';
const [pw,out]=process.argv.slice(2);if(!pw||!out)throw Error('Playwright directory and output required');await mkdir(out,{recursive:true});
const {chromium}=await import(pathToFileURL(path.resolve(pw,'index.mjs')));const {expect}=await import(pathToFileURL(path.resolve(pw,'test.mjs')));
const browser=await chromium.launch({channel:'chrome',headless:true,args:['--disable-background-networking']});const results=[],errors=[],sources={};
for(const name of ['app.mjs','client.mjs','login.mjs','supply.mjs','index.html','styles.css']){const b=await readFile(`dev/savia-staff-ui/${name}`);sources[name]={RAW:createHash('sha256').update(b).digest('hex'),LF:createHash('sha256').update(b.toString().replaceAll('\r\n','\n')).digest('hex'),ChromeDecoded:createHash('sha256').update(b.toString().replace(/^\uFEFF/,'')).digest('hex')};}
const match=process.env.SUPPLY_TEST_MATCH;
async function test(name,fn,viewport={width:1440,height:1000}){if(match&&!name.includes(match))return;const fixture=await serve();const ctx=await browser.newContext({viewport,recordVideo:{dir:path.join(out,'videos'),size:viewport},serviceWorkers:'block'});const page=await ctx.newPage();page.setDefaultTimeout(4000);const consoleErrors=[],external=[],served=[],responseReads=[],networkFailures=[];
page.on('requestfailed',r=>networkFailures.push({path:new URL(r.url()).pathname,error:r.failure()?.errorText}));
page.on('response',r=>{const n=new URL(r.url()).pathname.split('/').at(-1)||'index.html';if(sources[n])responseReads.push((async()=>{const raw=await r.body();const hash=createHash('sha256').update(raw).digest('hex');served.push({name:n,ChromeDecoded:hash});})());});
page.on('pageerror',e=>consoleErrors.push(e.message));await ctx.route('**/*',route=>new URL(route.request().url()).origin===fixture.origin?route.continue():(external.push(route.request().url()),route.abort()));
try{await page.goto(fixture.origin+'/internal/');await expect(page.locator('#staff-shell')).toBeVisible();await page.locator('[data-target="abastecimiento"]').click();await expect(page.locator('[data-order-id]')).toHaveCount(1);const receiptRead=page.waitForResponse(r=>new URL(r.url()).pathname.endsWith('/receipts'));await page.locator('[data-order-id]').click();await (await receiptRead).finished();await expect(page.locator('#supply-lines input')).toHaveCount(1);await fn({page,state:fixture.state,ctx});await Promise.all(responseReads);for(const x of served)assert.equal(x.ChromeDecoded,sources[x.name].ChromeDecoded);const rawHTTP=[];for(const n of Object.keys(sources)){const response=await fetch(fixture.origin+'/internal/'+(n==='index.html'?'':n));const hash=createHash('sha256').update(Buffer.from(await response.arrayBuffer())).digest('hex');assert.equal(hash,sources[n].RAW);rawHTTP.push({name:n,RAW:hash});}assert.ok(served.some(x=>x.name==='supply.mjs'));assert.deepEqual(consoleErrors,[]);assert.deepEqual(external,[]);results.push({name,status:'PASS',viewport,origin:fixture.origin,calls:fixture.state.calls,deliveries:fixture.state.receipts.length,consoleErrors,served,rawHTTP,networkFailures});}
catch(e){results.push({name,status:'FAIL',error:e.stack,calls:fixture.state.calls,consoleErrors});errors.push(name);}
finally{const v=page.video();await ctx.close();await v.saveAs(path.join(out,'videos',name.replaceAll(/[^a-z0-9]+/gi,'-')+'.webm'));await new Promise(r=>fixture.server.close(r));await writeFile(path.join(out,'results.json'),JSON.stringify({layer:'Actual Chrome / explicitly mocked HTTP API / no SQL',browser:browser.version(),sources,results},null,2));console.log(results.at(-1).status,name);}}
try{
for(const viewport of [{width:1440,height:1000},{width:390,height:844}])await test(`partial-full-${viewport.width}`,async({page,state})=>{await page.locator('#supply-lines input').fill('2');await page.locator('#supply-submit').click();await expect(page.locator('#supply-result')).toContainText('Recepción confirmada');await expect(page.locator('#supply-lines input')).toHaveAttribute('max','3');await page.locator('#supply-lines input').fill('3');await page.locator('#supply-submit').click();await expect(page.locator('#supply-lines input')).toHaveAttribute('max','0');assert.equal(state.receipts.length,2);assert.equal(state.order.status,'received');for(const c of state.calls.filter(x=>x.method==='POST')){assert.equal(c.csrf,true);assert.deepEqual(Object.keys(JSON.parse(c.raw)).sort(),['lines','receiptId']);}},viewport);
for(const viewport of [{width:1440,height:1000},{width:390,height:844}])await test(`lost-reload-${viewport.width}`,async({page,state})=>{state.fault='lost';await page.locator('#supply-lines input').fill('2');await page.locator('#supply-submit').click();await expect(page.locator('#supply-recover')).toBeVisible();await expect(page.locator('#supply-recover')).toBeEnabled();const raw=await page.evaluate(()=>sessionStorage.getItem('savia.supply.pending.v1'));await page.reload();await page.locator('[data-target="abastecimiento"]').click();assert.equal(await page.evaluate(()=>sessionStorage.getItem('savia.supply.pending.v1')),raw);await page.locator('#supply-recover').click();await expect(page.locator('#supply-result')).toContainText('Recepción confirmada');assert.equal(state.receipts.length,1);const posts=state.calls.filter(x=>x.method==='POST');assert.ok(posts.length>=1);assert.ok(posts.every(p=>p.key===posts[0].key&&p.raw===posts[0].raw));const saved=JSON.parse(raw);assert.equal(posts[0].key,saved.key);assert.equal(posts[0].raw,saved.rawBody);assert.equal(state.calls.find(x=>x.path.includes('/operations/')).key,saved.key);},viewport);
await test('double-submit',async({page,state})=>{await page.locator('#supply-lines input').fill('1');await page.evaluate(()=>{const f=document.querySelector('#supply-form');f.dispatchEvent(new Event('submit',{cancelable:true}));f.dispatchEvent(new Event('submit',{cancelable:true}));});await expect(page.locator('#supply-result')).toContainText('Recepción confirmada');assert.equal(state.calls.filter(x=>x.method==='POST').length,1);assert.equal(state.receipts.length,1);});
await test('invalid-contract',async({page,state})=>{state.fault='invalid';await page.locator('[data-order-id]').click();await expect(page.locator('#supply-status')).toContainText('contrato');await expect(page.locator('#supply-submit')).toBeDisabled();assert.equal(state.receipts.length,0);});
await test('401-private-clear',async({page,state})=>{state.fault='401';await page.locator('#supply-refresh').click();await expect(page.locator('#staff-shell')).toBeHidden();await expect(page.locator('#supply-detail')).toBeEmpty();assert.equal(state.receipts.length,0);});
await test('logout-late-reply',async({page,state})=>{
  let releaseReceipt,releaseLogout;
  state.holdReceipt=new Promise(r=>releaseReceipt=r);
  state.holdLogout=new Promise(r=>releaseLogout=r);
  try{
    await page.locator('#supply-lines input').fill('1');await page.locator('#supply-submit').click();
    await expect.poll(()=>state.receipts.length).toBe(1);
    const pending=await page.evaluate(()=>sessionStorage.getItem('savia.supply.pending.v1'));
    assert.ok(pending);const posts=state.calls.filter(x=>x.method==='POST'&&x.path.includes('/supply/')).length;
    await page.locator('[data-action="logout"]').click();await expect.poll(()=>state.logoutWaiting).toBe(true);
    const late=page.waitForResponse(r=>r.request().method()==='POST'&&new URL(r.url()).pathname.endsWith('/receipts'));
    releaseReceipt();assert.equal((await late).status(),200);
    // The stale-session guard can reject at headers without consuming the body.
    // Observe the same document after two frames; a disposable negative control checks this window.
    await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
    assert.equal(new URL(page.url()).pathname,'/internal/');
    await expect(page.locator('#staff-shell')).toBeHidden();
    for(const id of ['orders','detail','lines','receipts','result'])await expect(page.locator(`#supply-${id}`)).toBeEmpty();
    assert.equal(await page.evaluate(()=>sessionStorage.getItem('savia.supply.pending.v1')),pending,'Late receipt removed the original pending reference.');
    await page.locator('#supply-form').dispatchEvent('submit');
    await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
    assert.equal(state.calls.filter(x=>x.method==='POST'&&x.path.includes('/supply/')).length,posts);
    assert.equal(state.receipts.length,1);releaseLogout();await expect(page).toHaveURL(/\/internal\/login$/);
  }finally{releaseReceipt();releaseLogout();}
});
}finally{await browser.close();}if(errors.length)process.exitCode=1;
