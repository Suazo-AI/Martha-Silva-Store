# C6: delta mínimo de lectura del 401

Fecha UTC: 2026-11-04T02:46:35.792Z. Host: SUAZO-PC. Ejecutor: gpt-6.1-sol / xhigh.

Solo se cambió tests/golden-path/browser_path.mjs en el worktree C6 autorizado.
La propuesta difiere en un único bloque: guarda la respuesta de GET /internal/api/security/me, consume response.arrayBuffer() y conserva response.status.
El archivo resultante coincide byte por byte con browser_path.mjs.proposed del primario.
Se mantienen las guardas de 2ddf: HTTP204, URL/login, GETme401, SQLsesiones0 y readback de grupos propios.
No se modificaron las otras cuatro rutas C6, canónico, importador, Git ni producto.

## Comprobación única

| Comando | Resultado |
|---|---|
| python -m unittest discover -s tests -p test_golden_path*_safety.py | Ran33 tests in0.744s; OK; exit0; 17C5+16C6 |
| node --check tests/golden-path/browser_path.mjs | exit0, sin salida |
| ast.parse de golden_path.py y test_golden_path_browser_safety.py | PYTHON_AST_OK2files; exit0 |
| git diff --check | exit0, sin salida |
| Igualdad de bytes con propuesta | true |
| Whitespace final JS | 0 líneas |

Los comandos/argumentos exactos y stdout/stderr están en b6-body401-checks.json. No se repitió ninguna de las cuatro comprobaciones.

## Qué demuestra b6 y qué queda sin demostrar

Lectura puntual de GitHub: run41758450353, attempt1, pull_request, headb6bc0396bb7d53359d23b806a3177edc194c8e62, completed/success.
Inicio2026-11-04T02:05:39Z; actualización2026-11-04T02:07:33Z. Workflow .github/workflows/golden-path.yml.
El diff Git 6aeb9a35..b6bc0396 del JS muestra solo el bloque que consume el cuerpo401.
La función checkpoint espera page.waitForLoadState(networkidle) antes de publicar sus notas.
Así, la evidencia respalda que el candidato con esa lectura puede terminar verde en CI real.
No demuestra por sí sola que todo cuerpo401 sin consumir siempre mantenga abierta la petición ni que esa sea la única causa posible del timeout anterior.
El comentario de b6 afirma ese mecanismo; aquí no existe una reproducción local o traza de red que lo confirme de forma independiente.
No se hizo un nuevo probe, SQL, API, Docker ni descarga de artefactos.
La lectura del wrapper de jobs no se pudo interpretar; no se inventan jobIDs ni conteos de pasos a partir de ella.
El artefacto saneado no estaba en la ruta local esperada; su contenido no se revisó otra vez ni se descargó.
Los 9PASS/0FAIL/3SKIP/12 comunicados por el primario corresponden a Checks de PR, no a una aceptación automática de las17 afirmaciones C6.

El headb6 no contiene2ddf ni las nuevas guardas Chrome/C8. Por ello, ese run no valida el candidato combinado.
Las33 pruebas ligeras validan fronteras y sintaxis; no prueban ventas, revocación SQL o retirada real de procesos del candidato combinado.
Siguiente cierre: el primario resuelve Git solo tras la autorización pendiente y publica el candidato autorizado; CI de ese SHA debe aportar las17 comprobaciones ya congeladas.
No hay sondeo continuo activo.

SHA256 antes: 60e9c9a636dac13149a57449247edce1491c842d727936d6d8e2e760bb5a7aaf
SHA256 entregado/propuesta: 5a09272ffb8a1c433813bc4cad626921cd1b0ef329f0097a008122e41eb6df21
