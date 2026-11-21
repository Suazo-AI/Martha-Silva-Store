# BUG-010: una sucursal podía devolver una venta de otra sucursal

Fecha: 2026-11-12. Detectó: crítica independiente de ADR-001 (F3, experimento E7).
Reprodujo y corrigió: agente primary. Corrección: [V006](../../db/migrations/V006__return_same_branch_only.sql).
Estado: corregido. La prueba falla sin V006 y pasa con V006.

## Antes y después

| | Sin V006 | Con V006 |
| --- | --- | --- |
| B devuelve 2 unidades de una venta de A | Aceptado: B cambia la línea de venta de A y emite un anticipo | Rechazado con 51535; venta, stock y anticipos intactos |
| Prueba `sales/030` | FAIL | PASS |

Evidencia: [rojo](evidence/BUG-010-red.txt), [verde](evidence/BUG-010-green.txt) (`python savia/tools/check.py`: 47 T-SQL, 13 .NET, `RESULT PASS`).

## Por qué importa

Con sincronización por dueño (ADR-001 D5), B no puede escribir una fila de A.
A nunca recibiría el cambio, o lo pisaría. Además rompe D7: la regla de sucursal solo estaba en C#.

## Qué cambió

`sales.usp_PostCreditReturn` compara `Sales.BranchId` con `@BranchId` después de leer la venta.
Si difieren, lanza 51535. La API lo traduce a `403 auth.branch_access`.

## Decisión pendiente (Martha)

Si el negocio quiere devoluciones entre sucursales, la devolución debe ser una fila de B
y la venta de A no se modifica. Hasta esa decisión, se rechaza.
