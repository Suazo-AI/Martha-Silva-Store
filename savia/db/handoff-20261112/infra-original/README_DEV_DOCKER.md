# SAVIA: SQL Server 2022 en Docker (entorno de desarrollo)

Requisitos: Docker Desktop/Engine con soporte para contenedores Linux x86-64 y memoria suficiente, SSMS 2022 o sqlcmd. SQL Server Developer solo para desarrollo/pruebas, no para producción comercial.

1. Copiar `infra/.env.example` a `infra/.env`; generar contraseña segura para `MSSQL_SA_PASSWORD`. No guardar secretos en Git.
2. En la carpeta raíz del paquete:

   ```powershell
   docker compose --env-file infra/.env -f infra/docker-compose.dev.yml up -d
   docker compose --env-file infra/.env -f infra/docker-compose.dev.yml ps
   docker logs savia-sqlserver-dev
   ```

3. Esperar hasta que SQL Server esté listo. Con SSMS conectarse a `localhost,1433` (SQL Server Authentication, `sa`, contraseña de `.env`, **Encrypt** activo y configuración de certificado dev según la máquina).
4. Abrir `db/SAVIA_DB_SQLServer2022_COMPLETA.sql` y ejecutarlo **solo sobre una instancia de desarrollo / BD nueva**. El script instala `SAVIA_DB`, y no es re-ejecutable sobre una instalación parcial sin revisión.
5. Cambiar contexto a `SAVIA_DB` y ejecutar `db/SAVIA_DB_Verificar_Instalacion.sql` y después `db/SAVIA_DB_Prueba_Smoke_Rollback.sql`.
6. Guardar salida exacta. La prueba smoke solo verifica lo que realmente contiene el SQL; NO comprueba sincronización de red ni impresora física.
7. Confirmar persistencia: reiniciar contenedor (`docker compose ... restart`) y verificar que los objetos de `SAVIA_DB` permanecen. **Reiniciar no equivale a backup.** Implementar y comprobar respaldos/restauración separadamente.

**Precaución:** nunca ejecutar `docker compose down -v` sobre un contenedor con datos que quieras conservar; elimina volúmenes.

El archivo se entrega sin ejecutar porque el entorno de generación no dispone de Docker ni SQL Server; requiere validación real en tu equipo.
