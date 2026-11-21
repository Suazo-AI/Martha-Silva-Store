# C8: expiracion API completada, CI pendiente

Aceptado localmente por el primary tras revisar fuente, diff, logs originales, TRX y hashes.
Host `SUAZO-PC`. Worker `gpt-6.1-sol`, razonamiento `high`.
Base exacta `775f301bc195c43baedc68c86f4e71affe92ef95`.

- SDK portable `10.0.402`: `C:/Users/Jason/.dotnet-sdk-10.0.402/dotnet.exe`.
- ZIP oficial SHA512 verificado por worker y primary. Version leida independientemente; SDK del sistema conserva `8.0.422`.
- Restore locked desde cache: exit `0`. Sin cambios de NuGet, PATH global ni seguridad.
- Test nuevo: `1/1 PASS`; regresiones `InternalSecurityTests`: `49/49 PASS`, incluido el nuevo. Cero FAIL/SKIP.
- Ticket sintetico valido, ocho horas de vigencia y avance solo del reloj falso a ocho horas y un segundo.
- Dos GET `/internal/api/security/me`: `401`, contador DB `0`.
- Control sin expirar: contador de guarda DB `1`, excepcion prevista antes de configurar SQL.
- Eventos de autenticacion productivos conservados. Sin SQL, Docker, certificados, reloj global ni listener TCP.
- UI: cinco hashes anteriores intactos. Evidencia previa reutilizada: enfocado `9/9`, navegador `45/45`, staff JS `45/45`.
- Navegador previo: Chrome `156.0.8078.80`; Node `v24.18.0`. No se repitieron navegador ni C3.

[Comandos exactos, exits y tiempos](command-results.json). [TRX focal](expiry-test.sanitized.trx). [TRX regresiones](security-regressions.sanitized.trx).
[Proveniencia del SDK](sdk-provenance.json). [Aceptacion del primary](primary-acceptance.json).
[Reporte original del worker, anterior a la aceptacion](report.md).

## Estado y recursos

[Trello C8](https://trello.com/c/61IxxolB): `4/5`, `En curso`, CI sin marcar.
Descripcion actualizada y lectura exacta posterior verificada; [readback](trello-readback.json).
El bloqueo historico del SDK queda resuelto. Su evidencia de fallo se conserva sin sobrescribir.
C11 conserva dependencia C8 hasta cumplir CI del candidato que contenga ambos parches.
El CI de otros heads no demuestra estos cambios locales.

Worktree `C:/Users/Jason/MARTHA-SILVA/test-runs/c8-api-expiry-20261103`, rama `task/c8-api-expiry-20261103`.
La copia queda modificada intencionalmente: cinco archivos UI previos, un archivo de pruebas backend y documentacion.
No queda limpia ni sincronizada. No se descartaron cambios ni se eliminaron worktrees.
Cero procesos propios del SDK restantes al cierre del worker; primary comprobo ausencia de dotnet/testhost al revisar.
El checkout canonico recibe fuentes revisables y evidencia publica; no se aplica alli el producto.
Los logs privados, el ZIP y el ticket sintetico no se exportaron al checkout.

Patch backend SHA256: `927ea77b1a63c134cae03dac13e6545d624a05a8f3aabb501d01fef100a23e09`.
Test backend SHA256: `cf45feb9be7ef8e79f108ad0baa2b288c0bf488711fa9c08632ce740ff079c49`.
[Patch backend](backend-test.patch). [Patch UI previo](../ui.patch).
No hubo commit, push, merge, despliegue ni cambios de seguridad en este lote.
La evidencia esta guardada localmente en el checkout canonico; no se publico en GitHub.

Pendiente: CI del candidato. Responsable primary/Jason cuando se autorice publicar ese candidato.
Comprobacion: CI del SHA que contiene ambos parches en verde, antes de marcar `5/5`.
No se solicita ni ejecuta publicacion en este lote.

## Leccion comprobada

Un `401` aislado tambien puede venir de una cookie invalida.
Roundtrip, reloj falso y control no expirado permiten demostrar expiracion sin abrir una base.
