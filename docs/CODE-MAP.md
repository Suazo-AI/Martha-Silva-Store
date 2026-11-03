# Mapa de fuentes para agentes

Corte: 2026-11-03. Rutas verificadas en el checkout canónico. Consultar Git para cambios posteriores.

| Necesidad | Fuente / contrato | Comprobación |
| --- | --- | --- |
| Tienda pública y build | [src](../src/), [entradas](../build-inputs/static/), [prepare.py](../prepare.py) | [tests](../tests/README.md), `python tests/build.py` |
| Staff: sesión, venta, recibo y recuperación | [UI](../dev/savia-staff-ui/README.md), [app.mjs](../dev/savia-staff-ui/app.mjs), [client.mjs](../dev/savia-staff-ui/client.mjs) | `dev/savia-staff-ui/*.test.mjs`, [navegador sintético](../tests/browser-mock-validation.mjs) |
| Montaje HTTP y separación de autoridades | [Program.cs](../backend/src/Martha.Store.Api/Program.cs), [InternalHosting.cs](../backend/src/Martha.Store.Api/Internal/InternalHosting.cs) | [HTTP guards](../tests/run-http-guards.mjs), pruebas HTTP de backend |
| Sesiones, roles, CSRF y Owner | [Security](../backend/src/Martha.Store.Api/Internal/Security/), [branch access](../backend/src/Martha.Store.Api/Internal/InternalBranchAccess.cs) | `InternalSecurity*Tests.cs`, `InternalOwnerConsoleTests.cs`, `InternalBranchScope*Tests.cs` |
| Venta, stock, cancelación y devolución | [Commerce](../backend/src/Martha.Store.Api/Internal/Commerce/), [CommandRunner](../backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs) | `InternalCommerce*Tests.cs`, `InternalRunner*Tests.cs` |
| Compras y recepción | [Supply](../backend/src/Martha.Store.Api/Internal/Supply/) | `InternalSupply*Tests.cs` |
| Clientes y artículos | [Directory](../backend/src/Martha.Store.Api/Internal/Directory/) | `InternalDirectory*Tests.cs` |
| Esquema, migraciones y recuperación | [DATABASE](DATABASE.md), [migraciones internas](../backend/src/Martha.Store.Api/Internal/Migrations/) | `PrivatePilotReleaseTests.cs`; dos casos siguen NOT RUN en el lote reciente |
| Contratos y alcance | [contracts](../contracts/README.md), [incremento aceptable](delivery-20261031/NEXT-INCREMENT.md) | [evidencia reciente](testing-20261103/README.md), [matriz histórica exportada](reconciliation-20261103/operational-history.json) |
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

`graphify --help` fue bloqueado antes de ejecutar por Windows Application Control en SUAZO-PC:
`An Application Control policy has blocked this file.`
Binario: `C:/Users/Jason/.local/bin/graphify.exe`. No se cambió la política ni se intentó eludirla.
El grafo del folder hermano `cloudflare-store/graphify-out/graph.json` tiene 800 nodos y 1539 enlaces;
corresponde a otro checkout y no se importa como índice vigente. Este checkout no tiene `.codegraph/`
ni `graphify-out/graph.json` al corte indicado.

Ruta futura, si se necesita: Jason obtiene revisión autorizada del binario por Windows Application Control;
el agente confirma que `graphify --help` funciona y lee la skill instalada antes de generar un grafo
estructural limitado a código. Registrar SHA del candidato, alcance, versión y límites del extractor.
Excluir evidencia privada, dependencias, builds y medios. No instalar otra plataforma ni habilitar CodeGraph
solo para cerrar este bloqueo. Mientras tanto, Git, `rg` y este mapa permiten continuar.
