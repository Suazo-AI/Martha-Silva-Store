# C8: expiración API verificada localmente

Resultado: **PASS local**. Revisión del primary y CI siguen pendientes.
Host: `SUAZO-PC`, Windows x64. Worker: `gpt-6.1-sol`, razonamiento `high`.
Base: `775f301bc195c43baedc68c86f4e71affe92ef95`.
Rama: `task/c8-api-expiry-20261103`. Sin commit, push, PR, merge ni despliegue.

## Evidencia comprobada

- SDK portable `10.0.402` instalado en `C:/Users/Jason/.dotnet-sdk-10.0.402`.
- ZIP oficial de Microsoft verificado con SHA512 antes de extraer. Descarga única, sin fallo.
- `dotnet.exe --version`: `10.0.402`. `--list-sdks`: solo `10.0.402` en el directorio portable.
- Restore `--locked-mode --ignore-failed-sources --source C:/Users/Jason/.nuget/packages`: `exit 0`.
- No se desactivó la auditoría ni se editaron configuraciones de NuGet.
- Test nuevo: **1/1 PASS, 0 FAIL, 0 SKIP**.
- `InternalSecurityTests`: **49/49 PASS, 0 FAIL, 0 SKIP**; incluye el caso nuevo.
- `git diff --check`: `exit 0`. Los cinco archivos UI previos conservan sus SHA256.
- Cero procesos del SDK portable restantes después de las pruebas.

El test usa `UseTestServer()` y su cliente en memoria con `https://localhost`.
Registra el mismo `TestTime` en DI y en las opciones nombradas `InternalSavia`.
Conserva los eventos productivos `InternalCookieEvents`, ocho horas y expiración sin renovación deslizante.
Crea un principal sintético con las claims de sesión, rol y versión mediante `InternalSecurityRules.Principal`.
El ticket se protege con el `TicketDataFormat` configurado del mismo esquema.
El roundtrip comprueba esquema, identidad válida, `IssuedUtc` y `ExpiresUtc` exactamente ocho horas después.
Después avanza únicamente el reloj falso a ocho horas y un segundo.
Dos `GET /internal/api/security/me` devuelven `401`; el contador de resolución DB permanece `0`.
La guarda DB lanzaría una excepción antes de configurar SQL si fuera alcanzada.

El control no expirado usa otro TestServer con reloj sin avanzar y las mismas reglas productivas.
Su cookie alcanza la validación productiva: la guarda DB registra `1` y lanza la excepción exacta prevista.
La excepción ocurre antes de `UseSqlServer`; no conecta SQL ni ejecuta consultas.
Esto distingue la expiración real de una cookie mal formada o ignorada.
El contador del host expirado conserva `0` durante todo el caso.
No se escribió el valor protegido del ticket en ningún log o evidencia.

## Comandos y resultados

Los comandos exactos, argumentos, tiempos, exits y hashes de logs están en `command-results.json`.
La ruta absoluta del ejecutable fue `C:/Users/Jason/.dotnet-sdk-10.0.402/dotnet.exe`.
El proceso recibió `DOTNET_ROOT` y `DOTNET_CLI_HOME` locales al proceso.
No cambió PATH, registro ni variables globales.
Se desactivó la reutilización de procesos MSBuild para no dejar procesos propios activos.
El test focal compiló sin compartir compilador; las regresiones reutilizaron ese build con `--no-build`.
No se repitieron las suites browser/staff ya aprobadas.
Los TRX sanitizados conservan resultados y eliminan salida capturada, usuario, equipo y rutas de ensamblados.
Los originales y logs se conservan fuera del repositorio en la carpeta privada de evidencia.

## Bloqueos y límites

El bloqueo histórico de SDK incompatible queda resuelto por esta instalación portable.
La evidencia histórica `api-prerequisite.json` y `api-expiry-handoff.md` no se sobrescribió.
No hubo fallos de descarga, restauración ni pruebas en este lote.
La primera compilación fue fría; el caso nuevo tardó unos 14 segundos y las regresiones unos 6 segundos.
No se cambió seguridad productiva, reloj global, SQL, Docker, certificados, firewall ni datos reales.
No se abrió un listener HTTP: `GetTestClient()` usa el TestServer en memoria.
Este resultado no prueba navegador → API → SQL, despliegue, sesión real ni disponibilidad de producción.

Pendiente: revisión del primary, exportación pública al checkout canónico y CI del commit que corresponda.
Responsable: primary; comprobar patch, hashes, TRX y alcance antes de integrar.
El worktree queda modificado intencionalmente: cinco archivos UI heredados, un test y esta documentación.
No se afirma una copia limpia ni sincronizada.

## Lección aplicable

Un `401` aislado no prueba expiración: una cookie inválida también produce rechazo.
Combinar roundtrip, tiempo falso y control no expirado distingue ambas causas sin conectar una base.
Evidencia: el caso nuevo PASS, dos respuestas `401` con contador `0` y control de guarda con contador `1`.
