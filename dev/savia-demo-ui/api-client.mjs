// Read-only browser boundary for the existing SAVIA V2 synthetic contract.
// A successful diagnostic is not a sale, SQL test result, or payment integration.
export const API_PATHS = Object.freeze({
  ready: '/health/ready',
  capabilities: '/api/v2/synthetic/capabilities',
  catalog: '/api/v2/synthetic/catalog'
});
const authorityMatches = value => value?.mode === 'savia'
  && value.instanceId === 'savia-synthetic-v2' && value.epoch === 1;
const uuid = value => typeof value === 'string'
  && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)
  && value !== '00000000-0000-0000-0000-000000000000';

export function validCatalog(value) {
  if (value?.synthetic !== true || !authorityMatches(value.authority)
    || !Array.isArray(value.items) || value.items.length !== 1) return false;
  const item = value.items[0];
  return item.synthetic === true && authorityMatches(item.authority)
    && uuid(item.variantId) && uuid(item.locationId)
    && typeof item.name === 'string' && item.name.length > 0 && item.name.length <= 200
    && typeof item.sku === 'string' && item.sku.length > 0 && item.sku.length <= 200
    && item.currency === 'XXX' && Number.isSafeInteger(item.unitPriceMinor)
    && item.unitPriceMinor >= 0 && item.unitPriceMinor <= 9000000000000
    && [item.onHand, item.reserved, item.available].every(Number.isSafeInteger)
    && item.onHand >= item.reserved && item.reserved >= 0
    && item.available === item.onHand - item.reserved;
}

const SAVIA_FLAGS = Object.freeze({ catalog: true, reserve: true, getReservation: true,
  cancel: true, attemptLookup: true, movements: true, expiration: false,
  sale: false, shipment: false, return: false, payments: false });
function flagsMatch(flags, enabled) {
  return flags && Object.keys(flags).length === Object.keys(SAVIA_FLAGS).length
    && Object.entries(SAVIA_FLAGS).every(([name, value]) => flags[name] === (enabled && value));
}
function validCapabilities(value) {
  if (value?.synthetic !== true || !authorityMatches(value.authority)
    || !Array.isArray(value.providers) || value.providers.length !== 2) return false;
  const savia = value.providers.find(provider => provider.mode === 'savia');
  const cga = value.providers.find(provider => provider.mode === 'cga');
  return authorityMatches(savia?.authority) && savia.implementationStatus === 'synthetic_code_implemented'
    && savia.sqlVerification === 'not_verified' && flagsMatch(savia.capabilities, true)
    && cga?.authority === null && cga.implementationStatus === 'not_verified'
    && cga.sqlVerification === 'not_verified' && flagsMatch(cga.capabilities, false);
}

export async function readBackendStatus({ fetchImpl = globalThis.fetch, timeoutMs = 3500 } = {}) {
  const checks = [];
  let capabilities = null;
  let catalog = null;
  // Fixed same-origin paths; no caller-supplied URL, credentials, proxy or fallback.
  for (const [name, path] of Object.entries(API_PATHS)) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetchImpl(path, { method: 'GET', credentials: 'omit',
        cache: 'no-store', redirect: 'error', headers: { Accept: 'application/json' },
        signal: controller.signal });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const contentType = response.headers.get('content-type')?.split(';')[0].trim();
      if (contentType !== 'application/json') throw new Error('La respuesta no es JSON de la API.');
      const value = await response.json();
      if (name === 'ready' && value?.status !== 'ready') throw new Error('El almacenamiento no está listo.');
      if (name === 'capabilities') {
        if (!validCapabilities(value)) throw new Error('La respuesta no coincide con SAVIA V2 sintética.');
        capabilities = value;
      }
      if (name === 'catalog') {
        if (!validCatalog(value)) throw new Error('El catálogo no coincide con la fixture XXX de SAVIA V2.');
        catalog = value;
      }
      checks.push({ label: { ready: 'Almacenamiento', capabilities: 'Capacidades de SAVIA', catalog: 'Catálogo de prueba' }[name],
        ok: true, message: name === 'ready' ? 'La API informa que el almacenamiento está listo; no acredita las pruebas SQL pendientes.'
          : name === 'catalog' ? 'Una variante sintética. Importes XXX proporcionados por la API.'
            : 'Contrato sintético reconocido; sin ventas ni pagos.' });
    } catch (error) {
      checks.push({ label: { ready: 'Almacenamiento', capabilities: 'Capacidades de SAVIA', catalog: 'Catálogo de prueba' }[name],
        ok: false, message: error?.name === 'AbortError' ? 'La consulta tardó demasiado. Podés volver a comprobar.'
          : /^HTTP \d{3}$/.test(error?.message ?? '') ? `${error.message}. Servicio no disponible en este sitio.`
            : ['La respuesta no es JSON de la API.', 'El almacenamiento no está listo.',
              'La respuesta no coincide con SAVIA V2 sintética.', 'El catálogo no coincide con la fixture XXX de SAVIA V2.'].includes(error?.message)
              ? error.message : 'No se pudo contactar con la API de este sitio.' });
    } finally { clearTimeout(timer); }
  }
  const ready = checks.every(check => check.ok);
  const state = ready ? 'ready' : checks.some(check => check.ok) ? 'partial' : 'unavailable';
  return { state, checks, catalog, capabilities,
    message: ready ? 'API sintética accesible. Las consultas respondieron; no se ejecutaron reservas, ventas ni pagos.'
      : state === 'partial' ? 'Conexión incompleta. No se habilitaron operaciones con el backend.'
        : 'El backend SAVIA no está disponible en este sitio. La caja de demostración funciona por separado.',
    sqlVerification: capabilities?.providers.find(provider => provider.mode === 'savia')?.sqlVerification ?? 'not_verified',
    transactionsEnabled: false };
}
