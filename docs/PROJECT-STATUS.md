# Estado del proyecto

## Product sharing - 2026-10-25

Published source `e9e9609b9cda6f52abd0db1b35b570f3b83156b4` adds a sharing
button to all 40 product pages. Native sharing preserves click activation;
cancellation is quiet. Copy success is reported only after clipboard write;
permission failures expose a selected manual link. Product URLs preserve ES/EN
and exclude unrelated query parameters. Sharing remains available if the demo
commerce adapter is unavailable.

Cloud checks passed: 139 existing cases and 11 focused sharing cases, plus
reproducible 902-file assembly and 47-page structure validation. Only app.js,
locale-en.js and styles.css changed; all 780 raster files and index.html are
unchanged. No heavy work ran on Tony. Post-publication browser coverage is
recorded separately in evidence/product-share/publication.json.

Cloudflare version `205cf823-313b-4667-8779-b08957424bd5` serves 100% of traffic,
deployment `2172a1c0-e350-4ef7-b9fc-d0c567941669`. The photo-quality candidate
remains separate and unpublished; the audit resumes after sharing verification.
No GitHub push or hosted CI occurred.

## Luxury Instagram editorial - 2026-10-25

Published runtime source `8ef27660bb94acc5d93f09d59b92cbbc8661e94e` replaces
the opening gold photograph with Martha Silva's silver gown and pink/purple
supporting portraits. A six-photo Instagram editorial uses an espresso, ivory
and champagne palette. All 44 responsive JPEG/WebP derivatives preserve the
source frame and proportions; original photographs and provenance are retained.
The 40-product catalog, 120 variants, 170 gallery positions and prior bounded
bridal section remain unchanged. New copy and alternative text support ES/EN.

Cutufay built and tested in cloud Linux after Denis explicitly confirmed cloud.
Three lightweight local agents and six initial cloud agents split implementation,
media, localization and review; no laptop builds, image conversion or browser QA
ran. The local memory admission rejected heavy work at 817 MB available and
88% committed. Existing binary transfer used uncompressed archives and bounded
256 KiB buffers; all 784 supplied files and 13 reused binaries matched baseline.

All 161 automated cases passed without failure/skip: 139 existing runner cases,
14 offline deployment cases and eight focused editorial cases. All 902 runtime
records match the cloud output manifest; 855 baseline files are unchanged.
The historical completion gate still fails as expected at 777/778.

Actual CUA desktop preview review at DOM 1180x757 confirmed ES/EN hero, complete
photos, fonts, focus and six-photo gallery. Hero JPEG exports are 1165x747; the
gallery section capture is 1180x1751, not a mobile viewport. No mobile/Safari or
performance claim is made. The normal terminal HTTP client received 403 and
stopped; independent binary-body HTTP hashes are not claimed.

Cloudflare activated version `61c2f526-5315-4c55-9656-8cc148b1eea1` at 100%,
traffic deployment `80a86895-4d5a-4536-994c-98a0e0b8a319`. The temporary QA
path is omitted from the final 903-entry asset manifest and version preview
routing remains disabled. Final main-URL desktop verification passed in ES/EN: marker source8ef/902,
nine images decoded, fonts loaded and zero horizontal overflow. The owned tab
was closed; no local server remained.
No GitHub push or hosted CI run occurred. Source and evidence:
`../evidence/luxury/publication.json` and `../evidence/luxury/final-summary.json`.

## Published bridal photography and English — 2026-10-25

The `fix/bridal-photos-bilingual-20261025` branch updates the current public
storefront: a bounded bridal portrait beside its copy, truthful intrinsic
dimensions across all 47 HTML pages, proportional shopping photos and an
English/Spanish switch covering all 40 products and dynamic shopping UI.
Photographic bytes, product identifiers, prices and sample inventory are unchanged.
Spanish remains the default; `?lang=en` selects English and `?lang=es` selects
Spanish explicitly, including when browser storage cannot be updated.

Image inspection in this change reads 737 file headers, not a new visual review.
Seventeen serial localization DOM checks were added to the existing runner.
Local heavy work was refused by `mantenimiento/Run-SequentialHeavyTask.ps1`:
available RAM was below 1,536 MB and memory commitment exceeded 75%.
Cutufay coordinated six cloud subagents in Slack thread `1792971699.179229`.
Source `b248b925d5d61a49124e10b0244362ae558c852d` passed all 153 automated
cases: the complete runner, 17 localization cases and 14 offline deployment
cases, with zero failures/skips. All 107 source hashes and 858 runtime outputs
matched before/after. Live cloud HTTP checks passed the 858-entry marker,
14 sampled bodies and three missing-route checks.

Desktop browser review confirmed the 420×560 bridal portrait with contain fit,
English/Spanish navigation, search/filter/history, favorites, cart changes,
empty-bag navigation, checkout validation and gallery/zoom. It found a hardcoded
CSS search caption; final source `67d4647d5ee65c65dd037d2e664fcdc45c7009d6`
changes only that CSS value. Its prepare/reproducible-build/structure checks
passed; the other 857 outputs, including all JavaScript/HTML/tests, are identical.
Cloudflare activated version `eb917441-e2f6-443d-acf3-56d94837edb8` at 100%.
Final live browser verification passed: English displays Search in the visible
caption and accessible label; switching to Spanish displays Buscar. The bridal
portrait remains centered at 420×560 with contain fit. The final public marker
matches all 858 hashes and the CSS body matches its cloud-verified SHA-256.

Browser coverage is desktop 1188×761; no mobile/Safari/performance claim is made.
Laptop PowerShell/curl public HTTP checks timed out; cloud checks are recorded
separately. Media bytes remain unchanged and the historical 777/778 limitation
remains. No GitHub push or hosted CI run was performed. Full provenance and
verification are in `../evidence/bridal-bilingual/publication.json`.

## Previous storefront publication: public store and private SAVIA

Tienda principal publicada en source`d2ad2000c68c492618c15f5a601cca9a47e8a587`, deployment`8e298940246a49be9b55dcf8ee422983`. MainHTTP200; marcador856entradas y8cuerpos porhash comprobados. `/savia`, `/savia/`, `/savia/index.html` y `/savia/app.mjs` devuelven404; sin enlace a la caja descartada. Brave existente verificado y recargado. OriginalCloudflare conserva200 ySHA c5d028. Evidencia: `../evidence/cloudflare-storefront-only-2026-10-25.json`.

SAVIA sera exclusivamente interno para staff/duenos: CRM/admin/ventas/inventario/abastecimiento, con auth y permisos de servidor. Reuso: basef7 de reservas/inventario,45fuentes verificadas entregadas aCutufaycloud; noCRMterminado, noSQLreal ni nueva API publica afirmados. Los informes de la caja publica8c01f99 a continuacion son historicos de una implementacion retirada. NoGitHubpush ni CI nuevos.

## Correccion de alcance: una sola interfaz

Instruccion directa: conservar la URL principal y optimizar esa tienda para SAVIA; retirar la caja separada /savia/ y su enlace. No cambia el original Cloudflare. El prototipo queda fuera del build y su empaquetador se deshabilita. Los reportes de la publicacion8c01f99 se conservan como historicos. La retirada remota debe acreditarse con marker y HTTP404 para /savia/. No se afirma conexion real .NET/SQL.


## Publicacion SAVIA y frontend 2026-10-25

Fuente publicada `8c01f99fa325d8a5bde6fddfffdade4f527e91d3`, deployment `086e4da4c4504497a66ae6e93b08df17`, Worker `martha-silva-preview`. Tienda y `/savia/` responden HTTP200; marcador861entradas y13cuerpos comprobados por SHA256. El original conserva HTTP200 y el mismo SHA antes/despues.

Validacion final cloud:29DOM tienda PASS; SAVIA8API+9DOM PASS y12modelo previos con hashes identicos. jsdom no equivale a navegador/SQL. QA publica Chrome cloud en cierre; no Safari/iPhone. Full suite final aplazada por memoria; no se declara PASS total ni CI remota. Backend/SQL real no conectado (rutas404 en preview); solo caja ficticia separada y diagnostico GET. La foto de portada conserva referencias de7f29cf5; reemplazo solicitado pendiente de seleccion. No push a GitHub: Denis/Tony es el destino humano solicitado y Suazo-AI no fue usado como sustituto.

Evidencia: `../evidence/cloudflare-savia-deployment-2026-10-25.json`, `../evidence/cloudflare-savia-public-smoke-2026-10-25.json`, `../evidence/frontend-image-review/cloud-storefront-final-results.json`, `../dev/savia-demo-ui/evidence/cloud-savia-final-results.json`. Los estados previos a continuacion son cortes historicos.


## Frontend e imágenes — trabajo local del 25 de octubre de 2026

La rama `fix/frontend-image-review-20261025` contiene la revisión de imágenes y
usabilidad, separada de los worktrees activos de ERP. El destino solicitado
para el código es la cuenta de GitHub de **Denis**; el usuario confirmó que
**Tony y Denis son la misma persona**. Ese alias no determina un login de GitHub.
La conexión verificada sigue siendo `Suazo-AI`; todavía no se verificó el
repositorio de Denis ni se hizo push de esta rama. La web publicada y el estado
local deben seguir identificándose por sus commits concretos.

## Integración de la copia pública — 2026-10-25 UTC

**Publicado y verificado:** [nuevo Worker](https://martha-silva-preview.martha-silva-denis.workers.dev/),
commit de código `7f29cf5a75db60c93b3bb3efa89c7e33d9e02a79`,
deployment `faf7f80497c04932b50c8af836ee8c8c`. API HTTP 200, binding único `ASSETS`;
smoke público por cliente normal PowerShell: marcador completo de 856 archivos,
15 hashes de recursos y ruta inexistente 404 PASS. El navegador cloud de
Cutufay abrió el sitio sin 403. Python urllib recibió403 y se detuvo sin
reintento; no se oculta ese límite de cliente. La portada original sigue HTTP 200
con el mismo SHA-256 de la captura inicial. No hubo push ni CI nueva.

QA local: 55 pruebas Node, 22 DOM y 47 páginas estructurales PASS. El agregado
Windows conserva salida 1 por Win1314; Linux focal 13 PASS sin skips cubre los
casos de symlink. Navegador: 99 verificaciones amplias más siete focales después
del ajuste final de hover, con hashes y alcance separados. Ver
[evidencia QA](../evidence/original-preview/README.md) y
[registro de despliegue](../evidence/cloudflare-preview-deployment-2026-10-25.json).

La rama `feat/original-storefront-preview`, basada en `761559ad9b0cc6b7ac4c218029ce144791310172`, integra 47 páginas y el catálogo de muestra público de 40 productos, 120 variantes y 170 posiciones de galería. Preserva el hero fotográfico, los modos locales SAVIA/SISFAIN, los seis grupos `sample_image=true` y las regresiones del catálogo anterior. No habilita el transporte ni el Worker históricos.

El origen público autorizado permitió recuperar 840 de 841 archivos: 47 HTML, ocho recursos CSS/JS, ocho fuentes y 777 medios, con tamaños y SHA-256 verificados. Falta únicamente `/research/assets/martha-gala/f1bf4e3664d34cd4.jpg` (HTTP 404), que no usa la galería actual. La cobertura histórica sigue incompleta: `--require-complete` debe fallar 777/778. Los informes anteriores de dos productos y del equipo desconectado corresponden al snapshot base, no a esta captura.

El usuario autorizó expresamente publicar una copia separada en su cuenta Cloudflare conectada. Destino único: `martha-silva-preview`; el original `martha-silva-demo.jason-suazof.workers.dev` queda intacto. El acceso de escritura y la URL deben acreditarse al publicar; no se solicitan roles Admin amplios ni se activa CD por inferencia. Los resultados finales de build, pruebas, navegador y publicación se registrarán en evidencia separada vinculada al artefacto.

## Snapshot base histórico — 2026-10-24

Las tablas y bloqueos que siguen documentan el snapshot base anterior a la captura pública descrita arriba; no son el estado de la rama ampliada. El estado de remoto, CI y despliegues debe verificarse para el commit concreto de cada entrega.

## Qué existe y qué falta

| Área | Evidencia / estado | Siguiente condición verificable |
| --- | --- | --- |
| Demo mejorada local | 9 páginas, 2 productos, 6 variantes; `dist/` reproducible | Suite del commit integrado y revisión real en navegador |
| Original | Metadatos: 40 productos, 120 variantes, 170 referencias de galería | Recuperar medios aprobados y contrastar mapeo visual |
| Fotografías | 11 medios locales; 0/170 rutas JPEG primarias exactas del original; véase auditoría | Fuente original accesible, transferencia permitida y hashes verificados |
| Build | `prepare.py`, entradas versionadas y prueba de equivalencia | Mantener salida determinista al cambiar entradas |
| QA | Suite integrada: 23 adaptador local, 9 migración, 11 DOM, 3 auditoría, 5 runner y 7 staging; 9 páginas estructurales | Ubuntu y Windows PASS en `f22276a`, Actions [`40136425925`](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/40136425925); navegador real pendiente |
| Pagos | Investigación estática REA; ningún proveedor elegido ni integración implementada | Elegibilidad comercial, decisión y pruebas sandbox con backend |
| SISFAIN | No se ha encontrado backend en el material recuperado | Obtener contrato/API y acceso autorizado, si se requiere integrar |
| Producción | No preparada | Completar criterios separados de producción |

**Bloqueo de copia completa:** el equipo original está desconectado y faltan bytes de medios. Acción necesaria: hacer accesible la fuente autorizada y transferir solo los archivos permitidos a staging privado según [ASSET-COMPLETENESS](ASSET-COMPLETENESS.md). Tener el catálogo o conservar un Worker no resuelve ese bloqueo.

Los recuentos de referencias no equivalen a fotografías únicas; las 778 rutas del manifiesto incluyen derivados y vídeos. El demo sí tiene imágenes utilizables de sus dos productos, aunque no coincidan con las rutas JPEG originales.

## Criterios de aceptación

### A. Repositorio de demos recuperado

- [ ] Fuentes, salidas y material histórico diferenciados; historia Git preservada.
- [ ] Checkout limpio construye y repite salida idéntica; suite completa pasa en el commit de entrega.
- [ ] Inventario de medios y limitaciones documentados; ningún secreto o dato privado incorporado.
- [ ] SHA del commit confirmado en el remoto autorizado; CI revisada o ausencia de CI declarada.
- [ ] README permite ejecutar sin acceso al equipo original; enlaces internos revisados.

Son condiciones de aceptación, no una declaración de que esta edición documental las haya ejecutado.

### B. Copia completa del original

- [ ] Catálogo y variantes reconciliados con la fuente, sin inventar existencias.
- [ ] Todas las referencias requeridas disponibles; hashes y revisión visual del mapeo producto/medio.
- [ ] Pruebas de navegación y flujos en navegador real, escritorio y móvil; evidencia vinculada al commit.
- [ ] Diferencias deliberadas registradas y aprobadas. Original en vivo intacto.

### C. Tienda de producción

- [ ] **Pago con tarjeta obligatorio**: proveedor elegido con elegibilidad confirmada; sandbox y proceso de paso a producción revisados.
- [ ] Backend autoritativo para precios, stock, pedidos y pagos; autorización, sesiones y administración reales.
- [ ] Webhooks verificados, idempotencia, rechazo/cancelación, reintentos, devolución y reconciliación probados.
- [ ] Nunca guardar PAN/CVV en frontend, logs o repositorio; revisar obligaciones aplicables antes del lanzamiento.
- [ ] Integración SISFAIN solo con interfaz y alcance comprobados; no afirmar compatibilidad sin pruebas.
- [ ] QA real, accesibilidad, seguridad, recuperación, observabilidad y rollback documentados.
- [ ] Publicación expresamente autorizada y verificada en el destino correcto.

## Orden de trabajo

El [roadmap V1 propuesto](ROADMAP-V1.md) prioriza una venta autoritativa y recuperable, no la recuperación exhaustiva ni nuevas herramientas. Está pendiente de aprobación del propietario antes de implementación.

1. Acordar alcance/contratos y autoridad de stock; iniciar afiliación de tarjeta y catálogo piloto en paralelo.
2. Construir el corte frontend → API .NET → SQL: pedido, reserva y operación, primero con fixtures identificadas.
3. Integrar proveedor real en sandbox y cerrar staging, QA real, seguridad y recuperación.
4. Aceptación del negocio y piloto productivo específicamente autorizados.

La recuperación completa del catálogo y no-mistakes no bloquean ese piloto por sí mismos. La ausencia de una fuente única para stock compartido con ventas físicas sí bloquea ventas reales.

[Inicio](../README.md) · [Procedimientos](PLAYBOOK.md) · [Decisiones](DECISIONS.md)

## Evidencia de CI y límite de autorización

Actions run [`40136425925`](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/40136425925), commit `f22276a`: Ubuntu y Windows **PASS**, artefacto
**PASS**, despliegue **SKIPPED**. La evidencia corresponde a ese commit, no a
cambios posteriores. El acceso Cloudflare comprobado sigue siendo de solo lectura;
`gh` CLI no está autenticado. No hay prueba de publicación nueva.

La autorización persistente es únicamente para el nuevo Worker
`martha-silva-preview`; no autoriza Admin amplio ni modificar el original.
Antes de habilitar CD, una comprobación externa debe confirmar cuenta, Worker,
URL real y alcance del token dedicado. La validación offline de URL no demuestra
que su subdominio pertenezca a `CLOUDFLARE_ACCOUNT_ID`. El control de main es una
salvaguarda no atómica: main puede avanzar después de la lectura.


## Frontend review 2026-10-25 (local candidate)

737 image files were decoded and visually reviewed; media bytes are unchanged. Historical recovery remains incomplete at777/778. Hero viewport sizing and intrinsic zoom were checked in isolated Brave before the final header changes. Final UX fixes cover empty mini-bag checkout, favorite text, sample-stock wording and keyboard focus. The technical storefront selector is hidden while error retry and memory-only warnings remain available.

Final29-case DOM candidate is sent to Cutufay cloud (F0CCSR9L1FA); its local run was interrupted without a result under memory pressure. Earlier26DOM and3+5Brave checks apply only to their recorded hashes. Full final suite is pending; do not relabel an interrupted run as PASS. This branch is not pushed or newly deployed by this record. See evidence/frontend-image-review/review-summary.json.
