import * as api from '../api.mjs';
import { confirmAction } from '../confirm.mjs';
import { h, replace, showError } from '../ui.mjs';
import { formatMoney } from '../money.mjs';
import { FIELDS, guessMapping, mappingKey, mapRows, toBase64 } from './import-logic.mjs';

const remembered = headers => { try { return JSON.parse(localStorage.getItem(mappingKey(headers)) ?? 'null'); } catch { return null; } };
const remember = (headers, mapping) => { try { localStorage.setItem(mappingKey(headers), JSON.stringify(mapping)); } catch { /* the mapping is a convenience */ } };

export default {
  title: 'Importar catálogo',
  async mount(root, ctx) {
    const status = h('p', { role: 'alert', id: 'import-status' });
    const mapPanel = h('section', { class: 'panel', id: 'import-map', hidden: true });
    const previewPanel = h('section', { class: 'panel', id: 'import-preview', hidden: true });
    let file = null;
    let mapping = {};
    let request = null;
    const input = h('input', { id: 'import-file', type: 'file', accept: '.csv,.xlsx,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      onchange: async () => {
        status.textContent = ''; previewPanel.hidden = true; request = null;
        try {
          const chosen = input.files?.[0];
          if (!chosen) return;
          file = await api.importFile(chosen.name, toBase64(new Uint8Array(await chosen.arrayBuffer())));
          mapping = { ...guessMapping(file.headers), ...(remembered(file.headers) ?? {}) };
          drawMap();
        } catch (error) { mapPanel.hidden = true; showError(status, error); }
      } });
    const drawMap = () => {
      mapPanel.hidden = false;
      replace(mapPanel, h('h2', {}, `${file.fileName} · ${file.rows.length} filas`),
        h('div', { class: 'import-map' }, FIELDS.map(([field, label]) => h('label', {}, label,
          h('select', { id: `map-${field}`, onchange: e => { mapping = { ...mapping, [field]: Number(e.target.value) }; request = null; previewPanel.hidden = true; } },
            h('option', { value: '-1' }, 'Sin columna'),
            file.headers.map((header, index) => h('option', { value: String(index), selected: mapping[field] === index }, header || `Columna ${index + 1}`)))))),
        h('div', { class: 'actions' }, h('button', { type: 'button', id: 'import-preview-button', class: 'primary', onclick: preview }, 'Revisar filas')));
    };
    const preview = async () => {
      status.textContent = '';
      try {
        remember(file.headers, mapping);
        request = { batchId: api.uuid(), fileName: file.fileName, rows: mapRows(file.rows, mapping) };
        const result = await api.previewImport(request);
        previewPanel.hidden = false;
        replace(previewPanel, h('h2', {}, 'Revisión'),
          h('div', { class: 'report-totals' },
            ...[['rowsCount', 'Filas'], ['validCount', 'Filas válidas'], ['errorCount', 'Filas con error'], ['unitsCount', 'Existencia inicial']].map(([key, label]) =>
              h('div', { class: 'panel' }, h('span', {}, label), h('strong', { id: `import-${key}` }, String(result[key]))))),
          result.errors.length
            ? h('div', { class: 'table-wrap' }, h('table', { id: 'import-errors' }, h('thead', {}, h('tr', {}, ['Fila', 'Código', 'Error'].map(label => h('th', { scope: 'col' }, label)))),
              h('tbody', {}, result.errors.map(row => h('tr', { dataset: { row: row.row } }, h('td', {}, String(row.row)), h('td', {}, row.code ?? '—'), h('td', {}, row.message))))))
            : h('div', { class: 'table-wrap' }, h('table', { id: 'import-sample' }, h('thead', {}, h('tr', {}, ['Fila', 'Código', 'SKU', 'Prenda', 'Talla', 'Color', 'Costo', 'Precio', 'Existencia'].map(label => h('th', { scope: 'col' }, label)))),
              h('tbody', {}, result.sample.map(row => h('tr', {}, [row.row, row.code, row.sku, row.name, row.size ?? '—', row.color ?? '—',
                row.costMinor == null ? '—' : formatMoney(row.costMinor), formatMoney(row.priceMinor), row.stock].map(value => h('td', {}, String(value)))))))),
          h('div', { class: 'actions' }, result.errorCount
            ? h('p', {}, 'Corrija el archivo o el mapeo y vuelva a revisar.')
            : h('button', { type: 'button', id: 'import-confirm', class: 'primary big', onclick: () => commit(result) }, 'Importar catálogo')));
      } catch (error) { showError(status, error); }
    };
    const commit = async summary => {
      status.textContent = '';
      try {
        if (!await confirmAction(`Se crearán ${summary.rowsCount} prendas con ${summary.unitsCount} unidades de existencia inicial en un solo lote.`)) return;
        const done = await api.importCatalog(request);
        replace(previewPanel, h('h2', {}, 'Catálogo importado'),
          h('p', { id: 'import-batch' }, `Lote ${done.batchId}`),
          h('p', { id: 'import-created' }, `${done.itemsCreated} prendas · ${done.unitsAdded} unidades`),
          h('div', { class: 'actions' }, h('button', { type: 'button', onclick: () => ctx.go('inventario') }, 'Ver inventario')));
        mapPanel.hidden = true; input.value = '';
      } catch (error) { showError(status, error); }
    };
    replace(root, h('div', { class: 'page' }, h('section', { class: 'panel form' }, h('label', {}, 'Archivo CSV o Excel (.xlsx)', input)), status, mapPanel, previewPanel));
    return { handleScan: () => ctx.notify('Elija un archivo para importar.') };
  },
};
