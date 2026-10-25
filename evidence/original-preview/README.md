# Evidencia de la copia autorizada

Base Git: `761559ad9b0cc6b7ac4c218029ce144791310172`; rama
`feat/original-storefront-preview`. El commit que contiene este directorio
identifica las fuentes locales; la publicación debe registrar por separado ese
SHA, el inventario del artefacto y la versión remota. No hubo push ni CI nueva.

## Recuperación y build

- 47 páginas, 40 productos de muestra, 120 variantes y 170 posiciones de galería.
- `../original-import-2026-10-25.json`: lista cerrada de 791 recursos importados
  (777 medios, ocho fuentes y seis recursos de fuentes/vendors), con URL pública,
  hora, tamaño y SHA-256. No incorpora el transporte ni Worker originales.
- 856 archivos de salida corresponden exactamente a las entradas estáticas y
  tres módulos de `src/`. El runner compara dos builds por rutas y SHA-256.
- `../asset-completeness.json`: cobertura histórica 777/778; el gate
  `--require-complete` sigue fallando por el JPEG legacy que devuelve404.
  Las 170 imágenes primarias de las galerías están presentes; `STORE_MEDIA`
  requiere 774 rutas únicas y todas existen.

## Medios

`image-decode-result.json` registra725/725 imágenes con dimensiones válidas.
`contact-decode-result.json` corresponde a las170 posiciones de galería: nueve
hojas de contacto fueron inspeccionadas visualmente por el revisor.
`video-decode-result.json` registra52/52 cuadros decodificados, con dimensiones,
duraciones y rango de píxeles positivo. Los tiempos registrados son0: no se
afirma decodificación a mitad de cada video ni reproducción exhaustiva/audio.
Los seis grupos `sample_image=true` permanecen identificados como muestra.

## Pruebas y límites

La primera instalación usó `python tests/check.py --install`; las repeticiones
usan `python tests/check.py`. El agregado Windows se detiene en pruebas que
requieren crear symlinks, con WinError1314. No se oculta ni etiqueta PASS esa
salida1. Las etapas posteriores se ejecutaron por separado:55 pruebas Node de
API/adaptadores/migración/catálogo,22 DOM,47 páginas estructurales y12 sintaxis
JS. Runner/sync/deployment offline:35 PASS y un SKIP de symlink preexistente.
Staging Windows:8 PASS y dos errores del mismo privilegio.

Cutufay ejecutó en Linux los dos comandos focales del paquete
`b3c621babd4872b3ae806d8a0db4854edf8db8be20a53df093911ee55b419806`:
cinco AuditTests y ocho StagingTests,13 PASS sin skips. Un auditor independiente
corroboró ZIP, cuatro fuentes sin cambios, comandos y hashes de ambos logs.
Los tres archivos `FOCAL-QA-*` conservan esa evidencia; no es un agregado Linux
del nuevo sitio. La evidencia de pruebas actual figura también en
`../original-preview-qa-2026-10-25.json`.

Los informes de navegador distinguen la pasada amplia y sus hashes de las
pruebas focales sobre la última corrección de hover. Chrome local usa un perfil
aislado y emulación de390×844; no acredita Safari o dispositivo físico.
jsdom no prueba píxeles, accesibilidad o rendimiento. Las pruebas de despliegue
son offline; el smoke público y la revisión externa requieren publicación real.

El backend .NET de esta rama conserva los mismos dos archivos corregidos del
candidato auditado:18 PASS y seis SQL SKIPPED en Linux; no se inició SQL nuevo.
SAVIA/SISFAIN son adaptadores locales de demostración. No se procesan tarjetas,
no se ofrece autenticación de producción y no se importan pedidos/clientes.
