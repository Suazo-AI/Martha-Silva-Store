import { roleSummary } from '../roles.mjs';
import { device, h, replace } from '../ui.mjs';
export function applyPalette(value) {
  const palette = ['bosque', 'tinta', 'malva'].includes(value) ? value : 'bosque';
  if (palette === 'bosque') delete document.documentElement.dataset.palette;
  else document.documentElement.dataset.palette = palette;
}
export default {
  title: 'Ajustes',
  mount(root, ctx) {
    const palette = device.get('palette') ?? 'bosque';
    const picker = h(
      'fieldset',
      { class: 'palette-picker', id: 'palette-picker' },
      h('legend', {}, 'Color de este equipo'),
      ['bosque', 'tinta', 'malva'].map(value =>
        h(
          'label',
          {},
          h('input', {
            type: 'radio',
            name: 'savia-palette',
            value,
            checked: value === palette,
            onchange: () => {
              device.set('palette', value);
              applyPalette(value);
            },
          }),
          h('span', {}, value[0].toUpperCase() + value.slice(1)),
        ),
      ),
    );
    replace(
      root,
      h(
        'div',
        { class: 'page' },
        h(
          'section',
          { class: 'panel' },
          h('h2', {}, 'Preferencias'),
          picker,
          h('p', {}, 'El color se conserva en este equipo.'),
          h(
            'div',
            { id: 'settings-role' },
            roleSummary(ctx.roles).map(text => h('p', {}, text)),
          ),
          h('p', { id: 'sample-notice' }, 'Datos de prueba: los productos, precios y personas son ejemplos.'),
          h('a', { href: '/scanner/scanner-test.html' }, 'Probar el escáner'),
        ),
      ),
    );
    return {};
  },
};
