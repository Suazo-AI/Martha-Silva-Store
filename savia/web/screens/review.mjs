// Recepción · Revisar y aprobar. A supervisor approves, then posts; stock changes only on post.
import * as api from '../api.mjs';
import { h, replace, showError, showOk, clearMessage } from '../ui.mjs';
import { current, loadState, lineView } from './reception-data.mjs';

const STATUS = { counting: 'Contando', approved: 'Aprobada', posted: 'Registrada en inventario', closed: 'Cerrada' };

export default {
  title: 'Revisar recepción',
  async mount(root, ctx) {
    const session = current.get();
    if (!session) {
      replace(root, h('div', { class: 'page' }, h('section', { class: 'panel' },
        h('h2', {}, 'No hay recepción abierta en este equipo'),
        h('a', { href: '#/recepcion' }, 'Empezar una recepción'))));
      return { handleScan: () => ctx.notify('Para escanear, vaya a Recepción.') };
    }
    const message = h('p', { class: 'error', role: 'alert' });
    const summary = h('section', { class: 'panel', 'aria-labelledby': 'sum-title' });
    const linesPanel = h('section', { class: 'panel', 'aria-labelledby': 'rev-lines-title' });
    const actions = h('section', { class: 'panel', 'aria-labelledby': 'act-title' });
    const result = h('section', { class: 'panel', id: 'post-result', hidden: true, 'aria-live': 'polite' });
    replace(root, h('div', { class: 'page' }, h('div', { class: 'split' },
      h('div', { style: 'display:grid;gap:14px;min-width:0' }, summary, linesPanel),
      h('div', { style: 'display:grid;gap:14px;min-width:0' }, actions, result))));

    let state = null;
    const draw = () => {
      const p = state.progress;
      replace(summary,
        h('h2', { id: 'sum-title' }, session.reference),
        h('div', { class: 'row' }, h('span', {}, 'Estado'), h('strong', { id: 'rev-status' }, STATUS[p.status] ?? p.status)),
        h('div', { class: 'row' }, h('span', {}, 'Lecturas'), h('strong', { class: 'num' }, String(p.scanEvents))),
        h('div', { class: 'row' }, h('span', {}, 'Piezas reconocidas'), h('strong', { class: 'num', id: 'rev-matched' }, String(p.matchedUnits))),
        h('div', { class: 'row' }, h('span', {}, 'Piezas con código nuevo'), h('strong', { class: 'num' }, String(p.unitsPendingReview))),
        p.unitsPendingReview > 0 ? h('p', { class: 'warning' }, 'Hay códigos nuevos. Regístrelos antes de aprobar.') : null);
      replace(linesPanel,
        h('h2', { id: 'rev-lines-title' }, 'Prendas'),
        h('p', { class: 'totals' }, state.totals),
        h('div', { class: 'lines' }, state.lines.map(line => lineView(line))));
      drawActions();
    };

    const drawActions = () => {
      const status = state.progress.status;
      const items = [h('h2', { id: 'act-title' }, 'Aprobación'), h('p', { class: 'notice', style: 'margin:0' }, 'El inventario cambia al registrar la recepción aprobada.')];
      if (!ctx.isApprover) {
        items.push(h('p', {}, 'Una supervisora debe aprobar esta recepción. Pídale que ingrese en este equipo.'));
        items.push(h('a', { href: '#/recepcion' }, 'Volver a escanear'));
      } else if (status === 'counting') {
        items.push(h('button', { class: 'primary big', type: 'button', id: 'approve', disabled: state.progress.unitsPendingReview > 0, onclick: approve }, 'Aprobar recepción'));
        items.push(h('a', { href: '#/recepcion' }, 'Volver a escanear'));
      } else if (status === 'approved') {
        items.push(h('button', { class: 'primary big', type: 'button', id: 'post', onclick: post }, 'Registrar en inventario'));
      } else {
        items.push(h('p', {}, `Estado: ${STATUS[status] ?? status}.`));
      }
      items.push(message);
      if (status === 'posted' || status === 'closed' || result.dataset.done) {
        items.push(h('button', { type: 'button', onclick: finish }, 'Terminar y empezar otra recepción'));
      }
      replace(actions, ...items);
    };

    const reload = async () => {
      state = await loadState(current.get());
      draw();
    };

    const approve = async event => {
      event.currentTarget.disabled = true;
      clearMessage(message);
      try {
        await api.approveReception(session.sessionId);
        await reload();
        document.getElementById('post')?.focus();
      } catch (error) {
        showError(message, error, error.code === 'receiving.unresolved_codes' ? 'Registre los códigos nuevos y vuelva a aprobar.' : 'Revise y vuelva a intentar.');
        drawActions();
      }
    };

    const post = async event => {
      event.currentTarget.disabled = true;
      clearMessage(message);
      try {
        const receipt = await api.postReception(session.sessionId);
        await reload();
        await showResult(receipt);
        showOk(message, 'Recepción registrada en inventario.');
      } catch (error) {
        showError(message, error, 'Vuelva a intentar: registrar dos veces da el mismo recibo.');
        drawActions();
      }
    };

    const showResult = async receipt => {
      const itemIds = [...new Set(state.lines.map(l => l.itemId).filter(Boolean))];
      const stockRows = (await Promise.all(itemIds.map(id => api.stock(id)))).flat();
      let jobs = [];
      let jobsError = null;
      try { jobs = (await api.labelJobs()).filter(j => itemIds.includes(j.itemId)); } catch (error) { jobsError = error; }
      result.hidden = false;
      result.dataset.done = '1';
      replace(result,
        h('h2', {}, 'Resultado'),
        h('p', { class: 'muted num' }, `Recibo ${receipt.receiptId}`),
        h('h3', {}, 'Inventario ahora'),
        h('div', { class: 'lines', id: 'post-stock' }, stockRows.map(row => h('div', { class: 'rline' }, h('div', {}, h('strong', {}, row.variantName), h('p', { class: 'num' }, `SKU ${row.sku} · ${row.pool === 'store' ? 'Tienda' : row.pool}`)),
          h('span', { class: 'qty', dataset: { item: row.itemId }, 'aria-label': `Existencia ${row.onHand}` }, String(row.onHand))))),
        h('h3', {}, 'Etiquetas en cola'),
        jobsError ? h('p', { class: 'error' }, jobsError.message) : null,
        jobs.length === 0 && !jobsError ? h('p', { class: 'muted' }, 'No hay etiquetas en cola para estas prendas.') : null,
        h('div', { class: 'table-wrap' }, jobs.length ? h('table', { id: 'label-jobs' },
          h('thead', {}, h('tr', {}, h('th', {}, 'SKU'), h('th', {}, 'Código de barras'), h('th', { class: 'n' }, 'Copias'), h('th', {}, 'Estado'))),
          h('tbody', {}, jobs.map(j => h('tr', {}, h('td', {}, j.sku), h('td', { class: 'num' }, j.barcode),
            h('td', { class: 'n' }, String(j.copiesRequested)), h('td', {}, labelStatus(j.status)))))) : null));
      drawActions();
    };

    const finish = () => {
      current.set(null);
      ctx.go('recepcion');
    };

    try {
      await reload();
    } catch (error) {
      replace(actions, h('h2', { id: 'act-title' }, 'Aprobación'), message);
      showError(message, error);
    }
    return { handleScan: () => ctx.notify('Para escanear, vuelva a «Recepción».') };
  },
};

function labelStatus(status) {
  return { waiting_config: 'Esperando impresora configurada', pending: 'Pendiente', printed: 'Impresa', failed: 'Falló' }[status] ?? status;
}
