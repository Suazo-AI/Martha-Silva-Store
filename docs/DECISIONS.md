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
