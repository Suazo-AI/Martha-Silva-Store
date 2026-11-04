# C6: control de publicación de la unión puntual

Veredicto: **APTO en revisión estática del control de publicación solicitado.**
No encontré un bypass nuevo ni una exención para commits futuros.
La única ampliación del conjunto congelado es `b6bc0396bb7d53359d23b806a3177edc194c8e62`.
Este dictamen no acepta C6 funcional ni sustituye la suite del control de publicación.

Juicio: `savia-c6-judge-20261104`, continuación del mismo lote autorizado.
Modelo/razonamiento: `gpt-6.1-sol / xhigh`. Host: `SUAZO-PC`.
Fecha: `2026-11-04` UTC.
El primario comunicó la autorización explícita de Jason para esta única unión y excepción de SHA.
No amplié esa autorización.

## Alcance y evidencia directa

Revisé exclusivamente estas fuentes del índice canónico:

- `tools/progress.py`.
- `docs/progress-imports/pr2-b6bc0396.json`.
- `docs/AUTO-SYNC.md`, adición de la unión puntual.

Leí los blobs con `git show :<ruta>` y comparé el control con `HEAD`.
No había diferencias sin indexar en esas tres rutas al terminar las lecturas.
No ejecuté `progress.py`, sus hooks, sus pruebas, API, SQL, navegador ni runtime del producto.
No consulté GitHub ni modifiqué el checkout, índice, commits o refs.
El único archivo escrito por este juez es este informe.

SHA-256 de los bytes Git revisados:

| Fuente indexada | SHA-256 |
|---|---|
| `tools/progress.py` | `73b72fd8737d08d358370518c33a05e8f8954efab3bbf6380910d4df95b8ee19` |
| `docs/progress-imports/pr2-b6bc0396.json` | `b85fcdb199afa3d6acb3ee628796548bad4cf862c15b8c88973d63fc905b9dbe` |

El nuevo manifiesto Git contiene LF y no contiene CR.
No usé el hash del archivo CRLF del árbol de trabajo para aceptar el pin.

## Checks del control de publicación

| Check | Resultado | Evidencia |
|---|---|---|
| Conservar los 17 registros anteriores | Cumplido | Comparación estructural completa: los primeros 17 registros son idénticos al manifiesto activo anterior `pr2-9719d8ed.json`. |
| Conservar contenido y formato anteriores | Cumplido | Al retirar solo el registro 18 y restaurar `head`, la serialización reproduce exactamente los bytes LF del manifiesto anterior. |
| Añadir un único SHA | Cumplido | `PR2_IMPORT_COMMITS` conserva el prefijo anterior y añade solo `b6bc0396bb7d53359d23b806a3177edc194c8e62`; 18 registros únicos. `tools/progress.py:25-44`. |
| Vincular cabecera y lista congelada | Cumplido | La única diferencia de cabecera del JSON es `head`; la tupla coincide exactamente con los 18 commits del manifiesto. `tools/progress.py:202-208`. |
| Fijar los bytes Git correctos | Cumplido | SHA-256 calculado del blob indexado igual al pin en `tools/progress.py:21-22`; verificación obligatoria en `195-200`. |
| Vincular árbol, padre, ruta y blob de b6 | Cumplido | Lectura directa de ese único objeto Git y de su blob; registro idéntico a los datos abajo. `pr2-b6bc0396.json:604-614`. |
| Mantener la lógica del control | Cumplido | Comparación AST del archivo completo: idéntico al anterior al neutralizar solo `PR2_IMPORT_MANIFEST`, `PR2_IMPORT_SHA256`, `PR2_IMPORT_HEAD` y `PR2_IMPORT_COMMITS`. |
| Mantener filtros de publicación | Cumplido estáticamente | `verify_import` sigue invocando `describe(changes(commit), commit)`; conserva filtros de ruta, contenido, tamaño, secretos y modo. `tools/progress.py:93-144,209-219`. |
| Exigir recibo al commit de unión | Cumplido estáticamente | El commit de unión será otro SHA; no pertenece a la tupla fija. La ruta normal exige exactamente un recibo añadido y valida sus archivos. `tools/progress.py:223-234`. |
| Exigir recibos futuros | Cumplido estáticamente | La excepción depende de pertenencia exacta del SHA a la tupla, no de rama, padre, fecha, ruta o prefijo de hash. `tools/progress.py:195-208,227-233`. |
| Conservar guardas de publicación | Cumplido estáticamente | Repositorio, rama `Tony`, origin exacto, escaneo de cada commit y mensaje, HEAD estable, push sin force y readback remoto permanecen idénticos. `tools/progress.py:81-90,237-258`. |
| Conservar manifiestos previos | Cumplido | El diff indexado de `docs/progress-imports` solo añade `pr2-b6bc0396.json`; no modifica los manifiestos anteriores. |
| Documentar el límite de la excepción | Cumplido | El nuevo apartado de `docs/AUTO-SYNC.md` identifica ambos SHAs, pin LF, recibo de unión obligatorio y ausencia de aceptación C6/C8. |

No volví a escanear los objetos de los 17 commits anteriores.
Comparé sus registros congelados y examiné únicamente el objeto Git añadido.

## Registro 18 cotejado con Git

- Commit: `b6bc0396bb7d53359d23b806a3177edc194c8e62`.
- Árbol: `df8e64e568d9260107e5c5d5d6fa368ed148bc84`.
- Único padre: `6aeb9a35f45331ace85ac48dc19bfd9264b0f722`.
- Único cambio: `M tests/golden-path/browser_path.mjs`.
- Modo: `100644`.
- Blob: `b97b62c115914a861316e47d4cb5f6d712c76db5`.
- SHA-256 del blob: `178d42bcc034870159ee20b22edf81c93a337edb963ec03430af311bf67d0666`.

Ese hash corresponde al commit externo b6 sin la corrección de propiedad Chrome.
La propuesta combinada del driver tiene otro hash, ya fijado en `PROPOSAL-REVIEW.md`.
El control revisado no confunde el blob histórico importado con el contenido resuelto del commit de unión.
El recibo normal del commit de unión deberá vincular sus propios bytes finales.

## Hallazgos, pendientes y próximo cierre

**Sin hallazgos nuevos en este control estático.**

La suite de `progress.py` sigue pendiente de resultado verificable del ejecutor.
El primario informó un timeout anterior de `90` segundos y una corrida con límite mayor.
No repetí esa suite ni atribuyo a esta lectura un resultado de ejecución.
Propietario: ejecutor, con verificación del primario.
Cierre: resultado completo de la suite y recibo normal del commit de unión.

La publicación y su readback remoto también corresponden al primario.
No los doy por realizados desde un índice aún pendiente de integración.
Si cambia alguno de los dos blobs fijados arriba, este dictamen requiere el delta correspondiente.

H1 y H2 conservan sus condiciones de cierre y siguen esperando el CI real del candidato combinado.
Los 17 checks funcionales permanecen definidos en `PRE-FINAL-REVIEW.md` y `PROPOSAL-REVIEW.md`.
Esta revisión del control de publicación no modifica su contrato ni su estado de aceptación.

Uso: el entorno no expone tokens consumidos ni presupuesto restante por API.
