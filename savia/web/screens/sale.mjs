// Venta: scan or search to add garments, ticket always visible, cash received and change, Cobrar.
import * as api from '../api.mjs';
import { h, replace, photo, showError, clearMessage, flash } from '../ui.mjs';
import { attachScanField, serialQueue } from '../scan.mjs';
import { formatMoney, lineTotal } from '../money.mjs';
import { addToTicket, setQuantity, removeLine, ticketTotal, saleRequest, itemFromLookup } from './sale-logic.mjs';
import { openTillPanel, syncTill } from './till-open.mjs';
import { paymentsPanel } from './payments.mjs';
import { receiptContent } from './sale-view.mjs';

export default {
  title: 'Venta',
  async mount(root, ctx) {
    let detach = () => {};
    const handle = { handleScan: () => ctx.notify('Abra la caja antes de vender.'), unmount: () => detach() };

    const renderOpen = async () => {
      detach();
      replace(root, h('div', { class: 'page' }, await openTillPanel(ctx, renderSale)));
      root.querySelector('#till-opening')?.focus();
    };

    const renderSale = () => {
      detach();
      const till = ctx.till.get();
      let lines = [];
      let attempt = null;          // { saleId, key } kept while the ticket does not change, so a retry is safe

      const field = h('input', { id: 'sale-search', type: 'search', autocomplete: 'off', spellcheck: 'false', placeholder: 'Escanee o busque por SKU o nombre' });
      const fieldNote = h('p', { class: 'muted', id: 'sale-search-help' }, 'Escanee el código o escriba y pulse Enter.');
      const status = h('p', { class: 'error', role: 'alert' });
      const cards = h('div', { class: 'cards', id: 'cards', 'aria-live': 'polite' });
      const ticketLines = h('div', { id: 'ticket-lines' });
      const total = h('strong', { id: 'total', 'aria-live': 'polite' });
      const balanceLabel = h('span', { id: 'balance-label' }, 'Cambio');
      const balance = h('strong', { id: 'balance' });
      const payMessage = h('p', { class: 'error', role: 'alert' });
      const pay = h('button', { class: 'primary big', type: 'button', id: 'pay' }, 'Cobrar');
      const receipt = h('section', { class: 'panel receipt-paper', id: 'receipt', hidden: true, 'aria-live': 'polite' });
      const payments = paymentsPanel({ kinds: api.saleTenderKinds, branchId: ctx.me.branchId, getTotal: () => ticketTotal(lines), onChange: () => { attempt = null; drawBalance(); } });

      const drawTicket = () => {
        replace(ticketLines, lines.length === 0 ? h('p', { class: 'muted' }, 'Escanee una prenda para empezar.') : lines.map(line =>
          h('div', { class: 'tline', dataset: { item: line.itemId } },
            h('div', { class: 'line-meta' },
              h('strong', {}, line.name),
              h('span', { class: 'num' }, formatMoney(lineTotal(line.unitPriceMinor, line.quantity)))),
            h('div', { class: 'line-meta' },
              h('small', {}, [line.size ? `Talla ${line.size}` : null, `SKU ${line.sku}`, `${formatMoney(line.unitPriceMinor)} c/u`].filter(Boolean).join(' · ')),
              h('span', { class: 'stepper' },
                h('button', { type: 'button', 'aria-label': `Quitar una de ${line.name}`, onclick: () => update(setQuantity(lines, line.itemId, line.quantity - 1)) }, '−'),
                h('label', { class: 'sr', for: `qty-${line.itemId}` }, `Cantidad de ${line.name}`),
                h('input', { id: `qty-${line.itemId}`, class: 'qty-input', inputmode: 'numeric', value: String(line.quantity),
                  onchange: event => {
                    const next = setQuantity(lines, line.itemId, event.target.value.trim());
                    if (next === lines) { event.target.value = String(line.quantity); status.textContent = 'La cantidad debe ser un número entero de 1 o más.'; }
                    update(next);
                  } }),
                h('button', { type: 'button', 'aria-label': `Agregar una de ${line.name}`, onclick: () => update(setQuantity(lines, line.itemId, line.quantity + 1)) }, '+'),
                h('button', { type: 'button', class: 'remove', 'aria-label': `Quitar ${line.name} del ticket`, onclick: () => update(removeLine(lines, line.itemId)) }, 'Quitar')))))
        );
        total.textContent = formatMoney(ticketTotal(lines));
        drawBalance();
      };

      const drawBalance = () => {
        balanceLabel.textContent = 'Cambio';
        try {
          const draft = payments.draft();
          balance.textContent = formatMoney(draft.changeMinor);
          balance.classList.remove('short');
          pay.disabled = !lines.length;
          payMessage.textContent = '';
        } catch (error) {
          balance.textContent = '—';
          pay.disabled = true;
          payMessage.textContent = lines.length ? error.message : '';
        }
      };

      const update = next => {
        if (next !== lines) attempt = null;
        lines = next;
        drawTicket();
      };

      const add = row => {
        if (row.status && row.status !== 'active') {
          status.textContent = `${row.variantName ?? row.sku} no está a la venta (estado: ${row.status}).`;
          return;
        }
        clearMessage(status);
        receipt.hidden = true;
        update(addToTicket(lines, itemFromLookup(row)));
        const el = ticketLines.querySelector(`[data-item="${row.itemId}"]`);
        if (el) flash(el);
      };

      const drawCards = rows => replace(cards, rows.map(row => h('button', { type: 'button', class: 'product', onclick: () => add(row) },
        photo(row.sku),
        h('span', { class: 'product-info' },
          h('strong', {}, row.productName ?? row.variantName),
          h('small', {}, [row.sizeCode ? `Talla ${row.sizeCode}` : null, `SKU ${row.sku}`].filter(Boolean).join(' · ')),
          h('strong', { class: 'num' }, formatMoney(row.unitPriceMinor)),
          row.isSample ? h('span', { class: 'tag sample' }, 'MUESTRA') : null))));

      const find = async text => {
        clearMessage(status);
        try {
          const found = await api.lookup(text);
          if (found.length === 1) { add(found[0]); return; }
          if (found.length > 1) { drawCards(found); status.textContent = 'El código coincide con varias prendas. Elija una.'; return; }
        } catch (error) {
          showError(status, error); return;
        }
        try {
          const rows = await api.searchProducts(text);
          drawCards(rows);
          if (rows.length === 0) status.textContent = `No se encontró «${text}».`;
        } catch (error) {
          showError(status, error);
        }
      };
      const queue = serialQueue(find);
      handle.handleScan = code => queue.push(code);

      pay.addEventListener('click', async () => {
        let draft;
        try { draft = payments.draft(); } catch (error) { showError(payMessage, error); return; }
        const key = JSON.stringify([lines.map(l => [l.itemId, l.quantity, l.unitPriceMinor]), draft.tenders, payments.customerId]);
        if (!attempt || attempt.key !== key) attempt = { saleId: api.uuid(), key };
        pay.disabled = true;
        clearMessage(payMessage);
        try {
          const response = await api.postSale(saleRequest({ saleId: attempt.saleId, tillId: till.tillId, lines, tenders: draft.tenders, customerId: payments.customerId }));
          showReceipt(response, draft.changeMinor);
          lines = [];
          attempt = null;
          payments.reset();
          drawTicket();
          try {
            const detail = await api.saleReceipt(response.saleId);
            replace(receipt, h('h2', {}, 'Venta registrada'), ...receiptContent({ ...detail, branchName: ctx.branchName }),
              h('div', { class: 'actions no-print' },
                h('button', { type: 'button', onclick: () => window.print() }, 'Reimprimir'),
                h('button', { type: 'button', id: 'open-receipt', onclick: () => ctx.go(`recibo?sale=${encodeURIComponent(response.saleId)}`) }, 'Ver recibo')));
          } catch (error) {
            receipt.append(h('p', { class: 'warning' }, `La venta está registrada. Abra el recibo para consultar el detalle. ${error.message}`));
          }
        } catch (error) {
          const next = {
            'stock.insufficient': 'Quite prendas sin existencia o revise el inventario.',
            'sale.price_changed': 'El precio cambió. Quite la prenda y vuelva a escanearla.',
            'cash.till_not_open': 'Abra la caja de nuevo.',
            'cash.till_mismatch': 'Abra la caja de nuevo.',
          }[error.code] ?? (error.network ? 'Pulse Cobrar otra vez: la venta no se duplica.' : 'Revise el ticket y vuelva a intentar.');
          showError(payMessage, error, next);
          if (error.code === 'cash.till_not_open' || error.code === 'cash.till_mismatch') ctx.till.set(null);
          drawBalance();
        }
      });

      const showReceipt = (sale, changeMinor) => {
        receipt.hidden = false;
        replace(receipt,
          h('h2', {}, 'Venta registrada'),
          h('div', { class: 'row' }, h('span', {}, 'Subtotal'), h('strong', { class: 'num' }, formatMoney(sale.subtotalMinor))),
          sale.taxMinor ? h('div', { class: 'row' }, h('span', {}, 'Impuesto'), h('strong', { class: 'num' }, formatMoney(sale.taxMinor))) : null,
          h('div', { class: 'row' }, h('span', {}, 'Total cobrado'), h('strong', { class: 'num', id: 'receipt-total' }, formatMoney(sale.totalMinor))),
          h('div', { class: 'row' }, h('span', {}, 'Cambio a entregar'), h('strong', { class: 'num', id: 'receipt-change' }, formatMoney(changeMinor))),
          h('p', { class: 'muted num' }, `Venta ${sale.saleId}`),
          h('button', { type: 'button', class: 'primary', id: 'open-receipt', onclick: () => ctx.go(`recibo?sale=${encodeURIComponent(sale.saleId)}`) }, 'Ver recibo'));
        flash(receipt);
      };

      replace(root, h('div', { class: 'sale' },
        h('section', { class: 'catalog', 'aria-label': 'Buscar prendas' },
          h('label', { for: 'sale-search', class: 'sr' }, 'Escanear o buscar por SKU o nombre'),
          field, fieldNote, status, cards),
        h('aside', { class: 'ticket', 'aria-labelledby': 'ticket-heading' },
          h('h2', { id: 'ticket-heading' }, 'Ticket'),
          ticketLines,
          h('div', { class: 'checkout' },
            h('div', { class: 'total' }, h('span', {}, 'Total'), total),
            payments.node,
            h('div', { class: 'money-row', 'aria-live': 'polite', 'aria-atomic': 'true' }, balanceLabel, balance),
            payMessage, pay),
          receipt)));
      field.setAttribute('aria-describedby', 'sale-search-help');
      detach = attachScanField(field, code => handle.handleScan(code));
      drawTicket();
    };

    const { till } = await syncTill(ctx);
    if (till?.tillId) renderSale(); else await renderOpen();
    return handle;
  },
};
