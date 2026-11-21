// Pure helpers for reception. No DOM, no fetch: unit tested with node --test.

/** Server lines -> view rows. Quantity is the server's, never counted here. */
export function linesFromServer(rows) {
  return (rows ?? []).map(r => ({
    scanId: r.scanId ?? null,
    code: r.rawCode,
    itemId: r.itemId ?? null,
    matchStatus: r.matchStatus,
    name: r.productName
      ? `${r.productName}${r.variantName && r.variantName !== r.productName ? ` · ${r.variantName}` : ''}`
      : (r.variantName ?? null),
    size: r.sizeCode ?? null,
    sku: r.sku ?? null,
    quantity: Number.isInteger(r.quantity) ? r.quantity : null,
  }));
}

/** "1 código · 5 piezas". Pieces come from the server's session progress. */
export function totalsText(codeCount, progress) {
  const pieces = (progress?.matchedUnits ?? 0) + (progress?.unitsPendingReview ?? 0);
  return `${codeCount} ${codeCount === 1 ? 'código' : 'códigos'} · ${pieces} ${pieces === 1 ? 'pieza' : 'piezas'}`;
}

export function defaultReference(now = new Date()) {
  const p = n => String(n).padStart(2, '0');
  return `REC-${now.getFullYear()}${p(now.getMonth() + 1)}${p(now.getDate())}-${p(now.getHours())}${p(now.getMinutes())}`;
}
