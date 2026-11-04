# C8: validacion local, pendiente de revision y CI

Host: SUAZO-PC. Worker: gpt-6.1-sol, high. Fecha local: 2026-11-03.
Rama: `task/c8-n2-n6-n7-20261103`.
Base: `775f301bc195c43baedc68c86f4e71affe92ef95`.
Tarjeta: https://trello.com/c/61IxxolB.

N2 conserva el mismo intento despues de recargar para Cashier, Owner y Manager.
Esto ya funcionaba en la base; no se fabrico un fallo ni se cambio ese comportamiento.
N6 conserva la clave y liga intentos nuevos a `actorVersion`.
Una version distinta o una ubicacion fuera del ambito actual bloquea recuperacion y reenvio.
N7 invalida respuestas del cliente despues de 401/logout y evita POST de una venta que aun espera CSRF.
N5 permanece cubierto en el arnes completo.

| Etapa | PASS | FAIL | Exit |
| --- | ---: | ---: | ---: |
| Baseline original, primer arnes | 4 | 4 | 1 |
| Baseline con errores del arnes corregidos, antes de modificar producto | 4 | 4 | 1 |
| Primer verde | 8 | 0 | 0 |
| Verde final, incluye legado fuera de ambito | 9 | 0 | 0 |
| Solo app.mjs revertido a base; mismas nueve pruebas | 7 | 2 | 1 |
| Solo login.mjs revertido a base; mismas nueve pruebas | 6 | 3 | 1 |
| Arnes completo, producto restaurado | 45 | 0 | 0 |
| Staff JS completo | 45 | 0 | 0 |

Chrome `156.0.8078.80`. Node `v24.18.0`.
El arnes completo incluye 36 casos existentes y 9 nuevos.
Staff incluye 42 existentes y 3 nuevos de respuesta tardia en headers/body y revalidacion concurrente.
No hubo errores JavaScript no capturados ni solicitudes externas en las siete etapas.
Los abortos de respuesta de venta son deliberados para simular resultado incierto.

## Fallos, correcciones y limites

El primer arnes disparaba 401 antes de iniciar la venta en dos casos.
Ademas esperaba networkidle mientras retenia logout en el tercer caso.
Se corrigieron solo estas condiciones del arnes; no se relajaron sus expectativas.
La primera salida se conserva en `baseline` y no prueba tres defectos de producto.

El baseline corregido expuso cuatro fallos reales.
N6 mostraba `Venta confirmada por el servidor.` bajo una version diferente.
N7 envio `1` POST despues de 401 en cada variante y `1` despues de iniciar logout.
Revertir solo app.mjs reproduce N6 cambiado y legado fuera de ambito.
Revertir solo login.mjs reproduce los tres POST tardios de N7.
El driver restaura producto byte por byte en `finally` y nunca modifica pruebas.

El SHA del arnes se registro despues de las corridas, no dentro de cada salida historica.
El driver solo escribe app.mjs/login.mjs; las nueve pruebas permanecieron iguales entre rojo y verde final.
Los hashes de producto de cada corrida estan en [verification.json](verification.json).

Los intentos historicos sin version conservan esa incertidumbre.
Solo pueden consultar recuperacion si su ubicacion sigue en la lista autorizada del servidor.
No pueden reenviarse ni reciben una version nueva.
La API sigue siendo la autoridad; `InternalDirectoryEndpoints.ListLocations` aplica `InternalBranchAccess`.
Si el intento queda bloqueado por cambio de acceso, el responsable debe conciliar la clave original.
No se borra el intento para habilitar otra venta.

`absolute-expiry` es un 401 simulado en navegador.
No se ejecuto una prueba de expiracion absoluta en API con TimeProvider falso.
La fuente existente verifica `ExpiresAt <= now` y conserva pruebas de reglas/SQL con reloj fijo.
Eso no acredita ejecucion API en esta tarea.

CI del nuevo diff no ejecutado: commit/push/PR estan prohibidos para este lote.
SQL real, datos reales, politica/configuracion de seguridad, certificados, Docker y despliegue no se tocaron.
No hay aceptacion visual de Jason ni cierre integral C8.
Owner de SDK/CI pendientes: primary/Jason. Facilitar SDK 10.0.402 existente o autorizar su instalacion; autorizar push para CI.
La prueba API offline no requiere permiso SQL.
Completion check pendiente: CI del candidato nuevo y prueba API TimeProvider offline con SDK compatible.

## Repetir

Desde `C:/Users/Jason/MARTHA-SILVA/test-runs/c8-n2-n6-n7-20261103`:

```powershell
$env:MARTHA_BROWSER_TEST_MATCH='(C8)'
$env:MARTHA_BROWSER_RECORD_VIDEO='1'
node tests/browser-mock-validation.mjs 'C:/Users/Jason/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright' '<directorio-nuevo-de-evidencia>'
# MATCH usa includes literal, no expresion regular. Esperar exactamente 9 casos.
Remove-Item Env:MARTHA_BROWSER_TEST_MATCH -ErrorAction SilentlyContinue
Remove-Item Env:MARTHA_BROWSER_RECORD_VIDEO -ErrorAction SilentlyContinue
node tests/browser-mock-validation.mjs 'C:/Users/Jason/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright' '<directorio-nuevo-full>'
$env:NODE_PATH='C:/Users/Jason/MARTHA-SILVA/github/tests/frontend-deps/node_modules'
node --test dev/savia-staff-ui/*.test.mjs
# NODE_PATH solo afecta este proceso hijo; no cambia entorno global.
```

Comandos efectivamente ejecutados: mismos comandos con salidas privadas `baseline`,
`baseline-corrected-harness`, `green`, `green-final` y `full` bajo el directorio siguiente.
Rojo selectivo: `python C:/Users/Jason/MARTHA-SILVA/test-runs/c8-n2-n6-n7-20261103-evidence/red-proof.py`.
`git diff --check` paso. No hubo commit, push, merge ni mutacion de Trello.

## Artefactos y entrega

[ui.patch](ui.patch) contiene los cinco archivos modificados de producto, pruebas y README.
[verification.json](verification.json) contiene hashes, resultados, errores y limites sanitizados.
[cleanup.json](cleanup.json) confirma cero listeners propios y cero procesos del arnes.
El checkout canonico no fue modificado por este worker.
La rama aislada queda modificada intencionalmente para revision del primary.
Primary conserva ownership de la aceptacion y exportacion documental al checkout canonico.
Aplicar el parche requiere revisar la base; Tony puede tener otra historia.

Evidencia privada completa, logs y videos:
`C:/Users/Jason/MARTHA-SILVA/test-runs/c8-n2-n6-n7-20261103-evidence`.

Grabacion original antes: `baseline-corrected-harness/videos/n6-changed-version.webm` (390x844).
Grabacion despues: `green-final/videos/n6-changed-version.webm` (390x844).
Los archivos `n7-revoked.webm`, `n7-absolute-expiry.webm` y `n7-logout.webm` repiten secuencia a 1440x1000 en ambos directorios.
N2 Cashier/Owner/Manager y N6 otro actor tambien tienen antes/despues a 1440x1000.
El video legado en `red-app-only` es una restauracion posterior del baseline, no una grabacion original previa al primer cambio.
No exportar videos ni logs privados al repositorio publico sin revision.

Leccion aplicada: esperar networkidle con una respuesta retenida prueba un bloqueo del arnes.
La sincronizacion corregida espera las respuestas concretas y conserva el oraculo de cero POST.
El rojo-verde selectivo confirma que los defectos restantes pertenecen al producto.

## Intento de cerrar expiracion API, mismo lote

Se comprobo la ruta offline TestServer sin SQL y no se agrego un test que no pueda ejecutarse.
El proyecto requiere `net10.0`; `global.json` exige SDK `10.0.402`.
Solo esta instalado SDK `8.0.422`. Los paquetes cacheados no sustituyen al SDK.
El unico intento `dotnet test --no-restore` fallo antes de compilar, exit `-2147450735`.
Error exacto: `A compatible .NET SDK was not found.`
No se instalo SDK, no se cambio global.json y no se ejecuto restore de red.

[api-prerequisite.json](api-prerequisite.json) conserva comando, SDK, exit y hash del log privado.
[api-expiry-handoff.md](api-expiry-handoff.md) fija la prueba offline pendiente y su comando.
El parche conserva cinco archivos; no incluye cambios backend no ejecutados.
