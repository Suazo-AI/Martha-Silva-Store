# SQL: configuración, evidencia y límites

Actualizado: 2026-11-03. Esta entrega documenta SQL; no consulta ni modifica las bases de la aplicación.
Jason eligió índice para agentes y documentación de SQL. No se afirma que la API o SQL estén activos ahora.

## Dos contextos diferentes

| Contexto | Configuración y fuente | Alcance |
| --- | --- | --- |
| `StoreDbContext` | `ConnectionStrings__Store`; [Program.cs](../backend/src/Martha.Store.Api/Program.cs) | Adaptador legado/sintético; `/health/ready` valida este contexto |
| `InternalDbContext` | `ConnectionStrings__InternalSavia`; [InternalHosting.cs](../backend/src/Martha.Store.Api/Internal/InternalHosting.cs) | Personal, directorio, comercio, stock y compras privados; `/internal/api/readiness` exige sesión autorizada |

`InternalSavia__Enabled=true` y `ASPNETCORE_ENVIRONMENT=Development` habilitan las rutas privadas.
Estas rutas exigen HTTPS. La guarda interna admite solo `SaviaInternalTest_[A-Za-z0-9_]{1,64}` y rechaza MARS.
El prefijo no demuestra aislamiento ni autorización del servidor. No colocar conexiones o contraseñas en Git.
`Synthetic__Enabled` controla el contexto sintético legado, no reemplaza la habilitación interna.

`--migrate`, `--seed-synthetic` y `--seed-savia-synthetic` en Program.cs actúan sobre `StoreDbContext`.
No usarlos para migrar Internal. El arranque normal no aplica migraciones ni crea el primer Owner.
La consola Owner es mantenimiento explícito con sus propios controles; encontrar el comando no autoriza ejecutarlo.

Migraciones internas versionadas:

- `20261025085402_InitialInternalSavia`
- `20261027224500_InternalBranchScope`

Fuente: [migraciones](../backend/src/Martha.Store.Api/Internal/Migrations/) y
[factory de diseño](../backend/src/Martha.Store.Api/Internal/InternalDbContextFactory.cs).
La factory usa `design-time.invalid`; no es una conexión operativa.

## Qué está probado

| Fecha / capa | Evidencia | Límite |
| --- | --- | --- |
| 2026-10-31, piloto sintético local | Migración Internal real, segundo Up sin cambios; login Owner, venta desde UI, recuperación y persistencia API-only; copia/restauración histórica | 13/22 criterios operativos PASS, 9 NOT RUN; no aceptación completa ni permiso para repetir arranques |
| 2026-11-03, fixtures SQL aisladas | 67/67 PASS sobre `SUAZO-PC` / instancia existente `SAVIATEST`, SQL Developer 17.0.1000.7 | 21 casos Store con migraciones; 46 internos con `EnsureCreated` |
| Limpieza del lote 2026-11-03 | 52 bases antes y después, nombres previos preservados, cero bases nuevas restantes | Las fixtures eliminaron solo sus bases; no se alteró el piloto |
| Recuperación de release actual | Dos `PrivatePilotReleaseTests` NOT RUN | Migraciones/backup/restore y reinicio del contenedor propio siguen pendientes para ese candidato |

`EnsureCreated` no acredita migraciones. Un readiness del contexto Store no acredita readiness Internal.
Los resultados de navegador con API simulada y los tests SQL separados no prueban el recorrido combinado.
Ver [SQL-TEST-SCOPE](testing-20261103/SQL-TEST-SCOPE.md), [resultados](testing-20261103/README.md)
y [procedencia histórica](reconciliation-20261103/README.md).

## Preparar el siguiente entorno, sin ejecutarlo aquí

1. Fijar SHA y hash de fuentes; especificar host, instancia y base desechable nueva.
2. Revisar la guarda, migraciones, fixture y evidencia esperada; no reutilizar el piloto por comodidad.
3. Definir cuentas sintéticas, roles, sucursal, stock y conexiones mediante secretos fuera del repositorio.
4. Obtener alcance de runtime para esa ejecución. La aprobación del lote anterior está consumida.
5. Aplicar migraciones Internal reales en el destino aprobado y verificar historial/esquema/readiness autenticado.
6. Ejecutar N1–N10 desde navegador y comparar ventas, operaciones y movimientos directamente en SQL.
7. Verificar recuperación y restauración dentro del alcance aprobado; retirar solo recursos propios con evidencia.

No es un instalador ni una autorización. No iniciar Docker, servicios, certificados, seeds, cuentas o SQL
para “actualizar documentación”. Las bases, sesiones y recibos de autorización permanecen privados.
