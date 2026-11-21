"use strict";
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const source=fs.readFileSync(path.resolve('tests/gallery-browser-contracts.cjs'),'utf8');
const sizes=source.slice(source.indexOf('function sizesHintPx('),source.indexOf('function startServer('));
const resource=source.slice(source.indexOf('async function measureResource('),source.indexOf('async function openAndCloseZoom('));
const sandbox={assert};vm.createContext(sandbox);vm.runInContext(sizes+resource+'\nthis.measureResource=measureResource;this.assertResource=assertResource;',sandbox);
const url='http://127.0.0.1:18433/image.webp';
const page={evaluate:async()=>({dpr:1,innerWidth:1280,innerHeight:900,sizes:'426.666px',currentSrc:url,renderedWidth:400,drawnWidth:400,candidates:[{url,w:720}]})};
const observed={status:200,contentType:'image/webp',bytes:86518,source:'browser.response'};
const checks=[];
(async()=>{
 let replacementCalls=0;
 const context={request:{get:async()=>{replacementCalls++;return {status:()=>200,headers:()=>({'content-type':'image/webp'}),body:async()=>Buffer.from('image')};}}};
 async function measured(responses){return sandbox.measureResource.length===3? sandbox.measureResource(page,context,responses):sandbox.measureResource(page,responses);}
 async function check(name,fn){try{await fn();checks.push({name,pass:true});}catch(error){checks.push({name,pass:false,error:error.message});}}
 await check('observed browser response passes',async()=>sandbox.assertResource(await measured(new Map([[url,observed]])),'observed'));
 await check('missing browser observation rejects and never fetches',async()=>{const before=replacementCalls;const m=await measured(new Map());assert.throws(()=>sandbox.assertResource(m,'missing'));assert.equal(replacementCalls,before);});
 await check('replacement fetch origin rejects',async()=>{const m=await measured(new Map([[url,{...observed,source:'context.request'}]]));assert.throws(()=>sandbox.assertResource(m,'replacement'));});
 await check('unattributed response rejects',async()=>{const {source,...unattributed}=observed;const m=await measured(new Map([[url,unattributed]]));assert.throws(()=>sandbox.assertResource(m,'unattributed'));});
 console.log(JSON.stringify({checks,passed:checks.filter(x=>x.pass).length,failed:checks.filter(x=>!x.pass).length,replacementCalls},null,2));process.exitCode=checks.some(x=>!x.pass)?1:0;
})().catch(error=>{console.error(error);process.exitCode=2;});
