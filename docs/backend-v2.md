# Backend V2: libro sintético SAVIA

V2 agrega un puerto `IErpPort`, el adaptador `SaviaErpAdapter` y un descriptor `CgaCapabilityAdapter` cerrado. [Contrato HTTP](../contracts/openapi-v2.json) y [convenciones](../contracts/README.md). No redirige rutas V1 ni convierte sus existencias.

`Program.cs` registra V2 únicamente con `Development` y `Synthetic:Enabled=true`. Las mutaciones validan estructura, clave y autoridad antes de resolver SQL; el guard de base `MarthaSynthetic_[A-Za-z0-9_]{1,64}` continúa en la creación del contexto. Las capacidades son información de código sin acceso SQL: SAVIA sintético implementado, ejecución SQL no verificada; CGA no verificado, sin operaciones, conexión ni endpoint.

V2 mantiene `onHand >= reserved >= 0`; disponible es su diferencia. Reservar aumenta `reserved`; cancelar libera una sola vez, sin aumentar stock físico. Las tablas V2 son independientes de V1 y el seed V2 explícito no interpreta existencias anteriores. Precio/moneda vienen del servidor. La creación se conserva inmutable; su consulta de estado cambia a cancelada y expone la fecha por separado. Cada mutación queda vinculada a autoridad fija, operación, attemptId y clave. No se implementan expiración, venta, envío, devolución ni pagos.

## Operación explícita en un SQL de pruebas autorizado

La autorización para escribir código y compilar no autoriza iniciar SQL, aceptar EULA, crear credenciales ni ejecutar estas operaciones. Tras autorización separada del destino, migración y seeds se solicitan por CLI:

```text
--migrate
--seed-savia-synthetic
```

El flag V2 usa `SaviaSyntheticSeed.Apply` después de validar entorno y guard del contexto. Nunca se migra o siembra durante inicio normal ni readiness. `--seed-synthetic` sigue siendo la operación V1 anterior. Readiness verifica conexión/migraciones/esquema V1 y, cuando el gate V2 está activo, las tablas V2 mediante `CheckSchema`; no crea ni repara nada.

## Reconciliación y evidencia

La autoridad es siempre `savia / savia-synthetic-v2 / 1`; nunca se cambia por conectividad. Un fallo de transporte o un HTTP que no entrega recibo durable deja el resultado desconocido. El lookup devuelve el recibo de la operación en esta misma autoridad; `attempt_unknown` tampoco prueba ausencia de efecto. No existe fallback automático a CGA ni a almacenamiento local.

Compilar con SDK exacto `10.0.402`, restore `--locked-mode`, build/test `--no-restore`. Los tests sin SQL prueban contratos, gates y validación, pero no acreditan carreras ni transacciones. La integración SQL real debe verificar esquema separado, reservas concurrentes, claves/attemptId concurrentes, cancelación repetida y concurrente, rollback y replay original después de cancelar. No se afirma preparación productiva ni despliegue.

El harness de desarrollo usa CLI Node con HTTP; no publica HTML, no requiere CORS y no es un cliente comercial. Sin ejecución autorizada contra SQL no acredita un flujo E2E. Su lookup conserva estado desconocido ante `404 attempt_unknown`, fallos de red o HTTP sin recibo verificable, sin enviar a CGA.

## Verificación local del candidato

Restore oficial bloqueado (`--locked-mode`) en caché aislada y compilación Release con SDK 10.0.402: PASS, cero advertencias/errores. Pruebas C#: 45 PASS, 0 FAIL, 21 SQL SKIPPED; no se abrió una base ni se aplicó la migración. Las pruebas SQL omitidas no verifican transacciones ni cierran R07.

Playwright Test 1.62.1 ya instalado ejecutó cuatro pruebas con trazas contra HTTP local de la API real y un catálogo de conexión deliberadamente inválido: capacidades, validación/autoridad y cierre seguro sin datos ficticios. No constituye compra/reserva SQL end-to-end. El servidor temporal propio fue detenido. Ver [suite aislada](../dev/savia-harness/playwright/README.md) y [evidencia local](../evidence/savia-v2-local-gates.json).

El primer arranque del SDK informó creación automática de un certificado HTTPS de desarrollo; no se ejecutó trust. Las invocaciones posteriores deshabilitan esa generación. No se limpiaron certificados ajenos.
