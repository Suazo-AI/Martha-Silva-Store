import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {mountCommerce,mountStockReview} from './app.mjs';
import {createStaffClient,readReceipt,validateSaleRequest} from './client.mjs';
import {StaffRequestError,createAuthClient} from './login.mjs';
const {JSDOM}=createRequire(import.meta.url)('jsdom');
const html=await readFile(new URL('./index.html',import.meta.url),'utf8');
const id=n=>`10000000-0000-0000-0000-${String(n).padStart(12,'0')}`;
const actor={id:id(1),role:'Manager',enabled:true,loginName:'synthetic',displayName:'Synthetic',version:id(9)};
const body={locationId:id(3),customerId:null,lines:[{itemId:id(2),quantity:1,exceptionReason:'physical',size:'S'}]};
const receipt={saleId:id(5),actorId:id(8),locationId:id(3),customerId:null,currency:'USD',totalMinor:100,state:'recorded',paymentStatus:'not_processed',createdAt:'2026-11-06T00:00:00Z',lines:[{saleLineId:id(6),itemId:id(2),sku:'SYN-S',name:'Synthetic',quantity:1,returnedQuantity:0,unitPriceMinor:100,totalMinor:100,exceptionReason:'physical',size:'S'}]};
const reviewBody={saleLineId:id(6),evidence:'examined',outcome:'unproven',responsibleActorId:actor.id,nextReviewAt:'2099-11-07T17:00:00Z'};
const reviewResult=b=>({...b,id:id(10),createdAt:'2026-11-06T00:00:00Z',reviewerId:actor.id,causeState:'open'});
const flush=()=>new Promise(r=>setTimeout(r,0));
test('exception request rejects omitted size and blank reason',()=>{validateSaleRequest(body);for(const line of [{...body.lines[0],size:null},{...body.lines[0],exceptionReason:' '},{...body.lines[0],exceptionReason:null}])assert.throws(()=>validateSaleRequest({...body,lines:[line]}));});
test('receipt refuses an exceptional delivery silently changed to ordinary',()=>{assert.throws(()=>readReceipt({...receipt,lines:[{...receipt.lines[0],exceptionReason:null,size:null}]},body));assert.equal(readReceipt(receipt,body),receipt);});
test('cashier cannot send a review and manager sends fresh CSRF',async()=>{
 const calls=[];let role='Cashier';const json=v=>new Response(JSON.stringify(v),{headers:{'Content-Type':'application/json'}});
 const client=createStaffClient({fetchImpl:async(path,o)=>{calls.push({path,o});return json(path.endsWith('/me')?{...actor,role}:path.endsWith('/csrf')?{headerName:'X-CSRF-TOKEN',token:'synthetic'}:reviewResult(reviewBody));}});
 await client.getSession();await assert.rejects(()=>client.reviewStockException(receipt.saleId,id(7),reviewBody),e=>e.code==='forbidden');assert.equal(calls.length,1);
 role='Manager';await client.getSession();await client.reviewStockException(receipt.saleId,id(7),reviewBody);assert.equal(calls.at(-1).o.headers['X-CSRF-TOKEN'],'synthetic');assert.equal(calls.at(-1).o.headers['Idempotency-Key'],id(7));
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


for (const [field,value] of [['responsibleActorId','not-a-uuid'],['nextReviewAt','2000-01-01T12:00']]) {
 test(`invalid review ${field} stays editable without a pending operation`,async t=>{
  const s=setup(t);await s.load();s.fill();s.document.getElementById('stock-review-form').elements[field].value=value;
  s.submit('stock-review-form');await flush();
  assert.equal(s.calls.length,0,'Invalid data must not reach the server');
  assert.equal(s.dom.window.sessionStorage.getItem(`savia.stock.review.pending.${actor.id}`),null);
  assert.equal(s.document.querySelector('#stock-review-form button').disabled,false);
  s.fill();s.submit('stock-review-form');await flush();assert.equal(s.calls.length,1);
 });
}


async function transport(reply) {
 const calls=[];
 const client=createStaffClient({fetchImpl:async(path,options)=>{
  calls.push({path,options});
  const [value,status=200]=path.endsWith('/me')?[actor]:path.endsWith('/csrf')?[{headerName:'X-CSRF-TOKEN',token:'synthetic'}]:await reply(path,options);
  return new Response(JSON.stringify(value),{status,headers:{'Content-Type':'application/json'}});
 }});
 await client.getSession();return {client,calls};
}

test('durable rejection releases editing and a corrected review uses a new key',async t=>{
 let posts=0;const submitted=[];
 const {client}=await transport((path,options)=>{
  if(path.includes('/operations/'))return [{status:'completed',result:{success:false,error:'responsible_actor_forbidden',value:null}}];
  submitted.push({key:options.headers['Idempotency-Key'],body:JSON.parse(options.body)});
  return ++posts===1?[{},400]:[reviewResult(submitted.at(-1).body)];
 });
 const s=setup(t,{reviewStockException:(...args)=>client.reviewStockException(...args)});await s.load();s.fill();s.submit('stock-review-form');await flush();await flush();
 assert.equal(s.dom.window.sessionStorage.getItem(`savia.stock.review.pending.${actor.id}`),null);
 assert.equal(s.document.querySelector('#stock-review-form button').disabled,false);
 assert.match(s.document.getElementById('stock-review-status').textContent,/rechazada/);
 s.document.getElementById('stock-review-form').elements.responsibleActorId.value=id(88);s.submit('stock-review-form');await flush();await flush();
 assert.equal(posts,2);assert.notEqual(submitted[0].key,submitted[1].key);
 assert.equal(submitted[1].body.responsibleActorId,id(88));
 assert.match(s.document.getElementById('stock-review-status').textContent,/confirmada/);
});

for(const status of [400,403,404,409])test(`HTTP ${status} without a durable outcome preserves the original pending request`,async t=>{
 const {client,calls}=await transport(path=>path.includes('/operations/')?[{},404]:[{},status]);
 const s=setup(t,{reviewStockException:(...args)=>client.reviewStockException(...args)});await s.load();s.fill();s.submit('stock-review-form');await flush();await flush();
 const raw=s.dom.window.sessionStorage.getItem(`savia.stock.review.pending.${actor.id}`);assert.ok(raw);
 assert.equal(s.document.querySelector('#stock-review-form button').disabled,true);
 s.remount();s.document.getElementById('stock-review-retry').click();await flush();await flush();
 assert.equal(s.dom.window.sessionStorage.getItem(`savia.stock.review.pending.${actor.id}`),raw);
 const posts=calls.filter(x=>x.options.method==='POST');assert.equal(posts.length,2);
 assert.equal(posts[0].options.headers['Idempotency-Key'],posts[1].options.headers['Idempotency-Key']);
 assert.equal(posts[0].options.body,posts[1].options.body);
 const lookups=calls.filter(x=>x.path.includes('/operations/'));assert.equal(lookups.length,2);
 assert.equal(lookups[0].options.headers['Idempotency-Key'],posts[0].options.headers['Idempotency-Key']);
});

test('conflict recovery accepts only the original matching committed review',async()=>{
 for(const wrong of [false,true]){
  const {client}=await transport(path=>path.includes('/operations/')?[{status:'completed',result:{success:true,error:null,value:reviewResult({...reviewBody,...(wrong?{responsibleActorId:id(88)}:{})})}}]:[{},409]);
  if(wrong)await assert.rejects(()=>client.reviewStockException(receipt.saleId,id(7),reviewBody),e=>e.code==='response');
  else assert.equal((await client.reviewStockException(receipt.saleId,id(7),reviewBody)).id,id(10));
 }
});

test('malformed recovery cannot release an uncertain review',async()=>{
 for(const result of [{status:'completed',result:{success:false,error:'invalid_request',value:{}}},{status:'started',result:{success:false,error:'invalid_request',value:null}},{status:'completed',result:{success:false,error:null,value:null}}]){
  const {client}=await transport(path=>path.includes('/operations/')?[result]:[{},400]);
  await assert.rejects(()=>client.reviewStockException(receipt.saleId,id(7),reviewBody),e=>e.code==='response');
 }
});

test('review responses reject malformed lists and mismatched receipt fields',async()=>{
 const valid=reviewResult(reviewBody);
 for(const result of [null,{},[valid,valid],[{...valid,responsibleActorId:'bad'}],[{...valid,causeState:'closed'}],[{...valid,nextReviewAt:'2000-01-01T00:00:00Z'}]]){
  const {client}=await transport(()=>[result]);await assert.rejects(()=>client.stockReviews(receipt.saleId),e=>e.code==='response');
 }
 for(const patch of [{id:null},{reviewerId:id(88)},{saleLineId:id(88)},{evidence:'other'},{outcome:'other'},{responsibleActorId:id(88)},{nextReviewAt:'2098-01-01T00:00:00Z'}]){
  const {client}=await transport(()=>[{...valid,...patch}]);
  await assert.rejects(()=>client.reviewStockException(receipt.saleId,id(7),reviewBody),e=>e.code==='response');
 }
});

test('review replay accepts a once-valid review date after its deadline',async()=>{
 const past={...reviewBody,nextReviewAt:'2025-11-07T00:00:00Z'};
 const {client}=await transport(()=>[{...reviewResult(past),createdAt:'2025-11-06T00:00:00Z'}]);
 assert.equal((await client.reviewStockException(receipt.saleId,id(7),past)).nextReviewAt,past.nextReviewAt);
});

test('late durable rejection after clear cannot erase a pending request',async t=>{
 let reject;const s=setup(t,{reviewStockException:()=>new Promise((_,r)=>{reject=r;})});await s.load();s.fill();s.submit('stock-review-form');
 const key=`savia.stock.review.pending.${actor.id}`,raw=s.dom.window.sessionStorage.getItem(key);s.app.clear();reject(new StaffRequestError('stock_review_rejected'));await flush();
 assert.equal(s.dom.window.sessionStorage.getItem(key),raw);assert.equal(s.document.getElementById('stock-review-status').textContent,'');
});


test('review outcome lookup requires an authorized role and the original valid key',async()=>{
 let role='Cashier';const calls=[];
 const auth=createAuthClient({fetchImpl:async(path,options)=>{calls.push({path,options});return new Response(JSON.stringify(path.endsWith('/me')?{...actor,role}:{status:'completed',result:{success:false,error:'invalid_request',value:null}}),{headers:{'Content-Type':'application/json'}});}});
 const path='/internal/api/operations/commerce.stock.review';
 await auth.getSession();await assert.rejects(()=>auth.requestBusiness(path,{key:id(7)}),e=>e.code==='forbidden');assert.equal(calls.length,1);
 role='Manager';await auth.getSession();await assert.rejects(()=>auth.requestBusiness(path,{key:'invalid'}),e=>e.code==='invalid');assert.equal(calls.length,2);
 await auth.requestBusiness(path,{key:id(7)});assert.equal(calls.at(-1).options.headers['Idempotency-Key'],id(7));assert.equal(calls.at(-1).options.method,'GET');assert.equal(calls.at(-1).options.body,undefined);
});
