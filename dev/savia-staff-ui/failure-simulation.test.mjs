// Synthetic fault injection into real staff modules. No socket, SQL, browser or device proof.
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {mountCommerce} from './app.mjs';
import {createStaffClient, readReceipt} from './client.mjs';
import {StaffRequestError} from './login.mjs';
const {JSDOM} = createRequire(import.meta.url)('jsdom');
const html = await readFile(new URL('./index.html', import.meta.url), 'utf8');
const id = n => `00000001-0000-0000-0000-${String(n).padStart(12, '0')}`;
const actor = {id:id(1),version:id(9),role:'Owner',enabled:true,loginName:'synthetic',displayName:'Synthetic'};
const place = {id:id(3),branchId:id(4),name:'Synthetic location',active:true};
const items = [2,20,30].map(n => ({id:id(n),sku:`SYN-${n}`,name:`Synthetic ${n}`,active:true,unitPriceMinor:100,currency:'NIO'}));
const pendingKey = `savia.sale.pending.${actor.id}`, receiptKey = `savia.sale.receipt.${actor.id}`;
const body = {locationId:place.id,customerId:null,lines:[{itemId:items[0].id,quantity:2},{itemId:items[1].id,quantity:3}]};
const clone = value => JSON.parse(JSON.stringify(value));
const json = (value, status=200) => new Response(JSON.stringify(value), {status,headers:{'Content-Type':'application/json'}});
function receiptFor(request, sale=50) {
  const lines = request.lines.map((line,n) => ({...line,saleLineId:id(100+n),sku:`SYN-${n}`,name:`Synthetic ${n}`,returnedQuantity:0,unitPriceMinor:100,totalMinor:line.quantity*100}));
  return {saleId:id(sale),actorId:actor.id,locationId:request.locationId,customerId:null,currency:'NIO',state:'recorded',paymentStatus:'not_processed',createdAt:'2026-11-05T00:00:00Z',totalMinor:lines.reduce((sum,l)=>sum+l.totalMinor,0),lines};
}
function held() { let resolve, reject; const promise = new Promise((yes,no)=>{resolve=yes;reject=no;}); return {promise,resolve,reject}; }
async function until(check) {
  for(let n=0;n<50;n++) { if(check()) return; await new Promise(resolve=>setImmediate(resolve)); }
  assert.fail('Harness could not observe expected settled state within 50 event-loop turns');
}
async function drain() { for(let n=0;n<8;n++) await new Promise(resolve=>setImmediate(resolve)); }
async function setup(t, effects={}) {
  const dom = new JSDOM(html,{url:'https://staff.example.invalid/internal/'});
  const document = dom.window.document, calls=[];
  let app, session=actor, revoked=0;
  // All HTTP effects terminate here. No real fetch fallback exists.
  const client = createStaffClient({onUnauthorized:()=>{session=null;revoked++;app?.clear();},fetchImpl:async(path, options)=>{
    const call={path,method:options.method,key:options.headers['Idempotency-Key'],body:options.body===undefined?undefined:JSON.parse(options.body)};
    calls.push(call);
    if(path.endsWith('/me')) return json(actor);
    if(path.endsWith('/csrf')) return effects.csrf ? effects.csrf(call) : json({headerName:'X-CSRF-TOKEN',token:'synthetic-csrf'});
    if(path.startsWith('/internal/api/directory/')) {
      const u=new URL(path,'https://staff.example.invalid'), rows=u.pathname.endsWith('/items')?items:[place];
      return json({items:rows,total:rows.length,skip:Number(u.searchParams.get('skip')),take:Number(u.searchParams.get('take'))});
    }
    if(path.includes('/inventory?')) return effects.stock ? effects.stock(call) : json({items:[],total:0,skip:0,take:100});
    if(path==='/internal/api/commerce/sales' && call.method==='POST') return effects.post ? effects.post(call) : json(receiptFor(call.body));
    if(path==='/internal/api/operations/commerce.sale.record') return effects.recover ? effects.recover(call) : json({},404);
    if(path.startsWith('/internal/api/commerce/sales/')) return effects.sale ? effects.sale(call) : json({},404);
    assert.fail(`Unexpected mock HTTP route: ${path}`);
  }});
  await client.getSession();
  app=mountCommerce({document,client,getSession:()=>session,onUnauthorized:()=>{session=null;revoked++;app.clear();}});
  t.after(()=>{app.destroy();dom.window.close();});
  const $=id=>document.getElementById(id);
  const submit=()=>$('sale-form').dispatchEvent(new dom.window.Event('submit',{bubbles:true,cancelable:true}));
  const fill=(request=body)=>{
    $('sale-item').value=request.lines[0].itemId; $('sale-quantity').value=String(request.lines[0].quantity);
    for(let n=1;n<request.lines.length;n++) { $('sale-add').click(); $(`sale-item-${n+1}`).value=request.lines[n].itemId; $(`sale-quantity-${n+1}`).value=String(request.lines[n].quantity); }
  };
  return {app,client,dom,$,submit,fill,calls,posts:()=>calls.filter(c=>c.method==='POST'),store:dom.window.sessionStorage,revoked:()=>revoked};
}
function persist(s) { const op={key:id(8),body:clone(body),actorVersion:actor.version};s.store.setItem(pendingKey,JSON.stringify(op));return op; }
function pending(s, expected) {
  assert.deepEqual(JSON.parse(s.store.getItem(pendingKey)),expected);
  assert.equal(s.$('sale-submit').disabled,true);
  assert.equal(s.$('sale-receipt').hidden,true);
}
function confirmed(s, sale=id(50)) {
  assert.equal(s.store.getItem(pendingKey),null);
  assert.equal(s.store.getItem(receiptKey),sale);
  assert.equal(s.$('sale-receipt').hidden,false);
  assert.match(s.$('sale-receipt').textContent,new RegExp(sale));
  assert.equal(s.$('sale-submit').disabled,false);
}

test('F01 held pending recovery blocks submit and retry until original recovery completes', async t=>{
  const gate=held(); const s=await setup(t,{recover:()=>gate.promise}); const op=persist(s);
  const start=s.app.start(); await until(()=>s.calls.some(c=>c.path.includes('/operations/')));
  s.submit();s.$('sale-retry').click();pending(s,op);assert.equal(s.posts().length,0);
  assert.equal(s.$('sale-recover').disabled,true);
  gate.resolve(json({status:'completed',result:{success:true,value:receiptFor(body),error:null}}));await start;
  confirmed(s);assert.equal(s.posts().length,0);
  const recovery=s.calls.find(c=>c.path.includes('/operations/'));assert.equal(recovery.key,op.key);
});

test('F02 obsolete receipt discard permits a complete new multiarticle sale',async t=>{
  const s=await setup(t);s.store.setItem(receiptKey,id(99));await s.app.start();
  assert.equal(s.store.getItem(receiptKey),null);assert.equal(s.$('sale-submit').disabled,false);
  s.fill();s.submit();await until(()=>!s.$('sale-receipt').hidden);
  assert.equal(s.posts().length,1);assert.deepEqual(s.posts()[0].body,body);confirmed(s);
});

test('F03 late obsolete404 from an earlier generation cannot erase a newer pending sale',async t=>{
  const old=held(), post=held();const s=await setup(t,{sale:()=>old.promise,post:()=>post.promise});
  s.store.setItem(receiptKey,id(99));const first=s.app.start();await until(()=>s.calls.some(c=>c.path.endsWith(`/sales/${id(99)}`)));
  // Same-generation start keeps busy=true. Clear/start is the public generation boundary.
  s.submit();assert.equal(s.posts().length,0);
  s.app.clear();s.store.removeItem(receiptKey);await s.app.start();s.fill();s.submit();await until(()=>s.posts().length===1);
  const op=JSON.parse(s.store.getItem(pendingKey));old.resolve(json({},404));await first;
  pending(s,op);assert.equal(s.posts().length,1);
  post.resolve(json(receiptFor(body,51)));await until(()=>!s.$('sale-receipt').hidden);confirmed(s,id(51));
});

test('F04 response loss retry and reload preserve original full body and key',async t=>{
  const attempts=[];const s=await setup(t,{post:call=>{attempts.push(clone(call));throw new Error('synthetic response loss');},recover:()=>json({},404)});
  await s.app.start();s.fill();s.submit();await until(()=>!s.$('sale-retry').disabled);
  const op=JSON.parse(s.store.getItem(pendingKey));pending(s,op);
  s.$('sale-quantity-2').value='99';s.$('sale-retry').click();await until(()=>attempts.length===2);await drain();
  assert.deepEqual(attempts[1],attempts[0]);assert.deepEqual(attempts[0].body,body);assert.equal(attempts[0].key,op.key);
  const reload=await setup(t,{recover:call=>{assert.equal(call.key,op.key);return json({status:'completed',result:{success:true,value:receiptFor(body),error:null}});}});
  reload.store.setItem(pendingKey,s.store.getItem(pendingKey));await reload.app.start();confirmed(reload);
  assert.equal(s.posts().length,2);assert.equal(reload.posts().length,0);
  assert.match(reload.$('sale-receipt').textContent,/SYN-0/);assert.match(reload.$('sale-receipt').textContent,/SYN-1/);
});

test('F05 delayed POST double submit sends exactly one full operation',async t=>{
  const gate=held();const s=await setup(t,{post:()=>gate.promise});await s.app.start();s.fill();s.submit();s.submit();
  await until(()=>s.posts().length===1);const op=JSON.parse(s.store.getItem(pendingKey));pending(s,op);
  assert.deepEqual(s.posts()[0].body,body);assert.equal(s.posts()[0].key,op.key);
  gate.resolve(json(receiptFor(body)));await until(()=>!s.$('sale-receipt').hidden);confirmed(s);assert.equal(s.posts().length,1);
});

test('F06 failed pending storage prevents initial and retry POST',async t=>{
  const s=await setup(t);await s.app.start();s.fill();
  Object.defineProperty(s.dom.window,'sessionStorage',{value:{getItem:()=>null,setItem:()=>{throw Error('synthetic storage denied');},removeItem:()=>{}}});
  s.submit();s.$('sale-retry').click();await drain();assert.equal(s.posts().length,0);
  assert.equal(s.$('sale-submit').disabled,true);assert.equal(s.$('sale-retry').disabled,true);assert.equal(s.$('sale-receipt').hidden,true);
});

test('F07 revoked session rejects a late POST response without repopulating DOM',async t=>{
  const stock={items:[{itemId:items[0].id,locationId:place.id,onHand:10,reserved:0,available:10}],total:1,skip:0,take:100};
  const gate=held();let revoke=false;const s=await setup(t,{post:()=>gate.promise,stock:()=>revoke?json({},401):json(stock)});
  await s.app.start();assert.match(s.$('stock-table').textContent,/SYN-2/);
  s.fill();s.submit();await until(()=>s.posts().length===1);
  const original=s.store.getItem(pendingKey);revoke=true;await s.app.loadStock();assert.ok(s.revoked()>0);
  gate.resolve(json(receiptFor(body)));await drain();
  assert.equal(s.client.getVerifiedSession(),null);assert.equal(s.$('sale-receipt').hidden,true);
  assert.equal(s.$('sale-receipt').textContent,'');assert.equal(s.$('stock-table').textContent,'');
  assert.equal(s.$('sale-submit').disabled,true);assert.equal(s.store.getItem(pendingKey),original);assert.equal(s.store.getItem(receiptKey),null);
  assert.equal(s.posts().length,1);
});

test('F08 operation404 remains pending; durable rejected outcome unlocks without POST',async t=>{
  let reject=false;const s=await setup(t,{recover:()=>reject?json({status:'completed',result:{success:false,value:null,error:'stock_unavailable'}}):json({},404)});
  const op=persist(s);await s.app.start();pending(s,op);assert.equal(s.posts().length,0);
  reject=true;s.$('sale-recover').click();await until(()=>s.store.getItem(pendingKey)===null);
  assert.equal(s.$('sale-submit').disabled,false);assert.equal(s.$('sale-receipt').hidden,true);assert.equal(s.posts().length,0);
  assert.match(s.$('sale-status').textContent,/rechazada/);
});

const corruptions = {
  malformed:r=>{r.lines[0]=null;},
  missing:r=>{r.lines.pop();r.totalMinor=r.lines.reduce((sum,l)=>sum+l.totalMinor,0);},
  duplicateItem:r=>{r.lines[1].itemId=r.lines[0].itemId;},
  duplicateLine:r=>{r.lines[1].saleLineId=r.lines[0].saleLineId;},
  alteredTotal:r=>{r.totalMinor++;},
  alteredQuantity:r=>{r.lines[0].quantity++;r.lines[0].totalMinor+=100;r.totalMinor+=100;},
  wrongLocation:r=>{r.locationId=id(88);},
  fractional:r=>{r.lines[0].quantity=1.5;r.lines[0].totalMinor=150;r.totalMinor=r.lines.reduce((sum,l)=>sum+l.totalMinor,0);},
};
test('F09 corrupted HTTP receipts cannot confirm or clear original operation',async t=>{
  for(const [name,mutate] of Object.entries(corruptions)) await t.test(name,async t=>{
    const bad=receiptFor(body);mutate(bad);assert.throws(()=>readReceipt(bad,body),StaffRequestError);
    const s=await setup(t,{post:()=>json(bad)});await s.app.start();s.fill();s.submit();
    await until(()=>!s.$('sale-retry').disabled);const op=JSON.parse(s.store.getItem(pendingKey));pending(s,op);
    assert.equal(s.posts().length,1);assert.equal(s.store.getItem(receiptKey),null);assert.deepEqual(s.posts()[0].body,body);
  });
});

test('F10 deterministic receipt/quantity sweep: 32 seeds, 192 explicit actions, 8 fault classes',async t=>{
  // Formula is deterministic and injective in first quantity for seeds 1..32.
  // Six actions per seed: build body, build receipt, reorder, accept valid, corrupt, reject corrupt.
  // These are 32 parameter samples, not 32 independent business scenarios.
  const variants=Object.entries(corruptions);
  for(let seed=1;seed<=32;seed++) await t.test(`seed=${seed}`,()=>{
    const request={...body,lines:[{itemId:items[0].id,quantity:seed},{itemId:items[1].id,quantity:1+(seed*17)%100000}]};
    const receipt=receiptFor(request);if(seed%2) receipt.lines.reverse();
    const [fault,mutate]=variants[(seed-1)%variants.length];
    const sequence=['build-body','build-receipt',seed%2?'reverse-lines':'preserve-order','validate-valid',`inject:${fault}`,'validate-corrupt'];
    try { assert.equal(readReceipt(receipt,request).saleId,id(50));const bad=clone(receipt);mutate(bad);assert.throws(()=>readReceipt(bad,request),StaffRequestError); }
    catch(error) { error.message=`seed=${seed}; shortest fixed receipt repro=${JSON.stringify(sequence)}; ${error.message}`;throw error; }
  });
});
