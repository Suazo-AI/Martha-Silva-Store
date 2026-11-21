import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {serve,id,actor} from '../../../tests/fixtures/supply-browser.mjs';
const phase=process.argv[3];assert.ok(['before','after'].includes(phase));
const {chromium}=await import(pathToFileURL(path.resolve(process.argv[2],'index.mjs')));
const {expect}=await import(pathToFileURL(path.resolve(process.argv[2],'test.mjs')));
const out=path.join(path.dirname(fileURLToPath(import.meta.url)),`judge-${phase}`);await mkdir(out,{recursive:true});
const sources={};for(const name of ['app.mjs','client.mjs','login.mjs','index.html','styles.css'])sources[name]=createHash('sha256').update(await readFile('dev/savia-staff-ui/'+name)).digest('hex');
const browser=await chromium.launch({channel:'chrome',headless:true,args:['--disable-background-networking']}),results=[];
try{for(const width of [1440,390]){
 const fixture=await serve(),height=width===390?844:1000;
 const ctx=await browser.newContext({viewport:{width,height},recordVideo:{dir:path.join(out,'videos'),size:{width,height}},serviceWorkers:'block'}),page=await ctx.newPage();page.setDefaultTimeout(5000);
 const current={...actor,id:id(8),role:'Manager'},upper='ABCDEFAB-0000-0000-0000-000000000088';
 const line={saleLineId:id(21),itemId:id(2),sku:'SYN-EX',name:'Synthetic garment',quantity:1,returnedQuantity:0,unitPriceMinor:100,totalMinor:100,exceptionReason:'physical',size:'S'};
 const sale={saleId:id(20),actorId:actor.id,locationId:id(3),customerId:null,currency:'USD',totalMinor:300,state:'recorded',paymentStatus:'not_processed',createdAt:'2026-11-06T00:00:00Z',lines:[line,{...line,saleLineId:id(22),itemId:id(12)},{...line,saleLineId:id(23),itemId:id(13),exceptionReason:null,size:null}]};
 let committed=null,posts=[],listed=[],errors=[],external=[];
 page.on('pageerror',e=>errors.push(e.message));
 await ctx.route('**/*',async route=>{const req=route.request(),u=new URL(req.url()),p=u.pathname;const json=x=>route.fulfill({contentType:'application/json',body:JSON.stringify(x)});
  if(u.origin!==fixture.origin){external.push(u.origin);return route.abort();}
  if(p.endsWith('/security/me'))return json(current);
  if(p===`/internal/api/commerce/sales/${sale.saleId}`)return json(sale);
  if(p.endsWith('/stock-reviews')){
   if(req.method()==='GET')return json(listed);
   const body=req.postDataJSON(),key=req.headers()['idempotency-key'];assert.ok(req.headers()['x-csrf-token']);posts.push({key,body});
   committed??={...body,responsibleActorId:body.responsibleActorId.toLowerCase(),id:id(24),reviewerId:current.id,causeState:'open',createdAt:'2026-11-06T00:00:00Z'};
   if(posts.length===1)return route.abort('failed');return json(committed);
  }return route.continue();
 });
 async function open(){await page.goto(fixture.origin+'/internal/');await expect(page.locator('#staff-shell')).toBeVisible();await page.locator('[data-target="ventas"]').click();}
 async function load(){await page.locator('#stock-review-load input').fill(sale.saleId);await page.locator('#stock-review-load button').click();}
 try{
  await open();await load();await expect(page.locator('#stock-review-form select')).toHaveValue(line.saleLineId);
  await page.locator('[name="evidence"]').fill('Synthetic records examined');await page.locator('[name="outcome"]').fill('Cause unproven');
  await page.locator('[name="responsibleActorId"]').fill(upper);await page.locator('[name="nextReviewAt"]').fill('2099-11-07T17:00');await page.locator('#stock-review-form button').click();
  await expect(page.locator('#stock-review-status')).toContainText('sin confirmar');
  const raw=await page.evaluate(a=>sessionStorage.getItem(`savia.stock.review.pending.${a}`),current.id);assert.ok(raw);
  await page.reload();await page.locator('[data-target="ventas"]').click();const response=page.waitForResponse(r=>r.request().method()==='POST'&&r.url().endsWith('/stock-reviews'));await page.locator('#stock-review-retry').click();
  await (await response).finished();await page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
  await expect(page.locator('#stock-review-status')).toContainText(phase==='before'?'sin confirmar':'confirmada');assert.equal(posts.length,2);assert.deepEqual(posts[0],posts[1]);assert.equal(posts[0].body.responsibleActorId,upper);
  assert.equal(await page.evaluate(a=>sessionStorage.getItem(`savia.stock.review.pending.${a}`),current.id),phase==='before'?raw:null);
  const listResults=[];
  for(const [kind,saleLineId] of [['foreign',id(99)],['ordinary',id(23)]]){
   await page.evaluate(()=>sessionStorage.clear());listed=[{...committed,saleLineId,evidence:'UNRELATED EVIDENCE'}];await open();await load();
   if(phase==='before')await expect(page.locator('#stock-review-evidence')).toContainText('UNRELATED EVIDENCE');
   else{await expect(page.locator('#stock-review-status')).toContainText('No se pudo consultar');await expect(page.locator('#stock-review-evidence')).toBeEmpty();await expect(page.locator('#stock-review-form button')).toBeDisabled();}
   listResults.push({kind,rejected:phase==='after'});
  }
  listed=[{...committed,reviewerId:id(77),evidence:'FIRST REVIEW'},{...committed,id:id(25),saleLineId:id(22),reviewerId:id(78),evidence:'SECOND REVIEW'}];await open();await load();
  await expect(page.locator('#stock-review-evidence')).toContainText('FIRST REVIEW');await expect(page.locator('#stock-review-evidence')).toContainText('SECOND REVIEW');await expect(page.locator('#stock-review-form button')).toBeEnabled();
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));assert.deepEqual(errors,[]);assert.deepEqual(external,[]);
  results.push({width,height,phase,status:'PASS',observed:phase==='before'?'Defects reproduced':'Regressions corrected',posts:posts.length,unique_reviews:1,exact_pending_request_preserved:true,uppercase_confirmed:phase==='after',listResults,historical_reviewers_preserved:true,errors,external,video:path.relative(out,await page.video().path()),layer:'Actual Chrome / mocked HTTP / no SQL'});
 }finally{await ctx.close();await new Promise(r=>fixture.server.close(r));}
}}finally{await browser.close();await writeFile(path.join(out,'results.json'),JSON.stringify({sources,results},null,2));}
console.log(JSON.stringify(results));
