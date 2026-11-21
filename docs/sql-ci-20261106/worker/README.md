# SQL CI aislado: entrega del worker

Estado: **RETURNED / NOT ACCEPTED**. El primary conserva la aceptación independiente.

Una sola corrida manual: [42163110947, intento 1](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/42163110947).
Evento `workflow_dispatch`, rama `Tony`, SHA `708bdbbf2eff568d571b7593ed40d2422414c671`.
Creada `2026-11-06T04:32:28Z`; finalizada `2026-11-06T04:34:38Z`; conclusión `success`.

Host `SUAZO-PC`, proveedor `codex`, modelo `gpt-6.1-sol`, razonamiento solicitado y efectivo `high` según runtime T3.
Checkout aislado: `C:/Users/Jason/.t3/worktrees/github/t3-82ef9694`.
No se modificó el checkout canónico ni su índice.

## Resultados verificados

| Capa | Casos PASS | Fallos / omitidos |
| --- | ---: | --- |
| Backend completo | 602/602 | 0/0 observados |
| Subconjunto SQL, mapeado desde atributos de fuentes | 76/76 | 0/0 |
| Staff jsdom | 124/124 | 0/0 |
| Chrome existente, HTTP simulado | 50/50 | 0 fallos |
| Chrome abastecimiento, HTTP simulado | 8/8 | 0 fallos |

Los 76 casos SQL están incluidos en los 602; no se suman.
Distribución: `SqlServerFact`21, `InternalCommerceSqlFact`30, `InternalSecuritySqlFact`10,
`InternalJudgeHttpSqlFact`8, `InternalSupplySqlFact`7.
Cada método SQL del mapeo tiene un outcome presente y PASS.
El mínimo configurado es 601; el resultado real es 602.
El saneador rechaza outcomes distintos de Passed y duplicados.
Los mensajes negativos de sus pruebas unitarias son controles esperados; su step terminó correctamente.

Estos métodos tienen un caso PASS cada uno:

- `InternalSupplyUiTests.Supply_resource_is_embedded_protected_and_serves_the_source_bytes`.
- `PrivatePilotReleaseTests.Real_migration_reapply_throwaway_down_up_and_actual_backup_restore`.
- `PrivatePilotReleaseTests.Frozen_fixture_survives_controlled_owned_container_stop_start`.

El test de release ejecuta migraciones, segundo Up, Down/Up desechable, BACKUP con CHECKSUM,
RESTORE VERIFYONLY y RESTORE real; compara negocio, esquema y rechazos SQL.
El workflow detiene e inicia el contenedor antes del test de persistencia.
El test comprueba esquema, cuatro filas esperadas y rechazos de restricciones tras ese reinicio.
La evidencia pública conserva outcomes, no los datos privados intermedios de esas fixtures.

SQL usó `mcr.microsoft.com/mssql/server@sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718`.
El log confirma ese digest.
El step SQL comprobó major version16 y edición Developer, con exit0.
La fuente identifica la imagen como `16.0.4305.5`; el log no emite el patch de SERVERPROPERTY.
No se afirma una lectura runtime independiente de ese patch.
Se observaron los opt-ins `SAVIA_INTERNAL_SQL_TESTS_AUTHORIZED=1` y `SAVIA_INTERNAL_HTTP_SQL_TESTS_AUTHORIZED=1`.
Los outcomes reales confirman ejecución de los casos sujetos a esos opt-ins.

Cleanup terminó con exit0.
El mensaje real, separado del comando echo, aparece a `2026-11-06T04:34:35.8745839Z`:
`PASS: disposable SQL container absence verified.`

## Comandos y evidencia

Preflight: `python C:/Users/Jason/AI-OS/bin/agent-awareness.py --workspace "C:/Users/Jason/.t3/worktrees/github/t3-82ef9694"`.
`suazo-axi doctor --format json` terminó con exit0; GitHub estaba ready.
Inmediatamente antes del dispatch, `git rev-parse HEAD` y `git ls-remote origin refs/heads/Tony`
coincidieron con el SHA autorizado; ambos comandos terminaron con exit0.

Única mutación remota, iniciada `2026-11-06T04:32:22.9596165Z`, exit0:

```powershell
npx --no-install gh-axi workflow run savia.yml --ref Tony --repo=Suazo-AI/Martha-Silva-Store
```

Lecturas y descargas, exit0:

```powershell
npx --no-install gh-axi run list --workflow savia.yml --branch Tony --event workflow_dispatch --limit 5 --repo=Suazo-AI/Martha-Silva-Store
npx --no-install gh-axi run view 42163110947 --repo=Suazo-AI/Martha-Silva-Store
npx --no-install gh-axi run view 42163110947 --log --repo=Suazo-AI/Martha-Silva-Store
npx --no-install gh-axi run download 42163110947 --name savia-backend-outcomes-42163110947-1 --dir C:/Users/Jason/MARTHA-SILVA/test-runs/sql-ci-20261106/42163110947/backend-original --repo=Suazo-AI/Martha-Silva-Store
npx --no-install gh-axi run download 42163110947 --name savia-browser-evidence-42163110947-1 --dir C:/Users/Jason/MARTHA-SILVA/test-runs/sql-ci-20261106/42163110947/browser-original --repo=Suazo-AI/Martha-Silva-Store
```

Metadatos seleccionados: `gh-axi api repos/Suazo-AI/Martha-Silva-Store/actions/runs/42163110947`,
y sus rutas `/jobs` y `/artifacts`, con `--jq` para excluir actores y datos del runner.
Para JSON completo se usó `--full --jq '<selección> | tojson | @base64'` y decodificación local.

[RESULT.json](RESULT.json) registra jobs, steps, timestamps, conclusiones, comandos, límites y hashes.
[outcomes.json](outcomes.json) es un derivado saneado con métodos, conteos, estados y extractos permitidos.
Su SHA256 es `55e473195951046a82f3d4fec232d1a147170fb392aa195baaec2ba8b788729b`.
Los hashes de originales y fuentes Git/working bytes están en RESULT.json.
Los digests de artefactos de GitHub identifican el archivo remoto comprimido; no equivalen al hash del JSON extraído.

Los originales descargados permanecen intactos en el archivo privado:
`C:/Users/Jason/MARTHA-SILVA/test-runs/sql-ci-20261106/42163110947/`.
El log completo está en `workflow-raw.log`; no se copió al repositorio.
Los TRX y logs internos de dotnet fueron eliminados por el workflow y no están disponibles como artefactos.
Se verificaron outcomes individuales del artefacto saneado y la fuente exacta del saneador.

Dos errores de colección quedaron resueltos sin repetir pruebas:
la captura inicial de jobs estaba truncada; `--full` recuperó JSON completo.
Un regex del generador documental falló por conversión Unicode del shell; patrones ASCII resolvieron la captura.
Lección aplicada: usar `--full` y patrones ASCII en estas capturas mecánicas.

## Límites y siguiente acción

No acredita navegador→API→SQL combinado, C9 local RTO/RPO, C2/C10 operativo ni producción.
No hubo implementación, stage, commit, push, PR, merge, deploy, SQL local, Docker local ni cambios TLS/certificados.
No hubo rerun, segundo dispatch ni ejecución de `golden-path.yml`.
Solo se crean los tres archivos de este directorio; la integración corresponde al primary.
Coste de Actions y tokens del modelo: desconocidos, no expuestos.
La duración del run fue 130 segundos; las duraciones de jobs constan en RESULT.json.
No quedan bloqueos técnicos de colección.
Siguiente dueño: primary T3 Codex; verificar hashes, bindings y outcomes antes de aceptar e integrar.
