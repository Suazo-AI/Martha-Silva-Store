# FIX-PR2-DENIS-20261104

Integración canónica en `Tony`, host `SUAZO-PC`, sobre PR2
`88faa2dd0d51fc1c5089b721ba5b17c23d4d61d4`.
Responsable: Codex. Revisión independiente: `gpt-6.1-sol/high` para el importador
y `gpt-6-astra/high` para CI y el límite CLI de publicación de evidencia.

## Integración comprobada

- ZIP SHA256: `af0dd8199908ff1e0ac9b314be584597acbc664c0d7eddb4b2dde75370bace73`.
- Trece archivos: hashes base, candidato, longitud y blobs Git comprobados.
- `git apply --check --whitespace=error-all` terminó con código 0 antes de aplicar.
- `git apply --whitespace=error-all` terminó con código 0.
- Los 16 commits publicados de PR2 se incorporaron por fast-forward. No se creó un merge.
- Los 33 archivos ajenos sin seguimiento conservan su contenido. No se incluyen en este avance.
- Los siete hallazgos `TONY-*` permanecen en `review`.

Los [hashes](package-hashes.json) fijan el candidato original antes de las adiciones
de documentación y readback de retirada. El diff respecto de ese candidato agrega
el importador histórico, sus pruebas, esta evidencia y la comprobación de ausencia
del contenedor en los dos workflows SQL. El seguimiento corrige además la combinación
incompatible de flags de `gh`, con propagación de fallos. No cambia reglas de stock.

## Validación local

| Comando o interfaz | Resultado observado |
| --- | --- |
| `python -B tests/test_delivery_status.py` | 24 PASS |
| `python -B tests/test_golden_path_safety.py` | 17 PASS; funciones aisladas y dobles |
| `python -B tests/test_progress.py` | 22 PASS; Git temporal real, transporte reemplazado |
| SDK `10.0.402`: restore con `--locked-mode` y build Release sin restore | PASS para GoldenPath.Sql y backend/tests |
| SDK `10.0.402`: `dotnet test` sin SQL configurado | 599 descubiertos: 524 PASS, 75 SKIP, 0 FAIL |
| `python -B tools/export_progress.py --verify` | 15 hashes históricos conservados |
| `python -B tools/delivery_status.py --check` | PASS |
| CLI real `verify_evidence.py`, archivos sintéticos | 6/6 escenarios PASS; lectura independiente del resultado |
| Cleanup Bash de ambos workflows con Docker simulado | 8/8 escenarios PASS |

[Resultados y comandos locales](local-validation.json),
[CLI de evidencia](evidence-cli.json) y [regresión de retirada](teardown-regression.json).
Los checks restantes del frontend, estructura, sintaxis, runner y guardas históricas
se ejecutaron por separado después del bloqueo Windows; sus salidas están enumeradas.

## Bloqueos, correcciones y límites

1. El hook rechazaba la historia publicada sin recibos. El importador solo acepta
   16 SHA exactos con árbol, padres y blobs revisados. Conserva los escaneos de
   publicación. Cada commit nuevo necesita su recibo normal. Véase [AUTO-SYNC](../AUTO-SYNC.md).
2. La revisión independiente detectó que CRLF alteraba el hash del manifiesto.
   Se regeneró LF y se fijó el hash de sus bytes Git. La regresión Windows pasó.
3. Se reprodujo cleanup con código 0 cuando Docker devolvía error 42.
   El readback ahora falla ante Docker inaccesible o un contenedor restante.
   Los mismos bloques de shell pasaron ocho escenarios con directorios sintéticos.
4. `tests/check.py` se detuvo en tres errores de symlink `WinError 1314`.
   `tests/catalog-staging.py` tuvo otros dos errores por el mismo privilegio.
   No se cambió la política del host. Responsable: integrador; siguiente acción:
   completar los casos en el job Linux `historical-regressions` del nuevo SHA.
5. No se inició Docker ni se reutilizó SQL local. El arnés requiere POSIX.
   Los 75 SKIP locales no acreditan API/SQL. Responsable: integrador; siguiente acción:
   publicar este candidato en PR2 y leer los artefactos del CI sintético existente.
   Ese recorrido ya pasó en el corte inicial; el SHA de seguimiento necesita CI propio.
6. Los dos digest de push fallaron con `the --slurp option is not supported with --jq or --template`.
   `main` ya tenía la separación `--slurp | jq -r`; se reconcilió ese delta sin merge.
   Se agregó `set -euo pipefail`: una API simulada con error 42 ya no permite publicar.
   La consulta real de solo lectura con los flags compatibles terminó con código 0.
   Véase [regresión del CLI](digest-cli-regression.json). Responsable: integrador;
   cierre: ambos digest de push y el digest de PR pasan en el SHA de seguimiento.

El CLI válido copió exactamente `evidence.json` y `oracles.md`. Cinco negativos
retiraron evidencia publicable anterior y conservaron el archivo ajeno.
Esto prueba el límite de publicación con archivos reales, sin probar un fallo SQL real.
Las pruebas de interrupción del helper usan dobles; SIGKILL o pérdida de energía
siguen fuera de las garantías del proceso.

## Publicación y CI observado

El código inicial quedó `SYNCED` en `Tony` y PR2 con
`ca917005c331e8096e84d21bc1b35cb71a1700d5`. Véase [readback](publication.json).
Los workflows de progreso, snapshot y checks portátiles Windows/Linux pasaron.
Los casos de symlink pendientes en SUAZO-PC pasaron en Linux sin cambiar sus controles.
Build artifact, deploy y SQL del workflow backend limitado a `main` quedaron SKIP.

El [recorrido real](ci-runtime.json) tuvo **19/19 PASS**: dos migraciones EF,
Owner por consola privada, roles, venta idempotente, replay sin efecto, conflicto 409,
recuperación por clave y logout. SQL comprobó una venta, una línea, un movimiento
de venta, una operación de venta y stock total 28. Retirada: API exit 0,
`database_dropped=true`, `private_dir_removed=true`, cero logs fail/crit y 38 warn.
El backend SQL completó **599/599 PASS**, cero SKIP, incluida la prueba de reinicio.
La publicación de evidencia y el readback de ausencia de ambos contenedores pasaron.

Los jobs probaron el merge ref `c2371917f8f5cc10a7d7ee14b270035815a0db9b`.
Su único delta respecto del candidato fue la corrección compatible del digest que
ya estaba en `main`; todos los archivos del producto y workflows SQL eran idénticos.
El seguimiento aplica esa corrección, agrega fallo cerrado y documenta estos resultados.
Necesita confirmar su propio `SYNCED`, SHA remoto y CI; el resultado anterior no lo sustituye.

Integración: **100%**, 4/4 hitos del código inicial (fuentes, aplicación, hook, remotos).
Validación: **80%**, 4/5 hitos; digest unitario, seguridad, build/suite local y API/SQL
comprobados. Falta el conjunto completo de CI del SHA que contiene el ajuste del digest.
Son porcentajes de esta tarea; no miden preparación de producción ni cierre de tarjetas.

Se excluyen ZIP, logs crudos, TRX, certificados, sesiones y autorizaciones de ejecución.
La evidencia pública contiene únicamente fuentes, hashes y resultados revisados.

Lección aplicada: verificar el hash del blob Git cuando `core.autocrlf` normaliza
un manifiesto firmado por hash. Verificar también el estado final de una retirada;
una inspección fallida no demuestra ausencia.

## Reconciliación puntual de los historiales publicados

Tony avanzó a `95120c29cbd685a6818dc9923b05f81c45b5daa0`; otro ejecutor publicó
`9719d8edc226d09aa09df1be02658236fceaf97c` en PR2 con el mismo padre `ca917005`.
Ambos avances se conservan. Jason autorizó un único commit de unión de historiales
y ampliar el importador exclusivamente al segundo SHA, para un total de 17.
La autorización no incluye merge de PR2 a main, force-push ni despliegue.

El SHA adicional cambia solo `.github/workflows/progress-digest.yml`.
Su árbol es `5399907e741505b8d287ba8e2f5ca34c35f56e7a` y su blob es
`681ca470afb62ec44cbaabb618d20ee25b3727b9`, SHA256
`cb24a5857dc2c56c00cda20a0117f34c87fc2be38b221de0ff3953cd2d76410d`.
Los filtros de publicación pasaron. El nuevo manifiesto conserva íntegros los
16 registros anteriores; su pin y alcance constan en [AUTO-SYNC](../AUTO-SYNC.md).

El patch del importador pasó `git apply --check --whitespace=error-all` antes de
aplicarse. El control y su manifiesto entran en el único commit de unión con
recibo normal. Se resolvió el único conflicto al conservar exactamente el workflow
de Tony, incluida la propagación de errores con `set -euo pipefail`.
Las pruebas del registro pasan **23/23**: el caso nuevo rechaza un merge fuera
de la lista sin recibo y acepta el mismo árbol con su recibo normal.
Los 17 SHA reales pasan el verificador con los bytes Git del manifiesto en stage.
`export_progress.py --verify` conserva 15 hashes; el ledger es válido, 34 elementos.
Véase [evidencia de reconciliación](reconciliation.json).
Falta verificar el commit de unión, ambos remotos y su CI.
Responsable: integrador en SUAZO-PC. Los 33 archivos ajenos permanecen fuera del stage.

Integración al corte de esta reconciliación: **75%**, 3/4 hitos; falta el mismo SHA
final en ambos remotos. Validación: **80%**, 4/5; falta CI completo de ese SHA final.
Los siete hallazgos `TONY-*` permanecen en `review`.
