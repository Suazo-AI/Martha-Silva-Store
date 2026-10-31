# Evolución preservada de Martha Silva

Se conservan los commits originales accesibles, con sus fechas, SHA y parentesco.
Frontend y SAVIA divergían: dos merges reúnen ambas líneas. Las últimas tres
publicaciones existían como runtime congelado y deltas aislados; se importan
como commits nuevos con su procedencia. No se afirma que cada candidato se publicara.

## Cambios de la tienda, en orden

| Etapa | Fuente original | Resultado / evidencia |
| --- | --- | --- |
| Base GitHub, 24 octubre | `3b004916` | Demo anterior de 9 páginas y 2 productos; CI histórica no cubre cambios posteriores |
| Recuperación de la tienda | `7f29cf5a`, `c0b0c1f9`, `17b044df` | 47 páginas, 40 productos, 120 variantes; 777/778 medios históricos y publicación aislada |
| Usabilidad y revisión de fotos | `7cbba2e1` | Presentación y evidencia de revisión de imágenes |
| Retirada de prototipo SAVIA público | `d2ad2000`, `98a03b30` | Se conserva la tienda principal; la caja separada está fuera del runtime actual |
| Fotos nupciales y ES/EN | `b4952fbd` a `c6646107` | Ajustes, contexto de navegación, elección de idioma y caption de búsqueda |
| Portada/editorial Instagram | `8ef27660`, `8b251467` | Seis fotos autorizadas y derivados responsive |
| Compartir producto | `e9e9609b`, `8154aed5`, `d4536b4b` | Compartir nativo, copiar/enlace manual, ES/EN |
| Galería del vestido verde | `704b2e16`, `403d0d2f`, `2785ca7b` | Offset bajo cabecera, límites de viewport y comparación histórica antes/después |
| Historial e ilustraciones | `e2a47596`, `a69c4a78` | Contexto de navegación, soporte aprobado y retirada del enlace admin del footer |
| Primer candidato de carrusel | `fd760def` | Candidato de fuentes, no acreditado como publicación |
| Bordes del vestido verde | `e7cf4b16` | Derivados con padding incorporado recortado; originales conservados |
| Luxury revisión 3 | nuevo `4b883b77` | Snapshot publicado `26c01241`; fuentes, inventario de imágenes generadas y límites de fidelidad/QA |
| Galería horizontal final | nuevo `a9ffb399` desde `b8b1ee89` | Solo app/CSS; publicación `a29e4d01`, corrección de resize, revisión visual pendiente |
| Marcos proporcionales | nuevo `d39646dd` desde `7b3ce641` | Solo app/CSS; publicación `601268a3`, proporciones y columna centrada; sin regenerar fotos |

`b8b1ee89` y `7b3ce641` son SHA de fuentes aisladas previas, no ancestros de esta
rama. Sus bytes se importaron y verifican contra manifiestos. Los commits nuevos
tienen fecha real de importación, sin fingir fechas históricas.

## Publicaciones recientes, UTC

| Publicada | Versión | Deployment |
| --- | --- | --- |
| 2026-10-30 01:16:52 | `26c01241-dbdc-4af7-bfef-37cedff5ce23` | `1e0a20b7-88f7-4d82-b17c-0a3331e741d6` |
| 2026-10-30 03:14:18 | `a29e4d01-d512-4ac5-98b0-80aec872a70b` | `0448a761-19d3-4147-a39a-5e4281cf70f2` |
| 2026-10-30 04:50:10 | `601268a3-81ce-4277-a8ef-cb2e84d2fbb1` | `3abb96e2-6a47-4b3e-b07e-a4aec258468f` |

Recibos sanitizados, selección de medios y hashes:
[`evidence/releases/20261030`](../evidence/releases/20261030/).
La última fila es el snapshot importado, no una publicación nueva causada por el push.

## SAVIA, fuera del runtime público

Se conservan V1, contratos, libro sintético V2, intentos durables, idempotencia,
reservas/cancelación y harness de desarrollo. La línea staff continúa con
`8fcfd620`, `3d8f11de`, `4a9c11e4`, `c927eed3`, `744f245b`, `023364fd`:
auth/roles, consultas paginadas, Owner/B1 y aislamiento por sucursal.

El merge `003573ea` incorpora esa fuente, conservando historia y separación
de `dist/`. El anterior `68de299c` concilia frontend/fotos. El backend requiere
pruebas y entorno propios; este push no lo conecta a la demo.

Lista completa de commits originales, fechas, árboles y padres:
[`preserved-history.json`](../evidence/releases/20261030/preserved-history.json).

```sh
git log --graph --oneline Tony
git log --reverse --topo-order 3b004916..Tony
git show <sha>
```
