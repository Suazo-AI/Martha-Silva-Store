# Programa: CRM + sitio + SAVIA sincronizados, con reparación de bugs por evidencia

Fecha: 2026-11-11. Orquestador: agente primary. Base: `Tony` @ `fd275e6`.
Modo: BUILD. Revenue link: un sistema conectado que Martha pueda operar y un agente pueda mantener.

## Respuestas de Jason (2026-11-11)

- J-1: la clienta se registra con **email y nombre**. Teléfono opcional.
  Inferencia del orquestador: el teléfono queda opcional porque J-2 lo necesita para abrir WhatsApp.
- J-2: avisos por enlaces de WhatsApp enviados a mano.
- J-3: cotizar servidor en la nube; no contratar. Se desarrolla en SUAZO-PC.
- J-4: la app móvil es primero para el personal.
- J-5: app móvil y cuentas de tiendas, después. Prioridad: CRM, sitio y SAVIA sincronizados, más el pipeline de bugs.
- Objetivo de mantenimiento: un agente Opus con razonamiento medio debe poder mantener el sistema completo.

Arquitectura vigente: [architecture-20261111](../architecture-20261111/README.md) (T-1 a T-4).

## Fuera de alcance de este programa

- Pedidos pagados desde el sitio: siguen bloqueados por S-PAY y S-BACKEND (D-008, D-009).
- Despliegue, hosting contratado, merge a `main`, SQL en producción, cuentas nuevas y gastos.
- App móvil, tiendas de apps y API de WhatsApp Business.

## Paquetes de trabajo

Orden: WP-S primero (único dueño de migraciones). WP-A corre en paralelo desde el inicio.
WP-B, WP-C y WP-D arrancan sobre WP-S integrado. WP-E cierra.

| ID | Entrega | Rutas exclusivas | Riesgo |
| --- | --- | --- | --- |
| WP-A | Pipeline de bugs | `.github/workflows/bug-*.yml`, `tools/bugproof/`, `docs/bug-pipeline/` | Bajo |
| WP-S | Esquema: outbox de eventos y consentimiento de clienta | `Internal/Migrations/`, modelos de Party y Events | Alto (datos) |
| WP-B | Tiempo real: outbox → SSE → pantallas staff | `Internal/Events/`, suscripción en `dev/savia-staff-ui/` | Alto (datos) |
| WP-C | CRM-0: cajera busca y registra clienta en caja | `Internal/Directory/` (vista reducida), caja en staff UI | Alto (permisos) |
| WP-D | Sitio ↔ SAVIA: catálogo y stock en vivo, registro de clientas | endpoint público de solo lectura, `src/integration-adapters.js` | Alto (exposición) |
| WP-E | Mantenimiento por agente: runbook y `doctor` | `docs/MAINTENANCE.md`, `tools/doctor.py` | Bajo |

Los paquetes de riesgo alto pasan primero por el crítico, antes de escribir código.

## Checks congelados

### WP-A
- A1: un fallo de CI en `Tony` abre o actualiza un issue `bug` con enlace al job. Sin duplicados por el mismo fallo.
- A2: un PR que cierra un issue `bug` debe agregar o cambiar al menos una prueba.
- A3: `bug-proof` corre esas pruebas en la base del PR (deben fallar) y en la cabeza (deben pasar). Si no fallan en la base, el check falla.
- A4: el resultado se publica en el PR como tabla antes/después y como artefacto HTML descargable.
- A5: el paso de agente (Claude Code, Opus, esfuerzo medio) se salta limpio si falta el secreto; nunca rompe CI.
- A6: un PR de demostración prueba A3 con un bug real o sembrado y su reversión.

### WP-S
- S1: migraciones aditivas; el script idempotente regenerado aplica dos veces sin error en base desechable.
- S2: outbox con `event_id` único, `type`, `version`, `occurred_at`, `payload` y estado de entrega.
- S3: consentimiento de clienta con fecha, actor y finalidad; baja anonimiza sin borrar ventas.

### WP-B
- B1: el evento se escribe en la misma transacción que la venta. Si la venta revierte, no hay evento.
- B2: venta en pantalla A visible en pantalla B en ≤ 1 s, medido en navegador real.
- B3: reconexión con `Last-Event-ID` sin eventos perdidos ni repetidos.
- B4: el stream respeta sesión, rol y sucursal. Una cajera de otra sucursal no recibe el evento.

### WP-C
- C1: cajera busca por email o nombre y registra con email y nombre en caja.
- C2: cajera no ve historial completo ni datos de otras clientas más allá del resultado de búsqueda mínimo.
- C3: venta sin clienta sigue funcionando igual.
- C4: email duplicado devuelve la clienta existente, no crea otra.

### WP-D
- D1: el sitio muestra stock real de SAVIA; un cambio en caja se refleja en el sitio en ≤ 5 s.
- D2: el endpoint público expone solo catálogo, precio y disponibilidad. Nada de costos, clientas ni personal.
- D3: registro de clienta en el sitio con email, nombre y consentimiento; límite de solicitudes y validación.
- D4: si SAVIA no responde, el sitio muestra el último stock conocido y lo indica.
- D5: LCP ≤ 2,5 s y INP ≤ 200 ms en perfil móvil de gama baja con 4G lento.

### WP-E
- E1: `python tools/doctor.py` corre todas las comprobaciones locales y dice qué falla y qué archivo leer.
- E2: un agente nuevo con solo `AGENT-START.md` y `MAINTENANCE.md` reproduce y corrige un bug sembrado.

## Enmienda tras la crítica previa (2026-11-11)

El crítico (`gpt-6-astra` xhigh, base `391041e`) halló 10 riesgos P1 y 2 P2: [critic-pre-impl.md](critic-pre-impl.md).
El primary verificó dos citas en fuente: `InternalCommandRunner.cs:119` (savepoint) y `InternalDirectoryModels.cs:113` (email no es identidad).
Se adopta la tabla "Proposed edits to the frozen checks" del informe. Reemplaza S1–S3, B1–B4, C1–C4 y D1–D5 de arriba.
Se agregan S4, S5, D6 y la puerta de integración serial.

Valores por defecto del arquitecto para S4 y C2, reversibles hasta que Martha decida:
- El email se normaliza (recorte, NFC, minúsculas invariantes). No es único para clientas creadas por personal: hogares comparten email.
- Si la cajera registra un email que ya existe, ve las coincidencias mínimas y elige una o crea otra de forma explícita. Nunca hay fusión automática.
- Una cuenta del sitio es única por email normalizado y se enlaza a una clienta. La respuesta pública es siempre genérica.
- La búsqueda de la cajera es global (todas las sucursales), con DTO mínimo, consulta exacta o prefijo acotado y límite de tasa.
- Duplicados históricos: se dejan intactos y se listan para revisión del Owner.

Orden revisado: WP-S incluye S5 (contratos congelados de B, C y D). Luego B y C en paralelo; D después de C, porque comparte identidad.

## Roles

Ejecutor: `codex` `gpt-6.1-sol` high. Crítico y juez: `codex` `gpt-6-astra` xhigh (política vigente 2026-11-07).
Máximo dos tareas Codex en paralelo. Cada ejecutor en worktree propio. El primary integra en serie y acepta.

## Estado

| ID | Estado | Evidencia |
| --- | --- | --- |
| WP-A | integrado en `Tony`; activo solo para PR | 11 pruebas locales OK; demo A6 PASS/FAIL ([evidencia](../bug-pipeline/EVIDENCE.md)). A1 y A5 necesitan los workflows en `main` (rama por defecto): decisión de Jason. actionlint, .NET real y runtime GitHub NOT RUN. |
| Crítica previa S/B/C/D | hecha; checks enmendados | [critic-pre-impl.md](critic-pre-impl.md) |
| WP-S | entregado; juez en curso; SQL NOT RUN | `docs/program-20261111/wp-s/EVIDENCE.md` en el worktree del worker |
| WP-E | E1 integrado; E2 pendiente | `python tests/test_doctor.py` OK (primary). doctor: 53 PASS / 2 FAIL / 20 SKIPPED; los 2 FAIL son `WinError 1314` (symlinks en Windows sin privilegio), no producto. [MAINTENANCE](../MAINTENANCE.md) |
| WP-B, C, D | pendiente de WP-S aceptado | — |
| Cotización hosting (J-3) | lista, sin contratar | [hosting-quotes-20261111](../hosting-quotes-20261111/README.md) |
