# Sprint 4–6 nov: venta segura por cajero — estado al cierre del 3-nov

**Resultado.** N5 está corregido y probado en navegador real con ciclo rojo-verde-revert. El backend completo (592 casos) pasa contra SQL Server real, incluidos los dos casos de release/restart que estaban NOT RUN. Un workflow nuevo, `savia.yml`, hace que CI juzgue SAVIA en el PR de integración. Esto no es aceptación del producto ni producción: falta el recorrido combinado navegador → API → SQL y el ensayo en tienda.

- Plan del lote: [PROMPT](PROMPT.md). Reparto: Trello https://trello.com/b/pq9G9Qqj/martha-silva (C1–C12, Jason y Denis Alvarez).
- Prácticas adoptadas de los 19 repositorios, con SHA: [PRACTICAS-19-REPOS](PRACTICAS-19-REPOS.md). Cuestionario para la tienda: [CUESTIONARIO-MARTHA](CUESTIONARIO-MARTHA.md).
- Evidencia curada y hashes: [evidence.json](evidence.json).
- **4-nov:** C4 (script de release completo) y C7 (N1, N3, N4, N8 y N9 por HTTP con cero escrituras medidas en SQL): [C4-C7](C4-C7.md). Flujo de avance automático: [pipeline](../pipeline/README.md); prompt revisado: [PROMPT-AUTONOMO](PROMPT-AUTONOMO.md).

## Candidato y entorno

Base `Tony` `20932d5c97f2caaafad7dc888879957791907f36` más los cambios de esta rama (`claude/funny-brahmagupta-5e5rj0`). Contenedor Linux en la nube, **no SUAZO-PC**: Node 22.23.4, Python 3.13, .NET SDK 10.0.402, SQL Server 16.0.4305.5 Developer (la misma imagen fijada por digest en `backend.yml`) y Chrome for Testing 153 mediante Playwright 1.63.0. Los resultados de Windows, Chrome estable e iPhone no se infieren de aquí.

## N5: un recibo histórico inaccesible bloqueaba todas las ventas

**Causa confirmada.** En `start()` de `dev/savia-staff-ui/app.mjs`, un único `catch` convertía cualquier error al restaurar el último recibo en `pending ||= {}`. Ese objeto no tiene `key`: el formulario, "Comprobar" y "Reintentar" quedaban deshabilitados y la pantalla decía "La venta sigue sin confirmar" aunque no hubiera venta pendiente.

**Cambio mínimo.** `restoreReceipt` separa el recibo histórico de la operación pendiente. Una referencia de recibo solo existe después de que el servidor confirmó la venta, así que no poder mostrarla nunca crea una venta incierta.

| Respuesta al pedir el último recibo | Comportamiento |
| --- | --- |
| 200 del mismo actor | Muestra el recibo (sin cambios) |
| 403 o 404, u otro actor | No lo muestra, borra la referencia y avisa que ya no está disponible |
| 5xx, red o contrato inválido | Conserva la referencia y avisa que no se pudo cargar |
| 401 | Cierra la sesión, como antes |
| Hay una operación pendiente real | Sigue bloqueando ventas nuevas y se recupera con su clave original |

**Pruebas en la costura correcta (navegador).** `tests/browser-mock-validation.mjs` conserva el caso original de N5 y añade cuatro: 403 tras reasignación, 503 transitorio, pendiente real con recibo obsoleto, y 401 durante la restauración.

| Paso | Comando | Resultado |
| --- | --- | --- |
| Rojo antes del cambio, en `20932d5` | `MARTHA_BROWSER_TEST_MATCH='Stale confirmed receipt' node tests/browser-mock-validation.mjs <playwright> <salida>` | FAIL: enviar, comprobar y reintentar deshabilitados |
| Verde con el cambio | `MARTHA_BROWSER_TEST_MATCH='(N5)' node tests/browser-mock-validation.mjs <playwright> <salida>` | 5/5 PASS |
| Cambio revertido, pruebas intactas | igual | 3 FAIL (404, 403, 503) y 2 PASS (guardas que ya eran correctas) |
| Arnés completo | `node tests/browser-mock-validation.mjs <playwright> <salida>` | 36/36 PASS |
| Pruebas del personal (dobles jsdom) | `NODE_PATH=tests/frontend-deps/node_modules node --test dev/savia-staff-ui/*.test.mjs` | 42/42 PASS |
| Suite portable | `python3 tests/check.py --install` | PASS |

Capturas sintéticas: antes, [stale-receipt.png](../testing-20261103/evidence/stale-receipt.png); después, [n5-stale-receipt-after-fix.png](evidence/n5-stale-receipt-after-fix.png).

Un defecto de mi propia prueba quedó registrado: el primer intento del caso 401 hacía clic en "Ventas" cuando la sesión ya estaba cerrada. Los perfiles que no son Owner abren en Inventario, que inicia ventas de inmediato (`app.mjs:319`). Se corrigió la secuencia del test y se añadió una aserción de que la consulta del recibo sí ocurrió; el producto no cambió por ese motivo.

## Backend y SQL real

| Capa | Resultado | Nota |
| --- | --- | --- |
| Restore bloqueado y build | PASS, 0 advertencias | `dotnet restore backend/Martha.Store.slnx --locked-mode`; `dotnet build ... -c Release` |
| Sin SQL | 522 PASS, 1 FAIL, 69 SKIP | El FAIL pide `SAVIA_PILOT_EVIDENCE`, igual que en SUAZO-PC |
| Suite completa con SQL (sin el restart) | 591/591 PASS | 21 Store migrados, 46 Internal y HTTP con SQL; bases desechables `MarthaSynthetic_Test_*` y `SaviaInternalTest_*` |
| Release: migrador real, reaplicar, down/up, `BACKUP ... WITH CHECKSUM`, `RESTORE VERIFYONLY`, restauración | PASS | NOT RUN en SUAZO-PC porque usa rutas de SQL en Linux |
| Restart: stop/start controlado del contenedor | PASS | 15 s hasta listo; esquema, datos y rechazos intactos |
| **Total** | **592/592 PASS, 0 SKIP** | `python3 backend/tests/verify_full_suite.py --min-tests 592 <resultados>` |
| Job SQL actual de `main` (`Category=SqlServer` + `verify_sql_results.py`) | 21/21 PASS; verificador PASS | Integrar Tony a `main` no rompe ese job |
| Job de guardas de `backend.yml` (`Category!=SqlServer`) | Rojo en el CI del PR #2: 1 FAIL; corregido: 523 PASS, 0 FAIL, 48 SKIP | El caso offline de scripts de release necesita `SAVIA_PILOT_EVIDENCE`; el paso ahora le da una carpeta propia. Los 48 skips son los casos con SQL, que `savia.yml` sí ejecuta |

**Oráculo de esquema.** El caso de release compara el esquema contra `expected-invariants.json`, que solo existe en la evidencia privada de SUAZO-PC. Para no evaluar la base contra sí misma, se generó [expected-invariants.model-derived.json](../../backend/tests/fixtures/expected-invariants.model-derived.json) desde el modelo EF con `EnsureCreated`, un camino independiente de las migraciones escritas a mano: 19 tablas, 32 checks, 26 FK, 37 índices y 19 PK. Las migraciones, incluida `20261027224500_InternalBranchScope`, producen exactamente ese esquema. Ese archivo no reemplaza el oráculo privado: la tarjeta C4 exige compararlos.

## CI nuevo: `.github/workflows/savia.yml`

- Se ejecuta en PR hacia `main` (solo ramas de este repositorio para el job SQL), push a `main` y ejecución manual.
- Job 1: pruebas del personal y arnés de navegador con el Google Chrome del runner; sube evidencia sintética 7 días.
- Job 2: la suite completa contra SQL Server 2022 Developer desechable, con contraseña aleatoria enmascarada y puerto solo en loopback. Copia el oráculo derivado del modelo, reinicia el contenedor para la prueba de persistencia y exige que pasen 592 casos sin ningún skip. Sube solo contadores y nombres de métodos (`verify_full_suite.py` descarta argumentos y diagnósticos, porque algunos casos usan marcadores sintéticos parecidos a secretos). Destruye el contenedor siempre.
- `ci.yml` no cambia. En `backend.yml` solo cambia el paso de guardas, que ahora da al caso offline de scripts de release su carpeta de evidencia. Ningún workflow despliega ni publica.
- El job SQL se reprodujo localmente paso por paso: 592/592 y oráculo intacto durante la corrida.

## Correcciones a afirmaciones previas

- Afirmé durante la sesión que el verificador SQL de `main` fallaría al integrar Tony. Era falso: Tony ya lo actualizó a 21 casos, y se comprobó con 21/21 y el verificador en PASS.
- El bloqueo "WinError 1314" de [testing-20261103](../testing-20261103/README.md) ya está cerrado: el CI Linux de Tony ejecutó esas suites en `20932d5` ([run 41718312660](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41718312660)): auditoría 6/6 y staging 10/10.
- Integrar Tony a `main` **sí** rompía `backend.yml`, pero en el job de guardas, no en el job SQL: el caso offline de scripts de release falla sin `SAVIA_PILOT_EVIDENCE`. Nunca había corrido en CI porque Tony no tenía PR. Lo detectó el CI del PR #2 y se corrigió en el workflow, sin tocar la prueba.
- El primer push de `savia.yml` no arrancó: usaba el contexto `runner` en el `env` del job, donde GitHub no lo admite. Corregido.
- `main` no tiene protección de rama ni checks requeridos. "Fusionar cuando pasen los checks requeridos" no tiene freno hasta configurarlos (tarjeta C1).

## Integración con Tony

Estos commits no traen recibo de progreso: `tools/progress.py` solo funciona en la rama `Tony` de SUAZO-PC, y no se falsificó ninguno. Para llevarlos a Tony hay que hacer un merge local en SUAZO-PC, y el hook agregará el recibo del merge. Un fast-forward dejaría `HEAD` sin recibo y `progress.yml` fallaría.

Archivos tocados:
- `dev/savia-staff-ui/app.mjs`
- `tests/browser-mock-validation.mjs`
- `.github/workflows/savia.yml` y el paso de guardas de `.github/workflows/backend.yml`
- `backend/tests/verify_full_suite.py`, `backend/tests/test_verify_full_suite.py`
- `backend/tests/fixtures/expected-invariants.model-derived.json`
- `docs/sprint-20261104/`
- Encabezados de `docs/PROJECT-STATUS.md`, `docs/AGENT-START.md`, `docs/delivery-20261031/NEXT-INCREMENT.md` y `docs/CI-CD.md`

## Qué no se ejecutó

- El recorrido combinado navegador → API real → SQL con migraciones de release (tarjetas C5 y C6).
- N1–N4 y N6–N10 como pruebas automatizadas sobre el candidato (C7, C8 y C11).
- Chrome estable en Windows, iPhone, accesibilidad, rendimiento en la caja y ensayo con la persona que vende (C10).
- La comparación con el oráculo privado de SUAZO-PC (C4) y la medición de RTO/RPO en el entorno real (C9).
- El CI de este PR se registra en el PR al terminar; un resultado local no lo sustituye.
- No se desplegó nada; el original de Cloudflare sigue intacto.
