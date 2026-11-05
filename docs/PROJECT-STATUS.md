# Estado vigente de Martha Silva / SAVIA

Corte operativo: 2026-11-04 UTC. Host coordinador: SUAZO-PC. Checkout canónico `github`, rama `Tony`.
**No listo para producción. C6/C8 y C11 pasan técnicamente; C9 sigue bloqueado por confianza TLS.**

Actualización de alcance, 2026-11-04 America/Managua: Jason exige venta multiartículo
en una factura y sustitución de SISFAIN, no mantenerlo como integración objetivo
([D-023/D-024](DECISIONS.md#d-023--venta-multiartículo-obligatoria)).
El backend admite varias líneas; la UI/cliente actuales limitan a una. Los pagos
internos siguen `not_processed`; la paridad comercial/fiscal no está implementada.
Tres agentes investigaron operación, fiscalidad y migración/calidad. La explicación,
matriz, escenarios ficticios y límites están en
[ensayo sintético](synthetic-replacement-20261104/README.md).
El modelo no prueba SAVIA ni cierra C2/C9/C10. La aceptación sigue a cargo de SUAZO-PC.

Jason designó al coordinador SUAZO-PC como responsable de aceptación por flujo de C10
([D-022](DECISIONS.md#d-022--responsable-de-aceptación-del-ensayo)), en lugar de la propuesta de Martha.
El responsable está decidido; el ensayo y su dictamen no están aceptados anticipadamente.
Jason eligió **SUAZO-PC con datos sintéticos** para el ensayo
([D-025](DECISIONS.md#d-025--equipo-y-datos-del-ensayo)). No fija el montaje productivo.
Martha aporta datos de operación. Siguen pendientes C2/C9 y la ejecución/evidencia de C10.
Jason eligió para el ensayo que la cajera registre la excepción y la encargada revise
después ([D-026](DECISIONS.md#d-026--cajera-registra-la-excepción-encargada-revisa-después)).
Sin ajustes libres de la cajera. Siguiente decisión: momento de revisión y cobertura
cuando falta la encargada; se recomiendan cierre de jornada simulada y suplente ficticio.
La [explicación con situaciones y revisión de crítico/jurado](stock-decision-20261104/README.md)
conserva alternativas y límites. La política está elegida para ensayo; el nuevo flujo
no está implementado, ejecutado ni aceptado. No cierra criterios.

Código aceptado: `53dd23b5cfec2cb5dd717395b9095a71d29669f0`, publicado en Tony y PR #2.
C11/N10: [APTO independiente por capas](c11-next-20261104/final-review.md).
Nuevo N5 HTTP+SQL 1/1, backend 601/601 sin fallos/omitidos; conserva los 600 casos anteriores.
Los rechazos de autorización, alcance y CSRF conservan las 19 tablas. Staff 45/45 y browser con API simulada 45/45.
El [binding exacto](c11-next-20261104/ci-53dd23b5/root-ci-binding.json) registra 21 checks:
16 success, 5 skips de jobs previstos, 0 fallos/pendientes en ese candidato.

C6 se conserva: navegador→API→SQL real, 21/21 pasos, 20 capturas SQL y 0 fallos de oráculo.
Pérdida después de commit, recuperación GET con clave original y recargas mantienen solo dos POST,
dos ventas y stock 27. Logout 204/401 y sesiones 0.
API/base/directorio, Chrome y ausencia final de los contenedores comprobados en el [cierre C11](c11-next-20261104/README.md).
C8 conserva cierre técnico y sus regresiones; C7 conserva la excepción durable de remap 409.
No equivale a aceptación del negocio, Windows, dispositivos reales ni producción.

C9: [único preflight consumido](c9-recovery-20261103/PREFLIGHT-RESULT.md).
El cliente devolvió `The certificate chain was issued by an authority that is not trusted.`
Hubo 1 Open, 0 sesiones, 0 consultas y 0 mutaciones emitidas; exit 1 en 88 ms.
Cerró/dispuso y no reintentó. La identidad SQL, sesión TLS, permisos, rutas y colisiones siguen NOT RUN.
La causa exacta del certificado/cadena no está identificada. El primary preparó una
[investigación acotada](c9-recovery-20261103/CERTIFICATE-INVESTIGATION-SCOPE.md), todavía sin ejecución.
Jason / administrador decide cualquier corrección de seguridad y conexión nueva bajo alcance separado.
C9 sigue 0/5; faltan coordinador Windows, restore con ventas/oráculos, RTO/RPO y recuperación del último Owner.

Los tres extras N5-COV siguen pendientes. Las siete tarjetas TONY en revisión conservan su estado.
P-LEGACY: [19/19 aserciones clasificadas](p-legacy-20261104/CLASSIFICATION.md);
las correcciones permanecen abiertas en [issue #4](https://github.com/Suazo-AI/Martha-Silva-Store/issues/4).
El recibo normal identifica el commit documental de cierre; su SHA requiere readback y CI propios.
No hubo merge a main, despliegue ni cambios de seguridad en este cierre.

Los siguientes cortes y tablas conservan evidencia histórica; este corte y el ledger establecen el avance actual.

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

Preparar el siguiente lote de tres escenarios N5-COV a partir del código aceptado, conservando N1–N10.
Para C9, identificar primero el certificado/cadena mediante el alcance separado preparado.
No repetir el intento SQL consumido ni ejecutar restore hasta contar con metadata y autorización aplicables.
El [incremento N1–N10](delivery-20261031/NEXT-INCREMENT.md) ya tiene aceptación técnica por capas;
la aceptación operativa y recuperación Windows siguen pendientes.

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

### Continuacion coordinada: union C6 autorizada y candidatos congelados

Tony2ddf83de y PRb6bc0396 divergieron; no se forzo Git. Jason autorizo una union puntual y solo el nuevo SHA b6bc0396 en el importador; se conservan los 17 registros anteriores, filtros y recibo normal de la union. C6 combina cuerpo401 consumido con diagnostico y ausencia verificable de Chrome. 33/33 ligeras PASS; juez APTO CON REPAROS; CI combinado pendiente. [Detalle](c6-e2e-20261103/RECONCILIATION.md).

C8: seis blobs, overlay71/71 e inventario48/48 comprobados por agente separado; cierre depende del mismo candidato CI. [Revision](c8-ui-20261103/PRE-CI-REVIEW.md).

Se conserva el cierre C7 registrado por el otro hilo: Trello Hecho6/6 y excepcion durable aceptada, sin cambiar codigo ni seguridad. [Recibo del cierre](c7-closure-20261103/README.md). La nota historica5/6 queda desplazada por ese recibo.

C9: [procedimiento](c9-recovery-20261103/PROCEDURE.md) y 12/12 controles documentales nuevos; cero SQL/conexiones/runtime. Gates G0-G9 pendientes de campos, preflight autorizado, coordinador Windows y corrida con ventas/RTO/RPO/retirada. [Alcance solo lectura propuesto](c9-recovery-20261103/PREFLIGHT-SCOPE.md). No se repitieron one-shots historicos.
