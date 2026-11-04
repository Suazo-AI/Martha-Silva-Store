# Arnés del camino dorado (C5): API real + SQL desechable

Actualizado: 2026-11-03. Prueba reproducible del recorrido de personal **sin navegador**:
SQL Server desechable → migraciones de release → identidades sintéticas → proceso real de la API → HTTP por rol → oráculos SQL → retiro.
Es la base que C6 extiende con Chrome real (modo `serve`).

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
| `--no-build` | Usa binarios Release ya compilados (CI compila antes con `--locked-mode`). |
| `--keep-private-log <ruta>` | Copia el log crudo de la API (0600) **fuera** de `--out`. Solo diagnóstico local. |

Sin `--no-build` ejecuta `dotnet restore tests/golden-path/GoldenPath.Sql --locked-mode` y `dotnet build -c Release`.
No usa paquetes nuevos: `GoldenPath.Sql` solo referencia `Martha.Store.Api` y tiene su `packages.lock.json`.

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

- Rechaza cualquier base que no sea `SaviaInternalTest_Golden_<32 hex>`; nunca borra una base existente ajena
  (si el nombre ya existe, se niega antes de crear). La API además aplica su propia guarda `SaviaInternalTest_*`.
- No crea logins ni credenciales SQL. Las contraseñas de los usuarios sintéticos son aleatorias por corrida.
- Nunca escribe contraseñas, cookies, tokens CSRF ni la conexión; al final busca esos valores en `--out` y falla si aparecen.
- Clave TLS y log de la API viven en un directorio temporal 0700 fuera de `--out`, borrado al terminar.
- La API escucha solo en `127.0.0.1`. Un fallo o una señal siempre detiene la API y borra la base propia.

## Modo `serve` para C6 (navegador)

```sh
python3 tests/golden-path/golden_path.py --mode serve --out <dir>
```

Al estar listo escribe `<dir>/serve-ready.json` (URL, usuarios, PID; sin contraseñas) y `<dir>/session.json` con permisos
0600: `base_url`, `login_url`, `ca_cert`, `location_id`, `item_ids` y `users.<Rol>.{loginName,password,role,assigned}`.
El navegador debe confiar en `ca_cert` o usar un perfil desechable que lo acepte; las cookies `__Host-` exigen HTTPS.
Terminar con Ctrl+C o `SIGTERM` al PID: borra `session.json`, detiene la API y elimina la base. En `serve` no se hace la venta.

## Qué prueba y qué no

Prueba, en esta máquina: que el binario real de la API, con las migraciones de release aplicadas por el migrador EF,
autentica a cada rol con cookies y CSRF reales, limita lectura por sucursal, niega al usuario sin asignación,
registra una sola venta con su movimiento, que repetir la clave no produce efecto y que el logout revoca la sesión,
todo comparado directamente en SQL.

No prueba: UI ni navegador (C6); el script SQL idempotente de release (otro agente lo corrige); Windows/SUAZO-PC;
TLS, proxy o hosting de producción; pagos (no hay proveedor); concurrencia, carga, backup/restore (C9) ni el
oráculo privado de esquema (C4). La sucursal se inserta por EF porque el producto no ofrece otra vía.
Un PASS local no sustituye el resultado de CI (`.github/workflows/golden-path.yml`).
