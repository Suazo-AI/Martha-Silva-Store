# CRM de SAVIA: investigación y propuesta

Fecha: 2026-11-11. Modo: DISCOVER. Candidato leído: `Tony` @ `0ee69b6`.
Estado: propuesta. Nada de esto está implementado salvo lo marcado como "existe".

## Resultado

El CRM no debe ser un sistema aparte.
Debe ser un módulo dentro de SAVIA, sobre la misma base, la misma seguridad y la misma caja.
La base ya existe; falta hacerla usable para la cajera y emitir eventos para integraciones.

## Qué existe hoy (verificado en código)

- `InternalParty` en `Internal/Directory`: `Kind` (`customer`/`supplier`), `Name`, `Email`, `Phone`, `Active`.
- La venta ya tiene `CustomerId` opcional con FK a `InternalParty` (`InternalCommerceModel.cs:48`).
- Leer y crear clientes exige `internal.owner`. La cajera no puede buscar ni registrar un cliente.
- Las mutaciones ya exigen HTTPS, CSRF, actor del servidor e `Idempotency-Key`.
- Borrado solo lógico (`active=false`); el historial se conserva.
- No existe historial de cliente, consentimiento, eventos ni webhooks.

## Para quién se diseña

Tienda de ropa, una sucursal, roles Owner, Manager, Cashier e Inventory (D-014).
La cajera trabaja con la clienta enfrente y una fila detrás.
Cada segundo de captura en caja cuesta; cada campo obligatorio se llena mal o se salta.
Martha decide y revisa; no debe administrar un software de ventas B2B.

Reglas de diseño que salen de eso:

1. Registrar al cliente nunca bloquea una venta. Venta sin cliente sigue siendo válida.
2. Teléfono como clave de búsqueda. Un campo, teclado numérico, coincidencia mientras escribe.
3. Alta en caja con dos campos: teléfono y nombre. Lo demás se completa después, por Owner o Manager.
4. La cajera ve lo mínimo: nombre y si tiene historial. Owner ve todo.
5. Nada de embudos, oportunidades ni puntaje de leads. Eso es CRM de ventas B2B, no de tienda.

## Qué hace un CRM útil en esta tienda

| Necesidad | Valor para el negocio | Depende de |
| --- | --- | --- |
| Reconocer a la clienta que vuelve | Atención personal, recompra | Búsqueda por teléfono en caja |
| Historial: qué compró, talla, devoluciones | Recomendar, resolver devoluciones rápido | Ventas ya ligadas a `CustomerId` |
| Avisar llegadas nuevas | Ventas sin pagar anuncios | Consentimiento y canal |
| Crédito y abonos | Hoy fuera de alcance (D-031) | Incremento de crédito |

## Cómo aguantar cambios e integraciones

El objetivo es que agregar una integración no toque la caja.

1. **Outbox transaccional.** La venta y su evento se guardan en la misma transacción SQL.
   Eventos iniciales: `customer.created`, `customer.updated`, `sale.completed`, `sale.refunded`.
2. **Despachador aparte.** Lee el outbox y entrega a cada suscriptor con reintentos y backoff.
   Si un destino falla, la caja sigue funcionando.
3. **Webhooks firmados.** HMAC-SHA256 sobre el cuerpo, con timestamp y `event_id`.
   El receptor descarta duplicados por `event_id`. Esto permite reintentar sin duplicar.
4. **Contrato versionado.** Cada evento lleva `type` y `version`. Campos nuevos solo se agregan.
   Un esquema JSON por evento en `contracts/`, probado en CI.
5. **Historial derivado.** La ficha de la clienta se arma desde ventas y eventos existentes.
   No se duplica el dato de la venta en otra tabla.
6. **Migraciones aditivas.** Mismo patrón que las tres migraciones actuales; nunca destructivas.

Mismo mecanismo sirve para el pipeline de bugs pedido antes: un evento entra, un consumidor actúa.

## Legal (inferencia, requiere validación)

Nicaragua tiene ley de protección de datos personales (Ley 787, 2012).
No verifiqué el texto en esta investigación.
Antes de producción, un abogado o la contadora debe confirmar: consentimiento, finalidad, acceso, rectificación y supresión.
Diseño mínimo que cubre eso: casilla de consentimiento con fecha y actor, finalidad registrada, exportación y baja por cliente.
La baja anonimiza datos personales y conserva la venta para contabilidad.

## Incrementos propuestos

| ID | Entrega | Prueba independiente |
| --- | --- | --- |
| CRM-0 | Cajera busca y crea cliente por teléfono en caja; venta sin cliente sigue igual | Navegador → API → SQL: venta con y sin cliente; cajera no ve email ni historial completo |
| CRM-1 | Ficha de cliente para Owner: compras, devoluciones, totales | Oráculo SQL compara la ficha con las ventas reales |
| CRM-2 | Outbox, despachador y webhooks firmados | Caída simulada del destino: cero pérdidas y cero duplicados tras reintentos |
| CRM-3 | Consentimiento, exportación y baja | Baja anonimiza y la venta sigue cuadrando en el cierre |
| CRM-4 | Crédito y abonos | Depende de un incremento de crédito aprobado (D-031) |

CRM-0 es el de mayor valor: sin captura en caja, el resto queda vacío.

## Decisiones que necesita Jason

1. **Permiso de la cajera.** Hoy clientes es solo Owner. CRM-0 requiere que Cashier busque y cree con campos mínimos.
   Recomendación: permitirlo con vista reducida y auditoría por actor.
2. **Canal de avisos.** Recomendación: enlaces `wa.me` manuales primero; cero costo, cero cuenta nueva.
   La API de WhatsApp Business implica cuenta, costo y aprobación; posponerla.

## Lo que debe confirmar Martha (guion C2 existente)

El [guion D-029](../sprint-20261104/GUION-RECONSTRUCCION-MARTHA.md) ya pregunta qué datos de la clienta pide y por qué (línea 82).
Agregar tres preguntas en esa misma conversación:

- ¿Anotás hoy a tus clientas en algún lado? ¿Qué anotás?
- ¿Les escribís por WhatsApp para avisar llegadas o apartados?
- ¿Cuántas clientas vuelven en un mes, más o menos?

Si casi nadie vuelve o Martha no usa contacto directo, CRM-1 a CRM-3 bajan de prioridad.

## Límites de esta investigación

- No se habló con Martha ni con cajeras; las reglas de diseño son inferencia del contexto.
- No se verificó la Ley 787 ni requisitos fiscales.
- No se midió tiempo real de una venta en caja.
