import * as api from '../api.mjs';
import { confirmAction } from '../confirm.mjs';
import { formatMoney, parseMoney } from '../money.mjs';
import { h, replace, showError } from '../ui.mjs';
import { saleDate } from './sale-view.mjs';

export default {
  title: 'Precios',
  async mount(root) {
    const message = h('p', { role: 'alert' }),
      list = h('div', { id: 'price-list', class: 'form' });
    const query = h('input', { id: 'price-search', type: 'search', placeholder: 'Nombre o SKU' });
    async function load() {
      try {
        const items = await api.itemValues(query.value);
        replace(
          list,
          items.map(item => {
            const price = h('input', {
              inputmode: 'decimal',
              value: (item.priceMinor / 100).toFixed(2),
              'aria-label': `Precio de ${item.sku}`,
            });
            const cost = h('input', {
              inputmode: 'decimal',
              value: ((item.costMinor ?? 0) / 100).toFixed(2),
              'aria-label': `Costo de ${item.sku}`,
            });
            const reason = h('input', { maxlength: 250, 'aria-label': `Motivo de ${item.sku}` });
            const ids = api.retryIds('changeId');
            return h(
              'article',
              { class: 'panel', dataset: { item: item.itemId } },
              h('h2', {}, item.name),
              h('p', {}, item.sku),
              h(
                'div',
                { class: 'actions' },
                h('label', {}, 'Precio C$', price),
                h('label', {}, 'Costo C$', cost),
                h('label', {}, 'Motivo', reason),
                h(
                  'button',
                  {
                    type: 'button',
                    class: 'save-values',
                    onclick: async () => {
                      try {
                        const priceMinor = parseMoney(price.value),
                          costMinor = parseMoney(cost.value);
                        if (priceMinor === null || costMinor === null || !reason.value.trim())
                          throw new Error('Revise precio, costo y motivo.');
                        if (
                          !(await confirmAction(
                            `${item.name}: el precio cambiará de ${formatMoney(item.priceMinor)} a ${formatMoney(priceMinor)} y el costo a ${formatMoney(costMinor)}.`,
                          ))
                        )
                          return;
                        const { changeId } = ids([priceMinor, costMinor, reason.value]);
                        await api.setItemValues(item.itemId, { changeId, priceMinor, costMinor, reason: reason.value });
                        await load();
                      } catch (error) {
                        showError(message, error);
                      }
                    },
                  },
                  'Guardar precio y costo',
                ),
              ),
              h(
                'details',
                {},
                h('summary', {}, `Historial (${(item.history ?? []).length})`),
                // SQL sends null, not [], for an item whose price never changed.
                (item.history ?? []).map(row =>
                  h(
                    'p',
                    {},
                    `${saleDate(row.time)} · ${row.actorName} · Precio ${formatMoney(row.oldPriceMinor)} → ${formatMoney(row.newPriceMinor)} · Costo ${formatMoney(row.oldCostMinor ?? 0)} → ${formatMoney(row.newCostMinor)} · ${row.reason}`,
                  ),
                ),
              ),
            );
          }),
        );
      } catch (error) {
        showError(message, error);
      }
    }
    replace(
      root,
      h(
        'div',
        { class: 'page' },
        h(
          'section',
          { class: 'panel' },
          h('div', { class: 'actions' }, h('label', {}, 'Buscar prenda', query), h('button', { type: 'button', onclick: load }, 'Buscar')),
          message,
          list,
        ),
      ),
    );
    await load();
    return {};
  },
};
