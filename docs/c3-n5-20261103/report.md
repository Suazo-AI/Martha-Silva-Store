# C3 / N5: verificación diferencial en Windows

Resultado verificado: candidato 5 PASS / 0 FAIL, exit 0; corrección revertida 2 PASS / 3 FAIL, exit 1.
Host: SUAZO-PC. Agente: gpt-6.1-sol, high, según autorización del lote.
Candidato: 775f301bc195c43baedc68c86f4e71affe92ef95. Base de la reversión: 20932d5c97f2caaafad7dc888879957791907f36.
Node v24.18.0; Playwright 1.62.1; Google Chrome 156.0.8078.80.

Se ejecutaron exactamente dos invocaciones del arnés, con cinco casos idénticos por invocación.
API sintética interceptada en Chrome real; servidor HTTP efímero en loopback. No se accedió a SQL.

## Resultados reales

| Caso | Corrección | Reversión |
| --- | --- | --- |
| Stale confirmed receipt 404 must not permanently block a fresh sale (N5) | PASS | FAIL |
| Stale receipt 403 after reassignment is cleared and leaves a fresh sale available (N5) | PASS | FAIL |
| Unavailable receipt lookup keeps its reference and does not invent a pending sale (N5) | PASS | FAIL |
| Stale receipt never unlocks a real pending sale; recovery reuses the original key (N5) | PASS | PASS |
| Revoked session during receipt restore returns to sign-in without staff data (N5) | PASS | PASS |

Errores completos: [reverted/browser-results.json](reverted/browser-results.json).
404: `Confirmed receipt became unavailable; new authorized sale is locked, with no recoverable pending operation.`
403 y 503: `expect(locator).toBeEnabled() failed`; `#sale-submit`, esperado enabled, recibido disabled, timeout 5000ms.

## Comandos ejecutados

```powershell
git -C 'C:/Users/Jason/MARTHA-SILVA/github' worktree add --detach 'C:/Users/Jason/MARTHA-SILVA/test-runs/c3-n5-775f301-20261103' 775f301bc195c43baedc68c86f4e71affe92ef95
Set-Location 'C:/Users/Jason/MARTHA-SILVA/test-runs/c3-n5-775f301-20261103'
$env:MARTHA_BROWSER_TEST_MATCH = '(N5)'
node tests/browser-mock-validation.mjs 'C:/Users/Jason/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright' 'C:/Users/Jason/MARTHA-SILVA/test-runs/c3-n5-775f301-20261103-evidence/fixed'
git diff 20932d5c97f2caaafad7dc888879957791907f36 775f301bc195c43baedc68c86f4e71affe92ef95 -- dev/savia-staff-ui/app.mjs
git restore --source=20932d5c97f2caaafad7dc888879957791907f36 -- dev/savia-staff-ui/app.mjs
node tests/browser-mock-validation.mjs 'C:/Users/Jason/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright' 'C:/Users/Jason/MARTHA-SILVA/test-runs/c3-n5-775f301-20261103-evidence/reverted'
git restore --source=775f301bc195c43baedc68c86f4e71affe92ef95 -- dev/savia-staff-ui/app.mjs
git status --porcelain --untracked-files=all
```

Salidas y exit codes: `fixed.stdout.txt`, `fixed.stderr.txt`, `fixed-run.json`, `reverted.stdout.txt`, `reverted.stderr.txt`, `reverted-run.json`.
La restauración final se ejecutó en `finally`. El worktree se conserva para inspección.

## Integridad y limpieza

| Archivo / estado | SHA256 |
| --- | --- |
| app.mjs candidato | 6df74c24a246ee3539ef4f07839620df15129ceb6d3750253b61ed63bf62b130 |
| app.mjs revertido | 46dbf8aa0d2f8f962b2868d3893a6dd7ef3eeab49d30b317e42350ea80f74fd9 |
| app.mjs restaurado | 6df74c24a246ee3539ef4f07839620df15129ceb6d3750253b61ed63bf62b130 |
| browser-mock-validation.mjs antes / revertido / restaurado | 28d29a5722239e5ede1e5d6f7f2d6e7801028425506f317fd7920602e3e93956 |

La reversión solo modificó dev/savia-staff-ui/app.mjs. Numstat de la reversión: ["1\t19\tdev/savia-staff-ui/app.mjs"].
Los demás cinco hashes de fuentes del navegador coinciden entre corridas.
Estado final completo, incluidos untracked: [].
Chrome restante: []. Procesos node del arnés: [].
Listeners en puertos 62208 y 55167: [].
Ambas corridas: runtime errors 0, solicitudes externas 0, fallos de red 0.

Estados capturados: `before.json`, `reverted-state.json`, `restored-state.json`.
Diffs revisables: `product-fix.patch`, `product-reverted.patch`.
Aceptación automatizada de la evidencia: los 14 checks de `summary.json` son true.

## Límites y pendientes

- Chrome real con API sintética; no browser -> API real -> SQL.
- No prueba aceptación del producto, producción, móvil, accesibilidad ni rendimiento.
- No hubo grabación visual; la reversión es un baseline reconstruido para comparación conductual.
- No commit, push, merge, deploy, SQL, Docker, instalación ni cambios de seguridad.

No hubo bloqueos de entorno. Los tres FAIL de la reversión reproducen el defecto de producto, no una falla del entorno.
Causa: el catch de start() convierte un recibo histórico inaccesible en pending ||= {}, bloqueando Registrar venta sin clave recuperable.
Corrección temporal aplicada: restaurar los bytes del candidato en finally; resultado: hash original y status limpio.
Siguiente acción: primary /root verifica y conserva evidencia curada en el checkout canónico.
Comprobación de cierre: leer ambos resultados, hashes y estado limpio.

## Lección

Una suite verde demuestra más cuando las mismas pruebas fallan al retirar solamente la corrección y el hash del arnés permanece constante.
