-- TEST: usp_ResolveScan rejects an empty reason (51304), a read that is not resolvable (51305) and a variant without the original code (51306) without changing the read.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@reviewer uniqueidentifier=test.Id('supervisorA'),@manager uniqueidentifier=test.Id('manager'),
  @node uniqueidentifier=test.Id('nodeA'),
  @product uniqueidentifier=NEWID(),@itemA uniqueidentifier=NEWID(),@itemB uniqueidentifier=NEWID(),
  @sizeM uniqueidentifier=test.Id('sizeM'),@sizeS uniqueidentifier=test.Id('sizeS'),
  @colorB uniqueidentifier=test.Id('colorBlack'),@colorW uniqueidentifier=test.Id('colorWhite'),
  @e1 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),@e3 uniqueidentifier=NEWID(),
  @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),
  @scan uniqueidentifier=NEWID(),@scanUnknown uniqueidentifier=NEWID(),
  @scanMatched uniqueidentifier=NEWID(),@missing uniqueidentifier=NEWID(),@n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

EXEC catalog.usp_RegisterProduct @ProductId=@product,@Name=N'Producto Ambiguo',@ActorId=@manager,
  @OriginNodeId=@node,@EventId=@e1;
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-RES-0001',@VariantName=N'Variante A',
  @CurrencyCode='NIO',@UnitPriceMinor=10000,@UnitCostMinor=5000,@Barcode=N'0000777000001',
  @SizeId=@sizeM,@ColorId=@colorB,@ActorId=@manager,@ItemId=@itemA,
  @OriginNodeId=@node,@EventId=@e2;
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-RES-0002',@VariantName=N'Variante B',
  @CurrencyCode='NIO',@UnitPriceMinor=10000,@UnitCostMinor=5000,@SupplierId=@supplier,
  @SupplierSku=N'0000777000001',@SizeId=@sizeS,@ColorId=@colorW,@ActorId=@manager,
  @ItemId=@itemB,@OriginNodeId=@node,@EventId=@e3;

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-RESERR',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000777000001',2,NULL,@actor;
INSERT INTO @sink EXEC receiving.usp_RecordScan @scanUnknown,@session,N'NO-EXISTE-9999',1,NULL,@actor;
INSERT INTO @sink EXEC receiving.usp_RecordScan @scanMatched,@session,N'0000123456789',1,NULL,@actor;

-- 51304: the reason is mandatory.
BEGIN TRY
  EXEC receiving.usp_ResolveScan @scan,@itemA,@reviewer,N'  ';
  THROW 59002,'ASSERT FAIL: a resolution without reason was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51304 THROW; END CATCH;

-- 51305: a read that is already matched is not resolvable any more.
BEGIN TRY
  EXEC receiving.usp_ResolveScan @scanMatched,@itemA,@reviewer,N'Revisado';
  THROW 59002,'ASSERT FAIL: a matched read was resolved again',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51305 THROW; END CATCH;

-- 51305: a read that does not exist.
BEGIN TRY
  EXEC receiving.usp_ResolveScan @missing,@itemA,@reviewer,N'Revisado';
  THROW 59002,'ASSERT FAIL: a missing read was resolved',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51305 THROW; END CATCH;

-- 51306: the variant does not have the original code registered for this supplier.
BEGIN TRY
  EXEC receiving.usp_ResolveScan @scanUnknown,@itemA,@reviewer,N'Revisado';
  THROW 59002,'ASSERT FAIL: a read was bound to a variant without the original code',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51306 THROW; END CATCH;

-- The reads are unchanged.
SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE Id=@scan AND ItemId IS NULL AND MatchStatus='ambiguous');
EXEC test.AssertEq N'the ambiguous read is unchanged',1,@n;
SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE Id=@scanUnknown AND ItemId IS NULL AND MatchStatus='unknown');
EXEC test.AssertEq N'the unknown read is unchanged',1,@n;
SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE Id=@scanMatched AND ItemId=test.Id('item')
        AND MatchStatus='matched');
EXEC test.AssertEq N'the matched read is unchanged',1,@n;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances);
EXEC test.AssertEq N'stock after the rejected resolutions',0,@n;
PRINT 'PASS';
