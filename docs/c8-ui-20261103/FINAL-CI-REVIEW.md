# C8: revisión final de CI

**PASS técnico C8** en `e4b7910835bf2c9901aa06989e296997875a3636`.
No marco READY de Jason.
Los tres casos pendientes N5-COV conservan sus brechas de cobertura.

Run [41765611859, attempt 1](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41765611859).
Evento `pull_request`; workflow `.github/workflows/savia.yml`.
Ambos jobs y todos sus steps figuran `completed/success`.
No se acepta C8 por ese estado verde: se contrastaron los resultados y las fuentes.

## Resultado verificado

| Comprobación | Resultado |
| --- | --- |
| Seis blobs C8 contra candidato final | 6/6 MATCH |
| Dependencias con overlay C8 | 71/71 MATCH: 66 base y cinco reemplazos C8 |
| SHA256 browser contra bytes Git exactos | 6/6 MATCH |
| Staff JS | 45/45; FAIL 0, SKIP 0, cancelled 0, todo 0 |
| Browser completo | 45/45 PASS |
| Casos C8 dentro de browser | 9/9 PASS: N2×3, N6×3, N7×3 |
| Backend completo | 600/600; notPassed 0 |
| Seguridad dentro de backend | 49/49; 17 métodos |
| Expiración dentro de seguridad | 1/1 PASS |

La suma de casos y PASS de los 257 métodos backend coincide con `600/600`.
No sumar los nueve casos C8 a los 45 browser.
No sumar expiración a seguridad, ni seguridad a backend.
No repetí pruebas locales ni inicié runtime.

## Vinculación del candidato

El runner staff registró checkout `f1a0bb1d0cd0258838f920ec8f811315820c7587`.
El compare suministrado tiene base y merge-base `e4b7910835bf2c9901aa06989e296997875a3636`, `files=[]` y `too_large=null`.
No contiene cambios de archivos frente al candidato.
Los dos artifacts registran el mismo run, attempt y head.
Los seis SHA256 del browser se calcularon contra bytes de blobs Git; se evita la conversión CRLF de Windows.

| Archivo C8 | Blob final y esperado | Resultado |
| --- | --- | --- |
| `dev/savia-staff-ui/README.md` | `f7f17b0f792586ce3d296e6bcb78b4e046a905d1` | PASS |
| `dev/savia-staff-ui/app.mjs` | `761eafa3e64ebca784d96c4465d052b2603c91be` | PASS |
| `dev/savia-staff-ui/auth.test.mjs` | `857e81996dc82a4a9e484e86099d2c9c00b09586` | PASS |
| `dev/savia-staff-ui/login.mjs` | `6a639cafe028fe28be9ab0539688afcaa7aef86b` | PASS |
| `tests/browser-mock-validation.mjs` | `199f8826515d0a3c1f3e6c8981d964b6fc3aeebd` | PASS |
| `backend/tests/Martha.Store.Api.Tests/InternalSecurityTests.cs` | `ee3b15ec123c93b5a073295fe4b4cb70b814d501` | PASS |

Los seis hashes browser incluyen `app.mjs`, `client.mjs`, `login.mjs`, `login.html`, `index.html` y `styles.css`.
El JSON adjunto conserva cada SHA256 esperado y observado y las 71 entradas.

## Casos C8 ejercidos en CI

| Caso nombrado en el artifact | Resultado |
| --- | --- |
| N2 Cashier reload recovers the same uncertain attempt without another sale (C8) | PASS |
| N2 Owner reload recovers the same uncertain attempt without another sale (C8) | PASS |
| N2 Manager reload recovers the same uncertain attempt without another sale (C8) | PASS |
| N6 changing actor keeps the uncertain key private and never replays it as the new actor (C8) | PASS |
| N6 changed actor version preserves the attempt and blocks recovery and resend under the new scope (C8) | PASS |
| N6 legacy attempt outside the current authorized locations stays private and cannot be replayed (C8) | PASS |
| N7 revoked mocked 401 discards late stock and cancels a sale waiting for CSRF (C8) | PASS |
| N7 absolute-expiry mocked 401 discards late stock and cancels a sale waiting for CSRF (C8) | PASS |
| N7 logout cancels a sale awaiting CSRF and discards its late response (C8) | PASS |

N2 comprueba la misma clave y un único POST tras recuperar y recargar.
N6 conserva el intento privado al cambiar actor, versión o ubicación legacy.
N7 UI cancela la escritura detenida en CSRF y descarta respuestas tardías después de 401 o logout.
La expiración API es un caso distinto: cookie válida protegida, TimeProvider falso y control no expirado.
Sus dos 401 expirados mantienen cero resoluciones DB; el control no expirado alcanza la guarda productiva.
Esta descripción proviene del test congelado leído antes; su método aparece ahora `1/1 PASS` en el artifact final.

## Procedencia y límites

La diferencia inicial de hashes staff quedó resuelta.
El wrapper TOON tiene SHA256 `fa65771d9f5fa450ec518e69b915ebad7a5cac033d0af68d3141e26d64415cd2`.
El archivo completo señalado por `full_log` tiene SHA256 `8df416c3a7457057ca944074c6c51be00d330ae7d674747d7cfbceda40dee675`.
Son objetos distintos.
`log-provenance.json` y el resumen regenerado registran ambos.
Las siete líneas de contadores del resumen coinciden con sus campos numéricos.
Este worker no copió ni volvió a hashear el log completo.
Root obtuvo su resumen y procedencia mediante recuperación autenticada.

El browser registra nueve `requestfailed`: siete ventas abortadas y dos logout abortados durante navegación.
El código congelado contiene las inyecciones de aborto de venta.
Los nueve eventos permanecen en el JSON; no se ocultan.
Hay cero errores runtime y cero solicitudes externas.
Los 45 casos pasan.

Browser ejecuta Chromium real con respuestas API sintéticas.
Staff usa dobles DOM/transporte.
La expiración usa TestServer y reloj falso; no prueba una sesión real con SQL.
Versiones observadas en este browser CI: Node `v24.22.2`, Chromium `156.0.8078.79`.
La evidencia histórica rojo/verde sigue reutilizada.
Su hash del arnés se registró después de aquellas corridas; ese límite permanece.
Los intentos legacy sin versión conservan el límite documentado.
Este informe no acepta C6, C9, C11, producción ni dispositivos.

## N5-COV: tres casos siguen pendientes

Los cinco casos N5 actuales aparecen PASS en el artifact.
Su alcance no cubre estos tres escenarios completos.

| Criterio pendiente | Cobertura actual | Brecha |
| --- | --- | --- |
| Venta deshabilitada durante recuperación | `app.mjs:492-513` bloquea con busy/lock; `commerce.test.mjs:48-56` y browser `240-244` comprueban recuperación y clave. | No hay respuesta de recuperación retenida con intento de submit y aserción durante ese intervalo. |
| Venta nueva completa tras descartar recibo obsoleto | Browser `221-227` comprueba submit habilitado tras 404; `230-238` cubre 403/503. | El mismo caso no envía ni completa una venta nueva después del descarte. |
| Carrera 404 | `app.mjs:476-490` verifica generación/actor; los 404 N5 actuales responden de inmediato. | No hay 404 tardío controlado que compita con otra acción y ejercite el oráculo pendiente. |

Son brechas de cobertura; no afirmo un defecto de producto sin reproducción.
No cambié los criterios C8 ni N5.
No ejecuté estos escenarios porque este lote permite únicamente revisión y mapeo.
Dueño: root/FIX.
Siguiente acción: ejercitar los tres casos exactos ya pendientes en el ledger con su criterio vigente.
Cierre: evidencia directa de cada escenario; no basta sumar pruebas adyacentes.

## Bloqueos cerrados

El candidato final quedó vinculado con seis blobs, 71 dependencias y seis hashes browser.
CI dejó de estar pendiente tras revisar los artifacts y los steps del mismo run.
La procedencia staff distingue wrapper y log completo, y registra el checkout del runner.
No queda una brecha técnica de la aceptación C8 congelada en este bundle.
La aceptación formal de Jason y las tres brechas N5-COV permanecen separadas.

## Evidencia segura revisada

| Archivo bajo `coordination/c8-ci-41765611859/` | SHA256 |
| --- | --- |
| `run-binding.json` | `8ab656e51c585e6d3de72e3e37333161a5b796952da839013b40e9baa10850bb` |
| `staff-summary.json` | `14d54c5133534dfdba8513e2ac4343cbc287767de72ba0e2889a7625d08a127f` |
| `log-provenance.json` | `b748d8edde7a8f009d400dcf7e6110a53034066033a9dec35a99b04e3625a1f1` |
| `browser/browser-results.json` | `b2431b8f822d452ed3ab4c68ce659f243b33bf34e8baba5c02216894675b40d0` |
| `backend/sanitized-results.json` | `4afe8bcf8e774f8845cc1ecc800cea2db64fa9f6f750ebbef75815311d6a486d` |

Los artifacts son `savia-browser-evidence-41765611859-1` y `savia-backend-outcomes-41765611859-1`.
El JSON adjunto conserva IDs, digests GitHub, métodos, nombres de casos, comparaciones y límites.
No contiene TRX, logs crudos, tickets, certificados ni datos reales.

Este lote hizo cero llamadas GitHub, cero escrituras Git/checkout/índice/refs y cero cambios Trello.
Tokens y USD del worker no están expuestos.
Root recibe [final-ci-evidence.json](final-ci-evidence.json) para incorporar la evidencia y conservar N5-COV pendiente.
