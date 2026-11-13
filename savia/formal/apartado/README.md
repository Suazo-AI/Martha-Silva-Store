# Apartado con traslado: modelo revisado caso por caso

Un cliente pide en la tienda destino una prenda que está en la tienda origen.
`Apartado.tla` describe ese flujo; TLC recorre todos los casos posibles del modelo (18 estados visibles, 26 movimientos).
Las tiendas trabajan sin conexión, así que cada una se entera tarde de lo que hizo la otra.

## Correr

```sh
python savia/tools/formal.py setup   # una vez: Java 21 y TLA+ tools 1.7.4 fijados por SHA-256, en savia/.out/tools/formal
python savia/tools/formal.py check   # 6 revisiones, unos 10 segundos
python savia/tools/formal.py chart   # reescribe chart.mmd
```

Resultado del 2026-11-13: `FORMAL PASS: 6 of 6 checks gave the expected result`.

## Reglas

| Regla | En una frase | Daño si se rompe |
| --- | --- | --- |
| `AnticipoResuelto` | El anticipo se aplica a la venta o se devuelve. | La tienda se queda con dinero de un pedido que no se cumplió. |
| `ApartadaSoloConPedido` | Una prenda apartada siempre tiene un cliente esperándola. | Prenda bloqueada que nadie puede vender. |
| `VenceSoloSiLlego` | El plazo no vence antes de que la prenda llegue. | El cliente pierde la prenda sin haberla visto. |
| `NoSeNiegaLoQueViaja` | Nunca se le dice "no hay" al cliente si la prenda ya salió. | Cliente rechazado y prenda trasladada para nadie. |
| `RespuestaYPrendaCoinciden` | Lo que origen reservó o despachó coincide con dónde está la prenda. | Inventario que no cuadra entre tiendas. |
| `NoEsperaAlOrigen` | Un pedido no espera para siempre a la tienda origen. | Cliente sin respuesta y prenda reservada sin fin. |

## Qué decidió el modelo

Cada diseño descartado está en `formal.py` como una revisión que **debe fallar**, con su camino más corto.

1. El plazo del apartado cuenta desde que la prenda llega a destino, no desde el pedido.
   Descartado: pedir, pasan los días, vence con la prenda en camino.
2. La tienda origen tiene un plazo para despachar.
   Descartado: origen reserva, nadie despacha, la prenda queda reservada para siempre.
3. Ese plazo lo cuenta y lo cierra la tienda origen, no destino.
   Descartado: origen despacha, destino aún no lo sabe, cierra por "sin respuesta" y la prenda llega para nadie.

Dos fallas sembradas (`Falla`) prueban que `AnticipoResuelto` y `ApartadaSoloConPedido` detectan el error que cuidan.

## Decisiones de la dueña que el modelo sigue

Decididas el 2026-11-13 (ver `docs/pilot/TRASLADOS-APARTADOS.md`).

- Al vencer o cancelar, el anticipo queda como crédito en la tienda.
- Una prenda que llegó y ya no tiene cliente se queda en venta en destino; no regresa a origen.
- Autoriza el gerente de la tienda donde el cliente pide; origen solo reserva y despacha.
- La tienda origen tiene 2 días para despachar.

Supuesto sin decidir: si la tienda no puede cumplir, el anticipo se devuelve al cliente.

## Límites

- Una prenda, un pedido, dos tiendas. Varias prendas o varios clientes por la misma prenda no están modelados.
- Supone que la sincronización llega algún día. Una tienda apagada para siempre necesita a una persona (cancelar el pedido).
- Una prenda que sale y nunca llega no tiene cierre automático: hace falta una alerta al gerente.
- Días chicos (2 y 2) en lugar de 3 a 7: el orden de los hechos es el mismo.
- El pago, la comisión y los montos no están modelados; solo el estado del anticipo.

## Cobertura

El flujo no existe en el código (commit `aa05e71`). Este modelo es el diseño que el código debe seguir.
Al construirlo: cada acción del modelo debe apuntar a su procedimiento SQL, y esta sección debe nombrar esos archivos y el commit revisado.
Si el código cambia una regla, se cambia primero el modelo y se vuelve a correr `check`.
