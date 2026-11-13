// Shell, session and router of the SAVIA staff web.
import * as api from './api.mjs';
import { canAccess, isApprover, isOwner, landing, roleName, SCREENS } from './roles.mjs';
import approvals from './screens/approvals.mjs';
import cash from './screens/cash.mjs';
import commissions from './screens/commissions.mjs';
import customers from './screens/customers.mjs';
import exceptions from './screens/exceptions.mjs';
import history from './screens/history.mjs';
import importer from './screens/import.mjs';
import inventory from './screens/inventory.mjs';
import login from './screens/login.mjs';
import prices from './screens/prices.mjs';
import qualityReport from './screens/quality-report.mjs';
import receipt from './screens/receipt.mjs';
import reception from './screens/reception.mjs';
import report from './screens/report.mjs';
import returns from './screens/return.mjs';
import review from './screens/review.mjs';
import sale from './screens/sale.mjs';
import settings, { applyPalette } from './screens/settings.mjs';
import { syncTill } from './screens/till-open.mjs';
import { device, h, replace } from './ui.mjs';

/** The module of each route in roles.mjs SCREENS; start() refuses to run when the two disagree. */
const MODULES = {
  venta: sale,
  ajustes: settings,
  caja: cash,
  recepcion: reception,
  'recepcion/revisar': review,
  inventario: inventory,
  historial: history,
  recibo: receipt,
  devolucion: returns,
  clientes: customers,
  reporte: report,
  excepciones: exceptions,
  aprobaciones: approvals,
  comisiones: commissions,
  precios: prices,
  importar: importer,
  calidad: qualityReport,
};
const $ = id => document.getElementById(id);

const ctx = {
  me: null,
  get roles() {
    return ctx.me?.roles ?? [];
  },
  get isApprover() {
    return isApprover(ctx.roles);
  },
  get isOwner() {
    return isOwner(ctx.roles);
  },
  get branchName() {
    return ctx.me?.branchName || null;
  },
  notify(text) {
    $('notice').textContent = text || '';
  },
  go(route) {
    location.hash = `#/${route}`;
  },
  till: {
    get() {
      return device.get('till');
    },
    set(value) {
      device.set('till', value);
      renderTillState();
    },
  },
  refreshTill: () => renderTillState(),
};

let current = null; // { route, handle }

/** The one entry point for scanners: the active screen decides what a code means. */
export function handleScan(code) {
  return current?.handle?.handleScan?.(code);
}
globalThis.savia = { handleScan };

function renderTillState() {
  const el = $('till-state');
  el.hidden = !ctx.isApprover;
  const till = ctx.till.get();
  el.textContent = till ? `Caja abierta · ${till.cashierName ?? ctx.me?.displayName ?? ''}` : 'Caja cerrada · Abra la caja para vender';
  el.dataset.state = till ? 'open' : 'closed';
}

function renderHeader() {
  $('operator-label').textContent = ctx.me ? `${ctx.me.displayName} · ${ctx.roles.map(roleName).join(', ')}` : '';
  $('branch-label').textContent = ctx.branchName ?? 'Sucursal';
  renderTillState();
}

async function route() {
  const name = (location.hash.replace(/^#\/?/, '') || 'venta').split('?')[0];
  current?.handle?.unmount?.();
  current = null;
  ctx.notify('');
  if (!api.getToken() || !ctx.me) {
    $('shell').hidden = true;
    $('access').hidden = false;
    current = { route: 'ingreso', handle: login.mount($('access'), ctx, onSignedIn) };
    return;
  }
  const screen = MODULES[name] ?? sale;
  $('access').hidden = true;
  $('shell').hidden = false;
  if (ctx.isApprover) await syncTill(ctx);
  renderHeader();
  for (const link of document.querySelectorAll('#nav a')) {
    link.hidden = !canAccess(link.dataset.route, ctx.roles);
    const active = name === link.dataset.route || name.startsWith(`${link.dataset.route}/`);
    if (active) link.setAttribute('aria-current', 'page');
    else link.removeAttribute('aria-current');
  }
  $('title').textContent = screen.title;
  document.title = `SAVIA · ${screen.title}`;
  const root = $('screen');
  replace(root);
  if (!canAccess(name, ctx.roles)) {
    replace(
      root,
      h(
        'div',
        { class: 'page' },
        h('p', { class: 'error', role: 'alert' }, 'Su cuenta no tiene acceso. Elija una pantalla del menú o pida ayuda a la gerente.'),
      ),
    );
    return;
  }
  current = { route: name, handle: await screen.mount(root, ctx) };
}

async function onSignedIn(loginResponse) {
  api.setToken(loginResponse.token);
  ctx.me = await api.me();
  if (!location.hash || location.hash === '#/ingreso' || !canAccess(location.hash.replace(/^#\/?/, ''), ctx.roles))
    location.hash = `#/${landing(ctx.roles)}`;
  else route();
}

async function start() {
  const routes = SCREENS.map(s => s.route);
  const odd = [...routes.filter(r => !MODULES[r]), ...Object.keys(MODULES).filter(r => !routes.includes(r))];
  if (odd.length) throw new Error(`roles.mjs y app.mjs no coinciden en: ${odd.join(', ')}`);
  replace(
    $('nav'),
    SCREENS.filter(s => s.label).map(s => h('a', { href: `#/${s.route}`, dataset: { route: s.route } }, s.label)),
  );
  applyPalette(device.get('palette'));
  $('logout').addEventListener('click', async () => {
    try {
      await api.logout();
    } catch {
      /* the token dies on the server or expires; sign out here either way */
    }
    api.setToken(null);
    ctx.me = null;
    ctx.till.set(null);
    route();
  });
  api.setUnauthorizedHandler(() => {
    api.setToken(null);
    ctx.me = null;
    ctx.till.set(null);
    route();
  });
  window.addEventListener('hashchange', route);
  if (api.getToken()) {
    try {
      ctx.me = await api.me();
    } catch {
      api.setToken(null);
      ctx.me = null;
    }
  }
  route();
}

start().catch(error => {
  replace(document.body, h('p', { class: 'error', role: 'alert' }, `No se pudo iniciar: ${error.message}`));
});
