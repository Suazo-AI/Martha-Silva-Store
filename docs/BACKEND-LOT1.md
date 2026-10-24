# Backend — lote 1: contrato y base sintética

**Alcance:** R01 técnico + fundamento R04 del [roadmap](ROADMAP-V1.md). La aprobación de implementar este lote no cierra las decisiones comerciales allí pendientes. No es R07 productivo, lanzamiento, integración de tarjetas ni sustitución de la demo.

- [Contrato OpenAPI](../contracts/openapi-v1.json)
- [Convenciones y ejemplos](../contracts/README.md)
- [ADR de arquitectura e invariantes](adr/0001-backend-synthetic-foundation.md)

La demo vanilla y estática conserva su comportamiento local; las rutas `/api/...` internas del simulador no se redirigen al nuevo backend. R08 deberá adaptar explícitamente precios, datos y errores al servidor, con modo separado y sin fallback silencioso.

## Decisiones abiertas, responsables y gates

Los responsables son **roles**, no personas asignadas sin confirmación. Se puede avanzar con fixtures mientras estas puertas siguen cerradas.

| Decisión pendiente | Responsable de decisión / evidencia | Bloquea |
| --- | --- | --- |
| Moneda, precios, impuestos y redondeo | Negocio + responsable técnico; maestro piloto aprobado y reglas verificables | Carga comercial R03/R05 y ventas |
| Autoridad de stock físico/online; SISFAIN o cupo separado | Negocio + operaciones + técnico; fuente única, flujo observado y contrato si existe | Promesa de no sobreventa y ventas reales; no se presume ERP ni pool separado |
| Catálogo piloto, SKU/fotos y existencias | Negocio; fuente/fecha/aprobación privada | R03 y publicación comercial |
| Envíos/pickup, cancelación, duración de reserva, devoluciones | Negocio; políticas aprobadas | Checkout y operación real |
| Pasarela, elegibilidad, afiliación, cuenta y liquidación | Titular del comercio; documentación y sandbox autorizado | R02/R11/R17; ninguna pasarela elegida en este lote |
| Identidad, sesiones, permisos y acceso a pedidos | Técnico/seguridad; pruebas negativas R06 | Cualquier mutación productiva o lectura privada de pedidos |
| SQL de pruebas, edición/licencia/EULA y recursos | Titular autorizado + técnico; autorización expresa y entorno aislado | Arranque SQL y prueba de integración en este entorno; compilar/contratos pueden avanzar |
| Hosting .NET/SQL, costos, secretos y despliegue | Dueño + técnico/DevOps; destino y permisos aprobados | R12; el Worker estático no aloja .NET |
| RPO/RTO, recuperación y retención de claves | Negocio + operaciones + técnico; objetivos y ensayo | R15 y aceptación productiva |

## Evidencia exigida, sin confundirla con resultado

1. Compilar .NET y ejecutar pruebas de validación/contrato, con comando, SHA y salida.
2. En SQL Server real autorizado: migración vacía y segunda ejecución segura; seed sintético repetible; lectura de catálogo.
3. Veinte solicitudes por una unidad: una reserva ganadora, otras rechazadas, saldo nunca negativo.
4. Misma clave concurrente: mismo pedido/cuerpo; otra cantidad o variante con la misma clave: 409 y ningún efecto adicional. Campos manipulados de precio/total se rechazan con 400; el servidor nunca confía en ellos.
5. Fallo transaccional: sin pedido, reserva o clave parcial. Expiración aplazada: no se afirma liberación; R07 deberá probar liberación repetida/concurrente una sola vez sin aumentar stock físico.
6. Development sin flag y Test/Production con/sin flag: rutas sintéticas ausentes; storage no disponible: readiness falla, sin datos inventados ni fallback.
7. Suite estática existente pasa sin cambios frontend. La suite DOM no es QA real de navegador ni prueba de SQL.

Este documento es alcance y aceptación, **no reporte de tests aprobados**. Registrar resultados ejecutados y límites en la entrega del SHA integrado. No se arrancó SQL ni se aceptó su EULA como parte de redactar este contrato. Pruebas omitidas por autorización pendiente deben permanecer pendientes, nunca sustituirse por una base en memoria y declararse SQL probado.

## Fuera del lote

Pagos/reembolsos/webhooks, autenticación comercial, panel productivo, carrito/quote HTTP, pedido multi-línea, expiración/cancelación de reservas, datos reales, frontend conectado, ERP, publicación/remoto, y modificación del original Cloudflare. No hay contrato de API de producción listo: cualquier exposición de mutaciones requiere cerrar R06 y gates comerciales, revisar el nuevo contrato y obtener autorización de despliegue.
