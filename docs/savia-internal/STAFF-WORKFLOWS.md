# SAVIA interno: flujos para personal y dueños

Especificación de UX para la implementación privada en curso; no acredita funciones terminadas.
Alcance vigente del usuario: CRM, administración, ventas, inventario y abastecimiento exclusivos del personal. La tienda pública permanece aparte; no reintroducir `/savia` como acceso público ni convertir la tienda en un panel administrativo.

## Punto de partida y límites

La base `f7e859b` documenta SAVIA V2 sintético: catálogo/capacidades, reservas, cancelación, consulta de intentos y movimientos. Referencias: [harness y contrato](../../dev/savia-harness/README.md), [backend](../../backend/README.md).
Una reserva no es una venta, factura ni cobro. Esa base no entrega CRM ni ventas de producción; tampoco acredita acceso de personal, API publicada o SQL verificado. Las fixtures XXX y la caja USD ficticia no son datos comerciales intercambiables.
Los flujos siguientes requieren contratos, autorización y persistencia del backend privado. Una pantalla o una prueba con dobles no los convierte en capacidades disponibles.

## Entrada, negocio y permisos

Ingreso → identificación del personal → negocios autorizados → espacio del negocio elegido. Mostrar siempre negocio, ubicación y usuario activos; ofrecer «Cambiar negocio» y «Cerrar sesión».
Si no hay negocios autorizados, mostrar «Todavía no tenés acceso a un negocio» y el mecanismo de solicitud acordado; no inventar un negocio ni mostrar datos de otra organización.
Cambiar negocio requiere resolver operaciones pendientes y confirmar qué ocurrirá con borradores. No reutilizar bolsas, clientes, inventario ni claves de operación del negocio anterior.
Una sesión vencida pide volver a ingresar; un permiso insuficiente explica la restricción. No ocultar ambos casos detrás de «Algo salió mal». El servidor debe autorizar cada operación y su negocio.

Nombres de roles propuestos para acordar, sin crear cuentas ni asignar permisos:

| Rol propuesto | Trabajo esperado |
| --- | --- |
| Dueño/Administrador | Configuración del negocio, acceso del personal y consulta completa según permisos confirmados. |
| Ventas/Caja | Clientes y ventas autorizadas; sin ajustes de inventario o acceso global implícitos. |
| Inventario/Compras | Existencias, compras y recepciones autorizadas; sin habilitación automática para cobrar. |
| Consulta | Informes permitidos sin acciones de escritura. |

## Clientes y CRM

«Clientes» abre búsqueda por nombre o contacto dentro del negocio. Estado vacío: «Todavía no hay clientes» y «Nuevo cliente» solo si el permiso existe.
Alta/edición muestra únicamente campos acordados, sus requisitos y finalidad; permite revisar posibles duplicados antes de guardar. No incorporar datos de muestra como personas reales.
Ficha: contacto, preferencias o consentimiento cuando corresponda e historial de ventas confirmado por backend. Distinguir borradores y anulaciones; no fabricar historial a partir de reservas.
Guardar mantiene los datos escritos ante validación o error recuperable. Conflicto de edición: mostrar la versión actual y permitir revisar cambios; nunca sobrescribir silenciosamente.

## Venta del personal

«Nueva venta» → ubicación → prendas/variantes y cantidades → cliente si las reglas lo permiten → revisión → confirmación. Precios, moneda, disponibilidad y total proceden del backend del negocio.
El borrador no promete reserva de stock. Mostrar cuándo se verificaron las existencias y qué cambia al confirmar; resolver faltantes o cambio de precio antes de continuar.
Estados distinguibles: borrador, confirmando, confirmada, rechazada y resultado desconocido. No mostrar «Venta realizada» solo por haber pulsado el botón o recibido una reserva.
«Registrar cobro» aparece únicamente para un medio y contrato habilitados. Su estado es independiente de la venta; no pedir tarjetas ni presentar un cobro ficticio como dinero recibido.
El comprobante utiliza identificador, hora, líneas, total y estado devueltos por el backend; no atribuir validez fiscal sin contrato. Cancelación/anulación requiere permiso, motivo y confirmación, con efectos de stock y pago explícitos.
Ante timeout después de enviar: «Estamos comprobando el resultado». Conservar identidad, negocio y clave originales; ofrecer «Consultar resultado» y el reintento exacto admitido. Bloquear una segunda confirmación equivalente hasta resolver; no inventar una clave nueva ni usar la demo como respaldo.

## Inventario

Vista por ubicación con variante, existencia física, reservada, disponible y actualización. Búsqueda y filtros deben conservarse al volver de una ficha.
«Ajustar existencias» requiere permiso, cantidad, motivo y revisión del resultado previsto. Confirmar una vez; mostrar el movimiento persistido y quién lo realizó.
Si cambió la versión o disponibilidad, recargar el dato autoritativo y pedir revisar el ajuste. Ante resultado desconocido, consultar el movimiento/intento antes de repetir; nunca corregir el total solo en pantalla.

## Compra y recepción

«Nueva compra» → proveedor autorizado → ubicación → variantes/cantidades y condiciones → guardar borrador o confirmar según contrato. No sumar stock por emitir una compra.
Recepción muestra lo solicitado, ya recibido y pendiente. Registrar cantidades efectivamente recibidas y diferencias; permitir recepción parcial cuando el backend la soporte.
«Confirmar recepción» presenta su efecto de inventario y devuelve un recibo/movimiento durable. Un doble clic o reintento no debe volver a sumar las unidades.
Cancelar una compra no revierte automáticamente mercancía recibida. Las correcciones requieren un flujo autorizado y trazable; los documentos parciales conservan su historia.

## Reportes y estados comunes

Reportes por negocio, período y ubicación: ventas confirmadas, anulaciones y movimientos según permisos. Explicar qué incluyen los totales; no sumar reservas, fixtures XXX o simulaciones como ingresos.
Consulta vacía: «No hay movimientos confirmados en este período». Fallo de consulta: «No pudimos cargar los datos» con reintento; no reemplazarlo por ceros ni indicadores inventados. Exportar solo si el contrato y permiso lo permiten.
Carga conserva filtros y contexto, indica la sección ocupada y bloquea únicamente acciones incompatibles. Errores de campo se vinculan al control; errores de operación conservan el borrador cuando sea seguro.
Sin conexión o servicio no disponible: permitir leer únicamente datos identificados como anteriores, si existe esa capacidad; deshabilitar escrituras y explicar qué falta. Nunca declarar guardado, venta, recepción o sincronización sin confirmación verificable.

## Interacción accesible y entrega a implementación

Usar etiquetas visibles, nombres específicos para acciones repetidas, orden de teclado predecible y controles de al menos 44 px. No comunicar permisos, stock o errores únicamente por color.
Al abrir un diálogo, enfocar su título/acción segura y contener el foco; al cerrar, devolverlo al disparador válido o a un encabezado visible. Confirmaciones destructivas ofrecen «Volver sin cambios»; Escape no confirma.
Anunciar carga finalizada, validación y resultado con regiones de estado/alerta sin duplicar mensajes. Tras eliminar una fila, restaurar foco a la acción o encabezado útil; no dejarlo en el documento vacío.
En pantallas estrechas, mantener visibles negocio activo y acciones necesarias; permitir navegación flexible y desplazamiento contenido en tablas, sin esconder controles esenciales.
Implementar y verificar un recorrido completo por vez con permisos y respuestas reales del contrato privado. Etiquetar expresamente lo pendiente o sintético; esta guía acompaña la implementación cloud y no sustituye código, pruebas ni entrega.
