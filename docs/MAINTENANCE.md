# Mantenimiento por agente

Empieza por [AGENT-START](AGENT-START.md), las instrucciones vigentes y el SHA asignado.
Lee el [estado](PROJECT-STATUS.md) y verifica `git status --short` antes de editar.
Trabaja en una rama con rutas asignadas y conserva cambios ajenos.
Ejecuta `python tools/doctor.py --quick` para el diagnóstico inicial.
Ejecuta `python tools/doctor.py` para todas las comprobaciones offline disponibles.
Usa `python tools/doctor.py --json` para obtener `checks`, `summary` y `exit_code`.
Cada FAIL indica el archivo que debes leer después.
El proceso devuelve 1 si existe un FAIL y 0 si no existe ninguno.
Un SKIPPED no prueba comportamiento y puede coexistir con exit 0.
El doctor separa las etapas de `tests/check.py` para continuar cuando falta una dependencia.
Quick omite build reproducible, medios y .NET, e informa cada omisión.
El doctor no instala dependencias ni modifica archivos versionados.
Los tests crean fixtures temporales y .NET puede escribir salidas ignoradas de build.
.NET requiere assets de restore existentes, usa `--no-restore` y excluye `Category=SqlServer`.
Los recorridos de navegador, SQL, Docker y servicios externos quedan fuera del doctor.
La suite de adapters incluye HTTP local y se omite bajo el contrato sin red.
DOM y transportes simulados no prueban navegador real ni persistencia SQL.

## Reparar un bug

Fija el resultado esperado y reproduce el fallo con una prueba roja antes de cambiar comportamiento.
Comprueba que falla una aserción del producto y no un import, build o dependencia ausente.
Aplica la corrección mínima y verifica la prueba verde y las regresiones afectadas.
Sigue el [pipeline de bugs](bug-pipeline/README.md) para conservar las revisiones roja y verde cuando tengas autoridad de commit.
Ejecuta `python tools/bugproof/prove.py --base <sha-base> --head <sha-fix>` para comparar ambas revisiones.
El archivo de prueba cambiado debe fallar en base y pasar en head.
Las pruebas SQL omitidas no cuentan como bug-proof.
El [drill E2](../tests/maintenance-drill/README.md) queda preparado para un agente futuro.

## Fuentes por subsistema

Consulta [CODE-MAP](CODE-MAP.md) para localizar implementación, contratos y pruebas.
La tienda vive en `src/` y `build-inputs/static/`; `prepare.py` genera `dist/`.
La UI staff vive en `dev/savia-staff-ui/`.
La API, seguridad, caja, directorio y compras viven en `backend/src/Martha.Store.Api/Internal/`.
El CRM usa Directory; confirma los contratos vigentes antes de asumir identidad por email.
Los contratos del programa estarán en [CONTRACTS](program-20261111/CONTRACTS.md); su creación pertenece a WP-S y puede estar pendiente.
Las pruebas backend viven en `backend/tests/`; las del sitio y bug-proof viven en `tests/`.
El ledger vive en `docs/pipeline/ledger.json` y la sincronización vive en `tools/progress.py`.

## Commit y sincronización

Sigue [AUTO-SYNC](AUTO-SYNC.md) y el alcance explícito de la tarea.
Un worker sin permiso de commit deja rutas explícitas staged para integración por el primary.
Antes de un commit autorizado, documenta resultado, comando, evidencia, límites y siguiente acción en el documento del área.
Revisa datos sensibles y añade solo rutas autorizadas al índice.
Los hooks generan el recibo y publican en `Tony`; nunca los omitas.
Solo `SYNCED` y un SHA remoto coincidente prueban sincronización.
Si falla la publicación autorizada, corrige la causa y ejecuta `python tools/progress.py publish`.
No uses force-push.
Sin autorización de Jason, no despliegues, ejecutes SQL en producción, fusiones a `main`, manipules secretos ni arranques Docker.
Los permisos históricos de runtime no autorizan una nueva ejecución.

## Fallos documentados

| Síntoma real | Acción | Fuente |
| --- | --- | --- |
| `WinError 1314` al crear symlinks | Registra fallo de entorno; usa Linux autorizado sin relajar guardas ni permisos. | [Regresión de catálogo](CATALOG-REGRESSION-FIX.md) |
| Application Control `0x800711C7` al cargar tests .NET | Registra cero casos ejecutados; pide resolución autorizada y conserva la evidencia CI por SHA. | [Estado](PROJECT-STATUS.md) |
| Commit local sin publicación remota | Revisa el resultado del hook y la divergencia; exige `SYNCED` y SHA coincidente. | [AUTO-SYNC](AUTO-SYNC.md#fallo-o-divergencia) |
| Conversión inválida de `DB_ID()` en SQL Server 2025 | Lee la corrección `CONVERT(int, DB_ID())`; no ejecutes SQL para diagnosticar sin alcance autorizado. | [Runtime Owner](owner-recovery-20261107/runtime-20261110.md) |

## Evidencia WP-E

Tarea: `wp-e-maintenance-doctor-20261111`, base `de30ccfa5f999e37b14fcd5ee9dbf4566e373154`.
Host: `SUAZO-PC`, Windows, T3 Code/Codex, modelo `gpt-6.1-sol`, razonamiento `high`.
`python tests/test_doctor.py`: exit 0, 10 pruebas PASS, incluidos JSON, estados, códigos y exclusiones de runtime.
`python tools/doctor.py --quick`: exit 1, 50 PASS, 2 FAIL, 23 SKIPPED ([output completo](../tests/maintenance-drill/doctor-evidence/quick.txt)).
`python tools/doctor.py`: exit 1, 53 PASS, 2 FAIL, 20 SKIPPED ([output completo](../tests/maintenance-drill/doctor-evidence/full.txt)).
Ambos runs fallaron únicamente en `tests/asset-audit.py` y `tests/catalog-staging.py`.
El diagnóstico directo de esos comandos devolvió exit 1 con tres y dos errores `WinError 1314`, respectivamente.
La causa observada es la denegación de creación de symlinks en Windows, ya documentada arriba.
No se corrigieron permisos ni suites ajenas: esas acciones están fuera del alcance WP-E.
El primary debe comprobar esos casos en Linux autorizado; cierre significa ambas suites verdes sin relajar guardas.
Faltan `jsdom` y assets locales de restore .NET; las instalaciones requieren otra autorización de red.
El primary puede preparar esas dependencias con autoridad y volver a ejecutar el doctor; cierre significa eliminar esas omisiones.
No se ejecutaron SQL, Docker, red, navegador real, restore, instalación, commit, push ni el agente E2.
Linux y la capacidad de mantenimiento por un Opus nuevo siguen sin prueba runtime.
Las corridas preliminares se interrumpieron durante la revisión del inventario, antes de alcanzar los checks de navegador o HTTP.
Lección aplicada: clasificar efectos antes de descubrir ejecutables por extensión; navegador con escritura y HTTP local tienen exclusiones explícitas verificadas por test.
E1 tiene implementación y evidencia local; este entorno no queda verde.
E2 tiene preparación; la ejecución del agente fresco sigue NOT RUN.
Los únicos archivos versionados preexistentes modificados son la línea de enlace de AGENT-START y sus separadores.
La entrega queda staged para revisión del primary, sin publicación remota.
