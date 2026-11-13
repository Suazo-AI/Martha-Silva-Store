// Venta: scan or search to add garments, ticket always visible, cash received and change, Cobrar.
import * as api from '../api.mjs';
import { h, replace, showError, clearMessage, flash, device, openModal } from '../ui.mjs';
import { attachScanField, serialQueue } from '../scan.mjs';
import { formatMoney, lineTotal } from '../money.mjs';
import { addToTicket, setQuantity, removeLine, ticketTotal, saleRequest, itemFromLookup, discountedLines, needsDiscountApproval, catalogMatches } from './sale-logic.mjs';
import { openTillPanel, syncTill } from './till-open.mjs';
import { paymentsPanel } from './payments.mjs';
import { supervisorApproval } from './return.mjs';
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
      let catalog = [];
      let ticketPercent = 0;
      const effectiveLines = () => discountedLines(lines, ticketPercent);
      const effectiveTotal = () => ticketTotal(effectiveLines());
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
      const payments = paymentsPanel({ kinds: api.saleTenderKinds, branchId: ctx.me.branchId, getTotal: effectiveTotal, onChange: () => { attempt = null; drawBalance(); } });

      const drawTicket = () => {
        replace(ticketLines, lines.length === 0 ? h('p', { class: 'muted' }, 'Toque una prenda o escanee su código para empezar.') : lines.map(line =>
          h('div', { class: 'tline', dataset: { item: line.itemId } },
            h('div', { class: 'line-meta' },
              h('strong', {}, line.name),
              h('span', { class: 'num' }, formatMoney(lineTotal(line.unitPriceMinor, line.quantity) - (effectiveLines().find(l => l.itemId === line.itemId)?.discountMinor ?? 0)))),
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
                h('button', { type: 'button', class: 'remove', 'aria-label': `Quitar ${line.name} del ticket`, onclick: () => update(removeLine(lines, line.itemId)) }, 'Quitar')),
              h('label', { class: 'line-discount' }, 'Descuento de línea (%)', h('input', { id: `discount-${line.itemId}`, 'aria-label': `Descuento de ${line.name} (%)`, type:'number', min:0, max:100, value: line.discountPercent ?? 0,
                onchange: e => { const value = Number(e.target.value); if (value < 0 || value + ticketPercent > 100 || !Number.isFinite(value)) { e.target.value = line.discountPercent ?? 0; status.textContent = 'El descuento combinado debe estar entre 0 y 100 %.'; return; } update(lines.map(l => l.itemId === line.itemId ? { ...l, discountAmountMinor:undefined, discountPercent:value } : l)); } })))))

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

      const confirmPhysical = () => openModal((body, close) => replace(body,
        h('h2', { id:'modal-title' }, 'Confirmar existencia física'),
        h('p', {}, 'El sistema muestra 0. Confirmar que la prenda está en la tienda'),
        h('p', { class:'muted' }, 'La venta dejará una excepción para revisión de supervisión.'),
        h('div', { class:'actions' }, h('button', { type:'button', onclick:() => close(false) }, 'Cancelar'),
          h('button', { id:'confirm-stock', type:'button', class:'primary', onclick:() => close(true) }, 'Confirmar existencia física'))));
      let physicalConfirmed = false;
      const update = async next => {
        if (next.some(line => line.quantity > (catalog.flatMap(p => p.variants).find(v => v.itemId === line.itemId)?.available ?? 0) && line.quantity > (lines.find(l => l.itemId === line.itemId)?.quantity ?? 0))) {
          if (!await confirmPhysical()) { drawTicket(); return; }
          physicalConfirmed = true;
        }
        if (next !== lines) attempt = null;
        lines = next;
        drawTicket();
      };

      const add = async row => {
        const current = catalog.flatMap(p => p.variants).find(v => v.itemId === row.itemId);
        if (!current) { status.textContent = 'Vuelva a cargar el catálogo para consultar la prenda.'; return; }
        row = { ...row, ...current };
        if (row.status && row.status !== 'active') {
          status.textContent = `${row.variantName ?? row.sku} no está a la venta (estado: ${row.status}).`;
          return;
        }
        clearMessage(status);
        receipt.hidden = true;
        await update(addToTicket(lines, itemFromLookup(row)));
        const el = ticketLines.querySelector(`[data-item="${row.itemId}"]`);
        if (el) flash(el);
      };

      const typeFilter = h('select', { id:'sale-type', onchange: () => drawCatalog() }, h('option', { value:'' }, 'Todos los tipos'));
      const sizeFilter = h('select', { id:'sale-size', onchange: () => drawCatalog() }, h('option', { value:'' }, 'Todas las tallas'));
      const filters = h('div', { class:'catalog-filters' }, h('label', {}, 'Tipo de prenda', typeFilter), h('label', {}, 'Talla', sizeFilter));
      const choose = async product => {
        const variants = product.variants.filter(v => !sizeFilter.value || v.sizeCode === sizeFilter.value);
        if (variants.length === 1) { await add(variants[0]); return; }
        const selected = await openModal((body, close) => replace(body,
          h('h2', { id:'modal-title' }, product.name), h('p', {}, 'Elija la talla para agregar al ticket.'),
          h('div', { class:'sizes', id:'sale-sizes' }, variants.map(v => h('button', { type:'button',
            dataset:{ item:v.itemId }, onclick: () => close(v) }, `Talla ${v.sizeCode ?? 'única'} · ${v.available > 0 ? `${v.available} disponibles` : 'Sin existencia en sistema'} · ${formatMoney(v.unitPriceMinor)}`))),
          h('button', { type:'button', onclick:() => close() }, 'Volver')));
        if (selected) await add(selected);
      };
      const drawCatalog = () => {
        const visible = catalog.filter(p => catalogMatches(p, { type:typeFilter.value, size:sizeFilter.value, query: field.value.trim() }));
        replace(cards, visible.length ? visible.map(product => {
          const variants = product.variants.filter(v => !sizeFilter.value || v.sizeCode === sizeFilter.value);
          const available = variants.reduce((sum, v) => sum + v.available, 0);
          return h('button', { type:'button', class:'product', 'aria-label': `${product.name} · ${available > 0 ? `${available} disponibles` : 'Sin existencia en sistema'}`, dataset:{ product:product.productId, type:product.type }, onclick:() => choose(product) },
            h('span', { class:'product-info' }, h('strong', {}, product.name),
              h('small', {}, `${product.type} · Tallas ${variants.map(v => v.sizeCode ?? 'única').join(', ')}`), h('strong', { class:'num' }, formatMoney(Math.min(...variants.map(v => v.unitPriceMinor)))),
              h('span', { class:available ? 'stock-available' : 'out' }, available ? `${available} disponibles` : 'Sin existencia en sistema')));
        }) : h('p', { class:'muted' }, 'No hay prendas con estos filtros. Cambie el tipo, la talla o la búsqueda.'));
      };
      const loadCatalog = async () => {
        try {
          catalog = await api.catalogItems();
          const selectedType = typeFilter.value, selectedSize = sizeFilter.value;
          replace(typeFilter, h('option', { value:'' }, 'Todos los tipos'), [...new Set(catalog.map(p => p.type))].sort().map(type => h('option', { value:type }, type)));
          replace(sizeFilter, h('option', { value:'' }, 'Todas las tallas'), [...new Set(catalog.flatMap(p => p.variants.map(v => v.sizeCode)).filter(Boolean))].map(size => h('option', { value:size }, size)));
          typeFilter.value = selectedType; sizeFilter.value = selectedSize;
          drawCatalog();
        } catch (error) { showError(status, error, 'Vuelva a Venta para cargar el catálogo.'); }
      };
      field.addEventListener('input', () => drawCatalog());
      const drawCards = rows => { drawCatalog(); status.textContent = rows.length ? 'Elija una prenda y su talla.' : 'Cambie el nombre o SKU para buscar otra prenda.'; };

      const find = async text => {
        clearMessage(status);
        try {
          const found = await api.lookup(text);
          if (found.length === 1) { await add(found[0]); field.value = ''; drawCatalog(); return; }
          if (found.length > 1) { field.value=''; choose({ name:'Elija una prenda', variants:found.map(row => ({ ...row, ...catalog.flatMap(p => p.variants).find(v => v.itemId === row.itemId) })) }); return; }
        } catch (error) {
          showError(status, error); return;
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
        try { draft = payments.draft(); } catch (error) { showError(payMessage, error); return; }
        const key = JSON.stringify([effectiveLines(), draft.tenders, payments.customerId]);
        if (!attempt || attempt.key !== key) attempt = { saleId: api.uuid(), key };
        pay.disabled = true;
        clearMessage(payMessage);
        let approvalToken;
        let postedLines = effectiveLines();
        let discountReason = discountReasonInput.value.trim();
        try {
          if (!physicalConfirmed && postedLines.some(line => line.quantity > (catalog.flatMap(p => p.variants).find(v => v.itemId === line.itemId)?.available ?? 0))) {
            if (!await confirmPhysical()) { drawBalance(); return; }
            physicalConfirmed = true;
          }
          if (needsDiscountApproval(effectiveLines()) && !ctx.isApprover) {
            const approval = await supervisorApproval('descuento', postedLines);
            if (!approval) { drawBalance(); return; }
            approvalToken = approval.token;
            discountReason = approval.reason;
            postedLines = approval.lines;
            // The manager may change the requested amount. Refresh payments before charging.
            if (ticketTotal(postedLines) !== effectiveTotal()) {
              lines = postedLines.map(line => ({ ...line, discountAmountMinor: line.discountMinor, discountPercent: 0 }));
              ticketPercent = 0; discountInput.value = 0; drawTicket();
              draft = payments.draft();
            }
          }
          if (needsDiscountApproval(postedLines) && !discountReason) throw new Error('Indique el motivo del descuento.');
          const response = await api.postSale({ ...saleRequest({ saleId: attempt.saleId, tillId: till.tillId, lines:postedLines, tenders: draft.tenders, customerId: payments.customerId }),
            discountReason: discountReason || null, stockExceptionNote: physicalConfirmed ? 'El sistema decía 0 y había existencia física. Confirmado en tienda.' : null }, approvalToken);
          showReceipt(response, draft.changeMinor);
          lines = []; physicalConfirmed = false; discountReasonInput.value = '';
          ticketPercent = 0; discountInput.value = 0;
          attempt = null;
          payments.reset();
          drawTicket();
          await loadCatalog();
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
          if (approvalToken) { try { await api.endApproval(approvalToken); } catch { /* server expiry remains in force */ } }
        }
      });

      const showReceipt = (sale, changeMinor) => {
        receipt.hidden = false;
        replace(receipt,
          h('h2', {}, 'Venta registrada'),
          h('div', { class: 'row' }, h('span', {}, 'Subtotal'), h('strong', { class: 'num' }, formatMoney(sale.subtotalMinor))),
          h('div', { class: 'row' }, h('span', {}, 'Total cobrado'), h('strong', { class: 'num', id: 'receipt-total' }, formatMoney(sale.totalMinor))),
          h('div', { class: 'row' }, h('span', {}, 'Cambio a entregar'), h('strong', { class: 'num', id: 'receipt-change' }, formatMoney(changeMinor))),
          h('p', { class: 'muted num' }, `Venta ${sale.saleId}`),
          h('button', { type: 'button', class: 'primary', id: 'open-receipt', onclick: () => ctx.go(`recibo?sale=${encodeURIComponent(sale.saleId)}`) }, 'Ver recibo'));
        flash(receipt);
      };

      const discountReasonInput = h('input', { id:'discount-reason', maxlength:250, placeholder:'Motivo autorizado por supervisión' });
      const discountInput = h('input', { id:'ticket-discount', type:'number', min:0, max:100, value:0, onchange: e => {
        const value=Number(e.target.value);
        if (!Number.isFinite(value) || value < 0 || lines.some(l => value + (l.discountPercent ?? 0) > 100)) { e.target.value=ticketPercent; status.textContent='Revise el descuento: el combinado no puede superar 100 %.'; return; }
        ticketPercent=value; lines=lines.map(line=>({...line,discountAmountMinor:undefined})); attempt=null; drawTicket();
      } });
      const parked = () => { const saved = device.get('parkedTickets'); return saved?.tillId === till.tillId ? saved.tickets : []; };
      const clearTicket = () => { lines=[]; physicalConfirmed=false; ticketPercent=0; discountInput.value=0; attempt=null; payments.reset(); drawTicket(); };
      const confirmClear = h('div', { class:'warning actions', id:'confirm-empty', hidden:true }, '¿Vaciar el ticket actual?',
        h('button', { type:'button', id:'confirm-empty-yes', onclick: () => { clearTicket(); confirmClear.hidden=true; } }, 'Sí, vaciar'),
        h('button', { type:'button', onclick: () => { confirmClear.hidden=true; } }, 'Conservar ticket'));
      const ticketActions = h('div', { class:'actions ticket-actions' },
        h('button', { type:'button', id:'park-ticket', onclick: () => {
          if (!lines.length) { status.textContent='Agregue una prenda antes de guardar.'; return; }
          const tickets=parked();
          tickets.push({ id:api.uuid(), name:`Ticket ${tickets.length+1}`, lines:structuredClone(lines), ticketPercent, payment:payments.snapshot() });
          device.set('parkedTickets', { tillId:till.tillId, tickets }); clearTicket(); status.textContent='Ticket guardado. Abra Tickets guardados para recuperarlo.';
        } }, 'Guardar ticket'),
        h('button', { type:'button', id:'saved-tickets', onclick: () => {
          if (lines.length) { status.textContent='Guarde o vacíe el ticket actual antes de restaurar otro.'; return; }
          openModal((body, close) => replace(body, h('h2', { id:'modal-title' }, 'Tickets guardados'),
            parked().length ? parked().map(saved => h('button', { type:'button', class:'restore-ticket', onclick:async () => {
              try {
                await loadCatalog(); lines=structuredClone(saved.lines); ticketPercent=saved.ticketPercent; discountInput.value=ticketPercent;
                await payments.restore(saved.payment); attempt=null; drawTicket();
                device.set('parkedTickets', { tillId:till.tillId, tickets:parked().filter(t => t.id !== saved.id) }); close();
              } catch(error) { showError(status,error,'Revise el cliente antes de cobrar.'); close(); }
            } }, `${saved.name} · ${saved.lines.reduce((sum,l)=>sum+l.quantity,0)} prendas`)) : h('p', {}, 'No hay tickets guardados. Agregue prendas y pulse Guardar ticket.'),
            h('button', { type:'button', onclick:() => close() }, 'Volver')));
        } }, 'Tickets guardados'),
        h('button', { type:'button', id:'empty-ticket', onclick:() => { confirmClear.hidden=false; } }, 'Vaciar ticket'));

      replace(root, h('div', { class: 'sale' },
        h('section', { class: 'catalog', 'aria-label': 'Buscar prendas' },
          h('label', { for: 'sale-search', class: 'sr' }, 'Escanear o buscar por SKU o nombre'),
          field, fieldNote, filters, status, cards),
        h('aside', { class: 'ticket', 'aria-labelledby': 'ticket-heading' },
          h('h2', { id: 'ticket-heading' }, 'Ticket'), ticketActions, confirmClear,
          ticketLines,
          h('div', { class: 'checkout' },
            h('label', { class:'ticket-discount' }, 'Descuento solicitado (%)', discountInput),
            ctx.isApprover ? h('label', {}, 'Motivo del descuento', discountReasonInput) : h('small', {}, 'Todo descuento requiere aprobación de supervisión.'),
            h('div', { class: 'total' }, h('span', {}, 'Total'), total),
            payments.node,
            h('div', { class: 'money-row', 'aria-live': 'polite', 'aria-atomic': 'true' }, balanceLabel, balance),
            payMessage, pay),
          receipt)));
      field.setAttribute('aria-describedby', 'sale-search-help');
      detach = attachScanField(field, code => handle.handleScan(code));
      drawTicket();
      loadCatalog();
    };

    const { till } = await syncTill(ctx);
    if (till?.tillId) renderSale(); else await renderOpen();
    return handle;
  },
};
