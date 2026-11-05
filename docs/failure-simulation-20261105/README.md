# SAVIA deterministic failure injection

Task SAVIA-FAULT-SIM-20261105. Worker: T3 Code / Codex, gpt-6.1-sol / high, Windows.
Candidate: Tony@7d61524. Synthetic data only. Local tests; no commit or push.
Resultado local: focused 50/50 PASS; staff glob 102/102 PASS. Cero fallos, omisiones o cancelaciones.
Se ejecutaron dos comandos de prueba. No se corrigieron producto ni expectativas después de ejecutarlos.
Worker return no equivale a aceptación del primary ni del crítico/jurado.

Real imports: mountCommerce, createStaffClient, readReceipt and StaffRequestError.
Only HTTP, storage failure and response scheduling are doubled. No real network fallback.
jsdom does not establish SQL, browser, mobile/device, layout, backend idempotency or payment correctness.

See MATRIX.json for frozen coverage and RESULT.json for exact commands, exit codes and hashes.

## Ejecución

```powershell
$env:NODE_PATH='C:/Users/Jason/MARTHA-SILVA/github/tests/frontend-deps/node_modules'
node --test dev/savia-staff-ui/failure-simulation.test.mjs
node --test dev/savia-staff-ui/*.test.mjs
git diff --check
```

Ambos comandos Node devolvieron exit 0. Tiempos de pared: 2762 ms y 2823 ms.
Node v24.18.0, jsdom 26.1.0, SUAZO-PC. NODE_PATH solo se estableció en el proceso PowerShell hijo.
Los logs conservan salida de pruebas con datos sintéticos; no contienen sesiones ni HTTP reales.

## Cobertura comprobada

Diez familias F01–F10. Node cuenta 50 pruebas nuevas: 48 hojas y dos contenedores con subpruebas.
El glob incluye esas 50 y las 52 existentes; no son 102 escenarios comerciales independientes.
F09 tiene ocho clases de corrupción. F10 repite esas clases con 32 pares de cantidades distintos y orden alternado.
F10 usa semillas 1–32 y 192 acciones explícitas: construir cuerpo, construir recibo, elegir orden, validar, corromper, rechazar.
No es exploración exhaustiva. Los pasos fijos y los sondeos del event loop no se suman como escenarios independientes.
Las semillas no usan RNG. Las claves UUID de la aplicación sí son aleatorias; el oráculo compara identidad, sin depender de un UUID específico.
No hubo fallos que minimizar. Si F10 falla, emite semilla y secuencia fija de reproducción; no ejecuta un minimizador automático.

F03 retiene el 404 de un recibo confirmado. El primer submit queda bloqueado durante start.
Luego clear/start cambia la generación, con eliminación explícita del recibo obsoleto en almacenamiento simulado.
Una nueva venta queda pendiente mientras llega el 404 anterior. La clave/cuerpo pendiente sobrevive y la venta confirma.
Una venta nueva en la misma generación mientras start espera ese 404 está impedida por busy; no se fuerza esa ruta imposible.
F02 prueba aparte el descarte normal por 404 seguido de una venta completa.
F04 simula recarga mediante una nueva instancia DOM/cliente y copia exacta del sessionStorage pendiente.
El retry compara POSTs completos; la recarga confirma todas las líneas y cantidades sin POST nuevo.
F07 inyecta 401 real para el cliente simulado mientras un POST queda retenido; el resultado tardío no repuebla DOM.
Su primer stock HTTP200 tiene cuerpo inválido intencional; esa lectura falla antes de la revocación, sin bloquear la venta.

## Alcance y entrega

Únicos archivos nuevos: test, README.md, MATRIX.json, RESULT.json, focused.log y staff-glob.log.
Los cuatro grupos untracked ajenos del estado inicial se conservaron. Ningún archivo de producto cambió.
git diff --check devolvió 0; verificación adicional de whitespace de archivos nuevos registrada en RESULT.json.
Los hashes son posteriores a las pruebas; tracked sources siguen sin diff contra HEAD.
No se reprodujo un defecto de producto. No hay propuesta de fix necesaria a partir de esta ejecución.
No se ejecutó SQL, Docker, certificados, servicios, red, pagos, instalación, commit, push ni PR.

Límite: el POST simulado puede aceptar o perder respuesta, pero no demuestra commit durable ni unicidad SQL.
No cierra C9/C10 ni aceptación operativa. No modifica el ledger ni evidencia histórica.
Lección aplicada: retener efectos permite comprobar el bloqueo durante el intervalo, no solo después de recuperar.
Prueba concreta: F01 observa cero POST y pendiente intacto antes de liberar la respuesta.

Siguiente acción: primary revisa código, logs y matriz, y solicita revisión independiente del crítico/jurado.
Dueño de aceptación: primary/Jason. Cierre: verificar assertions, alcance y límites contra los criterios congelados.
