# Adopción de sucursales y reversión — plan sin ejecutar

Este documento prepara una revisión; no asigna datos, crea sucursales o cuentas,
autoriza SQL ni aplica migraciones. La instancia sigue siendo un negocio aislado.
El código, las pruebas escritas y el esquema manual no acreditan operación real.

## Destino y datos antes de cualquier ejecución

El propietario debe identificar por un canal privado el servidor y la base de
pruebas desechables, sus permisos CREATE/DROP y la licencia aplicable. Una base
con nombre de pruebas no demuestra que el servidor sea de pruebas. No copiar
credenciales ni bases comerciales a este repositorio o al paquete cloud.

La primera validación utiliza fixtures sintéticas y una copia autorizada del
esquema anterior. Confirmar backup y restauración verificable en un destino
aislado antes de plantear una adopción comercial. La aceptación de ese destino
y del plan de datos reales es una etapa posterior.

## Mapeo explícito pendiente de revisión

Preparar un inventario protegido de identificadores persistidos, fuera de Git:
personal, ubicaciones, saldos, movimientos, ventas, compras, recepciones y
operaciones históricas. Para cada ubicación indicar si tiene referencias o
historial y qué evidencia acredita su sucursal original. No inferirla a partir
de un nombre, la sucursal actual de un empleado ni la ubicación actual de stock.

El propietario revisa un mapeo con IDs estables de sucursal, ubicación y personal;
el plan debe distinguir filas sin evidencia y rechazar asignaciones ambiguas.
No sembrar nombres, GUID o asignaciones supuestamente reales. Generar primero un
informe de impacto sin escrituras: filas que cambiarían, referencias afectadas,
accesos que se perderían o ampliarían y recibos históricos sin ámbito.

Las ubicaciones históricas no se pueden remapear mediante `SaveLocation`, ni
siquiera de NULL a una sucursal. Hace falta diseñar y aprobar una migración de
datos separada con invariantes y reconciliación de historial. Este corte no
añade un override, endpoint de backfill o permiso para saltar esa guarda.

Operaciones con ámbito original desconocido permanecen sólo para Owner. No
reescribir sus fingerprints, claves, actores, recibos o metadatos originales
para atribuirles una sucursal. Conservar el intento original ante una respuesta
incierta; un conflicto no autoriza enviar otra clave o fabricar éxito.

## Comprobaciones previas y aceptación

Con el SDK fijado, validar modelo/snapshot y SQL generado; después probar Up
desde el esquema anterior en una base propia autorizada. `EnsureCreated` no
prueba esa actualización. Las asignaciones iniciales NULL deben seguir cerradas
para empleados; no activar acceso multisucursal ni presentar el esquema como
adopción completada.

El procedimiento de asignación posterior necesita Owner vigente, revisión del
mapeo, control de versión, auditoría y revocación de sesiones. Verificar carreras
entre reasignación, escritura y las tres vías de replay, además de lecturas por
rol y ubicación. PUT omitido conserva; null explícito sigue siendo una intención
de quitar asignación bajo las guardas del servidor. La UI actual no administra
sucursales ni resuelve este proceso.

## Estrategia de reversión conservadora

El `Down` manual elimina Branches, asignaciones de Staff/Locations, ámbito de
Operations y BranchAssignmentAudit. Es una transformación con pérdida de datos,
no un rollback operativo seguro. No ejecutar Down automáticamente para volver
al binario anterior: ese binario tampoco hace cumplir el nuevo aislamiento.

Ante un fallo de adopción, detener escrituras propias y mantener cerrado el
acceso interno afectado. Conservar esquema, asignaciones, auditoría y recibos;
preferir una corrección hacia delante revisada. Si se propone restaurar un
backup, conciliar primero las operaciones posteriores y probar la restauración
en otra base aislada. No borrar información para conseguir que arranque un
binario antiguo. Cualquier restauración o cambio de controles en un destino
real requiere su propio procedimiento y autorización.

La prueba de Down se limita a una base sintética desechable autorizada y debe
registrar exactamente qué información pierde. El paso a operación necesita
dictamen independiente sobre fuente, SQL, sesiones, UI, adopción y reversión;
ninguno se sustituye con revisión estática o con los resultados históricos.
