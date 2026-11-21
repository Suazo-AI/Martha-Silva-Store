# Aprendizaje y próximas acciones

Abrir [backlog.html](backlog.html) directamente, sin servidor, instalación ni conexión.
El tablero organiza aprendizaje de Jason aplicado a SAVIA y revisión independiente de código de IA.
El [ledger](../pipeline/ledger.json) conserva la autoridad sobre el proyecto.

## Uso

- Abrir una tarjeta para editar objetivo, criterio, intento, evidencia, recursos y próxima acción.
- Cambiar columna y prioridad desde el diálogo. Las columnas son To do / In progress / Done; orden P1, P2, P3, luego `order`, luego `id`.
- Usar «Dejar para después» con un motivo: guarda en To do y registra motivo y fecha en historial.
- Done exige evidencia. Aprendizaje exige además Sin ayuda o Transferido. Con ayuda conserva el intento, sin acreditar independencia.
- Reabrir una tarea cambiando su columna. Cambiar resultado no borra evidencia ni historial.
- Exportar JSON antes de cambiar de equipo o entregar cambios al agente. «Guardar copia HTML» incorpora el estado completo en otra página portátil.

Hay nueve ejercicios iniciales, todos Sin evaluar y sin evidencia. L01 comienza In progress; Done comienza vacío.
Los tres seguimientos de proyecto son reportes anteriores pendientes de leer la fuente vigente.
Done de proyecto no significa aceptación operativa ni producción.
Los recursos externos son enlaces opcionales; el tablero funciona sin visitarlos.

## Registro durable y continuidad

`<script type="application/json" id="backlog-data">` contiene el registro durable que el agente actualiza.
Formato: `{ "version": 1, "tasks": [...] }`.
Cada tarea tiene `id`, `title`, `type`, `priority`, `status`, `result`, `objective`, `criterion`, `evidence`, `notes`, `next`, `resources`, `order`, `createdAt`, `updatedAt`, `history`.
`type` admite Aprendizaje / Proyecto; `result` admite Sin evaluar / Con ayuda / Sin ayuda / Transferido.
`order` es entero no negativo; las fechas de tarea son UTC ISO con milisegundos.
`history` es una lista no vacía de `{at, action}`. Conserva los eventos anteriores al actualizar tareas.
Título, id, objetivo, criterio y próxima acción son obligatorios. Los recursos admiten HTTPS sin credenciales o rutas relativas `./` y `../`.
Para incrustar JSON nuevo, escapar cada `<` como `\u003c`, incluso dentro de notas.

El navegador autoguarda en `savia-learning-backlog-v1`, por origen y navegador.
La página muestra éxito o fallo; file:// puede tener restricciones diferentes según navegador.
Las ediciones locales no aparecen automáticamente en los archivos del repositorio ni son visibles para el agente.
JSON importado, semilla y estado local se combinan por id: gana `updatedAt` más reciente; empate conserva el registro actual.
Las tareas nuevas de la semilla coexisten con las ediciones locales. No hay borrado.
La importación valida el documento completo antes de cambiar estado. Un archivo inválido no cambia el tablero ni el almacenamiento.
Al detectar almacenamiento inicial inválido, se preserva y se suspende el autoguardado; exportar JSON o HTML conserva las ediciones de esa sesión.
La copia HTML usa el documento inicial anterior al render y sustituye solo el JSON; no guarda el diálogo abierto ni los filtros.
Otra pestaña combina actualizaciones válidas y avisa; cerrar y reabrir un diálogo antiguo antes de editar tras ese aviso.
El guardado rechaza un diálogo que quedó abierto antes de una actualización de otra pestaña.
Cada guardado conserva los valores anteriores y nuevos de resultado, evidencia, notas, columna y próxima acción en el historial.
Una copia movida fuera de `docs/learning/` conserva las tareas, pero los enlaces relativos requieren la estructura del repositorio.

Regla futura: cuando Jason explícitamente deje trabajo para después, capturar la tarea conservando objetivo, prioridad y próxima acción.
Registrar motivo y fecha. El agente actualiza la semilla y consulta la exportación más reciente cuando importen las ediciones del navegador.
No se promete monitoreo ni captura fuera de conversaciones activas.

## Evidencia de implementación — 2026-11-05

- Worker: SUAZO-PC, T3 Code / Codex `gpt-6.1-sol`, razonamiento efectivo `high` expuesto por runtime.
- Worktree: `C:/Users/Jason/.t3/worktrees/github/t3-01baed89`, rama `t3/learning-backlog-kanban`.
- Base: `9b387873cb5cb94e5b8c5450f32723f6b7b14d6e`.
- Alcance: solamente este README y `docs/learning/backlog.html`. Sin commit, push, PR, deploy, dependencias nuevas ni llamadas externas.
- Diseño: dirección explícita del packet, contrastada con `build-inputs/static/styles.css`: negro, blanco, gris pálido, bordes sobrios y Arial local. Sin CDN, imágenes ni fuentes remotas. Reglas de embedding sin fondo/color del wrapper.
- `lavish-axi design` y `lavish-axi playbook input`: leídos, exit 0. No se abrió ni publicó una sesión Lavish.

Comprobación funcional ejecutada con jsdom ya instalado en el checkout canónico:

```powershell
node "$env:TEMP/learning-backlog-check.cjs"
```

Resultado: **PASS 41 assertions**, exit 0, después de corregir la codificación UTF-8 de la semilla.
Script de comprobación temporal en este host: `C:/Users/Jason/AppData/Local/Temp/learning-backlog-check.cjs`.
Usa `C:/Users/Jason/MARTHA-SILVA/github/tests/frontend-deps/node_modules/jsdom`.
Verificó semilla, columnas, creación, edición, movimiento, Done de aprendizaje/proyecto, aplazamiento, motivo, historial, evidencia preservada y recarga local.
También verificó filtros, JSON malformado, duplicados, enums, campos obligatorios, fechas, enlaces, historial inválido y rechazo atómico.
Probó texto `</script><img ...>` sin crear nodos ejecutables y reabrió la copia HTML con el estado actual y diálogo cerrado.
Verificó combinación de semilla nueva y edición local, almacenamiento inválido preservado y fallo de escritura visible.
Las rutas relativas de recursos existen en esta base. Esto no verifica el contenido actual de fuentes externas.

```powershell
python tests/check.py
git diff --check
```

Suite general: exit 1, `FAIL: Missing jsdom: run python tests/check.py --install first.`
Causa: este worktree no tiene dependencias locales. No se instalaron porque el packet lo prohíbe.
Corrección alternativa ejecutada: prueba funcional con jsdom existente del checkout canónico; exit 0.
`git diff --check`: exit 0. Los archivos nuevos no están staged; la aceptación sigue pendiente del primary.

Límites: DOM simulado con diálogo adaptado; no acredita Chromium, descargas nativas, teclado real, móvil, contraste, rendimiento ni revisión visual humana.
No se grabó un estado anterior: la página es nueva. No se realizó grabación posterior en este worker.
El evento de otra pestaña está implementado pero no ejercitado con dos navegadores reales.
No se ejecutó producto, API, SQL ni CI. No hay competencia de Jason demostrada por esta entrega.
Tokens y coste: no disponibles en este runtime.

## Aceptación del primary — 2026-11-05

**Aceptado como tablero local de aprendizaje.** No es una evaluación de las habilidades de Jason ni una aceptación de SAVIA.

```powershell
node docs/learning/verify.mjs C:/Users/Jason/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright C:/Users/Jason/MARTHA-SILVA/test-runs/learning-backlog-20261105
```

Resultado: **33 comprobaciones PASS**, exit 0, Chrome real en modo headless con Playwright 1.62.1.
[RESULT.json](RESULT.json) vincula el HTML y el driver por SHA256, enumera cada comprobación y sus límites.
Se probaron el bloqueo de Done, aplazamiento, historial de intentos, recarga, filtros, descarga JSON y copia HTML reabierta.
Cinco importaciones inválidas conservaron el registro: duplicados, prioridad, objetivo vacío, enlace inseguro y versión no soportada.
También se probaron texto que intentaba cerrar un script, diálogo obsoleto, almacenamiento corrupto y fallo de escritura.
Sin overflow horizontal a 320 y 390 px; tres columnas a 1280 px. Enter abre el diálogo y Escape lo cierra.
Cero errores de página y cero solicitudes externas. La simulación del evento storage no demuestra escritura simultánea entre pestañas reales.
Las correcciones del primary conservan versiones anteriores de intentos y rechazan formularios obsoletos.

Evidencia local: `MARTHA-SILVA/test-runs/learning-backlog-20261105/`: capturas desktop/mobile, vídeo posterior, exportaciones y resultado original.
No hay vídeo anterior porque el artefacto es nuevo. No se modificó producto, API, base de datos ni publicaciones Cloudflare.
Fuente visual: neutrales y tipografía de `build-inputs/static/styles.css`, adaptados a un tablero utilitario; el visor puede aportar sus propios colores.
Contraste: `#111111` sobre blanco **18.88:1**; `#656565` sobre `#f7f7f7` **5.44:1**, exit 0 del comprobador de paleta.

`python tests/test_progress.py`: **23 PASS**, exit 0. `python tools/export_progress.py --verify`: **15 hashes PASS**, exit 0.
`python tests/check.py`: exit 1 por **WinError 1314** al crear symlinks en fixtures de medios. No es un fallo observado del tablero.
La ruta alternativa es CI Linux del SHA publicado; no se cambiaron privilegios de Windows ni se dispensó la puerta.
La publicación y el estado de CI se comprueban por separado. La aceptación visual humana y la primera práctica sin ayuda siguen pendientes.

Pendiente, dueño primary: abrir el artefacto en Chromium y verificar guardado/exportación/recarga, importación rechazada, controles táctiles/teclado y anchos móvil/escritorio.
Completar aceptación independiente con evidencia del artefacto integrado; la entrega del worker no es aceptación.

Lección aplicada: una etiqueta Done no demuestra competencia. El control exige evidencia y resultado independiente; las pruebas negativas verifican el rechazo.
Lección de implementación: PowerShell puede degradar acentos al pasar código a Python. Se corrigió la semilla con escapes Unicode y se repitió la prueba afectada.
