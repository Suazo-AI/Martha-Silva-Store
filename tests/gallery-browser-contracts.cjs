'use strict';
// Real installed Chrome (headless), real keyboard, local immutable dist.
// Read-only: serves this worktree's dist/ on 127.0.0.1:18433 and never writes
// product bytes. Programmatic scroll is SETUP only; every activation below is a
// real Tab/Shift+Tab/Enter/Space/Home/End/modified/media key press.
//
// Evidence written to docs/gallery-contracts-20261107/browser-contracts.json.
const fs=require('node:fs'),http=require('node:http'),path=require('node:path'),assert=require('node:assert/strict');
const core=require(path.join(process.env.APPDATA,'npm','node_modules','@playwright','cli','node_modules','playwright-core'));
const ROOT=path.resolve(__dirname,'..','dist');
const HOST='127.0.0.1',PORT=Number(process.env.GALLERY_PORT||18433),BASE=`http://${HOST}:${PORT}`;
const PAGE='/producto-verde-brillo-cuello-cruzado.html';
const CHROME='C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const OUTDIR=process.env.GALLERY_OUTDIR?path.resolve(process.env.GALLERY_OUTDIR):path.resolve(__dirname,'..','docs','gallery-contracts-20261107');
fs.mkdirSync(OUTDIR,{recursive:true});
const OUT=path.join(OUTDIR,'browser-contracts.json');
const MAX_TABS=240;
const MIME={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.js':'text/javascript; charset=utf-8','.json':'application/json','.webp':'image/webp','.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg','.svg':'image/svg+xml','.woff2':'font/woff2','.woff':'font/woff','.ttf':'font/ttf','.mp4':'video/mp4','.webm':'video/webm','.ico':'image/x-icon','.txt':'text/plain'};
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
function sizesHintPx(sizes,viewportWidth){
 if(!sizes)return NaN;
 for(const part of sizes.split(',').map(part=>part.trim()).filter(Boolean)){
  const m=part.match(/^(?:\(([^)]+)\)\s*)?(.+)$/);
  if(!m)continue;
  const condition=m[1],value=m[2].trim();
  if(condition){
   const max=condition.match(/max-width:\s*(\d+)px/),min=condition.match(/min-width:\s*(\d+)px/);
   if(max&&!(viewportWidth<=Number(max[1])))continue;
   if(min&&!(viewportWidth>=Number(min[1])))continue;
  }
  const px=value.match(/^([\d.]+)px$/);if(px)return Number(px[1]);
  const vw=value.match(/^([\d.]+)vw$/);if(vw)return Number(vw[1])*viewportWidth/100;
 }
 return NaN;
}
function startServer(){
 return new Promise((resolve,reject)=>{
  const server=http.createServer((req,res)=>{
   try{
    const url=new URL(req.url,BASE);
    let rel=decodeURIComponent(url.pathname);
    if(rel.endsWith('/'))rel+='index.html';
    const file=path.normalize(path.join(ROOT,rel));
    if(!file.startsWith(ROOT)){res.writeHead(403);res.end('forbidden');return;}
    if(!fs.existsSync(file)||!fs.statSync(file).isFile()){res.writeHead(404,{'Content-Type':'text/plain'});res.end('not found');return;}
    const body=fs.readFileSync(file);
    res.writeHead(200,{'Content-Type':MIME[path.extname(file).toLowerCase()]||'application/octet-stream','Content-Length':body.length,'Cache-Control':'no-store'});
    res.end(body);
   }catch(error){res.writeHead(500,{'Content-Type':'text/plain'});res.end(String(error));}
  });
  server.on('error',reject);
  server.listen(PORT,HOST,()=>resolve(server));
 });
}
async function activeInfo(page){
 return page.evaluate(()=>{
  const a=document.activeElement;
  if(!a)return {tag:null};
  const r=a.getBoundingClientRect(),style=getComputedStyle(a);
  return {tag:a.tagName,cls:typeof a.className==='string'?a.className:null,
   go:a.getAttribute('data-gallery-go'),prev:a.hasAttribute('data-gallery-prev'),next:a.hasAttribute('data-gallery-next'),
   photo:a.classList.contains('gallery-photo'),video:a.tagName==='VIDEO',inGallery:!!a.closest('.product-gallery'),
   inThumbs:!!a.closest('.gallery-thumbnails'),inDots:!!a.closest('.gallery-dots'),inArrows:!!a.closest('.gallery-arrows'),
   ariaCurrent:a.getAttribute('aria-current'),
   rect:{x:Math.round(r.x),y:Math.round(r.y),w:Math.round(r.width),h:Math.round(r.height)},
   visible:r.width>0&&r.height>0&&r.bottom>0&&r.right>0&&r.top<innerHeight&&r.left<innerWidth,
   display:style.display,visibility:style.visibility,focusVisible:a.matches(':focus-visible')};
 });
}
async function galleryState(page){
 return page.evaluate(()=>{
  const v=document.querySelector('[data-gallery-viewport]');
  const controls=[...document.querySelectorAll('.gallery-thumbnails [data-gallery-go],.gallery-dots [data-gallery-go]')];
  const current=controls.find(b=>b.getAttribute('aria-current')==='true');
  const slides=[...document.querySelectorAll('.gallery-track .gallery-photo,.gallery-track .gallery-video')];
  return {scrollLeft:v.scrollLeft,scrollWidth:v.scrollWidth,clientWidth:v.clientWidth,clientHeight:v.clientHeight,
   pageScrollY:scrollY,index:current?Number(current.dataset.galleryGo):null,slideCount:slides.length};
 });
}
async function tabUntil(page,predicate,label,max=MAX_TABS,direction='forward'){
 const trail=[];
 for(let i=1;i<=max;i++){
  await page.keyboard.press(direction==='back'?'Shift+Tab':'Tab');
  const info=await activeInfo(page);
  if(info.inGallery)trail.push({tab:i,tag:info.tag,go:info.go,photo:info.photo,video:info.video,prev:info.prev,next:info.next,visible:info.visible});
  if(predicate(info))return {info,count:i,trail};
 }
 throw new Error(`${label}: ${direction} tab budget ${max} exhausted without reaching the target`);
}
async function measureResource(page,responses){
 const m=await page.evaluate(()=>{
  const img=document.querySelector('.gallery-track .gallery-photo img');
  const picture=img.closest('picture'),candidates=new Map();
  for(const node of picture.querySelectorAll('source[srcset],img[srcset]')){
   for(const part of node.getAttribute('srcset').split(',')){
    const match=part.trim().match(/^(\S+)\s+(\d+)w$/);
    if(match)candidates.set(new URL(match[1],location.href).href,Number(match[2]));
   }
  }
  const r=img.getBoundingClientRect(),slot=img.closest('.gallery-photo').getBoundingClientRect(),v=document.querySelector('[data-gallery-viewport]').getBoundingClientRect();
  const naturalRatio=img.naturalWidth/img.naturalHeight,boxRatio=r.width/r.height;
  let drawnWidth=r.width,drawnHeight=r.height;
  if(Number.isFinite(naturalRatio)&&naturalRatio>0&&Number.isFinite(boxRatio)&&boxRatio>0){
   if(boxRatio>naturalRatio)drawnWidth=r.height*naturalRatio;else drawnHeight=r.width/naturalRatio;
  }
  return {dpr:devicePixelRatio,innerWidth,innerHeight,sizes:img.getAttribute('sizes'),currentSrc:img.currentSrc,
   naturalWidth:img.naturalWidth,naturalHeight:img.naturalHeight,renderedWidth:r.width,renderedHeight:r.height,
   drawnWidth,drawnHeight,slotWidth:slot.width,slotHeight:slot.height,viewportWidth:v.width,viewportHeight:v.height,
   candidates:[...candidates].map(([url,w])=>({url,w}))};
 });
 const chosen=m.candidates.find(c=>c.url===m.currentSrc);
 const response=responses.get(m.currentSrc)||null;
 const hintPx=sizesHintPx(m.sizes,m.innerWidth),neededHint=hintPx*m.dpr;
 const atLeastHint=m.candidates.filter(c=>c.w>=neededHint).sort((a,b)=>a.w-b.w);
 const smaller=m.candidates.filter(c=>c.w<(chosen?chosen.w:Infinity)).map(c=>c.w);
 return {...m,chosenWidth:chosen?chosen.w:null,hintPx,neededHint,smallestCandidateAtLeastHint:atLeastHint[0]?atLeastHint[0].w:null,nextSmallerCandidate:smaller.length?Math.max(...smaller):null,response};
}
function assertResource(m,label){
 assert.equal(m.response?.source,'browser.response',`${label}: image delivery requires an observed browser response`);
 assert.ok(m.response&&m.response.status===200,`${label}: image response status 200 (${JSON.stringify(m.response)})`);
 assert.ok(m.response.bytes>0,`${label}: image response bytes > 0`);
 assert.ok(/image\/webp/.test(m.response.contentType||''),`${label}: image content-type is webp`);
 assert.ok(m.chosenWidth!==null,`${label}: currentSrc is a declared srcset candidate`);
 assert.ok(m.renderedWidth>100,`${label}: rendered image width > 100 (${m.renderedWidth})`);
 assert.ok(m.chosenWidth>=m.drawnWidth*m.dpr,`${label}: chosen ${m.chosenWidth}w >= drawn ${m.drawnWidth}px * dpr ${m.dpr}`);
 assert.equal(m.chosenWidth,m.smallestCandidateAtLeastHint,`${label}: chosen candidate is the smallest that satisfies the sizes hint at dpr`);
 assert.ok(m.nextSmallerCandidate===null||m.nextSmallerCandidate<m.neededHint,`${label}: the next smaller candidate would under-resolve the hint`);
 assert.ok(Number.isFinite(m.hintPx)&&m.hintPx>=100,`${label}: sizes hint resolves >= 100px (${m.hintPx})`);
 assert.ok(m.hintPx>=m.drawnWidth,`${label}: sizes hint ${m.hintPx}px covers the drawn width ${m.drawnWidth}px`);
}
async function openAndCloseZoom(page,label){
 const before=await activeInfo(page);
 assert.ok(before.photo,`${label}: a photo button is focused before activation`);
 // Capture the focused photo's zoom source BEFORE Enter moves focus into the dialog.
 const expected=await page.evaluate(()=>document.activeElement?.getAttribute('data-zoom')||null);
 await page.keyboard.press('Enter');
 await sleep(400);
 const dialog=await page.evaluate(()=>({open:!!document.querySelector('#image-dialog[open]'),src:document.querySelector('#image-dialog img')?.getAttribute('src')||null}));
 assert.equal(dialog.open,true,`${label}: Enter on the focused photo opens the zoom dialog`);
 assert.equal(dialog.src,expected,`${label}: zoom dialog shows the focused photo source`);
 await page.keyboard.press('Escape');
 await sleep(300);
 const after=await page.evaluate(()=>({open:!!document.querySelector('#image-dialog[open]'),focusPhoto:document.activeElement?.classList?.contains('gallery-photo')||false}));
 assert.equal(after.open,false,`${label}: Escape closes the zoom dialog`);
 assert.equal(after.focusPhoto,true,`${label}: closing returns focus to the photo button`);
 return {opened:dialog.open,srcMatched:dialog.src===expected,escaped:!after.open,focusReturned:after.focusPhoto};
}
async function focusedPhotoScroll(page,label){
 // SETUP (not activation): move the gallery while a photo holds focus.
 const before=await activeInfo(page);
 assert.ok(before.photo,`${label}: a photo holds focus before the gallery scrolls`);
 await page.evaluate(()=>{
  const v=document.querySelector('[data-gallery-viewport]');
  const slides=[...document.querySelectorAll('.gallery-track .gallery-photo,.gallery-track .gallery-video')];
  v.scrollTo({left:slides[2].offsetLeft,behavior:'instant'});
 });
 await sleep(700);
 const state=await galleryState(page);
 const held=await activeInfo(page);
 await page.keyboard.press('Tab');
 await sleep(250);
 const next=await activeInfo(page);
 return {before:{go:before.go,photo:before.photo,visible:before.visible,rect:before.rect},afterScroll:{index:state.index,scrollLeft:state.scrollLeft,heldVisible:held.visible,heldStillFocused:held.photo},afterTab:{tag:next.tag,go:next.go,photo:next.photo,video:next.video,prev:next.prev,next:next.next,inGallery:next.inGallery,visible:next.visible,rect:next.rect}};
}
async function keyboardJourney(page,label,navKind){
 const out={label,navKind};
 const first=await tabUntil(page,info=>info.inGallery&&info.photo,'reach a gallery photo');
 assert.ok(first.info.visible&&first.info.focusVisible,`${label}: keyboard focus reaches a visible photo`);
 out.reachPhoto={tabs:first.count,info:first.info,trail:first.trail.slice(-6)};
 out.zoom=await openAndCloseZoom(page,label);
 out.focusedPhotoScroll=await focusedPhotoScroll(page,label);
 assert.ok(out.focusedPhotoScroll.afterTab.inGallery,`${label}: after the gallery scrolls, the next Tab stays in the gallery`);
 assert.equal(out.focusedPhotoScroll.afterTab.visible,true,`${label}: after the gallery scrolls, the next focused element is visible`);
 // Activate the newly focused element with the keyboard where it is a control.
 if(out.focusedPhotoScroll.afterTab.photo){await openAndCloseZoom(page,`${label} post-scroll`);}
 else if(out.focusedPhotoScroll.afterTab.video){await page.keyboard.press('Space');await sleep(200);}
 // Reach the visible nav strip (thumbnails on desktop, dots on mobile).
 const nav=await tabUntil(page,info=>navKind==='thumbs'?info.inThumbs&&info.go!==null:info.inDots&&info.go!==null,`reach ${navKind}`);
 assert.ok(nav.info.visible&&nav.info.focusVisible,`${label}: keyboard focus reaches a visible navigation control`);
 out.reachNav={tabs:nav.count,go:nav.info.go,ariaCurrent:nav.info.ariaCurrent,visible:nav.info.visible};
 const target=Number(nav.info.go);
 await page.keyboard.press('Enter');
 await sleep(700);
 const selected=await galleryState(page);
 const navFocus=await activeInfo(page);
 out.navEnter={target,index:selected.index,scrollLeft:selected.scrollLeft,focusStillOnNav:navFocus.inGallery&&navFocus.go!==null,visible:navFocus.visible};
 assert.equal(selected.index,target,`${label}: Enter on the ${navKind} control selects its slide`);
 assert.ok(navFocus.inGallery&&navFocus.go===nav.info.go&&navFocus.visible&&navFocus.focusVisible,`${label}: Enter keeps visible focus on the selected ${navKind} control`);
 // Tab to the next nav control and activate with Space.
 await page.keyboard.press('Tab');
 await sleep(200);
 const secondNav=await activeInfo(page);
 assert.ok(secondNav.go!==null&&secondNav.visible&&secondNav.focusVisible,`${label}: Tab reaches the next visible navigation control`);
 {
  const secondTarget=Number(secondNav.go);
  await page.keyboard.press('Space');
  await sleep(700);
  const spaceState=await galleryState(page);
  out.navSpace={target:secondTarget,index:spaceState.index,focusGo:(await activeInfo(page)).go};
  assert.equal(spaceState.index,secondTarget,`${label}: Space on the next ${navKind} control selects its slide`);
 }
 // Shift+Tab back and confirm the keyboard moves backwards.
 await page.keyboard.press('Shift+Tab');
 await sleep(200);
 out.shiftTab={go:(await activeInfo(page)).go,inGallery:(await activeInfo(page)).inGallery};
 assert.equal(out.shiftTab.go,nav.info.go,`${label}: Shift+Tab returns to the preceding navigation control`);
 // Arrows: Enter then Space must change selection.
 // Arrows sit before the dots on mobile and after the thumbnails on desktop.
 const arrow=await tabUntil(page,info=>info.next||info.prev,'reach a gallery arrow',60,navKind==='thumbs'?'forward':'back');
 assert.ok(arrow.info.visible&&arrow.info.focusVisible,`${label}: keyboard focus reaches a visible gallery arrow`);
 out.reachArrow={tabs:arrow.count,next:arrow.info.next,prev:arrow.info.prev,visible:arrow.info.visible};
 const beforeArrow=await galleryState(page);
 await page.keyboard.press('Enter');
 await sleep(700);
 const afterEnter=await galleryState(page);
 out.arrowEnter={before:beforeArrow.index,after:afterEnter.index,expected:(beforeArrow.index+(arrow.info.next?1:-1)+afterEnter.slideCount)%afterEnter.slideCount};
 assert.equal(afterEnter.index,out.arrowEnter.expected,`${label}: Enter on an arrow moves to the expected slide`);
 await page.keyboard.press('Space');
 await sleep(700);
 const afterSpace=await galleryState(page);
 out.arrowSpace={after:afterSpace.index,expected:(afterEnter.index+(arrow.info.next?1:-1)+afterSpace.slideCount)%afterSpace.slideCount};
 assert.equal(afterSpace.index,out.arrowSpace.expected,`${label}: Space on an arrow moves to the expected slide`);
 // Home / End: native or custom, but never an inconsistent index.
 await page.evaluate(()=>{window.__keys=[];window.addEventListener('keydown',event=>window.__keys.push({key:event.key,defaultPrevented:event.defaultPrevented}),{passive:true});});
 const beforeEnd=await galleryState(page);
 await page.keyboard.press('End');
 await sleep(500);
 const afterEnd=await galleryState(page);
 const endKey=(await page.evaluate(()=>window.__keys.filter(k=>k.key==='End').at(-1)))||{};
 out.end={before:beforeEnd.index,after:afterEnd.index,pageScrollYBefore:beforeEnd.pageScrollY,pageScrollYAfter:afterEnd.pageScrollY,defaultPrevented:endKey.defaultPrevented,slideCount:afterEnd.slideCount};
 assert.ok([beforeEnd.index,afterEnd.slideCount-1].includes(afterEnd.index),`${label}: End reaches the last slide or stays native`);
 const beforeHome=await galleryState(page);
 await page.keyboard.press('Home');
 await sleep(500);
 const afterHome=await galleryState(page);
 const homeKey=(await page.evaluate(()=>window.__keys.filter(k=>k.key==='Home').at(-1)))||{};
 out.home={before:beforeHome.index,after:afterHome.index,defaultPrevented:homeKey.defaultPrevented};
 assert.ok([beforeHome.index,0].includes(afterHome.index),`${label}: Home reaches the first slide or stays native`);
 // Modified key must not change the gallery index.
 const beforeAlt=await galleryState(page);
 await page.keyboard.press('Alt+ArrowRight');
 await sleep(300);
 const afterAlt=await galleryState(page);
 out.altArrowRight={before:beforeAlt.index,after:afterAlt.index};
 assert.equal(afterAlt.index,beforeAlt.index,`${label}: Alt+ArrowRight does not change the gallery index`);
 // A missing media control or a changed gallery index must fail the run.
 {
  const video=await tabUntil(page,info=>info.video,'reach the video',30,'back');
  const beforeMedia=await galleryState(page);
  await page.keyboard.press('ArrowRight');
  await sleep(300);
  const afterMedia=await galleryState(page);
  out.media={reached:true,tabs:video.count,before:beforeMedia.index,after:afterMedia.index};
  assert.equal(afterMedia.index,beforeMedia.index,`${label}: ArrowRight on the video does not change the gallery index`);
 }
 return out;
}
async function runViewport(browser,{label,viewport,deviceScaleFactor,navKind,desktopResize}){
 const result={label,viewport,deviceScaleFactor,navKind,blockedRequests:[],httpErrors:[],failedRequests:[]};
 const context=await browser.newContext({viewport,deviceScaleFactor});
 const responses=new Map();
 try{
  await context.route('**/*',route=>{
   const url=route.request().url();
   if(url===BASE||url.startsWith(BASE+'/'))return route.continue();
   result.blockedRequests.push(url);return route.abort();
  });
  const page=await context.newPage();
  page.setDefaultTimeout(15000);
  page.on('response',async response=>{
   const headers=response.headers(),type=headers['content-type']||'';
   if(response.status()>=400)result.httpErrors.push({url:response.url(),status:response.status()});
   if(!type.startsWith('image/'))return;
   let bytes=Number(headers['content-length']);
   if(!Number.isFinite(bytes)){try{bytes=(await response.body()).length;}catch{}}
   responses.set(response.url(),{status:response.status(),contentType:type,bytes,source:'browser.response'});
  });
  page.on('requestfailed',request=>result.failedRequests.push({url:request.url(),error:request.failure()?.errorText||null}));
  await page.goto(BASE+PAGE,{waitUntil:'load',timeout:30000});
  await page.waitForSelector('[data-gallery-viewport]',{timeout:15000});
  await sleep(1200);
  result.initial=await galleryState(page);
  result.resourceInitial=await measureResource(page,responses);
  assertResource(result.resourceInitial,`${label} initial`);
  if(desktopResize){
   const before=await galleryState(page);
   await page.setViewportSize(desktopResize);
   await sleep(900);
   const after=await galleryState(page);
   result.desktopResize={to:desktopResize,beforeIndex:before.index,afterIndex:after.index,scrollLeft:after.scrollLeft};
   assert.equal(after.index,before.index,`${label}: desktop resize retains the selected slide`);
   result.resourceResized=await measureResource(page,responses);
   assertResource(result.resourceResized,`${label} after desktop resize`);
   await page.setViewportSize(viewport);
   await sleep(900);
  }
  // Put the gallery in view for screenshots; focus journey still uses Tab.
  await page.evaluate(()=>document.querySelector('[data-gallery-viewport]')?.scrollIntoView({block:'center'}));
  await sleep(300);
  result.journeyViewport=await page.evaluate(()=>({width:innerWidth,height:innerHeight,deviceScaleFactor:devicePixelRatio}));
  assert.deepEqual(result.journeyViewport,{...viewport,deviceScaleFactor},`${label}: keyboard journey uses the promised viewport and DPR`);
  result.journey=await keyboardJourney(page,label,navKind);
  await page.screenshot({path:path.join(OUTDIR,`browser-contracts-${label}.png`)});
  result.final=await galleryState(page);
 }catch(error){
  result.error=error&&error.stack||String(error);
 }finally{
  await context.close();
 }
 return result;
}
(async()=>{
 const server=await startServer();
 const results={chrome:CHROME,base:BASE,page:PAGE,generatedAt:new Date().toISOString(),runs:[]};
 let browser;
 try{
  browser=await core.chromium.launch({executablePath:CHROME,headless:true});
  results.runs.push(await runViewport(browser,{label:'desktop-1280x900',viewport:{width:1280,height:900},deviceScaleFactor:1,navKind:'thumbs',desktopResize:{width:1440,height:900}}));
  results.runs.push(await runViewport(browser,{label:'mobile-390x844',viewport:{width:390,height:844},deviceScaleFactor:2,navKind:'dots',desktopResize:null}));
 }finally{
  if(browser)await browser.close();
  await new Promise(resolve=>server.close(resolve));
 }
 const failed=results.runs.filter(run=>run.error);
 results.summary={runs:results.runs.length,failed:failed.length};
 fs.writeFileSync(OUT,JSON.stringify(results,null,2)+'\n');
 const compact={
  summary:results.summary,
  errors:failed.map(run=>({label:run.label,error:run.error.split('\n')[0]})),
  resource:results.runs.map(run=>({label:run.label,chosenWidth:run.resourceInitial&&run.resourceInitial.chosenWidth,neededHint:run.resourceInitial&&run.resourceInitial.neededHint,response:run.resourceInitial&&run.resourceInitial.response})),
  keyboard:results.runs.map(run=>({label:run.label,reachTabs:run.journey&&run.journey.reachPhoto&&run.journey.reachPhoto.tabs,focusedPhotoScroll:run.journey&&run.journey.focusedPhotoScroll&&run.journey.focusedPhotoScroll.afterTab,media:run.journey&&run.journey.media})),
 };
 console.log(JSON.stringify(compact,null,2));
 process.exitCode=failed.length?1:0;
})().catch(error=>{console.error('BROWSER_CONTRACTS_FAILED',error&&error.stack||error);process.exitCode=2;});
