# Guion para reconstruir una venta con Martha

Decisión D-029 adoptada por Jason el 2026-11-04, America/Managua.
Estado: preparado; conversación sin coordinar ni realizar. Todos los datos del ejemplo son ficticios.
Objetivo: comprender una venta real de su proceso, representada con datos inventados,
desde elegir prendas hasta revisar el cierre. No es todavía la aceptación del sistema SAVIA.

## Preparación de Jason

Reservá unos 30 minutos como propuesta, sin prometer que resolveremos todo C2.
Tené este guion y una hoja para anotar. No necesitás saber programar ni manejar SISFAIN.
Martha conoce la tienda; vos seguís el recorrido y pedís ejemplos cuando algo no quede claro.
No hace falta grabar. No ingresés ventas ficticias, comprobantes ni ajustes en el sistema productivo.
Si existe un entorno de prueba autorizado y separado, puede mostrarse allí. Si no, usen papel y relato.

En el repositorio público solo van conclusiones saneadas y ejemplos ficticios.
No copies clientes, ventas reales, cuentas bancarias, credenciales ni pantallas sin revisar.
No se pide exportar bases ni acceder a su cuenta. Un resumen textual suele ser suficiente.

## Lo que ya está decidido

- Una factura debe admitir varios artículos. No le preguntés si quiere esa capacidad.
- El objetivo es sustituir SISFAIN, conservando las funciones que la tienda necesita.
- El ensayo posterior será en SUAZO-PC con datos sintéticos; no fija el equipo productivo.
- En el ensayo, cajera registra la excepción de stock cero y otra persona revisa al cierre.
- Si falta la encargada, revisa un suplente. La causa sin evidencia queda abierta.
- Martha confirma su práctica actual. SUAZO-PC emite el dictamen del ensayo y Jason decide integración y despliegue.

Preguntar cómo opera hoy no vuelve a decidir esas reglas ni obliga a Martha a decir que ya trabaja así.

## Abrí la conversación — 2 minutos

**Podés decir:** «Martha, queremos entender cómo trabajás para que el sistema te facilite
la venta y te deje registros claros. Voy a representar una clienta. Contame cada paso,
incluso los que te parezcan obvios. Usaremos prendas y cantidades inventadas».

«Si algo no lo sabés o lo lleva otra persona, lo anotamos pendiente. No necesitás adivinar».

**Primera pregunta:** «¿Qué versión o nombre aparece en SISFAIN? ¿Qué usás además de ese sistema,
como cuaderno, Excel, calculadora, terminal bancaria o aplicación del banco?»

Anotá nombres de herramientas y función. Si la versión se desconoce, dejala pendiente.
Esto permite descubrir trabajo que se perdería si solo copiamos las pantallas del sistema actual.

## La venta que vamos a representar

**EJEMPLO FICTICIO — NO ES FACTURA NI COMPROBANTE VÁLIDO.**

| Artículo de ejemplo | Identificación inventada | Cantidad | Precio unitario | Existencias de ejemplo antes |
| --- | --- | --- | --- | --- |
| Blusa azul, talla M | SIM-BLU-AZ-M | 1 | C$350 | 5 |
| Pantalón negro, talla S | SIM-PAN-NE-S | 1 | C$650 | 2 |

Total de referencia: C$1,000, **sin descuentos ni cargos adicionales en este ejemplo**.
No presupone tratamiento fiscal. Preguntá si los precios reales incluyen impuestos y cómo se presentan.
Si su práctica requiere otra estructura, anotala aparte; no cambies silenciosamente los números del ejemplo.

## 1. Identificar prendas y precio — 4 minutos

**Decí:** «Soy la clienta y llevo estas dos prendas a caja. ¿Qué hacés primero?»

**Preguntá:**

- «¿Escaneás una etiqueta, buscás por nombre o escribís un código?»
- «¿Cómo distinguís esa blusa de otra talla o color? ¿El código distingue cada variante?»
- «¿El precio lo toma el sistema, una etiqueta o una lista? ¿Quién puede cambiarlo?»
- «¿Vitrina, bodega u otra sucursal comparten el mismo inventario? ¿La venta en línea también lo usa?»

**Necesitamos comprobar con Martha:** cómo se identifica cada variante, de dónde sale el precio
y qué ubicación entrega la prenda. Pedí un ejemplo inventado si «se busca y ya» no explica el paso.

**Después deberá demostrar SAVIA:** seleccionar la variante y ubicación correctas;
una talla M no descuenta una S. Las dos líneas y su precio quedan visibles antes de confirmar.
Es un requisito por comprobar, no una capacidad certificada por esta conversación.

## 2. Armar la factura — 4 minutos

**Decí:** «Agreguemos la blusa y el pantalón. Antes de cobrar, mostrame en papel o contame qué debería verse».

**Preguntá:**

- «¿Qué datos son obligatorios? ¿Cuándo necesitás datos de la clienta y por qué?» No recolectés datos reales.
- «¿Podés revisar y corregir una línea antes de confirmar? ¿Qué acción termina la venta?»
- «¿Los descuentos son por prenda, por factura o ambos? ¿Quién los autoriza?»
- «¿El precio incluye impuestos? ¿Qué documento y numeración usan? ¿Quién confirma estos requisitos con el contador?»

**Necesitamos comprobar con Martha:** las dos prendas pertenecen a una sola operación,
qué datos pide, cuándo queda confirmada y qué correcciones requieren autorización.

**Ejemplo adicional solo si usa descuentos:** 10% sobre la blusa son C$35;
blusa C$315 + pantalón C$650 = C$965, antes de cualquier tratamiento adicional que corresponda.
Este ejemplo no establece una política de descuentos ni una regla fiscal.

**Después deberá demostrar SAVIA:** varias líneas en una factura, cálculo reproducible,
reglas de precio e impuestos confirmadas y permisos de corrección. El contador valida la parte fiscal;
esta charla no autoriza emitir documentos fiscales desde SAVIA.

## 3. Cobrar y conservar el comprobante — 5 minutos

**Decí:** «La venta de ejemplo suma C$1,000. Usemos una forma de pago que realmente aceptás».

**Preguntá primero:** «¿Qué medios usás hoy? ¿Aceptás combinarlos? ¿Vendés a crédito o recibís abonos?»
Seguí un medio habitual. Las variantes restantes quedan anotadas para otro recorrido.

**Caso efectivo ficticio, si aplica:** entrego C$1,200, me devolvés C$200; ingreso neto C$1,000.
«¿Dónde queda registrado lo recibido y el cambio? ¿Quién puede corregir un cobro equivocado?»

**Caso mixto ficticio, solo si confirma que lo usa:** C$600 en efectivo + C$400 por transferencia.
«¿Qué te demuestra que la transferencia llegó? ¿Qué pasa si solo tengo una captura y el banco no la confirma?»
Una captura o un pago anotado no prueban por sí solos dinero acreditado.

**Si usa tarjeta:** «¿El sistema procesa el cobro o solo anotás lo que aprobó una terminal aparte?
¿Qué pasa si la terminal rechaza o no responde?» No pedir números de tarjeta ni datos bancarios.

**Después preguntá:** «¿Qué comprobante recibe la clienta? ¿Cómo lo relacionás con venta y cobro?
¿Podés volver a consultarlo sin volver a vender ni cobrar?»

**Necesitamos comprobar con Martha:** medio, importe, estado del cobro, confirmación requerida,
documento entregado y forma de buscar la operación. Si crédito aplica, separar saldo pendiente de dinero cobrado.

**Después deberá demostrar SAVIA:** cada importe queda vinculado a la venta correcta;
el total de pagos y deuda explica el total facturado. Reintentar o reimprimir no duplica cobros ni ventas.
Registrar pagos y procesarlos con un proveedor son capacidades distintas; ambas requieren pruebas según el alcance confirmado.

## 4. Entregar y revisar inventario — 4 minutos

**Decí:** «Ya cobraste y entregaste las dos prendas. ¿Cuándo se descuenta cada una?»

**Preguntá:** «¿Al armar la factura, al confirmarla, al cobrar o al entregar?
Si cancelás antes de entregar, ¿qué se libera? ¿Quién recibe y registra mercadería nueva?»

**Referencia ficticia normal:** blusa de 5 a 4; pantalón de 2 a 1.
Necesitamos una venta con dos salidas correctas. Reconsultar el comprobante no produce otra salida.

**Variante separada de stock cero:** reiniciamos el ejemplo del pantalón: el registro dice 0,
pero hay 1 prenda física identificada. No mezclar esta variante con el saldo normal de 2.

**Decí:** «¿Cómo resolvés esto hoy y qué evidencia conserva la tienda? Para nuestro ensayo
ya elegimos registrar la excepción y revisarla al cierre. Queremos conocer tu proceso actual».

**Preguntá:** «¿Quién revisa? ¿Quién la sustituye? ¿Cómo queda anotado qué salió, quién actuó
y qué causa sigue sin comprobar? ¿Qué recepción o traslado podría explicar la diferencia?»

**Necesitamos comprobar con Martha:** identidad y ubicación de la prenda, responsables por función
y registros que permiten investigar. No deduzcas robo ni recepción omitida desde un cero.

**Después deberá demostrar SAVIA:** venta y excepción vinculadas, sin ajuste libre de cajera;
revisión por otra persona al cierre, suplencia y causa abierta con responsable y próxima revisión.
No inventar un +1/-1 ni quitar la guarda actual de existencias. Su implementación sigue pendiente.

## 5. Cerrar caja — 4 minutos

**Decí:** «Terminó el día. ¿Qué comparás para saber si ventas, cobros e inventario tienen explicación?»

**Ejemplo ficticio independiente:** fondo inicial C$500 + venta en efectivo C$1,000
− retiro autorizado C$200 = efectivo esperado C$1,300. No hubo otras operaciones.
Este ejemplo usa la venta totalmente en efectivo; no incluye la transferencia del caso alternativo.
Si contás C$1,250, faltan C$50 frente al registro. No inventemos un gasto para cuadrar.

**Preguntá:**

- «¿Dónde registrás fondo inicial, retiros y gastos? ¿Qué respaldo queda?»
- «¿Separás efectivo, transferencias, tarjetas y ventas a crédito en el cierre?»
- «¿Quién cuenta, quién compara y quién revisa diferencias? ¿Quién sustituye a esa persona?»
- «Si faltan C$50 y no conocemos la causa, ¿qué dejás abierto y quién lo sigue?»

**Necesitamos comprobar con Martha:** una explicación de cada saldo, registros de respaldo
y responsable de diferencias. Caja revisada no equivale a inventario conciliado ni banco liquidado.

**Después deberá demostrar SAVIA:** cierre por medio de pago, movimientos trazables y diferencias visibles.
Para el ensayo, causas sin evidencia permanecen abiertas; se conserva responsable y próxima revisión.

## 6. Cerrá la conversación — 3 minutos

**Decí:** «Voy a repetir lo que entendí: identificás así las prendas, confirmás la venta aquí,
verificás el cobro de esta manera y revisás estos registros al cierre. ¿Qué entendí mal o qué faltó?»

Pedile que confirme o corrija el resumen. Marcá qué fue relato y qué pudo observarse realmente.
El objetivo de estos 30 minutos se cumple con un primer recorrido coherente y los huecos identificados.
No se completa automáticamente C2 ni se acepta SAVIA con esta conversación.

## Si queda tiempo: variantes que no podemos olvidar

| Situación ficticia | Pregunta para Martha | Comprobación posterior que necesitamos definir |
| --- | --- | --- |
| Devuelve solo la blusa de C$350 de la venta base | «¿Quién autoriza, cuánto devolvés, por qué medio y cómo vinculás la factura original?» | Conservar pantalón C$650; devolución parcial trazable. Impuestos y descuentos deben seguir las reglas confirmadas |
| La blusa devuelta está dañada | «¿Se vende otra vez, se aparta o se da de baja? ¿Quién decide?» | No aumentar automáticamente stock vendible por una devolución dañada |
| La pantalla se queda esperando después de confirmar | «¿Cómo sabés si la venta quedó hecha? ¿Volvés a cobrar o buscás el comprobante?» | Recuperar estado sin duplicar venta, salida ni cobro; el relato no prueba esa recuperación en SAVIA |
| Se piden 10 blusas y llegan 8 | «¿Registrás pedido y recepción por separado? ¿Dónde quedan las 2 pendientes?» | Distinguir recibido, pendiente y disponible; no crear 10 unidades disponibles por el pedido |
| Se deja un saldo de C$400 a crédito | «¿Quién puede autorizarlo, dónde queda la deuda y cómo aplicás después un abono?» | Separar venta, cobro, saldo y abono; incluir solo si confirma este uso |
| Cambiamos de sistema | «¿Qué históricos, saldos, documentos y exportaciones necesitás conservar? ¿Qué equipo, impresora e internet usás?» | Matriz de sustitución, migración y equipo pendientes; sin exportar datos reales en esta charla |

Si no alcanza el tiempo, anotá la persona que debe responder y la próxima consulta.
No fuerces respuestas de fiscalidad o banco que correspondan al contador o proveedor.

## Hoja de registro: usar durante la llamada

Todas las celdas están **pendientes** hasta recibir evidencia; los ejemplos no son respuestas de Martha.
Una «brecha» es la diferencia entre lo necesario y lo que tenemos demostrado.

| Paso | Práctica actual, con palabras de Martha | Evidencia y tipo | Requisito para el reemplazo | SAVIA comprobado / brecha | Quién aclara / próxima acción |
| --- | --- | --- | --- | --- | --- |
| Artículo, variante, ubicación y precio | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |
| Factura, impuestos y correcciones | Pendiente | Pendiente | Multiartículo ya obligatorio; resto pendiente | Pendiente | Pendiente |
| Cobro y confirmación | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |
| Comprobante y consulta posterior | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |
| Entrega, movimientos y stock cero | Pendiente | Pendiente | D-026/D-027 para ensayo; práctica actual pendiente | Nuevo flujo de excepción no implementado ni probado | Pendiente |
| Cierre, suplencia y diferencias | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |
| Variantes, versión, fiscalidad, migración y equipo | Pendiente | Pendiente | Pendiente | Pendiente | Pendiente |

**Tipos de evidencia:**

- **Declarado:** Martha lo explica. Guardar fecha y función de quien lo confirmó, sin datos personales innecesarios.
- **Observado:** se vio un paso en un entorno seguro autorizado. Indicar entorno y alcance; una maqueta no prueba SISFAIN ni SAVIA.
- **Pendiente:** nadie lo confirmó o hay respuestas distintas. No completar con supuestos.
- **SAVIA probado:** exige evidencia propia del sistema y versión concreta. No se deriva de las tres categorías anteriores.

Si dos respuestas contradicen el mismo paso, anotá ambas y quién debe resolverlo.
Antes de publicar conclusiones, quitá información personal o comercial identificable.

## Qué me devolvés después

Un resumen saneado con estos cuatro puntos basta para empezar:

1. «Así hace Martha una venta completa», con los pasos que confirmó.
2. Medios de pago, comprobante, versión/módulos y equipo confirmados o marcados pendientes.
3. Qué pudo observarse y qué fue únicamente explicado.
4. Preguntas abiertas, función responsable y próxima consulta.

No necesitás mandarme grabaciones, credenciales ni documentos de clientes.
Con ese resumen prepararé la matriz proceso → requisito → prueba → brecha.
El siguiente trabajo será priorizar esas brechas; no habilitar producción por haber completado una entrevista.
