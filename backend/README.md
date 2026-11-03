# Backend .NET / SQL Server

API ASP.NET Core; SDK fijado en [global.json](../global.json): 10.0.402.
El [contrato](../contracts/README.md), [estado](../docs/PROJECT-STATUS.md) y
[DATABASE](../docs/DATABASE.md) distinguen el contexto sintético Store del privado Internal.
La tienda pública conserva su simulador. La UI staff se sirve desde el host privado .NET bajo habilitación explícita.

## Verificación

Desde la raíz, con las dependencias instaladas:

```sh
dotnet restore backend/Martha.Store.slnx --locked-mode
dotnet build backend/Martha.Store.slnx --no-restore -c Release
```

Antes de ejecutar tests, revisar las variables y fixtures SQL: algunas pruebas crean y eliminan bases
cuando reciben conexiones. No usar una conexión ambiental desconocida ni la base del piloto.
La [última ejecución](../docs/testing-20261103/README.md) registró 590 PASS y 2 NOT RUN en total:
523 offline y 67 SQL reales. Es evidencia fechada, no el resultado prometido de cualquier comando sin SQL.
Los dos casos pendientes son migración/backup/restore Internal y reinicio del contenedor propio.

## Autoridad y seguridad

- `Program.cs` configura los dos contextos; `--migrate` y los seeds de ese archivo operan sobre Store.
- `Internal/` contiene sesión, roles, ámbito de sucursal, directorio, stock, ventas, compras e idempotencia.
- `/health/ready` comprueba Store; `/internal/api/readiness` comprueba Internal y exige autorización.
- Internal exige Development, habilitación explícita, HTTPS y nombre de base de prueba permitido.
- El arranque no migra, no crea Owner y no habilita pagos bancarios.

Consultar [DATABASE](../docs/DATABASE.md) antes de preparar conexiones, migraciones o runtime.
No ejecutar comandos de documentos históricos como si fueran una autorización vigente.
Las reservas del adaptador legado no constituyen reservas implementadas en Internal.
