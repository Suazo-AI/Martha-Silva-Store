# SAVIA - paquete de prueba

Versión: rama Tony, commit a8a4dc1 (2026-11-11). Solo para pruebas con datos ficticios.
No es producción. No cobra dinero. No manda nada a internet.

## Qué necesitás

- Windows 10/11 x64. No hace falta instalar .NET: viene incluido.
- SQL Server (Express, Developer o el que tengas) y SSMS o `sqlcmd`.

## Tus conexiones no se tocan

- SAVIA usa SOLO una base nueva llamada `SaviaInternalTest_<algo>`. Rechaza cualquier otro nombre.
- Las variables se ponen solo mientras corre la ventana. No cambia nada global.
- No crea ni migra bases sola. No instala certificados como confiables.
- Puerto: `https://localhost:5443`. Solo escucha en tu PC.

## Pasos

1. En SSMS, crear la base vacía: `CREATE DATABASE SaviaInternalTest_Primo;`
2. Abrir `1-crear-tablas.sql` en SSMS, elegir esa base y ejecutar. Se puede repetir sin daño.
3. Doble clic en `crear-owner.cmd`. Contesta servidor, base y tipo de login. Seguí las instrucciones: escribí `PRIVATE`, luego usuario, nombre y contraseña del dueño.
4. Doble clic en `iniciar.cmd`. Se abre el navegador.
5. El navegador avisa "conexión no privada": es el certificado local. Elegí Avanzado → Continuar.
6. Entrá con el Owner que creaste.

Para cambiar servidor o base: `reset-config.cmd`.

## Si algo falla

- `storage_unavailable`: la base no existe, no se llama `SaviaInternalTest_...`, o falta el paso 2.
- Puerto ocupado: editar `Port` en `.local\config.json`.
- Windows bloquea el `.exe` (SmartScreen/Smart App Control): clic derecho en el zip → Propiedades → Desbloquear, antes de extraer.
- Mandá captura de la ventana negra y lo que hiciste.
