import test from 'node:test';
import assert from 'node:assert/strict';
import { saleRequest, ticketTotal } from '../screens/sale-logic.mjs';
test('line discounts reach SQL and lower the tender total', () => {
 const lines = [{ itemId: 'item', quantity: 2, unitPriceMinor: 59900, discountMinor: 11980 }];
 assert.equal(ticketTotal(lines), 107820);
 assert.equal(saleRequest({ saleId:'s', tillId:'t', lines, receivedMinor:107820 }).lines[0].discountMinor, 11980);
});

import { discountedLines, needsDiscountApproval, catalogMatches } from '../screens/sale-logic.mjs';
test('ticket and line percentages combine without bypassing manager approval', () => {
 const base=[{itemId:'a',quantity:2,unitPriceMinor:59900,discountPercent:5}];
 const ten=discountedLines(base,5);
 assert.equal(ten[0].discountMinor,11980);
 assert.equal(needsDiscountApproval(ten),true);
 assert.equal(needsDiscountApproval(discountedLines(base,15)),true);
 assert.throws(()=>discountedLines(base,96));
 assert.throws(()=>discountedLines(base,NaN));
});
test('catalog filters intersect type, size, name and SKU without accents', () => {
 const p={name:'Blusa de lino',type:'Blusas',variants:[{sku:'MAS-BLU-LIN-BLA-S',sizeCode:'S',variantName:'Blusa blanca'}]};
 assert.equal(catalogMatches(p,{type:'Blusas',size:'S',query:'blusa'}),true);
 assert.equal(catalogMatches(p,{type:'Vestidos'}),false);
 assert.equal(catalogMatches(p,{size:'M'}),false);
 assert.equal(catalogMatches(p,{query:'MAS-BLU'}),true);
});
