# SISFAIN: alcance fiscal y financiero del reemplazo

Task ID: `SISFAIN-FISCAL-20261104`.
Modo: DISCOVER. Corte: 2026-11-04, 05:56 UTC. Host: SUAZO-PC.
Modelo y esfuerzo asignados por el coordinador: `gpt-6.1-sol`, `high`.

**Resultado: matriz de descubrimiento terminada; validación fiscal vigente incompleta.**
No hay evidencia suficiente para emitir documentos fiscales desde el reemplazo.
La prioridad propuesta es mapear documentos y saldos con Martha y su contador antes de definir emisión o migración.
La investigación no determina el régimen tributario de Martha.

## Evidencia y alcance

Leí `github/AGENTS.md`, `docs/PROJECT-STATUS.md`, el playbook común y el contrato OUTPUT.
El proyecto mantiene separados el sistema interno, la tienda pública y la aceptación de producción.
Este informe no ejecuta ni aprueba SAVIA, SQL, certificados, Docker o despliegues.

La documentación comercial accesible identifica **SISFAIN Pro 4.0**.
Anuncia ventas, compras, inventarios, pagos mixtos, créditos, cuentas corrientes, cargos, abonos y reportes.
La exportación a Excel depende de que la función esté disponible.
Estas son declaraciones del proveedor, sin prueba de la versión o configuración instalada en Martha.
No prueban autorización fiscal, API, exportación completa, contabilidad general ni cierre contable.
[CGA: SISFAIN](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/).

Las páginas oficiales DGI presentan restricciones de acceso.
El buscador mostró fragmentos históricos oficiales; estos no equivalen a legislación consolidada vigente.
La apertura inicial de Crédito Fiscal devolvió una página identificable, pero no permitió evaluar todo su contenido.
Su segunda lectura devolvió rechazo.
No conseguí abrir una norma relevante íntegra desde Asamblea dentro del límite aprobado.

## Lo que las fuentes permiten afirmar

| Fuente | Evidencia consultada | Aplicabilidad y límite |
| --- | --- | --- |
| [DGI: Otros trámites](https://www.dgi.gob.ni/FAQ/otros_tramites.htm) | El índice oficial enumera una solicitud de autorización de facturación computarizada. Menciona identidad del sistema y proveedor, seguridad, respaldo, manuales, numeración, formalidades, impuestos, anulaciones y copias. Cita D.T. 09-2007. | Contenido histórico indexado. Apertura rechazada. No prueba requisitos actuales ni autorización de Martha. |
| [DGI: Obligaciones IVA](https://www.dgi.gob.ni/FAQ/obligaciones_de_los_responsabl.htm) | El índice describe numeración consecutiva, datos del emisor, detalle, precios, impuesto o razón de exención. Describe conservación de original y duplicados al anular. Cita LCT art. 143 y Reglamento art. 100. | Orientación histórica para responsables recaudadores. Apertura rechazada. No asigna ese carácter a Martha. |
| [DGI: Crédito Fiscal](https://www.dgi.gob.ni/FAQ/credito_fiscal.htm) | El índice distingue IVA trasladado y crédito fiscal de compras. Vincula devoluciones con ajustes y cita LCT art. 123. | No confundir crédito fiscal con venta al crédito. Procedimiento actual y período de ajuste pendientes de texto vigente y contador. |
| [DGI: Consultas generales](https://www.dgi.gob.ni/FAQ/consultas_generales2.htm) | El índice menciona cuatro años para información tributaria y cita Código Tributario art. 43. | Apertura rechazada. No usar ese extracto como política de borrado. Plazo aplicable, cómputo y otras obligaciones requieren validación profesional. |

**Vigencia legal confirmada en esta investigación: ninguna regla consolidada al corte.**
Las referencias anteriores sirven para ubicar preguntas y normas.
No establecen tasas, exenciones, plazos definitivos ni un permiso transferible entre sistemas.
Comprar o construir software tampoco demuestra que sus documentos estén autorizados para Martha.

## Matriz propuesta de descubrimiento y aceptación

Las siguientes filas son requisitos candidatos y pruebas propias.
No son obligaciones legales declaradas vigentes.

| Área | Información que debe entregar Martha o el contador | Prueba propuesta del reemplazo |
| --- | --- | --- |
| Identidad y régimen | Razón social, RUC, administración de rentas, régimen, obligaciones activas y sucursales. | Configuración explícita. Ninguna tasa se deduce del nombre del negocio o producto. |
| Factura y recibo | Una muestra saneada de cada documento. Identificar venta, cobro, abono, anticipo y cotización. | Cada operación genera el documento acordado. Un cobro de deuda no crea otra venta. |
| Autorización del sistema | Carta/resolución vigente y alcance. Confirmar procedimiento al sustituir nombre, proveedor o versión. | El contador valida el formato y la ruta de autorización antes de emitir. No reutilizar una autorización por inferencia. |
| Numeración | Series, sucursales, último número, rangos impresos, números anulados y permisos de corrección. | Dos cajas concurrentes y un reintento no duplican números. Cada anulación conserva su trazabilidad. |
| Impuestos y descuentos | Reglas por artículo/operación, precios con o sin impuesto, retenciones, redondeo y moneda. | Comparar resultados con ejemplos aprobados por el contador. No fijar una tasa general por defecto. |
| Exento y exonerado | Diferenciar cada tratamiento, fundamento, beneficiario y soporte que realmente usa Martha. | El tratamiento exige datos y respaldo acordados. Un descuento no se convierte en exención. |
| Devolución y nota | Casos del mismo día y días posteriores, devoluciones parciales, cambio de producto, reembolso y nota de crédito/débito utilizada. | Referencia al documento original. Separar ajuste de venta, impuesto, inventario, saldo y devolución de dinero. |
| Anulación | Quién autoriza, motivo, tratamiento de copias, numeración y correcciones permitidas. | El documento emitido permanece auditable. No borrar su historia para corregirlo. |
| Crédito y abonos | Plazos, vencimientos, anticipos, pagos parciales, sobrepagos, mora y documentos de cobro. | Aplicar cada abono a la deuda correcta. Mostrar saldo y vencimiento. Reversar un pago sin duplicar ingreso. |
| Cuentas por cobrar | Saldos abiertos, notas, abonos sin aplicar y conciliación por cliente al corte. | Total por documento = auxiliar por cliente = saldo de apertura firmado. |
| Cuentas por pagar | Compras, proveedores, devoluciones, retenciones y abonos pendientes. | Conciliar saldos por documento y proveedor. Separar recibir mercadería, registrar deuda y pagarla. |
| Caja y cierres | Apertura, retiros, gastos, efectivo, tarjetas, transferencias, pagos mixtos y diferencias. | Arqueo por medio de pago. Separar cierre de caja, cierre fiscal y cierre del negocio. |
| Conservación | Política aprobada por contador, documentos físicos/digitales, autorizaciones y períodos necesarios. | Recuperar una operación con su soporte y cambios. No eliminar históricos por un plazo tomado del buscador. |
| Exportación | Formatos disponibles, campos, adjuntos, catálogos, documentos cerrados/abiertos y acceso histórico acordado con CGA. | Exportación de prueba con datos ficticios. Conciliar conteos, totales, relaciones, series y saldos. Excel por sí solo no prueba migración completa. |
| Contingencia y corte | Procedimiento actual sin energía/red, facturas manuales y fecha del cambio. | Capturar operación de contingencia una sola vez. Poder volver al sistema anterior con saldos conciliados y sin doble emisión. |

## Tres escenarios ficticios

**Todos los importes son ilustrativos en córdobas, C$.**
Son ejercicios administrativos sin RUC, serie fiscal ni tasa tributaria configurada.
No son documentos fiscales reales ni ejemplos de tratamiento tributario autorizado.

1. **Venta y cobro mixto.** Total pactado C$1,000. Cliente paga C$600 en efectivo y C$400 por transferencia. Verificar una venta, dos aplicaciones de pago, saldo cero y una sola salida de inventario. Repetir la solicitud no agrega otra venta. El contador debe proporcionar después el desglose tributario correcto.

2. **Crédito, abono y devolución posterior.** Venta pactada C$2,400. Abono C$600. Saldo C$1,800. Después se acepta devolución por C$400. Si se aplica a deuda, saldo C$1,400. Verificar documento de ajuste vinculado y una unidad devuelta al estado de inventario acordado. No registrar reembolso en efectivo si no ocurrió. El contador decide documento fiscal, impuesto y período afectados.

3. **Caja y proveedor.** Efectivo inicial C$500. Ventas cobradas en efectivo C$1,000. Cobro de deuda anterior C$400. Pago a proveedor C$300. Reembolso efectivo C$200. Efectivo esperado C$1,400. Cobros por tarjeta C$700 permanecen fuera del cajón. Deuda inicial al proveedor C$1,200 menos pago C$300 deja C$900. Verificar caja, cuentas por cobrar y cuentas por pagar separadas. No deducir utilidad ni impuesto de estos movimientos.

## Bloqueos y siguiente acción

| Bloqueo | Evidencia / causa | Corrección intentada y resultado | Dueño y cierre |
| --- | --- | --- | --- |
| No hay texto legal vigente íntegro evaluado | Cuatro aperturas DGI rechazadas. Causa del filtro desconocida. | Busqué fuentes oficiales alternativas. No obtuve legislación relevante consolidada dentro de 16 consultas/aperturas. | Contador: confirmar normas actuales y requisitos aplicables con fuente oficial íntegra o respuesta DGI. |
| No se conoce configuración fiscal de Martha | No se recibieron constancias ni muestras. | No accedí a cuentas ni datos reales porque están fuera del encargo. | Martha/contador: entregar muestras saneadas y matriz tributaria validada. |
| No se conoce continuidad jurídica de emisión | No se inspeccionó autorización actual ni procedimiento de sustitución. | Preparé preguntas y aceptación documental. No contacté DGI ni proveedor. | Contador: decidir trámite y validar autorización antes de emitir desde el reemplazo. |
| No se conoce migración financiera disponible | El proveedor solo promete exportación condicional. No se recibió archivo. | Preparé conciliación y escenarios ficticios. No exporté información privada. | Martha/proveedor: acordar exportación saneada y cotejar saldos iniciales antes de retirar SISFAIN. |

**Siguiente acción recomendada:** una sesión con Martha y su contador usando muestras saneadas.
Resolver primero identidad/régimen, autorización, documentos y saldos abiertos.
Después convertir la matriz acordada en criterios de reemplazo.

Lección aplicada: una FAQ indexada ayuda a formular preguntas, pero no demuestra vigencia ni autorización de una empresa.
La corrección fue separar evidencia comercial, referencias históricas y pruebas propuestas.
La revisión documental comprobó que no se asigna una tasa ni se declara autorizado el reemplazo.

Uso: 16 consultas/aperturas web, incluyendo 4 adicionales autorizadas por el coordinador.
No usé Firecrawl, cuentas, mensajes externos, compras ni generación pagada.
El costo y los tokens exactos no fueron reportados por las herramientas.
Cambios: únicamente este informe y `sources.json` en la carpeta asignada.
