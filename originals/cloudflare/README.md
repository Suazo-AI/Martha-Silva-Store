# Original Cloudflare — recuperación parcial

Archivo de referencia de la demo original de **Martha Silva Store**. Esta carpeta
**no es una copia visual completa ni un sitio ejecutable**. El sitio original no
se ha modificado, desplegado ni consultado durante esta importación.

## Contenido conservado

| Archivo | Contenido |
| --- | --- |
| `index.js` | Worker recuperado previamente; copia byte a byte, conservada como fuente inerte. |
| `catalog-extracted.json` | Catálogo previamente extraído: 40 productos y 120 variantes; metadatos de 170 fotografías de producto. |
| `asset-paths.txt` | 171 rutas: 170 fotografías de producto y una imagen hero. **No contiene las imágenes.** |
| `provenance.json` | Alcance, exclusiones, tamaños y hashes del material importado. |
| `SHA256SUMS` | SHA-256 de los tres archivos originales conservados. |

Los precios, existencias y políticas del catálogo son datos de muestra
(`commercial_status: sample`), no condiciones comerciales confirmadas.

## Procedencia y límites

Se importaron únicamente los tres archivos indicados desde la recuperación local
preexistente `cloudflare-recovery`, el 24 de octubre de 2026. Los hashes comprueban
identidad con esos archivos locales, **no autentican por sí solos el despliegue
remoto**. No se ejecutó el Worker para obtener o verificar estos datos.

El acceso público al sitio original había devuelto **403**. No se reintentó el
acceso ni se usaron rutas alternativas para eludir esa denegación. Para completar
la copia original se requiere una exportación autorizada de los archivos estáticos
originales: HTML, CSS, JavaScript del navegador y las fotografías. Las rutas de
imagen no permiten afirmar que se recuperaron sus bytes. Tampoco se incluyen el
esquema de base de datos ni el estado de ejecución necesarios para ejecutar el
Worker original.

Las demos nuevas del repositorio son trabajo separado: no deben presentarse como
una reproducción exacta del original ni sustituir silenciosamente este archivo.

## Seguridad y uso

- No desplegar ni importar `index.js` en las demos actuales: es evidencia histórica.
- No se copiaron credenciales, valores de secretos, identificadores de cuenta de
  Cloudflare, configuraciones/bindings sin filtrar, registros de acceso ni datos
  de clientes, pedidos o sesiones.
- El código conserva nombres de interfaces como `ADMIN_PASSWORD`, `DB` y `ASSETS`;
  no sus valores o identificadores de recursos. Las referencias sociales públicas
  de la marca forman parte del catálogo.
- La revisión de importación fue estática; no constituye una auditoría de seguridad
  del Worker ni una validación funcional de comercio electrónico.

## Verificación sin ejecutar el Worker

Desde esta carpeta:

```sh
sha256sum -c SHA256SUMS
```

El manifiesto registra los hashes de origen y copia. Cualquier futura corrección
o reconstrucción debe ir en una carpeta diferente para preservar este snapshot.
