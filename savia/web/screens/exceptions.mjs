import * as api from '../api.mjs';
import { confirmAction } from '../confirm.mjs';
import { h, replace, showError } from '../ui.mjs';
import { saleDate } from './sale-view.mjs';

export default {
  title: 'Excepciones de inventario',
  async mount(root, ctx) {
    const status = h('p', { role: 'alert' });
    const list = h('div', { id: 'stock-exceptions', class: 'lines' });
    const load = async () => {
      try {
        const rows = await api.stockExceptions();
        replace(
          list,
          rows.length
            ? rows.map(row => {
                const reason = h('input', {
                  'aria-label': `Resultado de revisión · ${row.sku}`,
                  maxlength: 500,
                  placeholder: 'Resultado de la revisión',
                });
                return h(
                  'section',
                  { class: 'panel exception-item', dataset: { exception: row.id, reviewed: String(Boolean(row.reviewedAt)) } },
                  h('h2', {}, row.name),
                  h('p', {}, `SKU ${row.sku} · Faltaban ${row.quantityShort} en el sistema`),
                  h('p', {}, `${row.cashierName} · ${saleDate(row.createdAt)}`),
                  h('p', {}, row.note),
                  row.reviewedAt
                    ? h('p', { class: 'ok' }, `Revisado · ${row.reviewNote}`)
                    : h(
                        'div',
                        { class: 'actions' },
                        reason,
                        h(
                          'button',
                          {
                            type: 'button',
                            onclick: async e => {
                              if (!reason.value.trim()) {
                                status.textContent = 'Indique el resultado de la revisión.';
                                reason.focus();
                                return;
                              }
                              e.target.disabled = true;
                              try {
                                if (
                                  !(await confirmAction(
                                    `Se marcará como revisada la excepción de ${row.quantityShort} unidades: ${reason.value.trim()}.`,
                                  ))
                                )
                                  return;
                                await api.reviewStockException(row.id, reason.value.trim());
                                await load();
                              } catch (error) {
                                showError(status, error);
                                e.target.disabled = false;
                              }
                            },
                          },
                          'Revisado',
                        ),
                      ),
                );
              })
            : h('p', {}, 'No hay excepciones de inventario pendientes.'),
        );
      } catch (error) {
        showError(status, error);
      }
    };
    replace(
      root,
      h('div', { class: 'page' }, h('p', {}, 'Ventas con existencia física confirmada y faltantes en el sistema.'), status, list),
    );
    await load();
    return { handleScan: () => ctx.notify('Revise la prenda y registre el resultado.') };
  },
};
