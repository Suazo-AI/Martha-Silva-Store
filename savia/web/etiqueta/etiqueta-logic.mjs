// Pure rules of the phone tag page (/etiqueta/). No DOM, so node --test covers them.
import { formatMoney, parseMoney } from '../money.mjs';

export const MAX_SIDE = 1600;          // the phone sends at most 1600 px on the long side
export const JPEG_QUALITY = 0.85;
export const LOW_CONFIDENCE = 0.7;     // below this a filled field is marked "Revisar"
export const FIELDS = ['barcode', 'sku', 'name', 'brand', 'size', 'color', 'price', 'composition'];
const KEEP_FOR_OTHER_SIZES = ['name', 'brand', 'color', 'composition'];

/** Target size for the downscale: keeps the aspect ratio, never enlarges. */
export function fitSize(width, height, max = MAX_SIDE) {
  if (!(width > 0 && height > 0)) throw new RangeError('La foto no tiene tamaño.');
  const scale = Math.min(1, max / Math.max(width, height));
  return { width: Math.max(1, Math.round(width * scale)), height: Math.max(1, Math.round(height * scale)), scaled: scale < 1 };
}

/** Phone barcode reading: digits only, 8 to 14 long, otherwise ignored (the server checks the check digit). */
export function barcodeHint(text) {
  const digits = String(text ?? '').trim();
  return /^\d{8,14}$/.test(digits) ? digits : null;
}

/** C$ minor units -> "1,250.00" for the editable price field. */
export function priceText(minor) {
  if (!Number.isSafeInteger(minor)) return '';
  return formatMoney(minor).replace(/^C\$ /, '');
}

/** API answer (TagExtractResponse) -> form values plus the fields to review. */
export function toForm(answer, previous = {}) {
  const a = answer ?? {};
  const confidence = a.confidence ?? {};
  const values = {
    barcode: a.barcode ?? '', sku: a.sku ?? '', name: a.name ?? '', brand: a.brand ?? '', size: a.size ?? '',
    color: a.color ?? '', price: priceText(a.priceMinor), composition: a.composition ?? '',
  };
  // Another size of the same model: the tag may omit what the first photo already gave.
  for (const key of KEEP_FOR_OTHER_SIZES) if (!values[key] && previous[key]) values[key] = previous[key];
  const review = FIELDS.filter(key => {
    const score = confidence[key === 'price' ? 'priceMinor' : key];
    return values[key] !== '' && typeof score === 'number' && score < LOW_CONFIDENCE;
  });
  const matched = a.matchedItem ?? null;
  return { values, review, matched, source: a.source ?? 'none', warning: a.warning ?? null };
}

/** Values kept for the next size of the same model ("Otra talla"). */
export function keepForNextSize(values) {
  return Object.fromEntries(KEEP_FOR_OTHER_SIZES.map(key => [key, values[key] ?? '']));
}

const clean = text => String(text ?? '').trim().replace(/\s+/g, ' ');

/**
 * Form -> bodies of the existing catalog endpoints. The catalog has no brand or composition column:
 * the brand goes in the product name, size and colour in the variant name, the composition is not stored.
 */
export function registration(values, { productId, itemId, costText }) {
  const errors = [];
  const name = clean(values.name), brand = clean(values.brand), size = clean(values.size).toUpperCase(), color = clean(values.color);
  const barcode = barcodeHint(values.barcode);
  const sku = clean(values.sku) || barcode || '';
  const unitPriceMinor = parseMoney(values.price ?? '');
  const unitCostMinor = parseMoney(costText ?? '');
  if (!name) errors.push('Escriba el nombre.');
  if (!sku) errors.push('Escriba el código de barras o el SKU.');
  if (clean(values.barcode) && !barcode) errors.push('El código de barras debe tener solo números (8 a 14).');
  if (unitPriceMinor == null || unitPriceMinor <= 0) errors.push('Escriba un precio válido.');
  if (unitCostMinor == null) errors.push('Escriba el costo aprobado.');
  if (errors.length) return { errors };
  const productName = brand && !name.toUpperCase().includes(brand.toUpperCase()) ? `${name} · ${brand}` : name;
  const variantName = [name, size && `Talla ${size}`, color].filter(Boolean).join(' · ');
  return {
    errors,
    product: { productId, name: productName.slice(0, 200) },
    item: { itemId, productId, sku: sku.slice(0, 100), variantName: variantName.slice(0, 200), currencyCode: 'NIO',
      unitPriceMinor, unitCostMinor, barcode: barcode ?? null },
    scanCode: barcode ?? sku,
  };
}
