import * as api from '../api.mjs';
import { confirmAction } from '../confirm.mjs';
import { formatMoney } from '../money.mjs';
import { h, replace, showError } from '../ui.mjs';
import { FIELDS, guessMapping, mappingKey, mapRows, toBase64 } from './import-logic.mjs';

const remembered = headers => {
  try {
    return JSON.parse(localStorage.getItem(mappingKey(headers)) ?? 'null');
  } catch {
    return null;
  }
};
const remember = (headers, mapping) => {
  try {
    localStorage.setItem(mappingKey(headers), JSON.stringify(mapping));
  } catch {
    /* the mapping is a convenience */
  }
};

export default {
  title: 'Importar catálogo',
  async mount(root, ctx) {
    const status = h('p', { role: 'alert', id: 'import-status' });
    const mapPanel = h('section', { class: 'panel', id: 'import-map', hidden: true });
    const previewPanel = h('section', { class: 'panel', id: 'import-preview', hidden: true });
    let file = null;
    let mapping = {};
    let revision = 0;
    const isCurrent = started => started === revision && ctx.isCurrent?.() !== false;
    const invalidatePreview = () => {
      status.textContent = '';
      previewPanel.hidden = true;
      return ++revision;
    };
    const input = h('input', {
      id: 'import-file',
      type: 'file',
      accept: '.csv,.xlsx,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      onchange: async () => {
        const started = invalidatePreview();
        file = null;
        mapPanel.hidden = true;
        try {
          const chosen = input.files?.[0];
          if (!chosen) return;
          const bytes = await chosen.arrayBuffer();
          if (!isCurrent(started)) return;
          const parsed = await api.importFile(chosen.name, toBase64(new Uint8Array(bytes)));
          if (!isCurrent(started)) return;
          file = parsed;
          mapping = { ...guessMapping(file.headers), ...(remembered(file.headers) ?? {}) };
          drawMap();
        } catch (error) {
          if (isCurrent(started)) showError(status, error);
        }
      },
    });
    const drawMap = () => {
      mapPanel.hidden = false;
      replace(
        mapPanel,
        h('h2', {}, `${file.fileName} · ${file.rows.length} filas`),
        h(
          'div',
          { class: 'import-map' },
          FIELDS.map(([field, label]) =>
            h(
              'label',
              {},
              label,
              h(
                'select',
                {
                  id: `map-${field}`,
                  onchange: e => {
                    mapping = { ...mapping, [field]: Number(e.target.value) };
                    invalidatePreview();
                  },
                },
                h('option', { value: '-1' }, 'Sin columna'),
                file.headers.map((header, index) =>
                  h('option', { value: String(index), selected: mapping[field] === index }, header || `Columna ${index + 1}`),
                ),
              ),
            ),
          ),
        ),
        h(
          'div',
          { class: 'actions' },
          h('button', { type: 'button', id: 'import-preview-button', class: 'primary', onclick: preview }, 'Revisar filas'),
        ),
      );
    };
    const preview = async () => {
      if (!file || ctx.isCurrent?.() === false) return;
      const started = invalidatePreview();
      try {
        remember(file.headers, mapping);
        const request = { batchId: api.uuid(), fileName: file.fileName, rows: mapRows(file.rows, mapping) };
        const result = await api.previewImport(request);
        if (!isCurrent(started)) return;
        previewPanel.hidden = false;
        replace(
          previewPanel,
          h('h2', {}, 'Revisión'),
          h(
            'div',
            { class: 'report-totals' },
            ...[
              ['rowsCount', 'Filas'],
              ['validCount', 'Filas válidas'],
              ['errorCount', 'Filas con error'],
              ['unitsCount', 'Existencia inicial'],
            ].map(([key, label]) =>
              h('div', { class: 'panel' }, h('span', {}, label), h('strong', { id: `import-${key}` }, String(result[key]))),
            ),
          ),
          result.errors.length
            ? h(
                'div',
                { class: 'table-wrap' },
                h(
                  'table',
                  { id: 'import-errors' },
                  h(
                    'thead',
                    {},
                    h(
                      'tr',
                      {},
                      ['Fila', 'Código', 'Error'].map(label => h('th', { scope: 'col' }, label)),
                    ),
                  ),
                  h(
                    'tbody',
                    {},
                    result.errors.map(row =>
                      h(
                        'tr',
                        { dataset: { row: row.row } },
                        h('td', {}, String(row.row)),
                        h('td', {}, row.code ?? '—'),
                        h('td', {}, row.message),
                      ),
                    ),
                  ),
                ),
              )
            : h(
                'div',
                { class: 'table-wrap' },
                h(
                  'table',
                  { id: 'import-sample' },
                  h(
                    'thead',
                    {},
                    h(
                      'tr',
                      {},
                      ['Fila', 'Código', 'SKU', 'Prenda', 'Talla', 'Color', 'Costo', 'Precio', 'Existencia'].map(label =>
                        h('th', { scope: 'col' }, label),
                      ),
                    ),
                  ),
                  h(
                    'tbody',
                    {},
                    result.sample.map(row =>
                      h(
                        'tr',
                        {},
                        [
                          row.row,
                          row.code,
                          row.sku,
                          row.name,
                          row.size ?? '—',
                          row.color ?? '—',
                          row.costMinor == null ? '—' : formatMoney(row.costMinor),
                          formatMoney(row.priceMinor),
                          row.stock,
                        ].map(value => h('td', {}, String(value))),
                      ),
                    ),
                  ),
                ),
              ),
          h(
            'div',
            { class: 'actions' },
            result.errorCount
              ? h('p', {}, 'Corrija el archivo o el mapeo y vuelva a revisar.')
              : h(
                  'button',
                  { type: 'button', id: 'import-confirm', class: 'primary big', onclick: () => commit(result, request, started) },
                  'Importar catálogo',
                ),
          ),
        );
      } catch (error) {
        if (isCurrent(started)) showError(status, error);
      }
    };
    const commit = async (summary, request, started) => {
      if (!isCurrent(started)) return;
      status.textContent = '';
      try {
        const confirmed = await confirmAction(
          `Se crearán ${summary.rowsCount} prendas con ${summary.unitsCount} unidades de existencia inicial en un solo lote.`,
        );
        if (!confirmed || !isCurrent(started)) return;
        const done = await api.importCatalog(request);
        if (!isCurrent(started)) return;
        replace(
          previewPanel,
          h('h2', {}, 'Catálogo importado'),
          h('p', { id: 'import-batch' }, `Lote ${done.batchId}`),
          h('p', { id: 'import-created' }, `${done.itemsCreated} prendas · ${done.unitsAdded} unidades`),
          h('div', { class: 'actions' }, h('button', { type: 'button', onclick: () => ctx.go('inventario') }, 'Ver inventario')),
        );
        mapPanel.hidden = true;
        input.value = '';
      } catch (error) {
        if (isCurrent(started)) showError(status, error);
      }
    };
    replace(
      root,
      h(
        'div',
        { class: 'page' },
        h('section', { class: 'panel form' }, h('label', {}, 'Archivo CSV o Excel (.xlsx)', input)),
        status,
        mapPanel,
        previewPanel,
      ),
    );
    return { handleScan: () => ctx.notify('Elija un archivo para importar.') };
  },
};
