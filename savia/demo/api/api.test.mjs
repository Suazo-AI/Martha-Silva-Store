import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createFakeApi,DEMO_USERS} from './index.mjs';
import {id} from './seed.mjs';
import {readImport} from './import-file.mjs';
import {deflateRawSync} from 'node:zlib';
const now=()=>new Date('2026-11-15T18:00:00Z');
const date='2026-11-15';
const contracts=readdirSync(new URL('../../src/Savia.Contracts/',import.meta.url)).filter(f=>f.endsWith('.cs')).map(f=>readFileSync(new URL('../../src/Savia.Contracts/'+f,import.meta.url),'utf8')).join('\n');
function shape(value,record){
  const definition=contracts.match(new RegExp('record '+record+'\\(([\\s\\S]*?)\\);'))?.[1];assert.ok(definition,record);
  const fields=[...definition.matchAll(/(?:^|,\s*)(?:[\w<>?\[\]]+\s+)(\w+)(?:\s*=\s*[^,]+)?(?=,|$)/g)].map(m=>m[1][0].toLowerCase()+m[1].slice(1));
  for(const field of fields)assert.ok(field in value,`${record}.${field}`);
}
async function session(role='OWNER',storage=null){const api=createFakeApi({storage,now});const user=DEMO_USERS.find(u=>u.role===role);const login=await api.handle({method:'POST',path:'/auth/login',body:JSON.stringify({loginName:user.loginName,password:'demo'})});assert.equal(login.status,200);const headers={authorization:'Bearer '+login.body.token};return {api,headers,call:async(method,path,body)=>api.handle({method,path,headers,body:body instanceof FormData?body:body===undefined?null:JSON.stringify(body)})};}
const saleBody=(saleId,tillId,item,sellerId=id(3))=>({saleId,tillId,currencyCode:'NIO',lines:[{lineNumber:1,itemId:item.itemId,quantity:2,unitPriceMinor:item.unitPriceMinor,sellerId}],tenders:[{tenderNumber:1,tenderKind:'card',amountMinor:item.unitPriceMinor*2}]});
const exportedRoutes = new Map();
test('every web endpoint: real wrappers and Contracts fields',async t=>{
  const {api,call}=await session();const web=await import('../../web/api.mjs');
  const realFetch=globalThis.fetch,realDocument=globalThis.document,realTimeout=globalThis.setTimeout;
  let last;
  globalThis.fetch=async(url,opts={})=>{const result=await api.handle({method:opts.method,path:url.slice('/api/v1'.length),headers:Object.fromEntries(Object.entries(opts.headers??{}).map(([k,v])=>[k.toLowerCase(),v])),body:opts.body??null});last={...result,path:url.slice(7),method:opts.method};return new Response(result.status===204?null:typeof result.body==='string'?result.body:JSON.stringify(result.body),{status:result.status,headers:result.headers});};
  globalThis.document={createElement:()=>({click(){}})};
  // CSV cleanup timers do not hold the test runner for a second each.
  globalThis.setTimeout=(fn,ms,...args)=>{const timer=realTimeout(fn,ms,...args);timer.unref?.();return timer;};
  const login=await web.login('duena.muestra','demo');web.setToken(login.token);
  const catalog=await web.catalogItems(),item=catalog[0].variants[0], seller=id(3), till=id(9000), scanSession=id(9001), scan=id(9002), unknown=id(9003), saleId=id(9004);
  const checks=[
    ['login',()=>web.login('duena.muestra','demo'),'LoginResponse'],
    ['me',()=>web.me(),'MeResponse'],
    ['catalogItems',()=>web.catalogItems(),'CatalogProduct',true],
    ['lookup',()=>web.lookup(item.barcode),'ItemLookup',true],
    ['searchProducts',()=>web.searchProducts('Vestido'),'ProductSearchRow',true],
    ['registerProduct',()=>web.registerProduct(id(9010),'Prenda nueva')],
    ['registerItem',()=>web.registerItem({itemId:id(9011),productId:id(9010),sku:'NUEVO-M',variantName:'Prenda nueva M',currencyCode:'NIO',unitPriceMinor:10000,unitCostMinor:4000,barcode:'2909999999999'})],
    ['tagExtract',()=>web.tagExtract(new Blob(['demo']),item.barcode),'TagExtractResponse'],
    ['suppliers',()=>web.suppliers(),'SupplierRow',true],
    ['openReception',()=>web.openReception({containerId:id(9012),scanSessionId:scanSession,reference:'Lote prueba',supplierId:id(30)})],
    ['recordScan',()=>web.recordScan(scanSession,{scanId:scan,rawCode:item.barcode,quantity:5}),'ScanResult'],
    ['receptionProgress',()=>web.receptionProgress(scanSession),'ScanSessionProgress'],
    ['receptionLines',()=>web.receptionLines(scanSession),'ScanSessionLine',true],
    ['listReceptions',()=>web.listReceptions(),'ScanSessionSummary',true],
    ['resolveScan',async()=>{await web.recordScan(scanSession,{scanId:unknown,rawCode:'UNKNOWN'});return web.resolveScan(scanSession,unknown,item.itemId,'Corregido');}],
    ['rejectScan',()=>web.rejectScan(scanSession,unknown,'Etiqueta ilegible')],
    ['recordQuality',()=>web.recordQuality(scanSession,{checkId:id(9013),itemId:item.itemId,buena:4,danada:1,manchada:0,malOlor:0,faltante:0,reason:'Inspección'})],
    ['quality',()=>web.quality(scanSession)],
    ['qualityReport',()=>web.qualityReport(date,date)],
    ['approveReception',()=>web.approveReception(scanSession)],
    ['postReception',()=>web.postReception(scanSession),'PostScanSessionResponse'],
    ['stock',()=>web.stock(item.itemId),'StockRow',true],
    ['labelJobs',()=>web.labelJobs(),'LabelJob',true],
    ['registers',()=>web.registers(),'RegisterRow',true],
    ['approvals',()=>web.approvals()],
    ['sellers',()=>web.sellers()],
    ['itemValues',()=>web.itemValues('')],
    ['setItemValues',()=>web.setItemValues(item.itemId,{changeId:id(9020),priceMinor:item.unitPriceMinor,costMinor:85000,reason:'Revisión'})],
    ['commissions',()=>web.commissions('day',date)],
    ['setSellerRate',()=>web.setSellerRate(seller,{changeId:id(9021),rateBps:400,reason:'Nueva comisión'})],
    ['exchangeRate',()=>web.exchangeRate(),'ExchangeRateResponse'],
    ['setExchangeRate',()=>web.setExchangeRate({id:id(9022),rate:36.6243,effectiveFrom:date,reason:'Tasa diaria'})],
    ['denominations',()=>web.denominations()],
    ['openTill',()=>web.openTill({tillId:till,registerId:id(10),openingMinor:200000,lines:[{denominationMinor:10000,quantity:20}]})],
    ['currentTill',()=>web.currentTill(),'TillSummary'],
    ['tillSummary',()=>web.tillSummary(till),'TillSummary'],
    ['postSale',()=>web.postSale(saleBody(saleId,till,item)),'SaleResponse'],
    ['getSale',()=>web.getSale(saleId),'SaleDetailResponse'],
    ['searchSales',()=>web.searchSales({date}),'SalesPage'],
    ['searchCustomers',()=>web.searchCustomers('muestra'),'CustomerRow',true],
    ['postCreditReturn',async()=>{const detail=await web.getSale(saleId);return web.postCreditReturn(saleId,{reversalId:id(9023),creditId:id(9024),tillId:till,customerId:id(40),reason:'Talla',lines:[{saleLineId:detail.lines[0].saleLineId,quantity:1,restockPool:'store'}]});},'SaleReversal'],
    ['searchCredits',()=>web.searchCredits('muestra'),'CustomerCreditRow',true],
    ['postReturnOutcome',async()=>{const detail=await web.getSale(saleId);return web.postReturnOutcome(saleId,{reversalId:id(9025),tillId:till,outcome:'transfer',reference:'DEMO',reason:'Talla',lines:[{saleLineId:detail.lines[0].saleLineId,quantity:1,restockPool:'store'}]});},'SaleReversal'],
    ['dayReport',()=>web.dayReport(date),'DayReport'],
    ['summaryReport',()=>web.summaryReport('day',date)],
    ['stockExceptions',()=>web.stockExceptions()],
    ['reviewStockException',async()=>{await web.postSale({...saleBody(id(9026),till,item),lines:[{...saleBody(id(9026),till,item).lines[0],quantity:1000}],tenders:[{tenderNumber:1,tenderKind:'card',amountMinor:item.unitPriceMinor*1000}],stockExceptionNote:'Prendas verificadas'});const rows=await web.stockExceptions();return web.reviewStockException(rows[0].exceptionId,'Revisado');}],
    ['returnPolicy',()=>web.returnPolicy()],
    ['setReturnWindow',()=>web.setReturnWindow({changeId:id(9027),windowDays:45,reason:'Plazo muestra'})],
    ['kpiBusiness',()=>web.kpiBusiness('day',date)],
    ['kpiTeam',()=>web.kpiTeam('day',date)],
    ['importFile',()=>web.importFile('prueba.csv',btoa('sku,name,price,cost,stock\nIMPORT,Prenda,100,40,3')),'ImportFile'],
    ['previewImport',()=>web.previewImport({batchId:id(9028),fileName:'prueba.csv',rows:[{row:2,sku:'IMPORT',name:'Prenda',price:'100',cost:'40',stock:'3'}]})],
    ['importCatalog',()=>web.importCatalog({batchId:id(9028),fileName:'prueba.csv',rows:[{row:2,sku:'IMPORT',name:'Prenda',price:'100',cost:'40',stock:'3'}]})],
    ['exportSummary',()=>web.exportSummary('day',date)],
    ['exportCommissions',()=>web.exportCommissions('day',date)],
    ['exportKpiBusiness',()=>web.exportKpiBusiness('day',date)],
    ['exportKpiTeam',()=>web.exportKpiTeam('day',date)],
    ['recordCashCount',()=>web.recordCashCount(till,{cashCountId:id(9029),lines:[{denominationMinor:10000,quantity:20}]})],
    ['closeTill',()=>web.closeTill(till,{closureId:id(9030),cashCountId:id(9029)}),'CloseTillResponse'],
    ['endApproval',async()=>{const l=await web.login('gerente.muestra','demo');return web.endApproval(l.token);}],
    ['logout',()=>web.logout()],
  ];
  // Close the seeded manager drawer before the owner starts her own shift.
  await call('POST',`/cash/tills/${id(2000)}/counts`,{cashCountId:id(8998),lines:[{denominationMinor:10000,quantity:20}]});
  await call('POST',`/cash/tills/${id(2000)}/close`,{closureId:id(8999),cashCountId:id(8998)});
  try{for(const [name,run,record,array] of checks)await t.test(name,async()=>{const value=await run();assert.ok(last.status>=200&&last.status<300,`${name}: ${JSON.stringify(last)}`);exportedRoutes.set(name,`${last.method} ${last.path.split('?')[0]}`);if(record){const rows=array?value:[value];assert.ok(rows.length,`${name}: nonempty fixture`);rows.forEach(v=>shape(v,record));}if(name==='catalogItems')value.flatMap(p=>p.variants).forEach(v=>shape(v,'ProductSearchRow'));if(name==='getSale'){value.lines.forEach(v=>shape(v,'SaleDetailLine'));value.tenders.forEach(v=>shape(v,'SaleDetailTender'));}if(name==='postReturnOutcome'||name==='postCreditReturn')value.lines.forEach(v=>shape(v,'ReversalLine'));if(name==='dayReport'){value.tills.forEach(v=>shape(v,'DayTill'));value.totals.forEach(v=>shape(v,'DayTotal'));value.tenders.forEach(v=>shape(v,'DayTenderTotal'));value.returns.forEach(v=>shape(v,'DayReturn'));value.refundsByKind.forEach(v=>shape(v,'DayRefundKind'));value.topItems.forEach(v=>shape(v,'DayTopItem'));}if(name.startsWith('export'))assert.match(last.body,/\r\n/);});
    const names=[...readFileSync(new URL('../../web/api.mjs',import.meta.url),'utf8').matchAll(/export (?:const|function|async function) (\w+)/g)].map(m=>m[1]);
    const helpers=['ApiError','uuid','retryIds','getToken','setToken','setUnauthorizedHandler','toError','request','saleTenderKinds'];
    assert.deepEqual(names.filter(n=>!helpers.includes(n)&&!exportedRoutes.has(n)),[],'zero uncovered HTTP wrappers');
  }finally{globalThis.fetch=realFetch;globalThis.document=realDocument;globalThis.setTimeout=realTimeout;}
});
test('new sale, return, reconciliation, permissions, reset, deterministic reports',async()=>{
  const {api,call}=await session('MANAGER');const item=(await call('GET','/catalog/items')).body[0].variants[0];const endpoint=`/reports/kpi/business?period=day&date=${date}`;
  const before=(await call('GET',endpoint)).body, b=saleBody(id(9900),id(2000),item);const result=await call('POST','/sales',b);assert.equal(result.status,200);
  assert.equal((await call('GET',`/reports/day?date=${date}`)).body.salesCount,before.salesCount+1);
  const after=(await call('GET',endpoint)).body;assert.equal(after.netSalesMinor,before.netSalesMinor+result.body.totalMinor);
  const detail=(await call('GET',`/sales/${b.saleId}`)).body;
  const ret=await call('POST',`/sales/${b.saleId}/returns/outcome`,{reversalId:id(9901),tillId:id(2000),outcome:'transfer',reference:'demo',reason:'Talla',lines:[{saleLineId:detail.lines[0].saleLineId,quantity:1,restockPool:'store'}]});assert.equal(ret.status,200);
  const net=(await call('GET',endpoint)).body.netSalesMinor;assert.equal(net,after.netSalesMinor-item.unitPriceMinor);
  const team=(await call('GET',`/reports/kpi/team?date=${date}`)).body;assert.equal(team.sellers.reduce((n,r)=>n+r.netSalesMinor,0),net);
  const seller=(await api.handle({method:'POST',path:'/auth/login',body:JSON.stringify({loginName:'vendedor1.muestra',password:'demo'})})).body;
  for(const path of ['/reports/kpi/team','/reports/commissions']){const r=await api.handle({method:'GET',path:path+'?date='+date,headers:{authorization:'Bearer '+seller.token}});const rows=r.body.sellers??r.body;assert.equal(rows.length,1);assert.equal(rows[0].sellerId,seller.staffId);}
  const inventory=await session('INVENTORY');for(const [m,p,b] of [['GET','/catalog/values'],['POST',`/catalog/items/${item.itemId}/values`,{priceMinor:1,costMinor:1,reason:'x'}],['GET','/cash/registers'],['GET','/reports/kpi/business']])assert.equal((await inventory.call(m,p,b)).status,403);
  assert.equal((await inventory.call('GET','/catalog/items')).body[0].variants[0].unitPriceMinor,null);
  api.reset();const fresh=await session('MANAGER');const login=(await api.handle({method:'POST',path:'/auth/login',body:JSON.stringify({loginName:'gerente.muestra',password:'demo'})})).body;
  const restored=await api.handle({method:'GET',path:endpoint,headers:{authorization:'Bearer '+login.token}});assert.deepEqual(restored.body,(await fresh.call('GET',endpoint)).body);assert.deepEqual(restored.body,before);
});
test('persistence, idempotency, rollback, logout and invalid credentials',async()=>{
  const map=new Map(),storage={getItem:k=>map.get(k),setItem:(k,v)=>map.set(k,v)};const {api,call}=await session('MANAGER',storage);
  const item=(await call('GET','/catalog/items')).body[0].variants[0],b=saleBody(id(9950),id(2000),item);
  const a=await call('POST','/sales',b);assert.equal(a.status,200);assert.deepEqual(await call('POST','/sales',b),a);assert.equal((await call('POST','/sales',{...b,discountReason:'changed'})).status,409);
  const api2=createFakeApi({storage,now});const login=(await api2.handle({method:'POST',path:'/auth/login',body:JSON.stringify({loginName:'gerente.muestra',password:'demo'})})).body;
  assert.equal((await api2.handle({method:'GET',path:`/sales/${b.saleId}`,headers:{authorization:'Bearer '+login.token}})).body.saleId,b.saleId);
  const before=(await call('GET',`/reports/day?date=${date}`)).body;assert.equal((await call('POST','/sales',{...b,saleId:id(9951),tenders:[]})).status,422);assert.deepEqual((await call('GET',`/reports/day?date=${date}`)).body,before);
  assert.equal((await api.handle({method:'GET',path:'/me'})).status,401);assert.equal((await api.handle({method:'POST',path:'/auth/login',body:'{"loginName":"duena.muestra","password":"wrong"}'})).status,401);
  assert.equal((await call('POST','/auth/logout')).status,204);assert.equal((await call('GET','/me')).status,401);
});
test('CSV/XLSX parsing uses only local bytes',async()=>{
  assert.deepEqual(await readImport({fileName:'demo.csv',contentBase64:Buffer.from('sku,name\r\nA,"Vestido, azul"').toString('base64')}),{fileName:'demo.csv',headers:['sku','name'],rows:[['A','Vestido, azul']]});
  for(const compression of [0,8]){
    const name=Buffer.from('xl/worksheets/sheet1.xml'),xml=Buffer.from('<worksheet><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>sku</t></is></c><c r="B1" t="inlineStr"><is><t>price</t></is></c></row><row r="2"><c r="A2" t="inlineStr"><is><t>LOCAL</t></is></c><c r="B2"><v>100</v></c></row></sheetData></worksheet>'),data=compression?deflateRawSync(xml):xml;
    const local=Buffer.alloc(30),central=Buffer.alloc(46),end=Buffer.alloc(22);
    local.writeUInt32LE(0x04034b50);local.writeUInt16LE(compression,8);local.writeUInt32LE(data.length,18);local.writeUInt32LE(xml.length,22);local.writeUInt16LE(name.length,26);
    central.writeUInt32LE(0x02014b50);central.writeUInt16LE(compression,10);central.writeUInt32LE(data.length,20);central.writeUInt32LE(xml.length,24);central.writeUInt16LE(name.length,28);
    end.writeUInt32LE(0x06054b50);end.writeUInt16LE(1,10);end.writeUInt32LE(central.length+name.length,12);end.writeUInt32LE(local.length+name.length+data.length,16);
    const contentBase64=Buffer.concat([local,name,data,central,name,end]).toString('base64');
    assert.deepEqual((await readImport({fileName:'demo.xlsx',contentBase64})).rows,[['LOCAL','100']]);
  }
});
test('catalog, reception, till, labels and history mutate persisted projections',async()=>{
  const {call}=await session();const item=(await call('GET','/catalog/items')).body[0].variants[0];
  const start=(await call('GET',`/reports/kpi/business?date=${date}`)).body;
  assert.equal((await call('POST',`/catalog/items/${item.itemId}/values`,{changeId:id(9800),priceMinor:item.unitPriceMinor+100,costMinor:90000,reason:'Costo actualizado'})).status,204);
  assert.equal((await call('GET',`/catalog/lookup?code=${item.barcode}`)).body[0].unitPriceMinor,item.unitPriceMinor+100);
  assert.notEqual((await call('GET',`/reports/kpi/business?date=${date}`)).body.stockValueAtCostMinor,start.stockValueAtCostMinor);
  const batch={batchId:id(9801),fileName:'local.csv',rows:[{row:2,sku:'LOCAL-IMPORT',name:'Prenda importada',cost:'40',price:'100',stock:'3'}]};
  assert.equal((await call('POST','/catalog/import',batch)).status,200);assert.equal((await call('GET','/catalog/search?q=LOCAL-IMPORT')).body[0].onHand,3);
  const sid=id(9802);await call('POST','/receiving/sessions',{containerId:id(9803),scanSessionId:sid,reference:'Prueba',supplierId:id(30)});
  await call('POST',`/receiving/sessions/${sid}/scans`,{scanId:id(9804),rawCode:item.barcode,quantity:4});
  await call('POST',`/receiving/sessions/${sid}/quality`,{checkId:id(9805),itemId:item.itemId,buena:3,danada:1,manchada:0,malOlor:0,faltante:0,reason:'Una dañada'});
  await call('POST',`/receiving/sessions/${sid}/approve`);const post=await call('POST',`/receiving/sessions/${sid}/post`);assert.equal(post.status,200);assert.equal((await call('GET',`/stock?itemId=${item.itemId}`)).body[0].onHand,item.onHand+3);
  const labels=(await call('GET','/labels/jobs')).body,job=labels.at(-1);assert.equal((await call('POST',`/labels/jobs/${job.id}/attempts`,{attemptId:id(9806),attemptNo:1,successful:true})).status,204);assert.equal((await call('GET','/labels/jobs?status=printed')).body[0].copiesAcknowledged,4);
});
test('coverage table names every web HTTP wrapper',()=>{
  const readme=readFileSync(new URL('../README-api.md',import.meta.url),'utf8');
  for(const name of exportedRoutes.keys())assert.ok(readme.includes('`'+name+'`'),name);
});
