# Estado del proyecto

## Rama privada SAVIA — 2026-10-25

Esta rama desarrolla el sistema interno, separado de la tienda. Se incorporó
el delta privado de 57 archivos contra la base real f7, con hashes comprobados
y sin sobrescribir la UI: auth/roles, directorio, comercio, abastecimiento,
runner y migración de desarrollo. [Alcance privado](../SAVIA-INTERNAL.md).

El primer corte de fuentes UI está en `3d8f11deec4a4a2ab8d5d6f9ef3a8176d8baa2d4`:
ingreso/sesión y consultas de clientes/artículos contra el contrato privado.
Cutufay reportó nueve pruebas auth y cinco DOM PASS sobre el paquete exacto
`1d14ad33…`; son dobles y jsdom, sin SQL real ni navegador.
[Evidencia inicial](../evidence/savia-internal/ui-auth-read-cloud-2026-10-25.json).
El corte paginado posterior `41c66e52…` recibió 20 PASS. El juez repitió restore,
Release y suite C# tras integrar esa UI: 435 PASS, 56 SQL omitidas, cero fallos
y cero advertencias/errores. Son pruebas de código; SQL y operación real siguen
pendientes. CRUD y los flujos de venta/compra de la UI permanecen apagados.

No hay hosting interno configurado, base conectada, push o CI nuevos acreditados.
El candidato de pruebas debe ser gratis y sin tarjeta; véase
[alojamiento](savia-internal/FREE-HOSTING.md). Las secciones de publicación que
siguen pertenecen a la tienda histórica, no son una entrega de SAVIA.

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
