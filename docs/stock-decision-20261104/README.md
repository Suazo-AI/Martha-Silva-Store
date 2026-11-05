# Una venta, un inventario confiable y una decisión pendiente

Fecha: 2026-11-04, America/Managua. Equipo de ensayo: SUAZO-PC, datos sintéticos.
Estado posterior D-028: protección de `main` aplicada y verificada, sin merge ni despliegue.
La siguiente decisión propuesta es [cómo levantar el flujo real de Martha, C2](decision-028-next.md).
Actualización: Jason eligió la política para el ensayo sintético en [D-026](../DECISIONS.md#d-026--cajera-registra-la-excepción-encargada-revisa-después).
Jason eligió revisión al cierre con suplente y causas abiertas sin evidencia en [D-027](../DECISIONS.md#d-027--revisión-al-cierre-suplente-y-causas-abiertas).
El análisis siguiente conserva el razonamiento y las alternativas.
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

## Decisión registrada y siguiente decisión

Jason eligió que la cajera registre la excepción y la encargada revise después, para probarlo en SUAZO-PC.
No eligió activar el recorrido en producción ni lo aceptó como implementado.

Elegido en D-027: revisar al cierre de cada jornada simulada y usar suplente si falta la encargada.
Los perfiles del ensayo son ficticios y distintos de la cajera. Los nombres solo ilustran; no son una decisión comercial.
Ejemplo: Beatriz revisa; si falta, Carla toma esa responsabilidad. Si no logra explicar
el origen de un pantalón vendido, registra lo comprobado y conserva la causa abierta, con responsable y próxima revisión definidos.
El cierre observado puede registrarse sin declarar inventario conciliado artificialmente.
La regla ya está elegida. La [siguiente autorización recomendada](decision-027-next.md) es proteger `main`, sin merge ni despliegue.
Jason decide la facultad comercial. El equipo técnico debe resolver cómo implementarla y demostrarla.
No hace falta que Jason elija estructura de base de datos, transacciones o saldos internos.

## Evidencia, límites y siguiente acción

Fuentes vigentes: D-022 a D-027 en `docs/DECISIONS.md`, `docs/PROJECT-STATUS.md`,
modelo histórico de `docs/synthetic-replacement-20261104/README.md` e implementación indicada arriba.
El modelo histórico con autorización previa y +1/−1 no demuestra el nuevo procedimiento.
La entrega estaba decidida, D-026 elige la facultad y D-027 elige momento y cobertura de revisión para el ensayo.
No cierra C1, C2, C9 ni C10 y no modifica Trello ni el ledger.

Lección aplicada: saldo final correcto y revisión firmada no prueban movimientos correctos.
Por eso el ensayo incluye una talla equivocada y una causa desconocida que no deben cerrarse artificialmente.
No se observaron turnos reales ni se conoce todavía quién hará la revisión cotidiana.
Siguiente acción: resolver la protección de integración y obtener los hechos operativos de C2, conservando el alcance de implementación y ensayo pendiente.

### Registro y revisión de D-026

Se actualizaron DECISIONS, PROJECT-STATUS, C1/C10 del ledger y la pregunta de existencias
del cuestionario. Se sustituyó la recomendación vieja de ajuste +1/-1 como procedimiento preferido.
Las imágenes históricas del cuestionario no se regeneraron ni se enviaron a Martha.
Trello: cuatro descripciones con readback exacto; criterio de stock incompleto por cobertura,
momento y mecanismo verificado pendientes. [Recibo saneado](decision-026-receipt.json).

La nueva [crítica](decision-026-critic.md) y el [jurado con respuesta a objeciones](decision-026-jury.md)
coinciden en revisar al cierre con suplente; Jason adoptó esa regla posteriormente en D-027.
Lección aplicada: elegir nombres ficticios no es una decisión comercial; elegir cobertura y momento de revisión sí.

Por solicitud expresa de Jason se agregaron roles permanentes a las instrucciones globales
`C:/Users/Jason/.codex/AGENTS.md` y `C:/Users/Jason/.claude/CLAUDE.md`.
Se armonizó también `C:/Users/Jason/AGENTS.md`, que contenía la confirmación repetida de modelos.
Crítico: `gpt-6.1-sol/high`; jurado: `gpt-6-astra/high`. Solo esos dos roles tienen
selección permanente; el coordinador verifica evidencia y Jason conserva las decisiones.
Se verificó el texto instalado. Esto no acredita recarga en otros chats ni acceso a ambos modelos desde Claude.
Se publican únicamente esta descripción y la evidencia apta del proyecto, no copias de configuración global ni logs privados.

Verificación del registro: definiciones de roles globales coincidentes; JSON del ledger
legible; cuatro readbacks exactos de Trello y criterio de stock todavía incompleto.
`git diff --check` sin errores después de las correcciones documentales.

La suite local `python tests/check.py` terminó con exit 1 en `tests/asset-audit.py`:
`OSError: [WinError 1314] A required privilege is not held by the client` al crear enlaces
simbólicos de fixtures. La etapa informa seis pruebas y tres errores de creación de enlaces.
El build repetible pasó con 1082 rutas y hashes coincidentes antes de ese fallo.
La suite se detuvo; no se atribuyen resultados a sus etapas posteriores.

Bloqueo de verificación local, no defecto demostrado por el cambio documental.
No se cambiaron privilegios ni expectativas, ni se repitió la suite.
Ruta alternativa del coordinador: publicar el cambio autorizado y comprobar la CI Linux
del SHA exacto. Su resultado no elimina el fallo local Windows ni prueba el nuevo flujo de stock.
Los logs completos y las rutas temporales quedan fuera del repositorio público.
Comprobaciones focales separadas: `python tests/test_delivery_status.py`, exit 0,
24/24; `python tools/delivery_status.py --check`, exit 0, 34 items válidos.
No subsanan la suite completa fallida ni prueban implementación del nuevo recorrido.
