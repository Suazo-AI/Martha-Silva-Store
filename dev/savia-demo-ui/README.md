# RETIRADO: prototipo de caja separada

El usuario pidio mantener una unica interfaz en la URL principal. Este prototipo queda inerte y fuera de prepare.py y de la publicacion. No volver a publicar /savia/ ni su enlace. El contenido que sigue es evidencia historica de la implementacion descartada.

# SAVIA: demostración de caja

Interfaz de prueba independiente del storefront y del harness CLI. Permite
explorar un catálogo de ejemplo, elegir tallas, preparar una bolsa y probar una
caja simulada con aprobación, rechazo, comprobante, cancelación y reinicio.
Los importes de esta demostración se expresan en **USD de muestra**: no son
precios, SKU ni existencias comerciales. No ingreses datos personales, tarjetas
o credenciales. El escenario vive en memoria: recargar la página lo reinicia.
La bolsa no reserva existencias.

## Abrir en loopback

Desde la raíz del checkout, con Python 3 disponible:

```powershell
py -3 -m http.server 8030 --bind 127.0.0.1 --directory dev/savia-demo-ui
```

En Linux, usar `python3` en lugar de `py -3`. Abrir
<http://127.0.0.1:8030/> y detener el servidor con `Ctrl+C`. El directorio servido
es únicamente esta carpeta; no hace falta copiar archivos a `dist`, abrir la
raíz del repositorio por HTTP ni servir perfiles o carpetas privadas. Mantener
archivos privados y enlaces simbólicos fuera del directorio servido.

## Recorrido

1. Buscar una prenda y elegir una talla disponible.
2. Agregarla a la bolsa y ajustar cantidades o retirar líneas. Los datos y el
   stock de este recorrido pertenecen a la demostración.
3. Abrir la caja y elegir aprobación o rechazo **simulados**. Revisar el
   comprobante de prueba y el efecto sobre la bolsa y las existencias locales.
4. Probar cancelación y reinicio. Leer la confirmación antes de descartar el
   escenario de prueba.

El rechazo conserva bolsa y stock; la aprobación descuenta una sola vez y crea
un comprobante de demo. Cancelar ese comprobante repone sus unidades una vez.
Reiniciar descarta la bolsa y los comprobantes y restaura las fixtures.

No se envían pedidos comerciales, se cobran tarjetas ni se conecta un ERP por
completar este recorrido.

## Vista Conexión

La vista de conexión es un diagnóstico separado de la caja de demostración.
Consulta únicamente, en el mismo origen, `GET /health/ready`,
`GET /api/v2/synthetic/capabilities` y `GET /api/v2/synthetic/catalog`.
Puede indicar no disponible, parcial o listo según la respuesta comprobada.
El servidor estático Python no implementa esas rutas: allí se espera un estado
no disponible, sin inventar una respuesta de backend.

La API sintética tiene su propio contrato y una fixture en moneda **XXX**;
no equivale al catálogo USD de esta interfaz. Una respuesta de capacidades o
catálogo no acredita ventas, pagos, SQL verificado ni compatibilidad CGA.
Esta vista no habilita mutaciones reales ni convierte la demostración en
inventario autoritativo. El harness [SAVIA V2](../savia-harness/README.md) conserva
su flujo y sus requisitos separados.

## Pruebas y publicación

`ui.test.mjs` está destinado a pruebas DOM con jsdom ya instalado y modelo real
de la demostración. No instala paquetes ni abre un navegador. Desde la raíz,
con una instalación existente de jsdom, el responsable del QA puede ejecutar:

```powershell
$env:SAVIA_UI_JSDOM_PACKAGE = '../Martha-Silva-frontend-images/tests/frontend-deps/node_modules/jsdom'
node --test --test-concurrency=1 dev/savia-demo-ui/ui.test.mjs
```

La ruta es un ejemplo del workspace actual; se puede indicar otra carpeta
existente del paquete `jsdom`. Sin esa variable se busca en
`tests/frontend-deps/node_modules/jsdom`. Una dependencia ausente falla con un
mensaje; nunca se instala automáticamente. El responsable coordina una sola
tarea de QA a la vez.

jsdom no verifica diseño, interacción táctil, lectores de pantalla ni una
conexión .NET/SQL. La validación cloud del cliente final pasó ocho pruebas de API y nueve DOM.
El modelo conserva doce pruebas aprobadas con los mismos hashes. Ver
`evidence/cloud-savia-final-results.json` y el inventario asociado. No equivale
a una prueba de navegador ni a una conexión real .NET/SQL.

Por defecto, `prepare.py` sólo copia `build-inputs/static/**` y tres archivos de
`src/`; Wrangler usa `./dist`. `dev/savia-demo-ui/` queda fuera de ese build.
Una publicación en `/savia/` del nuevo Worker de preview requiere empaquetado
explícito mediante `package-preview.py`, que incluye sólo cinco archivos runtime
de esta UI y exige fuentes versionadas sin cambios. No incluye tests, evidencia
ni perfiles. Este documento no acredita que esa
publicación o una conexión remota hayan ocurrido. El Cloudflare original se
mantiene intacto.
