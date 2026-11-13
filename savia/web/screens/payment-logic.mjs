import { parseMoney } from '../money.mjs';

/** Convert pending form fields to integer minor units. SQL validates the submitted sale. */
export function paymentDraft(totalMinor, rows, { supportedKinds, customerId } = {}) {
  if (totalMinor === 0) return { tenders: [], changeMinor: 0 };
  const tenders = rows.map((row, index) => {
    if (!supportedKinds.includes(row.kind)) throw new Error('Elija un método de pago disponible.');
    const amountMinor = rows.length === 1 ? totalMinor : parseMoney(row.amount);
    if (!Number.isSafeInteger(amountMinor) || amountMinor <= 0) throw new Error('Indique el importe de cada pago.');
    let receivedMinor = null;
    let changeMinor = null;
    if (row.kind === 'cash') {
      receivedMinor = parseMoney(row.received);
      if (receivedMinor === null || receivedMinor < amountMinor) throw new Error('El efectivo recibido no cubre el pago.');
      changeMinor = receivedMinor - amountMinor;
    }
    const reference = row.reference?.trim();
    if (['card', 'transfer'].includes(row.kind) && !reference) throw new Error('Indique la referencia del pago con tarjeta o transferencia.');
    if (row.kind === 'credit' && (!customerId || !row.creditId)) throw new Error('Busque y elija un anticipo disponible del cliente.');
    return { tenderNumber: index + 1, tenderKind: row.kind, amountMinor, receivedMinor, changeMinor,
      ...(reference ? { reference } : {}), ...(row.kind === 'credit' ? { creditId: row.creditId } : {}) };
  });
  if (!tenders.length || tenders.reduce((sum, tender) => sum + tender.amountMinor, 0) !== totalMinor) {
    throw new Error('La suma de los pagos debe coincidir con el total del ticket.');
  }
  return { tenders, changeMinor: tenders.reduce((sum, tender) => sum + (tender.changeMinor ?? 0), 0) };
}
