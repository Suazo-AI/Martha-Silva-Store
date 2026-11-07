import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {setImmediate as checkpoint} from 'node:timers/promises';
import {createAuthClient} from './login.mjs';
import {createStaffClient} from './client.mjs';
import {mountCommerce, mountStockReview} from './app.mjs';
import {mountSupply, PENDING_SUPPLY} from './supply.mjs';
const {JSDOM} = createRequire(import.meta.url)('jsdom');
const html = await readFile(new URL('./index.html', import.meta.url), 'utf8');
const id = n => `10000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const actor = {id:id(1), version:id(9), role:'Manager', enabled:true, loginName:'synthetic', displayName:'Synthetic'};
const item = {id:id(2), sku:'SYN', name:'Synthetic', active:true, unitPriceMinor:100, currency:'NIO'};
const place = {id:id(3), branchId:id(4), name:'Synthetic', active:true};
const saleBody = {locationId:place.id, customerId:null, lines:[{itemId:item.id, quantity:1}]};
const saleResult = {saleId:id(5), actorId:actor.id, locationId:place.id, customerId:null, currency:'NIO', totalMinor:100, state:'recorded', paymentStatus:'not_processed', createdAt:'2026-11-07T00:00:00Z', lines:[{saleLineId:id(6), itemId:item.id, sku:item.sku, name:item.name, quantity:1, returnedQuantity:0, unitPriceMinor:100, totalMinor:100}]};
const order = {id:id(10), supplierId:id(11), supplierName:'Synthetic', locationId:place.id, currency:'NIO', reference:'SYN-1', status:'open', totalMinor:500, createdBy:actor.id, updatedBy:actor.id, createdAt:'2026-11-07T00:00:00Z', updatedAt:'2026-11-07T00:00:00Z', lines:[{id:id(12), itemId:item.id, sku:item.sku, name:item.name, orderedQuantity:5, receivedQuantity:0, remainingReceivableQuantity:5, cancelledQuantity:0, unitCostMinor:100, totalMinor:500}]};
const supplyBody = {receiptId:id(15), lines:[{purchaseOrderLineId:id(12), quantity:2}]};
const supplyResult = {id:id(15), purchaseOrderId:order.id, locationId:place.id, receivedBy:actor.id, currency:'NIO', totalMinor:200, orderStatusAfter:'partially_received', receivedAt:'2026-11-07T00:00:00Z', lines:[{purchaseOrderLineId:id(12), itemId:item.id, quantity:2, unitCostMinor:100}]};
const reviewBody = {saleLineId:id(6), evidence:'examined', outcome:'unproven', responsibleActorId:actor.id, nextReviewAt:'2099-11-07T00:00:00Z'};
const reviewResult = {...reviewBody, id:id(19), reviewerId:actor.id, causeState:'open', createdAt:'2026-11-07T00:00:00Z'};
const lanes = {
 sale:{storage:`savia.sale.pending.${actor.id}`, pending:{key:id(21), actorVersion:actor.version, body:saleBody}, method:'recordSale', button:'sale-retry', path:'/internal/api/commerce/sales', result:saleResult},
 supply:{storage:PENDING_SUPPLY, pending:{schema:1, scope:'supply.receipt.create', key:id(22), actorId:actor.id, actorVersion:actor.version, order, body:supplyBody, rawBody:JSON.stringify(supplyBody)}, method:'receivePurchase', button:'supply-retry', path:`/internal/api/supply/purchase-orders/${order.id}/receipts`, result:supplyResult},
 review:{storage:`savia.stock.review.pending.${actor.id}`, pending:{actorId:actor.id, actorVersion:actor.version, saleId:id(5), key:id(23), body:reviewBody}, method:'reviewStockException', button:'stock-review-retry', path:`/internal/api/commerce/sales/${id(5)}/stock-reviews`, result:reviewResult},
};
const json = (value,status=200) => new Response(JSON.stringify(value), {status,headers:{'Content-Type':'application/json'}});
function gate() { let release; const promise = new Promise(r=>{release=r;}); return {promise,release}; }
// Bounded microtask scheduler: no elapsed-time sleeps. All fixture work is promises.
async function until(predicate,label) { for(let n=0;n<200;n++) { if(predicate()) return; await Promise.resolve(); } assert.fail(`Scheduler did not reach ${label}`); }
async function fixture(t) {
 const dom = new JSDOM(html,{url:'https://staff.example.invalid/internal/'}), document=dom.window.document;
 const storage=dom.window.sessionStorage, calls=[], raw={};
 for(const [name,lane] of Object.entries(lanes)) { raw[name]=` \n${JSON.stringify(lane.pending,null,1)}\n `; storage.setItem(lane.storage,raw[name]); }
 let sessionNumber=0, tokenNumber=0, authenticated=false, failCsrf=false, unauthorized=0;
 let httpHold=null, csrfHold=null, mountHold=null;
 const committed=new Map();
 const fetchImpl=async(path,options)=>{
  calls.push({path,options,sessionNumber});
  if(path.endsWith('/csrf')) {
   const response=json({headerName:'X-CSRF-TOKEN',token:`synthetic-${sessionNumber}-${++tokenNumber}`},failCsrf?503:200);
   if(csrfHold) {const hold=csrfHold;csrfHold=null;hold.entered=true;await hold.promise;}
   return response;
  }
  if(path.endsWith('/login')) {authenticated=true;++sessionNumber;return json({staff:actor,expiresAt:'2099-11-07T00:00:00Z'});}
  if(path.endsWith('/logout')) {authenticated=false;return new Response(null,{status:204});}
  if(path.endsWith('/me')) return json(actor,authenticated?200:401);
  assert.equal(authenticated,true,'Business request requires simulated cookie');
  if(options.method==='POST') {
   const lane=Object.values(lanes).find(l=>l.path===path);assert.ok(lane,`Unexpected POST ${path}`);
   assert.match(options.headers['X-CSRF-TOKEN'],new RegExp(`^synthetic-${sessionNumber}-`));
   const key=options.headers['Idempotency-Key'];
   if(committed.has(key)) assert.equal(committed.get(key),options.body); else committed.set(key,options.body);
   const response=json(lane.result);
   if(httpHold) {const hold=httpHold;httpHold=null;hold.entered=true;await hold.promise;}
   return response;
  }
  if(path.includes('/operations/')) return json({},404);
  if(path.includes('/directory/')) {const u=new URL(path,'https://staff.example.invalid'), rows=path.includes('/items')?[item]:[place];return json({items:rows,total:1,skip:Number(u.searchParams.get('skip')),take:Number(u.searchParams.get('take'))});}
  if(path.includes('/commerce/inventory')) return json({items:[],total:0,skip:0,take:100});
  if(path===`/internal/api/supply/purchase-orders/${order.id}`) return json(order);
  if(path.includes('/supply/purchase-orders')) return json({items:path.includes('/receipts')?[]:[order],skip:0,take:50,hasMore:false});
  assert.fail(`Unexpected HTTP ${path}`);
 };
 const login=createAuthClient({fetchImpl});
 const staff=createStaffClient({fetchImpl,onUnauthorized:()=>{unauthorized++;}});
 // Real staff methods and their validators run before the optional mount-only scheduler gate.
 const client={...staff}, outcomes=[];
 for(const lane of Object.values(lanes)) client[lane.method]=async(...args)=>{
  try {
   const result=await staff[lane.method](...args);
   if(mountHold) {const hold=mountHold;mountHold=null;hold.entered=true;await hold.promise;}
   outcomes.push({method:lane.method,status:'fulfilled'});return result;
  } catch(error) {outcomes.push({method:lane.method,status:'rejected',code:error.code});throw error;}
 };
 let mounts=[];
 const getSession=()=>staff.getVerifiedSession();
 const mount=async()=>{
  const args={document,client,getSession,onUnauthorized:()=>{unauthorized++;}};
  mounts=[mountCommerce(args),mountSupply(args),mountStockReview(args)];
  await Promise.all(mounts.map(m=>m.start()));
 };
 const destroy=()=>{mounts.forEach(m=>m.destroy());mounts=[];};
 const signIn=async()=>{await login.login({loginName:'synthetic',password:'synthetic-only'});await staff.getSession();};
 await signIn();await mount();
 t.after(()=>{destroy();dom.window.close();});
 const posts=()=>calls.filter(c=>c.options.method==='POST'&&!c.path.includes('/security/'));
 const exact=()=>{for(const [name,lane] of Object.entries(lanes))assert.equal(storage.getItem(lane.storage),raw[name],`${name}: exact stored reference`);};
 const snapshot=()=>({html:document.body.innerHTML,storage:Object.fromEntries(Object.keys(storage).map(k=>[k,storage.getItem(k)])),session:getSession(),unauthorized});
 const transition=async()=>{destroy();await staff.logout();await signIn();await mount();assert.deepEqual(getSession(),actor);};
 const ready=async name=>{if(name==='supply'){document.getElementById('supply-recover').click();await until(()=>!document.getElementById('supply-retry').hidden,'supply recovery 404');}};
 const click=name=>document.getElementById(lanes[name].button).click();
 const idle=async name=>{await until(()=>!document.getElementById(lanes[name].button).disabled,`${name} pending retry enabled`);};
 return {document,storage,raw,client,staff,login,calls,posts,committed,outcomes,exact,snapshot,transition,ready,click,idle,getSession,
  holdHttp:()=>httpHold=gate(),holdCsrf:()=>csrfHold=gate(),holdMount:()=>mountHold=gate(),failRenewal:value=>{failCsrf=value;}};
}

test('same account/version logout and login preserves all three exact references without automatic POST',async t=>{
 const s=await fixture(t);s.exact();assert.equal(s.posts().length,0);
 await s.transition();s.exact();assert.equal(s.posts().length,0);
 for(const lane of Object.values(lanes)) assert.equal(JSON.stringify(lane.pending).includes('sessionId'),false);
});

for(const name of Object.keys(lanes)) {
 test(`${name}: failed renewal preserves all raw references; explicit continuation uses fresh token and original identity once`,async t=>{
  const s=await fixture(t);await s.transition();await s.ready(name);s.failRenewal(true);
  const before=s.calls.length;s.click(name);
  await until(()=>s.calls.length>before,'failed renewal request');await s.idle(name);
  s.exact();assert.equal(s.posts().length,0);s.failRenewal(false);
  // Supply requires a new explicit recovery after the failed send hides its retry.
  await s.ready(name);s.click(name);s.click(name);
  await until(()=>s.storage.getItem(lanes[name].storage)===null,'confirmed continuation');
  assert.equal(s.posts().length,1);assert.equal(s.committed.size,1);
  const post=s.posts()[0],lane=lanes[name];
  assert.equal(post.options.headers['Idempotency-Key'],lane.pending.key);
  assert.equal(post.options.body,JSON.stringify(lane.pending.body));
  assert.match(post.options.headers['X-CSRF-TOKEN'],/^synthetic-2-/);
  for(const other of Object.keys(lanes).filter(n=>n!==name))assert.equal(s.storage.getItem(lanes[other].storage),s.raw[other]);
 });
 test(`${name}: old-session CSRF renewal released after new login cannot send a POST or change current state`,async t=>{
  const s=await fixture(t);await s.ready(name);const hold=s.holdCsrf();s.click(name);
  await until(()=>hold.entered,'held old CSRF');await s.transition();s.exact();
  const before=s.snapshot();hold.release();
  // One event-loop checkpoint drains the released promise chain and mount continuations.
  await checkpoint();
  assert.deepEqual(s.snapshot(),before);s.exact();assert.equal(s.posts().length,0);
  assert.deepEqual(s.outcomes.at(-1),{method:lanes[name].method,status:'rejected',code:'unauthorized'});
  await s.ready(name);s.click(name);await until(()=>s.storage.getItem(lanes[name].storage)===null,'fresh continuation after stale renewal');
  assert.equal(s.posts().length,1);assert.match(s.posts()[0].options.headers['X-CSRF-TOKEN'],/^synthetic-2-/);
 });
 for(const boundary of ['HTTP','mount']) test(`${name}: old-session business response at ${boundary} cannot mutate remounted current state`,async t=>{
  const s=await fixture(t);await s.ready(name);const hold=boundary==='HTTP'?s.holdHttp():s.holdMount();s.click(name);
  await until(()=>hold.entered,`held ${boundary} response`);assert.equal(s.posts().length,1);
  await s.transition();s.exact();const before=s.snapshot();hold.release();
  await checkpoint();
  assert.deepEqual(s.snapshot(),before);s.exact();assert.equal(s.posts().length,1);assert.equal(s.committed.size,1);
  assert.deepEqual(s.outcomes.at(-1),boundary==='HTTP'
   ? {method:lanes[name].method,status:'rejected',code:'unauthorized'}
   : {method:lanes[name].method,status:'fulfilled'});
 });
}
