# Estado del proyecto

## Bridal photography and English candidate — 2026-10-25

The `fix/bridal-photos-bilingual-20261025` branch updates the current public
storefront: a bounded bridal portrait beside its copy, truthful intrinsic
dimensions across all 47 HTML pages, proportional shopping photos and an
English/Spanish switch covering all 40 products and dynamic shopping UI.
Photographic bytes, product identifiers, prices and sample inventory are unchanged.
Spanish remains the default; `?lang=en` selects the English presentation.

Image inspection in this change reads 737 file headers, not a new visual review.
Thirteen serial localization DOM checks were added to the existing runner.
Local heavy work was refused by `mantenimiento/Run-SequentialHeavyTask.ps1`:
available RAM was below 1,536 MB and memory commitment exceeded 75%.
Cutufay acknowledged independent cloud QA in Slack thread `1792971699.179229`.
Build, automated checks, browser QA and republication are pending for this
candidate; the publication record below remains the last verified live release.
No GitHub push or CI result is claimed for the candidate.

## Estado vigente: tienda publica y SAVIA privado

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
