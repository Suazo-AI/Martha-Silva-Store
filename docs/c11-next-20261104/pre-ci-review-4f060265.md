# C11: NEEDS WORK preliminar; CI pendiente

La estática confirma que el candidato añade el subcaso original Cashier A→B con cookie vieja explícita. Una brecha de aserción sigue abierta antes del dictamen final.

- task_id: C11-N5-01-FINAL-REVIEW-20261104
- status: pre_ci_review_returned
- verdict: NEEDS WORK (preliminar; no aceptación final)
- host: SUAZO-PC; reviewer: gpt-6-astra / high.
- candidate: 4f0602658141023be14cf294b6192a413aaaf8ae.
- parent: c2164c310acbcef94718499698abccaa7b1022c0.
- patch_sha256: 66f94206e8230c6d4a981f2373c01508e0e2f58e28b70593b76b91b59c71421b.

## Hallazgo accionable

**P2 / C11-N5-01-STATIC-01: las tres tablas de seguridad quedan sin comparación durante los rechazos.**

`backend/tests/Martha.Store.Api.Tests/InternalAcceptanceHttpSqlTests.cs:276–281` elimina Staff, Sessions y BranchAssignmentAudit. Las líneas314–325 comparan solo las16tablas restantes después de cada401. Las líneas336–338 hacen lo mismo tras404/403 del login nuevo.

Excluir esas tablas al cruzar el PUT autorizado y el login es razonable. Mantener la exclusión durante rechazos permite que cambios inesperados en esas tablas no hagan fallar el test. Los conteos de revocación y auditoría de307–311 se comprueban antes de esos rechazos. C7 mantiene igualdad de19tablas para autorización/alcance/CSRF. El servicio ValidateSession de la base, líneas53–60, solo lee; no justifica escrituras en esos rechazos.

Corrección mínima: capturar Fingerprint completo después del PUT; compararlo después de cada solicitud con cookie vieja. Capturar otro completo después del login nuevo y compararlo separadamente tras404 y403. Conservar16tablas para comparar a través de acciones autorizadas. No se reproduce ni afirma un defecto del producto.

Owner: ejecutor existente. Completion check: delta estático revisado y método nombrado1/1PASS en el CI del SHA corregido; suite sin fallos/omitidos. El juez no modifica código por su alcance de solo lectura.

## Verificado por lectura

- Un único Fact nuevo, líneas228–367. No cambian métodos existentes ni producto.
- AcceptanceFixture usa migración SQL real y JudgeFactory deriva WebApplicationFactory<Program>. La preparación de datos ocurre antes de la acción probada.
- Cashier crea ventaA y confirma recibo. Owner cambia BranchId por PUT normal manteniendo rol Cashier/enabled; versión, revocación y auditoría tienen aserciones SQL.
- SendOriginal agrega el Cookie y CSRF capturados en cada petición. Client usa HandleCookies=false. El mismo transporte obtiene200 antes del cambio. No puede sustituir silenciosamente la cookie vieja después del primer401.
- Tres solicitudes viejas exigen401: /me, venta con clave original y venta con clave nueva. Comparación comercial completa de16tablas tras cada una.
- Login nuevo del mismo usuario comprueba B y nueva versión. ReciboA404, ventaA403. Listas exactas B, stock8, sin IDs seleccionados deA ni unitCost.
- VentaB positiva exige una fila nueva en Sales/SaleLines/StockMovements/Operations y stock8→7. Historia completa deA permanece igual; operación original sigue única.
- Workflow cambia únicamente comentario y mínimo600→601. No cambia triggers, permisos, filtros ni condiciones de seguridad.
- El ledger solo cambia C11 de todo a review y añade evidencia/preparación. SieteTONY y N5-COV no cambian en este diff. No se declara cierre ni despliegue.
- No observé secretos concretos, cookies/tokens reales, bypasses ni identidades cliente nuevas en las adiciones revisadas.

## Vinculación

Reconstruí en memoria las ocho rutas del patch sobre blobs Git de la base. Las ocho coinciden textualmente con Git4f060265, normalizando CRLF/LF. Git añade además el recibo automático de progreso; ese recibo queda fuera de esta revisión focal.

Los hashes del manifiesto son de archivos exportados/locales. No son todos hashes de blobGit: por ejemplo fuente y workflow coinciden al convertir los blobsLF aCRLF. evidence.json registra ambos valores, sin afirmar igualdad binaria universal. Para CI se deben usar los hashes Git exactos y el SHA/árbol real del checkout.

Fuente Git SHA256: 9c4428105207c8802093427464e71814335bf6f425f09aa5a674e330af3e45d6.
Workflow Git SHA256: f91c5b631b5d48fd4aaa7503e20d54414bb39e8dc225801aa8ad35913a89fd36.

## Pendiente y límites

Run SAVIA41774458702 y Golden41774458728 fueron comunicados por root como en curso. No los consulté ni duplico su monitorización. Falta artefacto saneado con método1/1, suite601/601 sin failed/skipped, restart y cleanup, más binding del checkout al candidato/árbol idéntico.

N1/N2/N3/N4/N6/N7/N8/N9 conservan el dictamen técnico anterior por capas, sujeto a equivalencia final. N5 permanece PENDING. N10/C11 sigue NEEDS WORK hasta corregir la aserción y recibir CI directo. La excepción durable C7 permanece intacta. Browser con API simulada, DOM y SQL real siguen separados. No se prueban producción, Windows operativo, backup/restore ni los tres extrasN5-COV.

changed: solo PRE-CI-REVIEW.md y evidence.json del directorio judge.
verification: lectura del snapshot/contratos y Git show/diff-tree; SHA256 y reconstrucción de patch en memoria. No suites, runtime, red ni árbol mutable.
Local build/23tests/checks del CANDIDATE.json son resultados informados por el ejecutor, no pruebas repetidas por este juez.
Una lectura tuvo UnicodeEncodeError cp1252; se corrigió la salida aUTF-8. Una ruta fuente supuesta no existía; se localizó por Git ls-tree. Ninguno implica fallo de producto.
usage: tokens/coste/tiempo no expuestos; desconocidos.
next_action: root entrega el hallazgo al ejecutor y devuelve SHA corregido, artefacto por método y binding para juicio final.
