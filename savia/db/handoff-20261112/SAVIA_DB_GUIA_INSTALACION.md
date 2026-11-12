# SAVIA — Base de datos v0.1, diseño completo de referencia

**Estado:** baseline *greenfield* para evaluación local y revisión de arquitectura. **No es un release aprobado para producción.**

## Entregables

- `SAVIA_DB_SQLServer2022_COMPLETA.sql`: instalador para una **base nueva `SAVIA_DB`** en SQL Server 2022 (Developer/Standard/Enterprise según licencia). Incluye `CREATE DATABASE`, todos los esquemas, tablas, índices, procedimientos, vistas y roles.
- `SAVIA_DB_AzureSQL_Instalar_En_BD_Existente.sql`: mismo modelo pero **sin `CREATE DATABASE` ni `USE`**. Conectarse directamente a una base Azure SQL Database nueva antes de ejecutar.
- `SAVIA_DB_Verificar_Instalacion.sql`: verifica el recuento de los objetos creados (metadata). No valida reglas de negocio.
- `SAVIA_DB_Prueba_Smoke_Rollback.sql`: ejercicio transaccional con datos sintéticos; **finaliza con `ROLLBACK`**, sin persistirlos si se ejecuta completamente. Incluye una simulación de confirmación de Azure, no comunicación real entre nodos.
- `VALIDACION_ESTATICA.txt`, `QA_PROCEDIMIENTOS.txt`: resultados de herramientas de inspección estructural, **no de SQL Server**.

## Instalación rápida con SSMS (solo BD nueva)

1. Abrir SSMS y conectarse a **SQL Server 2022** con permisos de creación de base y DDL.
2. En **File > Open > File**, abrir `SAVIA_DB_SQLServer2022_COMPLETA.sql`.
3. Revisar primero el script; ejecutarlo con **Execute** (`F5`) en una instancia de desarrollo vacía. El script crea/usa la BD `SAVIA_DB`. **No ejecutarlo sobre la base legada.**
4. Abrir `SAVIA_DB_Verificar_Instalacion.sql` en la BD `SAVIA_DB` y ejecutar. Debe mostrar 15 esquemas, 77 tablas, 68 índices adicionales, 150 FKs, 151 restricciones CHECK, 41 procedimientos, 5 vistas, 4 TVPs y 9 roles.
5. Ejecutar `SAVIA_DB_Prueba_Smoke_Rollback.sql` en la misma BD. Debe terminar con `SAVIA: prueba revertida sin persistir datos.` No ejecutar este archivo en una base con datos importantes sin revisar y aprobar su contenido.

> Los instaladores utilizan `GO` (batch delimiter reconocido por SSMS/sqlcmd) y **no están diseñados para re-ejecución parcial**. En caso de error durante la instalación, inspeccionar y reparar con migraciones versionadas, o recrear **solo** la base de desarrollo de forma explícita. **No eliminan bases ni tablas existentes.**

## Esquemas

| Esquema | Propósito | Tablas |
|---|---|---:|
| `core` | Sucursales, ubicaciones, monedas y configuración | 4 |
| `security` | Personal, permisos, sesiones y auditoría de asignación | 6 |
| `crm` | Clientes | 1 |
| `sourcing` | Proveedores | 1 |
| `catalog` | Productos, **variantes**, identificadores, imágenes, historial de precios | 9 |
| `inventory` | Balances, movimientos, ajustes, transferencias y reservas | 6 |
| `purchasing` | Órdenes de compra y comprobantes de recepción | 4 |
| `receiving` | Contenedores importados, manifiesto, sesiones y lecturas | 4 |
| `sales` | POS, devoluciones, cobros, turnos, arqueos y cierres | 12 |
| `credits` | Anticipos por devolución, saldos, canjes y transferencias entre sucursales | 5 |
| `webstore` | Pedido, carrito, dirección, pago, líneas, despacho | 7 |
| `labels` | Impresoras, plantillas, trabajos y reintentos de impresión | 4 |
| `accounting` | Resumen del cierre, envío y contabilidad básica | 6 |
| `sync` | Nodos offline, outbox, inbox, delivery, cursor, errores | 6 |
| `audit` | Registro idempotente y auditoría de entidades | 2 |
| **Total** | | **77** |

## Reglas esenciales

### Catálogo y escaneo

- `catalog.Products` = modelo de prenda; `catalog.Items` = variante vendible (modelo, talla y color) con SKU único. `catalog.ItemIdentifiers` guarda el **código original del proveedor** como texto binario-colacionado, preservando ceros a la izquierda. Un código puede identificar una variante que existe en dos sucursales; **no se crea una fila por cada prenda**.
- Escanear `receiving.usp_RecordScan` registra lecturas idempotentes dentro de una sesión. Un código desconocido se marca para revisión; **no aumenta inventario** hasta resolverlo, aprobar la sesión y ejecutarse `receiving.usp_PostScanSession`.
- La recepción registra cantidades en `inventory.StockBalances`, crea `inventory.StockMovements` y deja trabajos en `labels.PrintJobs`. Un worker **local .NET** se encarga de generar ZPL/TSPL/Windows spooler, imprimir y confirmar mediante `labels.usp_AcknowledgePrint`. SQL por sí solo **no imprime**.
- SKU original y nombre de tienda se guardan como snapshots en el trabajo. Plantillas y driver de impresora deben configurarse para cada sucursal. Si no están configurados, el estado es `waiting_config`.
- Prendas sin costo o precio aprobado ingresan en `quarantine`; se habilitan con `catalog.usp_ActivateItem` e `inventory.usp_ReleaseQuarantine`, con aprobación local, **antes de estar disponibles para venta**.

### Inventario y e-commerce

- Existencias por `(ItemId, LocationId, Pool)`; pools `store`, `web`, `quarantine` distinguen disponibilidad. El stock en línea se asigna con `inventory.usp_AllocateToWeb` y Azure **no debe ofrecerlo** hasta confirmación del evento local.
- La compra web reserva stock, registra pago **solo mediante backend que verificó la pasarela** y despacha. Nunca permitir que el navegador invoque directamente SPs de pagos.
- Las operaciones de stock exigen GUID idempotentes, transacciones, restricciones de no-negatividad e historial de movimientos. Los ajustes no eliminan movimientos históricos.

### Anticipos entre sucursales (offline-first)

- La devolución validada con `sales.usp_PostCreditReturn` origina un anticipo mediante `credits.usp_IssueFromReturn` y saldo exclusivo en la sucursal que lo recibe.
- A→B: solicitar → aprobar por supervisor diferente → `credits.usp_LockTransferAtOrigin` en A (consume `AvailableMinor` y crea `HeldMinor`) → Azure comprueba evento aplicado en inbox → `credits.usp_CommitTransfer` crea saldo **retenido** en B → destino instala proyección de transferencia → `credits.usp_AcceptTransfer` libera monto para canje local.
- **No hay transferencia offline nueva entre sucursales desconectadas.** B solo puede gastar créditos cuyos derechos ya están instalados localmente. La aplicación orquestadora debe autenticar nodos y aplicar los eventos en orden/idempotentes; **SQL no incluye un agente de sincronización por red**.
- En cada instalación la tabla `sync.Nodes` y la configuración física del nodo deben representar topología real. Evitar replicar estados de crédito central indiscriminadamente a las cajas de las dos sucursales.

### Caja y contabilidad

- Un turno de caja registra ventas y cambios de caja. Al cierre, el arqueo captura denominaciones. `sales.usp_SubmitCashCount` y `sales.usp_CloseTill` calculan esperado, contado y diferencia, inmovilizan el turno y generan `accounting.CloseDocuments`, `accounting.CloseDocumentLines` y un trabajo `accounting.ExportJobs` de formato PDF para el contador.
- **El documento contable de cierre no es una segunda factura fiscal.** La emisión fiscal/IVA, numeración, fecha fiscal, reportes por medio de pago, reglas DGI y jurisdicción **deben validarse por contador/asesor tributario antes de producción**. El worker .NET todavía deberá construir el PDF y enviarlo al destinatario configurado. El SP solo encola el envío.
- `COGSMinor` se calcula con `catalog.Items.UnitCostMinor` **como snapshot**, aún no según FIFO/promedio móvil; necesita política de valoración aprobada. Los estados de resultados completos requieren gastos, impuestos, depreciaciones y conciliación: este modelo **no sustituye un ERP contable validado**.

### Sync

- Debe existir un **servidor de sucursal/servicio local** que posea escritura exclusiva para esa sucursal y un **nodo Azure**. La app registra operación de negocio y outbox juntos en una transacción; el worker sincroniza eventos `push`/`pull` y aplica inbox en transacción. La distribución funciona por destinatario/nodo, no por copia indiscriminada.
- `sync.usp_PullEvents` devuelve cambios paginados por secuencia para un nodo. Solo avanzar cursor tras aplicar lote local. Si la red cae después de procesar, el inbox idempotente permite reintento.
- No hay Redis ni SQL transactional replication. El backend de .NET debe implementar handlers explícitos de cada evento para poblar la proyección central y local, reconcilación, autenticación/mTLS, reintentos, expiración de pedidos y gestión de conflictos. La **topología real multi-nodo y tests de corte de energía quedan pendientes**.

## Relación con el modelo antiguo (`savia_internal`, 23 tablas)

El SQL proporcionado por el usuario es histórico y **no se transforma automáticamente**. Algunos equivalentes nuevos:

| Legado | Nuevo |
|---|---|
| `Items` | `catalog.Products` + `catalog.Items` (variantes) + `catalog.ItemIdentifiers` |
| `Branches`, `Locations` | `core.Branches`, `core.Locations` |
| `Parties` | `crm.Customers`, `sourcing.Suppliers` (separados por dominio) |
| `Staff`, `Sessions`, `BranchAssignmentAudit` | `security.*` |
| `StockBalances`, `StockMovements`, `StockAdjustments` | `inventory.*` |
| `PurchaseOrders`, `PurchaseOrderLines`, `PurchaseReceipts`, `PurchaseReceiptLines` | `purchasing.*` + `receiving.*` |
| `Sales`, `SaleLines`, `SaleReversals`, `SaleReversalLines` | `sales.*` |
| `CashTills`, `CashEntries`, `CashCloses` | `sales.CashTills`, `sales.CashEntries`, `sales.CashClosures` |
| `Operations`, `StockExceptionReviews` | `audit.Operations`, `sales.StockExceptionReviews` |

Se necesita una **migración de datos separada**, con mapeo de claves, auditoría, validación de conciliación y pruebas de regresión, si existen datos históricos que preservar. No ejecutar las migraciones EF originales sobre este modelo nuevo. La API .NET debe usar un historial de migraciones nuevo/versionado cuando se adopte el esquema.

## Seguridad y límites operativos

- Se crean nueve roles SQL sin credenciales ni usuarios. La aplicación debe usar identidades individuales/Managed Identity y asignar los permisos requeridos, sin `db_owner` para cuentas runtime. Las funciones de negocio requieren **autorización de aplicación y separación por sucursal**, además de los GRANT SQL. `@ActorId` no sustituye autenticación.
- Instalación SQL Server 2022 local recomendada en entorno de desarrollo; revisar licencias, espacio en disco y backups cifrados para instalaciones comerciales. Para Azure SQL Database elegir nivel y pausas teniendo en cuenta la disponibilidad POS.
- Objetivo 50,000 productos / ~250,000 variantes **no está benchmarkeado**. Crear pruebas con datos reales o sintéticos, operaciones concurrentes, internet intermitente, reinicios de caja y 10,000 eventos pendientes.
- Índices actuales son un **punto de partida**. Ajustarlos tras medir consultas con `SET STATISTICS IO`, Query Store / execution plans, no por cantidad de filas solamente.
- La ejecución de los SPs y la impresión real **no fueron probadas en SQL Server** en esta sesión por falta de instancia/conexión.

## Evidencia de revisión disponible

- QA estático: **15 esquemas, 77 tablas, 68 índices adicionales, 150 FKs, 151 CHECK, 41 SPs, 5 vistas, 4 TVP**; inspección de claves e índices, referencias locales y argumentos a procedimientos: **cero errores estáticos detectados**.
- Una prueba de humo transaccional está escrita y lista para ejecutar en SSMS; **no está ejecutada**.
- No hay despliegue, migraciones aplicadas a base de datos, integración en .NET ni impresora configurada.
