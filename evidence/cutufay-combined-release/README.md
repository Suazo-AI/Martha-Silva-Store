# Martha Silva — combinado final v4 (Back + dos ilustraciones AI de apoyo)

**Entrega técnica final aceptada por fuente y evidencia automatizada. Publicación condicionada al acceso y control del publicador. No publicada por este agente. Safari/iPhone/VoiceOver: NOT_RUN.**

App final: `aa0528f71c3a23410dd7c2c0151427826f800e8f78a8057fe60d14427dcd89e8` (78,861 bytes). Base registrada: `704b2e160106b709880ad7c22febd25adb6181d6`. El publicador asignará el nuevo commit real; este ZIP no inventa un Git SHA ni contiene `deployment.json`.

## Qué integrar

`source-overlay/` contiene **exactamente seis archivos**: app, styles, dos PDP y los dos PNG aprobados. Se copian a esos mismos paths sobre una fuente A verificada. El runtime probado contiene **904 rutas = 898 A idénticas + 4 modificadas + 2 nuevas**. El marcador posterior del publicador es separado: 905 archivos físicos.

No usar los apps combinados anteriores `1bb…`, `e269…` ni el viejo Back-only `be37…`. El v4 incluye correcciones adicionales de observadores, enlaces a originales, fragmentos nativos, idioma y eventos de hash obsoletos. No volver a aplicar otro overlay AI encima. Los módulos en `reference/not-runtime/` ya están integrados en el app: no cargarlos como scripts extra.

Las imágenes AI son ilustraciones de apoyo con disclosure visible, no sustitutos auténticos. Se conservan catálogo, fotos, SKU, formulario y galería; 40 productos, 120 variantes y 170 fotos seleccionadas presentes. La recuperación histórica sigue **777/778**, sin inventar la faltante. El ZIP no incluye medios originales ni una baseline completa.

## Tests: conservar la excepción, no ocultarla

El agregado terminó en 0. El resultado final es **`pass_with_documented_fixture_adaptation`**, no un PASS original sin excepciones. El test Green original fue **5/6, exit 1** por una frontera estática de CSS que asumía EOF; su informe y log están incluidos. Una copia aprobada por el juez delimita el bloque original con guard de prefijo A y sufijo AI, conservando las assertions: **6/6**. Está solo en `evidence/green-fixture/`; los tests de la fuente candidata no fueron modificados ni se repitió el agregado. No sumar 5 + 6 como 11 casos.

Focales finales: **15 compuestos distintos (14 + 1 vendor real sin fetch), 24 Back, 20 AI y 6 de alcance**. La prueba con Barba real sigue siendo JSDOM/sin fetch, no Safari, renderizado o lifecycle completo de red. Las condiciones de publicación y QA real están en el juez final y `INTEGRATION-AND-ROLLBACK.md`.

## Integridad y operación

Verificar `SHA256SUMS` y `PACKAGE-MANIFEST.json`; comprobar guards A antes de aplicar los seis archivos. Si la fuente/destino avanzó desde A, detener la copia automática y reconciliar cambios. Los manifiestos raw SHA256 y upload hash son distintos; los últimos son metadatos, no una solicitud API.

El helper portable solo deriva expectativas desde los seis archivos y el manifiesto A. No instala, construye, prueba, empaqueta ni publica. Los logs y scripts de tests se conservan sin reescribir y pueden contener rutas del workspace original: son evidencia, no una instalación portable de la suite.

El rollback correcto es al **A completo**, no solamente al app: debe revertir los cuatro textos y las dos rutas AI nuevas. La versión A histórica está identificada; el publicador debe verificarla de nuevo, junto con destino/estado actual, antes de mutar. No hay credenciales, dependencias instaladas ni scripts automáticos de subida en este ZIP.
