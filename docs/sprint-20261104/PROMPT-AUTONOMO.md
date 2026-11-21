# Prompt: cerrar lo que no depende de Denis y dejar que GitHub cuente el avance

Versión más profunda del pedido de Jason del 3-nov. Primero, lo que cambia respecto del pedido original.

## Lo que haría un profesional y no se pidió

1. **Separar el estado de su narración.** Un estado que escribe un modelo de lenguaje se puede equivocar con
   aplomo. El estado vive en un archivo verificable (ledger) con reglas que el CI hace cumplir. La IA solo
   comenta.
2. **Trabajar sobre el camino crítico, no sobre la lista.** "Todo lo que no dependa de Denis" incluye cosas
   que no acercan el viernes. Hay que priorizar lo que desbloquea a Denis (C5 desbloquea C6, C4 desbloquea C9).
3. **Definir "listo para producción" como compuertas con dueño y evidencia**, al estilo de una *production
   readiness review*: hospedaje, secretos, respaldo, monitoreo, runbook y aceptación. "Casi listo" no cuenta.
4. **Aviso con poco ruido.** Un comentario fijo por PR y un issue de bitácora, no un mensaje por commit en
   todos los canales.
5. **Respetar carriles.** No tomar las tarjetas de Denis sin coordinar. Basta con dejar listo lo que él necesita.

## Material crudo del que se parte

- `git log` de `Tony`, `main` y esta rama, con los recibos de `docs/progress/`; no los resúmenes.
- Los runs de CI por SHA y los TRX de `dotnet test`; no "pasó en mi máquina".
- El código de los endpoints (`backend/src/Martha.Store.Api/Internal/**`) y de la UI (`dev/savia-staff-ui/app.mjs`).
- Las migraciones y el script `.idempotent.sql` tal como están en el repo.
- La tabla N1–N10 de `docs/delivery-20261031/NEXT-INCREMENT.md` como contrato congelado.
- La actividad de las tarjetas de Trello: fechas, movimientos y comentarios.

## Métodos y herramientas

- **Grafo de dependencias con camino crítico**, calculado en cada evento por `tools/delivery_status.py`.
- **Ledger JSON con reglas que fallan cerrado**: nada pasa a `done` sin evidencia ni antes que sus dependencias.
- **GitHub Actions** en cada push y PR: comentario fijo, issue de bitácora y resumen del job.
- **Narrador opcional de solo lectura**: `anthropics/claude-code-action` u `openai/codex-action`, fijados por SHA,
  con salida estructurada.
- **Pruebas en la costura correcta.** xUnit con SQL Server desechable para los rechazos con cero escrituras,
  un arnés HTTP con la API real y migraciones de release, y Playwright en Chrome real para la UI.
- **Rojo-verde-revert** en cada prueba nueva, para demostrar que detecta lo que dice detectar.
- **Registro de decisiones con alternativas** (`docs/DECISIONS.md`) y una plantilla de PR que las exige.

## Qué demuestra que está bien (además de Jason o del agente)

- El **CI del SHA**: `savia.yml`, `backend.yml`, `golden-path.yml` y `progress-digest.yml` en verde, sin skips
  y con un mínimo de casos.
- **Un push de Denis que actualiza la bitácora sin que nadie la toque.** Es la prueba del flujo.
- **Una prueba roja con el ledger mentiroso** (`done` sin evidencia), incluida en `tests/test_delivery_status.py`.
- **Martha**, firmando el ensayo C10. Ninguna prueba sintética la sustituye.
- **Denis**, como revisor con postura NEEDS WORK (C3 y C11).

## El prompt

> Actúa como responsable de entrega de SAVIA interno (Martha Silva). Conserva las reglas de `AGENTS.md`, los
> permisos vigentes y las puertas de un solo sentido: nada de despliegue, credenciales de proveedores, datos
> reales, las 52 bases existentes ni cambios de visibilidad, y no fusionar sin checks requeridos.
>
> 1. **Estado desde la fuente.** Reconstruye el estado desde Git, los runs de CI por SHA y los TRX, no desde
>    resúmenes. Registra el estado en `docs/pipeline/ledger.json`, con dueño, dependencias, por qué, criterio de
>    hecho, alternativas y evidencia. El CI debe rechazar un ledger incoherente.
> 2. **Camino crítico primero.** Entre las tarjetas que no dependen de Denis, ejecuta de punta a punta las que
>    acortan el camino crítico o desbloquean a Denis: C4 (migraciones de release), C5 (arnés API real + SQL) y C7
>    (N1, N3, N4, N8 y N9 con cero escrituras medidas en SQL). Cada prueba nueva va con rojo-verde-revert. Si
>    una prueba revela un defecto de producto, repórtalo con evidencia antes de cambiar la semántica.
> 3. **Flujo automático.** Cada push y PR debe producir, sin intervención humana, un resumen determinista: qué
>    cambió, qué compuertas tocó, dónde vamos, el camino crítico, la siguiente acción por persona y las
>    decisiones, herramientas y pruebas que faltan. Publícalo en un comentario fijo del PR y en un issue de
>    bitácora. Un narrador IA (Claude o Codex) es opcional y de solo lectura, y nunca decide el estado. Exige
>    las secciones Por qué, Alternativas, Evidencia y Qué falta en PRs listos.
> 4. **Decisiones.** Toma tú las de dos sentidos que no afectan al cliente ni al producto, y regístralas con su
>    razonamiento. Lista las de un solo sentido con tu recomendación y quién decide.
> 5. **Salida.** Primero el resultado útil, con evidencia por SHA. Después: qué no se ejecutó y por qué, los
>    bloqueos con acción, destino, motivo y estado, las pruebas pendientes y quién las corre, y el siguiente
>    incremento. No declares producción por pruebas sintéticas, ni entrega remota sin SHA remoto y CI.
