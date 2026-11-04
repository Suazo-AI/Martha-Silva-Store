# Revisión de los 19 repositorios de prácticas — 2026-11-03

Método: clon superficial de cada repositorio en una carpeta aislada; lectura de README, SKILL.md,
hooks y scripts relevantes. **Nada se instaló ni se ejecutó.** Una práctica se adopta solo si ataca
una falla observada en Martha Silva / SAVIA, y se aplica como regla escrita (prompt, PLAYBOOK),
no como instalación de una colección.

Fallas observadas que sirven de filtro:

- a) N5 pasó 42/42 pruebas con dobles; solo un navegador real lo detectó.
- b) 19 aserciones heredadas de la tienda pública no coinciden con la salida actual.
- c) Criterios NOT RUN por esperar autorización de runtime.
- d) El CI no cubre la rama de trabajo; `main` y `Tony` no tienen protección ni checks requeridos.
- e) Validación sobre cambios sin commit; un checkout canónico compartido por varios agentes.
- f) Reparto de 3 días entre dos personas y sus agentes; faltan datos reales de la tienda.

## Revisión consultada

| Repositorio | SHA | Qué es | Veredicto | Práctica concreta o motivo |
| --- | --- | --- | --- | --- |
| mattpocock/skills | 4ae2317ddb22b046e26455e4f9c9b3aaaf62212d | 40 skills de ingeniería (sin cambios desde el 31-oct) | Adoptar 3 reglas | `diagnosing-bugs`: bucle rojo-capaz en la **costura correcta** (a). `to-tickets`: cortes verticales con "bloqueado por" (f). `to-questionnaire`: cuestionario asíncrono para quien tiene el dato (f). `wizard`: opcional para pasos solo humanos. |
| michaelshimeles/rstack | 11b15767d7587bab11f6c4957507b5f26d1785c7 | 7 skills + AGENTS (sin cambios desde el 31-oct) | Adoptar 1 regla | `new-feature`: un worktree por tarea (e). `before-and-after` cubierto con capturas Playwright existentes. `greploop` descartado: depende de Greptile (servicio externo). |
| addyosmani/agent-skills | 301b02b12bff98e4688e6984af6556802322bbde | 25 skills; avanzó desde 8bfcc1f revisado el 31-oct | Adoptar 1 regla | `doubt-driven-development`: revisión en contexto fresco cuando se afirma una invariante (idempotencia, orden) o el cambio es irreversible (migración) (c). No instalar: `hooks/session-start.sh` inyecta su meta-skill en cada sesión. |
| davidondrej/skills | 8aa01cf45110ae378bdf5c319cd41ac8fdbdf448 | 62 skills; avanzó desde 7201ee3 revisado el 31-oct | Adoptar 2 reglas | `risky-changes`: en dinero/stock, los tests prueban corrección y la medición en vivo prueba utilidad → ensayo en tienda y conteo físico. `prompt-for-others`: prompt autónomo para el agente del partner, sin comandos no probados (f). `better-prompt` es el texto exacto del pedido meta de Jason. |
| kunchenguid/kun | d09de04ef63d5b0e9e97ba007a6e05832d0eafbf | Skill "/kun" | Descartar | Cada uso descarga y ejecuta `pull-kun.mjs` desde `main` (sin fijar) y su contenido cambia a diario. Código remoto no fijado. |
| MengTo/Skills | 1de14e21b2ba8937c0f7f6ddca581cf7cd9d94af | 180 skills, sobre todo diseño, 3D y juegos | Descartar en este lote | Fuera del alcance de SAVIA. `iterate-until-verified` deja una lección: al mejorar un prompt, la tarea original sigue siendo la autoridad. `no-ai-design-slop` puede servir más tarde para la aceptación visual de la tienda pública. |
| BuilderIO/agent-native | 386ac4727002238df0f45749ae5afebcaae50a68 | Framework TypeScript para apps con agentes (31 446 archivos) | Adoptar 2 reglas, no el framework | `.agents/skills/adding-tests-and-ci`: probar en el nivel más barato que **pueda fallar** por el bug, preferir un oráculo a valores esperados a mano, nunca saltar tests para ponerse en verde (a). `concurrent-agents`: el árbol es compartido; leer antes de editar; nunca reset/clean/stash del trabajo ajeno (e). |
| BuilderIO/skills | f4f10b8d513476c24bd995ceac5294bcdd6ee15c | 26 skills de orquestación | Adoptar 1 regla | `stay-within-limits`: oleadas de máx. 3 subagentes, revisar uso entre oleadas, pausar ≥95 %. `factory-*` (experimental, autónomo) y `plan-arbiter` fuera del lote. |
| kunchenguid/gh-axi | bb8c797be7d352335be41d45537a10381aa8fd55 | Envoltorio de `gh` para agentes | Opcional | Requiere `gh` autenticado y Node 20+. `gh run view --log-failed` basta para leer el CI del SHA. |
| colbymchenry/codegraph | f72c9d2efb14454ff4f9fd7b8460abd82f19a287 | Grafo de código (kernel nativo en Rust + wasm; soporta C#) | Descartar | SAVIA tiene ~1 200 líneas de UI y 39 archivos C# (3 705 líneas) con CODE-MAP; `rg` basta (D-017). Un binario nativo puede chocar con Application Control como Graphify. |
| tt-a1i/archify | a4065941f12be7967436261d9934784e381d423c | Diagramas HTML generados por el agente | Descartar la herramienta, adoptar 1 regla | La instalación pide al agente leer `llms.txt` desde `main` (instrucciones remotas sin fijar). Su skill `test-value` aporta la taxonomía para (b): regresión de producto, aserción obsoleta, fallo de entorno o test inestable. |
| garrytan/gstack | f8085aa0e499085c411f712d6d5c00a81d1b104a | 76 skills con binarios y telemetría propios | Adoptar 2 reglas, no instalar | `captain`: los carriles no hacen merge; el integrador fusiona; las decisiones del dueño se citan con sus palabras; el bloque READY fija PR, SHA head, SHA base y CI en ese SHA (passed/failed=0/pending=0/skipped). `test-audit`: "ninguno" es un resultado válido. Las skills dependen de `~/.claude/skills/gstack/bin` y registran uso. |
| kunchenguid/no-mistakes | 18374c36079ea69a8b478d96d94e86e04a3c79b9 | Puerta de validación con IA antes del push | Mantener inactivo | Pasó de v1.84.0 (verificado el 24-oct) a v1.108.0 en 10 días. Sería un segundo publicador junto a los hooks de Tony. CI como juez cubre el lote. |
| msitarzewski/agency-agents | b37b5bb33b78f2c1d6567d98e25ca818e3259219 | 330 personas de agentes | Adoptar 1 postura | `testing-reality-checker`: "NEEDS WORK" por defecto hasta tener evidencia, como postura del revisor de N10. El resto son personas sin herramienta propia. |
| vitali87/code-graph-rag | 5d8db5e9b8acf986573b232f08e9d948cfac91a7 | Grafo de código en SQLite (Python 3.12; soporta C#) | Descartar | Mismo motivo que codegraph: el tamaño de SAVIA no lo justifica. |
| Graphify-Labs/graphify | 8e6a6d2129d4aeffc7a0e9ed79b153f7f057f42b | Grafo de conocimiento del proyecto | Descartar | Bloqueado por Application Control en SUAZO-PC (D-017); mismo argumento de tamaño. |
| obra/superpowers | 2ce8aa15d05bd57213e6f746f953aafb7ded7a8b | 15 skills de metodología | Adoptar 1 regla, no instalar | `verification-before-completion`: ninguna afirmación de éxito sin evidencia fresca del mismo mensaje; "test de regresión funciona" exige ciclo rojo-verde verificado; "agente terminó" exige diff en Git, no su reporte. No instalar: su hook SessionStart inyecta `<EXTREMELY_IMPORTANT>` en cada sesión. La regla de 2 intentos de Jason es más estricta que su "3 fixes". |
| DietrichGebert/ponytail | 96608e078b2d5ea607c5c3b8b5a54d1c1fba6846 | Modo "cambio mínimo" con hooks para Claude, Codex, Cursor y Copilot | Descartar instalación | La regla útil ("cambio mínimo sin quitar validación ni seguridad") ya está en AGENTS/PLAYBOOK. Sus hooks de activación y de subagentes modifican cada sesión. |
| headroomlabs-ai/headroom | 038af599e1a3c5e7e6b3047781aaf9ba2bbbf8bd | Proxy que comprime lo que lee el agente | Descartar | Se interpone en el tráfico entre el agente y el modelo, consulta PyPI a diario y trae telemetría activa por defecto (`HEADROOM_TELEMETRY=off` para apagarla). No vale ese riesgo en un lote de 3 días. |

## Prácticas adoptadas: ficha

| # | Práctica (fuente) | Problema que resuelve | Aplicación concreta | Herramienta existente | Dependencias / coste | Prueba de utilidad |
| --- | --- | --- | --- | --- | --- | --- |
| P1 | Bucle rojo-capaz en la costura correcta (mattpocock `diagnosing-bugs`) | a) 42/42 tests con dobles no vieron N5 | La regresión de N5 vive en el harness de navegador y en el camino dorado; un test con dobles no cuenta como regresión de N5 | `tests/browser-mock-validation.mjs`, Playwright | Ninguna nueva | En `9befe15` la regresión de navegador falla mientras los 42 tests con dobles pasan (ya observado el 3-nov) |
| P2 | Rojo-verde verificado y evidencia fresca (superpowers `verification-before-completion`) | Estados PASS heredados de otro candidato | Revertir el fix debe volver a poner la regresión en rojo; todo PASS cita comando, SHA y run | Git, Actions | Un run extra | La regresión falla con el fix revertido |
| P3 | Oráculo antes que valores a mano (agent-native `adding-tests-and-ci`) | Un 403 no prueba ausencia de efectos | Invariantes SQL después de cada escenario | SQL Server, xUnit | Consultas SQL | Inyectar a mano un doble débito en una base desechable hace fallar el oráculo |
| P4 | Bloque READY para cerrar (gstack `captain`) | d) y e): "hecho" sin SHA ni CI | Una tarjeta pasa a Hecho solo con PR, SHA head, SHA base, CI en ese SHA (passed/failed=0/pending=0/skipped) y evidencia | Actions, Trello | Copiar un bloque | Cualquiera lo verifica con `git ls-remote` y el run |
| P5 | Carriles sin merge e integrador único; worktree por carril (gstack `captain`, rstack `new-feature`, agent-native `concurrent-agents`) | e) agentes sobre un checkout compartido | Un worktree por carril; solo Jason fusiona; decisiones del dueño citadas | `git worktree` | Bajo | Ningún PR de un carril toca rutas del otro |
| P6 | Cortes verticales con "bloqueado por" (mattpocock `to-tickets`) | f) reparto | Máx. 12 tarjetas, cada una verificable en una sesión, con bloqueos explícitos | Trello o CSV | Bajo | Ninguna tarjeta empieza con bloqueos abiertos |
| P7 | Cuestionario asíncrono (mattpocock `to-questionnaire`) | f) faltan datos de la tienda | [CUESTIONARIO-MARTHA](CUESTIONARIO-MARTHA.md): preguntas priorizadas, una idea cada una, con "por qué importa" | Markdown | ~15 min de Martha | Cada respuesta confirma o cambia un criterio del prompt |
| P8 | Revisión en contexto fresco; "NEEDS WORK" por defecto (addyosmani `doubt-driven-development`, agency-agents `testing-reality-checker`) | Invariantes e irreversibles revisados por quien los escribió | El revisor recibe solo diff, criterios y evidencia: fix de N5, migración, cambio de workflow | Subagente revisor | Una revisión por cambio crítico | El revisor no ve el razonamiento del implementador |
| P9 | Presupuesto de uso por oleadas (BuilderIO `stay-within-limits`) | Límites de tiempo y tokens | Máx. 3 subagentes en paralelo; revisar uso entre oleadas; pausar ≥95 % | — | Nulo | Registro de uso por oleada |

Para después del lote: clasificar las 19 aserciones heredadas con la taxonomía de archify `test-value`
(regresión de producto, aserción obsoleta, entorno, inestable), una por una y con evidencia.
