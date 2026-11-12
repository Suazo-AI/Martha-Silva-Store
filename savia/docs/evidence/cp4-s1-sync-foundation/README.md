# CP4-S1: base de sync (V008)

Resultado: la base de sync existe y la regla del cursor `(fork, versión)` está probada en el motor real.
Fecha: 2026-11-12. Motor: SQL Server 2022 Developer 16.0.4305.5 (`savia-sqlserver-dev`).

## Qué agrega V008

- Change Tracking en la base (retención provisional 30 días) y en 6 tablas de sucursal:
  `sales.Sales`, `SaleLines`, `SaleTenders`, `CashTills`, `CashEntries`, `inventory.StockMovements`.
- `sync.LocalNode`: la base sabe qué nodo es. Se fija una sola vez (51806 si ya es otro nodo, 51807 si el nodo no existe).
- `sync.PeerCursors`: el receptor guarda, por emisor y tabla, el par `(recovery_fork_guid, versión)`.
- `sync.usp_GetSourceState`: nodo, fork, versión actual y versión mínima válida por tabla, en una lectura `SNAPSHOT`.
- `sync.usp_ClassifyCursor`: decide `initial`, `incremental`, `reinit` o `recover`.
- `sync.usp_AdvancePeerCursor`: el cursor solo avanza dentro de un fork (51808); tabla sin CT da 51809.

## Pruebas

| Prueba | Qué demuestra | Resultado |
| --- | --- | --- |
| `db/tests/sync/100` a `140` | Reglas de nodo local, CT ve una venta, clasificación, avance del cursor, estado del emisor | 5 PASS |
| `tools/db/restore_proof.py` | Restauración real de un respaldo viejo ([salida](restore-proof.txt)) | 4 PASS |
| `tools/db/no_physical_delete.py` | Ninguna migración hace `DELETE` ni `TRUNCATE` sobre una tabla con CT | 6 tablas, 0 violaciones |

### Prueba de restauración (F1, E3)

1. Se clona una base, se fija como `nodeA` y se abre la caja t1. Versión 1. Respaldo.
2. Se abre t2. Versión 3. El receptor guarda el cursor `(fork1, 3)`.
3. Se restaura el respaldo viejo. La versión vuelve a 1. Se abre t3. Versión 3 otra vez.
4. Un cursor que solo guarda la versión (3) no ve t3: pérdida de datos silenciosa.
5. El fork cambió. `usp_ClassifyCursor` con `(fork, versión)` responde `recover`.

### Control rojo del escáner

Un archivo de prueba con `ALTER TABLE [sales].[CashTills] ENABLE CHANGE_TRACKING`, un `DELETE` en un comentario,
un `DELETE` real, un `TRUNCATE` y un `DELETE` sobre `security.Staff` (sin CT) da 2 violaciones:
el `DELETE` real y el `TRUNCATE`. El comentario y la tabla sin CT no cuentan.

## Error encontrado antes del commit

La primera versión de V008 llamó `sync.usp_AdvanceCursor` al procedimiento nuevo.
Ese nombre ya existía en V001 (cursor del outbox). `CREATE OR ALTER` lo reemplazó sin aviso.
`outbox/030` y `outbox/070` fallaron en la suite completa (FAIL=2, PASS=116); la corrida filtrada `sync` no lo mostró.
Corrección: el nuevo se llama `sync.usp_AdvancePeerCursor`. Suite completa: PASS=118.
Lección: correr la suite completa, no solo el filtro del área, antes de dar por buena una migración.

## Límites

- No hay transporte todavía: nada se copia entre nodos. Esto es solo la base del protocolo.
- El escáner lee migraciones. No revisa SQL escrito en C# ni comandos manuales.
- Retención de 30 días es provisional (F7). Falta el valor real y la alerta.
- Faltan CT en el resto de tablas sincronizadas; entran con el aplicador generado (F4).
- La prueba de restauración usa un solo nodo emisor y una tabla. El simulador 1+3 sigue pendiente.

## Comandos

```bash
python savia/tools/db/saviadb.py test sync --jobs 3
python savia/tools/db/restore_proof.py
python savia/tools/db/no_physical_delete.py
python savia/tools/check.py
```
