# Alcance de Martha Silva SISFAIN

Decisión del propietario, 2026-10-25: derivar el proyecto Martha Silva de GitHub para usarlo como modelo de SISFAIN y base de su conexión con Martha Silva. SAVIA será un proyecto independiente.

## Procedencia

- Repositorio fuente: https://github.com/Suazo-AI/Martha-Silva-Store
- Commit base: `3b0049163ece2d9431cee01f1bea624a66d9d8d4`.
- Copia local de trabajo: carpeta `MarthaSilvaSISFAIN`.
- Rama de preparación: `sisfain-base`.
- Nombre previsto para el repositorio independiente: `MarthaSilvaSISFAIN`.
- Respaldo de la base: rama `sisfain-base` de https://github.com/Suazo-AI/Martha-Silva-Store, con el código completo y la historia del commit base.
- Creación del repositorio independiente: pendiente de acceso con capacidad de crear repositorios; el conector actual permite publicar ramas y archivos en el repositorio existente.

Se conserva la historia Git del origen. Como el repositorio fuente pertenece a la misma cuenta, la separación se prepara como una copia con historia en un repositorio independiente.

El remoto fuente se llama `upstream`, con URL de push `DISABLED` para impedir publicaciones accidentales al original desde este checkout. Todavía no se configura `origin`: se añadirá después de verificar la creación del repositorio independiente. No hay hooks de sincronización activados.

## Límites de esta base

La demo, el backend sintético, el catálogo recuperado y la documentación histórica se heredan sin afirmar que exista una conexión operativa con SISFAIN. Las pruebas y URLs anteriores siguen siendo evidencia del proyecto fuente, no de esta copia.

Para implementar la conexión se necesita identificar la interfaz real de SISFAIN, el mecanismo de autenticación, el contrato de datos y la autoridad de catálogo, stock y pedidos. No se inventarán endpoints ni credenciales.

SAVIA queda fuera del alcance de este repositorio. No se vinculan despliegues, secretos, bases de datos ni sincronización automática con ese proyecto. Los scripts heredados de publicación apuntan al proyecto original y no deben activarse en esta copia; su adaptación requiere un destino propio verificado.

## Entrega pendiente

Crear el repositorio independiente y trasladar allí la historia preservada desde esta rama, comprobar el SHA remoto y revisar sus resultados de CI. El respaldo en GitHub no publica una tienda ni activa una integración con SISFAIN.

## Verificación local, 2026-10-25

Base verificada: `3b0049163ece2d9431cee01f1bea624a66d9d8d4`, coincidente con `main` del origen mediante `git ls-remote`. Los cambios de preparación solo afectan documentación.

Comando: `python tests/check.py --install`, Windows, Python 3.12.10 y Node.js 24.22.1. Se instalaron las 39 dependencias fijadas; pasaron los builds repetibles (26 rutas y hashes iguales), la comprobación de 9 páginas, las 23 pruebas del adaptador local y las 9 de migración de catálogo.

La suite terminó con error en `tests/asset-audit.py::test_missing_and_symlink_not_read`: `WinError 1314` al crear un enlace simbólico, por falta de privilegio de Windows. Las etapas posteriores no se ejecutaron. No se modificaron permisos de Windows ni se afirma que la suite completa haya pasado. No se ejecutó QA visual, pruebas de SQL ni pruebas de integración SISFAIN. No hay CI ni SHA de entrega en un repositorio remoto nuevo.
