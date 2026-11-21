# Fuentes y decisiones de adopción

Inspección: 2026-10-31 local / 2026-11-01 UTC. Los repositorios se leyeron como referencias externas. No se instalaron ni ejecutaron sus hooks o scripts.

## Los cuatro repositorios solicitados

| Fuente fijada | Práctica útil | Adaptación a Martha Silva |
| --- | --- | --- |
| [Matt Pocock: TDD](https://github.com/mattpocock/skills/blob/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d/skills/engineering/tdd/SKILL.md) | Una conducta por ciclo rojo→verde; tests en interfaces; evitar tests tautológicos. | Probar UI/HTTP para comportamiento. Mantener readback SQL independiente para integridad; el riesgo del ledger exige esa evidencia adicional. No convertir su recomendación en nueva aprobación obligatoria fuera de las instrucciones locales. |
| [Michael Shimeles: evidence-driven-testing](https://github.com/michaelshimeles/rstack/blob/11b15767d7587bab11f6c4957507b5f26d1785c7/evidence-driven-testing/SKILL.md) | Evidencia proporcional: interacción real para UI; mediciones y pares de salida para API. Documentación no necesita grabar el producto. | Reutilizar evidencia apta con su candidato y límites. No subir videos a servicios externos ni instalar su harness automáticamente. |
| [Addy Osmani: Definition of Done](https://github.com/addyosmani/agent-skills/blob/8bfcc1f9916f2eea55494d8c1fa7f4bde867dd9e/references/definition-of-done.md) | Separar estándar común de calidad y criterios particulares del incremento. | PLAYBOOK fija el estándar; NEXT fija criterios. Permisos y aceptación siguen las reglas de este proyecto. |
| [Addy: performance-optimization](https://github.com/addyosmani/agent-skills/blob/8bfcc1f9916f2eea55494d8c1fa7f4bde867dd9e/skills/performance-optimization/SKILL.md) | Medir, identificar causa, cambiar y volver a medir bajo iguales condiciones. | SQL Server y DevTools existentes. No copiar comandos PostgreSQL ni adoptar umbrales API como si ya se hubieran medido aquí. |
| [David Ondrej: goal-loop](https://github.com/davidondrej/skills/blob/7201ee3854ada65e1863f68690800aa483e6d085/skills/agent-orchestration/goal-loop/SKILL.md) | Objetivo, restricciones, validación y condición de parada. Comprobar soporte del runtime. | Loop acotado por evidencia. No crear goal persistente ni daemon durante este diagnóstico; el usuario debe pedir esa activación. |
| [David: deny-dangerous.sh](https://github.com/davidondrej/skills/blob/7201ee3854ada65e1863f68690800aa483e6d085/hooks/deny-dangerous.sh) y [test-guard.sh](https://github.com/davidondrej/skills/blob/7201ee3854ada65e1863f68690800aa483e6d085/hooks/test-guard.sh) | El hook debe tener contrato de entrada, salida y pruebas. | No instalar. Depende de Bash/jq, admite comandos si falta jq/patrones y su allowlist de pruebas admite acciones que aquí necesitan autorización. No es una frontera de seguridad para Windows ni un reparador automático. |

Las tres primeras referencias se descargaron por SHA. David se leyó desde main inmediatamente después de resolver su SHA; se verificó de nuevo el contenido fijado por SHA para evitar deriva. Esos SHA identifican la investigación, no versiones instaladas.

Los umbrales web se contrastan con la fuente primaria [Core Web Vitals](https://web.dev/articles/vitals). Son referencias de experiencia, no resultados del producto.

## Materia prima local

Rutas relativas al checkout canónico `C:/Users/Jason/MARTHA-SILVA/github`:

- `dev/savia-staff-ui/index.html`, `app.mjs`, `client.mjs`, `login.mjs` y `styles.css`: controles, recuperación, sesión y tokens visuales.
- `backend/src/Martha.Store.Api/Internal/Commerce/InternalCommerceService.cs`: validación antes de efectos y orden por ItemId.
- `backend/src/Martha.Store.Api/Internal/InternalCommandRunner.cs`: revalidación dentro de transacción, permisos, replay y savepoint.
- `backend/src/Martha.Store.Api/Internal/InternalBranchAccess.cs`: alcance de datos y operaciones.
- `backend/src/Martha.Store.Api/Internal/Security/{InternalSecurity.cs,InternalSecurityRules.cs,README.md}` y `Supply/InternalSupplyEndpoints.cs`: contrato de roles y acceso.
- `.github/workflows/{backend.yml,tony-snapshot.yml,progress.yml}`, `.githooks/` y `tools/progress.py`: disparadores reales y registro.
- `docs/PROJECT-STATUS.md`, `docs/SAVIA-LATEST.md`, `docs/savia-internal/{ACCEPTANCE.md,STAFF-WORKFLOWS.md,IMPLEMENTATION-BOUNDARY.md}`: alcance y contradicciones.

## Evidencia conservada; no reejecutada

`docs/savia-internal/sql-local-20261031/` estaba sin seguimiento Git y pertenece a trabajo previo. Se inspeccionaron CURRENT, TEST-MATRIX y los resultados sanitizados de venta/recuperación/persistencia. Se publica aquí solo síntesis y hashes aptos, no toda esa carpeta.

El paquete registra en `evidence.json` los hashes de `TEST-MATRIX.md`, `CURRENT.md`, `ui-recovery-fix.json`, `ui-response-loss-proof.json` y `api-only-persistence-proof.json`, cuando existen. El hash identifica bytes; no valida su contenido por sí mismo.

Los documentos de este paquete no prometen que esas rutas locales estén en GitHub. Quien solo tiene el repositorio público dispone de esta síntesis y sus límites; debe solicitar evidencia sanitizada apta al responsable antes de recertificar runtime.

Excluidos de publicación: cuentas, autorizaciones, secretos, cookies, certificados, bases, logs privados, imágenes de sesiones y cambios ajenos sin commit. La investigación externa se enlaza y parafrasea; no se copia masivamente.
