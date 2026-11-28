-- savia:transactional
-- V065: SEC-05 gap 8 in docs/public-software/evidence/sec05-staff-input-audit.md.
-- usp_ImportCatalog read each JSON field as nvarchar(400) but kept it in a narrower #r column (code 128, name 200, size 70,
-- cost 40, ...). One overlong cell stopped the whole preview with a truncation error (500). The work columns are now 400
-- wide, so the existing row checks name the row. Money text over 40 characters is not parsed: ufn_ParseMoneyMinor takes
-- nvarchar(40) and would cut it silently; the row gets the existing price or cost message.
-- Same signature, same checks and request hash as V061; the previous API release keeps working.
-- The file runs again without error.
CREATE OR ALTER PROCEDURE catalog.usp_ImportCatalog @BatchId uniqueidentifier,@BranchId uniqueidentifier,@LocationId uniqueidentifier,
 @ActorId uniqueidentifier,@FileName nvarchar(200),@RowsJson nvarchar(max),@OriginNodeId uniqueidentifier,@Commit bit=0
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles r ON r.Id=sr.RoleId
  WHERE s.Id=@ActorId AND s.IsEnabled=1 AND r.Code='OWNER' AND r.IsActive=1
   AND (@BranchId IS NULL OR EXISTS(SELECT 1 FROM security.StaffBranchAccess a WHERE a.StaffId=s.Id AND a.BranchId=@BranchId AND a.IsActive=1)))
  THROW 52001,'Solo la duena importa el catalogo.',1;
 IF (@BranchId IS NULL AND @LocationId IS NOT NULL)
  OR (@BranchId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM core.Locations WHERE Id=@LocationId AND BranchId=@BranchId))
  THROW 51527,'Ubicacion no pertenece a sucursal.',1;
 IF NULLIF(LTRIM(RTRIM(@FileName)),N'') IS NULL OR ISJSON(@RowsJson)<>1 THROW 52030,'Archivo o filas invalidas.',1;
 CREATE TABLE #r(RowNumber int NOT NULL PRIMARY KEY,Code nvarchar(400) COLLATE DATABASE_DEFAULT NULL,Sku nvarchar(400) COLLATE DATABASE_DEFAULT NULL,Name nvarchar(400) COLLATE DATABASE_DEFAULT NULL,TypeName nvarchar(400) COLLATE DATABASE_DEFAULT NULL,
  SizeName nvarchar(400) COLLATE DATABASE_DEFAULT NULL,ColorName nvarchar(400) COLLATE DATABASE_DEFAULT NULL,CostText nvarchar(400) COLLATE DATABASE_DEFAULT NULL,PriceText nvarchar(400) COLLATE DATABASE_DEFAULT NULL,StockText nvarchar(400) COLLATE DATABASE_DEFAULT NULL,
  CostMinor bigint NULL,PriceMinor bigint NULL,Stock int NULL,SizeKey nvarchar(400) COLLATE DATABASE_DEFAULT NULL,ColorKey nvarchar(400) COLLATE DATABASE_DEFAULT NULL);
 INSERT #r(RowNumber,Code,Sku,Name,TypeName,SizeName,ColorName,CostText,PriceText,StockText)
  SELECT [row],NULLIF(LTRIM(RTRIM(code)),N''),NULLIF(LTRIM(RTRIM(sku)),N''),NULLIF(LTRIM(RTRIM(name)),N''),NULLIF(LTRIM(RTRIM([type])),N''),
   NULLIF(LTRIM(RTRIM(size)),N''),NULLIF(LTRIM(RTRIM(color)),N''),NULLIF(LTRIM(RTRIM(cost)),N''),NULLIF(LTRIM(RTRIM(price)),N''),NULLIF(LTRIM(RTRIM(stock)),N'')
  FROM OPENJSON(@RowsJson) WITH([row] int,code nvarchar(400),sku nvarchar(400),name nvarchar(400),[type] nvarchar(400),size nvarchar(400),color nvarchar(400),
   cost nvarchar(400),price nvarchar(400),stock nvarchar(400));
 IF NOT EXISTS(SELECT 1 FROM #r) OR (SELECT COUNT(*) FROM #r)>5000 THROW 52030,'El archivo debe tener entre 1 y 5000 filas.',1;
 UPDATE #r SET Sku=COALESCE(Sku,Code),CostMinor=CASE WHEN LEN(CostText)<=40 THEN catalog.ufn_ParseMoneyMinor(CostText) END,
  PriceMinor=CASE WHEN LEN(PriceText)<=40 THEN catalog.ufn_ParseMoneyMinor(PriceText) END,
  Stock=CASE WHEN StockText IS NULL THEN 0 ELSE TRY_CONVERT(int,StockText) END;
 -- Duplicates inside the file: one grouped pass instead of a count per row (A-10: about 1 M row reads per 1,000 rows).
 SELECT Code INTO #dupCode FROM #r WHERE Code IS NOT NULL GROUP BY Code HAVING COUNT(*)>1;
 SELECT Sku INTO #dupSku FROM #r WHERE Sku IS NOT NULL GROUP BY Sku HAVING COUNT(*)>1;
 -- One item per product, size and color (UQ_Items_Product_Variant). The key is the size or color the commit will use:
 -- an existing one by code or name, otherwise the new code (UPPER of the name). No size and no color is also one variant.
 UPDATE r SET SizeKey=ISNULL(COALESCE((SELECT TOP(1) CONVERT(nvarchar(70),z.Id) FROM catalog.Sizes z WHERE z.Code=r.SizeName OR z.Name=r.SizeName
   ORDER BY CASE WHEN z.Code=r.SizeName THEN 0 ELSE 1 END,z.Id),UPPER(r.SizeName)),N''),
  ColorKey=ISNULL(COALESCE((SELECT TOP(1) CONVERT(nvarchar(70),z.Id) FROM catalog.Colors z WHERE z.Code=r.ColorName OR z.Name=r.ColorName
   ORDER BY CASE WHEN z.Code=r.ColorName THEN 0 ELSE 1 END,z.Id),UPPER(r.ColorName)),N'') FROM #r r;
 SELECT Name,SizeKey,ColorKey INTO #dupVariant FROM #r WHERE Name IS NOT NULL GROUP BY Name,SizeKey,ColorKey HAVING COUNT(*)>1;
 CREATE TABLE #e(RowNumber int NOT NULL,Code nvarchar(400) COLLATE DATABASE_DEFAULT NULL,Message nvarchar(200) COLLATE DATABASE_DEFAULT NOT NULL);
 INSERT #e SELECT r.RowNumber,r.Code,m.Message FROM #r r CROSS APPLY (VALUES
  (CASE WHEN r.Code IS NULL THEN N'Falta el codigo.' END),
  (CASE WHEN r.Code IS NOT NULL AND (LEN(r.Code)>128 OR catalog.ufn_GtinCheckOk(r.Code)=0) THEN N'Digito verificador EAN incorrecto.' END),
  (CASE WHEN r.Code IS NOT NULL AND EXISTS(SELECT 1 FROM #dupCode x WHERE x.Code=r.Code) THEN N'Codigo repetido en el archivo.' END),
  (CASE WHEN r.Code IS NOT NULL AND EXISTS(SELECT 1 FROM catalog.ItemIdentifiers i WHERE i.RawCode=r.Code COLLATE Latin1_General_100_BIN2 AND i.Kind='barcode' AND i.IsActive=1) THEN N'Codigo ya registrado.' END),
  (CASE WHEN r.Sku IS NOT NULL AND (LEN(r.Sku)>100 OR EXISTS(SELECT 1 FROM #dupSku x WHERE x.Sku=r.Sku) OR EXISTS(SELECT 1 FROM catalog.Items i WHERE i.Sku=r.Sku COLLATE Latin1_General_100_BIN2)) THEN N'SKU repetido o ya registrado.' END),
  (CASE WHEN r.Name IS NULL OR LEN(r.Name)>200 THEN N'Falta el nombre.' END),
  (CASE WHEN r.PriceText IS NULL THEN N'Falta el precio.' WHEN r.PriceMinor IS NULL OR r.PriceMinor<=0 THEN N'Precio invalido.' END),
  (CASE WHEN r.CostText IS NOT NULL AND (r.CostMinor IS NULL OR r.CostMinor<0) THEN N'Costo invalido.' END),
  (CASE WHEN r.Stock IS NULL OR r.Stock<0 OR r.Stock>100000 THEN N'Existencia invalida.' WHEN @BranchId IS NULL AND r.Stock>0
    THEN N'En la central la existencia entra por recepcion.' END),
  (CASE WHEN EXISTS(SELECT 1 FROM #dupVariant d WHERE d.Name=r.Name AND d.SizeKey=r.SizeKey AND d.ColorKey=r.ColorKey)
    THEN N'Talla y color repetidos en el producto.' END),
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
   -- Validation ran before the transaction. Check SKU and barcode again under lock, and fail on the first row as usp_RegisterItem did.
   DECLARE @race int=(SELECT TOP(1) CASE WHEN EXISTS(SELECT 1 FROM catalog.Items i WITH(UPDLOCK,HOLDLOCK)
     WHERE i.Sku=r.Sku COLLATE Latin1_General_100_BIN2) THEN 51212 ELSE 51204 END
    FROM #r r WHERE EXISTS(SELECT 1 FROM catalog.Items i WITH(UPDLOCK,HOLDLOCK) WHERE i.Sku=r.Sku COLLATE Latin1_General_100_BIN2)
     OR EXISTS(SELECT 1 FROM catalog.ItemIdentifiers x WITH(UPDLOCK,HOLDLOCK)
      WHERE x.RawCode=r.Code COLLATE Latin1_General_100_BIN2 AND x.Kind='barcode' AND x.SupplierId IS NULL AND x.IsActive=1)
    ORDER BY r.RowNumber);
   IF @race=51212 THROW 51212,'SKU interno ya usado por otra variante.',1;
   IF @race=51204 THROW 51204,'Barcode ya asociado a una variante. Buscar producto antes de crear.',1;
   CREATE TABLE #p(Name nvarchar(200) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY,TypeName nvarchar(120) COLLATE DATABASE_DEFAULT NULL,
    ProductId uniqueidentifier NOT NULL,CategoryId uniqueidentifier NULL);
   INSERT #p(Name,TypeName,ProductId) SELECT Name,MIN(TypeName),NEWID() FROM #r GROUP BY Name;
   UPDATE p SET CategoryId=(SELECT TOP(1) c.Id FROM catalog.Categories c WHERE c.Name=p.TypeName AND c.IsActive=1 ORDER BY c.CreatedAt,c.Id) FROM #p p;
   INSERT catalog.Products(Id,CategoryId,BrandId,Name,Status,CreatedBy) SELECT ProductId,CategoryId,NULL,Name,'active',@ActorId FROM #p;
   -- The rows of the V039 item cursor, with the ids usp_RegisterItem and usp_ApplyMovement used to take one call at a time.
   CREATE TABLE #i(RowNumber int NOT NULL PRIMARY KEY,ItemId uniqueidentifier NOT NULL,ProductId uniqueidentifier NOT NULL,
    Code nvarchar(128) COLLATE DATABASE_DEFAULT NULL,Sku nvarchar(100) COLLATE DATABASE_DEFAULT NULL,Variant nvarchar(200) COLLATE DATABASE_DEFAULT NULL,
    SizeId uniqueidentifier NULL,ColorId uniqueidentifier NULL,CostMinor bigint NULL,PriceMinor bigint NULL,Stock int NOT NULL,MovementId uniqueidentifier NULL);
   INSERT #i(RowNumber,ItemId,ProductId,Code,Sku,Variant,SizeId,ColorId,CostMinor,PriceMinor,Stock,MovementId)
    SELECT r.RowNumber,NEWID(),pr.ProductId,r.Code,r.Sku,
     LEFT(CONCAT(r.Name,CASE WHEN r.SizeName IS NULL THEN N'' ELSE N' '+r.SizeName END,CASE WHEN r.ColorName IS NULL THEN N'' ELSE N' '+r.ColorName END),200),
     (SELECT TOP(1) Id FROM catalog.Sizes z WHERE z.Code=r.SizeName OR z.Name=r.SizeName ORDER BY CASE WHEN z.Code=r.SizeName THEN 0 ELSE 1 END,z.Id),
     (SELECT TOP(1) Id FROM catalog.Colors z WHERE z.Code=r.ColorName OR z.Name=r.ColorName ORDER BY CASE WHEN z.Code=r.ColorName THEN 0 ELSE 1 END,z.Id),
     r.CostMinor,r.PriceMinor,r.Stock,CASE WHEN r.Stock>0 THEN NEWID() END
    FROM #r r JOIN #p pr ON pr.Name=r.Name;
   INSERT catalog.Items(Id,ProductId,SizeId,ColorId,Sku,VariantName,CurrencyCode,UnitPriceMinor,UnitCostMinor,Status,CreatedBy)
    SELECT ItemId,ProductId,SizeId,ColorId,Sku,Variant,'NIO',PriceMinor,CostMinor,
     CASE WHEN PriceMinor=0 OR CostMinor IS NULL THEN 'draft' ELSE 'active' END,@ActorId FROM #i;
   INSERT catalog.ItemIdentifiers(ItemId,Kind,RawCode,IsPrimary,CreatedBy) SELECT ItemId,'barcode',Code,1,@ActorId FROM #i WHERE Code IS NOT NULL;
   -- New items have no balance: the opening stock is the whole balance, written once instead of inserted at 0 and updated.
   INSERT inventory.StockBalances(ItemId,LocationId,Pool,OnHand,Reserved,ModifiedAt,ModifiedBy)
    SELECT ItemId,@LocationId,'store',Stock,0,SYSUTCDATETIME(),@ActorId FROM #i WHERE Stock>0;
   INSERT inventory.StockMovements(Id,OperationId,ItemId,LocationId,Pool,Kind,OnHandDelta,ReservedDelta,OnHandAfter,ReservedAfter,UnitCostMinor,
     SourceType,SourceId,CreatedBy)
    SELECT MovementId,NEWID(),ItemId,@LocationId,'store','adjust',Stock,0,Stock,0,CostMinor,'catalog_import',@BatchId,@ActorId FROM #i WHERE Stock>0;
   INSERT catalog.ImportBatchItems(BatchId,RowNumber,ItemId,OpeningQuantity,MovementId) SELECT @BatchId,RowNumber,ItemId,Stock,MovementId FROM #i;
   -- Events keep the V039 order (products by name, items by row, then the batch) and payloads, in one outbox call (P1).
   DECLARE @events sync.EventInput;
   INSERT @events(Ord,EventId,AggregateType,AggregateId,EventType,PayloadJson)
    SELECT ROW_NUMBER() OVER(ORDER BY p.Name),NEWID(),'product',p.ProductId,'catalog.product_registered',
    (SELECT p.ProductId AS productId,p.Name AS name,p.CategoryId AS categoryId,CONVERT(uniqueidentifier,NULL) AS brandId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)
    FROM #p p;
   DECLARE @products int=@@ROWCOUNT;
   INSERT @events(Ord,EventId,AggregateType,AggregateId,EventType,PayloadJson)
    SELECT @products+ROW_NUMBER() OVER(ORDER BY i.RowNumber),NEWID(),'item',i.ItemId,'catalog.item_registered',
    (SELECT i.ItemId AS itemId,i.ProductId AS productId,i.Sku AS sku,i.Variant AS variantName,i.SizeId AS sizeId,i.ColorId AS colorId,
      CONVERT(varchar(3),'NIO') AS currency,i.PriceMinor AS priceMinor,i.CostMinor AS costMinor,i.Code AS barcode,
      CONVERT(uniqueidentifier,NULL) AS supplierId,CONVERT(nvarchar(128),NULL) AS supplierSku FOR JSON PATH,WITHOUT_ARRAY_WRAPPER)
    FROM #i i;
   INSERT @events(Ord,EventId,AggregateType,AggregateId,EventType,PayloadJson)
    SELECT @products+@rows+1,NEWID(),'catalog_import',@BatchId,'catalog.import_posted',
    (SELECT @BatchId AS batchId,@BranchId AS branchId,@FileName AS fileName,@rows AS itemsCreated,@units AS unitsAdded FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   EXEC sync.usp_EnqueueEvents @OriginNodeId=@OriginNodeId,@Events=@events;
  END;
  COMMIT;
 END TRY
 BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK;THROW;
 END CATCH;
 SELECT (SELECT b.Id AS batchId,b.FileName AS fileName,b.RowsCount AS rowsCount,b.ItemsCreated AS itemsCreated,b.UnitsAdded AS unitsAdded,b.CreatedAt AS createdAt
  FROM catalog.ImportBatches b WHERE b.Id=@BatchId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS Json;
END;
GO
