'use strict';
// Source-level DOM simulations for the CURRENT Jason gallery contract.
// WRITTEN FOR THE CURRENT SOURCE, NOT A BROWSER. jsdom has no layout, CSS,
// native BFCache or real keyboard. Geometry, media, matchMedia and dialogs are
// fixtures. Real-keyboard and responsive-resource evidence lives in
// tests/gallery-browser-contracts.cjs and docs/gallery-contracts-20261107/.
//
// Fixture binding (honest, not inferred): this product HTML has 4 slides:
// 3 photo buttons + 1 video. Tests derive first/last/previous from
// slides.length and assert the binding at boot.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {JSDOM,VirtualConsole}=require(process.env.MARTHA_JSDOM_PATH||'./frontend-deps/node_modules/jsdom');
const root=path.resolve(__dirname,'..'),staticRoot=path.join(root,'build-inputs/static');
const tests=[],test=(name,run)=>tests.push([name,run]);
const settle=()=>new Promise(resolve=>setTimeout(resolve,35));
const FIXTURE={slides:4,photos:3,videos:1};
// A responsive hint is a real user-facing contract only if it resolves to a
// usable width at the viewport being rendered. 1px/0px must fail. Static
// build hints and measured px values are both valid.
const MIN_USABLE_HINT_PX=100;
function sizesHintPx(sizes,viewportWidth){
 if(!sizes)return NaN;
 const parts=sizes.split(',').map(part=>part.trim()).filter(Boolean);
 for(const part of parts){
  const m=part.match(/^(?:\(([^)]+)\)\s*)?(.+)$/);
  if(!m)continue;
  const condition=m[1],value=m[2].trim();
  if(condition){
   const max=condition.match(/max-width:\s*(\d+)px/);
   const min=condition.match(/min-width:\s*(\d+)px/);
   if(max&&!(viewportWidth<=Number(max[1])))continue;
   if(min&&!(viewportWidth>=Number(min[1])))continue;
  }
  const px=value.match(/^([\d.]+)px$/);
  if(px)return Number(px[1]);
  const vw=value.match(/^([\d.]+)vw$/);
  if(vw)return Number(vw[1])*viewportWidth/100;
 }
 return NaN;
}
function assertUsableHint(node,viewportWidth,label){
 const sizes=node.getAttribute('sizes');
 const px=sizesHintPx(sizes,viewportWidth);
 assert.ok(Number.isFinite(px),`${label}: sizes hint is parseable (${JSON.stringify(sizes)})`);
 assert.ok(px>=MIN_USABLE_HINT_PX,`${label}: sizes hint ${JSON.stringify(sizes)} resolves to ${px}px, expected >= ${MIN_USABLE_HINT_PX}px at ${viewportWidth}px viewport`);
 assert.ok(px<=Math.max(viewportWidth*2,2048),`${label}: sizes hint ${JSON.stringify(sizes)} resolves to ${px}px, expected <= a plausible slot`);
}
function isUsable(node){
 return !!node&&node.isConnected&&!node.disabled&&!node.closest('[inert]')&&node.getAttribute('aria-hidden')!=='true';
}
function assertSelectedUsable(slide,label){
 assert.equal(slide.hasAttribute('inert'),false,`${label}: selected slide is not inert`);
 assert.notEqual(slide.getAttribute('aria-hidden'),'true',`${label}: selected slide is not hidden from assistive tech`);
 assert.equal(slide.hidden,false,`${label}: selected slide is not hidden`);
}
function key(w,key,extra={}){return new w.KeyboardEvent('keydown',{key,bubbles:true,cancelable:true,...extra});}

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
 const observed={};
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
  // jsdom has no layout. Model exactly the geometry app.js consumes in desktopLeft():
  // scrollWidth, clientLeft and both bounding rects. No product source is changed.
  Object.defineProperty(viewport,'scrollWidth',{get:()=>offsets?Math.max(...offsets)+frameWidth:slides.length*frameWidth,configurable:true});
  Object.defineProperty(viewport,'clientLeft',{value:0,configurable:true});
  viewport.getBoundingClientRect=()=>({left:0,top:0,right:frameWidth,bottom:0,width:frameWidth,height:0,x:0,y:0});
  slides.forEach(slide=>{
   slide.getBoundingClientRect=()=>({left:slide.offsetLeft-viewport.scrollLeft,top:0,right:slide.offsetLeft-viewport.scrollLeft+frameWidth,bottom:0,width:frameWidth,height:0,x:slide.offsetLeft-viewport.scrollLeft,y:0});
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
  assert.equal(slides.length,FIXTURE.slides,'fixture binding: slide count');
  assert.equal(slides.filter(node=>node.matches('.gallery-photo')).length,FIXTURE.photos,'fixture binding: photo count');
  assert.equal(slides.filter(node=>node.matches('.gallery-video')).length,FIXTURE.videos,'fixture binding: video count');
  const b={w,d,viewport,slides,errors,originals,clones,photoURLs,scrollCalls,pageScroll,verticalCalls,observed,router:()=>router,
   viewportWidth:()=>mode?1180:390,
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

test('desktop thumbnail selects the slide, scrolls only the gallery and keeps a usable focused control',()=>withPage({},async b=>{
 b.pageScroll.length=0;b.verticalCalls.length=0;
 const last=b.slides.length-1;
 b.thumb(last).focus();b.thumb(last).click();await settle();
 assert.equal(b.viewport.scrollLeft,b.slides[last].offsetLeft);
 assert.equal(b.current(),last);
 assert.equal(b.d.activeElement,b.thumb(last));
 assert.equal(b.verticalCalls.length,0);
 assert.equal(b.pageScroll.length,0);
 assertSelectedUsable(b.slides[last],'DG01');
 // Equivalent implementations allowed: every photo button must be reachable by focus.
 for(const photo of b.slides.filter(node=>node.matches('.gallery-photo'))){photo.focus();assert.equal(b.d.activeElement,photo,'each photo button is focusable');}
 // Inactive-slide policy is recorded as an observation, not an attribute recipe.
 b.observed.inactiveSlides=b.slides.map((slide,i)=>({i,selected:i===last,inert:slide.hasAttribute('inert'),ariaHidden:slide.getAttribute('aria-hidden'),tabindex:slide.getAttribute('tabindex')}));
}));

test('next and previous reach first/last through the original video view without losing an index',()=>withPage({reduced:true},async b=>{
 const last=b.slides.length-1,previous=(0-1+b.slides.length)%b.slides.length;
 assert.equal(last,b.slides.length-1);
 assert.equal(previous,last);
 assert.ok(b.slides[last].matches('.gallery-video'));
 b.d.querySelector('[data-gallery-prev]').click();await settle();
 assert.equal(b.current(),last);assert.equal(b.viewport.scrollLeft,b.slides[last].offsetLeft);
 assert.equal(b.scrollCalls.at(-1).behavior,'instant');
 assertSelectedUsable(b.slides[last],'DG10 previous from first');
 b.d.querySelector('[data-gallery-next]').click();await settle();
 assert.equal(b.current(),0);assert.equal(b.viewport.scrollLeft,b.slides[0].offsetLeft);
 assertSelectedUsable(b.slides[0],'DG10 next from last');
}));

test('manual desktop scrolling selects the nearest real offset and leaves usable focus on a gallery element',()=>withPage({},async b=>{
 b.setOffsets([0,400,900,1400]);b.slides[0].focus();
 await b.nativeScroll(910);
 assert.equal(b.current(),2);
 // Focus policy is an outcome: keep the user's control or move to the selected
 // slide. Either is acceptable if the active element is a usable gallery element.
 const active=b.d.activeElement;
 assert.ok(active===b.slides[0]||active===b.slides[2],'focus stays on a gallery element');
 assert.ok(isUsable(active),'active element is usable');
 assertSelectedUsable(b.slides[2],'DG03');
 b.observed.dg03Focus={retainedOnPhoto0:active===b.slides[0],movedToSelected:active===b.slides[2]};
 // Subsequent focus on the selected slide works (usable focus destination).
 b.slides[2].focus();assert.equal(b.d.activeElement,b.slides[2]);
}));

test('desktop resize retains the selected slide, keeps valid hints and creates no feedback loop',()=>withPage({},async b=>{
 const last=b.slides.length-1;
 b.thumb(last).focus();b.thumb(last).click();await settle();
 await b.resize(430);
 assert.equal(b.current(),last);assert.equal(b.viewport.scrollLeft,b.slides[last].offsetLeft);
 // Independent hint contract: resolves to a usable slot width at this viewport.
 for(const [node] of b.originals)assertUsableHint(node,b.viewportWidth(),'DG04 original');
 for(const [node] of b.clones)assertUsableHint(node,b.viewportWidth(),'DG04 mobile clone');
 b.observed.dg04Sizes=[...b.originals].map(([node])=>({sizes:node.getAttribute('sizes'),resolvedPx:sizesHintPx(node.getAttribute('sizes'),b.viewportWidth())}));
 const before=b.scrollCalls.length;await b.resize(430);assert.equal(b.scrollCalls.length,before,'same-size observer notification must not create a feedback loop');
}));

test('returning to mobile keeps navigation, reachable photos and valid hints',()=>withPage({},async b=>{
 b.thumb(2).focus();b.thumb(2).click();await settle();
 await b.setMode(false);
 for(const [node] of b.originals)assertUsableHint(node,b.viewportWidth(),'DG05 original');
 for(const [node] of b.clones)assertUsableHint(node,b.viewportWidth(),'DG05 mobile clone');
 assertSelectedUsable(b.slides[2],'DG05');
 for(const photo of b.slides.filter(node=>node.matches('.gallery-photo'))){photo.focus();assert.equal(b.d.activeElement,photo,'each photo button is reachable on mobile');}
 b.d.querySelector('[data-gallery-next]').click();await settle();
 assert.equal(b.current(),3);assert.equal(b.viewport.scrollLeft,b.slides[3].offsetLeft);
 await b.nativeScroll(b.slides[1].offsetLeft);assert.equal(b.current(),1);
}));

test('keyboard either navigates or stays native without hijacking modified or media keys',()=>withPage({},async b=>{
 b.slides[0].focus();
 const before=b.current();
 const right=key(b.w,'ArrowRight');b.slides[0].dispatchEvent(right);await settle();
 assert.ok([before,(before+1)%b.slides.length].includes(b.current()),'unmodified ArrowRight either navigates or is left native');
 assert.ok(b.d.activeElement===b.slides[0]||b.d.activeElement===b.slides[1],'focus remains on a gallery element');
 const next=b.d.querySelector('[data-gallery-next]');next.focus();
 const indexBefore=b.current();
 const home=key(b.w,'Home');next.dispatchEvent(home);await settle();
 assert.ok([indexBefore,0].includes(b.current()),'Home either selects first or is left native');
 assert.equal(b.d.activeElement,next,'Home does not steal focus from the control');
 const modifiedBefore=b.current();
 const modified=key(b.w,'ArrowRight',{altKey:true});next.dispatchEvent(modified);
 assert.equal(b.current(),modifiedBefore,'Alt+ArrowRight never changes the gallery index');
 const video=b.slides.at(-1).querySelector('video');const mediaBefore=b.current();
 const seek=key(b.w,'ArrowRight');video.dispatchEvent(seek);
 assert.equal(b.current(),mediaBefore,'ArrowRight on the video is reserved for media, not the gallery');
 b.observed.dg06={arrowRightDefaultPrevented:right.defaultPrevented,homeDefaultPrevented:home.defaultPrevented,modifiedDefaultPrevented:modified.defaultPrevented,mediaDefaultPrevented:seek.defaultPrevented};
}));

test('zoom opens the selected authentic source and closes back to its photo button',()=>withPage({},async b=>{
 b.thumb(2).focus();b.thumb(2).click();await settle();
 const photo=b.slides[2];photo.focus();photo.click();
 const dialog=b.d.querySelector('#image-dialog');assert.equal(dialog.open,true);
 assert.equal(dialog.querySelector('img').getAttribute('src'),photo.dataset.zoom);
 dialog.querySelector('[data-close-dialog]').click();assert.equal(b.d.activeElement,photo);
}));

test('BFCache-style remount restores the gallery position and leaves only one navigation handler',()=>withPage({},async b=>{
 const last=b.slides.length-1;
 await b.nativeScroll(b.slides[last].offsetLeft);await settle();
 for(let i=0;i<2;i++){b.w.dispatchEvent(new b.w.PageTransitionEvent('pageshow',{persisted:true}));await settle();await settle();}
 assert.equal(b.viewport.scrollLeft,b.slides[last].offsetLeft);assert.equal(b.current(),last);
 const before=b.scrollCalls.length;b.d.querySelector('[data-gallery-next]').click();await settle();
 assert.equal(b.current(),0);assert.equal(b.viewport.scrollLeft,b.slides[0].offsetLeft);assert.equal(b.scrollCalls.length,before+1);
}));

test('gallery navigation preserves photo identity, commercial selection, Share and the removed footer link',()=>withPage({},async b=>{
 const variant=b.d.querySelector('[name="variant"]');variant.checked=true;const value=variant.value;
 const last=b.slides.length-1;
 b.thumb(last).focus();b.thumb(last).click();await settle();
 assert.deepEqual(b.slides.filter(node=>node.matches('.gallery-photo')).map(node=>node.dataset.zoom),b.photoURLs);
 assert.equal(b.d.querySelector('[name="variant"]:checked').value,value);
 assert.equal(b.d.querySelectorAll('[data-product-share]').length,1);assert.equal(b.d.querySelector('footer a[href="/admin.html"]'),null);
}));

test('temporarily hidden geometry never replaces responsive sizes with zero and recovers the selected slide',()=>withPage({},async b=>{
 const last=b.slides.length-1;
 b.thumb(last).focus();b.thumb(last).click();await settle();
 await b.resize(0);
 for(const [node] of b.originals){assert.notEqual(node.getAttribute('sizes'),'0px');assertUsableHint(node,b.viewportWidth(),'DG09 hidden geometry');}
 await b.resize(410);assert.equal(b.current(),last);assert.equal(b.viewport.scrollLeft,b.slides[last].offsetLeft);
}));

test('rapid navigation uses the requested destination and Home/End stay native or reach first/last',()=>withPage({deferScroll:true},async b=>{
 const last=b.slides.length-1;
 const next=b.d.querySelector('[data-gallery-next]');next.focus();next.click();
 await b.nativeScroll(100);assert.equal(b.current(),1);
 next.click();assert.equal(b.scrollCalls.at(-1).left,b.slides[2].offsetLeft);
 await b.nativeScroll(400);assert.equal(b.current(),2);
 const calls=b.scrollCalls.length;
 const beforeEnd=b.current();
 const end=key(b.w,'End');next.dispatchEvent(end);await settle();
 assert.ok([beforeEnd,last].includes(b.current()),'End either reaches the last slide or stays native');
 const beforeLeft=b.current();
 const left=key(b.w,'ArrowLeft');next.dispatchEvent(left);await settle();
 assert.ok([beforeLeft,(beforeLeft-1+b.slides.length)%b.slides.length].includes(b.current()),'ArrowLeft either goes to the previous slide or stays native');
 assert.equal(b.d.activeElement,next,'navigation keys do not steal focus from the control');
 b.observed.dg10={scrollCallsBeforeKeys:calls,scrollCallsAfterKeys:b.scrollCalls.length,endDefaultPrevented:end.defaultPrevented,leftDefaultPrevented:left.defaultPrevented};
}));

test('a real user scroll interruption releases the pending desktop destination',()=>withPage({deferScroll:true},async b=>{
 const last=b.slides.length-1;
 b.thumb(last).focus();b.thumb(last).click();assert.equal(b.current(),last);
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

(async()=>{let failures=0;for(const [name,run] of tests){try{await run();console.log('PASS '+name);}catch(error){failures++;console.error('FAIL '+name+'\n'+error.stack);}}console.log(`${tests.length-failures}/${tests.length} DOM cases passed; layout, real keyboard and native browser behavior not established here.`);process.exitCode=failures?1:0;})();
