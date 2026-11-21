'use strict';
// Executes the actual browser source in a VM. Every I/O dependency is an explicit double.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const here=__dirname,base=path.dirname(here),r7=path.join(base,'runtime-proposal-revision7');
const frozen=path.join(r7,'package/manual/browser.cjs'),candidate=path.join(here,'candidate/browser.cjs');
const policySource=fs.readFileSync(path.join(r7,'package/manual/error-policy.cjs'),'utf8');
const playwright='C:/Users/Jason/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright';
const SECRET='SYNTHETIC_SECRET_MUST_NEVER_BE_PERSISTED';
const digest=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
async function exercise(file,scenario){
 const writes=[],calls=[],handlers={},streams=[];let resolve,reject;
 const done=new Promise((a,b)=>{resolve=a;reject=b;});
 const fakeProcess={exitCode:0,on:()=>{},stdin:{on:(event,fn)=>{handlers[event]=fn;}},stdout:{write:value=>{streams.push(String(value));resolve();return true;}},stderr:{write:value=>{streams.push(String(value));resolve();return true;}}};
 const policyModule={exports:{}};vm.runInNewContext(policySource,{module:policyModule},{timeout:1000});
 const injected=()=>new Error(SECRET);
 const page={setDefaultTimeout:()=>{},on:()=>{},url:()=> 'https://synthetic.invalid/internal/',
  request:{fetch:async(url,options)=>{calls.push({op:'fetch',url,options:JSON.parse(JSON.stringify(options))});if(scenario.fetchError)throw injected();return {status:()=>{calls.push({op:'status'});return scenario.http;}};}},
  goto:async url=>{calls.push({op:'goto',url});if(scenario.gotoError||url.endsWith('/login'))throw injected();},
  locator:selector=>{assert.equal(selector,'#staff-shell');return {count:async()=>{calls.push({op:'count'});return scenario.absent?0:1;},isVisible:async()=>{calls.push({op:'isVisible'});return scenario.visible??false;}}}
 };
 const context={newPage:async()=>page,close:async()=>{calls.push({op:'context-close'});}};
 const browser={newContext:async()=>context,close:async()=>{calls.push({op:'browser-close'});}};
 const sandbox={process:fakeProcess,URL,require:name=>{
  if(name==='./error-policy.cjs')return policyModule.exports;
  if(name==='fs')return {writeFileSync:(name,data)=>{assert.equal(path.basename(name),'browser-result.json');writes.push(JSON.parse(data));}};
  if(name==='path')return path;
  if(name==='assert/strict')return assert;
  if(name===playwright)return {chromium:{launch:async options=>{assert.equal(JSON.stringify(options),'{"headless":true}');return browser;}}};
  throw new Error('Unexpected require');
 }};
 vm.runInNewContext(fs.readFileSync(file,'utf8'),sandbox,{timeout:1000,filename:path.basename(file)});
 handlers.data(JSON.stringify({url:'https://synthetic.invalid',folder:'IN_MEMORY_ONLY',owner:{password:SECRET},manager:{password:SECRET}}));handlers.end();
 const timeout=setTimeout(()=>reject(new Error('VM completion timeout')),3000);
 try{await done;}finally{clearTimeout(timeout);}
 assert.ok(writes.length>0,'No browser result');
 const result=writes.at(-1);
 assert.ok(!JSON.stringify({writes,streams}).includes(SECRET),'Secret leaked');
 assert.ok(calls.some(x=>x.op==='context-close')&&calls.some(x=>x.op==='browser-close'),'Cleanup missing');
 return {result,writes,calls,exit:fakeProcess.exitCode,streams};
}
function validate(records){
 assert.ok(Array.isArray(records));assert.ok(records.length<=2);
 for(const r of records){
  assert.deepEqual(Object.keys(r).sort(),['expected','id','kind','received','status']);
  const http=r.id==='ANONYMOUS_API_ME_STATUS';
  assert.ok(http||r.id==='ANONYMOUS_DOCUMENT_SHELL_HIDDEN');
  assert.equal(r.kind,http?'http_status':'boolean');assert.equal(r.expected,http?401:true);
  assert.ok(['NOT_OBSERVED','INVALID_OBSERVATION','PASS','FAIL'].includes(r.status));
  assert.ok(r.received===null||(http?Number.isInteger(r.received)&&r.received>=100&&r.received<=599:typeof r.received==='boolean'));
 }
}
function compatible(a,b){
 const withoutDiagnostic=({assertions,...rest})=>rest;
 assert.deepEqual(withoutDiagnostic(a.result),withoutDiagnostic(b.result));
 assert.equal(a.exit,b.exit);assert.deepEqual(a.streams,b.streams);
 // Original helper read status twice; all request/navigation/locator/cleanup behavior stays identical.
 assert.deepEqual(a.calls.filter(x=>x.op!=='status'),b.calls.filter(x=>x.op!=='status'));
}
async function main(){
 const baseline=process.argv.includes('--baseline');
 if(baseline){
  const x=await exercise(frozen,{http:302});
  assert.equal(x.exit,1);assert.equal(x.result.checks.length,0);assert.equal(x.result.errors[0].code,'ERR_ASSERTION');
  assert.ok(Array.isArray(x.result.assertions),'Missing assertion ID and expected/received diagnostic (expected red check)');return;
 }
 const cases=[];
 for(const http of [100,200,302,400,403,404,500,599])cases.push({name:`HTTP_${http}`,http,want:'FAIL'});
 cases.push({name:'SHELL_VISIBLE',http:401,visible:true,want:'SHELL_FAIL'},
  {name:'SHELL_ABSENT',http:401,absent:true,want:'PASS'},
  {name:'SHELL_HIDDEN',http:401,visible:false,want:'PASS'},
  {name:'FETCH_ERROR',http:401,fetchError:true,want:'FETCH_ERROR'},
  {name:'GOTO_ERROR',http:401,gotoError:true,want:'GOTO_ERROR'});
 for(const [name,http] of [['STRING','302'],['OBJECT',{secret:SECRET}],['NAN',NaN],['LOW',99],['HIGH',600],['NULL',null],['UNDEFINED',undefined],['COERCION',{toString(){throw new Error(SECRET);}}]])cases.push({name:'INVALID_'+name,http,want:'INVALID'});
 const results=[];
 for(const c of cases){
  const before=await exercise(frozen,c),after=await exercise(candidate,c);compatible(before,after);
  for(const w of after.writes)validate(w.assertions);
  const records=after.result.assertions,api=records[0],doc=records[1];
  assert.equal(api.id,'ANONYMOUS_API_ME_STATUS');
  if(c.want==='FETCH_ERROR'){assert.equal(api.status,'NOT_OBSERVED');assert.equal(api.received,null);assert.equal(records.length,1);}
  else if(c.want==='INVALID'){assert.equal(api.status,'INVALID_OBSERVATION');assert.equal(api.received,null);assert.equal(records.length,1);}
  else {assert.equal(api.received,c.http);assert.equal(api.status,c.http===401?'PASS':'FAIL');}
  if(c.want==='FAIL'){assert.equal(records.length,1);assert.equal(after.result.errors[0].code,'ERR_ASSERTION');}
  if(c.want==='GOTO_ERROR'){assert.equal(doc.status,'NOT_OBSERVED');assert.equal(doc.received,null);}
  if(c.want==='SHELL_FAIL'){assert.equal(doc.status,'FAIL');assert.equal(doc.received,false);assert.equal(after.result.errors[0].code,'ERR_ASSERTION');}
  if(c.want==='PASS'){assert.equal(doc.status,'PASS');assert.equal(doc.received,true);assert.equal(after.result.checks.length,1);assert.equal(after.result.checks[0].name,'anonymous document and API');}
  else assert.equal(after.result.checks.length,0);
  // The original assert must still fail for every mismatch. PASS cases stop at injected next-stage failure.
  assert.equal(after.exit,1);
  assert.equal(after.writes[0].assertions[0].status,'NOT_OBSERVED');
  if(c.absent)assert.ok(!after.calls.some(x=>x.op==='isVisible'),'Short circuit changed');
  results.push({name:c.name,status:'PASS',assertions:records});
 }
 const snapshot=JSON.parse(fs.readFileSync(path.join(here,'PROTECTED-BEFORE.json'),'utf8'));
 const current=[];
 function walk(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,e.name);if(e.isDirectory())walk(p);else if(e.isFile())current.push(path.relative(base,p).replaceAll('\\','/'));}}
 for(let revision=3;revision<=7;revision++)walk(path.join(base,`runtime-proposal-revision${revision}`));
 assert.deepEqual(current.sort(),Object.keys(snapshot).sort(),'Protected file set changed');
 for(const [name,hash] of Object.entries(snapshot))assert.equal(digest(path.join(base,name)),hash,`Protected file changed: ${name}`);
 const report={measured_utc:new Date().toISOString(),node:process.version,status:'PASS_OFFLINE_SYNTHETIC_ONLY',cases:results.length,results,protected_files_unchanged:current.length,source_sha256:digest(frozen),candidate_sha256:digest(candidate),real_runtime_executed:false,real_browser_executed:false,network_used:false,certificate_stores_accessed:false,docker_accessed:false,pilot_status:'NO_APTO'};
 fs.writeFileSync(path.join(here,'OFFLINE-RESULT.json'),JSON.stringify(report,null,2)+'\n');
 console.log(JSON.stringify({status:report.status,cases:report.cases,protected_files_unchanged:current.length,candidate_sha256:report.candidate_sha256}));
}
main().catch(e=>{console.error(e.message);process.exitCode=1;});
