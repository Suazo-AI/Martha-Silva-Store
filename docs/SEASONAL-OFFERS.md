# Ofertas por temporada — demo Martha Silva

## Alcance

La sección de inicio «Ofertas por temporada» ofrece botones para **Graduaciones**, **Verano**, **Fin de año** y **Bodas y eventos**. Clasifica prendas por una promoción vinculada al producto. Muestra fotos, tipo de prenda, precio previo, precio actual, porcentaje de reducción y tallas con existencias. Si no hay ofertas confirmadas, muestra un estado vacío y acceso al catálogo.

**No se activó ningún descuento.** Los dos productos actuales son muestras (commercial_status=sample), sin promociones aprobadas; no se inventan precios históricos ni campañas. El sitio de Cloudflare y la venta real no fueron modificados.

## Contrato de datos para activar un descuento

Cada registro de catálogo puede declarar, tras validación comercial:

~~~json
{
  "commercial_status": "active",
  "price_minor": 17500,
  "currency": "USD",
  "seasonal_offer": {
    "approved": true,
    "season": "graduaciones",
    "previous_price_minor": 20000,
    "starts_on": "2026-11-01",
    "ends_on": "2026-11-30"
  }
}
~~~

El ejemplo anterior es **esquemático**, no un precio previo real ni una autorización de campaña. No copiarlo al catálogo sin evidencia. Temporadas válidas: graduaciones, verano, fin-de-ano, bodas-eventos.

Una tarjeta se muestra solamente si: la prenda tiene estado comercial active, la moneda es USD, la oferta está aprobada, fecha local de Nicaragua dentro de la vigencia, precio previo en centavos mayor al precio actual, ambos precios enteros válidos y al menos una talla con existencias. El **precio vigente es price_minor**, que también utiliza el simulador de compra; previous_price_minor es exclusivamente el precio histórico verificado para comparación. No agregar un precio promocional divergente del precio de compra.

El porcentaje se calcula a partir de esos dos precios y se redondea al entero más cercano. Si falta un dato, el artículo no aparece como oferta. El catálogo vigente puede seguir consultándose sin descuento.

## Regla comercial y pasos pendientes

Antes de activar cada producto: obtener evidencia verificable del precio previo ofrecido al público, aprobación de la propietaria, campaña/temporada, SKU y talla, estado de existencias, inicio y fin. Documentar fuente y responsable fuera del frontend. Si se requiere descuento por talla, no reutilizar este esquema de precio por producto: el backend debe ofrecer precios y stock por variante y aplicarlos en carrito/checkout.

Este componente sigue siendo una **demo**, con precios y stock ilustrativos. No constituye motor de promociones, garantía de stock, campaña publicada, descuento cobrado ni aprobación de publicación. Para producción, el backend autoritativo debe mantener reglas, tiempo, precio actual, reservas y totales consistentes. Validar además visualmente en móvil/escritorio y con pruebas de compra antes de publicar.

## Verificación

Preparar el build reproducible con python prepare.py, ejecutar python tests/check.py --install en una primera instalación y python tests/check.py después. Los tests DOM de tests/frontend-runtime.cjs cubren: estado vacío para las cuatro temporadas, cambio de selección, datos aprobados y precio consistente, además de descuentos falsos/expirados. jsdom no reemplaza QA visual ni pruebas contra una pasarela/stock real.

## Registro de corrección

- **2026-11-05**: La primera CI detectó una excepción al activar la vista: se había utilizado el selector singular `$` (Element) antes de llamar `forEach`. Se cambió al selector múltiple `$$` (array de Elements) en `src/app.js` y `dist/app.js`. Evidencia inicial: [CI fallida 41995071999](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/41995071999). Es necesario validar el commit corregido con una nueva CI antes de considerarlo apto.
