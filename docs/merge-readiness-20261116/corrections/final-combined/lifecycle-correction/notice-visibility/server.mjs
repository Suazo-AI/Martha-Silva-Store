// Loopback-only fake HTTP. Actual app shell/router/login; one test-only ctx export.
import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
const root=process.cwd(), web=path.join(root,'savia/web'), out=path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Z]:)/,'$1'));
const id=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
let calls=[], release, held=false;const sockets=new Set(),served=new Map();
const server=http.createServer(async(req,res)=>{try{
 const u=new URL(req.url,'http://localhost'), p=u.pathname;
 const json=(data,status=200)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify(data));};
 if(p==='/__fixture/state')return json({calls,held,served:Object.fromEntries(served)});
 if(p==='/__fixture/reset'){if(held)throw Error('Cleanup still held');calls=[];return json({ok:true});}
 if(p==='/__fixture/release'){release?.();return json({ok:true});}
 if(p.startsWith('/api/v1/')){
  calls.push({method:req.method,path:p,authorization:req.headers.authorization??null});
  if(p==='/api/v1/auth/login'){
   let raw='';for await(const c of req)raw+=c;const b=JSON.parse(raw);
   return json({token:`fictional-${b.loginName}`,roles:b.loginName==='manager'?['MANAGER']:['SELLER']});
  }
  if(p==='/api/v1/auth/logout'){
   if(req.headers.authorization==='Bearer fictional-approval'){held=true;await new Promise(r=>release=r);held=false;return json({},500);}
   return json(null,204);
  }
  if(p==='/api/v1/me'){const manager=req.headers.authorization==='Bearer fictional-manager';return json({staffId:id(manager?1:2),nodeId:id(3),branchId:id(4),locationId:id(5),displayName:manager?'PRIVATE OLD ACTOR':'Fixture Seller',roles:manager?['MANAGER']:['SELLER']});}
  if(p==='/api/v1/cash/registers')return json([]);
  if(p==='/api/v1/exchange-rate')return json({rate:36.5,effectiveFrom:'2026-11-16'});
  // The settings page calls the documented plural route in some revisions.
  if(p==='/api/v1/exchange-rates/current')return json({rate:36.5,effectiveFrom:'2026-11-16'});
  throw Error(`Unexpected fake API ${req.method} ${p}`);
 }
 if(p==='/favicon.ico'){res.writeHead(204);return res.end();}
 const target=p==='/probe.mjs'?path.join(out,'probe.mjs'):path.resolve(web,'.'+(p==='/'?'/index.html':p));
 if(target!==path.join(out,'probe.mjs')&&!target.startsWith(web+path.sep))throw Error('Outside web root');
 const raw=await fs.readFile(target),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
 served.set(path.relative(root,target).replaceAll('\\','/'),{bytes:raw.length,rawSha256:sha(raw)});
 const data=p==='/app.mjs'?Buffer.concat([raw,Buffer.from('\nexport {ctx as __probeCtx};\n')]):raw;
 res.writeHead(200,{'Content-Type':target.endsWith('.mjs')?'text/javascript; charset=utf-8':target.endsWith('.css')?'text/css; charset=utf-8':'text/html; charset=utf-8','Cache-Control':'no-store'});res.end(data);
}catch(e){console.error(e.message);res.writeHead(500);res.end();}});
server.on('connection',s=>{sockets.add(s);s.on('close',()=>sockets.delete(s));});
server.listen(0,'127.0.0.1',()=>console.log(JSON.stringify({port:server.address().port,scope:'fictional HTTP; ctx export appended only to served app.mjs'})));
const close=()=>{release?.();for(const s of sockets)s.destroy();server.close(()=>process.exit(0));};
process.on('SIGTERM',close);process.on('SIGINT',close);
