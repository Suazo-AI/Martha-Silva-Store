# Incremento: Venta segura por cajero

Estado: **PREPARADO; NO EJECUTADO**. Un único incremento sobre el flujo actual. Objetivo: cerrar ROLE-01, SESSION-01 y SCOPE-01, y completar la denegación pendiente de ADJ-01. Solo marcar cada criterio PASS cuando todos sus subcasos estén comprobados.

## Contrato

Un Cashier asignado registra una venta en su sucursal y recupera su resultado. No puede ajustar, devolver, cancelar, administrar personal ni consultar compras/costos. La sesión anterior pierde acceso tras revocación o reasignación. Los rechazos no alteran saldos.

Mantener Owner, Manager, Cashier e Inventory. Mantener una autoridad Internal, el precio del servidor, idempotencia y trazabilidad. No añadir pantallas, dependencias, reservas, pagos ni política de stock cero.

Límites observables: UI → HTTP autenticado → transacción/ledger. Usar pruebas de interfaz para comportamiento y lectura independiente del ledger para integridad. Una respuesta 403 sola no demuestra ausencia de efectos.

## Matriz mínima derivada de la fuente

| Acción | Owner | Manager asignado | Cashier asignado | Inventory asignado |
| --- | --- | --- | --- | --- |
| Vender | Sí | Sí | Sí | No |
| Ajustar / recibir | Sí | Sí | No | Sí |
| Cancelar / devolver / crear compra | Sí | Sí | No | No |
| Administrar personal/directorio | Sí | No | No | No |
| Consultar compras | Sí | Sí | No | Sí |

Los permisos de fila son condición necesaria. Deben además cumplir sesión, sucursal y recurso actuales. Usuario no Owner sin asignación no obtiene acceso global. Owner conserva su contrato actual; no se restringe para facilitar una prueba.

Fuentes: `InternalSecurity.cs`, `InternalCommandAuthorization` dentro de `InternalCommandRunner.cs`, `InternalSupplyEndpoints.cs` e `InternalBranchAccess.cs`. La matriz no amplía permisos.

## Preparación antes del runtime

1. Identificar candidato: commit y hashes de los cambios locales incluidos; entorno y límites de ejecución autorizados.
2. Identificar las cuentas sintéticas existentes y lo que falta. Nunca publicar contraseñas, cookies ni autorizaciones.
3. Preparar mínimo Owner, Manager, Cashier, Inventory y un usuario sin asignación; reutilizar cuando resulte seguro.
4. Usar dos ámbitos sintéticos para probar denegación, sin introducir una segunda sucursal operativa comercial.
5. Registrar saldos y registros iniciales. Conservar la base y operaciones anteriores. No borrar fixtures para obtener un PASS.
6. Confirmar recuperación del acceso Owner y la asignación original. Registrar cómo restaurarlas sin eliminar evidencia.

La autorización de este diagnóstico cubre preparación documental. Crear usuarios, revocar sesiones o ejecutar contra SQL requiere el alcance de runtime correspondiente. El operador debe revisar ese paquete concreto antes de iniciar; no reutilizar ventanas consumidas.

## Checks congelados

| ID | Dado / cuando | Resultado y evidencia exigidos |
| --- | --- | --- |
| N1 | Cada rol inicia sesión y consulta su ámbito. Un usuario sin asignación intenta operar. | Sesión y rol del servidor; listas, cuerpos y totales paginados autorizados; sin acceso global por omisión. |
| N2 | Cashier vende desde UI, recarga y recupera el mismo intento. Owner y Manager conservan venta permitida. | Recibo con actor, ubicación y precio del servidor; una venta, un débito por línea; replay igual sin nuevo efecto. |
| N3 | Cashier envía directamente ajuste, devolución, cancelación, compra, personal y lecturas de costos. Inventory intenta vender. | Rechazo API según contrato; no basta ocultar controles. Saldos, movimientos y registros no cambian; respuesta no filtra costos. |
| N4 | Se manipulan ubicación, IDs, skip/take e identidad de operación ajenos. Owner intenta reasignar una ubicación que ya tiene movimientos. | Denegación o respuesta sin recurso según contrato; ningún dato, total, recibo ni replay de otro ámbito. Reasignación histórica rechazada con conflicto; venta, movimientos e intento conservan ubicación original. |
| N5 | Cajero con último recibo confirmado cambia de sucursal y vuelve a entrar. | Sesión vieja inválida; no muestra recibo anterior; nueva venta autorizada disponible. Reproducir la hipótesis de `pending ||= {}` antes de corregir. |
| N6 | Existe además una venta de resultado incierto durante cambio de identidad/alcance. | No reenvía como otro actor ni crea key nueva. Conserva identidad del intento para conciliación autorizada; no revela datos anteriores. |
| N7 | Logout, expiración absoluta y revocación. Llega una respuesta tardía después de 401. | Solicitudes posteriores rechazadas; datos privados visibles borrados y respuesta tardía descartada. No cambiar reloj global para probar expiración. |
| N8 | Mutación con CSRF ausente/incorrecto; cambio de identidad con token anterior. | Rechazo sin escritura; login y mutación con par válido siguen funcionando. No guardar tokens en evidencia. |
| N9 | Owner ajusta con motivo y Cashier intenta el mismo tipo de acción. | Caso permitido conserva motivo, actor y movimiento; caso prohibido no altera nada. Reutilizar prueba previa solo si el candidato y sus dependencias siguen siendo equivalentes. |
| N10 | Revisión de todos los rechazos y regresión de recuperación. | Ledger concuerda antes/después; no hubo segundo débito ni éxito inventado; controles UI permiten resolver el estado real. |

En N5 separar un recibo confirmado inaccesible de una operación incierta. Borrar toda la sesión local para desbloquear el formulario no es una solución aceptable.

Si el lote autorizado no cubre el intento de reasignar una ubicación con historia de N4, conservar SCOPE-01 parcial/NOT RUN. La reasignación del cajero por sí sola no cubre ese subcaso.

Si la expiración necesita tiempo controlable, probarla en el harness existente y registrar ese límite. No declarar prueba de navegador de ocho horas a partir del test de reloj.

## Ejecución mínima y salida

El implementador reproduce un caso por vez. Si falla, conserva comando, resultado, actor sintético, request sanitizada, estado inicial y candidato. Escribe una regresión que falla por la causa correcta. Hace el cambio mínimo y repite el caso, su prueba y los flujos afectados.

Presupuesto propuesto para la futura ejecución: una sesión acotada de 45 minutos y hasta dos hipótesis fallidas por defecto. No autoriza gasto ni lanzamiento automático. Al agotarse, entrega el fallo exacto y cambia de diagnóstico o pide el dato faltante.

El revisor compara los resultados con N1–N10 y con la matriz operativa. No modifica checks para aumentar el conteo. La salida incluye qué pasó, qué no corrió, hashes, comandos, readbacks, diferencia antes/después y recuperación aplicada.

**Termina cuando** los criterios objetivo completos pasan sobre el candidato identificado, los casos afectados conservan su comportamiento y la evidencia permite repetir el resultado. Si faltan identidades o autorización, el paquete queda PREPARADO, con la acción exacta para el operador.

Este incremento puede cerrar hasta cuatro criterios, pero no se promete 17/22 antes de ejecutar. Stock cero, reservas, rollback parcial, autoridad y cierre integral de pantallas siguen fuera de esta ejecución.
