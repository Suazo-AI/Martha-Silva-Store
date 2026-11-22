-- TEST: the catalog import commit (V059) writes in sets and leaves exactly the rows, stock movements and outbox events of
-- the V039 per-row commit. Both paths import the same file into the same state, each inside a rolled-back transaction.
-- Ids differ, so rows compare by SKU, product name and size or color code, and event payloads after those ids are replaced.
SET NOCOUNT ON;
GO
-- The V039 procedure, copied unchanged under a test name: the reference result.
CREATE PROCEDURE test.usp_ImportCatalogV039 @BatchId uniqueidentifier,@BranchId uniqueidentifier,@LocationId uniqueidentifier,
 @ActorId uniqueidentifier,@FileName nvarchar(200),@RowsJson nvarchar(max),@OriginNodeId uniqueidentifier,@Commit bit=0
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles r ON r.Id=sr.RoleId
  JOIN security.StaffBranchAccess a ON a.StaffId=s.Id AND a.BranchId=@BranchId AND a.IsActive=1
  WHERE s.Id=@ActorId AND s.IsEnabled=1 AND r.Code='OWNER' AND r.IsActive=1) THROW 52001,'Solo la duena importa el catalogo.',1;
 IF NOT EXISTS(SELECT 1 FROM core.Locations WHERE Id=@LocationId AND BranchId=@BranchId) THROW 51527,'Ubicacion no pertenece a sucursal.',1;
 IF NULLIF(LTRIM(RTRIM(@FileName)),N'') IS NULL OR ISJSON(@RowsJson)<>1 THROW 52030,'Archivo o filas invalidas.',1;
 CREATE TABLE #r(RowNumber int NOT NULL PRIMARY KEY,Code nvarchar(128) COLLATE DATABASE_DEFAULT NULL,Sku nvarchar(100) COLLATE DATABASE_DEFAULT NULL,Name nvarchar(200) COLLATE DATABASE_DEFAULT NULL,TypeName nvarchar(120) COLLATE DATABASE_DEFAULT NULL,
  SizeName nvarchar(70) COLLATE DATABASE_DEFAULT NULL,ColorName nvarchar(70) COLLATE DATABASE_DEFAULT NULL,CostText nvarchar(40) COLLATE DATABASE_DEFAULT NULL,PriceText nvarchar(40) COLLATE DATABASE_DEFAULT NULL,StockText nvarchar(40) COLLATE DATABASE_DEFAULT NULL,
  CostMinor bigint NULL,PriceMinor bigint NULL,Stock int NULL);
 INSERT #r(RowNumber,Code,Sku,Name,TypeName,SizeName,ColorName,CostText,PriceText,StockText)
  SELECT [row],NULLIF(LTRIM(RTRIM(code)),N''),NULLIF(LTRIM(RTRIM(sku)),N''),NULLIF(LTRIM(RTRIM(name)),N''),NULLIF(LTRIM(RTRIM([type])),N''),
   NULLIF(LTRIM(RTRIM(size)),N''),NULLIF(LTRIM(RTRIM(color)),N''),NULLIF(LTRIM(RTRIM(cost)),N''),NULLIF(LTRIM(RTRIM(price)),N''),NULLIF(LTRIM(RTRIM(stock)),N'')
  FROM OPENJSON(@RowsJson) WITH([row] int,code nvarchar(400),sku nvarchar(400),name nvarchar(400),[type] nvarchar(400),size nvarchar(400),color nvarchar(400),
   cost nvarchar(400),price nvarchar(400),stock nvarchar(400));
 IF NOT EXISTS(SELECT 1 FROM #r) OR (SELECT COUNT(*) FROM #r)>5000 THROW 52030,'El archivo debe tener entre 1 y 5000 filas.',1;
 UPDATE #r SET Sku=COALESCE(Sku,Code),CostMinor=catalog.ufn_ParseMoneyMinor(CostText),PriceMinor=catalog.ufn_ParseMoneyMinor(PriceText),
  Stock=CASE WHEN StockText IS NULL THEN 0 ELSE TRY_CONVERT(int,StockText) END;
 -- Duplicates inside the file: one grouped pass instead of a count per row (A-10: about 1 M row reads per 1,000 rows).
 SELECT Code INTO #dupCode FROM #r WHERE Code IS NOT NULL GROUP BY Code HAVING COUNT(*)>1;
 SELECT Sku INTO #dupSku FROM #r WHERE Sku IS NOT NULL GROUP BY Sku HAVING COUNT(*)>1;
 CREATE TABLE #e(RowNumber int NOT NULL,Code nvarchar(128) COLLATE DATABASE_DEFAULT NULL,Message nvarchar(200) COLLATE DATABASE_DEFAULT NOT NULL);
 INSERT #e SELECT r.RowNumber,r.Code,m.Message FROM #r r CROSS APPLY (VALUES
  (CASE WHEN r.Code IS NULL THEN N'Falta el codigo.' END),
  (CASE WHEN r.Code IS NOT NULL AND (LEN(r.Code)>128 OR catalog.ufn_GtinCheckOk(r.Code)=0) THEN N'Digito verificador EAN incorrecto.' END),
  (CASE WHEN r.Code IS NOT NULL AND EXISTS(SELECT 1 FROM #dupCode x WHERE x.Code=r.Code) THEN N'Codigo repetido en el archivo.' END),
  (CASE WHEN r.Code IS NOT NULL AND EXISTS(SELECT 1 FROM catalog.ItemIdentifiers i WHERE i.RawCode=r.Code COLLATE Latin1_General_100_BIN2 AND i.Kind='barcode' AND i.IsActive=1) THEN N'Codigo ya registrado.' END),
  (CASE WHEN r.Sku IS NOT NULL AND (LEN(r.Sku)>100 OR EXISTS(SELECT 1 FROM #dupSku x WHERE x.Sku=r.Sku) OR EXISTS(SELECT 1 FROM catalog.Items i WHERE i.Sku=r.Sku COLLATE Latin1_General_100_BIN2)) THEN N'SKU repetido o ya registrado.' END),
  (CASE WHEN r.Name IS NULL OR LEN(r.Name)>200 THEN N'Falta el nombre.' END),
  (CASE WHEN r.PriceText IS NULL THEN N'Falta el precio.' WHEN r.PriceMinor IS NULL OR r.PriceMinor<=0 THEN N'Precio invalido.' END),
  (CASE WHEN r.CostText IS NOT NULL AND (r.CostMinor IS NULL OR r.CostMinor<0) THEN N'Costo invalido.' END),
  (CASE WHEN r.Stock IS NULL OR r.Stock<0 OR r.Stock>100000 THEN N'Existencia invalida.' END),
  (CASE WHEN LEN(r.TypeName)>120 OR LEN(r.SizeName)>30 OR LEN(r.ColorName)>30 THEN N'Tipo, talla o color demasiado largo.' END)) m(Message)
  WHERE m.Message IS NOT NULL;
 DECLARE @rows int=(SELECT COUNT(*) FROM #r),@bad int=(SELECT COUNT(DISTINCT RowNumber) FROM #e),@units bigint=(SELECT COALESCE(SUM(CONVERT(bigint,Stock)),0) FROM #r WHERE Stock>0);
 DECLARE @hash varbinary(32)=HASHBYTES('SHA2_256',CONCAT(CONVERT(nvarchar(36),@BranchId),N'|',CONVERT(nvarchar(36),@LocationId),N'|',@FileName,N'|',
  (SELECT RowNumber,Code,Sku,Name,TypeName,SizeName,ColorName,CostMinor,PriceMinor,Stock FROM #r ORDER BY RowNumber FOR JSON PATH)));
 IF @Commit=0 OR @bad>0
 BEGIN
  IF @Commit=1 AND NOT EXISTS(SELECT 1 FROM catalog.ImportBatches WHERE Id=@BatchId) THROW 52031,'El archivo tiene filas con errores. Corrija y vuelva a revisar.',1;
  IF @Commit=0
  BEGIN
   SELECT (SELECT @rows AS rowsCount,@rows-@bad AS validCount,@bad AS errorCount,@units AS unitsCount,
    JSON_QUERY(COALESCE((SELECT TOP(500) RowNumber AS [row],Code AS code,Message AS message FROM #e ORDER BY RowNumber,Message FOR JSON PATH),N'[]')) AS errors,
    JSON_QUERY(COALESCE((SELECT TOP(20) RowNumber AS [row],Code AS code,Sku AS sku,Name AS name,TypeName AS [type],SizeName AS size,ColorName AS color,
      CostMinor AS costMinor,PriceMinor AS priceMinor,Stock AS stock FROM #r ORDER BY RowNumber FOR JSON PATH),N'[]')) AS sample
    FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS Json;
   RETURN;
  END;
 END;
 BEGIN TRAN;
 BEGIN TRY
  IF EXISTS(SELECT 1 FROM catalog.ImportBatches WITH(UPDLOCK,HOLDLOCK) WHERE Id=@BatchId)
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM catalog.ImportBatches WHERE Id=@BatchId AND RequestHash=@hash AND CreatedBy=@ActorId) THROW 52004,'Lote de importacion reutilizado.',1;
  END
  ELSE
  BEGIN
   INSERT catalog.ImportBatches(Id,BranchId,LocationId,FileName,RowsCount,ItemsCreated,UnitsAdded,RequestHash,CreatedBy,CreatedAt)
    VALUES(@BatchId,@BranchId,@LocationId,@FileName,@rows,@rows,@units,@hash,@ActorId,core.ufn_BusinessNow());
   INSERT catalog.Categories(Id,Name,CreatedBy) SELECT NEWID(),t.TypeName,@ActorId FROM (SELECT DISTINCT TypeName FROM #r WHERE TypeName IS NOT NULL) t
    WHERE NOT EXISTS(SELECT 1 FROM catalog.Categories c WHERE c.Name=t.TypeName AND c.IsActive=1);
   INSERT catalog.Sizes(Id,Code,Name,SortOrder,CreatedBy) SELECT NEWID(),UPPER(t.SizeName),t.SizeName,100,@ActorId FROM (SELECT DISTINCT SizeName FROM #r WHERE SizeName IS NOT NULL) t
    WHERE NOT EXISTS(SELECT 1 FROM catalog.Sizes z WHERE z.Code=t.SizeName OR z.Name=t.SizeName);
   INSERT catalog.Colors(Id,Code,Name,CreatedBy) SELECT NEWID(),UPPER(t.ColorName),t.ColorName,@ActorId FROM (SELECT DISTINCT ColorName FROM #r WHERE ColorName IS NOT NULL) t
    WHERE NOT EXISTS(SELECT 1 FROM catalog.Colors z WHERE z.Code=t.ColorName OR z.Name=t.ColorName);
   DECLARE @products TABLE(Name nvarchar(200) PRIMARY KEY,TypeName nvarchar(120) NULL,ProductId uniqueidentifier NOT NULL);
   INSERT @products(Name,TypeName,ProductId) SELECT Name,MIN(TypeName),NEWID() FROM #r GROUP BY Name;
   DECLARE @name nvarchar(200),@type nvarchar(120),@product uniqueidentifier,@category uniqueidentifier,@evt uniqueidentifier;
   DECLARE p CURSOR LOCAL FAST_FORWARD FOR SELECT Name,TypeName,ProductId FROM @products ORDER BY Name;
   OPEN p;FETCH NEXT FROM p INTO @name,@type,@product;
   WHILE @@FETCH_STATUS=0
   BEGIN
    SET @category=(SELECT TOP(1) Id FROM catalog.Categories WHERE Name=@type AND IsActive=1 ORDER BY CreatedAt,Id);SET @evt=NEWID();
    EXEC catalog.usp_RegisterProduct @ProductId=@product,@Name=@name,@OriginNodeId=@OriginNodeId,@EventId=@evt,@CategoryId=@category,@ActorId=@ActorId;
    FETCH NEXT FROM p INTO @name,@type,@product;
   END;
   CLOSE p;DEALLOCATE p;
   DECLARE @row int,@code nvarchar(128),@sku nvarchar(100),@variant nvarchar(200),@size uniqueidentifier,@color uniqueidentifier,@cost bigint,@price bigint,
    @stock int,@item uniqueidentifier,@op uniqueidentifier,@mv uniqueidentifier;
   DECLARE i CURSOR LOCAL FAST_FORWARD FOR
    SELECT r.RowNumber,r.Code,r.Sku,LEFT(CONCAT(r.Name,CASE WHEN r.SizeName IS NULL THEN N'' ELSE N' '+r.SizeName END,CASE WHEN r.ColorName IS NULL THEN N'' ELSE N' '+r.ColorName END),200),
     (SELECT TOP(1) Id FROM catalog.Sizes z WHERE z.Code=r.SizeName OR z.Name=r.SizeName ORDER BY CASE WHEN z.Code=r.SizeName THEN 0 ELSE 1 END,z.Id),
     (SELECT TOP(1) Id FROM catalog.Colors z WHERE z.Code=r.ColorName OR z.Name=r.ColorName ORDER BY CASE WHEN z.Code=r.ColorName THEN 0 ELSE 1 END,z.Id),
     r.CostMinor,r.PriceMinor,r.Stock,pr.ProductId
    FROM #r r JOIN @products pr ON pr.Name=r.Name ORDER BY r.RowNumber;
   OPEN i;FETCH NEXT FROM i INTO @row,@code,@sku,@variant,@size,@color,@cost,@price,@stock,@product;
   WHILE @@FETCH_STATUS=0
   BEGIN
    SET @item=NEWID();SET @evt=NEWID();SET @mv=NULL;
    EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=@sku,@VariantName=@variant,@CurrencyCode='NIO',@UnitPriceMinor=@price,@ItemId=@item,
     @OriginNodeId=@OriginNodeId,@EventId=@evt,@SizeId=@size,@ColorId=@color,@Barcode=@code,@UnitCostMinor=@cost,@ActorId=@ActorId;
    IF @stock>0
    BEGIN
     SET @op=NEWID();
     EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@LocationId,@Pool='store',@Kind='adjust',@OnHandDelta=@stock,
      @SourceType='catalog_import',@SourceId=@BatchId,@ActorId=@ActorId,@UnitCostMinor=@cost,@MovementId=@mv OUTPUT;
    END;
    INSERT catalog.ImportBatchItems(BatchId,RowNumber,ItemId,OpeningQuantity,MovementId) VALUES(@BatchId,@row,@item,@stock,@mv);
    FETCH NEXT FROM i INTO @row,@code,@sku,@variant,@size,@color,@cost,@price,@stock,@product;
   END;
   CLOSE i;DEALLOCATE i;
   DECLARE @payload nvarchar(max)=(SELECT @BatchId AS batchId,@BranchId AS branchId,@FileName AS fileName,@rows AS itemsCreated,@units AS unitsAdded FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   SET @evt=NEWID();
   EXEC sync.usp_EnqueueEvent @evt,@OriginNodeId,'catalog_import',@BatchId,'catalog.import_posted',@payload;
  END;
  COMMIT;
 END TRY
 BEGIN CATCH
  IF CURSOR_STATUS('local','p')>=0 BEGIN CLOSE p;DEALLOCATE p;END;
  IF CURSOR_STATUS('local','i')>=0 BEGIN CLOSE i;DEALLOCATE i;END;
  IF @@TRANCOUNT>0 ROLLBACK;THROW;
 END CATCH;
 SELECT (SELECT b.Id AS batchId,b.FileName AS fileName,b.RowsCount AS rowsCount,b.ItemsCreated AS itemsCreated,b.UnitsAdded AS unitsAdded,b.CreatedAt AS createdAt
  FROM catalog.ImportBatches b WHERE b.Id=@BatchId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS Json;
END;
GO
-- Everything one import wrote, without ids or times. #pre holds the category, size and color ids that existed before.
CREATE PROCEDURE test.ImportSnapshot @batch uniqueidentifier,@seq0 bigint,@json nvarchar(max) OUTPUT
AS
BEGIN
 SET NOCOUNT ON;
 SELECT b.RowNumber,b.OpeningQuantity,b.MovementId,i.* INTO #it FROM catalog.ImportBatchItems b JOIN catalog.Items i ON i.Id=b.ItemId WHERE b.BatchId=@batch;
 SET @json=(SELECT
  (SELECT x.FileName,x.BranchId,x.LocationId,x.RowsCount,x.ItemsCreated,x.UnitsAdded,x.RequestHash,x.CreatedBy
    FROM catalog.ImportBatches x WHERE x.Id=@batch FOR JSON PATH) AS batch,
  (SELECT c.Name,c.ParentId,c.IsActive,c.CreatedBy,c.ModifiedBy,c.ModifiedAt FROM catalog.Categories c
    WHERE c.Id NOT IN (SELECT Id FROM #pre) ORDER BY c.Name FOR JSON PATH) AS categories,
  (SELECT z.Code,z.Name,z.SortOrder,z.CreatedBy,z.ModifiedBy,z.ModifiedAt FROM catalog.Sizes z
    WHERE z.Id NOT IN (SELECT Id FROM #pre) ORDER BY z.Code FOR JSON PATH) AS sizes,
  (SELECT k.Code,k.Name,k.HexColor,k.CreatedBy,k.ModifiedBy,k.ModifiedAt FROM catalog.Colors k
    WHERE k.Id NOT IN (SELECT Id FROM #pre) ORDER BY k.Code FOR JSON PATH) AS colors,
  (SELECT p.Name,c.Name AS category,p.BrandId,p.Description,p.Status,p.CreatedBy,p.ModifiedBy,p.ModifiedAt
    FROM catalog.Products p LEFT JOIN catalog.Categories c ON c.Id=p.CategoryId WHERE p.Id IN (SELECT ProductId FROM #it)
    ORDER BY p.Name COLLATE Latin1_General_100_BIN2 FOR JSON PATH) AS products,
  (SELECT i.RowNumber,i.OpeningQuantity,m.OnHandDelta AS movementDelta,i.Sku,p.Name AS product,z.Code AS size,k.Code AS color,i.VariantName,
     i.CurrencyCode,i.UnitPriceMinor,i.UnitCostMinor,i.TaxRateBps,i.Status,i.CreatedBy,i.ModifiedBy,i.ModifiedAt
    FROM #it i JOIN catalog.Products p ON p.Id=i.ProductId LEFT JOIN catalog.Sizes z ON z.Id=i.SizeId LEFT JOIN catalog.Colors k ON k.Id=i.ColorId
    LEFT JOIN inventory.StockMovements m ON m.Id=i.MovementId AND m.ItemId=i.Id ORDER BY i.RowNumber FOR JSON PATH) AS items,
  (SELECT i.Sku,x.SupplierId,x.Kind,x.RawCode,x.IsPrimary,x.IsActive,x.CreatedBy,x.ModifiedBy,x.ModifiedAt
    FROM #it i JOIN catalog.ItemIdentifiers x ON x.ItemId=i.Id ORDER BY i.RowNumber,x.Kind,x.RawCode FOR JSON PATH) AS identifiers,
  (SELECT i.Sku,s.ProductName,s.Sku AS searchSku,s.Status,s.SearchText
    FROM #it i JOIN catalog.ItemSearch s ON s.ItemId=i.Id ORDER BY i.RowNumber FOR JSON PATH) AS search,
  (SELECT i.Sku,b.LocationId,b.Pool,b.OnHand,b.Reserved,b.Status,b.CreatedBy,b.ModifiedBy,CASE WHEN b.ModifiedAt IS NULL THEN 0 ELSE 1 END AS modified
    FROM #it i JOIN inventory.StockBalances b ON b.ItemId=i.Id ORDER BY i.RowNumber,b.LocationId,b.Pool FOR JSON PATH) AS balances,
  (SELECT i.Sku,m.LocationId,m.Pool,m.Kind,m.OnHandDelta,m.ReservedDelta,m.OnHandAfter,m.ReservedAfter,m.UnitCostMinor,m.SourceType,m.SourceId,
     m.ReversesMovementId,m.Status,m.CreatedBy,m.ModifiedBy,m.ModifiedAt
    FROM #it i JOIN inventory.StockMovements m ON m.ItemId=i.Id ORDER BY i.RowNumber,m.Kind FOR JSON PATH) AS movements,
  (SELECT ROW_NUMBER() OVER(ORDER BY o.SequenceNo) AS [rank],o.OriginNodeId,o.AggregateType,o.EventType,o.Status,o.AttemptCount,o.NextAttemptAt,
     o.AckedAt,o.LastError,o.CreatedBy,o.ModifiedBy,o.ModifiedAt,
     COALESCE(N'I:'+it.Sku,N'P:'+pr.Name,CONVERT(nvarchar(36),o.AggregateId)) AS aggregate,
     REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(o.PayloadJson,
      COALESCE(CONVERT(nvarchar(36),it.Id),N'~'),N'I:'+COALESCE(it.Sku,N'~')),COALESCE(CONVERT(nvarchar(36),pr.Id),N'~'),N'P:'+COALESCE(pr.Name,N'~')),
      COALESCE(CONVERT(nvarchar(36),c.Id),N'~'),N'C:'+COALESCE(c.Name,N'~')),COALESCE(CONVERT(nvarchar(36),z.Id),N'~'),N'Z:'+COALESCE(z.Code,N'~')),
      COALESCE(CONVERT(nvarchar(36),k.Id),N'~'),N'K:'+COALESCE(k.Code,N'~')) AS payload,
     (SELECT d.DestinationNodeId,d.Status,d.AttemptCount,d.LastAttemptAt,d.AcknowledgedAt,d.CreatedBy,d.ModifiedBy,d.ModifiedAt
       FROM sync.EventDeliveries d WHERE d.EventId=o.EventId ORDER BY d.DestinationNodeId FOR JSON PATH) AS deliveries
    FROM sync.Outbox o
    OUTER APPLY (SELECT i.Id,i.Sku COLLATE DATABASE_DEFAULT AS Sku,i.ProductId,i.SizeId,i.ColorId FROM catalog.Items i WHERE o.AggregateType='item' AND i.Id=o.AggregateId) it
    OUTER APPLY (SELECT p.Id,p.Name,p.CategoryId FROM catalog.Products p
      WHERE p.Id=COALESCE(it.ProductId,CASE WHEN o.AggregateType='product' THEN o.AggregateId END)) pr
    LEFT JOIN catalog.Categories c ON c.Id=pr.CategoryId AND o.AggregateType='product'
    LEFT JOIN catalog.Sizes z ON z.Id=it.SizeId LEFT JOIN catalog.Colors k ON k.Id=it.ColorId
    WHERE o.SequenceNo>@seq0 ORDER BY o.SequenceNo FOR JSON PATH) AS events
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
END;
GO
-- Commits @rows through one procedure inside a transaction it rolls back, and returns the snapshot.
CREATE PROCEDURE test.ImportAndRollBack @proc sysname,@batch uniqueidentifier,@rows nvarchar(max),@json nvarchar(max) OUTPUT
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),@node uniqueidentifier=test.Id('nodeA'),
  @owner uniqueidentifier=test.Id('manager'),@seq0 bigint=(SELECT COALESCE(MAX(SequenceNo),0) FROM sync.Outbox);
 BEGIN TRAN;
 EXEC @proc @batch,@branch,@loc,@owner,N'equal.csv',@rows,@node,1;
 EXEC audit.usp_CheckConservation @Throw=1;
 EXEC test.ImportSnapshot @batch,@seq0,@json OUTPUT;
 ROLLBACK;
END;
GO
-- Rows cover: stock 0, no cost (draft), no type/size/color, one name with two types, names out of file order, quotes and
-- accents in a name, a variant cut at 200 characters, new and existing categories, sizes and colors, and an own SKU.
-- Rows of one name differ in size: a product holds one item per size and color (UQ_Items_Product_Variant).
DECLARE @rows nvarchar(max)=N'[
 {"row":2,"code":"7501234567893","sku":"","name":"Zapato \"Niño\" O''Brien ñ","type":"Calzado155","size":"XXL155","color":"Ocre155",
  "cost":"200","price":"C$ 450.00","stock":"3"},
 {"row":3,"code":"T155-SIN-COSTO","name":"Abrigo","type":"Abrigo155","size":"M","color":"Azul","price":"900","stock":"0"},
 {"row":4,"code":"T155-SIN-TIPO","sku":"T155-SKU-PROPIO","name":"Bolso","price":"300","stock":"7"},
 {"row":5,"code":"T155-OTRO-TIPO","name":"Abrigo","type":"Abrigo155b","size":"L","cost":"1","price":"901","stock":"2"},
 {"row":6,"code":"T155-LARGO","name":"' + REPLICATE(N'n',198) + N'","type":"Calzado155","size":"M","color":"Azul","cost":"5","price":"6","stock":"1"}'
 + (SELECT STRING_AGG(CONVERT(nvarchar(max),CONCAT(N',{"row":',n+6,N',"code":"T155-G',n,N'","name":"Grupo ',NCHAR(90-n%20),N'","type":"',
   CASE n%3 WHEN 0 THEN N'Blusa' WHEN 1 THEN N'Calzado155' ELSE N'' END,N'","size":"',
   CASE n/20 WHEN 0 THEN N'S' WHEN 1 THEN N'M' WHEN 2 THEN N'' ELSE N'XXL155' END,N'","color":"',CASE n%2 WHEN 0 THEN N'Negro' ELSE N'Ocre155' END,
   N'","cost":"',CASE WHEN n%7=0 THEN N'' ELSE CONVERT(nvarchar(9),n) END,N'","price":"',100+n,N'","stock":"',n%5,N'"}')),N'') WITHIN GROUP (ORDER BY n)
   FROM (SELECT TOP(60) ROW_NUMBER() OVER(ORDER BY object_id) AS n FROM sys.all_objects) g) + N']';
DECLARE @batch uniqueidentifier=NEWID(),@old nvarchar(max),@new nvarchar(max),@n bigint;
SELECT Id INTO #pre FROM catalog.Categories UNION ALL SELECT Id FROM catalog.Sizes UNION ALL SELECT Id FROM catalog.Colors;
EXEC test.ImportAndRollBack 'test.usp_ImportCatalogV039',@batch,@rows,@old OUTPUT;
EXEC test.ImportAndRollBack 'catalog.usp_ImportCatalog',@batch,@rows,@new OUTPUT;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@old,'$.items'));EXEC test.AssertEq N'every row imported',65,@n;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@old,'$.products'));EXEC test.AssertEq N'one product per name',24,@n;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@old,'$.events'));EXEC test.AssertEq N'one event per product and item, then the batch',90,@n;
IF @new IS NULL OR CONVERT(varbinary(max),@old)<>CONVERT(varbinary(max),@new)
BEGIN
 DECLARE @at int=1;
 WHILE @at<=LEN(@old) AND SUBSTRING(@old,@at,1) COLLATE Latin1_General_100_BIN2=SUBSTRING(@new,@at,1) SET @at+=1;
 PRINT CONCAT(N'V039: ',SUBSTRING(@old,@at-300,700));PRINT CONCAT(N'new:  ',SUBSTRING(@new,@at-300,700));
 THROW 59002,'ASSERT FAIL: the import wrote other rows or events than V039',1;
END;
-- The per-row procedures are gone from the commit: one statement per table instead of three calls per row.
SET @n=(SELECT COUNT(*) FROM sys.sql_expression_dependencies WHERE referencing_id=OBJECT_ID('catalog.usp_ImportCatalog')
 AND referenced_entity_name IN ('usp_RegisterProduct','usp_RegisterItem','usp_ApplyMovement'));
EXEC test.AssertEq N'commit calls no per-row procedure',0,@n;
PRINT 'PASS';
