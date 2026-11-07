# Mapa de fuentes para agentes

Corte de navegación: 2026-11-07. Consultar Git para cambios posteriores.
Estado y aceptación: [ledger](pipeline/ledger.json) y [continuación actual](completion-20261107/README.md).

| Necesidad | Fuente / contrato | Comprobación |
| --- | --- | --- |
| Tienda pública y build | [src](../src/), [entradas](../build-inputs/static/), [prepare.py](../prepare.py) | [tests](../tests/README.md), `python tests/build.py` |
| Staff: sesión, venta, recibo y recuperación | [UI](../dev/savia-staff-ui/README.md), [app.mjs](../dev/savia-staff-ui/app.mjs), [client.mjs](../dev/savia-staff-ui/client.mjs) | `dev/savia-staff-ui/*.test.mjs`, [navegador sintético](../tests/browser-mock-validation.mjs) |
| Montaje HTTP y separación de autoridades | [Program.cs](../backend/src/Martha.Store.Api/Program.cs), [InternalHosting.cs](../backend/src/Martha.Store.Api/Internal/InternalHosting.cs) | [HTTP guards](../tests/run-http-guards.mjs), pruebas HTTP de backend |
| Sesiones, roles, CSRF y Owner | [Security](../backend/src/Martha.Store.Api/Internal/Security/), [branch access](../backend/src/Martha.Store.Api/Internal/InternalBranchAccess.cs) | `InternalSecurity*Tests.cs`, `InternalOwnerConsoleTests.cs`, `InternalBranchScope*Tests.cs` |
| Venta, stock, cancelación y devolución | [Commerce](../backend/src/Martha.Store.Api/Internal/Commerce/), [CommandRunner](../backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs) | `InternalCommerce*Tests.cs`, `InternalRunner*Tests.cs` |
| Compras y recepción | [Supply](../backend/src/Martha.Store.Api/Internal/Supply/) | `InternalSupply*Tests.cs` |
| Recepción desde la pantalla staff | [supply.mjs](../dev/savia-staff-ui/supply.mjs), [montaje de recursos](../backend/src/Martha.Store.Api/Internal/InternalUiHosting.cs) | [Chrome con HTTP simulado](../tests/browser-supply-validation.mjs), `InternalSupplyUiTests.cs` |
| Excepción física de stock y revisión | [StockExceptions](../backend/src/Martha.Store.Api/Internal/StockExceptions/), [app.mjs](../dev/savia-staff-ui/app.mjs), [client.mjs](../dev/savia-staff-ui/client.mjs) | `InternalStockException*Tests.cs`, [staff](../dev/savia-staff-ui/stock-exception.test.mjs) |
| Clientes y artículos | [Directory](../backend/src/Martha.Store.Api/Internal/Directory/) | `InternalDirectory*Tests.cs` |
| Esquema, migraciones y recuperación | [DATABASE](DATABASE.md), [migraciones internas](../backend/src/Martha.Store.Api/Internal/Migrations/) | `PrivatePilotReleaseTests.cs`; consultar el resultado fechado del candidato |
| Huella SQL y escrituras no autorizadas | [InternalAcceptanceFingerprint.cs](../backend/tests/Martha.Store.Api.Tests/InternalAcceptanceFingerprint.cs), [uso HTTP/SQL](../backend/tests/Martha.Store.Api.Tests/InternalAcceptanceHttpSqlTests.cs) | `InternalAcceptanceFingerprintTests.cs`; [revisión y límites](local-validation-20261106/astra-fingerprint-judge.md) |
| Particiones locales A/C/E | [inventario congelado](local-validation-20261106/PARTITIONS.json), [verificador](../backend/tests/verify_full_suite.py) | [aceptación del verificador](local-validation-20261106/partition-verifier/ACCEPTANCE.json), [validación actual](completion-20261107/local-validation/README.md) |
| Recorrido real: venta, recepción y excepción | [golden_path.py](../tests/golden-path/golden_path.py), [browser_path.mjs](../tests/golden-path/browser_path.mjs), [oráculos SQL](../tests/golden-path/GoldenPath.Sql/Program.cs) | [contrato y comandos](../tests/golden-path/README.md); un comando preparado no prueba ejecución |
| Runner local en corrección | [preparación](completion-20261107/local-validation/README.md), [rechazo de seguridad](completion-20261107/local-validation/astra-runner-safety.md) | Revisar corrección y controles offline antes de solicitar runtime |
| CSRF por sesión y recuperación Owner | [contrato CSRF](session-csrf-20261107/README.md), [contrato Owner](owner-recovery-20261107/IMPLEMENTATION.md) | Contratos de implementación; confirmar entrega y aceptación en el ledger |
| Contratos y alcance | [contracts](../contracts/README.md), [incremento aceptable](delivery-20261031/NEXT-INCREMENT.md) | [validación histórica](testing-20261103/README.md), [matriz histórica exportada](reconciliation-20261103/operational-history.json) |
| Publicación del trabajo | [AUTO-SYNC](AUTO-SYNC.md), [hooks](../.githooks/), [progress.py](../tools/progress.py) | `python tests/test_progress.py`, `python tools/export_progress.py --verify` |

Los nombres de pruebas son pistas; no acreditan ejecución. La carpeta de pruebas C# es
`backend/tests/Martha.Store.Api.Tests/`. Los DTO, endpoints y políticas de la fuente prevalecen sobre propuestas antiguas.

## Consultas con herramientas existentes

Desde la raíz del checkout, sin iniciar la aplicación:

```sh
git status --short
git log -5 --oneline
rg --files backend/src/Martha.Store.Api/Internal dev/savia-staff-ui contracts
rg -n "pending|receipt|recover" dev/savia-staff-ui/app.mjs
rg -n "RequireAuthorization|MapGet|MapPost" backend/src/Martha.Store.Api/Internal
rg -n "EnsureCreated|MigrateAsync|GetEnvironmentVariable" backend/tests/Martha.Store.Api.Tests
```

## Graphify

Observación histórica del 2026-11-03: `graphify --help` fue bloqueado antes de ejecutar por Windows Application Control en SUAZO-PC:
`An Application Control policy has blocked this file.`
Binario: `C:/Users/Jason/.local/bin/graphify.exe`. No se cambió la política ni se intentó eludirla.
El grafo del folder hermano `cloudflare-store/graphify-out/graph.json` tiene 800 nodos y 1539 enlaces;
corresponde a otro checkout y no se importa como índice vigente. El 2026-11-07 se comprobó que este checkout
no tiene `.codegraph/` ni `graphify-out/graph.json`; el binario no se volvió a ejecutar.

Ruta futura, si se necesita: Jason obtiene revisión autorizada del binario por Windows Application Control;
el agente confirma que `graphify --help` funciona y lee la skill instalada antes de generar un grafo
estructural limitado a código. Registrar SHA del candidato, alcance, versión y límites del extractor.
Excluir evidencia privada, dependencias, builds y medios. No instalar otra plataforma ni habilitar CodeGraph
solo para cerrar este bloqueo. Mientras tanto, Git, `rg` y este mapa permiten continuar.
