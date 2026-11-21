# Corrección de regresiones del catálogo

Host: `SUAZO-PC`, Windows. Rama: `Tony`. Fecha: 31 de octubre de 2026 UTC.

## Reproducción y causa

`node --test tests/original-catalog.cjs` reprodujo 3 fallos entre 6 pruebas,
exit 1. Dos comprobaciones aplicaban el contrato fotográfico anterior al catálogo
luxury. La tercera solo contaba `/research/assets/` y exigía más de 700 referencias;
ignoraba `/generated-luxury/`.

El catálogo actual coincide con la publicación preservada
`601268a3-81ce-4277-a8ef-cb2e84d2fbb1`, SHA-256 de `catalog.js`:
`1495e8a10a2cde56ddb0087051c327949389f775977f41b7d4b676f37f3cd343`.

## Corrección

- La selección actual se contrasta con `luxury-selected-assets.json`, que ya
  existía antes de esta corrección: 152 imágenes de producto, 40 productos.
- Se comprueban rutas, bytes, SHA-256, firma PNG, dimensiones nativas,
  descriptores responsive y 202 referencias únicas de imagen/vídeo.
- Las 774 referencias del fixture histórico siguen comprobándose por separado.
  Se conservan los 22 derivados Green y los hashes de sus 18 originales.
- El fixture nuevo solo admite 22 campos de nombre/descripción en 18 productos,
  extraídos del catálogo publicado identificado por el hash anterior.
  Precios, stock y las 120 variantes siguen comparándose contra la captura original.
- Los casos negativos rechazan cambios de precio/stock/variante, imagen ausente,
  imagen de otro producto y un descriptor de ancho falso.
- `tests/asset-audit.py` conserva las 170 fotos de las capturas históricas y
  comprueba las 152 imágenes de la publicación contra el manifiesto independiente.
- Los atributos LF impiden convertir los textos canónicos a CRLF en Windows.
  El checkout inicial alteraba los hashes; se restauraron bytes exactos de Git.

No cambian catálogo, UI, medios, fixtures históricos, manifiestos de publicación,
runner ni workflows. Los textos canónicos coinciden byte a byte con `HEAD` anterior.

## Comprobaciones

- `node --test tests/original-catalog.cjs`: PASS, 9/9, sin omisiones.
- `python tools/verify_release_snapshot.py`: PASS; 1081 archivos públicos,
  1082 archivos dist, 47 páginas, 40 productos y 120 variantes.
- `python tests/build.py`, mediante el runner completo: PASS; dos builds idénticos.
- `python tools/export_progress.py --verify`: PASS, 15 hashes preservados.
- Auditoría sin creación de symlinks: PASS, 4/4 métodos, incluido el conteo corregido.
- Backend, adaptadores y migración del catálogo: PASS mediante el runner.
- Runner portable y helper histórico de sincronización: PASS.
- Frontend: PASS, 29/29 simulaciones DOM; localización: PASS, 17/17.
- Estructura: PASS, 47 páginas; sintaxis: PASS, 19 archivos JavaScript.

`python tests/check.py --install` ejecutó las etapas iniciales y se detuvo en
la auditoría: Windows deniega crear symlinks con `WinError 1314`. El primer
intento también detectó el conteo 169/152, corregido y comprobado después.
La suite de staging tiene el mismo impedimento en dos casos; sus otros ocho pasan.
No se cambian permisos de Windows ni se omiten controles en CI.

La aceptación completa exige `python tests/check.py --install` aprobado en
Linux por **Tony source snapshot**, asociado al SHA publicado. El resultado y los
logs quedan en GitHub Actions. **Progress documentation** debe aprobar recibo,
pruebas de sincronización y hashes. El agente comprueba ambos antes de entregar.

## Límites y siguiente acción

jsdom no acredita QA visual, Safari, móvil, pagos reales ni producción. La
recuperación histórica sigue en 777/778 archivos; no se declara completa.
No se ejecutan SQL, C#, Docker, certificados ni despliegues.

Lección aplicada: una prueba de preservación histórica y una prueba de publicación
actual necesitan contratos distintos con evidencia independiente. El conteo de
archivos nunca sustituye la verificación de su identidad.
