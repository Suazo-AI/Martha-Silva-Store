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
