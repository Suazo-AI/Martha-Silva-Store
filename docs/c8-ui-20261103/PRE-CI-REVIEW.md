# C8: revisión previa a CI

Estado: **PRE-CI verificado; aceptación final pendiente**.
Host: `SUAZO-PC`. Worker seleccionado: `gpt-6.1-sol`, razonamiento `xhigh`.
Candidato canónico leído: `Tony@2ddf83de7a89da608e8267a21313d64b373bf5e2`.
No ejecuté pruebas locales, SQL, API, Docker, servicios ni cambios externos.
No hice commit, push, merge ni despliegue.

## Verificado

Los seis blobs importados coinciden con el candidato canónico.

| Archivo | Blob esperado y observado | Resultado |
| --- | --- | --- |
| `dev/savia-staff-ui/README.md` | `f7f17b0f792586ce3d296e6bcb78b4e046a905d1` | PASS |
| `dev/savia-staff-ui/app.mjs` | `761eafa3e64ebca784d96c4465d052b2603c91be` | PASS |
| `dev/savia-staff-ui/auth.test.mjs` | `857e81996dc82a4a9e484e86099d2c9c00b09586` | PASS |
| `dev/savia-staff-ui/login.mjs` | `6a639cafe028fe28be9ab0539688afcaa7aef86b` | PASS |
| `tests/browser-mock-validation.mjs` | `199f8826515d0a3c1f3e6c8981d964b6fc3aeebd` | PASS |
| `backend/tests/Martha.Store.Api.Tests/InternalSecurityTests.cs` | `ee3b15ec123c93b5a073295fe4b4cb70b814d501` | PASS |

Las 71 entradas de dependencias coinciden al aplicar el overlay C8 esperado.
Son 66 blobs base intactos y cinco reemplazos C8 intencionales.
Es incorrecto describir los 71 como blobs base intactos después de aplicar el parche.
La prueba backend nueva es el sexto archivo C8 y se compara en la tabla anterior.

Los 48 archivos del inventario conservan sus SHA256.
Los dos TRX saneados siguen excluidos de publicación.
Leí solo sus contadores para verificar `1/1` y `49/49`, ambos sin FAIL ni SKIP.
El reporte JSON conserva sus hashes y contadores; no copia TRX ni logs.

La carpeta fuente exacta es `current-head-20261104/`.
No existe `current-head-validation-20261104/` en el área revisada.

## Evidencia reutilizada y cobertura

| Criterio | Evidencia reutilizada | Alcance comprobado |
| --- | --- | --- |
| N2 | 3 casos browser dentro de 45 | Cashier, Owner y Manager recuperan la clave original sin otro POST, incluso tras otra recarga. |
| N6 | 3 casos browser dentro de 45 | Cambio de actor, versión y ubicación legacy conservan el intento privado y evitan replay fuera del alcance. |
| N7 UI | 3 casos browser dentro de 45 | 401 revocado, 401 de expiración simulado y logout cancelan POST detenido en CSRF y descartan datos tardíos. |
| N7 API | 1 caso dentro de InternalSecurityTests 49 | Cookie protegida válida, reloj falso `8h+1s`, dos 401, cero resolución DB y control no expirado que alcanza la guarda productiva. |
| Auth/DOM | Staff JS 45/45 | Regresiones con dobles; respuesta tardía y revalidación concurrente no reviven acceso después de 401. |
| Browser completo | 45/45 | Chromium real con API sintética. No equivale a navegador → API → SQL. |

No sumar `9+45`, `1+49` ni `49+600`.
Los grupos menores están incluidos en los mayores.
La CI backend final debe localizar los 49 casos de seguridad y el caso de expiración dentro de sus 600.

Versiones históricas: Node `v24.18.0`, Chromium `156.0.8078.80`, SDK `10.0.402`.
Estas corridas se reutilizan; este worker ejecutó cero pruebas.
El hash histórico del arnés se registró después de las corridas.
El driver rojo modificaba solo `app.mjs` y `login.mjs`; conservó los nueve nombres de casos en rojo y verde.
El drift histórico fuera del cierre enfocado incluye una migración SQL y cinco clases de pruebas ajenas.
Los intentos legacy sin versión conservan su limitación documentada.

## Pedido mínimo para el cierre

Descargar únicamente estos artifacts del **mismo run y attempt final**:

1. `savia-browser-evidence-<run_id>-<run_attempt>`: leer `browser-results.json`.
2. `savia-backend-outcomes-<run_id>-<run_attempt>`: leer `sanitized-results.json`.

Añadir un snapshot autenticado de run/jobs/steps con SHA, evento y revisión del workflow.
Añadir el resumen saneado del step staff: `tests=45`, `pass=45`, `fail=0`, `cancelled=0`, `skipped=0`, `todo=0`, `exit=0`.
Staff no tiene un artifact propio en `savia.yml`.
Si CI usa un merge ref, comparar su árbol con el candidato final.
Conservar el binding final de los seis blobs y las 71 entradas.

Exigir browser `45/45`, incluidos los nueve nombres C8.
Exigir backend `cases=600`, `passed=600`, `notPassed=0`, sin `methodsNotPassed`.
Dentro de backend, exigir seguridad `49/49` y expiración `1/1` por método.
No se necesita una corrida adicional de seguridad o expiración.
Exigir ejecución real de los jobs/steps requeridos; un estado verde no basta.
No descargar TRX ni logs crudos.

## Bloqueos y siguiente acción

| Bloqueo | Hecho y causa | Corrección realizada | Siguiente acción, dueño y cierre |
| --- | --- | --- | --- |
| Candidato final | Solo se verificó `2ddf83d`. Root informó que PR2 divergió y `b6bc039` no contiene los seis blobs. | Comparé los seis blobs y las 71 entradas del candidato canónico. Este worker no tiene ownership Git. | Root integra y congela el SHA final. Cierre: blobs esperados y árbol probado vinculados al candidato publicado. |
| CI final | La única consulta GitHub devolvió `9 passed, 0 failed, 3 skipped, 12 total`, sin SHA en la salida compacta. | Leí rutas de artifacts y schemas. No hubo polling ni nueva ejecución. | Root entrega los dos artifacts y snapshots anteriores. Cierre: conteos y métodos reales del mismo SHA, sin omisiones requeridas. |

C8 conserva `doing` en el ledger leído.
No modifiqué ledger, Trello ni aceptación.
No marco READY de Jason.
Quedo congelado hasta recibir el snapshot final de root.

## Uso y límites

Una consulta GitHub inicial. Cero consultas posteriores.
Cero llamadas pagadas adicionales fuera del worker autorizado.
Tokens, caché, razonamiento y USD no están expuestos por esta herramienta.
Dos errores de extracción se corrigieron sin cambiar fuentes: raíz JSON de lista y salida `cp1252`.
La evidencia estructurada completa está en [source-evidence.json](source-evidence.json).
