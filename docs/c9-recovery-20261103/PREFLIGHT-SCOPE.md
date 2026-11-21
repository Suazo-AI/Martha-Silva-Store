# C9: alcance propuesto para el siguiente preflight

**PROPUESTA; NO AUTORIZADO NI EJECUTADO.**
Este documento concreta el siguiente paso de [PREPARATION.md](PREPARATION.md).
No autoriza ni programa una corrida.
No reutiliza autorizaciones, bases ni intentos históricos.

## Objetivo y destino

Obtener los campos actuales necesarios para diseñar una única recuperación sintética.
Host: `SUAZO-PC`. Instancia histórica que debe confirmarse: `SUAZO-PC\SAVIATEST`.
Identidad operadora: la sesión Windows autorizada de Jason.
Identidad API prevista: `SUAZO-PC\SaviaTestApi`; debe verificarse, sin modificarla.
El SHA de producto y el CI C6 aceptados se fijan antes del diseño de la corrida.

## Lecturas propuestas

1. Confirmar host, identidad Windows y ubicación de las herramientas existentes.
2. Confirmar instancia, edición Developer, versión y estado actual del servicio; no iniciarlo ni reiniciarlo.
3. Establecer una conexión de lectura con la configuración TLS vigente y comprobar su validación.
   Si falla confianza, identidad o conexión, registrar el error y detenerse; no añadir excepciones ni certificados.
4. Leer únicamente metadata del servidor: versión, edición y rutas predeterminadas de datos, logs y respaldo.
5. Leer la existencia y los roles de las dos identidades previstas.
   No impersonar usuarios, conceder permisos ni leer contraseñas, hashes o claves.
6. Consultar solo si ya existen estos dos nombres reservados, sin abrir sus tablas:
   `SaviaInternalTest_Golden_c9db647e8aeb4e55a7c46f48facb93aa` y
   `SaviaInternalTest_Golden_eb8b043220b54bc0a650d5b85bc8872f`.
   Si alguno existe, no reutilizarlo ni borrarlo; devolver el conflicto.
7. Comprobar existencia, volumen y ACL de las rutas candidatas conocidas; no crear carpetas ni archivos.
8. Devolver campos confirmados, campos faltantes y el alcance de una futura corrida, sin ejecutar esa corrida.

Las consultas exactas se congelan tras confirmar el cliente disponible y la conexión vigente.
No se propone un comando completo ficticio con rutas, certificado o SID aún desconocidos.
Los resultados públicos usarán estados y agregados; no contendrán credenciales ni datos de negocio.

## Efectos y límites

Efectos previstos: lecturas de metadata y sesiones SQL temporales.
Estado persistente esperado: sin cambios.
No se ejecutan BACKUP, RESTORE, VERIFYONLY, DDL, migraciones, INSERT, UPDATE ni DELETE.
No se consultan ventas, clientes ni tablas de negocio existentes.
No se inicia Docker, API, instaladores o servicios.
No se cambia seguridad, configuración, certificados, permisos, firewall ni main.
No se ejecutan one-shots históricos ni se cierra un diálogo de seguridad automáticamente.

Límite propuesto: una sesión de diagnóstico, sin reintentos automáticos ni rutas alternativas de conexión.
Ante una denegación, el ejecutor conserva el control y devuelve el paso manual exacto que falta.
No hay rollback de datos porque no se autoriza ninguna escritura.
Se cierran conexiones y archivos abiertos al terminar.

## Evidencia y cierre del preflight

El informe debe identificar host, instante, herramientas, edición, versión, validación TLS,
identidades verificadas, permisos observados, rutas disponibles y colisiones de nombres.
Debe registrar comandos y consultas permitidos, resultados saneados, errores y ausencia de mutaciones.
El informe distingue una lectura de metadata de una restauración probada.
No acredita RTO, RPO, recuperación Owner ni oráculos sobre una base restaurada.

Responsable de autorizar: Jason.
El modelo y razonamiento del ejecutor se confirman para ese lote antes de lanzarlo.
Después del preflight, cualquier corrida sintética o cambio de permisos requiere un alcance separado.
Si el preflight no puede completar sus lecturas, el informe indica causa, siguiente acción y comprobación de cierre.
