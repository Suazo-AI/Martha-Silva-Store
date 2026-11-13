// Input bounds are a preview. SQL remains the authority for eligibility and refund amounts.
export const remainingQuantity = line => Math.max(0, line.quantity - line.returnedQuantity);

export function selectedReturnLines(lines, quantities) {
  const selected = [];
  for (const line of lines) {
    const quantity = Number(quantities[line.lineNumber] ?? 0);
    if (!Number.isSafeInteger(quantity) || quantity < 0 || quantity > remainingQuantity(line)) {
      throw new Error('Revise las cantidades. No pueden superar las unidades pendientes de devolver.');
    }
    if (quantity) selected.push({ saleLineNumber: line.lineNumber, quantity });
  }
  if (!selected.length) throw new Error('Elija al menos una unidad para devolver.');
  return selected;
}

export const OUTCOMES = [
  ['exchange', 'Cambio por otra prenda'],
  ['credit', 'Anticipo al cliente'],
  ['cash', 'Efectivo de caja'],
  ['transfer', 'Transferencia bancaria'],
];

/** The value SQL credits: a proportional share of the line total, and the remainder for the last units. */
export function returnValue(sale, quantities) {
  return sale.lines.reduce((sum, line) => {
    const quantity = Number(quantities[line.lineNumber] ?? 0);
    if (!quantity) return sum;
    const prior = (sale.reversals ?? [])
      .filter(r => r.status === 'approved')
      .flatMap(r => r.lines)
      .filter(l => l.saleLineId === line.saleLineId)
      .reduce((total, l) => total + l.creditMinor, 0);
    return (
      sum +
      (line.returnedQuantity + quantity === line.quantity
        ? line.totalMinor - prior
        : Math.round((line.totalMinor * quantity) / line.quantity))
    );
  }, 0);
}

/** Exchange balance: positive dueMinor is paid by the customer; positive backMinor goes back to her. */
export function exchangeBalance(returnMinor, newLines) {
  const newMinor = newLines.reduce((sum, l) => sum + l.unitPriceMinor * l.quantity, 0);
  return { newMinor, dueMinor: Math.max(0, newMinor - returnMinor), backMinor: Math.max(0, returnMinor - newMinor) };
}

/** Body of POST /sales/{id}/returns/outcome for cash, transfer or exchange. */
export function outcomeRequest({
  reversalId,
  outcome,
  tillId,
  reason,
  lines,
  reference,
  exchangeSaleId,
  newLines = [],
  sellerId,
  tenderKind,
  tenderReference,
  differenceKind,
  differenceReference,
  returnMinor,
}) {
  if (!['cash', 'transfer', 'exchange'].includes(outcome)) throw new Error('Elija cómo se devuelve el dinero.');
  if (outcome === 'transfer' && !reference?.trim()) throw new Error('Indique la referencia de la transferencia.');
  const body = { reversalId, outcome, tillId, reason, lines };
  if (outcome === 'transfer') body.reference = reference.trim();
  if (outcome !== 'exchange') return body;
  if (!newLines.length) throw new Error('Agregue la prenda que se lleva la clienta.');
  const { dueMinor, backMinor } = exchangeBalance(returnMinor, newLines);
  body.exchangeSaleId = exchangeSaleId;
  body.newLines = newLines.map((l, i) => ({
    lineNumber: i + 1,
    itemId: l.itemId,
    quantity: l.quantity,
    unitPriceMinor: l.unitPriceMinor,
    discountMinor: 0,
    ...(sellerId ? { sellerId } : {}),
  }));
  body.newTenders = dueMinor
    ? [
        {
          tenderNumber: 1,
          tenderKind,
          amountMinor: dueMinor,
          ...(tenderKind === 'cash' ? { receivedMinor: dueMinor, changeMinor: 0 } : {}),
          ...(tenderReference?.trim() ? { reference: tenderReference.trim() } : {}),
        },
      ]
    : [];
  if (backMinor) {
    if (!['cash', 'transfer'].includes(differenceKind)) throw new Error('Indique cómo se devuelve la diferencia.');
    if (differenceKind === 'transfer' && !differenceReference?.trim()) throw new Error('Indique la referencia de la transferencia.');
    body.differenceKind = differenceKind;
    if (differenceKind === 'transfer') body.differenceReference = differenceReference.trim();
  }
  return body;
}
