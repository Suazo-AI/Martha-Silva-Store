# Investigación de métricas de personal de SAVIA

## Resumen

Fecha de consulta de todas las fuentes: **2026-11-14**.
Modo: DISCOVER; revisión estática y fuentes públicas; sin SQL ejecutado, datos de clientes, APIs pagadas, commits ni publicación.
Candidato leído: `44fe3074eb9d1f196b51310f55826c3a028ba571`, rama `t3/research-seller-metrics`, host SUAZO-PC.
Autor: Codex, proveedor OpenAI/Codex, modelo `gpt-6.1-sol`, razonamiento solicitado y efectivo `high` según el contexto del harness.
Revisor y aceptación independiente: orquestador principal Claude, pendientes.

**INFERENCE:** SAVIA debe empezar por ventas y devoluciones por vendedora × categoría × sucursal, antes de añadir una puntuación única de desempeño.
**OBSERVED:** Selfridges y Sephora publican KPIs de cesta; Harrods exige ventas por hora; Neiman Marcus y Louis Vuitton publican responsabilidades de desarrollo de clientes.[S02][S03][S04][S09][S10]
**OBSERVED:** El reporte actual de SAVIA muestra indicadores por vendedora, pero su consulta no agrupa por categoría.[L01][L02]
**OBSERVED:** `netSalesMinor` suma precio por cantidad menos descuento y mantiene las devoluciones en otro campo; no representa ventas después de devoluciones.[L02]
**INFERENCE:** La decisión de personal debe combinar resultado, oportunidades atendidas, tiempo y calidad de venta; vender más dinero por sí solo no identifica mejor atención.
**INFERENCE:** Las metas de empresas internacionales sirven como ejemplos de diseño, sin transferir sus números a Nicaragua.

### Cómo leer la evidencia

**OBSERVED** significa texto, esquema o cálculo directamente visible en una fuente; no significa implementación operativa comprobada.
**CLAIM** significa resultado, beneficio o explicación declarada por la empresa o los autores, sin validación independiente en esta investigación.
**INFERENCE** significa interpretación, riesgo hipotético, fórmula propuesta o recomendación del investigador.
Los enlaces S identifican fuentes públicas; los enlaces L identifican código leído localmente y su URL GitHub fijada al SHA del candidato.
Las URLs privadas del repositorio son referencias de trazabilidad; no se comprobó acceso anónimo ni se enviaron sus bytes a proveedores de investigación.
La fecha de consulta no equivale a la fecha de publicación ni demuestra que una vacante siga abierta.
El encargo describe tres sucursales, operación cloud, pocas vendedoras y ausencia de contador de visitas; son supuestos de adaptación, no hechos operativos auditados.

## Qué miden las tiendas líderes

### Nordstrom

**OBSERVED:** Una vacante oficial pide metas personales, cartera de clientes, seguimiento y colaboración; también publica comisiones que varían por mercancía.[S01]
**OBSERVED:** Esa vacante describe seguimiento posterior a la compra y herramientas de relación con clientes, pero no publica una fórmula de repetición ni metas por categoría.[S01]
**OBSERVED:** Una resolución judicial de 2013 describe compensación ligada a comisiones por hora de venta y disputas sobre qué tareas cuentan como tiempo de venta.[S18]
**INFERENCE:** Ese documento histórico no prueba las reglas laborales o salariales actuales de Nordstrom y no debe copiarse como política local.
**INFERENCE:** SAVIA puede aprovechar la separación entre producción individual y relación futura, registrando también tareas necesarias que no producen tickets inmediatos.

### Neiman Marcus

**OBSERVED:** La descripción oficial de Client Relationship Lead enumera frecuencia de visitas, migración entre niveles de gasto y engagement para clientes nuevos y existentes.[S04]
**OBSERVED:** La misma descripción menciona Connect como herramienta para profundizar relaciones y estrategias de retención y crecimiento de clientes de alto valor.[S04]
**INFERENCE:** Contar mensajes enviados sería una medida de actividad; el resultado útil es cuántas clientas vuelven y compran, evitando atribuir causalidad automática al mensaje.

### Selfridges

**OBSERVED:** Su vacante de Sales Manager enumera ventas contra año anterior y plan, beneficio, margen, NPS, captura de datos, UPT, ATV y SPH.[S02]
**OBSERVED:** También enumera absentismo, rotación de personal y nómina frente a ventas; la página indica que el plazo de solicitud terminó.[S02]
**INFERENCE:** Esta evidencia corresponde a responsabilidades gerenciales; no prueba que cada indicador determine la comisión de cada dependienta.
**INFERENCE:** Para SAVIA, ATV significa importe por ticket y UPT unidades por ticket, definidos con la misma base temporal y monetaria.

### Harrods

**OBSERVED:** La vacante oficial Sales Associate - Harrods Shop exige estándares mínimos de ventas por hora y metas individuales.[S03]
**OBSERVED:** Pide ofrecer productos relacionados, construir relaciones que generen repetición y compartir tareas de apoyo; la vacante está expirada.[S03]
**INFERENCE:** La venta complementaria debe medirse aparte de UPT, porque dos vestidos no equivalen a vestido más accesorio.

### NET-A-PORTER / contexto YNAP

**OBSERVED:** La vacante oficial de Personal Shopper pide objetivos anuales, perfiles según patrones de compra, priorización de cartera, citas y aumento del gasto individual y fidelidad.[S05]
**OBSERVED:** La página consultada identifica NET-A-PORTER como parte de LuxExperience; por eso no se atribuye esta evidencia actual a una estructura corporativa YNAP histórica.[S05]
**INFERENCE:** La lección para gala y novias es registrar oportunidades y citas, además del ticket final, sin asumir que una cartera de lujo digital equivale al tráfico de una tienda pequeña.

### Inditex / Zara

**OBSERVED, evidencia parcial:** El extracto indexado del informe oficial 2024, página 249, describe comisión mensual de tienda y parámetros objetivos vinculados a resultados.[S06]
**CLAIM:** Inditex presenta esa comisión como reconocimiento de ventas, feedback de producto y coordinación de tienda, y explica que busca evitar discriminación discrecional.[S06]
**INFERENCE:** Esto apoya estudiar cooperación y resultados de tienda, pero el extracto no establece el reparto exacto entre personas, categorías o marcas.
**INFERENCE:** No se debe afirmar que Zara usa una determinada fórmula individual o una comisión idéntica en todos los países.

### Fast Retailing / UNIQLO

**CLAIM:** La presentación del COO de UNIQLO del 10 de abril de 2025 informa un aumento aproximado de 30% de ventas por empleado en FY2025 frente a FY2022.[S07]
**CLAIM:** La misma presentación informa satisfacción de al menos 4,0 sobre 5 en casi todas las tiendas y vincula la gestión a información por tienda y SKU.[S07]
**OBSERVED:** Su página de satisfacción explica que las encuestas cubren comunicación del personal, conducta y rapidez en caja.[S08]
**INFERENCE:** Ventas por empleado no es ventas por hora y no debe utilizarse como sustituto cuando cambian jornadas o tareas.

### Mango

**OBSERVED, evidencia parcial:** El extracto indexado de la vacante oficial Multifunctional Sales Assistant exige conocer y mejorar indicadores de venta y usar herramientas omnicanal.[S11]
**INFERENCE:** La fuente recuperada no identifica ATV, UPT, conversión ni una fórmula concreta; atribuir esos KPIs específicos a Mango excedería esta evidencia.
**INFERENCE:** El caso aporta orientación comercial, pero tiene menos detalle verificable que Selfridges o Sephora.

### LVMH: Sephora y Louis Vuitton

**OBSERVED:** La vacante oficial de Sephora en Göteborg enumera conversión, artículos por cesta, cesta media, satisfacción y número de servicios.[S09]
**INFERENCE:** Esa lista identifica indicadores del rol, sin establecer en la página el denominador exacto de conversión o su peso en remuneración.
**OBSERVED:** La vacante oficial Regional CRM Manager Middle East de Louis Vuitton exige seguir conversión, retención e impacto del clienteling.[S10]
**OBSERVED:** LVMH distingue responsables de un universo o categoría y asesores que venden una categoría o todo el surtido.[S12]
**OBSERVED, evidencia parcial:** El extracto indexado de Merchandising Manager de Louis Vuitton pide analizar ventas semanales, sell-through y stock, además de formación por categoría.[S13]
**INFERENCE:** Esto respalda analizar producto y personal conjuntamente, pero no demuestra que todas estas marcas usen una matriz individual por categoría ni que paguen comisiones según ella.

### Pronovias, Kleinfeld y David's Bridal

**OBSERVED:** Pronovias pide cumplir objetivos de ventas y eficiencia, preparar citas y desarrollar cartera; su vacante no publica cifras objetivo.[S14]
**OBSERVED:** Su informe de sostenibilidad 2023 describe consultas de satisfacción después de la primera prueba de novia/cóctel y la segunda prueba de novia.[S15]
**OBSERVED:** Kleinfeld pide metas de conversión, citas puntuales y seguimiento, además de vender vestido, tocado y accesorios como conjunto.[S16]
**OBSERVED:** La vacante oficial de David's Bridal pide productividad por hora y una conversión de plataforma de al menos 65%.[S17]
**OBSERVED:** También publica metas de complementos: tocado 75%, prendas de base 10% y zapatos 20%, y una meta de conversión a citas de arreglos de 80% de novias que compraron.[S17]
**INFERENCE:** Son metas de esa descripción de puesto, no resultados logrados ni benchmarks universales.
**INFERENCE:** La página no define con suficiente detalle «platform conversion» ni todos los denominadores de complementos; SAVIA debe definir los propios antes de comparar.
**INFERENCE:** Para novias conviene separar primera consulta, seguimiento, prueba y entrega; una prueba posterior no debe inflar el denominador de oportunidades de venta nuevas.

### Qué está documentado y qué sigue desconocido

**OBSERVED:** Las fuentes anteriores documentan cesta, productividad, conversión, clientes, citas y responsabilidades por categoría.[S02][S03][S04][S09][S12][S16][S17]
**INFERENCE:** La matriz vendedora × categoría es una recomendación propia para SAVIA; no se presenta como tablero interno recuperado de las marcas.
**INFERENCE:** No hay evidencia suficiente aquí para asignar una fórmula uniforme de devoluciones por vendedora o reparto de comisión compartida a las marcas investigadas.
**INFERENCE:** Tampoco se dispone de sus diccionarios internos completos, umbrales por país ni ajustes por tráfico y disponibilidad.

## Crítica de SAVIA hoy

### Base útil, con una diferencia entre nombre y cálculo

**OBSERVED:** `savia/web/screens/report.mjs:226-244`, función `teamContent`, muestra vendido, prendas, tickets, ticket promedio, prendas por ticket, devoluciones %, descuentos y comisión.[L01]
**OBSERVED:** `savia/db/migrations/V027__usd_cash.sql:1103-1134` define `sales.usp_KpiTeam` con agregación por vendedora y sucursal, período día/semana/mes/año y fecha local desplazada seis horas.[L02]
**OBSERVED:** En `V027__usd_cash.sql:1124-1126`, vendido = suma de `UnitPriceMinor * Quantity - DiscountMinor`; unidades y tickets provienen de las ventas del período.[L02]
**OBSERVED:** En `V027__usd_cash.sql:1120-1132`, las devoluciones aprobadas se agrupan por fecha de devolución y se atribuyen a `SaleLines.SellerId` original.[L02]
**INFERENCE:** Llamar a ese campo «ventas netas» sin aclarar «después de descuentos, antes de devoluciones» puede inducir decisiones incorrectas.
**INFERENCE:** La tasa actual compara devoluciones ocurridas ahora con ventas ocurridas ahora, aunque procedan de ventas antiguas; sirve como flujo, no como calidad de una cohorte de ventas.
**OBSERVED:** Cuando las ventas del período son cero o negativas, la consulta devuelve cero para `returnsBps`, aunque existan devoluciones.[L02]
**INFERENCE:** La presentación debería indicar «sin base de ventas» y mostrar el importe devuelto; cero por construcción no demuestra ausencia de problemas.
**OBSERVED:** `COUNT(DISTINCT l.SaleId)` cuenta cada ticket donde participa esa vendedora; no cuenta solamente tickets exclusivos.[L02]
**INFERENCE:** Si dos vendedoras participan en un ticket, sumar sus tickets duplica ese ticket en el total del equipo; ATV individual representa importe atribuido por ticket participado.

### La categoría existe, pero no está cerrada la historia

**OBSERVED:** `savia/db/migrations/V001__baseline.sql:321-334` permite `catalog.Products.CategoryId` nulo y lo vincula a `catalog.Categories`.[L03]
**OBSERVED:** `V001__baseline.sql:341-348` vincula cada `Item` a `ProductId`, y `V001__baseline.sql:807-831` vincula cada línea de venta a `ItemId`.[L03]
**INFERENCE:** Es posible diseñar el recorrido línea → item → producto → categoría sin inventar una categoría por recibo.
**OBSERVED:** `V027__usd_cash.sql:1117-1134` no recorre esas tablas ni genera grupos de categoría.[L02]
**OBSERVED:** La inserción vigente en `V028__usd_change.sql:191-198` conserva SKU, nombre, costo, vendedora y comisión, pero no una categoría de venta congelada.[L05]
**INFERENCE:** Un informe que use solamente la categoría actual puede reescribir el pasado al reclasificar un producto.
**INFERENCE:** Primero debe distinguirse «clasificación actual» de «clasificación al vender» y mantener un grupo visible «Sin clasificar».
**INFERENCE:** No se comprobó cuántos productos reales carecen de categoría; leer que el campo acepta NULL no acredita su calidad operativa.

### Comisiones: buena trazabilidad inicial, sin remuneración por categoría

**OBSERVED:** `savia/db/migrations/V018__seller_commissions.sql:1-5` agrega vendedora y snapshots de tasa y comisión por línea; la tasa predeterminada es 300 puntos básicos, equivalente a 3%.[L04]
**OBSERVED:** `V018__seller_commissions.sql:7-28` restringe el cambio de tasa a la dueña y registra actor, razón, tasa anterior y nueva.[L04]
**OBSERVED:** `V018__seller_commissions.sql:87-100` valida atribución por línea cuando se entrega `SellersJson`; `SellerId` admite NULL y existe un recorrido sin ese JSON.[L04]
**OBSERVED:** La inserción actual conserva una tasa por vendedora y aplica redondeo hacia abajo a la comisión monetaria de cada línea después del descuento.[L05]
**OBSERVED:** `V018__seller_commissions.sql:54-67` y `V027__usd_cash.sql:1122-1132` restan reversos de comisión calculados proporcionalmente con cantidades devueltas acumuladas.[L04][L02]
**INFERENCE:** Un retorno posterior puede producir comisión pagadera negativa en el período; «pagadera» calculada no prueba pago de nómina ni acuerdo laboral.
**INFERENCE:** Conservar tasa y comisión históricas evita recalcular una venta antigua con la tasa nueva.
**INFERENCE:** El campo único por línea no reparte crédito entre dos personas que atendieron juntas esa misma prenda.
**INFERENCE:** Añadir visibilidad por categoría debe preceder cualquier cambio de tasa por categoría; medir mezcla y modificar incentivos son decisiones diferentes.

### Horas, clientas, margen y caja

**OBSERVED:** El reporte gerencial muestra cierres, diferencias C$/US$ y aprobaciones, en `report.mjs:246-259`; el SQL atribuye cierres a `ClosedBy`.[L01][L02]
**INFERENCE:** Eso aporta control de caja, pero cerrar una caja no equivale a supervisar bien ventas, disponibilidad o atención.
**OBSERVED:** `V001__baseline.sql:774-799` admite `Sales.CustomerId` nulo, y `V001__baseline.sql:807-833` conserva costo por línea.[L03]
**INFERENCE:** Recompra y margen son ampliaciones posibles, condicionadas a identidad y costo completos; no están demostradas como indicadores del equipo actual.
**OBSERVED:** La consulta `usp_KpiTeam` no usa horas trabajadas, visitas, citas ni contactos comerciales.[L02]
**INFERENCE:** La búsqueda estática de migraciones no identificó registros específicos de asistencia, footfall o citas; esto no descarta sistemas externos no inspeccionados.
**OBSERVED:** El reporte declara moneda NIO y separa diferencia de caja USD; V028 conserva datos de tipo de cambio y efectivo extranjero en su recorrido de cobro.[L02][L05]
**INFERENCE:** Las ventas deben contarse una vez por línea en moneda base; efectivo, tarjeta y USD son medios de cobro, no ventas adicionales.
**INFERENCE:** Antes de generalizar el reporte, hay que probar la base monetaria de cada venta; una etiqueta NIO no demuestra que todo dato histórico sea NIO.

## Conclusión y métricas recomendadas

Toda fórmula y prioridad de esta sección es **INFERENCE / propuesta**, no un benchmark atribuido a las tiendas.
«Lo tiene hoy» significa soporte estático encontrado, no datos completos ni runtime aceptado.[L01][L02][L03][L04][L05]
Las fórmulas monetarias propuestas usan NIO, después de descuentos y sin impuestos, con devoluciones normalizadas a la misma base.
No se debe restar automáticamente `CreditMinor` de una base sin impuestos hasta comprobar qué componentes incluye.
Si el denominador falta o es cero, mostrar «sin base», junto al numerador y el tamaño de muestra.

| Prioridad | Métrica | Fórmula propuesta | Dato que necesita | ¿SAVIA lo tiene hoy? | Por qué |
|---|---|---|---|---|---|
| 1 | Ventas y unidades por vendedora × categoría | Venta después de descuento − devolución atribuida; unidades vendidas − unidades devueltas, por categoría/sucursal/período | Línea, vendedora, categoría al vender, devolución original, base fiscal/monetaria | Parcial: atribución y devoluciones sí; categoría opcional y sin snapshot ni desglose de equipo [L02][L03][L05] | Permite distinguir novias, fiesta/gala y casual sin confundir precio con cantidad |
| 2 | Calidad de atribución y clasificación | Importe de líneas sin vendedora / importe vendido; importe sin categoría / importe vendido; mostrar también cantidades | Identidad por línea y clasificación histórica | Parcial: SellerId y CategoryId admiten NULL [L03][L04] | Evita premiar un ranking con huecos invisibles |
| 3 | Devoluciones por cohorte de venta, vendedora y categoría | Importe devuelto de ventas originadas en la cohorte / importe de esas ventas; separar flujo de devoluciones del período | Venta original, línea, fecha, motivo y ventana de observación acordada | Parcial: vínculo y fechas sí; consulta actual usa flujo temporal, no cohorte [L02][L03] | Compara calidad de ventas con la misma madurez y permite investigar motivos |
| 4 | ATV y UPT por categoría | Venta atribuida antes de devoluciones / tickets participados; unidades vendidas / tickets participados | Tickets distintos, líneas, vendedora y categoría | Agregado sí; categoría no [L01][L02] | Explica tamaño de cesta sin mezclar vestido de novia con casual |
| 5 | Venta y margen por hora | Venta neta / horas efectivas de atención; acompañar con venta neta / horas pagadas; margen / horas como complemento | Horas registradas por tarea/sucursal, costos y devoluciones | No en equipo; costo por línea disponible [L02][L03] | Compara jornadas y expone carga de apoyo sin borrar trabajo necesario |
| 6 | Tasa de complementos por categoría principal | Tickets con vestido elegible y complemento retenido / tickets con vestido elegible; mostrar tasa al vender y tras devoluciones | Categoría principal, tipo de complemento, ticket y regla de crédito entre vendedoras | Parcial: líneas y ticket sí; taxonomía y atribución compartida pendientes [L02][L03][L05] | Distingue venta de conjunto de vender varias prendas principales |
| 7 | Conversión de consultas y citas de novia/gala | Oportunidades únicas atendidas que compran dentro de ventana acordada / oportunidades únicas atendidas; asistencia = citas atendidas / citas programadas | Oportunidad, agenda, asistencia, responsable, venta vinculada y ventana | No en consulta actual [L02] | Permite coaching sin depender de contador de puerta |
| 8 | Mezcla por categoría y contribución al margen | Venta neta de categoría / venta neta total de la vendedora; margen monetario = ingreso neto − costo neto asociado | Categoría histórica, costos vendidos y reversos, moneda consistente | Parcial: costos y líneas sí; categoría congelada y desglose no [L02][L03][L05] | Muestra especialización y dependencia de rebajas sin imponer mezcla uniforme |
| 9 | Sell-through de categoría por sucursal | Unidades vendidas netas / unidades disponibles para vender en período; definir disponibles como inicio + entradas vendibles + transferencias recibidas − transferencias salientes | Stock inicial, movimientos, daños, ventas y retornos vendibles | No en equipo; requiere reconciliar inventario en otro alcance [L02] | Diagnostica surtido y reposición; responsabilidad de gerencia, no nota individual |
| 10 | Recompra y seguimiento útil | Clientas de una cohorte que recompran dentro de ventana / clientas identificadas de esa cohorte; compras posteriores a contacto / clientas contactadas elegibles | CustomerId estable, consentimiento, contactos, atribución y ventas entre sucursales | Parcial: CustomerId opcional; contactos y cohortes no aparecen en equipo [L02][L03] | Mide continuidad; publicar cobertura de identificación para no falsear fidelidad |
| 11 | Conversión de tienda | Oportunidades de compra que compran / oportunidades de compra que entran; separar acompañantes, retiros y pruebas | Conteo manual consistente o contador validado y tickets deduplicados | No en equipo [L02] | Sirve a dotación y horarios; no atribuir a cada vendedora tráfico que nunca atendió |
| 12 | Cumplimiento de meta del equipo y costo de comisión | Venta neta de sucursal / meta acordada; comisión devengada neta / venta neta con base comparable | Meta versionada, comisión original y reversada, base de ventas positiva | Comisión parcial sí; meta no en consulta [L02][L04] | Permite evaluar un piloto de incentivo colectivo sin ocultar costos ni devoluciones |

### Contrato de categoría por artículo

**INFERENCE:** Usar una categoría primaria excluyente por producto: «Fiesta/gala», «Novia», «Casual», «Accesorios» y «Sin clasificar».
**INFERENCE:** Martha debe validar ese catálogo contra su mercancía; son categorías propuestas, no inventario comercial confirmado.
**INFERENCE:** Conservar SKU/item, categoría primaria y versión/nombre de categoría al vender, además de la vendedora original.
**INFERENCE:** Una devolución hereda categoría y atribución de la línea original, aunque cambien después catálogo o personal.
**INFERENCE:** Talla, color y ocasión secundaria deben ser dimensiones separadas; no sumar etiquetas secundarias como categorías primarias.
**INFERENCE:** Un ticket mixto contribuye importes y unidades a varias categorías, pero el total de tickets de tienda se deduplica.
**INFERENCE:** Cuando una vendedora vende el vestido y otra el accesorio, conservar ambas contribuciones y mostrar attach de ticket como resultado conjunto.
**INFERENCE:** No duplicar el valor completo de la misma prenda para ambas vendedoras; cualquier reparto futuro debe sumar exactamente el crédito original.
**INFERENCE:** Presentar matriz con filas de vendedora y columnas de categoría, filtros por sucursal/período y detalle de líneas verificable por gerencia.
**INFERENCE:** No inventar una vendedora para ventas cloud sin asesoría atribuida; usar «canal digital / sin atribución personal».

### Secuencia pequeña y comprobable

**INFERENCE:** Primera etapa: acordar nombres y bases de cálculo, completar clasificación, y presentar prioridades 1–4 con «Sin clasificar» visible.
**INFERENCE:** Segunda etapa: registrar horas de atención y oportunidades de novia/gala con una planilla o agenda sencilla, sin comprar sensores.
**INFERENCE:** Tercera etapa: probar complementos, margen, disponibilidad y recompra cuando su captura resulte consistente.
**INFERENCE:** Revisar por sucursal y categoría antes de comparar personas entre tiendas o canales diferentes.
**INFERENCE:** Usar muestras y tendencias para coaching; no tomar decisiones de comisión o despido con una tasa aislada o un ranking diario.
**INFERENCE:** Congelar las reglas de incentivo durante un piloto acordado y evaluar ventas retenidas, margen, costo de comisión y reclamaciones.
**INFERENCE:** El primer cambio útil es la matriz por categoría con trazabilidad de devoluciones, sin cambiar todavía cuánto gana cada vendedora.

## Riesgos

**INFERENCE — dirigir la venta hacia la métrica:** Premiar solo dinero o una categoría puede desviar recomendaciones hacia productos caros o poco adecuados.
**INFERENCE — control propuesto:** Revisar devoluciones por motivo, descuentos y satisfacción junto a ventas; no atribuir mala fe sin investigar.
**INFERENCE — manipular retornos:** Una venta ficticia o una devolución aplazada puede inflar resultado antes del cierre de comisión.
**INFERENCE — control propuesto:** Vincular reversos a la línea original, conservar fechas y aprobaciones y conciliar devengado, reversado y pagado sin borrar historia.
**OBSERVED:** SAVIA ya calcula reversos proporcionales de comisión por cantidad acumulada devuelta, pero eso no acredita por sí solo controles antifraude completos.[L02][L04]
**INFERENCE — tráfico injusto:** Una persona puede recibir más citas, clientas habituales o turnos concurridos; el resultado refleja esa oportunidad además de habilidad.
**INFERENCE — control propuesto:** Registrar asignación de oportunidades y horarios, rotar atención según regla conocida y comparar grupos semejantes.
**INFERENCE — canibalización:** Robar atribución, acaparar clientas o evitar ayudar puede mejorar el ranking individual y empeorar la venta del equipo.
**INFERENCE — control propuesto:** Registrar quién atendió y quién cobró, resolver disputas con trazabilidad y evaluar también resultados de sucursal.
**CLAIM:** Una investigación de incentivos colectivos en panaderías reportó mejora de ventas cercana a 3%; no es evidencia de una mejora equivalente en moda.[S19]
**CLAIM:** Otro experimento en una cadena de lencería y baño encontró efecto cero estimado con precisión sobre ventas al introducir el incentivo colectivo estudiado.[S20]
**INFERENCE:** Ambos casos impiden prometer que pagar un bono colectivo elevará ventas en Martha Silva; el diseño y contexto requieren prueba propia.
**INFERENCE — horas invisibles:** Optimizar ventas por hora puede incentivar omitir limpieza, formación o seguimiento si esas tareas perjudican el denominador.
**OBSERVED:** La controversia histórica de Nordstrom documenta precisamente disputas sobre clasificación de tareas y tiempo; no es una sentencia general sobre toda compensación por comisión.[S18]
**INFERENCE — surtido y pocas observaciones:** Falta de tallas, precios y estacionalidad pueden explicar una categoría débil; el sell-through corresponde primero a disponibilidad y compra.
**INFERENCE — privacidad:** Capturar clienteling debe limitarse a identidad y consentimiento necesarios; no hace falta incorporar notas personales sensibles para medir recompra.
**INFERENCE — monedas y medios de pago:** Sumar dólares físicos a córdobas o contar tarjeta y efectivo del mismo ticket dos veces produciría ventas falsas.
**INFERENCE — calidad de fuente:** Una vacante describe expectativas; un informe empresarial declara resultados; ninguno prueba causalidad ni uniformidad internacional.

### Límites, bloqueos y siguiente comprobación

Se completó el informe documental dentro del alcance autorizado.
No se ejerció interfaz, API, SQL Server, nómina ni operación de sucursal; estas capas quedan **NOT RUN** por el alcance read-only.
El cuerpo de Mango devolvió cero líneas, el PDF de Inditex excedió el límite de lectura y Louis Vuitton Merchandising devolvió una página que requiere JavaScript.[S11][S06][S13]
Se conservaron solo sus extractos públicos indexados como evidencia parcial; ninguna conclusión crítica depende exclusivamente de ellos.
La primera vacante de Sephora consultada ya mostraba puesto cubierto; se sustituyó como evidencia principal por una vacante oficial con lista de KPIs legible.[S09]
No se recuperó acceso al artículo completo de AER por HTTP 403; se usó la explicación pública de su editor y el estudio público de Tinbergen.[S19][S20]
No se hicieron bucles de reintento, solicitudes pagadas ni rodeos de acceso.
El propietario de cualquier ampliación de fuentes internas es el orquestador principal, mediante documentos autorizados de las tiendas; cierre: diccionario de KPI verificable.
La calidad de clasificación, horas y oportunidades de Martha queda desconocida porque no se autorizó leer sus datos operativos.
El propietario de esa validación es Martha con el orquestador; cierre: muestra anonimizada y autorizada reconciliada contra tickets, sin tocar producción en esta tarea.
Siguiente acción recomendada al primary: validar definiciones de venta neta, devolución y categoría con Martha antes de especificar la matriz.
Lección de esta revisión: comprobar fórmulas y fechas detrás del nombre del KPI; la lectura de `usp_KpiTeam` cambió la interpretación de «neto» y de devoluciones.[L02]

## Fuentes

Todas las fuentes fueron consultadas el **2026-11-14**.
Las fuentes S son públicas y las L son fuentes del candidato leído localmente, con URL exacta para revisión.
No se usaron testimonios anónimos, currículos personales ni benchmarks comerciales sin metodología como evidencia de las marcas.

- S01 — [Nordstrom: Seasonal Commission Sales, Shoes, Menlo Park][S01]; página oficial, cuerpo leído; metas, seguimiento y remuneración.
- S02 — [Selfridges: Sales Manager, Accessorises, 7021][S02]; página oficial, cuerpo leído; lista de KPIs, vacante cerrada.
- S03 — [Harrods: Sales Associate, Harrods Shop, 6881][S03]; página oficial, cuerpo leído; ventas por hora, productos relacionados, vacante expirada.
- S04 — [Neiman Marcus: Client Relationship Lead][S04]; descripción oficial alojada en SelectMinds; cuerpo y extracto consultados.
- S05 — [NET-A-PORTER: Personal Shopper, R-17351][S05]; página oficial, cuerpo leído; cartera, citas y metas.
- S06 — [Inditex: Sustainability Report 2024, p. 249][S06]; PDF oficial, extracto indexado; lectura completa bloqueada por tamaño `10485761+`.
- S07 — [Fast Retailing: presentación de Takahiro Wakabayashi, 2025-04-10, p. 5][S07]; PDF oficial, texto leído; resultados declarados por la empresa.
- S08 — [Fast Retailing: Pursuing Customer Satisfaction][S08]; página oficial y extracto consultados; dimensiones de satisfacción.
- S09 — [Sephora: Beauty Advisor, Göteborg, 1370621155, 2026-11-04][S09]; página oficial, cuerpo leído; lista de KPIs.
- S10 — [Louis Vuitton: Regional CRM Manager Middle East, LVM34098][S10]; página oficial LVMH, cuerpo leído; conversión y retención.
- S11 — [Mango: Multifunctional Sales Assistant, JR110421][S11]; vacante oficial Workday, extracto indexado; cuerpo sin líneas legibles.
- S12 — [LVMH: Métiers of Retail][S12]; página oficial, cuerpo leído; responsabilidades por categoría.
- S13 — [Louis Vuitton: Merchandising Manager, Dubai, LVM33967][S13]; vacante oficial, extracto indexado; cuerpo requiere JavaScript.
- S14 — [Pronovias: Bridal Sales Stylist, New York, 6171709][S14]; vacante oficial, cuerpo leído; ventas, eficiencia, citas y cartera.
- S15 — [Pronovias: Sustainability Report 2023][S15]; informe oficial, extracto indexado; satisfacción después de pruebas.
- S16 — [Kleinfeld: Careers, Bridal Stylist][S16]; página oficial, cuerpo leído; conversión, conjunto y seguimiento.
- S17 — [David's Bridal: Part Time Bridal Sales, Coral Gables, 160355][S17]; página oficial, cuerpo leído; metas del puesto, no resultados observados.
- S18 — [Tribunal federal de California: orden de certificación de clase, 2013-08-12, pp. 2–5][S18]; documento judicial oficial; contexto histórico y alegaciones, no asesoría legal.
- S19 — [American Economic Association: Ensuring that everybody wins, 2017-09-05][S19]; explicación pública del editor sobre el estudio de Friebel y colaboradores; artículo completo no accesible.
- S20 — [Tinbergen Institute: Team Incentives, Task Assignment, and Performance][S20]; resumen institucional de investigación de Delfgaauw, Dur y Souverijn, 2017; cuerpo leído.
- L01 — [SAVIA: report.mjs, teamContent, líneas 226–259][L01]; lectura estática local.
- L02 — [SAVIA: V027, usp_KpiTeam, líneas 1103–1152][L02]; lectura estática local; sin ejecución.
- L03 — [SAVIA: V001, categorías, productos, items y ventas][L03]; líneas citadas en la crítica; lectura estática local.
- L04 — [SAVIA: V018, atribución y comisiones][L04]; líneas 1–100 y 180–191; lectura estática local.
- L05 — [SAVIA: V028, venta y snapshots, líneas 187–198][L05]; lectura estática local; reemplaza la inserción histórica V018.

[S01]: https://careers.nordstrom.com/seasonal-commission-sales-shoes-menlo-park/job/403C34D67DBC1EC9C82C598BCD75B0CE
[S02]: https://jobsearch.selfridges.com/jobs/job/Sales-Manager-Accessorises/7021
[S03]: https://www.harrodscareers.com/job/sales-associate-harrods-shop-in-various-jid-6881
[S04]: https://neimanmarcus.referrals.selectminds.com/neiman-marcus/jobs/client-relationship-lead-24330
[S05]: https://career.net-a-porter.com/open-positions/job-detail/personal-shopper-net-a-porter-r-17351
[S06]: https://www.inditex.com/itxcomweb/api/media/d6d06b5c-4a2f-431d-915f-ce8ca9e95181/Sustainabilityreport2024.pdf
[S07]: https://www.fastretailing.com/eng/ir/library/pdf/20250410_Wakabayashi_en.pdf
[S08]: https://www.fastretailing.com/eng/sustainability/products/customers.html
[S09]: https://jobs.sephora.com/Nordics/job/Gothenburg-Beauty-Advisor,-G%C3%B6teborg-temp-Christmas-Assistant/1370621155/
[S10]: https://www.lvmh.com/join-us/our-job-offers/LVM34098
[S11]: https://mango.wd3.myworkdayjobs.com/en-US/Mango_Work_Your_Passion/job/MULTIFUNCTIONAL-SALES-ASSISTANT_JR110421
[S12]: https://www.lvmh.com/en/join-us/discover-our-metiers/retail/
[S13]: https://jobs.louisvuitton.com/en/search-page/job/merchandising-manager-united-arab-emirates-dubai-LVM33967
[S14]: https://careers.pronovias.com/en/jobs/6171709-bridal-sales-stylist
[S15]: https://www.pronovias.com/media/sustainability_reports/PRONOVIASGROUP_SUSTAINABILITY_REPORT_2023_EN.pdf
[S16]: https://kleinfeldbridal.com/pages/careers-at-kleinfeld-bridal-kleinfeld-bridal
[S17]: https://careers.davidsbridal.com/details/160355/Part-Time-Bridal-Sales-
[S18]: https://www.govinfo.gov/content/pkg/USCOURTS-casd-3_11-cv-02609/pdf/USCOURTS-casd-3_11-cv-02609-4.pdf
[S19]: https://www.aeaweb.org/research/bonus-incentive-program-for-bakery-chain-teams
[S20]: https://tinbergen.nl/magazine/22/team-incentives-task-assignment-and-performance-a-field-experiment
[L01]: https://github.com/Suazo-AI/Martha-Silva-Store/blob/44fe3074eb9d1f196b51310f55826c3a028ba571/savia/web/screens/report.mjs#L226-L259
[L02]: https://github.com/Suazo-AI/Martha-Silva-Store/blob/44fe3074eb9d1f196b51310f55826c3a028ba571/savia/db/migrations/V027__usd_cash.sql#L1103-L1152
[L03]: https://github.com/Suazo-AI/Martha-Silva-Store/blob/44fe3074eb9d1f196b51310f55826c3a028ba571/savia/db/migrations/V001__baseline.sql
[L04]: https://github.com/Suazo-AI/Martha-Silva-Store/blob/44fe3074eb9d1f196b51310f55826c3a028ba571/savia/db/migrations/V018__seller_commissions.sql
[L05]: https://github.com/Suazo-AI/Martha-Silva-Store/blob/44fe3074eb9d1f196b51310f55826c3a028ba571/savia/db/migrations/V028__usd_change.sql#L187-L198
