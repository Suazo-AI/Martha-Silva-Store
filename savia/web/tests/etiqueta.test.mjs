import test from 'node:test';
import assert from 'node:assert/strict';
import { fitSize, barcodeHint, priceText, toForm, keepForNextSize, registration, LOW_CONFIDENCE } from '../etiqueta/etiqueta-logic.mjs';

test('fitSize scales the long side to 1600 px, keeps the ratio and never enlarges', () => {
  assert.deepEqual(fitSize(4000, 3000), { width: 1600, height: 1200, scaled: true });
  assert.deepEqual(fitSize(3024, 4032), { width: 1200, height: 1600, scaled: true });
  assert.deepEqual(fitSize(900, 1200), { width: 900, height: 1200, scaled: false });
  assert.deepEqual(fitSize(1600, 10), { width: 1600, height: 10, scaled: false });
  assert.deepEqual(fitSize(8000, 3), { width: 1600, height: 1, scaled: true });
  assert.throws(() => fitSize(0, 100), RangeError);
});

test('barcodeHint keeps 8 to 14 digits only', () => {
  assert.equal(barcodeHint(' 7501234567893 '), '7501234567893');
  assert.equal(barcodeHint('0036000291452'), '0036000291452');
  assert.equal(barcodeHint('BL-2041-AZ'), null);
  assert.equal(barcodeHint('1234567'), null);
  assert.equal(barcodeHint(null), null);
});

test('priceText shows minor units as an editable amount without floats', () => {
  assert.equal(priceText(125000), '1,250.00');
  assert.equal(priceText(89000), '890.00');
  assert.equal(priceText(null), '');
  assert.equal(priceText(undefined), '');
});

const answer = {
  barcode: '7501234567893', sku: 'BL-2041-AZ', name: 'Blusa manga corta', brand: 'ALMA TEXTIL', size: 'M', color: 'Azul',
  priceMinor: 125000, composition: '95% Algodón 5% Elastano',
  confidence: { barcode: 0.99, sku: 0.98, name: 0.55, brand: 0.6, size: 0.97, color: 0.95, priceMinor: 0.5, composition: 0.9 },
  rawText: '…', matchedItem: null, source: 'ocr', engine: 'rapidocr', elapsedMs: 1800, warning: null,
};

test('toForm maps the API answer and marks filled low-confidence fields for review', () => {
  const form = toForm(answer);
  assert.deepEqual(form.values, { barcode: '7501234567893', sku: 'BL-2041-AZ', name: 'Blusa manga corta', brand: 'ALMA TEXTIL',
    size: 'M', color: 'Azul', price: '1,250.00', composition: '95% Algodón 5% Elastano' });
  assert.deepEqual(form.review, ['name', 'brand', 'price']);
  assert.equal(form.matched, null);
  assert.equal(form.source, 'ocr');
  assert.ok(LOW_CONFIDENCE > 0.6 && LOW_CONFIDENCE < 0.98);
});

test('toForm: empty fields are not flagged, a failed reading keeps the form editable, another size reuses the model', () => {
  const failed = toForm({ barcode: '7894561230128', confidence: { barcode: 1, name: 0 }, source: 'none', warning: 'No se pudo leer la etiqueta.' },
    keepForNextSize(toForm(answer).values));
  assert.equal(failed.values.barcode, '7894561230128');
  assert.equal(failed.values.sku, '');
  assert.equal(failed.values.name, 'Blusa manga corta');       // kept from the first size
  assert.equal(failed.values.composition, '95% Algodón 5% Elastano');
  assert.equal(failed.values.size, '');                          // size and price are per tag
  assert.equal(failed.warning, 'No se pudo leer la etiqueta.');
  assert.deepEqual(toForm(null).review, []);
  const matched = toForm({ ...answer, source: 'match', matchedItem: { itemId: 'x', sku: 'BL-2041-AZ', matchedBy: 'barcode' } });
  assert.equal(matched.matched.matchedBy, 'barcode');
});

test('registration builds the existing catalog bodies and validates what the clerk must type', () => {
  const ids = { productId: 'p-1', itemId: 'i-1', costText: '600' };
  const plan = registration(toForm(answer).values, ids);
  assert.deepEqual(plan.errors, []);
  assert.deepEqual(plan.product, { productId: 'p-1', name: 'Blusa manga corta · ALMA TEXTIL' });
  assert.deepEqual(plan.item, { itemId: 'i-1', productId: 'p-1', sku: 'BL-2041-AZ', variantName: 'Blusa manga corta · Talla M · Azul',
    currencyCode: 'NIO', unitPriceMinor: 125000, unitCostMinor: 60000, barcode: '7501234567893' });
  assert.equal(plan.scanCode, '7501234567893');

  const noSku = registration({ ...toForm(answer).values, sku: '' }, ids);
  assert.equal(noSku.item.sku, '7501234567893');                // like the reception modal: code as SKU

  const bad = registration({ name: '', barcode: '12AB', price: 'gratis' }, { productId: 'p', itemId: 'i', costText: '' });
  assert.deepEqual(bad.errors, ['Escriba el nombre.', 'Escriba el código de barras o el SKU.',
    'El código de barras debe tener solo números (8 a 14).', 'Escriba un precio válido.', 'Escriba el costo aprobado.']);
  assert.equal(bad.item, undefined);
});
