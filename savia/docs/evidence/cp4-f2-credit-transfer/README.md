# CP4 F2: anticipo entre sucursales con un escritor por fila

Fecha: 2026-11-12. Base: `03d309d`. Migración: [V009](../../../db/migrations/V009__credit_transfer_transitions.sql).

## Resultado

`credits.usp_CommitTransfer` ya no mueve saldos de dos sucursales en un nodo.
La transferencia es ahora una cadena de filas inmutables, una por escritor (ADR-001 D5, crítica F2).
`python savia/tools/check.py` imprime `RESULT PASS` ([green.txt](green.txt)).

| Paso | Antes (V001) | Después (V009) |
| --- | --- | --- |
| Solicitar | `usp_RequestTransfer` inserta `CreditTransfers`, desde cualquier nodo | `usp_TransferRequest` inserta `TransferRequests`; solo nodo de B, solicitante con acceso a B |
| Aprobar | `usp_ApproveTransfer` actualiza la misma fila | `usp_TransferApprove` inserta `TransferApprovals`; solo nube; aprobador con `CanApproveTransfers` en A y distinto del solicitante |
| Bloquear / despachar | `usp_LockTransferAtOrigin` pasa A de disponible a retenido y actualiza la fila | `usp_TransferDispatch` inserta `TransferDispatches` y `-monto` en A; solo nodo de A, actor con acceso a A, exige aprobación (FK) y que no haya cancelación |
| Confirmar | `usp_CommitTransfer` en la nube: `Held(A)-monto`, `Held(B)+monto`, dos movimientos | retirado (51719) |
| Recibir / aceptar | `usp_AcceptTransfer` actualiza la fila y pasa B de retenido a disponible | `usp_TransferReceive` inserta `TransferReceipts` y `+monto` en B; solo nodo de B, actor con acceso a B, exige despacho (FK) |
| Cancelar | `usp_CancelUnblockedTransfer` actualiza la fila | `usp_TransferCancel` inserta `TransferCancellations`; solo nube, sin despacho previo |
| Escritores de `CreditTransfers` | B, nube, A, nube, B en la misma fila | tabla legada sin escritores; cada tabla nueva tiene un escritor |
| Saldos en tránsito | retenidos en A y luego en B | fuera de todo saldo; no canjeables en A ni en B |
| Oráculo | `Original = Σ disp + Σ ret + Σ canjes` | `+ Σ despachos sin recepción`; nuevo chequeo `credit.transfer_leg` |

Cada procedimiento nuevo es idempotente ante el mismo reintento y rechaza el mismo id con otro contenido (51721).
Usa el patrón `@ownTran` de V005, así que funciona dentro de `INSERT-EXEC` o de una transacción externa.
Un índice único filtrado impide un segundo `transfer_out` o `transfer_in` por transferencia.
La migración se detiene si existen transferencias legadas en `origin_locked` o `in_transit`.

Errores nuevos 51719 a 51732, mapeados en [Errors.cs](../../../src/Savia.Domain/Errors.cs).
51713 a 51718 quedan libres para V008.

## Defectos encontrados (rojo antes, verde después)

Evidencia en [red.txt](red.txt).

1. F2: `usp_CommitTransfer` cambia los saldos de dos sucursales en una llamada. Prueba `credits/140`: `expected=1 actual=2`.
2. Con dinero en tránsito, el oráculo V003 da `credit.conservation expected=120000 actual=70000`. Se extendió el oráculo en V009 (5 pruebas rojas, luego verdes).
3. `usp_RedeemCredit` marcaba el anticipo `exhausted` cuando A gastaba todo lo suyo con 50000 en tránsito. B no habría podido canjear tras recibir. Prueba `credits/120`. Se corrigió en V009.

## Pruebas

- `credits/140` nueva (roja en `03d309d`): cada transición cambia como mucho el saldo de la sucursal de su nodo y no reescribe filas anteriores (`RowVersion` intacta).
- `credits/050`, `060`, `070`, `080`, `090`, `110`, `120`, `130` reescritas para las transiciones, marcadas `-- FIXED (V009)`.
- `credits/100` reescrita: los seis procedimientos legados lanzan 51719 y no escriben nada.
- `audit/020` nueva: el oráculo acepta dinero en tránsito y detecta un tramo alterado o una recepción sin su `+monto`.
- Fixture: `test.SeedCredit`, `test.SeedSale` y `test.ChangedBranches`, agregados al final de `_fixture.sql`.

## Comandos

```bash
python savia/tools/db/saviadb.py test credits/140          # rojo en 03d309d
python savia/tools/db/saviadb.py test credits --jobs 3
python savia/tools/db/saviadb.py test audit
python savia/tools/check.py                                # RESULT PASS
```

## Límites

- La prueba corre en una sola base. No prueba la sincronización entre nodos: que A vea la aprobación, que B vea el despacho, el orden de aplicación o el filtro por dueño. Eso es trabajo del simulador.
- El nodo que escribe llega como parámetro `@NodeId`. Hasta que exista `sync.LocalNode` (F10), la base confía en que el host pasa su propio nodo.
- Cancelar (nube) y despachar (A) pueden cruzarse entre nodos: A despacha offline después de ver la aprobación y la nube cancela antes de ver el despacho. En una base quedan serializados; entre nodos falta una regla.
- `credits.Credits.Status` sigue escrito por la sucursal que canjea (otra parte de F2). V009 solo evita el `exhausted` prematuro.
- Los procedimientos nuevos no emiten eventos al outbox. D5 dice que el estado viaja por filas; webhooks y avisos de transferencia quedan pendientes.
- No hay API ni pruebas .NET de transferencias; nada en `src/` las llamaba.
- No se probó concurrencia real (varias sesiones); el bloqueo es `UPDLOCK,HOLDLOCK` sobre la fila de la solicitud.

## Verificación independiente (orquestador)

Aplicado sobre `db0bb31`, que ya trae V008. Corrido por el orquestador, no por el agente.

- Rojo sin V009: `credits/140` falla con `expected=1 actual=2` ([red-orchestrator.txt](red-orchestrator.txt)). `audit/020` falla solo porque falta `credits.usp_TransferRequest`; ese rojo es más débil.
- Verde con V008 + V009: `check.py` da `RESULT PASS`, 120 T-SQL y 13 .NET ([green.txt](green.txt), reemplaza el del agente).
- La prueba de restauración de V008 sigue pasando con V009.
- Revisión de V009: los `UPDATE` tocan solo la fila de la sucursal que actúa. `credits.Credits.Status` sigue con varios escritores (ver Límites).
- Pendiente: `@NodeId` todavía llega por parámetro; falta validarlo contra `sync.LocalNode` (V008).
