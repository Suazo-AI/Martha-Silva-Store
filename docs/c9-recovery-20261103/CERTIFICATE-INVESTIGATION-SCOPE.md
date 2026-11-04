# C9: propuesta acotada para identificar el bloqueo TLS

**Propuesta preparada; no ejecutada. No programa una conexión SQL.**

El único intento del preflight terminó con:
`The certificate chain was issued by an authority that is not trusted.`
Hubo 1 Open, 0 sesiones abiertas y 0 consultas; el intento quedó consumido.
[Resultado y campos pendientes](PREFLIGHT-RESULT.md).

## Siguiente acción recomendada

El primary prepara una inspección de metadata local de certificados para `MSSQL$SAVIATEST` en `SUAZO-PC`.
Jason o el administrador SQL decide ese alcance antes de ejecutarlo.
Primero se debe identificar el certificado efectivo y la cadena existente; todavía no se propone una corrección concreta.
La causa observada es rechazo de confianza; la CA, el certificado y el eslabón faltante son desconocidos.
Un binding vacío en el registro no demuestra que el certificado sea autofirmado ni que no exista TLS.

1. Leer el binding vigente y solo las entradas de arranque SQL relacionadas con certificado/TLS.
   Filtrar localmente; no exportar el ERRORLOG completo ni entradas de negocio.
2. Comparar la identidad pública observada con los certificados existentes del equipo.
   Leer solo subject, issuer, vigencia, SAN/EKU, thumbprint y disponibilidad observada de cadena.
3. Inspeccionar únicamente la cadena y almacenes de confianza existentes.
   No exportar claves privadas, instalar certificados, descargar autoridades ni cambiar políticas.
4. Devolver la causa comprobada o la información todavía ausente.
   Preparar una corrección separada con destino, efecto, rollback y comprobación antes de solicitarla.

La inspección no abre SQL, no modifica servicios/cuentas/permisos/configuración y no cambia el transporte.
No se relajan `Encrypt=True` ni `TrustServerCertificate=False`.
No se reutiliza el latch ni se ejecuta otro cliente o fallback para obtener la metadata pendiente.
Los datos de identificación sensibles quedan privados; el repositorio recibe estados, agregados y hashes saneados.

## Responsables y comprobación de cierre

Primary: preparar y revisar la inspección; registrar su resultado sin confundir configuración OS con sesión SQL.
Jason / administrador SQL: decidir cualquier modificación de confianza, certificado o servicio.
Cualquier nueva conexión requiere alcance y autorización separados del preflight ya consumido.

Una futura conexión autorizada debe validar certificado y destino, leer la identidad SQL y la sesión TLS,
clasificar todos los campos permitidos, emitir cero mutaciones y respetar el límite nuevo sin reintentos.
Solo después se puede terminar de diseñar la corrida C9 sintética Windows.
C9 permanece abierto 0/5: faltan restore con ventas/oráculos, RTO/RPO y recuperación Owner.
