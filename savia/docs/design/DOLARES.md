# Cobro en dólares a la tasa del día

Estado: implementado en V027 e integrado en `Tony`; 26/26 pruebas USD, 134/134 SQL, 109/109 .NET y `verify.py` completo 13 de 13 con venta en US$ en el navegador. Base: `f3caf57`. Evidencia: [USD](../evidence/usd-cash/README.md).
Fuente: [PCG](../pilot/PCG.md) y respuestas de la dueña el 2026-11-13.
Cada caso del crítico tiene su resolución en la tabla final.

## Hechos

- La tienda fija casi todos los precios en dólares; algunos, en córdobas.
- La etiqueta muestra los dos: `C$ 2,161 (59)`; 59 × 36.6243 = 2,160.83.
- El cliente paga en córdobas o en dólares. PCG convierte con la tasa del día.
- La tasa la pone la gerente o la dueña y vale para las 3 sucursales.
- La tasa está fija en 36.6243 todo 2026, pero PCG guarda una por día.
- El recibo de apertura cuenta billetes en córdobas y, aparte, en dólares.

## Alcance

1. Tasa del dólar con fecha de inicio.
2. Un pago en efectivo en dólares por venta, dentro de una venta en córdobas, con vuelto en córdobas.
3. Caja con dos gavetas: córdobas y dólares. Apertura, arqueo y cierre juntos.
4. Recibo y detalle de venta con la conversión usada.

Fuera de alcance, con motivo:

- Precio base en dólares por artículo. Con la tasa fija, el precio en córdobas no cambia.
- Vuelto en dólares, tarjeta o transferencia en dólares.
- Dólares en cambios de prenda (`usp_PostReturnOutcome`): se rechazan en esta entrega.
- Entradas manuales (pago, depósito, ajuste) en la gaveta de dólares: se rechazan.
- Devolución en dólares: se devuelve en córdobas, desde la gaveta de córdobas.
- Sincronizar la tasa entre sucursales: el piloto es una sola sucursal.

## Modelo

### Tasa

`core.ExchangeRates(Id, CurrencyCode='USD', EffectiveFrom date, Rate decimal(9,4), SetBy, SetAt, Reason)`.

- Única por `(CurrencyCode, EffectiveFrom)`. `Rate` entre 1 y 1000. Nunca se edita ni borra.
- Vigente: la fila con la mayor `EffectiveFrom` ≤ fecha local. Fecha local: `CAST(DATEADD(hour,-6,core.ufn_BusinessNow()) AS date)`.
- Solo `MANAGER` u `OWNER` crean una tasa. `EffectiveFrom` debe ser hoy o futura.
- Si ya hay una tasa para esa fecha, se rechaza: para corregir, se pone otra con fecha futura.
- Sin tasa vigente no se acepta pago en dólares.

### Pago en dólares

La venta sigue en córdobas. Precio, impuesto, total, comisión y reportes de venta no cambian.
Como máximo un pago en dólares por venta, siempre `cash`.
Columnas nuevas en `sales.SaleTenders`: `ForeignCurrencyCode`, `ForeignReceivedMinor`, `ExchangeRateId`, `ExchangeRate`, `RoundingMinor`.

- Los cinco juntos o ninguno; solo con `TenderKind='cash'`; la moneda extranjera nunca es la de la venta.
- `ReceivedMinor` = `ROUND(ForeignReceivedMinor × ExchangeRate, 0)` (mitad hacia arriba), en centavos de córdoba.
- `E` = `ReceivedMinor − AmountMinor` (exceso).
- Si `E ≥ 0`: vuelto `ChangeMinor` = `E` redondeado hacia abajo a córdoba entera; `RoundingMinor` = `E − ChangeMinor` (0 a 99, a favor de la tienda).
- Si `−100 < E < 0`: vuelto 0; `RoundingMinor` = `E` (la tienda absorbe menos de C$ 1).
- Si `E ≤ −100`: rechazo.
- Siempre: `ReceivedMinor − ChangeMinor − RoundingMinor = AmountMinor`.
- Hoy la regla `ReceivedMinor − ChangeMinor = AmountMinor` vale para todo `cash`. Para el pago en dólares cambia a la de arriba.

Así US$ 59 paga una prenda de C$ 2,161: 5,900 × 36.6243 = 216,083; `E` = −17; se acepta con redondeo −17.
Con US$ 60: 219,746; `E` = 3,646; vuelto C$ 36.00; redondeo 46.

El cliente manda `foreignReceivedMinor`, `exchangeRateId` y `amountMinor`. El servidor calcula lo demás.
Si el cliente manda `receivedMinor`, `changeMinor` o `roundingMinor` distintos, rechaza.
La huella de la venta incluye los campos del pago en dólares.

### Orden dentro de `usp_PostSale`

1. Detectar repetición por `SaleId` primero. Una repetición idéntica devuelve lo guardado aunque la tasa o el día hayan cambiado.
2. Bloquear el turno NIO con `UPDLOCK, HOLDLOCK` y comprobar que está abierto. Luego el turno USD hijo, igual.
3. Leer la tasa `ExchangeRateId` con bloqueo compartido y comprobar que es la vigente hoy.
4. Calcular la conversión y comprobar que la gaveta NIO tiene córdobas para el vuelto.
5. Escribir venta, pagos y movimientos de caja.

El cierre bloquea primero el turno NIO y luego el USD. Toda escritura en caja sigue ese mismo orden.
Así una venta y un cierre no se cruzan: o la venta entra antes del cierre, o se rechaza.

### Caja con dos gavetas

- `sales.CashTills` gana `ParentTillId`. El turno USD es hijo del turno NIO: misma caja, misma cajera, moneda `USD`.
- Un padre tiene como máximo un hijo. Un hijo no tiene hijos. El padre siempre es NIO.
- `UX_OpenTill_Register` pasa a contar solo turnos sin `ParentTillId`.
- Toda API y todo procedimiento que recibe un `TillId` acepta solo el padre. El hijo es interno.
- Las consultas "turno abierto de la caja" y "turno abierto de la cajera" devuelven solo el padre.
- Abrir caja crea los dos turnos y sus dos conteos en una transacción. Dólares en cero se permite.
- Un turno abierto antes de la migración no tiene hijo: no acepta dólares y cierra como hoy.
- `sales.CashDenominations` pasa a `(CurrencyCode, DenominationMinor)`. USD: billetes de 100, 50, 20, 10, 5, 2 y 1. Sin monedas.
- El arqueo valida las denominaciones con la moneda del turno.
- Repetir un `CashCountId` con otras líneas da conflicto (hoy se acepta en silencio; se corrige para las dos monedas).

### Movimientos de caja

- Pago en dólares: una entrada `sale` en el turno USD por `+ForeignReceivedMinor`.
- Si hay vuelto: una entrada nueva `change` en el turno NIO por `−ChangeMinor`, ligada al mismo pago.
- `CK_CashEntries_Kind` y `CK_CashEntries_Source` aceptan `change` (con `SaleTenderId`, monto negativo).
- `UX_CashEntries_Tender` pasa a ser única por `(SaleTenderId, Kind)`.
- La gaveta NIO no puede quedar negativa por un vuelto: si `esperado NIO − vuelto < 0`, se rechaza toda la venta.
- Pagos, depósitos y ajustes manuales en el turno USD se rechazan.

### Cierre

- Cerrar el padre exige el arqueo del padre y, si hay hijo, el del hijo. Se cierran los dos en una transacción.
- Cada turno guarda su cierre, su diferencia y su documento contable en su moneda.
- El documento USD lleva solo efectivo esperado, contado y diferencia.
- El documento NIO agrega una línea `CASH_ROUNDING` con la suma de `RoundingMinor`.
- Un cierre repetido con el mismo arqueo no crea otro documento ni evento.

### Reportes y KPIs

- Las consultas que suman diferencias de cierre o cuentan turnos filtran por moneda.
- Diferencias en dólares se muestran aparte; nunca se suman a córdobas.
- Contar turnos cuenta solo padres.
- Los totales por medio de pago siguen en córdobas: valor de venta, no billetes recibidos.

### Eventos y recibo

- `sales.sale_posted` incluye por pago: moneda extranjera, recibido, vuelto, redondeo, tasa y su `Id`.
- El detalle de venta y la reimpresión muestran la conversión guardada, no la tasa de hoy.

### Oráculo de conservación

- Pago en dólares: exactamente una entrada `sale` en el turno hijo de `s.TillId`, por `ForeignReceivedMinor`, en USD.
- Vuelto: exactamente una entrada `change` en `s.TillId`, por `−ChangeMinor`, o ninguna si es 0.
- `ReceivedMinor = ROUND(ForeignReceivedMinor × ExchangeRate, 0)` y la fila de tasa tiene ese valor.
- `ReceivedMinor − ChangeMinor − RoundingMinor = AmountMinor`; `−100 < RoundingMinor < 100`; `ChangeMinor` múltiplo de 100.
- Pago en córdobas: una entrada `sale` igual a `AmountMinor`, en `s.TillId` (antes no se comprobaba el turno).
- Turno hijo: padre NIO, misma caja y cajera, abiertos y cerrados juntos.
- Cierre: igual que hoy, por turno.

## API y pantallas

- `GET /api/exchange-rate` → `{id, currencyCode, rate, effectiveFrom}` o 404.
- `POST /api/exchange-rates` (gerente o dueña) → crea una tasa.
- Venta: el pago en efectivo acepta `foreignCurrencyCode`, `foreignReceivedMinor`, `exchangeRateId`.
- Abrir caja: conteo en córdobas y en dólares. Cerrar caja: los dos arqueos.
- Cobro: botón "Efectivo US$". Muestra equivalente, vuelto en C$ y redondeo.
- Total de la venta: C$ y, debajo, US$ a la tasa vigente.
- Ajustes de gerente o dueña: la tasa vigente y un formulario para una nueva.

## Pruebas que deben pasar

Contra SQL Server real, rojo antes del cambio y verde después:

1. C$ 2,161.00 pagado con US$ 60: recibido 219,746; vuelto 3,600; redondeo 46; USD +6,000; NIO −3,600.
2. C$ 2,161.00 pagado con US$ 59: redondeo −17; sin vuelto; USD +5,900.
3. Mixto: US$ 20 más el resto en córdobas.
4. Rechazos sin ningún efecto (stock, pagos, caja, evento): tasa no vigente; sin tasa; recibido mal calculado; dos pagos en dólares; campos extranjeros en tarjeta; falta de US$ ≥ C$ 1; vuelto mayor que los córdobas de la gaveta.
5. Dos ventas a la vez que juntas no alcanzan el vuelto: una entra, la otra se rechaza.
6. Repetición idéntica tras cambio de tasa y tras el cierre: misma respuesta, sin entradas nuevas. Repetición con otros datos en dólares: conflicto.
7. Venta y cierre a la vez: la venta queda en los dos cierres o se rechaza; nunca en un turno cerrado.
8. Abrir caja: si falla el segundo turno, no queda ninguno. Cerrar sin arqueo USD falla y no cierra el NIO.
9. Esperado USD = apertura USD + dólares recibidos. Esperado NIO incluye los vueltos.
10. Pago o depósito en el turno USD: rechazo. `TillId` del hijo en venta, devolución o cierre: rechazo.
11. Cambio de prenda con dólares: rechazo. Devolución en efectivo de una venta pagada en dólares: sale de la gaveta NIO.
12. Arqueo repetido con otras líneas: conflicto, en NIO y en USD.
13. KPIs: faltante de C$ 1 y faltante de US$ 1 no dan C$ 2; turnos contados una vez.
14. Una cajera no crea tasas; una fecha pasada o repetida se rechaza; una tasa futura no cambia la de hoy.
15. Oráculo: 0 violaciones tras las pruebas; detecta entrada USD alterada, entrada movida a otro turno, vuelto duplicado y tasa cambiada.
16. El evento `sales.sale_posted` y el detalle de venta llevan la conversión.
17. `python tools/verify.py` sigue en verde.

## Resolución de cada caso del crítico

| # | Caso | Resolución |
| --- | --- | --- |
| 1 | Venta y cierre se cruzan | Bloqueo del turno en la venta; orden padre, luego hijo (prueba 7) |
| 2 | Sin córdobas para el vuelto | Rechazo bajo bloqueo (pruebas 4 y 5) |
| 3 | Cambio de prenda pierde los dólares; devolución en turno USD | Dólares rechazados en cambios; solo `TillId` padre (pruebas 10 y 11) |
| 4 | KPIs suman monedas | Filtro por moneda; turnos solo padres (prueba 13) |
| 5 | Restricciones actuales lo impiden | Índice `(SaleTenderId, Kind)`, tipo `change`, denominación por moneda |
| 6 | Consultas devuelven el hijo | Solo padres; hijo interno; apertura atómica (pruebas 8 y 10) |
| 7 | Repetición y tasa sin orden | Repetición primero; tasa por `Id` bloqueada (prueba 6) |
| 8 | Redondeo no definido | Vuelto a córdoba entera; redondeo guardado y acotado (pruebas 1 y 2) |
| 9 | Movimientos manuales en USD | Rechazados (prueba 10) |
| 10 | Arqueo repetido acepta otras líneas | Conflicto (prueba 12) |
| 11 | Oráculo no ve el turno | Comprueba el turno de cada entrada (prueba 15) |
| 12 | Evento y recibo sin conversión | Campos en evento y detalle (prueba 16) |

## Preguntas abiertas para la dueña

1. ¿El vuelto se redondea a córdoba entera, como asume este diseño?
2. ¿Dan vuelto en dólares alguna vez?
3. ¿Aceptan monedas de dólar o solo billetes?
