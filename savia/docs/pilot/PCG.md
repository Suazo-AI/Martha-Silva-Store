# PCG en la tienda: lo que muestran los videos de Jason

Fuente: 3 videos de pantalla y 1 foto de recibo que Jason envió el 2026-11-13.
Los archivos, transcripciones y respuestas de modelos no entran a Git: muestran datos reales de la tienda.
Audio: transcrito con AssemblyAI (`universal-3-5-pro`, español), 3 trabajos completos, unos US$ 0.02.
Video: visto con AGY `gemini-4-hydrogen-high` a 1 cuadro por segundo, los 3 completos, más cuadros FFmpeg revisados a mano.
La respuesta del modelo es evidencia, no autoridad: las cifras clave se comprobaron con aritmética.
Los nombres de empleados y clientes vistos u oídos se omiten aquí.

## Lo que dice el personal (audio)

- PCG no funciona sin internet. El personal lo llama incómodo.
- La tasa de cambio se fijó en 36.6243 todo el año. Antes cambiaba cada día.
- No hay cuentas por pagar: las compras se pagan en efectivo o con tarjeta.
- PCG es un sistema genérico para todo tipo de negocio (retenciones, cheques); la tienda usa una parte.
- Devolución: se busca la factura por número y se puede devolver un solo producto. El sistema anterior obligaba a anular toda la factura.
- La bodega queda fija por terminal y el vendedor se llena solo.

## Pantallas vistas

### Facturación ("FACTURA – CONTADO (En Piso)")

- Encabezado: serie, número de factura, fecha, vendedor, bodega, lista de precio (`PRECIO PUBLICO`).
- Bodegas: `001 BODEGA CENTRAL`, `002 BODEGA PLAZA PASEO`, `003 BODEGA NATURA`, `004 INVENTARIO EN TRANSITO`.
- Cliente por defecto: `00000 CLIENTES VARIOS`, con tipo de identificación (cédula).
- Barra de opciones: Facturar, Proforma, Contado, Reservar, Servicio, Guardar en espera, Modo POS.
- Opciones del documento: descuento global, `IVA (15%)`, `Fisco (2%)`, `Alcaldía (1%)`, `Exonerado`, `Propina`, `Imprime $`, Imprimir (marcado).
- Llamar documentos: proforma, preventa, reserva, pedido, apartados, consignación, orden, venta aplicada.
- Columnas de la línea: código, no. parte, barras, referencia, producto, lote, color, talla, observación, saldo, medida, cantidad, precio.
- Códigos internos de producto alfanuméricos (`FAJMET20`) con código de barras numérico aparte.

### Devolución a cliente

- Diálogo `DEVOLUCION DE CLIENTES`: "Digita el numero de factura" y `Buscar`.
- Parte de la factura: contado o crédito, `T/C Fact 36.6243`, moneda, fecha, sucursal.
- Devolución parcial: se pone `1` en la columna Devolver de una línea. `Devolver todo` pide confirmación.
- Casillas: `Generar egreso de caja` (devolver efectivo) e `Incluir retenciones`.
- Totales: subtotal, descuento, I.V.A., retenciones, total; abonado y saldo pendiente.
- En los videos no se guardó ni imprimió ninguna devolución.

### Ventas en dólares

- La factura de ejemplo estaba en `Dolares`: US$ 168.00 en 2 productos, IVA 0.00.
- El recibo impreso dice `TOTAL C$ 6,152.88`, `TASA CAMBIO 36.6243`, `MONEDA DE PAGO: DOLARES`.
- Comprobado: 168 × 36.6243 = 6,152.88.

### Sistema y tipo de cambio

- `Sistema → T/C venta`: tabla mensual con una tasa por día (`Valor Venta` 36.6243; `Valor Contabilidad` 0).
- Módulos: Caja, Catálogos, Cuentas por Cobrar, Cuentas por Pagar, Facturación, Finanzas y Contabilidad, Importaciones, Inventario, Productos, Reportes, Sistema, Usuarios.
- Inventario: solicitud de salida, recibir, confirmar traslado, devolución de cliente, entradas, traslado, salidas.
- Reportes: cierre de caja diario, auditoría de cierre, verificar negativos, stock mínimo, existencia por marca, anticipos.

### Recibo de apertura de caja

- Conteo por billete y moneda en córdobas, y una sección aparte en dólares.
- La pantalla de apertura no aparece en los videos.

## Comparación con SAVIA hoy

| PCG | SAVIA hoy | Evidencia en SAVIA |
| --- | --- | --- |
| Sin internet no vende | El piloto corre en la PC de la tienda; vende sin internet. Un despliegue en la nube cambiaría esto | piloto localhost |
| Cobro en dólares a la tasa del día | No existe: no hay tabla de tasas ni pago en dólares convertido | sin `ExchangeRate` en `src` ni `db` |
| Conteo de caja por billete en C$ y US$ | Existe, en una sola moneda por sesión | `Savia.Contracts/Cash.cs` (`CashCountLine`) |
| I.V.A. por línea | Existe (`TaxRateBps` por artículo) | `V015`, `V024` |
| Retenciones `Fisco (2%)` y `Alcaldía (1%)` | No existe | sin `Retenc`/`Withhold` |
| Devolución parcial por línea | Existe, por línea y cantidad | `Savia.Contracts/Returns.cs` (`ReturnLine`) |
| Devolver efectivo desde la devolución | Existe como una de las 4 salidas | ronda 4, `V024` |
| Proforma, preventa, pedido, consignación, en espera | No existe | — |
| Apartados | Existe | [TRASLADOS-APARTADOS](TRASLADOS-APARTADOS.md) |
| Talla, color y lote en la línea | Talla y color por variante; sin lote | catálogo |

## Etiqueta de la tienda

- El código de tienda es estilo del proveedor + 3 letras de color + talla: `LT1558` + `ROS` + `M` = `LT1558ROSM`.
- La etiqueta lleva un código interno numérico, nombre corto, `MSILVA`, precio `C$ 2,161 (59)`, talla, color y código de barras.
- `(59)` es el precio en dólares: 59 × 36.6243 = 2,160.83, redondeado a C$ 2,161. Resultado del OCR: [ETIQUETA](ETIQUETA.md#real-tags-from-the-store-2026-11-13).

## Brecha principal

La tienda fija precios en dólares y cobra en córdobas o dólares a la tasa del día.
SAVIA solo maneja córdobas. Es la siguiente pieza a construir.

## Preguntas para la dueña

1. ¿Quién cambia la tasa si deja de ser fija, y aplica igual a las 3 sucursales?
2. ¿El precio base del producto es en dólares y el córdoba se calcula, o al revés?
3. ¿Aplican retención de Fisco 2% y Alcaldía 1% en tienda, o solo a empresas?
4. ¿Usan proforma, pedido, consignación o "guardar en espera" en Masaya?
