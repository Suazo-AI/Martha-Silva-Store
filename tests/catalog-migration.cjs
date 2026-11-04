'use strict';
const assert=require('node:assert/strict');
const test=require('node:test');
const {createDemoApi}=require('../dist/demo-api.js');
const expanded=require('./fixtures/catalog-expansion.json');
// Preserve the actual 6-variant legacy state independently of the 40-product storefront.
const legacy=require('./fixtures/legacy-catalog.json');
const vid=legacy.products[0].variants[0].id, other=legacy.products[1].variants[0].id;
const KEY='martha-parity-v2-demo-state-1', RECOVERY=KEY+'-recovery';
const clone=x=>JSON.parse(JSON.stringify(x));
const contact={name:'Test',email:'test@example.com',phone:'123'},address={line1:'Demo',city:'Demo',department:'Demo'};
function setup(){const saved=new Map();let blocked=false;const storage={getItem:k=>saved.get(k)??null,setItem:(k,v)=>{if(blocked)throw Error('quota');saved.set(k,v);}};return {storage,api:createDemoApi(legacy,storage),state:()=>JSON.parse(saved.get(KEY)),block:v=>blocked=v};}
async function quote(api,v=vid){await api('/api/cart/items',{variant_id:v,quantity:1});return api('/api/quote',{delivery_zone:'managua',coupon:'PRUEBA10'});}
async function order(api,key,v=vid){const q=await quote(api,v);return (await api('/api/orders',{quote_id:q.id,idempotency_key:key,contact,address})).order;}
const reject=(fn,code)=>assert.rejects(fn,e=>e.code===code);
test('known 6 to 120 expansion preserves the complete legacy snapshot and only adds fixture stock',async()=>{
 const x=setup();await x.api('/api/admin/inventory',{variant_id:vid,quantity:9,reason:'Manual adjustment'});
 const o=await order(x.api,'pending');await quote(x.api,other);await x.api('/api/admin/logout',{});
 const before=x.state();x.storage.setItem(RECOVERY,'previous unrelated recovery');
 const api=createDemoApi(expanded,x.storage);await api('/api/cart');const after=x.state();
 assert.equal(Object.keys(before.stock).length,6);assert.equal(Object.keys(after.stock).length,120);
 assert.deepEqual({...after,stock:before.stock},before);
 for(const p of expanded.products)for(const v of p.variants)assert.equal(after.stock[v.id],before.stock[v.id]??v.stock);
 assert.deepEqual(after.orders[o.id],before.orders[o.id]);assert.equal(x.storage.getItem(RECOVERY),'previous unrelated recovery');
 const serialized=x.storage.getItem(KEY);await createDemoApi(expanded,x.storage)('/api/cart');assert.equal(x.storage.getItem(KEY),serialized);
});
test('old quote remains usable after expansion and checkout retries retain identity',async()=>{
 const x=setup(),q=await quote(x.api);const api=createDemoApi(expanded,x.storage);
 const body={quote_id:q.id,idempotency_key:'quote-retry',contact,address};
 const o=(await api('/api/orders',body)).order;const retry=(await createDemoApi(expanded,x.storage)('/api/orders',body)).order;
 assert.equal(retry.id,o.id);assert.equal(o.total_minor,q.total_minor);assert.equal(Object.keys(x.state().orders).length,1);
});
test('pending reservation and payment idempotency survive migration and reopen',async()=>{
 const x=setup(),o=await order(x.api,'pending');let api=createDemoApi(expanded,x.storage);
 const inv=await api('/api/admin/inventory');assert.equal(inv.variants.find(v=>v.id===vid).reserved,1);
 assert.equal((await api('/api/orders',{idempotency_key:'pending'})).order.id,o.id);
 await api(`/api/orders/${o.id}/test-payment`,{outcome:'approved'});api=createDemoApi(expanded,x.storage);
 await api(`/api/orders/${o.id}/test-payment`,{outcome:'approved'});assert.equal(x.state().stock[vid],2);
 assert.equal(x.state().orders[o.id].events.filter(e=>e.type==='test_payment_approved').length,1);
});
test('returns and refund retry never restock twice after migration',async()=>{
 const x=setup(),o=await order(x.api,'return');await x.api(`/api/orders/${o.id}/test-payment`,{outcome:'approved'});
 for(const status of ['preparing','shipped','delivered'])await x.api(`/api/admin/orders/${o.id}/fulfill`,{status,tracking:'Demo'});
 const r=(await x.api(`/api/orders/${o.id}/returns`,{reason:'Demo',lines:[{variant_id:vid,quantity:1}]})).return;
 await x.api(`/api/admin/orders/${o.id}/returns/${r.id}/receive`,{});
 await x.api(`/api/admin/orders/${o.id}/refund`,{return_id:r.id,restock:true});const before=x.state();
 await createDemoApi(expanded,x.storage)(`/api/admin/orders/${o.id}/refund`,{return_id:r.id,restock:true});
 assert.deepEqual(x.state().orders,before.orders);assert.equal(x.state().stock[vid],3);
});
test('expired legacy reservations still expire once during expansion',async()=>{
 const x=setup(),o=await order(x.api,'expired'),s=x.state();s.orders[o.id].reservation_expires_at=Date.now()-1;x.storage.setItem(KEY,JSON.stringify(s));
 const api=createDemoApi(expanded,x.storage);await api('/api/cart');await api('/api/cart');
 assert.equal(x.state().orders[o.id].status,'cancelled');assert.equal(x.state().orders[o.id].events.filter(e=>e.type==='reserve_expired').length,1);assert.equal(x.state().stock[vid],3);
});
test('failed migration write preserves original bytes and can be retried',async()=>{
 const x=setup();await quote(x.api);const original=x.storage.getItem(KEY);const api=createDemoApi(expanded,x.storage);x.block(true);
 await reject(()=>api('/api/cart'),'storage_full');assert.equal(x.storage.getItem(KEY),original);assert.equal(x.storage.getItem(RECOVERY),null);
 x.block(false);await api('/api/cart');assert.deepEqual(x.state().cart,JSON.parse(original).cart);assert.equal(Object.keys(x.state().stock).length,120);
});
test('corrupt legacy data and partial stock loss are backed up, never silently repaired',async()=>{
 const mutations=[s=>delete s.stock[vid],s=>s.stock[vid]=-1,s=>s.cart[vid]=-1,s=>s.stock.unrecognized=3,s=>s.quotes[Object.keys(s.quotes)[0]].total_minor=-1,s=>s.cart['gris-perla-hombros-S']=1,s=>s.keys.missing='no-order'];
 for(const mutate of mutations){const x=setup();await quote(x.api);const s=x.state();mutate(s);const raw=JSON.stringify(s);x.storage.setItem(KEY,raw);await createDemoApi(expanded,x.storage)('/api/cart');assert.equal(x.storage.getItem(RECOVERY),raw);assert.deepEqual(x.state().cart,{});}
 const x=setup();await quote(x.api);await createDemoApi(expanded,x.storage)('/api/cart');const s=x.state();delete s.stock['gris-perla-hombros-S'];const raw=JSON.stringify(s);x.storage.setItem(KEY,raw);await createDemoApi(expanded,x.storage)('/api/cart');assert.equal(x.storage.getItem(RECOVERY),raw);
});
test('unknown catalog expansion is not eligible for legacy repair',async()=>{
 for(const change of [c=>c.products.pop(),c=>{c.products[2].variants[0].id='unknown-S';},c=>{c.products[2].id='unknown';}]){
 const x=setup();await quote(x.api);const raw=x.storage.getItem(KEY),c=clone(expanded);change(c);await createDemoApi(c,x.storage)('/api/cart');assert.equal(x.storage.getItem(RECOVERY),raw);
 }
});
test('migration corruption with occupied recovery slot leaves both copies untouched',async()=>{
 const x=setup();await quote(x.api);const s=x.state();delete s.stock[vid];const raw=JSON.stringify(s);x.storage.setItem(KEY,raw);x.storage.setItem(RECOVERY,'older backup');
 await reject(()=>createDemoApi(expanded,x.storage)('/api/cart'),'storage_corrupt');assert.equal(x.storage.getItem(KEY),raw);assert.equal(x.storage.getItem(RECOVERY),'older backup');
});
