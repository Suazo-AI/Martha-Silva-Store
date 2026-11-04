# Estado vigente de Martha Silva / SAVIA

Corte: 2026-11-03. Host de la validación: SUAZO-PC. Checkout canónico `github`, rama `Tony`.
**No listo para producción. Siguiente incremento: venta segura por cajero, empezando por N5.**

> **Actualización 2026-11-03, rama `claude/funny-brahmagupta-5e5rj0` (PR de integración):** N5 corregido con
> rojo-verde-revert en navegador real (arnés 36/36, personal 42/42); backend 592/592 contra SQL Server real,
> incluidos release y restart en Linux; CI `savia.yml` para el PR. Detalle, límites y comandos:
> [sprint-20261104](sprint-20261104/README.md). Reparto C1–C12: https://trello.com/b/pq9G9Qqj/martha-silva
> **Actualización 2026-11-04:** C3 cerrada por Jason; C4 (script de release completo), C5 (arnés API real + SQL)
> y C7 (N1, N3, N4, N8, N9 con cero escrituras) en verde en CI con mínimo de 599 casos. El estado vivo está en
> [ledger.json](pipeline/ledger.json) y se publica solo en cada push y PR ([pipeline](pipeline/README.md)).
Para continuar: [AGENT-START](AGENT-START.md), [mapa de fuentes](CODE-MAP.md), [decisiones](DECISIONS.md).

| Área | Evidencia verificada | Pendiente / límite |
| --- | --- | --- |
| Código del candidato | Diez archivos locales de producto/pruebas coinciden byte por byte con el candidato probado; [vinculación](reconciliation-20261103/source-binding.json) | Publicar código no corrige N5 ni cambia aceptación |
| Backend | 590 casos únicos PASS, 0 FAIL, 2 NOT RUN: 523 offline + 67 SQL reales | Dos casos de release/recuperación sin ejecutar |
| Staff JS | 42/42 PASS | Dobles de transporte/DOM |
| Navegador Chrome | 31/32 escenarios PASS; 47 páginas públicas montan sin errores JS no capturados | N5 FAIL; no Safari/iPhone físico ni auditoría completa de accesibilidad/rendimiento |
| HTTP real | 4/4 guardas PASS con API propia y SQL deliberadamente inaccesible | No es browser → API → SQL completo |
| SQL del lote reciente | 21 casos Store migrados + 46 internos EnsureCreated; 52 bases antes/después, cero nuevas restantes | No valida migración Internal de release; no se modifica SQL en esta sincronización |
| Operación histórica, 31 octubre | 13/22 criterios PASS, 9 NOT RUN; UI crítica 5/5; venta Owner, recuperación y persistencia | Corte histórico; no acepta automáticamente el código actual ni prueba uptime presente |
| Tienda pública | Snapshot histórico `601268a3`, 1081 archivos públicos, 47 páginas, 40 productos, 120 variantes | Demo; precios/stock/pedidos no son autoridad comercial; tarjetas pendientes |
| Regresiones heredadas | Desktop 1/14, Green 4/6, luxury 4/8 en el lote reciente | 19 casos fallidos necesitan reproducir y resolver contrato frente a producto |
| Auditorías Windows | Assets: 3 errores symlink; staging: 2 errores symlink; deployment: 13 PASS y 1 SKIP | `WinError 1314`; completar casos en Linux autorizado, sin relajar guardas |
| Medios y diseño | Recuperación 777/778; 156 PNG generados en 158 ubicaciones, según entrega histórica | No Full HD; referencias incompletas; no aceptación visual de Jason ni entrega CUTUFAY verificada |
| Navegación para agentes | AGENT-START, CODE-MAP, DATABASE y decisiones reconciliados | Graphify bloqueado por Application Control; no existe grafo canónico vigente |

Fuente de resultados: [validación 2026-11-03](testing-20261103/README.md).
La [reconciliación](reconciliation-20261103/README.md) conserva procedencia y exclusiones públicas.
Los porcentajes de matrices históricas no se suman con pruebas unitarias o escenarios de navegador.
La vinculación registra hashes locales y blobs publicados: Git solo normaliza saltos de línea en los diez archivos.

## Siguiente acción y aceptación

Corregir la recuperación de un recibo confirmado inexistente sin fabricar una venta pendiente.
Reproducir `Stale confirmed receipt`; conservar bloqueos de operaciones realmente pendientes y sesiones revocadas.
Después preparar el [incremento N1–N10](delivery-20261031/NEXT-INCREMENT.md) en entorno SQL aislado autorizado:
una venta, precio del servidor, un movimiento de stock, recibo tras recargar y recuperación sin duplicados.

Producción requiere además resolver pruebas heredadas, migraciones/recuperación, permisos/sesiones/sucursal,
dispositivos y aceptación del negocio. La tienda pública requiere su integración de pagos y autoridad comercial.
No ampliar pantallas ni infraestructura de agentes para evitar este camino crítico.

## Publicación y antecedentes

El commit que contiene esta reconciliación y su recibo en [progress](progress/) identifica los bytes publicados.
Comprobar SHA remoto y CI de ese SHA mediante [AUTO-SYNC](AUTO-SYNC.md); un resultado anterior no cubre el nuevo commit.
No se despliega, ejecuta SQL, inicia Docker, cambia certificados ni reinicia servicios en esta tarea.
[SAVIA-LATEST](SAVIA-LATEST.md), [cronología](UPDATE-HISTORY.md) y los documentos fechados conservan antecedentes.
La URL de producción para SEO sigue sin confirmarse; la observación anterior de `noindex,nofollow`
en la demo alternativa no se volvió a consultar aquí ni autoriza cambiar la indexación.


## Candidato de correcciones de Tony — 2026-11-04

Preparado sobre PR #2 `88faa2dd0d51fc1c5089b721ba5b17c23d4d61d4`: coherencia del digest, bitácora por evento y publicación de evidencia/limpieza incierta del arnés. Véase [informe](sprint-20261104/TONY-PR2-FIXES.md). Las 41 pruebas unitarias ligeras pasan; no se ejecutó aquí SQL, API, navegador ni compilación. Integración canónica, SHA remoto y CI del candidato pendientes. Esto no aprueba ni fusiona el PR y no cierra C1/C3/C6/C9/C11.

## Integración canónica de FIX-PR2-DENIS-20261104

El parche de 13 archivos está aplicado y cotejado contra sus blobs Git.
Digest 24/24, seguridad 17/17 e importador 22/22 PASS en SUAZO-PC.
Build Release con SDK10.0.402 PASS; backend local 524 PASS,75 SKIP,0 FAIL.
La importación histórica fija16 SHA y conserva recibos obligatorios para commits nuevos.
El CLI real de evidencia pasó6 escenarios; cleanup pasó8 escenarios de shell con Docker simulado.
Los cinco errores Windows de symlinks se conservan como limitación de verificación.
El código inicial quedó SYNCED como `ca917005c331e8096e84d21bc1b35cb71a1700d5` en Tony y PR2.
API/SQL real pasó 19/19; backend SQL pasó 599/599 sin SKIP e incluyó reinicio.
Publicación de evidencia y readback de retirada pasaron. Linux cubrió los symlinks.
Los digest de push fallaron por flags incompatibles de gh; el seguimiento reconcilia
la corrección vigente en main y agrega pipefail. Falta confirmar CI de ese nuevo SHA.
Los siete `TONY-*` permanecen en `review`.
Véanse [resultados, límites y siguientes acciones](fix-pr2-denis-20261104/README.md).

La divergencia entre Tony `95120c29` y PR2 `9719d8ed` está auditada.
Jason autorizó una unión puntual de historiales y ampliar el importador solo a
`9719d8ed`, para 17 SHA exactos. El manifiesto original de 16 permanece intacto.
Se conservan el workflow de Tony y los avances de ambos; no se fusiona PR2 a main.
Faltan el SHA común publicado, SYNCED y CI completo del mismo SHA.

La reconciliación quedó publicada como `260b75951729189d987ffe423218ab1643bcfa3c`:
Tony y PR2 coinciden, SYNCED, nueve workflows success en el mismo head.
Artefactos frescos: Golden19/19, backend599/599 sin SKIP, reinicio1/1 y retirada
con readback de ausencia de los dos contenedores. El merge ref probado tiene
un árbol idéntico al candidato. Los siete TONY-* siguen review.
El informe final debe conservar su propio SHA/CI; véase
[CI saneado](fix-pr2-denis-20261104/ci-reconciled.json).

## Continuación C6, C8 y C9 — 2026-11-03 local / 2026-11-04 UTC

El CI inicial de PR2 en `260b759` tenía 12 PASS, 0 FAIL y 3 SKIP configurados.
FIX-PR2 publicó su cierre en `9b35697`; se verificaron SYNCED y ambas ramas antes de tomar Tony.
Se conservan ese commit y las carpetas ajenas sin seguimiento.

C6 añade Chrome contra API HTTPS y SQL real, con oráculos antes de permitir cada checkpoint siguiente.
La pérdida de respuesta se inyecta después de recibir el HTTP 200 real de una venta comprometida.
La recuperación exige la misma clave y recibo, cero POST adicionales y stock 27 desde 30 tras las dos ventas.
Las 29/29 comprobaciones ligeras pasan; **corrida real y revisión independiente pendientes**.
El workflow conserva el smoke C5 y publica solo evidencia saneada.
Véase [informe C6](c6-e2e-20261103/README.md).

C8 conserva su ejecutor y evidencia local; su parche todavía requiere integración y CI del candidato.
C9 terminó la [preparación documental](c9-recovery-20261103/PREPARATION.md), con cero SQL/API/Docker nuevos.
Faltan preflight autorizado, rutas/permisos/TLS actuales, oráculos en restaurada y RTO/RPO medidos en SUAZO-PC.
El backup/restore Linux ya existente no cierra esa brecha. No se repiten one-shots históricos.
No se fusiona a main, despliega ni cambia seguridad.

### Resultado del primer CI C6 e integración C8

El candidato `6aeb9a35f45331ace85ac48dc19bfd9264b0f722` quedó publicado y SYNCED en Tony y PR2.
El [CI 41757409404](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41757409404) pasó C5 smoke.
C6 tuvo 20 pasos PASS y 1 FAIL: completó venta, descarte de respuesta después del commit,
recuperación GET con clave original y recarga repetida contra Chrome/API/SQL reales.
SQL observó 2 ventas, 2 líneas, 2 operaciones de venta, 2 movimientos de venta y stock 27.
Falló `browser.logout` a los 20126 ms; teardown de API/base/directorio y retirada del contenedor PASS.
El juez independiente confirmó la evidencia de negocio y pidió readback explícito de ausencia de Chrome/Node.
La corrección y un nuevo CI son obligatorios antes de cerrar C6.
La [evidencia inicial](c6-e2e-20261103/ci-41757409404/run-binding.json) conserva ese fallo.

Se importaron los seis archivos C8 del patch `a0762dc021260f4c8c88b849552c4775c6bef17af06c5338e68e95cd7a221df0`.
Los seis blobs Git coinciden con la entrega probada; se reutilizan 45/45 browser, 45/45 staff,
9/9 enfocados y 49/49 seguridad, incluido 1/1 de expiración absoluta con reloj falso en TestServer.
No se repitieron esas pruebas locales. Se elevó el mínimo CI backend de 599 a 600 por el nuevo Fact.
Falta CI del candidato integrado; véase [integración C8](c8-ui-20261103/INTEGRATION.md).

Se conservan los documentos y evidencia saneada entregados por los agentes existentes.
La [revisión técnica C4/C5/C7](technical-ready-review-20261104/primary-review.md) conserva C4 5/5 y C5 4/4,
con READY formal de Jason pendiente. C7 tiene 5/6: el 409 registra una Operations durable;
el ledger refleja blocked hasta resolver expresamente el criterio literal de cero escrituras.
No se alteró ese criterio ni el comportamiento para aprobarlo.
C9 sigue preparada y bloqueada según su informe. Trello C6/C9 tiene comentarios con readback exacto.

El delta C6 posterior quedó importado: logout espera204 y verifica URL/login/401;
la retirada registra Chrome por CDP y exige ausencia de grupos propios Node/Chrome.
Sus33/33 comprobaciones ligeras pasan; falta repetir el CI real y reevaluar el dictamen.
El hook bloqueó dos TRX saneados por extensión: se excluyeron del índice sin cambiar la política.
Se conservan sus originales, hashes y resultados JSON. El candidato combinará C8 y la corrección C6.
El [preflight propuesto C9](c9-recovery-20261103/PREFLIGHT-SCOPE.md) concreta lecturas y límites;
no está autorizado ni ejecutado.
