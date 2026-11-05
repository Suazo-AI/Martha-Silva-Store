import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {mountCommerce} from './app.mjs';
import {createStaffClient, readReceipt, validateSaleRequest} from './client.mjs';
import {StaffRequestError} from './login.mjs';
const {JSDOM}=createRequire(import.meta.url)('jsdom');
const html=await readFile(new URL('./index.html',import.meta.url),'utf8');
const id=n=>`00000001-0000-0000-0000-${String(n).padStart(12,'0')}`;
const actor={id:id(1),role:'Owner',enabled:true,loginName:'synthetic',displayName:'Synthetic',version:id(9)};
const item={id:id(2),sku:'SYN-S',name:'Synthetic S',active:true};
const place={id:id(3),branchId:id(4),name:'Paseo',active:true};
const body={locationId:place.id,customerId:null,lines:[{itemId:item.id,quantity:1}]};
const receipt={saleId:id(5),actorId:actor.id,locationId:place.id,customerId:null,currency:'NIO',totalMinor:10000,state:'recorded',paymentStatus:'not_processed',createdAt:'2026-10-31T20:00:00Z',lines:[{saleLineId:id(6),itemId:item.id,sku:item.sku,name:item.name,quantity:1,returnedQuantity:0,unitPriceMinor:10000,totalMinor:10000}]};
const flush=()=>new Promise(r=>setTimeout(r,0));
function setup(t,overrides={}) {
  const dom=new JSDOM(html,{url:'https://staff.example.invalid/internal/'}),document=dom.window.document;
  let session=actor, unauthorized=0;
  const client={listItems:async()=>({items:[item],total:1}),listLocations:async()=>({items:[place],total:1}),
    listInventory:async location=>({items:[{itemId:item.id,locationId:location,onHand:3,reserved:0,available:3}],total:1}),
    recordSale:async()=>receipt,recoverSale:async()=>receipt,getSale:async()=>receipt,...overrides};
  const app=mountCommerce({document,client,getSession:()=>session,onUnauthorized:()=>{unauthorized++;session=null;app.clear();}});
  t.after(()=>{app.destroy();dom.window.close();});
  const submit=()=>document.getElementById('sale-form').dispatchEvent(new dom.window.Event('submit',{bubbles:true,cancelable:true}));
  return {app,document,window:dom.window,submit,unauthorized:()=>unauthorized};
}
test('stock comes from the selected location and absent balances are not invented',async t=>{
  const seen=[];const s=setup(t,{listLocations:async()=>({items:[place,{...place,id:id(7),name:'Natura'}],total:2}),listInventory:async location=>{seen.push(location);return {items:[],total:0};}});
  await s.app.start();assert.match(s.document.getElementById('stock-table').textContent,/No hay saldos/);
  const select=s.document.getElementById('stock-location');select.value=id(7);select.dispatchEvent(new s.window.Event('change'));await flush();
  assert.deepEqual(seen,[place.id,id(7)]);
});
test('double submit sends one frozen sale and displays only a confirmed receipt',async t=>{
  const calls=[];let complete;const s=setup(t,{recordSale:(key,payload)=>{calls.push({key,payload});return new Promise(r=>complete=r);}});
  await s.app.start();s.submit();s.submit();assert.equal(calls.length,1);
  assert.equal(s.document.getElementById('sale-receipt').hidden,true);
  assert.deepEqual(calls[0].payload,body);assert.ok(s.window.sessionStorage.getItem(`savia.sale.pending.${actor.id}`));
  complete(receipt);await flush();assert.match(s.document.getElementById('sale-receipt').textContent,/Recibo confirmado/);
  assert.equal(s.window.sessionStorage.getItem(`savia.sale.pending.${actor.id}`),null);
});
test('lost response locks a new sale; retry reuses the exact key and payload',async t=>{
  const calls=[];const s=setup(t,{recordSale:async(key,payload)=>{calls.push({key,payload});if(calls.length===1)throw new StaffRequestError('unavailable');return receipt;}});
  await s.app.start();s.submit();await flush();assert.equal(s.document.getElementById('sale-submit').disabled,true);
  s.submit();assert.equal(calls.length,1);s.document.getElementById('sale-retry').click();await flush();
  assert.equal(calls.length,2);assert.deepEqual(calls[1],calls[0]);assert.equal(s.document.getElementById('sale-submit').disabled,false);
});
test('reload recovers an unresolved operation without sending a second sale',async t=>{
  let writes=0,recovered=0;const s=setup(t,{recordSale:async()=>{writes++;return receipt;},recoverSale:async(key,payload)=>{recovered++;assert.equal(key,id(8));assert.deepEqual(payload,body);return receipt;}});
  s.window.sessionStorage.setItem(`savia.sale.pending.${actor.id}`,JSON.stringify({key:id(8),body}));await s.app.start();
  assert.equal(writes,0);assert.equal(recovered,1);assert.match(s.document.getElementById('sale-receipt').textContent,/Recibo confirmado/);
});
test('operation not found keeps the original operation unresolved',async t=>{
  const s=setup(t,{recoverSale:async()=>{throw new StaffRequestError('invalid',404);}});
  s.window.sessionStorage.setItem(`savia.sale.pending.${actor.id}`,JSON.stringify({key:id(8),body}));await s.app.start();
  assert.equal(s.document.getElementById('sale-submit').disabled,true);assert.equal(s.document.getElementById('sale-retry').hidden,false);
});
test('401 clears rendered stock, receipt and controls',async t=>{
  const s=setup(t,{recordSale:async()=>{throw new StaffRequestError('unauthorized',401);}});await s.app.start();s.submit();await flush();
  assert.equal(s.unauthorized(),1);assert.equal(s.document.getElementById('stock-table').textContent,'');assert.equal(s.document.getElementById('sale-submit').disabled,true);
});
test('unavailable durable operation storage prevents both the initial write and retry',async t=>{
  let writes=0;const s=setup(t,{recordSale:async()=>{writes++;return receipt;}});await s.app.start();
  Object.defineProperty(s.window,'sessionStorage',{value:{getItem(){return null;},setItem(){throw Error('storage disabled');}}});
  s.submit();await flush();s.document.getElementById('sale-retry').click();await flush();
  assert.equal(writes,0);assert.equal(s.document.getElementById('sale-submit').disabled,true);assert.equal(s.document.getElementById('sale-retry').disabled,true);
});
test('late stock response cannot repopulate a cleared session',async t=>{
  let complete;const s=setup(t,{listInventory:()=>new Promise(r=>complete=r)});const start=s.app.start();await flush();s.app.clear();complete({items:[{itemId:item.id,onHand:3}],total:1});await start;
  assert.equal(s.document.getElementById('stock-table').textContent,'');
});
test('receipt validation rejects mismatched quantity, actor-independent arithmetic and unknown payment status',()=>{
  assert.equal(readReceipt(receipt,body).saleId,receipt.saleId);
  for(const wrong of [{...receipt,totalMinor:1},{...receipt,paymentStatus:'paid'},{...receipt,lines:[{...receipt.lines[0],quantity:2}]}]) assert.throws(()=>readReceipt(wrong,body),StaffRequestError);
});
test('commerce transport uses fresh CSRF and original idempotency key without client prices',async()=>{
  const calls=[];const json=value=>new Response(JSON.stringify(value),{headers:{'Content-Type':'application/json'}});
  const client=createStaffClient({fetchImpl:async(path,options)=>{calls.push({path,...options});if(path.endsWith('/me'))return json(actor);if(path.endsWith('/csrf'))return json({headerName:'X-CSRF-TOKEN',token:'synthetic-csrf'});return json(receipt);}});
  await client.getSession();await client.recordSale(id(8),body);
  assert.deepEqual(calls.map(x=>x.path),['/internal/api/security/me','/internal/api/security/csrf','/internal/api/commerce/sales']);
  assert.equal(calls[2].headers['Idempotency-Key'],id(8));assert.equal(calls[2].headers['X-CSRF-TOKEN'],'synthetic-csrf');assert.deepEqual(JSON.parse(calls[2].body),body);
});

function recoveryClient(outcome) {
  const json=value=>new Response(JSON.stringify(value),{headers:{'Content-Type':'application/json'}});
  return createStaffClient({fetchImpl:async path=>path.endsWith('/me')?json(actor):json({status:'completed',result:outcome})});
}
test('recovery decodes the real successful command envelope',async()=>{
  const client=recoveryClient({success:true,value:receipt,error:null});await client.getSession();
  assert.equal((await client.recoverSale(id(8),body)).saleId,receipt.saleId);
});
test('confirmed rejected command unlocks the form and clears only its pending reference',async t=>{
  const client=recoveryClient({success:false,value:null,error:'stock_unavailable'});await client.getSession();
  const s=setup(t,{recoverSale:client.recoverSale});
  s.window.sessionStorage.setItem(`savia.sale.pending.${actor.id}`,JSON.stringify({key:id(8),body}));
  await s.app.start();
  assert.equal(s.window.sessionStorage.getItem(`savia.sale.pending.${actor.id}`),null);
  assert.equal(s.document.getElementById('sale-submit').disabled,false);
  assert.equal(s.document.getElementById('sale-receipt').hidden,true);
  assert.match(s.document.getElementById('sale-status').textContent,/rechazada/);
});
test('malformed completed outcome stays unresolved and cannot unlock a new sale',async t=>{
  const client=recoveryClient({success:false,value:receipt,error:'stock_unavailable'});await client.getSession();
  const s=setup(t,{recoverSale:client.recoverSale});
  const original=JSON.stringify({key:id(8),body});s.window.sessionStorage.setItem(`savia.sale.pending.${actor.id}`,original);
  await s.app.start();assert.equal(s.window.sessionStorage.getItem(`savia.sale.pending.${actor.id}`),original);
  assert.equal(s.document.getElementById('sale-submit').disabled,true);
});

const second={...item,id:id(20),sku:'SYN-M',name:'Synthetic M'};
const multiBody={...body,lines:[{itemId:item.id,quantity:2},{itemId:second.id,quantity:3}]};
const multiReceipt={...receipt,totalMinor:50000,lines:[{...receipt.lines[0],quantity:2,totalMinor:20000},
  {...receipt.lines[0],saleLineId:id(21),itemId:second.id,sku:second.sku,name:second.name,quantity:3,totalMinor:30000}]};
const twoItems={listItems:async()=>({items:[item,second],total:2})};
function fillMulti(s) {
  s.document.getElementById('sale-quantity').value='2';
  s.document.getElementById('sale-add').click();
  s.document.getElementById('sale-quantity-2').value='3';
}

test('multiarticle cart adds, edits and removes either row without losing remaining quantities',async t=>{
  const s=setup(t,twoItems); await s.app.start(); fillMulti(s);
  assert.equal(s.document.getElementById('sale-item-2').value,second.id);
  assert.equal(s.document.getElementById('sale-add').disabled,true);
  s.document.querySelector('[data-sale-remove="0"]').click();
  assert.equal(s.document.getElementById('sale-item').value,second.id);
  assert.equal(s.document.getElementById('sale-quantity').value,'3');
  assert.equal(s.document.querySelector('[data-sale-remove]').disabled,true);
  s.document.getElementById('sale-add').click();
  assert.equal(s.document.getElementById('sale-item-2').value,item.id);
  s.document.querySelector('[data-sale-remove="1"]').click();
  assert.equal(s.document.querySelectorAll('[data-sale-line]').length,1);
});

test('multiarticle double submit freezes all lines and renders the server total and every item',async t=>{
  const calls=[]; let finish;
  const s=setup(t,{...twoItems,recordSale:(key,payload)=>{calls.push({key,payload});return new Promise(r=>finish=r);}});
  await s.app.start();fillMulti(s);s.submit();s.submit();
  assert.equal(calls.length,1);assert.deepEqual(calls[0].payload,multiBody);
  assert.deepEqual(JSON.parse(s.window.sessionStorage.getItem(`savia.sale.pending.${actor.id}`)).body,multiBody);
  for(const control of s.document.getElementById('sale-form').elements) assert.equal(control.disabled,true);
  finish(multiReceipt);await flush();
  const text=s.document.getElementById('sale-receipt').textContent;
  assert.match(text,/SYN-S/);assert.match(text,/SYN-M/);assert.match(text,/500/);
  assert.equal(s.document.querySelectorAll('[data-sale-line]').length,1);
  assert.equal(s.document.getElementById('sale-item').value,'');s.submit();await flush();assert.equal(calls.length,1);
});

test('duplicate articles and fractional quantities never create or persist a sale',async t=>{
  let writes=0;const s=setup(t,{...twoItems,recordSale:async()=>{writes++;return multiReceipt;}});
  await s.app.start();fillMulti(s);s.document.getElementById('sale-item-2').value=item.id;s.submit();
  assert.match(s.document.getElementById('sale-status').textContent,/repetidos/);
  s.document.getElementById('sale-item-2').value=second.id;s.document.getElementById('sale-quantity-2').value='1.5';s.submit();
  await flush();assert.equal(writes,0);assert.equal(s.window.sessionStorage.getItem(`savia.sale.pending.${actor.id}`),null);
});

test('multiarticle retry sends the original full body and key after response loss',async t=>{
  const calls=[];const s=setup(t,{...twoItems,recordSale:async(key,payload)=>{calls.push({key,payload});if(calls.length===1)throw new StaffRequestError('unavailable');return multiReceipt;}});
  await s.app.start();fillMulti(s);s.submit();await flush();
  // Even a programmatic field change cannot alter the persisted operation.
  s.document.getElementById('sale-quantity-2').value='99';s.document.getElementById('sale-retry').click();await flush();
  assert.equal(calls.length,2);assert.deepEqual(calls[0],calls[1]);assert.deepEqual(calls[1].payload,multiBody);
});

test('multiarticle reload displays and recovers the original lines even when an item left the catalog',async t=>{
  let writes=0;const s=setup(t,{recordSale:async()=>{writes++;return multiReceipt;},recoverSale:async(key,payload)=>{
    assert.equal(key,id(8));assert.deepEqual(payload,multiBody);
    assert.equal(s.document.getElementById('sale-item-2').value,second.id);
    assert.equal(s.document.getElementById('sale-quantity-2').value,'3');return multiReceipt;
  }});
  s.window.sessionStorage.setItem(`savia.sale.pending.${actor.id}`,JSON.stringify({key:id(8),body:multiBody,actorVersion:actor.version}));
  await s.app.start();assert.equal(writes,0);assert.equal(s.document.getElementById('sale-receipt').hidden,false);
});

test('request bounds and case-insensitive distinct item identities are enforced',()=>{
  const hundred={...body,lines:Array.from({length:100},(_,n)=>({itemId:id(100+n),quantity:100000}))};
  assert.doesNotThrow(()=>validateSaleRequest(hundred));
  const hex='abcdefab-cdef-abcd-efab-abcdefabcdef';
  for(const lines of [[],[...hundred.lines,{itemId:id(999),quantity:1}],
    [{itemId:hex,quantity:1},{itemId:hex.toUpperCase(),quantity:1}],
    [{itemId:item.id,quantity:0}],[{itemId:item.id,quantity:100001}],[null]])
    assert.throws(()=>validateSaleRequest({...body,lines}),StaffRequestError);
});

test('multiarticle receipts match every requested item and quantity independently of ordering',()=>{
  assert.equal(readReceipt({...multiReceipt,lines:[...multiReceipt.lines].reverse()},multiBody).saleId,receipt.saleId);
  const first=multiReceipt.lines[0],last=multiReceipt.lines[1];
  for(const wrong of [
    {...multiReceipt,lines:[first],totalMinor:first.totalMinor},
    {...multiReceipt,lines:[first,{...last,itemId:id(22)}]},
    {...multiReceipt,lines:[first,{...last,itemId:first.itemId}]},
    {...multiReceipt,lines:[first,{...last,saleLineId:first.saleLineId}]},
    {...multiReceipt,lines:[first,{...last,quantity:4,totalMinor:40000}],totalMinor:60000},
    {...multiReceipt,lines:[first,last,{...last,saleLineId:id(23),itemId:id(24)}],totalMinor:80000}
  ]) assert.throws(()=>readReceipt(wrong,multiBody),StaffRequestError);
});
