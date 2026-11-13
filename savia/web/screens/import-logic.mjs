// Column mapping for "Importar catalogo". SQL validates every row again; this is only the preview input.
export const FIELDS = [['code', 'Código de barras'], ['sku', 'Referencia (SKU)'], ['name', 'Descripción'], ['type', 'Tipo de prenda'],
  ['size', 'Talla'], ['color', 'Color'], ['cost', 'Costo'], ['price', 'Precio'], ['stock', 'Existencia inicial']];

const fold = text => String(text ?? '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim();
const HINTS = [['code', ['codigo', 'barras', 'ean', 'upc']], ['sku', ['sku', 'referencia', 'ref']], ['name', ['descripcion', 'nombre', 'prenda']],
  ['type', ['tipo', 'categoria']], ['size', ['talla', 'size']], ['color', ['color']], ['cost', ['costo', 'cost']],
  ['price', ['precio', 'price', 'pvp']], ['stock', ['existencia', 'stock', 'cantidad', 'inventario']]];

/** Field -> column index (or -1). Each column is used once; the first matching hint wins. */
export function guessMapping(headers) {
  const folded = headers.map(fold);
  const used = new Set();
  const mapping = {};
  for (const [field, hints] of HINTS) {
    const index = folded.findIndex((header, i) => !used.has(i) && hints.some(hint => header.includes(hint)));
    mapping[field] = index;
    if (index !== -1) used.add(index);
  }
  return mapping;
}

/** A remembered mapping applies only when it was saved for the same headers. */
export const mappingKey = headers => `savia.import.mapping:${headers.map(fold).join('|')}`;

/** File rows -> request rows. Row numbers are 1-based spreadsheet rows (header is row 1). */
export function mapRows(rows, mapping) {
  const pick = (row, field) => {
    const index = mapping[field];
    const value = index == null || index < 0 ? '' : String(row[index] ?? '').trim();
    return value === '' ? null : value;
  };
  return rows.map((row, i) => ({ row: i + 2, ...Object.fromEntries(FIELDS.map(([field]) => [field, pick(row, field)])) }));
}

/** Uint8Array -> base64 without call-stack limits. */
export function toBase64(bytes) {
  let binary = '';
  for (let i = 0; i < bytes.length; i += 0x8000) binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(binary);
}
