# Ensayo, sustitución de SISFAIN y calidad verificable

Corte: 2026-11-04, America/Managua. Host: SUAZO-PC. Modo: DISCOVER y simulación offline.
Resultado externo buscado: sustituir el servicio que usa Martha sin perder ventas,
inventario, saldos ni continuidad. Cuello de botella: paridad comercial desconocida
y módulos de operación todavía ausentes. No es un despliegue ni un ensayo C10.

[Abrir explicación interactiva](index.html) · [Resultados](results.json) ·
[Cuestionario actualizado](../sprint-20261104/CUESTIONARIO-MARTHA.md).

## Qué demuestra este trabajo

Se preparó un modelo ficticio ejecutable con **18 escenarios y 51 comprobaciones**.
El modelo detectó tres resultados alterados: total incorrecto, doble descuento de
stock y abono duplicado. Su resumen es `18 passed, 0 failed`.
La ejecución y los cuatro checks documentales constan en [revisión](REVIEW.md).
No se ejecutó código SAVIA, API, SQL, Docker, certificados ni transacciones reales.

El guion cubre autorización de ajuste, entrega tras conciliación, ausencia física,
venta con tres renglones/cuatro unidades, respuesta perdida, identidad distinta,
atomicidad secuencial, pago insuficiente, rol prohibido, última unidad secuencial,
recepción parcial, devolución parcial, crédito/abono, cierre, snapshot/restauración,
alteración de snapshot, treinta ventas ficticias y controles negativos.

La jornada enlazada usa compra → recepción → venta → devolución → crédito → abono
→ cierre → snapshot/restauración. Otros escenarios reinician sus fixtures para
aislar condiciones. No se presenta todo como una sola jornada compartida.

**Límite:** es un modelo didáctico de reglas propuestas. No implementa el producto
ni toda la oferta SISFAIN. No modela impuestos, autorización fiscal, pagos a
proveedores, cotizaciones, costos contables, todas las rutas de reembolso, múltiples
bodegas ni importación real. Los informes contienen contratos propuestos para esos
flujos, no resultados ejecutados. No certifica concurrencia SQL ni mide latencia.

## Quién acepta y qué significa aceptar

D-022 ya asignó el dictamen a **SUAZO-PC**, no a Martha. Martha describe operación
y aporta configuración; una persona que vende ejecuta el ensayo. Jason conserva
las autorizaciones de integración y despliegue. Son responsabilidades distintas.

El ensayo es un recorrido controlado con datos ficticios sobre la aplicación y
montaje previstos. Cada flujo tiene fixture inicial, resultado esperado, ejecución
observada, comprobación independiente y dictamen. APTO permite continuar dentro
del alcance probado. RECHAZADO identifica una diferencia concreta. BLOQUEADO
indica una condición no demostrada, como recuperación pendiente.

El guion vigente de C10 conserva cinco tareas: vender, perder respuesta y recuperar,
consultar existencias, intentar acción prohibida y cerrar sesión. La explicación
visual propone extender el contrato al reemplazo: venta multiartículo, conciliación
y devolución. Esa extensión es propuesta; no modifica silenciosamente los criterios
históricos de C10 ni acepta cobros o documentos fiscales inexistentes.

C10 mantiene 30 ventas sintéticas **medidas en caja**, conteo físico y dictamen por
flujo. Los 30 registros en este modelo no satisfacen esas mediciones. El objetivo
existente p95 ≤1 s corresponde a enviar→recibo, sin tiempo humano. Debe conservarse
la muestra completa, incluidos fallos y reintentos, sin contarlos como ventas nuevas.

Recomendación de aceptación: cero diferencias de dinero/unidades sin explicar,
ninguna duplicación, controles de permisos efectivos, tareas humanas completas y
recuperación probada. Un restore ausente bloquea el conjunto aunque una venta pase.

## Dónde y cuándo

La evidencia histórica Chrome→API→SQL 21/21 acredita ese candidato y entorno.
No acredita automáticamente Windows, red/dispositivos de caja o restore operacional.
Si el equipo final es SUAZO-PC con el mismo montaje, se reutiliza lo que siga
aplicando y solo se cubren las diferencias. No se exige otra computadora por ritual.

Recomiendo probar en el equipo y red que usará quien vende, con datos aislados.
Registrar versión, permisos y montaje; ejecutar guion; verificar persistencia;
probar pérdida de respuesta; comparar conteos; restaurar en un destino aislado.
Lector/impresora entran solo si pertenecen al flujo operativo confirmado.

El modelo se puede revisar ahora. El ensayo de aplicación depende de C2/C9 y de
completar los flujos elegidos. Viernes 6-nov sigue siendo propuesta, sin hora confirmada.

## Qué significa stock registrado 0

Es una cantidad de inventario, no un precio ni un saldo de caja.
Jason ya decidió entregar si la prenda física existe. No se reabre esa decisión.
Primero se confirma SKU, talla y ubicación para descartar un artículo equivocado.

Propuesta recomendada: facultad operativa de la encargada para registrar conteo y
motivo. Registro 0 / físico 1 → ajuste +1 → venta −1 → registro 0 / físico 0.
La incidencia y el actor permanecen visibles. No se inventa una compra para cuadrar.
La unidad reconciliada no debe quedar disponible para otra caja entre ajuste y venta;
el flujo real necesita protección transaccional o reserva y pruebas concurrentes.

La autorización de esa facultad sigue pendiente. El modelo la asigna a MOCK-MANAGER
como hipótesis explícita. No habilita negativos silenciosos ni modifica guardas SQL.
Si la diferencia no se puede resolver inmediatamente, se necesita un procedimiento
operativo acordado que conserve la entrega y la incidencia, sin esconder el faltante.

Buen visto: un documento, un cobro, una entrega, movimientos enlazados y saldo final
correcto. La conciliación demuestra qué ocurrió; no borra la discrepancia original.

## Qué significa sustituir SISFAIN

SISFAIN es el servicio actual según Jason. CGA publica Pro 4.0 y una asociación con
Martha; no se verificó la versión instalada. [Producto oficial](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/)
y [clientes](https://cgasoluciones.com/nuestros-clientes/).

La investigación cubre los dominios comercial, fiscal/financiero y migración/calidad.
Los informes distinguen oferta pública, código leído, evidencia histórica y propuestas:

| Informe | Cobertura | Límite principal |
| --- | --- | --- |
| [Operación](research/ops/REPORT.md) | 14 dominios; ventas, variantes, compras, caja, crédito, proformas, permisos/reportes | Marketing no prueba instalación ni paridad |
| [Fiscal](research/fiscal/REPORT.md) | Documento, numeración, impuestos, devoluciones, conservación y validación | DGI rechazó aperturas; vigencia y régimen no confirmados |
| [Migración y QA](research/migration/REPORT.md) | Modelo actual, saldos, importación, corte, rollback y CI | Sin exportación real ni recuperación Windows aceptada |

Hallazgos de código verificados por lectura:

- API: `InternalStockLedger.cs:63-69`, 1..100 líneas únicas; `InternalCommerceService.cs:32-69`, cálculo del servidor.
- UI: `app.mjs:547` arma una línea; `client.mjs:71-91` exige exactamente una.
- `InternalCommerceService.cs:202-207`: pagos/reembolsos `not_processed`. Una reversión interna no procesa dinero.
- `PrivatePilotReleaseTests.cs:107-144`: fixture de restore no incluye ventas ni caja.
- `verify_full_suite.py:20-52`: exige mínimo y PASS de casos presentes, sin inventario exacto obligatorio.

Las rutas C# son relativas a `backend/src/Martha.Store.Api/Internal/Commerce/`, salvo
`PrivatePilotReleaseTests.cs`, en `backend/tests/Martha.Store.Api.Tests/`.
`verify_full_suite.py` está en `backend/tests/`; las rutas UI en `dev/savia-staff-ui/`.

Recomendación: matriz de aceptación por flujo que Martha usa hoy. Cada fila indica
obligatorio, sustitución acordada o exclusión explícita. No excluir un flujo usado
porque la web del proveedor no lo detalla. No prometer cubrir todas las personalizaciones
sin observarlas. Multiartículo ya es obligatorio, D-023; sustitución es D-024.

La transición requiere exportación autorizada, mapeo, ensayo sintético de importación,
reconciliación por documento/moneda/ubicación, corte con una autoridad de escrituras y
vuelta probada. Después de nuevas ventas, volver a un backup anterior puede perderlas;
el rollback debe conservar y reconciliar el diario posterior al corte.

## Cómo hacer que CI verde tenga valor

CI ejecuta comprobaciones; no conoce por sí solo todo lo que exige el negocio.
El candidato histórico 53dd23b5 conserva 601/601 backend en evidencia. Eso no vuelve
verde cualquier SHA nuevo ni demuestra módulos que esas pruebas no cubren.

Recomendación concreta, todavía no implementada por este trabajo:

1. Contrato revisado: requisito → casos obligatorios por identidad/subcaso → resultado.
2. Gate agregado que falle ante caso ausente, skip no aprobado, artefacto inválido o SHA distinto.
3. Flujos browser→HTTP→SQL real con fixtures, oráculos independientes y restauración.
4. Controles negativos: introducir errores controlados y demostrar que la suite falla.
5. Manifiesto saneado con SHA/tree, run/attempt, versiones, casos y hashes de artefactos.
6. Protección de main, checks requeridos y revisión independiente antes de integrar.

El 4-nov se leyeron rulesets remotos: `[]`. PR #2 seguía abierto, sin merge.
Esto no vuelve a consultar la protección clásica; su evidencia anterior es separada.
No se cambiaron permisos ni workflows en esta tarea.
[Protección oficial de GitHub](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches).

`no-mistakes` puede orquestar revisión/pruebas/CI; no asegura ausencia total de errores.
La versión Windows observada: `v1.57.0 (0fcbbff) 2026-08-22T05:14:22Z`.
El documento anterior refiere Linux v1.84.0 y el ejemplo sigue inerte; no son la misma
instalación. Revisar release/configuración efectiva antes de activar. Mantener CI requerido,
agentes restringidos, límites de reparación y un solo publicador. No arrancar un segundo
publicador mientras el autosync actual controle Tony.
[Repo config](https://kunchenguid.github.io/no-mistakes/reference/repo-config/) ·
[Global config](https://kunchenguid.github.io/no-mistakes/reference/global-config/).

No se ejecutaron `init`, gate, daemon nuevo ni instalación. No se afirma una aprobación
de no-mistakes. La recomendación es reforzar los controles y evaluar después una ejecución
acotada en rama aislada. La activación tiene un alcance propio.

## Reproducir el artefacto

Python 3, sin dependencias nuevas:

```powershell
python docs/synthetic-replacement-20261104/simulate.py --out <directorio-nuevo>
```

Genera `results.json` e `index.html` desde `template.html`. No editar esas salidas a mano.
El hash del simulador en results identifica los bytes locales ejecutados; no equivale al
hash de un blob Git y puede cambiar por finales de línea. La publicación conserva blobs
y recibo normales. Los resultados no incluyen credenciales ni datos de clientes.

Diseño: tokens tomados de `dev/savia-staff-ui/styles.css`, no una identidad inventada.
La página es explicativa y permite recorrer resultados; no es una pantalla del producto.
No hubo before porque es un artefacto nuevo. La evidencia de navegador está separada.

## Verificación de navegador y coordinación

Se ejercitó la explicación en navegador con viewport 1440×900 claro y 390×844 oscuro.
Pasaron 13 comprobaciones: navegación de escenarios, selección, límites, reinicio,
18 evidencias/51 checks visibles, decisión correcta y ausencia de desborde de página.
No hubo errores JavaScript de página. El servidor temporal devolvió 404 para
`favicon.ico`; no es un fallo del simulador. [Recibo exacto](browser-proof.json).

[Grabación después, 30 segundos](after.mp4) · [Imagen escritorio](simulation-desktop.png) ·
[Imagen móvil](simulation-mobile.png). Se inspeccionaron ambas imágenes.
La grabación prueba la interacción de esta explicación, no el producto SAVIA.
No existe grabación anterior: el artefacto es nuevo.

Se conservan dos intentos previos fuera del checkout: una expectativa de texto sin
separador de miles y una grabación con anotaciones de Lavish que interceptaban clics.
Se corrigió la comprobación y se repitió sobre HTTP local sin esa capa. No se
presentan esos intentos como aceptación visual. Fuentes y resultados del modelo
conservan los hashes revisados; la plantilla/HTML posteriores cambian únicamente
la recomendación de primera decisión, antes de esta verificación de navegador.

Trello: cuatro descripciones y dos elementos de C2 actualizados, con lectura exacta
posterior; todos los criterios pendientes conservan su estado abierto.
[Recibo saneado](trello-receipt.json). No se mandó ningún mensaje a Martha.
El [resumen saneado de cinco comandos](verification/summary.json) conserva resultados
y procedencia. Los logs originales permanecen fuera del repositorio público.
El hook rechazó su extensión `.log`; se retiraron los originales de la publicación
y se exportaron solo campos revisados. No se debilitó el control ni se renombraron
logs para eludirlo.
[Hashes locales de la exportación](publication-hashes.json); no sustituyen los blobs Git.

## Bloqueos con dueño y salida

| Bloqueo | Evidencia / causa | Acción realizada | Dueño, siguiente acción y cierre |
| --- | --- | --- | --- |
| Configuración SISFAIN desconocida | Fuentes públicas sin instalación; faltan datos directos | Tres investigaciones; cuestionario corregido | Martha/coordinador: recorrido ficticio y matriz; Jason fija alcance de paridad |
| Fiscal sin validar | DGI `Request Rejected`; régimen desconocido | No asignar tasas ni emitir; preguntas y fuentes registradas | Martha/contador: comprobar requisitos vigentes y configuración; cierra con revisión aplicable |
| UI una línea y pagos no procesados | Lectura directa de contratos/código | Documentado como brecha; no arreglado en esta tarea | Implementación futura acotada; cierra con navegador/API/SQL, cobros y documento aceptados |
| C9 TLS/restore Windows | Preflight consumido; sin restore operativo | Sin nueva conexión ni cambio de certificados; estado conservado | Coordinador existente: recibir inspector OS revisado; después diagnóstico y corrección separada. Cierra con recuperación medida autorizada |
| CI no acredita paridad | Mínimo de casos no es inventario obligatorio | Matriz de controles y tres controles negativos del modelo | Jason: acordar gate requerido; implementación y fallo intencional deben demostrar bloqueo |

Primera decisión pendiente recomendada: **equipo y red finales del ensayo**. Elegir
el montaje de caja previsto, con datos aislados. Si es SUAZO-PC, se reutiliza esa evidencia.
Después se acuerdan facultad de conciliación y configuración de los flujos de sustitución.

Lección aplicada: un PASS debe describir exactamente la acción ejercitada. La revisión
detectó S01 con narrativa más amplia que sus comprobaciones; se corrigió antes de ejecutar.
S01 ahora verifica rechazo por rol y S02 verifica entrega tras ajuste autorizado.
