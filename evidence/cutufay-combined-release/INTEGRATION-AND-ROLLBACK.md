# Entrega combinada: Back + dos ilustraciones AI de apoyo

**V4 final: fuente y evidencia automatizada aceptadas con adaptación documentada de un fixture; autorización de publicación condicionada al control y acceso del publicador. No publicada por este agente.** V1/V2/V3 y el Back-only anterior son históricos, no esta entrega final.

## Guard de esta combinación

- Base registrada: `704b2e160106b709880ad7c22febd25adb6181d6`.
- Manifiesto runtime A: SHA256 `2385d52dbef90e8bfedb65864d05efc5635a2ec709623bde86547d0104e7a47b`.
- Receipt de combinación congelado: SHA256 `19ca37a9351820e2fb7481d8e95580888fe589ef1d00eba08a4d8c6d491367d2`.
- App combinado: SHA256 `aa0528f71c3a23410dd7c2c0151427826f800e8f78a8057fe60d14427dcd89e8`, 78,861 bytes.
- El app contiene el prefijo Back revisado SHA256 `f30cca0b19ab1df423baf5bbcbd995662c3e9b5297e75daae777f6141871c0bd` (74,724 bytes), seguido del módulo AI revisado (4,137 bytes). **No ensamblar sobre el antiguo Back-only `be37…`**: faltan sus correcciones de fragmentos/idioma/evento obsoleto. El app completo `aa0528…` es el payload final.

El nuevo runtime debe contener **904 rutas: 898 idénticas a A + 4 archivos de texto modificados + 2 PNG nuevos**. Se conservan todas las 902 rutas A; no hay eliminaciones. Con el `deployment.json` separado que genere el publicador: **905 archivos físicos**.

## Únicas seis entradas permitidas

| Fuente | Runtime | SHA256 final | Bytes | Upload hash Cloudflare |
| --- | --- | --- | ---: | --- |
| `src/app.js` | `app.js` | `aa0528f71c3a23410dd7c2c0151427826f800e8f78a8057fe60d14427dcd89e8` | 78861 | `8f4df8d34f12f81ad6e5295ad88d6a6a` |
| `build-inputs/static/styles.css` | `styles.css` | `14275118ce05a69322963373243dc723294292d5caca78802d2f9cf1ed65d186` | 64864 | `4721698f86ee2f3e8a00038e38cb8c2c` |
| `build-inputs/static/producto-blanco-perlado-sirena.html` | `producto-blanco-perlado-sirena.html` | `9e47db6124a43c8ebb88096977047250231f59cd08a2f732f279f373bc5dc6d8` | 247126 | `cf4010f4f0f5acc1d1771d8aa4be233b` |
| `build-inputs/static/producto-rosa-empolvado-pedreria.html` | `producto-rosa-empolvado-pedreria.html` | `eb9fc145b5c0311ee517e0c9c00a753dc228142ff0fa8ccc64c5cc6fd6d71039` | 248851 | `3893ef2e2257f39010b078d06430aef8` |
| `build-inputs/static/generated-illustrations/blanco-perlado-sirena-g1-gen-001-48170acd71bf.png` | `generated-illustrations/blanco-perlado-sirena-g1-gen-001-48170acd71bf.png` | `48170acd71bf1dae2f797cfb22c8dafe522d990de03c9b6ce5ce63a456b67ffe` | 1623549 | `071aeb200f44663c61d83e7c74caca09` |
| `build-inputs/static/generated-illustrations/rosa-empolvado-pedreria-g1-gen-001-8e13cba8e436.png` | `generated-illustrations/rosa-empolvado-pedreria-g1-gen-001-8e13cba8e436.png` | `8e13cba8e436ab0a4aa381db6a7d99e44f8624acb7a73eb62d4731ef0a218413` | 1737603 | `44e2438dce0b0f3fef89ff9e49d758ed` |

`manifests/six-file-delta.json` añade los guards anteriores de A y distingue reemplazo versus alta. `prepare.py` copia `src/app.js` a `dist/app.js` y conserva byte por byte los paths relativos bajo `build-inputs/static/`. No desplegar los módulos de autoría como scripts extra ni aplicar otra vez un overlay AI sobre este combinado.

Los PNG son las dos ilustraciones de apoyo aprobadas, no fotografías auténticas ni reemplazos de galería. Conservar disclosure, enlace a fotos originales, separación del formulario/galería y sus bytes exactos; no recomprimir, recortar, regenerar ni añadirlos a las listas del catálogo. El catálogo y los 170 originales seleccionados quedan fuera de este delta.

## Evidencia que debe acompañar el artefacto final

1. Receipt exacto anterior y seis hashes congelados.
2. Resultado de build/suite **del app combinado `aa0528…`**, no solamente los PASS separados Back `be37…` o AI. El propietario único de tests conserva esta evidencia.
3. Comparación del inventario real: 904 rutas, 898 sin cambio, exactamente cuatro modificaciones y dos altas; ninguna desviación o asset extra.
4. Revisión combinada de fuente y las limitaciones reales de navegador. Safari/iPhone/VoiceOver no se declaran verificados por heredar los tests de componentes.
5. SHA del commit real integrado y verificación del destino actual por el publicador antes de mutar. Si hay cambios posteriores a A ajenos a esta entrega, detener aplicación automática y reconciliar.

El helper de este directorio deriva expectativas sin construir ni ejecutar tests. Lee los seis payloads, no los 904 cuerpos. Las otras 898 entradas se heredan del manifiesto A verificado; la igualdad del build real debe acreditarla el verificador/publicador. Los 32 hex de upload se calculan como `SHA256(base64(bytes) + extensión_sin_punto)[:32]`; el marcador conserva SHA256 bruto de 64 hex. No intercambiarlos.

## Resultado automatizado y excepción documentada

Informe final del tester: SHA256 `88ae8636573498a4ea53657d4660066e580210f8e5729afe418ad9f249a23c46`, estado `pass_with_documented_fixture_adaptation`. El agregado terminó en 0. El Green original produjo **5/6, exit 1** porque su prueba estática asumía que el bloque Green continuaba hasta EOF; el CSS AI añadido rompía esa frontera de la prueba. Se conserva el informe/log original. Una **copia de evidencia** aprobada por el juez delimita el bloque original con marcador único y hashes de prefijo A/sufijo AI, sin cambiar assertions ni código de la aplicación: **6/6**. No contar esos resultados como 11 tests ni ocultar el exit 1 original. Los tests dentro de la fuente candidata permanecen intactos.

Pruebas focales: 15 casos compuestos distintos (14 + 1 de vendor real sin fetch), 24 Back, 20 AI y 6 de alcance. JSDOM/vendor sin fetch no equivale a navegador renderizado, Safari/iPhone, BFCache real o VoiceOver. Los informes de componentes anteriores no sustituyen estos resultados finales.

## Marcador y destino

El publicador debe generar `deployment.json` desde los 904 archivos del build final, con el **nuevo commit real**. Nunca usar `704b…`, el hash de app o un SHA inventado como identidad del código combinado. El marcador no se cuenta dentro de sus propias 904 entradas.

Este directorio no contiene credenciales, comandos de subida automáticos ni resultados de acceso a Cloudflare. La disponibilidad actual de Tony y del publicador sigue siendo un requisito operativo. No se consultó hoy la API de versiones/tráfico desde esta tarea; 401/403 son bloqueos, no motivo para reintentar o ampliar acceso.

## Rollback del combinado

Referencia históricamente confirmada por el publicador, pendiente de verificación actual antes de actuar:

- Versión A completa: `a8668b7b-9fe0-4635-ac5a-01033ae96e2b`.
- Referencia de tráfico/despliegue: `1f24157b-6fc0-40fa-8aec-5a861dc89587`.
- Fuente A: `704b2e160106b709880ad7c22febd25adb6181d6`.

**Volver solamente al app A no revierte esta combinación.** Un rollback completo hacia A debe restaurar las cuatro entradas de texto y excluir las dos rutas AI nuevas, preferentemente retornando al artefacto/version A completo de 902 runtime, con su marcador A. No confundir el ZIP Back-only con una versión Cloudflare publicada: ese ZIP es evidencia técnica, no un ID de rollback remoto.

Antes del rollback, confirmar Worker/cuenta autorizados, existencia y correspondencia de la versión A, estado de tráfico actual y ausencia de cambios nuevos ajenos que se perderían. Ante fallo de hashes/marcador o regresión material en la aceptación autorizada, detener promoción y aplicar el procedimiento del publicador autorizado. Verificar después A, inventario 902 y flujo afectado. Este plan no ejecutó ni afirma ese rollback.
