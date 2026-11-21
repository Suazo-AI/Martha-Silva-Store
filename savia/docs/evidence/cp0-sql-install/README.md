# CP0: el SQL del handoff ejecutado en SQL Server 2022 real

Fecha: 2026-11-12. Host: SUAZO-PC. Ejecutó: agente primary (Claude Fable 5.2).
Motor: SQL Server 2022 (RTM-CU27-GDR) 16.0.4305.5, Developer Edition, Linux, en Docker.
Imagen: `mcr.microsoft.com/mssql/server@sha256:cf8f0ab2ebe61feec2eed2629061a07d247f791c2a8ddda74a4ac9f06a291718`.
Fuente: [db/handoff-20261112](../../../db/handoff-20261112/), copiada sin editar; los 6 SHA-256 coinciden con `EVIDENCE.md`.

## Resultado

El instalador del handoff no instala tal como viene.
Con 7 correcciones con nombre, instala sin errores y el smoke test original pasa completo.

| Corrida | Qué se ejecutó | Resultado | Log |
| --- | --- | --- | --- |
| A | Script original, `sqlcmd` por defecto (camino documentado en el README del paquete) | 23 errores | [run-A](run-A-sqlcmd-default.txt) |
| B | Script original, `sqlcmd -I` (igual que SSMS) | 7 errores; 5 procedimientos no compilan | [run-B](run-B-sqlcmd-quoted-identifier-on.txt) |
| C | Línea base corregida, `sqlcmd -b` por defecto | exit 0, 0 errores | [run-C install](run-C-baseline-install.txt) |
| C verify | Script de verificación original | Falla: espera 150 llaves foráneas, hay 153 | [run-C verify](run-C-verify.txt) |
| C smoke | Smoke original, `sqlcmd` por defecto | Falla en el primer INSERT (Msg 1934) | [run-C smoke](run-C-smoke.txt) |
| C smoke -I | Smoke original, `sqlcmd -I` | exit 0; termina con `prueba revertida sin persistir datos` | [run-C smoke -I](run-C-smoke-quoted-identifier-on.txt) |

Conteo real de objetos: 15 esquemas, 77 tablas, 153 llaves foráneas, 151 CHECK, 68 índices, 41 procedimientos, 5 vistas, 4 tipos de tabla, 9 roles.
El texto fuente también contiene 153 `REFERENCES`; el número 150 del verificador está mal.

## Correcciones de instalación (línea base V001)

Las aplica [tools/db/build_baseline.py](../../../tools/db/build_baseline.py) sobre el archivo original.
Cada corrección debe coincidir exactamente una vez con el original, o la generación falla.
El resultado es [db/migrations/V001__baseline.sql](../../../db/migrations/V001__baseline.sql); no se edita a mano.

| ID | Objeto | Error real del motor | Corrección |
| --- | --- | --- | --- |
| F-001 | Todo el script | Msg 1934 en 16 índices filtrados: nunca fija `QUOTED_IDENTIFIER` | Encabezado con las opciones de sesión requeridas |
| F-002 | `sales.usp_PostSale` | Msg 102 `near ')'`: sobra un paréntesis | Se quita el paréntesis |
| F-003 | `sales.usp_PostSale` | Msg 102 `near '@qty'`: `-@qty` como argumento de `EXEC` | Variable `@negQty` |
| F-004 | `sales.usp_CloseTill` | Msg 156: `LineNo` es palabra reservada | `[LineNo]` |
| F-005 | `inventory.usp_AllocateToWeb` | Msg 102 `near '@Quantity'` | Variable `@negQuantity` |
| F-006 | `webstore.usp_FulfillPaidOrder` | Msg 102 `near '@qty'` | Variable `@negQty` |
| F-007 | `inventory.usp_ReleaseQuarantine` | Msg 102 `near '@Quantity'` | Variable `@negQuantity` |

El procedimiento de venta del POS no compilaba.
La afirmación del paquete "cero errores estáticos detectados" no se sostiene en el motor.

## Hallazgos que no son de instalación

Cada uno necesita una prueba roja antes de corregirse en una migración V002 o posterior.

- El script de verificación espera 150 llaves foráneas; el esquema declara 153.
- El smoke test y cualquier cliente necesitan `QUOTED_IDENTIFIER ON`; `sqlcmd` lo trae apagado.
- `receiving.usp_RecordScan` devuelve la columna `ScanId` la primera vez y `Id` en el reintento.
- `UQ_Items_Product_Variant` trata NULL como igual: un producto solo admite una variante sin talla ni color, y el error sale como Msg 2627 crudo.
- Los eventos del outbox no llevan los ids de las filas hijas (por ejemplo, líneas de venta), así que otro nodo no puede reconstruir ni referenciar esas filas.
- Varios procedimientos no emiten evento (`usp_RecordScan`, `usp_ApproveScanSession`, `usp_SubmitCashCount`, `usp_AcknowledgePrint`).
- `credits.usp_CommitTransfer` modifica en un solo nodo los saldos de dos sucursales; entre nodos reales eso exige manejadores que el paquete no trae.
- La base no sabe qué nodo es; el nodo llega como parámetro de la aplicación.
- `sales.usp_PostSale` rechaza la venta si el sistema no tiene stock; el backend anterior permitía vender y revisar la excepción (D-026/D-027). Es decisión de negocio pendiente.

Las decisiones de diseño sobre estos puntos están en [ADR-001](../../adr/ADR-001-arquitectura.md).

## Cómo repetirlo

```bash
python savia/tools/db/saviadb.py up        # necesita savia/infra/.env (copiar de env.example)
python savia/tools/db/saviadb.py status
python savia/tools/db/build_baseline.py --check
python savia/tools/db/saviadb.py test      # cada prueba corre en una base nueva
```

Las corridas A y B se repiten ejecutando el archivo original con `sqlcmd` dentro del contenedor.

## Límites

- No se probó concurrencia, rendimiento, Azure SQL Database ni SQL Server Express.
- Developer Edition es solo para desarrollo y pruebas.
- El smoke test corre todo en una sola base; no prueba sincronización entre nodos.
- No hay impresora, escáner, pasarela de pago ni requisito fiscal verificados.
