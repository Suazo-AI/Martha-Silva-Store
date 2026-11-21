# Crítica de ADR-001

task_id: critic-adr001-20261112.
Modo: DISCOVER, solo lectura sobre archivos versionados.
Fuente: HEAD `915044e958bce52015a0d9a33f5f60df567c8ac9` (igual a source_sha).
Motor: contenedor `savia-sqlserver-dev`, SQL Server 16.0.4305.5 Developer.
Bases usadas: `SAVIA_T_CRITIC_1`, `SAVIA_T_CRITIC_2`, `SAVIA_T_CRITIC_3`, `SAVIA_T_CRITIC_R`; todas borradas al final.
Scripts de experimento: fuera del repositorio, en el scratchpad de la sesión (`e1_meta.sql` a `e7_xbranch.sql`, `oracle.sql`, `replica.sql`).
Este informe no es aceptación; decide el primary.

## Resumen

ADR-001 elige bien el estilo: estado por fila, un dueño por fila, cursor en el receptor.
Pero dos premisas fallan contra el código y el motor.

1. **La detección de restauración no funciona.** Tras restaurar, Change Tracking reutiliza los mismos números de versión para cambios distintos. El receptor salta esos cambios para siempre. Verificado (E3).
2. **"Cada fila tiene un único nodo que la escribe" es falso para el esquema actual.** Al menos 12 tablas tienen filas escritas por dos o tres nodos. Con escritores múltiples, el filtro de eco por contexto pierde cambios reales. Verificado (E2a, E7).

Sin corregir esto, las filas "Recuperación" y "Sync idempotente" de la tabla de aceptación de HANDOFF_FABLE no se pueden probar.

## Hallazgos

Formato: severidad, evidencia, escenario de fallo, chequeo que lo atrapa, cambio recomendado al ADR.

### F1. P0. La restauración reutiliza versiones de Change Tracking; la detección de D5 falla en silencio

- Evidencia: ADR-001 línea 55: "Una restauración se detecta porque la versión del nodo retrocede frente al cursor guardado".
- Experimento E3 (`e3_restore.sql` en `SAVIA_T_CRITIC_1`), salida real:

```text
E3 before backup 7 3FA4823B-3A88-4869-A8C0-D9F9560EA188
E3 original after 2 writes 9
E3 original changes 9 POST2
E3 original changes 8 POST1
E3 restored 7 CD25F88E-0585-4A25-80D2-65A55C440858 0 1
E3 restored changes 8 FORK1
E3 restored changes 9 FORK2
E3 original fork now 3FA4823B-3A88-4869-A8C0-D9F9560EA188
```

- Fallo: la nube tiene cursor 9 para la sucursal A. A se restaura a versión 7. Antes del siguiente ciclo de sync, A vende dos veces (versiones 8 y 9). La versión ya no retrocede: 9 = 9. La nube nunca pide las versiones 8 y 9 nuevas. Esas ventas no suben nunca.
- Si el ciclo de sync corre antes de las escrituras, sí ve 7 < 9. La detección depende de una carrera.
- `recovery_fork_guid` cambia con la restauración (3FA4… → CD25…). Es un detector determinista.
- Chequeo: semilla del simulador "backup en A, escribir N filas en el original y sincronizar, restaurar, escribir N filas, sincronizar"; el oráculo R1 (réplica) debe dar cero filas.
- Cambio al ADR: el cursor guarda el par `(recovery_fork_guid, versión)`. Si el fork cambia, el nodo entra en recuperación siempre, sin comparar versiones. Añadir también `database_id` y nombre lógico como señales secundarias, y una prueba roja con este escenario exacto.

### F2. P0. Muchas filas tienen más de un nodo escritor

- Evidencia: mapa de escrituras de V001 (procedimientos desde la línea 1977). Detalle en "Mapa de propiedad".
- Peores casos:
  - `credits.CreditTransfers`: una misma fila la escriben B (`usp_RequestTransfer` 2964), la nube (`usp_ApproveTransfer` 3000, `usp_CommitTransfer` 3088), A (`usp_LockTransferAtOrigin` 3040) y B (`usp_AcceptTransfer` 3149).
  - `credits.CreditAllocations`: `usp_CommitTransfer` cambia en la nube los saldos de A y de B (V001 3108-3118).
  - `credits.Credits.Status`: lo emite la sucursal emisora (`usp_IssueFromReturn` 2885) y lo cambia la sucursal que canjea (`usp_RedeemCredit` 2922, `Status='exhausted'`).
  - `inventory.StockReservations`, `webstore.Fulfillments`, `webstore.Orders`: insertadas en la nube (`usp_CreateReservedOrder` 3382), actualizadas en la sucursal (`usp_FulfillPaidOrder` 3511).
  - `inventory.StockBalances` pool `web`: lo cambian la nube (reserva) y la sucursal (asignar, despachar).
  - `sales.Sales`, `sales.SaleLines`: `usp_PostCreditReturn` en otra sucursal actualiza la venta de A (F3).
  - `security.Staff`: la nube es dueña, pero los intentos fallidos y el bloqueo se escriben en la sucursal.
- Experimento E2a (`e2_ct.sql`): escritura local sin contexto y luego escritura del aplicador con contexto, en la misma ventana. Salida real:

```text
E2a local insert then applier update I 2 1 0x0C10D0 10
E2a rows surviving echo filter (ctx IS NULL OR ctx<>cloud) 0
```

- Change Tracking guarda solo el último contexto por fila. El cambio local queda marcado como "vino de la nube". El filtro de eco lo descarta. El cambio local no sube nunca.
- E2b muestra el orden inverso: el último escritor local gana y la fila rebota completa. Ninguno de los dos órdenes es correcto con dos escritores.
- Chequeo: una prueba por tabla que falla si dos procedimientos con distinto `Node:Kind` escriben la misma fila; el oráculo R1 por dueño en el simulador.
- Cambio al ADR: convertir cada derecho que cruza nodos en filas de transición inmutables, una por escritor (ver "Máquina de estados del anticipo" y "Stock web"). Reemplazar el filtro por contexto con un filtro por dueño: un nodo solo envía filas cuyo dueño es él. Así el eco es imposible por construcción y el contexto sobra.

### F3. P1. Una sucursal puede devolver una venta de otra sucursal

- Evidencia: `usp_PostCreditReturn` (V001 3208) no compara `Sales.BranchId` con `@BranchId`.
- Experimento E7 (`e7_xbranch.sql` en `SAVIA_T_CRITIC_3`), salida real:

```text
E7 branch B returned branch A sale: ACCEPTED 2 B0000000-0000-0000-0000-00000000000B
```

- La sucursal B escribió `ReturnedQuantity=2` en una línea de venta de A y emitió un anticipo con `IssuingBranchId=B`.
- Fallo con D5: B escribe una fila que es de A. A nunca la recibe o la sobrescribe. Con D7 ("un host de sucursal solo ejecuta operaciones de su propia sucursal"), la regla queda solo en C#, lo que choca con D2.
- Chequeo: prueba T-SQL roja: devolución con `@BranchId` distinto de la venta debe fallar.
- Cambio al ADR: decidir si se permiten devoluciones cruzadas. Si sí, la devolución vive en B como fila propia (`SaleReversals` de B) y la venta de A no se modifica; `ReturnedQuantity` se deriva. Si no, el procedimiento rechaza.

### F4. P1. El aplicador de sync no puede usar los procedimientos

- Experimento E2c, salida real:

```text
E2c context+EXEC rejected 156 Incorrect syntax near the keyword 'EXEC'.
```

- `WITH CHANGE_TRACKING_CONTEXT` solo envuelve DML, no `EXEC`.
- Además, un aplicador basado en estado copia filas. Por diseño, escribe `StockBalances` y `CashEntries` con `MERGE` o `INSERT` directo.
- Esto contradice D2 al pie de la letra: "Los procedimientos SQL son el único lugar que cambia stock".
- Chequeo: prueba de arquitectura que lista los objetos con DML sobre tablas de invariantes y solo admite procedimientos de negocio y un único procedimiento aplicador por tabla.
- Cambio al ADR: D2 dice "los procedimientos son el único escritor que origina cambios; el aplicador solo copia filas cuyo dueño es otro nodo, sin recalcular". El aplicador vive en SQL (un procedimiento genérico por tabla, generado), no en C#.

### F5. P1. La instantánea de D5 paso 1 no está habilitada

- Evidencia E1 sobre el clon: `snapshot_isolation OFF`, `RCSI 0`.
- D5 paso 1 exige leer "en una instantánea consistente". Sin `ALLOW_SNAPSHOT_ISOLATION`, la lectura de `CHANGETABLE` puede cruzarse con la limpieza automática y con escrituras en curso; la versión mínima válida puede pasar al cursor entre dos lecturas.
- Azure SQL Database trae RCSI activo por defecto. Express no. Las lecturas de los procedimientos se comportan distinto en los dos (razonado; no probado en Azure).
- Chequeo: la migración de sync verifica `snapshot_isolation_state=1` y el host se niega a sincronizar si no.
- Cambio al ADR: fijar `ALLOW_SNAPSHOT_ISOLATION ON` y la misma configuración de RCSI en todos los nodos, y leer versión actual, versión mínima válida y cambios dentro de una transacción `SNAPSHOT`.

### F6. P1. Migraciones y TRUNCATE reinician Change Tracking

- Experimento E2f y E2g, salida real:

```text
E2f min_valid before/after re-enable 0 6 6
E2g truncate allowed 0 7 7
```

- Desactivar y activar el seguimiento de una tabla (necesario para cambiar su llave primaria) sube la versión mínima válida a la actual. `TRUNCATE` está permitido y hace lo mismo.
- Fallo: una migración V002 que cambia una PK invalida todos los cursores de esa tabla en todos los receptores. Sin manejo, el receptor falla o, peor, salta filas.
- Chequeo: cada ciclo compara cursor con `CHANGE_TRACKING_MIN_VALID_VERSION` por tabla y entra en reinicialización explícita; prueba con una migración de ejemplo.
- Cambio al ADR: definir la reinicialización completa de una tabla (envío del estado completo filtrado por dueño). Prohibir `TRUNCATE` sobre tablas sincronizadas con una prueba que busca `TRUNCATE` en migraciones.

### F7. P1. Una sucursal offline más allá de la retención pierde su cursor

- Razonado desde el motor: con `CHANGE_RETENTION = N días`, la limpieza borra cambios viejos y la versión mínima válida avanza. El ADR no fija retención ni acción.
- Fallo: la sucursal C pasa 10 días sin internet con retención 7. La nube no puede pedir cambios incrementales a C; C tampoco a la nube.
- Chequeo: semilla con un nodo offline más que la retención; debe terminar en reinicialización y oráculo R1 en cero.
- Cambio al ADR: retención mayor que el máximo offline aceptado más margen; alerta cuando un nodo se acerca; reinicialización explícita. Las tablas laterales de CT cuentan contra el límite de 10 GB de Express.

### F8. P1. Grandes atrasos: ventanas por versión rompen el orden de llaves foráneas

- Razonado: `CHANGETABLE(CHANGES …)` devuelve la última versión de cada fila y el estado actual, no el estado en una versión pasada.
- Fallo: un padre se inserta en versión 40 y se actualiza en 120; un hijo se inserta en 50. Un lote "hasta la versión 100" incluye el hijo y excluye el padre. La FK falla.
- Un solo lote de un mes en una transacción hace crecer el log en Express.
- Hay dos autorreferencias que exigen orden dentro de la tabla (E1): `catalog.Categories` y `inventory.StockMovements.ReversesMovementId`.
- Chequeo: semilla de rendimiento de HANDOFF_FABLE (50k/250k, 1M movimientos) con un nodo offline varios días; mide tamaño de log y oráculo.
- Cambio al ADR: leer todos los cambios en una instantánea, aplicar tabla por tabla en orden topológico, paginando por llave dentro de cada tabla, con varias transacciones. El receptor tolera padres sin hijos temporalmente; el cursor avanza una sola vez al final.

### F9. P1. D6 bloquea un contenedor entero offline por un solo código desconocido

- Evidencia: `usp_ResolveScan` (V001 2345) lanza 51306 "Primero registrar el codigo original para esta variante." si el identificador no existe. `usp_PostScanSession` (V001 2472) rechaza la sesión si queda algún escaneo sin `matched`.
- Fallo: llega un contenedor de 800 piezas con 3 códigos nuevos y no hay internet. Nada del contenedor suma stock, no solo los 3 códigos.
- D6 dice "un código desconocido queda en revisión y no suma stock". El código hace más que eso: bloquea todo.
- Contradicción adicional: V001 3776+ concede `usp_RegisterProduct`, `usp_RegisterItem`, `usp_ActivateItem` y `usp_ChangePrice` a `savia_manager_app`. Si ese rol existe en la sucursal, la sucursal crea catálogo.
- Chequeo: prueba "sesión con 1 código desconocido y 99 conocidos, offline": 99 suman stock, 1 queda en revisión. Prueba de permisos: en un nodo sucursal, `savia_manager_app` no puede ejecutar procedimientos de catálogo.
- Cambio al ADR: permitir publicar las líneas emparejadas y dejar las desconocidas como filas de revisión de la sucursal, keyed por código crudo. Exigir que el manifiesto del contenedor se registre en la nube antes del despacho. Separar roles de catálogo por tipo de nodo.

### F10. P1. Tablas sin dueño posible hoy

- `crm.Customers`: la caja necesita crear clientas offline (anticipos exigen cliente). El ADR no la asigna.
- `inventory.StockTransfers` y `StockTransferLines`: ningún procedimiento las escribe. Un traslado A→B toca dos sucursales.
- `security.Sessions`: local por naturaleza; no debe sincronizarse.
- `sales.CashCounts`, `CashCountLines`, `receiving.ImportContainers`, `ScanSessions`, `ImportManifestLines`, `security.Staff`: sin procedimiento que las cree. La prueba existente inserta `CashCounts` directo (`savia/db/tests/sales/010_cash_sale_idempotent_and_till_close.sql`).
- La base no sabe qué nodo es (hallazgo de CP0). Sin identidad local, el filtro por dueño no se puede escribir en SQL.
- Cambio al ADR: tabla de propiedad completa como anexo normativo (ver abajo), una tabla `sync.LocalNode` de una fila, y procedimientos de creación para cada tabla sin escritor.

### F11. P2. Borrados: solo llega la llave

- Experimento E2d y E2e, salida real:

```text
E2d insert+delete in window D 5 6
E2e columns returned for delete SYS_CHANGE_VERSION,SYS_CHANGE_CREATION_VERSION,SYS_CHANGE_OPERATION,SYS_CHANGE_COLUMNS,SYS_CHANGE_CONTEXT,Id
```

- Un borrado entrega solo la PK. Para tablas cuyo dueño se deriva de un padre (`SaleLines` → `Sales.BranchId`), el emisor no puede decidir el destino tras el borrado.
- Insertar y borrar en la misma ventana entrega un `D` de una fila que el receptor nunca tuvo.
- Hoy ningún procedimiento borra (sin `DELETE`, sin triggers, sin cascadas; E1). El riesgo aparece con archivado y limpieza.
- Cambio al ADR: prohibir `DELETE` físico en tablas sincronizadas (estado `voided` en su lugar), o lápidas con dueño. El aplicador trata un borrado de fila inexistente como no-op.

### F12. P2. D2: pruebas en Developer, despliegue en Express, versiones mezcladas

- Las pruebas corren en Developer (todas las funciones de Enterprise). Express limita a 10 GB por base y no tiene SQL Agent. Una prueba puede pasar usando algo que Express no tiene.
- N sucursales offline actualizan en momentos distintos. Con sync por estado, una columna nueva en la nube rompe el `INSERT` en una sucursal con V001.
- Sin Agent, la limpieza, los respaldos y las migraciones dependen del host.
- Chequeo: CI corre las pruebas T-SQL también en la imagen con `MSSQL_PID=Express`; prueba "nube V(n+1), sucursal V(n)" en el simulador.
- Cambio al ADR: versión de esquema en el saludo de sync; la nube acepta N-1; migraciones aditivas primero y destructivas una versión después; el host ejecuta migraciones al arrancar con tabla de versiones y checksum.

### F13. P2. El ADR no define el oráculo

- D9 promete "una consulta que devuelve cero filas". No hay predicados.
- Escritos y probados abajo (E4-E6). Devuelven cero filas en un escenario completo y detectan cada corrupción inyectada.

### F14. P2. Change Tracking en Express y Azure SQL no está probado aquí

- ADR-001 línea 47 lo afirma. No hay instancia Express ni Azure disponible y la tarea prohíbe red.
- UNKNOWN. Chequeo: correr `e2_ct.sql` y `e3_restore.sql` en un contenedor Express y en una base Azure de prueba antes de aceptar D5.

### F15. P3. Restauración de la nube y comparación entre nubes

- El ADR solo habla de restaurar un nodo. Si se restaura la nube, las sucursales tienen cursores sobre versiones de la nube que se reutilizarán (F1), y las filas de la nube escritas después del respaldo se pierden aunque las sucursales las tengan.
- La comparación de réplicas con `EXCEPT` entre bases solo funciona en una misma instancia. Azure SQL Database no admite consultas entre bases.
- Cambio al ADR: la nube también guarda su `recovery_fork_guid` por par; tras restaurar, re-pide todo lo que es de las sucursales y re-publica lo suyo. El oráculo de réplica se calcula por digestos exportados por nodo.

## Mapa de propiedad de las 77 tablas

Leyenda: **N** nube, **S** sucursal dueña (por `BranchId` o `LocationId`, directo o por el padre), **L** local, no se sincroniza. **X** conflicto hoy: varios nodos escriben la misma fila.

| Tabla | Dueño propuesto | Conflicto hoy |
| --- | --- | --- |
| core.Currencies | N | |
| core.Branches | N | |
| core.Locations | N | |
| core.SystemSettings | N | |
| security.Staff | N (identidad) | X: bloqueo e intentos fallidos se escriben en S; separar en `StaffSignInState` de S |
| security.Roles | N | |
| security.StaffRoles | N | |
| security.StaffBranchAccess | N | |
| security.Sessions | L | |
| security.BranchAssignmentAudit | N | |
| crm.Customers | sin decidir | X: alta offline en S, edición en N |
| sourcing.Suppliers | N | |
| catalog.Categories | N | autorreferencia |
| catalog.Brands | N | |
| catalog.Sizes | N | |
| catalog.Colors | N | |
| catalog.Products | N | X si `savia_manager_app` existe en S |
| catalog.Items | N | X: `ActivateItem`, `ChangePrice`, `RegisterItem` concedidos a manager |
| catalog.ItemIdentifiers | N | |
| catalog.ItemImages | N | |
| catalog.PriceHistory | N | |
| inventory.StockBalances (pools de tienda) | S | |
| inventory.StockBalances (pool web) | S | X: N reserva, S asigna y despacha |
| inventory.StockMovements | S (por `LocationId`) | N escribe movimientos de reserva web |
| inventory.StockAdjustments | S | |
| inventory.StockTransfers | sin decidir | sin procedimientos |
| inventory.StockTransferLines | sin decidir | sin procedimientos |
| inventory.StockReservations | N | X: S actualiza al despachar |
| purchasing.PurchaseOrders | N | |
| purchasing.PurchaseOrderLines | N | |
| receiving.ImportContainers | N | sin procedimiento de alta |
| receiving.ImportManifestLines | N | sin procedimiento de alta |
| receiving.ScanSessions | S | sin procedimiento de alta |
| receiving.ScanEvents | S | |
| purchasing.GoodsReceipts | S | |
| purchasing.GoodsReceiptLines | S | |
| sales.Sales | S | X: devolución desde otra S (F3) |
| sales.SaleLines | S | X: `ReturnedQuantity` desde otra S (F3) |
| sales.SaleTenders | S | |
| sales.SaleReversals | S (la que devuelve) | |
| sales.SaleReversalLines | S | |
| sales.StockExceptionReviews | S | |
| sales.CashRegisters | N | |
| sales.CashTills | S | |
| sales.CashEntries | S | |
| sales.CashCounts | S | sin procedimiento de alta |
| sales.CashCountLines | S | sin procedimiento de alta |
| sales.CashClosures | S | |
| credits.Credits | S emisora | X: `Status` lo cambia la S que canjea |
| credits.CreditAllocations | S de `BranchId` | X: `CommitTransfer` escribe A y B en N |
| credits.CreditMovements | S de `BranchId` | X: `CommitTransfer` las inserta en N |
| credits.CreditTransfers | partir en transiciones | X: B, N, A, N, B escriben la misma fila |
| credits.CreditRedemptions | S de `BranchId` | |
| webstore.Orders | N | X: S cambia estado al despachar |
| webstore.OrderAddresses | N | |
| webstore.Carts | N | |
| webstore.CartLines | N | |
| webstore.OrderLines | N | |
| webstore.Payments | N | |
| webstore.Fulfillments | partir | X: N inserta, S actualiza |
| labels.Printers | S | |
| labels.Templates | N | |
| labels.PrintJobs | S | |
| labels.PrintAttempts | S | |
| accounting.CloseDocuments | S | |
| accounting.CloseDocumentLines | S | |
| accounting.ExportJobs | S crea | X si el envío al contador corre en N (`MarkExportSent`) |
| accounting.Accounts | N | |
| accounting.JournalEntries | UNKNOWN | `PostJournal` no indica nodo |
| accounting.JournalLines | UNKNOWN | igual |
| sync.Nodes | N | |
| sync.Outbox | L | |
| sync.EventDeliveries | L | |
| sync.Inbox | L | |
| sync.Cursors | L (del receptor) | |
| sync.SyncErrors | L | |
| audit.Operations | nodo de origen | |
| audit.EntityChanges | nodo de origen | |

Tablas con más de un procedimiento escritor (de `writemap.py` sobre V001): `CreditAllocations` (Accept, Commit, IssueFromReturn, Lock, Redeem), `CreditTransfers` (Request, Approve, Lock, Commit, Accept, CancelUnblocked), `Credits` (IssueFromReturn, Redeem), `StockBalances` (vía `ApplyMovement` desde venta, recepción, asignación, reserva, despacho, ajuste, liberación, devolución), `StockReservations` (Create, Fulfill), `Orders` (Create, RecordVerifiedPayment, Fulfill), `Fulfillments` (Create, Fulfill), `Sales`/`SaleLines` (PostSale, PostCreditReturn), `Items` (RegisterItem, ActivateItem, ChangePrice), `ExportJobs` (CloseTill, QueueExport, MarkExportSent), `PrintJobs` (Queue, Ack), `ScanSessions` (Approve, Post), `CashTills` (Open, Close).
Varios escritores en el mismo nodo no son un problema. El conflicto es cuando corren en nodos distintos, marcado con X.

## Máquina de estados del anticipo, con un escritor por transición

Principio: ninguna fila cambia en dos nodos. Cada transición es una fila nueva, con PK = `TransferId`, escrita por un solo nodo.

| Paso | Fila nueva | Escritor | Efecto en saldo |
| --- | --- | --- | --- |
| 1 Solicitar | `TransferRequest(TransferId, CreditId, From=A, To=B, Amount)` | B | ninguno |
| 2 Aprobar | `TransferApproval(TransferId, ApprovedBy)` | N | ninguno |
| 3 Despachar | `TransferDispatch(TransferId)` + `CreditMovement(A, -Amount, 'transfer_out', TransferId)` | A, en una transacción, solo si ve la aprobación y `Available(A) ≥ Amount` | baja A |
| 4 Recibir | `TransferReceipt(TransferId)` + `CreditMovement(B, +Amount, 'transfer_in', TransferId)` | B, solo si ve el despacho | sube B |
| Cancelar | `TransferCancel(TransferId)` | N, solo si no existe despacho | ninguno |

Saldos: `CreditAllocations(A)` solo lo escribe A; `(B)` solo B. `Credits.Status` se deriva, no se escribe.

Invariante de conservación por crédito:

`OriginalMinor = Σ Available(todas las sucursales) + Σ Redenciones posted + Σ Amount(despachos sin recepción)`

Ataques:

- **ACK perdido.** El emisor reenvía el estado de la fila. Recepción tiene PK = `TransferId`; el `MERGE` del aplicador no duplica. Movimiento con PK determinista (`TransferId` + tipo) tampoco.
- **Entrega duplicada.** Igual que arriba. Oráculo K1' detecta un doble `transfer_in`.
- **Reorden.** B ve la recepción solicitada antes que el despacho: el paso 4 exige que exista el despacho (FK). El aplicador aplica padres antes que hijos (F8).
- **Restaurar un respaldo viejo en A.** A pierde el despacho y el `-Amount`. Su saldo local vuelve a tener el monto. Si A canjea, se gasta dos veces. Defensa: fork GUID cambiado (F1) → A entra en recuperación, no canjea, y re-descarga de la nube **sus propias filas** (despacho, movimientos, redenciones) antes de reabrir. El ADR no dice que las filas de la sucursal bajen de vuelta a su dueño; hay que añadirlo. Ventas hechas en A después del último sync y antes del desastre se pierden en la base; solo el comprobante de caja las prueba.
- **Restaurar un respaldo viejo en B.** B pierde la recepción y sus redenciones posteriores. Al re-aplicar el despacho, la recepción se recrea con la misma PK (bien). Pero redenciones perdidas devuelven dinero canjeable. Misma defensa: recuperación por fork GUID y re-descarga de filas propias.
- **Ambas offline.** A puede despachar offline si ya vio la aprobación. El monto queda en tránsito; la conservación se mantiene. B no puede recibir hasta ver el despacho. Coincide con la guía: "No hay transferencia offline nueva entre sucursales desconectadas" (`SAVIA_DB_GUIA_INSTALACION.md`).
- **Canje concurrente en A y B.** Cada uno solo gasta su propia asignación. No hay doble gasto mientras cada asignación tenga un escritor.

Hoy `usp_CommitTransfer` (V001 3088) viola esto: mueve `HeldMinor` de A a B en la nube. Coincide con ADR-001 línea 59.

## Stock web con un solo escritor

Propuesta:

- La sucursal es dueña del pool `web` de sus ubicaciones. Solo ella cambia su `OnHand`: asignar (tienda → web), despachar, devolver a tienda.
- La nube no toca `StockBalances`. Escribe filas inmutables: `WebReservation(Id, OrderId, ItemId, LocationId, Qty)` y `WebReservationRelease(ReservationId)`.
- La sucursal escribe `WebFulfillment(ReservationId)` y el movimiento de salida del pool web en una transacción.
- Disponible web, calculado en la nube: `OnHand(web, replicado) − Σ reservas activas sin despacho`.
- Retirar stock del pool web: la sucursal no lo hace sola. Pide; la nube baja el techo y responde con `WebCeilingRelease`; solo entonces la sucursal mueve stock a tienda. Evita que la nube reserve unidades que la sucursal ya retiró offline.
- Sobreventa acotada: la nube solo reserva contra el último `OnHand(web)` que vio. Como solo la sucursal lo baja y solo tras liberación de la nube (o despacho de una reserva), la nube nunca ve más del que existe.
- Oráculo W1: para cada (ítem, ubicación), `Σ reservas activas + Σ despachadas sin movimiento ≤ OnHand(web) + Σ despachos ya movidos`.

## Oráculo de conservación

Archivo: `oracle.sql` en el scratchpad. Cada consulta devuelve violaciones. Cero filas en todas = consistente.

```sql
-- S1 saldo = suma de movimientos
SELECT 'S1' chk, b.ItemId, b.LocationId, b.Pool, b.OnHand, b.Reserved, m.on_sum, m.res_sum
FROM inventory.StockBalances b
FULL JOIN (SELECT ItemId,LocationId,Pool,SUM(OnHandDelta) on_sum,SUM(ReservedDelta) res_sum FROM inventory.StockMovements GROUP BY ItemId,LocationId,Pool) m
  ON m.ItemId=b.ItemId AND m.LocationId=b.LocationId AND m.Pool=b.Pool
WHERE ISNULL(b.OnHand,0)<>ISNULL(m.on_sum,0) OR ISNULL(b.Reserved,0)<>ISNULL(m.res_sum,0);
-- S2 sin negativos
SELECT 'S2' chk, ItemId, LocationId, Pool, OnHand, Reserved FROM inventory.StockBalances WHERE OnHand<0 OR Reserved<0 OR Reserved>OnHand;
-- S3 reservado = reservas activas
SELECT 'S3' chk, b.ItemId, b.LocationId, b.Pool, b.Reserved, r.q FROM inventory.StockBalances b
FULL JOIN (SELECT ItemId,LocationId,Pool,SUM(Quantity) q FROM inventory.StockReservations WHERE Status='active' GROUP BY ItemId,LocationId,Pool) r
  ON r.ItemId=b.ItemId AND r.LocationId=b.LocationId AND r.Pool=b.Pool
WHERE ISNULL(b.Reserved,0)<>ISNULL(r.q,0);
-- S4 ningún movimiento deja negativo
SELECT 'S4' chk, Id, OnHandAfter FROM inventory.StockMovements WHERE OnHandAfter<0 OR ReservedAfter<0;
-- C1 esperado del cierre = suma de entradas de caja
SELECT 'C1' chk, c.TillId, c.ExpectedMinor, e.s FROM sales.CashClosures c
OUTER APPLY (SELECT SUM(DeltaMinor) s FROM sales.CashEntries WHERE TillId=c.TillId) e
WHERE c.ExpectedMinor<>ISNULL(e.s,0) OR c.DifferenceMinor<>c.CountedMinor-c.ExpectedMinor;
-- C2 pagos en efectivo = entradas 'sale'
SELECT 'C2' chk, s.TillId, t.tend, e.ent FROM sales.Sales s
CROSS APPLY (SELECT SUM(AmountMinor) tend FROM sales.SaleTenders WHERE SaleId=s.Id AND TenderKind='cash') t
OUTER APPLY (SELECT SUM(ce.DeltaMinor) ent FROM sales.CashEntries ce JOIN sales.SaleTenders st ON st.Id=ce.SaleTenderId WHERE st.SaleId=s.Id AND ce.Kind='sale') e
WHERE ISNULL(t.tend,0)<>ISNULL(e.ent,0);
-- C3 ninguna entrada después del cierre
SELECT 'C3' chk, e.Id FROM sales.CashEntries e JOIN sales.CashClosures c ON c.TillId=e.TillId WHERE e.CreatedAt>c.ClosedAt;
-- K1 conservación del anticipo
SELECT 'K1' chk, c.Id, c.OriginalMinor, a.av, a.he, r.red FROM credits.Credits c
OUTER APPLY (SELECT SUM(AvailableMinor) av,SUM(HeldMinor) he FROM credits.CreditAllocations WHERE CreditId=c.Id) a
OUTER APPLY (SELECT SUM(AmountMinor) red FROM credits.CreditRedemptions WHERE CreditId=c.Id AND Status='posted') r
WHERE c.OriginalMinor<>ISNULL(a.av,0)+ISNULL(a.he,0)+ISNULL(r.red,0);
-- K2 asignación = suma de movimientos
SELECT 'K2' chk, a.CreditId, a.BranchId, a.AvailableMinor, a.HeldMinor, m.av, m.he FROM credits.CreditAllocations a
OUTER APPLY (SELECT SUM(AvailableDeltaMinor) av,SUM(HeldDeltaMinor) he FROM credits.CreditMovements WHERE CreditId=a.CreditId AND BranchId=a.BranchId) m
WHERE a.AvailableMinor<>ISNULL(m.av,0) OR a.HeldMinor<>ISNULL(m.he,0);
-- K3 sin saldos negativos
SELECT 'K3' chk, CreditId, BranchId FROM credits.CreditAllocations WHERE AvailableMinor<0 OR HeldMinor<0;
-- K4 lo retenido lo explican transferencias abiertas
SELECT 'K4' chk, a.CreditId, a.BranchId, a.HeldMinor, ISNULL(o.h,0)+ISNULL(d.h,0) expected FROM credits.CreditAllocations a
OUTER APPLY (SELECT SUM(AmountMinor) h FROM credits.CreditTransfers WHERE CreditId=a.CreditId AND FromBranchId=a.BranchId AND Status='origin_locked') o
OUTER APPLY (SELECT SUM(AmountMinor) h FROM credits.CreditTransfers WHERE CreditId=a.CreditId AND ToBranchId=a.BranchId AND Status='in_transit') d
WHERE a.HeldMinor<>ISNULL(o.h,0)+ISNULL(d.h,0);
-- K5 estado coherente con el saldo
SELECT 'K5' chk, c.Id, c.Status, a.left_ FROM credits.Credits c
OUTER APPLY (SELECT SUM(AvailableMinor+HeldMinor) left_ FROM credits.CreditAllocations WHERE CreditId=c.Id) a
WHERE (c.Status='exhausted' AND ISNULL(a.left_,0)<>0) OR (c.Status='active' AND ISNULL(a.left_,0)=0);
-- K6 canje solo donde hay asignación
SELECT 'K6' chk, r.Id FROM credits.CreditRedemptions r
WHERE NOT EXISTS(SELECT 1 FROM credits.CreditAllocations a WHERE a.CreditId=r.CreditId AND a.BranchId=r.BranchId);
```

Réplica (R1, archivo `replica.sql`): para cada una de las 77 tablas, `EXCEPT` en ambas direcciones entre dos bases, con todas las columnas salvo `RowVersion`. En producción se añade el filtro por dueño del mapa de arriba: la nube contra cada sucursal solo en las filas de esa sucursal.

Con el rediseño del anticipo, K1 pasa a K1': sumar también `Σ Amount(despachos sin recepción)`, y K4 desaparece.

### Pruebas del oráculo

Escenario E4 (`e4_scenario.sql` en `SAVIA_T_CRITIC_2`): stock en A, abrir dos cajas, venta en efectivo en A, devolución a crédito, transferencia A→B completa (solicitar, aprobar, bloquear, ACK simulado, confirmar, aceptar), venta en B pagada con anticipo y efectivo, asignar 3 a web, pedido web, pago, despacho en A, arqueo y cierre en A.
Salida: `sale ok`, `return ok`, `transfer ok`, `credit sale ok`, `web ok`, `close ok`.
Filas creadas: 9 movimientos, 4 entradas de caja, 6 movimientos de crédito, 2 asignaciones, 1 redención, 1 reserva, 1 cierre.
Oráculo: las 13 consultas devuelven cero filas.

E5: misma base, dentro de una transacción revertida, +1 a un saldo de tienda, +1 a una entrada de caja de venta, +1 a una asignación. Salida real:

```text
S1 00000000-0000-0000-0000-0000000017E1 A0000000-0000-0000-0000-0000000000A1 store 7 0 6 0
C1 13E63745-912A-432C-885E-06D35B5F6198 340000 340001
C2 13E63745-912A-432C-885E-06D35B5F6198 240000 240001
K1 9B6C6CC9-30E0-4AC2-A53C-49844FE10FDE 120000 70001 0 50000
K2 9B6C6CC9-30E0-4AC2-A53C-49844FE10FDE A0000000-0000-0000-0000-00000000000A 50001 0 50000 0
```

E6: `SAVIA_T_CRITIC_3` restaurada de `SAVIA_T_CRITIC_2`. R1 idéntico: 0 diferencias en 77 tablas. Tras −1 en una asignación y cambiar `ModifiedAt` de una caja en la copia:

```text
R1 [sales].[CashTills] 1 1
R1 [credits].[CreditAllocations] 1 1
R_TABLES_COMPARED 77
```

Límites del oráculo:

- K4 solo se ejercitó con la transferencia en estado final `accepted`; los estados intermedios no se probaron.
- S3, W1 y los estados de devolución con efectivo no tienen escenario.
- El escenario corre en una sola base; no prueba sync entre nodos.

## D6: análisis

Ver F9. Además:

- Una rebaja de precio urgente sin internet es imposible. Es una decisión de Martha, no técnica.
- `UQ_Items_Product_Variant` trata NULL como igual (CP0): dos variantes sin talla del mismo producto chocan; la nube lo rechaza, pero la sucursal no puede ni proponerlo.
- La nube puede desactivar un ítem mientras la sucursal publica una recepción. `usp_PostScanSession` manda esas piezas a cuarentena (V001 2472+). Correcto, pero el ADR no lo menciona.
- Veredicto: D6 sirve si el manifiesto llega a la nube antes que el contenedor a la tienda y si se permite publicación parcial. Sin eso, es demasiado restrictivo para importaciones.

## D2: análisis

Ver F4 y F12. Además:

- No hay procedimiento para crear `CashCounts`. La prueba de caja lo inserta directo. Si C# hace lo mismo, D2 queda refutado por su propia tabla de refutación.
- La regla "solo operaciones de la propia sucursal" (D7) no está en los procedimientos (F3). Si vive solo en C#, es una regla de ventas en C#.

## Contra la tabla de aceptación de HANDOFF_FABLE

| Fila | Estado con ADR-001 tal como está |
| --- | --- |
| SQL instalable | Probado en Developer (CP0). Express y Azure no probados (F14). |
| Escaneo | Bloqueo de contenedor entero por un código (F9). |
| Venta offline | Compatible con D4. `PostSale` rechaza venta con stock corto (CP0); política pendiente de Martha. |
| Sync idempotente | No demostrable mientras haya filas con varios escritores (F2). El oráculo R1 existe ahora. |
| Anticipos | `CommitTransfer` viola un escritor por fila (F2). Máquina propuesta arriba. |
| Caja y contabilidad | Oráculo C1-C3 pasa en una base. Dueño de `ExportJobs` y `JournalEntries` sin decidir. |
| Etiquetas | Tablas de sucursal; sin conflicto detectado. No probado. |
| Privilegios | Devolución cruzada aceptada (F3); grants de catálogo a manager (F9). |
| Recuperación | La detección propuesta falla (F1). Falta re-descarga de filas propias tras restaurar. |
| Rendimiento | Sin plan de lotes ni de log (F8); límite de 10 GB no medido. |

El control 4 de HANDOFF_FABLE pide desconectar A y B, perder ACK, restaurar una base local vieja y repetir canjes concurrentes. Con F1 y F2 abiertos, ese control no se puede pasar.

## Respuestas a las 8 preguntas

1. Change Tracking: ver F1, F2, F4-F8, F11, F14. Verificado: eco con último contexto (E2a/E2b), contexto no envuelve `EXEC` (E2c), borrados solo con PK (E2d/E2e), reinicio por desactivar/activar y `TRUNCATE` (E2f/E2g), reutilización de versiones tras restaurar y cambio de `recovery_fork_guid` (E3), snapshot apagado (E1). Razonado: orden de FK con lotes, retención, atraso grande, desajuste de esquema. UNKNOWN: Express y Azure.
2. Mapa de propiedad: tabla de 77 filas arriba; 12 tablas con conflicto X.
3. Máquina de estados del anticipo: arriba, con invariante K1' y siete ataques.
4. Stock web: arriba, con W1.
5. D6: F9 y sección D6. Demasiado restrictivo tal como está escrito en el código.
6. D2: F4, F12 y sección D2.
7. Oráculo: arriba, ejecutado y con detección comprobada.
8. Errores y faltas del ADR: F1-F15 y tabla de aceptación.

## Lo que no se probó

- Ninguna sincronización real entre nodos; no existe código de sync.
- Express, Azure SQL Database y su soporte de Change Tracking.
- Concurrencia real (dos sesiones a la vez).
- Rendimiento con 50k/250k/1M filas.
- `PostJournal`, `MarkExportSent` y su nodo de ejecución.

## Limpieza

Bases `SAVIA_T_CRITIC_1`, `_2`, `_3`, `_R` borradas con `python savia/tools/db/saviadb.py drop`.
Archivos de respaldo de prueba en el contenedor (`/var/opt/mssql/data/SAVIA_T_CRITIC_1.bak`, `SAVIA_T_CRITIC_2.bak`) borrados.
