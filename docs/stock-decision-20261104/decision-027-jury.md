# Jurado D027 — próxima decisión

Recomendación: cerrar C1 mediante una autorización acotada para proteger la rama principal, condicionada a verificar primero GitHub. No abrir otra microdecisión de existencias.

## Verificado

`docs/DECISIONS.md`, D-026, separa registrar la excepción, revisarla y corregir con evidencia. `docs/stock-decision-20261104/README.md`, líneas 52–72, ya propone que la encargada corrija el origen documentado. No existe prueba del nuevo recorrido.

El encargo comunica la nueva adopción: revisión al cierre de cada jornada simulada, suplente y causas sin evidencia abiertas. Los documentos consultados todavía muestran esa regla pendiente; actualizar el registro no autoriza ejecución.

`docs/pipeline/ledger.json`, C1/C12, exige protección verificable de `main`, checks requeridos y ausencia de despliegue no autorizado. C2 necesita respuestas agregadas de Martha; C9 conserva el bloqueo TLS y su permiso consumido. C10 depende de esas brechas.

## Comparación

- **C1:** una decisión habilita un freno verificable para integrar avances. Es material porque modifica controles externos. El estado histórico de `main` y `CLOUDFLARE_DEPLOY_ENABLED` no demuestra el estado actual.
- **Facultades de corrección:** dejar límites explícitos en el alcance técnico del ensayo. Solo pedir otra decisión si se propone ampliar facultades: editar ventas cerradas, costos, dinero o diferencias sin evidencia. Preguntar nuevamente quién revisa o si debe aportar evidencia repetiría lo adoptado.
- **C2:** mayor valor para validar la sustitución real, pero exige hechos de Martha, no una preferencia técnica de Jason. Preparar una solicitud concreta dentro de la autorización disponible; no enviar mensajes sin permiso.

## Situación y pregunta propuestas

«Terminamos una mejora de caja. Al incorporarla a la versión principal, queremos que GitHub rechace cambios con pruebas fallidas y que publicar el sitio siga requiriendo tu autorización.»

Alternativas: mantener el control manual mientras no se integre nada; o instalar una barrera automática comprobable antes de integrar. Recomiendo la segunda. Añade una configuración acotada y reduce dependencia de recordar cada revisión.

Tras comprobar el estado real y presentar los cambios exactos: **¿autorizás configurar esa protección en GitHub, conservando bloqueado el despliegue?** La autorización no incluye merge ni deploy.

## Límites y siguiente acción

Coordinador: lectura vigente de controles, permisos y variable antes de afirmar una carencia; preparar modificación exacta, reversión y readback. Si ya cumplen, omitir esta pregunta y avanzar a obtener los hechos de C2. No hacer de C1 un sustituto del piloto ni declarar conciliado un inventario por saldo final correcto.

Informe consultivo. Jason decide. Pendiente recibir objeciones del crítico.

## Refinación ante el crítico

Mantengo C1. La objeción contra una pregunta genérica era válida; la evidencia nueva permite una autorización concreta. Según lectura API comunicada por el coordinador: `main` tiene `protected=false`, SHA `3b004916`, y `/rulesets=[]`. PR #2 sigue abierto con head `8744a969`; sus 21 checks no equivalen a protección permanente.

El plan propuesto exige PR y checks estrictos vinculados a GitHub Actions `app15368`, bloquea force-push y borrado, y evita exigir otro revisor humano. El coordinador debe verificar los nombres exactos antes de aplicar.

Pregunta única: **¿autorizás activar esa protección de `main`, sin hacer merge ni desplegar?**

Esto reduce una brecha comprobada; no prueba calidad comercial ni habilita el ensayo. La variable de despliegue sigue sin lectura válida: ausencia o endpoint rechazado no significan `false`. Su estado no debe cambiar bajo esta autorización.

Acepto el valor de C2: después necesitamos un ejemplo saneado de venta multiartículo, cobro y comprobante. Es evidencia operativa pendiente, sin autorización implícita para contactar a Martha.
