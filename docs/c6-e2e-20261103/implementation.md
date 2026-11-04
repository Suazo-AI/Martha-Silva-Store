# C6: implementación preparada; runtime real pendiente

Lote: `20261103`. Host de edición: SUAZO-PC. Ejecutor seleccionado por Jason: `gpt-6.1-sol / xhigh`.
Tarjeta: https://trello.com/c/ezVfv0Pk. Integración destino: PR #2 de `Suazo-AI/Martha-Silva-Store`.
Base: `260b75951729189d987ffe423218ab1643bcfa3c`.
Rama de trabajo: `task/c6-browser-sql-20261103`.
Worktree: `C:/Users/Jason/MARTHA-SILVA/test-runs/c6-browser-sql-20261103`.

Resultado comprobado: fuentes preparadas y **29/29 pruebas ligeras PASS**.
Chrome → API HTTPS → SQL real: **NOT RUN** en este host.
C6 no queda aceptada ni se declara lista para producción con estas comprobaciones.

## Cambios

| Ruta | Cambio |
| --- | --- |
| `tests/golden-path/golden_path.py` | Modo `browser`; protocolo privado y allowlist; checkpoints con oráculos existentes; límite de 300 s; cierre idempotente del grupo propio de Node/Chrome; metadatos saneados en evidencia existente |
| `tests/golden-path/browser_path.mjs` | Login Cashier real; stock; venta cantidad 2; recibo/recarga; venta cantidad 1 con respuesta HTTP 200 descartada mediante CDP; pendiente conservada y recuperación GET; otra recarga; stock; logout |
| `tests/test_golden_path_browser_safety.py` | 12 casos adversariales sobre frontera de evidencia, orden, barrera SQL, timeout y retirada del grupo propio |
| `tests/golden-path/README.md` | Interfaz reproducible, 11 checkpoints de navegador, seguridad y límites |
| `docs/c6-e2e-20261103/implementation.md` | Este resultado, evidencia y siguiente acción |

No se cambió producto, UI, backend, paquetes, lockfiles ni configuración.
El workflow pertenece al coordinador y se revisó únicamente en su copia scratch.
No se hicieron commits, push, instalaciones, SQL, arranques, Docker ni cambios de certificados.
No se tocaron `validation/` ni `outputs/` históricos.

## Contrato que debe comprobar CI

Se reutilizan exactamente setup, migrador EF de release, consola Owner, seed HTTP, `step`, oráculos,
escaneo, manifiesto y retirada de C5. `smoke` sigue siendo predeterminado; `serve` conserva su contrato.
La corrida browser planea 9 pasos de preparación, 11 checkpoints de navegador y 1 retirada.

1. Cashier inicia sesión mediante la UI real. `__Host-Savia.Session` exige Secure/HttpOnly/Strict, host loopback y Path=/.
2. Los seis recursos UI servidos por la API deben tener los mismos hashes que las fuentes actuales.
3. El inventario DOM debe mostrar 3 saldos y existencia total 30.
4. El formulario envía cantidad 2, ubicación y artículo, sin precio ni total. El recibo exige precio 1250 y total 2500 del servidor.
5. SQL debe ver 1 venta, 1 línea, 1 movimiento de venta, 1 operación y existencia 28.
6. Recarga y stock conservan recibo y conteos; no aparece otro POST de venta.
7. Otra venta de cantidad 1 usa otra clave. Chrome envía el POST al servidor real.
8. CDP pausa la respuesta real en `requestStage: Response`; exige HTTP 200 y recibo válido antes de `Fetch.failRequest`.
9. La UI debe mostrar pendiente, conservar la clave original y bloquear la venta nueva.
10. **Antes de permitir la recarga**, Python exige en SQL 2 ventas/líneas/movimientos de venta/operaciones y existencia 27.
11. Recarga recupera la misma venta mediante GET operations y la misma clave. Otra recarga conserva el recibo.
12. Ambas recargas y la consulta de stock conservan los conteos de negocio y exactamente 2 POST acumulados.
13. Logout deja 0 sesiones. Cada checkpoint exige 2 migraciones y cero violaciones de los 8 invariantes existentes.
14. La retirada debe detener API, borrar solo la base cuya creación fue confirmada y verificar ausencia; CI retira su contenedor propio.

La prueba adversarial usa datos simulados para afirmar que **la barrera rechaza** una supuesta segunda venta
comprometida cuando el oráculo solo ve una. No acredita que una venta SQL haya ocurrido.
El transporte no usa `route.fetch`, reenvíos, respuestas fabricadas ni API simulada.

## Evidencia y privacidad

`evidence.json` y `oracles.md` incluyen runtime Chrome/Node/Playwright; SHA-256 del arnés, ejecutor JS,
seis fuentes UI y binario Release; DOM comprobado; método/ruta sin query; HTTP y claves de operación.
La respuesta perdida se marca únicamente después de leer el recibo real en memoria.
El protocolo rechaza campos extra, rutas arbitrarias, claves no UUID y estados fuera de orden.

Credenciales solo viajan por stdin privado; cookies y CSRF se añaden al escáner de valores conocidos.
No se emiten cuerpos, cabeceras, conexiones, excepciones crudas, perfiles ni login recordings.
No se graban trace/HAR. Solo se publican los dos archivos verificados por `verify_evidence.py`.
El manifiesto `evidence-approved` conserva la promoción de bytes exactos y el cierre ante fallo.
El escaneo de valores conocidos no demuestra ausencia de secretos desconocidos.

Chrome recibe solo el SPKI del certificado efímero en un perfil privado nuevo.
No se modifica un almacén de confianza ni se usa `ignoreHTTPSErrors` o bypass TLS global.
Se bloquean peticiones fuera del origen HTTPS loopback.
Python limita el subprocess a 300 segundos y termina su grupo propio incluso ante fallo.
La incertidumbre de propiedad de la base conserva la política C5: no borrar una base sin confirmación de creación.

## Comprobaciones locales

| Comando / lectura | Resultado real | Límite |
| --- | --- | --- |
| `python -m unittest discover -s tests -p 'test_golden_path*_safety.py'` | `Ran 29 tests in 0.292s`, `OK`, exit 0: 17 C5 + 12 C6 | Dobles de proceso/SQL; sin runtime |
| `node --check tests/golden-path/browser_path.mjs` | Exit 0; sin salida | Solo sintaxis |
| `ast.parse` de `golden_path.py` y `test_golden_path_browser_safety.py` | `PYTHON_AST_OK 2 files`, exit 0 | No ejecuta POSIX/API/SQL |
| `git diff --check` | Sin errores de whitespace | No es aceptación funcional |
| Importación del Playwright instalado y `expect.configure({timeout:15000})` | `version=1.62.1`, `configure=function`, `configured=function` | CI solicita 1.63.0; esa versión no se ejecutó localmente |
| Tipos CDP del Playwright instalado | `requestStage`, `getResponseBody`, `failRequest` presentes | Contrato de API; sin ejercitar Chrome |
| `yaml.safe_load` del workflow scratch del coordinador | 17 pasos; una invocación `--mode browser` | Sintaxis YAML/estructura; no es actionlint ni ejecución Actions |

Paquete existente inspeccionado:
`C:/Users/Jason/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright`.
Workflow scratch leído:
`C:/Users/Jason/MARTHA-SILVA/coordination/c6-browser-sql-20261103/golden-path.yml`.

## Fallas resueltas y siguiente comprobación

| Evidencia / causa | Corrección aplicada y resultado | Dueño / cierre |
| --- | --- | --- |
| Primera corrida: 28 OK, 1 ERROR; Windows carece de `signal.SIGKILL` en el doble POSIX | El test fija la constante solo en su mock. Nueva corrida: 29/29 OK. El runtime sigue limitado a Linux/macOS | Resuelto en pruebas; no se cambió la política de proceso real |
| Revisión detectó `expect.setTimeout` sin contrato garantizado | Se usa `expect.configure({timeout:15000})`; importación real local confirma ambas funciones | Resuelto; versión CI 1.63.0 pendiente de CI |
| Doble señalización por `finally` y `teardown` | Se conserva exit y se limpia el handle. Test de idempotencia exige solo TERM/KILL una vez | Resuelto en doble; cierre Chrome real pendiente de CI |
| Chrome/API/SQL no ejecutados por el alcance local asignado | No se intentó un runtime no autorizado en Windows. Fuentes y comando exacto preparados para Linux CI aislado existente | Coordinador publica y verifica SHA/CI; cerrar solo con evidencias reales y retirada |

Lección aplicada: una respuesta HTTP 200 interceptada no basta para aceptar recuperación.
Se exige primero el estado SQL y solo después se permite continuar el navegador.
La prueba adversarial conserva esa barrera y evita convertir una afirmación del ejecutor en éxito.

## Comando para CI, no ejecutado localmente

Requisitos existentes en el runner: Node 24, Chrome, OpenSSL, Playwright 1.63.0 y binarios Release.
Usar la conexión del contenedor SQL desechable ya autorizado; nunca el piloto.

```sh
python3 tests/golden-path/golden_path.py --mode browser --no-build \
  --playwright-directory "$RUNNER_TEMP/c6-playwright/node_modules/playwright" \
  --out "$RUNNER_TEMP/c6-evidence" < /dev/null
python3 tests/golden-path/verify_evidence.py --source "$RUNNER_TEMP/c6-evidence" \
  --destination "$RUNNER_TEMP/c6-approved"
```

Aceptación pendiente: CI del SHA integrado con C5 y C6 completos, cero skips, tabla de oráculos,
recuperación sin otro POST/venta/débito, evidencia aprobada y retirada con readback de API/base/contenedor.
La revisión independiente, commit, publicación y Trello pertenecen al coordinador.
