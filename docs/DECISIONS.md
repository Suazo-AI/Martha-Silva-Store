# Registro de decisiones

Fecha de registro: 2026-10-24. Este documento distingue decisiones adoptadas de decisiones pendientes; no sustituye la historia Git ni acredita un despliegue.

| ID | Estado | Decisión y razón | Consecuencia / evidencia |
| --- | --- | --- | --- |
| D-001 | Adoptada | Preservar el sitio original y mantener independiente la demo mejorada | No desplegar sobre `martha-silva-demo.jason-suazof.workers.dev`; destinos documentados en README |
| D-002 | Adoptada | Conservar una base ejecutable pequeña antes de ampliar el catálogo | Raíz: 9 páginas / 2 productos; las 40 fichas originales son un alcance distinto |
| D-003 | Adoptada | Versionar entradas de build y ensamblar con Python estándar | `prepare.py`, `build-inputs/`; sin dependencia del equipo desconectado |
| D-004 | Adoptada | Separar originales históricos del build activo | Material recuperado bajo `originals/cloudflare/` al integrarse; no habilitar infraestructura histórica |
| D-005 | Adoptada | Recuperar medios mediante lista permitida y staging, no copia general | [Auditoría](ASSET-COMPLETENESS.md); faltantes permanecen explícitos |
| D-006 | Adoptada | Medir cobertura por capa y conservar limitaciones | jsdom no acredita QA visual ni móvil; [evidencia previa](../evidence/QA.md) |
| D-007 | Adoptada | Mantener investigación de pagos fuera del artefacto desplegado | `research/rea/` no entra en `dist/`; análisis estático no equivale a integración |
| D-008 | Requisito | Exigir pago con tarjeta para producción | Una demo local, transferencia o pedido simulado no satisface este requisito |
| D-009 | Pendiente | Elegir proveedor de tarjeta con elegibilidad y condiciones del comercio verificadas | REA identifica opciones técnicas, no selecciona proveedor ni confirma disponibilidad |
| D-010 | Pendiente | Definir backend autoritativo e integración SISFAIN, si corresponde | No se encontró backend SISFAIN; no inventar endpoints, contratos o credenciales |
| D-011 | Adoptada | Preservar historia y verificar entregas por SHA | Commit local, push remoto y despliegue son estados distintos |

## Decisiones vigentes — 2026-11-03

| ID | Estado | Decisión y fundamento | Sustituye / evidencia |
| --- | --- | --- | --- |
| D-012 | Adoptada | Un checkout canónico `github`, rama Tony; actualizar código, decisiones y evidencia pública revisada | Pedido de Jason; [AGENT-START](AGENT-START.md), [reconciliación](reconciliation-20261103/README.md) |
| D-013 | Hecho de alcance | Snapshot de tienda: 47 páginas, 40 productos y 120 variantes de muestra | Actualiza la línea base 9/2 de D-002, sin convertirla en inventario comercial |
| D-014 | Alcance interno vigente | Un negocio y una sucursal operativa; Owner, Manager, Cashier, Inventory; Internal es autoridad privada | [NEXT-INCREMENT](delivery-20261031/NEXT-INCREMENT.md); propuestas multiempresa/seis roles quedan históricas |
| D-015 | Prioridad técnica propuesta | Corregir N5 y aceptar venta segura por cajero antes de ampliar pantallas o agentes | Fallo reproducido y falta de recorrido combinado; [pruebas](testing-20261103/README.md) |
| D-016 | Elegida por Jason | Preparar índice para agentes y documentación SQL; no modificar la base en esta reconciliación | Respuesta explícita 2026-11-03; [DATABASE](DATABASE.md) |
| D-017 | Decisión de implementación | Git + rg + mapa de fuentes como navegación disponible; Graphify opcional y derivado | Application Control bloquea el binario; no eludir la política ni importar el grafo de otro checkout |
| D-018 | Adoptada | Publicar resultados curados y hashes; mantener evidencias operativas privadas fuera del índice Git | [Exclusiones](reconciliation-20261103/README.md); no perder originales ni sobrescribir validation/outputs |
| D-019 | Distinción de alcance | D-008/D-009 siguen aplicando a la tienda pública; no añaden pagos al incremento interno | Backend interno implementado no resuelve tarjetas, producción ni SISFAIN de D-010 |
| D-020 | Adoptada (pedido de Jason, 2026-11-03) | El estado de entrega vive en [ledger.json](pipeline/ledger.json); `progress-digest.yml` lo valida y publica un resumen determinista en cada push y PR. Alternativas: resumen manual (se desactualiza), solo Trello (sin SHA ni CI), estado escrito por IA (puede inventar) | [Flujo](pipeline/README.md). Sustituye la exclusión "watcher o loop autónomo" del sprint solo para registrar y avisar: no corrige, no fusiona ni despliega |
| D-021 | Propuesta, decide Jason | Narrador IA opcional y de solo lectura en PR; recomendado Claude con `CLAUDE_CODE_OAUTH_TOKEN` | Item `PIPE-AI`. Sin secreto no corre; credencial y costo son decisión de Jason |

Los resultados de pruebas son evidencia, no decisiones de negocio. La política comercial de stock cero,
proveedor de tarjetas, aceptación visual y destino productivo siguen pendientes de sus responsables.
No se activa un loop autónomo ilimitado de agentes; los fixes requieren reproducción, límites y verificación.

## Hitos rastreables en la historia existente

- `e6299ee`: base recuperada referenciada por los registros de QA y build.
- `2e9f6b0`: preservación del estado legado ante expansión conocida del catálogo.
- `ad3ba47`: documentación y agregación de QA de la demo recuperada.
- `113a34e`: auditoría offline de medios y guía segura de recuperación.
- `339235f`: build autocontenido desde entradas versionadas.
- `10118d1`: evidencia REA y comprobaciones agregadas.

Consultar `git show <sha>` antes de atribuir un cambio específico. Los commits posteriores documentan la integración del nuevo repositorio; este listado no afirma que estén publicados o desplegados.

## Cómo cambiar una decisión

Añadir una entrada con fecha, estado, motivo, evidencia y decisión reemplazada. No borrar el bloqueo histórico para aparentar que nunca existió. Una ampliación del catálogo, selección de pagos o publicación debe traer sus pruebas y actualizar [PROJECT-STATUS](PROJECT-STATUS.md).

[Inicio](../README.md) · [Procedimientos](PLAYBOOK.md)


## Reconciliación de stock físico — candidato de corrección 2026-11-04

La instrucción directa de Denis conserva la entrega cuando la prenda física sí existe, aun si el stock registrado figura en 0. El ledger no debe reabrir esa elección ni recomendar un rechazo automático. Siguen pendientes la forma de alertar y reconciliar el registro, y su aceptación con el responsable del negocio. Este ajuste documental no modifica las guardas actuales de SQL/API ni acredita un cambio funcional de inventario.
