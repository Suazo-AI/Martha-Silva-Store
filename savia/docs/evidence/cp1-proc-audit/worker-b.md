# cp1-b — auditoría de procedimientos de ventas, caja y contabilidad

- **task_id**: `cp1-b-sales-cash-accounting-20261112`
- **Modo**: VALIDATE
- **source_sha verificado**: `915044e958bce52015a0d9a33f5f60df567c8ac9` (`git rev-parse HEAD`)
- **Modelo**: `opencode/deepseek-v4.1-flash-free`, razonamiento por defecto del harness (no se fijó `effort`).
- **Alcance**: 9 procedimientos de `savia/db/migrations/V001__baseline.sql`.
- **Regla de trabajo**: no se tocó producto, fixture, herramientas ni pruebas existentes. Solo se agregaron archivos nuevos en `savia/db/tests/{sales,cash,accounting}/` y este documento.

## Resultado

40 pruebas nuevas, 5 defectos documentados como XFAIL.

```text
python savia/tools/db/saviadb.py test sales --jobs 3       -> PASS=22 XFAIL=2  exit 0
python savia/tools/db/saviadb.py test cash --jobs 3        -> PASS=10 XFAIL=3  exit 0   (incluye 2 archivos de sales que contienen "cash" en la ruta)
python savia/tools/db/saviadb.py test accounting --jobs 3  -> PASS=6          exit 0
```

- `sales/`: 24 archivos (23 nuevos + `010_...` existente) → 22 PASS, 2 XFAIL.
- `cash/`: 11 archivos → 8 PASS, 3 XFAIL.
- `accounting/`: 6 archivos → 6 PASS.
- Ningún `FAIL`, `XPASS` ni `INVALID`.

Convención de reintento: cuando el procedimiento ya rechaza la repetición con un error codificado
(`usp_PostSale` 51510, `usp_SubmitCashCount` 51518, `usp_CloseTill` 51521, `usp_PostJournal` 51803),
la prueba exige ese número exacto **y** que los datos no cambien. No se marca XFAIL.
Los XFAIL son solo para repeticiones que hoy responden éxito con contenido distinto, y para actores sin autorización.

## Defectos

| id | procedimiento | defecto (una frase) | prueba |
|----|---------------|---------------------|--------|
| D-B-01 | `sales.usp_OpenTill` | Acepta el mismo `TillId` con otro `@OpeningMinor` y responde éxito, así que el POS cree un fondo de 200000 mientras la caja registró 100000. | `savia/db/tests/sales/103_open_till_replay_other_opening.sql` |
| D-B-02 | `sales.usp_RecordCashEntry` | No verifica que el actor tenga acceso a la sucursal del turno, así que una cajera de la sucursal B puede sacar efectivo de la caja de la sucursal A. | `savia/db/tests/cash/102_record_cash_entry_foreign_branch.sql` |
| D-B-03 | `sales.usp_PostCreditReturn` | Acepta el mismo `ReversalId` con otras cantidades y responde éxito, así que la cajera cree haber devuelto 3 unidades cuando solo se devolvió 1. | `savia/db/tests/sales/136_credit_return_replay_other_lines.sql` |
| D-B-04 | `sales.usp_CloseTill` | No verifica al actor, así que una cajera de la sucursal C puede cerrar y firmar la caja de la sucursal A. | `savia/db/tests/cash/124_close_till_foreign_actor.sql` |
| D-B-05 | `sales.usp_RecordCashEntry` | Acepta el mismo `EntryId` con otro tipo e importe y responde éxito, así que un depósito de 90000 que nunca se registró queda como cobrado. | `savia/db/tests/cash/103_record_cash_entry_replay_other_amount.sql` |

### Salida exacta de cada XFAIL

```text
sales/103  Msg 59002, Level 16, State 1, Server 23b66448cd53, Line 20
           ASSERT FAIL: se acepto el mismo TillId con fondo 200000 y solo quedo el fondo original

cash/102   Msg 59002, Level 16, State 1, Server 23b66448cd53, Line 19
           ASSERT FAIL: una cajera de otra sucursal retiro 50000 de esta caja

sales/136  Msg 59002, Level 16, State 1, Server 23b66448cd53, Line 40
           ASSERT FAIL: se acepto el mismo ReversalId devolviendo 2 unidades mas

cash/124   Msg 59002, Level 16, State 1, Server 23b66448cd53, Line 22
           ASSERT FAIL: una cajera de la sucursal C cerro la caja de la sucursal A

cash/103   Msg 59002, Level 16, State 1, Server 23b66448cd53, Line 23
           ASSERT FAIL: el mismo EntryId se acepto como deposito de 90000
```

Cada prueba XFAIL usa un guard tolerante: acepta cualquier error del producto entre 51000 y 51999
como "rechazado" y solo relanza 59002, de modo que pasa a `XPASS` en cuanto el procedimiento rechace.
Las aserciones posteriores valen con el producto actual y con el corregido (no fijan el estado defectuoso).

### Causa en el código

- **D-B-01** `V001__baseline.sql:2577-2583`: el guard de repetición compara `RegisterId`, `CashierId` y
  `CurrencyCode`, pero no `OpeningMinor`; hace `COMMIT; RETURN` sin comparar el dinero.
- **D-B-02** `V001__baseline.sql:2604-2628`: no hay ninguna consulta a `security.StaffBranchAccess`;
  `@ActorId` se copia tal cual a `CashEntries.ActorId` y `CreatedBy`.
- **D-B-03** `V001__baseline.sql:3221-3226`: el guard solo exige que el anticipo pertenezca a la devolución;
  ignora `@Lines`, `@TillId`, `@ReturnLocationId`, `@CustomerId` y `@Reason`.
- **D-B-04** `V001__baseline.sql:2796-2827`: no hay verificación de actor; `ClosedBy` y `CreatedBy` toman `@ActorId`.
- **D-B-05** `V001__baseline.sql:2614-2615`: `IF EXISTS(... WHERE Id=@EntryId) BEGIN COMMIT; RETURN; END`
  sin comparar tipo, importe, motivo ni turno.

Contraste: `usp_PostSale` sí resuelve el mismo problema con `RequestHash` SHA2-256 y `51510`
(`V001__baseline.sql:2662-2669`), y sus pruebas `sales/111` y `sales/112` pasan. El patrón correcto existe
en el repositorio; a estos cuatro guards les falta.

## Cobertura por procedimiento

| procedimiento | camino normal | repetición | errores codificados probados | invariantes |
|---|---|---|---|---|
| `usp_OpenTill` | `sales/100` (fondo único + evento) | `sales/100` no-op; `sales/103` XFAIL | 51501, 51502, 51503, 51504 (`sales/101`), 2601 `UX_OpenTill_Register` (`sales/102`) | un solo turno abierto por caja; un solo `CashEntries` de tipo `opening`; un evento |
| `usp_RecordCashEntry` | `cash/100` (deposit/payout con motivo, moneda copiada del turno) | `cash/100` no-op; `cash/103` XFAIL | 51505, 51506 (`cash/101`) | sin movimiento duplicado; esperado del turno = suma de `DeltaMinor` |
| `usp_PostSale` | `sales/110` (IVA por línea), `sales/121` (pago mixto) | `sales/111` no-op | 51507, 51508 (`sales/113`), 51509 (`sales/114`), 51510 (`sales/112`), 51511, 51512 (`sales/116`), 51513 (`sales/118`), 51514, 51515 (`sales/117`), 51516, 51517 (`sales/115`), 51102 (`sales/119`) | stock una vez por línea (`sales/120`); caja solo efectivo; sin rastro si falla |
| `usp_SubmitCashCount` | `cash/110` | `cash/110` → 51518 sin cambios | 51518, 51519, 51520, 2601 `UX_CashCounts_TillSubmitted` (`cash/111`) | un solo arqueo presentado por turno |
| `usp_CloseTill` | `cash/120` (esperado = suma de movimientos), `cash/123` (documento contable) | `cash/121` no-op | 51521 (`cash/121`), 51522, 51523, 51524 (`cash/122`) | un cierre por turno; un documento; 11 líneas; un `ExportJob`; un evento |
| `usp_PostCreditReturn` | `sales/130`, `sales/131` (dos partes suman exacto), `sales/135` (cuarentena) | `sales/132` no-op; `sales/136` XFAIL | 51525, 51526, 51527, 51528, 51529, 51530, 51531, 51534 (`sales/134`), 51532 (`sales/133`) | anticipo = importe devuelto; stock al pool elegido; un anticipo por devolución |
| `accounting.usp_QueueExport` | `accounting/100` | `accounting/100` mismo Id y mismo trío documento/destinatario/formato | 51801 (`accounting/101`) | un trabajo por `(CloseDocumentId, RecipientCode, Format)` |
| `accounting.usp_MarkExportSent` | `accounting/110` (pending→ready→sent) | ready repetido no-op | 51802 (`accounting/110`, `accounting/111`) | `sent` no vuelve a `ready`; el documento sigue `prepared` |
| `accounting.usp_PostJournal` | `accounting/120` | `accounting/120` → 51803 sin cambios | 51803, 51804, 51805 (`accounting/121`) | asiento balanceado, sellos de publicación, líneas intactas |

## Observaciones (no son XFAIL)

1. **`usp_QueueExport` descarta el `@ExportId` pedido** cuando ya existe el trío documento/destinatario/formato:
   devuelve éxito y no inserta. Es coherente con `UQ_ExportJobs_DocFormat`, así que `accounting/100` afirma
   "una sola fila, el Id original" y no lo trata como defecto.
2. **`usp_QueueExport` con `@Format` nulo devuelve 515 (NOT NULL), no 51801.** La validación `NOT IN` no atrapa
   NULL y el `INSERT` choca con la restricción. Igual no se guarda nada. `accounting/101` exige 515 y lo deja escrito.
3. **`@Format='pdf'` se acepta y se guarda en minúsculas** porque la base es `SQL_Latin1_General_CP1_CI_AS`
   y tanto el `IN` del procedimiento como `CK_ExportJobs_Format` comparan sin distinguir mayúsculas.
   Evidencia de sonda: `PDF_LOWER_ACCEPTED`. Es inocuo mientras toda comparación sea CI; un consumidor
   case-sensitive del `BlobKey`/nombre de archivo podría tropezar.
4. **`usp_MarkExportSent` con `@Delivered=1` sobre un trabajo ya `sent` vuelve a escribir `BlobKey` y `SentAt`**
   (`'sent'` está en la lista del `WHERE`). Evidencia: `SENT_REPLAY_OVERWRITES_BLOB=1`. Parece reenvío deliberado;
   el efecto es que un recibo de entrega puede reescribirse en silencio.
5. **`usp_PostSale` acepta una venta de total cero con cero pagos** (`SUM(AmountMinor)=0=@total`, no se exige al
   menos un pago). Se usa como preparación de 51534 en `sales/134`; una venta 100% descuento puede ser legítima.
6. **`CloseDocuments.SaleTaxMinor` es el IVA bruto del turno mientras `NetSalesMinor` ya descuenta devoluciones**,
   y no hay columna de IVA devuelto. En `cash/123`: bruto 533239, IVA 38249, devuelto 293239, neto 240000,
   pero el IVA sigue siendo 38249 aunque se devolvió la línea completa con IVA. Es una decisión de modelo de datos,
   no un error de código; el contador debe saberlo antes de exportar.
7. **`usp_PostJournal` con `@PosterId` inexistente devuelve 547 (FK `FK_JournalEntries_Poster`), no un error codificado**;
   el asiento queda en `draft`. Evidencia de sonda: `BOGUS_POSTER_ERR=547`, `BOGUS_POSTER_ENTRY_STILL_DRAFT=1`.
8. **No hay guardas de inmutabilidad** sobre `CashCountLines` ya presentadas ni sobre `JournalLines` ya publicadas:
   el esquema no tiene triggers y los procedimientos no bloquean `UPDATE` directo. Observado por inspección del esquema,
   **no ejercitado** por las pruebas.

## Ramas de validación no alcanzables

- `usp_PostSale` 51516 con `@total<0`: imposible, porque 51508 exige `descuento <= precio*cantidad` y el IVA no es negativo.
  El techo `@total>9000000000000` sí es alcanzable y se prueba en `sales/115` (precio 10000000 × 1000000 unidades → 51516).
- `usp_PostSale` 51515 por moneda del turno: inalcanzable, porque 51513 (moneda del artículo) se evalúa antes y el
  artículo solo existe en NIO. Documentado en `sales/117`.
- `usp_PostCreditReturn` 51533: inalcanzable en la práctica, porque 51532 ya rechaza devolver más unidades y el
  prorrateo nunca supera el total de la línea.
- `usp_CloseTill` 51524 por `@counted<0`: imposible, `CK_CashCountLines_Values` exige denominación > 0 y cantidad ≥ 0.

## Lo que no se pudo probar y por qué

- **Concurrencia** (dos `usp_SubmitCashCount` o dos ventas simultáneas sobre el mismo turno): requiere varias sesiones;
  el README del área indica que esas pruebas viven en la suite .NET.
- **Autorización de `usp_PostJournal` y `usp_QueueExport` por sucursal**: `JournalEntries` y `ExportJobs` no tienen
  columna de sucursal, así que no hay contra qué comparar; solo existe la FK de `PostedBy` (observación 7).
- **Reconciliación de IVA devuelto** (observación 6): falta la columna en el modelo; no es un defecto demostrable.
- **Inmutabilidad posterior a la presentación/publicación** (observación 8): no se ejercitó para no ampliar alcance
  con `UPDATE` directo sobre tablas de negocio.
- **Rendimiento y clientes POS/móviles**: fuera del alcance de esta tarea.

## Archivos agregados (staged, sin commit)

```text
savia/db/tests/sales/100_open_till_opening_entry_and_retry.sql
savia/db/tests/sales/101_open_till_validation.sql
savia/db/tests/sales/102_open_till_one_open_till_per_register.sql
savia/db/tests/sales/103_open_till_replay_other_opening.sql
savia/db/tests/sales/110_post_sale_totals_and_tax_per_line.sql
savia/db/tests/sales/111_post_sale_retry_same_request.sql
savia/db/tests/sales/112_post_sale_reused_id_other_content.sql
savia/db/tests/sales/113_post_sale_line_validation.sql
savia/db/tests/sales/114_post_sale_tender_validation.sql
savia/db/tests/sales/115_post_sale_total_mismatch.sql
savia/db/tests/sales/116_post_sale_location_and_cashier.sql
savia/db/tests/sales/117_post_sale_till_mismatch.sql
savia/db/tests/sales/118_post_sale_price_and_item_state.sql
savia/db/tests/sales/119_post_sale_insufficient_stock_stores_nothing.sql
savia/db/tests/sales/120_post_sale_stock_once_per_line.sql
savia/db/tests/sales/121_post_sale_mixed_tenders.sql
savia/db/tests/sales/130_credit_return_normal.sql
savia/db/tests/sales/131_credit_return_partial_then_rest_exact.sql
savia/db/tests/sales/132_credit_return_retry_no_change.sql
savia/db/tests/sales/133_credit_return_over_return_rejected.sql
savia/db/tests/sales/134_credit_return_validation.sql
savia/db/tests/sales/135_credit_return_pool_quarantine.sql
savia/db/tests/sales/136_credit_return_replay_other_lines.sql
savia/db/tests/cash/100_record_cash_entry_normal_and_retry.sql
savia/db/tests/cash/101_record_cash_entry_validation.sql
savia/db/tests/cash/102_record_cash_entry_foreign_branch.sql
savia/db/tests/cash/103_record_cash_entry_replay_other_amount.sql
savia/db/tests/cash/110_submit_cash_count_normal_and_replay.sql
savia/db/tests/cash/111_submit_cash_count_validation.sql
savia/db/tests/cash/120_close_till_expected_from_entries.sql
savia/db/tests/cash/121_close_till_retry_and_other_closure.sql
savia/db/tests/cash/122_close_till_validation.sql
savia/db/tests/cash/123_close_document_totals.sql
savia/db/tests/cash/124_close_till_foreign_actor.sql
savia/db/tests/accounting/100_queue_export_normal_and_retry.sql
savia/db/tests/accounting/101_queue_export_format_validation.sql
savia/db/tests/accounting/110_mark_export_sent_states.sql
savia/db/tests/accounting/111_mark_export_sent_invalid_targets.sql
savia/db/tests/accounting/120_post_journal_balanced_and_replay.sql
savia/db/tests/accounting/121_post_journal_validation.sql
```

## Siguiente acción

Revisar D-B-01..05 con el dueño del producto y decidir cuál se corrige primero. El más caro es **D-B-05**
(movimiento de caja que se cree registrado y no existe) y el más expuesto es **D-B-02/D-B-04** (cualquier
miembro del personal opera caja de otra sucursal). Al corregir cada uno, su prueba pasará de XFAIL a XPASS
y habrá que quitar la marca `-- XFAIL:`.
