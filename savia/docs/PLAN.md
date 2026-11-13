# Plan de SAVIA v2

Inicio: 2026-11-12. Orquestador: agente primary. Modo: BUILD.
Revenue link: un sistema que Martha puede operar en 3 sucursales sin internet y que un agente puede mantener.
Fuente del mandato: mensaje de Jason del 2026-11-12 y [HANDOFF_FABLE.md](../db/handoff-20261112/HANDOFF_FABLE.md).
Arquitectura: [ADR-001](adr/ADR-001-arquitectura.md).

## Qué significa "terminado"

Tres sucursales operan sin internet y vuelven a sincronizar sin perder inventario ni dinero.
Cada fila de esta tabla es una prueba que puede fallar. Sin prueba ejecutada no hay "verificado".

| ID | Aserción | La refuta | Prueba | Estado |
| --- | --- | --- | --- | --- |
| A-01 | El SQL instala desde cero sin errores | Un procedimiento no compila | `saviadb.py` + CP0 | verificado en una base |
| A-02 | 100 lecturas del mismo código suman 100 en una línea | 100 SKU, o stock antes de aprobar | `db/tests/receiving/010` | verificado en una base |
| A-03 | La caja vende con la nube apagada y deja registro para sincronizar | Espera a la nube o no deja registro | `VerticalSliceTests` | verificado en una base |
| A-04 | Reintentar una sincronización no repite efectos | Doble stock o doble venta | Simulador con semillas | pendiente |
| A-05 | Un anticipo transferido no se gasta en origen y destino | Doble canje | Simulador con semillas | pendiente |
| A-06 | Arqueo y documento contable se registran una sola vez | Ingreso duplicado o segunda factura | `db/tests/sales/010` | verificado en una base |
| A-07 | La etiqueta lleva el código original y la tienda; un trabajo no se pierde en silencio | Código alterado o trabajo descartado | `db/tests/receiving/010` (cola); impresora real | cola verificada; impresora NO probada |
| A-08 | Una cajera de A no cambia datos de B | Acceso entre sucursales | `VerticalSliceTests` | verificado en el host de sucursal; falta la nube |
| A-09 | Restaurar un respaldo viejo no revive derechos gastados | Saldo viejo canjeado otra vez | Simulador con semillas | pendiente |
| A-10 | Rendimiento medido con 50 000 productos y 250 000 variantes | Solo afirmaciones teóricas | Prueba de carga | pendiente |

"Verificado en una base" significa que la regla se cumple dentro de un nodo. Entre nodos falta CP4.

## Checkpoints

| CP | Entrega | Estado | Evidencia |
| --- | --- | --- | --- |
| CP0 | SQL real en SQL Server 2022, línea base corregida | hecho | [cp0-sql-install](evidence/cp0-sql-install/README.md) |
| CP1 | Arnés de pruebas de base y auditoría de los 44 procedimientos | hecho: 113 pruebas, los 44 tienen prueba; revisión escrita de anticipos y web pendiente | `python savia/tools/db/saviadb.py test` |
| CP2 | ADR-001 y crítica independiente previa al código de sync | revisión 2 con la crítica incorporada; F14 abierto | [ADR-001](adr/ADR-001-arquitectura.md), [crítica](adr/ADR-001-critica.md) |
| CP3 | Slice vertical de la API con pruebas contra SQL real | hecho (un nodo) | [cp3-vertical-slice](evidence/cp3-vertical-slice/README.md) |
| CP4 | Sync 1 nube + 3 sucursales, oráculo y simulador | en curso: S1 base de sync (V008) | [S1](evidence/cp4-s1-sync-foundation/README.md) |
| CP5 | Clientes sobre el contrato generado | pendiente | — |
| CP6 | Carga, respaldos, permisos y preparación de Azure sin desplegar | pendiente | — |

## Agentes

El primary diseña, integra en serie y acepta. El resumen de un worker no es evidencia.
Ejecutores esta noche, por instrucción de Jason: OpenCode en ruta gratis (MiniMax M3.1, DeepSeek V4.1, GLM-5.3), luego Claude Opus con esfuerzo medio.
Crítico y juez: Claude Opus con esfuerzo medio, en sesión nueva (Codex sin cuota hasta 2026-11-13 13:37).
Cada worker trabaja en su worktree, no hace commit y entrega con comandos y códigos de salida.

## Necesita a Jason

- Contratar o desplegar Azure, gastar, fusionar a `main`, tocar datos reales.
- Qué pasa con el piloto v1 mientras v2 madura.
- Devoluciones entre sucursales (hoy se rechazan), política de stock negativo, documento fiscal, impresora y escáner reales, pasarela de pago.

## Relación con el programa del 2026-11-11

WP-A (pipeline de bugs) y WP-E (doctor) siguen y sirven a v2.
WP-S, WP-B, WP-C y WP-D apuntaban al backend v1; quedan en pausa y su objetivo pasa a v2:
CRM sobre `crm.Customers`, tiempo real sobre el outbox, sitio sobre `webstore` y catálogo de la nube.

## Registro

| Fecha | Hecho | Commit |
| --- | --- | --- |
| 2026-11-12 | CP0: el instalador falla tal como viene (23 errores); línea base V001 con 7 correcciones; smoke original pasa | `915044e` |
| 2026-11-12 | CP3: API .NET 10 en capas; slice recepción → venta → arqueo; 8 pruebas contra SQL real | `5c204e1` |
| 2026-11-12 | Oráculo de conservación (V003): cero filas con libros sanos; detecta 5 tipos de corrupción | `a072b53` |
| 2026-11-12 | BUG-001 y BUG-002 de concurrencia: prueba roja, causa del grafo de interbloqueo, V004, verde 3 veces, 0 interbloqueos ([detalle](bugs/BUG-001-002-concurrencia.md)) | `3f29469` |
| 2026-11-12 | CP1-A: 41 pruebas de catálogo, recepción, etiquetas e inventario; crítica de ADR-001 (Opus) | `28c6305` |
| 2026-11-12 | BUG-003 a BUG-009 (CP1-A): 7 rojas sin V005, 46 verdes con V005 ([detalle](bugs/BUG-003-009-cp1a.md)) | `ec87e47` |
| 2026-11-12 | ADR-001 revisión 2 con los 15 hallazgos de la crítica; BUG-010 devolución entre sucursales: rojo sin V006, verde con V006 ([detalle](bugs/BUG-010-devolucion-otra-sucursal.md)) | ver `git log savia/` |
| 2026-11-12 | CP1-B y CP1-C: 66 pruebas de caja, ventas, contabilidad, anticipos, web y outbox; BUG-011 a BUG-015: 5 rojas sin V007, 113 verdes con V007 ([detalle](bugs/BUG-011-015-cp1b.md)) | ver `git log savia/` |
| 2026-11-12 | F12/F14 Express: 113 pruebas T-SQL pasan en SQL Server Express; Change Tracking con `SNAPSHOT` funciona ([evidencia](evidence/f12-express/README.md)); Azure sin probar | ver `git log savia/` |
| 2026-11-12 | CP4-S1: V008 base de sync; restauración real cambia el fork y reutiliza versiones, el cursor `(fork, versión)` da `recover` ([evidencia](evidence/cp4-s1-sync-foundation/README.md)) | `db0bb31` |
| 2026-11-12 | CP4-F2: traslado de anticipo como filas de transición, un escritor por fila (V009); rojo `credits/140` sin V009, 120 T-SQL verdes ([evidencia](evidence/cp4-f2-credit-transfer/README.md)) | ver `git log savia/` |
| 2026-11-12 | V010: decisiones de Jason sobre traslados (gana el despacho, pide cualquiera de las dos sucursales, búsqueda de anticipos) | `33f033b` |
| 2026-11-12 | Piloto Masaya en localhost: API sirve la web del diseño 08, base de muestra, registro local de producto y rechazo de lectura (V012), módulo de escáner; flujo completo en navegador 12/12, 126 T-SQL, 26 .NET ([web](pilot/WEB.md), [API](pilot/API-PILOT.md), [escáner](pilot/SCANNER.md)); escáner físico, impresora y sync entre sucursales NO probados | ver `git log savia/` |
| 2026-11-12 | CP4 simulador (en pausa, sin aceptar): V011 rastrea las 18 tablas sincronizadas; `tools/db/simulator.py` copia filas entre 4 bases; hallazgo abierto: el oráculo exige un evento de outbox local por cada venta replicada | ver `git log savia/` |
| 2026-11-12 | Piloto ronda 2: historial, recibo, devolución con anticipo, pagos con tarjeta/transferencia/anticipo (simulados), clientes, reporte del día, una contraseña por cuenta, respaldo con restauración probada y script de arranque; 128 T-SQL, 34 .NET, navegador 18/18 ([operación](pilot/OPERACION.md)); devolución en efectivo NO existe en SQL | ver `git log savia/` |
| 2026-11-12 | Roles reales, comisiones, historia de 60 días ([verificación](pilot/OWNER-ROLES-VERIFICATION.md)) | `7741309` |
| 2026-11-12 | Foto de etiqueta con OCR local (6/6 por la API real, [ETIQUETA](pilot/ETIQUETA.md)) y Azure preparado sin desplegar ([AZURE](deploy/AZURE.md)); decisiones de traslados y apartados ([doc](pilot/TRASLADOS-APARTADOS.md)); teléfono real, escáner e impresora NO probados | ver `git log savia/` |
