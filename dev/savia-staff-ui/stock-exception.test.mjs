import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {mountCommerce,mountStockReview} from './app.mjs';
import {createStaffClient,readReceipt,validateSaleRequest} from './client.mjs';
const {JSDOM}=createRequire(import.meta.url)('jsdom');
const html=await readFile(new URL('./index.html',import.meta.url),'utf8');
const id=n=>`10000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const actor={id:id(1),role:'Manager',enabled:true,loginName:'synthetic',displayName:'Synthetic',version:id(9)};
const body={locationId:id(3),customerId:null,lines:[{itemId:id(2),quantity:1,exceptionReason:'physical',size:'S'}]};
const receipt={saleId:id(5),actorId:id(8),locationId:id(3),customerId:null,currency:'USD',totalMinor:100,state:'recorded',paymentStatus:'not_processed',createdAt:'2026-11-06T00:00:00Z',lines:[{saleLineId:id(6),itemId:id(2),sku:'SYN-S',name:'Synthetic',quantity:1,returnedQuantity:0,unitPriceMinor:100,totalMinor:100,exceptionReason:'physical',size:'S'}]};
const flush=()=>new Promise(r=>setTimeout(r,0));
test('exception request rejects omitted size and blank reason',()=>{validateSaleRequest(body);for(const line of [{...body.lines[0],size:null},{...body.lines[0],exceptionReason:' '},{...body.lines[0],exceptionReason:null}])assert.throws(()=>validateSaleRequest({...body,lines:[line]}));});
test('receipt refuses an exceptional delivery silently changed to ordinary',()=>{assert.throws(()=>readReceipt({...receipt,lines:[{...receipt.lines[0],exceptionReason:null,size:null}]},body));assert.equal(readReceipt(receipt,body),receipt);});
test('cashier cannot send a review and manager sends fresh CSRF',async()=>{
 const calls=[];let role='Cashier';const json=v=>new Response(JSON.stringify(v),{headers:{'Content-Type':'application/json'}});
 const client=createStaffClient({fetchImpl:async(path,o)=>{calls.push({path,o});return json(path.endsWith('/me')?{...actor,role}:path.endsWith('/csrf')?{headerName:'X-CSRF-TOKEN',token:'synthetic'}:{});}});
 await client.getSession();await assert.rejects(()=>client.reviewStockException(receipt.saleId,id(7),{}),e=>e.code==='forbidden');assert.equal(calls.length,1);
 role='Manager';await client.getSession();await client.reviewStockException(receipt.saleId,id(7),{});assert.equal(calls.at(-1).o.headers['X-CSRF-TOKEN'],'synthetic');assert.equal(calls.at(-1).o.headers['Idempotency-Key'],id(7));
});
function setup(t,overrides={}){
 const dom=new JSDOM(html,{url:'https://staff.example.invalid/internal/'}),document=dom.window.document;
 let session=actor;const calls=[];
 const client={getSale:async()=>receipt,stockReviews:async()=>[],reviewStockException:async(sale,key,b)=>{calls.push({sale,key,b});return {...b,id:id(10),createdAt:'2026-11-06T00:00:00Z',reviewerId:actor.id,causeState:'open'};},...overrides};
 const make=()=>mountStockReview({document,client,getSession:()=>session,onUnauthorized:()=>{session=null;app.clear();}});
 let app=make();app.start();t.after(()=>{app.destroy();dom.window.close();});
 const submit=id=>document.getElementById(id).dispatchEvent(new dom.window.Event('submit',{bubbles:true,cancelable:true}));
 const load=async()=>{document.querySelector('#stock-review-load input').value=receipt.saleId;submit('stock-review-load');await flush();};
 const fill=()=>{const f=document.getElementById('stock-review-form').elements;f.evidence.value='examined';f.outcome.value='unproven';f.responsibleActorId.value=actor.id;f.nextReviewAt.value='2099-11-07T17:00';};
 return {document,dom,calls,load,fill,submit,get app(){return app;},remount(){app.destroy();app=make();app.start();},setSession(s){session=s;}};
}
test('review duplicate-submit produces one operation and keeps cause open',async t=>{const s=setup(t);await s.load();s.fill();s.submit('stock-review-form');s.submit('stock-review-form');await flush();assert.equal(s.calls.length,1);assert.match(s.document.getElementById('stock-review-status').textContent,/Causa abierta/);});
test('lost review response reload retries exact identity and payload',async t=>{
 const calls=[];const s=setup(t,{reviewStockException:async(sale,key,b)=>{calls.push({sale,key,b});if(calls.length===1)throw Error('lost');return {...b,id:id(10),createdAt:'2026-11-06T00:00:00Z',reviewerId:actor.id,causeState:'open'};}});
 await s.load();s.fill();s.submit('stock-review-form');await flush();const raw=s.dom.window.sessionStorage.getItem(`savia.stock.review.pending.${actor.id}`);assert.ok(raw);s.remount();s.document.getElementById('stock-review-retry').click();await flush();assert.deepEqual(calls[1],calls[0]);assert.equal(s.dom.window.sessionStorage.getItem(`savia.stock.review.pending.${actor.id}`),null);
});
test('self review stays disabled even for manager',async t=>{const s=setup(t,{getSale:async()=>({...receipt,actorId:actor.id})});await s.load();assert.equal(s.document.querySelector('#stock-review-form button').disabled,true);assert.equal(s.calls.length,0);});
test('late review success after clear cannot erase pending reference',async t=>{let done;const s=setup(t,{reviewStockException:async(sale,key,b)=>new Promise(r=>done=()=>r({...b,id:id(10),createdAt:'2026-11-06T00:00:00Z',reviewerId:actor.id,causeState:'open'}))});await s.load();s.fill();s.submit('stock-review-form');s.app.clear();done();await flush();assert.ok(s.dom.window.sessionStorage.getItem(`savia.stock.review.pending.${actor.id}`));assert.equal(s.document.getElementById('stock-review-status').textContent,'');});
test('changed session version blocks pending review retry',async t=>{const s=setup(t);s.dom.window.sessionStorage.setItem(`savia.stock.review.pending.${actor.id}`,JSON.stringify({actorId:actor.id,actorVersion:id(90),saleId:receipt.saleId,key:id(7),body:{}}));s.app.start();assert.equal(s.document.getElementById('stock-review-retry').disabled,true);});
test('exceptional sale captures reason and size durably before sending',async t=>{
 const dom=new JSDOM(html,{url:'https://staff.example.invalid/internal/'}),document=dom.window.document,calls=[];
 const client={listItems:async()=>({items:[{id:id(2),sku:'SYN-S',name:'Synthetic',active:true}],total:1}),listLocations:async()=>({items:[{id:id(3),branchId:id(4),name:'Synthetic',active:true}],total:1}),listInventory:async()=>({items:[],total:0}),recordSale:async(key,payload)=>{calls.push({key,payload});throw Error('lost');}};
 const app=mountCommerce({document,client,getSession:()=>actor,onUnauthorized:()=>{}});t.after(()=>{app.destroy();dom.window.close();});await app.start();
 const check=document.querySelector('[data-exception]');check.checked=true;check.dispatchEvent(new dom.window.Event('change'));
 const submit=()=>document.getElementById('sale-form').dispatchEvent(new dom.window.Event('submit',{bubbles:true,cancelable:true}));
 submit();assert.equal(calls.length,0);
 document.querySelector('[data-exception-reason]').value='physical';document.querySelector('[data-exception-size]').value='S';submit();await flush();
 assert.equal(calls.length,1);assert.deepEqual(calls[0].payload,body);
 const pending=JSON.parse(dom.window.sessionStorage.getItem(`savia.sale.pending.${actor.id}`));assert.deepEqual(pending.body,body);assert.equal(pending.key,calls[0].key);
});
