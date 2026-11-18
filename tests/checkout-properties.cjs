'use strict';
// Scope: local demo adapter; not a SQL, browser, real payment or multi-tab test.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');
const fc = require('./frontend-deps/node_modules/fast-check');
const {createDemoApi} = require('../dist/demo-api.js');
const KEY = 'martha-parity-v2-demo-state-1';
const contact = {name:'Synthetic Test', email:'test@example.invalid', phone:'00000000'};
const address = {line1:'Fixture', city:'Managua', department:'Managua'};
const seed = Number(process.env.FC_SEED ?? 20261118);
const runs = Number(process.env.FC_RUNS ?? 100);
const pathOption = process.env.FC_PATH ? {path:process.env.FC_PATH} : {};
const replayOption = process.env.FC_REPLAY_PATH ? {replayPath:process.env.FC_REPLAY_PATH} : {};
if (!Number.isSafeInteger(seed) || !Number.isInteger(runs) || runs < 1 || runs > 2000)
  throw new Error('Invalid FC_SEED or FC_RUNS (1..2000)');

function setup() {
  const context = {window:{}};
  vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../dist/catalog.js'),'utf8'), context);
  const catalog = JSON.parse(JSON.stringify(context.window.DEMO_CATALOG));
  const entries = new Map();
  const storage = {getItem:k=>entries.get(k) ?? null, setItem:(k,v)=>entries.set(k,v)};
  const variant = catalog.products[0].variants[0];
  return {api:createDemoApi(catalog, storage), storage, vid:variant.id, initial:variant.stock};
}
function choose(items, n) {return items[n % items.length];}
function pending(m) {return m.orders.filter(o=>o.status==='pending_payment');}
async function checkInvariant(m,r) {
  const row = (await r.api('/api/admin/inventory')).variants.find(v=>v.id===r.vid);
  const reserved = pending(m).reduce((sum,o)=>sum+o.qty,0);
  assert.ok(row);
  assert.equal(row.stock,m.stock,'stock');
  assert.equal(row.reserved,reserved,'reserved');
  assert.equal(row.available,m.stock-reserved,'available');
  assert.ok(row.available>=0,'oversell');
  assert.equal((await r.api('/api/cart')).lines.find(v=>v.variant_id===r.vid)?.quantity ?? 0,m.cart,'cart');
}
class Cart {
  constructor(q){this.q=q;}
  check(){return true;}
  async run(m,r){
    const available=m.stock-pending(m).reduce((n,o)=>n+o.qty,0);
    if(this.q>available) await assert.rejects(()=>r.api('/api/cart/items',{variant_id:r.vid,quantity:this.q},'PATCH'),e=>e.code==='insufficient_stock');
    else {await r.api('/api/cart/items',{variant_id:r.vid,quantity:this.q},'PATCH');m.cart=this.q;}
    await checkInvariant(m,r);
  }
  toString(){return 'cart('+this.q+')';}
}
class Reserve {
  check(m){return m.cart>0;}
  async run(m,r){
    const q=await r.api('/api/quote',{delivery_zone:'managua'});
    const key='fast-check-reserve-'+m.orders.length;
    const {order}=await r.api('/api/orders',{quote_id:q.id,idempotency_key:key,contact,address});
    assert.equal(order.status,'pending_payment');
    assert.equal(order.total_minor,q.total_minor);
    m.orders.push({id:order.id,key,qty:m.cart,status:'pending_payment'});
    m.cart=0;
    await checkInvariant(m,r);
  }
  toString(){return 'reserve';}
}
class Payment {
  constructor(n,outcome){this.n=n;this.outcome=outcome;}
  check(m){return pending(m).length>0;}
  async run(m,r){
    const o=choose(pending(m),this.n);
    const {order}=await r.api('/api/orders/'+o.id+'/test-payment',{outcome:this.outcome});
    o.status=this.outcome==='approved'?'paid':this.outcome;
    if(this.outcome==='approved')m.stock-=o.qty;
    assert.equal(order.status,o.status);
    await checkInvariant(m,r);
  }
  toString(){return 'payment('+this.outcome+','+this.n+')';}
}
class Expire {
  constructor(n){this.n=n;}
  check(m){return pending(m).length>0;}
  async run(m,r){
    const o=choose(pending(m),this.n);
    const state=JSON.parse(r.storage.getItem(KEY));
    state.orders[o.id].reservation_expires_at=Date.now()-1;
    r.storage.setItem(KEY,JSON.stringify(state));
    const {order}=await r.api('/api/orders/'+o.id);
    o.status='cancelled';
    assert.equal(order.status,o.status);
    await checkInvariant(m,r);
  }
  toString(){return 'expire('+this.n+')';}
}
class Replay {
  constructor(n){this.n=n;}
  check(m){return m.orders.length>0;}
  async run(m,r){
    const o=choose(m.orders,this.n);
    const {order}=await r.api('/api/orders',{idempotency_key:o.key});
    assert.equal(order.id,o.id);
    assert.equal(order.status,o.status);
    await checkInvariant(m,r);
  }
  toString(){return 'replay('+this.n+')';}
}
class ReturnRefund {
  constructor(n,restock){this.n=n;this.restock=restock;}
  check(m){return m.orders.some(o=>o.status==='paid');}
  async run(m,r){
    const o=choose(m.orders.filter(o=>o.status==='paid'),this.n);
    for(const status of ['preparing','shipped','delivered'])
      await r.api('/api/admin/orders/'+o.id+'/fulfill',{status,tracking:'FIXTURE'});
    const result=await r.api('/api/orders/'+o.id+'/returns',{reason:'Fixture',lines:[{variant_id:r.vid,quantity:o.qty}]});
    await r.api('/api/admin/orders/'+o.id+'/returns/'+result.return.id+'/receive',{});
    const body={return_id:result.return.id,restock:this.restock};
    const {order}=await r.api('/api/admin/orders/'+o.id+'/refund',body);
    assert.equal(order.status,'refunded');
    assert.equal(order.refunded_minor,order.subtotal_minor-order.discount_minor);
    // Invert restock during replay: a terminal refund must not restock twice.
    await r.api('/api/admin/orders/'+o.id+'/refund',{return_id:result.return.id,restock:!this.restock});
    if(this.restock)m.stock+=o.qty;
    o.status='refunded';
    await checkInvariant(m,r);
  }
  toString(){return 'refund('+this.n+','+this.restock+')';}
}
const selector=fc.integer({min:0,max:15});
const operations=[
  fc.integer({min:0,max:6}).map(q=>new Cart(q)),
  fc.constant(new Reserve()),
  fc.tuple(selector,fc.constantFrom('approved','declined','cancelled')).map(([n,outcome])=>new Payment(n,outcome)),
  selector.map(n=>new Expire(n)),
  selector.map(n=>new Replay(n)),
  fc.tuple(selector,fc.boolean()).map(([n,restock])=>new ReturnRefund(n,restock))
];
test('model-based state invariants for local demo',async()=>{
  await fc.assert(fc.asyncProperty(fc.commands(operations,{maxCommands:60,...replayOption}),async commands=>{
    await fc.asyncModelRun(()=>{
      const real=setup();
      return {model:{cart:0,stock:real.initial,orders:[]},real};
    },commands);
  }),{seed,numRuns:runs,...pathOption});
});
test('duplicate payment calls cannot double debit stock in one JS instance',async()=>{
  await fc.assert(fc.asyncProperty(fc.integer({min:1,max:3}),fc.constantFrom('approved','declined','cancelled'),async(q,outcome)=>{
    const r=setup();
    await r.api('/api/cart/items',{variant_id:r.vid,quantity:q},'PATCH');
    const quote=await r.api('/api/quote',{delivery_zone:'resto'});
    const {order}=await r.api('/api/orders',{quote_id:quote.id,idempotency_key:'repeat-fixture',contact,address});
    const results=await Promise.all(Array.from({length:8},()=>r.api('/api/orders/'+order.id+'/test-payment',{outcome})));
    const expected=outcome==='approved'?'paid':outcome;
    assert.ok(results.every(res=>res.order.status===expected));
    const state=JSON.parse(r.storage.getItem(KEY));
    assert.equal(state.orders[order.id].events.filter(e=>e.type.startsWith('test_payment_')).length,1);
    const row=(await r.api('/api/admin/inventory')).variants.find(v=>v.id===r.vid);
    assert.equal(row.stock,r.initial-(outcome==='approved'?q:0));
    assert.equal(row.reserved,0);
  }),{seed:seed+1,numRuns:runs,...pathOption});
});
test('full returns and refund retries preserve stock for varied quantities',async()=>{
  await fc.assert(fc.asyncProperty(fc.integer({min:1,max:3}),fc.boolean(),async(q,restock)=>{
    const r=setup();
    await r.api('/api/cart/items',{variant_id:r.vid,quantity:q},'PATCH');
    const quote=await r.api('/api/quote',{delivery_zone:'managua'});
    const {order}=await r.api('/api/orders',{quote_id:quote.id,idempotency_key:'refund-fixture',contact,address});
    await r.api('/api/orders/'+order.id+'/test-payment',{outcome:'approved'});
    for(const status of ['preparing','shipped','delivered'])
      await r.api('/api/admin/orders/'+order.id+'/fulfill',{status,tracking:'FIXTURE'});
    const requested=await r.api('/api/orders/'+order.id+'/returns',{reason:'Fixture',lines:[{variant_id:r.vid,quantity:q}]});
    await r.api('/api/admin/orders/'+order.id+'/returns/'+requested.return.id+'/receive',{});
    const body={return_id:requested.return.id,restock};
    const result=await r.api('/api/admin/orders/'+order.id+'/refund',body);
    assert.equal(result.order.status,'refunded');
    const before=(await r.api('/api/admin/inventory')).variants.find(v=>v.id===r.vid);
    assert.equal(before.stock,r.initial-q+(restock?q:0));
    await r.api('/api/admin/orders/'+order.id+'/refund',{return_id:requested.return.id,restock:!restock});
    const after=(await r.api('/api/admin/inventory')).variants.find(v=>v.id===r.vid);
    assert.equal(after.stock,before.stock);
    assert.equal(after.reserved,0);
  }),{seed:seed+2,numRuns:runs,...pathOption});
});
