/* Authored English copy. Product IDs, sample status, prices and inventory are not translated. */
(() => {
  'use strict';
  const pairs = `
Martha Silva · Gala & novias|Martha Silva · Occasionwear & bridal
Una entrada inolvidable.|An unforgettable entrance.
Gala, novias y momentos que merecen brillar.|Occasionwear, bridal and moments made to shine.
Descubrí la colección|Discover the collection
Explorá el editorial|Explore the editorial
Presencia que se siente. Detalles que se recuerdan.|A presence you feel. Details you remember.
El universo Martha|The world of Martha
Vestir un momento.|Dress for the moment.
Seis miradas a la gala y las novias, desde nuestro Instagram.|Six perspectives on occasionwear and bridal, from our Instagram.
Fotografía editorial · consultá disponibilidad con la tienda.|Editorial photography · check availability with the store.
Brillo en cada detalle|Sparkle in every detail
La fuerza del rosa|The power of pink
Una noche en violeta|A night in violet
Encaje para el sí|Lace for “I do”
El comienzo de todo|The beginning of it all
Romance en movimiento|Romance in motion
Ver en Instagram|View on Instagram
Vestido de gala nude con pedrería plateada, fotografiado de cuerpo entero|Full-length view of a nude evening gown with silver embellishments
Vestido de gala rosa con pedrería y detalle floral, fotografiado de cuerpo entero|Full-length view of a pink evening gown with sparkling embellishments and floral detail
Vestido de gala violeta con hombros descubiertos y cola, fotografiado de cuerpo entero|Full-length view of a purple off-the-shoulder evening gown with a train
Vestido blanco de encaje floral con abertura, fotografiado de cuerpo entero|Full-length view of a white floral lace dress with a slit
Vestido de novia blanco de falda amplia y cola|White wedding dress with a full skirt and train
Espalda de vestido rosa de falda amplia con motivos florales y cola|Back view of a pink dress with a full skirt, floral motifs and train
Muestra|Sample
Novias|Bridal
Buscar|Search
Vestidos de fiesta|Occasion dresses
Vestidos de novia|Wedding dresses
Moda femenina|Womenswear
Por confirmar|To be confirmed
Todas las prendas|All styles
La colección|The collection
Tu email|Your email
Guía de tallas|Size guide
Prendas anteriores|Previous styles
Prendas siguientes|Next styles
Entrega|Delivery
Devoluciones|Returns
Seguir mi pedido|Track my order
Privacidad|Privacy
Administrar la demo|Manage the demo
Gala, novias y moda femenina.|Occasionwear, bridal and womenswear.
Gala, novias y moda femenina|Occasionwear, bridal and womenswear
Tu compra|Your purchase
Talla|Size
Ir al contenido|Skip to content
Demo independiente · datos locales · sin cobros|Independent demo · local data · no charges
Modo de prueba|Demo mode
Elegir modo de prueba|Choose demo mode
Demostración|Demo
Modo no disponible|Mode unavailable
Cada modo conserva su propia bolsa|Each mode keeps its own bag
Reintentar|Retry
Reintentá para continuar.|Retry to continue.
Datos temporales: se pierden al recargar esta página.|Temporary data: lost when this page reloads.
Datos de ejemplo · sin cobros ni envíos|Sample data · no charges or deliveries
Cómo funciona esta demo|How this demo works
Elegí un modo y probá la bolsa sin realizar una compra.|Choose a mode and try the bag without making a purchase.
Qué podés hacer|What you can try
Explorá prendas y probá la bolsa, los pedidos y los pagos. Todo funciona con datos de ejemplo.|Explore styles and try the bag, orders and payments. Everything uses sample data.
Datos de esta prueba|About the demo data
Los precios y las existencias son de ejemplo. No se realizan cobros, envíos ni pedidos reales.|Prices and stock are examples. No real charges, deliveries or orders are made.
Bolsas separadas|Separate bags
Cada modo conserva su bolsa y sus pedidos en este navegador. Al cambiar, no se mezclan.|Each mode keeps its bag and orders in this browser. Switching modes does not mix them.
No hay conexión real con SAVIA ni SISFAIN. Usá datos ficticios; nunca ingresés tarjetas, contraseñas ni datos personales reales.|There is no live SAVIA or SISFAIN connection. Use fictional details; never enter real card information, passwords or personal data.
Martha Silva Store, inicio|Martha Silva Store, home
Ayuda|Help
Gala|Occasionwear
Moda|Fashion
El edit de gala|The occasion edit
El mundo de Martha Silva|The world of Martha Silva
Conocé las prendas y selecciones de la colección.|Discover the styles and selections in the collection.
Recibir novedades|Get updates
Demo. No se envían correos.|Demo. No emails are sent.
Tu compra, paso a paso|Your purchase, step by step
Entrega en Nicaragua con tarifas de muestra.|Delivery in Nicaragua with sample rates.
Seguí a Martha Silva|Follow Martha Silva
Cerrar búsqueda|Close search
Encontrá tu prenda|Find your style
Buscar por prenda o color|Search by style or color
Vestido negro, gala…|Black dress, occasionwear…
Fotografía ampliada de la prenda|Enlarged product photo
Fotografía ampliada|Enlarged photo
Cerrar fotografía|Close photo
Cerrar guía|Close guide
Elegí la talla que usás normalmente. Las medidas de cada prenda están pendientes de confirmar.|Choose your usual size. Measurements for each garment have yet to be confirmed.
Tallas disponibles en esta demo|Sizes available in this demo
Medidas de la prenda|Garment measurements
Esta tabla no indica medidas comerciales.|This table does not provide verified garment measurements.
Cerrar ubicación|Close location
Tu ubicación|Your location
Entrega de prueba en Nicaragua.|Demo delivery in Nicaragua.
Los precios se muestran en USD.|Prices are shown in USD.
Managua: US$5.00. Resto de Nicaragua: US$8.00.|Managua: US$5.00. Rest of Nicaragua: US$8.00.
Continuar en Nicaragua|Continue in Nicaragua
Agregada a tu bolsa|Added to your bag
Bolsa vacía|Empty bag
Cerrar bolsa|Close bag
Ver mi bolsa|View my bag
Ver bolsa|View bag
Continuar con la compra|Continue to checkout
Seguir viendo prendas|Continue browsing
Cerrar oferta|Close offer
Tu próxima ocasión empieza aquí|Your next occasion starts here
Probá un 10% de descuento con PRUEBA10 en esta demo.|Try 10% off with PRUEBA10 in this demo.
nombre@ejemplo.com|name@example.com
Ver mi código de prueba|Show my demo code
Oferta de muestra. No se envían correos ni se cobra dinero.|Sample offer. No emails are sent and no money is charged.
Activá JavaScript para elegir una talla y completar la compra de prueba.|Enable JavaScript to choose a size and complete the demo checkout.
Abrir menú|Open menu
Colecciones|Collections
El edit de Martha|Martha's edit
Colecciones móvil|Mobile collections
Cerrar menú|Close menu
Mis favoritos|My favorites
Favoritos|Favorites
Ver favoritos|View favorites
Ayuda y seguimiento|Help and tracking
Fotografía anterior|Previous photo
Fotografía siguiente|Next photo
vista 1|view 1
vista 2|view 2
vista 3|view 3
vista 4|view 4
vista 5|view 5
vista 6|view 6
Elegí tu talla|Choose your size
Agotada|Sold out
Stock de muestra|Sample stock
Agregar a la bolsa|Add to bag
Guardar en favoritos|Save to favorites
Quitar de favoritos|Remove from favorites
EL EDIT DE MARTHA|MARTHA'S EDIT
TALLA Y AJUSTE|SIZE AND FIT
Las medidas de esta prenda están pendientes de confirmar.|Measurements for this garment have yet to be confirmed.
Consultar guía de tallas|View size guide
DETALLES Y CUIDADO|DETAILS AND CARE
Composición: por confirmar. Cuidado: por confirmar.|Composition: to be confirmed. Care: to be confirmed.
ENTREGA Y DEVOLUCIONES|DELIVERY AND RETURNS
Revisá las tarifas de muestra al continuar con la compra. Pagos y entrega simulados.|Review the sample rates at checkout. Payments and delivery are simulated.
Ver condiciones de la demo|View demo terms
Combínalo con|Style it with
También te puede gustar|You may also like
Video de la prenda|Product video
Todas|All
Limpiar filtros|Clear filters
Ordenar por|Sort by
Selección de Martha|Martha's selection
Precio: menor a mayor|Price: low to high
Precio: mayor a menor|Price: high to low
Administrar la demo · Martha Silva Store|Manage the demo · Martha Silva Store
Pedidos e inventario de esta tienda de prueba.|Orders and inventory for this demo store.
Cargando el panel de prueba…|Loading the demo panel…
Estamos para ayudarte|We're here to help
Entrega, devoluciones y seguimiento de tu pedido de prueba.|Delivery, returns and tracking for your demo order.
Entrega de prueba. Elegí Managua o resto de Nicaragua para calcular un costo de muestra. Revisá el total antes de confirmar. La entrega se simula en este equipo.|Demo delivery. Choose Managua or the rest of Nicaragua to calculate a sample cost. Review the total before confirming. Delivery is simulated on this device.
Devolución de prueba. Podés solicitar una devolución después de marcar el pedido como entregado. El administrador revisa la solicitud y simula el reembolso. No se mueve dinero.|Demo returns. You can request a return after the order is marked as delivered. The administrator reviews the request and simulates a refund. No money changes hands.
Al confirmar un pedido de prueba, podés consultar sus detalles en este navegador y en el mismo modo.|After confirming a demo order, you can view its details in this browser using the same mode.
Ver mi último pedido de prueba|View my latest demo order
Usá datos ficticios para probar la compra. Los pedidos y datos de prueba permanecen en este navegador. No ingresés datos de tarjeta.|Use fictional details to try checkout. Demo orders and data stay in this browser. Do not enter card information.
Contacto|Contact
El contacto comercial está pendiente de confirmar.|Business contact details have yet to be confirmed.
Instagram de Martha Silva ↗|Martha Silva on Instagram ↗
Tu bolsa|Your bag
Revisá tus prendas antes de continuar.|Review your items before continuing.
Cargando tu bolsa…|Loading your bag…
Resumen de la bolsa|Bag summary
Vestidos de gala, novias y moda femenina.|Occasion dresses, bridal and womenswear.
Vestidos de gala, novias y moda femenina de Martha Silva Store, Nicaragua.|Occasion dresses, bridal and womenswear from Martha Silva Store, Nicaragua.
Selecciones|Selections
Filtros|Filters
Filtrar prendas|Filter styles
Cerrar filtros|Close filters
Prenda o color|Style or color
Categoría|Category
Todos|All
Gris perla|Pearl gray
Blanco perlado|Pearl white
Rojo|Red
Negro|Black
Azul gris|Blue gray
Verde|Green
Verde esmeralda|Emerald green
Rosa bronce|Bronze pink
Rosa empolvado|Dusty pink
Fucsia|Fuchsia
Plata|Silver
Plateado|Silver
Crema floral|Cream floral
Rosa marrón|Rose brown
Burdeos|Burgundy
Negro y blanco|Black and white
Crema y naranja|Cream and orange
Azul gris floral|Blue gray floral
Rosa floral|Pink floral
Rosa claro floral|Light pink floral
Negro y beige|Black and beige
Rosa|Pink
Amarillo|Yellow
Dorado|Gold
Marfil|Ivory
Marrón|Brown
Azul y marfil|Blue and ivory
Burdeos y beige|Burgundy and beige
Blanco|White
Ver prendas|View styles
Ver la selección|View the selection
Páginas de la colección|Collection pages
Página anterior|Previous page
Página siguiente|Next page
La colección de Martha Silva|The Martha Silva collection
Vestidos de gala, novias y moda femenina. Explorá las prendas por color, talla y ocasión.|Occasion dresses, bridal and womenswear. Explore styles by color, size and occasion.
← Volver a la bolsa|← Back to bag
Compra de prueba|Demo checkout
Cargando tu compra de prueba...|Loading your demo checkout...
Vestido dorado de Martha Silva frente a puertas de madera|Martha Silva gold dress in front of wooden doors
Ver vestidos de fiesta|Shop occasion dresses
LA SELECCIÓN DE MARTHA|MARTHA'S SELECTION
Vestidos para celebrar a tu manera.|Dresses for celebrating your way.
Ver la colección|Explore the collection
Escotes, brillo y siluetas largas.|Necklines, sparkle and flowing silhouettes.
Descubrí la selección de novia.|Discover the bridal selection.
Moda para cada ocasión.|Fashion for every occasion.
El edit de novias|The bridal edit
Descubrí la selección de Martha Silva.|Discover Martha Silva's selection.
Ver vestidos de novia|Shop wedding dresses
La colección de Martha|Martha's collection
Una prenda para cada ocasión|A style for every occasion
Gala, novias y moda femenina en Nicaragua.|Occasionwear, bridal and womenswear in Nicaragua.
Explorar la colección|Explore the collection
Tu pedido|Your order
Tu pedido de prueba|Your demo order
Consultá el estado y los detalles de tu pedido de prueba.|Check the status and details of your demo order.
Cargando tu pedido…|Loading your order…
Detalle de la fotografía original|Detail from the original photo
fotografía de stock|stock photo
video de la prenda|product video
Seguimiento:|Tracking:
Quitar filtro|Remove filter
No encontramos prendas con estos filtros.|No styles match these filters.
Probá otra talla, color o colección.|Try another size, color or collection.
Ver todas las prendas|View all styles
Subtotal|Subtotal
Descuento|Discount
Entrega estimada|Estimated delivery
Impuestos de prueba|Sample taxes
Total sin entrega|Total before delivery
Desde|From
Cantidad|Quantity
Retirar|Remove
Cantidad:|Quantity:
Última unidad|Last item
Pocas unidades|Limited stock
Pocas unidades disponibles|Limited stock available
Talla disponible|Size available
Próximamente|Coming soon
Tu bolsa está vacía.|Your bag is empty.
Explorá vestidos de fiesta, novias y moda femenina.|Explore occasion dresses, bridal and womenswear.
Resumen de compra|Order summary
Elegí tu zona de entrega para conocer el total completo antes del pago.|Choose your delivery zone to see the full total before payment.
Compra de prueba. Precios, tallas y stock de muestra.|Demo checkout. Sample prices, sizes and stock.
Compra de prueba · sin cobros reales.|Demo checkout · no real charges.
Revisá tu pedido de prueba anterior.|Review your previous demo order.
Podés recuperar su resultado en este mismo modelo. No se crea una compra real ni se cambia de sistema.|You can recover its result in this same mode. No real purchase is created and the system does not change.
Recuperar pedido de prueba|Recover demo order
Tu pedido de prueba ya fue creado.|Your demo order has already been created.
Continuar con tu pedido|Continue to your order
Agregá una prenda para continuar.|Add an item to continue.
Usá datos ficticios. Esta demo guarda la información solo en este navegador; no envía pedidos ni cobra.|Use fictional details. This demo stores information only in this browser; it does not send orders or charge money.
Nombre y apellido|Full name
Para identificar tu pedido. Esta prueba no envía correos.|To identify your order. This demo does not send emails.
Teléfono|Phone
Para coordinar la entrega cuando la tienda esté activa.|To arrange delivery when the store is live.
Quiero recibir novedades de Martha Silva (opcional).|I'd like updates from Martha Silva (optional).
Continuar con la entrega|Continue to delivery
← Editar contacto|← Edit contact
Dirección de entrega|Delivery address
Dirección|Address
Ciudad|City
Departamento|Department / region
Zona de entrega de prueba|Demo delivery zone
Resto de Nicaragua|Rest of Nicaragua
Tarifas de muestra. La cobertura comercial está pendiente.|Sample rates. Commercial delivery coverage has yet to be confirmed.
Código de descuento|Discount code
Código de prueba opcional: PRUEBA10.|Optional demo code: PRUEBA10.
Revisar la compra|Review purchase
← Editar entrega|← Edit delivery
Revisá tu compra|Review your purchase
Todos los importes son de prueba. No se cobra dinero ni se envían prendas.|All amounts are examples. No money is charged and no items are shipped.
Continuar al pago de prueba|Continue to demo payment
Pago de prueba|Demo payment
Este simulador guarda el resultado en tu pedido. No utiliza tarjetas ni una pasarela bancaria.|This simulator saves the result to your order. It does not use cards or a banking gateway.
No se cobra dinero.|No money is charged.
Aprobar pago de prueba|Approve demo payment
Probar pago rechazado|Try a declined payment
Cancelar pedido|Cancel order
Pasos de compra|Checkout steps
Revisión|Review
Pago|Payment
Tu selección|Your selection
USD · precios, tallas y stock de muestra.|USD · sample prices, sizes and stock.
Pago simulado. No se cobra dinero ni se envían prendas.|Simulated payment. No money is charged and no items are shipped.
Entrega y devoluciones|Delivery and returns
Ver entrega y devoluciones|View delivery and returns
Estado del pedido|Order status
Pedido de prueba guardado. No confirma un cobro ni una entrega real.|Demo order saved. This does not confirm a real charge or delivery.
Registrar recepción|Record receipt
Prenda revisada: devolver al inventario de prueba|Item inspected: return to demo inventory
Procesar reembolso de prueba|Process demo refund
No seleccionaste un pedido.|No order selected.
Completá el pago de prueba|Complete demo payment
La reserva se liberó. Podés volver a agregar las prendas disponibles.|The reservation was released. You can add the available items again.
Volver a agregar las prendas|Add the items again
Solicitar una devolución de prueba|Request a demo return
Seleccioná las prendas que querés devolver.|Select the items you want to return.
No devolver|Do not return
Motivo|Reason
Enviar solicitud de prueba|Submit demo request
Seguir explorando la colección|Continue exploring the collection
No pudimos abrir ese pedido.|We couldn't open that order.
Usá el navegador con el que hiciste la compra de prueba.|Use the browser where you placed the demo order.
Acceso a administración|Administration access
Vista previa local sin autenticación real. No ingresés contraseñas personales. Usá demo para entrar.|Local preview without real authentication. Do not enter personal passwords. Use demo to enter.
Abrir administración de demo|Open demo administration
Pedidos e inventario|Orders and inventory
Actualizar|Refresh
Cerrar sesión|Sign out
Demo de prueba. Los cambios se guardan solo en este navegador. No es un inventario de producción ni está sincronizado con la tienda original.|Demo only. Changes are saved only in this browser. This is not production inventory and is not synchronized with the original store.
Inventario|Inventory
Pedidos|Orders
Número de seguimiento|Tracking number
Preparar pedido|Prepare order
Registrar envío|Record shipment
Registrar entrega|Record delivery
No hay pedidos todavía.|No orders yet.
Inventario por talla|Inventory by size
Prenda / talla|Item / size
Físico|Physical stock
Reservado|Reserved
Disponible|Available
Ajustar|Adjust
Motivo del ajuste|Reason for adjustment
Guardar|Save
No quedan prendas en tu bolsa. Seguí explorando la colección.|There are no items left in your bag. Continue exploring the collection.
Ingresá un email válido.|Enter a valid email address.
Completá este campo.|Complete this field.
Prenda guardada en favoritos.|Item saved to favorites.
Prenda retirada de favoritos.|Item removed from favorites.
Elegí una talla para agregar esta prenda.|Choose a size to add this item.
Prenda agregada a tu bolsa.|Item added to your bag.
Prenda guardada en favoritos y retirada de tu bolsa.|Item saved to favorites and removed from your bag.
Prenda retirada de tu bolsa.|Item removed from your bag.
Revisá tu compra para crear el pedido primero.|Review your purchase to create the order first.
Tu código de prueba: PRUEBA10. No se envió ningún correo.|Your demo code: PRUEBA10. No email was sent.
Seleccioná al menos una prenda para devolver.|Select at least one item to return.
Solicitud de devolución de prueba guardada.|Demo return request saved.
Pago pendiente|Payment pending
Pago de prueba aprobado|Demo payment approved
Pago de prueba rechazado|Demo payment declined
Pedido cancelado|Order cancelled
En preparación|Preparing
Enviado|Shipped
Entregado|Delivered
Reembolso parcial de prueba|Partial demo refund
Reembolso de prueba completado|Demo refund completed
Solicitud recibida|Request received
Prenda recibida|Item received
Pedido creado|Order created
Novedades seleccionadas|Updates selected
Sin suscripción a novedades|No updates subscription
Pago de prueba cancelado|Demo payment cancelled
Devolución solicitada|Return requested
Reserva vencida|Reservation expired
No se cargó la compra de prueba. Usá Reintentar para continuar; no se realizó ninguna operación.|Demo checkout did not load. Use Retry to continue; no action was performed.
No pudimos guardar el modelo en esta pestaña. No se cambió la selección.|We couldn't save the mode in this tab. The selection was not changed.
No pudimos guardar el avance de prueba en esta pestaña. No se envió un pedido real.|We couldn't save demo progress in this tab. No real order was sent.
Modelo no disponible. Las operaciones están bloqueadas.|Mode unavailable. Actions are blocked.
El modelo cambió. Repetí la acción en el modelo seleccionado.|The mode changed. Repeat the action in the selected mode.
La operación pendiente sigue en su modelo original. Podés cambiar al terminar.|The pending action remains in its original mode. You can switch when it finishes.
SAVIA: Sistema de Administración, Ventas, Inventarios y Abastecimiento. Existe una API .NET sintética de prueba, pero esta demo no está conectada a ella ni a un sistema real. La compatibilidad comercial no está validada.|SAVIA: administration, sales, inventory and supply system. A synthetic .NET test API exists, but this demo is not connected to it or to a live system. Commercial compatibility has not been validated.
SISFAIN de CGA: modelo conceptual simulado. No contamos con un contrato ni una API verificada; no hay conexión configurada. La compatibilidad real está pendiente de validación con CGA.|SISFAIN by CGA: a simulated conceptual mode. No verified contract or API is available and no connection is configured. Real compatibility still requires validation with CGA.
bolsa y pedidos de prueba independientes. No se transfirió información entre modelos.|independent demo bag and orders. No information was transferred between modes.
prenda|item
Los datos guardados de la demo están dañados. No los modificamos. Conservá una copia antes de restablecer la demo.|Saved demo data is damaged. We have not changed it. Keep a copy before resetting the demo.
No pudimos guardar la demo en este navegador. Liberá espacio e intentá otra vez.|We couldn't save the demo in this browser. Free up space and try again.
Esta talla no existe en el catálogo de prueba.|This size does not exist in the demo catalog.
No hay suficientes unidades de esta talla. Revisá tu bolsa.|There are not enough items in this size. Review your bag.
No hay suficientes unidades de esta talla.|There are not enough items in this size.
Abrí la vista de administración de prueba. No requiere una contraseña real.|Open demo administration. No real password is required.
No encontramos ese pedido en este navegador.|We couldn't find that order in this browser.
Los datos de esta acción no son válidos. Intentá otra vez.|The data for this action is invalid. Try again.
Ruta no compatible con esta demostración local.|This route is not supported by the local demo.
Elegí una zona de entrega de prueba.|Choose a demo delivery zone.
Código de prueba no válido. Usá PRUEBA10 o dejá el campo vacío.|Invalid demo code. Use PRUEBA10 or leave the field blank.
La compra de prueba necesita una clave de confirmación.|Demo checkout needs a confirmation key.
Esta clave ya corresponde a otra compra de prueba. Conservá la clave para reintentar el mismo intento; usá una nueva para otra compra.|This key belongs to another demo purchase. Keep the key to retry the same attempt; use a new one for another purchase.
Revisá la entrega para calcular de nuevo el total.|Review delivery to recalculate the total.
La bolsa cambió o el presupuesto venció. Revisá la entrega otra vez.|The bag changed or the quote expired. Review delivery again.
Completá los datos de contacto y entrega de prueba.|Complete the demo contact and delivery details.
Elegí un resultado de pago de prueba.|Choose a demo payment outcome.
La devolución de prueba se solicita después de la entrega.|A demo return can be requested after delivery.
Elegí prendas y escribí un motivo de hasta 500 caracteres.|Choose items and enter a reason of up to 500 characters.
Elegí una prenda del pedido.|Choose an item from the order.
La cantidad supera las prendas disponibles para devolución.|The quantity exceeds the items available to return.
Indicá el motivo del ajuste (hasta 200 caracteres).|Enter the reason for adjustment (up to 200 characters).
Este cambio de estado no está disponible.|This status change is not available.
Ingresá un seguimiento de prueba de hasta 120 caracteres.|Enter demo tracking of up to 120 characters.
No encontramos esa devolución.|We couldn't find that return.
Primero registrá la recepción de la prenda.|Record receipt of the item first.
Esta acción no está disponible en la demostración local.|This action is not available in the local demo.
No se cargó el catálogo de prueba. Recargá la página.|The demo catalog did not load. Reload the page.
Las ventas reales están deshabilitadas: estos modelos no son una integración de producción.|Real sales are disabled: these modes are not a production integration.
Esta referencia no pertenece al modelo activo. Volvé a su modelo de origen.|This reference does not belong to the active mode. Return to its original mode.
La demostración nunca registra ventas ni inventario reales.|The demo never records real sales or inventory.
No se cargó el motor local de demostración.|The local demo engine did not load.
No se cargó el catálogo de prueba. No se sustituye por un catálogo vacío.|The demo catalog did not load. An empty catalog will not be substituted.
Referencia de pedido inválida.|Invalid order reference.
Referencia de devolución inválida.|Invalid return reference.
prenda|item
prendas|items
`.trim();
  const messages = Object.fromEntries(pairs.split('\n').map(line => { const at = line.indexOf('|'); return [line.slice(0, at), line.slice(at + 1)]; }));
  const products = `
rosa-empolvado-pedreria|Dusty pink embellished dress|Off-the-shoulder dusty pink gown with sparkling embellishments and a side slit. Bag and shoes are not included.
gris-perla-hombros|Off-the-shoulder pearl gray dress|Off-the-shoulder pearl gray gown with floral motifs, side ruching and a slit. Bag and shoes are not included.
blanco-perlado-sirena|Pearl white V-neck dress|Pearl white gown with thin straps, a V-neck and sparkling lines. The skirt flares toward the hem.
rojo-tirantes-falda-amplia|Red bow-strap full-skirt dress|Red dress with bow straps, a buttoned bodice and a full skirt.
negro-brillo-pantalon-amplio|Black shimmer set|Black set with a strapless buttoned top and wide-leg trousers.
azul-gris-un-hombro|Blue gray one-shoulder dress|Blue gray gown with one sleeve, waist pleats and a slit.
verde-brillo-cuello-cruzado|Green shimmer slit dress|Green shimmer gown with a V-neck, a cutout at the waist and a side slit.
verde-esmeralda-tirantes-cruzados|Emerald green strappy dress|Green strappy gown with pleats, a slit and crossover straps at the back.
rosa-bronce-pedreria|Bronze pink embellished dress|Strapless bronze pink gown with a sweetheart neckline and sparkling embellishments.
negro-escote-puntas-abertura|Black pointed-neckline dress|Strapless black gown with a pointed neckline and a side slit.
fucsia-halter-pliegues|Fuchsia halter-neck dress|Fuchsia gown with a halter neckline, waist pleats and a slit.
plata-tirantes-copas-pedreria|Silver embellished strappy dress|Silver gown with thin straps, defined cups and sparkling embellishments.
crema-flores-volante-asimetrico|Cream floral ruffle dress|Floral halter-neck dress with a full skirt and an asymmetric ruffle.
rosa-marron-chaqueta-falda|Rose brown jacket and skirt set|Set with a pocketed jacket and a straight knee-length skirt.
burdeos-top-pantalon-corto|Sleeveless burgundy set|Burgundy set with a sleeveless top, wide-leg trousers and a buttoned opening at the back.
negro-blanco-lunares-midi|Black and white polka-dot midi dress|Black midi dress with white polka dots, short sleeves and a slit skirt.
crema-flores-naranjas-halter|Cream orange-floral dress|Halter-neck dress with orange flowers and a full skirt.
azul-gris-flores-falda|Blue gray floral dress|Halter-neck dress with large flowers on the skirt and a relaxed silhouette.
rosa-flores-fucsias-halter|Pink fuchsia-floral dress|Pink halter-neck dress with fuchsia flowers and a full skirt.
rosa-claro-flores-doradas|Light pink gold-floral dress|Gown with thin straps, golden motifs and a full skirt.
burdeos-encaje-volantes-midi|Burgundy lace midi dress|Burgundy halter-neck midi dress with floral motifs and a ruffled skirt.
fucsia-un-hombro-volantes|Fuchsia one-shoulder ruffle dress|Fuchsia one-shoulder midi dress with floral motifs and a ruffled skirt.
negro-lunares-beige-hombros|Black and beige polka-dot dress|Off-the-shoulder black midi dress with beige polka dots and a full skirt.
rosa|Pink one-shoulder dress|Pink gown with a one-shoulder neckline, leaf detail and a slit skirt. Sparkling embellishments cover the bodice.
champagne|Strapless champagne dress|Strapless champagne gown with sparkling embellishments and a skirt that flares toward the hem. The photo shows a train.
negro|Black slit dress|Strapless black gown with waist pleats and a slit skirt.
amarillo|Yellow cape dress|Yellow one-shoulder gown with sparkling embellishments and a sheer cape falling from the shoulder.
dorado|Draped gold dress|Gold gown with a V-neck, sparkling embellishments on the bodice and pleats at the waist.
novia|Long-sleeve wedding dress|High-neck wedding dress with long sleeves and floral motifs. The photo shows a veil and bouquet; only the dress is included in this listing.
napoleon|Napoleon cropped button jacket|Cropped brown jacket with long sleeves and rows of buttons. The polka-dot trousers and accessories shown are not included.
azul-floral-un-hombro|Blue floral one-shoulder dress|Blue gown with a light floral print, a one-shoulder neckline and a slit skirt.
midi-estampado-burdeos|Burgundy-print midi dress|Sleeveless midi dress with a burgundy print on a beige background and a full skirt.
novia-satinada-abertura|Draped slit wedding dress|Strapless wedding dress with a sweetheart neckline, pleated bodice and a side slit. Veil, shoes and accessories are not included.
novia-tirantes-encaje|Strappy lace wedding dress|Strappy wedding dress with floral motifs, a V-neck, a slit and a train. Veil, shoes and accessories are not included.
gala-rubi|Ruby sample|Sample, not Martha Silva inventory. Off-the-shoulder red dress with pleats and a side slit.
gala-oro|Gold sample|Sample, not Martha Silva inventory. Gold strappy dress with a draped neckline and an open back.
gala-destello|Sparkle sample|Sample, not Martha Silva inventory. Off-the-shoulder silver dress with sparkling embellishments and a slit.
novias-velo|Veil sample|Sample, not Martha Silva inventory. High-neck wedding dress with long sleeves and lace motifs. The photos show only part of the skirt.
novias-alba|Alba sample|Sample, not Martha Silva inventory. V-neck wedding dress with long sleeves and voluminous shoulders. The photos crop the hem.
novias-encaje|Lace sample|Sample, not Martha Silva inventory. Wedding dress with a V-back, floral motifs, a bow and a train. Only back views are available.
`.trim();
  const byId = Object.fromEntries(products.split('\n').map(line => { const [id, name, description] = line.split('|'); return [id, { name, description }]; }));
  for (const product of window.DEMO_CATALOG?.products || []) {
    const english = byId[product.id];
    if (english) { messages[product.name] = english.name; messages[product.description] = english.description; }
  }
  window.MARTHA_PRODUCT_EN = byId;
  window.MARTHA_EN = messages;
})();
