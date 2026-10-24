# CI y entrega de artefacto

## Implementado

`.github/workflows/ci.yml` ejecuta `python tests/check.py --install` y
`python tests/test_check.py` en Ubuntu y Windows, con Python 3.12 y Node.js 24.
Se dispara con pushes a `main`, PRs hacia `main` y ejecución manual. No hay filtros
por ruta: los cambios de documentación también reciben comprobaciones.

Después de aprobar **ambos** sistemas, un push/ejecución manual de `main` genera
`artifact-dist/` con `prepare.py` y conserva el artefacto identificado por SHA
7 días. PRs no publican artefactos. La salida contiene únicamente la demo
recuperada, no `originals/`, dependencias de pruebas ni archivos del equipo.

**Esto no despliega un sitio.** No se modifica el Cloudflare original, DNS,
Workers, Pages, pagos ni bases de datos. El destino de despliegue sigue pendiente.
La visibilidad pública durante construcción está autorizada; volver a privado
al terminar es una acción separada que requiere verificar su resultado. Ninguna
visibilidad permite subir secretos, pedidos, clientes o credenciales.

## Controles

Token limitado a `contents: read`; checkout sin credenciales persistidas;
solo runners hospedados, sin `pull_request_target`, secretos ni OIDC.
Los trabajos tienen límites de 15/5 minutos y la suite de 10 minutos.
Se cancelan ejecuciones anteriores de la misma referencia. Windows conserva LF
antes del checkout para comparar exactamente los hashes del snapshot.

Acciones fijadas por SHA completo, comprobadas contra los tags oficiales mediante
`git ls-remote` el 2026-10-24:

| Acción | Versión | SHA |
| --- | --- | --- |
| checkout | v6.0.2 | de0fac2e4500dabe0009e67214ff5f5447ce83dd |
| setup-python | v6.2.0 | a309ff8b426b58ec0e2a45f0f869d46889d02405 |
| setup-node | v6.3.0 | 53b83947a5a98c8d113130e565377fae1a50d02f |
| upload-artifact | v6.0.0 | b7c566a772e6b6bfb58ed0dc250532a479d7789f |

Fuentes: [sintaxis de workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax),
[checkout](https://github.com/actions/checkout/tree/v6.0.2),
[setup-python](https://github.com/actions/setup-python/tree/v6.2.0),
[setup-node](https://github.com/actions/setup-node/tree/v6.3.0),
[upload-artifact](https://github.com/actions/upload-artifact/tree/v6.0.0).

## Verificar la activación

1. Integrar/publicar este commit y comprobar que Actions permite las acciones fijadas.
2. Abrir el run correspondiente al **SHA remoto exacto**; exigir ambos checks
   `Portable checks` y `Build artifact (not deployment)` en verde para `main`.
3. Descargar el artefacto y comprobar su contenido antes de cualquier entrega.
4. Configurar reglas de rama para exigir ambos checks si se autoriza: este archivo
   no crea protección de rama ni convierte automáticamente checks en obligatorios.

La existencia del YAML no demuestra una ejecución remota. Windows y subida del
artefacto están **no ejecutados** hasta disponer del run de Actions.
La suite local cubre simulaciones DOM/backend, no navegador real ni producción.
La instalación npm necesita red y usa el lockfile sin scripts de ciclo de vida.

## Siguiente fase de CD

Antes de implementar publicación: elegir proveedor/proyecto y URL, separar demo
vs producción, aprobar secretos mínimos y entorno protegido, rollback y criterio
de aceptación. No agregar credenciales ni reutilizar bindings históricos.
La revisión opcional con agente se describe en [NO-MISTAKES](NO-MISTAKES.md).

## Evidencia local de esta integración — 2026-10-24

- `npm_config_cache=/tmp/martha-cicd-npm-cache python tests/check.py --install`:
  PASS; build idéntico de 26 archivos, backend/catálogo/assets, 11 pruebas DOM,
  estructura de 9 páginas y sintaxis de 8 archivos JS.
- `python tests/test_check.py`: 5/5 PASS.
- `python prepare.py --output /tmp/martha-cicd-artifact`: 26 archivos preparados.
- Parseo YAML y aserciones de permisos/triggers/matriz/SHA/timeouts: PASS;
  `git diff --check`: PASS. No equivalen a validación de GitHub ni actionlint.
- El primer intento npm falló por caché no escribible en `/home/agent/.npm`;
  se repitió con caché temporal autorizada, sin cambiar el runner del proyecto.
- No ejecutados aquí: Windows, servicio Actions, carga remota del artefacto,
  no-mistakes, navegador real y despliegue.
