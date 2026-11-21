# D-027 registrada; siguiente autorización propuesta

**Actualización D-028:** Jason autorizó este plan y la protección se aplicó y verificó.
[Recibo de configuración](decision-028-main-protection-receipt.json).
El texto siguiente conserva el plan y las lecturas previas; ya no es autorización pendiente.
[Siguiente decisión vigente propuesta: C2](decision-028-next.md).

Jason eligió revisión al cierre de cada jornada simulada, con suplente si falta
la encargada y causas abiertas sin evidencia. Es política del ensayo sintético
SUAZO-PC. No acredita implementación, ejecución, aceptación ni personal real designado.

## Ejemplo para la siguiente decisión

Supongamos que terminamos una mejora para facturar dos prendas. Una modificación
posterior rompe el descuento de inventario. Aunque una prueba falle, sin protección
GitHub no exige esos checks antes de incorporar el cambio a `main`.
`main` es la rama donde se integraría la versión principal; no equivale por sí misma
a un sistema productivo ni a una publicación.

La protección propuesta rechaza integración directa y exige una solicitud de cambios
con las comprobaciones acordadas satisfactorias. Jason conserva el control de integrar.
La protección sola no publica nada. La revisión de despliegue sigue siendo una tarea
separada antes de cualquier merge; no se infiere deshabilitado desde una variable ausente.

Alternativas: mantener control manual mientras no se integre nada, o activar un freno
automático comprobable. Recomiendo el segundo: reduce dependencia de recordar cada check.
No demuestra que las pruebas cubran todos los defectos ni sustituye el ensayo de negocio.

## Evidencia actual

Lecturas API actuales, sin mutaciones:
[Resumen saneado de readbacks](decision-027-github-readback.json).
- `branches/main`: `protected=false`, SHA `3b0049163ece2d9431cee01f1bea624a66d9d8d4`.
- `rulesets`: lista vacía.
- PR #2 abierto, head `8744a9699812d62ea5ed31c63781748f833c3def`, base `main`.
- Ese head: 21 checks, 16 success y 5 skips de jobs previstos; los siete checks
  propuestos están presentes con success y productor GitHub Actions `app_id=15368`.
  No se confunde este head con el candidato histórico aceptado `53dd23b5`.
- El conector rechaza el endpoint de variables. La lectura CLI específica de
  `CLOUDFLARE_DEPLOY_ENABLED` devolvió HTTP 404. No se interpreta como valor efectivo false;
  no se verificaron valores heredados ni permisos suficientes para todos los ámbitos.
- `.github/workflows/ci.yml` condiciona deploy a push/no-PR en `main`, variable true,
  account ID y preview URL. Ninguna lectura autoriza desplegar.

## Cambio concreto listo para revisar, no ejecutado

Destino: protección clásica de `Suazo-AI/Martha-Silva-Store`, rama `main`.
[Payload propuesto](decision-027-main-protection.proposed.json), no aplicado.

- Exigir PR antes de integrar, también para administradores; Jason conserva la decisión de merge.
- Exigir base actualizada y siete checks: backend completo, staff/navegador, Golden API+SQL,
  build-and-guards, portables Windows y Ubuntu, y ledger. Productor GitHub Actions.
- Exigir resolución de conversaciones y bloquear force-push/borrado de la rama.
- Cero aprobaciones humanas adicionales obligatorias; no inventar un segundo mantenedor.
  El crítico, jurado y la verificación del coordinador no equivalen a aprobación humana en GitHub.
- No fusionar PR, no cambiar variables/secretos ni workflows y no desplegar por esta autorización.

La configuración disponible y permisos se comprueban antes de aplicar. Si GitHub rechaza
el cambio, conservar controles y devolver el error exacto con alternativa administrativa;
no debilitar silenciosamente los requisitos para conseguir una respuesta exitosa.

Comprobación de cierre: leer la protección y contrastar cada campo con el payload,
confirmar rulesets efectivos, comprobar que ningún PR fue fusionado y ningún despliegue fue disparado.
Si falta demostrar el rechazo efectivo de un cambio que incumpla las reglas, conservar ese límite
y preparar una comprobación acotada por separado; el readback no acredita todo el comportamiento.
Reversión: snapshot previo de reglas. Restaurar la configuración anterior debilitaría
protección y requiere indicación de Jason; no hacer rollback inseguro automático.

Pregunta única propuesta: **¿autorizás activar esta protección de `main`, sin fusionar cambios ni desplegar?**

## Crítico, jurado y siguiente trabajo de negocio

El [crítico](decision-027-critic.md) priorizó C2: conseguir un ejemplo saneado de venta
multiartículo, cobro y comprobante actual. Objetó pedir seguridad genérica sin inspección ni plan.
El [jurado](decision-027-jury.md) priorizó C1 si se confirmaba la brecha. Root verificó
la brecha y preparó destino, checks, efectos, límites y reversión; por eso recomienda C1 primero.
Se conserva el desacuerdo: C2 es el siguiente insumo comercial, no queda resuelto por esta protección.
No se contactó a Martha ni se recogieron datos personales.

## Registro y verificación

Se actualizaron DECISIONS, PROJECT-STATUS, C1/C10 del ledger y la pregunta de existencias
del cuestionario. Trello conserva stock incompleto hasta mecanismo implementado/probado;
la política y cobertura del ensayo ya no son preguntas pendientes.
[Recibo saneado](decision-027-receipt.json). Imágenes históricas no regeneradas ni enviadas.
No se repite la suite local detenida en D-026 por WinError 1314. La CI Linux de D-026
en `9f75b7447b364f75d80d20a73ae2665f254a53a4` terminó con cinco checks success y un
narrador opcional skipped, incluido el job portable histórico. No elimina el fallo local
ni prueba el nuevo recorrido. El nuevo commit requiere comprobación propia.

Lección aplicada: primero elegir el siguiente bloqueo material; no convertir una política
ya resuelta en una cadena de preguntas menores. El juicio de agentes se contrasta con fuente viva.
Verificación documental de este avance: `python tools/delivery_status.py --check`,
exit 0, ledger válido con 34 items; `git diff --check` sin errores. Siete nombres
de checks propuestos contrastados con success y app15368 en el head consultado.
Trello: cuatro readbacks exactos; criterio de stock sigue incompleto por implementación,
prueba y aceptación pendientes, no por volver a decidir la política.
