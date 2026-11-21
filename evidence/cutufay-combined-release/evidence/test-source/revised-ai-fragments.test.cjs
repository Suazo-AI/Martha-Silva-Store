'use strict';
// Independent focused artifact tests. Not a real browser, PDP build, A704b preservation or release gate.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');
const {JSDOM, VirtualConsole} = require(path.resolve(__dirname, '../../martha-published/tests/frontend-deps/node_modules/jsdom'));
const draft = path.resolve(process.env.AI_SUPPORT_DRAFT || path.join(__dirname, '../ai-support-draft'));
const manifest = JSON.parse(fs.readFileSync(path.join(draft, 'evidence/fragment-manifest.json'),'utf8'));
const revisedModule = path.resolve(__dirname,'../combined-support-back-candidate-v2/revision-inputs/ai-support-illustrations.js');
const source = fs.readFileSync(revisedModule,'utf8');
console.log('TESTED_REVISED_AI_MODULE_SHA256',crypto.createHash('sha256').update(source).digest('hex'));
const css = fs.readFileSync(path.join(draft,'src/ai-support-illustrations.css'),'utf8');
const targets = ['blanco-perlado-sirena','rosa-empolvado-pedreria'];
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const settle = () => new Promise(resolve => setTimeout(resolve, 0));
const readFragment = id => fs.readFileSync(path.join(draft, 'fragments',`producto-${id}.support.html`),'utf8');
function imageProps(img,complete,width){Object.defineProperty(img,'complete',{configurable:true,get:()=>complete});Object.defineProperty(img,'naturalWidth',{configurable:true,get:()=>width});}
function fixture(id,options={}){
 const errors=[],vc=new VirtualConsole();vc.on('jsdomError',e=>errors.push(e.message));vc.on('error',e=>errors.push(String(e)));
 const pageId=options.pageId||id;
 const html=`<!doctype html><html lang="${options.lang||'es'}"><head><style>${css}</style></head><body><main id="main" data-page="product" data-product-id="${pageId}"><div id="authentic-sentinels"><section class="product-detail"><div data-gallery-track><picture><source type="image/webp" srcset="/original-480.webp 480w, /original-800.webp 800w"><img id="authentic-primary" data-gallery-image src="/original-800.jpg" srcset="/original-480.jpg 480w, /original-800.jpg 800w" width="800" height="1067" alt="Original product photo"></picture><button data-zoom="0">Zoom original</button></div><form data-product-form><input name="variant" value="original-M"><span data-price>USD175.00</span><span data-stock>3</span><button data-add>Add</button></form><div data-product-share-control><button data-product-share>Compartir producto</button><input data-product-share-url value="https://preview.test/producto-original.html?lang=es"></div></section></div>${options.noSection?'':readFragment(id)}<section class="wear-it-with">Existing recommendations</section></main><aside id="green-sentinel" data-product-id="verde-brillo-cuello-cruzado"><img src="/green-original-g1.webp"><span>Gallery1,2,3,4,5</span></aside></body></html>`;
 const dom=new JSDOM(html,{url:`https://preview.test/producto-${pageId}.html`,runScripts:'outside-only',pretendToBeVisual:true,virtualConsole:vc});
 const w=dom.window,d=w.document;
 w.DEMO_CATALOG={products:[{id:pageId,images:['/original-800.webp','/original-g2.webp'],image_sets:['/original-480.webp 480w, /original-800.webp 800w'],price_minor:17500,currency:'USD',variants:[{id:'original-M',stock:3}],commercial_status:'sample'},{id:'verde-brillo-cuello-cruzado',images:[1,2,3,4,5]}]};
 const catalog=JSON.stringify(w.DEMO_CATALOG), original=d.querySelector('#authentic-sentinels').outerHTML, green=d.querySelector('#green-sentinel').outerHTML;
 const img=d.querySelector('[data-ai-support-image]');
 if(img){if(options.badPath)img.src=options.badPath;imageProps(img,options.complete??false,options.naturalWidth??0);}
 if(options.marthaLanguage)w.MarthaI18n={language:options.marthaLanguage};
 function unchanged(){assert.equal(d.querySelector('#authentic-sentinels').outerHTML,original,'authentic gallery/form/Share DOM changed');assert.equal(d.querySelector('#green-sentinel').outerHTML,green,'Green sentinel changed');assert.equal(JSON.stringify(w.DEMO_CATALOG),catalog,'catalogue/gallery/commercial fields changed');assert.deepEqual(errors,[],'unexpected JS error');}
 function boot(){w.eval(source);return w.MarthaSupportingIllustrations;}
 return {dom,w,d,img,errors,boot,unchanged,close:()=>w.close()};
}

test('original fragment contract targets exactly two SKUs and revised AI module parses',()=>{
 assert.equal(manifest.status,'isolated_source_fragments_only_not_assembled_runtime');assert.equal(manifest.runtime_registration,false);assert.equal(manifest.publication,false);
 assert.equal(manifest.source_commit_required,'704b2e160106b709880ad7c22febd25adb6181d6');assert.equal(manifest.required_app_sha256,'8ee8deb77dd6608023f0d315c2451aafa248f58e77658b881717e9de09470ba8');
 assert.deepEqual(manifest.assets.map(a=>a.product_id).sort(),targets.slice().sort());
 for(const forbidden of ['dist','catalog.js','app.js','src/app.js']) assert.equal(fs.existsSync(path.join(draft,forbidden)),false,`unexpected assembled/core artifact ${forbidden}`);
 new vm.Script(source);
});

test('two staged image bytes match provenance SHA and native PNG geometry',()=>{
 for(const asset of manifest.assets){const file=fs.readFileSync(asset.staged_path);assert.equal(sha(file),asset.sha256);assert.equal(sha(fs.readFileSync(asset.source_path)),asset.sha256,'staging altered source');assert.equal(file.subarray(1,4).toString(),'PNG');assert.equal(file.readUInt32BE(16),asset.width);assert.equal(file.readUInt32BE(20),asset.height);assert.equal(asset.width,1086);assert.equal(asset.height,1449);assert.ok(asset.staged_path.endsWith(asset.runtime_path_proposed_not_registered));}
});

for(const id of targets){
 test(`${id}: bilingual disclosure and accessible relation; separate from authentic gallery`,()=>{
  const f=fixture(id);try{const s=f.d.querySelector('[data-ai-support-illustration]');assert.equal(s.dataset.aiProduct,id);assert.equal(f.d.querySelectorAll('[data-ai-support-illustration]').length,1);assert.equal(s.previousElementSibling.id,'authentic-sentinels');assert.equal(s.nextElementSibling.className,'wear-it-with');assert.ok(!s.closest('[data-gallery-track],form'));assert.equal(s.querySelectorAll('[data-zoom],[data-gallery-image],[data-product-share],form').length,0);
   const asset=manifest.assets.find(a=>a.product_id===id);assert.equal(f.img.getAttribute('src'),asset.runtime_path_proposed_not_registered);assert.equal(f.img.getAttribute('width'),String(asset.width));assert.equal(f.img.getAttribute('height'),String(asset.height));
   const cap=s.querySelector('figcaption');assert.match(cap.querySelector('[data-ai-lang="es"]').textContent,/apoyo.*IA/);assert.match(cap.querySelector('[data-ai-lang="en"]').textContent,/Supporting.*AI/);assert.match(cap.textContent,/pueden diferir del producto real/);assert.match(cap.textContent,/may differ from the actual product/);assert.doesNotMatch(cap.textContent,/restauraci[oó]n exacta|exact restoration|identical to the actual/i);
   assert.equal(f.img.getAttribute('aria-describedby'),cap.id);assert.ok(f.d.getElementById(s.getAttribute('aria-labelledby')));assert.match(f.img.dataset.aiAltEs,/IA/);assert.match(f.img.dataset.aiAltEn,/AI/);assert.equal(s.getAttribute('translate'),'no');f.unchanged();
  }finally{f.close();}
 });
 test(`${id}: scoped contain/autoheight styling cannot cover-crop the illustration`,()=>{
  const f=fixture(id);try{const st=f.w.getComputedStyle(f.img);assert.equal(st.objectFit,'contain');assert.equal(st.height,'auto');assert.equal(st.maxHeight,'none');assert.equal(st.transform,'none');assert.equal(st.objectPosition,'center');for(let el=f.img;el&&!el.matches('main');el=el.parentElement){const c=f.w.getComputedStyle(el);assert.ok(!['hidden','clip'].includes(c.overflow));assert.ok(!c.clipPath||c.clipPath==='none');}f.unchanged();}finally{f.close();}
 });
 test(`${id}: ES default and language change EN→ES localize visible caption and alt`,()=>{
  const f=fixture(id);try{f.boot();const s=f.d.querySelector('[data-ai-support-illustration]');assert.equal(s.dataset.aiLanguage,'es');assert.ok([...s.querySelectorAll('[data-ai-lang="en"]')].every(n=>n.hidden));f.w.MarthaI18n={language:'en'};f.w.dispatchEvent(new f.w.Event('martha:languagechange'));assert.equal(s.dataset.aiLanguage,'en');assert.equal(f.img.alt,f.img.dataset.aiAltEn);assert.ok([...s.querySelectorAll('[data-ai-lang="es"]')].every(n=>n.hidden));f.w.MarthaI18n.language='es';f.w.dispatchEvent(new f.w.Event('martha:languagechange'));assert.equal(f.img.alt,f.img.dataset.aiAltEs);f.unchanged();}finally{f.close();}
 });
 test(`${id}: success then load error then recovery preserves all authentic controls`,()=>{
  const f=fixture(id);try{f.boot();const s=f.img.closest('[data-ai-support-illustration]'),notice=s.querySelector('[data-ai-support-load-error]');imageProps(f.img,true,1086);f.img.dispatchEvent(new f.w.Event('load'));assert.equal(s.dataset.aiImageState,'ready');assert.equal(f.img.hidden,false);assert.equal(notice.hidden,true);const src=f.img.getAttribute('src');
   for(let n=0;n<3;n++)f.img.dispatchEvent(new f.w.Event('error'));assert.equal(s.dataset.aiImageState,'failed');assert.equal(f.img.hidden,true);assert.equal(notice.hidden,false);assert.match(notice.textContent,/original photographs remain available/);assert.equal(f.img.getAttribute('src'),src,'error handler substituted image');f.unchanged();
   f.img.dispatchEvent(new f.w.Event('load'));assert.equal(f.img.hidden,false);assert.equal(notice.hidden,true);assert.equal(s.querySelectorAll('[data-ai-support-load-error]').length,1);f.unchanged();
  }finally{f.close();}
 });
 test(`${id}: already-failed completed image falls back on initial scan`,()=>{
  const f=fixture(id,{complete:true,naturalWidth:0});try{f.boot();assert.equal(f.img.hidden,true);assert.equal(f.img.closest('section').dataset.aiImageState,'failed');assert.equal(f.d.querySelector('[data-ai-support-load-error]').hidden,false);f.unchanged();}finally{f.close();}
 });
 test(`${id}: existing successful image and singleton reinitialization are idempotent`,()=>{
  const f=fixture(id,{complete:true,naturalWidth:1086});try{const api=f.boot();const before=f.d.querySelector('[data-ai-support-illustration]').outerHTML;assert.equal(f.boot(),api);api.refresh();assert.equal(f.d.querySelector('[data-ai-support-illustration]').outerHTML,before);assert.equal(f.img.hidden,false);assert.equal(f.img.closest('section').dataset.aiImageState,'ready');f.unchanged();}finally{f.close();}
 });
 test(`${id}: dynamically added complete support section gets localized and load-handled`,async()=>{
  const f=fixture(id,{noSection:true,marthaLanguage:'en'});try{f.boot();f.d.querySelector('.wear-it-with').insertAdjacentHTML('beforebegin',readFragment(id));await settle();const s=f.d.querySelector('[data-ai-support-illustration]'),im=s.querySelector('img');assert.equal(s.dataset.aiLanguage,'en');assert.equal(im.alt,im.dataset.aiAltEn);im.dispatchEvent(new f.w.Event('error'));assert.equal(im.hidden,true);assert.equal(s.querySelector('[data-ai-support-load-error]').hidden,false);f.unchanged();}finally{f.close();}
 });
 test(`${id}: unknown path or wrong-PDP identity remains untouched by decorator`,()=>{
  for(const opts of [{badPath:'/generated-illustrations/not-approved.png'},{badPath:'https://foreign.test'+manifest.assets.find(a=>a.product_id===id).runtime_path_proposed_not_registered},{pageId:'verde-brillo-cuello-cruzado'}]){const f=fixture(id,opts);try{const before=f.d.querySelector('[data-ai-support-illustration]').outerHTML;f.boot();f.img.dispatchEvent(new f.w.Event('error'));assert.equal(f.d.querySelector('[data-ai-support-illustration]').outerHTML,before);f.unchanged();}finally{f.close();}}
 });
}

test('ordinary authentic image error is not captured as an AI illustration failure',()=>{
 const f=fixture(targets[0]);try{f.boot();const before=f.d.querySelector('[data-ai-support-illustration]').outerHTML;f.d.querySelector('#authentic-primary').dispatchEvent(new f.w.Event('error'));assert.equal(f.d.querySelector('[data-ai-support-illustration]').outerHTML,before);f.unchanged();}finally{f.close();}
});

test('html lang mutation localizes when MarthaI18n is absent',async()=>{
 const f=fixture(targets[0]);try{f.boot();f.d.documentElement.lang='en';await settle();assert.equal(f.img.alt,f.img.dataset.aiAltEn);f.unchanged();}finally{f.close();}
});
