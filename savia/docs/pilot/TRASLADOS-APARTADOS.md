# Traslados y apartados: decisiones de la dueña

Fuente: respuesta de Jason del 2026-11-12, por la dueña. Estado: decidido, no construido.

## Flujo

Un cliente pide una prenda que está en otra sucursal.
La prenda se etiqueta como traslado y el gerente lo autoriza.
El sistema la aparta para ese cliente mientras viaja y espera.

## Decisiones

1. Anticipo: no se pide por defecto; la mayoría son clientes de confianza.
   Existe un anticipo opcional del 20 %, que el gerente activa o desactiva por apartado.
2. Plazo de apartado: selector de 3 a 7 días. Al vencer, la prenda vuelve a la venta.
3. Datos del cliente: solo nombre y teléfono, y solo en traslados y apartados. La venta normal no pide datos.
4. Comisión: es para el vendedor que cerró la venta, en la sucursal donde la cerró.

## Diseño revisado con un modelo (2026-11-13)

Modelo y reglas: [formal/apartado](../../formal/apartado/README.md). Comando: `python savia/tools/formal.py check` (6 de 6).
El modelo fijó tres puntos de diseño: el plazo cuenta desde la llegada; origen tiene plazo para despachar; ese plazo lo cierra origen.

Decisiones del 2026-11-13 (respuesta de Jason):

5. La tienda origen tiene 2 días para despachar. Leído de "ponerle que va" sobre la sugerencia de 2 días; confirmar el número.
6. Si el apartado vence o el cliente cancela, el anticipo queda como crédito en la tienda.
7. Una prenda que llegó y ya no tiene cliente se queda en venta en la tienda destino.
8. Autoriza el gerente de la tienda donde el cliente pide. La tienda origen solo reserva y despacha.

Supuesto sin decidir: si la tienda no puede cumplir (la prenda ya se vendió o no se despachó a tiempo), el anticipo se devuelve al cliente.

## Pendiente para construir

- Depende de la sincronización entre sucursales (hub), que todavía no existe.
- Reglas en SQL: plazo 3–7 días, anticipo 0 % o 20 %, vencimiento, autorización del gerente y lista de aprobaciones de la dueña.
