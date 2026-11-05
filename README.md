# Martha Silva Store / SAVIA

**Estado al 2026-11-05: candidato probado por capas; no listo para producción.**
La tienda pública y la aplicación interna de personal tienen alcances y autoridades separados.
N5 está corregido. Su cobertura adicional de recuperación está aceptada con límites;
siguen las validaciones y decisiones operativas del [estado vigente](docs/PROJECT-STATUS.md).

Entrada para cualquier agente: [AGENT-START](docs/AGENT-START.md).
Estado vigente: [PROJECT-STATUS](docs/PROJECT-STATUS.md).
Decisiones: [DECISIONS](docs/DECISIONS.md). SQL: [DATABASE](docs/DATABASE.md).
Validación histórica del 3 de noviembre: [590 backend PASS, 2 NOT RUN; navegador 31/32](docs/testing-20261103/README.md).
El N5 fallido en ese corte ya fue corregido. El [lote adicional N5](docs/n5-browser-20261105/README.md)
registró 50/50 con Chrome y HTTP simulado, sin defecto nuevo reproducido; controles negativos posteriores cerraron la revisión acotada.

Checkout canónico: `C:/Users/Jason/MARTHA-SILVA/github`, rama `Tony`.
Los hooks registran y sincronizan commits autorizados; [AUTO-SYNC](docs/AUTO-SYNC.md).
La [reconciliación](docs/reconciliation-20261103/README.md) vincula código probado, documentación y exclusiones.
Push, despliegue y aceptación son estados diferentes. Las copias vecinas no son el checkout activo.

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
| Original separado e inerte | [Procedencia del original](evidence/original-preview/README.md) |
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
python -m pip install --only-binary=:all: -r tests/media-requirements.txt
python tests/check.py --install
```

El verificador comprueba hashes, estructura y fuentes; build exige dos salidas
identicas. Las regresiones del catálogo distinguen capturas históricas y selección
publicada; conservan precios, stock, variantes y controles de archivos. Ver
[corrección y comprobaciones](docs/CATALOG-REGRESSION-FIX.md). El workflow
`Tony source snapshot` ejecuta la suite completa en Linux, sin desplegar ni iniciar
SQL. Consultar resultados del SHA exacto.

La puerta común incluye los controles de imágenes responsivas, fuentes completas
y procedencia editorial. Las dependencias de medios tienen versiones fijadas.
El snapshot actual se genera explícitamente con
`python tools/verify_release_snapshot.py --record`; el registro de octubre se conserva.

## SAVIA y publicación

SAVIA tiene sesión, permisos, directorio, stock, venta y recuperación implementados en el candidato.
Existe evidencia histórica de una venta Owner desde navegador a SQL. La validación reciente separó
API simulada en navegador y SQL real en fixtures; falta aceptar el recorrido combinado actual por cajero.
La UI staff está fuera de `dist/` y no se publica en el Worker de la tienda.
No se afirma hosting productivo, pagos bancarios ni aceptación visual.
El Worker original `martha-silva-demo.jason-suazof.workers.dev` queda fuera del destino de esta sincronización.
Cualquier despliegue requiere alcance, destino y rollback aprobados.
