# SAVIA interno

Actualizado: 2026-11-03. Aplicación privada de personal, separada de la tienda pública.
Entrar por [AGENT-START](docs/AGENT-START.md), [estado](docs/SAVIA-LATEST.md) y [mapa de código](docs/CODE-MAP.md).

El candidato implementa sesión/CSRF, roles, ámbito de sucursal, directorio, inventario, ventas,
recibos, recuperación de operaciones y abastecimiento. La UI comercial reside en `dev/savia-staff-ui/`;
los servicios y controles residen en `backend/src/Martha.Store.Api/Internal/`.
No reintroducir `/savia/` en la web pública ni confundir el contexto Store con Internal.

Alcance V1: un negocio y una sucursal operativa; roles Owner, Manager, Cashier e Inventory.
Las propuestas antiguas de más roles o negocios no amplían ese alcance.
Existe evidencia histórica Owner de UI a SQL; la [validación reciente](docs/testing-20261103/README.md)
prueba capas separadas y reproduce N5. No constituye aceptación completa del producto.

Siguiente: corregir el bloqueo de recibo inexistente y probar la venta por cajero con sus denegaciones,
sesión y aislamiento. [Contrato N1–N10](docs/delivery-20261031/NEXT-INCREMENT.md).
Estado de bases y permisos de ejecución: [DATABASE](docs/DATABASE.md).
Los documentos fechados de diseño/piloto permanecen como antecedentes; no son comandos pendientes de ejecutar.
