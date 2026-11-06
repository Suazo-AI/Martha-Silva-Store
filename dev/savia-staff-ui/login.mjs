// Anonymous entry: never imports protected application or business modules.
export const SECURITY_PATHS = Object.freeze({
  csrf: '/internal/api/security/csrf', login: '/internal/api/security/login',
  me: '/internal/api/security/me', logout: '/internal/api/security/logout',
});
export const STAFF_ROLES = Object.freeze(['Owner', 'Manager', 'Cashier', 'Inventory']);
const guid = value => typeof value === 'string'
  && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)
  && value !== '00000000-0000-0000-0000-000000000000';
export class StaffRequestError extends Error {
  constructor(code, status = null) {
    const messages = {
      unauthorized: 'La sesión no está disponible o venció. Volvé a ingresar.',
      forbidden: 'Tu cuenta no tiene permiso para esta operación.',
      invalid: 'El servidor no aceptó los datos. Revisá los campos antes de continuar.',
      sale_rejected: 'La venta fue rechazada. Revisá la sucursal y la cantidad antes de registrar otra.',
      rate_limited: 'Se alcanzó el límite de intentos. Esperá antes de volver a ingresar.',
      unavailable: 'No se pudo confirmar la respuesta del servidor. No se declaró una operación realizada.',
      response: 'La respuesta no coincide con el contrato interno. No se habilitaron operaciones.',
    };
    super(messages[code] || messages.unavailable);
    this.name = 'StaffRequestError'; this.code = code; this.status = status;
  }
}
export function readStaff(value) {
  if (!value || !guid(value.id)
    || typeof value.loginName !== 'string' || !/^[A-Za-z0-9._-]{3,64}$/.test(value.loginName)
    || typeof value.displayName !== 'string' || !value.displayName.trim() || value.displayName.length > 120
    || !STAFF_ROLES.includes(value.role) || value.enabled !== true
    || !guid(value.version)) throw new StaffRequestError('response');
  return Object.freeze({id: value.id, loginName: value.loginName, displayName: value.displayName,
    role: value.role, enabled: true, version: value.version});
}
export function createAuthClient({fetchImpl = globalThis.fetch, timeoutMs = 10000, onUnauthorized = () => {}} = {}) {
  if (typeof fetchImpl !== 'function') throw new Error('El transporte del servidor no está disponible.');
  let csrf = null, session = null, epoch = 0, sessionRead = 0;
  const current = generation => {
    if (generation !== epoch) throw new StaffRequestError('unauthorized', 401);
  };
  async function request(path, {method = 'GET', body, csrfToken, idempotencyKey, allowEmpty = false} = {}) {
    const generation = epoch;
    const controller = new AbortController(); let timer;
    try {
      const headers = {Accept: 'application/json'};
      if (body !== undefined) headers['Content-Type'] = 'application/json';
      if (csrfToken) headers['X-CSRF-TOKEN'] = csrfToken;
      if (idempotencyKey) headers['Idempotency-Key'] = idempotencyKey;
      const response = await Promise.race([
        fetchImpl(path, {method, headers, credentials: 'same-origin', redirect: 'error',
          cache: 'no-store', signal: controller.signal,
          ...(body === undefined ? {} : {body: JSON.stringify(body)})}),
        new Promise((_, reject) => { timer = setTimeout(() => {
          controller.abort(); reject(new StaffRequestError('unavailable'));
        }, timeoutMs); }),
      ]);
      current(generation);
      if (response.status === 401) {
        ++epoch; session = null; csrf = null; onUnauthorized();
        const error = new StaffRequestError('unauthorized', 401);
        if (path === SECURITY_PATHS.login) error.message = 'Usuario o contraseña inválidos. Revisá tus datos de acceso.';
        throw error;
      }
      if (response.status === 403) throw new StaffRequestError('forbidden', 403);
      if (response.status === 429) {
        const error = new StaffRequestError('rate_limited', 429);
        const seconds = Number(response.headers.get('retry-after'));
        error.retryAfterSeconds = Number.isSafeInteger(seconds) && seconds > 0 && seconds <= 3600 ? seconds : 60;
        error.message = `Esperá ${error.retryAfterSeconds} segundos antes de volver a ingresar.`;
        throw error;
      }
      if (!response.ok) throw new StaffRequestError(response.status >= 500 ? 'unavailable' : 'invalid', response.status);
      if (allowEmpty && response.status === 204) return null;
      const type = response.headers.get('content-type')?.split(';')[0].trim().toLowerCase();
      if (type !== 'application/json') throw new StaffRequestError('response', response.status);
      let value;
      try { value = await response.json(); } catch { throw new StaffRequestError('response', response.status); }
      current(generation);
      return value;
    } catch (error) {
      if (error instanceof StaffRequestError) throw error;
      throw new StaffRequestError('unavailable');
    } finally { clearTimeout(timer); }
  }
  async function renewCsrf() {
    const generation = epoch;
    const value = await request(SECURITY_PATHS.csrf);
    current(generation);
    if (value?.headerName !== 'X-CSRF-TOKEN' || typeof value.token !== 'string'
      || !/^[\x21-\x7e]{1,4096}$/.test(value.token)) throw new StaffRequestError('response');
    csrf = value.token;
  }
  async function getSession() {
    const generation = epoch, verification = ++sessionRead;
    session = null; csrf = null;
    try {
      const verified = readStaff(await request(SECURITY_PATHS.me));
      current(generation);
      if (verification !== sessionRead) throw new StaffRequestError('unauthorized', 401);
      ++epoch; session = verified; return session;
    }
    catch (error) { if (generation === epoch) session = null; throw error; }
  }
  async function login({loginName, password}) {
    if (typeof loginName !== 'string' || !loginName.trim() || typeof password !== 'string' || !password) {
      throw new StaffRequestError('invalid');
    }
    ++epoch; session = null; csrf = null; await renewCsrf();
    const result = await request(SECURITY_PATHS.login, {method: 'POST', csrfToken: csrf, body: {loginName, password}});
    const reported = readStaff(result?.staff);
    if (typeof result.expiresAt !== 'string' || !Number.isFinite(Date.parse(result.expiresAt))) throw new StaffRequestError('response');
    await renewCsrf();
    const verified = await getSession();
    if (verified.id !== reported.id) { session = null; throw new StaffRequestError('response'); }
    return verified;
  }
  async function logout() {
    ++epoch; session = null; csrf = null;
    await renewCsrf();
    await request(SECURITY_PATHS.logout, {method: 'POST', csrfToken: csrf, allowEmpty: true});
    csrf = null; session = null;
  }
  return Object.freeze({prepareLogin: renewCsrf, login, getSession, logout,
    requestBusiness: async (path, {method = 'GET', body, key} = {}) => {
      if (!session) throw new StaffRequestError('unauthorized', 401);
      const generation = epoch;
      const sale = path === '/internal/api/commerce/sales' && method === 'POST';
      const read = method === 'GET' && (/^\/internal\/api\/commerce\/inventory\?locationId=[0-9a-f-]+&skip=\d+&take=100$/i.test(path)
        || /^\/internal\/api\/commerce\/sales\/[0-9a-f-]+$/i.test(path));
      const review = /^\/internal\/api\/commerce\/sales\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\/stock-reviews$/i.test(path) && ['GET','POST'].includes(method);
      if(review && !['Owner','Manager'].includes(session.role)) throw new StaffRequestError('forbidden',403);
      const supplyWrite = method === 'POST' && /^\/internal\/api\/supply\/purchase-orders\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\/receipts$/i.test(path);
      const supplyRead = method === 'GET' && (/^\/internal\/api\/supply\/purchase-orders\?skip=\d+&take=50$/.test(path)
        || /^\/internal\/api\/supply\/purchase-orders\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}(?:\/receipts\?skip=\d+&take=50)?$/i.test(path));
      const supplyRecovery = method === 'GET' && path === '/internal/api/operations/supply.receipt.create';
      if ((supplyWrite || supplyRead || supplyRecovery) && !['Owner','Manager','Inventory'].includes(session.role)) throw new StaffRequestError('forbidden',403);
      const reviewRecovery = method === 'GET' && path === '/internal/api/operations/commerce.stock.review';
      if (reviewRecovery && !['Owner','Manager'].includes(session.role)) throw new StaffRequestError('forbidden',403);
      const recovery = method === 'GET' && path === '/internal/api/operations/commerce.sale.record';
      if (!(sale || read || recovery || supplyWrite || supplyRead || supplyRecovery || review || reviewRecovery) || ((sale || recovery || supplyWrite || supplyRecovery || (review && method==='POST') || reviewRecovery) && !guid(key))) throw new StaffRequestError('invalid');
      if (sale || supplyWrite || (review && method==='POST')) await renewCsrf();
      current(generation);
      if (!session) throw new StaffRequestError('unauthorized', 401);
      return request(path, {method, body, idempotencyKey: key, csrfToken: (sale || supplyWrite || (review && method==='POST')) ? csrf : undefined});
    },
    getVerifiedSession: () => session,
    requestAuthenticated: async path => {
      if (!session) throw new StaffRequestError('unauthorized', 401);
      if (!/^\/internal\/api\/directory\/(items|locations|parties)(?:\?[^#]*)?$/.test(path)) throw new StaffRequestError('response');
      return request(path);
    }});
}
export function mountStaffLogin({document = globalThis.document, client = createAuthClient(),
  redirect = path => document.defaultView.location.assign(path)} = {}) {
  if (!document?.querySelector('[data-staff-login]')) throw new Error('No se encontró la pantalla de ingreso.');
  const form = document.querySelector('#login-form'), status = document.querySelector('#login-status');
  const error = document.querySelector('#login-error'), submit = document.querySelector('#login-submit');
  if (!form || !status || !error || !submit) throw new Error('La pantalla de ingreso está incompleta.');
  let phase = 'preparing', destroyed = false, cooldownTimer;
  const lock = value => { for (const control of form.elements) control.disabled = value; };
  function fail(exception) {
    error.textContent = exception instanceof StaffRequestError ? exception.message : 'No se completó la verificación de acceso.';
    error.hidden = false;
  }
  lock(true); error.hidden = true; status.textContent = 'Preparando el ingreso seguro del servidor…';
  const ready = client.prepareLogin().then(() => {
    if (!destroyed) { phase = 'logged-out'; lock(false); status.textContent = 'Ingresá con una cuenta habilitada. Esta pantalla no crea propietarios ni concede permisos.'; }
  }).catch(exception => {
    if (!destroyed) { phase = 'unavailable'; fail(exception); status.textContent = 'No se pudo preparar el acceso. Recargá para volver a comprobarlo.'; }
  });
  const onSubmit = async event => {
    event.preventDefault(); if (phase !== 'logged-out') return;
    const invalid = [...form.elements].find(control => control.willValidate && !control.validity.valid);
    if (invalid) { error.textContent = 'Completá el nombre de acceso y la contraseña.'; error.hidden = false; invalid.focus(); return; }
    const loginName = form.elements.namedItem('loginName').value;
    const password = form.elements.namedItem('password').value;
    phase = 'signing-in'; lock(true); error.hidden = true; status.textContent = 'Verificando el acceso con el servidor…';
    try {
      await client.login({loginName, password});
      if (!destroyed) { phase = 'authenticated'; form.reset(); status.textContent = 'Acceso verificado. Abriendo el espacio interno…'; redirect('/internal/'); }
    } catch (exception) {
      if (!destroyed) {
        phase = exception?.code === 'rate_limited' ? 'cooldown' : 'logged-out';
        fail(exception); status.textContent = 'No se confirmó el ingreso. No se concedieron permisos desde esta pantalla.';
        if (phase === 'cooldown') cooldownTimer = setTimeout(() => {
          if (!destroyed) { phase = 'logged-out'; lock(false); status.textContent = 'Podés volver a intentar el ingreso.'; submit.focus(); }
        }, exception.retryAfterSeconds * 1000);
      }
    } finally {
      form.elements.namedItem('password').value = '';
      if (!destroyed && phase === 'logged-out') { lock(false); submit.focus(); }
    }
  };
  form.addEventListener('submit', onSubmit);
  return {ready, getState: () => ({phase, authenticated: phase === 'authenticated'}),
    destroy() { destroyed = true; clearTimeout(cooldownTimer); form.removeEventListener('submit', onSubmit); form.reset(); }};
}
if (typeof document !== 'undefined' && document.querySelector('[data-staff-login]')) mountStaffLogin();
