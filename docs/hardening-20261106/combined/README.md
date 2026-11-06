# Candidato combinado ? RETURNED / NOT ACCEPTED

Task `savia-web-combine-20261106`. SUAZO-PC / T3 Code / Codex / `gpt-6.1-sol`.
High solicitado y expuesto por el harness/agent-awareness. Atestaci?n separada del proveedor y coste: desconocidos.
HEAD confirmado al inicio y final: `b30a275ac7de4e796f34ddf5fb80ebffb3eea98c`.
Worktree administrado: `C:/Users/Jason/.t3/worktrees/github/t3-b74f045e`.
Sin stage, commit, push, PR, merge, Actions, despliegue, SQL ni cuentas.

## Integraci?n y procedencia

Se verificaron 1,583 entradas de manifiestos contra bytes actuales de los dos workers antes de importar.
Se importaron solo 14 fuentes/pruebas permitidas y se integr? `tests/check.py` por separado.
La comparaci?n con la base com?n `6d8d53c964ca07cf173e3683a7660624d955aa4c` no detect? cambios upstream en esas 14 rutas.
`tests/check.py` conserva todas las adiciones staff/supply de Tony; el diff a?ade solamente tres l?neas de hardening.
`dist/` procede exclusivamente de `python prepare.py`; el snapshot procede de `python tools/verify_release_snapshot.py --record`.
No se copiaron salidas dist de los workers.
Se conserva D-030: frontend Jason preparado + im?genes Denis, sin nuevo dise?o.
La procedencia hist?rica p?blica sigue en `t3-631c15a4/docs/hardening-20261105/frontend-completion/reference-provenance.json`; no se invent? un Git SHA del sitio p?blico.

- [Importaci?n verificada](import-verification.json): origen y hashes originales/importados.
- [22 rutas cambiadas](changed-hashes.json): hashes RAW/LF y bytes originales de HEAD.
- [Fuentes y dist congelados](candidate-hashes.json): 3,126 archivos.
- [624 im?genes](media-hashes.json): 156 PNG + 468 WebP intactos; verificados contra el worker frontend y dist.
- [17 archivos de fuentes](font-hashes.json): intactos y con paridad de origen/dist.
- [Resultado completo](RESULT.json): comandos, exits, l?mites, fallos y responsables.

SHA256 de `changed-hashes.json`: `2d0dd0d3f6ae596a99cbfbbd4d0db30af165f4825eaf8e97b96065ad6079531b`.
SHA256 de `candidate-hashes.json`: `76b0b1649ef6649736bbb6f6210c6d2bb3c7240e180623345796cd8eca86d58f`.
Las pruebas usan los bytes RAW presentes; no se ejecut? otra suite sobre materializaci?n LF.

## Evidencia actual

Todos los comandos de [checks.json](checks.json) salieron 0.
Build limpio y repetido: 1,560 rutas/hashes iguales; 47 p?ginas / 40 productos / 120 variantes.
DOM29/29; localizaci?n17/17; cat?logo/editorial27/27; im?genes1/1; fuentes2/2.
Headers2/2; snapshot1/1 con controles negativos; runner7/7; estructura47 p?ginas.
Deployment14 tests, uno omitido por capacidad de symlink: no afirmar 14 ejecutados.
El texto remote-smoke PASS de esa prueba corresponde al transporte sint?tico, no a un sitio remoto.
Lock e instalaci?n: Wrangler4.158.0, Miniflare5.20261104.0-beta y Undici7.30.1.
Los audits npm completo y producci?n actuales reportan cero vulnerabilidades, exit0.
Las instalaciones usaron lock, `--ignore-scripts --no-audit --no-fund`; no upgrade latest.

`python tests/static_headers.py --runtime --port 18314 --output C:/Users/Jason/AppData/Local/Temp/savia-web-combine-20261106-runtime`: exit0.
Tres runtimes locales Wrangler: pol?tica presente, retirada y restaurada; nueve respuestas cada uno.
Se verificaron bytes, CSP restrictiva, noindex, nosniff, assets, 404, `_headers` oculto y marcador no-store.
No unsafe-eval ni wildcard. Credenciales CF/CLOUDFLARE ausentes del entorno del hijo; archivo env vac?o; telemetry false.
[Recibos HTTP y limpieza](runtime-evidence.json). Los logs brutos de Wrangler permanecen en el temporal indicado.

Chrome real complet? home ? cat?logo ? producto ? mini-bolsa ? checkout ? pedido en desktop y m?vil.
Lecturas reales1280x900 y390x844; `DEMO-0001`, pago simulado aprobado, USD190.00 en ambos.
El host Python18313 aplic? exactamente los headers de seguridad del repositorio para ejercer CSP en navegador.
Esto es distinto de la comprobaci?n HTTP real Wrangler18314.
[Desktop](browser-desktop.json), [readback final](desktop-readback.log), [m?vil](browser-mobile.json), [estados compactos](browser-summary.json).
Las lecturas guardadas no muestran errores de producto ni overflow; im?genes completas sin rotura salvo el primer home desktop transitorio, resuelto abajo.
Consolas finales y home limpio: aviso existente `GSAP target not found`, sin errores en esas muestras.
No se conserva historia exhaustiva de consola de todas las navegaciones.
Se hicieron 13 navegaciones de documento incluyendo baseline/rechecks; el presupuesto ped?a aproximadamente12.
No hubo formularios remotos ni datos reales.

Capturas inspeccionadas directamente: [desktop home](desktop-home.png), [desktop pedido](desktop-order.png), [m?vil home](mobile-home.png), [m?vil bolsa](mobile-bag.png), [m?vil pedido](mobile-order.png).
Tambi?n se guardaron los dos pasos de pago.
Las capturas no son aprobaci?n visual humana ni prueba de dispositivo f?sico.
No hay nueva medici?n comparativa de velocidad; se preservan los WebP y su carga real, sin atribuir mejoras hist?ricas a esta corrida.

## Fallos, correcciones y pendientes

| Artefacto / evidencia | Causa y correcci?n intentada | Estado / due?o / cierre |
| --- | --- | --- |
| Grabaci?n T3: `Preview automation recordingStart timed out after 15000ms.`; luego host ausente | Un intento soportado; AXI tras doctor complet? capturas/readback. La interfaz AXI documentada no graba. | Pendiente, primary: usar host funcional y conservar video real. No existe before original ni hist?rico recuperado. |
| AXI `run`: ESM loader rechaz? protocolo `c:` | Error de ruta Windows del instrumento; cambi? a comandos individuales documentados. | Resuelto: flows y readbacks actuales. |
| Contexto destruido al aprobar pago | La navegaci?n destruy? la evaluaci?n en curso; lectura independiente confirm? pedido y aprobaci?n. | Resuelto desktop y m?vil; recibos conservados. |
| Primer home desktop: una imagen rota y `ERR_CONNECTION_REFUSED` durante cambio del servidor | Nueva p?gina con servidor activo, mismo asset HTTP200/65,308 bytes; broken=[], overflow=false. | Resuelto por [recheck](desktop-home-recheck.log) y [consola](desktop-home-recheck-console.log); el fallo inicial permanece en recibos. |
| UnicodeEncodeError cp1252 al imprimir fuente/resumen | Error de salida terminal; us? codificaci?n expl?cita/resumen ASCII. | Resuelto; ninguna correcci?n a producto. |
| Aggregate Windows / WinError1314 hist?rico | No repet? fallo conocido ni cambi? permisos/fixtures. Deployment actual omite una prueba de capacidad. | Primary: suite Linux y deployment del SHA integrado, symlinks ejecutados. |
| Aceptaci?n independiente | Worker congela evidencia; no delega revisiones anidadas. | Primary, luego Gemini4 Argon/high y Astra/high; veredictos ligados a hashes. |

Puertos18313/18314 liberados por bind nuevo. P?ginas Chrome propias8/9 y tab T3 cerrados; p?gina previa3 restaurada.
El cierre de procesos Python por Ctrl+C devuelve exit1 esperado; los binds prueban liberaci?n.
No se detuvo el bridge compartido ni procesos ajenos.

NOT RUN: suite agregada Windows conocida, Linux CI, cr?tico/juez, despliegue, remote smoke, SQL/backend/staff/golden-path runtime y cobros reales.
Pedidos y pagos probados son simulados y locales. Producci?n sigue sin aprobaci?n; C2/C9/C10 y gates operativos permanecen abiertos.

Siguiente acci?n: primary inspecciona los bytes congelados, integra serialmente, obtiene cr?tica/juez y Linux del SHA integrado.
Lecci?n aplicada: el ?xito del click que navega se comprueba en la p?gina destino; una imagen fallida durante recambio del servidor requiere carga limpia y readback HTTP antes de atribuir un defecto al producto.
