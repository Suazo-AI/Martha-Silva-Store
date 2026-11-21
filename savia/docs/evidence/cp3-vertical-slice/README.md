# CP3: slice vertical de la API contra SQL Server 2022

Fecha: 2026-11-12. Host: SUAZO-PC. Ejecutó: agente primary (Claude Fable 5.2).
SDK: .NET 10.0.402. Motor: SQL Server 2022 16.0.4305.5 en Docker.

## Resultado

El flujo completo corre por HTTP contra la base real, en un nodo de sucursal sin nube configurada.
8 pruebas, 0 fallidas, 0 omitidas (`dotnet test tests/Savia.Tests`, 30 s).

| Prueba | Qué demuestra |
| --- | --- |
| `Receive_100_scans_sell_offline_and_close_the_till` | 100 lecturas, 10 de ellas repetidas, suman 100 en una línea. Nada entra a stock antes de aprobar. Solo gerencia aprueba y publica. La etiqueta lleva el código original con ceros. La venta repetida no duplica. La venta deja un evento pendiente para la nube. Sin stock, la venta se rechaza y no deja filas. El arqueo cuadra con apertura + ventas en efectivo. El cierre repetido no duplica el documento contable. |
| `Unknown_code_is_recorded_but_never_becomes_stock` | Un código desconocido queda registrado, bloquea la aprobación y no suma stock. |
| `Staff_of_another_branch_cannot_operate_this_branch` | La cajera de B no opera en el host de A. La cajera de A no abre una caja de B. |
| `Calls_without_a_valid_session_are_rejected` | Sin sesión: 401. Contraseña mala y usuario inexistente dan la misma respuesta. Tras cerrar sesión el token muere. El token se guarda solo como hash. |
| `Branch_node_does_not_expose_catalog_writes` | El catálogo no se escribe en una sucursal. |
| `Each_layer_references_only_the_layers_it_may` | La regla de capas es una prueba. |
| `Only_infrastructure_talks_to_sql_server` | Solo Infrastructure usa SqlClient. |
| `The_api_publishes_its_contract` | `/openapi/v1.json` publica los endpoints del nodo. |

## Qué se construyó

- `src/Savia.Domain`: tipos y catálogo de errores. Sin dependencias.
- `src/Savia.Contracts`: los DTO de la API v1.
- `src/Savia.Application`: casos de uso. Autorizan y validan forma; no repiten reglas de stock ni de caja.
- `src/Savia.Infrastructure`: `SqlGateway` y los puertos. Las escrituras llaman procedimientos; las lecturas son `SELECT`.
- `src/Savia.Api`: un host con modo `Cloud` o `Branch`. Sesión por token; el token se guarda como hash.
- `db/migrations/V002__api_support.sql`: ids de rol fijos, hash de token de sesión, `usp_OpenScanSession`, `usp_RecordCashCount`.

## Cómo repetirlo

```bash
python savia/tools/db/saviadb.py up
python savia/tools/check.py
```

## Límites

- Un solo nodo. La sincronización entre sucursales y nube es CP4.
- "Offline" aquí significa que el host de sucursal no tiene ninguna dependencia de red configurada.
- No hay prueba de concurrencia ni de carga todavía.
- Las contraseñas usan PBKDF2-SHA256 con 600 000 iteraciones; falta flujo de alta y recuperación de usuarios.
- No hay impresora ni escáner reales: la etiqueta se prueba como trabajo en cola.
