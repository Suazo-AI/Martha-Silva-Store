# CP1 / A: pruebas de los procedimientos de catálogo, recepción, etiquetas e inventario

- task_id: `cp1-a-catalog-receiving-inventory-20261112`
- Modo: VALIDATE (pruebas que pueden fallar + auditoría de defectos)
- Ejecutor: agente worker A. Revisor: orquestador primary.
- Fuente: `915044e958bce52015a0d9a33f5f60df567c8ac9` (rama `t3/savia-proc-audit-tests`)
- Motor: SQL Server 2022 16.0.4305.5 Developer Edition, contenedor `savia-sqlserver-dev`
- Fecha: 2026-11-12
- Modelo del ejecutor: MiniMax M3.1 Flash (opencode/minimax-m3.1-flash-free), sin ajuste de razonamiento configurable.

## Qué se entregó

41 archivos de prueba nuevos (34 PASS, 7 XFAIL) para los 15 procedimientos asignados.
Ningún archivo del producto fue modificado: solo pruebas nuevas y este documento.

| Procedimiento | Normal | Reintento | Errores | Pruebas |
| --- | --- | --- | --- | --- |
| `catalog.usp_RegisterProduct` | 100 | 100 | 101 (51200, 51210) | 2 |
| `catalog.usp_RegisterItem` | 110 | 110 | 111 (51201, 51202, 51203, 51204, 51205, 51211) | 2 |
| `catalog.usp_ChangePrice` | 120 | 120 | 121 (51206 x2, 51207) | 2 |
| `catalog.usp_ActivateItem` | 130 | 130 | 131 (51220 x2, 51221) | 2 |
| `catalog.usp_LookupByScan` | 140 | 140 | sin validaciones en el código | 1 |
| `receiving.usp_RecordScan` | 100 | 100 | 102 (51301 x3, 51302, 51303) | 4 |
| `receiving.usp_ResolveScan` | 120 | 122 (XFAIL) | 121 (51304, 51305 x2, 51306) | 3 |
| `receiving.usp_ApproveScanSession` | 130 | 131 (XFAIL) | 132 (51307, 51308, 51309, 51310) | 3 |
| `receiving.usp_PostScanSession` | 140 | 140 | 141 (51312, 51313, 51314, 51315 x2), 142 (51311, 51316) | 4 |
| `labels.usp_QueueReceiptLabels` | 100 | 100 | 101 (51401) | 2 |
| `labels.usp_AcknowledgePrint` | 110 | 110 | 111 (51402, 51403) | 2 |
| `inventory.usp_ApplyMovement` | 100 | 100 | 101 (51101, 51102 x3, 51103) | 2 |
| `inventory.usp_PostAdjustment` | 110 | 110 | 111 (51105 x2, 51106, 51102) | 3 |
| `inventory.usp_ReleaseQuarantine` | 120 | 120 | 121 (51120 x3, 51121, 51122, 51102) | 2 |
| `inventory.usp_AllocateToWeb` | 130 | 130 | 131 (51104 x2, 51102) | 2 |

Comando de ejecución y resultado:

```
python savia/tools/db/saviadb.py test --jobs 3
SUMMARY PASS=36 XFAIL=7  logs: .out\dbtests
EXIT=0
```

(PASS=36 incluye las 2 pruebas que ya existían: `receiving/010` y `sales/010`.
Las 41 pruebas nuevas son 34 PASS + 7 XFAIL. No hay FAIL, XPASS ni INVALID.)

## Defectos encontrados (7 pruebas en rojo con marca XFAIL)

Cada defecto tiene su propio archivo, con `-- XFAIL: D-A-0n ...` en la línea 2.
La prueba sigue en rojo: no se tocó el producto ni se debilitó la aserción.

| ID | Procedimiento | Defecto | Gravedad | Prueba | Salida exacta |
| --- | --- | --- | --- | --- | --- |
| D-A-01 | `receiving.usp_ResolveScan` | Un reintento con los mismos ids falla con 51305 en vez de devolver la resolución: el procedimiento no es idempotente. | alta | `receiving/122_resolve_scan_retry_is_not_idempotent.sql` | `Msg 51305 ... Procedure receiving.usp_ResolveScan, Line 17 / Escaneo no resoluble en su estado actual.` |
| D-A-02 | `receiving.usp_ApproveScanSession` | Un reintento con el mismo id de sesión falla con 51307 en vez de devolver la aprobación: el procedimiento no es idempotente. | alta | `receiving/131_approve_scan_session_retry_is_not_idempotent.sql` | `Msg 51307 ... Procedure receiving.usp_ApproveScanSession, Line 12 / La sesion no puede aprobarse.` |
| D-A-03 | `inventory.usp_PostAdjustment` | Acepta un aprobador sin acceso a la sucursal del stock (supervisorB aprueba la sucursal A). `usp_ReleaseQuarantine` rechaza el mismo caso con 51122. | alta | `inventory/112_post_adjustment_approver_branch_access.sql` | `ASSERT FAIL: the adjustment was rejected expected=0 actual=1` |
| D-A-04 | `catalog.usp_RegisterItem` | Un SKU interno repetido se rechaza con el error crudo 2627 (violación de `UQ_Items_Sku`) en vez de un error del dominio, como sí hace con barcode (51204) y SKU de proveedor (51205). | media | `catalog/141_register_item_duplicate_sku.sql` | `ASSERT FAIL: the repeated SKU was rejected with raw SQL error 2627 instead of a catalog domain error` |
| D-A-05 | `catalog.usp_ActivateItem` | Cambia el precio de una variante ya activa sin escribir nada en `catalog.PriceHistory`: el historial de precios pierde el cambio y el cambio no pide motivo. | media | `catalog/142_activate_item_price_history.sql` | `ASSERT FAIL: price history rows for the price change expected=1 actual=0` |
| D-A-06 | `receiving.usp_PostScanSession` | Nunca cierra el contenedor: `receiving.ImportContainers.Status` sigue en `counting` después del posting, aunque `CK_Container_Status` permite `closed`. El mismo contenedor puede contarse y postearse otra vez. | media | `receiving/151_post_scan_session_closes_container.sql` | `ASSERT FAIL: the container is closed after the posting expected=1 actual=0` |
| D-A-07 | `receiving.usp_RecordScan` | Cuando la lectura se captura con `INSERT ... EXEC` (el patrón que indica la guía de pruebas), el error de validación 51303 se reemplaza por `Msg 3915 Cannot use the ROLLBACK statement within an INSERT-EXEC statement`: el cliente recibe un error crudo y no el código del dominio. | media | `receiving/103_record_scan_error_through_insert_exec.sql` | `ASSERT FAIL: the rejected read reported a raw SQL error instead of the domain error 51303` (el error real es `Msg 3915`) |

Notas sobre los defectos:

- D-A-01 y D-A-02 son el mismo tipo de hueco: el resto de los procedimientos mutantes del baseline sí son idempotentes por id (`usp_RecordScan` 51302, `usp_PostScanSession` estado `posted`, `usp_RegisterItem`/`usp_RegisterProduct` por id, `usp_PostAdjustment` por id, `usp_ReleaseQuarantine`/`usp_AllocateToWeb` por `audit.Operations`). El revisor puede decidir si la corrección es "mismo id + mismo contenido = no-op" y "mismo id + otro contenido = error de dominio nuevo".
- D-A-06 es la ficha de menor certeza: no hay documento que defina el ciclo de vida del contenedor, pero el estado `closed` existe en el CHECK y nada en el baseline lo escribe. La prueba solo afirma que el contenedor queda `closed`; no afirma que un segundo conteo del mismo contenedor se rechace.
- D-A-07 no rompe el happy path: solo cambia el número de error que ve el cliente cuando la captura es con `INSERT ... EXEC`. En las pruebas de error de este paquete se usa `EXEC` a secas, como manda la regla 4 de `db/tests/README.md`.

## Invariantes cubiertos

| Invariante | Dónde se prueba |
| --- | --- |
| `StockBalances.OnHand = SUM(OnHandDelta)` y `Reserved = SUM(ReservedDelta)`, con `OnHand >= Reserved >= 0` | `receiving/140`, `receiving/150`, `inventory/100`, `inventory/101`, `inventory/110`, `inventory/130` |
| Un código desconocido o ambiguo nunca aumenta el stock | `receiving/101` (desconocido), `receiving/110` (ambiguo) |
| El barcode conserva los ceros a la izquierda en identificador, lectura y trabajo de etiqueta | `catalog/110` (identificador y payload del evento), `receiving/100` (lectura), `receiving/150` y `labels/100` (trabajo de etiqueta) |
| Un ítem sin costo aprobado (draft) entra al pool `quarantine`, no a `store` | `receiving/150` |
| El mismo código en dos ítems da `MatchStatus = 'ambiguous'`, no una elección silenciosa | `receiving/110`, `catalog/140` |
| `usp_ReleaseQuarantine` y `usp_PostAdjustment` exigen aprobador distinto del actor | `inventory/121` (51120), `inventory/111` (51106) |
| `usp_AllocateToWeb` mueve unidades de `store` a `web` y el total no cambia | `inventory/130` |
| El stock nunca queda negativo (51102) y una operación rechazada no deja filas parciales (movimiento, saldo, evento outbox) | `inventory/101`, `inventory/111`, `inventory/121`, `inventory/131`, `receiving/143` |

## Qué no se pudo probar y por qué

- **Concurrencia**: dos sesiones que mueven el mismo saldo a la vez. Las pruebas de concurrencia viven en la suite .NET, no en T-SQL, según `db/tests/README.md`. No se probó.
- **Nodo en la nube / sincronización**: los procedimientos encolan en `sync.Outbox`; nada aquí prueba la entrega, la deduplicación entre nodos ni la reconciliación. Es alcance de CP4.
- **Impresora real**: se prueba la cola y el acuse de impresión (`labels.PrintJobs`, `labels.PrintAttempts`), no que el ZPL/TSPL salga en papel.
- **Error 51103 con pool congelado**: se prueba en `inventory/101` (congelado directo) y `receiving/143` (recepción sobre pool congelado). No se probó el congelamiento por negocio (no hay procedimiento que congele).
- **51316 (cantidad agrupada fuera de rango)**: se alcanza con 101 lecturas de 10000 unidades. Es un caso artificial: con el límite de 10000 por lectura, hacen falta 101 lecturas para pasarse.
- **51311 (sesión `posted` sin comprobante)**: no hay flujo normal que lo produzca; la prueba fuerza el estado con un `UPDATE` sobre `receiving.ScanSessions`.
- **Valores exactos de `catalog.Products`, `catalog.Items` y `catalog.ItemIdentifiers` en los estados intermedios**: solo se afirman los valores que el dominio usa (estado, precio, costo, códigos, `RawCode` con ceros).

## Notas para quien siga (armas de la casa)

1. `EXEC` no acepta expresiones como argumento: `EXEC ... @ActorId=test.Id('manager')` es error de sintaxis (Msg 102). Copiar siempre a una variable primero.
2. `DECLARE` dentro de `BEGIN TRY`/`BEGIN CATCH` no compila en este patrón (Msg 102). Declarar todo arriba del lote.
3. `catalog.Items` tiene `UQ_Items_Product_Variant (ProductId, SizeId, ColorId)` y los `NULL` cuentan como iguales. El fixture ya usa `(M,NEG)`, `(S,BLA)` y `(L,ROJ)` del producto `product`: cualquier variante nueva en ese producto necesita otra combinación de talla y color.
4. Un procedimiento que hace `ROLLBACK` en su `CATCH` no puede fallar dentro de `INSERT ... EXEC` (Msg 3915). Para probar errores usar `EXEC` a secas; para capturar filas usar `INSERT INTO @tabla EXEC` solo cuando el caso es exitoso.
5. El fixture no crea impresoras ni plantillas: los trabajos de etiqueta quedan en `waiting_config`, no `pending`.

## Archivos entregados

Pruebas (rutas relativas a `savia/db/tests/`):

```
catalog/100_register_product_normal_and_retry.sql
catalog/101_register_product_errors.sql
catalog/110_register_item_normal_and_retry.sql
catalog/111_register_item_errors.sql
catalog/120_change_price_normal_and_retry.sql
catalog/121_change_price_errors.sql
catalog/130_activate_item_normal_and_retry.sql
catalog/131_activate_item_errors.sql
catalog/140_lookup_by_scan.sql
catalog/141_register_item_duplicate_sku.sql          (XFAIL D-A-04)
catalog/142_activate_item_price_history.sql           (XFAIL D-A-05)
inventory/100_apply_movement_normal_and_retry.sql
inventory/101_apply_movement_errors.sql
inventory/110_post_adjustment_normal_and_retry.sql
inventory/111_post_adjustment_errors.sql
inventory/112_post_adjustment_approver_branch_access.sql   (XFAIL D-A-03)
inventory/120_release_quarantine_normal_and_retry.sql
inventory/121_release_quarantine_errors.sql
inventory/130_allocate_to_web_normal_and_retry.sql
inventory/131_allocate_to_web_errors.sql
labels/100_queue_receipt_labels_normal_and_retry.sql
labels/101_queue_receipt_labels_errors.sql
labels/110_acknowledge_print_normal_and_retry.sql
labels/111_acknowledge_print_errors.sql
receiving/100_record_scan_matched_and_retry.sql
receiving/101_record_scan_unknown_never_adds_stock.sql
receiving/102_record_scan_errors.sql
receiving/103_record_scan_error_through_insert_exec.sql    (XFAIL D-A-07)
receiving/110_ambiguous_code_never_adds_stock.sql
receiving/120_resolve_scan_normal.sql
receiving/121_resolve_scan_errors.sql
receiving/122_resolve_scan_retry_is_not_idempotent.sql       (XFAIL D-A-01)
receiving/130_approve_scan_session_normal.sql
receiving/131_approve_scan_session_retry_is_not_idempotent.sql (XFAIL D-A-02)
receiving/132_approve_scan_session_errors.sql
receiving/140_post_scan_session_normal_and_retry.sql
receiving/141_post_scan_session_errors.sql
receiving/142_post_scan_session_errors.sql
receiving/143_post_scan_session_rejected_leaves_no_rows.sql
receiving/150_draft_item_received_into_quarantine.sql
receiving/151_post_scan_session_closes_container.sql          (XFAIL D-A-06)
```

Evidencia: `savia/docs/evidence/cp1-proc-audit/worker-a.md` (este archivo).
