import { seed, users, id, day, sum } from './seed.mjs';
import { report, tillSummary, csv } from './reports.mjs';
import { readImport } from './import-file.mjs';
export { DEMO_USERS } from './seed.mjs';
const KEY = 'savia.demo.v1';
const fail = (status,code,message) => { throw { status, body:{code,message,traceId:'demo-local'} }; };
const required = (ok,code='input.invalid',message='Datos invalidos.',status=422) => { if(!ok) fail(status,code,message); };
const roles = (u, allowed) => required(allowed.includes(u.role),'auth.role_required','Su rol no permite esta operaci?n.',403);
const managers=['OWNER','MANAGER'], stockRoles=[...managers,'INVENTORY'], salesRoles=[...managers,'SELLER'];
const found = (rows,key,value) => rows.find(r=>r[key]===value) ?? fail(404,'resource.not_found','El registro no existe.');
export function createFakeApi({storage=globalThis.localStorage??null,now=()=>new Date()}={}) {
  let s;
  try { s=JSON.parse(storage?.getItem(KEY)??'null'); } catch { s=null; }
  if(s?.version!==1) s=seed(now);
  const persist=()=>{try{storage?.setItem(KEY,JSON.stringify(s));}catch{/* Private browsing/quota: memory remains usable. */}};
  const next=()=>id(++s.serial), stamp=()=>now().toISOString();
  function reset(){s=seed(now);persist();}
  function progress(r){return {scanSessionId:r.scanSessionId,containerId:r.containerId,reference:r.reference,status:r.status,scanEvents:r.scans.length,matchedUnits:sum(r.scans.filter(x=>x.matchStatus==='matched'),'quantity'),unitsPendingReview:sum(r.scans.filter(x=>!['matched','rejected'].includes(x.matchStatus)),'quantity')};}
  function receptionLines(r){
    const rows=[];
    for(const scan of r.scans){
      const line=scan.matchStatus==='matched'?rows.find(l=>l.itemId===scan.itemId&&l.rawCode===scan.rawCode&&l.matchStatus==='matched'):null;
      if(line){line.quantity+=scan.quantity;line.scans++;}
      else rows.push({...scan,scanId:scan.matchStatus==='matched'?null:scan.scanId,scans:1});
    }
    return rows;
  }
  function variant(i,u){return {itemId:i.itemId,sku:i.sku,productName:i.productName,variantName:i.variantName,sizeCode:i.sizeCode,colorCode:i.colorCode,barcode:i.barcode,unitPriceMinor:u.role==='INVENTORY'?null:i.unitPriceMinor,currencyCode:i.currencyCode,status:i.status,onHand:i.onHand,available:i.onHand};}
  function audit(u,action,amountMinor,reason){s.approvals.unshift({id:next(),action,actorName:u.displayName,amountMinor,reason,createdAt:stamp()});}
  function sale(b,u){
    const existing=s.sales.find(x=>x.saleId===b.saleId); if(existing)return existing;
    required(b.saleId&&b.lines?.length,'sale.lines','Venta sin articulos.');
    const t=found(s.tills,'tillId',b.tillId);required(t.status==='open','sale.till_closed','Turno padre no abierto.',409);
    required(b.currencyCode==='NIO','sale.currency','Moneda invalida.');
    required(!b.customerId||b.tenders?.some(t=>t.tenderKind==='credit'),'sale.customer','Una venta normal no lleva datos de cliente.');
    const lines=b.lines.map(l=>{
      const i=found(s.items,'itemId',l.itemId), seller=users.find(x=>x.staffId===l.sellerId&&x.role==='SELLER');
      required(seller,'sale.seller_required','Indique la vendedora de cada linea.');
      const discountMinor=l.discountMinor??0;
      required(Number.isSafeInteger(l.quantity)&&l.quantity>0&&Number.isSafeInteger(l.unitPriceMinor)&&l.unitPriceMinor===i.unitPriceMinor&&Number.isSafeInteger(discountMinor)&&discountMinor>=0&&discountMinor<=l.quantity*l.unitPriceMinor,'sale.line','Producto, moneda o precio desactualizado.');
      if(discountMinor) required(b.discountReason?.trim(),'sale.discount_reason','Indique el motivo del descuento.');
      required(i.onHand>=l.quantity||b.stockExceptionNote?.trim(),'stock.note_required','Confirme que la prenda esta en la tienda e indique una nota.',409);
      return {...l,discountMinor,saleLineId:next(),sku:i.sku,name:i.productName,sizeCode:i.sizeCode,returnedQuantity:0,taxMinor:0,totalMinor:l.quantity*l.unitPriceMinor-discountMinor,sellerName:seller.displayName,costMinor:i.unitCostMinor*l.quantity,commissionMinor:Math.floor((l.quantity*l.unitPriceMinor-discountMinor)*s.rates[l.sellerId]/10000)};
    });
    const totalMinor=sum(lines,'totalMinor');
    required(new Set(lines.map(l=>l.sellerId)).size<=3,'sale.too_many_sellers','Una venta admite hasta tres vendedoras.');
    required(Array.isArray(b.tenders)&&sum(b.tenders,'amountMinor')===totalMinor,'sale.tenders','Pagos no coinciden con total.');
    for(const t of b.tenders){required(Number.isSafeInteger(t.amountMinor)&&t.amountMinor>=0&&['cash','card','transfer','credit','other'].includes(t.tenderKind),'sale.tenders','Formas de pago invalidas.');if(t.tenderKind==='transfer')required(t.reference?.trim(),'sale.reference','Indique la referencia de la transferencia.');if(t.tenderKind==='cash'&&!t.foreignCurrencyCode)required(t.receivedMinor-t.changeMinor===t.amountMinor,'sale.cash','Efectivo invalido.');}
    const result={saleId:b.saleId,subtotalMinor:sum(lines,l=>l.quantity*l.unitPriceMinor),discountMinor:sum(lines,'discountMinor'),taxMinor:0,totalMinor,status:'posted',currencyCode:'NIO',createdAt:stamp(),customerId:b.customerId??null,customerName:null,cashierId:u.staffId,cashierName:u.displayName,tillId:b.tillId,registerName:t.registerName,lines,tenders:b.tenders.map(t=>({tenderId:next(),receivedMinor:null,changeMinor:null,reference:null,creditId:null,foreignCurrencyCode:null,foreignReceivedMinor:null,exchangeRateId:null,exchangeRate:null,roundingMinor:null,foreignChangeMinor:null,foreignChangeNioMinor:null,...t,status:'posted'})),reversals:[],receiptNumber:`CENTRO-${s.sales.length+1}`,discountApprovedBy:sum(lines,'discountMinor')?u.staffId:null,discountReason:b.discountReason??null};
    for(const l of lines){const i=found(s.items,'itemId',l.itemId);if(i.onHand<l.quantity)s.exceptions.push({exceptionId:next(),saleId:b.saleId,itemId:i.itemId,sku:i.sku,name:i.productName,quantity:l.quantity,reason:b.stockExceptionNote,status:'pending',createdAt:stamp()});i.onHand-=l.quantity;}
    s.sales.push(result);if(result.discountMinor)audit(u,'discount',result.discountMinor,b.discountReason);return result;
  }
  function returnSale(saleId,b,u,kind){
    const old=s.returns.find(r=>r.reversalId===b.reversalId);if(old)return old;
    const original=found(s.sales,'saleId',saleId), till=found(s.tills,'tillId',b.tillId);
    required(till.status==='open','return.till_closed','Turno de devolucion no abierto.',409);
    required(new Date(stamp())-new Date(original.createdAt)<=s.policy.windowDays*86400000,'return.window_expired','La venta supera el plazo de devolucion.',409);
    required(b.reversalId&&b.reason?.trim()&&b.lines?.length&&new Set(b.lines.map(l=>l.saleLineId)).size===b.lines.length,'return.lines','Devolucion sin prendas o motivo.');
    required(['credit','cash','transfer','exchange'].includes(kind),'return.outcome','Elija cambio, efectivo o transferencia.');
    if(kind==='credit'){required(b.customerId&&b.creditId,'return.customer','Indique cliente y credito.');found(s.customers,'customerId',b.customerId);}
    if(kind==='transfer')required(b.reference?.trim(),'return.transfer_reference','Indique la referencia de la transferencia.');
    const lines=b.lines.map(l=>{const o=found(original.lines,'saleLineId',l.saleLineId);required(Number.isInteger(l.quantity)&&l.quantity>0&&l.quantity<=o.quantity-o.returnedQuantity&&['store','quarantine'].includes(l.restockPool),'return.quantity','Intento de devolver unidades ya devueltas.',409);return {...l,creditMinor:Math.floor(o.totalMinor*(o.returnedQuantity+l.quantity)/o.quantity)-Math.floor(o.totalMinor*o.returnedQuantity/o.quantity),commissionReversedMinor:Math.floor(o.commissionMinor*(o.returnedQuantity+l.quantity)/o.quantity)-Math.floor(o.commissionMinor*o.returnedQuantity/o.quantity)};});
    const creditMinor=sum(lines,'creditMinor');
    if(kind==='cash')required(tillSummary(s,till).expectedCashMinor>=creditMinor,'return.till_cash_short','La caja no tiene efectivo suficiente para el reembolso.',409);
    if(kind==='exchange'){
      required(b.exchangeSaleId&&b.newLines?.length,'return.exchange_lines','Indique las prendas del cambio.');
      const total=sum(b.newLines,l=>l.quantity*l.unitPriceMinor-(l.discountMinor??0)), difference=Math.max(0,total-creditMinor);
      required(sum(b.newTenders??[],'amountMinor')===difference,'sale.tenders','Pagos de la diferencia no coinciden.');
      if(total<creditMinor)required(['cash','transfer'].includes(b.differenceKind),'return.difference','Indique como se devuelve la diferencia.');
      sale({saleId:b.exchangeSaleId,tillId:b.tillId,currencyCode:'NIO',lines:b.newLines,tenders:[...(b.newTenders??[]),{tenderNumber:99,tenderKind:'other',amountMinor:Math.min(total,creditMinor),reference:'Cambio'}]},u);
    }
    const r={reversalId:b.reversalId,saleId,kind:'return',settlementKind:kind,reason:b.reason,creditMinor,currencyCode:'NIO',status:'approved',createdAt:stamp(),approvedBy:u.staffId,actorId:u.staffId,tillId:b.tillId,creditId:b.creditId??null,lines};
    for(const l of lines){const o=found(original.lines,'saleLineId',l.saleLineId);o.returnedQuantity+=l.quantity;if(l.restockPool==='store')found(s.items,'itemId',o.itemId).onHand+=l.quantity;}
    original.reversals.push(r);s.returns.push(r);
    if(kind==='credit'){required(b.customerId&&b.creditId,'return.customer','Indique cliente y credito.');const c=found(s.customers,'customerId',b.customerId);s.credits.push({...c,creditId:b.creditId,currencyCode:'NIO',branchId:id(11),branchName:'Centro',availableMinor:creditMinor});}
    audit(u,'return',creditMinor,b.reason);return r;
  }
  async function route(method,p,q,b,u){
    if(p==='/me')return {staffId:u.staffId,displayName:u.displayName,roles:[u.role],nodeKind:'Branch',nodeId:id(12),branchId:id(11),locationId:id(13),branchName:'Centro',storeDisplayName:'Boutique Aurora',locationName:'Centro'};
    if(p==='/auth/logout'){delete s.tokens[u.token];return null;}
    if(p==='/catalog/items'&&method==='GET')return s.products.map(p=>({...p,variants:s.items.filter(i=>i.productId===p.productId).map(i=>variant(i,u))}));
    if(p==='/catalog/search'||p==='/catalog/lookup'){
      const text=(q.get(p.endsWith('lookup')?'code':'q')??'').toLowerCase();
      const rows=s.items.filter(i=>p.endsWith('lookup')?[i.barcode,i.sku].includes(text.toUpperCase())||i.barcode===text:[i.sku,i.productName,i.variantName].some(v=>v.toLowerCase().includes(text)));
      return rows.slice(0,100).map(i=>variant(i,u));
    }
    if(p==='/catalog/products'&&method==='POST'){roles(u,managers);required(b.productId&&b.name,'catalog.product','Indique el producto.');s.products.push({productId:b.productId,name:b.name,type:null});return null;}
    if(p==='/catalog/items'&&method==='POST'){roles(u,['OWNER']);const product=found(s.products,'productId',b.productId);required(b.itemId&&b.sku&&Number.isSafeInteger(b.unitPriceMinor),'catalog.item','Datos de prenda invalidos.');s.items.push({...b,productName:product.name,sizeCode:null,colorCode:null,barcode:b.barcode??null,status:'active',onHand:0,unitCostMinor:b.unitCostMinor??0,history:[]});return null;}
    if(p==='/catalog/values'){roles(u,managers);return s.items.filter(i=>(i.sku+' '+i.productName).toLowerCase().includes((q.get('q')??'').toLowerCase())).map(i=>({itemId:i.itemId,sku:i.sku,name:i.productName,priceMinor:i.unitPriceMinor,costMinor:i.unitCostMinor,history:i.history}));}
    let m;
    if((m=p.match(/^\/catalog\/items\/([^/]+)\/values$/))){roles(u,['OWNER']);required(b.reason?.trim()&&[b.priceMinor,b.costMinor].every(x=>Number.isSafeInteger(x)&&x>=0),'catalog.values','Precio, costo o motivo invalido.');const i=found(s.items,'itemId',m[1]);i.history.unshift({oldPriceMinor:i.unitPriceMinor,newPriceMinor:b.priceMinor,oldCostMinor:i.unitCostMinor,newCostMinor:b.costMinor,actorName:u.displayName,reason:b.reason,createdAt:stamp()});i.unitPriceMinor=b.priceMinor;i.unitCostMinor=b.costMinor;audit(u,'price',b.priceMinor,b.reason);return null;}
    if(p==='/suppliers'){roles(u,stockRoles);return s.suppliers;}
    if(p==='/inventory/tag-extract'){
      roles(u,stockRoles);await new Promise(resolve=>setTimeout(resolve,800));const barcode=b?.get?.('barcode')??null,i=s.items.find(i=>i.barcode===barcode);
      return {barcode:barcode??'2900000000009',sku:i?.sku??'AUR-SUGERIDO',name:i?.productName??'Vestido satén',brand:'Aurora',size:i?.sizeCode??'M',color:i?.colorCode??'Coral',priceMinor:u.role==='INVENTORY'?null:i?.unitPriceMinor??180000,composition:'Poliéster',confidence:{name:.9,size:.9,color:.8},rawText:'Etiqueta de muestra · sin OCR real',matchedItem:i?{...variant(i,u),matchedBy:'barcode'}:null,source:i?'match':'ocr',engine:'demo-local',elapsedMs:800,warning:'Sugerencia ficticia de demostración.'};
    }
    if(p==='/stock')return s.items.filter(i=>!q.get('itemId')||i.itemId===q.get('itemId')).map(i=>({itemId:i.itemId,sku:i.sku,variantName:i.variantName,locationId:id(13),pool:'store',onHand:i.onHand,reserved:0,available:i.onHand}));
    if(p==='/labels/jobs')return s.labels.filter(l=>!q.get('status')||l.status===q.get('status'));
    if((m=p.match(/^\/labels\/jobs\/([^/]+)\/attempts$/))){const l=found(s.labels,'id',m[1]);l.status=b.successful?'printed':'failed';if(b.successful)l.copiesAcknowledged=l.copiesRequested;return null;}
    if(p.startsWith('/stock/exceptions')){roles(u,managers);if(p==='/stock/exceptions')return s.exceptions;const e=found(s.exceptions,'exceptionId',p.split('/')[3]);required(b.reason?.trim());e.status='reviewed';e.reviewReason=b.reason;return null;}
    if(p.startsWith('/receiving/sessions')){
      roles(u,stockRoles);
      if(p==='/receiving/sessions'){
        if(method==='GET')return s.sessions.filter(r=>q.get('open')==='false'||!['posted','cancelled'].includes(r.status)).map(r=>({...progress(r),supplierId:r.supplierId,supplierName:r.supplierName,createdAt:r.createdAt}));
        required(b.scanSessionId&&b.reference&&b.containerId&&b.supplierId);s.sessions.push({...b,status:'open',supplierName:found(s.suppliers,'supplierId',b.supplierId).name,createdAt:stamp(),actorId:u.staffId,closedAt:null,scans:[],quality:[]});return null;
      }
      const parts=p.split('/'), r=found(s.sessions,'scanSessionId',parts[3]), action=parts[4];
      if(!action)return progress(r);
      if(action==='lines')return receptionLines(r).map(x=>{const i=s.items.find(i=>i.itemId===x.itemId);return {...x,scans:x.scans??1,sku:i?.sku??null,variantName:i?.variantName??null};});
      if(action==='scans'){
        required(r.status==='open','receiving.closed','La sesion no esta abierta.',409);
        if(parts[6]){roles(u,managers);const scan=found(r.scans,'scanId',parts[5]);required(b.reason?.trim());scan.matchStatus=parts[6]==='reject'?'rejected':'matched';if(parts[6]==='resolve')scan.itemId=found(s.items,'itemId',b.itemId).itemId;return null;}
        const old=r.scans.find(x=>x.scanId===b.scanId);if(old)return old;required(b.scanId&&b.rawCode&&Number.isInteger(b.quantity??1)&&(b.quantity??1)>0);const item=s.items.find(i=>i.barcode===b.rawCode||i.sku===b.rawCode);const scan={scanId:b.scanId,itemId:item?.itemId??null,matchStatus:item?'matched':'unmatched',quantity:b.quantity??1,rawCode:b.rawCode};r.scans.push(scan);return scan;
      }
      if(action==='quality'){if(method==='GET')return r.quality;required(b.reason&&b.checkId);required(['buena','danada','manchada','malOlor','faltante'].every(k=>Number.isInteger(b[k])&&b[k]>=0)&&['buena','danada','manchada','malOlor','faltante'].reduce((n,k)=>n+b[k],0)===sum(r.scans.filter(l=>l.itemId===b.itemId&&l.matchStatus==='matched'),'quantity'),'quality.quantity','Las condiciones deben sumar las unidades esperadas.');r.quality=r.quality.filter(x=>x.itemId!==b.itemId);r.quality.push({...b,createdAt:stamp(),actorId:u.staffId});return null;}
      roles(u,managers);
      if(action==='approve'){required(!progress(r).unitsPendingReview,'receiving.pending','Hay lecturas pendientes.',409);r.status='approved';return null;}
      if(action==='post'){if(r.receiptId)return {receiptId:r.receiptId};required(r.status==='approved','receiving.not_approved','Apruebe el conteo.',409);for(const l of receptionLines(r).filter(l=>l.matchStatus==='matched')){const i=found(s.items,'itemId',l.itemId);const quality=r.quality.find(q=>q.itemId===i.itemId);const received=quality?quality.buena:l.quantity;i.onHand+=received;s.labels.push({id:next(),itemId:i.itemId,storeName:'Boutique Aurora',sku:i.sku,barcode:i.barcode,copiesRequested:l.quantity,copiesAcknowledged:0,status:'pending'});}r.status='posted';r.closedAt=stamp();r.receiptId=next();return {receiptId:r.receiptId};}
    }
    if(p==='/sellers'){roles(u,salesRoles);return users.filter(x=>x.role==='SELLER').map(x=>({sellerId:x.staffId,name:x.displayName,rateBps:s.rates[x.staffId]}));}
    if((m=p.match(/^\/sellers\/([^/]+)\/rate$/))){roles(u,['OWNER']);required(b.reason&&Number.isInteger(b.rateBps)&&b.rateBps>=0&&b.rateBps<=10000);required(s.rates[m[1]]!==undefined);s.rates[m[1]]=b.rateBps;return null;}
    if(p==='/exchange-rate')return s.exchange;
    if(p==='/exchange-rates'){roles(u,managers);required(b.rate>0&&b.id&&b.effectiveFrom&&b.reason);s.exchange={id:b.id,currencyCode:'USD',rate:b.rate,effectiveFrom:b.effectiveFrom};return null;}
    if(p.startsWith('/cash/')){
      roles(u,managers);
      if(p==='/cash/denominations')return [100,500,1000,2000,5000,10000,20000,50000,100000];
      if(p==='/cash/registers'){const t=s.tills.find(t=>t.status==='open');return [{registerId:id(10),code:'CENTRO',name:'Caja Centro',locationId:id(13),openTillId:t?.tillId??null,openTillCashierId:t?.cashierId??null}];}
      if(p==='/cash/tills/current'){const t=s.tills.find(t=>t.status==='open'&&t.cashierId===u.staffId);if(!t)fail(404,'cash.no_open_till','No tiene un turno de caja abierto.');return tillSummary(s,t);}
      if(p==='/cash/tills'){required(b.tillId&&b.registerId===id(10)&&Number.isSafeInteger(b.openingMinor)&&b.openingMinor>=0);required(!s.tills.some(t=>t.status==='open'&&t.registerId===b.registerId),'cash.already_open','La caja tiene un turno abierto.',409);s.tills.push({...b,registerName:'Caja Centro',cashierId:u.staffId,cashierName:u.displayName,status:'open',openedAt:stamp(),closedAt:null,openingLines:b.lines??[],closureId:null,usdOpeningMinor:sum(b.usdLines??[],l=>l.denominationMinor*l.quantity)});return null;}
      const t=found(s.tills,'tillId',p.split('/')[3]);if(p.endsWith('/summary'))return tillSummary(s,t);
      if(p.endsWith('/counts')){required(b.cashCountId&&b.lines?.length,'cash.count_empty','El arqueo necesita denominaciones.');s.counts[b.cashCountId]={...b,tillId:t.tillId};return null;}
      if(p.endsWith('/close')){const c=found(Object.values(s.counts),'cashCountId',b.cashCountId);required(c.tillId===t.tillId);const expectedMinor=tillSummary(s,t).expectedCashMinor,countedMinor=sum(c.lines,l=>l.denominationMinor*l.quantity);Object.assign(t,{status:'closed',closureId:b.closureId,closedAt:stamp(),countedMinor,differenceMinor:countedMinor-expectedMinor});return {closureId:b.closureId,expectedMinor,countedMinor,differenceMinor:t.differenceMinor,usdExpectedMinor:tillSummary(s,t).usdExpectedMinor,usdCountedMinor:sum(c.usdLines??[],l=>l.denominationMinor*l.quantity),usdDifferenceMinor:sum(c.usdLines??[],l=>l.denominationMinor*l.quantity)-tillSummary(s,t).usdExpectedMinor};}
    }
    if(p.startsWith('/sales')){
      roles(u,managers);
      if(p==='/sales'){if(method==='POST')return sale(b,u);let rows=s.sales.filter(x=>(!q.get('from')||day(x.createdAt)>=q.get('from'))&&(!q.get('to')||day(x.createdAt)<=q.get('to'))&&(!q.get('q')||JSON.stringify(x).toLowerCase().includes(q.get('q').toLowerCase()))).toReversed();const page=Math.max(1,Number(q.get('page')||1)),pageSize=Math.min(100,Number(q.get('pageSize')||25));return {page,pageSize,total:rows.length,items:rows.slice((page-1)*pageSize,page*pageSize)};}
      const parts=p.split('/');if(parts[3]==='returns')return returnSale(parts[2],b,u,parts[4]==='credit'?'credit':b.outcome);return found(s.sales,'saleId',parts[2]);
    }
    if(p==='/customers'||p==='/credits/search'){roles(u,managers);return (p==='/customers'?s.customers:s.credits).filter(c=>(c.displayName+' '+(c.phone??'')).toLowerCase().includes((q.get('q')??'').toLowerCase()));}
    if(p==='/returns/policy'){roles(u,salesRoles);if(method==='GET')return s.policy;roles(u,['OWNER']);required(b.reason&&Number.isInteger(b.windowDays)&&b.windowDays>=1&&b.windowDays<=365);s.policy.history.unshift({oldWindowDays:s.policy.windowDays,newWindowDays:b.windowDays,actorName:u.displayName,reason:b.reason,createdAt:stamp()});s.policy.windowDays=b.windowDays;return null;}
    if(p==='/approvals'){roles(u,['OWNER']);return s.approvals;}
    if(p==='/reports/receiving-quality'){
      roles(u,stockRoles);
      return s.suppliers.map(supplier=>{
        const quality=s.sessions.filter(r=>r.supplierId===supplier.supplierId&&(!q.get('from')||day(r.createdAt)>=q.get('from'))&&(!q.get('to')||day(r.createdAt)<=q.get('to'))).flatMap(r=>r.quality);
        return {...supplier,...Object.fromEntries(['buena','danada','manchada','malOlor','faltante'].map(k=>[k,sum(quality,k)]))};
      });
    }
    if(p.startsWith('/reports/')){const kind=p.replace('.csv','').split('/').at(-1);roles(u,['team','commissions'].includes(kind)?salesRoles:managers);const period=q.get('period')??'day',date=q.get('date')??day(now());required(['day','week','month','year'].includes(period)&&/^\d{4}-\d{2}-\d{2}$/.test(date),'report.range','Periodo o fecha invalida.');const value=report(s,kind,kind==='day'?'day':period,date,u);return p.endsWith('.csv')?{csv:csv(value)}:value;}
    if(p.startsWith('/catalog/import')){
      roles(u,['OWNER']);
      if(p.endsWith('/file'))return readImport(b);
      required(b.rows?.length&&b.rows.length<=5000,'import.size','El archivo debe tener entre 1 y 5000 filas.');
      const sample=b.rows.map(r=>({...r,costMinor:Math.round(Number(r.cost)*100),priceMinor:Math.round(Number(r.price)*100),stock:Number(r.stock??0)}));
      const errors=sample.filter(r=>!r.name||!r.sku||!Number.isSafeInteger(r.priceMinor)||r.priceMinor<0||!Number.isSafeInteger(r.costMinor)||r.costMinor<0||!Number.isInteger(r.stock)||r.stock<0||s.items.some(i=>i.sku===r.sku||r.code&&i.barcode===r.code)||sample.filter(x=>x.sku===r.sku).length>1).map(r=>({row:r.row,code:r.code,message:'Nombre, SKU, precio, costo o existencia invalido o duplicado.'}));
      if(p.endsWith('/preview'))return {rowsCount:sample.length,validCount:sample.length-errors.length,errorCount:errors.length,unitsCount:sum(sample,'stock'),errors,sample:sample.slice(0,20)};
      required(!errors.length,'import.row_errors','Corrija las filas antes de importar.',409);
      for(const r of sample){const productId=next(),itemId=next();s.products.push({productId,name:r.name,type:r.type??null});s.items.push({itemId,productId,sku:r.sku,productName:r.name,variantName:r.name,sizeCode:r.size??null,colorCode:r.color??null,barcode:r.code??null,unitPriceMinor:r.priceMinor,unitCostMinor:r.costMinor,currencyCode:'NIO',status:'active',onHand:r.stock,history:[]});}
      return {batchId:b.batchId,fileName:b.fileName,rowsCount:sample.length,itemsCreated:sample.length,unitsAdded:sum(sample,'stock'),createdAt:stamp()};
    }
    fail(404,'route.not_found','Ruta de demo no encontrada.');
  }
  async function handle(req){
    const snapshot=JSON.stringify(s);
    try{
      const url=new URL(req.path,'http://demo.invalid'), p=decodeURIComponent(url.pathname), method=(req.method??'GET').toUpperCase();
      let b=req.body??{};if(typeof b==='string'){try{b=JSON.parse(b);}catch{fail(422,'input.json','JSON invalido.');}}
      if(p==='/auth/login'&&method==='POST'){const u=users.find(u=>u.loginName===b.loginName);required(u&&b.password==='demo','auth.bad_credentials','Usuario o contrase?a incorrectos.',401);const token=`demo-${u.staffId}-${++s.serial}`;s.tokens[token]=u.staffId;persist();return {status:200,body:{token,expiresAt:new Date(now().getTime()+86400000).toISOString(),staffId:u.staffId,displayName:u.displayName,roles:[u.role]}};}
      const h=req.headers??{}, token=(h.authorization??h.Authorization??'').replace(/^Bearer /i,''), staffId=s.tokens[token], user=users.find(u=>u.staffId===staffId);
      required(user,'auth.required','Inicie sesi?n.',401);
      const replayKey=method==='POST'?[b.saleId,b.reversalId,b.changeId,b.batchId,b.scanId,b.checkId,b.cashCountId,b.closureId,b.attemptId,b.scanSessionId,b.itemId,b.productId,b.tillId].find(Boolean):null;
      const key=replayKey?`${user.staffId}:${method}:${p}:${replayKey}`:null, fingerprint=typeof req.body==='string'?req.body:JSON.stringify(b);
      if(key&&s.replay[key]){required(s.replay[key].fingerprint===fingerprint,'idempotency.conflict','Identificador reutilizado con datos distintos.',409);return structuredClone(s.replay[key].response);}
      const result=await route(method,p,url.searchParams,b,{...user,token});
      const response=result?.csv?{status:200,headers:{'content-type':'text/csv; charset=utf-8'},body:result.csv}:{status:result===null?204:200,headers:{'content-type':'application/json'},body:result};
      if(key)s.replay[key]={fingerprint,response};persist();return structuredClone(response);
    }catch(e){s=JSON.parse(snapshot);if(e.status)return e;return {status:422,body:{code:'input.invalid',message:'Datos invalidos.',traceId:'demo-local'}};}
  }
  return {handle,reset};
}