// Venta: scan or search to add garments, ticket always visible, cash received and change, Cobrar.
import * as api from '../api.mjs';
import { confirmAction } from '../confirm.mjs';
import { formatMoney, lineTotal } from '../money.mjs';
import { attachScanField, serialQueue } from '../scan.mjs';
import { clearMessage, device, flash, h, openModal, replace, showError } from '../ui.mjs';
import { paymentsPanel } from './payments.mjs';
import { supervisorApproval } from './return.mjs';
import {
  addToTicket,
  alignSellers,
  catalogMatches,
  discountedLines,
  freeSellers,
  itemFromLookup,
  MAX_SELLERS,
  needsDiscountApproval,
  removeLine,
  saleRequest,
  setQuantity,
  ticketTotal,
} from './sale-logic.mjs';
import { receiptContent } from './sale-view.mjs';
import { openTillPanel, syncTill } from './till-open.mjs';

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
      let catalog = [];
      let sellers = [];
      // One to three sellers per ticket. The first is the default for every garment; "Venta compartida" (supervision) adds more.
      let ticketSellers = [];
      const sellerPanel = h('div', { id: 'seller-panel', class: 'seller-panel' });
      const setSellers = (next, replaced = null) => {
        ticketSellers = next;
        lines = alignSellers(lines, ticketSellers, replaced);
        saleIds.reset();
        drawSellers();
        drawTicket();
      };
      const drawSellers = () =>
        replace(
          sellerPanel,
          ticketSellers.map((sellerId, index) =>
            h(
              'label',
              { class: 'seller-slot' },
              index === 0 ? 'Vendedor' : `Vendedor ${index + 1}`,
              h(
                'select',
                {
                  id: index === 0 ? 'sale-seller' : `sale-seller-${index + 1}`,
                  class: 'sale-seller',
                  'aria-label': index === 0 ? 'Vendedor' : `Vendedor ${index + 1}`,
                  onchange: e =>
                    setSellers(
                      ticketSellers.map((id, i) => (i === index ? e.target.value : id)),
                      { from: sellerId, to: e.target.value },
                    ),
                },
                freeSellers(sellers, ticketSellers, sellerId).map(s =>
                  h('option', { value: s.sellerId, selected: s.sellerId === sellerId }, s.name),
                ),
              ),
              index > 0
                ? h(
                    'button',
                    {
                      type: 'button',
                      class: 'remove-seller',
                      'aria-label': `Quitar vendedor ${index + 1}`,
                      onclick: () => setSellers(ticketSellers.filter((_, i) => i !== index)),
                    },
                    'Quitar',
                  )
                : null,
            ),
          ),
          ctx.isApprover && ticketSellers.length < MAX_SELLERS && freeSellers(sellers, ticketSellers).length
            ? h(
                'button',
                {
                  type: 'button',
                  id: 'shared-sale',
                  onclick: () => setSellers([...ticketSellers, freeSellers(sellers, ticketSellers)[0].sellerId]),
                },
                ticketSellers.length === 1 ? 'Venta compartida' : 'Agregar vendedor',
              )
            : null,
        );
      api
        .sellers()
        .then(rows => {
          sellers = rows;
          ticketSellers = rows.length ? [rows[0].sellerId] : [];
          drawSellers();
        })
        .catch(error => showError(status, error));
      let ticketPercent = 0;
      const effectiveLines = () => discountedLines(lines, ticketPercent);
      const effectiveTotal = () => ticketTotal(effectiveLines());
      const saleIds = api.retryIds('saleId'); // the same ticket keeps its saleId, so a retry is safe

      const field = h('input', {
        id: 'sale-search',
        type: 'search',
        autocomplete: 'off',
        spellcheck: 'false',
        placeholder: 'Escanee o busque por SKU o nombre',
      });
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
      const payments = paymentsPanel({
        kinds: api.saleTenderKinds,
        branchId: ctx.me.branchId,
        getTotal: effectiveTotal,
        onChange: () => {
          saleIds.reset();
          drawBalance();
        },
      });

      const drawTicket = () => {
        replace(
          ticketLines,
          lines.length === 0
            ? h('p', { class: 'muted' }, 'Toque una prenda o escanee su código para empezar.')
            : lines.map(line =>
                h(
                  'div',
                  { class: 'tline', dataset: { item: line.itemId } },
                  h(
                    'div',
                    { class: 'line-meta' },
                    h('strong', {}, line.name),
                    ticketSellers.length > 1
                      ? h(
                          'label',
                          {},
                          'Vendedor',
                          h(
                            'select',
                            {
                              class: 'line-seller',
                              'aria-label': `Vendedor de ${line.name}`,
                              onchange: e =>
                                update(lines.map(l => (l.ticketKey === line.ticketKey ? { ...l, sellerId: e.target.value } : l))),
                            },
                            sellers
                              .filter(s => ticketSellers.includes(s.sellerId))
                              .map(seller =>
                                h('option', { value: seller.sellerId, selected: seller.sellerId === line.sellerId }, seller.name),
                              ),
                          ),
                        )
                      : null,
                    h(
                      'span',
                      { class: 'num' },
                      formatMoney(
                        lineTotal(line.unitPriceMinor, line.quantity) -
                          (effectiveLines().find(l => (l.ticketKey ?? l.itemId) === (line.ticketKey ?? line.itemId))?.discountMinor ?? 0),
                      ),
                    ),
                  ),
                  h(
                    'div',
                    { class: 'line-meta' },
                    h(
                      'small',
                      {},
                      [line.size ? `Talla ${line.size}` : null, `SKU ${line.sku}`, `${formatMoney(line.unitPriceMinor)} c/u`]
                        .filter(Boolean)
                        .join(' · '),
                    ),
                    h(
                      'span',
                      { class: 'stepper' },
                      h(
                        'button',
                        {
                          type: 'button',
                          'aria-label': `Quitar una de ${line.name}`,
                          onclick: () => update(setQuantity(lines, line.ticketKey ?? line.itemId, line.quantity - 1)),
                        },
                        '−',
                      ),
                      h('label', { class: 'sr', for: `qty-${line.ticketKey ?? line.itemId}` }, `Cantidad de ${line.name}`),
                      h('input', {
                        id: `qty-${line.ticketKey ?? line.itemId}`,
                        class: 'qty-input',
                        inputmode: 'numeric',
                        value: String(line.quantity),
                        onchange: event => {
                          const next = setQuantity(lines, line.ticketKey ?? line.itemId, event.target.value.trim());
                          if (next === lines) {
                            event.target.value = String(line.quantity);
                            status.textContent = 'La cantidad debe ser un número entero de 1 o más.';
                          }
                          update(next);
                        },
                      }),
                      h(
                        'button',
                        {
                          type: 'button',
                          'aria-label': `Agregar una de ${line.name}`,
                          onclick: () => update(setQuantity(lines, line.ticketKey ?? line.itemId, line.quantity + 1)),
                        },
                        '+',
                      ),
                      h(
                        'button',
                        {
                          type: 'button',
                          class: 'remove',
                          'aria-label': `Quitar ${line.name} del ticket`,
                          onclick: () => update(removeLine(lines, line.ticketKey ?? line.itemId)),
                        },
                        'Quitar',
                      ),
                    ),
                    h(
                      'label',
                      { class: 'line-discount' },
                      'Descuento de línea (%)',
                      h('input', {
                        id: `discount-${line.ticketKey ?? line.itemId}`,
                        'aria-label': `Descuento de ${line.name} (%)`,
                        type: 'number',
                        min: 0,
                        max: 100,
                        value: line.discountPercent ?? 0,
                        onchange: e => {
                          const value = Number(e.target.value);
                          if (value < 0 || value + ticketPercent > 100 || !Number.isFinite(value)) {
                            e.target.value = line.discountPercent ?? 0;
                            status.textContent = 'El descuento combinado debe estar entre 0 y 100 %.';
                            return;
                          }
                          update(
                            lines.map(l =>
                              (l.ticketKey ?? l.itemId) === (line.ticketKey ?? line.itemId)
                                ? { ...l, discountAmountMinor: undefined, discountPercent: value }
                                : l,
                            ),
                          );
                        },
                      }),
                    ),
                  ),
                ),
              ),
        );
        total.textContent = formatMoney(effectiveTotal());
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

      let physicalConfirmed = false;
      const update = async next => {
        const units = (rows, itemId) => rows.filter(l => l.itemId === itemId).reduce((sum, l) => sum + l.quantity, 0);
        if (
          next.some(
            line =>
              units(next, line.itemId) > (catalog.flatMap(p => p.variants).find(v => v.itemId === line.itemId)?.available ?? 0) &&
              units(next, line.itemId) > units(lines, line.itemId),
          )
        ) {
          if (
            !(await confirmAction(
              'La cantidad supera la existencia del sistema. Se registrará una excepción de inventario al cobrar. Confirme que la prenda está en la tienda.',
            ))
          ) {
            drawTicket();
            return;
          }
          physicalConfirmed = true;
        }
        if (next !== lines) saleIds.reset();
        lines = next;
        drawTicket();
      };

      const add = async row => {
        const current = catalog.flatMap(p => p.variants).find(v => v.itemId === row.itemId);
        if (!current) {
          status.textContent = 'Vuelva a cargar el catálogo para consultar la prenda.';
          return;
        }
        row = { ...row, ...current };
        if (row.status && row.status !== 'active') {
          status.textContent = `${row.variantName ?? row.sku} no está a la venta (estado: ${row.status}).`;
          return;
        }
        clearMessage(status);
        receipt.hidden = true;
        if (!ticketSellers.length) {
          status.textContent = 'Elija el vendedor antes de agregar la prenda.';
          return;
        }
        await update(addToTicket(lines, { ...itemFromLookup(row), sellerId: ticketSellers[0] }));
        const el = ticketLines.querySelector(`[data-item="${row.itemId}"]`);
        if (el) flash(el);
      };

      const typeFilter = h('select', { id: 'sale-type', onchange: () => drawCatalog() }, h('option', { value: '' }, 'Todos los tipos'));
      const sizeFilter = h('select', { id: 'sale-size', onchange: () => drawCatalog() }, h('option', { value: '' }, 'Todas las tallas'));
      const filters = h(
        'div',
        { class: 'catalog-filters' },
        h('label', {}, 'Tipo de prenda', typeFilter),
        h('label', {}, 'Talla', sizeFilter),
      );
      const choose = async product => {
        const variants = product.variants.filter(v => !sizeFilter.value || v.sizeCode === sizeFilter.value);
        if (variants.length === 1) {
          await add(variants[0]);
          return;
        }
        const selected = await openModal((body, close) =>
          replace(
            body,
            h('h2', { id: 'modal-title' }, product.name),
            h('p', {}, 'Elija la talla para agregar al ticket.'),
            h(
              'div',
              { class: 'sizes', id: 'sale-sizes' },
              variants.map(v =>
                h(
                  'button',
                  { type: 'button', dataset: { item: v.itemId }, onclick: () => close(v) },
                  `Talla ${v.sizeCode ?? 'única'} · ${v.available > 0 ? `${v.available} disponibles` : 'Sin existencia en sistema'} · ${formatMoney(v.unitPriceMinor)}`,
                ),
              ),
            ),
            h('button', { type: 'button', onclick: () => close() }, 'Volver'),
          ),
        );
        if (selected) await add(selected);
      };
      const drawCatalog = () => {
        const visible = catalog.filter(p =>
          catalogMatches(p, { type: typeFilter.value, size: sizeFilter.value, query: field.value.trim() }),
        );
        replace(
          cards,
          visible.length
            ? visible.map(product => {
                const variants = product.variants.filter(v => !sizeFilter.value || v.sizeCode === sizeFilter.value);
                const available = variants.reduce((sum, v) => sum + v.available, 0);
                return h(
                  'button',
                  {
                    type: 'button',
                    class: 'product',
                    'aria-label': `${product.name} · ${available > 0 ? `${available} disponibles` : 'Sin existencia en sistema'}`,
                    dataset: { product: product.productId, type: product.type },
                    onclick: () => choose(product),
                  },
                  h(
                    'span',
                    { class: 'product-info' },
                    h('strong', {}, product.name),
                    h('small', {}, `${product.type} · Tallas ${variants.map(v => v.sizeCode ?? 'única').join(', ')}`),
                    h('strong', { class: 'num' }, formatMoney(Math.min(...variants.map(v => v.unitPriceMinor)))),
                    h(
                      'span',
                      { class: available ? 'stock-available' : 'out' },
                      available ? `${available} disponibles` : 'Sin existencia en sistema',
                    ),
                  ),
                );
              })
            : h('p', { class: 'muted' }, 'No hay prendas con estos filtros. Cambie el tipo, la talla o la búsqueda.'),
        );
      };
      const loadCatalog = async () => {
        try {
          catalog = await api.catalogItems();
          const selectedType = typeFilter.value,
            selectedSize = sizeFilter.value;
          replace(
            typeFilter,
            h('option', { value: '' }, 'Todos los tipos'),
            [...new Set(catalog.map(p => p.type))].sort().map(type => h('option', { value: type }, type)),
          );
          replace(
            sizeFilter,
            h('option', { value: '' }, 'Todas las tallas'),
            [...new Set(catalog.flatMap(p => p.variants.map(v => v.sizeCode)).filter(Boolean))].map(size =>
              h('option', { value: size }, size),
            ),
          );
          typeFilter.value = selectedType;
          sizeFilter.value = selectedSize;
          drawCatalog();
        } catch (error) {
          showError(status, error, 'Vuelva a Venta para cargar el catálogo.');
        }
      };
      field.addEventListener('input', () => drawCatalog());
      const drawCards = rows => {
        drawCatalog();
        status.textContent = rows.length ? 'Elija una prenda y su talla.' : 'Cambie el nombre o SKU para buscar otra prenda.';
      };

      const find = async text => {
        clearMessage(status);
        try {
          const found = await api.lookup(text);
          if (found.length === 1) {
            await add(found[0]);
            field.value = '';
            drawCatalog();
            return;
          }
          if (found.length > 1) {
            field.value = '';
            choose({
              name: 'Elija una prenda',
              variants: found.map(row => ({ ...row, ...catalog.flatMap(p => p.variants).find(v => v.itemId === row.itemId) })),
            });
            return;
          }
        } catch (error) {
          showError(status, error);
          return;
        }
        try {
          const rows = await api.searchProducts(text);
          field.value = text;
          drawCards(rows);
          if (rows.length === 0) status.textContent = `No se encontró «${text}». Cambie el nombre o SKU para buscar otra prenda.`;
        } catch (error) {
          showError(status, error);
        }
      };
      const queue = serialQueue(find);
      handle.handleScan = code => queue.push(code);

      pay.addEventListener('click', async () => {
        let draft;
        try {
          draft = payments.draft();
        } catch (error) {
          showError(payMessage, error);
          return;
        }
        const { saleId } = saleIds([effectiveLines(), draft.tenders, payments.customerId]);
        pay.disabled = true;
        clearMessage(payMessage);
        let approvalToken;
        let postedLines = effectiveLines();
        let discountReason = discountReasonInput.value.trim();
        try {
          if (
            !physicalConfirmed &&
            postedLines.some(line => line.quantity > (catalog.flatMap(p => p.variants).find(v => v.itemId === line.itemId)?.available ?? 0))
          ) {
            if (
              !(await confirmAction(
                'La cantidad supera la existencia del sistema. Se registrará una excepción de inventario al cobrar. Confirme que la prenda está en la tienda.',
              ))
            ) {
              drawBalance();
              return;
            }
            physicalConfirmed = true;
          }
          if (needsDiscountApproval(effectiveLines()) && !ctx.isApprover) {
            const approval = await supervisorApproval('descuento', postedLines);
            if (!approval) {
              drawBalance();
              return;
            }
            approvalToken = approval.token;
            discountReason = approval.reason;
            postedLines = approval.lines;
            // The manager may change the requested amount. Refresh payments before charging.
            if (ticketTotal(postedLines) !== effectiveTotal()) {
              lines = postedLines.map(line => ({ ...line, discountAmountMinor: line.discountMinor, discountPercent: 0 }));
              ticketPercent = 0;
              discountInput.value = 0;
              drawTicket();
              draft = payments.draft();
            }
          }
          if (needsDiscountApproval(postedLines) && !discountReason) throw new Error('Indique el motivo del descuento.');
          const response = await api.postSale(
            {
              ...saleRequest({ saleId, tillId: till.tillId, lines: postedLines, tenders: draft.tenders, customerId: payments.customerId }),
              discountReason: discountReason || null,
              stockExceptionNote: physicalConfirmed ? 'El sistema decía 0 y había existencia física. Confirmado en tienda.' : null,
            },
            approvalToken,
          );
          showReceipt(response, draft.changeMinor);
          lines = [];
          physicalConfirmed = false;
          discountReasonInput.value = '';
          ticketSellers = ticketSellers.slice(0, 1);
          drawSellers();
          ticketPercent = 0;
          discountInput.value = 0;
          saleIds.reset();
          payments.reset();
          drawTicket();
          await loadCatalog();
          try {
            const detail = await api.getSale(response.saleId);
            replace(
              receipt,
              h('h2', {}, 'Venta registrada'),
              ...receiptContent({ ...detail, branchName: ctx.branchName }),
              h(
                'div',
                { class: 'actions no-print' },
                h('button', { type: 'button', onclick: () => window.print() }, 'Reimprimir'),
                h(
                  'button',
                  { type: 'button', id: 'open-receipt', onclick: () => ctx.go(`recibo?sale=${encodeURIComponent(response.saleId)}`) },
                  'Ver recibo',
                ),
              ),
            );
          } catch (error) {
            receipt.append(
              h('p', { class: 'warning' }, `La venta está registrada. Abra el recibo para consultar el detalle. ${error.message}`),
            );
          }
        } catch (error) {
          const next =
            {
              'stock.insufficient': 'Confirme la existencia física y vuelva a cobrar.',
              'sale.price_changed': 'El precio cambió. Quite la prenda y vuelva a escanearla.',
              'cash.till_not_open': 'Abra la caja de nuevo.',
              'cash.till_mismatch': 'Abra la caja de nuevo.',
            }[error.code] ?? (error.network ? 'Pulse Cobrar otra vez: la venta no se duplica.' : 'Revise el ticket y vuelva a intentar.');
          drawBalance();
          if (error.code === 'stock.insufficient') {
            await loadCatalog();
            physicalConfirmed = false;
          }
          showError(payMessage, error, next);
          if (error.code === 'cash.till_not_open' || error.code === 'cash.till_mismatch') ctx.till.set(null);
        } finally {
          if (approvalToken) {
            try {
              await api.endApproval(approvalToken);
            } catch {
              /* server expiry remains in force */
            }
          }
        }
      });

      const showReceipt = (sale, changeMinor) => {
        receipt.hidden = false;
        replace(
          receipt,
          h('h2', {}, 'Venta registrada'),
          h('div', { class: 'row' }, h('span', {}, 'Subtotal'), h('strong', { class: 'num' }, formatMoney(sale.subtotalMinor))),
          h(
            'div',
            { class: 'row' },
            h('span', {}, 'Total cobrado'),
            h('strong', { class: 'num', id: 'receipt-total' }, formatMoney(sale.totalMinor)),
          ),
          h(
            'div',
            { class: 'row' },
            h('span', {}, 'Cambio a entregar'),
            h('strong', { class: 'num', id: 'receipt-change' }, formatMoney(changeMinor)),
          ),
          h('p', { class: 'muted num' }, `Venta ${sale.saleId}`),
          h(
            'button',
            {
              type: 'button',
              class: 'primary',
              id: 'open-receipt',
              onclick: () => ctx.go(`recibo?sale=${encodeURIComponent(sale.saleId)}`),
            },
            'Ver recibo',
          ),
        );
        flash(receipt);
      };

      const discountReasonInput = h('input', { id: 'discount-reason', maxlength: 250, placeholder: 'Motivo autorizado por la gerente' });
      const discountInput = h('input', {
        id: 'ticket-discount',
        type: 'number',
        min: 0,
        max: 100,
        value: 0,
        onchange: e => {
          const value = Number(e.target.value);
          if (!Number.isFinite(value) || value < 0 || lines.some(l => value + (l.discountPercent ?? 0) > 100)) {
            e.target.value = ticketPercent;
            status.textContent = 'Revise el descuento: el combinado no puede superar 100 %.';
            return;
          }
          ticketPercent = value;
          lines = lines.map(line => ({ ...line, discountAmountMinor: undefined }));
          saleIds.reset();
          drawTicket();
        },
      });
      const parked = () => {
        const saved = device.get('parkedTickets');
        return saved?.tillId === till.tillId ? saved.tickets : [];
      };
      const clearTicket = () => {
        lines = [];
        ticketSellers = ticketSellers.slice(0, 1);
        drawSellers();
        physicalConfirmed = false;
        ticketPercent = 0;
        discountInput.value = 0;
        saleIds.reset();
        payments.reset();
        drawTicket();
      };
      const ticketActions = h(
        'div',
        { class: 'actions ticket-actions' },
        h(
          'button',
          {
            type: 'button',
            id: 'park-ticket',
            onclick: () => {
              if (!lines.length) {
                status.textContent = 'Agregue una prenda antes de guardar.';
                return;
              }
              const tickets = parked();
              tickets.push({
                id: api.uuid(),
                name: `Ticket ${tickets.length + 1}`,
                lines: structuredClone(lines),
                sellers: [...ticketSellers],
                ticketPercent,
                payment: payments.snapshot(),
              });
              device.set('parkedTickets', { tillId: till.tillId, tickets });
              clearTicket();
              status.textContent = 'Ticket guardado. Abra Tickets guardados para recuperarlo.';
            },
          },
          'Guardar ticket',
        ),
        h(
          'button',
          {
            type: 'button',
            id: 'saved-tickets',
            onclick: () => {
              if (lines.length) {
                status.textContent = 'Guarde o vacíe el ticket actual antes de restaurar otro.';
                return;
              }
              openModal((body, close) =>
                replace(
                  body,
                  h('h2', { id: 'modal-title' }, 'Tickets guardados'),
                  parked().length
                    ? parked().map(saved =>
                        h(
                          'button',
                          {
                            type: 'button',
                            class: 'restore-ticket',
                            onclick: async () => {
                              try {
                                await loadCatalog();
                                lines = structuredClone(saved.lines);
                                ticketPercent = saved.ticketPercent;
                                discountInput.value = ticketPercent;
                                ticketSellers = (saved.sellers ?? [...new Set(lines.map(l => l.sellerId).filter(Boolean))])
                                  .filter(id => sellers.some(s => s.sellerId === id))
                                  .slice(0, MAX_SELLERS);
                                if (!ticketSellers.length && sellers.length) ticketSellers = [sellers[0].sellerId];
                                lines = alignSellers(lines, ticketSellers);
                                drawSellers();
                                await payments.restore(saved.payment);
                                saleIds.reset();
                                drawTicket();
                                device.set('parkedTickets', { tillId: till.tillId, tickets: parked().filter(t => t.id !== saved.id) });
                                close();
                              } catch (error) {
                                showError(status, error, 'Revise el cliente antes de cobrar.');
                                close();
                              }
                            },
                          },
                          `${saved.name} · ${saved.lines.reduce((sum, l) => sum + l.quantity, 0)} prendas`,
                        ),
                      )
                    : h('p', {}, 'No hay tickets guardados. Agregue prendas y pulse Guardar ticket.'),
                  h('button', { type: 'button', onclick: () => close() }, 'Volver'),
                ),
              );
            },
          },
          'Tickets guardados',
        ),
        h(
          'button',
          {
            type: 'button',
            id: 'empty-ticket',
            onclick: async () => {
              if (await confirmAction(`Se vaciará el ticket de ${formatMoney(effectiveTotal())}.`)) clearTicket();
            },
          },
          'Vaciar ticket',
        ),
      );

      replace(
        root,
        h(
          'div',
          { class: 'sale' },
          h(
            'section',
            { class: 'catalog', 'aria-label': 'Buscar prendas' },
            h('label', { for: 'sale-search', class: 'sr' }, 'Escanear o buscar por SKU o nombre'),
            field,
            fieldNote,
            sellerPanel,
            filters,
            status,
            cards,
          ),
          h(
            'aside',
            { class: 'ticket', 'aria-labelledby': 'ticket-heading' },
            h('h2', { id: 'ticket-heading' }, 'Ticket'),
            ticketActions,
            ticketLines,
            h(
              'div',
              { class: 'checkout' },
              h('label', { class: 'ticket-discount' }, 'Descuento solicitado (%)', discountInput),
              ctx.isApprover
                ? h('label', {}, 'Motivo del descuento', discountReasonInput)
                : h('small', {}, 'Todo descuento requiere aprobación de la gerente.'),
              h('div', { class: 'total' }, h('span', {}, 'Total'), total),
              payments.node,
              h('div', { class: 'money-row', 'aria-live': 'polite', 'aria-atomic': 'true' }, balanceLabel, balance),
              payMessage,
              pay,
            ),
            receipt,
          ),
        ),
      );
      field.setAttribute('aria-describedby', 'sale-search-help');
      detach = attachScanField(field, code => handle.handleScan(code));
      drawTicket();
      loadCatalog();
    };

    const { till } = await syncTill(ctx);
    if (till?.tillId) renderSale();
    else await renderOpen();
    return handle;
  },
};
