# Arnés del camino dorado: API real + SQL desechable (C5), Chrome (C6)

Actualizado: 2026-11-03. Prueba reproducible del recorrido de personal **sin navegador**:
SQL Server desechable → migraciones de release → identidades sintéticas → proceso real de la API → HTTP por rol → oráculos SQL → retiro.
El modo `browser` extiende ese ciclo con Chrome real y oráculos entre acciones.
La implementación de C6 requiere su ejecución Linux CI del SHA exacto antes de declarar aceptación.

## Comando

```sh
# Requisitos: SDK .NET 10.0.402 (global.json), Python 3.9+ en Linux/macOS (usa pty), un SQL Server DESECHABLE.
export MARTHA_TEST_SQL_CONNECTION='Server=127.0.0.1,14333;Database=master;User ID=sa;Password=…;Encrypt=true;TrustServerCertificate=true'
python3 tests/golden-path/golden_path.py --out <dir-evidencia>
```

| Opción / variable | Uso |
| --- | --- |
| `MARTHA_TEST_SQL_CONNECTION` | Obligatoria. Conexión al **servidor** desechable; la base indicada se ignora. Mismo nombre que `savia.yml`. |
| `--sql-env-file <archivo>` | Alternativa local: lee solo `MARTHA_TEST_SQL_CONNECTION=…` (admite `export`) de un archivo privado. |
| `--out <dir>` | Evidencia saneada: `evidence.json`, `oracles.md` y `cert.pem` (certificado público efímero). |
| `--mode smoke` | Predeterminado. Recorrido completo y retiro. Código 0 solo si todo pasa. |
| `--mode serve` | Prepara datos, deja API y base activas e imprime URL y usuarios hasta Ctrl+C/SIGTERM (ver C6). |
| `--mode browser --playwright-directory <paquete>` | Reutiliza setup/oráculos/retirada de C5; ejecuta Chrome contra la API HTTPS real. No instala dependencias. |
| `--no-build` | Usa binarios Release ya compilados (CI compila antes con `--locked-mode`). |
| `--keep-private-log <ruta>` | Copia el log crudo de la API (0600) **fuera** de `--out`. Solo diagnóstico local. |

Sin `--no-build` ejecuta `dotnet restore tests/golden-path/GoldenPath.Sql --locked-mode` y `dotnet build -c Release`.
No usa paquetes nuevos: `GoldenPath.Sql` solo referencia `Martha.Store.Api` y tiene su `packages.lock.json`.

## C6: Chrome → API HTTPS → SQL, incluida respuesta perdida

```sh
# Mismo servidor SQL desechable y build Release que C5. No reutilizar el piloto.
# Node 24, OpenSSL, Google Chrome y Playwright 1.63.0 deben existir en el runner.
python3 tests/golden-path/golden_path.py --mode browser --no-build \
  --playwright-directory "$RUNNER_TEMP/c6-playwright/node_modules/playwright" \
  --out "$RUNNER_TEMP/c6-evidence"
python3 tests/golden-path/verify_evidence.py --source "$RUNNER_TEMP/c6-evidence" \
  --destination "$RUNNER_TEMP/c6-approved"
```

No cambia el modo predeterminado `smoke` ni el contrato `serve`.
Cada modo usa una base nueva; las dos ventas siguientes pertenecen solo a la corrida `browser`.

| Checkpoint del navegador | Acción real y comprobación DOM/HTTP | Oráculo SQL acumulado |
| --- | --- | --- |
| `browser.start` | Login servido por API; runtime Chrome/Node/Playwright; hashes locales | 0 ventas, 0 sesiones |
| `browser.cashier_login` | CSRF/login/me reales; Cashier visible; cookie `__Host-Savia.Session` Secure/HttpOnly/Strict; hashes de los 6 recursos servidos iguales al checkout | 1 sesión, 0 ventas |
| `browser.inventory` | Inventario visible: 3 saldos, total 30, primer artículo 10 | 0 ventas, existencia 30 |
| `browser.sale_confirmed` | Formulario con cantidad 2; POST 200, clave UUID; precio y total del recibo del servidor; DOM y referencia persistida | 1 venta/línea/movimiento de venta/operación, existencia 28 |
| `browser.receipt_reload` | Recarga y GET del mismo recibo; venta habilitada; sin nuevo POST | Conteos de negocio idénticos |
| `browser.stock_after_sale` | Inventario visible: total 28, primer artículo 8 | Conteos de negocio idénticos |
| `browser.response_loss_committed` | Cantidad 1; Chrome recibe HTTP 200 y recibo del servidor en CDP; se descarta la respuesta; DOM pendiente y clave original conservada | 2 ventas/líneas/movimientos de venta/operaciones, existencia 27 |
| `browser.recover_after_reload` | Solo después del oráculo anterior: recarga; GET operations con la misma clave; mismo recibo; pendiente retirado | Conteos de negocio idénticos; POST acumulados = 2 |
| `browser.repeated_reload` | Otra recarga; GET del mismo recibo | Sin otra venta/débito/operación |
| `browser.stock_after_recovery` | Inventario visible: total 27, primer artículo 7 | Conteos de negocio idénticos |
| `browser.logout` | Logout HTTP 204; URL de login, formulario habilitado; `me` = 401 | 0 sesiones, 2 ventas |

Cada checkpoint vuelve a exigir 2 migraciones y cero violaciones de los invariantes C5.
Python no confirma el checkpoint al navegador hasta que el helper SQL termina y los oráculos pasan.
La prueba unitaria adversarial rechaza una supuesta respuesta comprometida si SQL solo ve una venta.
Esa prueba usa dobles y acredita la barrera, no una ejecución SQL ni el recorrido de navegador.

La falla usa `Fetch.getResponseBody` y `Fetch.failRequest` en `requestStage: Response` de CDP.
No fabrica una respuesta, no reenvía el POST mediante otro cliente y no hace `route.fetch`.
El POST de venta solo contiene ubicación, cliente nulo, artículo y cantidad; nunca precio o total.
La evidencia registra método, ruta sin query, HTTP, clave de operación, comprobaciones DOM y conteo de POST.
Los cuerpos de peticiones/respuestas, cookies y CSRF permanecen privados.

Chrome usa un perfil temporal privado y permite únicamente el SPKI del certificado efímero de C5.
No usa `ignoreHTTPSErrors`, no toca almacenes de certificados y bloquea peticiones fuera del origen loopback.
El padre limita el proceso a 300 segundos. CDP identifica Chrome por un canal privado.
Linux valida su perfil, ascendencia y hora de inicio antes de registrar sus grupos propios de Node y Chrome.
La retirada usa TERM/KILL solo con identidad confirmada y exige leer la ausencia de ambos grupos.
Una lectura fallida, identidad reutilizada o proceso persistente impide PASS; conserva las guardas SQL de C5.
El logout publica solo un código fijo por fase ante fallo; nunca el mensaje crudo del navegador.

`evidence.json` y `oracles.md` incluyen runtime, hashes de fuentes/UI servida/API Release y eventos saneados.
Conservan staging privado, escaneo de secretos y manifiesto SHA-256 `evidence-approved` de C5.
Publicar solo los dos archivos copiados por `verify_evidence.py`.
El modo `browser` no graba trace/HAR, perfiles, screenshots ni grabaciones de login publicables.
Un fallo de sanitización sigue sin habilitar evidencia para publicación.

Comprobaciones ligeras sin runtime ni dependencias nuevas:

```sh
python3 -m unittest discover -s tests -p 'test_golden_path*_safety.py'
node --check tests/golden-path/browser_path.mjs
```

## Qué hace, en orden

| Paso | Camino usado | Oráculo después del paso |
| --- | --- | --- |
| `sql.migrate_release` | `IMigrator.MigrateAsync()` de EF sobre una base **nueva** `SaviaInternalTest_Golden_<32 hex>` (mismo migrador que `PrivatePilotReleaseTests`; no `EnsureCreated`) | 2 migraciones, 0 pendientes, 0 personal |
| `owner.bootstrap_console` | Consola real `Martha.Store.Api.dll --internal-bootstrap-owner`, conducida por un pty privado (modo raw) | 1 Owner |
| `sql.branch_seed` | Inserción EF de `InternalBranch`: **no existe endpoint HTTP de sucursales** en este candidato | 1 sucursal |
| `api.start_readiness_anonymous` | `dotnet Martha.Store.Api.dll --urls https://127.0.0.1:<puerto libre>` con certificado autofirmado efímero; `/internal/api/readiness` anónimo = 401 | sin cambios |
| `owner.login_readiness` | CSRF → login → CSRF renovado → `me` (contrato de `login.mjs`); readiness autenticado = 200 `ready` | 1 sesión |
| `owner.seed_directory` / `seed_stock_adjustments` / `seed_staff` | HTTP como Owner: ubicación de la sucursal, 3 artículos `SINTETICO-GOLDEN-*`, ajuste +10 por artículo, Manager/Cashier/Inventory asignados y un Cashier **sin sucursal** | 3 movimientos, existencia 30, 5 personas |
| `owner.scope_and_logout`, `manager.*`, `inventory.*` | Cada rol lee ubicaciones e inventario de su sucursal; Inventory intenta vender → 403 | 0 ventas, 0 operaciones de venta |
| `unassigned.denied_scope_and_sale` | El usuario sin asignación inicia sesión pero ve 0 ubicaciones y 0 existencias; su venta → 403 `forbidden` | movimientos y operaciones sin cambio |
| `cashier.sale_with_idempotency_key` | Una venta (2 u.) con `Idempotency-Key` | 1 venta, 1 línea, 1 movimiento de venta, existencia 28 |
| `cashier.replay_same_key_no_effect` | Misma clave y cuerpo → mismo `saleId` | movimientos, operaciones y existencia idénticos |
| `cashier.same_key_other_body_conflict` | Misma clave, otra cantidad → 409 `idempotency_conflict` | sin cambio |
| `cashier.recover_by_key` | `GET /internal/api/operations/commerce.sale.record` con la clave (recuperación de la UI) | sin cambio |
| `cashier.logout` | Logout 204 y `me` 401 | 0 sesiones activas |
| `teardown.stop_api_drop_database` | SIGTERM a la API, `DROP DATABASE` de la base propia y verificación de ausencia | base inexistente; 0 líneas `fail:`/`crit:` en el log |

Invariantes evaluados **después de cada paso**: cada línea de venta tiene exactamente 1 movimiento; ningún
movimiento de venta sin línea; suma de movimientos = saldo (`OnHand` y `Reserved`); último `OnHandAfter` = saldo;
ninguna existencia negativa o reservada > disponible; ninguna clave `(actor, alcance, clave)` repetida;
todos los artículos con marcador sintético. La tabla por paso queda en `oracles.md` y en la salida.

## Garantías de seguridad del arnés

- Rechaza cualquier base que no sea `SaviaInternalTest_Golden_<32 hex>` y conserva una base cuya creación
  fue rechazada por existir. La API además aplica su propia guarda `SaviaInternalTest_*`.
- No crea logins ni credenciales SQL. Las contraseñas de los usuarios sintéticos son aleatorias por corrida.
- Los dos archivos publicables se escriben primero en staging privado fuera de `--out`, se escanean contra
  los secretos conocidos y solo entonces se exponen con un manifiesto SHA-256 `evidence-approved`.
  CI verifica ese manifiesto y copia los bytes comprobados a `golden-approved` antes del resumen o artefacto.
  Un fallo del escaneo no imprime tabla ni error crudo y no habilita publicación. Este filtro de valores
  conocidos no garantiza detectar secretos desconocidos ni reemplaza la revisión del contenido.
- Clave TLS y log de la API viven en un directorio temporal 0700 fuera de `--out`, borrado al terminar.
- La API escucha solo en `127.0.0.1`. Ante una señal manejable o timeout se detiene y espera el helper propio
  antes de limpiar. Solo una respuesta `ok: true` de creación habilita el borrado automático con readback.
  Una creación interrumpida, sin respuesta o con error genérico queda `unknown`, hace fallar la retirada
  y pide revisión del operador; no se borra una base de propiedad incierta ni se declara `not_created`.
  Puede quedar una base parcial en un servidor local: identificarla mediante evidencia privada y propietario
  antes de una limpieza autorizada. CI elimina su contenedor desechable propio en el paso final independiente.
  SIGKILL, pérdida de energía o fallo del host no permiten garantizar limpieza desde este proceso.

## Modo `serve` para C6 (navegador)

```sh
python3 tests/golden-path/golden_path.py --mode serve --out <dir>
```

Al estar listo escribe `<dir>/serve-ready.json` (URL, usuarios, PID; sin contraseñas) y `<dir>/session.json` con permisos
0600: `base_url`, `login_url`, `ca_cert`, `location_id`, `item_ids` y `users.<Rol>.{loginName,password,role,assigned}`.
El navegador debe confiar en `ca_cert` o usar un perfil desechable que lo acepte; las cookies `__Host-` exigen HTTPS.
Terminar con Ctrl+C o `SIGTERM` al PID: retira `session.json`, detiene la API e intenta eliminar solo la base
con creación confirmada. La incertidumbre se reporta como fallo de retirada. En `serve` no se hace la venta.

## Regresiones ligeras de seguridad

`python -B tests/test_golden_path_safety.py` comprueba publicación, secretos sintéticos, manifiestos,
interrupción del helper y propiedad incierta sin SQL, API, .NET ni navegador. En Windows carga las
definiciones exactas por AST omitiendo imports POSIX; no acredita ejecutar el arnés POSIX allí.
El recorrido Linux API/SQL del mismo candidato y la ejecución de Actions siguen siendo verificaciones separadas.

## Cobertura del modo smoke (C5)

El modo smoke comprueba que el binario real de la API, con las migraciones de release aplicadas por el migrador EF,
autentica a cada rol con cookies y CSRF reales, limita lectura por sucursal, niega al usuario sin asignación,
registra una sola venta con su movimiento, que repetir la clave no produce efecto y que el logout revoca la sesión,
todo comparado directamente en SQL.

El modo smoke no prueba: UI ni navegador (C6); el script SQL idempotente de release; Windows/SUAZO-PC;
TLS, proxy o hosting de producción; pagos (no hay proveedor); concurrencia, carga, backup/restore (C9) ni el
oráculo privado de esquema (C4). La sucursal se inserta por EF porque el producto no ofrece otra vía.
Un PASS local no sustituye el resultado de CI (`.github/workflows/golden-path.yml`).

## Recepción combinada preparada, no ejecutada

`--mode browser --supply` conserva ventas y añade recepción de inventario parcial/completa,
pérdida de respuesta y recuperación GET con clave e identidad originales.
Requiere autorización de runtime nueva; no hereda la corrida SQL anterior.
Contrato, controles sin SQL y comando futuro: [SUPPLY-REAL-PREP](../../docs/supply-real-20261106/README.md).
El workflow ofrece `supply_receipt=false` por defecto.


## Physical exception + independent review: explicit opt-in, NOT RUN

`--stock-exception` defaults to false and requires `--supply --mode browser`.
Existing `--supply` alone retains its 17 checkpoints and four SQL identity oracles.
The new flag adds five checkpoints after that unchanged path: exceptional sale, reload,
different-person review, review reload and final logout.
No workflow dispatch, runtime permission or deployment is enabled by this preparation.

Prepared command, only after the primary obtains separate disposable SQL/API runtime authority:

```sh
python3 tests/golden-path/golden_path.py --out <fresh-evidence-directory> --mode browser --playwright-directory <installed-package> --supply --stock-exception
```

Use the existing private connection source, synthetic identities and disposable database guard.
The command requires the existing Linux/POSIX harness environment; this worker did not run it on Windows.
The fixture adds one synthetic article with no balance, receipt or opening quantity.
The cashier delivers 1 size S at 1250 USD minor units and enters an explicit reason.
A different Manager reviews sale and physical-count evidence at simulated close.
The cause remains open, with that synthetic Manager responsible and next review in 2099.
See [oracles.md](oracles.md) for exact durable accounting and identity checks.

Prepared SQL tests: `InternalStockExceptionSqlTests` cover concurrent identical replay,
body conflict, mixed-line rollback, partial return, cancellation, Owner self-review denial,
substitute review and review replay.
They use `MARTHA_INTERNAL_TEST_SQL_CONNECTION` only under separate runtime authority.
Their three skipped results here are NOT persistence proof.

Retirement is mandatory: stop only owned browser/API process groups, remove the private session
file and drop only the database acknowledged as created by this run.
A failed or uncertain drop/stop is a failed run; verify `cleanup` and evidence verification output.
No migration was applied and no SQL connection was opened by this worker.
