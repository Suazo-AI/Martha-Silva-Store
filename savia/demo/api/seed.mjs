// Synthetic fixtures only. Stable IDs keep persisted references portable.
export const id = n => `10000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
export const DEMO_USERS = [
  ['duena.muestra', 'OWNER', 'María Elena López'],
  ['gerente.muestra', 'MANAGER', 'Claudia Reyes'],
  ['vendedor1.muestra', 'SELLER', 'Ana Lucía Pérez'],
  ['vendedor2.muestra', 'SELLER', 'Rosa Isabel Gutiérrez'],
  ['vendedor3.muestra', 'SELLER', 'Daniela Luna'],
  ['bodega.muestra', 'INVENTORY', 'Marta Solís'],
].map(([loginName, role, displayName]) => ({ loginName, role, displayName }));
export const users = DEMO_USERS.map((u, i) => ({ ...u, staffId: id(i + 1) }));
export const day = date => new Date(new Date(date).getTime() - 6 * 3600000).toISOString().slice(0, 10);
export const sum = (rows, key) => rows.reduce((n, r) => n + (typeof key === 'function' ? key(r) : r[key] ?? 0), 0);
export function seed(now) {
  let random = 15112026;
  const rng = () => ((random = (Math.imul(random, 1664525) + 1013904223) >>> 0) / 4294967296);
  const today = day(now());
  const at = (offset, hour = 10) => new Date(new Date(`${today}T${String(hour).padStart(2,'0')}:00:00-06:00`).getTime() - offset * 86400000).toISOString();
  const categories = ['Fiesta/noche', 'Novia', 'Moda casual', 'Accesorios', 'Calzado', null];
  const names = ['Vestido satén', 'Vestido encaje', 'Blusa lino', 'Bolso perla', 'Sandalia lazo', 'Conjunto suave'];
  const products = Array.from({ length: 40 }, (_, i) => ({ productId: id(100 + i), name: `${names[i % 6]} ${i + 1}`, type: categories[i % 6] }));
  const items = products.flatMap((p, i) => ['S', 'M', 'L'].map((sizeCode, j) => ({ itemId: id(1000 + i * 3 + j), productId: p.productId,
    sku: `AUR-${i + 1}-${sizeCode}`, productName: p.name, variantName: `${p.name} · ${sizeCode}`, sizeCode,
    colorCode: ['Azul', 'Marfil', 'Coral'][j], barcode: `290${String(i * 3 + j).padStart(9,'0')}0`,
    unitPriceMinor: [180000, 450000, 65000, 35000, 95000, 80000][i % 6] + j * 1000,
    unitCostMinor: [85000, 210000, 25000, 12000, 40000, 35000][i % 6], currencyCode: 'NIO', status: 'active', onHand: 16, history: [] })));
  // EAN-13 check digits for scanner and import realism.
  for (const item of items) { const b = item.barcode.slice(0,12); item.barcode = b + ((10 - [...b].reduce((n,c,i) => n + Number(c) * (i % 2 ? 3 : 1), 0) % 10) % 10); }
  const s = { version: 1, serial: 100000, products, items, sales: [], returns: [], tills: [], sessions: [], labels: [], approvals: [], exceptions: [], credits: [],
    counts: {}, replay: {}, tokens: {}, rates: Object.fromEntries(users.filter(u => u.role === 'SELLER').map(u => [u.staffId, 300])),
    policy: { windowDays: 30, history: [] }, exchange: { id: id(20), currencyCode: 'USD', rate: 36.6243, effectiveFrom: today },
    suppliers: [{ supplierId: id(30), name: 'Textiles Horizonte' }],
    customers: [{ customerId: id(40), customerCode: 'C001', displayName: 'Cliente de muestra', phone: null, email: null }] };
  for (let d = 59; d >= 0; d--) {
    const tillId = id(2000 + d);
    s.tills.push({ tillId, registerId: id(10), registerName: 'Caja Centro', cashierId: id(2), cashierName: users[1].displayName,
      status: d ? 'closed' : 'open', currencyCode: 'NIO', openedAt: at(d,8), closedAt: d ? at(d,18) : null, openingMinor: 200000,
      openingLines: [{ denominationMinor: 10000, quantity: 20 }], closureId: d ? id(3000 + d) : null, countedMinor: null, differenceMinor: 0, usdOpeningMinor: 10000, usdDifferenceMinor: 0 });
    for (let n = 0; n < 7; n++) {
      const seller = n % 3;
      const preferred = [[0,1], [2,3], [4,5]][seller];
      const product = Math.floor(rng() * 6) * 6 + preferred[Math.floor(rng()*2)];
      const chosen = items[(product * 3 + Math.floor(rng() * 3)) % items.length];
      const lines = [chosen, ...(n === 6 ? [items[(product * 3 + 10) % items.length]] : [])].map((item, j) => {
        const quantity = rng() > .8 ? 2 : 1, discountMinor = n === 4 ? 2000 : 0;
        return { saleLineId: id(++s.serial), lineNumber: j + 1, itemId: item.itemId, sku: item.sku, name: item.productName, sizeCode: item.sizeCode,
          quantity, returnedQuantity: 0, unitPriceMinor: item.unitPriceMinor, discountMinor, taxMinor: 0, totalMinor: item.unitPriceMinor * quantity - discountMinor,
          sellerId: id(3 + (seller + j) % 3), sellerName: users[2 + (seller + j) % 3].displayName, costMinor: item.unitCostMinor * quantity,
          commissionMinor: Math.floor((item.unitPriceMinor * quantity - discountMinor) * .03) };
      });
      const totalMinor = sum(lines,'totalMinor'), usd = n === 5;
      const sale = { saleId: id(++s.serial), subtotalMinor: sum(lines,l=>l.quantity*l.unitPriceMinor), discountMinor: sum(lines,'discountMinor'), taxMinor: 0, totalMinor,
        status: 'posted', currencyCode: 'NIO', createdAt: at(d,9+n), customerId: null, customerName: null, cashierId: id(2), cashierName: users[1].displayName,
        tillId, registerName: 'Caja Centro', lines, reversals: [], receiptNumber: `CENTRO-${s.sales.length + 1}`, discountApprovedBy: n===4?id(2):null, discountReason: n===4?'Promoción de muestra':null,
        tenders: [{ tenderId: id(++s.serial), tenderKind: n % 3 === 0 ? 'card' : 'cash', amountMinor: totalMinor, receivedMinor: totalMinor, changeMinor: 0,
          reference: n%3===0?'DEMO':null, creditId: null, status: 'posted', foreignCurrencyCode: usd?'USD':null, foreignReceivedMinor: usd?Math.ceil(totalMinor/s.exchange.rate):null,
          exchangeRateId: usd?s.exchange.id:null, exchangeRate: usd?s.exchange.rate:null, roundingMinor: usd?0:null, foreignChangeMinor: usd?0:null, foreignChangeNioMinor: usd?0:null }] };
      s.sales.push(sale);
      if (sale.discountMinor) s.approvals.push({ action: 'discount', actorName: users[1].displayName, amountMinor: sale.discountMinor, reason: sale.discountReason, createdAt: sale.createdAt });
      if (n === 1 && d % 7 === 0) {
        const l = lines[0], creditMinor = Math.floor(l.totalMinor/l.quantity);
        const r = { reversalId: id(++s.serial), saleId: sale.saleId, kind: 'return', settlementKind: d%2?'credit':'transfer', reason: 'Talla de muestra', creditMinor,
          currencyCode: 'NIO', status: 'approved', createdAt: at(d,17), approvedBy: id(2), actorId: id(2), tillId, creditId: null,
          lines: [{ saleLineId: l.saleLineId, quantity: 1, creditMinor, restockPool: 'store', commissionReversedMinor: Math.floor(l.commissionMinor/l.quantity) }] };
        l.returnedQuantity++; sale.reversals.push(r); s.returns.push(r);
        if(r.settlementKind==='credit'){r.creditId=id(++s.serial);s.credits.push({...s.customers[0],creditId:r.creditId,currencyCode:'NIO',branchId:id(11),branchName:'Centro',availableMinor:creditMinor});}
      }
    }
    if (d % 5 === 0) s.sessions.push({ scanSessionId: id(4000+d), containerId: id(5000+d), reference: `Lote Aurora ${d+1}`, status: d?'posted':'open', supplierId: id(30), supplierName: s.suppliers[0].name,
      createdAt: at(d,8), actorId: id(6), closedAt: d?at(d,9):null, scans: [{ scanId: id(6000+d), itemId: items[d].itemId, rawCode: items[d].barcode, matchStatus: 'matched', quantity: 12 }], quality: [] });
  }
  // Derive current stock from opening units, posted receptions, sales and returns.
  for (const item of items) {
    item.onHand += sum(s.sessions.filter(r=>r.status==='posted'),r=>sum(r.scans.filter(l=>l.itemId===item.itemId),'quantity'));
    item.onHand -= sum(s.sales.flatMap(r=>r.lines).filter(l=>l.itemId===item.itemId),l=>l.quantity-l.returnedQuantity);
  }
  for(const t of s.tills.filter(t=>t.status==='closed')){
    const cash=sum(s.sales.filter(x=>x.tillId===t.tillId),x=>sum(x.tenders,y=>y.tenderKind==='cash'&&!y.foreignCurrencyCode?y.amountMinor:0));
    t.countedMinor=t.openingMinor+cash;
  }
  s.labels = items.slice(0,8).map((i,n)=>({id:id(7000+n),itemId:i.itemId,storeName:'Boutique Aurora',sku:i.sku,barcode:i.barcode,copiesRequested:3,copiesAcknowledged:0,status:'pending'}));
  return s;
}
