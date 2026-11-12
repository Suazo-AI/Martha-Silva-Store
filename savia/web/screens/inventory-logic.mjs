// Pure filter for Inventario. Filters server rows; never changes a number.

const fold = text => String(text ?? '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim();

export function filterStock(rows, query) {
  const q = fold(query);
  if (!q) return rows;
  return rows.filter(r => fold(r.sku).includes(q) || fold(r.variantName).includes(q) || fold(r.productName).includes(q));
}
