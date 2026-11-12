# BUG-001 y BUG-002: fallos bajo concurrencia

Fecha: 2026-11-12. Detectó y corrigió: agente primary. Estado: corregido, con prueba que lo forzó de nuevo.
Pruebas: [ConcurrencyTests.cs](../../tests/Savia.Tests/ConcurrencyTests.cs). Corrección: [V004](../../db/migrations/V004__concurrency_fixes.sql) y reintento en `SqlGateway`.

## Antes y después

| | Antes | Después |
| --- | --- | --- |
| 60 ventas simultáneas con 30 unidades | Falla: muchas respuestas `503 db.busy` | Pasa: 30 ventas, 30 rechazos por stock, 0 errores |
| 10 cierres simultáneos del mismo turno | Falla: `409 cash.till_not_open` en reintentos | Pasa: 10 respuestas iguales, 1 cierre, 1 documento |
| Interbloqueos registrados por SQL Server | 82 | 0 en 3 corridas seguidas (180 ventas simultáneas) |
| Pruebas de concurrencia | 2 pasan, 2 fallan | 5 pasan, 3 corridas seguidas |

Evidencia: [rojo](evidence/BUG-001-002-red.txt), [verde](evidence/BUG-001-002-green.txt).

## BUG-001: las ventas simultáneas se bloquean entre sí

Cómo se reproduce: 60 peticiones `POST /api/v1/sales` al mismo tiempo sobre el mismo artículo.
Causa, leída del grafo de interbloqueo del motor:
la venta A espera la fila de stock que tiene la venta B (`inventory.usp_ApplyMovement`, línea 31);
la venta B, al armar su evento, lee `sales.SaleLines` y espera las líneas sin confirmar de la venta A (`sales.usp_PostSale`, línea 123).
Con `READ COMMITTED` por bloqueos, un lector espera a un escritor. SQL Server elige una víctima y la venta falla.

Corrección:
1. `READ_COMMITTED_SNAPSHOT ON` y `ALLOW_SNAPSHOT_ISOLATION ON` en cada base. Un lector ya no espera a un escritor.
   Es el valor por defecto de Azure SQL Database; ahora la sucursal y la nube se comportan igual.
2. `SqlGateway` reintenta hasta 3 veces cuando la llamada fue víctima de un interbloqueo (error 1205).
   Es seguro porque cada procedimiento es atómico e idempotente por id.

## BUG-002: cerrar caja dos veces a la vez rompe el reintento

Cómo se reproduce: 10 peticiones `POST /api/v1/cash/tills/{id}/close` iguales al mismo tiempo.
Causa: `sales.usp_CloseTill` buscaba un cierre existente antes de bloquear el turno.
La segunda petición no veía el cierre, esperaba el bloqueo y luego encontraba el turno cerrado: error 51522.
Corrección: bloquear primero el turno y buscar el cierre después.

## Misma clase de defecto en otros procedimientos

`usp_OpenTill`, `usp_RecordCashEntry`, `usp_RegisterProduct`, `usp_RegisterItem`, `usp_PostCreditReturn`,
`usp_RequestTransfer`, `usp_PostAdjustment`, `usp_AllocateToWeb`, `usp_ReleaseQuarantine`,
`usp_CreateReservedOrder`, `usp_RecordVerifiedPayment` y `usp_QueueExport` revisan "ya existe" sin bloqueo.
Dos peticiones idénticas simultáneas chocan en la llave única (error 2601 o 2627).
No se corrompe ningún dato: la restricción única lo impide.
`SqlGateway` reintenta una vez ese error; el segundo intento toma el camino idempotente.
Prueba: `Ten_parallel_opens_of_one_till_open_it_once`.

## Límites

- Probado con una caja y una cajera lanzando peticiones en paralelo, no con varias cajas físicas.
- No se midió rendimiento; solo corrección.
- Los procedimientos de anticipos y tienda en línea todavía no tienen prueba de concurrencia.
