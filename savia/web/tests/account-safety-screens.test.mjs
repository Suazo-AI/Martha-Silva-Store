// V064 and DAY-ZERO.md gap 3, mounted: the password screen (forced and chosen), the Ajustes button and the hub's
// supplier form, on a minimal DOM. jsdom-free: this checks wiring and calls, not layout or a real browser.
import assert from 'node:assert/strict';
import test from 'node:test';

class Element {
  constructor(tag, text = '') {
    this.tag = tag;
    this.attributes = {};
    this.dataset = {};
    this.children = [];
    this.listeners = {};
    this.text = text;
    this.value = '';
    this.className = '';
    this.disabled = false;
  }
  setAttribute(key, value) {
    this.attributes[key] = value;
  }
  addEventListener(type, handler) {
    this.listeners[type] = handler;
  }
  append(...children) {
    this.children.push(...children);
  }
  replaceChildren(...children) {
    this.children = children;
  }
  focus() {}
  select() {}
  get textContent() {
    return this.text + this.children.map(child => child.textContent).join('');
  }
  set textContent(value) {
    this.children = [];
    this.text = String(value);
  }
  find(id) {
    if (this.attributes.id === id) return this;
    for (const child of this.children) {
      const found = child.find?.(id);
      if (found) return found;
    }
    return null;
  }
  buttons() {
    const own = this.tag === 'button' ? [this] : [];
    return own.concat(...this.children.map(child => child.buttons?.() ?? []));
  }
}
globalThis.Node = Element;
globalThis.document = { title: '', createElement: tag => new Element(tag), createTextNode: text => new Element('#text', text) };
globalThis.localStorage = { getItem: () => null, setItem() {} };
const calls = [];
let failNextWrite = false;
globalThis.fetch = async (url, init = {}) => {
  calls.push({ method: init.method ?? 'GET', url: String(url), body: init.body ? JSON.parse(init.body) : null });
  if ((init.method ?? 'GET') !== 'GET' && failNextWrite) {
    failNextWrite = false;
    return new Response(JSON.stringify({ code: 'sql.unavailable', title: 'No disponible' }), {
      status: 503,
      headers: { 'content-type': 'application/problem+json' },
    });
  }
  if ((init.method ?? 'GET') !== 'GET') return new Response(null, { status: 204 });
  return new Response('[]', { status: 200, headers: { 'content-type': 'application/json' } });
};

const { default: password } = await import('../screens/password.mjs');
const { default: importer } = await import('../screens/import.mjs');
const { default: settings } = await import('../screens/settings.mjs');

const submit = async form => form.listeners.submit({ preventDefault() {} });
const writes = () => calls.filter(call => call.method !== 'GET');

test('a one-time password shows the forced screen with Salir; a chosen change shows Volver', () => {
  const forced = new Element('main');
  let signedOut = 0;
  password.mount(
    forced,
    { me: { mustChangePassword: true, displayName: 'Dueña' } },
    () => {},
    () => signedOut++,
    () => {},
  );
  assert.match(forced.textContent, /Cambie su contraseña temporal/);
  const exit = forced.buttons().find(button => button.textContent === 'Salir');
  assert.ok(exit, 'the forced screen offers Salir');
  assert.equal(
    forced.buttons().some(button => button.textContent === 'Volver'),
    false,
  );
  exit.listeners.click();
  assert.equal(signedOut, 1);

  const chosen = new Element('main');
  let cancelled = 0;
  password.mount(
    chosen,
    { me: { mustChangePassword: false } },
    () => {},
    () => {},
    () => cancelled++,
  );
  assert.doesNotMatch(chosen.textContent, /temporal/);
  chosen
    .buttons()
    .find(button => button.textContent === 'Volver')
    .listeners.click();
  assert.equal(cancelled, 1);
});

test('the password form checks the rules locally, then posts the change and reports it', async () => {
  calls.length = 0;
  const root = new Element('main');
  let changed = 0;
  password.mount(
    root,
    { me: { mustChangePassword: true } },
    async () => changed++,
    () => {},
    () => {},
  );
  const form = root.children[0];
  root.find('password-current').value = 'clave-temporal-1';
  root.find('password-new').value = 'corta';
  root.find('password-repeat').value = 'corta';
  await submit(form);
  assert.deepEqual(writes(), [], 'a weak password is refused before any call');
  assert.match(form.textContent, /al menos 10/);

  root.find('password-new').value = 'clave-nueva-local-1';
  root.find('password-repeat').value = 'clave-nueva-local-1';
  await submit(form);
  assert.deepEqual(writes(), [
    { method: 'POST', url: '/api/v1/auth/password', body: { currentPassword: 'clave-temporal-1', newPassword: 'clave-nueva-local-1' } },
  ]);
  assert.equal(changed, 1);
});

test('Ajustes offers the password change to every signed-in person', async () => {
  const root = new Element('main');
  let asked = 0;
  await settings.mount(root, { me: { nodeKind: 'Branch' }, roles: [], isApprover: false, changePassword: () => asked++ });
  root.find('change-password').listeners.click();
  assert.equal(asked, 1);
});

test('the supplier form appears on the hub only and posts the name with one id across retries', async () => {
  const store = new Element('main');
  await importer.mount(store, { me: { nodeKind: 'Branch' }, isCurrent: () => true, notify() {}, go() {} });
  assert.equal(store.find('supplier-form'), null);

  calls.length = 0;
  const hub = new Element('main');
  await importer.mount(hub, { me: { nodeKind: 'Cloud' }, isCurrent: () => true, notify() {}, go() {} });
  const form = hub.find('supplier-form');
  assert.ok(form, 'the hub shows the supplier form');
  hub.find('supplier-name').value = '   ';
  await submit(form);
  assert.deepEqual(writes(), []);

  hub.find('supplier-name').value = ' Proveedor Uno ';
  failNextWrite = true;
  await submit(form);
  assert.equal(hub.find('supplier-name').value, ' Proveedor Uno ', 'a failed create keeps the name for a retry');
  await submit(form);
  const [failed, created] = writes();
  assert.equal(created.method, 'POST');
  assert.equal(created.url, '/api/v1/suppliers');
  assert.equal(created.body.name, 'Proveedor Uno');
  assert.match(created.body.supplierId, /^[0-9a-f-]{36}$/);
  assert.equal(failed.body.supplierId, created.body.supplierId, 'the retry reuses the id, so the server can dedupe');
  assert.match(form.textContent, /Proveedor creado: Proveedor Uno/);
  assert.equal(hub.find('supplier-name').value, '');
});
