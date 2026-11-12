-- TEST: the same code registered for two variants is reported as ambiguous, no variant is chosen and no stock is added.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@reviewer uniqueidentifier=test.Id('supervisorA'),@manager uniqueidentifier=test.Id('manager'),
  @node uniqueidentifier=test.Id('nodeA'),
  @product uniqueidentifier=NEWID(),@itemA uniqueidentifier=NEWID(),@itemB uniqueidentifier=NEWID(),
  @sizeM uniqueidentifier=test.Id('sizeM'),@sizeS uniqueidentifier=test.Id('sizeS'),
  @colorB uniqueidentifier=test.Id('colorBlack'),@colorW uniqueidentifier=test.Id('colorWhite'),
  @e1 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),@e3 uniqueidentifier=NEWID(),
  @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),@scan uniqueidentifier=NEWID(),
  @n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

EXEC catalog.usp_RegisterProduct @ProductId=@product,@Name=N'Producto Ambiguo',@ActorId=@manager,
  @OriginNodeId=@node,@EventId=@e1;
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-AMB-0001',@VariantName=N'Variante A',
  @CurrencyCode='NIO',@UnitPriceMinor=10000,@UnitCostMinor=5000,@Barcode=N'0000777000001',
  @SizeId=@sizeM,@ColorId=@colorB,@ActorId=@manager,@ItemId=@itemA,
  @OriginNodeId=@node,@EventId=@e2;
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-AMB-0002',@VariantName=N'Variante B',
  @CurrencyCode='NIO',@UnitPriceMinor=10000,@UnitCostMinor=5000,@SupplierId=@supplier,
  @SupplierSku=N'0000777000001',@SizeId=@sizeS,@ColorId=@colorW,@ActorId=@manager,
  @ItemId=@itemB,@OriginNodeId=@node,@EventId=@e3;

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-AMB',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);

INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000777000001',2,NULL,@actor;

SET @n=(SELECT COUNT(*) FROM @sink WHERE c='ambiguous' AND b IS NULL AND d=2);
EXEC test.AssertEq N'the read is ambiguous and picks no variant',1,@n;
SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE Id=@scan AND MatchStatus='ambiguous' AND ItemId IS NULL);
EXEC test.AssertEq N'scan event of the ambiguous code',1,@n;

-- An ambiguous read never becomes stock.
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances);
EXEC test.AssertEq N'stock after the ambiguous read',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements);
EXEC test.AssertEq N'stock movements after the ambiguous read',0,@n;

-- The session cannot be approved while the code is ambiguous.
BEGIN TRY
  EXEC receiving.usp_ApproveScanSession @session,@reviewer;
  THROW 59002,'ASSERT FAIL: a session with an ambiguous code was approved',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51309 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM receiving.ScanSessions WHERE Id=@session AND Status='counting');
EXEC test.AssertEq N'the session is still counting',1,@n;
SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceipts);
EXEC test.AssertEq N'receipts after the rejected approval',0,@n;
PRINT 'PASS';
