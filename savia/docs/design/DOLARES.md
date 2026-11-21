# Cobro en dólares a la tasa del día

Estado: V027 y V028 implementados. V028: vuelto completo en C$, en US$ o en las dos, y monedas de dólar. Diseño: crítico 1 y 2 NO-GO, crítico 3 GO-WITH-FIXES aplicadas.
V028: integrado en `Tony`; SQL 134/134, .NET 145/145, `verify.py` completo 13 de 13. Evidencia: [vuelto USD](../evidence/usd-change/README.md).
V027: implementado e integrado en `Tony`; 26/26 pruebas USD, 134/134 SQL, 109/109 .NET y `verify.py` completo 13 de 13 con venta en US$ en el navegador. Base: `f3caf57`. Evidencia: [USD](../evidence/usd-cash/README.md).
Fuente: [PCG](../pilot/PCG.md) y respuestas de la dueña el 2026-11-13 (dos rondas).
Cada caso del crítico tiene su resolución en la tabla final.

## Hechos

- La tienda fija casi todos los precios en dólares; algunos, en córdobas.
- La etiqueta muestra los dos: `C$ 2,161 (59)`; 59 × 36.6243 = 2,160.83.
- El cliente paga en córdobas o en dólares. PCG convierte con la tasa del día.
- La tasa la pone la gerente o la dueña y vale para las 3 sucursales.
- La tasa está fija en 36.6243 todo 2026, pero PCG guarda una por día.
- El recibo de apertura cuenta billetes en córdobas y, aparte, en dólares.
- El vuelto se da completo, en córdobas, en dólares o en las dos. Depende de lo que hay en caja y de lo que pide el cliente.
- Se aceptan monedas de dólar.

## Alcance

1. Tasa del dólar con fecha de inicio.
2. Un pago en efectivo en dólares por venta, dentro de una venta en córdobas, con vuelto completo en córdobas, en dólares o en las dos.
3. Caja con dos gavetas: córdobas y dólares. Apertura, arqueo y cierre juntos.
4. Recibo y detalle de venta con la conversión usada.

Fuera de alcance, con motivo:

- Precio base en dólares por artículo. Con la tasa fija, el precio en córdobas no cambia.
- Tarjeta o transferencia en dólares.
- Vuelto en dólares para un pago en córdobas: el vuelto en dólares sale solo del pago en dólares.
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
- La cajera elige cuánto vuelto da en dólares: `ForeignChangeMinor`, entero en centavos de dólar, 0 por defecto.
- `0 ≤ ForeignChangeMinor < ForeignReceivedMinor`, en API y en SQL. En un pago sin dólares el campo se rechaza.
- `ForeignChangeNioMinor` = `ROUND(ForeignChangeMinor × ExchangeRate, 0)`.
- Las dos conversiones se hacen por separado, nunca sobre el neto: `decimal(28,4)` por la tasa, mitad hacia arriba.
- Si `E < 0` (pago corto): `ForeignChangeMinor` debe ser 0. Si `E ≤ −100`, rechazo. Si no: `ChangeMinor` = 0; `RoundingMinor` = `E` (la tienda absorbe menos de C$ 1).
- Si `E ≥ 0`: `ForeignChangeNioMinor ≤ E`; si no, rechazo. Así el vuelto en dólares nunca regala dinero.
- Entonces `R` = `E − ForeignChangeNioMinor` (≥ 0) es lo que falta dar en córdobas.
- `ChangeMinor` = el mayor monto que se puede dar con las monedas de C$ y no pasa de `R`. `RoundingMinor` = `R − ChangeMinor`.
- Monedas menores del catálogo NIO (V015): 10, 25 y 50 centavos. Con ellas se forma todo múltiplo de 5 desde 20, además de 0 y 10. No se forman 5 ni 15.
- Fórmula: `c = R − R % 5`; si `c` es 5 o 15, `c = c − 5`. Solo importa cuando `R < 20`: desde 20 todo múltiplo de 5 se forma.
  - Ejemplos: `R` 3,646 → 3,645; 25 → 25; 19 → 10; 14 → 10; 9 → 0; 899 → 895.
- Así el redondeo queda de 0 a 9, y de 5 a 9 solo cuando `ChangeMinor` es 0 o 10.
- "Vuelto completo" significa: todo lo que se puede dar con monedas que existen. Si el catálogo NIO cambia, esta regla cambia con una migración.
- Siempre: `ReceivedMinor − ChangeMinor − ForeignChangeNioMinor − RoundingMinor = AmountMinor`.
- Hoy la regla `ReceivedMinor − ChangeMinor = AmountMinor` vale para todo `cash`. Para el pago en dólares cambia a la de arriba.
- `ForeignReceivedMinor` y `ForeignChangeMinor` aceptan centavos: hay monedas de dólar.
- Columna nueva `ForeignChangeMinor`. `NULL` marca un pago de V027, que conserva su regla. V028 siempre la escribe, 0 si no hay. Nunca se convierte `NULL` en 0.

Tres ramas en `CK_Tenders_Cash` y `CK_Tenders_FX`, y las mismas en el oráculo:

| Rama | Regla |
| --- | --- |
| No efectivo (tarjeta, transferencia) | Igual que V027: `ReceivedMinor`, `ChangeMinor`, `RoundingMinor`, `ForeignChangeMinor` y todos los campos extranjeros `NULL` |
| Efectivo C$ | `ReceivedMinor − ChangeMinor = AmountMinor`; campos extranjeros `NULL` |
| US$ V027 (`ForeignChangeMinor` `NULL`) | La de V027 sin cambios: `ChangeMinor` múltiplo de 100, redondeo −99 a 99. Una fila con vuelto 3,600 y redondeo 46 sigue válida |
| US$ V028 | La igualdad con `ForeignChangeNioMinor` y `0 ≤ ForeignChangeMinor < ForeignReceivedMinor`. Y una de dos: (a) `ChangeMinor % 5 = 0`, `ChangeMinor` no es 5 ni 15, redondeo 0 a 9, y redondeo 0 a 4 salvo que `ChangeMinor` sea 0 o 10; (b) `ForeignChangeMinor` = 0, `ChangeMinor` = 0 y redondeo −99 a −1 |

Las tres primeras ramas son de efectivo; la de no efectivo (`TenderKind <> 'cash'`) se conserva tal cual.
En SQL, las guardas de V027 van antes de las ramas: campos obligatorios `IS NOT NULL`, `ReceivedMinor >= 0`, `ChangeMinor >= 0`, `ForeignChangeMinor >= 0`. Sin ellas un `NULL` da `UNKNOWN` y el `CHECK` lo deja pasar, o un `ChangeMinor` negativo cuadra la igualdad.

Ejemplos con una prenda de C$ 2,161.00 (`AmountMinor` 216,100):

| Recibe | Vuelto US$ | Recibido | E | R | Vuelto C$ | Redondeo |
| --- | --- | --- | --- | --- | --- | --- |
| US$ 59 | 0 | 216,083 | −17 | no aplica (pago corto) | 0 | −17 |
| US$ 60 | 0 | 219,746 | 3,646 | 3,646 | 36.45 | 1 |
| US$ 100 | 0 | 366,243 | 150,143 | 150,143 | 1,501.40 | 3 |
| US$ 100 | US$ 40 (146,497) | 366,243 | 150,143 | 3,646 | 36.45 | 1 |
| US$ 59.25 | 0 | 216,999 | 899 | 899 | 8.95 | 4 |
| US$ 1 por C$ 36.37 | 0 | 3,662 | 25 | 25 | 0.25 | 0 |

El cliente manda `foreignReceivedMinor`, `foreignChangeMinor`, `exchangeRateId` y `amountMinor`. El servidor calcula lo demás.
En el ejemplo de US$ 100 con US$ 40 de vuelto, US$ 41.03 se rechaza (excede `E`); US$ 41.02 también (excede `E`). Solo vale hasta 4,099 centavos: 4,099 × 36.6243 = 150,123 ≤ 150,143.
Si el cliente manda `receivedMinor`, `changeMinor` o `roundingMinor` distintos, rechaza.
La huella de la venta incluye los campos del pago en dólares.
`foreignChangeMinor` entra en `@FxJson` (y en la huella) solo si es mayor que 0. Así la huella de una petición V027 no cambia y su reintento devuelve lo guardado.
La repetición se resuelve antes de cualquier cálculo nuevo. Un vuelto en dólares distinto de 0 nunca se ignora.

### Orden dentro de `usp_PostSale`

1. Detectar repetición por `SaleId` primero. Una repetición idéntica devuelve lo guardado aunque la tasa o el día hayan cambiado.
2. Bloquear el turno NIO con `UPDLOCK, HOLDLOCK` y comprobar que está abierto. Luego el turno USD hijo, igual.
3. Leer la tasa `ExchangeRateId` con bloqueo compartido y comprobar que es la vigente hoy.
4. Calcular la conversión y comprobar la gaveta NIO: `saldo NIO + Σ AmountMinor de los pagos en efectivo C$ de esta venta − ChangeMinor ≥ 0`. Tarjeta y transferencia no cuentan. El resultado no depende del orden de los pagos.
   La gaveta USD no puede quedar negativa: cada pago suma `ForeignReceivedMinor − ForeignChangeMinor > 0`.
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
- `sales.CashDenominations` pasa a `(CurrencyCode, DenominationMinor)`. USD: billetes de 100, 50, 20, 10, 5, 2 y 1, y monedas de 50, 25, 10, 5 y 1 centavo (V028). La moneda de US$ 1 se cuenta con el billete de US$ 1.
- El arqueo valida las denominaciones con la moneda del turno.
- Repetir un `CashCountId` con otras líneas da conflicto (hoy se acepta en silencio; se corrige para las dos monedas).

### Movimientos de caja

- Pago en dólares: una entrada `sale` en el turno USD por `+ForeignReceivedMinor`.
- Si hay vuelto en córdobas: una entrada `change` en el turno NIO por `−ChangeMinor`, ligada al mismo pago.
- Si hay vuelto en dólares: una entrada `change` en el turno USD por `−ForeignChangeMinor`, ligada al mismo pago.
- `CK_CashEntries_Kind` y `CK_CashEntries_Source` aceptan `change` (con `SaleTenderId`, monto negativo).
- V028: `UX_CashEntries_Tender` queda única por `(SaleTenderId, Kind)` con el filtro completo `WHERE SaleTenderId IS NOT NULL AND Kind <> 'change'`. Un índice nuevo, único por `(SaleTenderId, TillId)` con `WHERE SaleTenderId IS NOT NULL AND Kind = 'change'`.
  Así hay una sola entrada `sale` por pago y como máximo un vuelto por gaveta.
- Ninguna gaveta puede quedar negativa por un vuelto. La regla está en el paso 4 de `usp_PostSale`.
- El sistema controla totales por gaveta, no billetes ni monedas. La cajera elige la mezcla según lo que tiene.
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

- `sales.sale_posted` incluye por pago: moneda extranjera, recibido, vuelto C$, `foreignChangeMinor`, `foreignChangeNioMinor`, redondeo, tasa y su `Id`.
- Detalle de venta y reimpresión muestran los mismos campos.
- El detalle de venta y la reimpresión muestran la conversión guardada, no la tasa de hoy.

### Oráculo de conservación

- Pago en dólares: exactamente una entrada `sale` en el turno hijo de `s.TillId`, por `ForeignReceivedMinor`, en USD.
- Vuelto C$: exactamente una entrada `change` en `s.TillId`, por `−ChangeMinor`, o ninguna si es 0.
- Vuelto US$: exactamente una entrada `change` en el turno hijo, por `−ForeignChangeMinor`, o ninguna si es 0 o `NULL`.
- Un pago en dólares no tiene ninguna otra entrada: ni otra moneda, ni otro turno, ni otro tipo.
- `ReceivedMinor = ROUND(ForeignReceivedMinor × ExchangeRate, 0)` y la fila de tasa tiene ese valor.
- Pago V027 (`ForeignChangeMinor` `NULL`): `ReceivedMinor − ChangeMinor − RoundingMinor = AmountMinor`; `−100 < RoundingMinor < 100`; `ChangeMinor` múltiplo de 100.
- Pago V028: la rama V028 de la tabla de arriba, `0 ≤ ForeignChangeMinor < ForeignReceivedMinor` y la conversión de `ForeignChangeNioMinor`.
- Pago en córdobas: una entrada `sale` igual a `AmountMinor`, en `s.TillId` (antes no se comprobaba el turno).
- Turno hijo: padre NIO, misma caja y cajera, abiertos y cerrados juntos.
- Cierre: igual que hoy, por turno.

## API y pantallas

- `GET /api/exchange-rate` → `{id, currencyCode, rate, effectiveFrom}` o 404.
- `POST /api/exchange-rates` (gerente o dueña) → crea una tasa.
- Venta: el pago en efectivo acepta `foreignCurrencyCode`, `foreignReceivedMinor`, `exchangeRateId`.
- Abrir caja: conteo en córdobas y en dólares. Cerrar caja: los dos arqueos.
- Cobro: botón "Efectivo US$". Acepta centavos. Muestra equivalente y vuelto debido.
- Campo "Vuelto en US$", 0 por defecto. El vuelto en C$ se recalcula al escribir.
- Botón "Vuelto en US$": pone el mayor entero `d ≥ 0` con `100d < ForeignReceivedMinor` y `ROUND(100d × tasa, 0) ≤ E`; el resto va en C$. En pago corto pone 0.
  - Ejemplos: US$ 2 por C$ 36.63 (`E` 3,662) → US$ 1. `E` −17 → 0.
- Total de la venta: C$ y, debajo, US$ a la tasa vigente.
- Ajustes de gerente o dueña: la tasa vigente y un formulario para una nueva.

## Pruebas que deben pasar

Contra SQL Server real, rojo antes del cambio y verde después:

1. C$ 2,161.00 pagado con US$ 60: recibido 219,746; vuelto 3,645; redondeo 1; USD +6,000; NIO −3,645.
1a. Con US$ 100 y US$ 40 de vuelto: vuelto 3,645 centavos (C$ 36.45); redondeo 1; USD +10,000 y −4,000; NIO −3,645.
1b. Con US$ 59.25: vuelto 895; redondeo 4; USD +5,925. C$ 36.37 con US$ 1: vuelto 25; redondeo 0.
1b2. `R` de 0 a 30: el vuelto es el mayor monto formable con 10, 25 y 50 centavos que no pasa de `R`; nunca 5 ni 15.
1b3. Tarjeta sola y efectivo C$ más tarjeta siguen pasando tras V028.
1c. Rechazos sin efecto: vuelto US$ negativo; vuelto US$ ≥ recibido US$; vuelto US$ mayor que `E` (US$ 41.02 con US$ 100); vuelto US$ en pago corto; `foreignChangeMinor` sin dólares; `changeMinor` del cliente distinto.
1c2. Bordes de `E`: −100 rechazo; −99 y −1 redondeo; 0, 9, 10, 15 y 20 con vuelto 0, 0, 10, 10 y 20. Empate: US$ 50 → 183,122.
1c3. Conversión por separado, con `AmountMinor` 183,121: recibir US$ 100 y dar US$ 50 convierte 366,243 − 183,122 = 183,121, no el neto 183,122. Con el precio 216,100, dar US$ 50 se rechaza (excede `E`).
1d. Gaveta con C$ 50 y dos ventas a la vez con vuelto C$ 36.45 cada una: solo una entra.
1d2. Saldo C$ 50; venta C$ 2,161: US$ 60 asignado a C$ 1,000 y C$ 1,161 en efectivo. Vuelto C$ 1,197.45: se acepta (quedan C$ 13.55).
1d3. Varias aperturas NIO y USD (entradas `opening` sin pago) entran; una segunda entrada `sale` para el mismo pago se rechaza.
1e. Migración con filas V027 existentes: siguen válidas en constraints y oráculo. Reintento HTTP real de una venta V027 tras V028: misma respuesta, sin `51510`.
1e2. Si falla el segundo vuelto: rollback de venta, stock, pagos, caja y evento.
1e3. Cierre tras US$ 100 con US$ 40 de vuelto y apertura US$ 0: esperado US$ 60; `CASH_ROUNDING` 1; venta C$ 2,161; un turno padre en KPIs.
1e4. Devolución completa de esa venta: C$ 2,161 desde la gaveta NIO; los US$ 40 no se devuelven otra vez. También parcial.
1e5. El oráculo detecta cada entrada alterada, sobrante, de otra moneda o de otro turno.
1f. Arqueo USD con monedas en apertura, arqueo, cierre y reintento: 50, 25, 10, 5 y 1 centavo se aceptan; 3 centavos no. Tres billetes y dos monedas de US$ 1 se guardan como cantidad 5 en la denominación 100. La lista de la web (`web/screens/denominations.mjs`) muestra las monedas.
2. C$ 2,161.00 pagado con US$ 59: redondeo −17; sin vuelto; USD +5,900.
3. Mixto: US$ 20 más el resto en córdobas.
4. Rechazos sin ningún efecto (stock, pagos, caja, evento): tasa no vigente; sin tasa; recibido mal calculado; dos pagos en dólares; campos extranjeros en tarjeta; falta de US$ ≥ C$ 1; vuelto mayor que los córdobas de la gaveta.
5. Dos ventas a la vez que juntas no alcanzan el vuelto: una entra, la otra se rechaza.
6. Repetición idéntica tras cambio de tasa y tras el cierre: misma respuesta, sin entradas nuevas. Repetición con otros datos en dólares: conflicto.
7. Venta y cierre a la vez: la venta queda en los dos cierres o se rechaza; nunca en un turno cerrado.
8. Abrir caja: si falla el segundo turno, no queda ninguno. Cerrar sin arqueo USD falla y no cierra el NIO.
9. Esperado USD = apertura USD + dólares recibidos − vueltos en dólares. Esperado NIO incluye los vueltos en córdobas.
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
| 8 | Redondeo no definido | V028: mayor vuelto formable con monedas de 10, 25 y 50 centavos; redondeo guardado y acotado (pruebas 1 a 1c3) |
| 9 | Movimientos manuales en USD | Rechazados (prueba 10) |
| 10 | Arqueo repetido acepta otras líneas | Conflicto (prueba 12) |
| 11 | Oráculo no ve el turno | Comprueba el turno de cada entrada (prueba 15) |
| 12 | Evento y recibo sin conversión | Campos en evento y detalle (prueba 16) |

## Respuestas de la dueña (2026-11-13, segunda ronda)

1. Vuelto: completo, no a córdoba entera.
2. Vuelto en dólares: sí. En córdobas, en dólares o en las dos, según la caja y el cliente.
3. Monedas de dólar: sí se aceptan.

## Migración V028 y recuperación

- V028 corre en una sola transacción con `SET XACT_ABORT ON`. Si falla un paso (por ejemplo, crear el índice nuevo), no queda ningún cambio: el esquema sigue en V027.
- El esquema y su fila en `dbo.SaviaMigrations` se confirman juntos, en la misma conexión y transacción.
  - Cambio en `tools/db/saviadb.py`: un archivo que empieza con `-- savia:transactional` se envía en una sola sesión `sqlcmd` envuelto así: `SET XACT_ABORT ON; BEGIN TRAN;` + archivo + comprobación `@@TRANCOUNT = 1 AND XACT_STATE() = 1` (si no, `THROW`) + `INSERT dbo.SaviaMigrations` + `COMMIT`.
  - El archivo marcado no tiene `BEGIN TRAN` ni `COMMIT` propios. Cada `CREATE OR ALTER PROCEDURE` empieza su lote con `GO`.
  - Los archivos sin marca (V001 a V027) corren como hoy.
- `sqlcmd -b` sale ante un error de severidad mayor que 10, y la desconexión revierte la transacción pendiente. `XACT_ABORT` no cubre errores de compilación; por eso la salida de `sqlcmd` es la que manda.
- Pruebas: forzar un fallo después de borrar el índice viejo, y otro en el `INSERT` del registro. En los dos: índice viejo, restricciones, filas y registro siguen como en V027, y un reintento aplica V028 completa una vez.
- Restaurar el respaldo previo a V028 solo vale si no hubo ninguna escritura de negocio después del respaldo (aperturas, conteos, ventas). Durante esa ventana el piloto queda apagado (`pilot down`).
- Después de cualquier escritura de negocio con V028: no hay vuelta atrás a V027. Las filas V028 no cumplen `ChangeMinor % 100 = 0`. Solo se corrige hacia adelante con otra migración; nunca se borran ni reescriben ventas.

## Riesgo aceptado

- Pago corto (`E` de −1 a −99) seguido de devolución completa: se devuelve el precio entero, hasta C$ 0.99 más de lo cobrado. Igual que en V027. Exige una devolución autorizada.

## Pregunta abierta

- ¿Un cliente que paga en córdobas pide a veces vuelto en dólares? Hoy queda fuera; el vuelto en dólares sale solo de un pago en dólares.
