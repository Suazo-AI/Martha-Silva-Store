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

## D-022 — Responsable de aceptación del ensayo

Adoptada por Jason el 2026-11-03, America/Managua (2026-11-04 UTC):
el coordinador/agente de **SUAZO-PC** emite la aceptación por flujo del ensayo C10.
Sustituye la propuesta de asignar esa aceptación a Martha.
Martha sigue aportando los datos de operación y las respuestas de C2.
Jason conserva la autorización de integración y despliegue.

Asignar el responsable no acepta anticipadamente el ensayo ni cierra C1 o C10.
Las cinco tareas por quien vende, las 30 mediciones en caja y el conteo físico
siguen necesitando evidencia real. El coordinador acepta o rechaza cada flujo
contra esa evidencia y registra el dictamen; no atribuye una aceptación personal a Martha.
No se inicia otro agente ni se autoriza SQL, certificados, merge o despliegue.

Verificación: `python tests/test_delivery_status.py`, 24/24 PASS;
`python tools/delivery_status.py --check`, ledger válido, 34 items.
Lectura exacta de cuatro tarjetas y dos criterios de Trello:
[responsable decidido en C1](https://trello.com/c/e57qFLhJ);
[dictamen C10 todavía pendiente](https://trello.com/c/RYEhYexC).
Siguiente decisión de Jason: equipo y entorno del ensayo; fecha después de resolver C2/C9.

## D-023 — Venta multiartículo obligatoria

Adoptada por Jason el 2026-11-04, America/Managua: una factura debe admitir varios
artículos y cantidades. No se consulta si basta una prenda por venta.
La API interna modela varias líneas; la UI actual arma una y el cliente exige una.
La decisión no acredita su implementación completa en pantalla ni validez fiscal.
Se sustituye la alternativa de una línea de C2. Se pueden preguntar volúmenes para
diseñar y probar, sin reabrir el requisito.

## D-024 — Sustituir el servicio SISFAIN

Adoptada por Jason el 2026-11-04, America/Managua: SISFAIN es el servicio actual
que queremos sustituir. No es el objetivo mantenerlo como autoridad integrada.
CGA publica SISFAIN Pro 4.0 y lista a Martha Silva como cliente; esto no identifica
la versión, módulos ni configuración instalada. No se halló un backend/API accesible.
[Producto](https://cgasoluciones.com/servicios/sistema-de-facturacion-inventarios-sisfain/)
y [clientes oficiales](https://cgasoluciones.com/nuestros-clientes/).

Sustituye la incertidumbre comercial de D-010 y su propuesta de integración.
Los pedidos de la tienda pública y la autorización de pagos/despliegue conservan
sus contratos separados. No se infiere que el incremento interno ya cubra caja,
crédito, documento fiscal, migración o todos los módulos del servicio instalado.

Tres agentes `gpt-6.1-sol / high`, seleccionados por Jason, investigaron operación,
fiscalidad y migración/calidad. La matriz y el modelo ficticio están en
[ensayo y sustitución](synthetic-replacement-20261104/README.md).
Los datos reales, corte operativo, cambios fiscales, SQL, certificados y despliegue
requieren sus alcances correspondientes. No se canceló ni modificó el servicio actual.

## D-025 — Equipo y datos del ensayo

Adoptada por Jason el 2026-11-04, America/Managua: usar **SUAZO-PC** como equipo
del ensayo, con **datos sintéticos**. Sustituye la elección de equipo pendiente de
C1. D-022 conserva al coordinador SUAZO-PC como aceptante por flujo.

Esta decisión no fija la red ni el equipo productivo de la tienda. Antes de probar,
se registra el montaje efectivamente usado y se reutiliza solo la evidencia aplicable.
No acepta C10, no resuelve C9 ni autoriza conexiones SQL nuevas, Docker,
certificados, datos reales, integración o despliegue. No se ejecutó el ensayo.

Siguiente decisión: quién registra y quién concilia la diferencia cuando el registro
dice 0 y existe la prenda física. La entrega ya está decidida; los permisos no.
Propuesta para Jason, todavía no adoptada: cajera registra la entrega excepcional
con incidencia obligatoria; encargada valida y concilia al cierre. Sin facultad
de ajustes libres para la cajera. El flujo requiere implementación y pruebas propias.
Actualización posterior: [D-026](#d-026--cajera-registra-la-excepción-encargada-revisa-después)
elige esa facultad para el ensayo; momento y cobertura de revisión siguen pendientes.

Verificación: `python tests/test_delivery_status.py`, 24/24 PASS;
`python tools/delivery_status.py --check`, ledger válido con 34 items.
Trello: cuatro descripciones leídas de vuelta y criterio de entorno de C1 completo;
la facultad de stock conserva estado pendiente.
[Recibo saneado](sprint-20261104/ensayo-suazo-pc-receipt.json).
La decisión de entorno no completa los demás criterios de C1.

## D-026 — Cajera registra la excepción; encargada revisa después

Adoptada por Jason el 2026-11-04, America/Managua, **para probar en el ensayo
sintético de SUAZO-PC**: la cajera registra la entrega excepcional cuando existe
la prenda física y el registro dice 0. La encargada revisa después.
La propuesta pendiente de D-025 queda elegida para ese ensayo.

El caso queda vinculado a la venta, artículo, talla, ubicación, cantidad, actor y momento.
La cajera no recibe facultad de ajustar libremente las existencias.
Revisión y resolución de la causa son resultados distintos. Una corrección requiere
evidencia; una causa desconocida conserva seguimiento, sin inventar recepción, costo o saldo.
La entrega física ya estaba decidida y no se reabre el rechazo automático por stock 0.

Siguiente decisión pendiente: momento de revisión y cobertura de la encargada.
Recomendación para el ensayo, todavía no adoptada: revisión al cierre de cada jornada
simulada, con un suplente distinto de la cajera si falta la encargada. Usar perfiles
ficticios; no asignar empleados reales ni responsabilidades productivas por esta prueba.
Si falta evidencia, registrar revisión y conservar causa abierta, responsable y próxima revisión.

El código actual impide descontar a existencias negativas. El nuevo recorrido no está
implementado, ejecutado ni aceptado. No se elimina esa guarda ni se habilitan SQL,
Docker, certificados, datos reales o despliegue. C1/C2/C9/C10 conservan sus brechas.
Aceptar la política no equivale a aceptar funcionalmente el ensayo.

[Explicación y alternativas](stock-decision-20261104/README.md).
El registro, readback de Trello y revisión de los dos agentes quedan en
[recibo de D-026](stock-decision-20261104/decision-026-receipt.json).
