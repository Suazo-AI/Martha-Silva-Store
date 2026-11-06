# Validación local: RETURNED PARTIAL

Base `0f786c3f2a747115b5cae90957b17a959f357298` más tres fuentes importadas e inmutables.
Host `SUAZO-PC`; T3 Code / Codex / `gpt-6.1-sol`; high solicitado y efectivo según runtime y agent-awareness.
Worktree `C:/Users/Jason/.t3/worktrees/github/t3-1837cee6`. Tokens y costo desconocidos.
Sin stage, commit, push, dispatch ni deploy. Aceptación pendiente del primary; producción no acreditada.

## Ejecutado

- Base y **11/11 bindings LF** verificados antes y después: source-bindings.json.
- SDK efectivo **10.0.402**, restore bloqueado exit **0**.
- Una compilación Release durante fingerprint, exit **0**.
- Fingerprint **9 PASS / 0 FAIL / 0 SKIP**, exit **0**, pared **42.9621796 s**, incluyendo compilación.
- Discovery **631 casos / 274 métodos**, exit **0**.
- Un preflight SQL estricto: exit **1**, pared **0.3657018 s**.
- Error: `Microsoft ODBC Driver 18 for SQL Server : SSL Provider: The certificate chain was issued by an authority that is not trusted.` Luego `Client unable to establish connection.`
- Cero intentos del bloque de seis SQL. Sin conexión exitosa, consultas ejecutadas ni bases creadas. Inventario SQL no obtenido.

No repetí offline amplio: los **552 PASS / 58 skips** del worker anterior son históricos.
Los nueve actuales prueban metadata y diccionarios; no serialización real de filas SQL.
Raw TRX/logs quedan privados en `C:/Users/Jason/MARTHA-SILVA/test-runs/local-validation-20261106/worker-1837cee6`.

## Comandos ejecutados

PowerShell desde este worktree:

```powershell
$sdk='C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/dotnet.exe'
$private='C:/Users/Jason/MARTHA-SILVA/test-runs/local-validation-20261106/worker-1837cee6'
& $sdk --version
& $sdk restore backend/tests/Martha.Store.Api.Tests --locked-mode
& $sdk test backend/tests/Martha.Store.Api.Tests --no-restore --configuration Release --filter FullyQualifiedName~InternalAcceptanceFingerprintTests --logger 'trx;LogFileName=fingerprint.trx' --results-directory $private
& $sdk test backend/tests/Martha.Store.Api.Tests --no-build --no-restore --configuration Release --list-tests
```

Único preflight ejecutado; no repetir con este permiso consumido:

```powershell
& 'C:/Program Files/Microsoft SQL Server/Client SDK/ODBC/180/Tools/Binn/SQLCMD.EXE' -S 'lpc:SUAZO-PC\SAVIATEST' -E -N -d master -l 5 -t 5 -b -Q 'SET NOCOUNT ON; SELECT name FROM sys.databases ORDER BY name;'
```

`-E`: Windows integrado. `lpc:`: shared memory explícito. `-N`: cifrado requerido.
Sin `-C`: TrustServerCertificate false. Conexión y consulta limitadas a 5 s.
El cliente es ODBC18, no el SqlClient del test. Falló antes de habilitar el bloque SQL.

## Particiones y cobertura

PARTITIONS.json conserva los 274 métodos, multiplicidades, atributos, filtros y comandos exactos.
Backend disjunto: **A552 + C77 + E2 = 631**.
C1 son los seis InternalAcceptanceHttpSqlTests; los demás C están separados por dominio/clase.
A incluye los nueve fingerprint. Excluir su TRX diagnóstico del agregado final para evitar duplicados.
B conserva DOM y Chrome con HTTP simulado. D permanece combinado Chrome→HTTPS API→SQL.
E exige migraciones/backup/restore y reinicio de un runtime desechable exclusivo.

No se promete aceleración: solo se midió fingerprint.
Máximo dos procesos pesados; una compilación; SQL serial hasta verificar limpieza e inventario.
Los demás dominios C son particiones preparadas para ejecución posterior, no autorizadas por este intento de seis casos.

Receta A, **NOT RUN**, en un proceso PowerShell hijo dedicado:

```powershell
foreach($key in @('MARTHA_TEST_SQL_CONNECTION','MARTHA_INTERNAL_TEST_SQL_CONNECTION','SAVIA_INTERNAL_TEST_SQL_CONNECTION','SAVIA_INTERNAL_SQL_TESTS_AUTHORIZED','SAVIA_INTERNAL_HTTP_SQL_TESTS_AUTHORIZED')) { Remove-Item "Env:$key" -ErrorAction SilentlyContinue }
$env:SAVIA_PILOT_EVIDENCE="$private/offline-scripts"
New-Item -ItemType Directory -Force $env:SAVIA_PILOT_EVIDENCE | Out-Null
$inventory=Get-Content docs/local-validation-20261106/PARTITIONS.json -Raw | ConvertFrom-Json
$part=$inventory.partitions | Where-Object id -eq A
& $sdk test backend/tests/Martha.Store.Api.Tests --no-build --no-restore -c Release --filter $part.filter --logger 'trx;LogFileName=A.trx' --results-directory "$private/results"
```

Para C, usar los filtros JSON solo después de otro preflight específicamente autorizado.
Configurar conexiones privadas y flags únicamente en el proceso hijo.
C1 crea `SaviaInternalTest_Commerce_<GUID nuevo>`, aplica migraciones reales y usa TestServer sin puerto.
La fixture guarda y elimina su nombre exacto en DisposeAsync. Nunca eliminar por prefijo.
Si falla cleanup, conservar diagnóstico privado y devolver el nombre exacto al primary; no reintentar.
Exigir seis ejecutados/PASS y cero skips, inventario privado anterior/posterior, todos los previos presentes y cero DB propias restantes.

VSTest trunca algunos argumentos de teoría y repite etiquetas visibles; el JSON registra el número de colisiones.
Se conservan todas las ocurrencias y multiplicidades por método. No se inventan identidades desde etiquetas truncadas.
La correspondencia individual de argumentos exige inspección privada del TRX; no está probada aquí.
La fuente congelada y los IDs únicos TRX son necesarios para la aceptación completa.
No hay discovery runtime exhaustiva de todas las pruebas Python/Node del repositorio en esta tarea.

Después de ejecutar todas las particiones, juntar únicamente TRX finales A/C/E en una carpeta privada limpia:

```powershell
python backend/tests/verify_full_suite.py --min-tests 631 "$private/results"
```

Ese mínimo no basta: comprobar también igualdad exacta del multiconjunto de métodos:

```python
import collections,json,pathlib,xml.etree.ElementTree as E
p=json.loads(pathlib.Path('docs/local-validation-20261106/PARTITIONS.json').read_text())
expected=collections.Counter({r['method']:r['cases'] for r in p['backend_methods']})
actual=collections.Counter(); ids=set()
ns={'t':'http://microsoft.com/schemas/VisualStudio/TeamTest/2010'}
for f in pathlib.Path('C:/Users/Jason/MARTHA-SILVA/test-runs/local-validation-20261106/worker-1837cee6/results').glob('*.trx'):
    for r in E.parse(f).findall('.//t:UnitTestResult',ns):
        assert r.get('testId') not in ids
        ids.add(r.get('testId'))
        assert r.get('outcome')=='Passed'
        actual[r.get('testName').split('(',1)[0]]+=1
assert actual==expected, {'missing':expected-actual,'extra':actual-expected}
```

Comandos adicionales existentes de workflows, sin ejecución aquí:

```powershell
python -m unittest discover -s backend/tests -p test_verify_sql_results.py
python -m unittest discover -s backend/tests -p test_verify_full_suite.py
python tests/test_golden_path_safety.py
python tests/test_golden_path_browser_safety.py
python tests/test_golden_path_stock_exception.py
```

## B: reutilización histórica

docs/stock-exception-20261106/PREPARATION-ACCEPTANCE.json registra staff152/152 y Chrome50/50+supply8/8 con HTTP simulado.
Los siete bindings frontend/browser de su CANDIDATE.json coinciden actualmente; hashes y comandos están en PARTITIONS.json.
No se atribuye esa ejecución a este worker. B+C no acredita D.

## Bloqueos y siguiente acción

C: fallo TLS actual confirmado. Dueño: primary/Jason.
Intento: una conexión estricta; denegada. No se corrigió porque modificar certificados/seguridad está excluido.
Siguiente acción: preparar investigación de cadena con autorización específica o aprobar runtime Linux local desechable.
Cierre: nueva conexión estricta autorizada, seis PASS/cero skips y prueba privada de preservación/limpieza.

D: golden_path.py importa fcntl/pty/termios/tty y usa /proc para limpieza Linux.
E: PrivatePilotReleaseTests requiere /var/opt/mssql/data y un reinicio exclusivo de su contenedor.
Intento: lectura directa del código; ambos **NOT RUN**. Dueño: primary/Jason.
No se adaptó el harness ni se inició un servicio porque están excluidos.

Ruta recomendada: Docker Desktop ya instalado, runner Linux y SQL desechable con fuente exacta y salidas privadas.
Docker parado y WSL solo docker-desktop son hechos suministrados por primary; no se revalidaron arrancándolos.
Primero autorizar iniciar Docker Desktop y revisar imágenes/dependencias existentes; no instalar otra distro por defecto.
Prerequisitos: SDK10.0.402, Python Linux, Node24, OpenSSL, Chrome, Playwright1.63.0 y ffmpeg; restores bloqueados.
Usar SQL2022 Developer fijado por digest en savia.yml; puerto loopback disponible; 4GB/2CPU para SQL según workflow.
La conexión SQL debe satisfacer la política estricta del runtime aprobado; no copiar TrustServerCertificate=true de CI.
La identidad integrada Windows no se traslada automáticamente al contenedor.
D usa HTTPS efímero fijado por SPKI sin cambiar almacenes del host.
No reutilizar DB piloto ni reiniciar SAVIATEST.

E debe ejecutar primero Real_migration_reapply_throwaway_down_up_and_actual_backup_restore.
Después leer source DB del release-*.json privado y validar `^SaviaInternalTest_Pilot_[a-f0-9]{32}$`.
Reiniciar exclusivamente el contenedor propio y verificar readiness acotada.
Solo entonces ejecutar Frozen_fixture_survives_controlled_owned_container_stop_start con SAVIA_PILOT_PERSIST_DATABASE igual a esa source DB.
Los dos casos E no se ejecutan juntos antes del reinicio; ver comandos secuenciales en JSON.
Rollback: retirar solo contenedores/volúmenes/perfiles propios y verificar ausencia; preservar recursos previos.
Cierre D: checkpoints combinados y evidencia saneada. Cierre E: restore/reinicio real y ausencia de recursos propios.
Preparación no equivale a runtime proof. B, C, D y E conservan sus límites separados.

## Entrega

RESULT.json conserva comandos, resultados, bloqueos, dueños y duraciones.
artifact-bindings.json vincula documentos; el manifiesto final privado incluye también ese manifiesto.
Lección aplicada: Category!=SqlServer deja SQL custom como skips; particionar por atributos reales evita ocultarlos.
No se modificó código productivo, dependencias, workflows, ledger ni criterios de aceptación.
La revisión automática rechazó una escritura de documentación que incluía ejemplos de reinicio; se usó el editor de parches.
Ningún reinicio fue ejecutado.
