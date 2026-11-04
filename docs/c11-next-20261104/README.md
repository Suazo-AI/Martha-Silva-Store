# C11 / N10: cierre técnico por capas

**APTO técnico. C11 cerrado; no equivale a aceptación operativa ni producción.**

El [juez independiente](final-review.md), `gpt-6-astra / high`, aceptó el candidato
`53dd23b5cfec2cb5dd717395b9095a71d29669f0` en SUAZO-PC.
El ejecutor fue `gpt-6.1-sol / xhigh`. No se cambió código de producto ni seguridad.

[Trello C11](https://trello.com/c/ant3sEML): Hecho, 5/5 criterios; [readback exacto](trello-closure.json).
[Trello C9](https://trello.com/c/vVQVt9Qo): permanece abierto 0/5; [bloqueo actualizado](../c9-recovery-20261103/trello-preflight-result.json).

## Qué cambió y por qué

El [dictamen inicial](initial-review.md) dejó C11-N5-01: faltaba ejecutar la cookie original
después de que Owner reasignara Cashier A→B mediante el PUT real.
Se añadió un único Fact HTTP+SQL, con Program, migraciones, SQL sintético y cookie/CSRF reales.
El mínimo backend subió de 600 a 601; no se eliminó ningún caso anterior.

La [primera revisión estática](pre-ci-review-4f060265.md) detectó un oráculo incompleto.
La [corrección revisada](pre-ci-review-19-tables.md) compara las 19 tablas tras cada rechazo.
La comparación de 16 tablas solo atraviesa los cambios autorizados de PUT/login.
El hallazgo quedó resuelto en el mismo Fact; los candidatos y dictámenes previos se conservan históricos.

El transporte de replay usa `HandleCookies=false` y reenvía explícitamente la cookie/CSRF capturadas.
Antes del cambio prueba /me 200 y recibo A 200. Después exige tres 401 con ambas claves de venta.
Login nuevo en B confirma ámbito y versión; recibo A devuelve 404 y mutar A devuelve 403.
Las lecturas B son exactas. La venta B añade una venta, línea, movimiento y operación; stock 8→7.
Las filas originales A permanecen iguales y su operación sigue siendo única.

## Evidencia directa

| Capa | Resultado y fuente |
| --- | --- |
| Backend HTTP+SQL | [601/601 PASS](ci-53dd23b5/savia/savia-backend-outcomes-41774927960-1/sanitized-results.json), 0 failed/skipped; nuevo método N5 1/1. Los 257 métodos anteriores conservan sus 600 casos. Reinicio controlado 1/1. |
| Staff unit | 45/45, 0 failed/skipped, leído en el log del job 126392957018. |
| Chromium con API staff simulada | [45/45 PASS](ci-53dd23b5/savia/savia-browser-evidence-41774927960-1/browser-results.json); 0 errores runtime y solicitudes externas. Se observan 9 fallos de red: 7 en ventas con aborto deliberado y 2 cancelaciones de logout; el artefacto no clasifica individualmente su causa. |
| Golden API+SQL | [19/19 pasos](ci-53dd23b5/golden/savia-golden-path-41774928044-1/evidence.json), 18 capturas SQL y 0 fallos de oráculo. |
| C6 navegador→API→SQL | [21/21 pasos](ci-53dd23b5/golden/savia-browser-path-41774928044-1/evidence.json), 20 capturas SQL y 0 fallos de oráculo. |

[SAVIA 41774927960/1](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41774927960) y
[Golden 41774928044/1](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41774928044)
terminaron success en el head exacto. Hay 21 checks: 16 success, 5 skips previstos, 0 fallos o pendientes.
Los skips de jobs no son casos backend omitidos. El [binding](ci-53dd23b5/root-ci-binding.json)
identifica cada check, job, artefacto y digest informado por GitHub.

GitHub probó el checkout sintético `cb3109bc5159b86d4ec8c68e3ac058d2f949bab7`.
Su árbol y el de 53dd son idénticos: `abaf54477b400ac434835864fbd79795210b5f32`.
No se fusionó main. El [dictamen y hashes](final-review-evidence.json) vinculan fuentes y cuatro JSON descargados.
Los digests ZIP proceden de GitHub; no se recalcularon los ZIP binarios.
El export CRLF y el blob Git LF tienen hashes distintos, con texto normalizado idéntico.

## Recuperación y retirada

La pérdida de respuesta ocurre después del segundo commit. GET con la clave original recupera el mismo recibo.
Recuperación y recargas conservan 2 ventas, 2 líneas, 2 movimientos, 2 operaciones y stock 27.
Solo hay 2 POST de venta acumulados: no hay segundo débito ni éxito inventado.
Logout devuelve 204, /me devuelve 401 y quedan 0 sesiones activas.

Los artefactos registran salida API 0, base eliminada y directorio privado retirado.
C6 registra además salida Chrome 0, propiedad confirmada y ausencia de procesos.
El primary leyó después del dictamen las cuatro publicaciones y las dos salidas reales de ausencia de contenedor.
El [extracto saneado](ci-53dd23b5/publication-cleanup.json) completa ese límite del juez sin repetir la ejecución.

## Límites y siguiente acción

C6/C7/C8 conservan sus cierres. C7 conserva la excepción durable de remap 409.
La expiración existente usa reloj controlado; no prueba ocho horas reales.
Los tres escenarios adicionales N5-COV siguen pendientes; no se implementaron en este lote.
C9 sigue bloqueado por confianza TLS en su [único preflight](../c9-recovery-20261103/PREFLIGHT-RESULT.md).
Faltan recuperación Windows con ventas, RTO/RPO, recuperación del último Owner, dispositivos y aceptación del negocio.
No se probaron pagos, carga ni TLS/proxy de producción. No se autorizaron main, despliegue o cambios de seguridad.

El lote añadió cobertura y corrigió su oráculo de prueba. Se retestó con 601/601 y juicio APTO.
El [manifiesto de exportación](closure-export-manifest.json) registra procedencia y exclusiones.
El commit documental posterior debe conservar el código aceptado y pasar su propio CI.
Su recibo normal y el readback final identifican el SHA publicado, sin crear un commit para registrar su propio SHA.
