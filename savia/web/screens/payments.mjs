import * as api from '../api.mjs';
import { formatMoney } from '../money.mjs';
import { h, replace, showError } from '../ui.mjs';
import { paymentDraft } from './payment-logic.mjs';
import { tenderName } from './sale-view.mjs';

/** Payment inputs stay within the existing ticket. No bank/card details are collected. */
export function paymentsPanel({ kinds, getTotal, onChange, branchId }) {
  let payments = [{ kind: 'cash', amount: '', received: '', reference: '' }];
  let customer = null;
  let credits = [];
  let customerRevision = 0;
  const rows = h('div', { id: 'payment-rows', class: 'form' });
  const customerField = h('input', { id: 'sale-customer-search', type: 'search', autocomplete: 'off' });
  const customerRows = h('div', { class: 'actions', id: 'sale-customers' });
  const customerStatus = h('p', { role: 'status', id: 'sale-customer-status' });
  const customerSummary = h('summary', {}, 'Cliente y anticipos (opcional)');
  const customerPanel = h(
    'details',
    { class: 'form', id: 'sale-customer-panel' },
    customerSummary,
    h('label', {}, 'Buscar cliente', customerField),
    h(
      'button',
      {
        type: 'button',
        onclick: async () => {
          const revision = ++customerRevision;
          customer = null;
          credits = [];
          onChange();
          try {
            if (customerField.value.trim().length < 2) throw new Error('Escriba al menos dos caracteres para buscar un cliente.');
            const found = await api.searchCustomers(customerField.value.trim());
            if (revision !== customerRevision) return;
            replace(
              customerRows,
              found.map(row =>
                h(
                  'button',
                  {
                    type: 'button',
                    onclick: async () => {
                      const selectedRevision = ++customerRevision;
                      customer = null;
                      onChange();
                      try {
                        const allocations = await api.searchCredits(row.customerCode ?? row.displayName);
                        if (selectedRevision !== customerRevision) return;
                        customer = row;
                        credits = allocations.filter(
                          credit => credit.customerId === row.customerId && credit.branchId === branchId && credit.currencyCode === 'NIO',
                        );
                        for (const payment of payments) payment.creditId = null;
                        customerStatus.className = 'ok';
                        customerStatus.textContent =
                          row.displayName +
                          (credits.length
                            ? ' · Elija un anticipo en el método de pago.'
                            : ' · Sin anticipos disponibles en esta sucursal.');
                        draw();
                        customerPanel.open = false;
                        onChange();
                      } catch (error) {
                        showError(customerStatus, error);
                      }
                    },
                  },
                  row.displayName,
                ),
              ),
            );
            customerStatus.className = 'muted';
            customerStatus.textContent = found.length ? 'Elija el cliente.' : 'Sin clientes con esa búsqueda.';
          } catch (error) {
            showError(customerStatus, error);
          }
        },
      },
      'Buscar cliente',
    ),
    customerRows,
    customerStatus,
  );
  customerField.addEventListener('input', () => {
    customerRevision++;
    customer = null;
    credits = [];
    customerStatus.textContent = '';
    replace(customerRows);
    onChange();
  });

  function draw() {
    replace(
      rows,
      payments.map((payment, index) => {
        const id = `payment-${index}`;
        const kind = h(
          'select',
          {
            id: `${id}-kind`,
            onchange: e => {
              payment.kind = e.target.value;
              draw();
              onChange();
            },
          },
          kinds.map(value => h('option', { value }, tenderName(value))),
        );
        kind.value = payment.kind;
        const input = (label, name, key, mode = 'decimal') =>
          h(
            'label',
            {},
            label,
            h('input', {
              id: name,
              value: payment[key],
              inputmode: mode,
              autocomplete: 'off',
              maxlength: key === 'reference' ? '120' : undefined,
              oninput: e => {
                payment[key] = e.target.value;
                onChange();
              },
            }),
          );
        return h(
          'div',
          { class: 'payment-row' },
          h('label', {}, `Método de pago ${index + 1}`, kind),
          payments.length > 1 ? input(`Importe del pago ${index + 1}`, `${id}-amount`, 'amount') : null,
          payment.kind === 'cash'
            ? input(
                `Efectivo recibido${payments.length > 1 ? ` ${index + 1}` : ''}`,
                index === 0 ? 'received' : `${id}-received`,
                'received',
              )
            : null,
          ['card', 'transfer'].includes(payment.kind)
            ? input(
                payment.kind === 'card' ? 'Número de voucher del POS (opcional)' : `Referencia del pago ${index + 1}`,
                `${id}-reference`,
                'reference',
                'text',
              )
            : null,
          payment.kind === 'credit'
            ? h(
                'label',
                {},
                `Anticipo del pago ${index + 1}`,
                h(
                  'select',
                  {
                    id: `${id}-credit`,
                    onchange: e => {
                      payment.creditId = e.target.value;
                      onChange();
                    },
                  },
                  h('option', { value: '' }, 'Elija un anticipo'),
                  credits.map(credit =>
                    h(
                      'option',
                      { value: credit.creditId, selected: credit.creditId === payment.creditId },
                      `${credit.branchName} · ${formatMoney(credit.availableMinor)} · ${credit.creditId.slice(0, 8)}`,
                    ),
                  ),
                ),
              )
            : null,
          payments.length > 1
            ? h(
                'button',
                {
                  type: 'button',
                  onclick: () => {
                    payments.splice(index, 1);
                    draw();
                    onChange();
                  },
                },
                `Quitar pago ${index + 1}`,
              )
            : null,
        );
      }),
    );
    customerSummary.textContent = customer ? `Cliente: ${customer.displayName}` : 'Cliente y anticipos (opcional)';
    if (payments.some(row => row.kind === 'credit') && !customer) customerPanel.open = true;
    if (payments.some(row => row.kind === 'credit')) {
      if (!customerPanel.parentNode) node.append(customerPanel);
    } else {
      customerPanel.remove();
      customer = null;
      credits = [];
    }
  }
  const node = h(
    'div',
    { class: 'form', id: 'payments' },
    rows,
    h(
      'button',
      {
        type: 'button',
        id: 'split-payment',
        onclick: () => {
          payments.push({ kind: kinds.includes('card') ? 'card' : kinds[0], amount: '', received: '', reference: '' });
          draw();
          onChange();
        },
      },
      'Dividir pago',
    ),
  );
  draw();
  return {
    node,
    snapshot() {
      return { payments: structuredClone(payments), customer: customer ? structuredClone(customer) : null };
    },
    async restore(saved) {
      payments = saved?.payments?.length ? structuredClone(saved.payments) : [{ kind: 'cash', amount: '', received: '', reference: '' }];
      customer = saved?.customer ?? null;
      credits = customer
        ? (await api.searchCredits(customer.customerCode ?? customer.displayName)).filter(
            c => c.customerId === customer.customerId && c.branchId === branchId && c.currencyCode === 'NIO',
          )
        : [];
      customerRevision++;
      draw();
      onChange();
    },
    get customerId() {
      return customer?.customerId;
    },
    draft() {
      return paymentDraft(getTotal(), payments, { supportedKinds: kinds, customerId: customer?.customerId });
    },
    reset() {
      payments = [{ kind: 'cash', amount: '', received: '', reference: '' }];
      customer = null;
      credits = [];
      customerRevision++;
      customerStatus.textContent = '';
      customerField.value = '';
      customerPanel.open = false;
      replace(customerRows);
      draw();
    },
  };
}
