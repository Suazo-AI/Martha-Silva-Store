# SAVIA: estado más reciente

Actualizado: 2026-11-03. Estado general: [PROJECT-STATUS](PROJECT-STATUS.md).
Continuación: [AGENT-START](AGENT-START.md). Configuración y prueba SQL: [DATABASE](DATABASE.md).

La UI actual implementa ingreso, sesión, directorio, consulta de stock, venta y recuperación de recibo.
El código local probado se incorpora a Tony con [hashes de procedencia](reconciliation-20261103/source-binding.json).
No está aceptado para producción: N5 reproduce un bloqueo al restaurar un recibo confirmado que devuelve 404.

Validación reciente: 590 casos backend PASS y 2 NOT RUN; 42/42 staff JS; 31/32 navegador; 4/4 guardas HTTP.
Los 67 casos SQL reales usaron bases nuevas desechables y preservaron las 52 existentes.
Los casos internos de ese lote usan EnsureCreated; no acreditan migraciones de release.
Ver [resultados, fallos y límites](testing-20261103/README.md).

## Antecedente operativo preservado

El corte local del 31 de octubre registra 13/22 criterios PASS y 9 NOT RUN; interfaz crítica 5/5.
Incluye migración Internal real, venta sintética Owner, recibo, pérdida de respuesta, recuperación y persistencia
tras reinicio solo de API. No hace falta repetir ese reinicio para publicar documentación.
El [resumen público](reconciliation-20261103/operational-history.json) conserva resultados y hashes de fuentes privadas.
Las cuentas, conexiones, bases, sesiones y autorizaciones no se publican.

La preparación de vigilancia histórica quedó PREPARED_NOT_ACTIVE; entrega/reanudación NOT_PROVEN.
No se activa con este trabajo. Los intentos R3–R7 y autorizaciones de un solo uso son historia, no una cola de ejecución.
El estado offline previo NO_APTO/APTO se consulta en su corte; no sustituye la evidencia SQL/UI posterior.

## Alcance y próxima acción

V1 interno: un negocio, una sucursal operativa; Owner, Manager, Cashier e Inventory con ámbito validado por servidor.
Los ámbitos adicionales de fixtures son pruebas de aislamiento, no una ampliación comercial.
Checkout público, tarjetas/bancos, factura fiscal electrónica y multisucursal quedan fuera de este incremento.
Corregir N5 y completar [Venta segura por cajero](delivery-20261031/NEXT-INCREMENT.md).
No se ha ejecutado el recorrido combinado actual de navegador a SQL ni se han cerrado todos sus criterios.
