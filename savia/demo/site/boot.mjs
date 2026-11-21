import { createFakeApi, DEMO_USERS } from '/demo/api/index.mjs';
import { id, users } from '/demo/api/seed.mjs';

const fake = createFakeApi({ storage: globalThis.localStorage, now: () => new Date() });
const originalFetch = globalThis.fetch.bind(globalThis);
globalThis.fetch = async (input, init = {}) => {
  const url = new URL(input instanceof Request ? input.url : input, location.href);
  if (url.origin !== location.origin || !url.pathname.startsWith('/api/v1')) return originalFetch(input, init);
  const request = input instanceof Request ? input : null;
  const headers = new Headers(init.headers ?? request?.headers);
  let body = init.body ?? null;
  if (request && init.body === undefined && request.body) {
    const copy = request.clone();
    body = headers.get('content-type')?.includes('multipart/form-data') ? await copy.formData() : await copy.text();
  }
  const result = await fake.handle({
    method: (init.method ?? request?.method ?? 'GET').toUpperCase(),
    path: url.pathname.slice('/api/v1'.length) + url.search,
    headers: Object.fromEntries(headers), body,
  });
  const responseHeaders = new Headers(result.headers);
  if (!responseHeaders.has('content-type')) responseHeaders.set('content-type', 'application/json');
  return new Response(result.status === 204 ? null : JSON.stringify(result.body), {
    status: result.status, headers: responseHeaders,
  });
};

// This import runs only after the fetch patch. The app entry is never a sibling module script.
const api = await import('/api.mjs');
const { landing, canAccess, receivesTags } = await import('/roles.mjs');
const { h } = await import('/ui.mjs');
const { confirmAction } = await import('/confirm.mjs');
const { clearPending, readPending, RECOVERY_KEY, sameScope } = await import('/sale-recovery.mjs');
const banner = document.createElement('aside');
banner.id = 'demo-banner';
banner.setAttribute('aria-label', 'Demo');
const title = document.createElement('strong');
title.textContent = 'Demo · datos inventados';
const label = document.createElement('label');
label.textContent = 'Entrar como';
const picker = document.createElement('select');
picker.id = 'demo-role';
picker.setAttribute('aria-label', 'Entrar como');
picker.add(new Option('Entrar como', ''));
for (const [role, name] of [['OWNER', 'Dueña'], ['MANAGER', 'Gerente'], ['SELLER', 'Vendedora'], ['INVENTORY', 'Bodega']]) {
  picker.add(new Option(name, role));
}
label.append(picker);
const reset = document.createElement('button');
reset.type = 'button';
reset.id = 'demo-reset';
reset.textContent = 'Reiniciar demo';
const error = document.createElement('span');
error.setAttribute('role', 'alert');
error.hidden = true;
banner.append(title, label, reset, error);
document.body.prepend(banner);
const measure = () => document.documentElement.style.setProperty('--demo-height', `${banner.getBoundingClientRect().height}px`);
new ResizeObserver(measure).observe(banner);
measure();
const roles = [['MANAGER', 'gerente'], ['OWNER', 'dueña'], ['SELLER', 'vendedora'], ['INVENTORY', 'bodega']];
const currentRole = h('span', { id: 'demo-current-role', role: 'status' });
banner.insertBefore(currentRole, label);
let busy = false;
let activeRole = '';
function controls(disabled) {
  busy = disabled;
  for (const control of document.querySelectorAll('#demo-role, #demo-reset, [data-demo-role]')) control.disabled = disabled;
}
function showError(cause) {
  error.hidden = false;
  error.textContent = `${cause.message || 'No se pudo completar la acción'}. Vuelva a intentar con los controles de la demo.`;
}
async function enter(role) {
  if (busy || !role) return;
  controls(true);
  error.hidden = true;
  try {
    const user = DEMO_USERS.find(user => user.role === role);
    if (!user) throw new Error('Rol no disponible');
    api.setToken((await api.login(user.loginName, 'demo')).token);
    sessionStorage.setItem('savia.demo.focus', 'main');
    if (location.pathname.startsWith('/etiqueta/') && receivesTags([role])) {
      // Keep the etiqueta URL, query and hash for receiving roles.
    } else {
      const route = location.hash.replace(/^#\/?/, '');
      history.replaceState(null, '', `/#/${canAccess(route, [role]) ? route : landing([role])}`);
    }
    location.reload();
  } catch (cause) {
    picker.value = activeRole;
    showError(cause);
    controls(false);
  }
}
picker.addEventListener('change', () => enter(picker.value));
reset.addEventListener('click', async () => {
  if (busy) return;
  controls(true);
  error.hidden = true;
  try {
    // Etiqueta has no shared modal markup. Supply the same accessible helper host.
    if (!document.getElementById('modal')) {
      document.body.append(h('dialog', { id: 'modal', 'aria-labelledby': 'modal-title' }, h('div', { id: 'modal-body' })));
    }
    if (!await confirmAction('Se borrarán las ventas, existencias y cambios inventados de esta demo y se cerrará su sesión. ¿Reiniciar la demo?')) return;
    // Clear only a validated marker belonging to this fictional ledger. Keep all quarantine records.
    const raw = localStorage.getItem(RECOVERY_KEY);
    let pending = null;
    try { pending = readPending(); } catch { /* Unrecognized records require support; a demo reset must preserve them. */ }
    const demoPending = pending && users.some(user => sameScope(pending.scope, {
      origin: location.origin, staffId: user.staffId, nodeId: id(12), branchId: id(11), locationId: id(13),
    }));
    await fake.reset();
    if (demoPending && localStorage.getItem(RECOVERY_KEY) === raw) clearPending(pending);
    api.setToken(null);
    location.reload();
  } catch (cause) {
    showError(cause);
  } finally {
    controls(false);
  }
});

// Only this demo replaces the real app's signed-out presentation. Authentication,
// unauthorized handling and permission checks remain owned by the unchanged app.
const access = document.getElementById('access') ?? document.getElementById('root');
function syncEntry() {
  if (access.querySelector('#login-user')) {
    const entry = h('section', { id: 'demo-entry', class: 'card panel', 'aria-labelledby': 'demo-entry-title' },
      h('div', { class: 'brand' }, 'SAVIA'),
      h('h1', { id: 'demo-entry-title' }, 'Pruebe la demo'),
      h('p', {}, 'Datos inventados. Elija un rol para entrar.'),
      ...roles.map(([role, name]) => h('button', {
        type: 'button', class: role === 'MANAGER' ? 'primary' : '',
        'data-demo-role': role, onclick: () => enter(role),
      }, `Probar como ${name}`)));
    access.replaceChildren(entry);
    picker.value = '';
    activeRole = '';
    currentRole.textContent = '';
    entry.querySelector('button').focus();
  }
  if (sessionStorage.getItem('savia.demo.focus') && !access.querySelector('#demo-entry')) {
    const main = document.getElementById('screen') ?? document.getElementById('root');
    if (main?.childElementCount && !main.closest('[hidden]')) {
      main.tabIndex = -1;
      main.focus();
      sessionStorage.removeItem('savia.demo.focus');
    }
  }
}
new MutationObserver(syncEntry).observe(access, { childList: true, subtree: true });
if (document.getElementById('screen')) new MutationObserver(syncEntry).observe(document.getElementById('screen'), { childList: true, subtree: true });
if (api.getToken()) {
  try {
    const me = await api.me();
    picker.value = me.roles[0];
    activeRole = me.roles[0];
    currentRole.textContent = `Rol actual: ${roles.find(([role]) => role === me.roles[0])?.[1] ?? me.roles[0]}`;
  } catch { api.setToken(null); }
}
await import(document.querySelector('script[data-app]').dataset.app);
