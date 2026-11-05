# D-029: decisión y guion preparados

Fecha: 2026-11-04, America/Managua. Host comprobado: SUAZO-PC.

## Resultado

Jason adoptó reconstrucción guiada con Martha usando datos ficticios.
El [guion](../sprint-20261104/GUION-RECONSTRUCCION-MARTHA.md) incluye frases para leer,
preguntas, aritmética, evidencia necesaria, comprobación futura del producto y hoja sin respuestas.
El cuestionario existente pasa a ser complemento, sin fecha confirmada ni solicitud de prendas reales.

Se actualizaron DECISIONS, PROJECT-STATUS, C1/C2 del ledger y referencias vigentes.
Trello: cuatro descripciones con readback exacto. C2 permanece todo; protección main completa,
stock y variables incompletos. [Recibo saneado](decision-029-receipt.json).
Las respuestas, registros privados y credenciales no forman parte de esta publicación.

## Revisión independiente

Crítico `gpt-6.1-sol/high`: apto, sin hallazgos materiales. Aritmética y separación de
variantes correctas. Los bloques suman 26 minutos, más margen para notas; duración estimada.
Jurado `gpt-6-astra/high`: revisión independiente del guion, registro y comprobaciones documentales.
[Crítico](decision-029-critic.md) y [jurado](decision-029-jury.md).
El coordinador acepta únicamente lo sustentado por inspección y resultados de las comprobaciones.
No existe todavía evidencia de uso del guion con Jason o Martha ni de duración real.

Resultados inspeccionados por el coordinador: `python tests/test_progress.py`, exit 0,
23 pruebas; `python tools/export_progress.py --verify`, exit 0, 15 hashes;
`python tools/delivery_status.py --check`, exit 0, 34 items; `git diff --check`, exit 0.
El jurado comprobó 83 destinos locales en seis Markdown, ninguno ausente; ocho anclas
no verificadas. El coordinador comprobó aparte los enlaces locales de este registro posterior.
Los reportes se copiaron después del escaneo y su existencia fue comprobada.
[Resultados saneados](decision-029-receipt.json). No hay cambios de código ni runtime.
La suite general Windows no se repitió: conserva el bloqueo documentado WinError 1314
en fixtures de enlaces simbólicos. No se modificaron privilegios ni pruebas para ocultarlo.

## Límites y siguiente acción

No se contactó a Martha ni se coordinó o realizó la conversación. No se ejecutó SISFAIN
ni SAVIA, no se fusionó ni desplegó. La entrevista no equivale a aceptación del ensayo.
C1/C2/C9/C10 conservan las brechas vigentes. El guion deja temas omitidos con función
responsable y próxima consulta, en lugar de rellenarlos con supuestos.

Jason coordina disponibilidad para unos 30 minutos y usa el guion. Comprobación de cierre
de esa acción: resumen saneado validado por Martha, clasificado como declarado/observado/pendiente,
con huecos y responsables. Después el coordinador prepara la matriz proceso → requisito → prueba → brecha.

Lección aplicada: una entrevista inicial debe seguir una operación completa y conservar
lo desconocido. Aumentar el número de preguntas no sustituye evidencia del recorrido.
