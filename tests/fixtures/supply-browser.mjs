// Synthetic HTTP only. Optional response gates keep the real document alive during invalidation.
import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
export const id=n=>`00000001-0000-0000-0000-${String(n).padStart(12,'0')}`;
export const actor={id:id(1),version:id(9),role:'Owner',enabled:true,loginName:'synthetic',displayName:'Synthetic Owner'};
export const order={id:id(10),supplierId:id(11),supplierName:'Proveedor sintético',locationId:id(3),currency:'NIO',reference:'SYN-001',status:'open',totalMinor:500,createdBy:actor.id,updatedBy:actor.id,createdAt:'2026-11-05T12:00:00Z',updatedAt:'2026-11-05T12:00:00Z',lines:[{id:id(12),itemId:id(2),sku:'SYN-S',name:'Vestido sintético',orderedQuantity:5,receivedQuantity:0,remainingReceivableQuantity:5,cancelledQuantity:0,unitCostMinor:100,totalMinor:500}]};
export async function serve(port=0){
 const state={order:structuredClone(order),receipts:[],operations:new Map(),calls:[],session:true,role:'Owner',fault:null};
 const server=createServer(async(req,res)=>{const u=new URL(req.url,'http://127.0.0.1');const p=u.pathname;let raw='';for await(const b of req)raw+=b;
 const json=(v,status=200)=>{res.writeHead(status,{'Content-Type':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify(v));};
 if(p.startsWith('/internal/api/')){
 state.calls.push({path:p,method:req.method,raw,key:req.headers['idempotency-key'],csrf:!!req.headers['x-csrf-token']});
 if(p.endsWith('/security/csrf'))return json({headerName:'X-CSRF-TOKEN',token:'synthetic-only'});
 if(p.endsWith('/logout')){state.logoutWaiting=true;if(state.holdLogout)await state.holdLogout;state.session=false;res.writeHead(204);return res.end();}
 if(!state.session)return json({},401);
 if(p.endsWith('/security/me'))return json({...actor,role:state.role});
 const skip=Number(u.searchParams.get('skip')||0),take=Number(u.searchParams.get('take')||50);
 if(p.includes('/directory/')){const rows=p.endsWith('/locations')?[{id:id(3),name:'Sucursal sintética',branchId:id(4),active:true}]:[];return json({items:rows,total:rows.length,skip,take});}
 if(p.includes('/commerce/inventory'))return json({items:[],total:0,skip,take});
 if(p.includes('/operations/')){const result=state.operations.get(req.headers['idempotency-key']);return json(result?{status:'completed',result:{success:true,error:null,value:result}}:{error:'operation_not_found'},result?200:404);}
 if(p.includes('/supply/')){
 if(state.role==='Cashier')return json({},403);
 if(state.fault==='invalid')return json({});
 if(state.fault==='401')return json({},401);
 if(req.method==='POST'){
 const body=JSON.parse(raw),key=req.headers['idempotency-key'];let receipt=state.operations.get(key);
 if(!receipt){const q=body.lines[0].quantity;state.order.lines[0].receivedQuantity+=q;state.order.lines[0].remainingReceivableQuantity-=q;state.order.status=state.order.lines[0].remainingReceivableQuantity?'partially_received':'received';receipt={id:body.receiptId,purchaseOrderId:order.id,locationId:order.locationId,currency:'NIO',totalMinor:q*100,orderStatusAfter:state.order.status,receivedBy:actor.id,receivedAt:'2026-11-05T12:01:00Z',lines:body.lines.map(l=>({...l,itemId:id(2),unitCostMinor:100}))};state.receipts.push(receipt);state.operations.set(key,receipt);}
 if(state.fault==='lost'){return res.destroy();}if(state.holdReceipt)await state.holdReceipt;return json(receipt);
 }
 if(p.endsWith('/receipts'))return json({items:state.receipts.slice(skip,skip+take),skip,take,hasMore:false});
 if(p.endsWith('/purchase-orders'))return json({items:[state.order].slice(skip,skip+take),skip,take,hasMore:false});
 return json(state.order);
 }return json({},501);
 }
 try{const name=p==='/internal/'?'index.html':p.slice('/internal/'.length);if(!/^[a-z.-]+$/.test(name))return json({},404);const bytes=await readFile(path.resolve('dev/savia-staff-ui',name));res.writeHead(200,{'Content-Type':name.endsWith('html')?'text/html':name.endsWith('css')?'text/css':'text/javascript','Cache-Control':'no-store'});res.end(bytes);}catch{json({},404);}
 });await new Promise(r=>server.listen(port,'127.0.0.1',r));return {server,state,origin:`http://127.0.0.1:${server.address().port}`};
}
if(process.argv.includes('--serve')){const s=await serve(18764);console.log(s.origin);}
