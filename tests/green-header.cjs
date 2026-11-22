'use strict';
// Green gallery contract: the page must render exactly the product images recorded in
// evidence/releases/20261030/luxury-selected-assets.json (the luxury selection release record,
// commit c4e0e48a), which replaced the earlier four-photo crop in evidence/green-photo-borders.
// Focused source-level DOM simulation. Native OS share sheets, layout and browser
// permission UI are not exercised; the parent release check owns built artifacts.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {JSDOM, VirtualConsole} = require(process.env.MARTHA_JSDOM_PATH || './frontend-deps/node_modules/jsdom');
const root = path.resolve(__dirname, '..');
const staticRoot = path.join(root, 'build-inputs/static');
const GREEN = 'verde-brillo-cuello-cruzado';
const greenRecords = require('../evidence/releases/20261030/luxury-selected-assets.json').selected_assets
  .filter(record => record.product_id === GREEN)
  .sort((left, right) => left.runtime_destination.localeCompare(right.runtime_destination));
const responsive = new Map(require('../build-inputs/static/responsive-images/manifest.json').assets.map(record => [record.original, record]));
const webpSet = (url, fallback) => responsive.has(url) ? responsive.get(url).derivatives.map(r => r.path + ' ' + r.width + 'w').join(', ') : fallback;
const tick = () => new Promise(resolve => setTimeout(resolve, 10));
const tests = [];
const test = (name, run) => tests.push([name, run]);
const label = element => element.textContent.replace(/\s+/g, ' ').trim();

async function boot({page = 'producto-dorado.html', query = '', language, setup, blockedStorage = false} = {}) {
  const errors = [], vc = new VirtualConsole();
  vc.on('jsdomError', error => errors.push(error.message));
  const dom = new JSDOM(fs.readFileSync(path.join(staticRoot, page), 'utf8'), {
    url: 'https://demo.test/' + page + query,
    runScripts: 'outside-only', pretendToBeVisual: true, virtualConsole: vc,
  });
  const w = dom.window;
  try {
    w.matchMedia = () => ({matches:false, addEventListener(){}});
    w.IntersectionObserver = class { observe(){} disconnect(){} };
    w.CSS = {escape:value => value};
    w.HTMLElement.prototype.scrollIntoView = function(){};
    w.HTMLElement.prototype.scrollTo = function(){};
    w.scrollTo = () => {};
    w.HTMLMediaElement.prototype.pause = function(){};
    w.HTMLDialogElement.prototype.showModal = function(){ this.open = true; this.querySelector('button,input,select')?.focus(); };
    w.HTMLDialogElement.prototype.close = function(){ this.open = false; this.dispatchEvent(new w.Event('close')); };
    if (language) w.localStorage.setItem('martha-language-v1', language);
    if (blockedStorage) Object.defineProperty(w, 'localStorage', {get(){throw new w.DOMException('blocked', 'SecurityError');}});
    for (const file of ['catalog.js', 'locale-en.js', 'i18n.js']) w.eval(fs.readFileSync(path.join(staticRoot, file), 'utf8'));
    for (const file of ['store-api.js', 'integration-adapters.js']) w.eval(fs.readFileSync(path.join(root, 'src', file), 'utf8'));
    if (setup) setup(w);
    w.eval(fs.readFileSync(path.join(root, 'src/app.js'), 'utf8'));
    await tick(); await tick();
    const d = w.document;
    return {w, d, errors, button:() => d.querySelector('[data-product-share]'), status:() => d.querySelector('[data-product-share-status]'), close:() => w.close()};
  } catch(error) { w.close(); throw error; }
}
async function withPage(options, run) {
  const b = await boot(options);
  try { await run(b); assert.deepEqual(b.errors, []); } finally { b.close(); }
}
function clipboard(w, writeText) { Object.defineProperty(w.navigator, 'clipboard', {value:{writeText}, configurable:true}); }


test('sticky header measurement excludes banners, language and integration rows',async()=>withPage({page:'producto-verde-brillo-cuello-cruzado.html',setup:w=>{
 for(const e of w.document.querySelectorAll('.test-banner,.language-bar,[data-integration-panel],.site-header'))e.getBoundingClientRect=()=>({height:e.matches('.site-header')?106:32});
}},b=>{assert.equal(b.d.documentElement.style.getPropertyValue('--store-sticky-header-height'),'106px');assert.ok(parseFloat(b.d.documentElement.style.getPropertyValue('--store-chrome-height'))>106);}));
test('resize updates the exact measured header height with safe rounding',async()=>withPage({page:'producto-verde-brillo-cuello-cruzado.html',setup:w=>{w.document.querySelector('.site-header').getBoundingClientRect=()=>({height:106});}},b=>{
 b.d.querySelector('.site-header').getBoundingClientRect=()=>({height:123.25});b.w.dispatchEvent(new b.w.Event('resize'));assert.equal(b.d.documentElement.style.getPropertyValue('--store-sticky-header-height'),'124px');
}));
test('ResizeObserver follows header changes without relying on viewport resize',async()=>{const observers=[];await withPage({page:'producto-verde-brillo-cuello-cruzado.html',setup:w=>{
 w.document.querySelector('.site-header').getBoundingClientRect=()=>({height:106});w.ResizeObserver=class{constructor(cb){this.cb=cb;this.targets=[];observers.push(this)}observe(e){this.targets.push(e)}disconnect(){}};
}},b=>{const h=b.d.querySelector('.site-header');h.getBoundingClientRect=()=>({height:118});const o=observers.find(x=>x.targets.includes(h));assert.ok(o);o.cb();assert.equal(b.d.documentElement.style.getPropertyValue('--store-sticky-header-height'),'118px');});});
test('a page without the global header safely exposes zero sticky header height',async()=>withPage({page:'checkout.html'},b=>{assert.equal(b.d.querySelector('.site-header'),null);assert.equal(b.d.documentElement.style.getPropertyValue('--store-sticky-header-height'),'0px');}));
test('the CSS delta is desktop and exact-SKU scoped, with no pixel or zoom rule',()=>{
 const css=fs.readFileSync(path.join(staticRoot,'styles.css'),'utf8');const tail=css.split('/* GREEN cut A:')[1];assert.ok(tail);const next=tail.indexOf('/*',tail.indexOf('*/')+2);const delta=next<0?tail:tail.slice(0,next);assert.match(delta,/@media\(min-width:1024px\)/);assert.equal((delta.match(/main\[data-product-id="verde-brillo-cuello-cruzado"\]/g)||[]).length,2);assert.match(delta,/\.gallery-photo\{scroll-margin-top:var\(--store-sticky-header-height,106px\)\}/);assert.match(delta,/\.gallery-track>\.gallery-photo\{top:var\(--store-sticky-header-height,106px\);max-height:calc\(100svh - var\(--store-sticky-header-height,106px\)\)\}/);assert.doesNotMatch(delta,/first-child|image-dialog|object-fit|transform/);assert.doesNotMatch(delta,/(?:^|[;{])\s*(?:width|display)\s*:/);
});
test('Green renders exactly its recorded product images, then one video, with aligned controls and inert clones',async()=>withPage({page:'producto-verde-brillo-cuello-cruzado.html'},b=>{
 assert.equal(greenRecords.length,3,'luxury selection record lists three Green images');
 const base=b.w.STORE_CATALOG.products.find(item=>item.id===GREEN);assert.ok(base);
 // catalog.js applies STORE_MEDIA over the base record; JSON copy leaves the jsdom realm for strict comparison.
 const product=JSON.parse(JSON.stringify({...base,...((b.w.STORE_MEDIA||{})[GREEN]||{})}));
 const recorded=greenRecords.map(record=>'/'+record.runtime_destination);
 assert.deepEqual(product.images,recorded,'catalog images come from the selection record');
 const size=new Map(greenRecords.map(record=>['/'+record.runtime_destination,record.dimensions]));
 for(const url of [...product.images,...product.jpeg_images])assert.ok(fs.statSync(path.join(staticRoot,url)).isFile(),url);
 assert.equal(b.d.querySelectorAll('[data-product-share]').length,1);
 assert.ok(b.d.querySelector('[data-favorite]'));
 const gallery=b.d.querySelector(`main[data-product-id="${GREEN}"] .product-gallery`);
 assert.ok(gallery);
 const n=product.images.length;
 const photos=[...gallery.querySelectorAll('.gallery-photo[data-gallery-index]')];
 assert.equal(photos.length,n);
 assert.deepEqual(photos.map(photo=>photo.dataset.galleryIndex),[...Array(n).keys()].map(String));
 assert.deepEqual(photos.map(photo=>photo.dataset.zoom),product.images);
 assert.equal(gallery.querySelectorAll('[data-zoom]').length,n);
 const checkPicture=(img,source,index)=>{
  assert.ok(img);assert.ok(source);
  assert.equal(img.getAttribute('src'),product.jpeg_images[index]);
  assert.equal(img.getAttribute('srcset'),product.jpeg_sets[index]);
  assert.equal(source.getAttribute('srcset'),webpSet(product.images[index],product.image_sets[index]));
  const [width,height]=size.get(product.images[index]);
  assert.equal(Number(img.getAttribute('width')),width);
  assert.equal(Number(img.getAttribute('height')),height);
 };
 for(const [index,photo] of photos.entries()){
  checkPicture(photo.querySelector('picture img'),photo.querySelector('source[type="image/webp"]'),index);
  assert.equal(photo.getAttribute('aria-label'),`Ampliar fotograf\u00eda ${index+1}`);
  assert.ok(photo.querySelector('picture img').getAttribute('alt')?.trim(),'descriptive alt retained');
 }
 const track=gallery.querySelector('[data-gallery-track]');
 assert.equal(track.style.getPropertyValue('--gallery-rows').trim(),String(n));
 const videos=gallery.querySelectorAll('.gallery-video');
 assert.equal(videos.length,product.video?1:0);
 if(product.video){
  const video=gallery.querySelector('.gallery-video video[controls]');assert.ok(video);
  assert.equal(video.getAttribute('data-src'),product.video);
  if(product.video_webm)assert.equal(video.getAttribute('data-webm'),product.video_webm);
  // The page shows the poster as its same-width WebP derivative; the catalog keeps the original PNG.
  const poster=responsive.get(product.video_poster);
  assert.equal(video.getAttribute('poster'),poster?poster.derivatives.find(d=>d.width===poster.width).path:product.video_poster);
 }
 const total=n+videos.length;
 for(const selector of ['.gallery-thumbnails','.gallery-dots']){
  const group=gallery.querySelector(selector);assert.ok(group,selector);
  const controls=[...group.querySelectorAll('[data-gallery-go]')];
  assert.deepEqual(controls.map(control=>control.dataset.galleryGo),[...Array(total).keys()].map(String),selector);
  assert.deepEqual(controls.filter(control=>control.getAttribute('aria-current')==='true').map(control=>control.dataset.galleryGo),['0']);
  if(selector==='.gallery-thumbnails')for(let index=0;index<n;index++)
   checkPicture(controls[index].querySelector('picture img'),controls[index].querySelector('source[type="image/webp"]'),index);
 }
 if(videos.length)assert.match(gallery.querySelector(`.gallery-thumbnails [data-gallery-go="${n}"]`).getAttribute('aria-label'),/video/i);
 for(const clone of gallery.querySelectorAll('.gallery-clone')){
  assert.equal(clone.getAttribute('aria-hidden'),'true');assert.ok(clone.hasAttribute('inert'));
  assert.ok(product.jpeg_images.includes(clone.querySelector('img').getAttribute('src')),'clone repeats a recorded image');
  assert.equal(clone.querySelector('button,a,input,select,textarea,[tabindex]'),null,'clones must not add interactive views');
 }
 const listed=new Set([...product.images,...product.jpeg_images,product.video,product.video_webm,product.video_poster,
  ...product.images.flatMap(url=>(responsive.get(url)?.derivatives||[]).map(r=>r.path))].filter(Boolean));
 for(const node of gallery.querySelectorAll('img[src],source[srcset],[data-zoom]')){
  const urls=[node.getAttribute('src'),node.getAttribute('data-zoom'),...(node.getAttribute('srcset')||'').split(',').map(part=>part.trim().split(/\s+/)[0])].filter(Boolean);
  for(const url of urls)assert.ok(listed.has(url),'unrecorded gallery image: '+url);
 }
}));
(async()=>{let fails=0;for(const [name,run]of tests){try{await run();console.log('PASS '+name)}catch(e){fails++;console.error('FAIL '+name+'\n'+e.stack)}}console.log(`${tests.length-fails}/${tests.length} green header DOM/static checks passed (not browser layout)`);process.exitCode=fails?1:0;})();
