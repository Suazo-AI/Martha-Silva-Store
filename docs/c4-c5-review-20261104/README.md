# C4 y C5: revision tecnica independiente

Resultado: **APTO tecnico** para C4 y C5, sin hallazgos bloqueantes.
Revision de fuentes en `d475d6d4a2caffe9d8181acdff80794ff3f6abb4`.
Los contratos y checklists quedan C4 **5/5**, C5 **4/4**.
No se modificaron producto, pruebas, ledger ni Trello.

## Evidencia comprobada

- C4: script de release completo, incluida `20261027224500_InternalBranchScope`; igualdad con generacion EF y ausencia de modelo pendiente. Aplicacion a base vacia e historia sintetica, preservacion de filas, readback y reaplicacion. Seis metodos focales 1/1 dentro de backend 601/601.
- C5: API real con SQL desechable y migraciones de release; cinco identidades sinteticas. Smoke 19/19, 18 capturas SQL sin violaciones. Venta, replay, conflicto 409 y recuperacion conservan una venta, una linea, un movimiento de venta y stock 28. Logout deja cero sesiones activas.
- Retirada observada: API exit 0, base borrada y directorio privado retirado. Publicacion y ausencia de contenedor constan en logs vinculados. Se conservaron 38 warnings, con cero fail/crit.
- Comparacion offline de seis conjuntos del oraculo privado congelado contra el modelo publico: historia 2, tablas 19, checks 32, claves foraneas 26, indices 37 y claves primarias 19; igualdad exacta y hash congelado coincidente. No se exportaron valores privados.
- GitHub: 21 checks del SHA `8744a9699812d62ea5ed31c63781748f833c3def`, 16 success, 5 skipped, cero fallidos o pendientes.

Backend: [run 41779354410](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41779354410).
Golden: [run 41779354413](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41779354413).

El checkout real de CI fue `2c29209667631c38047f33f3e84f4d777a7740e3`, con arbol identico a 8744.
De 8744 a d475 solo cambian cuatro documentos. Producto, migraciones, dependencias, pruebas y workflows conservan bytes.
La evidencia runtime se reutiliza por equivalencia de fuentes; no se afirma CI propio de d475.

## Revision y comprobacion

El juez existente `gpt-6-astra/high` reviso fuentes inmutables y artefactos en SUAZO-PC.
Root verifico por separado sus hashes de fuentes y artefactos, seis resultados C4 nominales, pasos C5, igualdad de oraculos despues de replay/conflicto/recuperacion, retiro, GitHub, Trello y el oraculo privado congelado.

Comandos focales: `git show <SHA>:<ruta>`, `git diff --name-only 8744a969 d475d6d4`, calculo SHA256 de blobs Git y artefactos, y verificaciones JSON offline.
La guarda de divergencia compara el SQL registrado con `IMigrator.GenerateScript`; no modifica migraciones historicas.
El script de verificacion de esta revision completo todas sus aserciones y exporto solo evidencia revisada.

Consulte [acceptance.json](acceptance.json), [dictamen independiente](judge/REVIEW.md), [hashes del juez](judge/evidence.json), [checks](checks-readback.json), [Trello](trello-readonly.json) y [comparacion saneada](private-oracle-comparison.sanitized.json).

## Limites y siguiente accion

La prueba de runtime es sintetica Linux. No se ejecuto nuevamente SQL, API, Docker, compilacion ni suites pesadas durante esta revision.
El arnes local documentado requiere POSIX PTY; Windows no esta probado por este run.
La sucursal se inserta mediante EF porque no existe endpoint HTTP de creacion.
Las rutas de fallo y retirada de publicacion se revisaron en codigo; no hubo una nueva inyeccion de fallos runtime.
Los digests de ZIP proceden de GitHub; los hashes de JSON locales y blobs Git si se recalcularon.
El scanner cubre secretos conocidos y no demuestra ausencia universal de secretos.
Se excluyeron bases, secretos, sesiones, certificados, logs privados, valores de fixtures privados y autorizaciones de ejecucion.

C4/C5 quedan aceptados en su contrato tecnico. Esto no acredita operacion real, produccion ni despliegue.
Esta revision no acepta ni cambia C9, los siete TONY en review o N5-COV.
La siguiente accion fuera de este informe conserva sus permisos y criterios existentes.

## Check documental local y limite del host

`python tests/check.py` se ejecuto en SUAZO-PC y termino con exit 1.
El build reproducible coincidio en 1082 rutas/hashes; las etapas previas a asset-audit pasaron.
`tests/asset-audit.py` ejecuto seis tests y registro tres errores de creacion de symlink: `OSError: [WinError 1314] A required privilege is not held by the client`.
La falla ocurre en `Path.symlink_to`, antes de la asercion del producto; es una limitacion de privilegios de este host.
No se modificaron pruebas, permisos, Developer Mode ni controles. Las etapas posteriores del runner local no se ejecutaron.

Ruta alternativa comprobada: [Portable checks ubuntu-latest, job 126407090176](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41779354483/job/126407090176), SHA 8744, registra `python tests/check.py --install`, seis tests de assets OK y `PASS: all recovered-demo automated checks`.
Las fuentes de ese runner y de las pruebas son identicas en d475.
Esto conserva prueba Linux valida y no convierte el intento local fallido en PASS.
La limitacion local queda abierta: responsable Jason para decidir un entorno Windows con privilegio symlink si necesita PASS nativo; comprobacion de cierre `python tests/check.py` exit 0. No bloquea el dictamen tecnico C4/C5 ni la publicacion de este informe documental.
