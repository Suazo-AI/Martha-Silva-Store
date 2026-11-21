# F12 y F14 (mitad Express): SQL Server Express

Fecha: 2026-11-12. Ejecutó: agente primary, local, sin costo.
Resultado: la suite T-SQL completa pasa en Express, y Change Tracking con lectura `SNAPSHOT` funciona en Express.

## Qué se probó

| Prueba | Comando | Resultado |
| --- | --- | --- |
| Suite T-SQL en Express | `SAVIA_SQL_CONTAINER=savia-sqlserver-express python savia/tools/db/saviadb.py test --jobs 3` | `PASS=113`, [salida](express-tests.txt) |
| Change Tracking + `SNAPSHOT` | [ct-probe.sql](ct-probe.sql) en una base `SAVIA_T_ctprobe` de Express | 2 filas cambiadas, `PASS`, [salida](ct-probe-result.txt) |

Contenedor: [docker-compose.express.yml](../../infra/docker-compose.express.yml). Misma imagen fijada por digest que el de desarrollo.
`MSSQL_PID=Express`, puerto `127.0.0.1:14341`, volumen propio. El contenedor Developer no cambia.
`saviadb.py` acepta `SAVIA_SQL_CONTAINER`, solo con nombres `savia-sqlserver-*`.

## Límites

- Azure SQL no está probado. Necesita autorización de Jason (gasto). F14 sigue abierto para Azure.
- La prueba de CT es mínima: una tabla, sin limpieza automática vencida ni restauración. La restauración la cubre CP4-S1.
- Express limita memoria y tamaño (10 GB por base). No se midió carga.
- CI con Express no está conectado; esto es la corrida local que CI debe repetir.
