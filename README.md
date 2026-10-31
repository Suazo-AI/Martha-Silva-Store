# Martha Silva Store

La rama `Tony` conserva la historia real y las fuentes de la ultima demo publicada.
Este push no despliega la web ni modifica `main`. [Cronologia](docs/UPDATE-HISTORY.md).

**Demo:** <https://martha-silva-preview.martha-silva-denis.workers.dev/>.
Ultimo recibo conservado: version `601268a3-81ce-4277-a8ef-cb2e84d2fbb1`, publicada
2026-10-30 a las 04:50:10 UTC. `dist/` reproduce sus 1081 archivos publicos;
`README.txt` es un auxiliar adicional excluido del manifiesto publico.
La integridad de bytes no acredita una comprobacion visual actual del sitio.

Incluye 47 paginas, 40 productos de muestra, 120 variantes, ES/EN, portada editorial,
compartir productos, historial y galeria horizontal con marco proporcional.
Precios, pedidos y existencias del simulador no son datos comerciales autoritativos.
No hay pagos bancarios productivos implementados.

## Fuentes y evidencia

| Contenido | Ubicacion |
| --- | --- |
| Comportamiento editable | `src/` |
| HTML, CSS, catalogo y medios | `build-inputs/static/` |
| Salida ensamblada | `dist/` y `prepare.py` |
| Cronologia y versiones | [UPDATE-HISTORY](docs/UPDATE-HISTORY.md) |
| Estado y pendientes | [PROJECT-STATUS](docs/PROJECT-STATUS.md) |
| Hashes, imagenes y recibos | [Entregas](evidence/releases/20261030/) |
| Comprobaciones reproducibles | [SYNC-VERIFICATION](docs/SYNC-VERIFICATION.md) |
| Original separado e inerte | [originals/cloudflare](originals/cloudflare/README.md) |
| SAVIA staff | [SAVIA-INTERNAL](SAVIA-INTERNAL.md), `backend/`, `contracts/`, `dev/savia-staff-ui/` |
| Seguridad y contribuciones | [SECURITY](docs/SECURITY.md), [AGENTS](AGENTS.md) |

Se conservan fotografias historicas y derivados. La ultima demo tambien contiene
**156 PNG unicos generados con IA**, en 158 ubicaciones: son ilustraciones de demo,
no fotografias documentales recuperadas ni garantia de fidelidad del vestido real.
No alcanzan Full HD; diez registros historicos carecen de listas completas de
referencias y persisten limites de continuidad visual. Ver
[luxury-selected-assets.json](evidence/releases/20261030/luxury-selected-assets.json).
La recuperacion historica permanece en 777/778 medios; el JPEG ausente no se invento.

## Ejecutar localmente

Con Python 3, desde la raiz del checkout:

```sh
python prepare.py
python -m http.server 8000 --bind 127.0.0.1 --directory dist
```

Abrir <http://127.0.0.1:8000/>; Ctrl+C detiene el servidor. En Windows tambien puede
usarse `py -3`. No usar datos reales de clientes o tarjetas. Editar las entradas,
no solo `dist/`; `prepare.py --output` acepta una carpeta nueva.

```sh
python tools/verify_release_snapshot.py
python tests/build.py
python tests/check.py --install
```

El verificador comprueba hashes, estructura y fuentes; build exige dos salidas
identicas. La suite historica conserva fallos documentados: no se declara toda
la bateria aprobada. El workflow `Tony source snapshot` ejecuta estas comprobaciones
en cloud, sin desplegar ni iniciar SQL. Consultar resultados del SHA exacto.

## SAVIA y publicacion

SAVIA conserva `023364fd`, Owner/B1 y aislamiento por sucursal. Su compilacion,
SQL y migraciones necesitan validacion propia. La UI staff esta fuera de `dist/`;
no se reintroduce `/savia/` ni se afirma que el backend este alojado o conectado.
El Worker original `martha-silva-demo.jason-suazof.workers.dev` queda fuera del
destino. Cualquier despliegue posterior requiere candidato, destino y rollback.
