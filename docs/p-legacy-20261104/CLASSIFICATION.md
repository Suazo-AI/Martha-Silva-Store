# P-LEGACY: clasificación de las 19 aserciones heredadas

Entradas auditadas: `9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3`. Responsable del ledger: Denis. Ejecutor de esta clasificación: Codex en SUAZO-PC.

Resultado: **19/19 clasificadas: 5 regresión del contrato DOM, 9 obsoletas, 5 entorno, 0 inestables**. Esta tarea clasifica; las correcciones permanecen abiertas en este issue.

“Regresión” aquí significa incumplimiento observado del contrato DOM histórico después de modelar geometría. No atribuye el origen a FIX-PR2 ni prueba un defecto visual en navegador.

## Reproducción fresca

`python prepare.py` pasó. Los tres comandos siguientes salieron con código1 el2026-11-04, entre01:42:53 y01:43:04UTC. No se instaló una dependencia nueva.

| Comando | PASS | FAIL |
|---|---:|---:|
| `node tests/desktop-gallery.cjs` | 1 | 13 |
| `node tests/green-header.cjs` | 4 | 2 |
| `node --test tests/luxury-editorial.cjs` | 4 | 4 |

El código probado fue260b759. La comparación Git de los ocho archivos usados contra9b35697 no tiene diferencias; este último commit añade documentación.

## Diagnóstico independiente del arnés

jsdom no calcula layout. El fixture define offsetLeft/clientWidth, pero desktopLeft consume scrollWidth y getBoundingClientRect; sus valores por defecto llevan el destino a0. Una copia privada e inmutable de las ocho entradas añadió únicamente estos modelos, sin cambiar producto ni aserciones:

```js
Object.defineProperty(viewport,'scrollWidth',{get:()=>slides.length*frameWidth,configurable:true});
Object.defineProperty(viewport,'clientLeft',{value:0,configurable:true});
viewport.getBoundingClientRect=()=>({left:0,width:frameWidth});
for(const slide of slides)slide.getBoundingClientRect=()=>({left:slide.offsetLeft-viewport.scrollLeft,width:frameWidth});
```

Resultado diagnóstico: **6/14 PASS, 8 FAIL**. Cinco de los trece fallos originales desaparecen; los ocho restantes conservan evidencia de contrato o de índices antiguos. No se llama verde a la suite original.

## Cada fallo y su acción

| ID / prueba | Clase | Evidencia directa | Acción pendiente |
|---|---|---|---|
| [DG01 Miniatura desktop y foco](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/desktop-gallery.cjs#L69) | regresión | Con geometría modelada, navegación/foco pasan; aria-hidden de la foto inactiva es null, esperado true. | Conservar el requisito de accesibilidad; verificar foco/tabulación en navegador y corregir fuente o contrato aprobado. |
| [DG02 Wrap anterior/siguiente al video](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/desktop-gallery.cjs#L78) | entorno | Falla con scrollLeft0; pasa al modelar scrollWidth y rectángulos en jsdom. | Completar geometría del fixture; conservar las aserciones de wrap/video. |
| [DG03 Scroll manual y traslado del foco](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/desktop-gallery.cjs#L87) | regresión | Con geometría modelada cambia al índice2; el foco sigue en la foto0, no en la foto2. | Verificar tabulación/scroll real y corregir la política de foco sin quitar cobertura. |
| [DG04 Resize y resource hints](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/desktop-gallery.cjs#L93) | regresión | Con geometría modelada conserva el índice; sizes sigue en 33.333vw, esperado430px. | Medir el ancho real y las descargas en navegador; actualizar hints o justificar un contrato equivalente. |
| [DG05 Retorno a mobile](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/desktop-gallery.cjs#L103) | entorno | Pasa con la misma fuente al modelar geometría desktop; las aserciones de mobile quedan intactas. | Corregir solo el fixture de geometría y mantener restauración/a11y/navigation. |
| [DG06 Navegación con teclado](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/desktop-gallery.cjs#L112) | regresión | ArrowRight deja índice0 en lugar de1 aun con geometría; gallery() no registra ese keydown. | Implementar o resolver explícitamente el contrato de teclado con prueba de foco y teclas modificadas. |
| [DG07 Remount y un único handler](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/desktop-gallery.cjs#L131) | obsoleta | Con geometría, restauración y un desplazamiento pasan; el test espera índice4 tras3, pero existen4 slides y el wrap correcto es0. | Derivar el siguiente índice de slides.length; mantener el conteo de handlers. |
| [DG08 Identidad, comercio y Share](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/desktop-gallery.cjs#L139) | obsoleta | thumb(4) es null; los controles actuales son0..3 tras la revisión de imágenes. | Elegir un índice existente a partir del fixture; conservar identidad/variante/Share/footer. |
| [DG09 Geometría temporalmente oculta](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/desktop-gallery.cjs#L147) | entorno | El caso pasa con geometría consistente; no se cambió la fuente ni ninguna aserción. | Modelar geometría sin sustituir sizes por0; conservar la recuperación de selección. |
| [DG10 Comandos rápidos y teclado End](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/desktop-gallery.cjs#L154) | regresión | Tras modelar geometría, las dos órdenes next pasan; End no cambia índice2. También arrastra el índice5 de un catálogo previo. | Resolver End/ArrowLeft junto a DG06; derivar último/anterior de slides.length, sin borrar las pruebas de carrera. |
| [DG11 Interrupción con wheel](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/desktop-gallery.cjs#L165) | obsoleta | thumb(4) es null antes de ejercitar wheel; el fixture actual tiene controles0..3. | Usar el último índice válido y conservar cancelación del destino pendiente. |
| [DG12 Back a otro ancho](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/desktop-gallery.cjs#L171) | entorno | Pasa al modelar la geometría consumida por desktopLeft, sin cambio de app ni aserciones. | Mantener el fixture consistente y conservar restauración por identidad. |
| [DG13 Back/Forward sin pagehide](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/desktop-gallery.cjs#L183) | entorno | Pasa con geometría modelada; no se cambió historia/router ni aserciones. | Mantener la prueba y añadir después browser BFCache como evidencia distinta. |
| [GH01 Pin de todo styles.css](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/green-header.cjs#L65) | obsoleta | Hash actual9d7cb94e..., esperado14275118... de e2a; falla antes de examinar reglas, tras cambios publicados de galería. | Separar el pin histórico inmutable del contrato CSS actual; revisar reglas y layout, no reemplazar solo el hash. |
| [GH02 Cuatro fotos Green](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/green-header.cjs#L70) | obsoleta | Esperado4, actual3; el manifest de revisión aprobada y la galería actual usan imágenes generadas, no la antigua selección cuatro-fotos. | Versionar el contrato de medios aprobado y derivar controles/filas; conservar fotos y manifiestos históricos. |
| [LE01 Lead editorial y prioridad](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/luxury-editorial.cjs#L59) | obsoleta | Espera /editorial/DdXjMXIFHwT-*; la revisión actual usa /generated-luxury/champagne/01-front-v1.png. | Actualizar procedencia al manifest vigente; conservar eager/high único y lazy de secundarios. |
| [LE02 Dimensiones y responsive de imagen](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/luxury-editorial.cjs#L90) | obsoleta | El mapa de44 derivados originales no contiene /generated-luxury/champagne/01-front-v1.png. | Usar la procedencia actual y validar dimensiones nativas y candidatos; no fabricar derivadas. |
| [LE03 Enlaces de seis fotos editoriales](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/luxury-editorial.cjs#L117) | obsoleta | TypeError al buscar .post de una imagen generada en el mapa antiguo de fotografías Instagram. | Validar las imágenes generadas con su procedencia; conservar la separación de contenido editorial y compra. |
| [LE04 Hash catálogo y selección Green](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/luxury-editorial.cjs#L179) | obsoleta | Hash actual1495e8a1..., esperado bd5e8b95... anterior a la revisión de medios. | Rebasar solo campos de medios contra el manifest vigente; comparar intactos precios, stock y variantes. |

## Contratos y límites conservados

- [Revisión aprobada de imágenes y límites de procedencia](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/evidence/releases/20261030/luxury-selected-assets.json):158ubicaciones,156PNG únicos, selección generada. No equivale a QA visual ni fidelidad del producto real.
- [Publicación histórica de la galería](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/evidence/releases/20261030/gallery-frame-20261030-0330-publication.json): autorización de publicación con QA visual pendiente; el juez siguió HOLD.
- [Límites del fixture desktop](https://github.com/Suazo-AI/Martha-Silva-Store/blob/9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3/tests/desktop-gallery-README.md): simulaciónDOM; no render, CSS, Safari ni BFCache nativo.

No se cambió ninguna aserción ni fuente canónica. No se ejecutó SQL/Docker local ni se usaron datos reales. Los sieteTONY-* continúanreview.

El checkoutTony está cedido al integradorC6. El ledger y PROJECT-STATUS no se modificaron para evitar pisar su integración. Este issue es la evidencia pública revisable de P-LEGACY; el integrador puede enlazarlo y mover la tarjeta a review después de su lectura.

## Aceptación de las correcciones

1. Completar el fixture de geometría y versionar contratos de medios sin borrar pruebas ni pins históricos.
2. Resolver los cinco incumplimientos DOM o documentar un contrato equivalente aprobado, con evidencia del navegador.
3. Repetir las tres suites con conteos exactos y conservar controles de accesibilidad, precios, stock y variantes.
4. Mantener P-LEGACY y este issue separados: la clasificación tiene19/19 entradas; sus correcciones y aceptación de producto no están terminadas.

Integridad de la tabla:19IDs únicos, total5+9+5=19. SHA256 del diagnóstico `dd3488dfff750a79e0b162785083c491a200f030ca05b57e2f95c8736b7d0ded`.
