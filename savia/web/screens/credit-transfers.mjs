import * as api from '../api.mjs';
import { confirmAction } from '../confirm.mjs';
import { formatMoney } from '../money.mjs';
import { h, replace, showError } from '../ui.mjs';
import { statusLabel, transferActions } from './credit-transfers-logic.mjs';
import { saleDate } from './sale-view.mjs';

/** Open and recent credit transfers of this node, with the steps this node owns. A store requests from Clientes. */
export default {
  title: 'Traslados de anticipo',
  async mount(root, ctx) {
    const status = h('p', { role: 'alert' });
    const list = h('div', { id: 'credit-transfers', class: 'lines' });

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

    const actions = row => {
      const amount = formatMoney(row.amountMinor, row.currencyCode);
      const what = `${amount} de ${row.customerName}`;
      const reason = h('input', { 'aria-label': `Motivo de la cancelación · ${row.customerName}`, maxlength: 400, placeholder: 'Motivo' });
      const step = (name, label, sentence, call) =>
        h('button', { type: 'button', dataset: { step: name }, onclick: e => act(e.target, sentence, () => call(row.transferId)) }, label);
      const buttons = {
        approve: step(
          'approve',
          'Aprobar',
          `Se aprobará el traslado de ${what} de ${row.fromBranchName} a ${row.toBranchName}.`,
          api.approveCreditTransfer,
        ),
        cancel: h(
          'button',
          {
            type: 'button',
            class: 'secondary',
            dataset: { step: 'cancel' },
            onclick: e => {
              if (!reason.value.trim()) {
                status.textContent = 'Escriba el motivo de la cancelación.';
                reason.focus();
                return;
              }
              return act(e.target, `Se cancelará el traslado de ${what}.`, () =>
                api.cancelCreditTransfer(row.transferId, reason.value.trim()),
              );
            },
          },
          'Cancelar',
        ),
        dispatch: step(
          'dispatch',
          'Enviar',
          `Se enviará ${what} a ${row.toBranchName}. El saldo sale de esta sucursal.`,
          api.dispatchCreditTransfer,
        ),
        receive: step(
          'receive',
          'Recibir',
          `Se recibirá ${what} desde ${row.fromBranchName}. El saldo queda en esta sucursal.`,
          api.receiveCreditTransfer,
        ),
      };
      const chosen = transferActions(row, ctx.me?.nodeKind, ctx.me?.branchId);
      return chosen.length
        ? h(
            'div',
            { class: 'actions' },
            chosen.includes('cancel') ? reason : null,
            chosen.map(a => buttons[a]),
          )
        : null;
    };

    const card = row =>
      h(
        'section',
        { class: 'panel', dataset: { transfer: row.transferId, status: row.status } },
        h('h2', {}, `${row.customerName} · ${formatMoney(row.amountMinor, row.currencyCode)}`),
        h('p', {}, `${row.fromBranchName} → ${row.toBranchName} · ${statusLabel(row.status)}`),
        h('p', { class: 'muted' }, `${row.reason} · solicitado ${saleDate(row.requestedAt)}`),
        actions(row),
      );

    const load = async () => {
      try {
        const rows = await api.creditTransfers();
        replace(list, rows.length ? rows.map(card) : h('p', {}, 'No hay traslados de anticipo.'));
      } catch (error) {
        showError(status, error);
      }
    };

    replace(root, h('div', { class: 'page' }, status, list));
    await load();
    return { handleScan: () => ctx.notify('Los traslados no usan el escáner.') };
  },
};
