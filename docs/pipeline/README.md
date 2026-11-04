# Flujo de avance automático

**Qué hace.** En cada push (cualquier rama) y cada PR, GitHub calcula el estado del proyecto a partir de
[ledger.json](ledger.json) y avisa sin que nadie tenga que escribirlo:

- **Dónde vamos:** hecho, en curso, bloqueado y pendiente por carril (sprint, producción, tienda, flujo).
- **Camino crítico:** la cadena más larga de pasos sin terminar hasta el cierre del sprint y hasta producción.
- **Siguiente acción por persona:** solo items cuyas dependencias ya están hechas.
- **Decisiones, herramientas y pruebas que faltan**, con quién decide y la recomendación.
- **Qué tocó este cambio:** commits del evento y las compuertas del ledger afectadas por los archivos cambiados,
  con su porqué, criterio de hecho y alternativas.

Dónde aparece:

| Evento | Destino | Aviso |
| --- | --- | --- |
| Push a cualquier rama (incluye `Tony` cuando el workflow llegue ahi) o ejecucion manual | Issue con etiqueta `bitacora`: comentarios historicos con evento, ref, SHA, run e intento; no reescribe el cuerpo como estado global vigente | Notificacion de GitHub a quien este suscrito al issue |
| PR abierto, actualizado o editado | Comentario fijo del evento, solo si el PR sigue abierto y coinciden su head y `updated_at` vivos; si cambio, se omite la escritura y queda el snapshot en Actions | Notificacion normal del PR cuando se publica |
| Cualquiera | Resumen del job en Actions | — |

## Publicacion historica y concurrencia

Cada resumen identifica evento, ref, SHA del evento, head del PR si corresponde, run e intento.
Es un snapshot historico del ledger de ese evento, no una afirmacion de estado global actual.
Una rama atrasada o un run demorado puede publicar despues de otro: ese orden refleja llegada
al publicador y no convierte su ledger en el vigente para todas las ramas.

El job `publish` usa un grupo de concurrencia global, `savia-progress-digest-publication`,
compartido entre ramas y tipos de evento. Los publicadores que usan esta version no buscan ni
crean simultaneamente la primera Bitacora. Se elige el issue abierto etiquetado de menor numero
(excluyendo PRs) y solo se agregan comentarios; no se cierran ni eliminan issues duplicados existentes.
Las colas usan `queue: max`: GitHub admite hasta 100 pendientes por grupo; al superar ese limite
puede cancelar entradas. No es una promesa de entrega ilimitada ni exactamente una vez. Reintentar
un run puede agregar otro comentario historico, identificado por su run e intento.

Para el comentario fijo de PR, despues de buscar el comentario existente se consulta el PR vivo.
Si esta cerrado, cambio el head o cambio `updated_at` respecto del evento, el job omite el POST/PATCH.
La lectura fallida no autoriza usar datos antiguos. Esta comprobacion reduce escrituras atrasadas,
pero GET y POST/PATCH no son una operacion atomica: aun existe una ventana si el PR cambia entre
ambas llamadas. Por eso el propio comentario conserva el head y el evento del snapshot.

Antes de activar esta correccion deben terminar los runs antiguos que no compartan el nuevo
bloqueo. Otros workflows, bots y personas no quedan serializados por este grupo. Si ya existe un
cuerpo de issue generado por una version anterior que diga que es el estado vigente, esta version
no lo sustituye: requiere una correccion puntual revisada del texto historico; no se debe interpretar
ese cuerpo antiguo como una medicion actual. No se cambia informacion manual del issue por inferencia.

Permisos y efectos conservados: el publicador tiene `contents: read`, `issues: write` y
`pull-requests: write`; puede crear la etiqueta/issue y escribir comentarios de issue/PR.
No hace push de codigo, merge ni despliegue. El narrador opcional y los tests del digest no cambian
por esta correccion; la metadata y los artefactos no prueban que la evidencia del ledger sea cierta.

Referencia de la cola y sus limites: [documentacion oficial de concurrencia de GitHub](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency).

## Reglas que el CI hace cumplir

`tools/delivery_status.py` falla (y el check queda rojo) si el ledger miente o está incompleto:

- un item `done` sin `evidence`, o `done` mientras una dependencia no lo está;
- `blocked` sin `blocked_by` ni `blocker`; `dropped` sin `decision_ref`;
- dueños, carriles o dependencias inexistentes, ids duplicados o ciclos;
- un PR **listo para revisión** sin las secciones *Por qué*, *Alternativas*, *Evidencia* y *Qué falta*
  ([plantilla](../../.github/pull_request_template.md)). En borrador solo avisa.

Si un cambio toca archivos de una compuerta (`paths`) sin actualizar el ledger, el resumen lo señala.
Las pruebas del propio script están en `tests/test_delivery_status.py` y corren en `tests/check.py`.

## Cómo registra Denis (o cualquiera) un avance

1. Trabajar en una rama propia y abrir PR hacia `main` con la plantilla.
2. Si el cambio mueve un item, editar `docs/pipeline/ledger.json` en el mismo PR: `status`, y `evidence`
   con el run de CI o la ruta. `done` sin evidencia no pasa.
3. Hacer push. El resto lo hace GitHub: bitácora, comentario del PR y narrador si está configurado.

La rama `Tony` conserva su flujo de recibos (`tools/progress.py`); este workflow corre ahí cuando Jason
integre esta rama en Tony con un merge local en SUAZO-PC (el hook agrega el recibo). Hasta que el workflow
esté en `main`, los PR y ramas nuevas lo heredan solo si parten de esta rama.

## Narrador IA opcional (Claude o Codex)

Solo en PR de este repositorio. Corre en un job con permisos de **solo lectura**: lee el resumen, el ledger y
el diff, y devuelve texto (qué cambió, alternativas, riesgos, si el ledger debería cambiar). Otro job lo
publica dentro del comentario del PR, plegado y marcado "no decide el estado". No escribe archivos, no
aprueba, no fusiona y no cambia el ledger. Sin secreto configurado, el job lo indica y no hace nada.

Activarlo es decisión de Jason (item `PIPE-AI`), porque implica una credencial y un costo de uso. Agregar **uno** de estos secretos
del repositorio (Settings → Secrets and variables → Actions):

| Secreto | Proveedor | Nota |
| --- | --- | --- |
| `CLAUDE_CODE_OAUTH_TOKEN` | Claude (suscripción) | Se obtiene con `claude setup-token`; recomendado |
| `ANTHROPIC_API_KEY` | Claude (API) | Pago por uso |
| `OPENAI_API_KEY` | Codex | Se usa solo si no hay secreto de Claude |

La acción de Claude no admite eventos `push`, por eso el narrador comenta PR y no cada push; la bitácora
de pushes es siempre determinista. Acciones fijadas por SHA: `anthropics/claude-code-action` v1.0.255
(`e4a6faa…`), `openai/codex-action` v1.13 (`bdf19a4…`), ambas publicadas hace más de dos semanas.

## Límites

- El estado es tan bueno como el ledger: el script verifica coherencia, no que la evidencia diga lo que
  afirma. Esa revisión sigue siendo de una persona (C3/C11) y del CI de cada SHA.
- No hay sincronización con Trello: el conector no tiene credencial en GitHub. Trello sigue siendo la vista
  de quién hace qué; el ledger es la fuente de estado. Agregarla requiere `TRELLO_KEY`/`TRELLO_TOKEN`.
- No despliega, no hace push, no cambia configuración. Los fork PR no publican comentarios.
