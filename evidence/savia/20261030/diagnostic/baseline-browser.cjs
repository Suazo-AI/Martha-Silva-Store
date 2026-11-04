const {safeError,installOutputPolicy}=require('./error-policy.cjs');
const output=installOutputPolicy(process);
process.on('uncaughtException',e=>output.failure('uncaught',e));
process.on('unhandledRejection',e=>output.failure('unhandled',e));
const fs=require('fs'),path=require('path'),assert=require('assert/strict');
const {chromium}=require('C:/Users/Jason/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
let input='';process.stdin.on('data',x=>input+=x);process.stdin.on('end',()=>{try{Promise.resolve(main(JSON.parse(input))).catch(e=>output.failure('unhandled',e));}catch(e){output.failure('input',e);}});
async function main(config){
 // Authenticated errors persist only approved identifiers; no message/stack/call log.
 const checks=[],network=[],errors=[],consoleErrors=[];let browser;const contexts=[];let stage='launch';
 const attachErrors=page=>page.on('pageerror',e=>consoleErrors.push(safeError(stage,e,'PAGE_ERROR')));
 const noOverflow=async(page,name)=>{const d=await page.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth}));assert.ok(d.scroll<=d.width,`${name} overflow ${JSON.stringify(d)}`);check(name+' no page overflow',d);};
 const save=()=>fs.writeFileSync(path.join(config.folder,'browser-result.json'),JSON.stringify({checks,network,errors,consoleErrors},null,2));
 const check=(name,details={})=>{checks.push({name,status:'PASS',...details});save();};
 async function status(page,url,expected,options={}){const response=await page.request.fetch(config.url+url,options);assert.equal(response.status(),expected,`${url}: expected ${expected}, got ${response.status()}`);return response;}
 async function api(page,url){return (await status(page,url,200)).json();}
 async function login(page,staff){await page.goto(config.url+'/internal/login');await page.locator('#login-submit').waitFor({state:'visible'});await page.waitForFunction(()=>!document.querySelector('#login-submit').disabled);await page.locator('#login-name').fill(staff.login);await page.locator('#login-password').fill(staff.password);await page.locator('#login-submit').click();await page.waitForURL('**/internal/');await page.locator('#staff-shell').waitFor({state:'visible'});}
 async function list(page,kind,prefix,label){
  for(const size of [25,50,100]){
   await page.selectOption(`#${prefix}-page-size`,String(size));
   await page.waitForFunction(({prefix,size})=>document.querySelector(`#${prefix}-rows`).children.length===size,{prefix,size});
   let expected=1,all=[];
   while(true){
    const rows=await page.locator(`#${prefix}-rows tr`).allTextContents();
    for(const row of rows){assert.ok(row.includes(`${label} ${String(expected).padStart(3,'0')}`),`unexpected value ${expected}`);all.push(expected++);}
    const next=page.locator(`[data-page-next="${kind}"]`);if(await next.isDisabled())break;
    const old=await page.locator(`#${prefix}-rows`).textContent();await next.click();await page.waitForFunction(({prefix,old})=>{const rows=document.querySelector(`#${prefix}-rows`);return rows.children.length>0&&rows.textContent!==old;},{prefix,old});
   }
   assert.equal(all.length,105);assert.equal(new Set(all).size,105);check(`${prefix} pagination ${size}`,{values:105,noDuplicates:true});
  }
  await page.locator(`#${prefix}-search`).fill('073');await page.locator(`#${prefix}-search`).press('Enter');
  await page.waitForFunction(prefix=>document.querySelector(`#${prefix}-rows`).children.length===1,prefix);
  assert.ok((await page.locator(`#${prefix}-rows`).textContent()).includes(`${label} 073`));check(`${prefix} keyboard search`,{value:`${label} 073`});
 }
 try{
  browser=await chromium.launch({headless:true});
  const ownerContext=await browser.newContext({viewport:{width:1440,height:1000}});contexts.push(ownerContext);
  const page=await ownerContext.newPage();page.setDefaultTimeout(20000);
  page.on('response',r=>{let u=new URL(r.url());if(u.origin===config.url)network.push({method:r.request().method(),path:u.pathname+u.search,status:r.status()});});
  attachErrors(page);
  stage='anonymous';await status(page,'/internal/api/security/me',401);
  await page.goto(config.url+'/internal/');assert.ok((await page.locator('#staff-shell').count())===0||!(await page.locator('#staff-shell').isVisible()));check('anonymous document and API',{api:401,urlPath:new URL(page.url()).pathname});
  await page.goto(config.url+'/internal/login');check('normal TLS',{browser:'Chromium',bypass:false});
  const csrfFail=await status(page,'/internal/api/security/login',400,{method:'POST',data:{loginName:config.owner.login,password:config.owner.password}});assert.ok((await csrfFail.text()).includes('csrf_invalid'));check('login rejects missing CSRF');
  stage='owner-login';await login(page,config.owner);config.owner.password='';
  const cookies=(await ownerContext.cookies()).filter(c=>c.name.startsWith('__Host-Savia.')).map(({name,httpOnly,secure,sameSite,path})=>({name,httpOnly,secure,sameSite,path}));
  for(const cookie of cookies){assert.equal(cookie.secure,true);assert.equal(cookie.httpOnly,true);assert.equal(cookie.sameSite,'Strict');assert.equal(cookie.path,'/');}assert.ok(cookies.some(c=>c.name==='__Host-Savia.Session'));check('real owner login cookie attributes',{cookies});
  assert.ok((await api(page,'/internal/api/security/me')).role==='Owner');
  await noOverflow(page,'owner desktop 1440x1000');
  await page.screenshot({path:path.join(config.folder,'owner-desktop.png'),fullPage:true});
  stage='owner-clients';await list(page,'clientes','clients','QA Cliente');
  await page.locator('[data-action="nav"][data-target="inventario"]').click();await page.locator('#inventory-rows tr').first().waitFor();
  stage='owner-items';await list(page,'inventario','inventory','QA Articulo');
  assert.ok(await page.locator('[data-action="new-client"]').isDisabled());for(const [view,note] of [['ventas','sales-pending-note'],['abastecimiento','purchasing-pending-note']]){await page.locator(`[data-action="nav"][data-target="${view}"]`).click();const action=page.locator(`[data-view="${view}"] button[aria-describedby="${note}"]`);await action.waitFor({state:'visible'});assert.ok(await action.isDisabled());}await page.locator('[data-action="nav"][data-target="inventario"]').click();await page.locator('#inventory-rows tr').first().waitFor();check('operational UI actions disabled');
  await page.setViewportSize({width:390,height:844});await page.screenshot({path:path.join(config.folder,'owner-mobile.png'),fullPage:true});
  const dimensions=await page.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth}));assert.ok(dimensions.scroll<=dimensions.width,`mobile overflow ${JSON.stringify(dimensions)}`);check('mobile viewport no page overflow',dimensions);
  await page.locator('#inventory-search').focus();await page.keyboard.press('Tab');const focus=await page.evaluate(()=>({tag:document.activeElement.tagName,text:document.activeElement.textContent?.trim()}));assert.equal(focus.tag,'BUTTON');await page.screenshot({path:path.join(config.folder,'owner-keyboard.png'),fullPage:true});check('keyboard focus and Enter search',{focus});
  // Record only a postlogin context. Credentials never enter a recorded page.
  stage='postlogin-video';try{const videoContext=await browser.newContext({viewport:{width:1280,height:800},recordVideo:{dir:path.join(config.folder,'video'),size:{width:960,height:600}}});contexts.push(videoContext);await videoContext.addCookies(await ownerContext.cookies());const vp=await videoContext.newPage();attachErrors(vp);await vp.goto(config.url+'/internal/');await vp.locator('#staff-shell').waitFor({state:'visible'});await vp.locator('[data-target="inventario"][data-action="nav"]').click();await vp.locator('#inventory-search').fill('073');await vp.locator('#inventory-search').press('Enter');await vp.locator('#inventory-rows tr').first().waitFor();await videoContext.close();check('postlogin video captured');}catch(e){checks.push({name:'postlogin video',status:'NOT_RUN',error:safeError('postlogin-video',e)});save();}
  stage='owner-logout';const ownerCookies=await ownerContext.cookies();await page.locator('[data-action="logout"]').click();await page.waitForURL('**/internal/login');await status(page,'/internal/api/security/me',401);check('owner logout invalidates browser session');const replay=await browser.newContext();contexts.push(replay);await replay.addCookies(ownerCookies);const rp=await replay.newPage();await status(rp,'/internal/api/security/me',401);check('revoked cookie replay rejected');
  stage='manager-login';const managerContext=await browser.newContext({viewport:{width:1440,height:1000}});contexts.push(managerContext);const mp=await managerContext.newPage();attachErrors(mp);mp.setDefaultTimeout(20000);await login(mp,config.manager);config.manager.password='';await mp.locator('#inventory-rows tr').first().waitFor();assert.equal((await api(mp,'/internal/api/security/me')).role,'Manager');assert.ok(await mp.locator('[data-target="clientes"][data-action="nav"]').isDisabled());await status(mp,'/internal/api/directory/parties?kind=customer&skip=0&take=25',403);check('manager role server and UI',{partiesStatus:403});await noOverflow(mp,'manager desktop 1440x1000');await mp.screenshot({path:path.join(config.folder,'manager-desktop.png'),fullPage:true});await mp.setViewportSize({width:390,height:844});await noOverflow(mp,'manager mobile 390x844');await mp.screenshot({path:path.join(config.folder,'manager-mobile.png'),fullPage:true});
  await mp.locator('[data-action="logout"]').click();await mp.waitForURL('**/internal/login');await status(mp,'/internal/api/security/me',401);check('manager logout invalidates browser session');
  assert.equal(consoleErrors.length,0);check('no browser page errors');
 }catch(e){errors.push(safeError(stage,e));process.exitCode=1;}
 finally{for(const c of contexts)await c.close().catch(e=>{errors.push(safeError('context-close',e));process.exitCode=1;});if(browser)await browser.close().catch(e=>{errors.push(safeError('browser-close',e));process.exitCode=1;});save();output.summary(checks.length,errors);}
}
