# Terminar lo que depende de nosotros

2026-11-05. SUAZO-PC. Modo VALIDATE. Base Tony `6f304a7571a554bb8968e081a14985829aee3dfb`.
El [ledger](../pipeline/ledger.json) conserva estados, responsables y criterios de cierre.
Este documento ordena la ejecución; no crea otro ledger ni cambia decisiones.

## Cómo avanzar sin esperar por todo

Separar pruebas técnicas, preparación operativa y aceptación real.
Cada módulo usa un contrato explícito, datos sintéticos y resultados esperados independientes.
Los supuestos siguen identificados hasta recibir los hechos de Martha.
Una prueba simulada cierra su alcance técnico, nunca un criterio que exige el entorno real.

| Frente | Acción de agentes | Prueba que permite aceptar | Dependencia que permanece |
| --- | --- | --- | --- |
| Sitio público | Medir tres rutas reales con Chrome local, ventanas estrecha/ancha, conexión degradada, sin JS y offline. | Recursos realmente solicitados, errores, selección de imágenes, navegación y estados observados ligados a fuentes. Corregir después el cuello de botella demostrado. | Dispositivos físicos, hechos comerciales, dominio, proveedor y activación de pagos. |
| Flujos SAVIA | Reutilizar la auditoría por jornada y dividir recepción, excepciones, cobros y cierre en contratos separados. | Caso que demuestra la brecha; cambio mínimo; oráculos de stock, dinero y auditoría; comprobación de persistencia cuando corresponda. | Los contratos de cobro, cierre y fiscalidad necesitan hechos del negocio. La política D-026/027 ya elegida no se reabre. |
| Recuperación | Conservar el paquete G0-G9; preparar comando, oráculos, rollback y destino aislado para el administrador. | Restauración efectiva con contenido comparado, RTO/RPO y recuperación Owner. | C9 necesita alcance nuevo para certificados/conexión SQL; no reintentar el permiso consumido ni desactivar TLS. |
| Ensayo | Convertir respuestas reales de C2 en datos sintéticos y guion repetible. Automatizar el registro de resultados existente donde aporte valor. | Cinco tareas sin ayuda, 30 mediciones en caja, conciliación física y dictamen del coordinador. | La observación de la persona y el equipo no se reemplaza con un agente. |
| Hospedaje/operación | Preparar configuración revisable y procedimientos tras la elección del destino; separar respaldo, alerta y rollback. | Readback del destino y ejercicio de caída/restauración autorizado. | Elección y costo del alojamiento, cuentas y autorización de despliegue. |

No abrir otra investigación general ni repetir N5-COV, ya aceptado.
No activar el narrador IA opcional ni calificar más proveedores como condición del producto.
Usar un ejecutor por módulo y worktree; integrar en serie un candidato.
Sol/high ejecuta; Opus critica los riesgos materiales; Astra arbitra evidencia y objeciones.
La revisión debe compartir el candidato y los criterios, no las conclusiones del implementador como prueba.
El primary conserva la aceptación y no relanza revisión por cambios documentales triviales.

## Avance comprobado en esta continuación

El [readback](deploy-variable-readback.json) confirma cero variables de Actions y dueño de tipo User.
El deploy job no declara environment y exige `CLOUDFLARE_DEPLOY_ENABLED == 'true'`.
La condición no se cumple con la configuración observada; no se cambió ninguna configuración.
Es evidencia puntual de configuración, no un ensayo adversarial ni permiso para merge/deploy.
C1 sigue abierto por el mecanismo de excepciones de stock.

La [medición real del sitio](browser-baseline/README.md) ya tiene inspección del primary.
Las seis muestras normales transfieren 29.9–53.4 MB; las tres degradadas agotan 40 segundos.
El candidato responsivo ya reduce imágenes y fuentes, conservando diseño y originales.
Astra devolvió APTO CON REPAROS; el primary corrigió ambos hallazgos e integró el candidato.
La [aceptación técnica](responsive-integration/README.md) conserva las mediciones y exige CI del SHA publicado.
La [simulación administrativa](../synthetic-replacement-20261104/admin-20261105/README.md) tiene doce familias y controles negativos comprobados.
Astra/high revisó los diez criterios; el primary acepta evidencia técnica offline acotada.
La revisión requerida de Opus sigue pendiente por cuota; esto no prueba capacidades del producto.
El [dictamen del primary](primary-baselines.md) registra comprobaciones, límites e importación.

## Handoffs que requieren hechos o autoridad externos

- C2: Jason coordina el [guion existente](../sprint-20261104/GUION-RECONSTRUCCION-MARTHA.md). Cierre: respuestas confirmadas y matriz por flujo; sin contacto externo enviado por agentes.
- C9: Jason/administrador decide el [alcance ya preparado](../c9-recovery-20261103/CERTIFICATE-INVESTIGATION-SCOPE.md). Cierre: causa verificada, corrección autorizada y nueva prueba de recuperación dentro de su alcance.
- C10: el coordinador SUAZO-PC ejecuta el ensayo cuando sus dependencias estén satisfechas. Cierre: resultados por flujo y aceptación, sin convertir una simulación en aprobación.
- Hosting/pagos: Jason aporta destino y comercio elegible antes de cuentas, servicios o cargos. Cierre: sandbox y operación productiva separados, con conciliación y rollback.

## Regla de salida

Cada resultado debe indicar criterio, candidato, entorno, comando/acción, observación, oráculo, evidencia y límite.
Un verde sin sensibilidad al fallo no basta para un caso crítico: usar control negativo acotado cuando aporte prueba.
No hay promesa de cero fallos ni compatibilidad universal. Definir dispositivos y condiciones soportadas.
Preparar lo reversible ahora; presentar las acciones irreversibles concretas cuando sean el único paso restante.

Lección aplicada: un bloqueo real de una línea no debe detener las líneas independientes.
La corrección es ejecutar mediciones y módulos acotados; la prueba es su evidencia, no otro documento de planificación.
