import * as api from '../api.mjs';
import { h, replace, showError } from '../ui.mjs';
import { receiptContent } from './sale-view.mjs';

export const routeSaleId = () => new URLSearchParams(location.hash.split('?')[1] ?? '').get('sale');

export default {
  title: 'Recibo',
  async mount(root, ctx) {
    const status = h('p', { role: 'alert' });
    replace(root, h('div', { class: 'page receipt-page' }, status));
    try {
      const id = routeSaleId();
      if (!id) throw new Error('Abra una venta desde Historial.');
      const sale = await api.getSale(id);
      replace(
        root,
        h(
          'div',
          { class: 'page receipt-page' },
          h('section', { class: 'panel receipt-paper', id: 'receipt' }, ...receiptContent({ ...sale, branchName: ctx.branchName })),
          h(
            'div',
            { class: 'actions no-print' },
            h('button', { type: 'button', id: 'reprint', onclick: () => window.print() }, 'Reimprimir'),
            h('button', { type: 'button', onclick: () => ctx.go('historial') }, 'Cerrar recibo'),
            h('button', { type: 'button', class: 'primary', onclick: () => ctx.go('venta') }, 'Nueva venta'),
          ),
        ),
      );
    } catch (error) {
      showError(status, error);
    }
    return { handleScan: () => ctx.notify('Cierre el recibo para escanear una venta.') };
  },
};
