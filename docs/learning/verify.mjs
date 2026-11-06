// Real Chrome against the local HTML. No server, product API or external requests.
// node docs/learning/verify.mjs <installed-playwright-directory> <evidence-directory>
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {pathToFileURL,fileURLToPath} from 'node:url';
import path from 'node:path';
import assert from 'node:assert/strict';
const [pw,outArg]=process.argv.slice(2);
if(!pw||!outArg)throw Error('Supply installed Playwright and evidence directory.');
const out=path.resolve(outArg),file=fileURLToPath(new URL('./backlog.html',import.meta.url));
await mkdir(out,{recursive:true});
const {chromium}=await import(pathToFileURL(path.join(pw,'index.mjs')));
const browser=await chromium.launch({channel:'chrome',headless:true,args:['--disable-background-networking']});
const context=await browser.newContext({acceptDownloads:true,viewport:{width:1280,height:900},recordVideo:{dir:path.join(out,'video'),size:{width:1280,height:900}}});
const checks=[],errors=[],requests=[];
const page=await context.newPage();
const key='savia-learning-backlog-v1';
context.on('page',p=>p.on('pageerror',e=>errors.push(e.message)));
page.on('pageerror',e=>errors.push(e.message));
await context.route(/^https?:/,route=>{requests.push(route.request().url());return route.abort();});
const check=(name,condition)=>{assert.ok(condition,name);checks.push(name);};
const state=()=>page.evaluate(k=>JSON.parse(localStorage.getItem(k)),key);
const edit=id=>page.locator(`article[data-id="${id}"] button`).click();
const fill=(name,value)=>page.locator(`[name="${name}"]`).fill(value);
const select=(name,value)=>page.locator(`[name="${name}"]`).selectOption(value);
const save=()=>page.getByRole('button',{name:'Guardar tarea',exact:true}).click();
const payload='</script><img src=x onerror="window.pwned=true">';
let failure;
try{
 await page.goto(pathToFileURL(file).href);
 const initial=await state();
 check('12 seed tasks, no invented mastery',initial.tasks.length===12&&initial.tasks.every(t=>t.result==='Sin evaluar'));
 check('Three exact column labels',JSON.stringify(await page.locator('.column>h2').allTextContents())===JSON.stringify(['To do','In progress','Done']));
 check('Priority order in every column',await page.locator('.column').evaluateAll(cols=>cols.every(c=>{const p=[...c.querySelectorAll('.card .meta:first-child')].map(x=>x.textContent.slice(0,2));return JSON.stringify(p)===JSON.stringify([...p].sort());})));
 check('Desktop has three columns',await page.locator('.board').evaluate(b=>getComputedStyle(b).gridTemplateColumns.split(' ').length===3));
 await page.screenshot({path:path.join(out,'desktop.png'),fullPage:true});
 await edit('L01');await select('status','Done');await save();
 check('Done without evidence rejected',await page.locator('#editor').evaluate(e=>e.open)&&/Done/.test(await page.locator('#error').textContent()));
 await fill('evidence','Synthetic first attempt: explain exact diff and evidence.');await save();
 check('Done with unassessed skill rejected',await page.locator('#editor').evaluate(e=>e.open));
 await select('result','Con ayuda');await save();
 check('Assisted skill cannot be Done',await page.locator('#editor').evaluate(e=>e.open));
 await select('result','Sin ayuda');await fill('notes','Synthetic first attempt');await save();
 check('Done with independent result and evidence saved',(await state()).tasks.find(t=>t.id==='L01').status==='Done');
 await page.reload();
 check('Reload preserves saved evidence',(await state()).tasks.find(t=>t.id==='L01').evidence.includes('Synthetic first attempt'));
 await edit('L01');await select('status','In progress');await fill('notes','Synthetic second attempt');await save();
 check('Previous attempt retained in history',(await state()).tasks.find(t=>t.id==='L01').history.some(h=>h.before?.notes==='Synthetic first attempt'&&h.after?.notes==='Synthetic second attempt'));
 await edit('L01');await page.locator('#defer').click();
 check('Defer requires reason',/motivo/.test(await page.locator('#error').textContent()));
 await fill('reason','Resume after checking the source');await page.locator('#defer').click();
 check('Deferred task returns to To do with dated reason',(await state()).tasks.find(t=>t.id==='L01').status==='To do'&&(await state()).tasks.find(t=>t.id==='L01').history.at(-1).action.includes('Resume after'));
 await page.locator('#add').click();await fill('title',payload);await fill('objective','Synthetic objective');await fill('criterion','Synthetic observable check');await fill('next','Independent retry');await select('priority','P3');await save();
 const id=(await state()).tasks.find(t=>t.title===payload).id;
 check('User text rendered without executable nodes',await page.locator('img').count()===0&&!await page.evaluate(()=>globalThis.pwned));
 await page.locator('#filter').selectOption('Proyecto');
 check('Type filter restricts cards',await page.locator('.card').count()===3);
 await page.locator('#filter').selectOption('');await page.locator('#search').fill('L01');
 check('Search returns correct task',await page.locator('.card').count()===1&&await page.locator('.card').getAttribute('data-id')==='L01');
 await page.locator('#search').fill('');
 const beforeImport=JSON.stringify(await state());
 for(const [name,mutate] of [
  ['duplicate IDs',d=>d.tasks.push(d.tasks[0])],
  ['invalid priority',d=>d.tasks[0].priority='P0'],
  ['missing objective',d=>d.tasks[0].objective=''],
  ['unsafe link',d=>d.tasks[0].resources=['javascript:alert(1)']],
  ['unsupported version',d=>d.version=2]
 ]){
  const d=JSON.parse(beforeImport);mutate(d);
  await page.locator('#import').setInputFiles({name:'invalid.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(d))});
  await page.waitForFunction(()=>document.getElementById('notice').textContent.startsWith('Importación rechazada'));
  check('Atomic import rejection: '+name,JSON.stringify(await state())===beforeImport);
 }
 const dl=page.waitForEvent('download');await page.locator('#export').click();const jsonDownload=await dl;await jsonDownload.saveAs(path.join(out,'export.json'));
 check('Native JSON export round trip',JSON.stringify(JSON.parse(await readFile(path.join(out,'export.json'),'utf8')))===JSON.stringify(await state()));
 const incoming=JSON.parse(beforeImport);const task=incoming.tasks.find(t=>t.id===id);task.notes='Imported newer notes';task.updatedAt=new Date(Date.parse(task.updatedAt)+1000).toISOString();
 await page.locator('#import').setInputFiles({name:'valid.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(incoming))});
 await page.waitForFunction(()=>document.getElementById('notice').textContent==='JSON validado y combinado.');
 check('Valid newer import merged',(await state()).tasks.find(t=>t.id===id).notes==='Imported newer notes');
 const htmlEvent=page.waitForEvent('download');await page.locator('#html-copy').click();const htmlDownload=await htmlEvent;await htmlDownload.saveAs(path.join(out,'portable.html'));
 const portable=await context.newPage();await portable.goto(pathToFileURL(path.join(out,'portable.html')).href);
 check('Portable HTML safely restores embedded state',await portable.locator('.card').count()===13&&await portable.locator('img').count()===0&&!await portable.evaluate(()=>globalThis.pwned));
 check('Portable HTML starts with closed editor',!await portable.locator('#editor').evaluate(e=>e.open));await portable.close();
 // A storage update while the dialog is open must reject stale form content.
 await edit('L01');const newer=await state();const n=newer.tasks.find(t=>t.id==='L01');n.next='Newer external edit';n.updatedAt=new Date(Date.parse(n.updatedAt)+2000).toISOString();
 await page.evaluate(({key,newer})=>window.dispatchEvent(new StorageEvent('storage',{key,newValue:JSON.stringify(newer)})),{key,newer});
 await save();check('Stale dialog cannot overwrite newer change',await page.locator('#editor').evaluate(e=>e.open)&&/otra/.test(await page.locator('#error').textContent()));await page.locator('#cancel').click();
 // Other-tab updates are synthetic events here; this does not claim real multi-device sync.
 await page.evaluate(k=>localStorage.removeItem(k),key);await page.reload();
 for(const width of [390,320]){await page.setViewportSize({width,height:844});check('No horizontal overflow at '+width,await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));}
 await page.screenshot({path:path.join(out,'mobile.png'),fullPage:true});
 await page.locator('#add').focus();await page.keyboard.press('Enter');
 check('Keyboard opens accessible native dialog',await page.locator('#editor').evaluate(e=>e.open));await page.keyboard.press('Escape');
 check('Escape closes dialog',!await page.locator('#editor').evaluate(e=>e.open));
 // Preserve corrupt storage bytes and warn instead of replacing them.
 await page.evaluate(k=>localStorage.setItem(k,'{broken'),key);await page.reload();
 check('Corrupt local record preserved',await page.evaluate(k=>localStorage.getItem(k),key)==='{broken'&&await page.locator('#storage').getAttribute('data-error')==='true');
 await page.evaluate(k=>localStorage.removeItem(k),key);await page.reload();
 await page.addInitScript(()=>Storage.prototype.setItem=function(){throw new DOMException('Synthetic quota failure','QuotaExceededError');});await page.reload();
 check('Storage write failure visible',await page.locator('#storage').getAttribute('data-error')==='true');
 check('No uncaught page errors',errors.length===0);check('No external requests',requests.length===0);
}catch(e){failure=e;}
finally{await context.close();await browser.close();}
const sha=b=>createHash('sha256').update(b).digest('hex');
const result={status:failure?'FAIL':'PASS',host:process.env.COMPUTERNAME,scope:'Local HTML in real headless Chrome; synthetic records only',sourceSha256:sha(await readFile(file)),driverSha256:sha(await readFile(fileURLToPath(import.meta.url))),checks,uncaughtPageErrors:errors,externalRequests:requests,failure:failure?.message??null,notRun:['Jason unaided practice','Human visual acceptance','Actual simultaneous-tab writes','Product API/SQL','Production readiness']};
await writeFile(path.join(out,'RESULT.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({status:result.status,checks:checks.length,result:path.join(out,'RESULT.json'),failure:result.failure}));
if(failure)throw failure;
