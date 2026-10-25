# Contrato HTTP V1 — base sintética

[`openapi-v1.json`](openapi-v1.json) es el contrato versionado de este lote, no una API comercial lista. Ver [ADR](../docs/adr/0001-backend-synthetic-foundation.md) y [gates](../docs/BACKEND-LOT1.md). No requiere generar código ni bloquea compilar la aplicación.

## Convenciones congeladas

- ASP.NET Core .NET 10 + SQL Server; rutas `/api/v1`, JSON camelCase, GUID no vacío, UTC ISO 8601.
- Solo `Development` **y** `Synthetic:Enabled=true` habilitan fixtures y rutas de pedidos sintéticos. `Test`, `Staging`, `Production` y cualquier otro entorno no las habilitan. Sin gate: catálogo devuelve 503 `catalog_not_enabled`, pedidos 404. No interpretar la ausencia de auth como listo para acceso público.
- El `Initial Catalog` de la conexión debe satisfacer `^MarthaSynthetic_[A-Za-z0-9_]{1,64}$`. El prefijo evita errores de destino; no reemplaza autorización, aislamiento ni aprobación EULA.
- Pedido mínimo: una variante, cantidad entera 1..100; campos adicionales, incluidos precio/total/contacto, se rechazan con 400. Importes desde SQL: `unitPriceMinor <= 9000000000000`, `totalMinor <= 900000000000000`, dentro del rango entero seguro de JavaScript. `XXX` y `synthetic:true` identifican pruebas; no copiar USD, stock o condiciones del simulador al comercio.
- `Idempotency-Key`: exactamente un valor, 8..128 caracteres ASCII visibles `!`–`~`, sensible a mayúsculas, sin espacios. Ámbito fijo de prueba + operación; no identidad de cliente. Canonicalizar GUID/cantidad, no bytes del JSON. Mismo intento devuelve **201**, mismo pedido y snapshot; otro payload con la misma clave devuelve **409**. Intentos fallidos no consumen una clave exitosamente. Retención: vida de la base sintética desechable, sin purga automática.
- Problem Details: `application/problem+json`, `status`, `title`, `code`, `traceId`; no secretos, consultas SQL, cuerpos ni datos de clientes. `type` puede ser el predeterminado del framework. Clientes deciden por `code`, no por texto de `title`.
- No hay expiración, cancelación, liberación automática, pagos ni cliente real. `reserved` es el único estado del corte mínimo. No reintentar pagos: no existe API de cobro.

## Ejemplo local (solo tras habilitar SQL de pruebas autorizado)

Consultar `GET /api/v1/catalog`, tomar un `variantId` real de esa respuesta y enviar:

```http
POST /api/v1/synthetic/orders
Content-Type: application/json
Idempotency-Key: synthetic-attempt-0001

{"variantId":"11111111-1111-1111-1111-111111111111","quantity":1}
```

El GUID es ilustrativo, no un SKU real ni promesa de que el seed lo contenga. Respuesta 201: `orderId`, `variantId`, `quantity`, `unitPriceMinor`, `currency`, `totalMinor`, `status`, `createdAt`, `synthetic`; `Location` apunta a `/api/v1/synthetic/orders/{orderId}`. Repetir exactamente la operación no reserva otra unidad. Consultar esa ruta devuelve el pedido persistido; no constituye autorización de comprador.

| HTTP | Código | Acción / significado |
| --- | --- | --- |
| 400 | invalid_request | Corregir JSON, clave, GUID, cantidad o campos no admitidos; no mutación |
| 404 | unknown_variant / order_not_found | Referencia no encontrada |
| 404 | not_found | Ruta ausente por gate o identificador de ruta mal formado |
| 409 | out_of_stock | No hay disponibilidad suficiente; no pedido parcial |
| 409 | idempotency_conflict | Misma clave para otro intento lógico; no sobrescribir el anterior |
| 503 | storage_unavailable | Mantener misma clave al reintentar; nunca fallback a localStorage |
| 503 | catalog_not_enabled | Gate de catálogo sintético cerrado |
| 500 | internal_error | Error inesperado sin detalles internos; investigar con traceId |

`/health/live` solo comprueba vida del proceso; `/health/ready` comprueba SQL/esquema. Ninguno certifica autenticación, licencia, pagos, datos comerciales, backups o preparación de producción.

## Comprobación del artefacto

El JSON es OpenAPI 3.0.3, con schemas cerrados para solicitudes/DTOs y errores extensibles. Revisar referencias internas y comparar rutas/DTOs contra código y pruebas en cada lote. El contrato por sí solo no demuestra atomicidad: las pruebas con SQL real autorizado deben verificarla. No hay endpoint de expiración declarado anticipadamente.


## V2 SAVIA sintética (contrato separado)

[`openapi-v2.json`](openapi-v2.json) describe el libro de inventario V2; las convenciones V1 anteriores y `openapi-v1.json` siguen congeladas. Detalle de implementación y límites: [backend V2](../docs/backend-v2.md).

Todas las rutas `/api/v2/synthetic` existen solo con `Development` **y** `Synthetic:Enabled=true`; fuera del gate devuelven 404, incluido catálogo/capacidades. El prefijo SQL de pruebas existente sigue obligatorio. Ninguna ruta habilita CGA ni escribe a un ERP externo.

- `GET /catalog`: `{synthetic:true,authority,items:[...]}` con `onHand`, `reserved`, `available = onHand - reserved`, precio del servidor y moneda `XXX`.
- `GET /capabilities`: código sintético implementado frente a SQL no verificado; CGA no verificado, sin operaciones habilitadas. No requiere conexión SQL.
- `POST /reservations`: `{variantId,locationId,quantity,attemptId,authority}` e `Idempotency-Key`. Respuesta 201 y `Location`; el replay conserva el recibo original, aunque la reserva haya sido cancelada.
- `GET /reservations/{reservationId}`: `{creation,status,cancelledAt}`; `creation` es el recibo inmutable, `status` es el estado actual.
- `POST /reservations/{reservationId}/cancel`: `{attemptId,authority}` y clave; 200, libera la reserva una sola vez sin aumentar `onHand`.
- `GET /attempts/{operation}/{attemptId}`: operación `reserve` o `cancel`; solo consulta esta autoridad. 404 `attempt_unknown` indica resultado desconocido: nunca demuestra que una escritura no ocurrió.
- `GET /movements`: `{synthetic:true,authority,items:[...]}`; movimientos del libro V2.

La autoridad fija e inmutable es `{mode:"savia",instanceId:"savia-synthetic-v2",epoch:1}`. Es obligatoria en ambas mutaciones; cualquier otra devuelve 409 `authority_mismatch` antes de abrir almacenamiento. Solicitudes y autoridad rechazan campos desconocidos. GUID no vacío, cantidad entera 1..100 y reglas de clave V1; precio/total del cliente se rechazan. Un `attemptId` identifica el intento de una operación y se conserva junto a su clave y autoridad; conflictos no reemplazan el intento persistido.

Una pérdida de respuesta, timeout, 5xx, conexión caída o ausencia de recibo implica **desconocido**. Conservar la misma autoridad, intento y clave para reconciliar; jamás enviar automáticamente a CGA ni a otra autoridad. No hay carrito multilínea, expiración, venta, envío, devolución, pago, datos comerciales ni API productiva. Las pruebas SQL reales autorizadas siguen necesarias para acreditar atomicidad, carreras, rollback y liberación concurrente.
