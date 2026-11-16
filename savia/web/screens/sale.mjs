// Venta: scan or search to add garments, ticket always visible, cash received and change, Cobrar.
import * as api from '../api.mjs';
import { confirmAction } from '../confirm.mjs';
import { formatMoney, lineTotal } from '../money.mjs';
import {
  actorScope,
  clearPending,
  matchesReceipt,
  persistPending,
  readPending,
  sameGuid,
  sameScope,
  validResponse,
} from '../sale-recovery.mjs';
import { attachScanField, serialQueue } from '../scan.mjs';
import { clearMessage, device, flash, h, openModal, replace, showError } from '../ui.mjs';
import { paymentsPanel } from './payments.mjs';
import { supervisorApproval } from './return.mjs';
import {
  addToTicket,
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

const mounts = new WeakMap();

export default {
  title: 'Venta',
  async mount(root, ctx) {
    const actor = ctx.me;
    const mountId = {};
    mounts.set(root, mountId);
    const token = api.getToken();
    const scope = actorScope(actor);
    let alive = true;
    const current = () =>
      alive &&
      ctx.isCurrent?.() !== false &&
      mounts.get(root) === mountId &&
      ctx.me === actor &&
      api.getToken() === token &&
      sameScope(scope, actorScope(ctx.me));
    const tillCtx = Object.create(ctx);
    tillCtx.isCurrent = current;
    let detach = () => {};
    const handle = {
      handleScan: () => {},
      unmount: () => {
        alive = false;
        detach();
      },
    };
    const recovery = record => {
      detach();
      handle.handleScan = () => {};
      const message = h('p', { role: 'alert' }, 'Venta pendiente. No vuelva a cobrar. Consulte el recibo o avise a la gerente.');
      const lookup = h(
        'button',
        {
          type: 'button',
          id: 'consult-receipt',
          onclick: async () => {
            if (!current()) return;
            lookup.disabled = true;
            try {
              const detail = await api.getSale(record.body.saleId);
              if (!current()) return;
              if (!matchesReceipt(detail, record)) throw new Error('El recibo no coincide con la caja y cajera originales.');
              replace(
                root,
                h(
                  'section',
                  { class: 'panel receipt-paper', role: 'status' },
                  h('h2', {}, 'Venta registrada'),
                  ...receiptContent({ ...detail, branchName: ctx.branchName }),
                  h('p', {}, `Cambio registrado: ${formatMoney(record.changeMinor)}`),
                  h(
                    'button',
                    {
                      type: 'button',
                      id: 'finish-recovery',
                      onclick: async () => {
                        if (!current()) return;
                        try {
                          clearPending(record);
                          await startSale();
                        } catch (error) {
                          showError(message, error);
                          root.append(message);
                        }
                      },
                    },
                    'Continuar',
                  ),
                ),
              );
            } catch (error) {
              if (current())
                showError(
                  message,
                  new Error('La venta sigue pendiente. Avise a la gerente con el identificador; no vuelva a cobrar.'),
                  `Venta ${record.body.saleId}. ${error.message}`,
                );
            } finally {
              if (current()) lookup.disabled = false;
            }
          },
        },
        'Consultar recibo',
      );
      replace(
        root,
        h(
          'section',
          { class: 'panel' },
          h('h2', {}, 'Venta pendiente'),
          message,
          h('p', { class: 'num' }, `Venta ${record.body.saleId} · Caja original ${record.body.tillId}`),
          sameScope(scope, record.scope)
            ? lookup
            : h(
                'p',
                { role: 'alert' },
                'Registro de otra cuenta, sucursal o dispositivo. Ingrese con la cuenta original y avise a la gerente.',
              ),
        ),
      );
    };
    let pending;
    try {
      pending = readPending();
    } catch {
      replace(
        root,
        h(
          'p',
          { class: 'error', role: 'alert' },
          'No se puede verificar el almacenamiento de ventas. Avise a la gerente; no vuelva a cobrar.',
        ),
      );
      return handle;
    }
    let rate = null;
    const renderOpen = async () => {
      if (!current()) return;
      detach();
      const panel = await openTillPanel(tillCtx, renderSale);
      if (!current()) return;
      replace(root, h('div', { class: 'page' }, panel));
      root.querySelector('#till-opening')?.focus();
    };

    const renderSale = () => {
      if (!current()) return;
      detach();
      const till = ctx.till.get();
      let lines = [];
      let catalog = [];
      let sellers = [];
      // One to three sellers per ticket. The first is the default for every garment; "Venta compartida" (supervision) adds more.
      let ticketSellers = [''];
      let busy = false;
      let sellersReady = false;
      const sellersValid = () =>
        sellersReady &&
        ticketSellers.length > 0 &&
        ticketSellers.every(id => sellers.some(s => sameGuid(s.sellerId, id))) &&
        lines.every(l => ticketSellers.some(id => sameGuid(id, l.sellerId)));
      const locked = () => busy || !current();
      const lock = value => {
        busy = value;
        root.querySelectorAll('input,select,button,textarea').forEach(el => {
          el.disabled = value;
        });
        if (!value) drawBalance();
      };
      const sellerPanel = h('div', { id: 'seller-panel', class: 'seller-panel' });
      const setSellers = (next, replaced = null) => {
        if (locked()) return;
        const previous = ticketSellers;
        ticketSellers = next;
        lines = lines.map(line => ({
          ...line,
          sellerId:
            replaced && (line.sellerId === replaced.from || sameGuid(line.sellerId, replaced.from))
              ? replaced.to
              : previous.some(id => sameGuid(id, line.sellerId)) && !next.some(id => sameGuid(id, line.sellerId))
                ? next[0]
                : line.sellerId,
        }));
        drawSellers();
        drawTicket();
      };
      const drawSellers = () => {
        replace(
          sellerPanel,
          ticketSellers.map((sellerId, index) =>
            h(
              index === 0 ? 'div' : 'details',
              {},
              index === 0 ? null : h('summary', {}, `Vendedor ${index + 1}`),
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
                  h('option', { value: '', selected: !sellers.some(s => sameGuid(s.sellerId, sellerId)) }, 'Elija vendedor'),
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
          ),
          ctx.isApprover && ticketSellers.length < MAX_SELLERS && freeSellers(sellers, ticketSellers).length
            ? h(
                'details',
                {},
                h('summary', {}, 'Compartir venta'),
                h(
                  'button',
                  {
                    type: 'button',
                    id: 'shared-sale',
                    onclick: () => setSellers([...ticketSellers, '']),
                  },
                  ticketSellers.length === 1 ? 'Venta compartida' : 'Agregar vendedor',
                ),
              )
            : null,
        );
      };
      api
        .sellers()
        .then(rows => {
          if (!current()) return;
          sellers = rows;
          sellersReady = true;
          ticketSellers = [rows.find(s => sameGuid(s.sellerId, actor.staffId))?.sellerId ?? ''];
          drawSellers();
          drawBalance();
        })
        .catch(error => showError(status, error));
      let ticketPercent = 0;
      const effectiveLines = () => discountedLines(lines, ticketPercent);
      const effectiveTotal = () => ticketTotal(effectiveLines());
      // Pending writes use the durable final request; mutable drafts have no retry key.

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
      const usdTotal = h('div', { id: 'usd-total', class: 'num' });
      const balanceLabel = h('span', { id: 'balance-label' }, 'Cambio');
      const balance = h('strong', { id: 'balance' });
      const payMessage = h('p', { class: 'error', role: 'alert' });
      const pay = h('button', { class: 'primary big', type: 'button', id: 'pay' }, 'Cobrar');
      const receipt = h('section', { class: 'panel receipt-paper', id: 'receipt', hidden: true, 'aria-live': 'polite' });
      const payments = paymentsPanel({
        kinds: api.saleTenderKinds,
        rate: till.usdExpectedMinor == null ? null : rate,
        branchId: ctx.me.branchId,
        getTotal: effectiveTotal,
        onChange: () => {
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
                      'details',
                      {},
                      h('summary', {}, 'Descuento de línea'),
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
              ),
        );
        total.textContent = formatMoney(effectiveTotal());
        usdTotal.textContent = rate ? formatMoney(Math.round(effectiveTotal() / rate.rate), 'USD') : '';
        drawBalance();
        if (busy) lock(true);
      };

      const drawBalance = () => {
        payments.refresh();
        balanceLabel.textContent = 'Cambio';
        try {
          const draft = payments.draft();
          balance.textContent = formatMoney(draft.changeMinor);
          balance.classList.remove('short');
          pay.disabled = locked() || !sellersValid() || !lines.length;
          payMessage.textContent = '';
        } catch (error) {
          balance.textContent = '—';
          pay.disabled = true;
          payMessage.textContent = lines.length ? error.message : '';
        }
      };

      let physicalConfirmed = false;
      const update = async next => {
        if (locked()) return;
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
        if (locked()) return;
        lines = next;
        drawTicket();
      };

      const add = async row => {
        if (locked()) return;
        if (!sellersValid()) {
          status.textContent = 'Elija vendedores activos antes de agregar prendas.';
          return;
        }
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
        if (locked()) return;
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
          const loaded = await api.catalogItems();
          if (!current()) return;
          catalog = loaded;
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
        if (locked()) return;
        clearMessage(status);
        try {
          const found = await api.lookup(text);
          if (locked()) return;
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
        if (locked() || !sellersValid() || !lines.length) return;
        lock(true);
        let record = null;
        let sent = false;
        let confirmed = false;
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
              lock(false);
              return;
            }
            physicalConfirmed = true;
          }
          if (needsDiscountApproval(effectiveLines()) && !ctx.isApprover) {
            const approval = await supervisorApproval('descuento', postedLines);
            if (!approval) {
              lock(false);
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
          if (!current()) return;
          if (needsDiscountApproval(postedLines) && !discountReason) {
            advanced.open = true;
            lock(false);
            discountReasonInput.focus();
            throw new Error('Indique el motivo del descuento.');
          }
          draft = payments.draft();
          const saleId = api.uuid();
          const body = {
            ...saleRequest({ saleId, tillId: till.tillId, lines: postedLines, tenders: draft.tenders, customerId: payments.customerId }),
            discountReason: discountReason || null,
            stockExceptionNote: physicalConfirmed ? 'El sistema decía 0 y había existencia física. Confirmado en tienda.' : null,
          };
          record = persistPending({ version: 1, scope, body, changeMinor: draft.changeMinor });
          if (!current()) return;
          sent = true;
          const response = await api.postSale(record.body, approvalToken);
          if (!current()) return;
          if (!validResponse(response, saleId)) throw new Error('La respuesta no confirma la venta.');
          confirmed = true;
          showReceipt(response, draft.changeMinor);
          clearPending(record);
          lock(false);
          lines = [];
          physicalConfirmed = false;
          discountReasonInput.value = '';
          ticketSellers = ticketSellers.slice(0, 1);
          drawSellers();
          ticketPercent = 0;
          discountInput.value = 0;
          payments.reset();
          drawTicket();
          await loadCatalog();
          try {
            const detail = await api.getSale(response.saleId);
            if (!current()) return;
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
          if (!current()) return;
          if (confirmed) {
            showError(payMessage, new Error('Venta registrada. Consulte el recibo antes de continuar.'), error.message);
            return;
          }
          // Only an explicit first-response domain rejection can release this attempt.
          const rejected =
            sent &&
            error.status >= 400 &&
            error.status < 500 &&
            error.code &&
            !error.code.startsWith('http.') &&
            !['sale.id_reused'].includes(error.code);
          if (record && sent && !rejected) {
            recovery(record);
            return;
          }
          if (record && rejected) {
            try {
              clearPending(record);
            } catch {
              recovery(record);
              return;
            }
          }
          // A failed write/readback can leave a marker. Never unlock over it.
          try {
            const saved = readPending();
            if (saved) {
              recovery(saved);
              return;
            }
          } catch {
            showError(payMessage, new Error('No se puede verificar el almacenamiento. Avise a la gerente.'));
            return;
          }
          lock(false);
          showError(payMessage, error, 'Revise los datos antes de cobrar.');
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
          drawTicket();
        },
      });
      const parked = () => {
        const saved = device.get('parkedTickets');
        return saved?.tillId === till.tillId ? saved.tickets : [];
      };
      const clearTicket = () => {
        if (locked()) return;
        lines = [];
        ticketSellers = ticketSellers.slice(0, 1);
        drawSellers();
        physicalConfirmed = false;
        ticketPercent = 0;
        discountInput.value = 0;
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
              if (locked()) return;
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
              if (locked()) return;
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
                                if (locked()) {
                                  close();
                                  return;
                                }
                                lines = structuredClone(saved.lines).map(line => ({
                                  ...line,
                                  sellerId: sellers.find(s => sameGuid(s.sellerId, line.sellerId))?.sellerId ?? line.sellerId,
                                }));
                                ticketPercent = saved.ticketPercent;
                                discountInput.value = ticketPercent;
                                ticketSellers = (saved.sellers ?? [...new Set(lines.map(l => l.sellerId).filter(Boolean))])
                                  .map(id => sellers.find(s => sameGuid(s.sellerId, id))?.sellerId ?? id)
                                  .slice(0, MAX_SELLERS);
                                if (!ticketSellers.length) ticketSellers = [''];
                                ticketSellers = [...new Set(lines.map(l => l.sellerId ?? '').concat(ticketSellers))].slice(0, MAX_SELLERS);
                                if (!sellersValid()) status.textContent = 'Reasigne los vendedores que ya no están activos.';
                                drawSellers();
                                await payments.restore(saved.payment);
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

      const advanced = h(
        'details',
        { id: 'sale-advanced' },
        h('summary', {}, 'Opciones de venta'),
        ticketActions,
        h('label', { class: 'ticket-discount' }, 'Descuento solicitado (%)', discountInput),
        ctx.isApprover
          ? h('label', {}, 'Motivo del descuento', discountReasonInput)
          : h('small', {}, 'Todo descuento requiere aprobación de la gerente.'),
      );
      // Native disclosure keeps its focus; the scanner reclaims focus only from non-controls.
      detach = () => {};
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
            advanced,
            ticketLines,
            h(
              'div',
              { class: 'checkout' },

              h('div', { class: 'total' }, h('span', {}, 'Total'), total),
              usdTotal,
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
      const stopScan = attachScanField(field, code => handle.handleScan(code), { keepFocus: false });
      const keepDisclosureFocus = event => {
        if (event.target.closest?.('summary,button')) event.stopPropagation();
      };
      root.addEventListener('click', keepDisclosureFocus);
      detach = () => {
        stopScan();
        root.removeEventListener('click', keepDisclosureFocus);
      };
      drawTicket();
      loadCatalog();
    };

    const startSale = async () => {
      try {
        rate = await api.exchangeRate();
      } catch (error) {
        if (error.status !== 404) throw error;
      }
      if (!current()) return;
      const { till } = await syncTill(tillCtx);
      if (!current()) return;
      if (till?.tillId) renderSale();
      else await renderOpen();
    };
    if (pending) {
      recovery(pending);
      return handle;
    }
    await startSale();
    return handle;
  },
};
