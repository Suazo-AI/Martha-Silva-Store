# PR #2: revisión técnica independiente

**APTO CON REPAROS para el alcance inspeccionado.** No encontré un bloqueo técnico de integración confirmado.
Este dictamen no cubre los 69 commits completos ni acepta SAVIA para operar una tienda.
La decisión de integración depende de las comprobaciones live del primary y de la autorización de Jason.

Host: SUAZO-PC. Modelo: gpt-6.1-sol. Razonamiento: high, según el paquete autorizado del lote.
Modo: VALIDATE, lectura de fuentes y evidencia existente, sin ejecutar pruebas.
Fecha: 2026-11-03.
Head inspeccionado: `775f301bc195c43baedc68c86f4e71affe92ef95`.
Base del incremento: `20932d5c97f2caaafad7dc888879957791907f36`.
Base completa indicada: `3b0049163ece2d9431cee01f1bea624a66d9d8d4`.
Worktree: `C:/Users/Jason/MARTHA-SILVA/test-runs/c3-n5-775f301-20261103`.
HEAD y estado limpio comprobados por lectura Git al inicio y al cierre.

## Hallazgos y límites concretos

**Sin defecto de producto bloqueante confirmado.**
Los dos reparos siguientes limitan las afirmaciones de verificación.
No demuestran una venta duplicada, acceso cruzado ni fallo actual del candidato.
No les asigno gravedad de defecto porque no se comprobó una regresión actual.

### R1 — Cobertura del verificador; no bloquea este incremento por sí sola

Fuente: `backend/tests/verify_full_suite.py:35`, `:37`, `:44`; `.github/workflows/savia.yml:145`.

El verificador exige IDs únicos, al menos 592 resultados y todos `Passed`.
Rechaza archivos ausentes, XML malformado, identidad inválida, duplicados y cualquier resultado no `Passed`.
No contrasta los resultados contra un inventario esperado de casos o métodos críticos.

Ejemplo de entrada: 592 filas válidas y distintas, todas `Passed`, sin el método de restart.
El código las acepta porque solo cuenta identidades y resultados.
Esto puede ocurrir después de añadir casos y omitir otro sin actualizar el mínimo.
No se demostró que esa sustitución ocurra en el CI actual.
La selección actual ejecuta toda la suite salvo restart, seguido por restart separado.

Corrección mínima propuesta: exigir también la presencia de los métodos de release y restart.
Para afirmar «ninguna omisión», contrastar un inventario de descubrimiento con los TRX.
No ejecutar otra suite solo para corregir la redacción de la garantía.
Owner: primary / responsable de CI.
Cierre: evidencia sintética que omita restart manteniendo el total debe ser rechazada.

### R2 — Alcance del oráculo; pendiente de release C4

Fuente: `backend/tests/Martha.Store.Api.Tests/PrivatePilotReleaseTests.cs:59`, `:60`, `:61`, `:67`.
Fuente del fixture: `backend/tests/fixtures/expected-invariants.model-derived.json:3` y `:7`.
Afirmación afectada: `docs/sprint-20261104/README.md:55`.

`Inspect` captura columnas, definiciones de checks y composición de índices.
`AssertSchema` compara contra el fixture solo historial y nombres de tablas, checks, FK, índices y PK.
También verifica cantidad de tablas, checks/FK habilitados y confiables, y borrado restrictivo de FK.
Las comparaciones posteriores contra `initial` comprueban estabilidad y restauración del mismo esquema migrado.
No convierten sus definiciones en una expectativa independiente.

Ejemplo: una migración puede conservar el nombre de un check y debilitar su expresión.
Si el cambio no afecta los cuatro rechazos concretos de `AssertRejects`, este oráculo no lo detecta.
Lo mismo aplica a columnas de un índice que conserva su nombre.
No encontré una migración defectuosa de ese tipo en el código inspeccionado.

La procedencia «EnsureCreated» está declarada en el fixture, pero este lote no la reprodujo.
No encontré un generador versionado que permita verificar esa procedencia aquí.
El historial del fixture se declara explícitamente; EnsureCreated no ejecuta esas migraciones.

Corrección mínima propuesta: describir la comparación como inventario de objetos y controles seleccionados.
Antes de usarlo como oráculo de release, completar C4 y comparar definiciones independientes.
Owner: primary / responsable de C4.
Cierre: un check debilitado o índice cambiado, conservando nombres, debe fallar contra la expectativa independiente.

## Qué respalda la revisión

- Sesión y autorización: `Program.cs` solo monta SAVIA con Development y habilitación explícita.
  Las rutas internas exigen HTTPS; cookies Secure/HttpOnly/Strict; mutaciones protegidas con CSRF.
- Identidad: `InternalCommerceEndpoints.cs:22` y `:25` derivan actor de `HttpContext.User`.
  El cliente no elige actor ni rol mediante el DTO de venta.
- Escrituras: `InternalCommandRunner.cs:67` abre una transacción Serializable.
  Revalida sesión y rol persistidos en `:69` antes de ejecutar o devolver replay.
- Sucursal: el runner resuelve el recurso en servidor y verifica acceso en `:93`–`:95`.
  `InternalBranchAccess` exige personal habilitado, sucursal asignada y activa para no Owner.
  El replay valida sucursal original y asignación actual, incluso con una sesión nueva válida.
- Idempotencia: `InternalCommandRunner.cs:78` serializa actor/scope/key con applock.
  El índice único de `InternalDbContext` usa esos tres campos con collation binaria.
  Fingerprint diferente devuelve conflicto; replay autorizado devuelve el resultado persistido.
- Atomicidad: `InternalCommandRunner.cs:105` revierte al savepoint cualquier rechazo de negocio.
  Operación y efecto exitoso se confirman en la misma transacción en `:115`.
- Precio y stock: `InternalCommerceService.RecordSale` usa precios y moneda de Items persistidos.
  `InternalStockLedger.Change` exige la transacción Serializable compartida.
  La actualización SQL condiciona saldo, reserva y límites antes de crear el movimiento.
- Compras: `InternalSupplyService.Receive` resuelve la compra en servidor.
  Bloquea compra/recibo y deduplica ReceiptId, identidad física separada de Idempotency-Key.
  No encontré bypass por LocationId/ReceiptId/actor controlado por el cliente en estas rutas.
- Migración de sucursales: `20261027224500_InternalBranchScope` es aditiva y no inventa asignaciones.
  Campos nulos dejan sin acceso a no Owner; no significan acceso global.
- Release: `PrivatePilotReleaseTests` llama al migrador real, reaplica y ejecuta down/up desechable.
  Usa BACKUP CHECKSUM, RESTORE VERIFYONLY y RESTORE real con archivos independientes.
  La prueba de restart comprueba datos congelados y rechazos tras stop/start del contenedor propio.
  Estas son operaciones reales en la implementación, no dobles de SQL.
- CI: `savia.yml:121` excluye solo restart de la primera invocación.
  `:131` y `:132` detienen y arrancan el contenedor; `:140` selecciona restart.
  Una invocación fallida sigue dejando el job fallido aunque el saneamiento use `always()`.
- Evidencia publicada: solo se sube `sanitized-results.json` del backend.
  El verificador descarta argumentos, mensajes, stdout y stack traces del TRX.
  Los workflows inspeccionados usan permisos contents:read y checkout sin credenciales persistidas.
  No contienen un paso de deploy, publicación o bootstrap de cuentas.
  La evaluación de triggers externos y configuración live pertenece al primary.

Estas observaciones proceden de lectura estática.
No sustituyen ejecución adversarial del recorrido combinado ni auditoría completa de seguridad.

## C3 reutilizado, sin repetición

Leídos `github/docs/c3-n5-20261103/report.md` y `summary.json`.
Candidato 5 PASS / 0 FAIL, exit 0.
Fix revertido 3 FAIL / 2 PASS, exit 1.
Arnés constante: `28d29a5722239e5ede1e5d6f7f2d6e7801028425506f317fd7920602e3e93956`.
Head exacto y bytes restaurados constan en la evidencia.
Las cinco pruebas usan Chrome real con respuestas API sintéticas.
Leí además el diff mínimo de `app.mjs`; no ejecuté C3 de nuevo.

## Alcance inspeccionado

Lectura completa del incremento relevante: `.github/workflows/savia.yml`, `backend.yml`,
`verify_full_suite.py`, `test_verify_full_suite.py` y el fixture nuevo.
Lectura del diff de `app.mjs` y `docs/CI-CD.md`.
Leídos AGENTS, AGENT-START, PROJECT-STATUS, CODE-MAP, DATABASE, README/evidence del sprint y evidencia C3.

Selección crítica del resto del PR: `Program.cs`, `InternalHosting.cs`, `InternalCommandRunner.cs`,
`InternalBranchAccess.cs`, `InternalDbContext.cs`, `InternalSecurity.cs`, `InternalSecurityService.cs`,
`InternalStockLedger.cs`, `InternalCommerceEndpoints.cs`, `InternalCommerceService.cs`,
`InternalSupplyService.cs`, migración `20261027224500_InternalBranchScope`, y `PrivatePilotReleaseTests.cs`.
Inspeccionadas secciones de `InternalSecuritySqlTests`, `InternalRunnerSqlTests` e `InternalBranchScopeSqlTests`.
La búsqueda de guardas de tests cubrió las variables SQL, autorización y skip de las fixtures.

No revisión exhaustiva de tienda pública, assets, migración inicial/Designer, frontend entero,
consola Owner, lógica heredada Store/Savia ni los 97 archivos backend/UI/workflow cambiados desde main.
El alcance filtrado desde main suma 17.171 inserciones y 31 eliminaciones.
No se puede convertir esta muestra en aprobación de los 69 commits.

## Pendiente y dueño

- Primary: confirmar head/base/checks live, protecciones y efecto de merge sobre deploy.
  No dupliqué sus consultas GitHub.
- Responsable C4: completar el oráculo independiente con los límites de R2.
- Responsable C5/C6: probar navegador → API real → SQL migrado bajo autorización específica.
- Jason / responsable de aceptación: aprobar recorrido del cajero, dispositivos y ensayo en tienda.
  Son criterios de release; su ausencia no demuestra por sí sola que este diff no pueda integrarse.

Los 592/592 del documento son evidencia curada de la sesión cloud.
Este reviewer no ejecutó ni auditó sus TRX privados; no los presenta como verificación nueva propia.
No hubo fallo de entorno ni corrección intentada durante esta revisión.
Los reparos siguen abiertos porque la tarea es read-only y prohíbe modificar producto o repetir pruebas.

No hubo tests, SQL, Docker, navegador, instalación, commit, push, merge, deploy ni cambio de seguridad.
Solo se creó este informe fuera del worktree revisado.
