# Martha Silva / SAVIA: cerrar y demostrar la venta por cajero (lote de 3 días)

> Plan del lote, redactado el 3-nov. Lo ya ejecutado y su evidencia están en [README](README.md);
> el reparto está en Trello: https://trello.com/b/pq9G9Qqj/martha-silva

Trabaja como responsable de entrega. Este lote no produce otro plan: el diagnóstico del 31-oct
(`docs/delivery-20261031/`) y la validación del 3-nov (`docs/testing-20261103/`) ya fijaron el
siguiente incremento. Tu trabajo es cerrarlo y demostrarlo ante jueces que no seamos tú ni yo:
un runner limpio de CI, la base SQL, un navegador real y la persona que vende en la tienda.
Profundiza en ese camino; no amplíes el alcance.

## 0. Decisiones de Jason para este lote

Vienen prellenadas con la recomendación. Si alguna queda vacía, pregunta solo esa, una vez,
con tu recomendación y la herramienta de preguntas del harness.

- Alcance de los 3 días: SAVIA interno; venta por cajero en una sucursal; ensayo supervisado en la
  tienda. Fuera: tienda pública en producción, tarjetas, SISFAIN, factura fiscal, multisucursal y app
  móvil. La tienda pública sigue siendo demo.
- Responsable de aceptación: [nombre; recomendado: Martha]. Firma por flujo; un agente no acepta.
- Venta con existencia 0 (STOCK-00, pendiente desde el 31-oct): recomendado rechazar, coherente con
  "nunca saldo negativo".
- Puertas abiertas para todo el lote (cítalas textualmente al delegar):
  Permitido: crear y borrar solo bases nuevas con prefijo `SaviaInternalTest_` o `MarthaSynthetic_` en la
  instancia local de pruebas y en runners de CI; crear identidades sintéticas (Owner, Manager,
  Cashier, Inventory y un usuario sin asignación) y revocar sus sesiones; levantar el API en
  loopback; cambiar workflows para que CI ejecute las pruebas SAVIA; abrir el PR de integración y
  hacer merge a `main` con CI verde si el merge no despliega ni publica.
  Prohibido: las 52 bases existentes, datos reales en Git, despliegues y Cloudflare, credenciales de
  proveedores, cobros y cambios de visibilidad del repositorio.
- Modelo y razonamiento por rol en este lote: implementador [___]; revisor independiente [___].
- Tablero: Trello como vista de quién hace qué; el repositorio es la autoridad de "terminado".

## Forma de trabajo (texto de Jason, citado tal cual)

> I trust you with whole problems. Be ambitious: take the full scope, use as many subagents and
> workflows as the work needs, and carry it all the way to done.
>
> Walk through two-way doors and show me after. Stop at one-way doors; If my answer would be a
> rubber stamp, don't ask. If running something could answer the question, run it instead. Save
> questions for taste and product calls only I can make, one at a time, with your recommendation &
> the built in question tool in your harness. If your honest answer is no (don't build it, it isn't
> worth it, I'm wrong), say so.
>
> Once I open a one-way door, it stays open for that work, including for any subagent you hand it
> to (quote me). Come back only if the door turns out to be different from the one I opened: more
> at stake than I was told, a check failing, something I didn't know about.
>
> Agents are free to merge completed, verified work into the repo's default branch once required
> checks and reviews pass, within the maintainers' rules. You do not need to ask me again for merge
> permission. Before merging, inspect what the merge triggers. Automatic builds and tests are
> covered by this permission; publishing a release or deploying to users needs my authorization for
> that consequence. If merging triggers either, get that authorization before merging.

## 1. Línea base: solo el delta (máximo 45 min)

Lee en este orden y cita ruta y SHA en cada afirmación:

1. En SUAZO-PC (`C:/Users/Jason/MARTHA-SILVA/github`): `git status --short --branch`,
   `git log --oneline origin/Tony..HEAD` y `git stash list`. Si no estás en SUAZO-PC, dilo:
   trabajas sobre `origin/Tony`, sin cambios locales ni evidencia privada.
2. El código de `Tony` (`20932d5` o posterior), no los documentos de `main` (`3b00491`, 24-oct,
   sin SAVIA).
3. `docs/AGENT-START.md`, `PROJECT-STATUS.md`, `DECISIONS.md`,
   `delivery-20261031/NEXT-INCREMENT.md` y `testing-20261103/README.md`.
4. Evidencia cruda, no resúmenes: TRX, casos y capturas de navegador en
   `C:/Users/Jason/MARTHA-SILVA/test-runs/20261103-results`; logs de Actions por SHA.

Entrega solo qué cambió desde el 3-nov y qué afirmaciones de esos documentos ya no son ciertas.
Ya comprobado: el bloqueo WinError 1314 de `testing-20261103` está cerrado; el CI Linux de Tony
ejecutó esas suites en `20932d5` (run 41718312660: auditoría 6/6, staging 10/10). El run
"Progress documentation" de ese mismo SHA terminó cancelled: no des esa sincronización por
verificada. No repitas el diagnóstico del 31-oct ni reabras verificaciones sin una razón concreta.

Contradicciones detectadas; presenta cada una con una resolución recomendada:

- `sisfain-base:docs/SISFAIN.md` (25-oct: "SAVIA será un proyecto independiente"; repositorio
  `MarthaSilvaSISFAIN` pendiente) frente a D-012 y D-014 (3-nov: SAVIA en este repositorio,
  rama Tony).
- `AGENTS.md` ("no se ha encontrado un backend SISFAIN") frente a la existencia de la rama
  `sisfain-base`.
- `Tony` suma 65 commits sin PR ni revisión, y `main` no contiene SAVIA. Define la línea de entrega.

## 2. Materia prima de la tienda (día 1; Jason la consigue y el agente prepara el guion)

Antes de tocar UI nueva, usa [CUESTIONARIO-MARTHA](CUESTIONARIO-MARTHA.md) (formato `to-questionnaire`:
preguntas priorizadas, una idea por pregunta, con "por qué importa") para que Martha lo responda
de forma asíncrona. Debe cubrir:

- 30 minutos observando una venta real: quién vende, qué dispositivo y qué red usa la caja,
  cuánto tarda y qué documento recibe el cliente.
- Muestra anonimizada de 2 a 4 semanas de ventas: ventas por día, líneas por venta, devoluciones.
  Con esos datos decide si sirve el formulario de una sola línea (`dev/savia-staff-ui/app.mjs:517`)
  y fija el volumen de las pruebas.
- ¿Cada venta exige un comprobante fiscal emitido por otro sistema? Si es así, SAVIA obliga a
  capturar dos veces. Esa decisión es de Jason, no del agente.
- Artículos, precios y existencias del ensayo, y el personal con su rol. Todo privado y fuera de
  Git; al repositorio solo van agregados y hashes.

## 3. Definition of Done ejecutable (las pruebas van antes que el código)

- N5 primero. El caso "Stale confirmed receipt" de `tests/browser-mock-validation.mjs` debe fallar en
  `20932d5`, pasar con el cambio y volver a fallar al revertirlo. Causa: `app.mjs:510` convierte
  cualquier error de `start()` en `pending ||= {}`. Separa el recibo histórico inaccesible de la
  operación pendiente sin borrar el estado local para desbloquear. Conserva los pendientes reales,
  la pérdida de respuesta, 401/403, el recibo malformado y la recarga. Un test con dobles no cuenta
  como regresión de N5: la costura que puede fallar por este bug es el navegador.
- Camino dorado E2E: Playwright con Chrome real → API .NET en loopback → SQL Server desechable creado
  con las migraciones de release, no con `EnsureCreated`. Cashier: login → venta → recibo → recarga →
  respuesta perdida después del commit → recuperación con la misma `Idempotency-Key` → logout.
- Oráculos SQL después de cada escenario: una venta y un movimiento por línea; suma de movimientos
  igual al saldo; ninguna existencia negativa; claves de idempotencia únicas; cero escrituras en cada
  rechazo (401, 403, CSRF, ámbito), con conteos o huellas iguales antes y después. Un 403 por sí
  solo no prueba que no hubo efectos.
- N1–N10 de `NEXT-INCREMENT.md` como pruebas automatizadas. N7 con un `TimeProvider` falso (Internal
  ya lo inyecta), sin tocar el reloj global. No cambies checks para subir el conteo.
- Migraciones: `20261027224500_InternalBranchScope` se escribió a mano y el script de release
  `InitialInternalSavia.idempotent.sql` no la incluye. Valida el modelo con
  `dotnet ef migrations has-pending-model-changes`, aplica las migraciones a una base vacía y a una
  copia sintética con historia, y ejecuta los 2 `PrivatePilotReleaseTests` que siguen NOT RUN.
- Ningún PASS sin evidencia fresca: comando, SHA y run en el mismo informe. "El agente terminó"
  exige un diff en Git, no su reporte.

## 4. Juez externo (día 1)

Hoy ninguna prueba SAVIA corre en un runner limpio: `backend.yml` solo corre en `main` (último run,
24-oct) y `Tony` solo ejecuta snapshot y progress. Añade lo mínimo para que el PR de integración
ejecute `node --test dev/savia-staff-ui/*.test.mjs`, .NET con SQL desechable (reutiliza la imagen
fijada y la contraseña efímera de `backend.yml`) y el camino dorado.
Un PASS de entrega cita SHA y run de CI. Lo que solo corrió en SUAZO-PC se reporta como "local".
Hoy `main` no está protegida: ningún check es requerido, así que "merge con checks requeridos" no
tiene freno. Antes del primer merge, Jason marca en GitHub como requeridos los jobs del PR de
integración.
Antes de cualquier merge, revisa qué dispara: el job `deploy` de `ci.yml` depende de
`vars.CLOUDFLARE_DEPLOY_ENABLED`. Si el merge despliega o publica, detente y pide autorización.

## 5. Operación mínima (día 2)

- Backup `WITH CHECKSUM` → `RESTORE VERIFYONLY` → restaurar como base nueva → mismos oráculos SQL.
  Mide el RTO real y qué ventas se pierden (RPO).
- Recuperación del acceso Owner, probada y documentada.
- Rendimiento en el dispositivo y la red reales de la caja: 30 ventas sintéticas; p50 y p95 de
  "enviar → recibo visible" y del tiempo de servidor, en frío y en caliente. Presupuesto propuesto:
  p95 ≤ 1 s. Mide antes de optimizar. No pongas en caché precio, saldo ni permisos para llegar al
  número.

## 6. Aceptación en la tienda (día 3)

- La persona que vende, sin ayuda del agente, completa 5 tareas con guion: vender; vender con la red
  cortada y recuperar; consultar existencias; intentar una acción prohibida; cerrar sesión. Registra
  si completa cada tarea, el tiempo, los errores y sus dudas en sus propias palabras.
- Conteo físico de los artículos del ensayo contra el saldo de SAVIA.
- El responsable de aceptación firma por flujo. Lo que falle queda como defecto, no como "casi".

## 7. Reparto entre Jason y su partner

- Comprueba primero que el conector de Trello exista en tu sesión. Si no existe, no lo simules:
  entrega las tarjetas como CSV importable y dilo.
- Un worktree por carril. Los carriles no hacen merge; solo Jason fusiona. Dos carriles con archivos
  disjuntos:
  - A, UI y navegador: N5 y la parte de UI de N2, N6 y N7; camino dorado
    (`dev/savia-staff-ui/**`, `tests/browser-*`).
  - B, API, SQL, CI y operación: oráculos; N1, N3, N4, N8 y N9; migraciones; backup/restore;
    workflows (`backend/**`, `.github/workflows/**`).
  - Jason integra contratos, migraciones, workflows y `main`. N10 lo cierra el revisor independiente.
- Máximo 12 tarjetas, cada una un corte vertical verificable en una sola sesión, con "Bloqueado por".
  Cada una lleva resultado observable, archivos, comando, evidencia esperada, dueño y día. WIP de 1
  por persona. Una tarjeta pasa a Hecho solo con un bloque READY: PR, SHA head, SHA base y CI en ese
  SHA (passed, failed=0, pending=0, skipped).
- Escribe para el agente del partner un prompt autónomo del carril B: objetivo en una frase, sin
  comandos no probados.
- Al final de cada día: PR y CI en verde.
- Lista explícita de lo que no se hace en estos 3 días; incluye las 19 aserciones heredadas de la
  tienda pública.

## 8. Prácticas externas (revisadas el 3-nov: 19 repositorios fijados por SHA)

El detalle, los SHA y la ficha de cada práctica están en [PRACTICAS-19-REPOS](PRACTICAS-19-REPOS.md). No repitas
la revisión salvo que cambie un SHA o aparezca una falla nueva. Aplica estas reglas sin instalar
colecciones ni agentes:

- Costura correcta y bucle rojo-capaz (mattpocock `diagnosing-bugs`): sección 3.
- Rojo-verde verificado y evidencia fresca (superpowers `verification-before-completion`): sección 3.
- Oráculo antes que valores escritos a mano (agent-native `adding-tests-and-ci`): oráculos SQL, sección 3.
- Bloque READY, carriles sin merge y worktree por carril (gstack `captain`, rstack `new-feature`,
  agent-native `concurrent-agents`): sección 7.
- Cortes verticales con "Bloqueado por" (mattpocock `to-tickets`): sección 7.
- Cuestionario asíncrono para Martha (mattpocock `to-questionnaire`): sección 2.
- Revisión en contexto fresco con "NEEDS WORK" por defecto (addyosmani `doubt-driven-development`,
  agency-agents `testing-reality-checker`): sección 9.
- Oleadas de máximo 3 subagentes (BuilderIO `stay-within-limits`): sección 9.

Descartados con evidencia:
- superpowers, agent-skills y ponytail inyectan sus instrucciones en cada sesión mediante hooks.
- kun descarga y ejecuta un script sin fijar desde `main` en cada uso.
- headroom se interpone en el tráfico hacia el modelo, con telemetría activa por defecto.
- codegraph, code-graph-rag, Graphify y archify no aportan sobre ~5 000 líneas que ya tienen
  CODE-MAP; Graphify además está bloqueado por Application Control.
- no-mistakes pasó de v1.84.0 a v1.108.0 en 10 días y sería un segundo publicador.
- MengTo trata sobre todo de diseño y juegos.
- gh-axi es opcional: `gh run view --log-failed` basta.

## 9. Defectos y automatización

Usa el ciclo NEW→CLOSED y el contrato de hooks de `delivery-20261031/PLAYBOOK.md`. Límite por
defecto: 45 minutos y dos hipótesis fallidas; después cambia de ruta o pide el dato que falta.
No construyas ni actives un watcher o loop autónomo en este lote: sigue en PREPARED_NOT_ACTIVE.
Trabaja en oleadas de máximo 3 subagentes; revisa el uso entre oleadas y pausa con uso ≥95 %.
El fix de N5, la validación de migraciones y el cambio de workflows pasan por un revisor en
contexto fresco que recibe solo el diff, los criterios y la evidencia, y parte de "NEEDS WORK".

## 10. Entrega

1. Qué quedó demostrado y qué juez lo demuestra: run de CI, consulta SQL, traza de Playwright o firma.
2. Trazabilidad: necesidad → criterio (N#) → cambio (SHA) → prueba → evidencia → aceptación.
3. Qué no se ejecutó y por qué, y qué falta para producción.

No declares producción. Como máximo, SAVIA queda "aceptado en ensayo supervisado"; la tienda pública
sigue siendo demo sin tarjetas.
