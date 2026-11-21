# C4 / C5 / C7 — APTO CON REPAROS

Modo: VALIDATE, sólo lectura.
Host: `SUAZO-PC`.
Modelo: `gpt-6.1-sol`, razonamiento `xhigh`.
Candidato: `260b75951729189d987ffe423218ab1643bcfa3c`.
Snapshot: `C:/Users/Jason/MARTHA-SILVA/test-runs/c4-c5-c7-review-20261104`.
Rama: `task/c4-c5-c7-review-20261104`.
HEAD exacto y estado limpio comprobados al inicio y al cierre de las lecturas.

**Recomendación:** completar cinco checks técnicos de C4, cuatro de C5 y cinco de C7.
Retener el check universal de «cero escrituras» hasta registrar su excepción explícita.
Resultado: **14 VERIFIED, 1 PARTIAL**.
No encontré un defecto funcional bloqueante en este alcance.
El resultado no constituye aceptación formal de Jason.

## Evidencia del candidato

[SAVIA judge 41753826810](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41753826810): `599/599`, cero casos no aprobados y cero skips.
[SAVIA golden path 41753825439](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41753825439): `19/19`, sin fallos de oráculo.

El [vínculo HEAD/merge](evidence/head-merge-binding.json) distingue el candidato del checkout real.
CI ejecutó `ec671f4331267c8a0419b38d6c36a31e78f1be8d`, merge provisional del PR.
La comparación primaria devuelve `changedFiles: []`.

Los [resultados por método](evidence/backend-sanitized-results.json) confirman `1/1` en N1/N3/N4/N8/N9.
También confirman las dos InternalReleaseScriptTests y las tres PrivatePilotReleaseTests.
Leí sus aserciones y oráculos; el conteo total no fue la única prueba.

La [evidencia golden](evidence/golden-evidence.json) contiene oráculos SQL después de cada paso.
Observa dos migraciones, cinco identidades, una venta, una línea y un movimiento de venta.
El stock pasa de30 a28 y permanece28 durante replay y conflicto.
El teardown confirma `database_dropped=true` y `private_dir_removed=true`.

Las fuentes C4/C5/C7, migraciones, fixture, harness y workflows son idénticos entre `ca917005c331e8096e84d21bc1b35cb71a1700d5` y el candidato.
Los textos históricos «CI no ejecutado» conservan el límite de su captura.
No usé `ledger.done` como prueba de comportamiento.
No repetí runtime.

## Checklist exacto

Las rutas siguientes son relativas al snapshot.
Los IDs vienen del [snapshot de Trello](trello-before.json).
[checklist-verdicts.json](checklist-verdicts.json) contiene texto literal, cardId, checklistId, evidencia, candidato y límite por fila.
Todas las filas VERIFIED incluyen el artefacto actual correspondiente.

| Card | checkItemId | Estado | Marcar | Fuente y línea |
|---|---|---|---|---|
| C4 | `6aea5e36ade0714b026596c2` | VERIFIED | Sí | `docs/sprint-20261104/C4-C7.md:16`; `backend/tests/Martha.Store.Api.Tests/InternalMigrationTests.cs:55` |
| C4 | `6aea5e374ce5c9cbf52b665f` | VERIFIED | Sí | `backend/tests/Martha.Store.Api.Tests/InternalReleaseScriptTests.cs:53`; `docs/sprint-20261104/C4-C7.md:44` |
| C4 | `6aea5e379bee14751da20f79` | VERIFIED | Sí | `backend/tests/Martha.Store.Api.Tests/InternalReleaseScriptTests.cs:40`; `backend/tests/Martha.Store.Api.Tests/InternalReleaseScriptTests.cs:56` |
| C4 | `6aea5e38ca3d0c5bd7a5af6b` | VERIFIED | Sí | `backend/tests/Martha.Store.Api.Tests/PrivatePilotReleaseTests.cs:88`; `backend/tests/Martha.Store.Api.Tests/PrivatePilotReleaseTests.cs:107` |
| C4 | `6aea5e50d29ae382152ad09c` | VERIFIED | Sí |  |
| C5 | `6aea5e5058c211bc54ccc925` | VERIFIED | Sí | `docs/sprint-20261104/C5.md:6`; `docs/sprint-20261104/C5.md:69` |
| C5 | `6aea5e5100c0dabd87682f74` | VERIFIED | Sí | `tests/golden-path/golden_path.py:515`; `tests/golden-path/golden_path.py:578` |
| C5 | `6aea5e52186655e5afef1c42` | VERIFIED | Sí | `tests/golden-path/GoldenPath.Sql/Program.cs:105`; `tests/golden-path/golden_path.py:511` |
| C5 | `6aea5e5214eec246fdff6462` | VERIFIED | Sí | `docs/sprint-20261104/C5.md:16`; `docs/sprint-20261104/C5.md:69` |
| C7 | `6aea5e56683d163dc2a0a549` | VERIFIED | Sí | `backend/tests/Martha.Store.Api.Tests/InternalAcceptanceHttpSqlTests.cs:25`; `backend/tests/Martha.Store.Api.Tests/InternalAcceptanceHttpSqlTests.cs:90` |
| C7 | `6aea5e57d64fe07fd3f98734` | PARTIAL | No, literal actual | `backend/tests/Martha.Store.Api.Tests/InternalAcceptanceHttpSqlTests.cs:182`; `backend/tests/Martha.Store.Api.Tests/InternalAcceptanceHttpSqlTests.cs:214` |
| C7 | `6aea5e58259b11d8a36c5e90` | VERIFIED | Sí | `backend/tests/Martha.Store.Api.Tests/InternalAcceptanceHttpSqlTests.cs:156`; `backend/tests/Martha.Store.Api.Tests/InternalAcceptanceHttpSqlTests.cs:179` |
| C7 | `6aea5e58a0ea2858280cc089` | VERIFIED | Sí | `backend/tests/Martha.Store.Api.Tests/InternalAcceptanceHttpSqlTests.cs:229`; `backend/tests/Martha.Store.Api.Tests/InternalAcceptanceHttpSqlTests.cs:253` |
| C7 | `6aea5e59bb5feea16e85c12d` | VERIFIED | Sí | `backend/tests/Martha.Store.Api.Tests/InternalAcceptanceHttpSqlTests.cs:279`; `backend/tests/Martha.Store.Api.Tests/InternalAcceptanceHttpSqlTests.cs:300` |
| C7 | `6aea5e593ebeede65d38b9ee` | VERIFIED | Sí |  |

## C4: oráculo privado comparado

La comparación pendiente se completó offline.
El primary aportó las rutas exactas mediante búsqueda acotada al proyecto.
No se leyó ninguna base ni se ejecutó SQL.

Privado: `C:/Users/Jason/MARTHA-SILVA/validation/private-pilot-20261028/worker/expected-invariants.json`.
Freeze: `C:/Users/Jason/MARTHA-SILVA/validation/private-pilot-20261028/worker/expected-invariants-freeze.json`.
Público: `backend/tests/fixtures/expected-invariants.model-derived.json`.

| Conjunto completo | Privado | Modelo | Diferencias |
|---|---:|---:|---:|
| history | 2 | 2 | 0 |
| tables | 19 | 19 | 0 |
| checks | 32 | 32 | 0 |
| foreign_keys | 26 | 26 | 0 |
| indexes | 37 | 37 | 0 |
| primary_keys | 19 | 19 | 0 |

SHA256 privado: `569a26094a106c305093acd291e772558af2c13b6cfb60e8a5ebcc0486043021`.
Coincide con el freeze de `2026-10-29T05:33:42.2820687Z`.
SHA256 público de este checkout: `3015d5316e6c5090846c29f87e6d180bb72fa9964dea48b3f628251a601239d0`.
Normalizado a LF: `4e3b7296aabddd94e9cdc2928246f74761438b72f944ed40eca74b418851a305`, igual al documentado.

La única diferencia restante es `provenance`.
El privado declara congelación desde fuente Up antes de SQL.
El público declara derivación independiente desde el modelo EF mediante EnsureCreated.
Es una diferencia esperada de origen; los seis conjuntos coinciden completos.
No se copiaron las listas privadas al reporte.
Esto resuelve la comparación documental de C4.
No demuestra el estado actual de una base de SUAZO-PC.

## Hallazgo por gravedad

**P3 — El texto universal «cero escrituras» necesita alcance explícito.**
Fuente: [InternalAcceptanceHttpSqlTests.cs:214](C:/Users/Jason/MARTHA-SILVA/test-runs/c4-c5-c7-review-20261104/backend/tests/Martha.Store.Api.Tests/InternalAcceptanceHttpSqlTests.cs:214).
Es una discrepancia del contrato literal, no un defecto funcional.

Reproducción ya ejecutada en N4:
Owner intenta dos veces remapear una ubicación con historia usando la misma clave.
Ambas respuestas son409.
Las 18 tablas distintas de Operations conservan la misma huella.
Operations añade exactamente una fila de rechazo durable.
El replay no añade otra fila.
La ubicación y el historial original no cambian.

El [runner:102](C:/Users/Jason/MARTHA-SILVA/test-runs/c4-c5-c7-review-20261104/backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs:102) revierte el efecto de negocio antes de guardar el rechazo durable.
Los rechazos de autorización/alcance/CSRF conservan las huellas de las 19 tablas.
La [huella:474](C:/Users/Jason/MARTHA-SILVA/test-runs/c4-c5-c7-review-20261104/backend/tests/Martha.Store.Api.Tests/InternalAcceptanceHttpSqlTests.cs:474) incluye todas las filas y RowVersion.

Acción mínima: primary registra la precisión en Trello antes de marcar `6aea5e57d64fe07fd3f98734`.
Texto propuesto: «Autorización/CSRF: huella idéntica en19 tablas. Remap409: negocio intacto y un único rechazo durable».
Comprobación de cierre: el check y su evidencia no afirman cero filas Operations para ese409.
No requiere cambio de código ni nuevas pruebas.
Jason conserva la aceptación.

## Autoridad y límites

N1 falsifica X-Role y X-Actor-Id; Cashier recibe403.
N3 intenta autopromoción y comandos fuera de rol con cuerpos válidos.
N4 prueba IDs, ubicación y clave de otro actor; no obtiene su recibo.
El mismo texto de clave en el alcance propio crea una operación propia del Cashier.
No transfiere la identidad del Owner.

El [runner:59](C:/Users/Jason/MARTHA-SILVA/test-runs/c4-c5-c7-review-20261104/backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs:59) vincula actor y principal.
Revalida sesión y rol dentro de la transacción.
La [consulta de alcance:27](C:/Users/Jason/MARTHA-SILVA/test-runs/c4-c5-c7-review-20261104/backend/src/Martha.Store.Api/Internal/InternalBranchAccess.cs:27) consulta Staff, Branches y Locations persistidos.
El cliente no define la autoridad mediante headers, IDs ni paginación.
N9 revisa razón, actor, ubicación, movimiento y balance mediante SQL.

C4 prueba el script sobre base vacía y primera migración con filas de nueve tablas.
Comprueba conservación de filas, nuevas columnas sin asignación inferida y reaplicación sin efecto.
Los PrivatePilot validan esquema, backup/restauración real sintética y rechazos de restricciones.
Su CI usa el oráculo público; la comparación privada adicional descrita arriba ya pasó.

C5 usa `IMigrator.MigrateAsync`; no usa EnsureCreated para crear la base.
El .sql idempotente se valida en C4, no en el golden.
El quinto perfil C5 es Cashier sin BranchId.
C7 también prueba Manager sin asignación.
La sucursal se prepara con EF porque no existe endpoint HTTP de creación.

SEC-CSRF del mismo usuario tras relogin permanece como decisión separada de Jason.
No cambié seguridad ni presenté ese comportamiento como escalada.
C5 prueba Linux local/CI; no prueba Windows, tienda real, pagos, carga ni producción.
No evalué C6, C9 ni el PR completo.

No ejecuté tests, builds, SQL, Docker, API ni browser.
No modifiqué repositorios, ledger, PROJECT-STATUS, GitHub ni Trello.
Únicas salidas: este reporte y checklist-verdicts.json.
Ownership de esta auditoría liberado.

