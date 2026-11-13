import * as api from '../api.mjs';
import { h, replace, showError } from '../ui.mjs';
import { formatMoney } from '../money.mjs';
import { saleDate } from './sale-view.mjs';
const name={descuento:'Descuento',devolucion:'Devolución',excepcion:'Excepción de inventario',precio:'Cambio de precio',anulacion:'Anulación'};

export default {
  title: 'Aprobaciones',
  async mount(root) {
    const status = h('p', {role:'alert'});
    const rows = h('div', {id:'approval-list', class:'form'});
    replace(root, h('div', {class:'page'}, h('section', {class:'panel'},
      h('h2', {}, 'Acciones autorizadas'),
      h('p', {}, 'Revise quién autorizó cada acción, su importe y su motivo.'), status, rows)));
    try {
      const entries = await api.approvals();
      replace(rows, entries.length ? entries.map(row => h('article', {class:'panel'},
        h('strong', {}, `${name[row.kind]??row.kind} · ${formatMoney(row.amountMinor)}`),
        h('p', {}, row.what), h('p', {}, `${row.actorName ?? 'Sin nombre'} · ${saleDate(row.time)}`),
        h('p', {}, row.reason ?? 'Sin motivo registrado'))) : h('p', {}, 'No hay aprobaciones registradas.'));
    } catch (error) { showError(status,error); }
    return {};
  },
};
