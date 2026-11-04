'use strict';
// Independent selection.json is the expected contract; execution results live in evidence.
// Focused source-level DOM simulation. Native OS share sheets, layout and browser
// permission UI are not exercised; the parent release check owns built artifacts.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const {JSDOM, VirtualConsole} = require(process.env.MARTHA_JSDOM_PATH || './frontend-deps/node_modules/jsdom');
const root = path.resolve(__dirname, '..');
const staticRoot = path.join(root, 'build-inputs/static');
const selection = require('../evidence/green-photo-borders/selection.json');
const expected = selection.expected_media;
const variants = new Map(selection.variants.map(value => [value.path,value]));
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
    for (const file of ['demo-api.js', 'integration-adapters.js']) w.eval(fs.readFileSync(path.join(root, 'src', file), 'utf8'));
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
 assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(staticRoot,'styles.css'))).digest('hex'),'14275118ce05a69322963373243dc723294292d5caca78802d2f9cf1ed65d186','whole CSS remains byte-identical to published e2a base');
 const css=fs.readFileSync(path.join(staticRoot,'styles.css'),'utf8');const tail=css.split('/* GREEN cut A:')[1];assert.ok(tail);const next=tail.indexOf('/*',tail.indexOf('*/')+2);const delta=next<0?tail:tail.slice(0,next);assert.match(delta,/@media\(min-width:1024px\)/);assert.equal((delta.match(/main\[data-product-id="verde-brillo-cuello-cruzado"\]/g)||[]).length,2);assert.match(delta,/\.gallery-photo\{scroll-margin-top:var\(--store-sticky-header-height,106px\)\}/);assert.match(delta,/\.gallery-track>\.gallery-photo\{top:var\(--store-sticky-header-height,106px\);max-height:calc\(100svh - var\(--store-sticky-header-height,106px\)\)\}/);assert.doesNotMatch(delta,/first-child|image-dialog|object-fit|transform/);assert.doesNotMatch(delta,/(?:^|[;{])\s*(?:width|display)\s*:/);
});
test('Green has the approved four photo indices and fifth video with aligned controls, clones and rows',async()=>withPage({page:'producto-verde-brillo-cuello-cruzado.html'},b=>{
 assert.equal(selection.schema,1);
 assert.equal(selection.product_id,'verde-brillo-cuello-cruzado');
 assert.deepEqual(selection.active_positions,[1,3,4,5]);
 assert.deepEqual(selection.excluded_positions,[2]);
 assert.equal(selection.rows.length,4);
 assert.deepEqual(selection.rows.map(row=>row.position),[1,3,4,5]);
 assert.equal(selection.variants.length,22);
 assert.equal(b.d.querySelectorAll('[data-product-share]').length,1);
 assert.ok(b.d.querySelector('[data-favorite]'));
 const gallery=b.d.querySelector('main[data-product-id="verde-brillo-cuello-cruzado"] .product-gallery');
 assert.ok(gallery);
 const photos=[...gallery.querySelectorAll('.gallery-photo[data-gallery-index]')];
 assert.equal(photos.length,4);
 assert.deepEqual(photos.map(photo=>photo.dataset.galleryIndex),['0','1','2','3']);
 assert.deepEqual(photos.map(photo=>photo.dataset.zoom),expected.images);
 assert.equal(gallery.querySelectorAll('[data-zoom]').length,4);
 for(const [index,photo] of photos.entries()){
  const img=photo.querySelector('picture img'), source=photo.querySelector('source[type="image/webp"]');
  assert.ok(img);assert.ok(source);
  assert.equal(img.getAttribute('src'),expected.jpeg_images[index]);
  assert.equal(img.getAttribute('srcset'),expected.jpeg_sets[index]);
  assert.equal(source.getAttribute('srcset'),expected.image_sets[index]);
  for(const [node,url] of [[img,expected.jpeg_images[index]],[source,expected.images[index]]]){
   const variant=variants.get(url);assert.ok(variant,url);
   assert.equal(Number(node.getAttribute('width')),variant.width);
   assert.equal(Number(node.getAttribute('height')),variant.height);
  }
  assert.equal(photo.getAttribute('aria-label'),`Ampliar fotograf\u00eda ${index+1}`);
  assert.ok(img.getAttribute('alt')?.trim(),'existing descriptive alt retained');
 }
 const track=gallery.querySelector('[data-gallery-track]');
 assert.equal(track.style.getPropertyValue('--gallery-rows').trim(),'4');
 const video=gallery.querySelector('.gallery-video video[controls]');assert.ok(video);
 assert.equal(gallery.querySelectorAll('.gallery-video').length,1);
 assert.equal(video.getAttribute('data-src'),expected.video);
 assert.equal(video.getAttribute('data-webm'),expected.video_webm);
 assert.equal(video.getAttribute('poster'),expected.video_poster);
 for(const selector of ['.gallery-thumbnails','.gallery-dots']){
  const group=gallery.querySelector(selector);assert.ok(group,selector);
  const controls=[...group.querySelectorAll('[data-gallery-go]')];
  assert.equal(controls.length,5,selector);
  assert.deepEqual(controls.map(control=>control.dataset.galleryGo),['0','1','2','3','4']);
  assert.deepEqual(controls.filter(control=>control.getAttribute('aria-current')==='true').map(control=>control.dataset.galleryGo),['0']);
  if(selector==='.gallery-thumbnails') for(let index=0;index<4;index++){
   const img=controls[index].querySelector('picture img'),source=controls[index].querySelector('source[type="image/webp"]');
   assert.ok(img);assert.ok(source);
   assert.equal(img.getAttribute('src'),expected.jpeg_images[index]);
   assert.equal(img.getAttribute('srcset'),expected.jpeg_sets[index]);
   assert.equal(source.getAttribute('srcset'),expected.image_sets[index]);
   for(const [node,url] of [[img,expected.jpeg_images[index]],[source,expected.images[index]]]){
    const variant=variants.get(url);assert.ok(variant,url);
    assert.equal(Number(node.getAttribute('width')),variant.width);
    assert.equal(Number(node.getAttribute('height')),variant.height);
   }
  }
 }
 assert.match(gallery.querySelector('.gallery-thumbnails [data-gallery-go="4"]').getAttribute('aria-label'),/video/i);
 const clones=[...gallery.querySelectorAll('.gallery-clone')];assert.equal(clones.length,2);
 for(const [index,clone] of clones.entries()){
  const activeIndex=2+index; // Approved originals G4 and G5, in this order.
  assert.equal(clone.getAttribute('aria-hidden'),'true');assert.ok(clone.hasAttribute('inert'));
  assert.equal(clone.querySelector('img').getAttribute('src'),expected.jpeg_images[activeIndex]);
  assert.equal(clone.querySelector('img').getAttribute('srcset'),expected.jpeg_sets[activeIndex]);
  assert.equal(clone.querySelector('source').getAttribute('srcset'),expected.image_sets[activeIndex]);
  assert.equal(clone.querySelector('button,a,input,select,textarea,[tabindex]'),null,'clones must not add interactive views');
 }
 assert.doesNotMatch(gallery.outerHTML,/02-three-quarter-front-full-length/,'excluded G2 must not return through clone, thumbnail or zoom');
}));
(async()=>{let fails=0;for(const [name,run]of tests){try{await run();console.log('PASS '+name)}catch(e){fails++;console.error('FAIL '+name+'\n'+e.stack)}}console.log(`${tests.length-fails}/${tests.length} green header DOM/static checks passed (not browser layout)`);process.exitCode=fails?1:0;})();
