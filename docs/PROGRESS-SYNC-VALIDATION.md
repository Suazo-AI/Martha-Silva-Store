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
