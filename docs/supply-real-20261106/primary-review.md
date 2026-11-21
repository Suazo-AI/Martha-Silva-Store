# Recepción real: revisión primaria de la preparación

**Candidato congelado para revisión; aceptación final pendiente. Recorrido combinado NOT RUN.**

Base: `b30a275ac7de4e796f34ddf5fb80ebffb3eea98c`. Host: `SUAZO-PC`.
Primary: T3 Code / Codex, `gpt-6.1-sol`, esfuerzo `xhigh`.
Worker: Codex `gpt-6.1-sol/high`; worktree `t3-9fd9e2cf`.
Coste y tokens no expuestos. Este informe no convierte una devolución en aceptación independiente.

## Resultado verificado

El primary contrastó los 20 archivos del manifiesto contra los bytes del worker y la base Git.
Los 20 hashes RAW coinciden con el worker; los contratos canónicos coinciden tras normalizar solo CRLF a LF.
La importación contiene los seis archivos cambiados y los dos documentos devueltos, sin edición de esos originales.
`IMPORT.json` conserva la lista permitida, origen y hashes. `CANDIDATE.json` fija los bytes para revisión.
La única ampliación primaria de código es el cableado de comprobaciones en el workflow sin SQL existente.
No se cambiaron fuentes del producto, permisos, contratos HTTP, migraciones ni políticas de seguridad.

| Comprobación primaria | Resultado |
| --- | --- |
| `python tests/test_golden_path_safety.py` | 17/17, exit 0 |
| `python tests/test_golden_path_browser_safety.py` | 23/23, exit 0 |
| `python -m py_compile tests/golden-path/golden_path.py tests/golden-path/verify_evidence.py` | exit 0 |
| `node --check tests/golden-path/browser_path.mjs` | exit 0 |
| `dotnet restore tests/golden-path/GoldenPath.Sql --locked-mode` con SDK portable 10.0.402 | exit 0 |
| `dotnet build tests/golden-path/GoldenPath.Sql --no-restore --configuration Release` con ese SDK | exit 0, 0 errores, 0 advertencias |
| PyYAML BaseLoader sobre los dos workflows y assertions de activación | exit 0 |
| `git diff --check` sobre el candidato importado | exit 0 |
| `python tests/test_progress.py` | 23/23, exit 0 |
| `python tools/export_progress.py --verify` | exit 0; 15 hashes preservados |

`primary-checks.json` registra comandos, códigos de salida y hashes de logs privados.
El YAML comprueba `supply_receipt=false`, activación exclusiva manual con ese input y ausencia de trigger SQL en Tony.
Comprueba también las rutas de activación, ambos controles Python y compilación en `staff-ui-candidate.yml`.
Ese workflow conserva solo pruebas sin SQL y HTTP simulado; no invoca el recorrido real.
El resultado remoto del nuevo SHA no se infiere de estas comprobaciones locales.

## Qué se revisó directamente

El recorrido conserva once checkpoints de venta y añade seis para recepción y logout de Inventory.
El fixture compra cinco unidades a 700 centavos. Recibe dos y después tres.
El stock esperado pasa de 25 a 27 y después 30; dos recibos suman 3500 centavos.
Los dos POST tienen identidades distintas. La recuperación GET conserva la identidad del segundo recibo y su clave.
La respuesta descartada debe ser un HTTP 200 real cuyo contenido ya fue inspeccionado por el driver.
Recuperación y reload no pueden añadir POST, recibos ni movimientos.
El conteo SQL une recibo, compra, línea, movimiento, actor y resultado persistido de la clave exacta.
Las nuevas invariantes rechazan movimientos duplicados o huérfanos y cantidades recibidas discordantes.
Los controles sin SQL rechazan identidades y atribuciones incorrectas, repost y cuentas adulteradas.
El protocolo no confirma un checkpoint al navegador hasta verificar su oráculo.
Persisten límites de rutas, hashes servidos, saneamiento, propiedad de procesos/base y cleanup existentes.
Estas observaciones son inspección y comprobación del arnés; no resultados del recorrido real.

## Bloqueos y correcciones

| Ítem | Evidencia, causa y corrección | Dueño y comprobación de cierre |
| --- | --- | --- |
| SDK reportado ausente: resuelto | El worker consultó el PATH y encontró 8.0.422. El SDK 10.0.402 ya estaba en `C:/Users/Jason/.dotnet-sdk-10.0.402/dotnet.exe`. El primary comprobó versión y ejecutó restore/build con ruta absoluta, ambos exit 0. No instaló ni cambió configuración global. | Primary: cerrado para compilación del helper y API. La afirmación histórica en README/RESULT del worker permanece identificada como superada. |
| Controles fuera del CI sin SQL: corregido, resultado remoto pendiente | El workflow real ya los invoca, pero no corre automáticamente en Tony. El primary añadió paths, controles y build a `staff-ui-candidate.yml`; parseo y assertions pasan. | Primary: verificar el run del SHA publicado y conservar sus conteos exactos. No iniciar SQL para resolverlo. |
| Recorrido real: NOT RUN | La autorización aislada anterior se consumió en run 42163110947 sobre 708bdbb. No se intentó otra conexión ni runtime. | Jason autoriza el candidato revisado; primary comprueba 17 checkpoints, cuatro identidades SQL, saneamiento y cleanup del mismo run. No ejecutar antes. |
| Crítico y juez: pendientes | El candidato era mutable; ahora fuentes y evidencia están congeladas en un mismo commit accesible al reviewer. | Primary delega Gemini 4 Argon/high y después GPT-6 Astra/high. Resolver hallazgos y verificar fuentes exactas antes de aceptar. |
| Agregado Windows: límite conocido | El fixture de symlinks requiere un privilegio que este host no tiene (`WinError 1314`). No se repitió el mismo fallo. | Primary verifica el agregado Linux automático del nuevo SHA; no modifica permisos locales. |

El build generado no se publica. Solo se registran hashes de sus binarios para enlazar esta compilación.
Los logs privados no contienen resultados SQL y no se incorporan al repositorio público.
Los originales devueltos conservan su procedencia; el recibo portátil usa LF explícito.

Lección aplicada: antes de declarar una dependencia ausente, consultar instalaciones autorizadas conocidas además del PATH.
La ruta portable resolvió el bloqueo con una compilación real, sin instalación ni excepción de seguridad.

## Siguiente acción

Publicar el candidato en Tony mediante hooks; verificar SHA remoto y CI sin SQL.
Delegar el crítico sobre ese commit congelado. El juez evaluará después los hallazgos materiales.
No ejecutar `golden-path.yml`, SQL, Docker, API, certificados, merge ni despliegue durante esta preparación.
No cierra C2/C9/C10, tarjetas, operación ni producción.
