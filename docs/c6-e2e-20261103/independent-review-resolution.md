# C6: revisión de la resolución propuesta de logout

Veredicto: **APTO CON REPAROS para la resolución de código. C6 sigue NO APTO para aceptación funcional completa.**
No encontré un defecto nuevo en este delta.
La propuesta conserva las comprobaciones anteriores y espera el cuerpo de `me` antes del checkpoint.
H1 y H2 siguen pendientes del artefacto real del candidato combinado.

Juicio: `savia-c6-judge-20261104`, continuación del mismo lote autorizado.
Modelo/razonamiento: `gpt-6.1-sol / xhigh`. Host: `SUAZO-PC`.
Fecha: `2026-11-04` UTC.
No ejecuté pruebas, API, SQL, navegador, runtime, consultas GitHub, commits, pushes ni cambios canónicos.
Los informes anteriores permanecen congelados.

## Composición revisada y procedencia

Base: `2ddf83de7a89da608e8267a21313d64b373bf5e2`.
Fuente propuesta: `coordination/pr2-b6bc0396-proposal-20261104/browser_path.mjs.proposed`.
Parche: `coordination/pr2-b6bc0396-proposal-20261104/browser-resolution.patch`.
Leí el blob Git del driver en esa base y comparé todo su texto con la propuesta.
La comparación normalizó exclusivamente CRLF → LF.
Solo existe un hunk, en la consulta de `me` posterior al logout.

SHA-256 de los bytes de la propuesta:
`5a09272ffb8a1c433813bc4cad626921cd1b0ef329f0097a008122e41eb6df21`.

Leí también el driver del ejecutor en `test-runs/c6-browser-sql-20261103`.
Sus bytes son idénticos a la propuesta y tienen ese mismo SHA-256.
La composición evaluada conserva los otros tres archivos C6 de `2ddf83d` ya revisados.
Esta revisión no afirma que la propuesta esté aplicada o publicada.
No revisé el importador, la reconciliación Git ni C8.

El primario informó que el CI de `b6bc0396bb7d53359d23b806a3177edc194c8e62`, run `41758450353`, terminó satisfactorio.
No consulté ese run ni recibí su artefacto en esta revisión.
Ese dato no prueba H2 ni la composición combinada todavía propuesta.
Los `33/33` checks ligeros y Node/AST/diffcheck `0` provienen del ejecutor; no los repetí.

## Verificado en la resolución

En `browser_path.mjs.proposed:284-288`, el driver conserva la petición real y same-origin a `/internal/api/security/me`.
Ahora espera `response.arrayBuffer()` y después devuelve el status de esa misma respuesta.
No sustituye la respuesta, no cambia el status ni captura un error para convertirlo en éxito.
Un rechazo de `fetch` o de la lectura del cuerpo sigue llegando al manejo de fallo existente.

El checkpoint continúa esperando `networkidle` en `browser_path.mjs.proposed:114-116`.
La lectura del cuerpo termina antes de invocar ese checkpoint en la línea `290`.
Esto conserva el guard y ordena la lectura completa antes de la espera.
No demuestra por sí solo la causa del timeout anterior ni garantiza su resolución en CI.

Se conservan estas exigencias del logout:

- POST real de logout y HTTP `204`: `browser_path.mjs.proposed:272-277`.
- URL exacta del login y formulario habilitado: `browser_path.mjs.proposed:279-281`.
- GET `me` real, HTTP `401` y `posts === 2`: `browser_path.mjs.proposed:284-289`.
- Checkpoint `browser.logout` y DOM `logged_out`: `browser_path.mjs.proposed:290`.
- Fases de fallo y salida saneada: `browser_path.mjs.proposed:271-282,291-295`.

No cambian las comprobaciones SQL del arnés en `2ddf83d`.
`golden_path.py:1006-1011` sigue exigiendo dos ventas, stock `27`, cero sesiones activas y ausencia de nuevas escrituras al hacer logout.
El checkpoint no reemplaza ese oráculo con el resultado HTTP.

La propiedad de Chrome permanece intacta en `browser_path.mjs.proposed:37-46`.
El PID procede de CDP y el driver espera el ACK privado antes de iniciar el recorrido.
La propuesta no cambia el código Python que verifica perfil, ascendencia y starttime.
Tampoco cambia la retirada de ambos grupos ni el readback de ausencia.
Referencias de la base revisada: `golden_path.py:842-916,996-1002,1063-1066,1153-1157`.
El PASS de retirada sigue condicionado a `browser_processes_absent is True` en modo browser.

El hunk no introduce parámetros cliente de permisos, precios, tenant o ámbito.
Tampoco añade endpoints, RPC, replay del POST, fixtures ni operaciones de negocio desde el arnés.

## Hallazgos y reparos

**Sin hallazgos nuevos de código en la resolución propuesta.**

**H1, alto, sigue abierto como fallo funcional pendiente de nueva prueba real.**
El run `41757409404` falló en `browser.logout`.
La secuencia estática revisada es coherente, pero el artefacto anterior no acredita logout ni revocación final.
El primario debe entregar el artefacto del candidato combinado y su binding.
El cierre exige `browser.logout=PASS`, logout HTTP `204`, `me=401` y `sale_posts=2`.
SQL debe mostrar `active_sessions=0`, `cashier_active_sessions=0` y `oracle_failures=[]`.
Las ventas, líneas, movimientos y operaciones de venta deben seguir en `2`, con stock `27`.
También deben pasar los otros diez checkpoints browser y la retirada, sin omisiones.

**H2, medio, sigue pendiente solo de evidencia real de la retirada corregida.**
El código de propiedad y ausencia fue aceptado estáticamente en `DELTA-REVIEW.md`; esta propuesta lo conserva.
El cierre exige `browser_ownership_confirmed=true` y `browser_processes_absent=true` en teardown PASS.
También exige API retirada, base eliminada, directorio privado eliminado y `api_log_fail_or_crit=0`.
El binding debe vincular el arnés corregido y acreditar ausencia final del contenedor.
La salida de Node, una señal enviada o los checks con dobles no sustituyen ese readback.

Propietario de la siguiente acción: primario, con el artefacto saneado del CI combinado.
Acción del juez: comprobar ese paquete contra los 17 puntos, sin ejecutar runtime.
No intenté otra corrección: mi autorización es solo lectura y escritura de este informe.

## Conservación de los 17 checks

El contrato permanece sin cambios.
Esta tabla describe la composición propuesta; no atribuye el PASS de otro SHA a este candidato.

| Punto | Resultado de la revisión del delta | Evidencia final pendiente |
|---|---|---|
| 1 | Conserva recursos UI reales y mismo HTTPS API; no cambia carga ni hashes. | Recursos servidos y hashes del SHA combinado. |
| 2 | Conserva todo el recorrido y refuerza la finalización de lectura de `me`. | H1 real: logout, revocación SQL y recorrido completo PASS. |
| 3 | No añade fixtures, replay ni inserciones de venta desde el arnés. | Vincular las fuentes revisadas al CI final. |
| 4 | Conserva `networkidle`, protocolo de checkpoints y ACK posterior al oráculo. | Todos los checkpoints y oráculos del run combinado. |
| 5 | Primera venta y recarga no cambian. | Una venta cantidad `2`, stock `28`, recarga sin escritura. |
| 6 | No cambia la pérdida de respuesta después del HTTP `200` real. | Segundo POST confirmado antes del descarte. |
| 7 | No cambia el orden SQL anterior a recuperación ni la clave pendiente. | Segunda venta comprometida y misma clave. |
| 8 | No cambia GET de recuperación ni recarga posterior. | Recibo original y POST acumulados `2`. |
| 9 | No cambia cantidades ni contadores de negocio. | Dos ventas/líneas/movimientos/operaciones, stock `27`. |
| 10 | Conserva todos los invariantes y controles SQL. | Cero violaciones y `oracle_failures=[]`, también tras logout. |
| 11 | Conserva allowlist, códigos fijos y salida saneada. | Scanner del paquete final satisfactorio. |
| 12 | No cambia manifiesto, hashes, scanner ni selección de los dos archivos. | Verificación y upload de `evidence.json` y `oracles.md`. |
| 13 | No añade HAR, traces, logs, sesiones, bases ni capturas. | Inventario del upload final sin artefactos privados. |
| 14 | Conserva CDP/ACK, identidad Linux, dos grupos y ausencia obligatoria. | H2 real y ausencia final del contenedor. |
| 15 | No cambia C5 smoke/serve ni convierte fallos en SKIP. | C5 y C6 satisfactorios del mismo candidato. |
| 16 | No cambia workflow, permisos, digest SQL ni configuración de máquina. | Vincular la composición final sin cambios adicionales C6. |
| 17 | Hash de propuesta y driver del ejecutor idénticos, comprobados directamente. | SHA publicado, run/attempt/checkout y hashes de artefactos combinados. |

Los campos exactos del paquete final siguen definidos en `PRE-FINAL-REVIEW.md`.
Este informe no acepta C6 completo ni amplía el alcance autorizado.

Uso: el entorno no expone tokens consumidos ni presupuesto restante por API.
