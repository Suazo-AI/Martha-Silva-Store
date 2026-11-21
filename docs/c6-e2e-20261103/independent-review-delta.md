# C6: revisión independiente del delta H1/H2

VEREDICTO: **APTO CON REPAROS como delta de código**.
**C6 continúa NO APTO para aceptación funcional hasta recibir el nuevo CI real**.

No encontré hallazgos nuevos de código en el delta asignado.
H2 queda corregido en la implementación; su ejercicio Linux sigue pendiente.
H1 permanece abierto. El cambio de logout mejora observación y espera, pero aún no demuestra resolver el fallo real.

## Alcance congelado

Tarea: `savia-c6-judge-20261104`, reevaluación del mismo lote autorizado `gpt-6.1-sol / xhigh`.
Host: `SUAZO-PC`. Fecha: `2026-11-04` UTC.

El informe inicial `REPORT.md` queda congelado.
La comparación parte del snapshot revisado `6aeb9a35f45331ace85ac48dc19bfd9264b0f722`.
El contrato de 17 puntos no cambia.

Fuentes de este delta:

- `C:/Users/Jason/MARTHA-SILVA/coordination/c6-correction-20261104/delta.patch`.
- Las cuatro fuentes corregidas en `C:/Users/Jason/MARTHA-SILVA/test-runs/c6-browser-sql-20261103`.
- `docs/c6-e2e-20261103/implementation.md` de ese worktree, sección posterior al CI `41757409404`.
- `C:/Users/Jason/MARTHA-SILVA/github/docs/c6-e2e-20261103/correction-import.json` y las cuatro fuentes importadas.

Leí solo el delta y su contexto directo.
No ejecuté pruebas, navegador, SQL, API, Docker, builds ni instalaciones.
No edité fuentes, contrato o informe inicial. No hice commits ni pushes.
La revisión no cubre C8 ni otros cambios del candidato combinado.

## Hallazgos y estado de H1/H2

### H1 — Alta, pendiente de CI real

Referencia nueva: `tests/golden-path/browser_path.mjs:270-285`.
Referencia histórica: `REPORT.md`, H1; run `41757409404`, `browser.logout=FAIL` tras `20126 ms`.

El delta registra un observador del POST antes del click y exige HTTP 204 real.
Después verifica URL exacta de login, formulario habilitado, `me=401` y dos POST de venta acumulados.
`click({noWaitAfter:true})` separa la espera de navegación de esas comprobaciones explícitas.
No sustituye respuestas ni relaja la comprobación SQL de cero sesiones.

La causa del timeout original sigue sin confirmar.
No declaro que cambiar las esperas haya corregido el producto o la corrida real.
El probe con transporte en memoria reportado por el ejecutor no prueba el logout contra API y SQL.

Cierre necesario: nuevo CI del SHA publicado con `browser.logout=PASS`, HTTP 204, `me=401` y SQL sesiones=0.
El mismo CI debe conservar dos ventas y stock 27, sin otro POST o débito.
Responsable: primario/ejecutor C6. No realicé corrección ni ejecución porque este encargo es de solo lectura.

### H2 — Corrección estática satisfactoria; prueba real pendiente

Referencias: `tests/golden-path/browser_path.mjs:37-46` y `tests/golden-path/golden_path.py:841-916`, `:996-1002`, `:1065-1066`, `:1153-1157`.

CDP entrega el PID del proceso browser mediante el canal privado.
Python exige PID entero, líder de grupo, perfil temporal exacto y ascendencia hasta el Node propio.
Guarda el starttime de `/proc/<pid>/stat` para distinguir una identidad reutilizada.
Registra ambos grupos y retira Chrome antes de Node.
Solo señala un grupo si un miembro actual conserva una identidad conocida.
Comprueba ausencia de ambos grupos después de TERM y, si hace falta, KILL.
Un proceso persistente o una lectura fallida mantiene `browser_processes_absent=false`.
La retirada de modo browser exige explícitamente `browser_processes_absent is True` para producir PASS.
El cierre repetido conserva el resultado previo sin volver a señalar procesos.

El PID, perfil, ascendencia y starttime no se añaden a la evidencia pública.
Los metadatos nuevos de retirada son booleanos.
Los errores por fase se limitan a códigos fijos permitidos.
No encontré una ruta nueva para señalar procesos ajenos mediante parámetros no validados del cliente.

Los casos `tests/test_golden_path_browser_safety.py:162-221` cubren con dobles ambos grupos, persistencia, identidad reutilizada, lectura denegada y perfil ajeno.
No confundo esos dobles con ejercicio real de CDP, `/proc` o señales.
El probe CDP local del ejecutor fue inconcluso; no se usa para aceptar esta corrección.

Cierre necesario: nuevo CI Linux con `browser_ownership_confirmed=true` y `browser_processes_absent=true` en la retirada.
Debe conservar API detenida, base propia borrada, perfil/directorio privado ausentes y contenedor ausente.
Responsable: primario/ejecutor C6. No se repitieron pruebas ni procesos durante esta revisión.

## Regresiones revisadas

No cambia el flujo de venta, respuesta perdida, recibo o recuperación.
El ACK de propiedad precede a los checkpoints y no sustituye sus oráculos SQL.
La barrera SQL permanece antes de cada ACK de negocio.
No cambia el precio del servidor, la cantidad esperada ni la clave de idempotencia.
No cambia la allowlist de campos de negocio ni la publicación mediante manifiesto y hashes.
El modo smoke predeterminado y serve conservan sus ramas de ejecución.
La guarda nueva de ausencia solo aplica a `mode=browser`.
El workflow no forma parte de este delta y no se modifica aquí.

El fallo de protocolo, dependencia o lectura continúa produciendo FAIL, sin SKIP silencioso.
No se introducen endpoints, RPC, PostgREST, cambios de permisos o parámetros nuevos del producto.

## Preservación de las 17 comprobaciones

La evidencia del run anterior sigue congelada y conserva su resultado FAIL.
Las filas sin cambios conservan la revisión estática y la evidencia histórica; no prueban por sí solas el candidato nuevo.
El nuevo CI debe repetir el contrato completo para el SHA combinado publicado.

| Punto | Efecto del delta | Estado de revisión |
|---|---|---|
| 1 | Conserva seis recursos reales y comparación de hashes servidos. | Sin regresión estática observada; nuevo CI pendiente. |
| 2 | Añade HTTP 204, URL exacta, formulario y `me=401` explícitos al logout. | H1 abierto hasta logout real PASS y SQL sesiones=0. |
| 3 | No añade fixtures, respuestas sintéticas ni inserción de ventas. | Sin cambio. |
| 4 | Añade ACK privado de propiedad; conserva SQL antes de cada ACK de negocio. | Sin relajación del contrato. |
| 5 | Conserva venta de dos unidades, recibo y recarga sin escrituras. | Sin cambio. |
| 6 | Conserva HTTP 200 real antes de descartar la segunda respuesta. | Sin cambio. |
| 7 | Conserva SQL antes de recuperación y la misma clave. | Sin cambio. |
| 8 | Conserva GET de recuperación, recibo original y dos POST acumulados. | Sin cambio. |
| 9 | Conserva dos ventas/líneas/movimientos/operaciones de venta y stock 27. | Sin cambio. |
| 10 | Conserva todos los invariantes y oráculos existentes. | Sin cambio. |
| 11 | Añade códigos fijos de fase y booleanos de limpieza; identidad de proceso sigue privada. | Sin filtración nueva observada estáticamente. |
| 12 | Conserva saneamiento, manifiesto, hashes y dos archivos publicables. | Sin cambio. |
| 13 | No añade HAR, trazas, logs públicos, sesiones ni capturas. | Sin cambio. |
| 14 | Verifica propiedad de ambos grupos y hace obligatorio leer su ausencia. | H2 corregido en código; CI real de retirada pendiente. |
| 15 | Conserva smoke/serve; la nueva guarda solo aplica a browser y falla cerrada. | Sin regresión estática observada; no ejecuté pruebas. |
| 16 | No cambia workflow, permisos, imagen SQL, seguridad, servicios, main o despliegue. | Sin cambio dentro de este delta. |
| 17 | Las cuatro fuentes importadas coinciden; el SHA y artefacto del próximo CI aún faltan. | Pendiente para el candidato corregido. |

## Igualdad de la importación comprobada

Leí los bytes de las cuatro fuentes del ejecutor y del checkout canónico.
Comprobé cada SHA-256 contra `correction-import.json`.
Comprobé igualdad de texto normalizando únicamente CRLF a LF.
Las cuatro comparaciones de hash por destino y de texto resultaron verdaderas.

| Fuente | SHA-256 del ejecutor |
|---|---|
| `tests/golden-path/golden_path.py` | `e420885d49e066ca50cf6582d574149eb847338813362040c72bf92dbd9072fb` |
| `tests/golden-path/browser_path.mjs` | `60e9c9a636dac13149a57449247edce1491c842d727936d6d8e2e760bb5a7aaf` |
| `tests/test_golden_path_browser_safety.py` | `fbf94d089f5815f28e1d214292175ea9153d0e1806c8fa6a805ce193b9665fa7` |
| `tests/golden-path/README.md` | `2e1cf928279e97a267080952d73cd24756550fc259db59aae3621cf2a9ba4322` |

El MJS y la prueba Python tienen hashes físicos distintos en el canónico por terminadores de línea.
Su texto normalizado coincide. No se comparó el candidato nuevo con artefactos del CI anterior como si fueran suyos.

## Evidencia ligera y límites

El ejecutor documenta 33/33 comprobaciones ligeras, Node syntax, AST y diff check con exit 0.
También documenta retirada local de 2/2 perfiles y lectura CIM de 0 Chrome.
Verifiqué que esas afirmaciones y límites están registrados; no repetí esas ejecuciones.
La evidencia local de Windows no valida el mecanismo Linux de `/proc`.
La limpieza local de probes no acredita el siguiente CI.

Lo que cumple en este delta: H2 ahora exige prueba de ausencia y el logout conserva comprobaciones reales más precisas.
Lo pendiente: nuevo SHA publicado, CI completo, artefactos saneados y binding exacto para revisar los 17 puntos.

Siguiente acción: el primario publica el candidato combinado y aporta evidencia real del mismo SHA a esta revisión existente.
No hacen falta más probes locales para aceptar una hipótesis de timeout.
No autoriza runtime adicional, despliegue, main ni cambios de seguridad.

Uso: el entorno del agente no expone tokens consumidos ni presupuesto restante por API.
