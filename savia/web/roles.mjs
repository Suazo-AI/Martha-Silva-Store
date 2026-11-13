// Who sees what, in one place. The menu, the access check, the landing page and the role texts read this file.
// The server checks every request again (Roles in Savia.Domain); this table only decides what the screen offers.

const OWNER = ['OWNER'];
const APPROVERS = ['MANAGER', 'OWNER'];
const STOCK = ['INVENTORY', 'MANAGER', 'OWNER'];
const COMMISSION_READERS = ['SELLER', 'MANAGER', 'OWNER'];
const EVERYONE = ['SELLER', 'INVENTORY', 'MANAGER', 'OWNER'];
/** The phone tag page follows the server's receiving roles (TagExtractionService). */
const TAG_RECEIVERS = ['INVENTORY', 'CASHIER', 'MANAGER', 'OWNER'];

/** One row per screen, in menu order. A row without a label is reached from another screen, not from the menu. */
export const SCREENS = [
  { route: 'venta', label: 'Venta', roles: APPROVERS },
  { route: 'caja', label: 'Caja', roles: APPROVERS },
  { route: 'historial', label: 'Historial', roles: APPROVERS },
  { route: 'recepcion', label: 'Recepción', roles: STOCK },
  { route: 'inventario', label: 'Inventario', roles: STOCK },
  { route: 'clientes', label: 'Clientes', roles: APPROVERS },
  { route: 'ajustes', label: 'Ajustes', roles: EVERYONE },
  { route: 'aprobaciones', label: 'Aprobaciones', roles: OWNER },
  { route: 'comisiones', label: 'Comisiones', roles: COMMISSION_READERS },
  { route: 'precios', label: 'Precios', roles: OWNER },
  { route: 'importar', label: 'Importar catálogo', roles: OWNER },
  { route: 'calidad', label: 'Calidad de recepción', roles: STOCK },
  { route: 'excepciones', label: 'Excepciones', roles: APPROVERS },
  { route: 'reporte', label: 'Reportes', roles: COMMISSION_READERS },
  { route: 'recepcion/revisar', roles: STOCK },
  { route: 'recibo', roles: APPROVERS },
  { route: 'devolucion', roles: APPROVERS },
];

const ROLES = {
  OWNER: { name: 'Dueña', can: 'Dueña: ve todo, fija precios y costos, y revisa las aprobaciones.' },
  MANAGER: { name: 'Gerente', can: 'Gerente: cobra, abre y cierra la caja, y autoriza descuentos y devoluciones.' },
  SELLER: { name: 'Vendedora', can: 'Vendedora: atiende clientes y consulta sus comisiones.' },
  INVENTORY: { name: 'Bodega', can: 'Bodega: recibe mercadería, revisa su estado y consulta el inventario.' },
  CASHIER: { name: 'Caja', can: null },
};

const has = (roles, allowed) => roles.some(role => allowed.includes(role));
const screen = route => {
  const path = route.split('?')[0];
  return SCREENS.find(s => s.route === path) ?? SCREENS.find(s => s.route === path.split('/')[0]);
};

export const canAccess = (route, roles) => has(roles, screen(route)?.roles ?? []);
export const isApprover = roles => has(roles, APPROVERS);
export const isOwner = roles => has(roles, OWNER);
export const receivesTags = roles => has(roles, TAG_RECEIVERS);
export const roleName = code => ROLES[code]?.name ?? code;
/** What each of the user's roles can do, most senior first, for the settings screen. */
export const roleSummary = roles =>
  Object.keys(ROLES)
    .filter(code => roles.includes(code) && ROLES[code].can)
    .map(code => ROLES[code].can);
/** Where a user lands after signing in. */
export const landing = roles => (roles.includes('SELLER') ? 'comisiones' : roles.includes('INVENTORY') ? 'recepcion' : 'venta');
