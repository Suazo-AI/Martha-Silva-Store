import * as api from '../api.mjs';
import { countTotal, formatMoney } from '../money.mjs';
import { h } from '../ui.mjs';

// Opening and closing use the same SQL-owned list and the same input validation.
export async function denominationCount({ prefix = 'den', saved = [], onChange = () => {} } = {}) {
  const denominations = await api.denominations();
  const values = new Map(denominations.map(d => [d, saved.find(l => l.denominationMinor === d)?.quantity ?? 0]));
  const total = h('strong', { id: prefix === 'open-den' ? 'till-opening' : 'counted', class: 'num', 'aria-live': 'polite' });
  const lines = () => [...values].map(([denominationMinor, quantity]) => ({ denominationMinor, quantity }));
  const inputs = [];
  const node = h(
    'div',
    { class: 'denoms' },
    denominations.map(d => {
      const subtotal = h('output', { class: 'num', id: `${prefix}-total-${d}` }, formatMoney(d * values.get(d)));
      const input = h('input', {
        id: `${prefix}-${d}`,
        'aria-label': `Cantidad de ${formatMoney(d)}`,
        type: 'number',
        min: 0,
        max: 1000000,
        step: 1,
        inputmode: 'numeric',
        autocomplete: 'off',
        value: values.get(d),
        onfocus: e => e.target.select(),
        oninput: e => {
          const q = Number(e.target.value);
          const valid = e.target.value.trim() !== '' && Number.isInteger(q) && q >= 0 && q <= 1000000;
          e.target.setAttribute('aria-invalid', String(!valid));
          values.set(d, valid ? q : 0);
          subtotal.textContent = valid ? formatMoney(d * q) : 'Revise la cantidad';
          total.textContent = formatMoney(countTotal(lines()));
          onChange();
        },
      });
      inputs.push(input);
      return h('label', { for: `${prefix}-${d}` }, h('span', { class: 'num' }, formatMoney(d)), input, subtotal);
    }),
  );
  total.textContent = formatMoney(countTotal(lines()));
  return {
    node,
    total,
    lines: () => {
      if (inputs.some(i => i.getAttribute('aria-invalid') === 'true')) throw new Error('Revise las cantidades de billetes y monedas.');
      return lines();
    },
  };
}

export const openingBreakdown = summary =>
  h(
    'details',
    { class: 'opening-breakdown', open: true },
    h('summary', {}, 'Desglose de apertura'),
    h(
      'div',
      { class: 'opening-lines' },
      (summary.openingLines ?? [])
        .filter(l => l.quantity > 0)
        .map(l =>
          h(
            'div',
            { class: 'row' },
            `${formatMoney(l.denominationMinor)} × ${l.quantity}`,
            h('strong', {}, formatMoney(l.denominationMinor * l.quantity)),
          ),
        ),
    ),
  );
