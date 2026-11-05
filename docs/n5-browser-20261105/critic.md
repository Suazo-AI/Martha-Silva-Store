**Veredicto: ACCEPT WITH LIMITS.**

Los tres casos N5-COV cubren lo que dicen cubrir sobre el código actual. Los hashes cuadran. No encontré cambios de producto. No encontré ningún falso positivo bloqueante.

Hay un hueco para cerrar el ítem. El `done_when` de N5-COV ([ledger.json:331](file:///C:/Users/Jason/.t3/worktrees/github/t3-512affaf/docs/pipeline/ledger.json#L331)) exige "rojo-verde" o un descarte por escrito. Los huecos 1 y 2 solo tienen verde a la primera, sin control negativo. Los documentos no inventan un rojo-verde, y eso está bien. Pero falta evidencia de que esas pruebas fallarían ante una regresión.

## Hallazgos

**M1 (afecta el cierre, no la validez).** No hay rojo-verde ni prueba de mutación en ninguno de los tres casos.
- Impacto: según el ledger, N5-COV no puede pasar de `review` solo con esta evidencia.
- Opciones: una corrida de mutación desechable, o que el owner registre que "primer verde + análisis de fuente" cumple el `done_when`.

**m1. La ventana de observación del caso 3.** En [test:349-351](file:///C:/Users/Jason/.t3/worktrees/github/t3-512affaf/tests/browser-mock-validation.mjs#L349-L351) se ve la referencia retenida después de `finished()` y dos rAF. Pero la página no emite ninguna señal de que el JS procesó la respuesta tardía.
- Si el procesamiento se atrasara, la aserción pasaría igual, sin haber probado nada.
- La fuente sí respalda el resultado: `login.mjs:56` → 401 → `app.mjs:511` → el catch de `start` con `current` en falso (`app.mjs:572`).
- Severidad baja. Astra ya lo notó.

**m2.** En [test:353](file:///C:/Users/Jason/.t3/worktrees/github/t3-512affaf/tests/browser-mock-validation.mjs#L353) el segundo `dispatchEvent('submit')` se afirma sin `browserTurn`. Esa aserción no puede fallar. No importa en la práctica: `actor=null` (`app.mjs:462`) y la guarda de `app.mjs:578` ya hacen inalcanzable el POST.

**m3. Textos desactualizados.** El campo `review` del ledger ([ledger.json:340](file:///C:/Users/Jason/.t3/worktrees/github/t3-512affaf/docs/pipeline/ledger.json#L340)) todavía dice "CI Linux pendiente" y "Opus pendiente por cuota". Lo mismo [EXECUTION-SUMMARY.json:112](file:///C:/Users/Jason/.t3/worktrees/github/t3-512affaf/docs/n5-browser-20261105/EXECUTION-SUMMARY.json#L112). Ya está declarado en `PUBLICATION.md:35-37`. Hay que actualizarlo al cerrar.

**m4. Reproducibilidad.**
- `INTEGRATION.json.sha256` mezcla normalizaciones sin decirlo. 16 entradas coinciden con los bytes CRLF del working tree y 18 con el blob LF de Git.
- `checks[].log` apunta a rutas `.log` que ya no están en el paquete. Están mapeadas en `excludedRawLogs`.
- La copia CRLF de `worker-test.patch` no aplica directamente. El blob LF sí aplica.

## Disposición de los cinco checks

1. **ACCEPT.** [271-298](file:///C:/Users/Jason/.t3/worktrees/github/t3-512affaf/tests/browser-mock-validation.mjs#L271-L298).
   - Botón nativo deshabilitado y submit sintético sin POST nuevo.
   - Los bytes pendientes son idénticos: clave, body y `actorVersion`.
   - El GET de recuperación lleva la clave original en el header `Idempotency-Key` (`client.mjs:58`, `login.mjs:47`). Hay un solo POST de preparación.
   - Fuente: el submit lo bloquean `busy` o `pending` (`app.mjs:578`). No hay ventana sin `busy` entre `app.mjs:573` y `574`.
2. **ACCEPT.** [299-335](file:///C:/Users/Jason/.t3/worktrees/github/t3-512affaf/tests/browser-mock-validation.mjs#L299-L335).
   - Body exacto sin precio, comparado con `deepEqual` estricto. Una sola clave UUID.
   - Stock exacto `10/0/10` → `8/0/8` y `7/0/7`.
   - El `toBeEnabled` espera a que termine `loadStock` (`app.mjs:532,542`), así que la lectura es determinista.
   - Reload sin repost. No hay una operación pendiente previa, y el caso no dice que la haya.
3. **ACCEPT WITH LIMITS.** [336-360](file:///C:/Users/Jason/.t3/worktrees/github/t3-512affaf/tests/browser-mock-validation.mjs#L336-L360).
   - La atribución corregida es correcta: es protección combinada de logout (`login.mjs:117,56`, `app.mjs:511,354,152,462`). No prueba la guarda `app.mjs:514` por separado.
   - Confirmo que la carrera "newer-pending" en la misma generación es inalcanzable: `busy` sigue en true mientras `start` espera `restoreReceipt` (`app.mjs:546-573`), y lo bloquean `lock` (445) y `submit` (578).
   - El límite es m1.
4. **ACCEPT.**
   - El diff de código desde la base solo toca `tests/browser-mock-validation.mjs`, con 95 líneas añadidas y 0 borradas.
   - El parche del worker tenía 94 líneas añadidas. La corrección cambió 1 línea por 2.
   - `dev/savia-staff-ui/README.md` es solo documentación.
   - "Primer verde" es un dato registrado por el worker. No lo observé yo.
5. **ACCEPT.** Los documentos separan bien:
   - el worker: focused 8/8, full 50/50, staff 102/102;
   - el primario: focused corregido 8/8.
   - El `stockBefore` del primario guarda celdas exactas. El del worker guarda strings concatenados. Eso confirma que el primario corrió el test corregido.
   - Todo el alcance es Chrome con HTTP mockeado.

## Verificado (solo lectura)

- Worktree `t3-512affaf`: HEAD `5ab44fbb8210f3d6e98f34745700194195c0e1ce`, limpio, `core.autocrlf=true`.
- Test corregido: working CRLF = `8fdd63ef…60c8`. Blob de HEAD = `fa7e8dd3…e624`.
- Original del worker reproducido: blob LF del parche sobre la base, `git apply` con exit 0. El resultado en LF es `fb82cbe1…15b8`. Normalizado a CRLF da `020b29f1…862c`, que es exacto.
- `INTEGRATION.json.sha256`: 34/34 coinciden (16 en CRLF y 18 en LF). Ninguna discrepa.
- Las 6 fuentes de staff en los tres `browser-results.json` coinciden con los bytes actuales.
- Conteos: focused 8/0, full 50/0, primary-focused 8/0. Errores de runtime: 0. Peticiones externas: 0. Fallos de red: 2, 13 y 2, todos aborts deliberados.
- Los 9 logs archivados en `MARTHA-SILVA/test-runs/.../raw-logs` coinciden por hash. No hay ningún `.log` versionado.
- N5-COV sigue en `status: review`.

## Pendiente o no verificado

- No verifiqué los runs de CI en GitHub; no hice llamadas de red.
- No reejecuté pruebas.
- No pude leer `AI-OS/rules/orchestration.md`, `PROTOCOL.md` ni `OUTPUT.md`: el pre-tool hook los bloqueó por estar fuera del workspace. No lo esquivé. Sí leí `AGENTS.md` del repo.
- Antes de ver ese bloqueo había hecho el hash de los logs archivados desde la shell; queda declarado.
- Escribí archivos temporales en `antigravity-tmp` para reproducir el parche y luego los borré. No escribí nada en el repo.

## Runtime

- Host `SUAZO-PC`, Windows. T3 Code, harness Antigravity.
- Modelo reportado por el runtime: `claude-opus-5-5`.
- Reasoning pedido: high. Reasoning efectivo: desconocido, el runtime no lo expone.
- Uso y costo: desconocidos.

## Siguiente acción

El primario decide cómo cerrar M1. La opción concreta es una corrida de mutación desechable fuera del repo canónico:
- (a) quitar `busy || pending ||` en `app.mjs:578` → el caso 1 debe fallar;
- (b) quitar `storage().removeItem` en `app.mjs:516` → el caso 2 debe fallar;
- (c) quitar `current(generation)` en `login.mjs:56` y `login.mjs:77`, más `if(!current(g,id))return` en `app.mjs:514` → el caso 3 debe fallar. Esto también cierra m1.

La otra opción es registrar en el ledger que el owner acepta el primer verde como suficiente.
