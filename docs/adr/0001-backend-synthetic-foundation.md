# ADR 0001 — Base .NET/SQL y contrato sintético aislado

Fecha: 2026-10-24. Estado: decisión técnica del primer lote autorizado; **no aprobación comercial ni de producción**.

## Contexto

El roadmap V1 propone un monolito modular. `src/app.js` llama a `window.marthaDemoApi`; `src/demo-api.js` mantiene estado local, precios USD ilustrativos y autenticación simulada. No constituye API HTTP, autoridad de inventario ni modelo de seguridad. El primer lote desarrolla R01 técnico y la base R04; no cierra R01 comercial, R06, R07 productivo o R08.

## Decisión

- Backend independiente ASP.NET Core sobre .NET 10 y SQL Server, monolito modular. Mantener frontend vanilla, build estático y demo sin cambios; no añadir fallback de HTTP a localStorage.
- Contrato HTTP versionado `/api/v1`, JSON camelCase. `contracts/openapi-v1.json` describe el corte sintético. Cambios incompatibles posteriores requieren revisión y versión, no cambios silenciosos.
- Catálogo leído de SQL; fixtures explícitamente sintéticas, con identificadores distintos del catálogo comercial y moneda `XXX` (marcador sin moneda comercial). Importes enteros en unidades de prueba: no tasas, redondeo, impuestos, envío, descuentos ni moneda de cobro aprobados.
- Solo una variante por pedido de prueba. No clientes, direcciones, tarjetas, pasarela, checkout, administración ni integración SISFAIN. No endpoint para declarar pago.
- Rutas sintéticas solo en entorno Development **y** opción `Synthetic:Enabled=true`; ausentes en Production incluso si la opción está activa. Ningún POST de ventas productivas se habilita en este lote. El guard es aislamiento de desarrollo, **no autenticación**; tampoco autoriza publicar el servidor de desarrollo.

## Transacción e invariantes

Una transacción SQL incluye la adjudicación de la clave de idempotencia, comprobación/retención de stock, pedido, reserva y respuesta persistida. El servidor calcula el precio desde SQL, nunca desde un importe del cliente. El DTO estricto rechaza campos adicionales de precio/total con 400; no los acepta como autoridad. Error o rollback revierte todo; no quedan claves exitosas sin pedido ni stock retenido sin reserva.

Las cantidades deben ser enteras y positivas dentro del límite del contrato. El corte mínimo mantiene `availableQuantity >= 0` y registra en el pedido la cantidad retenida; la reserva decrementa disponibilidad, no registra una venta o movimiento de stock físico. Antes de ampliar a inventario comercial se deberá modelar y probar explícitamente `0 <= reserved <= onHand`, disponibilidad = `onHand - reserved`. Una escritura condicional o bloqueo serializable equivalente impide que dos transacciones ganen la última unidad. La validación previa en memoria no sustituye esa condición SQL.

La clave se limita al actor fijo de pruebas y operación de creación; en producción el ámbito deberá incorporar identidad autorizada. La comparación es exacta y sensible a mayúsculas. Huella canónica: GUID normalizado y cantidad; el orden/espacios del JSON no cambian el intento lógico; cualquier campo adicional (incluidos precios) se rechaza con 400. Misma clave y huella devuelve el mismo 201 y cuerpo persistido; GET permite consultar el pedido persistido. Misma clave con otra huella devuelve 409 sin mutación. Una contienda por la misma clave debe serializarse hasta ver el resultado confirmado. Los intentos fallidos no consumen definitivamente la clave.

**Expiración aplazada:** este corte mínimo no incluye `expiresAt`, endpoint de liberación, scheduler ni cancelación. Las reservas sintéticas permanecen retenidas en la base desechable. No afirmar que ya se libera stock. Antes de cerrar R07, implementar y demostrar transición condicional `reserved -> expired`, con hora UTC de servidor; liberación, reserva y pedido en una transacción. Ejecutar dos veces o concurrentemente debe liberar una sola vez, sin aumentar `onHand`, renovar por replay ni aceptar pagos tardíos. Negocio debe aprobar duración/política antes de ventas reales.

## Convenciones de persistencia (no segunda migración)

La migración del backend es la única fuente ejecutable del esquema; este ADR fija invariantes, no nombres de tablas obligatorios:

| Entidad lógica | Clave / restricciones mínimas |
| --- | --- |
| Variante | GUID PK; precio entero no negativo; moneda de fixture; disponibilidad derivada |
| Balance del corte mínimo | Disponible entero no negativo en variante; no representa stock físico/ERP aprobado |
| Pedido de prueba | GUID PK; variante FK; cantidad positiva; precio/moneda/total snapshot; createdAt UTC; estado reserved en este lote |
| Reserva | Relación 1:1 con pedido; cantidad positiva; liberación fuera de este lote; puede coexistir en la fila del pedido del corte mínimo |
| Idempotencia | Unicidad por ámbito+clave con comparación binaria; huella canónica; pedido FK; snapshot inmutable suficiente para reconstruir el 201 original; clave puede coexistir en fila de pedido |

Retener claves durante toda la vida de la base sintética; no purgarlas ni reutilizarlas automáticamente. Producción necesitará política de retención, auditoría, identidad, migraciones y respaldo aprobados. Fechas SQL `datetime2` UTC o `datetimeoffset`; importes `bigint`, sin float. Un índice único es obligatorio, no una consulta previa seguida de inserción sin protección.

## Consecuencias y puertas

Este corte permite probar concurrencia e idempotencia contra SQL real sin inventar decisiones de negocio. No demuestra seguridad entre clientes, transacciones bancarias ni inventario compartido. SQL real y revisión independiente son necesarios antes de afirmar las invariantes verificadas. La edición/hosting productivos, EULA, costos y credenciales son decisiones aparte. No iniciar un contenedor SQL ni aceptar términos automáticamente. La conexión de aplicación/migración/seed debe usar una base cuyo Initial Catalog cumpla `^MarthaSynthetic_[A-Za-z0-9_]{1,64}$`; es una barrera contra apuntar por error a otra base, no autorización de acceso ni autenticación.
