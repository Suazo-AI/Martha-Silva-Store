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
del contenedor en los dos workflows SQL. No cambia las reglas funcionales de stock.

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

El CLI válido copió exactamente `evidence.json` y `oracles.md`. Cinco negativos
retiraron evidencia publicable anterior y conservaron el archivo ajeno.
Esto prueba el límite de publicación con archivos reales, sin probar un fallo SQL real.
Las pruebas de interrupción del helper usan dobles; SIGKILL o pérdida de energía
siguen fuera de las garantías del proceso.

## Publicación y aceptación pendientes en este corte

El commit contenedor y su recibo identifican estos bytes. Después del hook se debe
leer `SYNCED` y el SHA remoto de `Tony`, y avanzar por fast-forward la rama existente
`claude/funny-brahmagupta-5e5rj0` de PR2 al mismo SHA. Sin force-push, merge ni deploy.

La aceptación requiere CI asociado a ese SHA, artefacto golden path con oráculos y
readback SQL de retirada, suite SQL completa sin SKIP y readback de ausencia de los
contenedores. Los jobs de PR pueden probar un merge ref: registrar también su SHA,
padres y comparación de árbol. Un CI anterior no cubre este candidato.

Integración: **50%** en este corte, 2/4 hitos (fuentes verificadas y parche aplicado).
Faltan publicación canónica y readback remoto/PR2.
Validación: **60%**, 3/5 hitos (digest, seguridad, build y suite local).
Faltan checks completos Linux y recorrido real API/SQL con evidencia y retirada.
Son porcentajes de esta tarea; no miden preparación de producción ni cierre de tarjetas.

Se excluyen ZIP, logs crudos, TRX, certificados, sesiones y autorizaciones de ejecución.
La evidencia pública contiene únicamente fuentes, hashes y resultados revisados.

Lección aplicada: verificar el hash del blob Git cuando `core.autocrlf` normaliza
un manifiesto firmado por hash. Verificar también el estado final de una retirada;
una inspección fallida no demuestra ausencia.
