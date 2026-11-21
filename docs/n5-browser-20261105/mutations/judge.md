# Independent Astra adjudication: verbatim report

**ACCEPT WITH LIMITS.** No encontré un bloqueo material para la aceptación técnica acotada de N5-COV. M1 queda satisfecho por controles negativos reales. m1 queda resuelto para la ventana y el escenario observados, con límites explícitos.

`task_id: savia-n5-m1-adjudication-20261105`

Este dictamen es una devolución independiente. El primary conserva la aceptación final.

**M1 — satisfecho sin waiver**

Verifiqué que `done_when` permanece idéntico al de `5ab44fbb8210f3d6e98f34745700194195c0e1ce`:

> Cada hueco cubierto por una prueba en tests/browser-mock-validation.mjs con rojo-verde, o descartado por escrito con el motivo

La evidencia contiene cinco invocaciones documentadas:

- Baseline: **8 PASS, 0 FAIL; exit 0**.
- M01: **0 PASS, 1 FAIL; exit 1**. Error: `Original pending bytes changed during held recovery.`
- M02: **0 PASS, 1 FAIL; exit 1**. La referencia obsoleta permanece donde se esperaba `null`.
- M03: **0 PASS, 1 FAIL; exit 1**. Error: `Old 404 erased reference after generation invalidation.`
- Restaurado: **8 PASS, 0 FAIL; exit 0**.

Contrasté los fallos semánticos en los JSON con los conteos de los logs, el driver y los bytes reconstruidos de cada mutación.

M01 elimina únicamente `busy || pending ||` del guard de submit. El handler cambia la clave pendiente, pero `resolve()` todavía bloquea el envío por `busy`. Por eso la corrupción de bytes es el fallo correcto; otro POST no es necesario.

M02 elimina la retirada de la referencia obsoleta. El caso verde también comprueba venta completa, cuerpo exacto, inventario y reload sin repost.

M03 elimina conjuntamente dos comprobaciones `current(generation)` del cliente y el guard `current(g,id)` de `restoreReceipt`. Demuestra sensibilidad a una regresión de esa protección combinada.

Esto satisface rojo-verde mediante mutaciones y restauración. **No demuestra una corrección de un defecto existente en producto.**

La carrera con una venta pendiente nueva dentro de la misma generación permanece razonadamente descartada. `start()` mantiene `busy` mientras espera `restoreReceipt`; `lock()` deshabilita controles y el handler rechaza submit. No se fabricó ese estado.

**m1 — resuelto para el alcance observado**

El test sigue usando `response.finished()` y dos frames. No incorpora una señal explícita de finalización de todos los callbacks.

Sin embargo, M03 alcanza exactamente la aserción posterior a esa espera y detecta la eliminación prohibida de la referencia. La ventana observada sí detectó la regresión inyectada.

La fuente respalda la interpretación: en producto intacto, el epoch invalidado rechaza la respuesta antes de procesar el 404. El mutant permite que llegue hasta la eliminación de la referencia.

Límites conservados:

- No prueba cada guard por separado.
- No prueba todos los órdenes posibles del scheduler.
- No demuestra que el segundo guard de `login.mjs`, situado después de `response.json()`, sea necesario para este 404.
- No sustituye una señal explícita de finalización si futuras modificaciones añaden nuevas esperas.

No considero esos límites un bloqueo para los tres casos congelados.

**Otros hallazgos**

**m2 corregido.** `tests/browser-mock-validation.mjs:353` incluye `await browserTurn(s.page)` después del segundo submit sintético. Está presente en el overlay usado por baseline, mutaciones y restaurado.

**m3: queda una inconsistencia documental menor.** `docs/n5-browser-20261105/PLAN.md:5-6` todavía presenta como estado que Opus está pendiente. Las secciones posteriores y el ledger registran correctamente su devolución.

El primary debe actualizar esa cabecera antes de publicar. Puede conservar la historia identificándola como tal. Esto no invalida los controles negativos.

**m4: trazabilidad suficiente.** Verifiqué el mapa de importación, los archivos originales y el archivo privado del parche M03. Los logs históricos ahora tienen rutas de archivo y hashes verificables.

`INTEGRATION.json` conserva `correctedFocused` asociado al test histórico `8fdd63ef…60c8`. Las mutaciones están asociadas al overlay actual `88eaa468…9dea`. El full browser 50/50 permanece atribuido al worker original. No encontré una afirmación de CI ejecutada sobre el overlay actual.

**Evidencia verificada**

- Packet RAW SHA256: `3f04c85c77d423038a61f5d14e7a4a3b6ec6bf9ae797a3e61368166850722085`.
- **29/29** entradas congeladas coincidentes al inicio y al cierre.
- **53/53** hashes de `INTEGRATION.json`, según su política.
- **13/13** hashes originales de evidencia del worker.
- **14/14** entradas de `IMPORT.json`, verificando origen y copia pública.
- **5/5** hashes de logs privados de mutaciones.
- **1/1** hash del driver privado.
- **1/1** hash del M03 original archivado.
- **9/9** hashes de logs históricos archivados.
- **3/3** parches originales reconstruidos íntegramente en memoria.
- **30/30** hashes de fuentes de los cinco resultados: seis fuentes por ejecución.

El driver captura el código de salida del proceso y restaura fuentes mediante `finally`. Los logs corroboran los conteos. No observé personalmente los procesos históricos.

Baseline y restaurado registran cero excepciones de página y cero solicitudes externas. Ambos conservan un `ERR_FAILED` de venta y un `ERR_ABORTED` de logout esperados.

La corrección del clasificador está declarada. El driver permite reutilizar el baseline 8/8 sin repetirlo. No encontré evidencia contradictoria con las cinco invocaciones registradas.

**Fuente y política de bytes**

HEAD del checkout canónico, del worker y de este juez:

`5ab44fbb8210f3d6e98f34745700194195c0e1ce`

Overlay RAW de test:

`88eaa468cc92bdd32ca6b066b512c6a8ebd38969cc7f332dbad9b41122269dea`

Fuentes RAW restauradas:

- `app.mjs`: `383c40447e91aa465cc945138699151826d7c1ad93f2f1ed041aa3dcda303309`
- `login.mjs`: `ac7714a22eb1e7a383ca41e3e11343472025271dcf21dcf862f39cf8c386fc787`

Ambas fuentes coinciden byte por byte entre worker y canonical. Coinciden con la base tras normalizar únicamente CRLF→LF.

Los hashes históricos describen bytes originales. El manifiesto portátil normaliza CRLF→LF para los tipos textuales declarados; las imágenes se verifican por bytes RAW.

El M03 público cambia exclusivamente dos líneas añadidas vacías: elimina su indentación. Verifiqué esas diferencias en las líneas 19 y 28 del parche. **Solo el parche original reconstruye los bytes exactos observados.** No atribuyo ninguna ejecución al derivado público.

**Runtime y límites**

Host: **SUAZO-PC / Windows**. Harness: **T3 Code / Codex**. Modelo: **gpt-6-astra**.

Reasoning solicitado: **high**. Reasoning efectivo: **high**, reportado por metadata del runtime y agent-awareness.

Worktree del juez: `C:/Users/Jason/.t3/worktrees/github/t3-0c8da770`.

Opus: `claude-opus-5-5` mediante Antigravity. `thinking_level: high` solicitado; esfuerzo efectivo **desconocido**. Este dictamen no convierte esa incertidumbre en una verificación ni sustituye al crítico.

Tokens, consumo de cuota y costo: **no reportados**.

Leí las instrucciones solicitadas sin denegaciones. Una lectura documental falló por decodificación CP1252; la repetí explícitamente en UTF-8 y quedó resuelta.

**NOT RUN:** pruebas de navegador por este juez, suites, CI, API real, SQL, dispositivos, Docker, certificados, TLS, producción o aceptación operativa. No escribí archivos, modifiqué producto, índice o ledger, ni publiqué.

**Acción del primary:** corregir la cabecera de `PLAN.md`, registrar su aceptación o rechazo de este dictamen y mantener separados los resultados históricos. Después corresponde publicación normal y comprobación del SHA remoto y su CI. Ningún gate de proveedor u operación queda dispensado.

## Primary erratum after export

The report's narrative login.mjs hash contains one extra `f` (65 characters).
The actual 64-character raw SHA256, verified from the file and frozen worker
RESULT.json, is `ac7714a22eb1e7a383ca41e3e11343472025271dcf21dc862f39cf8c386fc787`.
This is a transcription error in prose. The artifact hashes and verdict are
unchanged. Original report wording above is preserved; no new review is implied.
