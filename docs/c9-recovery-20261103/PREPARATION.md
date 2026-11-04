# C9: preparación de recuperación, sin ejecución

**Resultado: PREPARED_NOT_AUTHORIZED. C9 sigue pendiente.**

La ruta corta es reutilizar los oráculos C5/C6 sobre una copia nueva en `SUAZO-PC\SAVIATEST`.
Medir la recuperación completa exige un alcance nuevo de SQL/API, rutas concretas e identidad limitada verificadas.
No reutilizar el piloto histórico ni sus autorizaciones.

Fecha de inspección: `2026-11-04 01:43 UTC` (`2026-11-03` en Managua).
Host comprobado: `SUAZO-PC`. Worker seleccionado para este lote: `gpt-6.1-sol / xhigh`.
Modo: `DISCOVER / VALIDATE`, documental.
Fuente Git fijada: `260b75951729189d987ffe423218ab1643bcfa3c`, checkout `C:/Users/Jason/MARTHA-SILVA/github`, rama observada `Tony`.
No se modificó ese checkout, otra rama, ledger, Trello, pruebas, `outputs/` ni `validation/`.
La publicación/exportación pertenece al hilo principal y a FIX-PR2.

## Qué ya existe y su límite

| Evidencia directa | Lo que demuestra | Lo que falta |
| --- | --- | --- |
| `docs/pipeline/ledger.json:216-234` | C9 exige CHECKSUM, VERIFYONLY, nueva base con oráculos, RTO/RPO medidos y recuperación Owner documentada. El RTO necesita SQL real de SUAZO-PC. | En el SHA fijado, C9 está `todo`; no convertir este informe en cierre. |
| `PrivatePilotReleaseTests.cs:107-144` | Migra, reaplica, prueba Down/Up en otra base, respalda con CHECKSUM, hace VERIFYONLY y restaura con archivos independientes. Compara esquema y cuatro filas comerciales. | Ruta Linux fija `/var/opt/mssql/data/`; sin venta, recibo, operación de venta, navegador, cronómetros ni RPO. No es un runner Windows. |
| `PrivatePilotReleaseTests.cs:75-85,127-152` | Fixture: sucursal, artículo, saldo `17/3` y usuario Inventory deshabilitado. Prueba rechazos de restricciones tras restaurar. | `Business()` no compara Sales, SaleLines, Operations ni identidades completas. No cubre los oráculos C5/C6. |
| `docs/sprint-20261104/C4-C7.md:3-5,67-72,139-155` | Evidencia Linux, SQL 2022 desechable; 598/598 sin el caso de reinicio. Documenta que la prueba release deja tres bases y `.bak`. | No equivale a medición Windows. No ejecutar esa prueba sin adaptación: ruta Linux y ausencia de limpieza propia. |
| Histórico privado `sql-local-20261031/restore-proof.json:1-30` | Copia local del 31-oct: COPY_ONLY, CHECKSUM, VERIFYONLY, restauración y CHECKDB; conteos iguales. | Tenía `Sales=0`; no hay tiempos ni RPO. `cleanupExecuted=false`. No ejecutar de nuevo sus nombres fijos. |
| Histórico privado `LocalRestoreProof.cs:10-46` | Ya hay patrón Windows ADO.NET: instancia local, identidad fijada, rutas desde SERVERPROPERTY, colisiones rechazadas, nombres lógicos leídos y CHECKDB. | Está fijado al piloto viejo y su copia. Reutilizar el patrón, no invocar ese archivo. |
| `tests/golden-path/GoldenPath.Sql/Program.cs:15-23,45-64,154-207` | Helper existente: `create`, `branch`, `oracles`, `exists`, `drop`; guardia estricta Golden. Sus oráculos leen venta/línea/movimiento/saldo/operación y migraciones. | No tiene comando backup/restore, cronómetro ni lectura de un recibo HTTP. |

El hilo principal aportó readback fresco de Trello C9: el backup/VERIFYONLY/restore de release ya corrió en CI; faltan oráculos C5/C6 sobre la restaurada, RTO local, RPO y Owner. Su checklist sigue `0/5`.
No consulté Actions ni Trello en este lote; esa ejecución CI es evidencia suministrada, no una revalidación mía.
Las afirmaciones `599/599` de `docs/PROJECT-STATUS.md:69-70` y del ledger corresponden a sus ejecuciones vinculadas.

`docs/DATABASE.md:35-38` conserva un corte anterior que aún llama NOT RUN a release.
Para C9, prevalecen el código fijado y la evidencia fechada del sprint/ledger; no repetir trabajo para resolver esa frase histórica.

## Alcance de ejecución propuesto, todavía cerrado

Objetivo: una restauración sintética en la instancia Windows existente, con integridad comercial y tiempos observados.
Conservar `sin reinicio`, `no producción`, `no Docker`, sin instalación, cuentas Windows, logins servidor, ACL, trust o servicios nuevos.
No detener SQL ni la API histórica.

| Campo | Valor / estado |
| --- | --- |
| Host / instancia | `SUAZO-PC\SAVIATEST`; transporte local documentado `lpc:.\SAVIATEST`. Es antecedente, no conectividad actual comprobada. |
| Motor histórico | SQL Developer `17.0.1000.7`, documentado en `docs/testing-20261103/SQL-TEST-SCOPE.md:31` y `sql-readback.sanitized.json:3-9`. No se consultó hoy. |
| Operador SQL candidato | `SUAZO-PC\Jason`; identidad histórica fijada en `LocalRestoreProof.cs:12-13`. Falta readback privado del operador/SID y alcance vigente. |
| API candidata | Identidad ya existente `SUAZO-PC\SaviaTestApi`, documentada en `api-permissions.json:2-5`. Falta confirmar SID, permisos efectivos y acceso a **las bases nuevas**. Nunca ejecutar la API como sysadmin. |
| SDK | `global.json:1` fija `10.0.402`, sin roll-forward. Existe `C:/Users/Jason/.dotnet-sdk-10.0.402/dotnet.exe` y su carpeta `sdk/10.0.402`. No se ejecutó build. |
| SDK provenance | El hilo C8 `01a1a3b8-ccb5-7ed0-b25f-5e2480f52e40` informó instalación y verificación SHA512. Aquí se comprobó existencia y SHA256 del **exe**, `ABCE6623A6729059CF39BB0F728C4A7804F625895099C88C17E6E704661E09EB`; no es el hash del paquete SDK. |
| Fuente nueva reservada documentalmente | `SaviaInternalTest_Golden_c9db647e8aeb4e55a7c46f48facb93aa` |
| Restaurada nueva reservada documentalmente | `SaviaInternalTest_Golden_eb8b043220b54bc0a650d5b85bc8872f` |
| Archivo backup propuesto | `SaviaInternalTest_Golden_c9db647e8aeb4e55a7c46f48facb93aa_c9_20261103.bak` |
| Archivos restaurados propuestos | `SaviaInternalTest_Golden_eb8b043220b54bc0a650d5b85bc8872f.mdf` y `SaviaInternalTest_Golden_eb8b043220b54bc0a650d5b85bc8872f_log.ldf` |
| Rutas SQL faltantes | `sql.InstanceDefaultBackupPath`, `sql.InstanceDefaultDataPath`, `sql.InstanceDefaultLogPath`; además nombres lógicos reales y ausencia de colisión. No se deducen de `master.mdf`. |
| API/TLS faltantes | `api.releaseSha`, `api.windowsSid`, `api.loopbackPort`, ruta del certificado existente autorizado y clave privada accesible, vigencia y mecanismo de confianza del cliente. No generar/importar certificados ni relajar TLS. |
| Datos | Solo fixture sintética C5/C6, identificadores y claves de operación propios. Nunca clientes ni una copia del piloto histórico. |

Los dos nombres nuevos cumplen la guarda de producto y la guarda **Golden** del helper.
Su disponibilidad todavía no está comprobada; cualquier colisión obliga a parar, conservar el recurso existente y emitir otro alcance con nombres nuevos.
No ampliar `PrivatePilotReleaseTests.Connection()` para aceptarlos: esa prueba admite Pilot/Release y no hace falta usarla.
No usar `--database` del runner Python para adjuntar una restaurada: es una opción oculta de prueba de rechazo (`golden_path.py:794`).

## Camino mínimo, con comandos existentes

No existe hoy una invocación C9 completa Windows.
`golden_path.py` importa `fcntl`, `pty` y `termios` (`:12-30`); su contrato es Linux/macOS (`:1-6`).
No instalar WSL ni cambiar de host para aparentar RTO de SUAZO-PC.
La extensión mínima propuesta es coordinar el helper .NET existente, SQL revisado y el driver C6 aceptado.
No se implementó esa extensión en este lote.

1. Fijar candidato y artefactos Release en una copia de trabajo que el ejecutor sea dueño de usar.
   Leer identidades, inventario anterior, rutas y TLS bajo una autorización nueva de diagnóstico SQL.
   Resolver todos los campos anteriores antes del permiso de mutación; no incluir secretos en el informe público.
2. Comprobar que los dos nombres y tres archivos destino no existen.
   Registrar ruta absoluta, inventario previo y acuse de creación; una respuesta perdida conserva estado UNKNOWN.
3. Migrar la **fuente nueva** con el helper existente `create`; aplicar las dos migraciones Internal reales.
   Preparar la misma fixture C5/C6 y una venta confirmada mediante las rutas reales.
   No usar `EnsureCreated`, seed de Store ni un bootstrap histórico.
4. Tomar oráculos y huella comercial previa. Congelar escritores de esta fuente durante el backup.
   Registrar watermark de ventas/operaciones confirmadas y momento de cada acuse HTTP.
5. Ejecutar COPY_ONLY + CHECKSUM, VERIFYONLY, restauración a la segunda base y CHECKDB.
   Leer nombres lógicos reales; no asumir que coinciden con la base, ni usar `WITH REPLACE` o `INIT`.
6. Comparar esquema y datos de la restaurada con el checkpoint, luego conectar **una API nueva propia** a ella.
   Login fresco, readiness Internal autenticado, recibo por ID, recuperación por la misma clave y replay sin otro débito.
   Añadir los pasos C6 pertinentes cuando su dueño los haya aceptado; este lote no duplica C6 ni sus cambios.
7. Registrar tiempos/RPO y retirar solo recursos de propiedad probada, con el permiso de limpieza correspondiente.

Estas invocaciones del helper ya existen; **no se ejecutaron aquí**.
Exigen binarios revisados, variable privada `MARTHA_TEST_SQL_CONNECTION` hacia el servidor autorizado y los permisos necesarios.
La presencia actual de DLLs en el checkout no prueba su correspondencia con el SHA fijado.

```powershell
$c9Dotnet = 'C:\Users\Jason\.dotnet-sdk-10.0.402\dotnet.exe'
$c9Helper = '.\tests\golden-path\GoldenPath.Sql\bin\Release\net10.0\GoldenPath.Sql.dll'
$c9Source = 'SaviaInternalTest_Golden_c9db647e8aeb4e55a7c46f48facb93aa'
$c9Restored = 'SaviaInternalTest_Golden_eb8b043220b54bc0a650d5b85bc8872f'
& $c9Dotnet $c9Helper exists $c9Source
& $c9Dotnet $c9Helper exists $c9Restored
# Solo después del permiso de creación y de ambos exists=false:
& $c9Dotnet $c9Helper create $c9Source
& $c9Dotnet $c9Helper oracles $c9Source
# Después del restore autorizado:
& $c9Dotnet $c9Helper oracles $c9Restored
```

Son llamadas separadas. Capturar exit code y JSON `ok` de cada una antes de continuar.
No ejecutar todo el bloque sin las precondiciones.
El helper no configura el mínimo privilegio de una API Windows; no inventar que `create` lo resuelve.
Si se requiere un usuario/grant nuevo dentro de estas bases, es un efecto de seguridad adicional que Jason debe autorizar explícitamente.
No lo ocultar bajo “sin cambios de seguridad”.

**Abrir la API sobre la copia:** el producto admite una conexión Internal explícita por configuración y valida el nombre Golden.
No hay un comando de hot-rebind del proceso actual ni un modo C9 del runner.
La extensión mínima debe crear un proceso API independiente, con variables **solo del hijo**: `ASPNETCORE_ENVIRONMENT=Development`, `DOTNET_ENVIRONMENT=Development`, `InternalSavia__Enabled=true`, `Synthetic__Enabled=false`, `ConnectionStrings__InternalSavia` apuntando a la restaurada con identidad limitada y las rutas TLS existentes aprobadas.
Mantener Store deshabilitado/no operativo según el contrato del arnés.
La invocación real existente es `dotnet Martha.Store.Api.dll --urls <https-loopback-aprobado>` (`golden_path.py:433-460`).
El coordinador Windows pendiente debe inyectar esa configuración privada, registrar PID/creación, esperar TLS/401 anónimo, hacer login nuevo y readiness 200, leer/reprobar el recibo y recoger oráculos finales antes de parar solo su proceso.
No se ha implementado ni ejercido ese coordinador; tampoco se ha probado hoy el acceso SQL/TLS de la identidad candidata.
No usar cookies antiguas como requisito de recuperación ni editar configuración persistente del piloto para cambiar su base.

SQL disponible por el patrón Windows ya existente (`LocalRestoreProof.cs:19-45`), con marcadores pendientes:

Preflight propuesto, bajo permiso nuevo y todavía no ejecutado:

```sql
SELECT SERVERPROPERTY('ServerName') AS server_name,
       SERVERPROPERTY('InstanceName') AS instance_name,
       SERVERPROPERTY('ProductVersion') AS product_version,
       ORIGINAL_LOGIN() AS original_login,
       SUSER_SNAME() AS effective_login,
       SERVERPROPERTY('InstanceDefaultBackupPath') AS backup_root,
       SERVERPROPERTY('InstanceDefaultDataPath') AS data_root,
       SERVERPROPERTY('InstanceDefaultLogPath') AS log_root;
SELECT name,create_date FROM sys.databases ORDER BY name;
-- Tras crear la fuente propia: leer nombres lógicos y rutas reales.
SELECT name,type_desc,physical_name FROM sys.master_files
 WHERE database_id=DB_ID(N'SaviaInternalTest_Golden_c9db647e8aeb4e55a7c46f48facb93aa')
 ORDER BY file_id;
```

Conservar inventario y conexiones en evidencia privada. Un root NULL o no absoluto detiene el plan.

```sql
-- Plantilla revisable; NO ejecutable hasta fijar rutas y nombres lógicos reales.
BACKUP DATABASE [SaviaInternalTest_Golden_c9db647e8aeb4e55a7c46f48facb93aa]
 TO DISK=N'<sql.InstanceDefaultBackupPath>\SaviaInternalTest_Golden_c9db647e8aeb4e55a7c46f48facb93aa_c9_20261103.bak'
 WITH COPY_ONLY,CHECKSUM;
RESTORE VERIFYONLY
 FROM DISK=N'<mismo archivo absoluto aprobado>' WITH CHECKSUM;
RESTORE HEADERONLY FROM DISK=N'<mismo archivo absoluto aprobado>';
RESTORE FILELISTONLY FROM DISK=N'<mismo archivo absoluto aprobado>';
RESTORE DATABASE [SaviaInternalTest_Golden_eb8b043220b54bc0a650d5b85bc8872f]
 FROM DISK=N'<mismo archivo absoluto aprobado>'
 WITH MOVE N'<nombre lógico ROWS comprobado>' TO N'<archivo .mdf absoluto aprobado>',
      MOVE N'<nombre lógico LOG comprobado>' TO N'<archivo .ldf absoluto aprobado>',
      CHECKSUM,RECOVERY;
DBCC CHECKDB([SaviaInternalTest_Golden_eb8b043220b54bc0a650d5b85bc8872f])
 WITH TABLERESULTS,NO_INFOMSGS,ALL_ERRORMSGS;
```

No probar esa plantilla contra una ruta imaginada.
Conservar del header el nombre de base, identificador del backup, inicio/fin y estado de checksum/COPY_ONLY; cotejar FILELISTONLY con los nombres lógicos previstos.
Los tiempos SQL del header requieren zona horaria del servidor documentada; no etiquetarlos UTC por suposición.
`SQLCMD.EXE` existe en `C:/Program Files/Microsoft SQL Server/Client SDK/ODBC/180/Tools/Binn/SQLCMD.EXE`.
No se ejecutó SQLCMD ni se propone instalar otro cliente; ADO.NET ya existe en ambos helpers.
No se publica `.bak`, `.mdf`, `.ldf`, claves, cookies, tokens, hashes de contraseña, autorizaciones ni log crudo.

## Oráculos que faltan sobre la restaurada

- Historial exactamente `20261025085402_InitialInternalSavia` y `20261027224500_InternalBranchScope`; cero pendientes; esquema/restricciones iguales y confiables.
- Snapshot comercial prebackup y restaurado igual por IDs/valores: Sales, SaleLines, StockMovements, StockBalances, Operations y metadatos comerciales de directorio.
  Los conteos solos no detectan una venta distinta con el mismo total.
  Conservar huellas privadas de todas las columnas relevantes; publicar solo resultados y huellas seguras, nunca hash de credenciales/sesión.
- Reutilizar `GoldenPath.Sql/Program.cs:162-201`: líneas sin un movimiento, movimientos sin línea, saldo contra suma/último movimiento, stock inválido y claves duplicadas deben ser `0`.
  Conteos de ventas/líneas/operaciones, stock y migraciones deben coincidir con el checkpoint.
- Después del login nuevo, excluir de la igualdad las **nuevas sesiones de esa prueba** y documentarlas por separado.
  Conservar iguales ventas, líneas, movimientos, saldos y operaciones durante GET/recuperación/replay.
- El recibo restaurado debe ser el mismo `saleId`, líneas y total; `GET /internal/api/operations/commerce.sale.record` usa actor y clave originales.
  Repetir el POST con misma clave/cuerpo devuelve el mismo recibo y ningún débito adicional.
- Una API anónima debe recibir `401`; autenticada, `GET /internal/api/readiness` devuelve `200`, `status=ready`, `scope=internal`.
  `/health/ready` no sirve: prueba Store, no Internal (`docs/DATABASE.md:10-20`; `InternalHosting.cs:45-58`).

## RTO y RPO: medir dos límites distintos

Usar un reloj monotónico del coordinador para duraciones y UTC para correlación.
Registrar tamaño de la fixture, bytes de base/backup, versión SQL, candidato y readbacks.
Un resultado con una fixture pequeña solo describe esa fixture, no el volumen futuro de la tienda.

**RTO SQL:** desde `restore_request_started` inmediatamente antes de RESTORE DATABASE, hasta restore terminado, base ONLINE y CHECKDB/oráculos correctos.
Publicar también el tiempo puro del RESTORE por separado.
El backup y VERIFYONLY se miden aparte; no incluirlos dentro del tiempo de restauración sin declararlo.

**RTO servicio:** desde `incident_declared` del simulacro hasta API nueva con TLS validado, login fresco, readiness Internal `200`, recibo restaurado recuperado y oráculos comerciales finales correctos.
Incluye selección/verificación de backup, RESTORE, oráculos, arranque de API y autenticación.
Anotar tiempos de espera humana y cualquier tarea prehecha; no esconderlos para reducir el número.
No apagar la PC ni SQL: declarar la indisponibilidad lógica del **entorno sintético propio** y recuperar en la base nueva.
Esto mide un simulacro en caliente; no prueba recuperación de una PC destruida o arranque frío.
Sin API autorizada, reportar únicamente RTO SQL y dejar RTO servicio `NOT RUN`.

**RPO observado:** usar dos checkpoints sintéticos y no el tiempo del restore.
Con escritores congelados, confirmar venta `S1`, guardar acuse UTC y lectura SQL, tomar backup y registrar inicio/fin/identificador del backup.
Después, permitir una única venta sintética `S2`, confirmar su acuse y SQL, congelar la fuente y declarar `incident_declared`.
Restaurar ese backup en la base nueva: `S1` debe existir; `S2` debe faltar, según el punto elegido.
Medir y publicar:

- Última transacción confirmada recuperada; última confirmada en fuente; número/importe de transacciones confirmadas ausentes.
- Edad del punto de recuperación: `incident_declared_utc - backup_finish_utc`, bajo el freeze declarado.
- Intervalo observado de acuses perdidos y antigüedad del último acuse recuperado, separados del anterior.

Los acuses HTTP son tiempos observados, no timestamps exactos de commit; registrar esa incertidumbre.
Si se elige backup final sin escrituras posteriores, solo puede afirmarse “0 transacciones del checkpoint perdidas”.
Eso no prueba RPO operativo `0` ni una política de backup continuo.
Cadencia, copia fuera del equipo y objetivos máximos RTO/RPO siguen sin definirse aquí; no inventarlos ni convertirlos en PASS de negocio.

## Owner: reutilizar el borrador ya aceptado

Referencia suministrada por el hilo principal:
[c9-owner-recovery-draft.md](https://denis-projects-group.slack.com/files/U0CC17GNJA0/F0CELEANZ8E/c9-owner-recovery-draft.md).
SHA256 suministrado: `fee62423f69fd7946e6923f594ce8ae5d5f0a448e05049cef274f03a031e6a12`.
Veredicto suministrado: `ACCEPT_DOCUMENTARY_DRAFT_ONLY`.
No se localizó una ruta local confirmada ni se descargó el documento.
No afirmo haber comprobado sus bytes; no lo copio ni lo sustituyo.

Notas de revisión directas del código para acompañar esa referencia:

- Otro Owner **habilitado y con sesión vigente** puede obtener la fila actual por `GET /internal/api/security/staff` y usar su `version` actual.
  `POST /internal/api/security/staff/{staffId}/password` recibe `{password, version}` por HTTPS con cookie y par CSRF válidos.
  La política exige Owner y el servicio revalida esa sesión dentro de la transacción serializable (`InternalSecurity.cs:81-93,126-138`; `InternalSecurityService.cs:120-148`).
- El reset rota `SecurityVersion`, limpia intentos/bloqueo y revoca todas las sesiones del destinatario (`InternalSecurityService.cs:151-162`).
  No habilita por sí solo una cuenta deshabilitada. Para ese caso, otro Owner necesita un PUT autorizado con versión fresca; no reutilizar una versión previa al reset.
- Verificar respuesta `200`, versión distinta, cookie antigua `401`, clave anterior rechazada y login nuevo con CSRF renovado.
  Verificar que rol, alcance y estado Enabled conservan el valor aprobado y que comercio no cambió.
  `version_conflict` es `409`: releer y decidir, nunca reenviar ciegamente una mutación incierta.
- Si se perdió el **último Owner accesible**, no hay recuperación implementada demostrada.
  `CreateInitialOwner` rechaza cualquier fila Staff, incluso deshabilitada (`InternalSecurityService.cs:185-202`).
  La consola devuelve `3` para `bootstrap_closed` y `4` para resultado UNKNOWN; UNKNOWN no autoriza retry (`InternalOwnerConsole.cs:23-28,122-137`).
  No borrar Staff, sustituir hashes por SQL, crear otro Owner por bootstrap ni cambiar de base para saltar el cierre.
  Conservar la base y elevar a Jason un procedimiento nuevo, revisado y autorizado. Un backup con los mismos accesos perdidos no resuelve ese caso.

Estas notas documentan comportamiento de código; no prueban un reset real ni modifican identidades.
La protección de último Owner no es una recuperación: `UpdateStaff` rechaza deshabilitar/degradar el último habilitado (`:89-100`).

## Efectos, rollback y autorización que falta

Efectos materiales propuestos: dos bases sintéticas nuevas, un backup nuevo, archivos SQL propios, datos sintéticos y un proceso API propio.
El ensayo completo puede necesitar identidades de aplicación sintéticas y un usuario/grant mínimo **solo en las bases nuevas** para el login Windows existente.
Eso sigue siendo una mutación y no está autorizado por esta preparación.

Rollback propuesto: detener normalmente solo el PID API creado por la corrida, comprobando PID, creación e identidad.
Conservar backup/evidencia hasta revisar resultados.
Para borrar las dos bases, exigir creación confirmada, ausencia en inventario inicial, misma identidad de base y autorización de limpieza explícita.
El helper existente `drop <nombre>` usa `SINGLE_USER WITH ROLLBACK IMMEDIATE` y confirma `existsAfter=false` (`Program.cs:137-151`).
No invocarlo sobre recursos ajenos o de propiedad incierta.
Eliminar `.bak` propio solo con ruta absoluta bajo raíz aprobada, hash/propiedad comprobados y permiso; no elevar ni cambiar ACL para borrarlo.
Nunca tocar `SaviaInternalTest_20261031`, `SaviaInternalTest_20261031_RestoreProof` ni archivos históricos.
Si la propiedad o el resultado son UNKNOWN, preservar y entregar un handoff concreto; no prometer limpieza realizada.

Falta autorización nueva para: diagnóstico SQL de preflight; creación/migración/fixture de las bases nombradas; backup/restore/CHECKDB; API nueva limitada con TLS existente; y limpieza exacta propia.
Cualquier grant o cambio de identidad que resulte necesario debe figurar como efecto separado.
No hay autorización en este lote para ejecutarlos, ni para merge, despliegue o datos reales.

## Bloqueos reales y cierre

| Bloqueo | Evidencia / causa | Intento y resultado | Próxima acción / dueño | Comprobación de cierre |
| --- | --- | --- | --- | --- |
| Alcance runtime consumido / inexistente para C9 | `docs/DATABASE.md:47-56`; lote actual es solo preparación. | Solo inspección; no corrección runtime porque falta autorización explícita. | Primary prepara permiso acotado; Jason decide. | Autorización nueva identifica host, nombres, efectos y límites. |
| Rutas y permisos efectivos desconocidos | Histórico obtiene SERVERPROPERTY en runtime; `.bak` JSON solo expone basename. No se consultó SQL hoy. | Se inspeccionaron fuentes; no se adivinaron carpetas ni se ejecutó preflight. | Ejecutor autorizado obtiene raíces, nombres lógicos, identidad/SID y colisiones. | Readback privado fija todos los campos de la tabla y cero recursos ajenos afectados. |
| RTO servicio requiere API limitada/TLS concretos | Identidad histórica existe; `create` no aprovisiona su acceso a bases nuevas. TLS/puerto actuales desconocidos. | No se cambió seguridad ni se arrancó API. | Primary revisa identidad y TLS existentes; Jason autoriza efectos adicionales si aparecen. | API propia opera en la restaurada sin privilegios SQL elevados ni cambios ocultos. |
| No hay runner Windows C9 completo | Runner C5 es POSIX; release fija rutas Linux; helper no ofrece restore/timing. | Se identificaron comandos reutilizables y la extensión mínima; no se inventaron flags ni se implementó código fuera de alcance. | Dueño C9 prepara secuencia Windows propia tras fijar campos; reutiliza driver C6 aceptado. | Corrida única entrega backup/VERIFYONLY/restore, oráculos, tiempos y retirada verificables. |
| Último Owner perdido | Bootstrap cierra ante cualquier Staff; reset exige otro Owner vigente. | Revisión del código y referencia del borrador; ningún intento de bypass. | Jason define procedimiento nuevo solo si necesita ese caso; no bloquea documentar el límite actual. | Ruta documental distingue recuperación por otro Owner y ausencia de recuperación del último. |

No se intentó corregir esos bloqueos operativos porque el alcance prohíbe SQL, runtime y seguridad.
La ausencia de un SDK no se mantiene como bloqueo: el SDK aislado ya existe; PATH conserva .NET 8.
Dos fallos de lectura de codificación fueron del instrumento, no del producto: Git se leyó como UTF-8 explícito; el README histórico no UTF-8 se dejó fuera usando CURRENT y pruebas directas equivalentes.
No se reintentó ningún one-shot.

## Verificación de esta entrega

Lecturas de blobs Git fijados y archivos históricos indicados; metadatos de herramientas y host.
**0 consultas SQL, 0 cambios de servicio, 0 Docker, 0 API arrancadas, 0 tests ejecutados, 0 commits, 0 push, 0 mensajes externos.**
Solo se escriben este informe y el manifiesto seguro de fuentes en la carpeta asignada.

Lección aplicada: una restauración “PASS” con cero ventas prueba una copia, no recuperación del negocio.
La corrección mínima del plan exige una venta confirmada, oráculos independientes y recuperación del mismo recibo antes de declarar RTO servicio.
No se modificó memoria ni reglas globales.

Siguiente acción recomendada: el primary completa los campos privados del preflight bajo permiso de diagnóstico nuevo y presenta un único alcance revisable a Jason.
C9 permanece pendiente hasta que una corrida autorizada aporte la evidencia restante.
