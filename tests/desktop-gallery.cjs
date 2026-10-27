'use strict';
// Source-level DOM simulations, WRITTEN BUT NOT RUN on Tony. Geometry, media,
// matchMedia and dialogs are fixtures; this is not CSS/render/native BFCache QA.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {JSDOM,VirtualConsole}=require(process.env.MARTHA_JSDOM_PATH||'./frontend-deps/node_modules/jsdom');
const root=path.resolve(__dirname,'..'),staticRoot=path.join(root,'build-inputs/static');
const tests=[],test=(name,run)=>tests.push([name,run]);
const settle=()=>new Promise(resolve=>setTimeout(resolve,35));

async function boot({desktop=true,reduced=false,width=360,deferScroll=false}={}){
 const errors=[],vc=new VirtualConsole();vc.on('jsdomError',error=>errors.push(error.message));
 const dom=new JSDOM(fs.readFileSync(path.join(staticRoot,'producto-verde-brillo-cuello-cruzado.html'),'utf8'),{
  url:'https://demo.test/producto-verde-brillo-cuello-cruzado.html?lang=es',runScripts:'outside-only',pretendToBeVisual:true,virtualConsole:vc,
 });
 const w=dom.window,d=w.document,viewport=d.querySelector('[data-gallery-viewport]');
 const slides=[...d.querySelectorAll('[data-gallery-track] .gallery-photo,[data-gallery-track] .gallery-video')];
 const media=new Map(),observers=[],scrollCalls=[],pageScroll=[],verticalCalls=[];
 let mode=desktop,frameWidth=width,offsets=null,router=null;
 const originals=slides.flatMap(slide=>[...slide.querySelectorAll('source[srcset],img[srcset]')]).map(node=>[node,node.getAttribute('sizes')]);
 const clones=[...viewport.querySelectorAll('.gallery-clone source[srcset],.gallery-clone img[srcset]')].map(node=>[node,node.getAttribute('sizes')]);
 const photoURLs=slides.filter(node=>node.matches('.gallery-photo')).map(node=>node.getAttribute('data-zoom'));
 try{
  Object.defineProperty(w,'innerWidth',{get:()=>mode?1180:390,configurable:true});
  w.matchMedia=query=>{
   if(!media.has(query)){
    const listeners=new Set();
    media.set(query,{get matches(){return query.includes('prefers-reduced-motion')?reduced:query.includes('min-width:1024px')?mode:query.includes('max-width:1023px')?!mode:false;},
     addEventListener(type,fn){if(type==='change')listeners.add(fn);},removeEventListener(type,fn){listeners.delete(fn);},
     notify(){for(const fn of [...listeners])fn(new w.Event('change'));},
    });
   }
   return media.get(query);
  };
  w.IntersectionObserver=class{observe(){}disconnect(){}};
  w.ResizeObserver=class{constructor(callback){this.callback=callback;this.targets=new Set();observers.push(this);}observe(target){this.targets.add(target);}disconnect(){this.targets.clear();}};
  w.CSS={escape:value=>value};
  w.HTMLElement.prototype.scrollIntoView=function(){verticalCalls.push(this);};
  w.HTMLElement.prototype.scrollTo=function(options){this.scrollLeft=options.left||0;this.scrollTop=options.top||0;};
  Object.defineProperty(viewport,'clientWidth',{get:()=>frameWidth,configurable:true});
  viewport.scrollTo=function(options){scrollCalls.push({...options});if(!deferScroll){this.scrollLeft=options.left;this.dispatchEvent(new w.Event('scroll'));}};
  slides.forEach((slide,index)=>{
   Object.defineProperty(slide,'offsetLeft',{get:()=>offsets?offsets[index]:index*frameWidth,configurable:true});
   Object.defineProperty(slide,'offsetWidth',{get:()=>frameWidth,configurable:true});
  });
  let pageX=0,pageY=0;
  Object.defineProperty(w,'scrollX',{get:()=>pageX,configurable:true});Object.defineProperty(w,'scrollY',{get:()=>pageY,configurable:true});
  w.scrollTo=(options,y)=>{pageScroll.push(options);if(typeof options==='number'){pageX=options;pageY=y||0;}else{pageX=options.left||0;pageY=options.top||0;}};
  w.HTMLMediaElement.prototype.pause=function(){this.__galleryPauseCount=(this.__galleryPauseCount||0)+1;};
  w.HTMLDialogElement.prototype.showModal=function(){this.open=true;this.querySelector('button,input,select')?.focus();};
  w.HTMLDialogElement.prototype.close=function(){this.open=false;this.dispatchEvent(new w.Event('close'));};
  w.barba={init(options){router=options.transitions[0];}};
  for(const file of ['catalog.js','locale-en.js','i18n.js'])w.eval(fs.readFileSync(path.join(staticRoot,file),'utf8'));
  for(const file of ['demo-api.js','integration-adapters.js','app.js'])w.eval(fs.readFileSync(path.join(root,'src',file),'utf8'));
  await settle();await settle();
  const b={w,d,viewport,slides,errors,originals,clones,photoURLs,scrollCalls,pageScroll,verticalCalls,router:()=>router,
   thumb:i=>d.querySelector(`.gallery-thumbnails [data-gallery-go="${i}"]`),
   current:()=>Number(d.querySelector('.gallery-thumbnails [aria-current="true"]').dataset.galleryGo),
   async setMode(value){mode=value;for(const q of media.values())q.notify();w.dispatchEvent(new w.Event('resize'));await settle();await settle();},
   async resize(value){frameWidth=value;for(const observer of observers)if(observer.targets.has(viewport))observer.callback([{target:viewport}]);w.dispatchEvent(new w.Event('resize'));await settle();await settle();},
   setOffsets(value){offsets=value;},
   async nativeScroll(left){viewport.scrollLeft=left;viewport.dispatchEvent(new w.Event('scroll'));await settle();},
   close:()=>w.close(),
  };
  return b;
 }catch(error){w.close();throw error;}
}
async function withPage(options,run){const b=await boot(options);try{await run(b);assert.deepEqual(b.errors,[]);}finally{b.close();}}

test('desktop thumbnail scrolls only the gallery and keeps the chosen control focused',()=>withPage({},async b=>{
 b.pageScroll.length=0;b.verticalCalls.length=0;
 b.thumb(3).focus();b.thumb(3).click();await settle();
 assert.equal(b.viewport.scrollLeft,b.slides[3].offsetLeft);assert.equal(b.current(),3);
 assert.equal(b.d.activeElement,b.thumb(3));assert.equal(b.verticalCalls.length,0);assert.equal(b.pageScroll.length,0);
 assert.equal(b.slides[3].hasAttribute('inert'),false);assert.equal(b.slides[0].getAttribute('aria-hidden'),'true');
 assert.equal(b.slides[0].getAttribute('tabindex'),'-1');
}));

test('next and previous wrap through the original video view without losing an index',()=>withPage({reduced:true},async b=>{
 assert.ok(b.slides.at(-1).matches('.gallery-video'));
 b.d.querySelector('[data-gallery-prev]').click();await settle();
 assert.equal(b.current(),b.slides.length-1);assert.equal(b.viewport.scrollLeft,b.slides.at(-1).offsetLeft);
 assert.equal(b.scrollCalls.at(-1).behavior,'instant');assert.equal(b.slides.at(-1).hasAttribute('inert'),false);
 b.d.querySelector('[data-gallery-next]').click();await settle();
 assert.equal(b.current(),0);assert.equal(b.viewport.scrollLeft,b.slides[0].offsetLeft);
}));

test('manual desktop scrolling selects the nearest real offset and moves focus out of an inactive slide',()=>withPage({},async b=>{
 b.setOffsets([0,400,900,1400,1800,2300]);b.slides[0].focus();
 await b.nativeScroll(910);
 assert.equal(b.current(),2);assert.equal(b.d.activeElement,b.slides[2]);assert.equal(b.slides[2].hasAttribute('inert'),false);
}));

test('desktop resize retains the selected slide and supplies the actual stage width to responsive images',()=>withPage({},async b=>{
 b.thumb(3).focus();b.thumb(3).click();await settle();
 await b.resize(430);
 assert.equal(b.current(),3);assert.equal(b.viewport.scrollLeft,1290);
 for(const [node] of b.originals)assert.equal(node.getAttribute('sizes'),'430px');
 for(const [node,sizes] of b.clones)assert.equal(node.getAttribute('sizes'),sizes,'mobile clone hints remain intact');
 const before=b.scrollCalls.length;await b.resize(430);assert.equal(b.scrollCalls.length,before,'same-size observer notification must not create a feedback loop');
}));

test('returning to mobile restores original hints and accessibility attributes while keeping navigation',()=>withPage({},async b=>{
 b.thumb(2).focus();b.thumb(2).click();await settle();
 await b.setMode(false);
 for(const [node,sizes] of b.originals)assert.equal(node.getAttribute('sizes'),sizes);
 for(const slide of b.slides){assert.equal(slide.hasAttribute('inert'),false);assert.equal(slide.hasAttribute('aria-hidden'),false);assert.equal(slide.hasAttribute('tabindex'),false);}
 b.d.querySelector('[data-gallery-next]').click();await settle();
 assert.equal(b.current(),3);assert.equal(b.viewport.scrollLeft,b.slides[3].offsetLeft);
 await b.nativeScroll(b.slides[1].offsetLeft);assert.equal(b.current(),1);
}));

test('desktop keyboard navigation preserves control focus and does not steal media or modified arrow keys',()=>withPage({},async b=>{
 b.slides[0].focus();b.slides[0].dispatchEvent(new b.w.KeyboardEvent('keydown',{key:'ArrowRight',bubbles:true,cancelable:true}));await settle();
 assert.equal(b.current(),1);assert.equal(b.d.activeElement,b.slides[1]);
 const next=b.d.querySelector('[data-gallery-next]');next.focus();next.dispatchEvent(new b.w.KeyboardEvent('keydown',{key:'Home',bubbles:true,cancelable:true}));await settle();
 assert.equal(b.current(),0);assert.equal(b.d.activeElement,next);
 const modified=new b.w.KeyboardEvent('keydown',{key:'ArrowRight',altKey:true,bubbles:true,cancelable:true});next.dispatchEvent(modified);
 assert.equal(modified.defaultPrevented,false);assert.equal(b.current(),0);
 const video=b.slides.at(-1).querySelector('video');const seek=new b.w.KeyboardEvent('keydown',{key:'ArrowRight',bubbles:true,cancelable:true});video.dispatchEvent(seek);
 assert.equal(seek.defaultPrevented,false);assert.equal(b.current(),0);
}));

test('zoom opens the selected authentic source and closes back to its photo button',()=>withPage({},async b=>{
 b.thumb(2).focus();b.thumb(2).click();await settle();
 const photo=b.slides[2];photo.focus();photo.click();
 const dialog=b.d.querySelector('#image-dialog');assert.equal(dialog.open,true);
 assert.equal(dialog.querySelector('img').getAttribute('src'),photo.dataset.zoom);
 dialog.querySelector('[data-close-dialog]').click();assert.equal(b.d.activeElement,photo);
}));

test('BFCache-style remount restores the gallery position and leaves only one navigation handler',()=>withPage({},async b=>{
 await b.nativeScroll(b.slides[3].offsetLeft);await settle();
 for(let i=0;i<2;i++){b.w.dispatchEvent(new b.w.PageTransitionEvent('pageshow',{persisted:true}));await settle();await settle();}
 assert.equal(b.viewport.scrollLeft,b.slides[3].offsetLeft);assert.equal(b.current(),3);
 const before=b.scrollCalls.length;b.d.querySelector('[data-gallery-next]').click();await settle();
 assert.equal(b.current(),4);assert.equal(b.scrollCalls.length,before+1);
}));

test('gallery navigation preserves photo identity, commercial selection, Share and the removed footer link',()=>withPage({},async b=>{
 const variant=b.d.querySelector('[name="variant"]');variant.checked=true;const value=variant.value;
 b.thumb(4).focus();b.thumb(4).click();await settle();
 assert.deepEqual(b.slides.filter(node=>node.matches('.gallery-photo')).map(node=>node.dataset.zoom),b.photoURLs);
 assert.equal(b.d.querySelector('[name="variant"]:checked').value,value);
 assert.equal(b.d.querySelectorAll('[data-product-share]').length,1);assert.equal(b.d.querySelector('footer a[href="/admin.html"]'),null);
}));

test('temporarily hidden geometry never replaces responsive sizes with zero and recovers the selected slide',()=>withPage({},async b=>{
 b.thumb(3).focus();b.thumb(3).click();await settle();
 await b.resize(0);for(const [node] of b.originals)assert.notEqual(node.getAttribute('sizes'),'0px');
 await b.resize(410);assert.equal(b.current(),3);assert.equal(b.viewport.scrollLeft,b.slides[3].offsetLeft);
}));

test('rapid navigation uses the requested destination while smooth scrolling crosses intermediate slides',()=>withPage({deferScroll:true},async b=>{
 const next=b.d.querySelector('[data-gallery-next]');next.focus();next.click();
 await b.nativeScroll(100);assert.equal(b.current(),1);
 next.click();assert.equal(b.scrollCalls.at(-1).left,b.slides[2].offsetLeft);
 await b.nativeScroll(400);assert.equal(b.current(),2);
 next.dispatchEvent(new b.w.KeyboardEvent('keydown',{key:'End',bubbles:true,cancelable:true}));
 await b.nativeScroll(800);assert.equal(b.current(),5);
 next.dispatchEvent(new b.w.KeyboardEvent('keydown',{key:'ArrowLeft',bubbles:true,cancelable:true}));
 assert.equal(b.scrollCalls.at(-1).left,b.slides[4].offsetLeft);
 await b.nativeScroll(b.slides[4].offsetLeft);assert.equal(b.current(),4);assert.equal(b.d.activeElement,next);
}));

test('a real user scroll interruption releases the pending desktop destination',()=>withPage({deferScroll:true},async b=>{
 b.thumb(4).focus();b.thumb(4).click();assert.equal(b.current(),4);
 b.viewport.dispatchEvent(new b.w.WheelEvent('wheel',{bubbles:true}));await b.nativeScroll(b.slides[1].offsetLeft);
 assert.equal(b.current(),1);
}));

test('Back after another viewport width restores the same photo instead of a raw pixel offset',()=>withPage({width:600},async b=>{
 b.thumb(2).focus();b.thumb(2).click();await settle();
 const saved=JSON.parse(JSON.stringify(b.w.history.state));
 assert.equal(b.viewport.scrollLeft,1200);
 assert.ok(saved.__marthaViewV1.containers.some(item=>item.galleryIndex===2));
 const main=b.d.querySelector('main'),router=b.router();assert.ok(router);
 await router.leave({trigger:'click',current:{container:main}});
 b.w.history.pushState({},'', '/catalogo.html?category=Gala');await b.resize(400);
 b.w.history.replaceState(saved,'','/producto-verde-brillo-cuello-cruzado.html?lang=es');
 const data={trigger:'back',event:{type:'popstate',state:saved},current:{container:main},next:{container:main}};
 await router.leave(data);router.enter(data);await router.after(data);await settle();await settle();
 assert.equal(b.viewport.scrollLeft,800);assert.equal(b.current(),2);
}));

test('native Back then Forward preserves the outgoing gallery without pagehide or an anchor click',()=>withPage({},async b=>{
 const stalePDP=JSON.parse(JSON.stringify(b.w.history.state)),main=b.d.querySelector('main'),router=b.router();
 b.thumb(2).focus();b.thumb(2).click();
 const catalog={__marthaViewV1:{id:'catalog-history-entry',url:'/catalogo.html',scroll:{x:0,y:0},containers:[]}};
 async function traverse(state,url,page,trigger){
  b.w.history.replaceState(state,'',url);
  const event=new b.w.PopStateEvent('popstate',{state});b.w.dispatchEvent(event);
  const data={trigger,event,current:{container:main},next:{container:main}};
  await router.leave(data);main.dataset.page=page;router.enter(data);await router.after(data);await settle();await settle();
 }
 await traverse(catalog,'/catalogo.html','catalog','back');
 await b.resize(420);
 await traverse(stalePDP,'/producto-verde-brillo-cuello-cruzado.html?lang=es','product','forward');
 assert.equal(b.current(),2);assert.equal(b.viewport.scrollLeft,840);
}));

(async()=>{let failures=0;for(const [name,run] of tests){try{await run();console.log('PASS '+name);}catch(error){failures++;console.error('FAIL '+name+'\n'+error.stack);}}console.log(`${tests.length-failures}/${tests.length} DOM cases passed; layout and native browser behavior not established.`);process.exitCode=failures?1:0;})();
