# SUPPLY-REAL-PREP: RETURNED / NOT ACCEPTED

Fuente: `b30a275ac7de4e796f34ddf5fb80ebffb3eea98c`, confirmada antes de editar.
Worktree administrado: `C:/Users/Jason/.t3/worktrees/github/t3-9fd9e2cf`.
Rama: `t3/supply-receipt-harness`. Host: `SUAZO-PC`.
Harness: T3 Code / Codex; modelo `gpt-6.1-sol`; high solicitado y efectivo expuesto por el runtime.
Coste y tokens: desconocidos. Sin agentes anidados, stage, commit, publicación o cambios canónicos.

## Candidato

El harness existente conserva sus once checkpoints de venta y recuperación.
`--mode browser --supply` añade seis checkpoints de recepción después del logout Cashier.
El Owner prepara proveedor y una compra mediante las APIs soportadas y su sesión/CSRF existentes.
Inventory recibe desde la pantalla real; no se simulan respuestas de negocio en el driver.
El archivo `supply.mjs`, ya importado por el producto, se incluye en la guarda de rutas y hashes servidos.
El workflow añade un input manual `supply_receipt`, false por defecto; no se despachó.

Fixture independiente, sin nuevas reglas comerciales:

| Estado | Stock total | Unidades recibidas | Recibos / movimientos compra | Importe recibido |
| --- | ---: | ---: | ---: | ---: |
| Tras ventas existentes, compra open | 25 | 0 | 0 / 0 | 0 |
| Parcial, 2 unidades | 27 | 2 | 1 / 1 | 1400 |
| Completa, 3 adicionales, respuesta perdida | 30 | 5 | 2 / 2 | 3500 |
| Recuperación GET y nueva recarga | 30 | 5 | 2 / 2 | 3500 |

Una línea de compra: cinco unidades del primer artículo a 700 centavos, total 3500 USD minor.
Las ventas conservan dos ventas, cuatro líneas y cuatro movimientos; tres ajustes iniciales.
El estado final tiene nueve movimientos totales y dos operaciones `supply.receipt.create`.
El driver descarta con CDP una respuesta HTTP 200 confirmada, después de leer el recibo real.
Comprueba pending íntegro tras reload y recupera con GET usando la misma clave, sin pulsar retry.
Comprueba ambos recibos en historial, pendiente eliminado y recepción deshabilitada al completar.

Los oráculos comparan cantidades, estados, importes, stock, operaciones y atribución.
Una lectura SQL parametrizada une recibo, movimiento y resultado persistido de la clave exacta.
Verifica actor Inventory, compra, ubicación, artículo, cantidad y coste; solo publica un conteo.
Las invariantes rechazan movimientos huérfanos, movimientos repetidos y desacuerdo recibo/compra.
Se conservan migrador, nombre de base, propiedad de cleanup, perfil Chrome, saneador y manifiesto de publicación existentes.

## Evidencia actual sin SQL

| Comando | Resultado |
| --- | --- |
| `python tests/test_golden_path_safety.py` | exit 0; 17/17 |
| `python tests/test_golden_path_browser_safety.py` | exit 0; 23/23 |
| `python -m py_compile tests/golden-path/golden_path.py tests/golden-path/verify_evidence.py` | exit 0 |
| `node --check tests/golden-path/browser_path.mjs` | exit 0 |
| `git diff --check` | exit 0 |
| PyYAML BaseLoader sobre `.github/workflows/golden-path.yml`; assertions input false y wiring `--supply` | exit 0 |
| `dotnet --list-sdks` | exit 0; solo `8.0.422` |

Python `3.11.9`; Node `v24.18.0`.
Los dobles validan el protocolo completo, el ACK después del oráculo y rechazos de estado obsoleto,
recibo/movimiento duplicado, repost, actor/ubicación/compra incorrectos e identidad pending discordante.
**Estos controles no prueban persistencia ni ejecución real de navegador, API o SQL.**

Incidente corregido: el primer compile encontró `SyntaxError: unmatched ')'` en el filtro de rutas.
Se retiró el paréntesis sobrante; compile y suites posteriores dieron exit 0.
Lección aplicada: verificar primero la sintaxis del protocolo antes de ejercer sus controles.

## Pendientes y cierre

| Bloqueo / límite | Evidencia y corrección | Dueño / acción / prueba de cierre |
| --- | --- | --- |
| Compilación C# NOT RUN | `global.json` exige `10.0.402`, no instalado. No se intentó instalar ni cambiar versión. | Primary: compilar en entorno aprobado con ese SDK; restore locked y build Release exit 0. |
| Browser→API→SQL NOT RUN | Prohibido por el packet. La autorización anterior está consumida; no se intentó conexión, Docker ni certificados. | Jason autoriza una corrida exacta; primary ejecuta y verifica evidencia y cleanup del nuevo SHA. |
| Revisión NOT RUN | Candidato devuelto sin aceptación independiente. | Primary inspecciona/importa; Gemini 4 Argon/high critica y GPT-6 Astra/high juzga los bytes congelados. |

Histórico separado: run `42163110947`, SHA `708bdbbf2eff568d571b7593ed40d2422414c671`,
602/602 backend aceptado según `docs/sql-ci-20261106/README.md` leído en esta tarea.
No es prueba de esta recepción combinada. No se consultó GitHub en esta tarea.

## Corrida futura: NO EJECUTADA

Tras aprobación independiente y autorización nueva de Jason, usar el SHA integrado exacto en Linux,
el SDK fijado, Chrome/Playwright fijados y el SQL desechable del workflow existente.
No reutilizar una base del piloto ni suministrar credenciales en argumentos o evidencia.
El input manual `supply_receipt=true` añade `--supply` al C6 existente.
Comandos previstos dentro del entorno autorizado y ya preparado:

```bash
dotnet restore tests/golden-path/GoldenPath.Sql --locked-mode
dotnet build tests/golden-path/GoldenPath.Sql --no-restore --configuration Release
python3 tests/golden-path/golden_path.py --mode browser --supply --no-build \
  --playwright-directory "$RUNNER_TEMP/c6-playwright/node_modules/playwright" \
  --out "$RUNNER_TEMP/c6-evidence" < /dev/null
python3 tests/golden-path/verify_evidence.py --source "$RUNNER_TEMP/c6-evidence" \
  --destination "$RUNNER_TEMP/c6-approved"
```

Prueba de cierre: exit 0; `supply_journey=true`; los once checkpoints de venta y seis de supply PASS;
oráculos exactos de la tabla; cuatro lecturas de identidad SQL con un match;
dos POST de recibo y GET de recuperación con la clave perdida; cero fallos del oráculo;
SHA/hash servido y binario vinculados; evidencia saneada y manifiesto exacto;
base propia eliminada, API/Chrome detenidos, perfiles privados eliminados y contenedor ausente con readback.
El primary debe leer las filas y la salida real de cleanup del mismo run, no solo su conclusión verde.
No acredita C2/C9/C10, TLS productivo, pagos, carga ni aceptación de negocio.

`RESULT.json` contiene fuentes y hashes RAW SHA256 del candidato; se excluye a sí mismo para evitar recursión.
