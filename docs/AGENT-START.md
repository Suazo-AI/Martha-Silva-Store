# Continuar Martha Silva / SAVIA

Actualizado: 2026-11-07. Entrada común para cualquier agente; no requiere Graphify.
Checkout: `C:/Users/Jason/MARTHA-SILVA/github`. Rama: `Tony`.
Remoto: `Suazo-AI/Martha-Silva-Store`. No trabajar sobre las copias históricas del folder padre.

## Leer lo necesario

1. Leer [AGENTS](../AGENTS.md) y las reglas aplicables del equipo anfitrión.
2. Leer [estado](PROJECT-STATUS.md), [decisiones vigentes](DECISIONS.md) y `git status --short`.
3. Localizar el área en [CODE-MAP](CODE-MAP.md); leer su fuente y contrato antes de editar.
4. Para SQL, leer [DATABASE](DATABASE.md). Para pruebas pendientes, leer la [validación local actual](completion-20261107/local-validation/README.md).

## Aprendizaje y tareas que Jason pospone

Cuando Jason posponga una tarea, registrarla en el [backlog de aprendizaje](learning/backlog.html).
Leer [su contrato](learning/README.md) antes de actualizar el registro: conservar prioridad, objetivo, criterio de finalización y siguiente acción.
No marcar una habilidad como demostrada por una explicación o una entrega del agente.
Los cambios del navegador requieren exportación para que el agente pueda incorporarlos; no afirmar sincronización automática.
El ledger de producción sigue siendo la autoridad del proyecto.

Prioridad de fuentes: instrucción vigente de Jason → contrato aprobado → código del candidato
→ evidencia con fecha/hash → propuesta histórica. Un conflicto se registra; no se resuelve inventando capacidades.
El índice y cualquier grafo son ayudas de navegación, nunca autoridad de permisos, esquema o aceptación.

## Cuando un paso requiere las manos de Jason

Actualización 2026-11-11 (Jason): decisiones y pasos se presentan como Artifact publicado (herramienta Artifact
por defecto). Lavish solo cuando Jason lo pida. Las rondas de decisión siguen el skill global `align`.
Formato histórico: entregar esos pasos como una guía visual interactiva en Lavish (`lavish-axi`), no como
texto en el chat. Formato que Jason pidió explícitamente (2026-11-10): pasos numerados grandes, un
to-do con casillas para marcar, botón de copiar en cada texto literal que hay que escribir o pegar,
una barra de progreso, y al final qué hace el agente y qué decisiones quedan. Archivos de ejemplo:
[owner-recovery-20261107/interactive-handoff-20261110.md](owner-recovery-20261107/interactive-handoff-20261110.md).
Antes de pedirle un paso, dejar el preflight en verde: si el agente puede comprobar por código que el
paso va a funcionar, primero lo comprueba, y solo entonces lo pide. Cada guía nueva va en un archivo
propio bajo `.lavish/`; no reabrir una sesión cerrada.

## Estado compartido entre agentes

1. **Estado:** [docs/pipeline/ledger.json](pipeline/ledger.json) es la fuente única. `python3 tools/delivery_status.py`
   muestra dónde vamos, el camino crítico, la siguiente acción por persona y las decisiones pendientes.
2. **Candidato:** verificar `git branch --show-current`, `git rev-parse HEAD` y cambios locales en `Tony`.
   Para un worker, fijar ese SHA y usar el worktree administrado por T3 con sus rutas asignadas.
   La integración y publicación en el checkout canónico pertenecen al primary.
3. **Evidencia:** reutilizar resultados aceptados cuando sus fuentes y alcance sigan vigentes.
   Separar pruebas históricas, simuladas, SQL y navegador → API → SQL. Una CI anterior no cubre un SHA nuevo.
4. **Registrar avance:** actualizar el documento del área y, cuando cambie su estado, el item del ledger.
   Publicar en `Tony` mediante [AUTO-SYNC](AUTO-SYNC.md); verificar `SYNCED`, SHA remoto y CI aplicable.
5. **Hallazgos:** registrar causa demostrada o hipótesis, evidencia, dueño, siguiente acción y comprobación de cierre.
   Mantener los criterios aprobados; una entrega del worker no constituye aceptación del primary.
6. **Permisos:** comprobar el alcance vigente antes de ejecutar SQL, recuperación, cambios de seguridad,
   cuentas, merge o despliegue. La publicación documental no autoriza esas acciones.

## Elegir el siguiente trabajo

Partir del ledger y de la [continuación actual](completion-20261107/README.md), no de una tarea fechada antigua.
Antes de cambiar rutas compartidas, comprobar actividad y propiedad con las reglas de coordinación de AGENTS.

- Validación: [preparación local](completion-20261107/local-validation/README.md), con A, C, D y E separados.
- Seguridad de sesión: [contrato CSRF](session-csrf-20261107/README.md).
- Acceso de emergencia: [contrato Owner](owner-recovery-20261107/IMPLEMENTATION.md).

La [validación del 3 de noviembre](testing-20261103/README.md), la [venta multiartículo](multiarticle-20261104/README.md)
y el [sprint anterior](sprint-20261104/README.md) conservan sus cortes históricos.
N5 ya fue corregido; consultar su [aceptación y límites](n5-browser-20261105/README.md) si cambia la recuperación.

## Ciclo de trabajo

- Fijar candidato, resultado observable, límites y comprobación antes de cambiar código.
- Reproducir el fallo; cambiar lo mínimo; verificar fallo corregido y comportamiento afectado.
- Actualizar el documento del área y PROJECT-STATUS con comando, resultado y límites.
- Registrar decisiones nuevas en DECISIONS; conservar evidencia anterior, sin sobrescribirla.
- Revisar el diff y datos sensibles. Añadir rutas explícitas y hacer commit; los hooks sincronizan Tony.
- Comprobar SHA remoto y CI del mismo SHA. [AUTO-SYNC](AUTO-SYNC.md) describe recuperación de fallos.

No ejecutar scripts históricos de arranque, bootstrap Owner, reinicio, migración o vigilancia por encontrar sus archivos.
No repetir autorizaciones de un solo uso. No publicar sesiones, bases, certificados o logs privados.
No activar un agente permanente ni instalar herramientas para suplir una tarea que Git y `rg` ya resuelven.
Antes de delegar, leer `C:/Users/Jason/AI-OS/rules/orchestration.md` y aplicar la selección vigente de Jason.
Selección de este proyecto: executors gratuitos de OpenCode/high; único juez Astra/xhigh.
Una selección ya aprobada no necesita otra confirmación; no autoriza sustituir proveedor ni ampliar permisos.

## Antes de entregar a otro agente

Indicar: host, rama/SHA, cambios locales, tarea pendiente, prueba reproducible, resultados exactos,
exclusiones y siguiente condición de aceptación. Los documentos fechados conservan su corte histórico.
La [reconciliación](reconciliation-20261103/README.md) explica qué se publicó y qué permanece privado.
