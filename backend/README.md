# Backend: primera base técnica, no tienda productiva

ASP.NET Core / .NET SDK 10.0.402, EF Core SQL Server 10.0.13. Leer [contrato](../contracts/README.md) y [alcance del lote](../docs/BACKEND-LOT1.md). El frontend existente sigue usando su simulador; todavía no está conectado a esta API.

## Verificar sin base de datos

Desde la raíz, con el SDK de global.json instalado:

```sh
dotnet restore backend/Martha.Store.slnx --locked-mode
dotnet build backend/Martha.Store.slnx --no-restore -c Release
dotnet test backend/tests/Martha.Store.Api.Tests --no-build --no-restore -c Release
```

El resultado actual esperado sin conexión SQL es 16 pruebas PASS y 6 SQL SKIPPED. Omitir esas pruebas no verifica reservas ni transacciones. En runners restringidos que no permiten sockets internos de MSBuild: restore con `-m:1`; build con `-m:1 -p:UseSharedCompilation=false`. No desactivar protecciones del sistema.

## Entorno sintético (pendiente de SQL autorizado)

- `ASPNETCORE_ENVIRONMENT=Development` y `Synthetic__Enabled=true`, ambos necesarios.
- `ConnectionStrings__Store`: conexión a base de prueba autorizada cuyo nombre cumple `MarthaSynthetic_[A-Za-z0-9_]{1,64}`. No guardar contraseñas en Git. El prefijo es una protección accidental, no prueba que el servidor sea de pruebas.
- Migración y seed son explícitos con argumentos `--migrate` y `--seed-synthetic`; jamás automáticos al iniciar. No aplicar EF CLI directamente a un destino real ni usar overrides para sortear la guarda.
- `--seed-synthetic` no rellena existencias de una semilla ya creada.
- Production/Test no habilitan las rutas sintéticas aunque la bandera esté encendida. Live puede devolver 200 y readiness 503 cuando SQL no está listo; eso es el cierre seguro esperado.

No hay login real, expiración/cancelación de reservas, pagos, clientes, envíos ni despliegue API. Los precios/currency XXX son fixtures, no cotización ni moneda comercial. Las pruebas de carreras/rollback deben pasar contra SQL Server real antes de afirmar esa funcionalidad.

La licencia SQL Server Developer se debe aceptar específicamente para uso no productivo antes de iniciar su contenedor. Su aceptación no autoriza nuevas credenciales, cobros, producción o gastos.
