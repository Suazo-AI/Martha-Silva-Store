# Modelos de integración: SAVIA y SISFAIN de CGA

Trabajo local solicitado el 2026-10-24. No constituye certificación de compatibilidad del proveedor, conexión productiva ni autorización de publicación de información operativa.

## Alcance

Una tienda y un modelo canónico, con adaptadores intercambiables. No duplicar el diseño ni mantener dos catálogos comerciales divergentes. **SAVIA** significa **Sistema de Administración, Ventas, Inventarios y Abastecimiento** y es el sistema propio; **SISFAIN** pertenece a CGA Soluciones.

Ambos modos visibles se ejecutan inicialmente con datos de demostración aislados. Cambiar de modo no debe transportar carritos, pedidos, confirmaciones ni solicitudes pendientes al otro sistema. Una simulación no es una fuente comercial de stock ni debe habilitar cobros.

## Autoridad de inventario pendiente

El negocio requiere inventario compartido con tiendas físicas. Falta decidir si SAVIA reemplazará SISFAIN o actuará como puente, y qué único sistema aceptará reservas y ventas. Los estados locales separados de esta demo son fixtures comparativas: no constituyen dos pools comerciales ni autorización de dual-write. Esta decisión operativa se mantiene local hasta autorizar su publicación.

## SAVIA

Existe una API .NET/SQL de pruebas sintéticas, documentada en [OpenAPI](../../contracts/openapi-v1.json). Su integración SQL fue verificada separadamente en el commit `3b0049163ece2d9431cee01f1bea624a66d9d8d4`, Actions run 40140349013: seis pruebas SQL aprobadas, cero omitidas, contenedor eliminado.

Ese resultado no demuestra la conexión de esta interfaz al backend ni producción. El contrato admite una variante por solicitud, precios autoritativos desde SQL dentro del entorno sintético, moneda `XXX`, idempotencia y ausencia de pagos. No descomponer un carrito de varias líneas en múltiples reservas fingiendo atomicidad de un único pedido. No enviar datos de clientes ni sustituir un error de red por un pedido local exitoso.

## SISFAIN de CGA

La [ficha oficial consultada](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/) describe SISFAIN Pro 4.0, conexión Local/Cloud según configuración e inventario por bodega. Menciona exportación a Excel cuando la función esté disponible; esto no acredita formato, importación, API, webhooks ni reservas atómicas.

No se han verificado endpoints, credenciales, contrato de integración o sandbox del proveedor. El adaptador de demostración no se conecta a CGA. Un snapshot o archivo exportado, por sí solo, no evita ventas simultáneas ni demuestra stock disponible en tiempo real.

Antes de una conexión real, verificar con CGA:

1. Versión, edición y licencia instaladas; acceso de integración autorizado.
2. Interfaz soportada y documentación de lectura/escritura, identificadores de variantes y bodegas.
3. Operación atómica de reserva/venta y comportamiento ante conflictos, reintentos y cortes.
4. Frecuencia, versionado y conciliación de movimientos; tratamiento de operaciones offline.
5. Entorno de pruebas y responsabilidad de soporte, sin alterar la instalación productiva.

## Evidencia requerida para cerrar este lote

- Adaptadores con capacidades y estado explícitos, sin endpoints de CGA inventados.
- Aislamiento al cambiar modo, navegación atrás/adelante y respuesta tardía.
- Sin pedidos duplicados por clicks repetidos; fallos de red sin éxito ficticio.
- Contrato sintético respetado y validación de respuestas.
- Build reproducible, suite agregada y pruebas independientes de navegador.
- Informe con SHA y distinción entre tests simulados, HTTP fixture, backend real y funcionalidades no probadas.

La publicación remota y el despliegue se informarán por separado de la implementación local.
