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
| A-03 | La caja vende con la nube apagada y deja registro para sincronizar | Espera a la nube o no deja registro | Integración .NET | pendiente |
| A-04 | Reintentar una sincronización no repite efectos | Doble stock o doble venta | Simulador con semillas | pendiente |
| A-05 | Un anticipo transferido no se gasta en origen y destino | Doble canje | Simulador con semillas | pendiente |
| A-06 | Arqueo y documento contable se registran una sola vez | Ingreso duplicado o segunda factura | `db/tests/sales/010` | verificado en una base |
| A-07 | La etiqueta lleva el código original y la tienda; un trabajo no se pierde en silencio | Código alterado o trabajo descartado | `db/tests/receiving/010` (cola); impresora real | cola verificada; impresora NO probada |
| A-08 | Una cajera de A no cambia datos de B | Acceso entre sucursales | Integración .NET | pendiente |
| A-09 | Restaurar un respaldo viejo no revive derechos gastados | Saldo viejo canjeado otra vez | Simulador con semillas | pendiente |
| A-10 | Rendimiento medido con 50 000 productos y 250 000 variantes | Solo afirmaciones teóricas | Prueba de carga | pendiente |

"Verificado en una base" significa que la regla se cumple dentro de un nodo. Entre nodos falta CP4.

## Checkpoints

| CP | Entrega | Estado | Evidencia |
| --- | --- | --- | --- |
| CP0 | SQL real en SQL Server 2022, línea base corregida | hecho | [cp0-sql-install](evidence/cp0-sql-install/README.md) |
| CP1 | Arnés de pruebas de base y auditoría de los 41 procedimientos | en curso | `python savia/tools/db/saviadb.py test` |
| CP2 | ADR-001 y crítica independiente previa al código de sync | en curso | [ADR-001](adr/ADR-001-arquitectura.md) |
| CP3 | Slice vertical de la API con pruebas contra SQL real | pendiente | — |
| CP4 | Sync 1 nube + 3 sucursales, oráculo y simulador | pendiente | — |
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
- Política de stock negativo, documento fiscal, impresora y escáner reales, pasarela de pago.

## Relación con el programa del 2026-11-11

WP-A (pipeline de bugs) y WP-E (doctor) siguen y sirven a v2.
WP-S, WP-B, WP-C y WP-D apuntaban al backend v1; quedan en pausa y su objetivo pasa a v2:
CRM sobre `crm.Customers`, tiempo real sobre el outbox, sitio sobre `webstore` y catálogo de la nube.

## Registro

| Fecha | Hecho | Commit |
| --- | --- | --- |
| 2026-11-12 | CP0: el instalador falla tal como viene (23 errores); línea base V001 con 7 correcciones; smoke original pasa | ver `git log savia/` |
