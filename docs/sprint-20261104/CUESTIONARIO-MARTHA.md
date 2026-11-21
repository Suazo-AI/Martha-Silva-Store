# Cuestionario: cómo se vende hoy en la tienda

**Propósito:** documentar los flujos de SISFAIN que SAVIA debe sustituir y preparar un ensayo.
**Método elegido D-029:** reconstrucción guiada con datos ficticios; este cuestionario completa los huecos.
Fecha y hora sin coordinar. La propuesta anterior del viernes 6 no es una cita confirmada.
**De:** Jason. **Para:** Martha. **Uso de las respuestas:** en el repositorio solo se guardan totales y decisiones; nunca nombres de clientes, montos de ventas reales ni datos personales.

## Contexto

SAVIA es el sistema interno para que el personal registre ventas y consulte existencias. Hoy funciona con datos de prueba. Jason confirmó que sustituiremos SISFAIN y que una factura debe permitir varios artículos. Necesitamos saber qué flujos y módulos usan hoy para conservar la operación completa. El coordinador SUAZO-PC acepta cada flujo del ensayo; Jason autoriza integración y despliegue.

## Cómo responder

Primero seguir el [guion de reconstrucción](GUION-RECONSTRUCCION-MARTHA.md), unos 30 minutos propuestos.
Después responder por escrito las preguntas que quedaron pendientes. "No sé" y respuestas aproximadas
también sirven: márcalas como aproximadas. No se espera cubrir todo en una llamada.

## La venta de cada día

### ¿Qué documento recibe el cliente al comprar: factura con número fiscal, recibo simple o ninguno?
¿Qué numeración, impuestos, exenciones, anulaciones y devoluciones usan? El contador debe validar los requisitos y la autorización aplicable antes de emitir desde el reemplazo. Se pueden describir formatos o mostrar ejemplos ficticios; no enviar facturas de clientes.

>

### Requisito decidido: varios artículos en la misma factura.
¿Cuál es un carrito habitual y uno grande, usando prendas e importes ficticios? ¿Hay descuentos por artículo, por factura o ambos? La cantidad nos ayuda a probar el requisito; no decide si se incluye.

>

### ¿Cuántas ventas hacen en un día normal y en un día fuerte?
_Por qué importa: con ese número fijamos cuántas ventas de prueba hacer y cuánto puede tardar cada una._

>

### SISFAIN es el servicio actual confirmado. ¿Qué versión y módulos usan?
Incluir proformas, compras, recepciones, traslados, cuentas por cobrar/pagar, abonos, caja, reportes y exportaciones que efectivamente necesitan. ¿Qué operación requiere hoy una hoja o cuaderno adicional?

>

## Existencias

### Si la prenda física existe aunque SISFAIN registre 0, se entrega: decisión ya tomada.
Para el ensayo sintético, Jason eligió que la cajera registre la excepción sin ajustes libres (D-026), y que otra persona revise al cierre, con suplente y causas abiertas si falta evidencia (D-027). El nuevo flujo todavía no está implementado ni aceptado. ¿Quién confirma SKU, talla y ubicación en la operación real? ¿Quién revisa las diferencias y quién la sustituye? ¿Qué evidencia y alertas usan? Se pide conocer la operación real, no volver a elegir la política del ensayo ni aprobar un ajuste automático +1/-1.

>

### ¿Las prendas de vitrina y de bodega se cuentan juntas? ¿Otra sucursal o la venta en línea usan las mismas prendas?
_Por qué importa: si dos canales venden la misma prenda sin un registro común, se puede vender dos veces la última unidad._

>

### ¿Qué 5 a 10 tipos de prendas, con talla y color inventados, conviene representar en el ensayo sintético?

No pedimos existencias ni ventas reales. El ensayo posterior usará datos ficticios en SUAZO-PC;
no se registran pruebas en la operación productiva.

>

## Devoluciones y cambios

### ¿Cuántas devoluciones o cambios hay en un mes, aproximadamente, y quién los autoriza?

¿Se devuelve parte de una factura? ¿El reintegro va a efectivo, transferencia, saldo a favor o deuda? ¿Qué pasa con la prenda dañada?

>

## Personas y permisos

### ¿Quién vende, quién recibe mercadería y quién puede corregir existencias?
_Por qué importa: SAVIA tiene cuatro perfiles (dueña, encargada, cajera e inventario) y cada uno puede hacer cosas distintas._

>

### ¿Cada persona usa su propio equipo o comparten uno en la caja?

>

## La caja

### ¿Qué medios de pago usan y se pueden combinar? ¿Venden a crédito o reciben abonos?

Describir apertura, cambio, retiros, gastos, arqueo, cierre, diferencias y saldos pendientes con ejemplos ficticios. Registrar un pago con tarjeta es distinto de procesarlo con un banco.

>

### ¿Qué equipo hay en la caja (computadora, tableta o teléfono) y qué internet usa (wifi o datos)?
_Por qué importa: la velocidad se mide en ese equipo y esa red, no en una computadora de oficina._

>

### ¿Se cae el internet en la tienda? ¿Con qué frecuencia y por cuánto tiempo?
_Por qué importa: SAVIA tiene que recuperar una venta cuya respuesta se perdió, sin cobrar ni descontar dos veces._

>

## El ensayo propuesto

### ¿Quién puede dedicar 45 minutos a probar cinco tareas sin ayuda del agente y qué equipo usará?

Fecha y hora por acordar después de C2/C9 y de completar los módulos del flujo. Para medir 30 ventas y recuperación, reservar tiempo adicional según el guion.

>

### Responsable decidido: el coordinador SUAZO-PC acepta o rechaza cada flujo con evidencia.

Martha aporta reglas y datos de operación. Quien vende ejecuta las tareas. Jason conserva las decisiones de integración y despliegue. Asignar el responsable no significa que el ensayo esté aceptado.

>

## ¿Algo más?

¿Hay algo de cómo trabajan que no preguntamos y deberíamos saber?

>

## Migración y continuidad

¿Qué reportes/exportaciones permiten conservar catálogo, stock por ubicación, ventas, saldos y documentos pendientes? ¿Qué información histórica necesitan consultar después del cambio?

Solo se solicitan descripción y agregados. Un acceso, exportación o migración con datos reales requiere alcance separado. No cancelar el servicio actual antes de reconciliar y aceptar el reemplazo.

>

Versión vigente: 2026-11-04 America/Managua, D-022 a D-029. Las imágenes antiguas del cuestionario quedan históricas si contradicen esta versión; no enviarlas sin regenerar. No se envió este documento a Martha.
