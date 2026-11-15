import { createFakeApi, DEMO_USERS } from '/demo/api/index.mjs';

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
const { landing } = await import('/roles.mjs');
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
reset.textContent = 'Reiniciar demo';
const error = document.createElement('span');
error.setAttribute('role', 'alert');
error.hidden = true;
banner.append(title, label, reset, error);
document.body.prepend(banner);
const measure = () => document.documentElement.style.setProperty('--demo-height', `${banner.getBoundingClientRect().height}px`);
new ResizeObserver(measure).observe(banner);
measure();
picker.addEventListener('change', async () => {
  if (!picker.value) return;
  picker.disabled = true;
  reset.disabled = true;
  try {
    const user = DEMO_USERS.find(user => user.role === picker.value);
    if (!user) throw new Error('Rol no disponible');
    api.setToken((await api.login(user.loginName, 'demo')).token);
    history.replaceState(null, '', `/#/${landing([user.role])}`);
    location.reload();
  } catch (cause) {
    error.hidden = false;
    error.textContent = cause.message;
    picker.disabled = false;
    reset.disabled = false;
  }
});
reset.addEventListener('click', async () => {
  try {
    await fake.reset();
    api.setToken(null);
    sessionStorage.removeItem('savia.token');
    location.reload();
  } catch (cause) {
    error.hidden = false;
    error.textContent = cause.message;
  }
});
await import(document.querySelector('script[data-app]').dataset.app);
