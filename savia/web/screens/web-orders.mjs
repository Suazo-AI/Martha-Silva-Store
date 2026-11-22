import * as api from '../api.mjs';
import { confirmAction } from '../confirm.mjs';
import { formatMoney } from '../money.mjs';
import { h, replace, showError } from '../ui.mjs';
import { saleDate } from './sale-view.mjs';
import { FILTERS, linesText, manualPayment, orderActions, statusLabel } from './web-orders-logic.mjs';

export default {
  title: 'Pedidos web',
  async mount(root, ctx) {
    const status = h('p', { role: 'alert' });
    const list = h('div', { id: 'web-orders', class: 'lines' });
    const filter = h(
      'select',
      { 'aria-label': 'Estado', onchange: () => load() },
      FILTERS.map(([value, label]) => h('option', { value }, label)),
    );

    const act = async (button, sentence, call) => {
      button.disabled = true;
      try {
        if (!(await confirmAction(sentence))) return;
        await call();
        await load();
      } catch (error) {
        showError(status, error);
      } finally {
        button.disabled = false;
      }
    };

    const actions = order => {
      const total = formatMoney(order.totalMinor, order.currency);
      const reference = h('input', { 'aria-label': `Referencia del pago · ${order.code}`, maxlength: 160, placeholder: 'Referencia del pago' });
      const buttons = {
        pay: h('button', {
          type: 'button',
          onclick: e => {
            const payment = manualPayment(order, reference.value);
            if (payment.error) {
              status.textContent = payment.error;
              reference.focus();
              return;
            }
            return act(e.target, `Se registrará el pago de ${total} del pedido ${order.code} con la referencia ${payment.body.reference}.`, () =>
              api.recordManualPayment(order.id, payment.body),
            );
          },
        }, 'Registrar pago'),
        cancel: h('button', {
          type: 'button',
          class: 'secondary',
          onclick: e => act(e.target, `Se cancelará el pedido ${order.code} y su mercadería volverá a la tienda web.`, () => api.cancelWebOrder(order.id)),
        }, 'Cancelar'),
        fulfill: h('button', {
          type: 'button',
          onclick: e => act(e.target, `Se marcará como enviado el pedido ${order.code}.`, () => api.fulfillWebOrder(order.id)),
        }, 'Marcar enviado'),
      };
      const chosen = orderActions(order);
      return chosen.length ? h('div', { class: 'actions' }, chosen.includes('pay') ? reference : null, chosen.map(a => buttons[a])) : null;
    };

    const card = order =>
      h(
        'section',
        { class: 'panel web-order', dataset: { order: order.id, status: order.status } },
        h('h2', {}, `${order.code} · ${statusLabel(order.status)}`),
        h('p', {}, `${formatMoney(order.totalMinor, order.currency)} · envío ${formatMoney(order.shippingMinor, order.currency)} · ${order.provider ?? ''}`),
        h('p', {}, linesText(order)),
        h('p', {}, [order.name, order.phone, order.email].filter(Boolean).join(' · ')),
        h('p', {}, [order.address, order.city, order.zone].filter(Boolean).join(' · ')),
        order.notes ? h('p', {}, order.notes) : null,
        h('p', { class: 'muted' }, [
          `Creado ${saleDate(order.createdAt)}`,
          order.status === 'reserved' && order.expiresAt ? `vence ${saleDate(order.expiresAt)}` : null,
          order.sourceStore ? `mercadería de ${order.sourceStore}` : null,
        ].filter(Boolean).join(' · ')),
        actions(order),
      );

    const load = async () => {
      try {
        const rows = await api.webOrders(filter.value);
        replace(list, rows.length ? rows.map(card) : h('p', {}, 'No hay pedidos web en este estado.'));
      } catch (error) {
        showError(status, error);
      }
    };

    if (ctx.me?.nodeKind !== 'Cloud') {
      replace(root, h('div', { class: 'page' }, h('p', {}, 'Los pedidos web se atienden en el servidor central.')));
      return {};
    }
    replace(root, h('div', { class: 'page' }, filter, status, list));
    await load();
    return { handleScan: () => ctx.notify('Los pedidos web no usan el escáner.') };
  },
};
