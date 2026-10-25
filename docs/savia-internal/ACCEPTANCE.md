# Aceptación de SAVIA interno

Criterios propuestos para integrar una aplicación privada de personal y propietarios.
No describen funciones ya entregadas ni sustituyen el código o los contratos vigentes.

## Estado actual

- El prototipo público se retiró: el registro de `d2ad200…` / `8e298940…` indica `/savia` y sus recursos en 404.
- La tienda principal sigue separada; SAVIA interno no debe reaparecer en su raíz ni en su footer público.
- El trabajo cloud basado en `f7e859b…` está pendiente de recepción, integración y validación.
- El backend sintético y sus fixtures no acreditan CRM, ventas, compras, autenticación ni SQL de producción.
- Los roles siguientes son una propuesta; el propietario debe confirmar su matriz antes de habilitarlos.

## Identidad y primer propietario

- Elegir y documentar el mecanismo real de identidad; no asumir proveedor, cuenta o credenciales por defecto.
- Probar inicio de sesión, cierre, caducidad y revocación mediante validación efectiva en el servidor.
- Crear el primer owner con un procedimiento controlado del servidor, de un solo uso y con evidencia auditable.
- Una visita inicial, un parámetro del cliente o `isAdmin=true` nunca deben crear ni elevar un propietario.
- No incluir contraseñas fijas, secretos, cookies, tokens o claves de bootstrap en frontend, repositorio o logs.
- Proteger el bootstrap contra repetición; impedir eliminar o degradar al último owner sin recuperación autorizada.
- Rechazar llamadas directas sin sesión válida, aunque se oculten menús o botones en la interfaz.
- Si se usan cookies de sesión, verificar sus protecciones y defensa CSRF antes de habilitar operaciones.

## Permisos propuestos

| Rol | Alcance permitido a confirmar |
| --- | --- |
| Owner | Configuración del negocio, usuarios, roles y aprobaciones sensibles; acceso operativo autorizado. |
| Administración | CRM y operación de ventas, inventario y compras; sin autoasignarse owner ni borrar auditoría. |
| Ventas | Consultar catálogo/disponibilidad y operar ventas y clientes dentro de su alcance autorizado. |
| Inventario | Recepciones, conteos y ajustes justificados; sin conceder roles ni aprobar cobros. |
| Compras | Proveedores y órdenes de compra; aprobación y recepción según separación de funciones acordada. |
| Consulta/auditoría | Lecturas y reportes expresamente autorizados; ninguna mutación. |

- Probar cada permiso permitido y denegado desde la API, incluyendo acceso por ID y cambios de rol en sesión.
- Las devoluciones, descuentos excepcionales, ajustes y aprobaciones requieren permiso explícito y motivo.

## Negocio, datos y autoridad

- Obtener identidad, rol y negocio desde la sesión validada; no confiar en `businessId` enviado por el cliente.
- Probar aislamiento entre dos negocios en listados, búsquedas, IDs, escrituras, comprobantes y exportaciones.
- Un usuario de otro negocio no debe leer ni modificar registros ni deducir datos mediante mensajes de error.
- Precio, moneda, totales, stock y transiciones válidas deben proceder de la autoridad del servidor.
- Separar USD de muestra, fixtures XXX y datos comerciales; nunca convertirlos ni mezclarlos por conveniencia.
- Usar sólo clientes, proveedores y documentos ficticios en QA; no importar PII ni volcados del equipo.
- Definir campos mínimos, conservación, acceso y eliminación de datos antes de autorizar información real.

## Flujos de aceptación

- CRM: crear y editar una ficha ficticia, validar campos y permisos, registrar cambios y evitar duplicados previstos.
- Ventas: crear borrador, seleccionar variantes, verificar precio/disponibilidad y confirmar sólo la transición autorizada.
- Rechazo o cancelación: conservar o liberar unidades exactamente una vez según el estado; nunca decidirlo por timeout.
- Comprobante: mostrar negocio, identidad operadora, moneda, líneas y resultado real; identificar toda simulación.
- Inventario: recibir y ajustar con motivo; verificar movimientos y disponibilidad sin cantidades negativas.
- Compras: recorrer borrador, aprobación, recepción parcial/completa y cancelación sin duplicar entradas de stock.
- Ningún cobro se declara aprobado sin un contrato y resultado verificables; un proveedor de pagos sigue por decidir.
- Probar navegación por teclado, nombres con prenda/talla, errores visibles y foco útil después de cada acción.
- Actualizar o recargar no debe perder una operación duradera ni convertir una demostración en una venta real.

## Resultado desconocido y trazabilidad

- Antes de enviar una mutación, conservar identidad de operación, negocio, autoridad, clave y payload exactos.
- Un corte de red o resultado desconocido no es éxito ni rechazo: mostrar pendiente y bloquear otra operación incompatible.
- Recuperar por consulta al servidor; reintentar la misma operación con la misma clave y payload, sin crear otra venta.
- Probar repetición, concurrencia y reinicio: un único efecto, respuesta coherente y recuperación del resultado.
- Registrar actor, negocio, hora UTC, acción, correlación, resultado y cambio mínimo necesario.
- Restringir consulta y conservación de auditoría; no registrar secretos ni fichas personales completas.
- Un fallo, rechazo o intento incierto debe conservar evidencia; la interfaz no puede fabricar un recibo confirmado.

## Puertas de entrega

- Integrador: entregar commit, contratos, matriz de permisos y evidencia por caso, separando mocks de pruebas reales.
- Propietario: confirmar identidad, bootstrap, permisos, datos autorizados y destino privado antes de habilitar acceso.
- Aplicar las autorizaciones ya recibidas; pedir sólo decisiones o datos indispensables que aún falten.
- Ejecutar almacenamiento/SQL, aceptar EULA o publicar requiere autorización específica; crear código no la concede.
- Registrar bloqueos con acción, destino, motivo y estado; no reemplazar servicios faltantes con éxito simulado.
- Mantener pendientes explícitos de backend, persistencia, pagos y QA; no prometer porcentajes o latencias sin medición.
- Aceptar la entrega sólo tras verificar autenticación del servidor y flujos en el destino privado autorizado.
