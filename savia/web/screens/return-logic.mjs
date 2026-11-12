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
