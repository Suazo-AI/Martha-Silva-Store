# Referencias para la UX de SAVIA

Revisión: 2026-11-16, SUAZO-PC. Alcance: las seis mejoras autorizadas en [README.md](README.md).

Leí los README actuales de los 26 repositorios mediante la conexión GitHub. Profundicé en seis guías concretas, enlazadas abajo.
Esto es una selección de patrones. No es una auditoría de las bibliotecas, una prueba visual de sus sitios ni una aprobación de sus licencias.
No instalé dependencias ni cambié el stack de SAVIA. El contenido externo se trató como referencia, no como instrucciones de ejecución.

## Qué aplicamos

| Patrón | Aplicación en este incremento | Cómo se verifica |
| --- | --- | --- |
| Una acción principal y opciones secundarias plegables | Venta mantiene vendedor, prendas, total y Cobrar visibles. Descuentos y acciones del ticket quedan en controles nativos desplegables. | Recorrido de venta, valores conservados y acceso con Enter/Space. |
| Controles nativos y foco visible | Navegación agrupada con `details`/`summary`; el escáner respeta el foco de navegación. | Prueba roja del defecto, regresión de foco y teclado real en móvil/desktop. |
| Errores concretos y calmados | Mensaje operativo primero; código y diagnóstico se pueden desplegar. | Texto anunciado, marcado válido y acción accesible con teclado. |
| Estado incierto visible | Una venta pendiente ofrece Consultar recibo y conserva su identificador. Un 404 no autoriza volver a cobrar. | Pérdida de respuesta, almacenamiento, identidad original y ausencia de otro POST. |
| Confirmación para acciones destructivas | Reiniciar demo requiere confirmación; Cancelar conserva datos y sesión. | Comprobaciones del demo con API ficticia. |
| Identidad visual coherente | Conservar verde `#124b2d`, fondo `#f6f5f1`, superficies blancas y vocabulario existente. | Comparación de capturas y revisión del diff. |
| Calidad por comportamiento | Comprobar rutas, importes, atribución y recuperación; no aceptar una captura bonita como prueba de una venta. | Suite afectada, pruebas de fallos y revisión independiente del candidato combinado. |

Estos patrones coinciden con el trabajo ya autorizado. No abren una dirección visual nueva ni cambian las reglas de cobro, aprobación o permisos.

## Guías leídas en profundidad

- [Jakub: accesibilidad](https://github.com/jakubkrehel/skills/blob/main/skills/better-accessibility/SKILL.md): controles nativos, teclado, foco, etiquetas y anuncios. Blob leído: `919aff85f66061c116b50f5dd78c695f32147cb0`.
- [Jakub: escritura](https://github.com/jakubkrehel/skills/blob/main/skills/better-writing/SKILL.md): vocabulario estable, verbos concretos y errores junto al problema. Blob: `54f93d31197446fc5b4d8645fddaa3ec91baa5c2`.
- [Addy: frontend UI engineering](https://github.com/addyosmani/agent-skills/blob/main/skills/frontend-ui-engineering/SKILL.md): partir del producto real, conservar tokens y verificar los estados de la interfaz. Blob: `556b9878808486abb0d3e39daa985e6e34fa341c`.
- [Matt: TDD](https://github.com/mattpocock/skills/blob/main/skills/engineering/tdd/SKILL.md): probar comportamiento público, reproducir el fallo y corregir por partes. Blob: `01eadaa34e7c9a63a67d6dc3cce1cc81b0e49985`.
- [shadcn: improve](https://github.com/shadcn/improve/blob/main/skills/improve/SKILL.md): planes acotados, instrucciones autosuficientes y revisión del resultado. Blob: `df5b9001adda5ee72697ab5f7d3efe74c212e478`.
- [Caldo: untangle-codebase](https://github.com/caldoai/skills/blob/main/skills/untangle-codebase/SKILL.md): límites claros y menos conexiones innecesarias. Blob: `102ff57803e504876f6eb9b412e4eb0f6c576350`. No se ejecuta su propuesta de refactor general.

Los identificadores anteriores son hashes de blobs Git, no commits ni versiones instaladas.

## Selección de los 26 repositorios

La columna de lectura describe lo observado en el README. La decisión es una recomendación específica para el alcance actual de SAVIA.

| Fuente | Lectura | Decisión para SAVIA |
| --- | --- | --- |
| [shadcn/improve](https://github.com/shadcn/improve) | Auditoría y planes para otros ejecutores. | Usar tareas concretas y criterios verificables. |
| [shadcn-ui/ui](https://github.com/shadcn-ui/ui) | Componentes accesibles y personalizables. | Referencia de jerarquía y estados; conservar módulos JS actuales. |
| [jakubkrehel/skills](https://github.com/jakubkrehel/skills) | Guías de interfaz, accesibilidad, texto y estados. | Aplicar controles nativos y texto claro. |
| [Illyism/seo-skills](https://github.com/Illyism/seo-skills) | SEO/GEO y evidencia para contenido público. | Reservar para la tienda pública; no indexar la caja privada. |
| [emilkowalski/skills](https://github.com/emilkowalski/skills) | Diseño, móvil, animación y revisión de UI. | Referencia para claridad móvil y movimiento discreto. No se auditó cada guía. |
| [shader-effects-inc/shaders](https://github.com/shader-effects-inc/shaders) | Efectos WebGPU. | No hay necesidad demostrada en una pantalla de cobro. |
| [caldoai/skills](https://github.com/caldoai/skills) | Organización y desacoplamiento de código. | Cambios locales con límites claros; evitar un refactor general. |
| [t3dotgg/tstack](https://github.com/t3dotgg/tstack) | Flujos de agentes, revisión y PR. | Referencia de ejecución, no una dirección visual. |
| [michaelshimeles/rstack](https://github.com/michaelshimeles/rstack) | Trabajo aislado, contratos y evidencia. | Reforzar separación de áreas y revisión del resultado integrado. |
| [goabstract/Awesome-Design-Tools](https://github.com/goabstract/Awesome-Design-Tools) | Directorio de herramientas. | Consulta futura, sin añadir herramientas al flujo actual. |
| [tailwindlabs/heroicons](https://github.com/tailwindlabs/heroicons) | Iconos SVG y adaptadores. | Candidato si falta un icono; mantener etiquetas comprensibles. |
| [DavidHDev/react-bits](https://github.com/DavidHDev/react-bits) | Componentes y fondos animados de React. | Referencia visual opcional para web pública, fuera de esta caja. |
| [MengTo/threeui](https://github.com/MengTo/threeui) | Muestra de componentes e interacción. | Referencia de estados; no instalar componentes por apariencia. |
| [MengTo/Skills](https://github.com/MengTo/Skills) | Captura de referencias y especificación visual. | Vincular decisiones a pantallas reales; no copiar contenido. |
| [petyosi/react-virtuoso](https://github.com/petyosi/react-virtuoso) | Virtualización de listas/tablas React. | Considerar solo tras medir un problema de listas grandes. |
| [BuilderIO/skills](https://github.com/BuilderIO/skills) | Planificación, edición, revisión y flujos de agentes. | Tomar el enfoque verificable; no añadir otra infraestructura. |
| [barbajs/barba](https://github.com/barbajs/barba) | Transiciones entre páginas. | Mantener navegación nativa y rutas existentes. |
| [ibelick/motion-primitives](https://github.com/ibelick/motion-primitives) | Componentes con animación. | No hay motivo para añadir una dependencia en este incremento. |
| [mattpocock/skills](https://github.com/mattpocock/skills) | Guías de diseño de código, diagnóstico y pruebas. | Probar resultados públicos y corregir por partes. |
| [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | Ingeniería frontend, rendimiento y tareas verificables. | Estados completos y pruebas de flujos reales. |
| [greensock/GSAP](https://github.com/greensock/GSAP) | Biblioteca de animación. | Reservar para una necesidad visual concreta y aprobada. |
| [greensock/gsap-skills](https://github.com/greensock/gsap-skills) | Guías oficiales de uso de GSAP. | Consultar si se elige GSAP; no instalarlo ahora. |
| [ibelick/ui-skills](https://github.com/ibelick/ui-skills) | Registro de guías, CLI y MCP. | Fuente potencial de criterios; no se auditó todo el registro. |
| [darkroomengineering/lenis](https://github.com/darkroomengineering/lenis) | Desplazamiento suave. | Conservar scroll nativo en operaciones de caja. |
| [nextlevelbuilder/ui-ux-pro-max-skill](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill) | Recomendaciones de estilos e industria. | Usar como contraste; la identidad de SAVIA prevalece. |
| [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) | Identidad coherente, texto claro y referencias reales. | Conservar el sistema existente. No actualizar automáticamente la skill local. |

## Límites de esta revisión

No ejecuté código de estos repositorios. No medí sus demos, rendimiento, cumplimiento de accesibilidad o compatibilidad con SAVIA.
Dos páginas de directorios de GitHub no cargaron por el navegador de consulta; la lectura de archivos por la conexión GitHub sí funcionó.
Las pruebas de SAVIA y la revisión independiente determinan la aceptación del incremento. La reputación de una referencia no la sustituye.
