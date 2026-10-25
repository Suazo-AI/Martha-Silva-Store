# Martha Silva: sistema visual recuperado

Fuente autorizada: [original Cloudflare](https://martha-silva-demo.jason-suazof.workers.dev/), captura pública del 25 de octubre de 2026 UTC. Los HTML, `styles.css`, `prototypes/fonts/fonts.css` y cuatro vendors locales fueron observados en ese mismo origen. El original permanece separado e intacto.

## Evidencia y alcance

Se inspeccionaron los píxeles de la captura completa de Firecrawl: cabecera negra, tipografía editorial, fotografía de campaña y colecciones sobre blanco; un modal de newsletter oscurece esa captura. Cutufay observó el original sin modal y entregó capturas de home, catálogo y producto, filtros 40→20→1, hover, mega-menú, zoom y video. Su viewport real fue 1165×747 o 1180×757; no acredita móvil ni 1440×1000. Los valores siguientes proceden del CSS descargado, no de estimaciones visuales.

## Tokens de la fuente

| Uso | Valor CSS |
| --- | --- |
| Fondo / texto | `#fff` / `#111` |
| Texto editorial / secundario | `#2b2b2b` / `#656565` |
| Cinta / borde / panel claro | `#cbcbcb` / `#e5e5e5` / `#f7f7f7` |
| Error | `#b60218` |
| Títulos | Cormorant Garamond, Georgia, serif |
| Texto e interfaz | Manrope, Arial, sans-serif; base 16px/18.4px |
| Escala de espacio | 8, 16, 24, 32, 48px; gutter 32px |
| Radio | 2px |
| Transiciones | fade 200ms; slide 300ms; `cubic-bezier(.25,.1,.25,1)` |
| Capas | header 100; menú 200; drawer 1000; modal 1100 |

Fuentes locales: cuatro TTF Cormorant (400 italic, 400/500/600 normal) y cuatro Manrope (400/500/600/700), `font-display: swap`.

## Composición y componentes

Cabecera de escritorio: cinta de 32px y header de 106px, masthead de 72px y navegación de 34px; contenedor máximo 1440px. Wordmark 40px/48px, tracking 2px. Mega-menú blanco de 532px con tres columnas de enlaces y editorial de 280×360px. El hero original ocupa `calc(100vh - 138px)` con mínimo 500px, texto inferior y degradado. La copia conserva deliberadamente el hero fotográfico de la demo mejorada, sin autoplay de video.

Secciones editoriales y carruseles preceden las colecciones. Catálogo con filtros, ordenación y tarjetas con segunda imagen al hover. PDP con galería, variantes, guía de tallas y zoom. Bolsa, checkout, pedido y ayuda comparten cabecera/pie. Botones oscuros de altura mínima 40px y variante blanca con borde; foco visible de 2px. Los breakpoints extraídos son 1023px y 599px; por sí solos no prueban QA móvil.

El código recuperado usa GSAP para la entrada de 0.2s y Barba para transición de 0.12s. ScrollTrigger y Lenis están descargados por la fuente, pero no se encontró inicialización: no se añaden efectos supuestos. El transporte de la app original no se habilita; la copia conserva adaptadores locales SAVIA/SISFAIN y su aviso de demostración.

## Imágenes y fidelidad

Se conserva `/research/assets/...` para galerías y derivados responsive, con 40 grupos y 170 posiciones. Hay seis grupos declarados `sample_image=true`; esa marca se mantiene. La captura disponible contiene 777 medios de 778 históricos: el JPEG `/research/assets/martha-gala/f1bf4e3664d34cd4.jpg` devuelve 404 y no se reemplaza. Esa referencia antigua no pertenece a la galería renderizada actual. La integridad, el mapeo visual y el QA del build se registran por separado en `evidence/`.

Las páginas utilizan un catálogo compartido en lugar de repetir el JSON de medios en cada HTML. Se conserva el diseño y sus selectores con menos bytes repetidos. Ningún precio, stock o foto de muestra se presenta como inventario comercial verificado. No se afirma fidelidad píxel por píxel ni validación completa de accesibilidad o rendimiento.
