# C11 / N5: candidato de cobertura HTTP+SQL

C6/C8 conservan su cierre técnico sobre e4b7910835bf2c9901aa06989e296997875a3636. C7 conserva su cierre y excepción durable aceptados.
[Registro previo de dependencias en Trello](trello-dependencies.json).

C11 sigue en revisión. El [dictamen inicial](initial-review.md) es NEEDS WORK: ocho criterios APTO y C11-N5-01 pendiente.
La [evidencia inicial](initial-review-evidence.json) conserva sus bytes y procedencia. Las copias root-c11-review y c11-integration son idénticas.
No existe un defecto de producto reproducido por este lote.

Se añade un único método en InternalAcceptanceHttpSqlTests:
`N5_owner_branch_reassignment_rejects_original_cashier_cookie_and_preserves_sales_before_new_scope_login`.
Usa Program, migraciones, SQL sintético y login/cookie/CSRF reales del arnés existente.

1. Cashier crea venta A y lee su recibo. El cliente que reenvía la cookie capturada prueba /me 200 y recibo A 200.
2. Owner cambia A→B por PUT staff, conservando Cashier y enabled. SQL comprueba nueva versión, revocación y auditoría del cambio.
3. El mismo cliente reconstruye Cookie y X-CSRF-TOKEN originales en cada petición. /me y dos ventas protegidas requieren 401, incluso después del primer 401; las ventas usan clave original y nueva.
4. Después del PUT se captura la huella completa de las 19 tablas; cada replay 401 debe conservarla. Después del login B se captura otra huella completa; cada rechazo 404/403 y lectura permitida debe conservarla. La comparación de 16 tablas solo excluye Staff, Sessions y BranchAssignmentAudit al atravesar los cambios autorizados de PUT/login.
5. Login nuevo confirma B. Recibo A requiere 404; venta A requiere 403. Ubicación, stock y ventas muestran exactamente el ámbito B, sin identificadores de A.
6. Una venta positiva B añade una venta, línea, movimiento y operación; stock B pasa de 8 a 7. Todas las filas originales de A, líneas, movimientos, operaciones y stock quedan idénticas.

Compilación local con SDK existente 10.0.402: PASS, cero errores y advertencias. [Comandos y hashes](local-checks.json).
No se ejecutó API, SQL, Docker, navegador ni test HTTP+SQL local.
El mínimo backend de CI pasa de 600 a 601 para exigir los 600 casos anteriores y este método; cero failed/skipped siguen siendo obligatorios.

Pendiente: publicar candidato, comprobar hooks/remotos, CI del SHA exacto, método 1/1 en artefacto saneado, suite 601/601 y C6/C8 conservados.
El juez independiente debe emitir el dictamen final antes de cerrar C11. N5-COV y C9 permanecen fuera de este lote.
No se publican cookies, CSRF, sesiones, TRX ni logs crudos.

La revisión estática del candidato 4f0602658141023be14cf294b6192a413aaaf8ae detectó la exclusión indebida de tres tablas durante los rechazos. La [corrección del oráculo](oracle-revision-checks.json) conserva el mismo Fact y mínimo 601; el candidato anterior y su evidencia siguen históricos. CI y dictamen final siguen pendientes.
