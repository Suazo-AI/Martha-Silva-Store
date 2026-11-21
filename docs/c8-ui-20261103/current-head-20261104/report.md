# C8 sobre el candidato actual

C8 quedó aplicado localmente sobre `260b75951729189d987ffe423218ab1643bcfa3c`.
CI del candidato con ambos parches sigue pendiente.
El worktree queda modificado de forma intencional.

## Verificado

Los dos parches originales pasaron `git apply --check` y `git apply`, con exit `0`.
Los seis archivos coinciden byte por byte con los archivos probados anteriores.
Coinciden 71 blobs de dependencias entre `775f301bc195c43baedc68c86f4e71affe92ef95` y la base actual.
También coinciden los 12 archivos staff y los 1082 archivos públicos `dist` con la copia probada.

La evidencia se **REUTILIZA**.
Este lote ejecutó cero pruebas nuevas.
Los resultados anteriores son: browser enfocado `9/9`, browser completo `45/45`, staff `45/45`, API expiración `1/1` e `InternalSecurityTests` `49/49`.
Los TRX sanitizados se leyeron y sus contadores coinciden.
Versiones de esas ejecuciones: Node `v24.18.0`, Chromium `156.0.8078.80`, SDK `.NET 10.0.402`.

`git diff --check`, `git apply --check --cached candidate.patch` y `git apply --reverse --check candidate.patch` terminaron con exit `0`.
El diff tiene seis archivos, `246 insertions(+)` y `18 deletions(-)`.

## Cambios exactos

- `dev/savia-staff-ui/README.md`: documenta los límites y las pruebas C8.
- `dev/savia-staff-ui/app.mjs`: vincula el intento pendiente con la versión del actor y conserva su clave al cambiar el alcance.
- `dev/savia-staff-ui/auth.test.mjs`: agrega regresiones de respuestas tardías y cancelación de escrituras.
- `dev/savia-staff-ui/login.mjs`: invalida respuestas y escrituras de una sesión anterior, incluso después de obtener CSRF.
- `tests/browser-mock-validation.mjs`: agrega nueve casos C8 y soporte acotado para video.
- `backend/tests/Martha.Store.Api.Tests/InternalSecurityTests.cs`: prueba expiración real del middleware con cookie sintética, TimeProvider falso y contador de resolución DB.

## Procedencia y límites

[binding.json](binding.json) registra SHA256, blobs, comandos, comparación de origen/destino y hashes de la evidencia histórica.
[verification.json](verification.json) registra resultados reutilizados, estado y límites.
[candidate.patch](candidate.patch) contiene únicamente los seis archivos.

SHA256 de `candidate.patch`: `a0762dc021260f4c8c88b849552c4775c6bef17af06c5338e68e95cd7a221df0`.

El drift backend observado consiste en una migración SQL y cinco clases de pruebas ajenas.
No cambió ningún C# productivo ni el cierre de dependencias del caso de expiración.
El caso fake-cookie usa TestServer y rechaza antes de configurar SQL.
No se ejecutó SQL.
La prueba browser de 401 simulado y la prueba API de TimeProvider siguen siendo evidencias distintas.
Los intentos legacy sin versión conservan la limitación histórica: no se reenvían y solo permiten recuperación con ubicación actualmente autorizada.
El hash histórico del arnés se registró después de las ejecuciones; esa limitación permanece documentada.

No se modificaron seguridad productiva, configuración, paquetes, ledger ni PROJECT-STATUS.
No se hizo commit, push, PR, merge ni despliegue.
No se crearon procesos persistentes ni recursos que limpiar.

## Pendiente y traspaso

La CI de la base no cubre estos seis archivos nuevos.
No se intentó publicar porque este lote no tiene autorización para ello.
Primary recibe el ownership para revisar el patch y su vinculación de evidencia.
El cierre exige una CI autorizada que cubra estos mismos bytes.
El worker libera el worktree al entregar este informe.

Lección aplicada: comprobar bytes y dependencias permite reutilizar evidencia sin repetir suites ni atribuirles una ejecución nueva.
