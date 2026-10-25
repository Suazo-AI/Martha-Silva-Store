# QA externo representativo — Martha Preview

**Resultado:** completado en navegador normal. Sin fallos funcionales confirmados en los recorridos probados; quedan límites explícitos.

**Versión declarada:** `7f29cf5a75db60c93b3bb3efa89c7e33d9e02a79`.
**Destino:** https://martha-silva-preview.martha-silva-denis.workers.dev/
**Viewport real:** 1180 × 757, DPR 1. No es una prueba móvil ni a 1440 px.

## Comprobado

- Home accesible, con fotografía de portada cargada.
- Catálogo: **40 prendas**. Novias: **6**; Novias + Dorado: **0**; limpiar: **40**. Cierre de filtros devuelve foco.
- Orden ascendente: 40 precios de USD 65 a USD 295, verificados en orden.
- Ficha Rosa: navegación, zoom y cierre con Escape; foco devuelto a la fotografía.
- Bolsa demo: SAVIA conserva **Rosa/S** y SISFAIN **Rosa/M**, sin mezclarlas. Retirar en SAVIA no afecta SISFAIN. **Ambas bolsas quedaron vacías**.
- Hover real de tarjeta Rosa: vídeo WebM reproducido, `readyState=4`, 720 × 1280, sin error; salir con el puntero lo pausa.
- Vídeo de la ficha: controles manuales y carga diferida observados. **No se probó su reproducción manual**.

## Procedencia

`/deployment.json` fue leído como texto renderizado por Chrome normal y declara **856 archivos**. Coinciden:

- Commit: `7f29cf5a75db60c93b3bb3efa89c7e33d9e02a79`.
- `app.js`: `b0d5b729c6888c690ce940a8d3da8a94fcadc8b324301d587ca43a043cf215f8`.
- `catalog.js`: `c2d5ed59e03dd68b8e279a33bbce27f120ddb0ca29ff260bb2ec38bdf2df726f`.

**Son hashes declarados en el manifiesto, no hashes calculados aquí de los cuerpos servidos.** El deployment ID y los 857 assets totales provienen del reporte del usuario, no de una consulta API propia.

## Límites

Muestreo representativo, no recorrido exhaustivo de 47 páginas ni validación de todos los assets. No se probaron móvil, reduced-motion/saveData, rendimiento o accesibilidad completa. No se abrieron checkout/admin ni se enviaron formularios, pedidos o pagos. No hubo cambios de fuente, despliegue, credenciales, permisos, SQL, descargas alternativas, cambios de UA o repetición de urllib. No se revalida el gate histórico 777/778.

## Capturas

| ID | Archivo | Evidencia |
|---|---|---|
| 01 | `01-home.jpg` | Home y foto hero |
| 02 | `02-catalog.jpg` | Catálogo |
| 03 | `03-filter-empty.jpg` | Filtros sin resultados |
| 04 | `04-product.jpg` | Ficha Rosa |
| 05 | `05-zoom.jpg` | Zoom abierto |
| 06 | `06-product-video.jpg` | Vídeo de ficha con controles |
| 07 | `07-bag-savia.jpg` | Alta en bolsa SAVIA |
| 08 | `08-bag-savia-restored.jpg` | SAVIA restaurada: talla S |
| 09 | `09-bag-sisfain-restored.jpg` | SISFAIN restaurada: talla M |
| 10 | `10-card-hover.jpg` | Hover de tarjeta con vídeo |

Detalles y límites por prueba: `REMOTE-QA-RESULTS.json`. Identidad: `provenance.json` y `deployment-rendered.json` (resumen extraído, no manifiesto completo). Las capturas y evidencias DOM/JSON quedan en esta carpeta.
