# SAVIA interno: mapa de reutilización del core

Fecha: 2026-10-25. Documento de alcance; no implementación, despliegue ni ejecución de pruebas.
Base exacta: `f7e859bd0e6edf6bdef8b391b63589a212f0d088`.
Checkout observado: `d2ad2000c68c492618c15f5a601cca9a47e8a587`.
La comparación Git entre ambos no mostró cambios en `backend/`, `contracts/`, `tests/backend/` ni `global.json`.
El nuevo lote de código cloud debe revisarse por separado: sus cambios todavía no se atribuyen a este mapa.

## Qué reutilizar entero en su función actual

“Entero” significa conservar el comportamiento sintético y sus límites; no habilitarlo como API comercial.

| Ruta desde la raíz | Base reutilizable | Límite que se conserva |
| --- | --- | --- |
| [StoreDbContext.cs](../../backend/src/Martha.Store.Api/StoreDbContext.cs), [SaviaModels.cs](../../backend/src/Martha.Store.Api/SaviaModels.cs) | EF Core; DTOs y entidades de balance, reserva, intento, recibo y movimiento. | La autoridad fija de prueba no identifica empleados ni empresas. |
| [SaviaModel.cs](../../backend/src/Martha.Store.Api/SaviaModel.cs) | Restricciones de cantidades, importes, estado e inmutabilidad del libro sintético. | No sustituye políticas de acceso ni un modelo contable comercial. |
| [SaviaService.cs](../../backend/src/Martha.Store.Api/SaviaService.cs) | Catálogo SQL, reservar, consultar reserva, cancelar reserva, consultar intentos y movimientos. | Conservar claves/intentos, recibos originales y errores; no convertir cancelación en venta o devolución. |
| [ErpPort.cs](../../backend/src/Martha.Store.Api/ErpPort.cs) | Puerto de capacidades y operaciones SAVIA existentes; CGA cerrado cuando no está verificado. | Sin endpoint CGA inventado ni fallback después de un resultado desconocido. |
| [Program.cs](../../backend/src/Martha.Store.Api/Program.cs) | Rutas minimal API versionadas, validación y diagnósticos de vida/disponibilidad. | No hay controllers MVC separados; los handlers actuales son sintéticos, no una API privada con autorización. |
| [StoreDatabaseGuard.cs](../../backend/src/Martha.Store.Api/StoreDatabaseGuard.cs), [StoreDbContextFactory.cs](../../backend/src/Martha.Store.Api/StoreDbContextFactory.cs) | Guardas de destino sintético y configuración de contexto. | Development + opción sintética y prefijo de base son aislamiento de pruebas, nunca login o autorización. |
| [SyntheticOrders.cs](../../backend/src/Martha.Store.Api/SyntheticOrders.cs), [SyntheticSeed.cs](../../backend/src/Martha.Store.Api/SyntheticSeed.cs), [SaviaSyntheticSeed.cs](../../backend/src/Martha.Store.Api/SaviaSyntheticSeed.cs) | Compatibilidad V1 y seeds explícitos reproducibles para desarrollo. | Un `SyntheticOrder` reservado de una variante no es una venta facturada ni un pedido comercial completo. |
| [openapi-v1.json](../../contracts/openapi-v1.json), [openapi-v2.json](../../contracts/openapi-v2.json) | Contratos existentes y su distinción entre recibo de creación y estado actual. | Extensiones comerciales requieren contrato propio; no alterar silenciosamente V1/V2. |
| [dev/savia-harness/](../../dev/savia-harness/README.md) | Cliente de desarrollo con intento, clave y autoridad conservados ante resultado desconocido. | No es UI de personal ni sesión autenticada; no reutilizar su actor fijo como identidad real. |

## Qué extender o agregar para personal autenticado

| Área faltante | Trabajo necesario sobre la base |
| --- | --- |
| Autenticación y RBAC | Identidad de personal, sesión y revocación; roles/permisos y autorización del servidor por operación y recurso. Ocultar botones no aplica permisos. |
| Empresas y pertenencia | Empresas, membresías y ubicaciones propias; claves, relaciones, consultas e idempotencia delimitadas por empresa y actor autorizado. No confiar en un `businessId` enviado por el cliente. |
| CRM | Clientes y contactos, relaciones con empresa, acceso autorizado y reglas de datos personales. No importar pedidos/clientes del material recuperado. |
| Catálogo e inventario operativo | Productos/variantes y ubicaciones múltiples con autoridad aprobada; conservar `available = onHand - reserved` y restricciones de balance. Definir precios, moneda y políticas comerciales por separado. |
| Ventas | Documento de venta, líneas, snapshots de precios e importes del servidor, estados, actor y movimientos físicos correspondientes. No renombrar una reserva como venta aprobada. |
| Anulación y devoluciones | Definir transiciones y movimientos compensatorios de una venta; recepción de prendas y eventual reembolso son procesos distintos. No llamar a cancelar reserva para simular devolución o refund. |
| Compras y abastecimiento | Proveedores, órdenes de compra, líneas, recepción y movimientos de entrada trazables; no equivalen a liberar unidades reservadas. |
| Auditoría y operaciones | Registro por empleado/empresa y operación, trazabilidad de cambios y permisos; criterios de respaldo y recuperación antes de usar datos reales. |
| Frontend interno | Flujos privados de personal contra permisos del servidor; no republicar la caja separada `/savia/` ni convertir la tienda pública en administración. |

## Persistencia y pruebas que conservar

- Mantener la historia de [20261024223644_InitialSyntheticFoundation.cs](../../backend/src/Martha.Store.Api/Migrations/20261024223644_InitialSyntheticFoundation.cs) y [20261025010000_SaviaV2Ledger.cs](../../backend/src/Martha.Store.Api/Migrations/20261025010000_SaviaV2Ledger.cs), sus designers y [StoreDbContextModelSnapshot.cs](../../backend/src/Martha.Store.Api/Migrations/StoreDbContextModelSnapshot.cs).
- Los cambios de identidad, empresas, ventas y compras necesitan migraciones nuevas y revisión de relaciones/índices; no reescribir migraciones históricas ni ejecutar migraciones como parte de este documento.
- Reutilizar [GuardTests.cs](../../backend/tests/Martha.Store.Api.Tests/GuardTests.cs), [SaviaContractTests.cs](../../backend/tests/Martha.Store.Api.Tests/SaviaContractTests.cs) y [SaviaModelGuardTests.cs](../../backend/tests/Martha.Store.Api.Tests/SaviaModelGuardTests.cs) como regresión del corte original.
- Conservar [SqlServerIntegrationTests.cs](../../backend/tests/Martha.Store.Api.Tests/SqlServerIntegrationTests.cs) y [SaviaSqlServerIntegrationTests.cs](../../backend/tests/Martha.Store.Api.Tests/SaviaSqlServerIntegrationTests.cs); agregar casos de aislamiento entre empresas, permisos, actor e idempotencia de las nuevas operaciones.
- Para `f7e859bd0e6edf6bdef8b391b63589a212f0d088` se **reportaron 45 pruebas C# PASS y 21 SQL SKIPPED**. No se reejecutaron ni se reinterpretan las omisiones como SQL aprobado. El lote exportado de **45 archivos fuente** es un conteo distinto del número de pruebas.

## Fronteras de datos y significado

- La fixture SQL V2 usa una variante/ubicación y moneda **XXX**: son unidades de prueba, no dinero comercial ni stock autorizado.
- Los **40 productos / 120 variantes USD de muestra** de [build-inputs/static/catalog.js](../../build-inputs/static/catalog.js) pertenecen al simulador de tienda; no son el seed SQL ni la base de clientes/ventas interna.
- [dev/savia-demo-ui/model.mjs](../../dev/savia-demo-ui/model.mjs) conserva seis productos USD ficticios en memoria. Su aprobación, cancelación y recibo de demo no son implementaciones de venta, pago o devolución del backend.
- En V2, reservar aumenta `reserved`; cancelar una reserva libera lo retenido **sin aumentar `onHand`**. El recibo de creación puede seguir diciendo `active` por replay aunque el estado consultado ya sea `cancelled`.
- Una venta, una devolución física y un reembolso tienen reglas propias; ninguno se acredita por ese replay ni por el botón de pago de un simulador.
- No habilitar rutas sintéticas en producción para eludir la nueva autenticación. No declarar auth, CRM, empresas, ventas, compras, pagos o compatibilidad CGA implementados por conservar este core.

Revisión realizada sólo sobre fuentes y documentación: sin SQL, .NET, pruebas, navegador, instalación, credenciales ni cambios de backend.
