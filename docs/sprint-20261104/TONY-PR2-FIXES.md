# Candidato de correcciones de PR2 — Tony, 2026-11-04

Fuente revisada: `88faa2dd0d51fc1c5089b721ba5b17c23d4d61d4`, rama
`claude/funny-brahmagupta-5e5rj0` de `Suazo-AI/Martha-Silva-Store`.
Denis autorizó corregir los hallazgos y enviar resultados. El candidato se preparó
aislado porque no está confirmada la propiedad actual de las rutas en SUAZO-PC.
No se modificó el checkout canónico, no se saltaron hooks ni se hizo push o merge.

## Cambios

- STATUS01: una meta desconocida da error de validación y no aparece como completa.
- STATUS02: ciclos y referencias desconocidas conservan un digest explícitamente
  inválido, sin calcular recursivamente una ruta engañosa ni lanzar KeyError.
- STATUS03: `dropped` con decisión registrada satisface dependencias de forma
  coherente para avanzar, completar y calcular caminos.
- WF-P2-01: cada push agrega un snapshot histórico con evento, rama, SHA y run;
  no reemplaza el cuerpo global de la Bitácora. Los publicadores cooperantes se
  serializan; el comentario de PR vuelve a comprobar head, metadatos y estado.
  El GET seguido de PATCH no es atómico y no controla versiones antiguas del workflow.
- HC01: los dos archivos de evidencia pasan por staging privado y escaneo de
  secretos conocidos antes de exponerse; el manifiesto fija sus hashes. CI verifica
  y copia esos mismos bytes antes de habilitar resumen o artefacto, incluso si el
  smoke falló. Un escaneo fallido no imprime la tabla ni el error crudo.
- HC02: el helper propio se termina y espera ante interrupción o timeout. Una
  creación sin confirmación booleana positiva se registra `unknown`, bloquea un
  PASS de retirada y exige revisión del operador. No se borra una base incierta.
  Puede quedar una base parcial local; no se anuncia recuperada. CI conserva el
  retiro independiente de su contenedor desechable. SIGKILL o pérdida de energía
  no permiten garantías de limpieza desde el proceso.
- Documentación de C1: se conserva la instrucción de Denis de entregar la prenda
  física existente aunque el registro sea 0. La alerta y reconciliación siguen
  pendientes; no se modifican las guardas funcionales de stock en este parche.

## Verificación ligera realizada

```sh
python -B tests/test_delivery_status.py
python -B tests/test_golden_path_safety.py
```

24/24 y 17/17 casos, respectivamente, pasan en menos de un segundo por suite.
Las ocho regresiones nuevas del digest fallan contra la fuente anterior. Las
pruebas de seguridad también distinguen la fuente anterior de la corrección.
Los resúmenes de tres ledgers válidos conservan exactamente su salida anterior.
Se revisó sintaxis Python por AST. No se instaló PyYAML; validación de schema de
Actions y ejecución de sus comandos están pendientes.

Los tests de seguridad cargan las definiciones exactas por AST omitiendo imports
POSIX para poder aislar fallos con dobles en Windows. No ejecutan SQL, API, .NET,
bootstrap, navegador ni procesos del producto. No acreditan soporte Windows del
arnés POSIX, ni el recorrido combinado navegador → API → SQL.

El escáner solo busca secretos conocidos de la corrida, no garantiza detectar
todos los datos sensibles. La revisión de contenido sigue siendo necesaria.

## Integración y aceptación pendiente

Un solo integrador debe confirmar rutas libres y estado local del checkout
`C:/Users/Jason/MARTHA-SILVA/github`, cotejar los hashes base del manifiesto y
reconciliar cualquier delta nuevo antes de aplicar el parche. Usar la rama y los
hooks canónicos de `docs/AUTO-SYNC.md`; no hacer force-push ni eludir controles.
El parche incluye archivos nuevos que deben enumerarse explícitamente al stage.

Repetir las dos suites ligeras sobre el árbol integrado y las comprobaciones
aplicables del repositorio. Ejecutar build/API/SQL en el ejecutor autorizado de
SUAZO-PC o en CI; no repetir SQL aquí. Confirmar recibo SYNCED, SHA remoto y CI del
mismo SHA antes de declarar entrega. No confundir la aceptación estática del
parche con cierre de tarjetas, aprobación formal o autorización de despliegue.
