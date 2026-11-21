# C8 — revisión independiente

**VEREDICTO: APTO CON REPAROS.**

El parche local de cinco archivos no presenta un bloqueo técnico nuevo demostrado por esta revisión.
Este veredicto no acepta ni cierra C8.
Faltan CI del candidato y evidencia API de expiración absoluta con `TimeProvider` falso.

Fecha: 2026-11-03, America/Managua.
Host: `SUAZO-PC`.
Revisor: `gpt-6.1-sol`, razonamiento `xhigh`.
Modo: `VALIDATE`, revisión independiente de solo lectura.
Worktree: `C:/Users/Jason/MARTHA-SILVA/test-runs/c8-review-20261103`.
Base verificada: `775f301bc195c43baedc68c86f4e71affe92ef95`, HEAD separado.
Contrato: snapshot `C:/Users/Jason/MARTHA-SILVA/coordination/c8-trello-start.json`, tarjeta https://trello.com/c/61IxxolB.

## Alcance y evidencia

Revisé exclusivamente el diff de `app.mjs`, `login.mjs`, `auth.test.mjs`, su `README.md` y `tests/browser-mock-validation.mjs`.
Leí las fuentes inmediatas necesarias, incluidas las autorizaciones de ubicación y recuperación del servidor.
No ejecuté pruebas, navegador, API, SQL, Docker, commits, push ni cambios de seguridad.
Solo escribí este informe.
No repetí C3 ni N5.

Los cinco SHA-256 actuales coinciden con `docs/c8-ui-20261103/verification.json` del worktree productor.
Los siete `browser-results.json` privados coinciden con sus hashes registrados en ese documento.
Esto vincula los bytes revisados con la evidencia suministrada.
No convierte las corridas existentes en una nueva ejecución independiente.

| Evidencia existente | Resultado | Alcance comprobado al leer pruebas y salida |
| --- | --- | --- |
| `baseline-corrected-harness` | 4 PASS, 4 FAIL | N6 versión cambiada y tres POST tardíos de N7 fallan con producto base |
| `green-final` | 9 PASS, 0 FAIL | N2 por tres roles, N6 por actor/versión/legado y N7 por 401/logout |
| `red-app-only` | 7 PASS, 2 FAIL | Vuelven a fallar versión cambiada y legado fuera del ámbito |
| `red-login-only` | 6 PASS, 3 FAIL | Vuelven los tres POST tardíos de N7 |
| `full` | 45 PASS, 0 FAIL | Incluye los 36 casos existentes y los nueve C8 |
| Staff JS registrado | 45 PASS, 0 FAIL | Añade tres casos de respuestas tardías y revalidación concurrente |

Chrome registrado: `156.0.8078.80`.
Node registrado: `v24.18.0`.
El primer baseline contiene errores del arnés y no demuestra los tres defectos N7.
El baseline corregido y las reversiones selectivas sí conservan un oráculo concreto de cero POST.
El driver `red-proof.py` solo escribe temporalmente `app.mjs` y `login.mjs`; restaura sus bytes en `finally`.
El hash del arnés se tomó después de las corridas.
No existe un hash del arnés capturado dentro de cada corrida histórica.
Esta limitación está declarada y no se oculta con los conteos.

## Hallazgos técnicos

No encontré un defecto nuevo accionable que justifique `NO APTO` para estos cinco archivos.
No atribuyo fallos a carreras hipotéticas sin un camino del producto que las active.

Lo que se cumple: clave original, aislamiento por actor, bloqueo conservador por versión/ubicación, descarte por época y cancelación antes del POST.

| Criterio congelado | Evaluación |
| --- | --- |
| N2: Cashier recarga y recupera sin otro POST; Owner/Manager permitidos | Las pruebas `browser-mock-validation.mjs:141–152` comprueban payload, clave del GET de recuperación, recibo y un único POST tras dos recargas. Ya pasaban en la base. |
| N6: conservar intento al cambiar actor | `app.mjs:410` y `525–530` cargan únicamente el registro del actor actual. El caso `153–163` conserva los bytes del actor anterior y no consulta su operación. |
| N6: cambiar versión o ubicación bloquea reenvío | `app.mjs:414–424`, `492–494` y `532–535` aplican las guardas también al manejador. `548` guarda la versión al crear el intento. Las reversiones selectivas distinguen los fallos corregidos. |
| N6: legado sin versión | No recibe versión nueva. `424` y `494` impiden reenviar. Puede consultar recuperación cuando su ubicación sigue en la lista autorizada. El caso fuera del ámbito verifica conservación exacta y cero GET/POST. |
| N7: headers/body tardíos después de 401 | `login.mjs:56–58` y `75–77` verifican la época antes de devolver datos. `auth.test.mjs:139–160` retiene cada frontera y exige rechazo 401, sesión nula y lecturas cerradas. |
| N7: POST esperando CSRF | `login.mjs:125–134` captura la época antes del `await` y la vuelve a comprobar. `58` y `117` invalidan por 401/logout. Los casos `185–219` exigen cero POST y ausencia de datos privados visibles. |
| N7: revalidación concurrente | `login.mjs:93–101` evita que un `/me` anterior reactive sesión tras un 401 o borre una verificación posterior. `auth.test.mjs:162–177` comprueba el primer escenario. |
| Guardas existentes y seguridad | El diff añade pruebas y conserva las expectativas anteriores. No modifica backend, políticas, cookies, CSRF ni configuración de seguridad. Las guardas de N5 siguen en `app.mjs:474–490`. |

### Épocas del cliente y de la UI

Una verificación exitosa incrementa la época del cliente.
Una respuesta anterior pendiente pasa a rechazar con 401 local, aunque el servidor devolviera 200.
Esto evita consumir datos de una identidad anterior.

Los consumidores de UI descartan generaciones anteriores antes de actuar sobre éxito o error.
Fuentes: `app.mjs:255–263`, `295–325`, `353–360` y `413`.
La UI actual llama `verifySession()` solo al montar, en `394`.
El login usa su propia instancia y después navega a la aplicación.
No encontré un camino actual donde una revalidación benigna compartida provoque un cierre espurio del montaje vigente.
Si después se añade revalidación periódica, debe avanzarse también la época de UI antes de llamar al cliente.
No presento esa ampliación futura como un defecto de este parche.

### Autoridad del servidor y compatibilidad

`InternalDirectoryEndpoints.cs:71–81` obtiene ubicaciones mediante `InternalBranchAccess.Locations`.
`InternalBranchAccess.cs:27–42` limita sucursal vigente y exige actor y sucursal original para leer operaciones.
`InternalHosting.cs:63–74` vuelve a validar la sesión y filtra la operación por actor, scope y clave.
La lista del cliente no concede acceso por sí sola.
Una ubicación reasignada puede pasar la selección actual y todavía recibir 403 por la sucursal original.
Ese 403 no revela el resultado privado ni autoriza reenvío.

El bloqueo por versión también afecta cambios de nombre o contraseña sin cambio de sucursal.
`InternalSecurityService.cs:111–115`, `129–130` y `151–157` rotan `SecurityVersion` en esos casos.
Por tanto, una venta incierta puede requerir conciliación manual aun cuando la sucursal siga permitida.
Este límite es conservador y coincide con el contrato congelado.
La referencia permanece guardada; no se reemplaza con otra venta ni con otra versión.
Los legados sin versión y recuperación todavía desconocida tampoco recuperan el permiso de reenviar.
No hay una nueva pantalla de conciliación en este alcance.

## Reparos de verificación y siguiente acción

1. **API con reloj falso: pendiente.** `absolute-expiry` devuelve 401 desde el mock del navegador.
   La prueba existente `InternalSecurityTests.cs:70–93` cambia `ExpiresAt` y llama directamente a `SessionIsValid` con `Now` fijo.
   `InternalSecurityService.ValidateSession` usa `TimeProvider`, pero consulta la base persistida.
   `TestTime` existente se usa en el limiter; no prueba expiración de sesión mediante HTTP.
   No afirmo que la API con reloj falso haya pasado.

   Siguiente acción acotada: añadir una prueba `UseTestServer` de cookie sintética protegida y reloj falso.
   Reutilizar `InternalSecurityTests.TestApp`, sin listener externo, SQL, cuenta real ni cambio de configuración de producción.
   Avanzar el reloj más allá de `ExpiresUtc` y exigir HTTP 401 en `/internal/api/security/me`.
   Añadir un contador que falle si se resuelve la configuración de base de datos.
   Exigir contador `0` al terminar.
   Esa prueba cubriría la expiración HTTP de cookie; no demostraría la validación de una sesión persistida ni SQL.
   Owner: primary/worker C8 autorizado.
   Completion check: prueba nueva con reloj falso, 401 real de TestServer y contador DB `0`.

2. **CI del nuevo candidato: pendiente.** No existe un run que cubra estos bytes nuevos.
   El CI de la base o de otro SHA no sirve como readback del candidato.
   Owner: primary/Jason.
   Completion check: SHA exacto publicado y CI aplicable terminado en verde.
   Este juez no tiene autorización para publicar ni ejecutar CI.

3. **Grabaciones y aceptación visual: límite separado.** Leí las rutas y procedencia declaradas.
   No analicé los videos ni atribuyo aceptación visual a esta revisión de código.
   No es una regresión técnica demostrada del diff.

El primary debe verificar este informe antes de aceptarlo.
No marcar C8 completa con la evidencia actual.

## Fuentes de evidencia

- `C:/Users/Jason/MARTHA-SILVA/test-runs/c8-n2-n6-n7-20261103/docs/c8-ui-20261103/report.md`
- `C:/Users/Jason/MARTHA-SILVA/test-runs/c8-n2-n6-n7-20261103/docs/c8-ui-20261103/verification.json`
- `C:/Users/Jason/MARTHA-SILVA/test-runs/c8-n2-n6-n7-20261103-evidence/*/browser-results.json`
- `C:/Users/Jason/MARTHA-SILVA/test-runs/c8-n2-n6-n7-20261103-evidence/red-proof.py`

Comprobaciones de este juez: `git status --short`, `git rev-parse HEAD`, `git diff`, lecturas con líneas y `Get-FileHash -Algorithm SHA256`.
Las referencias de código anteriores son relativas al worktree de revisión.
No se ha afirmado ninguna ejecución nueva de producto.
