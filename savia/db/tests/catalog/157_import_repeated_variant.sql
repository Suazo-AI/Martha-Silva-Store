-- TEST: the preview refuses two rows of one product with the same size and color (P1). Before V061 the file passed the
-- preview and the commit failed on UQ_Items_Product_Variant (db.duplicate), so the owner saw no row to fix.
SET NOCOUNT ON;SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),@node uniqueidentifier=test.Id('nodeA'),
 @owner uniqueidentifier=test.Id('manager'),@batch uniqueidentifier=NEWID(),@n bigint,@json nvarchar(max);
DECLARE @out TABLE(Json nvarchar(max));
-- Rows 2 and 3 differ only in letter case, so they name one size and one color. Row 4 is another color; row 5 has none.
DECLARE @rows nvarchar(max)=N'[
 {"row":2,"code":"7501234567893","name":"Blusa lino","size":"M","color":"Azul","price":"450"},
 {"row":3,"code":"7501234567886","name":"Blusa lino","size":"m","color":"azul","price":"450"},
 {"row":4,"code":"7501234567879","name":"Blusa lino","size":"M","color":"Rojo","price":"450"},
 {"row":5,"code":"7501234567862","name":"Falda","price":"300"}]';
INSERT @out EXEC catalog.usp_ImportCatalog @batch,@branch,@loc,@owner,N'rep.csv',@rows,@node,0;
SET @json=(SELECT Json FROM @out);
SET @n=TRY_CONVERT(bigint,JSON_VALUE(@json,'$.errorCount'));EXEC test.AssertEq N'two rows repeat one variant',2,@n;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@json,'$.errors') WHERE JSON_VALUE(value,'$.row') IN ('2','3')
  AND JSON_VALUE(value,'$.message')=N'Talla y color repetidos en el producto.');EXEC test.AssertEq N'both rows named',2,@n;
BEGIN TRY EXEC catalog.usp_ImportCatalog @batch,@branch,@loc,@owner,N'rep.csv',@rows,@node,1;THROW 59002,'ASSERT FAIL: committed a repeated variant',1;END TRY BEGIN CATCH IF ERROR_NUMBER()<>52031 THROW;END CATCH;
PRINT 'PASS';
