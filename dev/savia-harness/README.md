# SAVIA V2: harness sintético de desarrollo

Cliente CLI independiente, Node 18+ y biblioteca estándar. Hace HTTP real contra la API .NET V2 en loopback; no inicia servidores, SQL, migraciones ni seed. Una fixture, una variante, una ubicación, moneda no comercial `XXX`. No es carrito, tienda ni integración ERP/pagos. No usa los 40 productos de la demo.

`prepare.py` copia exclusivamente `build-inputs/static/**` y tres archivos `src`; este directorio no es entrada del build. Wrangler publica exclusivamente `dist`. No copiar estos archivos a esas rutas ni incluirlos en un deploy. No se cambian contratos, backend, build ni lockfiles. Se eligió CLI para evitar CORS y cambios de serving del backend; no hay HTML público ni endpoint de CGA inventado.

## Ejecutar contra la API real

Requisito externo: el responsable del backend ya debe haber preparado y autorizado un SQL sintético, migrado/seeded explícitamente e iniciado .NET en `Development` con `Synthetic:Enabled=true`. Este harness no realiza esas acciones. Readiness real debe verificarse con `/health/ready`; `/health/live` no prueba acceso a SQL. Ver las instrucciones del backend y contrato V2 integrado. No introducir credenciales en el comando, JSON ni repositorio.

Desde la raíz del checkout, PowerShell:

```powershell
$env:SAVIA_API_ORIGIN = 'http://127.0.0.1:5080'
node dev/savia-harness/cli.mjs capabilities
node dev/savia-harness/cli.mjs catalog
node dev/savia-harness/cli.mjs reserve 1
node dev/savia-harness/cli.mjs status
node dev/savia-harness/cli.mjs movements
node dev/savia-harness/cli.mjs cancel
node dev/savia-harness/cli.mjs retry
node dev/savia-harness/cli.mjs status
node dev/savia-harness/cli.mjs movements
```

`catalog` muestra precio, onHand, reserved y available autoritativos de la API. Se acepta solo una variante/ubicación `synthetic:true`, autoridad SAVIA V2 y moneda `XXX`. La reserva envía IDs/cantidad; precio y total proceden de la respuesta, jamás del estado local. El API puede estar implementado y seguir indicando `sqlVerification:not_verified`; el harness no lo convierte en verificado.

Los resultados impresos son respuestas HTTP o estado de transporte local, nunca una prueba independiente de commit SQL. Si la API/SQL no está disponible, el comando falla o conserva outcome `unknown`; jamás inventa éxito ni usa `localStorage`, demo o ERP de respaldo. CGA queda `not_verified`, sin autoridad y con capacidades cerradas.

## Timeout y reintento

Antes de cada POST se conserva el estado incierto `unknown` en disco; el guardado inicial `prepared` también se trata como incierto si se recupera tras una interrupción. Se guarda `.state.json` (ignorado por Git) con operación, autoridad original, attemptId, clave y payload exacto. El origen original también queda fijado. Fallar la escritura impide el POST. El lock exclusivo evita dos procesos sobre el mismo archivo; si un proceso fue interrumpido, inspeccionar que terminó antes de retirar manualmente su `.lock`. No borrar estado para resolver un timeout: podría ocultar un intento ya confirmado en SQL.

```powershell
node dev/savia-harness/cli.mjs attempts
node dev/savia-harness/cli.mjs lookup
node dev/savia-harness/cli.mjs retry
```

`lookup` usa `GET /api/v2/synthetic/attempts/{reserve|cancel}/{attemptId}`. `404 attempt_unknown` significa resultado desconocido; no equivale a rechazo ni prueba que el POST no haya ejecutado. Un rechazo persistido tiene `outcome:rejected`. En un primer envío solo se reconoce como rechazo un ProblemDetails coherente del contrato y con código permitido. Un 4xx de un reintento no resuelve el resultado original, aunque parezca un rechazo de negocio: conserva `unknown` hasta recibir el éxito exacto o consultar un recibo durable. Respuestas de acceso, rutas cerradas, conflictos de identidad o cuerpos inválidos nunca habilitan una nueva reserva pendiente. Tras `unknown`, `retry` reenvía exactamente el POST guardado: misma autoridad, clave, attemptId, payload y ruta, sin releer catálogo ni generar otra autoridad. Mientras existe un intento pendiente/desconocido no se admite una nueva reserva/cancelación ni cambio de modo.

`lookup <attemptId>` y `retry <attemptId>` permiten escoger un intento anterior. Repetir la creación después de cancelar conserva el recibo original `status:active`; `status` hace un GET separado cuyo estado mutable será `cancelled`. Repetir la misma cancelación usa su clave original. Una cancelación nueva sobre una reserva ya cancelada puede devolver `already_cancelled` y liberación cero. El harness solo muestra movimientos reales de `GET /movements`; no los calcula localmente.

Parámetros opcionales: `SAVIA_TIMEOUT_MS` (1..120000, por defecto 5000), `SAVIA_HARNESS_STATE` (otro archivo de intentos sintéticos, para una sesión aislada). Usar un archivo nuevo solo para un escenario nuevo deliberado, nunca como recuperación de resultado desconocido. El estado no lleva datos de clientes ni contraseñas. `mode api-cga` falla cerrado sin HTTP. Códigos de salida: 0 respuesta/recibo conocido, 1 error de comando/lectura, 2 outcome pendiente/desconocido, 3 rechazo conocido.

## Contrato HTTP utilizado

| Operación | Ruta |
| --- | --- |
| Catálogo, precio y disponibilidad | `GET /api/v2/synthetic/catalog` |
| Capacidades y límites verificados | `GET /api/v2/synthetic/capabilities` |
| Crear reserva | `POST /api/v2/synthetic/reservations` |
| Estado actual | `GET /api/v2/synthetic/reservations/{id}` |
| Cancelar | `POST /api/v2/synthetic/reservations/{id}/cancel` |
| Recuperar intento | `GET /api/v2/synthetic/attempts/{operation}/{attemptId}` |
| Movimientos | `GET /api/v2/synthetic/movements` |

Autoridad original: `{mode:'savia',instanceId:'savia-synthetic-v2',epoch:1}`. POST reserva: `{variantId,locationId,quantity,attemptId,authority}`; cancelar: `{attemptId,authority}`. Ambos usan `Idempotency-Key` ASCII visible, 8..128 caracteres. El harness genera UUID y clave de desarrollo, sin dependencias. No envía precios, totales ni datos de negocio reales.

## Pruebas de contrato, separadas de integración

```powershell
node --check dev/savia-harness/client.mjs
node --check dev/savia-harness/cli.mjs
node --test dev/savia-harness/client.test.mjs
```

Las pruebas usan doubles explícitos de `fetch`: verifican contrato, guardado previo, timeout, recuperación, autoridad fija, rechazo/unknown, reintentos exactos, recibo inmutable y CGA cerrado. **No son pruebas SQL ni integración .NET**; tampoco prueban navegador, CORS, rendimiento o despliegue. El test de exclusión inspecciona la lista de fuentes y directorio de assets, no ejecuta el build Python.

La ejecución real requiere API y SQL autorizados; no se afirma haberlos ejecutado cuando solo pasan estas pruebas. Para un smoke real guardar por separado comandos, códigos HTTP, recibos, movimientos y límites, sin credenciales. No instalar dependencias para correr este harness.
