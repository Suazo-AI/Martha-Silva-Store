# C6: resolución combinada y CI pendiente

Tony publicó `2ddf83de7a89da608e8267a21313d64b373bf5e2` con C6 y C8.
El push al PR fue rechazado porque su rama avanzó a `b6bc0396bb7d53359d23b806a3177edc194c8e62`.
Ambos partían de `6aeb9a35f45331ace85ac48dc19bfd9264b0f722`.
No se forzó Git ni se descartó ninguna historia.

Jason autorizó la unión puntual y la excepción exacta de ese único SHA sin recibo.
El manifiesto anterior mantiene sus 17 registros y filtros. El nuevo commit exige recibo normal.
La resolución conserva el diagnóstico por fase y la comprobación de ausencia de Chrome de Tony.
También espera el cuerpo del 401, aportado por la rama remota, antes de `networkidle`.

## Evidencia previa al CI combinado

- Una corrida ligera: **33/33 PASS**; Node syntax, Python AST y whitespace: exit 0.
- JS del worker, propuesta y resolución: SHA256 `5a09272ffb8a1c433813bc4cad626921cd1b0ef329f0097a008122e41eb6df21`.
- Juez independiente: **APTO CON REPAROS**, sin regresión nueva; conserva los 17 checks.
- [CI remoto 41758450353](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41758450353): PASS en `b6bc0396`, 21/21 pasos y 11/11 de navegador.
- Logout de ese CI: 648 ms, dos POST de venta totales y cero sesiones SQL activas.
- Final de negocio: dos ventas, dos líneas, dos operaciones de venta y dos movimientos de venta; stock 27.
- Preparación incluida: nueve Operations totales y cinco movimientos totales. No confundirlos con los dos de venta.

El CI de `b6bc0396` no contiene la retirada nueva de Chrome ni C8 de Tony.
No sustituye el CI combinado y no cierra H1/H2 del juez.
El mensaje de su commit afirma reproducción local; no se adopta esa afirmación como evidencia independiente.

Ver [checks](body401-checks.json), [manifiesto](body401-manifest.json),
[revisión](independent-review-resolution.md) y [binding](reconciliation-binding.json).

## Bloqueos y siguiente acción

La divergencia se resolvió con autorización acotada y una resolución revisada.
Falta validar el importador, publicar ambos SHA remotos y leer el nuevo CI con sus artefactos.
Root integra y publica. Ejecutor y juez C6 verifican el resultado contra los 17 checks.
C8 debe aportar browser 45/45, staff 45/45 y backend 600/600 del mismo candidato.
C9 conserva su alcance documental; no hubo SQL, API, Docker ni cambios de seguridad locales por este lote.

Si una verificación falla, conservar el commit y el artefacto; corregir la causa y repetir solo la ruta afectada.
No cerrar C6 por un estado verde sin vincular fuentes, negocio y retirada.

## Control de publicación completado

La suite `python -B tests/test_progress.py -v` terminó **23/23 PASS**, exit 0, en 228.214 s.
Exportación histórica: 15 hashes preservados; ledger: 34 elementos válidos.
Los 17 registros previos permanecen idénticos y el escaneo adicional de los blobs de b6 pasó.
El [juez del control](independent-review-publication.md) dio APTO estático, sin ampliar filtros ni exenciones.
Véase el [informe completo](publication-validation/REPORT.md) y sus checks.

Los primeros colectores de 90 s vencieron sin resultado completo; no cuentan como PASS.
Un launcher no encontró Python y no inició pruebas; su exit 0 tampoco cuenta como PASS.
La corrección usó el intérprete existente, salida verbose y límite de 600 s; los 23 casos terminaron.
Lección aplicada: separar límite del colector, fallo del launcher y resultado del producto.
No hubo API, SQL, Docker ni navegador local en esta validación.
El CI combinado sigue pendiente de publicación y lectura directa de artefactos.
