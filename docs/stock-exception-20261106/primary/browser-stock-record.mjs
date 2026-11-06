import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
import {serve,id,actor} from '../../../tests/fixtures/supply-browser.mjs';
const {chromium}=await import(pathToFileURL(path.resolve(process.argv[2],'index.mjs')));
const {expect}=await import(pathToFileURL(path.resolve(process.argv[2],'test.mjs')));
const out=path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Z]:)/,'$1'));
const browser=await chromium.launch({channel:'chrome',headless:true,args:['--disable-background-networking']});
const results=[],sources={};
for(const name of ['app.mjs','client.mjs','login.mjs','index.html','styles.css'])sources[name]=createHash('sha256').update(await readFile('dev/savia-staff-ui/'+name)).digest('hex');
try{for(const width of [1440,390]){
 const fixture=await serve();const ctx=await browser.newContext({viewport:{width,height:width===390?844:1000},recordVideo:{dir:path.join(out,'videos'),size:{width,height:width===390?844:1000}},serviceWorkers:'block'});const page=await ctx.newPage();page.setDefaultTimeout(5000);
 let current={...actor,role:'Cashier'},sale=null,review=null,salePosts=0,reviewPosts=[],operations=new Map(),errors=[],external=[];
 const item={id:id(2),sku:'SINTETICO-EX',name:'Synthetic physical garment',active:true,unitPriceMinor:1250,currency:'USD'};
 page.on('pageerror',e=>errors.push(e.message));
 await ctx.route('**/*',async route=>{const req=route.request(),u=new URL(req.url()),p=u.pathname;const json=x=>route.fulfill({contentType:'application/json',body:JSON.stringify(x)});
  if(u.origin!==fixture.origin){external.push(u.origin);return route.abort();}
  if(p.endsWith('/security/me'))return json(current);
  if(p.endsWith('/directory/items'))return json({items:[item],total:1,skip:0,take:100});
  if(p.endsWith('/stock-reviews')){if(req.method()==='GET')return json(review?[review]:[]);const b=req.postDataJSON(),key=req.headers()['idempotency-key'];reviewPosts.push({key,body:b});assert.ok(req.headers()['x-csrf-token']);
   review??={...b,id:id(22),reviewerId:current.id,causeState:'open',createdAt:'2026-11-06T00:00:00Z'};if(reviewPosts.length===1)return route.abort('failed');return json(review);}
  if(p.endsWith('/operations/commerce.sale.record'))return json({status:'completed',result:{success:true,error:null,value:sale}});
  if(p.endsWith('/commerce/sales')&&req.method()==='POST'){salePosts++;const b=req.postDataJSON();assert.equal(b.lines[0].exceptionReason,'Synthetic physical garment present');assert.equal(b.lines[0].size,'S');assert.ok(req.headers()['x-csrf-token']);
   sale={saleId:id(20),actorId:current.id,locationId:id(3),customerId:null,currency:'USD',totalMinor:1250,state:'recorded',paymentStatus:'not_processed',createdAt:'2026-11-06T00:00:00Z',lines:[{saleLineId:id(21),itemId:item.id,sku:item.sku,name:item.name,quantity:1,returnedQuantity:0,unitPriceMinor:1250,totalMinor:1250,exceptionReason:b.lines[0].exceptionReason,size:'S'}]};return route.abort('failed');}
  if(p===`/internal/api/commerce/sales/${id(20)}`)return json(sale);
  return route.continue();});
 try{await page.goto(fixture.origin+'/internal/');await expect(page.locator('#staff-shell')).toBeVisible();await page.locator('[data-target="ventas"]').click();await expect(page.locator('#sale-submit')).toBeEnabled();
  await page.locator('[data-exception]').check();await page.locator('#sale-submit').click();assert.equal(salePosts,0);
  await page.locator('[data-exception-reason]').fill('Synthetic physical garment present');await page.locator('[data-exception-size]').fill('S');await page.locator('#sale-submit').click();await expect(page.locator('#sale-recover')).toBeVisible();
  await page.reload();await page.locator('[data-target="ventas"]').click();await expect(page.locator('#sale-receipt')).toContainText(sale.saleId);await expect(page.locator('#sale-receipt')).toContainText('Causa abierta');assert.equal(salePosts,1);
  current={...actor,id:id(8),role:'Manager'};await page.reload();await page.locator('[data-target="ventas"]').click();await page.locator('#stock-review-load input').fill(sale.saleId);await page.locator('#stock-review-load button').click();await expect(page.locator('#stock-review-form select')).toHaveValue(id(21));
  await page.locator('[name="evidence"]').fill('Synthetic sale and physical count examined');await page.locator('[name="outcome"]').fill('Synthetic cause unproven');await page.locator('[name="responsibleActorId"]').fill(current.id);await page.locator('[name="nextReviewAt"]').fill('2099-11-07T17:00');await page.locator('#stock-review-form button').click();await expect(page.locator('#stock-review-retry')).toBeVisible();
  await page.reload();await page.locator('[data-target="ventas"]').click();await page.locator('#stock-review-retry').click();await expect(page.locator('#stock-review-status')).toContainText('confirmada');assert.equal(reviewPosts.length,2);assert.deepEqual(reviewPosts[0],reviewPosts[1]);assert.notEqual(review.reviewerId,sale.actorId);
  await page.locator('#stock-review-load input').fill(sale.saleId);await page.locator('#stock-review-load button').click();await expect(page.locator('#stock-review-evidence')).toContainText(review.id);
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await page.screenshot({path:path.join(out,`stock-review-${width}.png`),fullPage:true});assert.deepEqual(errors,[]);assert.deepEqual(external,[]);
  results.push({width,status:'PASS',sale_posts:salePosts,review_posts:reviewPosts.length,unique_reviews:1,layer:'Actual Chrome / mocked HTTP / no SQL'});
 }finally{await ctx.close();await new Promise(r=>fixture.server.close(r));}
}}finally{await browser.close();await writeFile(path.join(out,'browser-stock-results.json'),JSON.stringify({sources,results},null,2));}
console.log(JSON.stringify(results));
