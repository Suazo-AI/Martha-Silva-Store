# Pruebas de base de datos SAVIA

Cada archivo `.sql` de esta carpeta es una prueba.
Corre sola, en una base nueva clonada de la plantilla (migraciones + `_fixture.sql`).
Falla cuando SQL Server devuelve un error; pasa cuando termina sin error.

```bash
python savia/tools/db/saviadb.py test                 # todas
python savia/tools/db/saviadb.py test receiving       # solo las que contienen ese texto en la ruta
python savia/tools/db/saviadb.py test --json          # salida para agentes
```

## Reglas para escribir una prueba

1. La primera línea dice qué afirma: `-- TEST: <una frase>`.
2. Usa los ids del fixture: `DECLARE @loc uniqueidentifier = test.Id('locA');`.
   Un argumento de `EXEC` no puede ser una expresión; copia siempre el valor a una variable.
3. Compara con `EXEC test.AssertEq N'qué se mide', <esperado>, @actual;`.
4. Para probar un rechazo, exige el número de error exacto:

   ```sql
   BEGIN TRY
     EXEC ...;
     THROW 59002,'ASSERT FAIL: se aceptó lo que debía rechazarse',1;
   END TRY
   BEGIN CATCH IF ERROR_NUMBER()<>51312 THROW; END CATCH;
   ```

5. No abras una transacción externa: los procedimientos hacen `ROLLBACK` al fallar.
6. Un procedimiento que devuelve filas se captura con `INSERT INTO @tabla EXEC ...`.
7. Una prueba que hoy falla por un defecto del producto se deja en rojo con una marca:
   `-- XFAIL: D-0xx <defecto en una frase>`.
   El corredor la reporta como `XFAIL`. Cuando el defecto se corrige pasa a `XPASS` y obliga a quitar la marca.
   No se corrige el producto para que la prueba pase sin dejar primero la prueba roja.

## Fixture

`_fixture.sql` crea 1 nodo nube y 3 sucursales (A, B, C) con una ubicación, una caja,
una cajera y una supervisora cada una; un gerente con acceso a las tres; proveedor, clientas,
un producto con 3 variantes (`item`, `item2` con IVA 15 %, `itemDraft` sin costo) y
`test.SeedStock` para ingresar unidades por el flujo real de recepción.

Las pruebas de concurrencia necesitan varias sesiones y viven en las pruebas .NET, no aquí.
