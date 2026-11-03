# Interfaz interna de SAVIA

Actualizado: 2026-11-03. Fuentes privadas de personal, fuera de `dist/` y del Worker público.
Montaje .NET: `/internal/login` y `/internal/`; API bajo `/internal/api/`.
El servidor aplica sesión, permisos, ámbito de sucursal y CSRF. Ocultar botones no es autorización.

## Fuentes y comportamiento

- `login.html` / `login.mjs`: ingreso anónimo.
- `index.html` / `styles.css`: estructura, controles y presentación.
- `app.mjs` / `client.mjs`: sesión, directorio paginado, stock, venta, recibo y recuperación del intento.

La UI ya tiene venta y recuperación implementadas. El catálogo global y las existencias por sucursal son lecturas diferentes.
Una pérdida de respuesta requiere recuperar el intento original; no fabricar éxito ni generar una venta equivalente.
N5 permanece abierto: restaurar un recibo confirmado con 404 crea un falso estado pendiente y bloquea ventas nuevas.
Fuente reproducible: `Stale confirmed receipt` de [browser-mock-validation.mjs](../../tests/browser-mock-validation.mjs).

## Evidencia y comprobaciones

El [lote 2026-11-03](../../docs/testing-20261103/README.md) obtuvo 42/42 pruebas staff JS.
El navegador usa API simulada; hay 31/32 escenarios aprobados en el conjunto público/staff y N5 fallido.
La evidencia Owner navegador → SQL del 31 de octubre es histórica; falta aceptar el candidato actual por cajero.

```powershell
# Usar el jsdom ya instalado del lock, solo en el proceso de comprobación.
$env:NODE_PATH = (Resolve-Path tests/frontend-deps/node_modules).Path
node --test dev/savia-staff-ui/*.test.mjs
```

Consultar el [toolkit de navegador](../../docs/testing-20261103/README.md) para enfocar N5.
La [entrada de agentes](../../docs/AGENT-START.md) y [N1–N10](../../docs/delivery-20261031/NEXT-INCREMENT.md)
definen el siguiente trabajo. No se acredita aceptación visual, Safari/iPhone físico ni despliegue productivo.
