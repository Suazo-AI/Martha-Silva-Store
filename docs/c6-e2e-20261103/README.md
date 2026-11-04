# C6: Chrome → API HTTPS → SQL

Estado de esta publicación: implementación integrada; **ejecución real y revisión independiente pendientes**.
Tarjeta: https://trello.com/c/ezVfv0Pk. PR: https://github.com/Suazo-AI/Martha-Silva-Store/pull/2.
Fecha local: 2026-11-03; host de coordinación `SUAZO-PC`.

## Estado inicial y coordinación

El PR empezó en `260b75951729189d987ffe423218ab1643bcfa3c` con **12 PASS, 0 FAIL, 3 SKIP**.
Los SKIP configurados eran integración limitada a main, artefacto main y despliegue.
Ese CI probaba API/SQL y navegador con mocks por separado; no cerraba C6.

FIX-PR2 terminó su cierre documental en `9b35697ae29e0c793fc7ed4448ec6e77a1f85ee3`.
Se comprobó `SYNCED` y ese mismo SHA en Tony y la rama del PR antes de tomar el checkout.
Solo cambió documentación y recibo desde la base del ejecutor; se conservó esa historia.
C8 conserva sus ejecutores y worktrees; C9 hizo una preparación documental aislada.
No se duplicaron sus pruebas ni se añadieron sus cambios ajenos al índice de C6.

## Cambio y evidencia disponible

Se conserva C5 smoke. El workflow añade una corrida separada `--mode browser` con Chrome, Playwright 1.63.0,
la API Release real y otra base sintética en el mismo contenedor SQL desechable.
El navegador espera el acuse del oráculo SQL después de cada checkpoint.
La respuesta de la segunda venta se descarta después de recibir el HTTP 200 real; la recuperación consulta la clave original.

- [Contrato de aceptación](ACCEPTANCE.md): 17 afirmaciones verificables.
- [Informe del ejecutor](implementation.md): 29/29 pruebas ligeras, sintaxis, riesgos y NOT RUN explícito.
- [Procedencia de la importación](import-manifest.json): fuentes exactas y exclusiones.
- [Trello: comentarios iniciales comprobados](trello-start.json).
- [Preparación C9](../c9-recovery-20261103/PREPARATION.md): respaldo existente, brechas y siguiente alcance, sin SQL nuevo.

La revisión directa detectó un uso no válido de `expect.setTimeout`; se sustituyó por `expect.configure` comprobado en el paquete local.
También se hizo idempotente la retirada del grupo propio de Node/Chrome.
Las 29 pruebas ligeras incluyen una barrera adversarial: si SQL ve solo una venta, no se permite recuperar la segunda.
Son dobles; no demuestran una venta real.

Solo se publican `evidence.json` y `oracles.md` después de verificar sus bytes.
No se graban ni publican HAR, trace nativo, sesiones, perfiles, bases, backups, claves ni logs privados.
La traza del artefacto consiste en eventos permitidos y sintéticos, con DOM, rutas, HTTP, claves de operación y oráculos.
El escáner de secretos conocidos conserva su límite: no acredita ausencia de secretos desconocidos.

## Bloqueos y siguiente comprobación

| Bloqueo | Evidencia / causa | Acción y resultado | Dueño / cierre |
| --- | --- | --- | --- |
| C6 real NOT RUN | El alcance local no inicia Docker/SQL/API; el arnés usa POSIX | Fuentes y workflow preparados para el CI Linux existente | Coordinador: publicar candidato, exigir C5 y C6 PASS, bajar evidencia y verificar retirada |
| Revisión independiente pendiente | El ejecutor no acepta su propio trabajo; la selección del juez está solicitada | Diff y contrato congelados; no se declara C6 terminada | Jason confirma modelo/razonamiento; juez de solo lectura; primary comprueba hallazgos |
| C8 aún separado | La evidencia local pertenece a su parche, no al SHA publicado | Su ejecutor prepara patch sobre el head actual y conserva rojo/verde | Integración posterior con CI del candidato y conteo nuevo de suite |
| C9 requiere alcance nuevo | Falta medir restaurada con ventas, RTO/RPO en SUAZO-PC y campos SQL/TLS actuales | Revisión documental terminada; cero SQL/API/Docker nuevos | [Informe C9](../c9-recovery-20261103/PREPARATION.md#bloqueos-reales-y-cierre) fija causa, efectos, rollback y comprobación |

La lectura de `.github/workflows/ci.yml` confirma que el despliegue exige main y habilitación expresa.
La variable `CLOUDFLARE_DEPLOY_ENABLED` estaba ausente (HTTP 404); no se modificó.
Esta continuación no fusiona a main ni despliega ni cambia seguridad.

Lección aplicada: el evento del navegador no basta; SQL debe confirmar el commit antes de permitir recuperación.
