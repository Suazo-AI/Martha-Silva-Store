// Protected receipt workflow. No stock arithmetic and no purchase creation.
import {StaffRequestError} from './login.mjs';
export const PENDING_SUPPLY = 'savia.supply.pending.v1';
const fail = () => { throw new StaffRequestError('response'); };
const validId = x => typeof x === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(x) && !/^0{8}-0{4}-0{4}-0{4}-0{12}$/.test(x);
const integer = (x,min=0,max=Number.MAX_SAFE_INTEGER) => Number.isSafeInteger(x) && x>=min && x<=max;
const text = x => typeof x==='string' && x.trim().length>0;
const currency = x => /^[A-Z]{3}$/.test(x) && x!=='XXX';
const receivable = s => ['open','partially_received'].includes(s);
const unique = xs => new Set(xs.map(x=>x.toLowerCase())).size===xs.length;
export function readOrder(v){
 if(!v || ![v.id,v.supplierId,v.locationId,v.createdBy,v.updatedBy].every(validId) || !text(v.supplierName) || !currency(v.currency)
 || !['open','partially_received','received','cancelled'].includes(v.status) || !integer(v.totalMinor)
 || ![v.createdAt,v.updatedAt].every(x=>typeof x==='string' && Number.isFinite(Date.parse(x)))
 || !Array.isArray(v.lines) || !integer(v.lines.length,1,100))fail();
 let total=0;
 for(const l of v.lines){if(!l || !validId(l.id) || !validId(l.itemId) || !text(l.sku) || !text(l.name)
 || !integer(l.orderedQuantity,1,1000000) || !integer(l.receivedQuantity,0,l.orderedQuantity) || !integer(l.unitCostMinor)
 || !integer(l.totalMinor) || l.totalMinor!==l.unitCostMinor*l.orderedQuantity
 || l.remainingReceivableQuantity!==(receivable(v.status)?l.orderedQuantity-l.receivedQuantity:0)
 || l.cancelledQuantity!==(v.status==='cancelled'?l.orderedQuantity-l.receivedQuantity:0))fail();total+=l.totalMinor;}
 if(!unique(v.lines.map(l=>l.id)) || !unique(v.lines.map(l=>l.itemId)) || total!==v.totalMinor || !integer(total)
 || (v.status==='received' && v.lines.some(l=>l.receivedQuantity!==l.orderedQuantity))
 || (v.status==='open' && v.lines.some(l=>l.receivedQuantity!==0))
 || (v.status==='partially_received' && (!v.lines.some(l=>l.receivedQuantity>0) || !v.lines.some(l=>l.remainingReceivableQuantity>0))))fail();
 return v;
}
export function validateDelivery(body){
 if(!body || Object.keys(body).sort().join()!=='lines,receiptId' || !validId(body.receiptId) || !Array.isArray(body.lines) || !integer(body.lines.length,1,100)
 || body.lines.some(l=>!l || Object.keys(l).sort().join()!=='purchaseOrderLineId,quantity' || !validId(l.purchaseOrderLineId) || !integer(l.quantity,1,1000000))
 || !unique(body.lines.map(l=>l.purchaseOrderLineId)))throw new StaffRequestError('invalid');return body;
}
export function readDelivery(v,order,expected,actor){
 if(!v || ![v.id,v.purchaseOrderId,v.locationId,v.receivedBy].every(validId) || !currency(v.currency) || !integer(v.totalMinor)
 || !['partially_received','received'].includes(v.orderStatusAfter) || !Number.isFinite(Date.parse(v.receivedAt))
 || !Array.isArray(v.lines) || !integer(v.lines.length,1,100) || !unique(v.lines.map(l=>l.purchaseOrderLineId||'')))fail();
 let total=0;
 for(const l of v.lines){const source=order?.lines.find(x=>x.id===l.purchaseOrderLineId);
 if(!l || !validId(l.purchaseOrderLineId) || !validId(l.itemId) || !integer(l.quantity,1,1000000) || !integer(l.unitCostMinor)
 || (order && (!source || source.itemId!==l.itemId || source.unitCostMinor!==l.unitCostMinor)))fail();total+=l.quantity*l.unitCostMinor;}
 if(!integer(total) || total!==v.totalMinor || (order && (v.purchaseOrderId!==order.id || v.locationId!==order.locationId || v.currency!==order.currency)))fail();
 if(expected && (v.id!==expected.receiptId || v.receivedBy!==actor || v.lines.length!==expected.lines.length || v.lines.some(l=>expected.lines.find(x=>x.purchaseOrderLineId===l.purchaseOrderLineId)?.quantity!==l.quantity)))fail();return v;
}
export function readPending(raw){
 const v=JSON.parse(raw);if(v?.schema!==1 || !validId(v.key) || !validId(v.actorId) || !validId(v.actorVersion) || v.scope!=='supply.receipt.create' || typeof v.rawBody!=='string')fail();
 readOrder(v.order);validateDelivery(v.body);
 if(JSON.stringify(v.body)!==v.rawBody || !receivable(v.order.status) || v.body.lines.some(l=>{const source=v.order.lines.find(x=>x.id===l.purchaseOrderLineId);return !source || l.quantity>source.remainingReceivableQuantity;}))fail();return v;
}
export function createSupplyClient(auth){
 const base='/internal/api/supply/purchase-orders';
 const page=async(path,skip,reader)=>{if(!integer(skip,0,100000))throw new StaffRequestError('invalid');const v=await auth.requestBusiness(`${path}?skip=${skip}&take=50`);
 if(!v || v.skip!==skip || v.take!==50 || typeof v.hasMore!=='boolean' || !Array.isArray(v.items) || v.items.length>50 || (v.hasMore && v.items.length!==50))fail();v.items.forEach(reader);if(!unique(v.items.map(x=>x.id)))fail();return v;};
 const orderPath=id=>{if(!validId(id))throw new StaffRequestError('invalid');return `${base}/${id}`;};
 return {listPurchaseOrders:(skip=0)=>page(base,skip,readOrder),getPurchaseOrder:async id=>readOrder(await auth.requestBusiness(orderPath(id))),
 listPurchaseReceipts:(order,skip=0)=>page(`${orderPath(order.id)}/receipts`,skip,v=>readDelivery(v,order)),
 receivePurchase:async pending=>{readPending(JSON.stringify(pending));return readDelivery(await auth.requestBusiness(`${orderPath(pending.order.id)}/receipts`,{method:'POST',key:pending.key,body:pending.body}),pending.order,pending.body,pending.actorId);},
 recoverPurchase:async pending=>{readPending(JSON.stringify(pending));const v=await auth.requestBusiness('/internal/api/operations/supply.receipt.create',{key:pending.key});
 if(v?.status!=='completed' || !v.result)fail();const r=v.result;
 if(r.success===false && r.value===null && /^[a-z_]{1,80}$/.test(r.error)){throw new StaffRequestError('receipt_rejected');}
 if(r.success!==true || r.error!==null)fail();return readDelivery(r.value,pending.order,pending.body,pending.actorId);}};
}
export function mountSupply({document,client,getSession,onUnauthorized,onStock=()=>{}}){
 const $=s=>document.querySelector(s);if(!$('#supply-form'))return {start(){},clear(){},destroy(){}};
 const el=(tag,text)=>{const e=document.createElement(tag);e.textContent=text;return e;};
 let epoch=0,busy=false,started=false,pending=null,blocked=false,retry=false,order=null,skip=0,receiptSkip=0,read=0;
 const same=(g,a)=>g===epoch && getSession()?.id===a?.id && getSession()?.version===a?.version;
 const allowed=()=>['Owner','Manager','Inventory'].includes(getSession()?.role);
 const status=t=>{$('#supply-status').textContent=t;};
 const storage=()=>document.defaultView.sessionStorage;
 function controls(){const enable=allowed()&&!busy&&!pending&&!blocked&&order&&receivable(order.status);
 $('#supply-submit').disabled=!enable;$('#supply-lines').querySelectorAll('input').forEach(x=>x.disabled=!enable||Number(x.max)===0);
 $('#supply-recover').hidden=!pending;$('#supply-recover').disabled=busy||!compatible();$('#supply-retry').hidden=!pending||!retry;$('#supply-retry').disabled=busy||!compatible();}
 function compatible(){const a=getSession();return allowed()&&a?.id===pending?.actorId&&a?.version===pending?.actorVersion;}
 function error(e){if(e?.status===401){onUnauthorized();return;}status(e instanceof StaffRequestError?e.message:'No se confirmó la recepción. Conservá la referencia pendiente.');}
 function clear(){++epoch;++read;busy=false;started=false;pending=null;blocked=false;retry=false;order=null;skip=0;receiptSkip=0;
 for(const id of ['orders','detail','lines','receipts','result'])$(`#supply-${id}`).replaceChildren();status('');controls();}
 async function list(target=0){const g=epoch,a=getSession(),r=++read;$('#supply-orders').replaceChildren();$('#supply-prev').disabled=true;$('#supply-next').disabled=true;
 try{const page=await client.listPurchaseOrders(target);if(!same(g,a)||r!==read)return;skip=target;
 for(const row of page.items){const b=el('button',`${row.reference||row.id} · ${row.supplierName} · ${row.status}`);b.type='button';b.className='btn btn-secondary';b.dataset.orderId=row.id;b.onclick=()=>void detail(row.id);$('#supply-orders').append(b);}
 if(!page.items.length)$('#supply-orders').append(el('p','Sin compras registradas.'));$('#supply-prev').disabled=skip===0;$('#supply-next').disabled=!page.hasMore;
 }catch(e){if(same(g,a)&&r===read)error(e);}}
 async function receipts(target=0){if(!order)return;const selected=order,g=epoch,a=getSession();$('#supply-receipts-prev').disabled=true;$('#supply-receipts-next').disabled=true;
 try{const page=await client.listPurchaseReceipts(selected,target);if(!same(g,a)||order!==selected)return;receiptSkip=target;$('#supply-receipts').replaceChildren(...page.items.map(v=>el('p',`${v.id} · ${v.receivedAt} · ${v.lines.reduce((n,l)=>n+l.quantity,0)} unidades`)));$('#supply-receipts-prev').disabled=target===0;$('#supply-receipts-next').disabled=!page.hasMore;}catch(e){if(same(g,a)&&order===selected)error(e);}}
 async function detail(id){if(busy)return;const g=epoch,a=getSession(),r=++read;order=null;$('#supply-lines').replaceChildren();$('#supply-detail').replaceChildren();$('#supply-receipts').replaceChildren();controls();
 try{const v=await client.getPurchaseOrder(id);if(!same(g,a)||r!==read)return;order=v;
 $('#supply-detail').append(el('h3',v.reference||v.id),el('p',`${v.supplierName} · Sucursal ${v.locationId} · ${v.currency} · ${v.status}`));
 for(const l of v.lines){const label=el('label',`${l.sku} · ${l.name}. Pedidas ${l.orderedQuantity}, recibidas ${l.receivedQuantity}, pendientes ${l.remainingReceivableQuantity}`);label.className='field';const input=document.createElement('input');input.type='number';input.min='0';input.max=String(l.remainingReceivableQuantity);input.step='1';input.value='0';input.dataset.lineId=l.id;input.setAttribute('aria-label',`Recibir ${l.sku}`);label.append(input);$('#supply-lines').append(label);}controls();await receipts();
 }catch(e){if(same(g,a)&&r===read)error(e);}}
 async function start(){if(started||!allowed())return;started=true;
 try{const raw=storage().getItem(PENDING_SUPPLY);if(raw)pending=readPending(raw);}catch{blocked=true;status('Referencia local inválida o almacenamiento no disponible. No se enviará una entrega. Conservá el almacenamiento para revisión.');}
 if(pending)status(compatible()?'Hay una recepción pendiente. Comprobá su resultado antes de recibir otra entrega.':`Referencia pendiente ${pending.key}. Ingresá con el actor y versión originales para recuperarla.`);controls();await list();}
 async function confirmed(result,g,a){if(!same(g,a))return;const selected=pending.order.id;
 // Keep the reference if durable cleanup fails; replay recovery remains safe.
 storage().removeItem(PENDING_SUPPLY);pending=null;retry=false;$('#supply-result').textContent=`Recepción confirmada: ${result.id}`;status('Recepción confirmada por el servidor.');busy=false;controls();await detail(selected);if(same(g,a))await onStock();}
 async function send(){if(!pending||!compatible()||busy||blocked)return;busy=true;retry=false;controls();const g=epoch,a=getSession();
 try{await confirmed(await client.receivePurchase(pending),g,a);}catch(e){if(same(g,a)){error(e);status(`${$('#supply-status').textContent} Comprobá la recepción pendiente; no registres otra entrega equivalente.`);}}finally{if(same(g,a)){busy=false;controls();}}}
 async function recover(){if(!pending||busy||!compatible()||blocked)return;busy=true;retry=false;controls();const g=epoch,a=getSession();
 try{await confirmed(await client.recoverPurchase(pending),g,a);}catch(e){if(same(g,a)){
 if(e.code==='receipt_rejected'){try{storage().removeItem(PENDING_SUPPLY);pending=null;status('El servidor confirmó el rechazo. Revisá las cantidades antes de registrar otra recepción.');}catch{blocked=true;status('No se pudo guardar el rechazo. Conservá la referencia pendiente.');}}
 else if(e.status===404){retry=true;status('La operación no fue encontrada. Podés reenviar exclusivamente la misma recepción con su identidad original.');}
 else {error(e);if(e.status!==401)status(`${$('#supply-status').textContent} Resultado pendiente; la referencia se conserva.`);}
 }}finally{if(same(g,a)){busy=false;controls();}}}
 function submit(e){e.preventDefault();if(busy||pending||blocked||!allowed()||!order||!receivable(order.status))return;
 try{const lines=[...$('#supply-lines').querySelectorAll('input')].map(i=>({purchaseOrderLineId:i.dataset.lineId,quantity:Number(i.value)}));
 if(lines.some(l=>!integer(l.quantity,0,order.lines.find(x=>x.id===l.purchaseOrderLineId).remainingReceivableQuantity)))throw new StaffRequestError('invalid');
 const body=validateDelivery({receiptId:document.defaultView.crypto.randomUUID(),lines:lines.filter(l=>l.quantity>0)}),a=getSession();
 const v={schema:1,scope:'supply.receipt.create',key:document.defaultView.crypto.randomUUID(),actorId:a.id,actorVersion:a.version,order:structuredClone(order),body,rawBody:JSON.stringify(body)};
 readPending(JSON.stringify(v));storage().setItem(PENDING_SUPPLY,JSON.stringify(v));if(storage().getItem(PENDING_SUPPLY)!==JSON.stringify(v))throw Error('storage');pending=v;void send();
 }catch(e){blocked=e?.code!=='invalid';status(blocked?'No se pudo guardar la referencia durable. No se envió la recepción.': 'Ingresá al menos una cantidad entera dentro del pendiente.');controls();}}
 const handlers=[['#supply-form','submit',submit],['#supply-refresh','click',()=>void list()],['#supply-prev','click',()=>void list(Math.max(0,skip-50))],['#supply-next','click',()=>void list(skip+50)],['#supply-receipts-prev','click',()=>void receipts(Math.max(0,receiptSkip-50))],['#supply-receipts-next','click',()=>void receipts(receiptSkip+50)],['#supply-recover','click',()=>void recover()],['#supply-retry','click',()=>void send()]];
 handlers.forEach(([s,e,f])=>$(s).addEventListener(e,f));controls();
 return {start,clear,destroy(){clear();handlers.forEach(([s,e,f])=>$(s).removeEventListener(e,f));}};
}
