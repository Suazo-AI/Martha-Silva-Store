// Runs existing Playwright guards against an owned, loopback-only .NET process without SQL.
import {spawn} from 'node:child_process';
import {createServer} from 'node:net';
import {mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const [dotnet,dll,pw,outArg]=process.argv.slice(2);
if(!dotnet||!dll||!pw||!outArg)throw Error('Explicit dotnet, DLL, installed Playwright, and private evidence directory required.');
const out=path.resolve(outArg),root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');await mkdir(out,{recursive:true});
const inherited=Object.keys(process.env).filter(k=>/^(MARTHA_|SAVIA_INTERNAL_).*SQL/.test(k)&&process.env[k]);
if(inherited.length)throw Error('Unexpected inherited SQL test configuration. Stop and inspect names privately.');
const probe=createServer();await new Promise(r=>probe.listen(0,'127.0.0.1',r));const port=probe.address().port;await new Promise(r=>probe.close(r));
const origin=`http://127.0.0.1:${port}`;
const env={...process.env,DOTNET_ROOT:path.dirname(dotnet),ASPNETCORE_ENVIRONMENT:'Development',DOTNET_ENVIRONMENT:'Development',ASPNETCORE_URLS:origin,
  Synthetic__Enabled:'true',InternalSavia__Enabled:'false',ConnectionStrings__Store:'Database=Forbidden_NoSql',ConnectionStrings__InternalSavia:'Database=Forbidden_NoSql'};
const api=spawn(dotnet,[dll,'--urls',origin],{cwd:path.dirname(dll),env,windowsHide:true,stdio:['ignore','pipe','pipe']});
let log='',exited=false;api.stdout.on('data',b=>log+=b);api.stderr.on('data',b=>log+=b);api.on('exit',()=>{exited=true;});
let result={origin,apiPid:api.pid,mode:'real HTTP API; intentionally invalid SQL target; no database connection',status:'NOT_RUN'};
try{
  let ready=false;for(let i=0;i<40&&!exited;i++){try{const r=await fetch(origin+'/health/live',{signal:AbortSignal.timeout(500)});if(r.status===200){ready=true;break;}}catch{}await new Promise(r=>setTimeout(r,200));}
  if(!ready)throw Error('Owned API did not become live in the bounded startup window.');
  const args=[path.join(pw,'cli.js'),'test','-c','dev/savia-harness/playwright/playwright.config.mjs'];
  const runner=spawn(process.execPath,args,{cwd:root,env:{...process.env,SAVIA_PLAYWRIGHT_PACKAGE:pw,SAVIA_QA_ORIGIN:origin,SAVIA_QA_OUTPUT:path.join(out,'traces')},windowsHide:true,stdio:['ignore','pipe','pipe']});
  let output='';runner.stdout.on('data',b=>output+=b);runner.stderr.on('data',b=>output+=b);
  const code=await new Promise((resolve,reject)=>{runner.on('error',reject);runner.on('exit',resolve);});await writeFile(path.join(out,'playwright.txt'),output);
  result={...result,status:code===0?'PASS':'FAIL',exitCode:code,command:[process.execPath,...args],output};process.exitCode=code===0?0:1;
}catch(e){result={...result,status:'BLOCKED',error:e.message};process.exitCode=1;}
finally{
  if(!exited){api.kill();for(let i=0;i<30&&!exited;i++)await new Promise(r=>setTimeout(r,100));}
  result.ownedApiStopped=exited;await writeFile(path.join(out,'api.log'),log);await writeFile(path.join(out,'results.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result));
}
