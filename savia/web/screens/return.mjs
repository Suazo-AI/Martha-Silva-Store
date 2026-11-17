import * as api from '../api.mjs';
import { confirmAction } from '../confirm.mjs';
import { formatMoney, parseMoney } from '../money.mjs';
import { isApprover } from '../roles.mjs';
import { h, openModal, replace, showError } from '../ui.mjs';
import { routeSaleId } from './receipt.mjs';
import {
  actorScope,
  cancelDraft,
  changeIntent,
  finishIntent,
  matchingReversal,
  readIntent,
  reserveIntent,
  sameScope,
  validReversal,
  withIntentLock,
} from './return-intent.mjs';
import { exchangeBalance, OUTCOMES, outcomeRequest, remainingQuantity, returnValue, selectedReturnLines } from './return-logic.mjs';
import { itemFromLookup } from './sale-logic.mjs';
import { garmentLine, tenderName } from './sale-view.mjs';
import { syncTill } from './till-open.mjs';

/** A second real login. The cashier's session and token stay in place. */
export function supervisorApproval(action = 'devolución', lines = [], current = () => true, revoke = token => api.endApproval(token)) {
  return openModal((body, close) => {
    const user = h('input', { id: 'approval-user', autocomplete: 'username', required: true });
    const pass = h('input', { id: 'approval-pass', type: 'password', autocomplete: 'current-password', required: true });
    document.getElementById('modal').addEventListener(
      'close',
      () => {
        pass.value = '';
      },
      { once: true },
    );
    const error = h('p', { role: 'alert' });
    const reason = h('input', { id: 'approval-reason', maxlength: 250, required: true });
    const discounts = lines.map((line, index) => ({
      line,
      input: h('input', {
        id: `approval-discount-${index}`,
        inputmode: 'decimal',
        value: ((line.discountMinor ?? 0) / 100).toFixed(2),
      }),
    }));
    const submit = h('button', { type: 'submit', class: 'primary' }, `Autorizar ${action}`);
    const form = h(
      'form',
      {
        class: 'form',
        onsubmit: async event => {
          event.preventDefault();
          if (!current() || submit.disabled) return;
          submit.disabled = true;
          try {
            if (
              action === 'descuento' &&
              (!reason.value.trim() ||
                discounts.some(
                  ({ line, input }) => parseMoney(input.value) == null || parseMoney(input.value) > line.unitPriceMinor * line.quantity,
                ))
            ) {
              throw new Error('Indique el motivo y un descuento válido para cada prenda.');
            }
            const approval = await api.login(user.value.trim(), pass.value);
            pass.value = '';
            if (!current() || !isApprover(approval.roles)) {
              await revoke(approval.token);
              throw new Error('Use la cuenta de la gerente o de la dueña para autorizar.');
            }
            if (!form.isConnected || !document.getElementById('modal').open) {
              await revoke(approval.token);
              return;
            }
            close(
              action === 'descuento'
                ? {
                    token: approval.token,
                    reason: reason.value.trim(),
                    lines: discounts.map(({ line, input }) => ({ ...line, discountMinor: parseMoney(input.value) })),
                  }
                : approval.token,
            );
          } catch (failure) {
            pass.value = '';
            if (current() && form.isConnected) {
              showError(error, failure);
              submit.disabled = false;
            }
          }
        },
      },
      h('label', {}, 'Usuario de la gerente', user),
      h('label', {}, 'Contraseña de la gerente', pass),
      action === 'descuento' ? discounts.map(({ line, input }) => h('label', {}, `Descuento en C$ · ${line.name}`, input)) : null,
      action === 'descuento' ? h('label', {}, 'Motivo del descuento', reason) : null,
      error,
      h(
        'div',
        { class: 'actions' },
        h(
          'button',
          {
            type: 'button',
            onclick: () => {
              pass.value = '';
              close();
            },
          },
          'Cancelar',
        ),
        submit,
      ),
    );
    replace(
      body,
      h('h2', { id: 'modal-title' }, 'Aprobación de la gerente'),
      h(
        'p',
        {},
        `${action === 'descuento' ? 'El descuento' : 'La devolución'} necesita autorización. Ingrese la cuenta de la gerente o de la dueña.`,
      ),
      form,
    );
  });
}

export default {
  title: 'Devolución',
  async mount(root, ctx) {
    const actor = ctx.me,
      session = api.getToken(),
      hash = location.hash,
      scope = actorScope(actor);
    let disposed = false,
      replacement = null;
    let retired = false,
      busy = false,
      pending = null,
      ownedContent = null;
    const approvals = new Map();
    const revoke = token => {
      if (approvals.has(token)) return approvals.get(token);
      const task = api.endApproval(token).catch(() => {
        if (ctx.reportApprovalCleanupFailure) ctx.reportApprovalCleanupFailure();
        else ctx.notify('No se pudo cerrar la autorizaci\u00f3n temporal. Pida revisi\u00f3n a la gerente.');
      });
      approvals.set(token, task);
      return task;
    };
    const activeApprovals = new Set();
    const cleanup = () => {
      for (const token of activeApprovals) void revoke(token);
    };
    const current = () =>
      !retired &&
      ctx.isCurrent?.() !== false &&
      ctx.me === actor &&
      api.getToken() === session &&
      location.hash === hash &&
      sameScope(scope, actorScope(ctx.me));
    const handle = {
      unmount() {
        disposed = true;
        retired = true;
        replacement?.unmount?.();
        cleanup();
        if (ownedContent?.isConnected && document.getElementById('modal').open) document.getElementById('modal').close();
      },
      handleScan(code) {
        if (replacement) return replacement.handleScan?.(code);
        if (current()) ctx.notify(`Para un cambio, escriba ${code} en Prenda nueva.`);
      },
    };
    const status = h('p', { role: 'alert', id: 'return-status' });
    const panel = h('section', { class: 'panel' });
    replace(root, h('div', { class: 'page' }, panel, status));
    const summary = r => {
      const b = r.body,
        amount = r.expected.reduce((sum, l) => sum + l.creditMinor, 0);
      const money = value => (r.currencyCode ? formatMoney(value, r.currencyCode) : `${value} unidades menores (moneda sin verificar)`);
      const outcome = OUTCOMES.find(([key]) => key === (b.outcome ?? 'credit'))?.[1];
      const details = [`${outcome}: ${money(amount)}.`, `Motivo: ${b.reason}.`];
      if (b.reference) details.push(`Referencia: ${b.reference}.`);
      if (b.creditId) details.push(`Anticipo: ${b.creditId}.`);
      if (b.outcome === 'exchange') {
        const balance = exchangeBalance(amount, b.newLines);
        details.push(
          `Prendas nuevas: ${money(balance.newMinor)}. La clienta paga: ${money(balance.dueMinor)}. Se devuelve: ${money(balance.backMinor)}.`,
        );
        for (const t of b.newTenders)
          details.push(`${tenderName(t.tenderKind)}: ${money(t.amountMinor)}${t.reference ? ` \u00b7 ${t.reference}` : ''}.`);
        if (balance.backMinor)
          details.push(`${tenderName(b.differenceKind)}${b.differenceReference ? ` \u00b7 ${b.differenceReference}` : ''}.`);
      }
      return details.join(' ');
    };
    const cancelPending = () => {
      if (!current() || pending?.state !== 'draft') return;
      cancelDraft(pending);
      pending = null;
      cleanup();
    };
    const recovery = () => {
      if (!current()) return;
      if (!sameScope(scope, pending.scope)) {
        replace(panel, h('p', { role: 'alert' }, 'Hay una devolución pendiente. Pida revisión a la gerente.'));
        return;
      }
      replace(
        panel,
        h('h2', {}, pending.state === 'confirmed' ? 'Devolución verificada' : 'Devolución pendiente'),
        h('p', {}, `Operación ${pending.body.reversalId}`),
        h('p', { id: 'return-result' }, summary(pending)),
        h('a', { href: `#/recibo?sale=${encodeURIComponent(pending.saleId)}` }, 'Recibo original'),
        pending.state === 'confirmed' && pending.body.exchangeSaleId
          ? h('a', { href: `#/recibo?sale=${encodeURIComponent(pending.body.exchangeSaleId)}` }, 'Recibo del cambio')
          : null,
        pending.state === 'draft'
          ? h(
              'button',
              {
                type: 'button',
                id: 'return-cancel',
                onclick: async () => {
                  if (!current() || busy) return;
                  busy = true;
                  try {
                    await withIntentLock(() => cancelPending());
                    if (current() && !pending) {
                      retired = true;
                      replacement = await this.mount(
                        root,
                        Object.assign(Object.create(ctx), {
                          isCurrent: () =>
                            !disposed &&
                            ctx.isCurrent?.() !== false &&
                            ctx.me === actor &&
                            api.getToken() === session &&
                            location.hash === hash &&
                            sameScope(scope, actorScope(ctx.me)),
                        }),
                      );
                    }
                  } catch (e) {
                    if (current()) showError(status, e);
                  } finally {
                    busy = false;
                  }
                },
              },
              'Cancelar devoluci\u00f3n',
            )
          : null,
        pending.body.outcome === 'exchange' && pending.state !== 'confirmed'
          ? h('p', {}, 'El recibo permite verificar lo devuelto. El vínculo del cambio requiere revisión de la gerente.')
          : null,
        h('button', { type: 'button', id: 'return-lookup', onclick: () => runRecovery(false) }, 'Consultar resultado'),
        pending.state !== 'confirmed'
          ? h('button', { type: 'button', id: 'return-replay', onclick: () => runRecovery(true) }, 'Reenviar misma operación')
          : h(
              'button',
              {
                type: 'button',
                id: 'return-finish',
                onclick: async () => {
                  if (!current() || busy) return;
                  busy = true;
                  try {
                    await withIntentLock(() => {
                      if (!current()) return;
                      finishIntent(pending);
                      ctx.go('historial');
                    });
                  } catch (e) {
                    if (current()) showError(status, e);
                  } finally {
                    busy = false;
                  }
                },
              },
              'Terminar',
            ),
      );
    };
    const lookup = async () => {
      if (!current()) return;
      const response = await api.request('GET', `/sales/${encodeURIComponent(pending.saleId)}`, undefined, { withStatus: true });
      const receipt = response.status === 200 ? response.data : null;
      if (!current()) return;
      const match = matchingReversal(receipt, pending);
      if (!match) throw Error('El resultado no confirma esta devolución. Mantenga la operación pendiente.');
      // A partial readmodel cannot establish the complete exchange identity.
      if (pending.body.outcome === 'exchange')
        throw Error('Devolución encontrada. La gerente debe conciliar el vínculo y el pago del cambio.');
      pending = changeIntent(pending, 'confirmed');
      status.textContent = '';
      recovery();
    };
    const sendPending = async () => {
      if (!current()) return;
      const confirmation = confirmAction(summary(pending));
      ownedContent = document.getElementById('modal-title');
      const confirmed = await confirmation;
      if (!current()) return;
      if (!confirmed) {
        cancelPending();
        return;
      }
      let approval;
      try {
        if (!ctx.isApprover) {
          const authorization = supervisorApproval(undefined, [], current, revoke);
          ownedContent = document.getElementById('modal-title');
          approval = await authorization;
          if (approval) {
            activeApprovals.add(approval);
            if (!current()) void revoke(approval);
          }
          if (!current()) return;
          if (!approval) {
            cancelPending();
            return;
          }
        }
        if (!current()) return;
        pending = changeIntent(pending, 'sending');
        if (!current()) return;
        // Explicit captured authorization; a retired actor can never borrow a replacement bearer.
        const response = await api.request(
          'POST',
          `/sales/${encodeURIComponent(pending.saleId)}/returns/${pending.endpoint}`,
          pending.body,
          { token: approval || session, notifyUnauthorized: !approval, withStatus: true },
        );
        if (!current()) return;
        if (response.status !== 200 || !validReversal(response.data, pending))
          throw Error('Respuesta sin confirmar. Consulte el resultado.');
        // changeIntent checks exact durable ownership while the exclusive lock is held.
        pending = changeIntent(pending, 'confirmed');
        status.textContent = '';
        recovery();
      } catch (error) {
        if (current() && pending?.state === 'sending') pending = changeIntent(pending, 'unresolved');
        throw error;
      } finally {
        if (approval) void revoke(approval);
      }
    };
    const runRecovery = async replay => {
      if (!current() || busy || !sameScope(scope, pending.scope)) return;
      if (replay && pending.state === 'confirmed') return;
      busy = true;
      try {
        await withIntentLock(async () => {
          if (!current()) return;
          const saved = readIntent();
          if (JSON.stringify(saved) !== JSON.stringify(pending))
            throw Error('La operación cambió en otra pantalla. Vuelva a abrir Devolución.');
          if (replay) await sendPending();
          else await lookup();
          if (!current()) return;
        });
      } catch (e) {
        if (current()) showError(status, e, 'La operación sigue guardada. No registre otra devolución.');
      } finally {
        busy = false;
        if (current()) {
          if (pending) recovery();
          else {
            retired = true;
            replacement = await this.mount(
              root,
              Object.assign(Object.create(ctx), {
                isCurrent: () => !disposed && ctx.isCurrent?.() !== false && ctx.me === actor && api.getToken() === session,
              }),
            );
          }
        }
      }
    };
    try {
      pending = readIntent();
      if (pending) {
        recovery();
        return handle;
      }
      const id = routeSaleId();
      if (!id) throw new Error('Elija una venta desde Historial.');
      const sale = await api.getSale(id);
      if (!current()) return handle;
      const [policy, sellers] = await Promise.all([api.returnPolicy().catch(() => null), api.sellers().catch(() => [])]);
      if (!current()) return handle;
      let creditCustomerId = sale.customerId;
      const creditCustomer = h('input', { id: 'return-credit-customer', type: 'search', placeholder: 'Nombre para emitir el anticipo' });
      const customerChoices = h('div', { class: 'actions' });
      const chooseCustomer = h(
        'div',
        { class: 'form' },
        h('label', {}, 'Destinataria del anticipo', creditCustomer),
        h(
          'button',
          {
            type: 'button',
            onclick: async () => {
              try {
                if (!current() || pending) return;
                const customers = await api.searchCustomers(creditCustomer.value);
                if (!current() || pending) return;
                replace(
                  customerChoices,
                  customers.map(customer =>
                    h(
                      'button',
                      {
                        type: 'button',
                        onclick: () => {
                          if (!current() || pending) return;
                          creditCustomerId = customer.customerId;
                          creditCustomer.value = customer.displayName;
                          replace(customerChoices);
                        },
                      },
                      customer.displayName,
                    ),
                  ),
                );
              } catch (error) {
                if (current()) showError(status, error);
              }
            },
          },
          'Buscar destinataria',
        ),
        customerChoices,
      );
      const { till } = await syncTill(Object.assign(Object.create(ctx), { isCurrent: current }));
      if (!current()) return handle;
      if (!till) throw new Error('Abra una caja desde Venta antes de registrar la devolución.');
      const quantities = {};
      let outcome = 'credit';
      let newLines = [];
      let attempt = null;
      const reason = h('textarea', { id: 'return-reason', required: true, maxlength: '500', rows: '1' });
      const restock = h('input', { id: 'return-restock', type: 'checkbox', checked: true });
      const total = h('strong', { id: 'return-preview' }, formatMoney(0));
      const submit = h('button', { id: 'return-submit', class: 'primary big', type: 'submit' }, 'Confirmar devolución');
      const reference = h('input', { id: 'return-reference', maxlength: 120, placeholder: 'Número de la transferencia' });
      const exchangeCode = h('input', { id: 'exchange-code', type: 'search', autocomplete: 'off', placeholder: 'Código o SKU' });
      const exchangeLines = h('div', { id: 'exchange-lines' });
      const firstSeller = sale.lines.find(l => sellers.some(s => s.sellerId === l.sellerId))?.sellerId ?? sellers[0]?.sellerId;
      const exchangeSeller = h(
        'select',
        { id: 'exchange-seller' },
        sellers.map(s => h('option', { value: s.sellerId, selected: s.sellerId === firstSeller }, s.name)),
      );
      const tenderKind = h(
        'select',
        { id: 'exchange-tender' },
        ['cash', 'card', 'transfer'].map(kind => h('option', { value: kind }, tenderName(kind))),
      );
      const tenderReference = h('input', { id: 'exchange-tender-reference', maxlength: 120 });
      const differenceKind = h(
        'select',
        { id: 'exchange-difference' },
        h('option', { value: 'cash' }, 'Efectivo de caja'),
        h('option', { value: 'transfer' }, 'Transferencia bancaria'),
      );
      const differenceReference = h('input', { id: 'exchange-difference-reference', maxlength: 120 });
      const balance = h('div', { id: 'exchange-balance', class: 'form' });
      const outcomePanel = h('div', { id: 'outcome-panel', class: 'form' });
      const returnMinor = () => returnValue(sale, quantities);
      const drawBalance = () => {
        const { newMinor, dueMinor, backMinor } = exchangeBalance(returnMinor(), newLines);
        replace(
          balance,
          h('div', { class: 'total' }, 'Prendas nuevas', h('strong', { id: 'exchange-new-total' }, formatMoney(newMinor))),
          dueMinor
            ? [
                h('div', { class: 'total' }, 'La clienta paga', h('strong', { id: 'exchange-due' }, formatMoney(dueMinor))),
                h('label', {}, 'Forma de pago', tenderKind),
                h('label', {}, 'Referencia del pago', tenderReference),
              ]
            : null,
          backMinor
            ? [
                h('div', { class: 'total' }, 'Se devuelve a la clienta', h('strong', { id: 'exchange-back' }, formatMoney(backMinor))),
                h('label', {}, 'Devolver la diferencia en', differenceKind),
                h('label', {}, 'Referencia de la transferencia', differenceReference),
              ]
            : null,
        );
      };
      const drawExchange = () => {
        replace(
          exchangeLines,
          newLines.map((line, index) =>
            h(
              'div',
              { class: 'row', dataset: { item: line.itemId } },
              h('span', {}, `${line.name} · ${line.quantity} × ${formatMoney(line.unitPriceMinor)}`),
              h(
                'button',
                {
                  type: 'button',
                  'aria-label': `Quitar ${line.name} del cambio`,
                  onclick: () => {
                    if (!current() || pending || busy) return;
                    newLines = newLines.filter((_, i) => i !== index);
                    attempt = null;
                    drawExchange();
                  },
                },
                'Quitar',
              ),
            ),
          ),
        );
        drawBalance();
      };
      const addExchange = async () => {
        try {
          if (!current() || pending || busy) return;
          const code = exchangeCode.value.trim();
          if (!code) return;
          const found = await api.lookup(code);
          if (!current() || pending) return;
          if (found.length !== 1)
            throw new Error(found.length ? 'Hay varias prendas con ese código. Use el SKU.' : `No se encontró «${code}».`);
          const row = found[0];
          if (row.unitPriceMinor == null) throw new Error('La prenda no tiene precio de venta.');
          const item = itemFromLookup(row);
          const existing = newLines.findIndex(l => l.itemId === item.itemId);
          newLines =
            existing === -1
              ? [...newLines, { ...item, quantity: 1 }]
              : newLines.map((l, i) => (i === existing ? { ...l, quantity: l.quantity + 1 } : l));
          exchangeCode.value = '';
          attempt = null;
          status.textContent = '';
          drawExchange();
        } catch (error) {
          if (current()) showError(status, error);
        }
      };
      exchangeCode.addEventListener('keydown', event => {
        if (event.key === 'Enter') {
          event.preventDefault();
          addExchange();
        }
      });
      const drawOutcome = () =>
        replace(
          outcomePanel,
          outcome === 'credit'
            ? [
                h('p', {}, 'Se emite un anticipo a nombre de la clienta. No sale efectivo de caja.'),
                sale.customerId ? null : chooseCustomer,
              ]
            : null,
          outcome === 'cash' ? h('p', {}, 'Sale efectivo de la caja abierta. Si la caja no alcanza, se rechaza.') : null,
          outcome === 'transfer' ? [h('p', {}, 'La caja no cambia.'), h('label', {}, 'Referencia de la transferencia', reference)] : null,
          outcome === 'exchange'
            ? [
                h(
                  'div',
                  { class: 'row' },
                  h('label', {}, 'Prenda nueva', exchangeCode),
                  h('button', { type: 'button', id: 'exchange-add', onclick: addExchange }, 'Agregar'),
                ),
                exchangeLines,
                h('label', {}, 'Vendedor del cambio', exchangeSeller),
                balance,
              ]
            : null,
        );
      const outcomes = h(
        'fieldset',
        { class: 'outcomes', id: 'refund-outcomes' },
        h('legend', {}, 'Cómo se resuelve'),
        OUTCOMES.map(([value, label]) =>
          h(
            'label',
            {},
            h('input', {
              type: 'radio',
              name: 'outcome',
              value,
              id: `outcome-${value}`,
              checked: value === outcome,
              onchange: () => {
                if (!current() || pending || busy) return;
                outcome = value;
                attempt = null;
                status.textContent = '';
                drawOutcome();
              },
            }),
            label,
          ),
        ),
      );
      const drawPreview = () => {
        attempt = null;
        total.textContent = formatMoney(returnMinor());
        drawBalance();
      };
      const lineRows = sale.lines.map(line => {
        const max = remainingQuantity(line);
        return h(
          'div',
          { class: 'return-item' },
          garmentLine(line),
          h(
            'label',
            {},
            `A devolver · ${line.sku} · Máximo ${max}`,
            h('input', {
              id: `return-qty-${line.lineNumber}`,
              type: 'number',
              min: '0',
              max,
              step: '1',
              value: '0',
              disabled: max === 0,
              oninput: e => {
                if (!current() || pending || busy) return;
                quantities[line.lineNumber] = e.target.value;
                drawPreview();
              },
            }),
          ),
        );
      });
      const form = h(
        'form',
        {
          class: 'form',
          oninput: () => {
            if (!pending && !busy) attempt = null;
          },
          onsubmit: async event => {
            event.preventDefault();
            if (!current() || busy || pending) return;
            const disabledBefore = new Map([...form.querySelectorAll('input,select,textarea,button')].map(el => [el, !!el.disabled]));
            busy = true;
            submit.disabled = true;
            status.textContent = '';
            try {
              await withIntentLock(async () => {
                if (!current()) return;
                if (readIntent()) throw Error('Hay una devoluci\u00f3n pendiente. Vuelva a abrir Devoluci\u00f3n.');
                if (typeof sale.currencyCode !== 'string' || !/^[A-Z]{3}$/.test(sale.currencyCode))
                  throw Error('La venta no tiene una moneda verificable.');
                const lines = selectedReturnLines(sale.lines, quantities);
                if (!reason.value.trim()) throw new Error('Indique el motivo de la devolución.');
                if (outcome === 'credit' && !creditCustomerId)
                  throw new Error('Elija la destinataria del anticipo. La venta original no requiere cliente.');
                const returned = lines.map(selected => ({
                  saleLineId: sale.lines.find(row => row.lineNumber === selected.saleLineNumber).saleLineId,
                  quantity: selected.quantity,
                  restockPool: restock.checked ? 'store' : 'quarantine',
                }));
                if (!attempt)
                  attempt =
                    outcome === 'credit'
                      ? {
                          reversalId: api.uuid(),
                          creditId: api.uuid(),
                          tillId: till.tillId,
                          customerId: creditCustomerId,
                          reason: reason.value.trim(),
                          lines: returned,
                        }
                      : outcomeRequest({
                          reversalId: api.uuid(),
                          outcome,
                          tillId: till.tillId,
                          reason: reason.value.trim(),
                          lines: returned,
                          reference: reference.value,
                          exchangeSaleId: api.uuid(),
                          newLines,
                          sellerId: exchangeSeller.value || null,
                          tenderKind: tenderKind.value,
                          tenderReference: tenderReference.value,
                          differenceKind: differenceKind.value,
                          differenceReference: differenceReference.value,
                          returnMinor: returnMinor(),
                        });
                pending = reserveIntent({
                  version: 1,
                  state: 'draft',
                  scope,
                  saleId: id,
                  saleTillId: sale.tillId,
                  currencyCode: sale.currencyCode,
                  endpoint: outcome === 'credit' ? 'credit' : 'outcome',
                  body: attempt,
                  expected: returned.map(line => {
                    const original = sale.lines.find(l => l.saleLineId === line.saleLineId);
                    return { ...line, creditMinor: returnValue({ ...sale, lines: [original] }, { [original.lineNumber]: line.quantity }) };
                  }),
                });
                for (const el of form.querySelectorAll('input,select,textarea,button')) el.disabled = true;
                await sendPending();
                if (!current()) return;
              });
            } catch (error) {
              if (current()) showError(status, error, pending ? 'La operación sigue guardada. No registre otra devolución.' : undefined);
            } finally {
              busy = false;
              if (current()) {
                if (pending) recovery();
                else {
                  for (const [el, disabled] of disabledBefore) el.disabled = disabled;
                  submit.disabled = false;
                  attempt = null;
                }
              }
            }
          },
        },
        ...lineRows,
        h(
          'div',
          { class: 'return-options' },
          h(
            'div',
            { class: 'form' },
            policy ? h('p', { id: 'return-window', class: 'muted' }, `Plazo: ${policy.windowDays} días desde la venta.`) : null,
            h('label', {}, 'Motivo de la devolución', reason),
            outcomes,
            outcomePanel,
            h('label', { class: 'check' }, restock, 'Reingresar al stock disponible'),
          ),
          h('div', { class: 'total' }, 'Importe a devolver', total),
        ),
        h(
          'div',
          { class: 'actions return-actions' },
          h(
            'button',
            {
              type: 'button',
              onclick: () => {
                if (current()) ctx.go('historial');
              },
            },
            'Volver',
          ),
          submit,
        ),
      );
      drawOutcome();
      drawExchange();
      replace(panel, h('h2', {}, `Devolución · ${id}`), form);
    } catch (error) {
      if (current()) showError(status, error);
    }
    return handle;
  },
};
