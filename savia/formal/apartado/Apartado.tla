------------------------------ MODULE Apartado ------------------------------
(* Traslado con apartado: un cliente pide en la tienda destino una prenda que esta en la tienda origen.
   Una prenda, un pedido, dos tiendas que se enteran tarde una de la otra (trabajan sin conexion).
   Fuente de las reglas: savia/docs/pilot/TRASLADOS-APARTADOS.md y V010 (gana el despacho).
   Cada tienda escribe solo sus propias filas (ADR-001 F2): destino el pedido, origen la respuesta. *)
EXTENDS Naturals

CONSTANTS DiasApartado,    \* dias que la prenda espera al cliente (la duena eligio de 3 a 7; aqui un numero chico)
          RelojDesde,      \* "pedido" o "llegada": cuando empieza a contar el plazo del apartado
          PlazoOrigen,     \* dias que tiene la tienda origen para despachar; 0 = sin plazo
          PlazoLoCuenta,   \* "origen" o "destino": cual tienda cierra el pedido cuando ese plazo pasa
          Falla            \* "ninguna", o un error sembrado para probar que cada regla puede fallar

VARIABLES pedido,          \* lo que sabe el cliente y escribe la tienda destino
          origen,          \* la respuesta que escribe la tienda origen
          prenda,          \* donde esta fisicamente la prenda
          anticipo,        \* el 20 % opcional
          relojActivo, diasRestantes,
          espera,          \* dias sin despacho, contados por la tienda que lleva el plazo
          llego,           \* la prenda llego a destino con el pedido abierto
          origenVioPedido, origenVioCierre, destinoVe   \* lo que cada tienda ya sincronizo de la otra

vars == <<pedido, origen, prenda, anticipo, relojActivo, diasRestantes, espera, llego,
          origenVioPedido, origenVioCierre, destinoVe>>

Cerrado == {"vendido", "cancelado", "vencido", "sin_respuesta", "no_disponible"}
EstadosOrigen == {"sin_enterarse", "reservada", "despachada", "no_disponible"}
Reposo == {"en_venta_origen", "en_venta_destino", "vendida_a_otro_en_origen",
           "vendida_a_otro_en_destino", "vendida_al_cliente"}

TypeOK ==
    /\ pedido \in {"sin_pedido", "pedido"} \cup Cerrado
    /\ origen \in EstadosOrigen
    /\ prenda \in Reposo \cup {"reservada_origen", "en_camino", "apartada_destino"}
    /\ anticipo \in {"sin_anticipo", "cobrado", "aplicado", "devuelto"}
    /\ relojActivo \in BOOLEAN /\ diasRestantes \in 0..DiasApartado /\ espera \in 0..PlazoOrigen
    /\ llego \in BOOLEAN /\ origenVioPedido \in BOOLEAN /\ origenVioCierre \in BOOLEAN
    /\ destinoVe \in EstadosOrigen

Init ==
    /\ pedido = "sin_pedido" /\ origen = "sin_enterarse" /\ prenda = "en_venta_origen"
    /\ anticipo = "sin_anticipo" /\ relojActivo = FALSE /\ diasRestantes = DiasApartado /\ espera = 0
    /\ llego = FALSE /\ origenVioPedido = FALSE /\ origenVioCierre = FALSE /\ destinoVe = "sin_enterarse"

Devuelve(a) == IF a = "cobrado" THEN "devuelto" ELSE a
SueltaPrenda(p) == IF p = "apartada_destino" THEN "en_venta_destino" ELSE p

----------------------------------------------------------------------------
(* Personas *)

ClientePide(conAnticipo) ==   \* el gerente de destino autoriza; destino aun puede creer que la prenda sigue en origen
    /\ pedido = "sin_pedido"
    /\ pedido' = "pedido"
    /\ anticipo' = IF conAnticipo THEN "cobrado" ELSE "sin_anticipo"
    /\ relojActivo' = (RelojDesde = "pedido")
    /\ UNCHANGED <<origen, prenda, diasRestantes, espera, llego, origenVioPedido, origenVioCierre, destinoVe>>

OtroClienteCompraEnOrigen ==
    /\ prenda = "en_venta_origen"
    /\ prenda' = "vendida_a_otro_en_origen"
    /\ UNCHANGED <<pedido, origen, anticipo, relojActivo, diasRestantes, espera, llego,
                   origenVioPedido, origenVioCierre, destinoVe>>

OrigenReserva ==
    /\ origenVioPedido /\ ~origenVioCierre /\ origen = "sin_enterarse" /\ prenda = "en_venta_origen"
    /\ origen' = "reservada" /\ prenda' = "reservada_origen"
    /\ UNCHANGED <<pedido, anticipo, relojActivo, diasRestantes, espera, llego,
                   origenVioPedido, origenVioCierre, destinoVe>>

OrigenDespacha ==   \* gana el despacho: si origen no ha visto el cierre, la prenda viaja igual
    /\ origen = "reservada" /\ ~origenVioCierre
    /\ origen' = "despachada" /\ prenda' = "en_camino"
    /\ UNCHANGED <<pedido, anticipo, relojActivo, diasRestantes, espera, llego,
                   origenVioPedido, origenVioCierre, destinoVe>>

DestinoRecibePrenda ==
    /\ prenda = "en_camino"
    /\ destinoVe' = "despachada"
    /\ IF pedido = "pedido"
       THEN /\ prenda' = "apartada_destino" /\ llego' = TRUE
            /\ relojActivo' = (relojActivo \/ RelojDesde = "llegada")
       ELSE /\ prenda' = "en_venta_destino" /\ UNCHANGED <<llego, relojActivo>>
    /\ UNCHANGED <<pedido, origen, anticipo, diasRestantes, espera, origenVioPedido, origenVioCierre>>

ClienteCompra ==    \* la comision es del vendedor que cierra esta venta
    /\ pedido = "pedido" /\ prenda = "apartada_destino"
    /\ pedido' = "vendido" /\ prenda' = "vendida_al_cliente"
    /\ anticipo' = IF anticipo = "cobrado" THEN "aplicado" ELSE anticipo
    /\ relojActivo' = FALSE
    /\ UNCHANGED <<origen, diasRestantes, espera, llego, origenVioPedido, origenVioCierre, destinoVe>>

ClienteCancela ==
    /\ pedido = "pedido"
    /\ pedido' = "cancelado" /\ anticipo' = Devuelve(anticipo) /\ relojActivo' = FALSE
    /\ prenda' = IF Falla = "no_libera_prenda" THEN prenda ELSE SueltaPrenda(prenda)
    /\ UNCHANGED <<origen, diasRestantes, espera, llego, origenVioPedido, origenVioCierre, destinoVe>>

OtroClienteCompraEnDestino ==
    /\ prenda = "en_venta_destino"
    /\ prenda' = "vendida_a_otro_en_destino"
    /\ UNCHANGED <<pedido, origen, anticipo, relojActivo, diasRestantes, espera, llego,
                   origenVioPedido, origenVioCierre, destinoVe>>

----------------------------------------------------------------------------
(* Sistema: sincronizacion, reloj y cierres automaticos *)

OrigenSeEnteraDelPedido ==
    /\ pedido # "sin_pedido" /\ ~origenVioPedido
    /\ origenVioPedido' = TRUE
    /\ UNCHANGED <<pedido, origen, prenda, anticipo, relojActivo, diasRestantes, espera, llego,
                   origenVioCierre, destinoVe>>

OrigenSeEnteraDelCierre ==
    /\ pedido \in Cerrado \ {"vendido"} /\ ~origenVioCierre
    /\ origenVioCierre' = TRUE
    /\ UNCHANGED <<pedido, origen, prenda, anticipo, relojActivo, diasRestantes, espera, llego,
                   origenVioPedido, destinoVe>>

DestinoSeEnteraDeLaRespuesta ==
    /\ destinoVe # origen
    /\ destinoVe' = origen
    /\ UNCHANGED <<pedido, origen, prenda, anticipo, relojActivo, diasRestantes, espera, llego,
                   origenVioPedido, origenVioCierre>>

OrigenNoTiene ==    \* la prenda ya se vendio en origen, o el pedido se cerro antes de reservar
    /\ origenVioPedido /\ origen = "sin_enterarse" /\ (prenda # "en_venta_origen" \/ origenVioCierre)
    /\ origen' = "no_disponible"
    /\ UNCHANGED <<pedido, prenda, anticipo, relojActivo, diasRestantes, espera, llego,
                   origenVioPedido, origenVioCierre, destinoVe>>

OrigenLibera ==     \* el cierre llego antes del despacho: la prenda vuelve a la venta en origen
    /\ origen = "reservada" /\ origenVioCierre
    /\ origen' = "no_disponible" /\ prenda' = "en_venta_origen"
    /\ UNCHANGED <<pedido, anticipo, relojActivo, diasRestantes, espera, llego,
                   origenVioPedido, origenVioCierre, destinoVe>>

DestinoAvisaQueNoHay ==
    /\ pedido = "pedido" /\ destinoVe = "no_disponible"
    /\ pedido' = "no_disponible" /\ relojActivo' = FALSE
    /\ anticipo' = IF Falla = "no_devuelve_anticipo" THEN anticipo ELSE Devuelve(anticipo)
    /\ UNCHANGED <<origen, prenda, diasRestantes, espera, llego, origenVioPedido, origenVioCierre, destinoVe>>

CuentaApartado == relojActivo /\ diasRestantes > 0
SinDespachar == {"sin_enterarse", "reservada"}
CuentaOrigen ==
    /\ espera < PlazoOrigen
    /\ IF PlazoLoCuenta = "destino" THEN pedido = "pedido" /\ destinoVe \in SinDespachar
                                    ELSE origenVioPedido /\ origen \in SinDespachar

PasaUnDia ==
    /\ CuentaApartado \/ CuentaOrigen
    /\ diasRestantes' = IF CuentaApartado THEN diasRestantes - 1 ELSE diasRestantes
    /\ espera' = IF CuentaOrigen THEN espera + 1 ELSE espera
    /\ UNCHANGED <<pedido, origen, prenda, anticipo, relojActivo, llego, origenVioPedido, origenVioCierre, destinoVe>>

VenceApartado ==
    /\ pedido = "pedido" /\ relojActivo /\ diasRestantes = 0
    /\ pedido' = "vencido" /\ anticipo' = Devuelve(anticipo) /\ relojActivo' = FALSE
    /\ prenda' = SueltaPrenda(prenda)
    /\ UNCHANGED <<origen, diasRestantes, espera, llego, origenVioPedido, origenVioCierre, destinoVe>>

DestinoVencePlazo ==   \* descartado: destino no sabe si la prenda ya salio (ver NoSeNiegaLoQueViaja)
    /\ PlazoLoCuenta = "destino" /\ PlazoOrigen > 0 /\ pedido = "pedido" /\ espera = PlazoOrigen
    /\ destinoVe \in SinDespachar
    /\ pedido' = "sin_respuesta" /\ anticipo' = Devuelve(anticipo) /\ relojActivo' = FALSE
    /\ UNCHANGED <<origen, prenda, diasRestantes, espera, llego, origenVioPedido, origenVioCierre, destinoVe>>

OrigenVencePlazo ==    \* origen no despacho a tiempo: suelta la prenda y responde que no hay
    /\ PlazoLoCuenta = "origen" /\ PlazoOrigen > 0 /\ espera = PlazoOrigen
    /\ origenVioPedido /\ origen \in SinDespachar
    /\ origen' = "no_disponible"
    /\ prenda' = IF prenda = "reservada_origen" THEN "en_venta_origen" ELSE prenda
    /\ UNCHANGED <<pedido, anticipo, relojActivo, diasRestantes, espera, llego,
                   origenVioPedido, origenVioCierre, destinoVe>>

Fin == pedido \in Cerrado /\ prenda \in Reposo /\ UNCHANGED vars

Sistema == \/ OrigenSeEnteraDelPedido \/ OrigenSeEnteraDelCierre \/ DestinoSeEnteraDeLaRespuesta
           \/ OrigenNoTiene \/ OrigenLibera \/ DestinoAvisaQueNoHay
           \/ PasaUnDia \/ VenceApartado \/ DestinoVencePlazo \/ OrigenVencePlazo

Next == \/ ClientePide(TRUE) \/ ClientePide(FALSE) \/ OtroClienteCompraEnOrigen \/ OrigenReserva
        \/ OrigenDespacha \/ DestinoRecibePrenda \/ ClienteCompra \/ ClienteCancela
        \/ OtroClienteCompraEnDestino \/ Sistema \/ Fin

(* Solo el sistema es justo: las personas pueden no hacer nunca su parte. *)
Spec == Init /\ [][Next]_vars /\ WF_vars(Sistema)

----------------------------------------------------------------------------
(* Reglas *)

\* El anticipo nunca queda en el aire: se aplica a la venta o se devuelve.
AnticipoResuelto ==
    /\ pedido \in Cerrado \ {"vendido"} => anticipo \in {"sin_anticipo", "devuelto"}
    /\ pedido = "vendido" => anticipo \in {"sin_anticipo", "aplicado"}

\* Una prenda apartada siempre tiene un cliente esperandola.
ApartadaSoloConPedido == prenda = "apartada_destino" => pedido = "pedido"

\* El plazo no le quita la prenda a un cliente antes de que la prenda llegue.
VenceSoloSiLlego == pedido = "vencido" => llego

\* Lo que origen reservo o despacho coincide con donde esta la prenda.
RespuestaYPrendaCoinciden ==
    /\ prenda = "reservada_origen" => origen = "reservada"
    /\ prenda \in {"en_camino", "apartada_destino"} => origen = "despachada"
    /\ (prenda = "vendida_al_cliente") = (pedido = "vendido")

\* Al cliente nunca se le dice que no hay cuando la prenda ya salio hacia el.
NoSeNiegaLoQueViaja == pedido \in {"sin_respuesta", "no_disponible"} => origen # "despachada"

\* Un pedido no espera para siempre a la tienda origen.
NoEsperaAlOrigen ==
    (pedido = "pedido" /\ origen \in {"sin_enterarse", "reservada"}) ~> (pedido # "pedido" \/ origen = "despachada")
=============================================================================
