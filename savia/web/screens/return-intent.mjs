// One origin-wide durable return. No credentials. Web Locks serialize mounts and tabs.
import { actorScope, sameGuid, sameScope } from '../sale-recovery.mjs';
import { GUID_RE } from '../ui.mjs';
export { actorScope, sameScope };
export const RETURN_KEY = 'savia.return.pending.v1';
const fail = () => { throw Error('No se pudo verificar la devoluci\u00f3n pendiente. Pida revisi\u00f3n a la gerente.'); };
const guid = x => typeof x === 'string' && GUID_RE.test(x);
const int = x => Number.isSafeInteger(x) && x >= 0;
const only = (o, keys) => o && typeof o === 'object' && !Array.isArray(o) && Object.keys(o).every(k => keys.includes(k));
export function validateIntent(r) {
 const b=r?.body;
 if(r?.currencyCode!==undefined && !/^[A-Z]{3}$/.test(r.currencyCode))fail();
 if(!only(r,['version','state','scope','saleId','saleTillId','endpoint','body','expected','currencyCode']) || r.version!==1 ||
 !['draft','sending','unresolved','confirmed'].includes(r.state) ||
 !only(r.scope,['origin','staffId','nodeId','branchId','locationId']) || typeof r.scope.origin!=='string' ||
 !['staffId','nodeId','branchId','locationId'].every(k=>guid(r.scope[k])) || !guid(r.saleId) || !guid(r.saleTillId) ||
 !['credit','outcome'].includes(r.endpoint) ||
 !only(b,['reversalId','creditId','tillId','customerId','reason','lines','outcome','reference','exchangeSaleId','newLines','newTenders','differenceKind','differenceReference']) ||
 !guid(b.reversalId) || !guid(b.tillId) || typeof b.reason!=='string' || !b.reason.trim() || b.reason.length>500 ||
 !Array.isArray(b.lines) || !b.lines.length || !b.lines.every(l=>only(l,['saleLineId','quantity','restockPool']) && guid(l.saleLineId) && int(l.quantity) && l.quantity>0 && ['store','quarantine'].includes(l.restockPool)) ||
 new Set(b.lines.map(l=>l.saleLineId.toLowerCase())).size!==b.lines.length ||
 !Array.isArray(r.expected) || r.expected.length!==b.lines.length ||
 !r.expected.every((l,i)=>only(l,['saleLineId','quantity','restockPool','creditMinor']) && sameGuid(l.saleLineId,b.lines[i].saleLineId) && l.quantity===b.lines[i].quantity && l.restockPool===b.lines[i].restockPool && int(l.creditMinor))) fail();
 if(r.endpoint==='credit' ? (!guid(b.creditId)||!guid(b.customerId)||b.outcome!=null) : !['cash','transfer','exchange'].includes(b.outcome)) fail();
 if(b.outcome==='transfer' && (typeof b.reference!=='string'||!b.reference.trim())) fail();
 if(b.outcome==='exchange') {
 if(!guid(b.exchangeSaleId)||!Array.isArray(b.newLines)||!b.newLines.length||!b.newLines.every(l=>only(l,['lineNumber','itemId','quantity','unitPriceMinor','discountMinor','sellerId']) && guid(l.itemId) && guid(l.sellerId) && int(l.lineNumber)&&l.lineNumber>0&&int(l.quantity)&&l.quantity>0&&int(l.unitPriceMinor)&&l.discountMinor===0) ||
 !Array.isArray(b.newTenders)||!b.newTenders.every(t=>only(t,['tenderNumber','tenderKind','amountMinor','receivedMinor','changeMinor','reference']) && int(t.tenderNumber)&&['cash','card','transfer'].includes(t.tenderKind)&&int(t.amountMinor)&&(t.reference==null||typeof t.reference==='string')&&(t.receivedMinor==null||int(t.receivedMinor))&&(t.changeMinor==null||int(t.changeMinor)))) fail();
 }
 for(const k of ['reference','differenceReference']) if(b[k]!=null && (typeof b[k]!=='string'||b[k].length>120)) fail();
 if(b.differenceKind!=null&&!['cash','transfer'].includes(b.differenceKind)) fail();
 return r;
}
export function readIntent(storage=localStorage) {
 const raw=storage.getItem(RETURN_KEY);
 if(raw===null)return null;
 if(raw.length>250000)fail();
 return validateIntent(JSON.parse(raw));
}
export function reserveIntent(record, storage=localStorage) {
 validateIntent(record);
 if(storage.getItem(RETURN_KEY)!==null)fail();
 const raw=JSON.stringify(record);storage.setItem(RETURN_KEY,raw);
 if(storage.getItem(RETURN_KEY)!==raw)fail();
 return JSON.parse(raw);
}
export function changeIntent(record,state,storage=localStorage) {
 if(JSON.stringify(readIntent(storage))!==JSON.stringify(record))fail();
 const next=validateIntent({...record,state}), raw=JSON.stringify(next);
 storage.setItem(RETURN_KEY,raw);if(storage.getItem(RETURN_KEY)!==raw)fail();return next;
}
export function finishIntent(record,storage=localStorage) {
 if(record.state!=='confirmed'||JSON.stringify(readIntent(storage))!==JSON.stringify(record))fail();
 storage.removeItem(RETURN_KEY);if(storage.getItem(RETURN_KEY)!==null)fail();
}
export async function withIntentLock(fn) {
 if(!globalThis.navigator?.locks?.request) throw Error('Este navegador no permite proteger la devoluci\u00f3n. Use el navegador autorizado.');
 return navigator.locks.request(RETURN_KEY,{mode:'exclusive',ifAvailable:true},lock=>{
 if(!lock)throw Error('Otra pantalla est\u00e1 procesando la devoluci\u00f3n.');return fn();
 });
}
// Legacy records retain lookup access but cannot invent a missing currency expectation.
const validTimestamp = value => {
 if(typeof value!=='string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,7})?(?:Z|[+-]\d{2}:\d{2})?$/.test(value) || !Number.isFinite(Date.parse(value)))return false;
 const [year,month,day]=value.slice(0,10).split('-').map(Number);
 return month>=1 && month<=12 && day>=1 && day<=new Date(Date.UTC(year,month,0)).getUTCDate();
};
export function validReversal(x,r) {
 const b=r.body, total=r.expected.reduce((s,l)=>s+l.creditMinor,0);
 if(!x || typeof x!=='object' || Array.isArray(x) || !r.currencyCode ||
 !sameGuid(x.reversalId,b.reversalId) || x.kind!=='return' || x.status!=='approved' ||
 !guid(x.actorId) || !guid(x.approvedBy) || !validTimestamp(x.createdAt) ||
 !sameGuid(x.tillId,b.tillId) || x.settlementKind!==(b.outcome??'credit') || x.reason!==b.reason || x.currencyCode!==r.currencyCode ||
 !Number.isSafeInteger(total) || total<=0 || !Number.isSafeInteger(x.creditMinor) || x.creditMinor!==total ||
 (b.creditId ? !sameGuid(x.creditId,b.creditId) : x.creditId!==null) ||
 !Array.isArray(x.lines) || x.lines.length!==r.expected.length ||
 !x.lines.every(a=>a && typeof a==='object' && !Array.isArray(a)) ||
 !r.expected.every(l=>x.lines.filter(a=>sameGuid(a.saleLineId,l.saleLineId)&&a.quantity===l.quantity&&a.restockPool===l.restockPool&&Number.isSafeInteger(a.creditMinor)&&a.creditMinor===l.creditMinor).length===1))return false;
 return true;
}
export function matchingReversal(sale,r) {
 if(!sameGuid(sale?.saleId,r.saleId)||!sameGuid(sale?.tillId,r.saleTillId)||!Array.isArray(sale.reversals))return null;
 const hits=sale.reversals.filter(x=>x && sameGuid(x.reversalId,r.body.reversalId));
 return hits.length===1 && validReversal(hits[0],r) ? hits[0] : null;
}
export function cancelDraft(record,storage=localStorage) {
 if(record.state!=='draft'||JSON.stringify(readIntent(storage))!==JSON.stringify(record))fail();
 storage.removeItem(RETURN_KEY);if(storage.getItem(RETURN_KEY)!==null)fail();
}
