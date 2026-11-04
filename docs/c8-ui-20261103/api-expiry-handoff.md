# Handoff: expiracion API offline pendiente

Bloqueo comprobado: SDK `10.0.402` solicitado por global.json, solo `8.0.422` instalado.
Destino: `backend/tests/Martha.Store.Api.Tests/InternalSecurityTests.cs`.
No hay test nuevo implementado ni ejecutado.

Primary/Jason debe facilitar un SDK compatible existente, autorizar su instalacion,
o autorizar push para usar un entorno CI que ya lo tenga.
No usar SQL, Docker, certificados, reloj global ni cambios de seguridad productiva.

Con SDK compatible, implementar un unico Fact:
`Expired_cookie_is_rejected_by_fake_TimeProvider_before_database_resolution`.

1. Reutilizar `TestApp`, que usa `UseTestServer` y no abre listener.
2. Extender el helper con un `TimeProvider` opcional solo para este test.
3. Registrar `TestTime` de este archivo en DI del TestServer y en `CookieAuthenticationOptions.TimeProvider` del esquema Internal.
4. Conservar el resto de opciones y eventos productivos; no sustituir autenticacion.
5. Inyectar el callback existente de resolucion DB: incrementar contador y lanzar excepcion antes de configurar SQL.
6. Crear principal sintetico valido con `InternalSecurityRules.Principal` y un ticket del mismo esquema.
7. Definir IssuedUtc con el reloj falso y ExpiresUtc exactamente ocho horas despues.
8. Proteger el ticket con `TicketDataFormat` del esquema; comprobar roundtrip de principal/IssuedUtc/ExpiresUtc.
9. Enviar la cookie mediante HttpClient del TestServer con BaseAddress https://localhost.
10. Avanzar solo TestTime mas alla de ExpiresUtc; no modificar el reloj del host.
11. Consultar GET `/internal/api/security/me`: exigir 401 y contador DB igual a 0.
12. Exigir 401 tambien en la solicitud siguiente y conservar contador igual a 0.
13. No escribir el valor de la cookie ni el ticket en logs o evidencia publica.

El roundtrip evita aceptar un 401 provocado por un ticket mal formado.
El callback DB que lanza demuestra que el camino expirado no resuelve configuracion ni abre SQL.
Cualquier control adicional pre-expiry debe mantener ese callback; no conectarse a una base.

Desde el worktree aislado, con SDK compatible y solo paquetes cacheados:

```powershell
dotnet restore backend/tests/Martha.Store.Api.Tests/Martha.Store.Api.Tests.csproj --locked-mode --ignore-failed-sources --source 'C:/Users/Jason/.nuget/packages' -p:NuGetAudit=false
dotnet test backend/tests/Martha.Store.Api.Tests/Martha.Store.Api.Tests.csproj --no-restore --filter 'FullyQualifiedName~InternalSecurityTests.Expired_cookie_is_rejected_by_fake_TimeProvider_before_database_resolution' --logger 'console;verbosity=minimal'
```

Estos comandos futuros no se ejecutaron con SDK 10; no garantizan cache completo.
Si falta un paquete, detener el camino offline y reportar su version; no instalar sin permiso.

Completion check: exactamente un caso PASS, cero FAIL/SKIP, 401 tras avance del reloj,
contador DB 0 y diff limitado a este archivo de pruebas.
Conservar comando, exit, TRX/log sanitizado y hash del archivo.
No repetir browser/staff: ya estan verificados para el diff actual.
