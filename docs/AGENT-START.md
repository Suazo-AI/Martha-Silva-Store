# Continuar Martha Silva / SAVIA

Actualizado: 2026-11-04. Entrada común para cualquier agente; no requiere Graphify.
Checkout: `C:/Users/Jason/MARTHA-SILVA/github`. Rama: `Tony`.
Remoto: `Suazo-AI/Martha-Silva-Store`. No trabajar sobre las copias históricas del folder padre.

## Leer lo necesario

1. Leer [AGENTS](../AGENTS.md) y las reglas aplicables del equipo anfitrión.
2. Leer [estado](PROJECT-STATUS.md), [decisiones vigentes](DECISIONS.md) y `git status --short`.
3. Localizar el área en [CODE-MAP](CODE-MAP.md); leer su fuente y contrato antes de editar.
4. Para SQL, leer [DATABASE](DATABASE.md). Para pruebas, leer [la última validación](testing-20261103/README.md).

## Aprendizaje y tareas que Jason pospone

Cuando Jason posponga una tarea, registrarla en el [backlog de aprendizaje](learning/backlog.html).
Leer [su contrato](learning/README.md) antes de actualizar el registro: conservar prioridad, objetivo, criterio de finalización y siguiente acción.
No marcar una habilidad como demostrada por una explicación o una entrega del agente.
Los cambios del navegador requieren exportación para que el agente pueda incorporarlos; no afirmar sincronización automática.
El ledger de producción sigue siendo la autoridad del proyecto.

Prioridad de fuentes: instrucción vigente de Jason → contrato aprobado → código del candidato
→ evidencia con fecha/hash → propuesta histórica. Un conflicto se registra; no se resuelve inventando capacidades.
El índice y cualquier grafo son ayudas de navegación, nunca autoridad de permisos, esquema o aceptación.

## Estado compartido entre agentes (2026-11-04)

Incremento posterior: la venta multiartículo está validada técnicamente en Tony@922852c.
Consultar [su evidencia y límites](multiarticle-20261104/README.md) antes de integrar este cambio en PR #2.
No atribuir al incremento la CI del candidato anterior ni fusionarlo sin autorización de Jason.

Todos los agentes (Claude, Codex/Tony y otros) parten del mismo lugar:

1. **Estado:** [docs/pipeline/ledger.json](pipeline/ledger.json) es la fuente única. `python3 tools/delivery_status.py`
   muestra dónde vamos, el camino crítico, la siguiente acción por persona y las decisiones pendientes.
   Trello muestra quién hace qué; si Trello y el ledger difieren, se corrige el ledger con evidencia.
2. **Candidato:** rama `claude/funny-brahmagupta-5e5rj0`, [PR #2](https://github.com/Suazo-AI/Martha-Silva-Store/pull/2).
   Partir del head más reciente del PR, no de `775f301` ni de `Tony@20932d5`: ya incluye N5, C4, C5, C7 y el flujo.
3. **No repetir trabajo verificado:** N5, C3, C4, C5 y C7 están `done` con evidencia en el ledger. Si se duda de
   algo, se reabre con una prueba que falle, no rehaciéndolo.
4. **Registrar avance:** en el mismo PR, cambiar `status` y `evidence` del item; `done` sin evidencia o antes
   que sus dependencias hace fallar el CI. Usar la [plantilla de PR](../.github/pull_request_template.md).
   El workflow `progress-digest.yml` publica el estado en el PR y en el issue #3 sin intervención.
5. **Hallazgos:** un hallazgo nuevo es un item nuevo del ledger (dueño, porqué, criterio de hecho,
   alternativas, decisión si aplica), no solo un comentario de Trello o Slack.
6. **Puertas de un solo sentido:** merge a `main`, despliegue, secretos, datos reales y cambios de
   seguridad requieren a Jason. Ver [pipeline](pipeline/README.md) y [AGENTS](../AGENTS.md).

## Próxima tarea concreta

> Actualización 2026-11-03: N5 está corregido en la rama `claude/funny-brahmagupta-5e5rj0` (PR de integración),
> con evidencia en [sprint-20261104](sprint-20261104/README.md). No repetir esa corrección: integrarla y seguir
> las tarjetas C1–C12 del sprint. El texto siguiente queda como antecedente.

Corregir N5: la recuperación de un recibo confirmado con respuesta 404 crea un bloqueo de venta pendiente.
Reproducción: caso `Stale confirmed receipt` de [browser-mock-validation.mjs](../tests/browser-mock-validation.mjs).
Punto inicial: restauración del recibo en [app.mjs](../dev/savia-staff-ui/app.mjs).

Aceptar solo si el recibo obsoleto deja disponible una venta nueva, una venta realmente pendiente sigue
bloqueando duplicados y una sesión revocada continúa invalidando el acceso. Conservar la clave del intento
original en recuperación. Añadir/verificar la regresión y ejecutar las pruebas afectadas.
Después preparar el recorrido navegador → API → SQL aislado del
[incremento N1–N10](delivery-20261031/NEXT-INCREMENT.md), con una venta y un único débito persistidos.
La autorización de sincronización no autoriza ese nuevo runtime SQL.

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
Cada delegación requiere la selección de modelo/razonamiento de Jason para ese lote, según las reglas del proyecto.

## Antes de entregar a otro agente

Indicar: host, rama/SHA, cambios locales, tarea pendiente, prueba reproducible, resultados exactos,
exclusiones y siguiente condición de aceptación. Los documentos fechados conservan su corte histórico.
La [reconciliación](reconciliation-20261103/README.md) explica qué se publicó y qué permanece privado.
