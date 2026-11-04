# Una venta, un inventario confiable y una decisión pendiente

Fecha: 2026-11-04, America/Managua. Equipo de ensayo: SUAZO-PC, datos sintéticos.
Estado: explicación y recomendación. Jason todavía no aprueba esta política.
No se modificó ni ejecutó el producto para producir este análisis.

## El negocio que queremos administrar

La meta práctica es vender sin perder el control de prendas, dinero y responsabilidades.
Una pantalla fácil de usar ayuda cuando sus registros permiten responder preguntas concretas:
qué entró, qué salió, qué queda, cuánto se cobró y qué falta investigar.
Tener muchos botones o un saldo que siempre parece correcto no demuestra buena administración.

| Momento | Situación hipotética | Lo que el registro debe explicar |
| --- | --- | --- |
| Comprar | Se piden diez blusas a un proveedor | Cantidad pedida, costo documentado y compromiso de pago |
| Recibir | Llegan ocho de las diez | Ocho recibidas y dos pendientes; no diez disponibles |
| Ubicar | Se llevan tres a otra ubicación | Origen y destino; el traslado no crea prendas |
| Vender | Una factura incluye dos blusas y un pantalón | Cada artículo, talla, cantidad, precio y salida |
| Cobrar | Parte en efectivo y parte por transferencia | Medio e importe; una transferencia declarada no acredita liquidación bancaria |
| Devolver | Regresa una blusa dañada | Venta de origen, devolución y condición; no vuelve automáticamente a disponibilidad |
| Contar | El registro dice cuatro y se observan tres | Diferencia documentada, responsable y revisión; no una corrección silenciosa |
| Reponer | Una talla se vende con frecuencia | Demanda y disponibilidad sustentadas antes de decidir una compra |

Esta tabla describe requisitos de negocio. No afirma que SAVIA implemente todo el recorrido.
Orden recomendado: identidad y movimientos confiables; ventas y cobros trazables;
recepciones, devoluciones y cierre; después usar esos datos para mejorar compras y rentabilidad.
La demanda y la rentabilidad reales aún no se midieron en este análisis.

## Representemos una venta

Todos los nombres, cantidades e importes siguientes son ficticios.

Una clienta trae una blusa azul M de C$350 y un pantalón negro S de C$650.
La factura suma C$1,000 y debe admitir ambas prendas, conforme a D-023.

**Yo, como cajera:** identifico cada prenda y reviso el importe antes de cobrar.
La blusa tiene cinco unidades registradas y cinco contadas al inicio.
Vendo una: quedan cuatro registradas y cuatro físicas. Es el recorrido normal.

El pantalón aparece con cero unidades registradas, pero tengo uno físicamente en mis manos.
Cero significa que el sistema no reconoce una unidad disponible de ese artículo y ubicación.
No demuestra que físicamente no exista, ni que haya robo, ni cuál fue la causa.
Podría ser una recepción omitida, una talla equivocada o un traslado sin registrar.
Son hipótesis que requieren comprobación.

La entrega de una prenda física existente ya está decidida. Falta delimitar las facultades del personal.
Primero confirmo etiqueta, talla y ubicación: un pantalón M no debe venderse como S.
Después necesito registrar la venta y conservar la diferencia, sin fingir una compra ni borrar el problema.

## Mi recomendación, como procedimiento propuesto

1. La cajera confirma artículo, talla, ubicación y cantidad físicamente entregada.
2. Registra la entrega excepcional dentro de la misma venta, con una incidencia obligatoria vinculada.
3. El registro conserva quién actuó, cuándo, qué salió y qué diferencia requiere revisión.
4. La cajera no recibe permiso para cambiar libremente las existencias.
5. La encargada revisa al cierre, o un suplente previamente designado.
6. La encargada corrige el origen solo con evidencia; si falta, conserva la causa abierta y fija la próxima revisión.

Una incidencia es un caso pendiente: «Se entregó este artículo aunque figuraba cero; hay que investigar la diferencia».
Es información operativa que puede consultarse, no un castigo automático a la cajera.
El registro no debe obligarla a adivinar la causa para poder continuar.

Supongamos que la encargada encuentra una recepción omitida y demuestra que contiene ese pantalón.
Registra la recepción sin duplicarla y relaciona la venta con la investigación.
Si no encuentra el origen, puede confirmar que la entrega ocurrió y dejar la causa desconocida.
No inventa proveedor, costo o ganancia para completar la pantalla.

Que al final queden cero prendas físicas y cero registradas no demuestra una historia correcta.
Sumar uno y restarlo produce cero incluso cuando se usó la talla equivocada.
La evidencia debe explicar los movimientos, no solamente el resultado numérico.

## Las alternativas y sus costos

| Política | Qué facilita | Qué exige o arriesga |
| --- | --- | --- |
| Encargada autoriza cada excepción antes de registrarla | Segunda mirada inmediata | Cobertura disponible y suplente; puede generar espera. Debe conservar la entrega ya decidida |
| Cajera registra una excepción delimitada; encargada revisa después | Continuidad en caja y responsabilidades separadas | Revisión real, seguimiento y diferencias visibles hasta resolverlas |
| Cajera modifica existencias libremente | Resolver rápido la pantalla | Puede ocultar errores y pérdidas. Rechazada |

Recomiendo ensayar la segunda. La primera puede ser mejor si siempre hay supervisión
y la identificación de prendas todavía falla. No hay mediciones para prometer ventas adicionales.
La segunda pierde valor si nadie revisa: no elimina trabajo, lo asigna a otra persona.

## Miradas distintas sobre la misma solución

- Clienta: comprar varias prendas sin una investigación larga en caja.
- Cajera: instrucciones claras, pocos pasos y registro que no la obligue a inventar explicaciones.
- Encargada: lista priorizada de diferencias y evidencia para resolverlas.
- Dueña: saber qué datos son confiables, qué dinero está registrado y qué sigue pendiente.
- Equipo técnico: impedir duplicaciones, conservar permisos e historial y demostrar cada comportamiento.

Estas necesidades se complementan. La rapidez no justifica ocultar diferencias;
el control tampoco justifica dejar sin responsable una venta o una revisión.

## Crítico, jurado y verificación del coordinador

El crítico solicitado `gpt-6.1-sol/high` recomienda la excepción delimitada.
Su objeción central es que una firma al cierre no demuestra exactitud.
El jurado solicitado `gpt-6-astra/high` coincide y condiciona la aceptación a una revisión independiente real.
Recibió las objeciones del crítico y dos límites adicionales del coordinador; los aceptó en su refinación.
Sus informes son asesoría, no certificación ni aprobación de Jason.

Lectura directa del coordinador: `backend/src/Martha.Store.Api/Internal/Commerce/InternalStockLedger.cs`
impide descuentos que dejarían `OnHand` negativo. El nuevo recorrido diferido no está implementado.
Una diferencia pendiente de una unidad no significa una prenda física negativa.
Su representación técnica debe diseñarse y probarse sin retirar esa guarda por esta decisión.
Artículo, talla y ubicación identifican un tipo de prenda; no garantizan exclusividad de una unidad entre cajas.

Los informes completos conservan su carácter consultivo y están junto a esta explicación:
[crítico](critic.md) y [jurado, con respuesta al crítico](jury.md).

## Qué debe demostrar el próximo ensayo

| Caso sintético | Resultado exigido para ese caso |
| --- | --- |
| Venta normal de cinco a cuatro | Una venta y una salida, sin incidencia artificial |
| Registro cero y prenda física identificada | Entrega registrada y diferencia vinculada, sin ajuste libre |
| Etiqueta de otra talla | Se detecta y corrige la identificación antes de confirmar la línea |
| Encargada ausente | Suplente o revisión posterior explícita; no se atribuye una aprobación ficticia |
| Causa desconocida al cierre | Cierre observado registrado; causa abierta con responsable y próxima revisión |
| Doble clic o reintento | Una sola venta y una sola salida; recuperar la operación original |
| Dos cajas intentan vender la última unidad | El mecanismo impide dos entregas sobre la misma disponibilidad demostrada |
| Excepciones repetidas | Historial visible y revisión del origen; no borrar ni concluir fraude automáticamente |

Un caso deliberado de causa desconocida puede pasar si el sistema conserva esa incertidumbre correctamente.
No puede pasar como inventario conciliado. Sin responsable de revisión previsto, falla la aceptación operativa del flujo.
Mediríamos tiempo en caja, proporción de excepciones, antigüedad de pendientes y esfuerzo de revisión.
No se ejecutaron estos casos nuevos ni se fijaron metas sin datos.

## La primera decisión

Para el ensayo sintético en SUAZO-PC: cuando la prenda existe, ¿la cajera puede registrar
la excepción y continuar, dejando revisión obligatoria a otra persona, o debe intervenir la encargada en cada caso?

Recomendación: la primera, con las condiciones anteriores. Después corresponde nombrar encargada y suplente.
Jason decide la facultad comercial. El equipo técnico debe resolver cómo implementarla y demostrarla.
No hace falta que Jason elija estructura de base de datos, transacciones o saldos internos.

## Evidencia, límites y siguiente acción

Fuentes vigentes: D-022 a D-025 en `docs/DECISIONS.md`, `docs/PROJECT-STATUS.md`,
modelo histórico de `docs/synthetic-replacement-20261104/README.md` e implementación indicada arriba.
El modelo histórico con autorización previa y +1/−1 no demuestra el nuevo procedimiento.
La entrega está decidida; los permisos continúan pendientes. Este documento aclara la propuesta de D-025.
No cierra C1, C2, C9 ni C10 y no modifica Trello ni el ledger.

Lección aplicada: saldo final correcto y revisión firmada no prueban movimientos correctos.
Por eso el ensayo incluye una talla equivocada y una causa desconocida que no deben cerrarse artificialmente.
No se observaron turnos reales ni se conoce todavía quién hará la revisión cotidiana.
Siguiente acción del coordinador: registrar la respuesta de Jason y preparar el alcance de implementación y ensayo correspondiente.
