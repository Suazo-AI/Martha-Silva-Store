import * as api from '../api.mjs';
import { formatMoney } from '../money.mjs';
import { attachScanField } from '../scan.mjs';
import { h, replace, showError, showOk } from '../ui.mjs';
import { uuid } from '../uuid-logic.mjs';
import { newCustomer, transferRequest } from './credit-transfers-logic.mjs';

export default {
  title: 'Clientes y anticipos',
  async mount(root, ctx) {
    let revision = 0;
    const field = h('input', { id: 'customer-search', type: 'search', placeholder: 'Buscar cliente', autocomplete: 'off' });
    const rows = h('tbody', { id: 'customer-rows' });
    const status = h('p', { role: 'status' });
    const balance = h('section', { class: 'panel', id: 'customer-balance', hidden: true });
    // One transfer id per request: a repeated click sends the same request, and the store keeps it once.
    const bringHere = credit => {
      let transferId = uuid();
      const amount = h('input', { 'aria-label': `Monto a traer · ${credit.branchName}`, inputmode: 'decimal', placeholder: 'Monto' });
      const reason = h('input', { 'aria-label': `Motivo · ${credit.branchName}`, maxlength: 400, placeholder: 'Motivo' });
      const send = async e => {
        const request = transferRequest(credit, ctx.me.branchId, amount.value, reason.value, transferId);
        if (request.error) {
          status.textContent = request.error;
          return;
        }
        e.target.disabled = true;
        try {
          await api.requestCreditTransfer(request.body);
          transferId = uuid();
          showOk(status, 'Traslado solicitado. El servidor central debe aprobarlo; véalo en Traslados de anticipo.');
        } catch (error) {
          showError(status, error);
        } finally {
          e.target.disabled = false;
        }
      };
      return h('span', { class: 'actions' }, amount, reason, h('button', { type: 'button', onclick: send }, 'Traer a esta sucursal'));
    };
    const consult = async customer => {
      try {
        const result = (await api.searchCredits(customer.customerCode ?? customer.displayName)).filter(
          row => row.customerId === customer.customerId,
        );
        balance.hidden = false;
        replace(
          balance,
          h('h2', {}, customer.displayName),
          h('h3', {}, 'Anticipos disponibles'),
          result.length
            ? result.map(row =>
                h(
                  'div',
                  { class: 'row', dataset: { credit: row.creditId, branch: row.branchId } },
                  h('span', {}, row.branchName),
                  h('strong', { class: 'credit-balance' }, formatMoney(row.availableMinor, row.currencyCode)),
                  h('small', {}, row.creditId),
                  row.branchId !== ctx.me.branchId ? h('small', {}, 'Disponible en otra sucursal') : null,
                  row.branchId !== ctx.me.branchId && ctx.me.branchId ? bringHere(row) : null,
                ),
              )
            : h('p', {}, 'Sin anticipos disponibles.'),
        );
      } catch (error) {
        showError(status, error);
      }
    };
    const load = async () => {
      const current = ++revision;
      try {
        if (field.value.trim().length < 2) {
          replace(rows);
          balance.hidden = true;
          status.textContent = 'Escriba al menos dos caracteres para buscar clientes.';
          return;
        }
        const customers = await api.searchCustomers(field.value.trim());
        if (current !== revision) return;
        status.textContent = customers.length
          ? `${customers.length} ${customers.length === 1 ? 'cliente' : 'clientes'}`
          : 'Sin clientes con esa búsqueda.';
        balance.hidden = true;
        replace(
          rows,
          customers.map(customer =>
            h(
              'tr',
              { dataset: { customer: customer.customerId } },
              h('td', {}, h('strong', {}, customer.displayName)),
              h('td', {}, customer.email ?? '—'),
              h('td', {}, h('button', { type: 'button', onclick: () => consult(customer) }, 'Consultar')),
            ),
          ),
        );
      } catch (error) {
        if (current === revision) showError(status, error);
      }
    };
    const fields = Object.fromEntries(
      [
        ['displayName', 'Nombre'],
        ['documentNumber', 'Cédula'],
        ['phone', 'Teléfono'],
        ['email', 'Correo'],
      ].map(([name, label]) => [name, h('input', { name, 'aria-label': label, placeholder: label, maxlength: 200 })]),
    );
    // One customer id per form: a repeated click creates one customer.
    let customerId = uuid();
    const create = async e => {
      e.preventDefault();
      const values = Object.fromEntries(Object.entries(fields).map(([name, input]) => [name, input.value]));
      const customer = newCustomer(values, customerId);
      if (customer.error) {
        status.textContent = customer.error;
        return;
      }
      try {
        await api.createCustomer(customer.body);
        customerId = uuid();
        for (const input of Object.values(fields)) input.value = '';
        field.value = customer.body.displayName;
        await load();
      } catch (error) {
        showError(status, error);
      }
    };
    replace(
      root,
      h(
        'div',
        { class: 'page' },
        h(
          'section',
          { class: 'panel' },
          h('h2', {}, 'Directorio de clientes'),
          h(
            'form',
            { class: 'row', id: 'customer-new', onsubmit: create },
            Object.values(fields),
            h('button', { type: 'submit' }, 'Nueva clienta'),
          ),
          h(
            'form',
            {
              class: 'row',
              onsubmit: e => {
                e.preventDefault();
                load();
              },
            },
            h('label', {}, 'Buscar cliente', field),
            h('button', { type: 'submit' }, 'Buscar clientes'),
          ),
          status,
          h(
            'div',
            { class: 'table-wrap' },
            h('table', {}, h('thead', {}, h('tr', {}, ...['Nombre', 'Correo', 'Acción'].map(x => h('th', { scope: 'col' }, x)))), rows),
          ),
        ),
        balance,
      ),
    );
    await load();
    const handleScan = code => {
      field.value = code;
      return load();
    };
    const detach = attachScanField(field, handleScan, { keepFocus: false });
    return {
      handleScan,
      unmount() {
        revision++;
        detach();
      },
    };
  },
};
