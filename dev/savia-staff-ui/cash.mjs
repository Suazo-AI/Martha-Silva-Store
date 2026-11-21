import {StaffRequestError} from './login.mjs';
import {readReceipt, validateSaleRequest, validRecordedDate} from './client.mjs';
const MAX=9000000000000, id=v=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v)&&!/^0{8}-0{4}-0{4}-0{4}-0{12}$/.test(v);
const same=(a,b)=>id(a)&&id(b)&&a.toLowerCase()===b.toLowerCase();
const amount=(v,signed=false)=>Number.isSafeInteger(v)&&v<=(MAX)&&v>=(signed?-MAX:0);
const exponent=v=>Number.isInteger(v)&&v>=0&&v<=6;
const currency=v=>typeof v==='string'&&/^[A-Z]{3}$/.test(v)&&v!=='XXX';
const date=validRecordedDate;
const text=(v,max)=>typeof v==='string'&&v.trim().length>0&&v.length<=max&&!/[\x00-\x1f\x7f]/.test(v);
const key=v=>typeof v==='string'&&/^[A-Za-z0-9_-]{16,128}$/.test(v);
function need(ok,code='response'){if(!ok)throw new StaffRequestError(code);}
function fields(v,names){need(v&&typeof v==='object'&&!Array.isArray(v)&&Object.keys(v).length===names.length&&names.every(n=>Object.hasOwn(v,n)));}
export function parseMinor(value,exp){
  need(exponent(exp)&&typeof value==='string'&&/^(0|[1-9]\d*)(?:\.\d+)?$/.test(value),'invalid');
  const [whole,fraction='']=value.split('.'); need(fraction.length<=exp,'invalid');
  const result=BigInt(whole)*10n**BigInt(exp)+BigInt(fraction.padEnd(exp,'0')||'0');
  need(result<=BigInt(MAX),'invalid'); return Number(result);
}
export function formatMinor(value,exp,code){
  need(amount(value,true)&&currency(code));
  if(exp==null)return `${value} ${code} (unidades menores)`;
  need(exponent(exp));const n=BigInt(value),abs=n<0n?-n:n,power=10n**BigInt(exp);
  return `${n<0n?'-':''}${abs/power}${exp?'.'+String(abs%power).padStart(exp,'0'):''} ${code}`;
}
function till(v){fields(v,['id','cashierId','locationId','currency','exponent','openedAt','closedAt']);
  need(id(v.id)&&id(v.cashierId)&&id(v.locationId)&&currency(v.currency)&&exponent(v.exponent)&&date(v.openedAt)
    &&(v.closedAt===null||(date(v.closedAt)&&Date.parse(v.closedAt)>=Date.parse(v.openedAt))));return v;}
function entry(v){fields(v,['id','tillId','cashierId','actorId','currency','exponent','kind','deltaMinor','receivedMinor','changeMinor','saleId','reversalId','createdAt']);
  need([v.id,v.tillId,v.cashierId,v.actorId].every(id)&&currency(v.currency)&&exponent(v.exponent)&&date(v.createdAt)
    &&amount(v.deltaMinor,true)&&amount(v.receivedMinor)&&amount(v.changeMinor)&&['opening','sale','refund'].includes(v.kind)
    &&(v.saleId===null||id(v.saleId))&&(v.reversalId===null||id(v.reversalId)));return v;}
function close(v,t){fields(v,['id','tillId','actorId','expectedMinor','countedMinor','differenceMinor','createdAt']);
  need(id(v.id)&&same(v.tillId,t.id)&&same(v.actorId,t.cashierId)&&amount(v.expectedMinor)&&amount(v.countedMinor)&&amount(v.differenceMinor,true)
    &&v.differenceMinor===v.countedMinor-v.expectedMinor&&date(v.createdAt)&&v.createdAt===t.closedAt);return v;}
function balance(v){fields(v,['till','balanceMinor']);till(v.till);need(v.till.closedAt===null&&amount(v.balanceMinor));return v;}
export function readCashContext(v,actor){fields(v,['configuration','ownTill','lastClose']);
  if(v.configuration!==null){fields(v.configuration,['currency','exponent']);need(currency(v.configuration.currency)&&exponent(v.configuration.exponent));}
  if(v.ownTill!==null){balance(v.ownTill);need(same(v.ownTill.till.cashierId,actor));}
  if(v.lastClose!==null){fields(v.lastClose,['till','close']);till(v.lastClose.till);need(same(v.lastClose.till.cashierId,actor));close(v.lastClose.close,v.lastClose.till);}
  return v;
}
export function readRefundContext(v,saleId,skip,take){fields(v,['sale','payment','refundedMinor','refundableMinor','paymentStatus','payingTills']);
  readReceipt(v.sale);entry(v.payment);const p=v.payment;
  need(same(v.sale.saleId,saleId)&&v.sale.paymentStatus==='paid'&&p.kind==='sale'&&same(p.saleId,saleId)&&p.reversalId===null
    &&same(p.actorId,v.sale.actorId)&&same(p.cashierId,v.sale.actorId)&&p.currency===v.sale.currency&&p.deltaMinor===v.sale.totalMinor
    &&p.receivedMinor-p.changeMinor===p.deltaMinor&&amount(v.refundedMinor)&&amount(v.refundableMinor)
    &&v.refundedMinor+v.refundableMinor===p.deltaMinor
    &&v.sale.lines.reduce((sum,x)=>sum+BigInt(x.returnedQuantity)*BigInt(x.unitPriceMinor),0n)===BigInt(v.refundedMinor)
    &&v.paymentStatus===(v.refundedMinor===0?'paid':v.refundableMinor===0?'refunded':'partially_refunded'));
  fields(v.payingTills,['items','skip','take','hasMore']);const page=v.payingTills;
  need(page.skip===skip&&page.take===take&&typeof page.hasMore==='boolean'&&Array.isArray(page.items)&&page.items.length<=take&&(!page.hasMore||page.items.length===take));
  page.items.forEach(x=>{balance(x);need(same(x.till.locationId,v.sale.locationId)&&x.till.currency===p.currency&&x.till.exponent===p.exponent);});
  need(new Set(page.items.map(x=>x.till.id.toLowerCase())).size===page.items.length);return v;
}
const routes={open:['cash.till.open','/internal/api/cash/tills'],sale:['cash.sale','/internal/api/cash/sales'],refund:['cash.refund',null],close:['cash.till.close',null]};
export function validateCashIntent(op){
  need(op&&op.schema===1&&id(op.actorId)&&id(op.actorVersion)&&key(op.key)&&Object.hasOwn(routes,op.kind)
    &&op.scope===routes[op.kind][0]&&['prepared','dispatching','uncertain'].includes(op.dispatchState)
    &&typeof op.rawBody==='string'&&JSON.stringify(op.body)===op.rawBody&&op.evidence,'invalid');
  const b=op.body,e=op.evidence;need(typeof b==='object'&&b!==null,'invalid');
  if(op.kind==='open'){fields(b,['locationId','currency','openingMinor']);need(id(b.locationId)&&currency(b.currency)&&amount(b.openingMinor)&&exponent(e.exponent)&&b.currency===e.currency,'invalid');}
  else {
    till(e.till);need(e.till.closedAt===null,'invalid');need(op.kind==='refund'||same(e.till.cashierId,op.actorId),'invalid');
    if(op.kind==='sale'){fields(b,['tillId','customerId','lines','currency','receivedMinor']);
      validateSaleRequest({locationId:e.till.locationId,customerId:b.customerId,lines:b.lines});need(b.lines.every(x=>Object.keys(x).every(k=>['itemId','quantity','exceptionReason','size'].includes(k))),'invalid');need(same(b.tillId,e.till.id)&&b.currency===e.till.currency&&amount(b.receivedMinor),'invalid');}
    if(op.kind==='close'){fields(b,['countedMinor']);need(amount(b.countedMinor),'invalid');}
    if(op.kind==='refund'){fields(b,['payingTillId','currency','reason','lines']);readReceipt(e.sale);
      need(same(b.payingTillId,e.till.id)&&same(e.till.locationId,e.sale.locationId)&&e.till.closedAt===null&&b.currency===e.till.currency&&b.currency===e.sale.currency
        &&amount(e.refundableMinor)&&text(b.reason,500)&&Array.isArray(b.lines)&&b.lines.length>0&&b.lines.length<=100,'invalid');
      const originals=new Map(e.sale.lines.map(x=>[x.saleLineId.toLowerCase(),x]));
      b.lines.forEach(x=>{fields(x,['saleLineId','quantity']);const original=originals.get(x.saleLineId?.toLowerCase());need(id(x.saleLineId)&&original&&Number.isInteger(x.quantity)&&x.quantity>0&&x.quantity<=original.quantity-original.returnedQuantity,'invalid');});
      need(new Set(b.lines.map(x=>x.saleLineId.toLowerCase())).size===b.lines.length,'invalid');}
  }
  const expected=routes[op.kind][1]||(op.kind==='refund'?`/internal/api/cash/sales/${e.sale.saleId}/refunds`:`/internal/api/cash/tills/${e.till.id}/close`);
  need(op.path===expected,'invalid');return op;
}
export function readCashReceipt(v,op){validateCashIntent(op);const b=op.body,e=op.evidence;
  if(op.kind==='open'||op.kind==='close'){
    fields(v,op.kind==='open'?['till','opening']:['till','close']);till(v.till);need(same(v.till.cashierId,op.actorId));
    if(op.kind==='open'){entry(v.opening);const x=v.opening;need(v.till.closedAt===null&&same(v.till.locationId,b.locationId)&&v.till.currency===b.currency&&v.till.exponent===e.exponent
      &&x.kind==='opening'&&x.deltaMinor===b.openingMinor&&x.saleId===null&&x.reversalId===null&&x.receivedMinor===0&&x.changeMinor===0);link(x,v.till,op.actorId);}
    else{close(v.close,v.till);need(['id','cashierId','locationId','currency','exponent','openedAt'].every(k=>v.till[k]===e.till[k])&&v.close.countedMinor===b.countedMinor);}
  }else if(op.kind==='sale'){
    fields(v,['sale','payment','locationId','exponent','changeMinor','paymentStatus']);
    readReceipt(v.sale,{locationId:e.till.locationId,customerId:b.customerId,lines:b.lines});entry(v.payment);link(v.payment,e.till,op.actorId);
    need(v.sale.state==='recorded'&&v.sale.lines.every(x=>x.returnedQuantity===0)&&v.sale.paymentStatus==='paid'&&v.paymentStatus==='paid'&&same(v.sale.actorId,op.actorId)&&same(v.locationId,e.till.locationId)
      &&v.exponent===e.till.exponent&&v.sale.currency===e.till.currency&&same(v.payment.saleId,v.sale.saleId)&&v.payment.reversalId===null
      &&v.payment.kind==='sale'&&v.payment.deltaMinor===v.sale.totalMinor&&v.payment.receivedMinor===b.receivedMinor
      &&amount(v.changeMinor)&&v.changeMinor===v.payment.changeMinor&&b.receivedMinor-v.changeMinor===v.sale.totalMinor);
  }else{
    fields(v,['reversal','refund','locationId','refundableMinor','paymentStatus']);entry(v.refund);link(v.refund,e.till,op.actorId);
    const r=v.reversal;fields(r,['reversalId','saleId','actorId','kind','saleState','currency','recordedCreditMinor','bankRefundStatus','reason','createdAt','lines']);
    need(id(r.reversalId)&&same(r.saleId,e.sale.saleId)&&same(r.actorId,op.actorId)&&r.kind==='return'&&['returned','partially_returned'].includes(r.saleState)
      &&r.currency===b.currency&&r.bankRefundStatus==='not_processed'&&r.reason===b.reason.trim()&&date(r.createdAt)&&Array.isArray(r.lines)&&r.lines.length===b.lines.length);
    const originals=new Map(e.sale.lines.map(x=>[x.saleLineId.toLowerCase(),x]));let total=0n;
    for(const line of r.lines){fields(line,['saleLineId','quantity','recordedCreditMinor']);need(id(line.saleLineId));const request=b.lines.find(x=>same(x.saleLineId,line.saleLineId)),original=originals.get(line.saleLineId.toLowerCase());
      need(request&&original&&line.quantity===request.quantity&&amount(line.recordedCreditMinor)&&BigInt(line.recordedCreditMinor)===BigInt(original.unitPriceMinor)*BigInt(line.quantity));total+=BigInt(line.recordedCreditMinor);}
    need(new Set(r.lines.map(x=>x.saleLineId.toLowerCase())).size===r.lines.length&&total>0n&&total<=BigInt(MAX)&&r.recordedCreditMinor===Number(total)
      &&v.refund.kind==='refund'&&same(v.refund.saleId,e.sale.saleId)&&same(v.refund.reversalId,r.reversalId)&&v.refund.deltaMinor===-Number(total)
      &&v.refund.receivedMinor===0&&v.refund.changeMinor===0&&same(v.locationId,e.sale.locationId)&&amount(v.refundableMinor)
      &&v.refundableMinor<=e.refundableMinor-Number(total)&&v.paymentStatus===(v.refundableMinor===0?'refunded':'partially_refunded'));
  }return v;
}
function link(x,t,actor){need(same(x.tillId,t.id)&&same(x.cashierId,t.cashierId)&&same(x.actorId,actor)&&x.currency===t.currency&&x.exponent===t.exponent&&Date.parse(x.createdAt)>=Date.parse(t.openedAt));}
export function createCashClient(auth){
  const session=()=>auth.getVerifiedSession();
  return {session,
    async context(){const a=session();need(a,'unauthorized');return readCashContext(await auth.requestBusiness('/internal/api/cash/context'),a.id);},
    async refundContext(saleId,skip=0){need(id(saleId)&&Number.isSafeInteger(skip)&&skip>=0,'invalid');return readRefundContext(await auth.requestBusiness(`/internal/api/cash/sales/${saleId}/refund-context?skip=${skip}&take=50`),saleId,skip,50);},
    async send(op){validateCashIntent(op);try{return readCashReceipt(await auth.requestBusiness(op.path,{method:'POST',body:op.body,key:op.key}),op);}
      catch(error){if([400,403,404,409].includes(error.status)&&rejections.has(error.serverCode)&&!['invalid_request','forbidden'].includes(error.serverCode))return this.recover(op);throw error;}},
    async recover(op){validateCashIntent(op);const v=await auth.requestBusiness(`/internal/api/operations/${op.scope}`,{key:op.key});
      fields(v,['status','result']);need(v.status==='completed');fields(v.result,['success','value','error']);
      if(v.result.success===false&&v.result.value===null&&rejections.has(v.result.error)){const error=new StaffRequestError('cash_rejected');error.serverCode=v.result.error;throw error;}
      need(v.result.success===true&&v.result.error===null);return readCashReceipt(v.result.value,op);}
  };
}
const rejections=new Set(['forbidden','invalid_request','till_already_open','location_not_found','till_closed','currency_mismatch','cash_payment_required','insufficient_tender','amount_out_of_range','sale_not_found','return_quantity_exceeded','refund_exceeded','insufficient_cash','item_not_found','stock_unavailable','customer_not_found','sale_state_conflict']);
export class CashIntentStore {
  constructor({client,storage,getSession,crypto=globalThis.crypto}){Object.assign(this,{client,storage,getSession,crypto});this.pending=null;this.epoch=0;this.busy=false;}
  slot(a){return `savia.cash.pending.${a.id.toLowerCase()}`;}
  clear(){this.epoch++;this.pending=null;this.busy=false;}
  current(epoch,a){return epoch===this.epoch&&same(this.getSession()?.id,a.id)&&same(this.getSession()?.version,a.version);}
  load(){const a=this.getSession();need(a,'unauthorized');const raw=this.storage.getItem(this.slot(a));if(!raw)return null;
    const op=JSON.parse(raw);validateCashIntent(op);need(typeof op.bodyHash==='string'&&/^[a-f0-9]{64}$/.test(op.bodyHash));need(same(op.actorId,a.id));this.pending=op;return op;}
  compatible(){const a=this.getSession();return a&&this.pending&&same(a.id,this.pending.actorId)&&same(a.version,this.pending.actorVersion)&&
    ['Owner','Manager','Cashier'].includes(a.role)&&(this.pending.kind!=='refund'||['Owner','Manager'].includes(a.role));}
  save(op){const a=this.getSession();need(a&&same(a.id,op.actorId)&&same(a.version,op.actorVersion),'unauthorized');validateCashIntent(op);
    const raw=JSON.stringify(op);this.storage.setItem(this.slot(a),raw);need(this.storage.getItem(this.slot(a))===raw,'unavailable');this.pending=op;}
  async prepare(kind,body,evidence){need(!this.pending&&!this.busy,'invalid');const a=this.getSession();need(a,'unauthorized');const epoch=this.epoch;this.busy=true;
    try { const op={schema:1,actorId:a.id,actorVersion:a.version,kind,scope:routes[kind]?.[0],key:this.crypto.randomUUID(),
      path:routes[kind]?.[1]||(kind==='refund'?`/internal/api/cash/sales/${evidence.sale.saleId}/refunds`:`/internal/api/cash/tills/${evidence.till.id}/close`),
      body:structuredClone(body),rawBody:JSON.stringify(body),dispatchState:'prepared',evidence:structuredClone(evidence)};
    validateCashIntent(op);op.bodyHash=[...new Uint8Array(await this.crypto.subtle.digest('SHA-256',new TextEncoder().encode(op.rawBody)))].map(x=>x.toString(16).padStart(2,'0')).join('');
    need(this.current(epoch,a),'unauthorized');this.save(op);return op;
    } finally {if(this.current(epoch,a))this.busy=false;}
  }
  cleanup(op,epoch,a){need(this.current(epoch,a),'unauthorized');const slot=this.slot(a),raw=JSON.stringify(op);
    need(this.storage.getItem(slot)===raw,'unavailable');try{this.storage.removeItem(slot);need(this.storage.getItem(slot)===null,'unavailable');}
    catch(error){try{this.storage.setItem(slot,raw);}catch{}throw error;}need(this.current(epoch,a),'unauthorized');this.pending=null;}
  async resolve(mode='recover'){
    need(this.compatible()&&!this.busy,'invalid');const op=this.pending,a=this.getSession(),epoch=this.epoch,uncertain=op.dispatchState!=='prepared';this.busy=true;
    try{
      if(mode==='send'){this.save({...op,dispatchState:'dispatching'});}
      const value=await this.client[mode==='send'?'send':'recover'](this.pending);
      need(this.current(epoch,a),'unauthorized');this.cleanup(this.pending,epoch,a);return value;
    }catch(error){
      if(this.current(epoch,a)){
        const definitive=error.code==='cash_rejected'||(mode==='send'&&!uncertain&&((error.status===400&&['invalid_request','csrf_invalid','https_required'].includes(error.serverCode))||(error.status===403&&error.serverCode==='forbidden')));
        if(definitive){this.cleanup(this.pending,epoch,a);error.definitive=true;}
        else if(this.pending){try{this.save({...this.pending,dispatchState:'uncertain'});}catch{}}
      }throw error;
    }finally{if(this.current(epoch,a))this.busy=false;}
  }
}
export function mountCash({document,client,getSession,onUnauthorized,onChange=()=>{},onStock=()=>{},onSale=()=>{}}){
  const $=id=>document.getElementById(id),panel=$('cash-panel');
  if(!panel)return null;
  const store=new CashIntentStore({client:client.cash,storage:document.defaultView.sessionStorage,getSession,crypto:document.defaultView.crypto});
  let context=null,refund=null,busy=false,blocked=false,places=[],epoch=0,refundRead=0;
  const removers=[],listen=(el,event,fn)=>{el.addEventListener(event,fn);removers.push(()=>el.removeEventListener(event,fn));};
  const current=(e,a)=>e===epoch&&same(getSession()?.id,a.id)&&same(getSession()?.version,a.version);
  const allowed=()=>['Owner','Manager','Cashier'].includes(getSession()?.role),manage=()=>['Owner','Manager'].includes(getSession()?.role);
  const status=message=>{$('cash-status').textContent=message;};
  const el=(tag,value)=>{const node=document.createElement(tag);node.textContent=value;return node;};
  const money=(v,t)=>formatMinor(v,t.exponent,t.currency);
  const legacy=()=>{const a=getSession();return !!a&&!!document.defaultView.sessionStorage.getItem(`savia.sale.pending.${a.id}`);};
  function usable(){try{return allowed()&&!busy&&!blocked&&!store.pending&&!legacy();}catch{blocked=true;return false;}}
  function lock(){
    const ready=usable(),own=context?.ownTill;
    for(const control of $('cash-open').elements)control.disabled=!ready||!context?.configuration||!!own||!places.length;
    for(const control of $('cash-close').elements)control.disabled=!ready||!own;
    for(const control of $('cash-refund-load').elements)control.disabled=!ready||!manage();
    for(const control of $('cash-refund').elements)control.disabled=!ready||!manage()||!context?.configuration||!refund||refund.refundableMinor===0||!refund.payingTills.items.length;
    $('cash-refund-section').hidden=!manage();
    $('cash-prev').disabled=!ready||!refund||refund.payingTills.skip===0;
    $('cash-next').disabled=!ready||!refund?.payingTills.hasMore;
    $('cash-refresh').disabled=busy||blocked||!allowed();
    for(const name of ['cash-recover','cash-continue']){$(name).hidden=!store.pending;$(name).disabled=busy||blocked||!store.compatible();}
    const p=store.pending;$('cash-reference').textContent=p?`Actor ${p.actorId} · ${p.scope} · ${p.key} · SHA256 ${p.bodyHash||'no disponible'}${store.compatible()?'':' · El acceso cambió. Conciliar con el responsable.'}`:'';
    $('cash-reference').style.overflowWrap='anywhere';onChange();
  }
  function showContext(){
    const out=$('cash-context');out.replaceChildren();
    if(!context)return;
    if(context.ownTill){const x=context.ownTill;out.append(el('p',`Caja abierta · ${x.till.id}`),el('p',`Saldo confirmado: ${money(x.balanceMinor,x.till)}`));}
    else out.append(el('p','Sin caja abierta.'));
    if(!context.configuration)out.append(el('p','Configuración monetaria no disponible. Apertura, venta y devolución deshabilitadas.'));
    if(context.lastClose){const x=context.lastClose;out.append(el('p',`Último cierre · ${x.close.id} · Esperado ${money(x.close.expectedMinor,x.till)} · Contado ${money(x.close.countedMinor,x.till)} · Diferencia ${money(x.close.differenceMinor,x.till)}`));}
    out.style.overflowWrap='anywhere';
    $('cash-currency').textContent=context.configuration?`${context.configuration.currency} · ${context.configuration.exponent} decimales`:'';
    $('sale-received-label').textContent=`Efectivo recibido${context.ownTill?' ('+context.ownTill.till.currency+')':''}`;
  }
  function showRefund(){
    const mount=$('cash-refund-lines');mount.replaceChildren();const page=$('cash-paying-till');page.replaceChildren();
    if(!refund)return;
    const p=refund.payment;
    $('cash-refund-summary').textContent=`Venta ${refund.sale.saleId} · Reembolsable ${money(refund.refundableMinor,p)} · ${refund.paymentStatus}`;
    for(const x of refund.sale.lines){const label=el('label',`${x.sku} · ${x.name} · Precio original ${money(x.unitPriceMinor,p)} · Disponible ${x.quantity-x.returnedQuantity}`);label.className='field';
      const input=document.createElement('input');input.type='number';input.min='0';input.max=String(x.quantity-x.returnedQuantity);input.step='1';input.value='0';input.dataset.refundLine=x.saleLineId;input.setAttribute('aria-label',`Devolver ${x.sku}`);label.append(input);mount.append(label);}
    for(const x of refund.payingTills.items){const option=el('option',`${x.till.cashierId} · ${money(x.balanceMinor,x.till)} · ${x.till.id}`);option.value=x.till.id;page.append(option);}
    $('cash-page').textContent=refund.payingTills.items.length?`Cajas ${refund.payingTills.skip+1}–${refund.payingTills.skip+refund.payingTills.items.length}${refund.payingTills.hasMore?' · Hay más':''}`:'Sin cajas disponibles.';
  }
  async function refresh(){const a=getSession(),e=epoch;if(!a||!allowed())return;
    const value=await client.cash.context();if(!current(e,a))return;context=value;showContext();lock();
  }
  async function readRefund(skip=0){const a=getSession(),e=epoch,request=++refundRead,saleId=$('cash-sale-id').value.trim();
    const value=await client.cash.refundContext(saleId,skip);if(!current(e,a)||request!==refundRead)return;
    refund=value;showRefund();lock();
  }
  function fail(error){if(error?.status===401){onUnauthorized();return;}
    status(store.pending?'Resultado sin confirmar. Comprobá la operación o continuá con la misma referencia.':error instanceof StaffRequestError?error.message:'No se pudo completar la consulta.');}
  function showReceipt(value,op){const out=$('cash-receipt');out.replaceChildren(el('h3','Operación confirmada'));const t=op.evidence.till||value.till;
    if(op.kind==='open')out.append(el('p',`Apertura: ${money(value.opening.deltaMinor,value.till)}`));
    if(op.kind==='sale'){out.append(el('p',`Venta ${value.sale.saleId}`));for(const line of value.sale.lines)out.append(el('p',`${line.sku} · ${line.quantity} × ${money(line.unitPriceMinor,t)} = ${money(line.totalMinor,t)}`));
      out.append(el('p',`Total ${money(value.sale.totalMinor,t)} · Recibido ${money(value.payment.receivedMinor,t)} · Cambio ${money(value.changeMinor,t)}`));$('cash-sale-id').value=value.sale.saleId;}
    if(op.kind==='refund')out.append(el('p',`Devolución ${value.reversal.reversalId} · Entregado ${money(value.reversal.recordedCreditMinor,t)} · Reembolsable ${money(value.refundableMinor,t)} · ${value.paymentStatus}`));
    if(op.kind==='close')out.append(el('p',`Cierre ${value.close.id} · Esperado ${money(value.close.expectedMinor,t)} · Contado ${money(value.close.countedMinor,t)} · Diferencia ${money(value.close.differenceMinor,t)}`));
    out.hidden=false;out.style.overflowWrap='anywhere';
  }
  async function resolve(mode){if(busy||blocked||!store.compatible())return;const a=getSession(),e=epoch,op=store.pending;busy=true;lock();status('Comprobando la operación…');
    try{const value=await store.resolve(mode);if(!current(e,a))return;showReceipt(value,op);if(op.kind==='sale')onSale();status('Operación confirmada por el servidor.');
      await refresh();if(!current(e,a))return;
      if(refund){await readRefund(refund.payingTills.skip);if(!current(e,a))return;}onStock();
    }catch(error){if(current(e,a)){fail(error);if(error.definitive){status(`Operación rechazada: ${error.serverCode}. Corregí los datos.`);try{await refresh();if(current(e,a)&&refund)await readRefund(refund.payingTills.skip);}catch(readError){if(current(e,a))fail(readError);}}}}
    finally{if(current(e,a)){busy=false;lock();}}
  }
  async function begin(kind,body,evidence){if(!usable())return;const a=getSession(),e=epoch;busy=true;lock();
    try{await store.prepare(kind,body,evidence);if(!current(e,a))return;busy=false;await resolve('send');}
    catch(error){if(current(e,a)){busy=false;if(!store.pending&&!['invalid','response'].includes(error?.code))blocked=true;fail(error);lock();}}
  }
  function clear(){epoch++;refundRead++;store.clear();context=null;refund=null;places=[];busy=false;blocked=false;
    for(const name of ['cash-open','cash-close','cash-refund-load','cash-refund'])$(name).reset();
    for(const name of ['cash-context','cash-location','cash-paying-till','cash-refund-lines','cash-refund-summary','cash-page','cash-currency','cash-receipt','cash-reference'])$(name).replaceChildren();
    $('sale-received-label').textContent='Efectivo recibido';$('cash-receipt').hidden=true;panel.hidden=true;status('');lock();}
  async function start(){clear();panel.hidden=!allowed();if(!allowed())return;const a=getSession(),e=epoch;busy=true;lock();
    try{store.load();let skip=0;do{const page=await client.listLocations({skip,take:100});if(!current(e,a))return;places.push(...page.items.filter(x=>x.active&&x.branchId));skip+=page.items.length;if(skip>=page.total)break;if(!page.items.length)throw new StaffRequestError('response');}while(true);
      $('cash-location').replaceChildren(...places.map(x=>{const option=el('option',x.name);option.value=x.id;return option;}));
      await refresh();if(!current(e,a))return;status(store.pending?'Operación pendiente. Comprobando la referencia original…':'Caja actualizada.');
    }catch(error){if(current(e,a)){blocked=!context;fail(error);}}
    finally{if(current(e,a)){busy=false;lock();}}
    if(current(e,a)&&store.compatible()&&!blocked)await resolve('recover');
  }
  const action=fn=>async event=>{event.preventDefault();if(!usable())return;const a=getSession(),e=epoch;try{await fn();}catch(error){if(current(e,a)){fail(error);lock();}}};
  listen($('cash-open'),'submit',action(()=>{const config=context?.configuration;if(!config||!$('cash-open').reportValidity())return;
    return begin('open',{locationId:$('cash-location').value,currency:config.currency,openingMinor:parseMinor($('cash-opening').value,config.exponent)},config);}));
  listen($('cash-close'),'submit',action(()=>{const x=context?.ownTill;if(!x||!$('cash-close').reportValidity())return;
    return begin('close',{countedMinor:parseMinor($('cash-counted').value,x.till.exponent)},{till:x.till});}));
  listen($('cash-refund-load'),'submit',action(async()=>{if(!manage()||!$('cash-refund-load').reportValidity())return;const a=getSession(),e=epoch;busy=true;refund=null;showRefund();lock();
    try{await readRefund();}finally{if(current(e,a)){busy=false;lock();}}}));
  listen($('cash-refund'),'submit',action(()=>{if(!manage()||!context?.configuration||!refund||!$('cash-refund').reportValidity())return;
    const selected=refund.payingTills.items.find(x=>same(x.till.id,$('cash-paying-till').value));if(!selected)throw new StaffRequestError('invalid');
    const lines=[...$('cash-refund-lines').querySelectorAll('input')].filter(x=>x.value!=='0').map(x=>({saleLineId:x.dataset.refundLine,quantity:Number(x.value)}));
    return begin('refund',{payingTillId:selected.till.id,currency:selected.till.currency,reason:$('cash-reason').value,lines},{till:selected.till,sale:refund.sale,refundableMinor:refund.refundableMinor});}));
  for(const [name,delta] of [['cash-prev',-50],['cash-next',50]])listen($(name),'click',action(async()=>{if(!refund)return;const a=getSession(),e=epoch;busy=true;lock();try{await readRefund(refund.payingTills.skip+delta);}finally{if(current(e,a)){busy=false;lock();}}}));
  listen($('cash-refresh'),'click',async()=>{if(busy||blocked)return;const a=getSession(),e=epoch;busy=true;lock();try{await refresh();}catch(error){if(current(e,a))fail(error);}finally{if(current(e,a)){busy=false;lock();}}});
  listen($('cash-recover'),'click',()=>void resolve('recover'));listen($('cash-continue'),'click',()=>void resolve('send'));
  return {start,clear,canSell:()=>usable()&&!!context?.configuration&&!!context?.ownTill,till:()=>context?.ownTill?.till,
    async sell(lines,received){if(!usable()||!context?.configuration||!context?.ownTill)return;const till=context.ownTill.till;
      let minor;try{minor=parseMinor(received,till.exponent);validateSaleRequest({locationId:till.locationId,customerId:null,lines});}catch(error){fail(error);return;}
      await begin('sale',{tillId:till.id,customerId:null,lines,currency:till.currency,receivedMinor:minor},{till});},
    destroy(){clear();removers.forEach(fn=>fn());}};
}
