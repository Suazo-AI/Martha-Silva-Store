# Crítica de la excepción con stock registrado 0

**Dictamen:** recomiendo la propuesta nueva, con controles previos y conciliación basada en evidencia.
“Validar al cierre” es insuficiente si significa aprobar todo sin investigar.
Jason decide la política.
Este informe no la aprueba ni demuestra implementación.

Fecha: 2026-11-04.
Host observado: SUAZO-PC.
Modelo solicitado por Jason: gpt-6.1-sol / high.
No dispongo de una medición independiente del backend efectivo.

## Qué está verificado

D-023 exige varios artículos por factura.
D-025 fija SUAZO-PC y datos sintéticos para el ensayo.
La entrega de una prenda física existente ya está decidida.
D-025:121-125 propone que cajera registre la excepción y encargada concilie; todavía requiere implementación y pruebas.

El README:83-90 conserva otra propuesta: encargada autoriza +1 y luego venta −1.
No son el mismo permiso.
Ninguna demuestra que la aplicación permita hoy este flujo.
Los pagos y la validez fiscal quedan fuera de esta evaluación.

## Venta ficticia, explicada paso a paso

Supongamos una factura con dos prendas.

La blusa azul M tiene registro 5 y un conteo inicial correcto de 5.
Se entrega una.
El movimiento normal resta 1: registro 4 y físico 4.

El pantalón negro S tiene registro 0.
La cajera sostiene un pantalón negro S de la ubicación indicada.
Hay una unidad observada; eso no demuestra el total de toda la tienda.

**Cajera:** “Confirmé etiqueta, talla y ubicación. Esta prenda dice 0. Registraré su entrega con incidencia”.

**Sistema propuesto:** “Una factura, dos líneas. Una salida normal y una salida excepcional. La incidencia queda vinculada”.

**Encargada:** “Verificaré el origen de la diferencia y el conteo. No crearé una compra ni aprobaré +1 automáticamente”.

Son cuatro acciones distintas:

- **Registrar venta:** cajera documenta artículos y cantidades realmente entregadas.
- **Conceder excepción:** la política autoriza una salida específica, bajo condiciones. No concede ajustes libres.
- **Corregir cantidad u origen:** encargada investiga y registra la corrección sustentada, con motivo y vínculo.
- **Revisar:** encargada comprueba evidencia, repetición y resolución. Revisar no equivale a corregir.

Si esa salida parte de registro 0, el saldo contable provisional es −1.
Ese número representa una diferencia pendiente; no significa que exista una prenda física negativa.
La disponibilidad para nuevas ventas no debe convertir esa diferencia en unidades disponibles.

Es fiable que salió una unidad identificada, si la entrega quedó demostrada.
El total físico restante sigue desconocido sin conteo.
Un ajuste posterior exige explicar la diferencia o registrar explícitamente que su causa sigue desconocida.

## Objeciones críticas y salvaguardas

**Talla o ubicación equivocada.**
Si la etiqueta dice M y la pantalla S, la cajera corrige la línea antes de entregar.
Si procede de otra ubicación, registra su origen real.
La encargada verifica el conteo afectado y cualquier traslado.
Vender S y aumentar S escondería un problema de identificación.

**Encargada ausente.**
Su ausencia no debe detener una entrega ya autorizada por política.
La cajera usa una facultad previamente delimitada, identifica la prenda y deja incidencia.
Una segunda persona confirma cuando esté disponible.
Si no está, queda explícita la falta de corroboración.
La encargada o suplente recibe responsable y plazo; no una aprobación atribuida ficticiamente.

**Cierre sin resolución.**
Se puede registrar el cierre operativo con incidencia abierta.
No se declara inventario conciliado.
Quedan cantidad afectada, evidencia disponible, investigación pendiente, responsable y siguiente turno de revisión.
La encargada investiga; Jason resuelve faltas de responsable.
El cierre de la incidencia exige evidencia revisada, no solo una firma.

**Duplicación y abuso repetido.**
Un reintento conserva la misma operación e incidencia.
Dos cajas no pueden adjudicarse la misma unidad.
Anulaciones y devoluciones deben enlazarse, sin borrar el historial.
Repeticiones por cajera, SKU o ubicación disparan revisión pronta.
La recurrencia puede indicar importación defectuosa, capacitación insuficiente o abuso; no demuestra fraude.

**El +1/−1 circular.**
Terminar en 0 no prueba que el inventario inicial estuviera bien.
El +1 es defendible con conteo y explicación registrados.
No sirve si se deduce únicamente de “necesito vender una”.
Tampoco corresponde inventar compra, costo o margen.

## Dos opciones realistas

**A. Excepción delimitada a cajera; investigación de encargada. Recomendada.**
Preserva la venta y reduce esperas.
Exige identidad confirmada, trazabilidad y revisión con plazo.
Aumenta trabajo de seguimiento y deja incertidumbre visible hasta resolverla.

**B. Encargada autoriza cada excepción antes de registrarla.**
Aporta un segundo control inmediato.
Exige suplente o autorización remota disponible.
Sin cobertura, acumula demoras y necesita un procedimiento de continuidad que conserve la entrega.
Puede servir si las excepciones son escasas y siempre hay supervisión.

**Opción rechazada:** aumentar automáticamente 1, vender y aprobar todo al cierre.
Da apariencia de exactitud y permite ocultar errores repetidos.

## Qué cambiaría mi recomendación

Un ensayo sintético debe incluir talla equivocada, encargada ausente, cierre pendiente, reintento y dos cajas.
Observar excepciones frecuentes o identificación poco fiable justificaría reforzar supervisión inmediata.
Medir pocas excepciones correctamente documentadas y resueltas respaldaría A.
No hay evidencia para cuantificar ventas ganadas ni carga real del personal.

Fuentes actuales: `github/docs/DECISIONS.md:56-58,81-125`; `github/docs/synthetic-replacement-20261104/README.md:77-95`; `github/docs/PROJECT-STATUS.md:1-23`.
Límite: lectura documental y análisis hipotético, sin ejecutar aplicación ni cambiar el repositorio.
