# Alojamiento de desarrollo: gratis y sin tarjeta

Restricción del usuario, 2026-10-25: desarrollo y demo por ahora gratuitos, sin
tarjeta; un servicio profesional pagado se evaluará después. Esto no acredita
una cuenta creada, recursos disponibles ni un despliegue.

## Candidato compatible

MonsterASP.NET anuncia .NET 10 y SQL Server en su plan gratuito. Su
[tarifa oficial](https://www.monsterasp.net/Pricing/) incluye una web, 5 GB de
archivos, 256 MB de RAM y una base de hasta 1 GB, con subdominio del proveedor.
La memoria es un límite a probar con el artefacto real; no garantiza que SAVIA
funcione dentro de la cuota.

Su [comparación de planes](https://help.monsterasp.net/getting-started/first-steps/free-vs-premium)
precisa que HTTPS gratuito se activa por soporte a solicitud después de subir
la web. No habilitar ingreso ni credenciales de personal antes de verificar TLS.
La misma documentación indica que no hay backups diarios incluidos, no hay
AlwaysRunning y los servicios inactivos se archivan tras seis meses.

El [registro](https://help.monsterasp.net/getting-started/first-steps/create-account)
requiere correo, activación y datos del titular; no tarjeta. El usuario debe
mantener el control de su cuenta y contraseña. El catálogo de plugins consultado
no devolvió un conector específico de MonsterASP; no se afirmó que exista.

Compatibilidad pendiente, comprobada contra el código recibido: la guarda
privada actual acepta únicamente bases `SaviaInternalTest_...`; MonsterASP
[conserva su prefijo `dbXXXX` incluso al renombrar](https://help.monsterasp.net/databases/tools/rename-database).
Por eso este candidato no es una conexión directa lista para usar. Hace falta
revisar una configuración explícita del destino de pruebas sin eliminar la
protección existente. No se implementó ni activó una excepción.

La [cadena de ejemplo del proveedor](https://help.monsterasp.net/databases/mssql/secure-connection)
incluye `MultipleActiveResultSets=True`; el runner actual exige `False` para
sus savepoints. También se debe verificar el cifrado y la confianza del
certificado SQL del destino. No copiar esa cadena a Git ni aplicar defaults
del proveedor automáticamente.

## Preparación antes de conectar

- Confirmar titular, plan Free, subdominio y cuenta efectivos, sin copiar claves
  a chat, documentación o Git.
- Verificar versión .NET, disponibilidad del SQL asignado, permisos DDL y nombre
  de base admitido por las guardas del código. No quitar prefijos ni habilitar
  flags sintéticos en producción para acomodarse al proveedor.
- Preparar publicación ligera y migración revisable con Cutufay en cloud.
  No compilar en paralelo en la PC con presión de memoria.
- Activar y verificar HTTPS, cookies seguras y rutas protegidas. La web pública
  Martha Silva y ambos Workers Cloudflare quedan fuera de este alojamiento.
- Ejecutar las pruebas SQL pendientes en una base de pruebas autorizada y
  vacía; registrar operaciones, reinicio y persistencia. Usar datos sintéticos.
- Establecer exportación/backup y retirada de la demo antes de depender del host.

Azure App Service con Azure SQL sigue siendo técnicamente compatible, pero
su registro ordinario pide tarjeta y no satisface la restricción actual.
Supabase/Neon PostgreSQL no sustituyen directamente el proveedor EF SQL Server;
no se autorizó esa migración.

Fuentes consultadas el 2026-10-25. El estado efectivo del panel y el artefacto
prevalecen sobre el anuncio del plan. No se creó cuenta, base, servidor ni URL.
