# C9: procedimiento revisable de recuperación Windows

**Estado: DOCUMENTARY_PROCEDURE_READY_FOR_REVIEW. C9 sigue BLOCKED.**

Modo `DISCOVER`. Resultado externo buscado: demostrar recuperación comercial en `SUAZO-PC` sin consumir una corrida incompleta.
Cuello de botella: faltan preflight vigente, campos privados y un coordinador Windows revisado.
Recomendación: cerrar primero el preflight de lectura descrito en `PREFLIGHT-SCOPE.md`.
Ningún paso SQL, API, Owner o retirada de este documento está autorizado por esta entrega.

Host leído: `SUAZO-PC`.
Modelo/razonamiento seleccionados por Jason para este lote: `gpt-6.1-sol / xhigh`.
Checkout leído: `C:/Users/Jason/MARTHA-SILVA/github`, rama `Tony`.
HEAD observado al comenzar: `2ddf83de7a89da608e8267a21313d64b373bf5e2`.
Ese SHA identifica el contexto documental observado; no selecciona automáticamente el producto que se ejecutará.
El árbol compartido tenía rutas ajenas sin seguimiento; este agente no las modificó.

## 1. Hechos verificados y límites

| ID | Hecho leído | Fuente exacta del checkout |
| --- | --- | --- |
| E01 | C9 está `blocked`. Exige CHECKSUM, VERIFYONLY, base nueva con oráculos, RTO/RPO y recuperación Owner documentada. | `docs/pipeline/ledger.json:223-237` |
| E02 | El preflight propuesto todavía no está autorizado ni ejecutado. Las mutaciones necesitan otro alcance. | `docs/c9-recovery-20261103/PREFLIGHT-SCOPE.md:3-6,38-49,59-62`; `docs/PROJECT-STATUS.md:139-140` |
| E03 | Helper existente: `create`, `branch`, `oracles`, `exists`, `drop`; también contiene `cert`, excluido de C9. | `tests/golden-path/GoldenPath.Sql/Program.cs:15-23` |
| E04 | `create` rechaza base existente y aplica `IMigrator.MigrateAsync`; devuelve historial, pendientes y Staff. | `tests/golden-path/GoldenPath.Sql/Program.cs:105-118` |
| E05 | `oracles` devuelve conteos e inconsistencias. `ok=true` solo acredita lectura, no que los conteos pasen. | `tests/golden-path/GoldenPath.Sql/Program.cs:154-207` |
| E06 | El runner Python usa POSIX y no es coordinador Windows. `--database` solo prueba la guarda de rechazo. | `tests/golden-path/golden_path.py:1-6,13-29,1119` |
| E07 | El arranque API existente usa `dotnet`, DLL y `--urls`. Las variables viven en el hijo. | `tests/golden-path/golden_path.py:540-562` |
| E08 | La prueba release fija rutas Linux y usa `INIT`. No se propone ejecutarla aquí. | `backend/tests/Martha.Store.Api.Tests/PrivatePilotReleaseTests.cs:137-144` |
| E09 | Readiness Internal exige autorización y examina tablas/migraciones. `/health/ready` pertenece a Store. | `backend/src/Martha.Store.Api/Internal/InternalHosting.cs:43-58`; `docs/DATABASE.md:10-20` |
| E10 | Otro Owner vigente puede resetear la contraseña con versión actual. El reset rota versión y revoca sesiones. | `backend/src/Martha.Store.Api/Internal/Security/InternalSecurity.cs:126-138`; `InternalSecurityService.cs:120-162` |
| E11 | Cualquier Staff cierra bootstrap. Resultado `4` significa UNKNOWN y prohíbe retry. | `backend/src/Martha.Store.Api/Internal/Security/InternalSecurityService.cs:185-202`; `InternalOwnerConsole.cs:23-28,122-137` |
| E12 | La preparación anterior y su REPORT tienen el mismo SHA256: `5a577ca35c45c31f0252395eb4b63445c08f2b1d0573597eed72ca15ead0f950`. | `docs/c9-recovery-20261103/PREPARATION.md`; `coordination/c9-prep-20261103/REPORT.md` |

La evidencia CI y los resultados históricos citados por PREPARATION no se revalidaron en servicios externos.
No se abrió el borrador Owner de Slack; su hash y veredicto siguen siendo referencia suministrada.
El código actual desplaza referencias antiguas: API `540-562`, opción oculta `1119` y C9 ledger `223-237`.

## 2. Gates: resolver todos antes de una corrida completa

`VERIFICADO_DOCUMENTAL` significa fuente leída. `PENDIENTE` significa que falta evidencia actual.
Ningún gate operativo está aprobado por la presencia de esta tabla.

| Gate | Estado | Evidencia necesaria para abrirlo | Dueño |
| --- | --- | --- | --- |
| G0 Alcance de lectura | PENDIENTE | Aprobación nueva del preflight exacto, host, identidad, límite de una sesión y sin rutas alternativas. | Jason / primary |
| G1 Candidato y binarios | PENDIENTE | SHA producto aceptado por C6, CI del mismo SHA, hashes de DLL/helper y compilación vinculada; SDK `10.0.402`. | Primary / dueño C6 |
| G2 Cliente, identidad y TLS SQL | PENDIENTE | Cliente exacto, versión, ruta, transporte, dos identidades/SID y conexión que valida TLS según alcance aprobado. | Ejecutor autorizado |
| G3 Rutas, archivos y colisiones | PENDIENTE | Raíces absolutas, volumen/espacio, permisos observados y ausencia de nombres/archivos; sin crear ni cambiar ACL. | Ejecutor autorizado |
| G4 Identidad y TLS API | PENDIENTE | SID efectivo limitado, acceso propio a nuevas bases, certificado existente válido, hostname/SAN, clave legible y puerto loopback libre. | Primary / ejecutor autorizado |
| G5 Coordinador Windows | PENDIENTE | Código revisado con manifest privado, identidad hija, reloj monotónico, checkpoints, timeouts, fallos y retirada; sin invocación C9 inventada. | Dueño C9 / primary |
| G6 Permiso de mutación | PENDIENTE | Alcance único enumera creación/migración/fixture/Owner sintético, backup/restore/CHECKDB, API, eventuales grants y retirada. | Jason |
| G7 Recuperación comercial | PENDIENTE | Backup válido, restaurada ONLINE, esquema/checkpoint/oráculos iguales, login fresco y mismo recibo sin otro débito. | Ejecutor autorizado / reviewer |
| G8 Métricas | PENDIENTE | Tiempos monotónicos completos, RPO de S1/S2, tamaño y límites del simulacro; objetivos de negocio separados. | Ejecutor autorizado / Jason |
| G9 Owner y retirada | PENDIENTE | Procedimiento Owner revisado y límites aceptados; readback de ausencia de recursos propios o handoff de conservación. | Primary / Jason |

La definición documental y los límites de E01–E12 están `VERIFICADO_DOCUMENTAL`.
G0–G9 siguen pendientes; no equivalen a un checklist C9 completado.

## 3. Manifest privado pendiente

Conservar valores sensibles fuera del checkout y del resultado público.
Publicar solo estados, agregados y hashes de evidencia aptos.

| Campos | Valor conocido / campo faltante | Comprobación exacta propuesta |
| --- | --- | --- |
| `host`, `sql.instance` | Host `SUAZO-PC` comprobado; instancia histórica `SUAZO-PC\SAVIATEST`. | Cotejar identidad del servidor conectado con host/instancia autorizados. |
| `candidate.sha`, `candidate.ci`, `api.dllHash`, `helper.dllHash` | FALTAN. HEAD documental no sustituye candidato aceptado. | Mismo SHA y hashes antes de abrir conexiones. |
| `client.path`, `client.version`, `client.driver`, `client.transport`, `client.tlsPolicy` | FALTAN actuales. Antecedente SQLCMD: `C:/Program Files/Microsoft SQL Server/Client SDK/ODBC/180/Tools/Binn/SQLCMD.EXE`. | Confirmar instalación existente; elegir un cliente y congelar consultas/flags. No instalar ni adivinar sintaxis. |
| `operator.name`, `operator.sid`, `sql.originalLogin`, `sql.effectiveLogin`, `sql.roles` | Candidato histórico `SUAZO-PC\Jason`; SID y permisos FALTAN. | Readback de identidad inicial y efectiva; rechazo de destino o identidad inesperados. |
| `sql.edition`, `sql.version`, `sql.serviceState`, `sql.tlsValidated` | Developer `17.0.1000.7` es histórico. | Leer metadata vigente; servicio detenido o fallo TLS detiene el preflight. No iniciarlo ni relajar TLS. |
| `sql.backupRoot`, `sql.dataRoot`, `sql.logRoot`, `sql.logicalFiles` | FALTAN rutas actuales y nombres lógicos reales. | SERVERPROPERTY de raíces; FILELISTONLY del backup autorizado; ninguna raíz NULL, relativa o deducida. |
| `storage.freeBytes`, `storage.aclObserved`, `storage.serviceIdentity` | FALTAN. | Verificar espacio para fuente+copia+backup y permisos de identidad del motor. La ACL observada no prueba por sí sola acceso efectivo. |
| `api.identity`, `api.sid`, `api.dbAccess`, `api.port` | Candidata `SUAZO-PC\SaviaTestApi`; acceso a nuevas bases FALTA. | API nunca corre como operador SQL elevado. Si hacen falta grants, efecto separado para Jason. |
| `api.certPath`, `api.keyPath`, `api.validFromTo`, `api.hostname`, `api.clientTrust` | FALTAN. | TLS validado en hostname aprobado; certificado existente y clave legible por SID API. Sin generación, importación, pin nuevo ni excepción TLS. |
| `fixture.ids`, `fixture.actor`, `fixture.branch`, `fixture.body`, `fixture.keyS1`, `fixture.keyS2` | FALTAN; los define el driver C6 aceptado. | IDs propios, marcador sintético, actor original conservado y claves distintas de S1/S2. No usar cookies históricas. |
| `owner.recoveryActor`, `owner.target`, `owner.allowedState` | FALTAN si se ensaya reset. | Otro Owner vigente; destinatario y estado/rol/sucursal autorizados. Sin esto, procedimiento documental solamente. |
| `limits.timeouts`, `limits.rtoMax`, `limits.rpoMax`, `retention.until`, `cleanup.scope` | FALTAN. | Congelar tiempos máximos y conservación. RTO/RPO observados no son PASS de negocio sin objetivos aprobados. |

Nombres reservados documentalmente; disponibilidad actual **NO COMPROBADA**:

- Fuente: `SaviaInternalTest_Golden_c9db647e8aeb4e55a7c46f48facb93aa`.
- Restaurada: `SaviaInternalTest_Golden_eb8b043220b54bc0a650d5b85bc8872f`.
- Backup: `SaviaInternalTest_Golden_c9db647e8aeb4e55a7c46f48facb93aa_c9_20261103.bak`.
- Restaurada: basename de la base más `.mdf` y `_log.ldf` bajo raíces aprobadas.

Cualquier colisión detiene el plan. No reutilizar, sobrescribir ni borrar el recurso existente.
Si un nombre ya fue consumido, el primary emite otro alcance antes de cualquier intento.
Nunca tocar `SaviaInternalTest_20261031` ni `SaviaInternalTest_20261031_RestoreProof`.
Fuentes: `PREPARATION.md:41-60,248-255`; `PREFLIGHT-SCOPE.md:18-33`.

## 4. Secuencia propuesta, NO EJECUTADA

Cada etapa necesita acuse inequívoco antes de continuar.
Un timeout, salida perdida, discrepancia o resultado UNKNOWN conserva evidencia y detiene la secuencia.
No hay retry automático, fallback de cliente, elevación ni cambios de seguridad implícitos.

| Etapa | Acción después del gate | Evidencia y condición de parada |
| --- | --- | --- |
| P0 Preflight | Ejecutar solo lecturas aprobadas de G0. Completar manifest y cerrar sesiones. | Identidades, TLS, metadata, colisiones y rutas actuales; no tablas de negocio existentes. Un fallo retorna al primary. |
| P1 Revisión previa | Fijar G1–G6 y revisar coordinador Windows con campos completos. | Permiso de mutación separado y checks congelados. No consumir una corrida para descubrir estos campos. |
| P2 Fuente | Crear fuente nueva mediante helper y migraciones reales. Preparar fixture C6 autorizada y S1 confirmada. | Historial exacto de dos migraciones, pendientes `0`, marca sintética, acuse S1 y lectura SQL; no `EnsureCreated` ni seed Store. |
| P3 Checkpoint B0 | Congelar escritores propios y capturar esquema, oráculos, IDs/valores comerciales y acuse S1. | Checkpoint incluye Sales, SaleLines, StockMovements, StockBalances, Operations y directorio pertinente. Ninguna venta ajena. |
| P4 Backup | Crear archivo nuevo con COPY_ONLY/CHECKSUM. Leer HEADERONLY/FILELISTONLY y hacer VERIFYONLY. | Nombre de fuente, BackupSetGUID, inicio/fin, checksum, COPY_ONLY y nombres lógicos correctos. Sin INIT, FORMAT ni REPLACE. |
| P5 Punto perdido | Permitir únicamente S2 con otra clave; guardar acuse HTTP+SQL y congelar otra vez. Declarar incidente lógico. | S2 existe en fuente. Guardar B1, importe/cantidad y hora UTC. No detener PC, SQL ni API histórica. |
| P6 Restauración | Seleccionar/verificar backup ya identificado. Restaurar a base nueva con MOVE explícito y CHECKSUM/RECOVERY. | Base ONLINE, archivos independientes, CHECKDB sin errores y esquema/B0 iguales. S1 presente; S2 ausente. |
| P7 Servicio | Abrir API propia limitada sobre restaurada; validar TLS, 401 anónimo, login fresco y readiness Internal 200. | PID/creación/SID/configuración coinciden; `status=ready`, `scope=internal`. No hot-rebind de proceso histórico. |
| P8 Recibo | Recuperar S1 por ID y por clave/actor originales. Repetir el mismo POST solo como replay de idempotencia autorizado. | Mismo saleId/líneas/total; ningún incremento en ventas, líneas, movimientos, saldos u Operations. Separar GET/replay del flujo C6 de cero POST adicionales. |
| P9 Medición | Cerrar relojes después de los oráculos finales. Evaluar Owner como apartado separado. | RTO SQL, RTO servicio y RPO observados completos; cualquier tramo ausente es NOT RUN o parcial. |
| P10 Retirada | Detener solo procesos propios verificados. Conservar backup/evidencia según permiso. Borrar solo recursos propios autorizados. | Readback de PID ausente, bases propias ausentes, inventario ajeno preservado y estado de archivos. Si falta propiedad, conservar y entregar handoff. |

P6 compara B0, no B1: S2 fue confirmada después del backup y es la pérdida esperada del ensayo.
Antes de abrir sesiones nuevas, comparar Staff/roles/sucursal/Enabled con B0 sin publicar hashes de contraseña.
Después de login, separar nuevas sesiones del snapshot comercial.
Fuente: `PREPARATION.md:70-85,167-212`; implementación de los oráculos en E05.

### Comandos existentes: PROPUESTOS, NO EJECUTADOS

Son llamadas independientes del helper. No constituyen un runner C9.
La variable privada `MARTHA_TEST_SQL_CONNECTION` debe apuntar al servidor aprobado con política TLS revisada.
El helper conserva las opciones TLS suministradas; su guarda comprueba nombre/MARS, no valida identidad o confianza por sí sola.

```powershell
$c9Dotnet = 'C:\Users\Jason\.dotnet-sdk-10.0.402\dotnet.exe'
$c9Helper = '.\tests\golden-path\GoldenPath.Sql\bin\Release\net10.0\GoldenPath.Sql.dll'
$c9Source = 'SaviaInternalTest_Golden_c9db647e8aeb4e55a7c46f48facb93aa'
$c9Restored = 'SaviaInternalTest_Golden_eb8b043220b54bc0a650d5b85bc8872f'
# Solo bajo autorización explícita de lectura:
& $c9Dotnet $c9Helper exists $c9Source
# Exigir exit=0, ok=true y exists=false; después comprobar la segunda base.
& $c9Dotnet $c9Helper exists $c9Restored
# Solo después de G1–G6 y ambos nombres ausentes:
& $c9Dotnet $c9Helper create $c9Source
# Después de fixture/S1 y checkpoint autorizados:
& $c9Dotnet $c9Helper oracles $c9Source
# Después de restauración autorizada:
& $c9Dotnet $c9Helper oracles $c9Restored
```

Guardar `$LASTEXITCODE` y JSON de cada proceso por separado.
`exists` consulta SQL; no ejecutarlo bajo este lote documental.
`create`: exigir `ok=true`, `pending=0`, dos IDs esperados y Staff `0` antes de bootstrap sintético autorizado.
`oracles`: evaluar los campos; no aceptar `ok=true` como PASS comercial.

Inconsistencias que deben ser `0`:
`lines_without_exactly_one_movement`, `sale_movements_not_matching_a_line`,
`balance_vs_movement_sum_mismatch`, `balance_vs_last_movement_mismatch`,
`negative_or_invalid_stock`, `negative_movement_after`, `duplicate_idempotency_keys`,
`unassigned_staff`, `items_without_synthetic_marker`.
Comparar los demás conteos con B0; su valor esperado depende de la fixture C6 aceptada.

No se publica comando SQLCMD completo: faltan versión cliente, transporte y política TLS aprobados.
No se publica comando de coordinador Windows: todavía no existe una invocación completa demostrada.
La plantilla SQL revisable permanece en `PREPARATION.md:142-158`; no se ejecuta con marcadores pendientes.
El preflight vigente limita las consultas a los dos nombres; no copiar el inventario general de la plantilla histórica.

### Contrato mínimo del coordinador Windows pendiente

El coordinador debe usar un manifest privado y artefactos vinculados al mismo SHA.
Debe iniciar el proceso con el SID API limitado aprobado; establecer variables no cambia la identidad Windows.
Debe inyectar solo en el hijo: `ASPNETCORE_ENVIRONMENT=Development`, `DOTNET_ENVIRONMENT=Development`,
`InternalSavia__Enabled=true`, `Synthetic__Enabled=false`, conexión Internal a la restaurada y configuración TLS existente.
Debe dejar Store cerrado según `golden_path.py:547-548`.
Debe registrar PID, instante de creación, SID, puerto, hashes y fases sin imprimir secretos.
Debe usar reloj monotónico y UTC correlacionado; tiempos SQL requieren zona horaria registrada.
Debe limitar cada proceso/consulta/espera y registrar timeout como fallo, sin repetir la mutación.
Debe devolver un estado por fase y permitir retirada únicamente con propiedad comprobada.
No debe reutilizar `cert`, pty POSIX, `--database`, bootstrap histórico ni la prueba release Linux.

## 5. RTO y RPO: aceptación de la medición propuesta

| Métrica | Inicio | Final / prueba |
| --- | --- | --- |
| `restore_engine_ms` | Justo antes del RESTORE DATABASE. | RESTORE devuelve acuse. Se publica separado. |
| `rto_sql_ms` | `restore_request_started` inmediatamente antes del RESTORE DATABASE. | ONLINE, CHECKDB y oráculos/checkpoint correctos. |
| `rto_service_ms` | `incident_declared` tras S2 y freeze. | Selección/verificación del backup, restore, API/TLS/login/readiness/recibo y oráculos finales completos. |
| RPO observado | B0/S1 frente a B1/S2 y al backup seleccionado. | S1 recuperada, S2 ausente; transacciones/importes perdidos, edad del backup e intervalo de acuses documentados. |

Registrar `backup_started/finished`, `verify_started/finished`, `incident_declared`,
`restore_request_started/finished`, `sql_validated`, `api_ready`, `receipt_validated` y `final_oracles_validated`.
Guardar duración monotónica y timestamp UTC de cada evento; registrar pausas humanas y tareas prehechas.
La segunda verificación después del incidente forma parte de RTO servicio.
Los acuses HTTP son observaciones, no timestamps exactos de commit.
Sin API autorizada, RTO servicio queda `NOT RUN`; RTO SQL no lo sustituye.
Un backup final sin S2 solo prueba cero transacciones del checkpoint perdidas.
El ensayo en caliente no prueba arranque frío, desastre del equipo, copia externa ni RPO operativo cero.
RTO/RPO máximos, cadencia y copia fuera del equipo siguen siendo decisiones de Jason.

## 6. Recuperación Owner: procedimiento documental

Referencia suministrada: `c9-owner-recovery-draft.md`, SHA256 `fee62423f69fd7946e6923f594ce8ae5d5f0a448e05049cef274f03a031e6a12`.
Su aceptación previa fue `ACCEPT_DOCUMENTARY_DRAFT_ONLY`; no acredita reset real.
Fuente de esa procedencia: `docs/c9-recovery-20261103/source-evidence.json:189-192` y `PREPARATION.md:214-221`.

Si existe otro Owner habilitado y accesible, aplicar esta secuencia solo bajo permiso separado de seguridad:

1. Validar HTTPS, sesión actual y par cookie/token CSRF del Owner recuperador.
2. Leer `GET /internal/api/security/staff`; fijar ID destinatario y `version` actual.
3. Enviar `POST /internal/api/security/staff/{staffId}/password` con `{password, version}` por canal privado.
4. Exigir HTTP `200`, versión distinta, mismo rol/sucursal/Enabled y sesiones anteriores revocadas.
5. Verificar cookie vieja `401`, contraseña vieja rechazada y login nuevo con CSRF renovado.
6. Comparar comercio antes/después; el reset no debe crear ventas ni movimientos.

El reset no habilita cuentas deshabilitadas.
Un PUT adicional necesita autorización explícita y versión fresca posterior al reset.
Ante `409 version_conflict`, releer y decidir; no reenviar una mutación incierta.
No publicar contraseña, cookies, tokens ni hashes; no usar la consola bootstrap como reset.

Si se perdió el último Owner accesible, detenerse y conservar la base.
No hay recuperación implementada demostrada para ese caso.
Cualquier Staff, incluso deshabilitado, cierra bootstrap.
No borrar Staff, sustituir hashes por SQL ni cambiar de base para eludirlo.
Un backup con los mismos accesos perdidos no resuelve la pérdida del último Owner.
La protección `last_owner_required` impide deshabilitar/degradar al último habilitado; no recupera su acceso.
Fuente directa: E10–E11 y `InternalSecurityService.cs:89-100`.

## 7. Retirada y rollback propuestos

El alcance futuro debe nombrar ambos recursos, archivos absolutos y procesos propios antes de mutar.
Detener normalmente solo el PID propio que conserve creación/SID/ruta registrados.
No detener SQL, API histórica, servicios ni procesos cuyo propietario sea incierto.
Para borrar bases, exigir inventario inicial ausente, acuse de creación y database_id/create_date coincidentes.
`drop` usa `SINGLE_USER WITH ROLLBACK IMMEDIATE`; su efecto necesita aprobación explícita.
Exigir después `existsAfter=false` y que los nombres previos permanezcan iguales.
Un acuse perdido de creación/restore/borrado deja UNKNOWN; no repetir, adjuntar ni eliminar por inferencia.
Retener backup y evidencia hasta aceptación o fecha autorizada.
Eliminar un archivo solo si su ruta final queda bajo raíz aprobada, hash/propiedad coinciden y el permiso lo cubre.
No cambiar ACL ni elevar para completar limpieza.
Las nuevas identidades/grants, si se autorizan, necesitan retirada precisa propia; nunca quitar un login Windows preexistente.
Si no hay permiso de borrar, devolver `PRESERVED_PENDING_AUTHORIZATION` con recurso, motivo, dueño y check; no llamar rollback completo.
Fuente: `PREPARATION.md:242-258`; `GoldenPath.Sql/Program.cs:137-151`.

## 8. Bloqueos y resolución preparada

| Bloqueo / hecho | Causa | Corrección documental y resultado | Acción / dueño | Check de cierre |
| --- | --- | --- | --- | --- |
| No hay permiso C9 operativo. | Solo lote documental y propuesta previa; G0/G6 cerrados. | Separados preflight y mutación; no se intentó runtime por autorización ausente. | Primary presenta G0; Jason decide. | Permiso nuevo enumera lecturas, identidad y límites. |
| Cliente, TLS, SID, rutas y colisiones sin readback actual. | Obtenerlos exige lectura SQL/host no autorizada en este lote. | Manifest fija campos y rechazos; no adivina valores ni instala. | Ejecutor autorizado completa P0. | Campos actuales completos, TLS validado, colisiones ausentes y sin mutaciones. |
| Acceso limitado de API a bases nuevas desconocido. | Identidad histórica no implica mapping/grants de la copia. | Distinguida identidad de configuración; seguridad no se modifica. | Primary revisa permisos; Jason decide cualquier grant. | API con SID limitado usa restaurada y no requiere credenciales elevadas. |
| Falta coordinador C9 Windows. | Helper no tiene backup/restore/timing; Python es POSIX. | Contrato concreto y llamadas existentes; ningún flag ficticio. | Dueño C9 implementa solo tras alcance nuevo de código. | Fuente revisada y manifest completo; una invocación soportada con fases/retirada. |
| Candidato C6 final y binarios no fijados por este agente. | C6/C8 pertenecen a otros agentes; no se duplicó su validación. | Gate G1 exige referencia aceptada. | Primary / dueño C6. | Mismo SHA/CI/artefactos y fixture aprobada; evidencia enlazada. |
| No hay recuperación del último Owner accesible. | Bootstrap cierra con cualquier Staff; reset exige otro Owner vigente. | Límite documentado y ruta válida por segundo Owner; no hubo bypass. | Jason acepta límite o encarga procedimiento nuevo separado. | Decisión explícita; no etiquetar ese caso como recuperado. |
| No existen RTO/RPO ni retirada nuevos. | No hubo ejecución SQL/API. Objetivos y retención faltan. | Relojes/checkpoints/evidencia/rollback definidos. | Ejecutor autorizado / Jason. | Corrida autorizada entrega métricas y readback; objetivo comercial separado. |

## 9. Verificación y entrega

Escrituras de este agente: únicamente `PROCEDURE.md` y `source-evidence.json` en la carpeta asignada.
Consultas SQL `0`; conexiones SQL `0`; API iniciadas `0`; servicios/Docker `0`; pruebas `0`.
Cambios de seguridad/certificados/ACL `0`; commits/push/merge/despliegue `0`; mensajes externos `0`.
No se modificaron `validation/`, `outputs/`, memoria ni checkout canónico.
La revisión automática de la entrega comprueba JSON, controles documentados y cercas Markdown; no prueba runtime.
Tokens de entrada/cache/salida/razonamiento y costo USD no fueron expuestos por la herramienta; no se estiman.

Lección aplicada: `ok=true` del helper acredita que leyó; cada oráculo requiere comparación explícita con B0.
Corrección mínima: exigir inconsistencias cero y equivalencia por IDs/valores antes de cerrar RTO servicio.

**Único siguiente paso recomendado:** el primary presenta a Jason el preflight de lectura de `PREFLIGHT-SCOPE.md`, con los campos de G0 y este manifest.
La autorización posterior de una corrida sigue separada y no está concedida.
