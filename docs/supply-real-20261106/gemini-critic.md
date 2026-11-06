# Revisión Crítica Independiente: SUPPLY-REAL-PREP (`65ab1d9`)

**Verdict: ACCEPT WITH LIMITS**

Rol: Crítico independiente (`Gemini critic only`). Este informe es consultivo (`RETURNED`), no constituye aceptación del primary ni aprobación de producto o producción.

## 1. Identidad, Entorno y Límites

- **Task ID**: `savia-supply-real-critic-65ab1d9-20261106` (`mode: VALIDATE`).
- **Worktree**: `C:/Users/Jason/.t3/worktrees/github/t3-5e28772e` (`## t3/review-supply-receipt`).
- **HEAD verificado**: `65ab1d942a4666321e489da1cccd6341a0f671b7` (base `b30a275ac7de4e796f34ddf5fb80ebffb3eea98c`).
- **Host / Harness / Modelo**: Windows (`SUAZO-PC`) / T3 Code (`antigravity-acp`) / `gemini-4-argon`.
- **Ajustes solicitados vs. efectivos**: `thinking_level: high` solicitado; el wrapper local expone `EFFORT LEVEL: 0.20`. El esfuerzo interno efectivo del proveedor, tokens, costo y `gemini_argon_weekly` son `unknown` (no expuestos).
- **Políticas globales (`C:/Users/Jason/AI-OS/rules/*`)**: Lectura bloqueada por el pre-tool hook (`Access to path "C:/Users/Jason/AI-OS/rules/orchestration.md" is denied. It is outside the allowed workspace directories...`, igual para `PROTOCOL.md` y `OUTPUT.md`). Se respetó el límite sin evasión y se aplicaron [AGENTS.md](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/AGENTS.md), [docs/AGENT-START.md](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/docs/AGENT-START.md) y [docs/DATABASE.md](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/docs/DATABASE.md).

## 2. Verificación de los 21 Bindings y Blobs Git (Check 1)

Se contrastaron los 21 bindings de [CANDIDATE.json](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/docs/supply-real-20261106/CANDIDATE.json) contra el disco actual, `HEAD`, la base `b30a275`, [IMPORT.json](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/docs/supply-real-20261106/IMPORT.json) y [RESULT.json](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/docs/supply-real-20261106/RESULT.json).

- **21/21 `lfSha256`**: Coinciden exactamente entre disco (`CRLF -> LF` preservando BOM), `git show HEAD:<path>` y `CANDIDATE.json`.
- **13/13 `contract`**: Idénticos en LF a la base `b30a275`. Cero cambios en producto, API, UI o `global.json`.
- **7/7 archivos importados del worker (`changed` + `RESULT.json`)**: Intactos respecto a `IMPORT.json` y `RESULT.json`.
- **1/1 `primary-ci-wiring`**: [.github/workflows/staff-ui-candidate.yml](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/.github/workflows/staff-ui-candidate.yml) contiene únicamente el cableado CI sin SQL del primary.
- **Diferencias RAW de checkout (solo saltos de línea, sin cambio de contenido)**:
  - [dev/savia-staff-ui/supply.mjs](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/dev/savia-staff-ui/supply.mjs) (con UTF-8 BOM `efbbbf`): en disco tiene CRLF (`28a2eeb8...`, igual a `workerRawSha256` en `IMPORT.json`), mientras `CANDIDATE.json` registra `1695273b...`. Su `lfSha256` (`2beb1f82...`) es idéntico en disco, `HEAD`, `IMPORT.json` y `CANDIDATE.json`.
  - [docs/supply-real-20261106/README.md](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/docs/supply-real-20261106/README.md): escrito en LF (`d6344868...`); en este worktree Windows tiene CRLF (`94f67d33...`), con `lfSha256` idéntico (`d6344868...`).

| # | Ruta | Rol | `lfSha256` verificado | vs. Base `b30a275` |
| :- | :--- | :--- | :--- | :--- |
| 1 | `.github/workflows/golden-path.yml` | `changed` | `15e23e84284f0227c35074bee6dee0f17bba5b1f675d1e40373098cc37afad82` | Worker |
| 2 | `backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs` | `contract` | `83889bcab5bbe88cef341e5ed125206c00956a87fa03fd57d80f7c37e3b3f1a5` | Intacto |
| 3 | `backend/src/Martha.Store.Api/Internal/Supply/InternalSupplyDbContext.cs` | `contract` | `57e4fdeb43a4dba44c14fa667dfedee5b2e078949537c2bee6b3c96dddfa23fd` | Intacto |
| 4 | `backend/src/Martha.Store.Api/Internal/Supply/InternalSupplyEndpoints.cs` | `contract` | `c7707b5c937a3475236e02bb4c67b9d29e23fa986eb8f0b29c016ba13646eb61` | Intacto |
| 5 | `backend/src/Martha.Store.Api/Internal/Supply/InternalSupplyModels.cs` | `contract` | `072545d4aac6cc9fb310dbf6bbe8aa1318007d29a4c300518179fa44d26624c9` | Intacto |
| 6 | `backend/src/Martha.Store.Api/Internal/Supply/InternalSupplyService.cs` | `contract` | `42294e790dcf444ceab1e209eaade68a3610a2400d5d71119c1b0fbafb786adf` | Intacto |
| 7 | `dev/savia-staff-ui/app.mjs` | `contract` | `7901d54f7ea18b09e6f50dfc8f7596a135ec3a951bd732e1a3435cb7d1185083` | Intacto |
| 8 | `dev/savia-staff-ui/client.mjs` | `contract` | `cdf34879fdd5e78d8141c23533de2d07155bb7451bcd7582b41e553cd71e2639` | Intacto |
| 9 | `dev/savia-staff-ui/index.html` | `contract` | `234fa005e324a0cd20bd43936450b68b9d08d1152b4714db871e425577c6a859` | Intacto |
| 10 | `dev/savia-staff-ui/login.mjs` | `contract` | `5d2bd800a550501c020a300b39d87c85c9abf06379609942e02bc39beb580297` | Intacto |
| 11 | `dev/savia-staff-ui/supply.mjs` | `contract` | `2beb1f821afcbfe773968d00a9534158ca8ef4b5f124427377288be01182b71a` | Intacto (BOM) |
| 12 | `docs/supply-real-20261106/README.md` | `changed` | `d6344868fbabdba64837bffd43b1d7f450edfb35c91d743b42ec06dfc56ec436` | Worker |
| 13 | `global.json` | `contract` | `3f9b8063fdc946bf82db965d9a228d4ea581390f83680ee3b952fb0ec00b2cf3` | Intacto |
| 14 | `tests/golden-path/GoldenPath.Sql/Program.cs` | `changed` | `3bb8e1c89ae2456b9ae06397272c99f37a9261598c9889b6bb87d3db90f4842c` | Worker |
| 15 | `tests/golden-path/README.md` | `changed` | `02fe87b5d812a4d202ba715c08919ba43c51c951be94ae0bd18c9bde9addbbc6` | Worker |
| 16 | `tests/golden-path/browser_path.mjs` | `changed` | `2ed74f02c5f821c6a3574ae21d6b627cab4e8791df5e04aeaf087a540f99c8d5` | Worker |
| 17 | `tests/golden-path/golden_path.py` | `changed` | `5d203118448f9b0c40e72bef9ef20194746bb20be520a6d7fed35227fd7f9859` | Worker |
| 18 | `tests/golden-path/verify_evidence.py` | `contract` | `cf494c86fe22cbbd7e8ad3e7ffabc97d55cafbb1e1afb90e19efa2656ce6c5ff` | Intacto |
| 19 | `tests/test_golden_path_browser_safety.py` | `changed` | `ce82e38e239697ee35226bacb1cc4217b1a113dabaaccd2a8659c8e8ede4284e` | Worker |
| 20 | `tests/test_golden_path_safety.py` | `contract` | `06e11db0a2c1f0acea63b6f0c1bae0e751a56a8df057ac5ea6c536a0d856dd1e` | Intacto |
| 21 | `.github/workflows/staff-ui-candidate.yml` | `primary-ci-wiring` | `7676d1225e59af05a8008d08244bdda5ad1233030a3e3cd1864d18ee028a75ff` | Primary |

## 3. Hallazgos Concretos

No existen fallos `HIGH` o `CRITICAL` que generen falsos positivos, debiliten la sanitización o comprometan el teardown. Se registran **1 hallazgo `MEDIUM`** y **3 hallazgos `LOW`**.

### F1 — `MEDIUM`: Los 14 códigos de error `c6_supply_*` de `browser_path.mjs` no están en `allowed_errors` de `golden_path.py`

- **Líneas exactas**: [tests/golden-path/browser_path.mjs](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/tests/golden-path/browser_path.mjs#L314-L417) y [tests/golden-path/golden_path.py](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/tests/golden-path/golden_path.py#L1046-L1057).
- **Ruta de fallo**: Cuando falla cualquier `check(..., 'c6_supply_*')` en `browser_path.mjs`, el bloque `catch` (línea 416) valida `/^c6_[a-z_]{1,80}$/` y emite `{"error": "c6_supply_..."}`. En `golden_path.py`, `receive()` filtra `event['error']` contra `allowed_errors` (líneas 1046–1054), que no incluye ningún `c6_supply_*`. El código específico se sobrescribe por `'browser_protocol_invalid'`, ocultando la causa exacta del fallo de recepción en el navegador.
- **Dueño**: Primary.
- **Corrección mínima**: Añadir los 14 códigos (`c6_supply_identity_invalid`, `c6_supply_request_invalid`, `c6_supply_partial_http`, `c6_supply_partial_invalid`, `c6_supply_pending_not_cleared`, `c6_supply_loss_requires_commit`, `c6_supply_complete_invalid`, `c6_supply_loss_request_missing`, `c6_supply_loss_failed`, `c6_supply_pending_identity_invalid`, `c6_supply_pending_changed`, `c6_supply_recovery_invalid`, `c6_supply_reload_invalid`, `c6_supply_logout_invalid`) a `allowed_errors` en `golden_path.py`.
- **Comprobación de cierre**: Caso en `tests/test_golden_path_browser_safety.py` verificando que `{"error": "c6_supply_partial_invalid"}` propaga `c6_supply_partial_invalid`.

### F2 — `LOW`: Caracteres UTF-8 sustituidos por `?` en `tests/golden-path/README.md`

- **Líneas exactas**: [tests/golden-path/README.md](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/tests/golden-path/README.md#L165-L169).
- **Ruta de fallo**: La sección final contiene `?` ASCII (`0x3f`) en `Recepci?n`, `a?ade`, `p?rdida`, `recuperaci?n` y `autorizaci?n`.
- **Dueño**: Primary.
- **Corrección mínima**: Restaurar las tildes y la `ñ` en esas cinco palabras.
- **Comprobación de cierre**: `git diff` limpio con UTF-8 válido.

### F3 — `LOW`: `ReceiptIdentity` en `GoldenPath.Sql/Program.cs` omite `m.ReservedDelta = 0` y `l.PurchaseOrderId = @order` directos y el texto de ayuda `usage`

- **Líneas exactas**: [tests/golden-path/GoldenPath.Sql/Program.cs](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/tests/golden-path/GoldenPath.Sql/Program.cs#L25) y [Program.cs](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/tests/golden-path/GoldenPath.Sql/Program.cs#L240-L253).
- **Ruta de fallo**: No causa falso positivo porque inmediatamente después se ejecuta `Oracles(db)` verificando `receipt_movement_mismatch` (`m.ReservedDelta = 0`) y `purchase_partial` / `purchase_complete` (`o.Status`). Sin embargo, endurecer la consulta individual y el string `usage` en la línea 25 mantiene el helper autocontenido.
- **Dueño**: Primary (opcional).
- **Corrección mínima**: Añadir `AND m.ReservedDelta=0 AND l.PurchaseOrderId=@order AND o.Status=r.OrderStatusAfter` en `ReceiptIdentity` y documentar `receipt-identity` en `usage`.
- **Comprobación de cierre**: `dotnet build tests/golden-path/GoldenPath.Sql --no-restore -c Release` exit 0.

### F4 — `LOW`: `TABLE_COLUMNS` en `golden_path.py` no incluye columnas de compra en `oracles.md`

- **Líneas exactas**: [tests/golden-path/golden_path.py](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/tests/golden-path/golden_path.py#L51-L54).
- **Detalle**: `evidence.json` persiste todos los contadores `purchase_*` y `receipt_*` por paso, pero la tabla markdown `oracles.md` solo muestra `movements` (7 -> 8 -> 9) y `on_hand_total` (25 -> 27 -> 30). No afecta la validez de las aserciones SQL.
- **Dueño**: Primary (no requiere edición obligatoria).

## 4. Evaluación de los Criterios Congelados (Checks 2 a 7)

- **Check 2 (Contratos API, DOM y aritmética)**:
  - `owner.seed_purchase` ([golden_path.py:734-749](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/tests/golden-path/golden_path.py#L734-L749)): `POST /internal/api/directory/parties` devuelve `201` ([InternalDirectoryEndpoints.cs:43](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryEndpoints.cs#L43)); `POST /internal/api/supply/purchase-orders` (5 u. del artículo 1 a 700 centavos) devuelve `200` con `status: 'open'` y `totalMinor: 3500` ([InternalSupplyEndpoints.cs:27](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/backend/src/Martha.Store.Api/Internal/Supply/InternalSupplyEndpoints.cs#L27)).
  - Tras las dos ventas multiartículo existentes (3 u. y 2 u., dejando `on_hand_total = 25`, `sales = 2`, `sale_lines = 4`, `sale_movements = 4`, `movements = 7`), los 6 pasos `browser.supply_*` verifican: recepción parcial de 2 u. (`stock = 27`, `received = 2`, `receipts = 1`, `total = 1400`, `movements = 8`) y recepción final de 3 u. (`stock = 30`, `received = 5`, `receipts = 2`, `total acumulado = 3500`, `movements = 9`).
  - Los selectores `[data-order-id]`, `[data-line-id]`, `#supply-detail`, `#supply-submit`, `#supply-recover`, `#supply-result` y `#supply-receipts` coinciden con [index.html](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/dev/savia-staff-ui/index.html#L97-L110) y [supply.mjs](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/dev/savia-staff-ui/supply.mjs#L70-L94).
- **Check 3 (SQL exact identity e invariantes)**:
  - `Oracles` ([Program.cs:164-186](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/tests/golden-path/GoldenPath.Sql/Program.cs#L164-L186)) añade 14 conteos de compras/recibos y 3 invariantes en `ALWAYS_ZERO`: `receipt_movement_mismatch`, `orphan_receipt_movement` y `receipt_order_mismatch`.
  - `ReceiptIdentity` ([Program.cs:235-259](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/tests/golden-path/GoldenPath.Sql/Program.cs#L235-L259)) une `PurchaseReceipts`, `PurchaseReceiptLines`, `StockMovements`, `PurchaseOrders` y `Operations` (`Scope = 'supply.receipt.create'`, `[Key] = @key`, `JSON_VALUE(op.ResultJson, '$.success') = 'true'`, `JSON_VALUE(op.ResultJson, '$.value.id') = CONVERT(nvarchar(36), r.Id)`), coincidiendo con la serialización camelCase de `InternalCommandRunner` ([InternalCommandRunner.cs:44,112](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs#L44)). La compilación local no ejecutó SQL.
- **Check 4 (Intercepción CDP HTTP 200 y recuperación GET)**:
  - `Fetch.enable` ([browser_path.mjs:372](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/tests/golden-path/browser_path.mjs#L372)) filtra `${origin.origin}${receiptPath}` en `requestStage: 'Response'`. No intercepta el `GET /internal/api/security/csrf` previo; pausa el `POST .../receipts` tras recibir HTTP `200`, lee el recibo real (`totalMinor === 2100`, `orderStatusAfter === 'received'`, nueva identidad y clave), marca `response_lost = true` y descarta la respuesta con `Fetch.failRequest`.
  - Tras recargar la página, `savia.supply.pending.v1` permanece idéntico en `sessionStorage`, `#supply-recover` ejecuta `GET /internal/api/operations/supply.receipt.create` con la clave original, sin nuevo POST (`receiptPosts === 2`), limpia el pendiente y muestra ambos recibos en `#supply-receipts`.
- **Check 5 (Privacidad, sanitización y cleanup)**:
  - Intactos el protocolo de lista blanca en `browser_checkpoint`, el staging privado `0700`, `scan_for_secrets`, `verify_evidence.py`, el readback de procesos Chrome/Node por `/proc` y la guarda de propiedad antes de `DROP DATABASE`. Cero filas SQL, secretos o binarios en el commit.
- **Check 6 (Workflows CI)**:
  - [.github/workflows/golden-path.yml](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/.github/workflows/golden-path.yml#L11-L16) define `supply_receipt: default: false` solo en `workflow_dispatch`, sin trigger en `Tony`.
  - [.github/workflows/staff-ui-candidate.yml](file:///C:/Users/Jason/.t3/worktrees/github/t3-5e28772e/.github/workflows/staff-ui-candidate.yml#L12-L46) ejecuta las dos suites Python de seguridad, `node --check` y `dotnet restore/build` de `GoldenPath.Sql` sin iniciar SQL ni API.
- **Check 7 (Separación documental)**:
  - La documentación distingue el retorno histórico del worker (`README.md`, `RESULT.json`), la compilación del primary con el SDK portable `10.0.402` existente (`primary-review.md`, `primary-checks.json`), los controles con dobles sin SQL, el CI en curso y el estado `NOT RUN` del recorrido real.

## 5. Comandos Ejecutados y NOT RUN

- **Comandos ejecutados (todos `exit 0`, solo lectura)**:
  1. `git rev-parse HEAD; git status --short --branch`
  2. `python -` (verificación SHA-256 RAW/LF de los 21 bindings contra disco, `HEAD`, base `b30a275`, `IMPORT.json` y `RESULT.json`)
  3. `python -` (inspección de BOM y CRLF/LF en `supply.mjs` y `docs/supply-real-20261106/README.md`)
  4. `git diff b30a275ac7de4e796f34ddf5fb80ebffb3eea98c..HEAD -- tests/golden-path/README.md`
  5. `git diff --name-status b30a275ac7de4e796f34ddf5fb80ebffb3eea98c..HEAD`
  6. `git ls-files backend/src/Martha.Store.Api/Internal/`
  7. `python -` (conteo de palabras, SHA-256 y `git status` del informe escrito)
- **NOT RUN**: Ejecución de SQL Server, Docker, API, Chrome/Playwright, `golden_path.py`, despacho de workflows o re-ejecución de suites locales.

## 6. Siguiente Acción

Primary corrige **F1** (`allowed_errors` en `golden_path.py`) y **F2** (tildes UTF-8 en `tests/golden-path/README.md`), y transfiere el candidato congelado a adjudicación del juez (`GPT-6 Astra/high`) antes de solicitar autorización de runtime a Jason.
