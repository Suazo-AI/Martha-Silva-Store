# Cotización de servidor en la nube (J-3: cotizar, no contratar)

Fecha: 2026-11-11. Autor: agente primary. Nada contratado; ninguna cuenta creada.
Precios en USD o EUR sin impuestos, tomados de búsqueda web el 2026-11-11.
Cada precio marcado "estimado" debe confirmarse en la calculadora oficial antes de decidir.

## Qué necesita SAVIA

- API .NET 10 y SQL Server (el código usa SQL Server; cambiar de motor no entra en este programa).
- Una tienda, pocas cajas, horario de unas 12 horas al día; base pequeña (menos de 10 GB por años).
- Copias de seguridad automáticas y restauración a un punto en el tiempo.
- Mantenimiento por un agente Opus medio: menos piezas que operar es mejor.

## Opciones

| | A. Azure administrado | B. VPS Hetzner | C. Azure serverless |
| --- | --- | --- | --- |
| API | App Service B1 Linux, 1 núcleo, 1,75 GB | Mismo VPS | App Service B1 Linux |
| Base | Azure SQL provisionado, nivel DTU básico o S0 | SQL Server 2022 Express en contenedor (gratis, tope 10 GB por base) | Azure SQL serverless General Purpose |
| Costo mensual | ~USD 13 API + ~USD 5–15 base = **~USD 18–28** (estimado) | CPX31 4 vCPU 8 GB: €16,49 antes del alza de junio 2026 = **~€17–25** (estimado) | ~USD 0,52 por vCore-hora; 0,5 vCore × 360 h ≈ USD 94 + API = **~USD 107+** (estimado) |
| Copias y restauración | Incluidas, a un punto en el tiempo | Las configuramos nosotros | Incluidas |
| Parches, TLS, monitoreo | Del proveedor | Nuestros | Del proveedor |
| Riesgo principal | Precio DTU no verificado en esta búsqueda | Operación y copias quedan a cargo del agente; requiere aprobar Docker | Caro para una tienda con horario continuo |

Para desarrollo y pruebas: Azure SQL free offer da 100 000 vCore-segundos, 32 GB por base y por mes, sin caducar.
No alcanza para producción con 12 horas diarias de uso; sirve como staging.

## Recomendación del arquitecto

Opción A. Es la que menos piezas deja al agente de mantenimiento: copias, parches y TLS son del proveedor.
Costo estimado similar a B. Ruta de crecimiento: subir de nivel sin migrar.
Antes de decidir: confirmar en la calculadora de Azure la región (East US o South Central US) y el precio DTU.

## Lo que esto no autoriza

Ninguna cuenta, compra, despliegue ni SQL en producción. Jason decide y aprueba el gasto.

## Fuentes

- [Precios Azure SQL Database single](https://azure.microsoft.com/en-us/pricing/details/azure-sql-database/single/) (la página oficial no muestra cifras sin iniciar sesión)
- [Spendark: Azure SQL pricing explained (2026-09-07)](https://spendark.com/blog/azure-sql-pricing-explained/)
- [Azure SQL Database free offer](https://learn.microsoft.com/en-us/azure/azure-sql/database/free-offer)
- [Precios App Service Linux](https://azure.microsoft.com/en-us/pricing/details/app-service/linux/)
- [Kuberns: Azure pricing 2026](https://kuberns.com/blogs/azure-pricing/)
- [Hetzner: ajuste de precios](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/)
- [whtop: Hetzner CPX31 €16,49](https://www.whtop.com/plans/hetzner.com/128287)
- [Ediciones SQL Server 2022 en Linux](https://learn.microsoft.com/sql/linux/sql-server-linux-editions-and-components-2022)
- [Imagen Docker mssql-server](https://hub.docker.com/r/microsoft/mssql-server)
