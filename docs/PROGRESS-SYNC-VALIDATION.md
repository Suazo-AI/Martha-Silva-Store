# Validación del registro de avances

Host local: `SUAZO-PC`, Windows. Alcance: registro Git y exportación de evidencia.

- `python tests/test_progress.py`: PASS, 13 pruebas; Git temporal real y transporte remoto simulado.
- `python tests/test_sync_progress.py`: PASS, 16 pruebas del helper histórico; no prueba el push nuevo.
- `python tools/export_progress.py --verify`: PASS, 15 hashes de evidencia preservada, sin runtime.
- `git diff --check`: PASS, comprobación de whitespace del diff.

El archivo congelado `evidence/savia/20261030/` conserva CRLF y queda excluido
del control de whitespace mediante atributos; sus bytes se verifican por SHA-256.

Las pruebas nuevas cubren índice frente a working tree, recibos idempotentes y alterados,
secretos en bytes staged, rutas sensibles, symlinks, rama/remoto incorrectos, recibo ausente,
push de SHA exacto, rechazo sin reintento y lectura remota discrepante.
El primer push real debe acreditar el hook completo con SHA remoto coincidente.
El recibo local de esa lectura está en `.git/progress-sync.json`, fuera del repositorio.

## Resultado real verificado

Primer commit publicado por los hooks: `115b95197250b86121282116ff808ba3923f286f`.
`pre-commit` agregó el recibo de 37 archivos. `post-commit` hizo el push y confirmó
el SHA mediante `ls-remote`; una consulta independiente de la referencia GitHub coincidió.
La lectura remota de `docs/SAVIA-LATEST.md` coincidió con el blob local
`c45c8c4b45de66910ef6fb8af1267ba56a99e9ac`. Working tree limpio después del push.

- [CI del registro](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41173856157): PASS, incluidos tests, recibo y hashes.
- [CI de tienda](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41173856076): integridad/build/sintaxis PASS; regresión histórica FAIL.
- [Run anterior a este cambio](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41170326976): ya terminaba en `failure`.

## Fallo pendiente de la suite histórica

`python tests/check.py --install` termina con exit 1 al ejecutar
`node --test tests/original-catalog.cjs`. Tres comprobaciones fallan:

1. `all 40 original products retain their captured sample prices, variants and stock`.
2. `other 39 products remain exact; Green alone uses its independently approved media selection`.
3. `every rendered gallery, responsive image and product-video file exists locally without symlinks`.

Los dos primeros rechazan diferencias contra el catálogo original congelado.
El tercero falla en `assert.ok(references.size > 700)`.
Este commit no modifica catálogo, medios ni esa suite. La entrega de la tienda ya
documentaba incompatibilidades entre el catálogo histórico y las ilustraciones luxury.
No se da por aprobada la suite completa; los pasos posteriores al primer fallo no corrieron.

No se intentó cambiar la tienda ni reescribir los criterios históricos: esta tarea
autoriza sincronización y documentación. La corrección pertenece a una tarea de catálogo.
Responsable siguiente: agente de tienda, con el catálogo actual como artefacto explícito.
Recomendación: conservar la suite original para su fixture y definir las expectativas
del catálogo luxury con evidencia de las decisiones autorizadas.
Antes de editar UI o medios, aplicar el gate del proyecto.
Cerrar con `python tests/check.py --install` aprobado sobre el fixture correcto,
sin eliminar controles de integridad ni afirmar fotografías originales para imágenes generadas.

La suite completa `tests/check.py --install` se ejecuta por el workflow existente
`Tony source snapshot`. Este checkout local es parcial y no contiene `build-inputs/`
ni `dist/`; no se afirma ejecutar aquí las pruebas que los necesitan.
El workflow conserva sus fallos históricos; no se cambió para ocultarlos.

Los cinco archivos C# son fuentes históricas importadas, no lógica nueva del producto.
No se ejecutó SQL ni se repitió la suite C# de 581 resultados en esta publicación.
No se ejecutaron los scripts históricos del diagnóstico, navegador, Docker ni certificados.

CI nuevo: `Progress documentation`, pasos de pruebas, recibo y hashes.
Consultar el resultado asociado al SHA publicado antes de afirmar que pasó.

Correcciones durante esta tarea: la prueba de symlink necesitaba `update-index --add`.
La exportación necesitaba la ruta completa del contenedor histórico R7.
Se corrigieron las rutas y se volvió a comprobar el comportamiento afectado.
Lección aplicada: probar el índice y el transporte por separado; la aceptación exige lectura remota.
