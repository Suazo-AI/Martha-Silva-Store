# Interfaz interna de SAVIA

Actualizado: 2026-11-03. Fuentes privadas de personal, fuera de `dist/` y del Worker público.
Montaje .NET: `/internal/login` y `/internal/`; API bajo `/internal/api/`.
El servidor aplica sesión, permisos, ámbito de sucursal y CSRF. Ocultar botones no es autorización.

## Fuentes y comportamiento

- `login.html` / `login.mjs`: ingreso anónimo.
- `index.html` / `styles.css`: estructura, controles y presentación.
- `app.mjs` / `client.mjs`: sesión, directorio paginado, stock, venta, recibo y recuperación del intento.

La UI ya tiene venta multiartículo y recuperación implementadas. El catálogo global y las existencias por sucursal son lecturas diferentes.
Una pérdida de respuesta requiere recuperar el intento original; no fabricar éxito ni generar una venta equivalente.
N5 está corregido en la base `775f301bc195c43baedc68c86f4e71affe92ef95`.
Fuente reproducible: `Stale confirmed receipt` de [browser-mock-validation.mjs](../../tests/browser-mock-validation.mjs).

C8 añade la versión del actor a los intentos nuevos y conserva su clave durante cambios de acceso.
Una versión distinta o una ubicación fuera del ámbito actual bloquean recuperación y reenvío del intento.
Los intentos históricos sin versión pueden consultar su recuperación si la ubicación sigue autorizada; no pueden reenviarse.
No se asigna una versión nueva a un intento histórico ni se borra su referencia para desbloquear ventas.
Un 401 o logout invalida respuestas tardías y evita enviar una venta que todavía espera CSRF.
Ver [evidencia local y límites de C8](../../docs/c8-ui-20261103/report.md).

## Evidencia y comprobaciones

El [lote 2026-11-03](../../docs/testing-20261103/README.md) obtuvo 42/42 pruebas staff JS.
En ese corte histórico hubo 31/32 escenarios con API simulada y N5 fallido; ese defecto ya está corregido.
El [lote N5 del 5 de noviembre](../../docs/n5-browser-20261105/README.md) registró 50/50 con Chrome/HTTP simulado
y staff 102/102. El primary aplica dos precisiones del juez; la revisión de Opus sigue pendiente.
Para pruebas posteriores navegador → API → SQL por cajero, consultar el estado vigente; este lote no repite SQL.

```powershell
# Usar el jsdom ya instalado del lock, solo en el proceso de comprobación.
$env:NODE_PATH = (Resolve-Path tests/frontend-deps/node_modules).Path
node --test dev/savia-staff-ui/*.test.mjs
```

Consultar el [toolkit de navegador](../../docs/testing-20261103/README.md) para enfocar N5.
La [entrada de agentes](../../docs/AGENT-START.md) y [N1–N10](../../docs/delivery-20261031/NEXT-INCREMENT.md)
definen el siguiente trabajo. No se acredita aceptación visual, Safari/iPhone físico ni despliegue productivo.

## Recepción de compras existentes (2026-11-05)

`supply.mjs` permite Owner, Manager e Inventory consultar compras y entregas paginadas y recibir cantidades pendientes.
El proveedor, ubicación, moneda, costos y líneas vienen del servidor.
No crea compras ni edita proveedores.
Cashier no opera abastecimiento; el servidor conserva autorización y ámbito.

Antes del POST se guarda `savia.supply.pending.v1` en sessionStorage con identidad física, clave, actor/versión, compra, cuerpo y bytes JSON.
No se envía si falla el almacenamiento.
Reload conserva la referencia; una respuesta perdida requiere **Comprobar recepción pendiente**.
Solo un 404 de operaciones permite **Reenviar la misma recepción**, conservando identidad, clave y cuerpo.
Un resultado desconocido o malformado conserva el bloqueo.
Un rechazo confirmado de operaciones libera el intento; un 403/409/503 directo no lo elimina.
Cambiar actor/versión no actualiza referencias históricas.
Logout y 401 limpian la UI privada y conservan la referencia durable.
Confirmar una recepción consulta de nuevo compra, entregas y stock autorizado; no suma existencias localmente.

El módulo tiene recurso .NET y ruta protegida explícitos; queda fuera del Worker y `dist/`.
Pruebas portables: `NODE_PATH=<locked node_modules> node --test dev/savia-staff-ui/*.test.mjs`.
Chrome con API HTTP simulada: `node tests/browser-supply-validation.mjs <installed-playwright-directory> <evidence-directory>`.
Evidencia y límites: [worker](../../docs/supply-ui-20261105/worker/README.md).


## Physical delivery exception (D-026/D-027, synthetic trial)

Each sale row has an explicit physical-delivery checkbox for recorded available stock 0.
Reason and physical garment size are mandatory.
The server records the exception on the sale line; it does not create stock, cost, purchase receipt or a stock movement.
Normal rows retain the ordinary stock/reservation checks.
Returns/cancellations record exceptional delivered quantity and sale credit reversals without creating inventory.
An evidence-based inventory correction is separate.

At simulated day close, a Manager or Owner opens the sale ID under Ventas.
The reviewer must differ from its registering actor, including an Owner or substitute.
The reviewer enters examined evidence, outcome, an authorized synthetic responsible profile ID and a future review date.
Review records remain open and append-only; this UI does not claim cause resolution or reconciliation.
Profile IDs are entered explicitly; this increment does not assign real employees.
The UI stores `savia.stock.review.pending.<actorId>` before POST.
Reload/retry preserves its key/body; duplicate submits and late replies cannot erase the pending reference.
Session/version changes block recovery for manual reconciliation.

Focused checks: `node --test dev/savia-staff-ui/stock-exception.test.mjs` with existing jsdom on NODE_PATH.
See [worker evidence](../../docs/stock-exception-20261106/worker/README.md) for commands, limits and prepared SQL checks.
