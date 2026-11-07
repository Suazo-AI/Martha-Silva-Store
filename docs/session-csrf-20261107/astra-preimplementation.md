# SEC-CSRF pre-implementation review

**VIABLE CON CONDICIONES.** El proveedor propuesto puede cumplir la regla adoptada. Su implementación y eficacia todavía no están probadas. Este informe es asesoría, no aceptación ni permiso.

Task: `savia-session-csrf-preimplementation-584fcaa-20261107`.
Solicitado: `codex / gpt-6-astra / reasoningEffort xhigh`.
Expuesto por T3/Codex y agent-awareness: `gpt-6-astra/xhigh`, host `SUAZO-PC`; coincide. Telemetría interna adicional: desconocida.
Checkout administrado: `C:/Users/Jason/.t3/worktrees/github/t3-caf284da`.
HEAD verificado: `584fcaa6a11a09c1dbdcc97df3205d3e85a0b8d8`; inicialmente limpio.
Único archivo creado: `docs/session-csrf-20261107/astra-preimplementation.md`.

## Fuente observada y riesgos

`InternalSecurityRules.cs:25–45` crea una identidad estable con `NameIdentifier`, rol, versión y `savia:session`.
`InternalSecurityService.cs:40–60` genera otra sesión al ingresar, revoca anteriores y valida estado persistido.
El [extractor del framework v10.0.0](https://raw.githubusercontent.com/dotnet/aspnetcore/v10.0.0/src/Antiforgery/src/Internal/DefaultClaimUidExtractor.cs) prioriza `NameIdentifier`; cambiar solamente `savia:session` no cambia esa identidad antiforgery.
N8 actual (`InternalAcceptanceHttpSqlTests.cs:374–420`) cambia cashier→manager; no demuestra same-account relogin.

**P1 — Registro ineficaz o aceptación vacía.** `TryAddSingleton` después de `AddAntiforgery` conservaría el proveedor predeterminado. Aceptar datos vacíos para autenticados conservaría el hueco.
La [DI del framework](https://raw.githubusercontent.com/dotnet/aspnetcore/v10.0.0/src/Antiforgery/src/AntiforgeryServiceCollectionExtensions.cs) y su [generador/validador](https://raw.githubusercontent.com/dotnet/aspnetcore/v10.0.0/src/Antiforgery/src/Internal/DefaultAntiforgeryTokenGenerator.cs) sustentan esta conclusión.

**Recomendación:** después de `AddAntiforgery`, antes del return de `InternalSecurity.AddInternalSecurity:51–61`, usar `services.Replace(ServiceDescriptor.Singleton<IAntiforgeryAdditionalDataProvider, InternalSessionAntiforgeryAdditionalDataProvider>())`.
Proveedor sin estado; leer exclusivamente el `HttpContext` recibido.
Comprobar en prueba el tipo resuelto.

Autenticado: exigir exactamente un claim de sesión en la identidad autenticada, GUID D canónico no vacío; emitir `s1:<session-id>` y comparar ordinalmente.
Rechazar claims ausentes, inválidos o duplicados, incluso duplicados idénticos y distribuidos entre identidades.
No clasificar como anónimo un principal mixto con identidad autenticada.
Generación inválida: no devolver token utilizable; error fijo sin valores.
Validación inválida: `false`, sin excepciones que expongan datos.
Anónimo: emitir/aceptar cadena vacía, conservando login-CSRF; nunca aceptarla para mutaciones autenticadas.

La [interfaz oficial](https://learn.microsoft.com/en-us/dotnet/api/microsoft.aspnetcore.antiforgery.iantiforgeryadditionaldataprovider?view=aspnetcore-10.0) está presente también en el XML local `Microsoft.AspNetCore.App.Ref/10.0.13/ref/net10.0/Microsoft.AspNetCore.Antiforgery.xml:184–213`, dentro del SDK documentado.
Compatibilidad ejecutada con 10.0.13: NOT RUN.

## Todas las rutas internas de escritura

Prefijo común: `/internal/api`. Son 22 combinaciones método/ruta.

| Área | Rutas relativas |
|---|---|
| security | POST `/security/login`, `/security/logout`, `/security/staff`, `/security/staff/{staffId:guid}/password`; PUT `/security/staff/{staffId:guid}` |
| directory | Para cada `items`, `locations`, `parties`: POST `/directory/{recurso}`; PUT/DELETE `/directory/{recurso}/{id:guid}` |
| commerce | POST `/commerce/adjustments`, `/commerce/sales`, `/commerce/sales/{id:guid}/cancel`, `/commerce/sales/{id:guid}/returns`, `/commerce/sales/{id:guid}/stock-reviews` |
| supply | POST `/supply/purchase-orders`, `/supply/purchase-orders/{id:guid}/receipts`, `/supply/purchase-orders/{id:guid}/cancel` |

Security, Commerce y Supply usan `RequireInternalCsrf`.
Directory usa `InternalDirectoryMutationFilter.ValidateRequestAsync` (`InternalDirectoryEndpoints.cs:135–147`).
Ambos consumen el mismo `IAntiforgery`; cambiar solamente el filtro común dejaría Directory descubierto.
Los POST sintéticos externos a `/internal/api` pertenecen a otra autoridad y quedan fuera de este cambio.
Conservar sus errores respectivos: `csrf_invalid` / `invalid_csrf`.

## Especificación mínima de aceptación

**Offline, framework real.** Extender `InternalSecurityTests.TestApp:350–371` con selección de principal exclusivamente en el fixture.
Usar TestServer HTTPS, DataProtection efímero y antiforgery real; nunca mockear `IAntiforgery`.
Dos principales mediante `InternalSecurityRules.Principal`: mismo staff/NameIdentifier/login/rol/security-version, sesiones válidas distintas S1/S2.
Afirmar que sólo difiere el claim de sesión.
La autenticación es simulada; esto no prueba login SQL.

1. En S1 obtener cookie C y token T1. Una mutación con C/T1 debe alcanzar exactamente una vez el handler contador.
2. Cambiar únicamente a S2; conservar C. C/T1 debe devolver 400 sin incrementar contador. Esta aserción debe fallar antes del proveedor y pasar después.
3. Obtener T2 bajo S2 conservando C; C/T2 debe funcionar. Repetir T2 y usar dos tokens emitidos en S2: todos válidos; no imponer tokens de un uso.
4. Ejecutar controles por el filtro común y por `InternalDirectoryMutationFilter`, con actor/key válidos.
5. Probar anónimo→login con credenciales vacías: `401 invalid_credentials` demuestra admisión CSRF sin conexión SQL. Anónimo→mutación autenticada debe fallar.
6. Probar cross-user manteniendo C, sesión ausente/empty/malformada/duplicada, identidades mixtas, token antiguo sin datos adicionales, cookie ausente/incorrecta, header ausente/duplicado y HTTP. Ninguna negativa alcanza el handler.
7. Capturar respuestas y logs en memoria; no contener tokens, cookies, contraseña ni valores de claims inválidos. Verificar generación inválida además de validación.

**SQL N8, autorización separada.** Conservar controles existentes; agregar logout/relogin del MISMO cashier mediante `HttpSession`.
Confirmar mismo staff/security-version, S1 revocada, S2 distinta y válida.
Retener cookie antiforgery C y T1; usar cookie autenticada S2.
Tomar fingerprint inmediatamente antes del POST rechazado, después de terminar logout/login.
Exigir 400/`csrf_invalid` y fingerprint completo idéntico inmediatamente después: las 20 tablas, incluidas Staff, Sessions y Operations.
Usar el ADO.NET independiente existente (`:619–643`), nunca la proyección de 17 tablas.
Obtener T2; enviar el mismo cuerpo y clave original.
Exigir una Sale, SaleLine, StockMovement y Operation nuevas, actor/sucursal/cantidades/precios exactos y stock disponible −1; demás filas sin cambios.
Reenvío explícito con esa clave debe recuperar el mismo resultado sin otro efecto.
Repetir separación S1/S2 con Owner para Directory; exigir rechazo sin escrituras y creación exacta con token fresco.
Un 401 por cookie vieja o 403 por rol no sustituye la aserción CSRF con sesión nueva válida.

**Cliente.** `login.mjs:103–143` renueva después del login y antes de cada escritura.
Logout renueva antes de salir, limpia el token; prepareLogin/login obtiene después el anónimo.
`app.mjs:480–594,641–657` y `supply.mjs:75–100` conservan referencias al limpiar vistas.
No se justifica cambio frontend para same-account por la fuente.
Añadir regresión login/logout/relogin con pending sale/supply/review: bytes/key/referencias intactos, cero POST automático, respuestas/CSRF tardíos invalidados por epoch.
No incorporar session-id a idempotency keys, actorVersion o referencias.
Carrera entre renovación y cambio de sesión: rechazo seguro, pendiente conservado.

Riesgo residual inferido: otra pestaña puede cambiar de cuenta sin actualizar el epoch local; renovar CSRF no confirma identidad visual.
Reproducir separadamente antes de afirmar seguridad cross-tab entre cuentas.

## Evidencia congelada y límites

Campaña preparada y A552 fresco pertenecen a `69d3268c63019d8b8299027789962a1089f91a58`.
El diff hacia HEAD no cambia backend/UI/manifest; 11/11 bindings LF actuales coinciden.
`docs/local-validation-20261106/PARTITIONS.json`, base `0f786c3f2a747115b5cae90957b17a959f357298`, SHA256 `b95a226931107e0143dcab19cd87c4973a13d22a690f76ecd7bb211642df07ad`: A552/C77/E2, 631 casos/274 métodos; N8 pertenece a C1.
Tras implementación: nuevo SHA/build/bindings e inventario descubierto separado.
Extender N8 conserva su multiplicidad; nuevos casos offline cambian A.
No reescribir resultados ni reducir inventario para obtener verde.

Conservar HTTPS, cookies Secure/HttpOnly/Strict, roles/sucursal, revocación/security-version y revalidación transaccional (`InternalCommandRunner:67–71`).
Bootstrap permanece cerrado ante cualquier Staff (`InternalSecurityService:183–202`).
Sin criptografía, almacenamiento, esquema, paquetes o ajustes del host nuevos.

Comandos propuestos, NO ejecutados. Ejecutar la misma regresión primero sin proveedor y después con proveedor; compilar cada variante.
Seleccionar `$phase='red'` o `'green'` deliberadamente; no sobrescribir resultados ni tratar el fallo rojo esperado como aceptación.

```powershell
$sdk = 'C:/Users/Jason/MARTHA-SILVA/validation/resolution-20261028-jsdom/.sdk-10.0.402/dotnet.exe'
$phase = 'red'
& $sdk restore backend/tests/Martha.Store.Api.Tests --locked-mode
& $sdk test backend/tests/Martha.Store.Api.Tests --no-restore -c Release --filter 'FullyQualifiedName~InternalSecurityTests' --logger trx --results-directory "private-exports/session-csrf-20261107/$phase"
$env:NODE_PATH = (Resolve-Path tests/frontend-deps/node_modules).Path
node --test dev/savia-staff-ui/*.test.mjs
# Sólo con alcance SQL separado:
& $sdk test backend/tests/Martha.Store.Api.Tests --no-build --no-restore -c Release --filter 'FullyQualifiedName~InternalAcceptanceHttpSqlTests.N8_' --logger trx
```

Lección aplicada: mantener cookie y usuario constantes distingue vinculación de sesión de una rotación cosmética.

NOT RUN: builds, tests, SQL, navegador, runtime y CI.
Búsqueda opcional con wildcard literal falló `os error 123`; sin reintento ni fuente requerida faltante.
Cálculo auxiliar de bytes falló `TextEncoder is not defined`; texto retenido y contador de palabras comprobado sin ese auxiliar.
No corrección de producto intentada: está prohibida hasta adjudicación.
Pendientes: primary adjudica condiciones y registra decisión SEC-CSRF; OpenCode implementa; primary verifica rojo/verde; SQL requiere alcance propio.
Siguiente acción única: adjudicar este informe y congelar estos controles antes de delegar implementación.
