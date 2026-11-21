# Paquete de prueba SAVIA para tercero

Fecha: 2026-11-11. Pedido por Jason: enviar SAVIA actual por Cloudflare para probar con otra base SQL.

## Qué se entregó

- Build self-contained win-x64 desde `Tony@a8a4dc17e7fd4aa0196df0768453b598f9782eec` con SDK 10.0.402.
- Zip `SAVIA-a8a4dc1.zip`, 55,349,264 bytes, SHA-256 `e56fc8568a0cb952382346a43d2688120ae631832b86c35114dc1dcc38d6ae86`.
- Incluye `1-crear-tablas.sql` (script idempotente con las 4 migraciones Internal), scripts de arranque y `LEEME.md`.
- Fuentes de scripts y página de descarga: [tools/test-package](../../tools/test-package/).
- Descarga: Worker `savia-prueba-fc4ebb31` en la cuenta de Jason, versión `3ebd7410-bf28-40fe-8ce4-8a71d9dcb10a`.
- R2 no está habilitado en la cuenta; el zip va en 3 partes de assets y la página las une y verifica SHA-256.

## Aislamiento de conexiones

- Variables solo del proceso; nada global. Solo acepta bases `SaviaInternalTest_*` por la guarda existente.
- Certificado HTTPS autofirmado para localhost en `.local`; no se instala como confiable.
- Sin appsettings ni secretos dentro del build.

## Evidencia

- Arranque local con servidor SQL inexistente: `/internal/login` 200, `/internal/` 302 a login, readiness 401.
- Descarga desde workers.dev: partes unidas con SHA-256 idéntico, por curl y por el JS de la página en navegador.

## Límites

- No se ejecutó SQL ni creación de Owner contra ninguna base en esta entrega.
- No se probó en la PC del destinatario; SmartScreen o Smart App Control pueden bloquear el exe sin firma.
- La URL es pública para quien la tenga. El código no tiene secretos. Borrar el Worker cuando termine la prueba.
- No cambia el estado de producción: sigue NO-GO.
