-- Owner decision 2026-11-12: import the catalog from the current system (CSV or XLSX mapped by the owner).
-- The API only reads the file and applies the column mapping. Every row rule and every write is here.
CREATE TABLE catalog.ImportBatches(Id uniqueidentifier NOT NULL PRIMARY KEY,BranchId uniqueidentifier NOT NULL REFERENCES core.Branches(Id),
 LocationId uniqueidentifier NOT NULL REFERENCES core.Locations(Id),FileName nvarchar(200) NOT NULL,RowsCount int NOT NULL,
 ItemsCreated int NOT NULL,UnitsAdded bigint NOT NULL,RequestHash varbinary(32) NOT NULL,
 CreatedBy uniqueidentifier NOT NULL REFERENCES security.Staff(Id),CreatedAt datetime2(3) NOT NULL DEFAULT(core.ufn_BusinessNow()));
CREATE TABLE catalog.ImportBatchItems(BatchId uniqueidentifier NOT NULL REFERENCES catalog.ImportBatches(Id),RowNumber int NOT NULL,
 ItemId uniqueidentifier NOT NULL REFERENCES catalog.Items(Id),OpeningQuantity int NOT NULL CHECK(OpeningQuantity>=0),
 MovementId uniqueidentifier NULL,PRIMARY KEY(BatchId,RowNumber));
GO
-- GTIN/EAN check digit (EAN-8, UPC-A, EAN-13, GTIN-14). Other codes are store codes and pass.
CREATE OR ALTER FUNCTION catalog.ufn_GtinCheckOk(@Code nvarchar(128)) RETURNS bit
AS
BEGIN
 IF @Code IS NULL OR @Code LIKE N'%[^0-9]%' OR LEN(@Code) NOT IN (8,12,13,14) RETURN 1;
 DECLARE @i int=LEN(@Code)-1,@sum int=0,@w int=3;
 WHILE @i>=1 BEGIN SET @sum+=CONVERT(int,SUBSTRING(@Code,@i,1))*@w; SET @w=4-@w; SET @i-=1; END;
 RETURN CASE WHEN (10-@sum%10)%10=CONVERT(int,RIGHT(@Code,1)) THEN 1 ELSE 0 END;
END;
GO
CREATE OR ALTER FUNCTION catalog.ufn_ParseMoneyMinor(@Text nvarchar(40)) RETURNS bigint
AS
BEGIN
 DECLARE @clean nvarchar(40)=REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(@Text)),N'C$',N''),N' ',N''),N',',N''),NCHAR(160),N'');
 DECLARE @value decimal(18,4)=TRY_CONVERT(decimal(18,4),NULLIF(@clean,N''));
 RETURN CASE WHEN @value IS NULL OR @value<>ROUND(@value,2) THEN NULL ELSE CONVERT(bigint,@value*100) END;
END;
GO
-- @Commit=0 returns the preview with row errors. @Commit=1 imports all rows in one transaction or none.
CREATE OR ALTER PROCEDURE catalog.usp_ImportCatalog @BatchId uniqueidentifier,@BranchId uniqueidentifier,@LocationId uniqueidentifier,
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
 CREATE TABLE #e(RowNumber int NOT NULL,Code nvarchar(128) COLLATE DATABASE_DEFAULT NULL,Message nvarchar(200) COLLATE DATABASE_DEFAULT NOT NULL);
 INSERT #e SELECT r.RowNumber,r.Code,m.Message FROM #r r CROSS APPLY (VALUES
  (CASE WHEN r.Code IS NULL THEN N'Falta el codigo.' END),
  (CASE WHEN r.Code IS NOT NULL AND (LEN(r.Code)>128 OR catalog.ufn_GtinCheckOk(r.Code)=0) THEN N'Digito verificador EAN incorrecto.' END),
  (CASE WHEN r.Code IS NOT NULL AND (SELECT COUNT(*) FROM #r x WHERE x.Code=r.Code)>1 THEN N'Codigo repetido en el archivo.' END),
  (CASE WHEN r.Code IS NOT NULL AND EXISTS(SELECT 1 FROM catalog.ItemIdentifiers i WHERE i.RawCode=r.Code COLLATE Latin1_General_100_BIN2 AND i.Kind='barcode' AND i.IsActive=1) THEN N'Codigo ya registrado.' END),
  (CASE WHEN r.Sku IS NOT NULL AND (LEN(r.Sku)>100 OR (SELECT COUNT(*) FROM #r x WHERE x.Sku=r.Sku)>1 OR EXISTS(SELECT 1 FROM catalog.Items i WHERE i.Sku=r.Sku COLLATE DATABASE_DEFAULT)) THEN N'SKU repetido o ya registrado.' END),
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
