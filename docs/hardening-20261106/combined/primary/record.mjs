import {createRequire} from 'node:module';
import fs from 'node:fs';
import path from 'node:path';
const require=createRequire(import.meta.url);
const {chromium}=require('C:/Users/Jason/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const phase=process.argv[2];
if(!['before','after'].includes(phase))throw Error('Expected before or after');
const out=path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/,'$1')),phase);
fs.mkdirSync(out,{recursive:true});
const browser=await chromium.launch({channel:'chrome',headless:true,args:['--disable-background-networking']});
const results=process.argv[3]==='mobile'?JSON.parse(fs.readFileSync(path.join(out,'RESULT.json'),'utf8')):[];
try {
 for(const [label,width,height] of [['desktop',1280,900],['mobile',390,844]]){
  if(process.argv[3]==='mobile'&&label==='desktop')continue;
  const dir=path.join(out,label);fs.mkdirSync(dir,{recursive:true});
  const context=await browser.newContext({viewport:{width,height},recordVideo:{dir,size:{width,height}},reducedMotion:'no-preference'});
  await context.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());
  const page=await context.newPage(),errors=[],consoleErrors=[],failed=[],external=[],observations=[];
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')consoleErrors.push(m.text());});
  page.on('requestfailed',r=>failed.push({url:r.url(),error:r.failure()?.errorText}));
  page.on('request',r=>{if(new URL(r.url()).hostname!=='127.0.0.1')external.push(r.url());});
  const read=async step=>{
   await page.evaluate(()=>document.fonts.ready);
   await page.waitForTimeout(650);
   const state=await page.evaluate(()=>({url:location.pathname+location.search,size:[innerWidth,innerHeight],overflow:document.documentElement.scrollWidth>innerWidth,broken:[...document.images].filter(i=>i.complete&&i.currentSrc&&!i.naturalWidth).map(i=>i.currentSrc),heading:document.querySelector('h1')?.innerText,order:document.querySelector('.order-heading')?.innerText,summary:document.querySelector('.order-summary')?.innerText,notice:document.querySelector('main .notice')?.innerText,csp:window.__primaryCsp||[]}));
   observations.push({step,...state});
   await page.screenshot({path:path.join(dir,step+'.png')});
   if(state.overflow||state.broken.length||state.csp.length)throw Error('Visual/runtime check failed '+step+': '+JSON.stringify(state));
  };
  await page.addInitScript(()=>{window.__primaryCsp=[];document.addEventListener('securitypolicyviolation',e=>window.__primaryCsp.push({directive:e.violatedDirective,blocked:e.blockedURI}));});
  try {
   await page.goto('http://127.0.0.1:18313/',{waitUntil:'networkidle'});await read('home');
   await page.evaluate(()=>scrollTo({top:innerHeight,behavior:'smooth'}));await read('home-scroll');
   await page.goto('http://127.0.0.1:18313/catalogo.html',{waitUntil:'networkidle'});await page.waitForSelector('.product-card');await read('catalog');
   await page.goto('http://127.0.0.1:18313/producto-dorado.html',{waitUntil:'networkidle'});
   await page.locator('[name=variant]:not(:disabled)').first().check();await page.locator('[data-add]').click();await page.locator('#mini-bag[open]').waitFor();await read('bag');
   await page.getByRole('button',{name:'Cerrar bolsa',exact:true}).click();
   if(phase==='after'){
    await page.goto('http://127.0.0.1:18313/checkout.html',{waitUntil:'networkidle'});
    for(const [name,value] of Object.entries({name:'Persona Ficticia',email:'piloto@example.test',phone:'88888888'}))await page.locator('[name='+name+']').fill(value);
    await page.locator('[data-checkout-form=contact] button').click();
    for(const [name,value] of Object.entries({line1:'Direccion ficticia 123',city:'Managua',department:'Managua'}))await page.locator('[name='+name+']').fill(value);
    await page.locator('[data-checkout-form=delivery] button').click();await read('review');
    await page.locator('[data-create-order]').click();await page.locator('[data-test-payment=approved]').waitFor();await read('payment');
    await page.locator('[data-test-payment=approved]').click();await page.locator('.order-heading').waitFor();await read('order');
    if(!observations.at(-1).order?.includes('DEMO-0001'))throw Error('Missing demo order');
    if(!observations.at(-1).summary?.replace(/\s/g,'').includes('TotalUSD190.00'))throw Error('Unexpected order total');
   }
   if(errors.length||external.length)throw Error('Runtime page errors or external requests');
  } finally {
   await context.close();
   results.push({phase,label,viewport:{width,height},browser:browser.version(),observations,errors,consoleErrors,failed,external,video:await page.video().path()});
   fs.writeFileSync(path.join(out,'RESULT.json'),JSON.stringify(results,null,2)+'\n');
  }
 }
 console.log(JSON.stringify({phase,contexts:results.length,observations:results.reduce((n,r)=>n+r.observations.length,0),errors:results.flatMap(r=>r.errors).length,external:results.flatMap(r=>r.external).length,videos:results.map(r=>r.video)}));
} finally {await browser.close();}
