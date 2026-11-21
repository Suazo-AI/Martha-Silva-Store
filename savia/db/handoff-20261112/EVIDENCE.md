# Proveniencia y evidencia de fuentes

Los archivos SQL abajo se copiaron sin editar desde los adjuntos de la conversación.

| Archivo | SHA-256 |
|---|---|
| `SAVIA_DB_AzureSQL_Instalar_En_BD_Existente.sql` | `5ad497342c1c04aab9b6a4b96fc55dea3029967cf169b845452b3727f1da48d9` |
| `SAVIA_DB_GUIA_INSTALACION.md` | `6a2adb70d8668200458376a3414e735b3e65f547bcd5f15d0be7de4ea617d294` |
| `SAVIA_DB_Prueba_Smoke_Rollback.sql` | `4f8d65124e42b55421e34c8df70b5175b343e250e32cbc295396be8738f95c44` |
| `SAVIA_DB_SQLServer2022_COMPLETA.sql` | `61c97305cdf3f83b677d965c0fd51d6e589abd5fc5ebe5bea1ba6fee4ec9ad1c` |
| `SAVIA_DB_Verificar_Instalacion.sql` | `002a2b6c8af1d34516ab1b88408da0a5453dd02479c357f5757f964050fe0419` |
| `Texto pegado.txt` | `8e914e05494f0aea4e2e2d2f4758558063df3488e43e15d9b9c04a2df58959ba` |

## Evidencia de entorno

- No se dispone de `docker`, `dotnet` ni `sqlcmd` en el entorno actual.
- No se ejecutó instalación SQL, compilación C# o tests de sistema.
- El Docker Compose es un ejemplo de desarrollo que debe validarse con Docker real.
- El esquema rediseñado de 77 tablas es un **draft**, sujeto a auditoría por el agente antes de aprobar uso.
- No hay deploy ni gasto en Azure.
