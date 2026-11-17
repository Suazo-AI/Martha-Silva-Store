import {__probeCtx as ctx} from '/app.mjs';
import * as api from '/api.mjs';
const wait=async(fn)=>{for(let i=0;i<200;i++){if(await fn())return;await new Promise(r=>setTimeout(r,20));}throw Error('Probe condition timed out');};
const visible=el=>!!el&&el.getClientRects().length>0&&getComputedStyle(el).visibility!=='hidden';
const pause=()=>new Promise(r=>setTimeout(r,220));
const login=async user=>{
 await wait(()=>visible(document.querySelector('#login-user')));
 document.querySelector('#login-user').value=user;document.querySelector('#login-pass').value='fictional-password';
 document.querySelector('#access form').requestSubmit();
 await wait(()=>ctx.me?.displayName===(user==='manager'?'PRIVATE OLD ACTOR':'Fixture Seller')&&visible(document.querySelector('#palette-picker')));
};
export async function run(){
 const checks=[];const check=(name,value)=>checks.push({name,status:value?'PASS':'FAIL'});
 await fetch('/__fixture/reset',{method:'POST'});
 location.hash='#/ajustes';await login('manager');await pause();
 const key='savia.return.pending.v1', marker=JSON.stringify({fixture:'PENDING PRIVATE SALE',state:'sending'});localStorage.setItem(key,marker);
 ctx.notify('PRIVATE OLD NOTICE');
 // Exercise the real API failure and root handler. The return module's unmount/catch
 // wiring is covered separately; this probe does not fabricate a cashier route.
 const cleanup=api.endApproval('fictional-approval').catch(()=>ctx.reportApprovalCleanupFailure());
 await wait(async()=> (await fetch('/__fixture/state').then(r=>r.json())).held);
 document.querySelector('#logout').click();
 await wait(()=>visible(document.querySelector('#login-user'))&&ctx.me===null);await pause();
 await fetch('/__fixture/release',{method:'POST'});await cleanup;await pause();
 const notice=()=>document.querySelector('#approval-cleanup-notice')??document.querySelector('#notice');
 const expected='No se pudo cerrar la autorización temporal. Pida revisión a la gerente.';
 check('warning-visible-after-real-logout',visible(notice()));
 check('warning-exact-non-private-text',notice().textContent===expected);
 check('warning-has-live-status',notice().getAttribute('role')==='status'&&notice().getAttribute('aria-atomic')==='true');
 check('private-shell-hidden',!visible(document.querySelector('#shell')));
 check('private-notice-and-actor-not-visible',!document.body.innerText.includes('PRIVATE OLD'));
 location.hash='#/ingreso';await wait(()=>document.querySelector('#login-user')?.value==='');await pause();
 check('warning-survives-logged-out-navigation',visible(notice())&&notice().textContent===expected);
 location.hash='#/ajustes';await wait(()=>document.querySelector('#login-user')?.value==='');await login('seller');await pause();
 check('warning-survives-different-account-login',visible(notice())&&notice().textContent===expected);
 check('new-account-shown',document.querySelector('#operator-label').textContent.includes('Fixture Seller'));
 check('old-private-notice-cleared',document.querySelector('#notice').textContent==='');
 location.hash='#/inventario';await wait(()=>document.querySelector('#title').textContent==='Inventario');await pause();
 check('warning-survives-next-route',visible(notice())&&notice().textContent===expected);
 check('pending-reference-byte-identical',localStorage.getItem(key)===marker);
 const state=await fetch('/__fixture/state').then(r=>r.json());
 check('exactly-one-approval-cleanup',state.calls.filter(c=>c.path.endsWith('/auth/logout')&&c.authorization==='Bearer fictional-approval').length===1);
 check('exactly-one-user-logout',state.calls.filter(c=>c.path.endsWith('/auth/logout')&&c.authorization==='Bearer fictional-manager').length===1);
 check('no-sale-or-return-post',!state.calls.some(c=>c.method==='POST'&&!c.path.includes('/auth/')));
 check('no-horizontal-overflow',document.documentElement.scrollWidth<=innerWidth);
 return {checks,passed:checks.filter(c=>c.status==='PASS').length,failed:checks.filter(c=>c.status==='FAIL').length,viewport:{width:innerWidth,height:innerHeight,dpr:devicePixelRatio},calls:state.calls,instrumentation:'Only export {ctx as __probeCtx} appended to served app.mjs. Actual index, CSS, router, login, logout and API. Controlled cleanup call; return unmount wiring verified separately.'};
}
