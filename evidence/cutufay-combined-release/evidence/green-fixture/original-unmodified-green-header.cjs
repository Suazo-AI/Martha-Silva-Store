'use strict';
// Focused source-level DOM simulation. Native OS share sheets, layout and browser
// permission UI are not exercised; the parent release check owns built artifacts.
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const {JSDOM, VirtualConsole} = require(process.env.MARTHA_JSDOM_PATH || './frontend-deps/node_modules/jsdom');
const root = path.resolve(__dirname, '..');
const staticRoot = path.join(root, 'build-inputs/static');
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
 const css=fs.readFileSync(path.join(staticRoot,'styles.css'),'utf8');const delta=css.split('/* GREEN cut A:')[1];assert.ok(delta);assert.match(delta,/@media\(min-width:1024px\)/);assert.equal((delta.match(/main\[data-product-id="verde-brillo-cuello-cruzado"\]/g)||[]).length,2);assert.match(delta,/\.gallery-photo\{scroll-margin-top:var\(--store-sticky-header-height,106px\)\}/);assert.match(delta,/\.gallery-track>\.gallery-photo\{top:var\(--store-sticky-header-height,106px\);max-height:calc\(100svh - var\(--store-sticky-header-height,106px\)\)\}/);assert.doesNotMatch(delta,/first-child|image-dialog|object-fit|transform/);assert.doesNotMatch(delta,/(?:^|[;{])\s*(?:width|display)\s*:/);
});
test('share, favorites and gallery controls remain mounted on the unchanged green PDP',async()=>withPage({page:'producto-verde-brillo-cuello-cruzado.html'},b=>{assert.equal(b.d.querySelectorAll('[data-product-share]').length,1);assert.ok(b.d.querySelector('[data-favorite]'));assert.equal(b.d.querySelectorAll('[data-gallery-index]').length,5);assert.ok(b.d.querySelector('[data-zoom]'));}));
(async()=>{let fails=0;for(const [name,run]of tests){try{await run();console.log('PASS '+name)}catch(e){fails++;console.error('FAIL '+name+'\n'+e.stack)}}console.log(`${tests.length-fails}/${tests.length} green header DOM/static checks passed (not browser layout)`);process.exitCode=fails?1:0;})();
