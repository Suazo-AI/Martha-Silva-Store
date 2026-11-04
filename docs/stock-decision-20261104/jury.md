# Dictamen: entrega con registro 0

Recomiendo ensayar una excepción limitada para la cajera, con revisión independiente de la encargada. No recomiendo ajustes libres ni activación productiva.

Modo: DISCOVER. Resultado buscado: conservar la venta y una historia verificable del inventario. Cuello de botella: decidir quién puede autorizar, registrar y resolver la diferencia.

Host verificado: SUAZO-PC. Modelo solicitado: `gpt-6-astra/high`. El paquete identifica esa selección; esta sesión no expone una comprobación independiente del backend efectivo.

## Lo confirmado y lo propuesto

D-025 conserva pendiente esta facultad. Entregar la prenda existente ya está decidido. También están decididas la factura multiartículo, la sustitución de SISFAIN y la prueba sintética en SUAZO-PC.

El README anterior modela encargada → ajuste +1 → venta −1. Es una hipótesis didáctica, no una función implementada. La propuesta posterior permite registrar primero la entrega excepcional y revisar después. Son procedimientos diferentes.

PROJECT-STATUS documenta guardas actuales, UI de una línea y pagos `not_processed`. No inspeccioné ni ejecuté código. Ninguna fuente acredita esta nueva excepción funcionando o el ensayo aceptado.

## Cuatro acciones distintas

1. **Registrar la venta:** identificar prendas, cantidades, precio y documento. Un reintento recupera esa operación; no crea otra.
2. **Permitir la excepción:** aplicar el permiso elegido por Jason a una prenda física identificada. No autoriza editar cualquier existencia.
3. **Corregir el origen:** resolver una recepción omitida, talla equivocada u otro hecho demostrado. No inventar compras, costos ni motivos.
4. **Revisar y cerrar la causa:** otra persona comprueba la evidencia y registra su conclusión. Si falta evidencia, la causa permanece abierta.

“Venta autorizada” significa que cumple el permiso comercial. No significa cobro comprobado, documento fiscal válido ni causa resuelta.

## Tres opciones

| Opción | Ventaja | Costo y riesgo | Dictamen |
|---|---|---|---|
| Encargada autoriza cada caso | Segunda mirada inmediata | Interrumpe caja; sin suplente puede contradecir la entrega ya decidida | Viable si siempre hay respuesta y respaldo operativo |
| Cajera registra excepción limitada; encargada revisa | Conserva la entrega con responsabilidad identificada | Acumula trabajo y riesgo hasta la revisión | Recomendada para ensayo, condicionada a revisión real |
| Cajera cambia inventario libremente | Resuelve rápido la pantalla | Permite esconder errores, duplicaciones o pérdidas | Rechazada |

La segunda opción separa la rapidez necesaria en caja de la investigación que puede esperar. No elimina trabajo: lo asigna a la encargada.

## Casos hipotéticos

| Situación | Acción y evidencia esperada |
|---|---|
| Registro 5, físico 5, venta 1 | Venta normal: registro 4 y físico 4. Ninguna excepción. |
| Registro 0, físico 1, venta 1 | Confirmar artículo, talla y ubicación. Registrar una entrega y una incidencia vinculadas. Mantener visible la diferencia hasta resolverla. |
| Talla o ubicación equivocadas | Identificar la prenda correcta antes de registrarla. No aumentar otra talla ni inventar un traslado para aprobar la pantalla. |
| Encargada ausente | La excepción limitada usa autorización previa de Jason; no exige una llamada por caso. Asignar revisión al regreso o a un suplente nombrado. Sin responsable disponible, el diseño queda incompleto. |
| Causa sin resolver al cierre | Registrar dinero y conteo observados; dejar conciliación pendiente con responsable y próxima revisión. No marcar inventario conciliado ni borrar la diferencia. |
| Excepciones repetidas | Conservar todos los casos y alertar a la encargada. Revisar recepción, identificación y permisos. La repetición puede exigir supervisión presencial; no demuestra fraude. |
| Doble clic, recarga o segunda caja | Una operación produce una entrega y una incidencia. La misma unidad identificada no puede quedar disponible simultáneamente. El ensayo debe intentar duplicarla. |

La opción de autorización por caso añade espera en todos los casos excepcionales. El ajuste libre permite “cuadrarlos” sin demostrar qué pasó.

## Ejemplo de C$350

**Cajera:** “Tengo esta blusa, talla M, en esta ubicación. El registro dice 0”. Confirma identidad, cantidad 1 y precio C$350. Registra la excepción dentro de la misma venta, aunque contenga otras prendas. No modifica existencias libremente.

**Sistema propuesto:** vincula venta, salida e incidencia con actor y hora. Muestra, por ejemplo, registro 0, salida pendiente de conciliar 1 y diferencia −1. Nunca presenta 0 como saldo confiable. Esto no permite prometer otra unidad.

**Encargada:** revisa movimiento e identidad. Si demuestra una recepción omitida, corrige ese origen sin duplicarlo. Si solo comprueba que se entregó una prenda, valida la entrega y conserva la causa pendiente.

Cierre físico 0 y registro 0 no prueban que un ajuste anterior +1 fuera correcto. Una corrección y una venta pueden cancelarse numéricamente aunque correspondan a tallas equivocadas.

## Qué hacer ahora y qué puede esperar

Ahora: elegir el permiso; definir responsable y suplente; exigir identidad, evidencia física contemporánea y enlace único. La causa puede investigarse después. El registro de la entrega no puede esperar ni desaparecer.

Luego: ensayar todos los casos con datos ficticios y restaurar el estado inicial, conservando evidencia. El coordinador SUAZO-PC dicta aceptación por flujo. C2/C9 y el alcance de ejecución siguen pendientes; este dictamen no los habilita.

Medir, sin inventar metas: proporción de ventas excepcionales, antigüedad de casos abiertos y esfuerzo en caja. Registrar también trabajo de revisión. Hoy no hay mediciones.

Cambiaría mi recomendación si la revisión nunca ocurre, faltan identidades confiables o las excepciones son habituales. Probaría supervisión por caso con suplente y resolvería el origen antes de ampliar permisos.

Lección: saldo final correcto no demuestra historia correcta. El ensayo debe incluir una talla equivocada que termine en cero para comprobar que la revisión la detecta.

**Pregunta para Jason:** ¿Querés que la cajera pueda registrar y entregar una prenda física cuando el sistema dice 0, dejando una incidencia obligatoria para que otra persona la revise, sin poder ajustar libremente el inventario?

## Fuentes y límites

Lectura local: `docs/DECISIONS.md:60-125`, `docs/PROJECT-STATUS.md:1-55`, `docs/synthetic-replacement-20261104/README.md:77-95`. Rige el playbook canónico y OUTPUT.md.

Análisis de casos, no prueba funcional ni certificación. No hubo cambios de producto, SQL, Docker, red ni datos reales. Decisión pendiente de Jason.

## Refinación tras el crítico — propuesta, no aprobación

Acepto ambas objeciones. Una firma acredita revisión, no exactitud. El par +1/−1 tampoco demuestra el origen de la prenda. La encargada puede confirmar la entrega y dejar la causa desconocida abierta. Corregir inventario requiere evidencia adicional del hecho que se corrige.

SKU, talla y ubicación identifican un tipo de prenda, no una unidad única. La protección entre cajas mencionada arriba es un requisito por demostrar. No afirmo que esa identificación impida dos entregas de la misma unidad.

El coordinador verificó que `InternalStockLedger.cs` prohíbe `OnHand` negativo. El flujo diferido no está implementado. El ejemplo de diferencia −1 describe una discrepancia visible; no instruye a guardar existencias negativas ni a retirar esa guarda. Representarla sin perder información requiere diseño y pruebas posteriores.

La decisión comercial puede preguntarse así: **¿Autorizás que la cajera registre la entrega excepcional, sin ajustar libremente existencias, y que otra persona revise el caso después?** Jason decide facultades; no necesita elegir cómo almacenar la incidencia.

Para el ensayo propongo revisar al cierre. Si falta la encargada, revisa un suplente previamente designado. Sin suplente o evidencia suficiente, se registra el cierre observado con incidencia pendiente, responsable y próxima revisión explícitos. No se declara inventario conciliado ni se inventa una corrección.

Un caso deliberado de causa desconocida pasa si conserva la incertidumbre. La ausencia no prevista de cualquier responsable bloquea la aceptación operativa del flujo; no justifica borrar la venta ni forzar saldo cero.
