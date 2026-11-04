# C8: integración en el PR #2

Coordinación: `SUAZO-PC`, 2026-11-03 local / 2026-11-04 UTC.
Base de integración: `6aeb9a35f45331ace85ac48dc19bfd9264b0f722`.
Estado: seis archivos importados; CI del candidato integrado pendiente.

El patch [candidate.patch](current-head-20261104/candidate.patch) conserva SHA-256
`a0762dc021260f4c8c88b849552c4775c6bef17af06c5338e68e95cd7a221df0`.
`git apply --check` pasó antes de aplicarlo al checkout canónico.
No se modificaron las seis fuentes durante la importación.
Los hashes del checkout de Windows se comparan con el [binding](current-head-20261104/binding.json).
Git normaliza los finales de línea: los hashes de publicación se registran por separado.

La UI conserva el intento incierto y su clave al cambiar actor, versión o ubicación.
El cliente descarta respuestas de una sesión anterior y detiene POST pendientes de CSRF tras logout o 401.
La prueba nueva usa `TimeProvider` falso dentro de TestServer para verificar expiración absoluta antes de resolver SQL.
No cambia reloj, servicios, cookies ni políticas de seguridad de producción.

## Evidencia reutilizada

| Comprobación existente | Resultado |
| --- | --- |
| Casos UI C8 enfocados | 9/9 PASS |
| Navegador completo | 45/45 PASS |
| Staff JS | 45/45 PASS |
| Expiración API | 1/1 PASS |
| InternalSecurityTests | 49/49 PASS; incluye el caso API |

Estas corridas pertenecen a los bytes y dependencias vinculados en el binding.
La revisión de integración no volvió a ejecutarlas.
La [revisión UI independiente](independent-review.md) no identificó un defecto nuevo accionable.
Su reparación pendiente de prueba API quedó resuelta en [primary-acceptance.json](api-expiry-completion-20261103/primary-acceptance.json).
La CI todavía debe probar el candidato integrado.

Se elevó `--min-tests 599` a `600` en `.github/workflows/savia.yml` por el único Fact añadido.
600 es el mínimo esperado; aún no es un conteo ejecutado de este candidato.
La CI de `6aeb9a3` no contiene C8 y no puede cerrar esta tarjeta.

## Procedencia y límites de publicación

Se conservaron los documentos históricos, parches, resultados saneados y aceptación del primary de C8.
También se exportó la [revisión C4/C5/C7](../technical-ready-review-20261104/primary-review.md).
Sus 48 archivos sumaban 462450 bytes antes de añadir esta nota.
Todos los JSON pudieron leerse y no se encontraron marcadores de claves privadas, tokens GitHub,
conexiones con contraseña ni salidas capturadas en los TRX saneados.
La búsqueda es una comprobación limitada; no demuestra ausencia universal de secretos.
No se publican logs originales, ZIP de SDK, bases, sesiones, certificados ni valores del oráculo privado.
El hook de publicación bloqueó los dos `.sanitized.trx` por su extensión `.trx`.
Se excluyeron del índice, conservando los archivos originales sin seguimiento ni renombrarlos.
Los JSON, conteos y hashes originales sí se publican; no se cambia la política del hook.
La [lista de fuentes revisadas](integration-source-inventory.json) identifica las dos exclusiones.

`git diff --cached --check` señaló espacios de contexto propios de los parches históricos
y una línea final vacía en dos informes recibidos.
Se conservan esos bytes y hashes; la comprobación de whitespace excluye únicamente los cuatro parches
recibidos, `technical-ready-review-20261104/checklist-verdicts.json` y su `independent-review.md`.
El código integrado y el resto de documentación sí pasan esa comprobación.

La revisión mantiene C4 5/5 y C5 4/4 técnicos, con READY formal reservado a Jason.
C7 conserva 5/6: el rechazo 409 registra una Operations durable.
El ledger pasa C7 de done a blocked para reflejar el criterio literal pendiente.
No se cambió el comportamiento ni se redujo el criterio para aprobarlo.

## Cierre requerido

Primary verifica CI del SHA publicado, 600 casos backend, 45 casos de navegador,
45 staff JS y C6 real contra la UI integrada.
Después actualiza Trello con lectura exacta y conserva la aprobación formal pendiente donde corresponde.
No se hace merge, despliegue, SQL local ni cambio de seguridad.
