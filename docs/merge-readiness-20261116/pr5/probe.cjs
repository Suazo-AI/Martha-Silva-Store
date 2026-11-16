'use strict';
// Review evidence only. Executes exact extracted PR source; never patches product.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const receipt=JSON.parse(fs.readFileSync(path.join(__dirname,'snapshot-receipt.json')));
const root=path.join(receipt.scratch,'pr5');
const source=fs.readFileSync(path.join(root,'src/app.js'),'utf8');
const functions=source.slice(source.indexOf('  function nicaraguaDate()'),source.indexOf('  function seasonalOffers('));
const ctx=vm.createContext({Intl,Date});vm.runInContext(functions,ctx);
const good=()=>({commercial_status:'active',currency:'USD',price_minor:17500,variants:[{size:'S',stock:2},{size:'M',stock:0}],seasonal_offer:{approved:true,season:'graduaciones',previous_price_minor:20000,starts_on:'2026-11-01',ends_on:'2026-11-30'}});
let checks=0;
function check(label,mutate,expected,today='2026-11-16'){const p=good();mutate(p);assert.equal(ctx.isApprovedSeasonalOffer(p,'graduaciones',today),expected,label);checks++;}
check('valid',()=>{},true);
for(const [label,mutate] of [
 ['sample',p=>p.commercial_status='sample'],['currency',p=>p.currency='NIO'],['unapproved',p=>p.seasonal_offer.approved=false],
 ['approval string',p=>p.seasonal_offer.approved='true'],['missing offer',p=>delete p.seasonal_offer],['wrong season',p=>p.seasonal_offer.season='verano'],
 ['no stock',p=>p.variants.forEach(v=>v.stock=0)],['no variants',p=>p.variants=[]],['equal price',p=>p.seasonal_offer.previous_price_minor=17500],
 ['fractional cents',p=>p.price_minor=17499.5],['unsafe cents',p=>p.price_minor=Number.MAX_SAFE_INTEGER+1],['zero price',p=>p.price_minor=0],
 ['string cents',p=>p.price_minor='17500'],['fractional previous',p=>p.seasonal_offer.previous_price_minor=20000.5],
 ['reversed window',p=>{p.seasonal_offer.starts_on='2026-11-30';p.seasonal_offer.ends_on='2026-11-01'}],
 ['nonleap',p=>p.seasonal_offer.starts_on='2025-02-29'],['century nonleap',p=>p.seasonal_offer.starts_on='1900-02-29'],
 ['invalid day',p=>p.seasonal_offer.ends_on='2026-11-31'],['year zero',p=>p.seasonal_offer.starts_on='0000-01-01']
])check(label,mutate,false);
check('before start',()=>{},false,'2026-10-31');check('after end',()=>{},false,'2026-12-01');
check('inclusive start',()=>{},true,'2026-11-01');check('inclusive end',()=>{},true,'2026-11-30');
check('400 year leap',p=>p.seasonal_offer.starts_on='2000-02-29',true);
for(const [instant,want] of [['2026-11-16T05:59:59Z','2026-11-15'],['2026-11-16T06:00:00Z','2026-11-16']]){
 const NativeDate=Date;ctx.Date=class extends NativeDate{constructor(...args){super(...(args.length?args:[instant]));}};
 assert.equal(ctx.nicaraguaDate(),want);checks++;
}
console.log(`${checks}/${checks} independent predicate/timezone assertions passed`);
for(const [label,stock] of [['numeric string','2'],['fraction',0.5],['infinity',Infinity]]){
 const p=good();p.variants=[{size:'S',stock}];console.log('OBSERVED accepts malformed stock',label,ctx.isApprovedSeasonalOffer(p,'graduaciones','2026-11-16'));
}
// Reuse the PR DOM harness with only dependency location adapted by snapshot reader.
let harness=fs.readFileSync(path.join(root,'tests/frontend-runtime.cjs'),'utf8');
harness=harness.slice(0,harness.indexOf('(async()=>{let failed=0;'));
harness+=`\n(async()=>{tests.length=0;const b=await boot('index.html',()=>{},catalog=>{const p=catalog.products[0];p.commercial_status='active';p.seasonal_offer={approved:true,season:'graduaciones',previous_price_minor:20000,starts_on:'2020-01-01',ends_on:'2099-12-31'};});try{for(const season of ['graduaciones','verano','fin-de-ano','bodas-eventos']){b.d.querySelector('[data-seasonal-season="'+season+'"]').click();assert.equal(b.d.querySelector('[data-seasonal-season="'+season+'"]').getAttribute('aria-pressed'),'true');}b.d.querySelector('[data-seasonal-season="graduaciones"]').click();const p=b.w.DEMO_CATALOG.products[0],v=p.variants.find(v=>v.stock>0);await b.w.marthaDemoApi('/api/cart/items',{variant_id:v.id,quantity:1});const cart=await b.w.marthaDemoApi('/api/cart');assert.equal(cart.lines[0].unit_price_minor,p.price_minor);assert.equal(cart.subtotal_minor,p.price_minor);assert.deepEqual(b.errors,[]);console.log('PASS four seasons and simulated authoritative cart price: '+p.price_minor+' cents');}finally{b.close();}})().catch(e=>{console.error(e);process.exitCode=1});`;
const Module=require('node:module'),m=new Module(path.join(root,'tests/review-probe.cjs'),module);m.filename=path.join(root,'tests/review-probe.cjs');m.paths=module.paths;m._compile(harness,m.filename);
