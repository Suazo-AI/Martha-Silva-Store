# SISFAIN: dominio comercial y alcance de sustitución

Task: SISFAIN-OPS-20261104. Modo: DISCOVER. Consulta: 2026-11-04 UTC / 2026-11-03 Managua.
Host verificado: SUAZO-PC. Modelo seleccionado por Jason en el paquete: gpt-6.1-sol, razonamiento high; no se midió aquí el backend efectivo.

Recomendación: aprobar primero un contrato operativo de sustitución con Martha.
La venta multiartículo debe ser obligatoria desde el primer flujo.
No conviene tratar la lista pública de módulos como inventario de su instalación.
El cuello de botella es conocer su configuración y sus reglas reales.
La siguiente validación útil es un recorrido autorizado con datos ficticios y documentos saneados.
Este informe no implementa ni ejecuta ese recorrido.

## Verificado públicamente

El nombre oficial es **SISFAIN Pro 4.0**.
CGA anuncia modalidades Local y Cloud según configuración. [Producto oficial](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/).

La página de clientes incluye el recurso `LogoMarthaSilva2` dentro de **Clientes SISFAIN en Nicaragua**.
Esto confirma la asociación publicada por CGA.
No confirma contrato activo, módulos, versión, datos, fechas de instalación ni uso actual. [Clientes oficiales](https://cgasoluciones.com/nuestros-clientes/).
El recurso enlaza a [LogoMarthaSilva2.jpg](https://cgasoluciones.com/wp-content/uploads/2023/06/LogoMarthaSilva2.jpg).
Se verificó el enlace, sin atribuir a la imagen texto no inspeccionado.

La categoría del sitio conserva una entrada del **21 de junio de 2023** con una referencia a operación multiusuario.
Su fragmento y la página actual no permiten fechar una actualización instalada. [Categoría oficial](https://cgasoluciones.com/service-category/sistemas/).

## Matriz: promesa pública frente a contrato propuesto

La columna pública resume únicamente el texto leído.
Todas las comprobaciones de la última columna son **propuestas propias**, pendientes de aprobación y ejecución.
La instalación de Martha es **desconocida en todas las filas**.
Una característica no hallada en estas páginas puede existir en el producto o en una personalización.

| Dominio | Evidencia pública | Comprobación propuesta para la sustitución |
| --- | --- | --- |
| Venta multiartículo | POS; multiartículo no explícito. [S1](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/) | Una factura con ≥3 SKU, cantidades diferentes, descuento y total reproducible. Confirmación íntegra o rechazo íntegro. |
| Cobro | Efectivo, tarjeta, transferencia y mixto según configuración. [S1](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/) | Desglosar importes, cambio y referencia. Registrar un pago con tarjeta no prueba integración con adquirente. |
| Descuentos | Descuentos autorizados. [S1](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/) | Acordar descuentos por línea/documento, límites, redondeo y actor que autoriza. |
| Devoluciones y cambios | No hallados explícitamente. [S1](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/) | Relacionar venta original, línea, cantidad, motivo, reembolso y destino del artículo. Impedir devolver de más. |
| Inventario | Existencias, entradas, salidas, compras y movimientos. [S1](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/) | Libro de movimientos conciliable con existencias. Identificar origen, actor y documento. |
| Variantes | Talla/color no explícitos. [S1](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/) | SKU vendible por talla/color. Mover una variante sin alterar otra. Definir códigos de barras y unidades. |
| Bodegas | Múltiples bodegas. [S1](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/) | Distinguir bodega de sucursal. Traslado con origen, destino y estado; impedir cantidades imposibles. |
| Conteo | Comparación física y ajustes revisables. [S1](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/) | Conteo por variante/bodega, diferencia, motivo y aprobación; ajustar exactamente una vez. |
| Compras y recepción | Compras; recepción parcial no explícita. [S1](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/) | Separar pedido, recepción física y factura. Permitir parcial y rechazar duplicados. Acordar costos y devolución al proveedor. |
| Cotizaciones | Proformas editables y conversión a factura. [S1](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/) | Acordar vigencia, reserva y actualización de precios. Revalidar existencias al confirmar; evitar doble conversión. |
| Crédito | Historiales, cuentas corrientes, cargos y abonos. [S1](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/) | Separar cuentas por cobrar/pagar. Aplicar abonos y devoluciones sin duplicarlos. Acordar vencimiento, límites y saldo inicial. |
| Caja | Preparación por vendedor y cobro centralizado opcional. [S1](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/) | Definir apertura, ingresos/egresos, arqueo, cierre y diferencias por medio de pago. No asumirlos incluidos. |
| Clientes/proveedores | Administración de ambos. [S1](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/) | Unificar identidad sin mezclar deudas. Aplicar mínimos de datos y controles contra duplicados. |
| Control y reportes | Permisos, bitácora, reportes; Excel condicionado. [S1](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/) | Trazar cambios sensibles y conciliar venta, stock, cobro y saldo. Probar exportación útil con datos ficticios. |

## Alcance recomendado; pendiente de aprobación

**Núcleo de sustitución:** venta multiartículo, devoluciones parciales, variantes, movimientos y conteo de inventario, recepción de compras, clientes/proveedores, cobros, permisos, conciliación y recuperación.
La decisión comercial debe cubrir el trabajo diario completo que Martha necesita conservar.
No declarar sustitución si un faltante obliga a operar dos libros incompatibles.

**Configuración por confirmar antes de cerrar alcance:** número de bodegas y cajas, separación vendedor/cajero, crédito, proformas, pagos mixtos, impuestos y documentos impresos.
Si un flujo se usa hoy, debe entrar en la aceptación o en una transición expresamente aprobada.
No excluir crédito o devoluciones solo porque la información pública es breve.

**Fuera de este informe:** implementación, migración de datos reales, integración bancaria, declaración fiscal, comercio público y aceptación productiva.
La mención comercial de tarjeta no demuestra un procesamiento bancario integrado.
No se cotizaron licencias, soporte, hardware ni migración.
No hay evidencia de precio o costo de sustitución suficiente para prometer ahorro.

## Tres escenarios mock; resultados esperados, no ejecutados

Estos contratos son propuestas propias.
Todos los nombres, importes, SKU y saldos son ficticios.
Los ejemplos usan C$ como unidad de prueba, sin afirmar moneda ni reglas tributarias de la instalación.
Los tres escenarios son independientes y reinician sus datos.
El precio de prueba es final; no modela cálculo fiscal.

### M1. Venta multiartículo, pago mixto y repetición

Inicio: `VEST-M-ROJO` stock 5 a C$1,200; `VEST-L-ROJO` stock 2 a C$1,200; `ACC-U` stock 10 a C$150.
Comprar 2, 1 y 3 unidades, respectivamente.
Aplicar 5% de descuento autorizado exclusivamente a los vestidos.
Subtotal: C$4,050. Descuento: C$180. Total: C$3,870.
Registrar efectivo C$2,000 y transferencia C$1,870.

Esperado: una venta, tres líneas y dos componentes de pago.
Stock final: 3, 1 y 7, respectivamente.
Repetir la confirmación con el identificador original debe devolver la misma venta.
No debe generar otro cobro ni otro movimiento.
Intentar luego vender 8 `ACC-U` junto con otro SKU debe rechazar toda esa nueva venta.
El rechazo debe conservar stock, caja y saldos.
Una recarga debe recuperar el documento original.

### M2. Compra, recepción parcial y deuda con proveedor

Inicio: `VEST-M-ROJO` stock 3; proveedor ficticio `PROV-01`, saldo 0.
Pedido: 10 unidades a C$700, total C$7,000.
Recibir primero 6 y después 4.
Registrar una factura del proveedor por C$7,000 y un pago de C$2,000.

Esperado: stock 9 después de la primera recepción y 13 después de la segunda.
El pedido debe mostrar 4 pendientes y luego 0.
La factura debe generar una sola deuda de C$7,000.
El pago debe dejar C$5,000 pendientes.
Repetir cualquiera de las dos recepciones no debe cambiar stock ni deuda.
Intentar una tercera recepción superior a lo pendiente debe rechazarse o exigir un cambio de pedido autorizado.
Esta política es propuesta; Martha debe confirmar cómo maneja sobrantes y facturas parciales.

### M3. Cotización, crédito y devolución parcial

Inicio: `VEST-L-AZUL` stock 2 a C$1,200; cliente ficticio `CLI-01`, saldo 0.
Preparar una cotización por 2 unidades, C$2,400.
Para este mock se propone que cotizar no reserve stock.
Convertirla una vez a venta a crédito y registrar un abono de C$400.
Devolver 1 unidad vendible y aplicar C$1,200 a la deuda.

Esperado: cotizar conserva stock 2 y saldo 0.
La venta deja stock 0 y deuda C$2,400.
El abono deja deuda C$2,000.
La devolución deja stock 1 y deuda C$800.
La segunda línea/unidad sigue vendida.
Repetir la devolución con el mismo identificador no cambia nada.
Intentar devolver 2 unidades adicionales debe rechazarse.
La caja registra el abono real de C$400; la devolución aplicada a deuda no crea un reembolso ficticio.
Si el artículo está dañado, la política debe enviarlo a un destino no vendible, pendiente de acuerdo.

## Preguntas de configuración y evidencia mínima

1. ¿Qué versión y módulos muestra la pantalla de instalación actual? Obtener versión y configuración saneadas.
2. ¿Cuántos SKU, variantes, bodegas, cajas y sucursales se usan? Separar cantidades operativas de registros históricos.
3. ¿Cómo se vende una factura con varios artículos, descuento y pago mixto? Recorrer un ejemplo ficticio y su recuperación.
4. ¿Cómo se resuelven devolución parcial, cambio de talla, artículo dañado y reembolso? Confirmar política y documento.
5. ¿Cómo llegan compras parciales y facturas del proveedor? Diferenciar mercadería, costo, deuda y pago.
6. ¿Se vende a crédito o se aceptan abonos? Confirmar vencimientos, límites y saldo pendiente.
7. ¿La cotización reserva stock o congela precio? Confirmar vigencia y condiciones de conversión.
8. ¿Qué arqueos, impresoras, lectores, reportes y exportaciones son indispensables? Nombrar el usuario y decisión que necesita cada salida.

No se solicita entregar bases, credenciales ni documentos de clientes.
El coordinador puede preparar capturas redactadas o una sesión autorizada con ejemplos ficticios.
No se debe introducir información real en un prototipo para responder estas preguntas.

## Bloqueos y cierre

| Bloqueo | Evidencia y causa conocida | Corrección intentada / resultado | Dueño, próxima acción y comprobación |
| --- | --- | --- | --- |
| Configuración de Martha desconocida | CGA publica asociación, sin ficha de instalación. Causa: faltan datos directos autorizados. | Investigación pública completada; no accedió al equipo ni a datos reales. | Martha + coordinador: confirmar preguntas anteriores. Cierra con recorrido autorizado y matriz aceptada por flujo. |
| Contratos detallados no públicos | Texto consultado no explicita multiartículo, variantes, devolución ni recepción parcial. Ausencia en texto no prueba ausencia funcional. | Cinco consultas buscaron fuentes adicionales; resultados pertinentes fueron producto, clientes y categoría oficiales. No se localizó manual verificable en ese conjunto. | Coordinador: no ampliar búsquedas genéricas; usar documentación saneada o demostración autorizada del servicio actual. Cierra con reglas observadas y límites. |
| Alcance de sustitución sin aceptación | Esta investigación propone pruebas, sin ejecutarlas ni aprobarlas por Martha/Jason. | Se prepararon M1–M3 con resultados deterministas. No hubo implementación ni verificación operativa. | Jason aprueba el contrato y prioriza faltantes después del recorrido. Cierra con aceptación explícita y pruebas posteriores del artefacto real. |

Lección aplicada: un catálogo comercial confirma promesas y asociación, no una configuración instalada.
La corrección mínima fue separar evidencia, preguntas y contratos propuestos en la matriz.
Verificación documental: enlaces y trazabilidad pública registrados en `sources.json`; cálculos M1–M3 revisados.
No se ejecutaron SQL, Docker, navegador, migración, pruebas de producto, compras, mensajes, Git ni despliegue.
No hay dictamen de reemplazo completo ni aceptación productiva.
