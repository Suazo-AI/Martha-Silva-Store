# D-028 aplicada; siguiente decisión propuesta: conocer la operación real

Fecha local: 2026-11-04, America/Managua. Host SUAZO-PC.

**Actualización D-029:** Jason eligió la reconstrucción guiada con datos ficticios.
[Guion operativo preparado](../sprint-20261104/GUION-RECONSTRUCCION-MARTHA.md).
La elección siguiente queda como historia; ya no es una decisión pendiente.
La conversación todavía no fue coordinada ni realizada.

## Qué quedó resuelto

La protección aprobada de `main` está instalada. Siete checks requeridos y cada campo
contrastados con el payload. [Recibo exacto](decision-028-main-protection-receipt.json).
No se fusionaron cambios ni se desplegó. C1 continúa abierta por variables efectivas
y mecanismo de stock pendiente. La configuración no demuestra cobertura total ni rechazo adversarial.

## La siguiente decisión y por qué importa

C2 necesita conocer cómo trabaja Martha hoy. Investigar SISFAIN no demuestra qué módulos,
cobros, documentos, devoluciones o equipos usa su tienda. Antes de copiar pantallas o
construir más, necesitamos seguir una operación suya de principio a fin.

La decisión propuesta es **cómo obtener ese conocimiento**. No vuelve a preguntar
si debe existir venta multiartículo: ya es requisito obligatorio.

| Opción | Qué obtenemos | Límite |
| --- | --- | --- |
| Cuestionario escrito solamente | Respuestas fáciles de enviar y revisar a su ritmo | Puede omitir pasos que Martha considera obvios o palabras que entendemos diferente |
| Reconstrucción guiada de unos 20–30 minutos, más cuestionario para huecos | Seguimos una venta y comprobamos qué significa cada paso | Requiere disponibilidad; una venta no cubre todo el negocio |

Recomendación: la reconstrucción guiada. Martha conoce la operación; nosotros conducimos
las preguntas y traducimos respuestas a requisitos y pruebas. No necesita dominar software.
La sesión es propuesta: no coordinada, enviada ni realizada. No autoriza entrar en SISFAIN,
registrar ventas reales, emitir comprobantes reales ni grabar información de clientes.

## Ejemplo de cómo la conduciría

Importes y prendas inventados: blusa C$350 + pantalón C$650 = C$1,000.

**Yo:** «Martha, imaginemos que soy una clienta con estas dos prendas. Contame qué hacés
desde que llego a caja hasta que cierres la jornada. Usemos nombres y números inventados».

1. **Identificar:** «¿Cómo distinguís talla, color y código? ¿De dónde sale el precio?»
2. **Facturar:** «Mostrame o describime cómo quedan ambas prendas en la misma factura».
3. **Cobrar:** «Usemos un medio de pago que realmente aceptás. ¿Cómo sabés que quedó pagado?»
4. **Documentar:** «¿Qué comprobante recibe la clienta y qué registro conservás vos?»
5. **Inventario:** «¿Cuándo baja cada prenda y quién revisa una diferencia?»
6. **Cerrar:** «Al terminar el día, ¿con qué comparás ventas, cobros y dinero recibido?»

Si menciona efectivo C$600 y transferencia C$400, seguimos ese caso. Esa combinación
es hipotética hasta que Martha confirme que la usa. No suponemos pagos mixtos, crédito,
documentos fiscales o liquidación bancaria a partir del ejemplo.

Si no se puede mostrar un entorno de prueba seguro, reconstruimos verbalmente y con
ejemplos inventados. Marcamos el relato como declarado, no como comportamiento observado.
No manipulamos su operación real para conseguir una demostración.

## Resultado útil y criterio de cierre

Prepararemos una tabla por paso: práctica actual, requisito, evidencia, comportamiento
del producto verificado y brecha. Cada dato se marca observado, declarado o pendiente.
El dinero registrado se distingue del dinero efectivamente recibido/conciliado.
Lo desconocido conserva dueño y próxima acción. No inventamos respuestas para completar la tabla.

Esta sesión produce un primer flujo; no cierra todo C2 ni acredita sustitución de SISFAIN.
Versión/módulos, fiscalidad, exportación, crédito, devoluciones y equipo quedan explícitos
si no aparecen. SUAZO-PC mantiene aceptación del ensayo; Martha confirma su práctica.

Pregunta única: **¿Elegimos esta reconstrucción guiada con Martha como siguiente paso de C2?**

## Revisión y límites de este avance

Se reutilizó el análisis D-027 y se pidió revisión acotada nueva al crítico
`gpt-6.1-sol/high` y al jurado `gpt-6-astra/high`. El coordinador verifica la evidencia;
ningún informe sustituye la elección de Jason ni demuestra paridad del producto.
[Crítico](decision-028-critic.md) y [jurado](decision-028-jury.md).

Verificación del coordinador: acepta las objeciones sobre variables, rechazo no probado
y alcance incompleto de C2. Corrigió el estado vigente que pedía autorización antigua.
El jurado señaló un campo omitido en el recibo: `require_code_owner_reviews=false`.
Se consultó otra vez por CLI y se añadió el valor comprobado; no se cambió la configuración.
El GET del conector devolvió HTTP 403 `Resource not accessible by integration`;
el mismo GET por CLI instalado funcionó. Se conservan los permisos del conector.
La falla era de acceso del conector, no evidencia de protección ausente. Bloqueo resuelto
por la ruta CLI ya autorizada, con lectura satisfactoria y sin cambios de permisos.

Trello: cuatro descripciones y criterio de protección leídos de vuelta exactamente.
Stock y variables permanecen incompletos. [Recibo](decision-028-trello-receipt.json).
El historial privado y credenciales se excluyen de la publicación.

Lección aplicada: activar una regla resuelve su configuración, no todas las causas de
un merge inseguro. Cerrar únicamente el criterio que tiene evidencia nueva.

Verificación documental: `python tools/delivery_status.py --check`, exit 0, 34 items
válidos; `git diff --check`, exit 0. No hay cambios de código ni pruebas nuevas.
No se repite la suite Windows que falló por WinError 1314 en D-026; ese límite
histórico permanece documentado. El nuevo flujo de stock sigue sin prueba funcional.
