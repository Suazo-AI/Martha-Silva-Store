# C6: dictamen final del CI combinado

Veredicto: **APTO. Los 17 puntos del contrato C6 están cumplidos para este candidato y este CI sintético Linux.**
H1 y H2 quedan cerrados con evidencia nueva.
No encontré un hallazgo nuevo que impida aceptar C6 dentro de ese alcance.

Candidato: `e4b7910835bf2c9901aa06989e296997875a3636`.
CI: [run `41765611979`](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41765611979), attempt `1`, evento `pull_request`.
Resultado leído: `completed / success`.
Juicio: `savia-c6-judge-20261104`, mismo lote autorizado, `gpt-6.1-sol / xhigh`, host `SUAZO-PC`.

**Cumple:** Chrome real → API HTTPS real → SQL Server real, dos ventas sintéticas, recuperación sin duplicación, logout y retirada verificada.

## Fuentes y comprobación independiente

Leí directamente el paquete `coordination/c6-ci-41765611979`:

- `run-binding.json` y `log-provenance.json`.
- `browser/evidence.json` y `browser/oracles.md`.
- `smoke/evidence.json` y `smoke/oracles.md`.

No usé el informe del ejecutor como prueba del recorrido.
Leí los blobs Git del SHA candidato y los comparé con los hashes del artefacto.
Las seis fuentes UI y los dos drivers coinciden: **8/8**.
Los hashes servidos en `browser.start` y `browser.cashier_login` coinciden con las seis fuentes UI publicadas.

El driver final es idéntico, byte por byte, a `browser_path.mjs.proposed` ya revisado.
El arnés Python, el test de seguridad C6 y README son idénticos a `2ddf83de7a89da608e8267a21313d64b373bf5e2`.
El workflow y el contrato son idénticos al snapshot `6aeb9a35f45331ace85ac48dc19bfd9264b0f722`.
`verify_evidence.py` también permanece idéntico a ese snapshot.

El checkout real del runner fue `f1a0bb1d0cd0258838f920ec8f811315820c7587`.
La captura mínima registra el readback de `git log -1 --format=%H` a las `2026-11-04T03:12:16.9502245Z`.
El binding compara candidato → merge: `ahead_by=1`, `behind_by=0`, `files=[]`.
Los contenidos probados corresponden al candidato publicado.

Las comparaciones Git son lecturas propias del juez.
El binding y el extracto mínimo del runner son archivos seguros suministrados por el primario.
No repetí consultas GitHub, pruebas, runtime, API, SQL, navegador, checkout ni mutaciones de refs.
Solo escribí este informe y `FINAL-CI-EVIDENCE.json`, fuera del checkout.

## H1: logout cerrado

Referencia: `browser/evidence.json:1296` y `browser/oracles.md:22`.

- `browser.logout`: `PASS`, `649 ms`, DOM `logged_out`.
- POST `/internal/api/security/logout`: HTTP `204`.
- GET `/internal/api/security/me`: HTTP `401`.
- `sale_posts=2`, `external_requests=0`, `runtime_errors=0`.
- SQL: `active_sessions=0`, `cashier_active_sessions=0`, `oracle_failures=[]`.
- Siguen `2` ventas, `2` líneas, `2` movimientos de venta, `2` operaciones de venta y stock `27`.

El driver vinculado exige URL exacta del login y formulario habilitado antes del checkpoint.
También conserva la lectura completa del cuerpo de `me` y la espera `networkidle`.
Referencias: `browser_path.mjs:114-124,270-290`.
El arnés comprueba SQL antes del siguiente ACK: `golden_path.py:1003-1051`.

El run anterior `41757409404` permanece FAIL como evidencia histórica.
No atribuyo una causa demostrada al timeout anterior.
H1 se cierra por el comportamiento real satisfactorio del candidato corregido.

## H2: propiedad y ausencia de Chrome cerradas

Referencia: `browser/evidence.json:1386`.

- Teardown `PASS`, `876 ms`.
- `browser_exit=0` y `api_exit=0`.
- `browser_ownership_confirmed=true`.
- `browser_processes_absent=true`.
- `database_dropped=true` y `private_dir_removed=true`.
- `api_log_fail_or_crit=0`.

El hash del arnés corresponde al código que valida PID CDP, perfil privado, ascendencia y starttime.
Su readback exige ausencia de los grupos registrados de Chrome y Node; una señal enviada no basta.
Referencias: `golden_path.py:842-916,996-1002,1063-1071,1094-1095,1153-1157`.
La ausencia del directorio privado incluye el perfil efímero que contiene.

El paso final del contenedor terminó `success` según el binding.
El suplemento incluye el resultado ejecutado, separado del texto del comando:
`2026-11-04T03:13:56.7059623Z PASS: disposable SQL container absence verified.`
El workflow comprueba la lista real tras retirar el contenedor: `golden-path.yml:153-171`.
No se publican PIDs, cmdlines, rutas de perfiles ni logs crudos para acreditar este cierre.

## Los 17 puntos congelados

Contrato: `docs/c6-e2e-20261103/ACCEPTANCE.md:7-23`.
Resultado: **17 cumplidos, 0 pendientes, 0 fallidos dentro de C6**.
Las referencias de código siguientes corresponden al SHA candidato.
Las referencias de evidencia corresponden al paquete de este run.

| Punto | Estado | Evidencia concreta |
|---|---|---|
| 1. UI real desde el mismo proceso HTTPS API | Cumplida | Seis hashes servidos coinciden con los blobs UI del candidato en `browser.start` y login. `browser/evidence.json:365,447`; API loopback HTTPS y fuentes registradas en ese mismo archivo. |
| 2. Recorrido real completo | Cumplida | Los 11 checkpoints browser pasan; hay login, inventario, ventas, recibos, recargas y logout HTTP/SQL. `browser/evidence.json:447,596,661,974,1296`. H1 cerrado arriba. |
| 3. Sin fixtures de negocio ni venta insertada por el arnés | Cumplida | Los drivers coinciden con los revisados. El navegador continúa peticiones reales; la pérdida usa CDP sobre la respuesta recibida. `browser_path.mjs:69-76,221-243`. SQL tiene cero ventas antes de la primera UI: `browser/evidence.json:596`. |
| 4. SQL antes de cada siguiente paso | Cumplida | 11 checkpoints en orden, todos con oráculos; Python ejecuta `self.step(...)` antes de enviar el ACK. `golden_path.py:1003-1051`; `browser_path.mjs:114-124`. |
| 5. Primera venta de dos unidades una sola vez | Cumplida | Cantidad `2`, total `2500`, una venta/línea/movimiento/operación y stock `28`. La recarga conserva recibo y contadores. `browser/evidence.json:661,728,849`. |
| 6. Pérdida tras HTTP 200 real de la segunda venta | Cumplida | Segundo POST HTTP `200`, `response_lost=true`, cantidad `1`, total `1250`. CDP valida el recibo antes de descartar. `browser/evidence.json:914`; `browser_path.mjs:227-239`. |
| 7. Commit SQL anterior a recuperación, misma clave | Cumplida | Checkpoint de pérdida ya tiene dos ventas y stock `27`; la recuperación mantiene exactamente su clave y sale_id. `browser/evidence.json:914,974`; ACK SQL en `golden_path.py:1050-1051`. |
| 8. GET recupera recibo original sin otro POST | Cumplida | GET `/internal/api/operations/commerce.sale.record` HTTP `200` con la clave anterior; recibo recuperado y recarga posterior conservan el sale_id. `sale_posts=2` hasta logout. `browser/evidence.json:974,1110,1296`. |
| 9. Contadores finales correctos | Cumplida | Dos ventas/líneas/movimientos de venta/operaciones de venta y stock `27`, desde `30`. Hay `5` movimientos totales y `9` operaciones totales, incluidos los de preparación. `browser/evidence.json:974,1296`. |
| 10. Invariantes existentes sin violaciones | Cumplida | Las 38 capturas SQL de browser y smoke tienen `oracle_failures=[]`; los ocho contadores de violación permanecen en cero. Tablas completas `browser/oracles.md:3` y `smoke/oracles.md:3`. |
| 11. Eventos permitidos, sintéticos y saneados | Cumplida | Allowlist de protocolo, claves tipadas y secretos por canal privado: `golden_path.py:72-113`. Escaneo antes del manifiesto: `445-476,511-525`. Ambas verificaciones de publicación pasan en el binding. |
| 12. Solo dos archivos tras manifiesto/hashes | Cumplida | `verify_evidence.py:13-46` comprueba manifiesto, hashes y bytes copiados. Workflow `105-151` condiciona ambos uploads a la verificación. Los dos paquetes recibidos contienen únicamente `evidence.json` y `oracles.md` cada uno. |
| 13. Sin HAR, traces nativos, logs o sesiones privadas | Cumplida | `raw_trace_or_har_recorded=false`; los uploads tienen rutas explícitas a los dos archivos. No hay esos materiales en el paquete recibido. `golden-path.yml:119-151`; metadatos browser y binding de artefactos. |
| 14. Retirada y ausencia verificadas | Cumplida | H2 cerrado: propiedad/ausencia Chrome y Node, API salida `0`, base y directorio privado ausentes. Contenedor ausente por readback ejecutado. `browser/evidence.json:1386`; `log-provenance.json`; `golden-path.yml:153-171`. |
| 15. C5 y contratos existentes preservados, sin SKIP silencioso | Cumplida | Smoke real: `19/19 PASS`; browser: `21/21 PASS`. El CI también pasa regresiones de evidencia/retirada. El delta preserva el modo serve y aplica el nuevo requisito de ausencia solo a browser. `smoke/evidence.json:26,724`; `golden_path.py:1153-1157`; workflow `37-40,90-104`. |
| 16. Permisos, digest y alcance de seguridad preservados | Cumplida en el alcance C6 | Workflow idéntico al snapshot revisado: `contents: read`, SQL con digest inmutable, sin deploy. `golden-path.yml:13-14,30-31,173`. No hay cambios nuevos en las fuentes C6 frente al delta ya revisado ni mutaciones de máquina desde esta revisión. |
| 17. CI y artefactos vinculados al SHA publicado | Cumplida | Binding final: run/attempt/head y ambos artifact IDs con ese head. Checkout real del merge y comparación `files=[]`; ocho hashes de fuentes verificados contra Git. Los cuatro archivos recibidos quedan sellados abajo y en `FINAL-CI-EVIDENCE.json`. |

## Sellado del paquete recibido

| Archivo | SHA-256 calculado por el juez |
|---|---|
| `browser/evidence.json` | `6f1eb9cb175d00c5abaaf4a01bf337363af0547e9fffacdc38e1030d22f6bb0d` |
| `browser/oracles.md` | `5780090af31f8bdf41a76d4a72fe933013a960eab8ebc0baf41d31384430b6f8` |
| `smoke/evidence.json` | `2ab7c5982f68b248fead2644c1e706abe016bbd792610a7639533fa39a1e6184` |
| `smoke/oracles.md` | `30ee767aa786d93551b3c94fd5e82565e6a2c42302c7f91419b97c9e086b6307` |
| `run-binding.json` | `b872f240a5b960a0937b538f25134f1d755a09c56d26cccc08852176c019946f` |
| `log-provenance.json` | `9bc87c22e0155442a31b63836fface44245986703ee1c0e6a11e2fd081625bfc` |

Artefactos finales identificados en el binding:
browser `13292142418`, smoke `13291863195`.
No recalculé el digest del ZIP remoto porque el paquete local no incluye esos archivos ZIP.
Sí comprobé los bytes recibidos, los contenidos de evidencia y su vinculación de fuentes/SHA.
Tampoco reconstruí independientemente la DLL; su hash está registrado en la evidencia del build y recorrido del CI.

## Límites reales y entrega

No queda un bloqueo de aceptación C6 abierto en este candidato.
El dictamen no acepta C8, el PR completo, producción ni todo el piloto SAVIA.
Su siguiente integración y cualquier cambio de estado pertenecen al primario.
Los informes iniciales permanecen congelados; este informe cierra H1/H2 con nueva evidencia, sin reescribir su FAIL histórico.

La pérdida de respuesta es una simulación CDP después del commit real.
No prueba una caída real de proceso ni de red.
Siguen sin probarse Windows/SUAZO-PC, TLS/proxy de producción, pagos, concurrencia/carga, backup/restore, script SQL idempotente, móviles, aceptación visual y auditoría completa de accesibilidad.
No se inició un recorrido interactivo nuevo de serve desde este juez; su preservación se evaluó por el delta y las regresiones existentes.
Estos límites no se convierten en resultados PASS de C6 ni autorizan ejecutarlos.

Datos compactos, hashes y checkpoints: `FINAL-CI-EVIDENCE.json`.
Uso: el entorno no expone tokens consumidos ni presupuesto restante por API.
