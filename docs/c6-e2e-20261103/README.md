# C6: Chrome → API HTTPS → SQL

Estado de esta publicación: primera ejecución real parcial; corrección importada; **nuevo CI y reevaluación independiente pendientes**.
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

Primer CI real: [41757409404](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41757409404),
head `6aeb9a35f45331ace85ac48dc19bfd9264b0f722`.
Chrome `156.0.8078.47`, Node `v24.22.1`, Playwright `1.63.0`.
C5 smoke pasó. C6 confirmó diez checkpoints de navegador, incluida respuesta perdida tras commit,
recuperación GET con clave original y recarga repetida: dos ventas, dos líneas, dos operaciones de venta,
dos movimientos de venta, stock 27 y cero invariantes fallidas.
Falló únicamente `browser.logout` tras 20126 ms; no se declara C6 PASS.
La causa de ese timeout todavía no estaba demostrada al registrar esta corrida.
API, base y directorio privado se retiraron; el paso de destrucción del contenedor pasó.
La ausencia explícita de Chrome/Node requiere una guarda adicional señalada por el juez.
Los [bytes saneados y binding](ci-41757409404/run-binding.json) conservan el fallo sin sobrescribirlo.
El ejecutor corrige su alcance y el juez independiente revisa el snapshot aislado.

La corrección posterior conserva la hipótesis de timeout sin atribuirla al producto.
Logout observa el HTTP 204 antes de comprobar navegación, formulario y `/me` 401.
Cada fase publica un código fijo de fallo, sin mensajes crudos.
CDP identifica el PID Chrome; Linux exige perfil privado, ascendencia y hora de inicio propios.
La retirada consulta ambos grupos Node/Chrome y no permite PASS si una lectura falla o quedan procesos.
Las 33/33 pruebas ligeras pasan, incluidas persistencia, reutilización de PID y lectura denegada.
El probe local dejó sus dos perfiles ausentes, Chrome vivos=0 y señales=0.
[Procedencia del delta](correction-import.json) · [informe del ejecutor](implementation.md).
Estas pruebas no sustituyen un nuevo CI Chrome/API/SQL.

| Bloqueo | Evidencia / causa | Acción y resultado | Dueño / cierre |
| --- | --- | --- | --- |
| C6 logout FAIL inicial | CI 41757409404 confirmó negocio/recuperación; logout agotó 20s | Gates explícitos importados y comprobaciones ligeras33/33; corrida real pendiente | Coordinador: exigir C5/C6 PASS y verificar evidencia y retirada en nuevo SHA |
| Revisión independiente pendiente | Dictamen inicial NO APTO: logout y ausencia Chrome;15/17 cumplidos | Jason autorizó gpt-6.1-sol/xhigh; juez reevalúa delta de ambos hallazgos | Primary verifica dictamen y nueva evidencia antes de aceptar |
| C8 CI pendiente | Seis archivos importados con blobs iguales al patch probado | Rojo/verde conservado; mínimo backend elevado a600 por nuevo Fact | CI del candidato integrado y C6 contra esa misma UI |
| C9 requiere alcance nuevo | Falta medir restaurada con ventas, RTO/RPO en SUAZO-PC y campos SQL/TLS actuales | Revisión documental terminada; cero SQL/API/Docker nuevos | [Informe C9](../c9-recovery-20261103/PREPARATION.md#bloqueos-reales-y-cierre) fija causa, efectos, rollback y comprobación |

La lectura de `.github/workflows/ci.yml` confirma que el despliegue exige main y habilitación expresa.
La variable `CLOUDFLARE_DEPLOY_ENABLED` estaba ausente (HTTP 404); no se modificó.
Esta continuación no fusiona a main ni despliega ni cambia seguridad.
El [alcance propuesto de preflight C9](../c9-recovery-20261103/PREFLIGHT-SCOPE.md) queda sin autorizar ni ejecutar.

Lección aplicada: el evento del navegador no basta; SQL debe confirmar el commit antes de permitir recuperación.

## Union puntual C6 y validacion combinada pendiente

Ver [RECONCILIATION.md](RECONCILIATION.md). Jason autorizo conservar 2ddf83de y b6bc0396 mediante una union con recibo y una excepcion limitada al unico SHA remoto nuevo. Resolucion revisada; 33/33 ligeras PASS. CI combinado y cierre de los 17 checks pendientes.
