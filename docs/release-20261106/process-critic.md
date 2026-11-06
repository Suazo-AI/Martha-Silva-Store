# SAVIA y Tienda Pública: Crítica de Proceso y Plan de Cierre

**Veredicto sobre [`completion-audit.md`](../release-20261106/completion-audit.md): REVISE. Producción: NO-GO.**

El inventario primario respeta los límites técnicos, pero su plan prolonga la entrega con ceremonia documental, estados obsoletos y dependencias mal bloqueadas. El avance se frenó por manifiestos masivos de hashes, corridas CI fragmentadas y postergar la única función pendiente para el ensayo (`D-026`/`D-027`).

## 1. Identidad, fuente y límites

- **Tarea:** `savia-process-critic-8e38d98-20261106-01` (`VALIDATE`).
- **Crítico:** Antigravity `gemini-4-argon` en `C:/Users/Jason/.t3/worktrees/github/t3-0d8dc0fc`.
- **Ajustes y consumo:** solicitado `thinking_level: high`; arnés `EFFORT LEVEL: 0.20`; ajuste efectivo del proveedor y tokens/costo: **unknown**.
- **Fuente verificada:** `HEAD` `8e38d98dca394d0730ddd830ecd55bc834dbf366` (`git status --short` limpio al inicio).
- **Límites:** cero runtime, SQL, Docker, navegador, red o polling. Run Linux `42173233401` sigue `in_progress` al último corte; no se inventa su resultado.

## 2. Hallazgos materiales sobre [`completion-audit.md`](../release-20261106/completion-audit.md)

1. **M1 (ALTO) — Falso bloqueo del Ensayo Sintético (`C10`) por `C2` y `C9`.**
   - **Evidencia:** [`completion-audit.md:51`](../release-20261106/completion-audit.md#L51) ata el día sintético a `C2`, y [`ledger.json:284-289`](../pipeline/ledger.json#L284-L289) bloquea `C10` con `C1,C2,C6,C9`. Pero `D-022`/`D-025` ([`DECISIONS.md:60-72,110-120`](../DECISIONS.md#L60-L72)) fijaron que `SUAZO-PC` acepta el ensayo con datos sintéticos, y `D-026`/`D-027` ([`DECISIONS.md:136-180`](../DECISIONS.md#L136-L180)) definieron su regla de excepción.
   - **Corrección:** Desacoplar `C10` de `C2` (Martha) y `C9` (TLS local). `C2` y `C9` bloquean `P-GO` (producción), no el ensayo sintético.

2. **M2 (ALTO) — `P-LEGACY` figura `done` en [`ledger.json:441-457`](../pipeline/ledger.json#L441-L457) pero oculta 5 regresiones DOM y bloquea `P-GO`.**
   - **Evidencia:** [`CLASSIFICATION.md:5`](../p-legacy-20261104/CLASSIFICATION.md#L5) documenta 5 regresiones DOM (`DG01,DG03,DG04,DG06,DG10`), 9 obsoletas y 5 de geometría jsdom en la tienda (`tests/desktop-gallery.cjs`, `green-header.cjs`, `luxury-editorial.cjs`). `P-GO` ([`ledger.json:480-487`](../pipeline/ledger.json#L480-L487)) depende de `P-LEGACY` asumiendo pruebas corregidas.
   - **Corrección:** Abrir un ítem en el carril `store` para corregir las 19 aserciones y desvincularlo de `P-GO`.

3. **M3 (MEDIO) — Diez ítems administrativos inflan el trabajo pendiente.**
   - **Evidencia:** Los 7 `TONY-*` ([`ledger.json:569-673`](../pipeline/ledger.json#L569-L673)) ya están en código ([`tools/delivery_status.py`](../../tools/delivery_status.py), [`progress-digest.yml`](../../.github/workflows/progress-digest.yml), [`golden-path.yml`](../../.github/workflows/golden-path.yml)) y pasaron CI en `260b759` ([`fix-pr2-denis-20261104/README.md:141-173`](../fix-pr2-denis-20261104/README.md#L141-L173)).
   - **Corrección:** Pasar los 7 `TONY-*` a `done` hoy; diferir `API-BRANCH` y `PIPE-AI`.

4. **M4 (BAJO) — `D-030` ausente en [`DECISIONS.md`](../DECISIONS.md) y `done_when` de `C1` desalineado.**
   - **Evidencia:** [`completion-audit.md:22`](../release-20261106/completion-audit.md#L22) cita `D-030`, pero `DECISIONS.md` termina en `D-029`. En [`ledger.json:106-119`](../pipeline/ledger.json#L106-L119), `C1.done_when` solo pide protección de `main` (cumplida), mientras `why`/`prep` exigen `D-026`/`D-027`.
   - **Corrección:** Registrar `D-030` en `DECISIONS.md` y separar `C1` (merge `done` vs stock `todo`).

## 3. Reconciliación de los 20 ítems no-`done` del ledger y las 24 filas del primary

| ID Ledger (Estado) | Clasificación | Evidencia directa y contraste con las 24 filas de `completion-audit.md` |
| --- | --- | --- |
| `C1` (`todo`) | **Stale status** + **Missing implementation** | Protección `main` lista ([`ledger.json:119`](../pipeline/ledger.json#L119)). Falta D-026/D-027 ([`InternalStockLedger.cs:34-41`](../../backend/src/Martha.Store.Api/Internal/Commerce/InternalStockLedger.cs#L34-L41)). Fila 3 y l.72. |
| `C2` (`todo`) | **External fact-or-decision** | [`GUION-RECONSTRUCCION-MARTHA.md`](../sprint-20261104/GUION-RECONSTRUCCION-MARTHA.md); entrevista pendiente ([`DECISIONS.md:230`](../DECISIONS.md#L230)). Filas 4, 5, 19: sobreestimado para ensayo sintético. |
| `C9` (`blocked`) | **External fact** + **Missing verification** | Fallo TLS en [`PREFLIGHT-RESULT.md`](../c9-recovery-20261103/PREFLIGHT-RESULT.md). Restore Linux pasó en `708bdbb` ([`sql-ci-20261106/README.md:6-8`](../sql-ci-20261106/README.md#L6-L8)). Filas 6 y 7. |
| `C10` (`blocked`) | **Missing verification** (depende de `C1`, no `C2`/`C9`) | Guion listo; 0/5 tareas y 0/30 mediciones ([`ledger.json:292-300`](../pipeline/ledger.json#L292-L300)). Fila 12. |
| `C12` (`blocked`) | **Missing verification** + **External decision** | `main` en `3b004916` ([`DECISIONS.md:198`](../DECISIONS.md#L198)). Fila 13 mezcla `C12` con `P-GO`. |
| `SEC-CSRF` (`todo`) | **External decision** / **Optional** en ensayo | [`InternalSecurity.cs:51-60`](../../backend/src/Martha.Store.Api/Internal/Security/InternalSecurity.cs#L51-L60) liga CSRF al usuario; [`InternalSecurityService.cs:41`](../../backend/src/Martha.Store.Api/Internal/Security/InternalSecurityService.cs#L41) revoca sesión previa. Fila 20. |
| `API-BRANCH` (`todo`) | **Optional** (`D-014` = 1 sucursal) | Sin endpoint sucursal en [`InternalDirectoryEndpoints.cs:19-41`](../../backend/src/Martha.Store.Api/Internal/Directory/InternalDirectoryEndpoints.cs#L19-L41); validación en [`InternalSecurityService.cs:136-139`](../../backend/src/Martha.Store.Api/Internal/Security/InternalSecurityService.cs#L136-L139). Fila 21 (`P2`). |
| `P-HOST` (`todo`) | **External fact-or-decision** | [`ledger.json:392-406`](../pipeline/ledger.json#L392-L406); `D-025` es solo ensayo. Fila 8 (`P1`). |
| `P-SEC` (`blocked`) | **External fact** + **Missing verification** | [`ledger.json:408-422`](../pipeline/ledger.json#L408-L422); depende de `P-HOST`. Fila 9 (`P1`). |
| `P-OPS` (`blocked`) | **Missing verification** | [`ledger.json:424-439`](../pipeline/ledger.json#L424-L439); depende de `P-HOST` y `C9`. Fila 10 (`P1`). |
| `P-OWNER` (`todo`) | **External decision** + **Missing verification** | [`InternalSecurityService.cs:98-100`](../../backend/src/Martha.Store.Api/Internal/Security/InternalSecurityService.cs#L98-L100) protege último Owner; [`InternalOwnerConsole.cs:122-125`](../../backend/src/Martha.Store.Api/Internal/Security/InternalOwnerConsole.cs#L122-L125) cierra bootstrap. Fila 11 (`P1`). |
| `P-GO` (`blocked`) | **External decision** + **Missing verification** | [`ledger.json:475-495`](../pipeline/ledger.json#L475-L495). Fila 13 (`P1`). |
| `S-PAY` (`todo`) | **External decision** + **Missing implementation** | [`src/app.js:445`](../../src/app.js#L445) simula pago (`data-test-payment`). Fila 14 (`P1`). |
| `S-BACKEND` (`blocked`) | **Missing implementation** | [`src/app.js:215-232`](../../src/app.js#L215-L232) usa `localStorage`; [`Program.cs:116-198`](../../backend/src/Martha.Store.Api/Program.cs#L116-L198) cierra rutas sintéticas fuera de `Development`. Fila 15 (`P1`). |
| `PIPE-AI` (`todo`) | **Optional** | [`progress-digest.yml:54-150`](../../.github/workflows/progress-digest.yml#L54-L150) salta sin secreto. Fila 24 (`P2`). |
| `TONY-STATUS01..03`, `WF01`, `HC01..02`, `STOCKDOC` (7 `review`) | **Stale acceptance status** (los 7) | Aplicados en [`delivery_status.py:25,71-80,110-139`](../../tools/delivery_status.py#L25), [`progress-digest.yml:161-237`](../../.github/workflows/progress-digest.yml#L161-L237), [`verify_evidence.py`](../../tests/golden-path/verify_evidence.py), [`golden_path.py`](../../tests/golden-path/golden_path.py), [`golden-path.yml:114-181`](../../.github/workflows/golden-path.yml#L114-L181) y [`DECISIONS.md:56-59,136-180`](../DECISIONS.md#L56-L59). Verificados en `260b759`. Fila 22. |
| *Extras en 24 filas:* | `SUPPLY-UI` (Fila 2: **Missing verification**, `--supply` NOT RUN); `P-LEGACY` (Fila 23: **Missing implementation**, 5 regresiones DOM); Filas 1, 16, 17, 18 (sub-tareas CI/tienda). | [`PREPARATION-ACCEPTANCE.json`](../supply-real-20261106/PREPARATION-ACCEPTANCE.json), [`CLASSIFICATION.md`](../p-legacy-20261104/CLASSIFICATION.md). |

## 4. Tres fallas de ejecución y por qué falló el plan del 5 de noviembre

**Por qué [`release-20261105/PLAN.md`](../release-20261105/PLAN.md) no logró un día operativo:** Diagnosticó que faltaba `D-026`/`D-027` ([`savia-audit.md:40`](../release-20261105/savia-audit.md#L40)), pero en los >20 commits siguientes (`1e353d4` a `8e38d98`) **cero workers tocaron excepciones de stock**. El tiempo se fue en simulaciones jsdom offline, backlog (`14c1fbc`), skills (`9b38787`), imágenes WebP y tres iteraciones de recepción sin ejecutar `golden-path.yml` con `--supply`.

1. **Falla 1: Ceremonia de manifiestos SHA256 RAW/LF y re-auditorías por saltos de línea.**
   - **Ejemplo:** [`docs/hardening-20261106/combined/`](../hardening-20261106/combined/) añadió >15,000 líneas de JSON y tres commits (`8523523`, `a77f705`, `8e38d98`) por hashes CRLF grabados en Windows ([`ci-correction.md:3-43`](../hardening-20261106/combined/ci-correction.md#L3-L43)).
   - **Alternativa:** Usar `git rev-parse HEAD^{tree}`, normalizar LF antes de grabar snapshots y usar Crítico/Juez solo en cambios de código/seguridad.
2. **Falla 2: Fraccionar una prueba E2E en tres campañas y no verificar herramientas locales.**
   - **Ejemplo:** Se corrió SQL aislado en `708bdbb` (`run 42163110947`, [`sql-ci-20261106/README.md`](../sql-ci-20261106/README.md)) *antes* de integrar `--supply` (`65ab1d9`), dejando el recorrido combinado **NOT RUN**. Además, el worker declaró ausente el SDK `.NET 10.0.402` instalado en `C:/Users/Jason/.dotnet-sdk-10.0.402/dotnet.exe` ([`supply-real-20261106/primary-review.md:57`](../supply-real-20261106/primary-review.md#L57)).
   - **Alternativa:** Verificar binarios portables antes de delegar y empaquetar UI + arnés E2E en **una sola** corrida SQL.
3. **Falla 3: Priorizar simuladores offline y metaproceso sobre `D-026`/`D-027`.**
   - **Ejemplo:** Doce familias de simulación offline ([`PROJECT-STATUS.md:56-58`](../PROJECT-STATUS.md#L56-L58)), `14c1fbc` y `9b38787` consumieron turnos mientras `D-026`/`D-027` seguía en cero.
   - **Alternativa:** Congelar simulaciones offline y asignar un worker directo a `Internal/Commerce` y `dev/savia-staff-ui`.

## 5. Separación de las 3 entregas y camino crítico real

| Entrega | Camino crítico real | ¿Avanza hoy sin Martha (`C2`)? |
| --- | --- | --- |
| **1. Ensayo SAVIA (`SUAZO-PC`, `D-022`/`D-025`)** | 1) Correr `golden-path.yml` (`supply_receipt=true`). 2) Implementar excepción `D-026`/`D-027`. 3) Ejecutar 5 tareas + 30 ventas (`p95 <= 1s`) y conteo físico (`C10`). | **SÍ, 100%.** Usa datos sintéticos aprobados (`D-025`). |
| **2. Producción SAVIA (`D-024`)** | 1) Hechos de Martha (`C2`/`D-029`). 2) Efectivo/cambio, cierre y doc fiscal según `C2`. 3) TLS/restore (`C9`) + `P-OWNER`. 4) Host (`P-HOST`), `P-SEC` y `P-OPS`. | **Parcial:** `P-OWNER` sintético y alcance TLS (`C9`) avanzan; corte fiscal/caja requiere `C2`. |
| **3. Producción tienda (`D-008`/`D-009`/`D-030`)** | 1) Cerrar `D-030` y arreglar 5 regresiones DOM (`P-LEGACY`). 2) Elegir pasarela (`S-PAY`). 3) Backend público (`S-BACKEND`). 4) Precios/legal (Ley 842) y dominio/SEO. | **Solo el paso 1** (`D-030` + `P-LEGACY`). Pagos y órdenes dependen de `S-PAY` y datos comerciales. |

## 6. Código: brecha de stock (`D-026`/`D-027`) y frontera de pagos/pedidos

- **Brecha de stock (`D-026`/`D-027`):** [`InternalStockLedger.cs:34-41`](../../backend/src/Martha.Store.Api/Internal/Commerce/InternalStockLedger.cs#L34-L41) exige en SQL `Serializable` que `OnHand + onHandDelta >= 0`; con `OnHand == 0`, [`InternalCommerceService.cs:64`](../../backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceService.cs#L64) falla con `"stock_unavailable"`. `Adjust` ([`InternalCommerceEndpoints.cs:21-23`](../../backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceEndpoints.cs#L21-L23)) exige `"internal.inventory"`, bloqueando a `Cashier`. **Solución sin quitar la guarda:** permitir en `InternalSaleLineRequest` excepción física con motivo; en `RecordSale` (`Serializable`), registrar `InternalStockException` durable y movimiento puente trazado para que `OnHand` quede en `0` (nunca `< 0` ni recepción ficticia), más endpoint de revisión al cierre para `Manager`/`Owner` (`ReviewerId != CashierId`) que conserve `open_cause` sin evidencia.
- **Frontera de pagos y pedidos:** En SAVIA, [`InternalCommerceService.cs:202-207`](../../backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceService.cs#L202-L207) emite `"not_processed"`, [`InternalHosting.cs:57`](../../backend/src/Martha.Store.Api/Internal/InternalHosting.cs#L57) reporta `paymentProcessing = false` y [`dev/savia-staff-ui/app.mjs:502`](../../dev/savia-staff-ui/app.mjs#L502) muestra `"Sin cobro bancario"`. En tienda, [`src/app.js:215-245`](../../src/app.js#L215-L245) usa `localStorage` sin API, y [`Program.cs:116-198`](../../backend/src/Martha.Store.Api/Program.cs#L116-L198) bloquea rutas sintéticas fuera de `Development` (`StoreDbContext` separado de `InternalDbContext`, [`DATABASE.md:8-11`](../DATABASE.md#L8-L11)).

## 7. Respuestas directas de rendición de cuentas

1. **¿Qué debimos hacer antes?** Implementar `D-026`/`D-027` el 4 de noviembre; incluir `--supply` antes del CI SQL `42163110947`; validar LF en Windows; y cerrar los 7 `TONY-*` tras `260b759`.
2. **¿Restricciones genuinas vs autocreadas?**
   - **Genuinas:** hechos fiscales/caja de Martha (`C2`), tarjetas en tienda (`D-008`/`D-009`), validación TLS (`C9`), proteger `main`/despliegues (`D-028`), y `WinError 1314` en symlinks.
   - **Autocreadas:** bloquear el ensayo `C10` por `C2`/`C9`, escribir >15,000 líneas de hashes JSON por commit, dejar 7 `TONY-*` en `review`, y correr Crítico/Juez por ajustes de tests.
3. **¿Qué debe hacer el primary inmediatamente después?** Leer `42173233401` (`8e38d98`), cerrar el crítico de tienda, limpiar `ledger.json` (7 `TONY-*` a `done`, desacoplar `C10` de `C2`/`C9`, separar `C1`), pedir dispatch `golden-path.yml` (`supply_receipt=true`), y lanzar `Sol/high` para `D-026`/`D-027`.

## 8. START / STOP / KEEP y ventana práctica de 3 horas

- **STOP:** Manifiestos masivos de hashes JSON; revisiones Crítico/Juez para cambios no funcionales; trabajo en `PIPE-AI`, `learning/backlog` o simuladores offline; bloqueo de `C10` por `C2`/`C9`.
- **START:** Excepción `D-026`/`D-027`; corrida `golden-path.yml` (`supply_receipt=true`); corrección de las 19 aserciones de `P-LEGACY`.
- **KEEP:** Guarda no-negativa y aislamiento `Serializable` en `InternalStockLedger.cs`; un escritor por ruta (máx. 2 workers); `noindex` en demo y pruebas rojo/verde en dinero/stock/seguridad.

| Minutos | Primary (Ledger / CI) | Worker A (`Sol/high` — `D-026`/`D-027`) | Worker B (`Sol/high` — `P-LEGACY`) | Evidencia |
| --- | --- | --- | --- | --- |
| **0–25m** | Leer `42173233401` y crítico storefront. Actualizar `ledger.json` y `DECISIONS.md` (`D-030`). Pedir dispatch `golden-path.yml` (`supply_receipt=true`). | Congelar contrato `D-026`/`D-027` en `Internal/Commerce` y `dev/savia-staff-ui`. | Reproducir 19 fallos de [`CLASSIFICATION.md`](../p-legacy-20261104/CLASSIFICATION.md) en las 3 suites JS. | `delivery_status.py --check` exit 0. |
| **25–105m** | Con permiso de Jason, correr `golden-path.yml` (`supply_receipt=true`) y verificar 17 checkpoints, 4 oráculos SQL y cleanup. | Implementar excepción en venta con stock 0, entidad/migración y revisión al cierre (`ReviewerId != CashierId`). Build SDK `10.0.402`. | Corregir 5 regresiones DOM (`DG01/03/04/06/10`), 5 fixtures de geometría y 9 contratos de medios (`D-030`). | `golden-path.yml` verde; build C# 0 errores; 3 suites `P-LEGACY` 0 FAIL. |
| **105–150m** | Integrar Worker B y A en `Tony`. Correr `prepare.py`, `verify_release_snapshot.py` (LF) y suites locales. | Tests rojo/verde (409 sin excepción; registro con excepción; prohibido auto-revisar). | Conteos: `desktop-gallery` 14/14, `green-header` 6/6, `luxury-editorial` 8/8. | `git diff --check` exit 0; suites locales verdes. |
| **150–180m** | Ejecutar **una sola** ronda Crítico → Juez sobre el diff combinado (`D-026`/`D-027` + `P-LEGACY`). | Resolver hallazgos materiales sobre `D-026`/`D-027`. | Documentar cierre de issue #4. | Candidato listo para ensayo `C10` en `SUAZO-PC`. |

### Orden posterior y acciones inevitables de Jason
1. **Ensayo `C10` (`SUAZO-PC`):** tras integrar `D-026`/`D-027` y su CI SQL, ejecutar 5 tareas, 30 ventas (`p95 <= 1s`) y conteo físico (`D-022`/`D-025`).
2. **Acciones de Jason:** (a) **Hoy:** autorizar `golden-path.yml` (`supply_receipt=true`) y otra tras `D-026`/`D-027`; (b) **SAVIA:** entrevista con Martha (`C2`/`D-029`), autorizar TLS (`C9`) y decidir `P-HOST`/`P-OWNER`; (c) **Tienda:** elegir pasarela (`S-PAY`) y precios; (d) **Cierre (`C12`/`P-GO`):** autorizar merge a `main` tras `C10`, y despliegue tras `P-SEC`/`P-OPS`.
