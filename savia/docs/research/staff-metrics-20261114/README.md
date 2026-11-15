# Métricas por vendedora y categoría (2026-11-14)

Estado: propuesta; nada construido en SAVIA.
Pedido de Jason: medir ventas por vendedora y por tipo de prenda, investigar tiendas líderes, criticar, concluir y mostrar un visual.

## Resultado

SAVIA no puede atribuir hoy cada prenda vendida a una categoría.
Solo la importación del catálogo guarda categoría, y es opcional; recepción y etiqueta crean productos sin ella.
Recomendación: categoría obligatoria al registrar, reporte vendedora × categoría con «Sin categoría» visible, y sin cambiar comisiones hasta tener datos.
El reporte Equipo llama «venta neta» a un valor que no resta devoluciones (`V027__usd_cash.sql:1117-1126`).

## Archivos

- `RESEARCH.md`: tiendas líderes, crítica y 12 métricas priorizadas, con 20 fuentes públicas.
- `DATA-AUDIT.md`: auditoría con archivo:línea y diseño mínimo de categoría.
- `mockup.html`, `mockup-1440.png`, `mockup-390.png`: visual con datos de ejemplo.
- `decision.html`: página resumen publicada como artifact privado: https://claude.ai/artifact/BuW37kdXsSkiSQqUdKo3At

## Evidencia

- Workers: Codex `gpt-6.1-sol` high (investigación; auditoría y mockup) y Antigravity `gemini-4-argon` high (investigación cruzada, sin archivos).
- Base: `44fe3074eb9d1f196b51310f55826c3a028ba571`.
- El orquestador comprobó las citas de `CatalogStore.cs:22-24`, `reception.mjs:303-348`, `V025__catalog_import.sql:96-103` y `V027__usd_cash.sql:1117-1133`.
- El orquestador comprobó en la vacante oficial de David's Bridal las metas 65%, 75%, 10%, 20% y 80%.
- El orquestador cambió los datos de ejemplo de las vendedoras B y C para que el mix difiera; las sumas por categoría siguen iguales (C$ 114,000; 75 unidades).
- `agent-browser` a 1440×900 y 390×844: `scrollWidth` igual a `innerWidth` en ambos.

## Límites

- No se consultó ninguna base de datos; el número real de productos sin categoría es desconocido.
- La investigación de Antigravity citó redirecciones de búsqueda y reportes de empleados; se usó solo como contraste.
- Taxonomía y aceptación visual pendientes de la dueña.

## Decisiones de la dueña (comentarios en el artifact, 2026-11-15)

- Categorías: fiesta/noche, novia, moda casual, accesorios y calzado, más «Sin categoría» visible.
- Venta neta de la vendedora resta devoluciones.
- Ganancia por vendedora (venta menos costo) es privada; quién la ve sigue abierto.
- La gerente ve las métricas de su equipo solo en su tienda.
- Comprobado en código: la venta guarda costo (`V027__usd_cash.sql:209`, `V028__usd_change.sql:192-194`) y rechaza prendas sin costo (`V028__usd_change.sql:154`). No existe rol ADMIN (`V001__baseline.sql:1969-1971`, `V002__api_support.sql:19-24`, `V017`).
- Revisión independiente (Claude Sonnet, solo lectura) marcó dos inferencias como decisiones; se movieron a propuesta (artifact versión 4).

## Siguiente acción

La dueña decide: una categoría por prenda o varias; si la categoría queda fija al vender; quién ve la ganancia y qué es «admin».
Después: especificación de etapa 1 y crítica previa con `gpt-6-astra` xhigh, porque toca datos de ventas.
El visual de ejemplo todavía no incluye calzado; se agrega al integrar la galería de gráficos.
- 2026-11-14: `decision.html` corregida en teléfono: las imágenes se estiraban (faltaba `height:auto`); a 390 px se muestra la versión móvil. Verificado con agent-browser a 390 y 1440, scrollWidth igual a innerWidth.
