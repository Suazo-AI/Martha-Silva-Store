# Resumen

SAVIA puede atribuir algunas unidades a una categoría mediante el catálogo, pero no garantiza una categoría para cada unidad vendida.
La importación V025 sí asigna categorías; recepción y etiqueta crean productos sin ese dato.
Esta auditoría es estática sobre el SHA `44fe3074eb9d1f196b51310f55826c3a028ba571`, en SUAZO-PC, el 2026-11-14.
No se consultó SQL Server ni se verificó qué migraciones o datos existen en una instalación operativa.
Modo: DISCOVER + VALIDATE; resultado externo buscado: permitir coaching por vendedora y categoría sin revelar ventas ajenas.
El cuello de botella es la clasificación incompleta, no la visualización.
Recomendación: reutilizar Categories y exigir una categoría en las entradas antes de crear otra estructura de clasificación.

# Lo que existe (file:line)

Las rutas siguientes son relativas a la raíz de este checkout y corresponden al SHA indicado.
`savia/db/migrations/V001__baseline.sql:260-272` define Categories con nombre, estado activo y padre opcional.
`savia/db/migrations/V001__baseline.sql:321-334` define Products.CategoryId nullable y su clave foránea a Categories.
`savia/db/migrations/V001__baseline.sql:341-361` define Items como variantes con ProductId obligatorio.
`savia/db/migrations/V001__baseline.sql:807-831` conecta SaleLines.ItemId con Items y conserva SKU y nombre, pero no una categoría histórica.
La ruta de atribución es SaleLines.ItemId → Items.Id → Items.ProductId → Products.Id → Products.CategoryId → Categories.Id.
`savia/db/migrations/V001__baseline.sql:2193-2213` permite @CategoryId=NULL en usp_RegisterProduct y lo escribe en Products y en el evento de registro.
`savia/db/migrations/V001__baseline.sql:2202-2206` comprueba solamente el nombre al reutilizar ProductId, no la categoría.
`savia/src/Savia.Contracts/Catalog.cs:9` limita RegisterProductRequest a ProductId y Name.
`savia/src/Savia.Infrastructure/CatalogStore.cs:22-24` llama a usp_RegisterProduct sin @CategoryId.
`savia/src/Savia.Application/Catalog.cs:60-71` exige permisos de aprobación para crear productos y valida el nombre, sin exigir categoría.
`savia/web/screens/reception.mjs:303-353` pide nombre, precio y costo y llama a registerProduct sin categoría al registrar una prenda desconocida.
`savia/src/Savia.Contracts/Tags.cs:9-12` devuelve nombre, marca, talla, color, precio y composición en la extracción, sin categoría.
`savia/web/etiqueta/etiqueta-logic.mjs:7` enumera los campos editables sin categoría.
`savia/web/etiqueta/etiqueta-logic.mjs:83-87` construye el producto con ProductId y nombre.
`savia/web/etiqueta/etiqueta.mjs:293` registra ese producto mediante el mismo endpoint sin categoría.
`savia/web/screens/import-logic.mjs:2-11` incluye type como «Tipo de prenda» y `:48-56` convierte valores vacíos o columnas ausentes a null.
`savia/src/Savia.Contracts/Catalog.cs:16-18` admite ImportRow.Type nullable.
`savia/db/migrations/V025__catalog_import.sql:35-37` restringe la importación a OWNER con acceso activo a la sucursal.
`savia/db/migrations/V025__catalog_import.sql:40-46` convierte type vacío a TypeName NULL.
`savia/db/migrations/V025__catalog_import.sql:52-63` valida filas sin rechazar TypeName ausente.
`savia/db/migrations/V025__catalog_import.sql:90-104` crea categorías desde tipos no vacíos y pasa @CategoryId a usp_RegisterProduct.
`savia/db/migrations/V025__catalog_import.sql:96-103` agrupa productos por nombre y usa MIN(TypeName), por lo que tipos incompatibles pueden quedar reducidos a uno.
La búsqueda `rg -n "CategoryId|categoryId|catalog.Categories" savia/db/migrations savia/src savia/web` encontró las asignaciones anteriores y ninguna obligatoriedad adicional hasta V028.
`savia/db/migrations/V028__usd_change.sql:191-198` escribe SellerId por línea de venta y no añade una categoría a la línea.
`savia/web/screens/report.mjs:225-245` dibuja Equipo con ventas, prendas, tickets, devoluciones, descuentos y comisión, sin desglose por categoría.
`savia/web/api.mjs:247` solicita `/reports/kpi/team`.
`savia/src/Savia.Api/ReportsEndpoints.cs:23-27` conecta la lectura y exportación CSV con ReportsService.KpiTeamAsync.
`savia/src/Savia.Application/Reports.cs:36-40` deriva la sucursal del actor y pasa su StaffId.
`savia/src/Savia.Infrastructure/ReportsStore.cs:25-27` ejecuta sales.usp_KpiTeam.
La definición vigente en las migraciones inspeccionadas es `savia/db/migrations/V027__usd_cash.sql:1103-1151`; V028 no redefine ese procedimiento.
`savia/db/migrations/V027__usd_cash.sql:1108-1115` exige rol autorizado y acceso a sucursal, calcula periodos y aplica límites diarios a las 06:00 UTC.
`savia/db/migrations/V027__usd_cash.sql:1124-1126` calcula unidades y vendido como SUM(UnitPriceMinor*Quantity-DiscountMinor), agrupados por SellerId sin categorías.
`savia/db/migrations/V027__usd_cash.sql:1117-1122` llama netSalesMinor a ese vendido después de descuentos, pero no resta ret.net de devoluciones.
`savia/db/migrations/V027__usd_cash.sql:1127-1132` suma créditos aprobados por fecha de devolución y los atribuye a la vendedora de la línea original.
`savia/db/migrations/V027__usd_cash.sql:1120` calcula returnsBps por monto devuelto sobre vendido, no por unidades.
`savia/db/migrations/V027__usd_cash.sql:1110` habilita vista de equipo para MANAGER y OWNER.
`savia/db/migrations/V027__usd_cash.sql:1133` limita SELLER a su propia fila en SQL.
`savia/web/app.css:1-18` aporta los tokens reales del mockup: primary #124b2d, accent #257252, canvas #f6f5f1, ink #182921 y surface #fff.
`savia/web/app.css:25-54` aporta tipografía de sistema, controles de 44px, foco visible, rail y contexto superior.

# Lo que falta

Falta exigir categoría en recepción, etiqueta, contrato API, procedimiento de registro e importación.
Falta un vocabulario controlado y un rechazo de categorías incompatibles dentro del mismo producto importado.
Faltan lecturas y exportaciones por vendedora y categoría con la misma autorización del reporte actual.
Falta medir productos sin categoría en la base autorizada; la cantidad real es desconocida.
Falta una regla histórica para impedir que cambiar Products.CategoryId cambie retroactivamente resultados publicados.

# Diseño propuesto

Todo este apartado es propuesta, sin implementación ni migración ejecutada.
Proponer a la dueña cuatro categorías excluyentes: Vestido de fiesta/noche, Novia, Moda casual y Accesorios.
La lista no es una taxonomía comercial confirmada y no se deduce automáticamente del nombre o del OCR.
Capturar CategoryId mediante selector obligatorio al crear producto en recepción y en la confirmación de etiqueta.
Para variantes conocidas, heredar la categoría del producto y mostrar una corrección autorizada si falta.
En importación, mapear Tipo de prenda a una categoría activa existente y bloquear filas vacías, desconocidas o contradictorias por producto.
Validar en API y SQL; un formulario required no garantiza integridad.
Mantener las mismas facultades de creación y permitir administrar categorías solamente a OWNER.
Impedir nuevas ventas de productos sin categoría válida después del corte acordado, comprobándolo transaccionalmente al contabilizar.
No permitir «Sin categoría» como selección nueva; reservar ese bucket visible para el legado y excepciones históricas.
Hacer backfill revisado por la dueña, por lotes de ProductId, con categoría anterior, nueva, responsable, motivo y fecha.
No inferir categorías de fotos, precios, palabras o marcas sin confirmación humana.
Reconciliar antes y después las unidades y montos por sucursal, incluyendo siempre el bucket pendiente.
Para el alcance mínimo, congelar CategoryId después de la primera venta clasificada; las reclasificaciones posteriores requieren otro diseño aprobado.
El backfill del legado reclasifica también sus ventas históricas y debe mostrar fecha de reclasificación y preservar el informe anterior para comparación.
Si la dueña necesita clasificar el catálogo de nuevo sin alterar historia, ampliar el alcance con snapshot de categoría por línea y devolución enlazada al snapshot original.
Usar LEFT JOIN al catálogo y COALESCE al bucket pendiente para no perder líneas sin categoría.
Agregar ventas y devoluciones por separado por sucursal, SellerId y categoría antes de unirlas, evitando multiplicar líneas por devoluciones parciales.
Unidades vendidas = suma de Quantity de ventas contabilizadas en el periodo.
Unidades devueltas = suma de cantidades de devoluciones aprobadas en el periodo, incluso si la venta fue anterior.
Vendido = precio por cantidad menos descuentos, en centavos NIO y sin sumar cobros USD como otra venta.
Venta neta = vendido menos créditos aprobados del periodo, con una base tributaria consistente acordada antes de implementar.
Participación = venta neta de categoría / venta neta total de la vendedora; si el total es cero o hay componentes negativos, mostrar «—» y reemplazar la barra por montos.
Devoluciones % = monto devuelto de categoría / vendido de categoría; mostrar «—» si el denominador es cero y permitir resultados mayores a 100%.
Precio medio = venta neta / (unidades vendidas menos unidades devueltas); mostrar «—» si el denominador no es positivo.
El criterio por fecha de evento permite importes negativos por devoluciones de ventas anteriores y no representa una cohorte de ventas.
Conservar inicialmente periodos day/week/month/year; el rango del mockup representa noviembre completo y no promete una API de rangos arbitrarios.
Conservar alcance por sucursal y control SQL de fila antes de agregar, también en CSV, detalle, totales y barras.
La vista OWNER o MANAGER muestra equipo; la vista SELLER recibe únicamente sus categorías y sus totales.
No enviar el equipo completo al navegador para después ocultarlo.
El mockup representa una vista de dueña para «Sucursal de ejemplo» con tres identificadores sintéticos y ningún dato de personas reales.
Las barras codifican participación por venta neta, con leyenda y tabla textual; el detalle de Vendedora A permanece desplegado para revisión.
Las cinco series usan primary, accent, muted, warning y line de app.css; son codificación propuesta, no colores comerciales extraídos de una marca.
La composición adapta la tabla real de Equipo y el rail existente; en móvil cada fila se convierte en ficha con etiquetas y sin desplazamiento horizontal.
La etiqueta «Datos de ejemplo» permanece visible y las fechas son texto de un periodo fijo para evitar prometer filtros operativos.
Pruebas requeridas para una implementación futura: null directo en API/SQL, categoría inactiva, importación conflictiva, venta concurrente con reclasificación y backfill reversible.
Pruebas adicionales: devolución parcial repetida, venta compartida por vendedoras, devolución de otro periodo, totales cero/negativos y suma de categorías igual al total.
Verificar acceso directo ajeno, otra sucursal y CSV con SELLER; el resultado esperado es denegación o solo su fila, nunca datos ajenos.

# Riesgos

Las búsquedas estáticas prueban estructura e intención, no migraciones aplicadas ni calidad del catálogo operativo.
La clasificación libre actual puede crear sinónimos o productos agrupados con categorías erróneas.
Cambiar una categoría sin congelación o snapshot altera historia y puede distorsionar coaching y comisiones.
La nueva venta neta no debe reemplazar silenciosamente netSalesMinor ni cambiar la base de comisiones existente.
No mezclar retorno físico, crédito aprobado y movimiento de caja como tres devoluciones distintas.
El mix de sucursales, turnos, precios y disponibilidad afecta comparaciones; estas métricas no prueban habilidad ni causalidad.
No ampliar el permiso SELLER al añadir filtros o detalle.
No se ejecutaron SQL, tests del producto, integraciones, pagos, servicios ni consultas de inventario real.
La aceptación visual y la taxonomía final pertenecen a la dueña y al orquestador primario.
Limitación de herramienta: preview_open rechazó file: con «Invalid preview URL (unsupported-protocol: file:)»; se usa el CLI local solicitado.
Verificación local del archivo final: `agent-browser --session savia-staff-metrics-20261114 --allow-file-access open "file:///C:/Users/Jason/.t3/worktrees/github/t3-363ef031-2c01734c360488ae/savia/docs/research/staff-metrics-20261114/mockup.html"` salió 0.
`agent-browser --session savia-staff-metrics-20261114 set viewport 1440 900` y `set viewport 390 844` salieron 0.
En cada viewport se ejecutó `agent-browser --session savia-staff-metrics-20261114 eval "JSON.stringify({innerWidth,scrollWidth:document.documentElement.scrollWidth,innerHeight,overflow:[...document.querySelectorAll('body *')].filter(e=>e.getBoundingClientRect().right>innerWidth+1).map(e=>e.tagName+'.'+e.className)})"`.
Resultado escritorio: innerWidth=1440, scrollWidth=1440, innerHeight=900, overflow=[].
Resultado móvil: innerWidth=390, scrollWidth=390, innerHeight=844, overflow=[].
`agent-browser --session savia-staff-metrics-20261114 screenshot "<directorio de este documento>/mockup-1440.png" --full` y su equivalente mockup-390.png salieron 0.
Las capturas completas miden 1440×1146 y 390×3339; corresponden a viewports 1440×900 y 390×844 con desplazamiento vertical normal.
Se inspeccionaron directamente ambas capturas: contenido legible, sin superposición ni recorte lateral observado.
La evaluación de performance.getEntriesByType('resource') devolvió []; sampleLabel=true y detailsOpen=true.
`agent-browser --session savia-staff-metrics-20261114 close` salió 0 y devolvió «Browser closed».
La comprobación local de rutas y rangos de citas pasó y el directorio contiene exactamente los cuatro archivos solicitados.
Los 14 tokens copiados coinciden con app.css; contraste calculado: ink/surface 15.24:1, muted/surface 6.66:1, primary/surface 10.14:1, warning/warning-bg 6.70:1 y on-primary/primary 10.14:1.
La reconciliación aritmética del ejemplo pasó: equipo y categorías suman C$ 114,000 y 75 unidades; el detalle A suma C$ 57,000.
Lección aplicada: mantener «vendido» y «venta neta» separados evita trasladar al diseño una etiqueta ambigua del KPI existente.
No hay bloqueos abiertos dentro del encargo; confirmar taxonomía y aceptar el diseño siguen siendo decisiones de la dueña y del orquestador.

# Preguntas para la dueña

¿Confirma las cuatro categorías o necesita separar fiesta de noche y añadir otras líneas comerciales?
¿Una prenda tiene una sola categoría principal, aunque sirva para varias ocasiones?
¿Autoriza reclasificar ventas históricas durante el backfill o exige conservar la categoría al momento de vender?
¿Confirma venta neta después de devoluciones y devoluciones por monto, registradas en la fecha del evento?
¿Debe MANAGER conservar acceso a todo su equipo o quiere restringir ese acceso a OWNER?
