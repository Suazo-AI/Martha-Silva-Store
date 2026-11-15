import { day, sum, users, id } from './seed.mjs';
export const ratio = (a,b,scale=10000) => b ? Math.floor(a*scale/b) : 0;
export function range(period, date) {
  const d = new Date(`${date}T12:00:00Z`), end = new Date(d);
  if (period==='week') { d.setUTCDate(d.getUTCDate()-(d.getUTCDay()+6)%7); end.setTime(d.getTime()+6*86400000); }
  if (period==='month') { d.setUTCDate(1); end.setUTCMonth(end.getUTCMonth()+1,0); }
  if (period==='year') { d.setUTCMonth(0,1); end.setUTCMonth(11,31); }
  return { period, date, startDate:d.toISOString().slice(0,10), endDate:end.toISOString().slice(0,10), currencyCode:'NIO' };
}
const within = (r,b) => day(r.createdAt)>=b.startDate && day(r.createdAt)<=b.endDate;
const group = (rows,key,fn) => [...new Set(rows.map(key))].map(k=>fn(rows.filter(r=>key(r)===k),k));
export function tillSummary(s,t) {
  const sales = s.sales.filter(x=>x.tillId===t.tillId), refunds=s.returns.filter(r=>r.tillId===t.tillId && r.settlementKind==='cash');
  const cashSalesMinor=sum(sales,x=>sum(x.tenders,t=>t.tenderKind==='cash'&&!t.foreignCurrencyCode?t.amountMinor:t.foreignCurrencyCode?-(t.foreignChangeNioMinor??0):0));
  const cashRefundsMinor=sum(refunds,'creditMinor');
  const usdExpectedMinor=(t.usdOpeningMinor??0)+sum(sales,x=>sum(x.tenders,t=>t.foreignCurrencyCode==='USD'?(t.foreignReceivedMinor??0)-(t.foreignChangeMinor??0):0));
  return {...t,cashSalesMinor,cashRefundsMinor,otherCashMinor:0,expectedCashMinor:t.openingMinor+cashSalesMinor-cashRefundsMinor,saleCount:sales.length,salesTotalMinor:sum(sales,'totalMinor'),usdExpectedMinor};
}
export function report(s,kind,period,date,actor) {
  const b=range(period,date), sales=s.sales.filter(r=>within(r,b)), returns=s.returns.filter(r=>within(r,b)), lines=sales.flatMap(x=>x.lines);
  const rlines=returns.flatMap(r=>r.lines.map(l=>({...l, original:s.sales.find(x=>x.saleId===r.saleId)?.lines.find(x=>x.saleLineId===l.saleLineId)})));
  const grossSalesMinor=sum(sales,'totalMinor'), returnsMinor=sum(returns,'creditMinor'), unitsSold=sum(lines,'quantity'), discountsMinor=sum(lines,'discountMinor');
  const tenders=group(sales.flatMap(x=>x.tenders),x=>x.tenderKind,(a,tenderKind)=>({currencyCode:'NIO',tenderKind,saleCount:a.length,totalMinor:sum(a,'amountMinor')}));
  const refundsByKind=group(returns,r=>`${r.tillId}:${r.settlementKind}`,(a)=>({tillId:a[0].tillId,kind:a[0].settlementKind,returnsCount:a.length,amountMinor:sum(a,'creditMinor'),cashOutMinor:sum(a,r=>r.settlementKind==='cash'?r.creditMinor:0)}));
  const topItems=group(lines,l=>l.itemId,(a,itemId)=>({itemId,sku:a[0].sku,name:a[0].name,unitsSold:sum(a,'quantity'),totalMinor:sum(a,'totalMinor')})).sort((a,b)=>b.unitsSold-a.unitsSold);
  const tills=s.tills.filter(t=>within({createdAt:t.openedAt},b)).map(t=>{const x=tillSummary(s,t); const ret=sum(s.returns.filter(r=>r.tillId===t.tillId),'creditMinor'); return {countedMinor:null,differenceMinor:null,usdCountedMinor:null,usdDifferenceMinor:null,...x,expectedMinor:x.expectedCashMinor,accountingDocumentId:null,documentNumber:null,accountingStatus:null,saleGrossMinor:x.salesTotalMinor,returnGrossMinor:ret,netSalesMinor:x.salesTotalMinor-ret};});
  if(kind==='day') return {date,branchId:id(11),salesCount:sales.length,unitsSold,totals:[{currencyCode:'NIO',saleCount:sales.length,totalMinor:grossSalesMinor}],tenders,returns:returns.map(r=>({...r,unitsReturned:sum(r.lines,'quantity')})),tills,topItems,refundsByKind};
  const sellerRows=users.filter(u=>u.role==='SELLER'&&(actor.role!=='SELLER'||actor.staffId===u.staffId)).map(u=>{
    const own=lines.filter(l=>l.sellerId===u.staffId), returned=rlines.filter(l=>l.original?.sellerId===u.staffId), sold=sum(own,'totalMinor'), back=sum(returned,'creditMinor');
    const units=sum(own,'quantity'), tickets=sales.filter(x=>x.lines.some(l=>l.sellerId===u.staffId)).length, earned=sum(own,'commissionMinor'), reversed=sum(returned,'commissionReversedMinor');
    return {sellerId:u.staffId,name:u.displayName,rateBps:s.rates[u.staffId],salesLines:own.length,units,tickets,netSoldMinor:sold,netSalesMinor:sold-back,returnedUnits:sum(returned,'quantity'),returnsMinor:back,returnsBps:ratio(back,sold),discountsMinor:sum(own,'discountMinor'),commissionEarnedMinor:earned,commissionReversedMinor:reversed,commissionPayableMinor:earned-reversed,averageTicketMinor:ratio(sold,tickets,1),unitsPerTicketX100:ratio(units,tickets,100)};
  });
  if(kind==='commissions') return sellerRows;
  const sessions=s.sessions.filter(r=>within(r,b)), quality=sessions.flatMap(r=>r.quality);
  const qualityRejects=sum(quality,q=>q.danada+q.manchada+q.malOlor+q.faltante);
  if(kind==='team') return {...b,sellers:sellerRows,managers:actor.role==='SELLER'?[]:users.filter(u=>['MANAGER','OWNER'].includes(u.role)).map(u=>({staffId:u.staffId,name:u.displayName,tillClosures:tills.filter(t=>t.cashierId===u.staffId&&t.status==='closed').length,tillDifferenceMinor:sum(tills.filter(t=>t.cashierId===u.staffId),'differenceMinor'),usdTillDifferenceMinor:sum(tills.filter(t=>t.cashierId===u.staffId),'usdDifferenceMinor'),approvalsCount:s.approvals.filter(a=>a.actorName===u.displayName&&within(a,b)).length,approvalsMinor:sum(s.approvals.filter(a=>a.actorName===u.displayName&&within(a,b)),'amountMinor')})),stockWorkers:actor.role==='SELLER'?[]:[{staffId:id(6),name:users[5].displayName,garmentsReceived:sum(sessions,x=>sum(x.scans.filter(y=>y.matchStatus==='matched'),'quantity')),qualityRejects,receptionMinutesAverage:sessions.some(x=>x.closedAt)?Math.floor(sum(sessions.filter(x=>x.closedAt),x=>(new Date(x.closedAt)-new Date(x.createdAt))/60000)/sessions.filter(x=>x.closedAt).length):null}]};
  const costOfGoodsMinor=sum(lines,'costMinor')-sum(rlines,l=>Math.floor((l.original?.costMinor??0)*l.quantity/(l.original?.quantity||1))), netSalesMinor=grossSalesMinor-returnsMinor, grossMarginMinor=netSalesMinor-costOfGoodsMinor;
  const stockUnits=sum(s.items,'onHand');
  return {...b,grossSalesMinor,returnsMinor,netSalesMinor,salesCount:sales.length,unitsSold,averageTicketMinor:ratio(grossSalesMinor,sales.length,1),unitsPerTicketX100:ratio(unitsSold,sales.length,100),revenueMinor:netSalesMinor,costOfGoodsMinor,grossMarginMinor,grossMarginBps:ratio(grossMarginMinor,netSalesMinor),discountsMinor,discountsBps:ratio(discountsMinor,sum(sales,'subtotalMinor')),returnsBps:ratio(returnsMinor,grossSalesMinor),returnsCount:returns.length,refundsByKind,stockUnits,stockValueAtCostMinor:sum(s.items,i=>i.onHand*i.unitCostMinor),daysOfInventory:unitsSold?Math.floor(stockUnits*(1+(new Date(b.endDate)-new Date(b.startDate))/86400000)/unitsSold):null,stockExceptionsCount:s.exceptions.filter(r=>within(r,b)).length,qualityRejects,tillClosures:tills.filter(t=>t.status==='closed').length,tillClosuresWithDifference:tills.filter(t=>t.differenceMinor).length,tillDifferenceMinor:sum(tills,'differenceMinor'),usdTillDifferenceMinor:sum(tills,'usdDifferenceMinor'),salesByHour:group(sales,x=>new Date(new Date(x.createdAt).getTime()-21600000).getUTCHours(),(a,hour)=>({hour,salesCount:a.length,totalMinor:sum(a,'totalMinor')})),sellThrough:s.products.map(p=>{const its=s.items.filter(i=>i.productId===p.productId), ids=new Set(its.map(i=>i.itemId)), unitsReceived=sum(s.sessions.filter(x=>x.status==='posted'),x=>sum(x.scans.filter(l=>ids.has(l.itemId)),'quantity')), sold=sum(s.sales.flatMap(x=>x.lines).filter(l=>ids.has(l.itemId)),'quantity');return {productId:p.productId,name:p.name,unitsReceived,unitsSold:sold,sellThroughBps:ratio(sold,unitsReceived)};}),staleItems:s.items.filter(i=>!s.sales.some(x=>x.lines.some(l=>l.itemId===i.itemId))).map(i=>({itemId:i.itemId,sku:i.sku,name:i.productName,onHand:i.onHand,lastMovementAt:null})),grossMinor:sum(sales,'subtotalMinor'),netMinor:netSalesMinor,tenders,salesByDay:group(sales,x=>day(x.createdAt),(a,date)=>({date,salesCount:a.length,totalMinor:sum(a,'totalMinor')})),cashiers:group(sales,x=>x.cashierId,(a,staffId)=>({staffId,name:a[0].cashierName,salesCount:a.length,totalMinor:sum(a,'totalMinor')})),topItems};
}
export function csv(value) {
  const rows=Array.isArray(value)?value:Object.entries(value).flatMap(([key,v])=>Array.isArray(v)?v.map(r=>({section:key,...r})): [{section:'total',field:key,value:v}]);
  const fields=[...new Set(rows.flatMap(Object.keys))];
  const quote=v=>'"'+String(v??'').replaceAll('"','""')+'"';
  return '\ufeff'+[fields,...rows.map(r=>fields.map(f=>r[f]))].map(r=>r.map(quote).join(',')).join('\r\n');
}
