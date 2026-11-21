import * as api from '../api.mjs';
import { h, replace, showError } from '../ui.mjs';
import { businessDate } from './sale-view.mjs';

export default {
  title: 'Calidad de recepción',
  async mount(root) {
    const today = businessDate();
    const from = h('input', { type: 'date', value: `${today.slice(0, 8)}01` }),
      to = h('input', { type: 'date', value: today });
    const message = h('p', { role: 'alert' }),
      rows = h('div', { id: 'quality-report', class: 'form' });
    const load = async () => {
      try {
        const report = await api.qualityReport(from.value, to.value);
        replace(
          rows,
          report.length
            ? report.map(row =>
                h(
                  'article',
                  { class: 'panel' },
                  h('h2', {}, row.supplierName),
                  h(
                    'p',
                    {},
                    `Buena: ${row.buena} · Dañada: ${row.danada} · Manchada: ${row.manchada} · Mal olor: ${row.malOlor} · Faltante: ${row.faltante}`,
                  ),
                ),
              )
            : h('p', {}, 'Sin recepciones registradas en este periodo.'),
        );
      } catch (error) {
        showError(message, error);
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
          h(
            'div',
            { class: 'actions' },
            h('label', {}, 'Desde', from),
            h('label', {}, 'Hasta', to),
            h('button', { type: 'button', onclick: load }, 'Consultar calidad'),
          ),
          message,
          rows,
        ),
      ),
    );
    await load();
    return {};
  },
};
