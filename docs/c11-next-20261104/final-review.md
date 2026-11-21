# C11 / N10: APTO técnico por capas

El candidato `53dd23b5cfec2cb5dd717395b9095a71d29669f0` resuelve C11-N5-01 y C11-N5-01-STATIC-01. El dictamen cubre el contrato sintético revisado por capas. No equivale a aceptación operativa integral, producción o permiso de despliegue.

- task_id: C11-N5-01-FINAL-REVIEW-20261104.
- status: final_review_returned; verdict: APTO.
- reviewer: gpt-6-astra / high; host: SUAZO-PC.
- changed: solo informes/evidencia de judge; ningún estado de proyecto modificado.

## Prueba nueva y regresiones

Leí directamente los cuatro artefactos descargados. Backend: **601/601 PASS,0failed/0skipped**; notPassed0 y methodsNotPassed vacío. El verificador incluye cualquier resultado distinto dePassed en notPassed.

`InternalAcceptanceHttpSqlTests.N5_owner_branch_reassignment_rejects_original_cashier_cookie_and_preserves_sales_before_new_scope_login`: **1/1 PASS**.

El método usa Program/migraciones SQL, cookie/CSRF reales y Owner PUT para cambiar CashierA→B. El transporte con HandleCookies=false envía la cookie capturada en cada solicitud, incluso después del primer401. Sus controles previos200 validan ese transporte.

Después del PUT captura19tablas; cada401 conserva esa huella. Después del login nuevo captura otras19tablas; cada404/403 conserva esa huella por separado. La comparación de16tablas solo cruza cambios autorizados de personal/sesión/auditoría. El loginB confirma identidad/versión/ámbito; reciboA404, ventaA403, lecturaB exacta y ventaB permitida. VentaB añade una venta/línea/movimiento/operación y stock8→7. La historiaA y su operación original permanecen iguales. Fuentes: líneas228–374 y Fingerprint633 del candidato, detalladas en los PRE-CI preservados.

Comparé el artefacto anterior600casos: sus257métodos conservan exactamente casos/aprobados. Solo aparece el métodoN5 adicional. N1/N3/N4/N8/N9 siguen1/1. `PrivatePilotReleaseTests.Frozen_fixture_survives_controlled_owned_container_stop_start` sigue1/1. El workflow detiene/arranca el contenedor y ejecuta ese filtro contra la base persistida; no es una simulación de reinicio del cliente.

Browser:45/45PASS,0erroresruntime y0solicitudesexternas. Es Chromium real con APIstaff simulada. Sus cincoN5, tresN2, tresN6 y tresN7 siguenPASS. Hay fallos de red registrados por escenarios de respuesta perdida/cancelación; no se declara red sin fallos. Esta suite no pruebaSQL.

## Matriz congelada

- N1: APTO: identidades/roles/scope y usuario sin asignacion; metodo HTTP+SQL1/1.
- N2: APTO: venta/recarga/recuperacion Cashier real C6; Owner/Manager por capas HTTP y browserAPI simulado.
- N3: APTO: denegaciones directas y19tablas sin cambios; metodo HTTP+SQL1/1.
- N4: APTO: alcance/IDs/paginacion y remap409; metodo1/1; excepcion durableC7 preservada.
- N5: APTO: nuevo metodo HTTP+SQL1/1 mas cinco casos browserAPI simulado; cookie vieja invalida, reciboA inaccesible y ventaB posible.
- N6: APTO: tres casos browserAPI simulado preservan intento incierto sin reenviarlo como otro actor/alcance.
- N7: APTO: logout/revocacionHTTP+SQL; expiracion con TimeProvider1/1; tres casos browserAPI simulado de respuestas tardias.
- N8: APTO: paresCSRF invalidos sin cambios19tablas y control valido; metodoHTTP+SQL1/1.
- N9: APTO: ajusteOwner, denegacionCashier y replay sin segundo efecto; metodoHTTP+SQL1/1.
- N10: APTO: juicio independiente por capas; ledger y recuperacion coherentes, sin segundo debito ni exito inventado.

La expiración usa reloj local controlado; no demuestra ocho horas de navegador/SQL. C7 conserva19tablas para rechazos de autorización/alcance/CSRF y18tablas+un rechazo durableOperations para remap409. N5-COV conserva sus tres extras pendientes.

## Ledger y controles de recuperación

Golden smoke19/19 y browser realAPI/SQL21/21;38capturasSQL,0oracle_failures. En browser: inicial0ventas/stock30; primera venta2unidades deja1venta/línea/movimiento/operación y stock28; recarga conserva esos valores. Segunda venta1unidad confirmaHTTP200 y pierde la respuesta medianteCDP: quedan2de cada registro y stock27. GETrecuperación, recargas y logout conservan esos2registros y27stock. Solo2POSTdeventa acumulados. La clave ysale_id coinciden entre pérdida/recuperación. El recibo vuelve visible y venta queda habilitada. No hubo segundo débito ni éxito inventado.

Logout devuelve204, /me401 y sesiones activas0. Ambos teardown registran APIexit0, database_dropped=true y private_dir_removed=true. Browser añade exit0, ownership_confirmed=true y processes_absent=true. No leí en este corte un extracto independiente de ausencia final del contenedorSQL ni del paso de publicación/retirada a niveljob; no los infiero solo de success. Los artefactos publicados sí se leyeron directamente. Esta limitación de readback no amplía el contratoC11.

## SHA y procedencia

[SAVIA41774927960](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41774927960) y [Golden41774928044](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41774928044): pull_request, attempt1, head53dd23b5, completed/success en el binding exportado por root desdeGitHub. No repetí consultasCI.

Los extractos de checkout de los tresjobs muestran `cb3109bc5159b86d4ec8c68e3ac058d2f949bab7`, merge sintético de53dd23b5 conmain3b004916. Candidate y checkout tienen árbolidéntico `abaf54477b400ac434835864fbd79795210b5f32`. La aceptación corresponde al árbol probado; no se hizo merge a main.

La fuenteGitLF verificada tiene48033bytes/SHA256`a2ad86527f08e0d8b20c08cf659ce4695b4faa1352ca836a5843a07fd5dfe0df`; exportCRLF48696bytes/SHA256`9fbc9e14133b2f6601d7a0246a32cdb5045d4679cf7d84269dd801adfb2901ca`. Coinciden tras normalización. Comparé seis hashesUI y ocho fuentesC6 conGit53dd: todos coinciden. No reconstruí laDLL registrada.

El diff focal e4b79108→53dd cambia solo nuevoFact y mínimo601 del workflow; producto/UI/arneses focales son iguales. Root exportó21checks:16success,5skipped y0pending/fail. Son skips de jobs, distintos de0skips de casosbackend; no revisé independientemente cada condición de esos jobs.

Los cuatro SHA256 deJSON calculados por este juez coinciden con root-runtime-review.json. IDs/digestsZIP provienen del bindingGitHub; no recalculéZIPbinarios. Hashes, nombres y URLs están en evidence.json.

## Límites y siguiente acción

verification: lectura directa de artefactos/contratos, comparación de métodos, hashes y blobsGit inmutables. Sin suites/runtime/red nuevos ni lectura del checkoutmutable.
blockers: ninguno para este dictamen técnicoC11; el readback adicional de contenedor/publicación queda delimitado arriba.
unverified: N5-COV, aceptación operativa integral, Windows/dispositivos, backup/restore, producciónTLS/proxy, pagos, carga y despliegue.
usage: tokens/coste/tiempo no expuestos; desconocidos.
next_action: root verifica este dictamen y el integrador registra el cierre autorizado. Un commit documental posterior requiere comprobar equivalencia y CI propios antes de afirmar entrega final. Este juez no cambia ledger/Trello ni sieteTONYreview.
