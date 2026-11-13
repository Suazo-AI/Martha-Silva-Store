# PCG en la tienda: lo que muestran los videos de Jason

Fuente: 3 videos de pantalla y 1 foto de recibo que Jason envió el 2026-11-13.
Los archivos no entran a Git: muestran datos reales de la tienda.
Revisión: cuadros con FFmpeg mirados uno por uno. El audio no se transcribió (falta autorización para subirlo a AssemblyAI).
Los nombres de empleados y clientes vistos en pantalla se omiten aquí.

## Pantallas vistas

### Facturación ("FACTURA – CONTADO (En Piso)")

- Encabezado: serie, número de factura, fecha, vendedor, bodega (`BODEGA PLAZA PASEO`), lista de precio (`PRECIO PUBLICO`).
- Cliente por defecto: `00000 CLIENTES VARIOS`, con tipo de identificación (cédula).
- Opciones del documento: descuento global, ver mora, `Fisco (2%)`, `Alcaldía (1%)`, `Exonerado`, `Propina`, `Imprime $`.
- Llamar documentos: proforma, preventa, reserva, pedido, apartados, consignación, orden, venta aplicada.
- Columnas de la línea: código, no. parte, barras, referencia, producto, lote, color, talla, observación, saldo, medida, cantidad, precio.

### Devolución a cliente

- Parte de una factura: número, contado o crédito, `T/C Fact 36.6243`, moneda (`Dolares`), fecha, sucursal.
- Casillas: `Generar egreso de caja` (devolver efectivo) e `Incluir retenciones`.
- Totales: subtotal, descuento, I.V.A., retenciones, total; abonado y saldo pendiente.
- Columnas: lote, saldo, medida, pendiente, cantidad, devolver, precio, % descuento, descuento, IVA, total.
- Botón `Devolver todo`, que pregunta "¿Desea devolver todo?".
- Listas a la izquierda: devoluciones aplicadas y pendientes. Concepto: `DEVOLUCION DE CLIENTES`.

### Sistema y tipo de cambio

- Tabla `Tipo de Cambio` con una tasa por día (36.6243 córdobas por dólar en el video).
- Módulos: Caja, Catálogos, Cuentas por Cobrar, Cuentas por Pagar, Facturación, Finanzas y Contabilidad, Importaciones, Inventario, Productos, Reportes, Sistema, Usuarios.

### Recibo de apertura de caja

- Conteo por billete y moneda en córdobas, y una sección aparte en dólares.

## Comparación con SAVIA hoy

| PCG | SAVIA hoy | Evidencia en SAVIA |
| --- | --- | --- |
| Conteo de caja por billete y moneda | Existe, en una sola moneda por sesión | `Savia.Contracts/Cash.cs` (`CashCountLine`) |
| Dólares en la misma caja, tasa del día | No existe: no hay tabla de tasas ni pago en dólares convertido | sin `ExchangeRate` en `src` ni `db` |
| I.V.A. por línea | Existe (`TaxRateBps` por artículo) | `V015`, `V024` |
| Retenciones `Fisco (2%)` y `Alcaldía (1%)` | No existe | sin `Retenc`/`Withhold` |
| Devolver efectivo desde la devolución | Existe como una de las 4 salidas | ronda 4, `V024` |
| Proforma, preventa, pedido, consignación | No existe | — |
| Apartados | Existe | [TRASLADOS-APARTADOS](TRASLADOS-APARTADOS.md) |
| Talla, color y lote en la línea | Talla y color por variante; sin lote | catálogo |

## Etiqueta de la tienda

- El código de tienda es estilo del proveedor + 3 letras de color + talla: `LT1558` + `ROS` + `M` = `LT1558ROSM`.
- La etiqueta lleva un código interno numérico, nombre corto, `MSILVA`, precio `C$ 2,161 (59)`, talla, color y código de barras.
- Qué significa `(59)` no se sabe todavía. Resultado del OCR: [ETIQUETA](ETIQUETA.md#real-tags-from-the-store-2026-11-13).

## Preguntas para la dueña

1. ¿Cobran en dólares en caja? ¿Quién pone la tasa del día y de dónde sale?
2. ¿Aplican retención de Fisco 2% y Alcaldía 1% en tienda, o solo a empresas?
3. ¿Qué es el número entre paréntesis en la etiqueta, `(59)`?
4. ¿Usan proforma, pedido o consignación en Masaya?
