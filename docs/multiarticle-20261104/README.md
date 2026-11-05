# Venta multiartículo completa y recuperable

Autorizada por Jason el 2026-11-04, America/Managua. Implementación en Tony; sin merge ni despliegue.
Host local: SUAZO-PC. Datos de prueba sintéticos. D-023 deja de ser una limitación de una línea en la UI.

## Comportamiento

- Agregar, quitar y editar hasta 100 artículos distintos en una venta. Una fila por artículo; cantidad entera de 1 a 100000.
- Una sucursal, una clave y un cuerpo completo por intento. El navegador no envía precios ni totales.
- Guardar el intento antes del POST y bloquear carrito, sucursal y confirmación mientras sigue pendiente.
- Reintentar usa el mismo cuerpo y clave. Recargar consulta la operación original, sin emitir otra venta.
- Conservar las líneas pendientes aunque un artículo salga del catálogo activo. El servidor conserva la autoridad sobre el resultado.
- Comprobar todas las identidades, cantidades, importes y total del recibo. Admitir otro orden; rechazar líneas faltantes, extras o duplicadas.
- Después de confirmar, vaciar las líneas y exigir elegir un artículo para la siguiente venta. Otro clic no reenvía el carrito anterior.

## Verificación del candidato

Pruebas locales: 52/52 de frontend, incluidas siete nuevas pruebas multiartículo; 16/16 de seguridad del arnés de navegador y 17/17 del arnés API.
Chrome con API simulada: los recorridos multiartículo pasan a 390 y 1440 píxeles, con pérdida de respuesta y recuperación tras recarga.
El recorrido completo de Chrome con API simulada pasa 47/47, sin errores JavaScript ni solicitudes externas.
Las pruebas reales del candidato `922852cbf6c9af2eacb2e5c02a42d912c14f6893` pasan:
backend HTTP+SQL 601/601, Chrome con API simulada 47/47, golden API+SQL 19/19 y Chrome→API→SQL 21/21.
[SAVIA judge](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41956521427) y
[SAVIA golden path](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41956521562) terminaron success sobre ese SHA.
[Recibo CI y hashes](ci-receipt.json), [oráculos C6](c6-oracles.md), [evidencia C6](c6-evidence.json) y [backend](backend-results.json).
Ocho hashes de fuentes servidas/arnés coinciden con los blobs Git del candidato; no se usan resultados de otro SHA.

El arnés C6 se amplió a dos líneas por cada venta. Sus oráculos exigen dos ventas, cuatro líneas y cuatro movimientos de venta;
existencia total 25 desde 30, primer artículo 7, segundo 8 y tercero intacto en 10. La recarga debe conservar esas cuentas.
La pérdida de respuesta ocurre después de un HTTP 200 real. Tras recuperarla y recargar otra vez, SQL mantiene esas mismas cuentas;
cero claves duplicadas, cero líneas sin movimiento único y cero diferencias entre movimientos y balances.
Las pruebas existentes de replay inmutable y rollback de la segunda línea pasan en la suite 601/601.
Las bases, API y procesos de navegador desechables se eliminaron con readback de ausencia.

Comandos locales:

```powershell
$env:NODE_PATH=(Resolve-Path tests/frontend-deps/node_modules).Path
node --test dev/savia-staff-ui/*.test.mjs
python tests/test_golden_path_browser_safety.py
python tests/test_golden_path_safety.py
node tests/browser-mock-validation.mjs <playwright-instalado> <directorio-evidencia>
```

## Revisión y límites

Crítico: gpt-6.1-sol / high. Jurado: gpt-6-astra / high. Dictamen final: APTO técnicamente; sin defectos accionables abiertos.
El crítico pidió normalizar UUID, validar el recibo completo, conservar el pendiente fuera del catálogo y limpiar el carrito confirmado.
Las cuatro correcciones están incorporadas y tienen pruebas de comportamiento. El jurado detectó la última antes de la publicación.
[Crítico](critic.md) y [jurado](jury.md). [Resultados locales](local-verification.json) y [Chrome completo](browser-complete.json).
[Jurado de evidencia CI](jury-ci.md): aceptación técnica del incremento; no aceptación operativa ni producción lista.

[Antes: una línea](before-single-article.webm) · [Después: escritorio](multiarticle-desktop.webm) · [Después: móvil](multiarticle-mobile.webm).
Grabación y capturas muestran datos sintéticos y respuestas simuladas; no son evidencia SQL ni aprobación visual de Jason.
Se conservan los tokens y distribución existentes. Capturas: [carrito móvil](multiarticle-mobile-cart.png) y [recibo](multiarticle-mobile-receipt.png).

El comando general tests/check.py falla localmente: WinError 1314 en tres fixtures de enlaces simbólicos.
No se elevan permisos para evitarlo; el check Historical portable regression suite del CI Linux del candidato pasó.
El CLI no-mistakes informa repo no inicializado;
no se instaló otro gate ni proveedor. Se usan los controles existentes y la revisión independiente, sin afirmar ejecución de ese pipeline.

Lección aplicada: vaciar el carrito al confirmar evita repetir la selección con una clave nueva. Prueba: segundo submit sin elegir artículo, cero POST extra.
Las expectativas antiguas de opciones contaban el placeholder como artículo. Se corrigieron para contar únicamente opciones con identidad;
el recorrido completo volvió a pasar 47/47. Una ejecución inicial perdió validez al cambiar fuentes durante la prueba; fue reemplazada por la ejecución completa con hashes estables.

Recuperación cubierta: recarga/reintento en la misma pestaña mediante sessionStorage. Cerrar la pestaña, borrar almacenamiento o cambiar de equipo
no está cubierto por esta recuperación. No se presenta como recuperación ante desastre ni como ensayo productivo aceptado.
Pagos siguen not_processed. Este recibo es interno; no es prueba de cobro bancario ni de cumplimiento fiscal.
C1 (excepción de stock y variables), C2, C9 y C10 mantienen sus brechas. No se ejecuta SQL, Docker ni certificados en SUAZO-PC.

## Siguiente acción y responsables

Incremento técnico completado y publicado en Tony. [Trello SALE-MULTI](https://trello.com/c/ADACfDwh).
Primary comprobó los artefactos, hashes, rollback/replay, limpieza y revisión del jurado. Las pruebas no acreditan cero errores futuros.
El siguiente incremento recomendado es implementar la excepción de stock acordada D-026/D-027; permanece pendiente y no se amplía este cambio.
Jason conserva la aceptación operativa, el merge y el despliegue. PR #2 permanece abierto con head 8744a969;
main protegido conserva 3b004916. Publicar en Tony no modifica ni fusiona el PR.
