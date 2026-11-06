# Revisión Independiente (Gemini Critic): Storefront Jason + Imágenes Denis, Hardening y Corrección LF

- **Fecha**: 2026-11-06
- **Rol**: Gemini critic
- **Modelo solicitado / efectivo**: `gemini-4-argon`, `high` solicitado; efectivo `gemini-4-argon` (T3 Code / Antigravity; razonamiento interno efectivo, tokens y costo no expuestos: `UNKNOWN`)
- **Host / Worktree**: `SUAZO-PC` (Windows) / `C:/Users/Jason/.t3/worktrees/github/t3-57bf20db`
- **HEAD verificado**: `a77f705a6fd6a2778e4112c21aaa72ab8e478015` (derivado de `8523523a41d490f7bdcca016bf34cc5fc2c04a37`, base `65ab1d942a4666321e489da1cccd6341a0f671b7`)

---

## 1. Veredicto / Verdict

**REJECT** (Rechazado por regresión determinista en `tests/responsive_images.py` tras la normalización CRLF→LF de `index.html`, y brecha de portabilidad Windows/Linux para `_headers` en `.gitattributes` y `tools/verify_release_snapshot.py`).

- **Estado de producción**: **NO-GO**. La entrega es consultiva; ningún gate de pagos reales, backend/SQL, inventario comercial ni despliegue queda cerrado.
- **Composición visual (D-030)**: El frontend/layout de Jason integrado con las 624 imágenes de Denis (156 PNG + 468 WebP) y 17 archivos de fuentes cumple fielmente con D-030, pero el commit `a77f705a6fd6a2778e4112c21aaa72ab8e478015` romperá el segundo job (`historical-regressions` → `python tests/check.py --install`) en Linux CI (`tony-snapshot.yml`).

---

## 2. Brechas de Acceso / Instruction Access Gaps

Se leyó `AGENTS.md` en el repositorio. El hook de seguridad del entorno denegó la lectura fuera del workspace (`Access to path ... is outside the allowed workspace directories`) para:
- `C:/Users/Jason/AI-OS/rules/orchestration.md` — **ACCESO DENEGADO**
- `C:/Users/Jason/AI-OS/rules/PROTOCOL.md` — **ACCESO DENEGADO**
- `C:/Users/Jason/AI-OS/rules/OUTPUT.md` — **ACCESO DENEGADO**

No se eludió el sandbox ni se infirió su contenido.

---

## 3. Hallazgos Materiales / Material Findings

### Hallazgo M1 (BLOQUEANTE / BLOCKER): `tests/responsive_images.py:26-29` falla porque fija el hash CRLF pre-corrección de `index.html`

- **Archivo y línea**: `tests/responsive_images.py:26-30` (invocado por `tests/check.py:101-102` y `.github/workflows/tony-snapshot.yml:57`).
- **Mecanismo de fallo**:
  En la línea 26 se define:
  `selected_layouts={'index.html': '008e96af33d9ba8c3630d057a6885faf314a859d9d55bed9cf8d1782898d4e54', 'catalogo.html': '672886e25c2de0535b5265f9e105d63f1acbb50eeefceb6f8cebc79328268c92'}`
  y en las líneas 28-29 se elimina `<source data-responsive-generated=""[^>]+>` de `page.read_bytes()` y se compara el SHA-256 contra `selected_layouts`.
  - En `8523523`, `build-inputs/static/index.html` tenía CRLF en el disco de Windows (`3a2d298f...`); al quitar las etiquetas `<source data-responsive-generated...>`, su SHA-256 con CRLF era `008e96af33d9ba8c3630d057a6885faf314a859d9d55bed9cf8d1782898d4e54`.
  - En `a77f705a6fd6a2778e4112c21aaa72ab8e478015` (`CI-LF-FIX.json:20-25`), el primario normalizó `build-inputs/static/index.html` a LF (`b025431c...`, quitando 428 bytes `\r`), que es como Git lo extrae en Linux y Windows (`.gitattributes:20`).
  - Con `index.html` en LF, el SHA-256 tras quitar las etiquetas generadas es `35a8495127d2da4ce6061e77092fb46682e5a7c5d34ec5c88f2646985f3db1f5` (`catalogo.html` ya estaba en LF y conserva `672886e2...`).
  - El primario no re-ejecutó `python tests/responsive_images.py` tras la normalización (`CI-LF-FIX.json:48-118`). Al ejecutarlo personalmente sobre `a77f705`, falla con:
    `AssertionError: '35a8495127d2da4ce6061e77092fb46682e5a7c5d34ec5c88f2646985f3db1f5' != '008e96af33d9ba8c3630d057a6885faf314a859d9d55bed9cf8d1782898d4e54' : index.html`.
  - Este mismo fallo romperá el job `historical-regressions` del run de Linux CI `42170897865`.

### Hallazgo M2 (Portabilidad Windows/Linux): `_headers` carece de `eol=lf` en `.gitattributes` y escapa de la guarda CRLF en `tools/verify_release_snapshot.py:40-41`

- **Archivo y línea**: `.gitattributes:19-25` y `tools/verify_release_snapshot.py:40-41`.
- **Mecanismo de fallo**:
  - `evidence/releases/20261105/responsive-runtime-sha256.json:2-5` registra `_headers` con su hash LF (`503d49f3f495ee3001ae78d8db6ca666bbe424cfa962ba4244348000943e907f`, 486 bytes), idéntico al blob en Git.
  - `.gitattributes:19-25` declara `text eol=lf` para `*.html`, `*.js` y `*.css`, pero omite `_headers`.
  - En cualquier checkout o worktree nuevo en Windows con `core.autocrlf=true` (como `t3-57bf20db`), Git convierte `build-inputs/static/_headers` y `dist/_headers` a CRLF (495 bytes, RAW SHA-256 `7585293acbbcf9e7ed8a35b80bbaa9b92af00ecf90127afb69b2830d7384590f`), mientras los otros 1,558 archivos quedan en LF.
  - En consecuencia: (1) `python tools/verify_release_snapshot.py` falla en worktrees Windows limpios con `AssertionError: Publication bytes differ from the recorded snapshot` por `_headers`; y (2) la guarda CRLF (`path.suffix in {'.html', '.js', '.css'}`) no cubre `_headers`, permitiendo que `--record` en un worktree Windows grabe un hash CRLF para `_headers`.

---

## 4. Verificación de los 8 Criterios de Aceptación / Eight Acceptance Checks

1. **Referencia exacta y hashes (`reference/IMPORT.json`, `reference-provenance.json`) — PASS**:
   Verificados personalmente los 8 archivos recuperados de `https://martha-silva-demo.jason-suazof.workers.dev/`. Los 6 `.txt` coinciden con `saved_lf_sha256`. Los 2 wrappers JSON (`styles.css.json` SHA-256 `77d9e371...` y `app.js.json` SHA-256 `4e13b815...`) preservan líneas en blanco finales y al decodificar `"text"` a UTF-8 LF recuperan exactamente `8f9e1261...` y `49674f5f...`. `source_commit` permanece `"UNKNOWN"`.
2. **Estructura, estilo, navegación y demo de Jason (`index.html`, `catalogo.html`, `styles.css`, `src/app.js`) — PASS**:
   Preserva la barra negra `.site-header`, mega-menú, carrusel hero de 3 diapositivas (`.hero-oh`, `.ho-slide`, `.ho-dots`, `.ho-pause`), catálogo con pestañas `[data-category-tab]`, mosaicos `.category-tiles`, selector de columnas `[data-cols]` (2/3/4 desktop, 1/2 móvil), tarjetas `.plp-card` con `Agregar rápido` (`[data-quick]`, `[data-quick-size]`), bolsa, mini-bag, checkout y pedido `DEMO-0001`.
3. **Preservación de 156 PNG + 468 WebP de Denis y 17 fuentes — PASS**:
   Verificados criptográficamente en disco los 624 archivos de `media-hashes.json` (156 PNG + 468 WebP) y los 17 archivos de `font-hashes.json` (8 TTF, 8 WOFF2, `fonts.css`): `0` discrepancias.
4. **Sin layout editorial de Denis en el hero ni tercer diseño — PASS**:
   `.luxury-hero` fue eliminado de `index.html`. El carrusel `.hero-oh` de Jason encabeza la portada; `.luxury-editorial` (6 ilustraciones con enlace a Instagram sin compra) y `.editorial-campaign` (`El edit de novias`) permanecen integrados sin inventar un tercer diseño.
5. **Accesibilidad, avisos legales/demo/IA/noindex, rutas y checkout sintético — PASS**:
   Las 47 páginas conservan `meta[name="robots" content="noindex,nofollow"]` y `_headers` añade `X-Robots-Tag: noindex, nofollow`. El banner `Demo independiente · datos locales · sin cobros` es visible; `[data-storefront-integration-hidden]` oculta el panel técnico manteniendo avisos de pago simulado en bolsa/checkout/pedido. Todas las imágenes generadas incluyen `· Imagen generada con IA` en `alt`. Los 40 IDs de producto, 120 variantes y 47 páginas permanecen intactos.
6. **Build reproducible y pruebas enfocadas significativas (diff desde `65ab1d94`) — FAIL (por Hallazgo M1)**:
   `tests/luxury-editorial.cjs:53-163`, `tests/static_headers.py:41-63` y `tests/test_release_snapshot.py:15-74` verifican comportamiento real y controles negativos (mutación de `alt`, `src`, `<source>`, cabeceras, CRLF y archivos extra). Sin embargo, `tests/responsive_images.py:26-29` falla en `index.html` por el hash CRLF (Hallazgo M1).
7. **Observación visual Desktop/Mobile (Referencia vs Candidato), flujo de pedido y controles — PASS WITH LIMITS**:
   - **Píxeles inspeccionados personalmente**: Se revisaron `reference/reference-desktop-clear.png`, `reference/reference-mobile.png`, `primary/screenshots/before-{desktop,mobile}-home.png`, `primary/screenshots/after-{desktop,mobile}-{home,catalog,order,frame-2s}.png` y `{desktop,mobile}-{home,bag}.png`.
   - **Observación visual**: La transición desde `before` (fondo marrón oscuro de Denis `"Una entrada inolvidable."`) hacia `after` reproduce la estética de Jason (header negro `Martha Silva`, carrusel hero a doble columna en desktop y columna única en móvil con `"Noche de gala"`, `"Champagne"`, `"Novias"`, CTA blanco `"COMPRAR AHORA"`, barras de progreso y botón de pausa) usando las fotografías de Denis. Las vistas de catálogo, mini-bag y pedido aprobado (`PEDIDO DEMO-0001`, `Vestido dorado con drapeado`, `USD 185.00` + `USD 5.00` = `USD 190.00`) no presentan desbordamiento ni imágenes rotas.
   - **Controles interactivos y accesibilidad en `src/app.js`**:
     - `heroCarousel()` (`src/app.js:644-665`): inicia pausado si `matchMedia('(prefers-reduced-motion: reduce)').matches`; aplica `inert` a diapositivas inactivas (`s.inert = k !== i`); alterna `aria-current` en `.ho-dots button` y `aria-label` (`Pausar`/`Reproducir`) en `[data-hero-pause]`; soporta `ArrowLeft`/`ArrowRight`, pausa en `:focus-visible` o fuera de viewport (`IntersectionObserver`), drag táctil/puntero y limpieza con `AbortSignal`.
     - `card(p)` y quick-size-add (`src/app.js:346-352, 717-718`): escapa interpolaciones con `esc()`, actualiza `aria-expanded` en `[data-quick]`, enfoca el primer `[data-quick-size]:not(:disabled)`, etiqueta tallas agotadas (`aria-label="Talla X agotada"`) y abre `miniBag()` tras agregar.
8. **Manifiesto exacto de fuentes, evidencias y rutas cambiadas; sin despliegue — PASS**:
   Los 27 `lfSha256` en `REVIEW-CANDIDATE.json` coinciden al 100% con los blobs de Git en `HEAD` y el disco LF. Los 29 artefactos en `primary/ARTIFACTS.json` coinciden al 100%. `CANDIDATE.json` e `IMPORT.json` históricos se preservan intactos. Sin despliegue.

---

## 5. Evaluación de Hardening y Corrección LF

- **Dependencias**: `package.json` y `package-lock.json` fijan `wrangler@4.158.0` y `undici@7.30.1`. `primary/dependencies.json` registra `0` vulnerabilidades en `npm audit` al momento de ejecución.
- **Cabeceras (`_headers` y Wrangler local)**: `build-inputs/static/_headers` aplica `Content-Security-Policy` (`default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'self'`), `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `X-Robots-Tag: noindex, nofollow` en `/*` y `Cache-Control: no-store` en `/deployment.json`. `primary/wrangler-runtime.json` demuestra las 27 respuestas locales (positiva, negativa sin `_headers` y restaurada) y cierre de procesos. `style-src 'unsafe-inline'` es requerido por variables CSS dinámicas (`--i`, `--dur`, `--drag`, `--store-chrome-height`). Esto valida la configuración local de Wrangler, no un despliegue real en Cloudflare.
- **Corrección LF**: En `HEAD` (`a77f705`), los blobs de Git de `app.js`, `index.html` y `locale-en.js` son 100% idénticos a los de `8523523`, y las 1,559 entradas de `responsive-runtime-sha256.json` coinciden con los blobs LF en Git. Quedan pendientes **M1** y **M2**.

---

## 6. Comprobaciones Verificadas Personalmente / Personally Verified Checks

| Comprobación | Comando / Método | Resultado |
| --- | --- | --- |
| `git HEAD` y estado limpio | `git rev-parse HEAD; git status --short` | `a77f705a6fd6a2778e4112c21aaa72ab8e478015`, limpio |
| 27 bindings de `REVIEW-CANDIDATE.json` vs Git y disco LF | Script Python (`sha256` + `git show HEAD:<path>`) | 27/27 coinciden (`0` errores) |
| 8 archivos en `reference/IMPORT.json` (incl. JSON wrappers) | Script Python (`sha256` + `json.loads`) | 8/8 coinciden (`0` errores) |
| 29 artefactos en `primary/ARTIFACTS.json` | Script Python (`sha256`) | 29/29 coinciden (`0` errores) |
| 624 imágenes Denis (156 PNG + 468 WebP) y 17 fuentes | Script Python vs `media-hashes.json` y `font-hashes.json` | 624/624 y 17/17 coinciden (`0` errores) |
| Paridad blobs Git `8523523` vs `a77f705` (`app.js`, `index.html`, `locale-en.js`) | Script Python (`git show`) | 100% idénticos en Git |
| 1,559 entradas de `responsive-runtime-sha256.json` vs `dist/` | Script Python (`sha256`) | 1,559/1,559 coinciden en LF; `_headers` difiere en RAW Windows (M2) |
| Regresión de snapshot y guarda CRLF | `python tests/test_release_snapshot.py` | `Ran 1 test in 15.396s - OK` (exit 0) |
| Regresión estática de `_headers` | `python tests/static_headers.py` | `Ran 2 tests in 0.001s - OK` (exit 0) |
| Verificador directo de snapshot en worktree Windows | `python tools/verify_release_snapshot.py` | **FAIL** (exit 1): CRLF en `dist/_headers` (Hallazgo M2) |
| Regresión de imágenes responsivas | `python tests/responsive_images.py` | **FAIL** (exit 1): `index.html` LF `35a84951...` != CRLF `008e96af...` (Hallazgo M1) |
| Inspección visual de píxeles (Referencia, Before, After, 2s frames, Bag) | `view_file` en 14 imágenes PNG | Layout de Jason con imágenes de Denis confirmado visualmente |

*(Nota: `node --test tests/luxury-editorial.cjs` requiere `tests/frontend-deps/node_modules/jsdom`, ausente en este worktree sin nuevas instalaciones permitidas; fue verificado por inspección de código y diff).*

---

## 7. Límites de Evidencia / Evidence Limitations

1. **Linux CI**: El run `42170897865` sobre `a77f705` estaba `in_progress` en la lectura del primario y fallará en su segundo job (`historical-regressions`) debido al **Hallazgo M1**.
2. **Navegador local y muestreo**: Evidencia de Playwright grabada sobre `8523523` contra servidor local/sintético; videos muestreados en `t = 2s`. No prueba pagos reales, persistencia backend ni dispositivos físicos.
3. **Reglas globales**: `C:/Users/Jason/AI-OS/rules/{orchestration.md,PROTOCOL.md,OUTPUT.md}` inaccesibles desde el sandbox del worktree.

---

## 8. Ruta del Reporte y Siguiente Acción del Primario

- **Archivo escrito**: `docs/hardening-20261106/combined/gemini-critic.md` (hash SHA-256 reportado en la entrega al primario).
- **Siguiente acción del primario**:
  1. En `tests/responsive_images.py:26`, actualizar el hash esperado de `'index.html'` en `selected_layouts` a `'35a8495127d2da4ce6061e77092fb46682e5a7c5d34ec5c88f2646985f3db1f5'` (LF) y verificar `python tests/responsive_images.py` (Hallazgo M1).
  2. Añadir `build-inputs/static/_headers text eol=lf` y `dist/_headers text eol=lf` en `.gitattributes`, e incluir `_headers` (`rel in controls`) en la guarda CRLF de `tools/verify_release_snapshot.py:40-41` y `tests/test_release_snapshot.py:46` (Hallazgo M2).
  3. Actualizar `REVIEW-CANDIDATE.json`, publicar en `Tony`, confirmar ambos jobs verdes en Linux CI sobre el nuevo SHA y proceder con re-verificación / Astra.
