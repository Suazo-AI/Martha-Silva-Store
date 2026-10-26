# Martha Silva Store

Repositorio de recuperación y evolución de las demos de Martha Silva. Conserva código, evidencia y decisiones sin confundir una demo con una tienda en producción.

**Demo publicada:** [martha-silva-preview.martha-silva-denis.workers.dev](https://martha-silva-preview.martha-silva-denis.workers.dev/).
Código publicado: `8ef27660bb94acc5d93f09d59b92cbbc8661e94e`, separado del original.
Portada editorial con seis fotografías de Instagram, fondo espresso/marfil y 44 derivados responsivos.
Conserva el selector de idioma en las 47 páginas y 40 productos.
[English](https://martha-silva-preview.martha-silva-denis.workers.dev/?lang=en) ·
[Español](https://martha-silva-preview.martha-silva-denis.workers.dev/?lang=es).
[Evidencia de publicación y QA](evidence/luxury/publication.json).

**Copia publicada:** 47 páginas, 40 productos de muestra, 120 variantes y 170 posiciones de galería, con los adaptadores locales SAVIA/SISFAIN. Se recuperaron 777 de 778 medios históricos desde el sitio público autorizado; el JPEG restante devuelve 404 y no se sustituye. No procesa tarjetas ni ofrece autenticación o inventario de producción. El original de Cloudflare permanece intacto.

La rama `feat/original-storefront-preview` amplía la demo anterior de dos productos. Conserva el hero fotográfico y usa el catálogo compartido para evitar repetir los metadatos de imágenes en cada página. Procedencia y límites: [diseño](DESIGN.md), [estado](docs/PROJECT-STATUS.md) y [medios](docs/ASSET-COMPLETENESS.md). Una copia local no acredita publicación: el destino autorizado es únicamente el nuevo Worker `martha-silva-preview` de la cuenta conectada.


**Direccion vigente:** continuar unicamente sobre la demo principal <https://martha-silva-preview.martha-silva-denis.workers.dev/>. La caja separada `/savia/` y su enlace fueron retirados: sus rutas responden404. La integracion real con el backend SAVIA sigue pendiente; no se sustituye por otra aplicacion ni por operaciones simuladas presentadas como reales.

## Navegación

| Necesidad | Entrada |
| --- | --- |
| Original recuperado (parcial) | [Cloudflare](originals/cloudflare/README.md) |
| Comparación del catálogo sin activar productos | [Staging](tests/catalog-staging-README.md), [resultado](evidence/catalog-staging.json) |
| Seguridad y datos excluidos | [SECURITY](docs/SECURITY.md) |
| Roadmap V1 propuesto y tareas | [ROADMAP-V1](docs/ROADMAP-V1.md), [tareas estructuradas](docs/roadmap-tasks.json) |
| Estado, pendientes y criterios de aceptación | [PROJECT-STATUS](docs/PROJECT-STATUS.md) |
| Procedimientos, herramientas y lecciones reutilizables | [PLAYBOOK](docs/PLAYBOOK.md) |
| Registro de decisiones | [DECISIONS](docs/DECISIONS.md) |
| Reglas para contribuir | [AGENTS](AGENTS.md) |
| Fuentes editables y compilación determinista | [build-inputs](build-inputs/README.md), `src/`, `prepare.py` |
| Demo ensamblada | `dist/` |
| CD aislado de Cloudflare, desactivado hasta autorización/configuración | [CLOUDFLARE-CD](docs/CLOUDFLARE-CD.md) |
| Pruebas y límites de QA | [tests](tests/README.md), [evidencia](evidence/QA.md) |
| Fotografías faltantes e importación segura | [ASSET-COMPLETENESS](docs/ASSET-COMPLETENESS.md) |
| Investigación de pagos; ningún proveedor elegido | [REA](research/rea/README.md), [hallazgos](research/rea/FINDINGS.md) |

El material histórico de Cloudflare se conserva separado en `originals/cloudflare/` (integrado); no forma parte del build raíz ni debe desplegarse por defecto. La historia Git registra la evolución; los commits importados indican el SHA de procedencia local cuando cambia su identidad al publicarlos por API: `git log --oneline --all --decorate`.

## Ejecutar localmente

Requisitos de referencia usados por las pruebas: Python 3.12.14, Node.js 24.22.1 y npm 11.9.0. Python utiliza solo biblioteca estándar. Las pruebas DOM requieren las dependencias fijadas en `tests/frontend-deps/package-lock.json`; su primera instalación necesita acceso al registro npm.

### Linux / WSL

Desde la raíz del checkout:

```sh
python3 prepare.py
python3 tests/check.py --install   # primera vez; instala dependencias fijadas
python3 tests/check.py          # siguientes ejecuciones sin instalar
python3 -m http.server 8000 --bind 127.0.0.1 --directory dist
```

Abrir <http://127.0.0.1:8000>. `Ctrl+C` detiene el servidor. No abrir el HTML con `file://` ni introducir datos reales de clientes o tarjetas.

### Windows

Para ejecutar la demo desde PowerShell, con Python instalado y su lanzador disponible:

```powershell
py -3 prepare.py
py -3 -m http.server 8000 --bind 127.0.0.1 --directory dist
```

Para la suite completa desde PowerShell:

```powershell
py -3 tests/check.py --install
py -3 tests/check.py
```

El runner usa Python estándar y resuelve `npm.cmd` en Windows. La suite pasó en Ubuntu y Windows para `f22276a` (Actions run [`40136425925`](https://github.com/Suazo-AI/Martha-Silva-Store/actions/runs/40136425925)); el job de despliegue quedó **SKIPPED**. Incluye pruebas de staging y del propio runner. Esto no prueba QA en navegador ni un despliegue.

Editar HTML/CSS/catálogo/imágenes en `build-inputs/static/`, comportamiento en `src/`; después ejecutar `prepare.py`. No editar solo `dist/`: se perderá al reconstruir. Para una salida independiente: `python3 prepare.py --output /tmp/martha-demo-build` (directorio vacío).

## Sitios de referencia

- [Original Cloudflare](https://martha-silva-demo.jason-suazof.workers.dev/): preservar sin modificar.
- [Demo mejorada privada](https://martha-silva-photo-store.suazo-ai.chatgpt.site): puede requerir acceso; no es un enlace público nuevo ni prueba de sincronización con este commit.

Publicar el repositorio no publica automáticamente la tienda. Cualquier despliegue debe identificar destino, commit, autorización, prueba de acceso y rollback. Ver [criterios de entrega](docs/PROJECT-STATUS.md#criterios-de-aceptación).

La conexión autorizada se limita al **nuevo Worker `martha-silva-preview`**, no a Admin amplio. Cloudflare confirmó por API la creación del subdominio separado `martha-silva-denis`; el despliegue y su URL deben comprobarse contra el artefacto concreto. `gh` CLI no está autenticado y no se activó CD. Ver [CD aislado](docs/CLOUDFLARE-CD.md).


## SAVIA interno

SAVIA es un sistema para staff y propietarios, separado de la tienda publica: CRM, administracion, ventas, inventario y abastecimiento. La base tecnica reutilizada es f7e859b; todavia no constituye un CRM/ERP completo. La implementacion privada se coordina con Cutufay desde un snapshot de45fuentes verificadas, sin datos reales ni despliegue publico. Ver `docs/savia-internal/REUSE-MAP.md`, `STAFF-WORKFLOWS.md` y `ACCEPTANCE.md`.
