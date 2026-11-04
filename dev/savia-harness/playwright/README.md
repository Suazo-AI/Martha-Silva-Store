# Playwright: pruebas HTTP y navegador sin SQL

Suite de desarrollo aislada del build público. Usa Playwright Test ya instalado mediante `SAVIA_PLAYWRIGHT_PACKAGE`; no instala paquetes automáticamente ni usa el MCP del navegador. Node >=20, Playwright 1.62.1 y Chrome instalado fueron comprobados en este equipo.

Estas pruebas navegan una respuesta JSON real de capacidades y verifican los guards HTTP de la API .NET. **No prueban reserva/cancelación persistida, transacciones SQL, stock comercial ni integración CGA.** El servidor debe arrancarse deliberadamente sin destino SQL utilizable; no apuntar a una conexión heredada o comercial.

## Ejecución local controlada

1. Usar el SDK 10.0.402 y el backend ya compilado.
2. En un proceso exclusivo de prueba, quitar `MARTHA_TEST_SQL_CONNECTION`, configurar Development y `Synthetic__Enabled=true`, y sobrescribir `ConnectionStrings__Store=Database=Forbidden_NoSql`. Ese catálogo no pasa la guarda: cualquier resolución de almacenamiento falla antes de abrir una conexión.
3. Iniciar la API únicamente en una dirección HTTP loopback libre; no ejecutar flags de migración/seed.
4. Definir variables del runner y ejecutar desde la raíz:

```powershell
$env:SAVIA_PLAYWRIGHT_PACKAGE = '<carpeta del paquete oficial playwright instalado>'
$env:SAVIA_QA_ORIGIN = 'http://127.0.0.1:5087'
$env:SAVIA_QA_OUTPUT = '<carpeta privada de resultados>'
node "$env:SAVIA_PLAYWRIGHT_PACKAGE/cli.js" test -c dev/savia-harness/playwright/playwright.config.mjs
```

La configuración fija un worker, cero reintentos, Chrome headless con perfil temporal y trace `on`. Solo el proceso que inició el servidor debe detener ese proceso; no manejar terminales o navegadores ajenos.

Cada prueba produce un `trace.zip` local. Para inspeccionarlo con el visor oficial:

```powershell
node "$env:SAVIA_PLAYWRIGHT_PACKAGE/cli.js" show-trace '<ruta/trace.zip>'
```

El visor puede requerir su navegador Playwright compatible; comprobar ese requisito antes de descargarlo. No subir trazas a servicios externos. El CLI y las trazas no sustituyen un resultado SQL real. SQL/Testcontainers, licencias y ejecución CI conservan sus autorizaciones separadas. Stryker queda para una etapa posterior.
