# Operación local de SAVIA en Masaya

El respaldo y la restauración se probaron en bases temporales el 12 de noviembre de 2026.
La prueba terminó con `restore-test PASS` y conteos iguales a los del respaldo.
No se consultó ni modificó `SAVIA_DEV_pilot` durante esta entrega.
No se usó el puerto 5080 ni se instalaron tareas programadas.

## Inicio diario

Encienda la computadora e ingrese con el usuario de Windows que usa SAVIA.
Cuando el coordinador instale las tareas, `SAVIA Piloto` iniciará Docker Desktop si hace falta.
La tarea esperará hasta cinco minutos para que `savia-sqlserver-dev` indique que está saludable.
Después ejecutará `python savia/tools/pilot.py up --no-provision` desde la raíz del repositorio.
Abra <http://127.0.0.1:5080/> en esta misma computadora.
Use su usuario y contraseña de muestra.
El inicio automático requiere que el coordinador haya preparado antes la base y las credenciales del piloto.
La disponibilidad de `--no-provision` depende del trabajo del otro responsable.

## Si la página no abre

Espere hasta cinco minutos después de ingresar a Windows.
Compruebe que Docker Desktop esté abierto y que el contenedor existente esté saludable.
No cree otro contenedor ni reinicie la base para resolver un problema de página.
Revise `savia/.out/pilot/autostart.log` y `savia/.out/pilot/api.log`.
Consulte el estado de las tareas con el siguiente comando desde la raíz del repositorio.

```powershell
powershell -NoProfile -File savia/tools/pilot_autostart.ps1 -Status
```

Si el registro muestra un error de inicio o contraseña, informe al coordinador y conserve el registro localmente.
No publique contraseñas, registros completos ni archivos de respaldo.

## Respaldos

La tarea `SAVIA Respaldo` se programa para cada ingreso a Windows y para las 20:00.
La ejecución diaria requiere una sesión del usuario y una computadora encendida.
El programador permite ejecutar una tarea pendiente cuando vuelva a estar disponible.
Esto no garantiza un respaldo diario si Windows, Docker o SQL Server no están disponibles.
Un error queda en el registro y produce un código de salida distinto de cero.
Revise periódicamente la fecha del último respaldo válido.
Los siguientes comandos crean una copia manual y muestran las copias disponibles.

```powershell
python savia/tools/pilot_backup.py backup
python savia/tools/pilot_backup.py list
```

SQL Server escribe primero en `/var/opt/mssql/data/backups` dentro del contenedor.
La herramienta ejecuta `BACKUP DATABASE WITH INIT, FORMAT, CHECKSUM` y `RESTORE VERIFYONLY WITH CHECKSUM`.
Luego copia el archivo al directorio `savia/.out/pilot/backups/` de Windows.
Cada respaldo tiene fecha UTC, un archivo `.bak`, un archivo `.sha256` y un archivo `.json`.
SHA-256 es una huella que permite detectar cambios en los bytes del archivo.
El JSON guarda la huella y los conteos de ventas, movimientos de inventario y entradas de caja.
Los conteos salen de una restauración temporal del propio respaldo, sin depender del estado posterior de la fuente.
La herramienta conserva los catorce respaldos completos más recientes entre todas las bases de esa carpeta.
La retención elimina solamente archivos creados por esta herramienta y sus dos archivos acompañantes dentro de esa carpeta del equipo.
La retención no elimina las copias del contenedor.
La herramienta exige que `git check-ignore` confirme que la carpeta está excluida de Git.
Estos archivos contienen datos de la base y deben conservarse fuera del repositorio publicado.
Conserve juntos los tres archivos al copiar un respaldo a un dispositivo externo autorizado.
Esta entrega no configura copias externas ni realiza transferencias de datos.

## Verificar y restaurar

Sustituya `RUTA.bak` por la ruta del respaldo elegido.
El comando de verificación exige los dos archivos acompañantes y valida tanto la huella como el respaldo en SQL Server.

```powershell
python savia/tools/pilot_backup.py verify RUTA.bak
python savia/tools/pilot_backup.py restore-test RUTA.bak
```

La prueba restaura exclusivamente en una base nueva llamada `SAVIA_DEV_restoretest`.
Si esa base ya existe, la herramienta falla sin sustituirla ni eliminarla.
La prueba ejecuta `DBCC CHECKDB WITH NO_INFOMSGS` para comprobar la integridad de la base.
También ejecuta `audit.usp_CheckConservation @Throw=1` para comprobar las reglas de conservación definidas en SQL.
Compara los tres conteos con el JSON y elimina únicamente la base temporal creada por esa ejecución.
Un error de limpieza también hace fallar el comando.

La restauración real reemplaza datos y corresponde al coordinador cuando se autorice esa recuperación.
Cierre el piloto y suspenda las tareas antes de una recuperación real para evitar nuevas escrituras.
El siguiente comando es una referencia de operación y no se ejecutó contra el piloto en esta entrega.

```powershell
python savia/tools/pilot_backup.py restore RUTA.bak --db SAVIA_DEV_pilot --yes-replace
```

La herramienta rechaza una restauración sin `--yes-replace` o con un nombre ajeno a la regla de `saviadb.check_name()`.
Si la base destino ya existe, toma y verifica primero un respaldo de seguridad de esa base.
Si el destino no existe, no hay datos previos que respaldar.
La restauración usa los archivos cargados al contenedor y rutas de datos nuevas para el nombre destino.
Después comprueba integridad, conservación y conteos.
No aplica migraciones ni cambia reglas comerciales.
Una restauración interrumpida puede requerir intervención del coordinador y el respaldo de seguridad.
Un código de salida cero significa que terminaron todos los pasos del comando.

## Corte de energía y pérdida del equipo

Un corte de energía detiene la página, el proceso de la API y Docker.
Al volver la energía, ingrese a Windows para activar las tareas que haya instalado el coordinador.
SQL Server recupera las transacciones del almacenamiento disponible al iniciar.
Una operación interrumpida requiere comprobar su resultado antes de repetirla.
Esta entrega no simuló cortes eléctricos ni garantiza la integridad del disco.
Si la computadora muere y existe una copia válida fuera de ella, se pierde el trabajo posterior al último respaldo recuperable.
Si todas las copias permanecen en el mismo disco que falla, puede perderse toda la base.
El respaldo del contenedor y la copia de Windows no protegen por sí solos contra la pérdida de ese disco.

## Instalación de las tareas por el coordinador

Los siguientes comandos quedan preparados para el coordinador y no se ejecutaron en esta entrega.

```powershell
powershell -NoProfile -File savia/tools/pilot_autostart.ps1 -Install
powershell -NoProfile -File savia/tools/pilot_autostart.ps1 -Status
powershell -NoProfile -File savia/tools/pilot_autostart.ps1 -Uninstall
```

Las tareas usan el usuario actual, ingreso interactivo y nivel limitado, sin contraseña almacenada.
La instalación fija la ruta del Python local encontrado para que el inicio de sesión use el mismo ejecutable.
La herramienta rechaza el reemplazo o retiro de una tarea homónima que pertenezca a otro usuario.
No eleva permisos ni crea contenedores.
Una política de Windows puede impedir registrar tareas de usuario y requiere revisión del coordinador.
No se garantiza ejecución si el usuario cierra sesión o si una política bloquea scripts.

## Evidencia reproducible

La ejecución final de `python -u savia/db/tests/ops/proof_backup.py` terminó con código 0.
La fuente se creó con `saviadb.clone("SAVIA_DEV_bkpsrc")` y las dos ventas pasaron por `test.SeedSale` y los procedimientos reales.
El siguiente bloque conserva la salida relevante de esa ejecución sin datos secretos.

```text
CLONE SAVIA_DEV_bkpsrc PASS
BACKUP PASS C:\Users\Jason\MARTHA-SILVA\github\savia\.out\pilot\backups\SAVIA_DEV_bkpsrc_20261112T222706385902Z_d511308c.bak
COUNTS {"inventory.StockMovements": 2, "sales.CashEntries": 2, "sales.Sales": 1}
SHA256 c22da27d051c6a3802045c0fed4f56f280d0bb41e0d6326040b48920af3e47b8
GIT ignored PASS
SOURCE AT BACKUP {"inventory.StockMovements": 2, "sales.CashEntries": 2, "sales.Sales": 1}
SOURCE AFTER SALE {"inventory.StockMovements": 4, "sales.CashEntries": 3, "sales.Sales": 2}
COMMAND pilot_backup.py list EXIT 0
VERIFY PASS SAVIA_DEV_bkpsrc_20261112T222706385902Z_d511308c.bak
COMMAND pilot_backup.py verify EXIT 0
EXPECTED {"inventory.StockMovements": 2, "sales.CashEntries": 2, "sales.Sales": 1}
ACTUAL   {"inventory.StockMovements": 2, "sales.CashEntries": 2, "sales.Sales": 1}
restore-test PASS; CHECKDB PASS; conservation PASS; counts MATCH; temporal eliminada
COMMAND pilot_backup.py restore-test EXIT 0
ERROR: SQL: exit 1; revise Docker y SQL Server localmente.
COMMAND pilot_backup.py restore-test EXIT 1
EXISTING restoretest PRESERVED PASS
ERROR: SHA-256 no coincide; respaldo corrupto o metadatos incorrectos.
COMMAND pilot_backup.py verify EXIT 1
ERROR: SQL: exit 1; revise Docker y SQL Server localmente.
COMMAND pilot_backup.py verify EXIT 1
COMMAND pilot_backup.py restore EXIT 1
ERROR: Refused: database name 'master' is outside SAVIA_(DEV|T|SIM)_*.
COMMAND pilot_backup.py restore EXIT 1
BACKUP PASS C:\Users\Jason\MARTHA-SILVA\github\savia\.out\pilot\backups\SAVIA_DEV_bkpsrc_20261112T222724614580Z_8e850ca6.bak
COUNTS {"inventory.StockMovements": 4, "sales.CashEntries": 3, "sales.Sales": 2}
SHA256 98842f4f1024c730cf57d7b51db4c37f4668d3e5576f57d2acd7498fe2322e21
GIT ignored PASS
SAFETY BACKUP C:\Users\Jason\MARTHA-SILVA\github\savia\.out\pilot\backups\SAVIA_DEV_bkpsrc_20261112T222724614580Z_8e850ca6.bak
RESTORE PASS SAVIA_DEV_bkpsrc
COMMAND pilot_backup.py restore EXIT 0
REAL RESTORE SAFETY BACKUP PASS; source counts MATCH
PROOF PASS
DROP SAVIA_DEV_bkpsrc PASS
```

El primer rechazo de corrupción usó la huella original y una copia con 4096 bytes invertidos.
El segundo rechazo usó esa copia con huellas recalculadas para demostrar que SQL también detecta el daño.
La copia corrupta y sus archivos acompañantes se eliminaron al terminar la prueba.
Las copias válidas de prueba permanecen solamente en las carpetas locales ignoradas y en el contenedor.
Una regresión aislada reprodujo primero un fallo al releer metadatos de una copia antigua eliminada por la retención del respaldo de seguridad.
La ejecución roja de `python savia/db/tests/ops/test_backup_safety.py` terminó con código 1 y `FileNotFoundError`.
La corrección conserva los metadatos validados antes de crear el respaldo de seguridad.
La ejecución verde del mismo comando terminó con código 0 y cinco pruebas aprobadas.
Las pruebas cubren retención de catorce copias, preservación de archivos ajenos, rechazos previos a SQL y propiedad de la base temporal.
El analizador de PowerShell devolvió `PowerShell parser PASS; 0 errors` con código 0.
El comando exacto del analizador se conserva a continuación.

```powershell
$parseTokens=$null
$parseErrors=$null
[System.Management.Automation.Language.Parser]::ParseFile((Join-Path (Get-Location) 'savia/tools/pilot_autostart.ps1'), [ref]$parseTokens, [ref]$parseErrors) | Out-Null
if ($parseErrors.Count) { $parseErrors | Format-List; exit 1 }
Write-Output 'PowerShell parser PASS; 0 errors'
exit 0
```

## Límites y siguiente acción

Este piloto usa datos de muestra en una computadora local y una sucursal.
No se hicieron llamadas externas, despliegues, instalaciones de dependencias, commits ni pushes.
No se ejecutaron `dotnet`, `check.py` ni `pilot.py`.
No se modificaron archivos existentes, migraciones ni tablas comerciales mediante borrado físico.
No se verificaron el registro de tareas, el inicio de sesión real, el horario de las 20:00, la recuperación eléctrica ni una recuperación en otra computadora.
No se afirmó una prueba de navegador ni una integración de pagos.
La siguiente acción del coordinador es revisar los archivos preparados e integrar `--no-provision` antes de instalar y probar las tareas.
