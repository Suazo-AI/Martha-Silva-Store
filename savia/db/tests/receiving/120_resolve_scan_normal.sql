-- TEST: usp_ResolveScan binds an ambiguous read to one variant with a reason, and only that variant receives the stock.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@supplier uniqueidentifier=test.Id('supplier'),
  @actor uniqueidentifier=test.Id('cashierA'),@reviewer uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@product uniqueidentifier=NEWID(),
  @itemA uniqueidentifier=NEWID(),@itemB uniqueidentifier=NEWID(),
  @sizeM uniqueidentifier=test.Id('sizeM'),@sizeS uniqueidentifier=test.Id('sizeS'),
  @colorB uniqueidentifier=test.Id('colorBlack'),@colorW uniqueidentifier=test.Id('colorWhite'),
  @e1 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),@e3 uniqueidentifier=NEWID(),
  @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),@scan uniqueidentifier=NEWID(),
  @receipt uniqueidentifier,@n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

EXEC catalog.usp_RegisterProduct @ProductId=@product,@Name=N'Producto Ambiguo',@ActorId=@reviewer,
  @OriginNodeId=@node,@EventId=@e1;
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-RES-0001',@VariantName=N'Variante A',
  @CurrencyCode='NIO',@UnitPriceMinor=10000,@UnitCostMinor=5000,@Barcode=N'0000777000001',
  @SizeId=@sizeM,@ColorId=@colorB,@ActorId=@reviewer,@ItemId=@itemA,@OriginNodeId=@node,@EventId=@e2;
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-RES-0002',@VariantName=N'Variante B',
  @CurrencyCode='NIO',@UnitPriceMinor=10000,@UnitCostMinor=5000,@SupplierId=@supplier,
  @SupplierSku=N'0000777000001',@SizeId=@sizeS,@ColorId=@colorW,@ActorId=@reviewer,
  @ItemId=@itemB,@OriginNodeId=@node,@EventId=@e3;

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-RES',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000777000001',2,NULL,@actor;

EXEC receiving.usp_ResolveScan @scan,@itemA,@reviewer,N'Revisado: es la variante negra';

SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE Id=@scan AND ItemId=@itemA
        AND MatchStatus='matched' AND ResolutionReason=N'Revisado: es la variante negra');
EXEC test.AssertEq N'the read is bound to the chosen variant',1,@n;

-- The resolution decides the variant that receives the stock.
EXEC receiving.usp_ApproveScanSession @session,@reviewer;
EXEC receiving.usp_PostScanSession @ScanSessionId=@session,@ActorId=@actor,@OriginNodeId=@node,
  @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;

SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceiptLines WHERE GoodsReceiptId=@receipt AND ItemId=@itemA
        AND Quantity=2);
EXEC test.AssertEq N'receipt line of the chosen variant',1,@n;
SET @n=(SELECT COUNT(*) FROM purchasing.GoodsReceiptLines WHERE GoodsReceiptId=@receipt AND ItemId=@itemB);
EXEC test.AssertEq N'receipt lines of the other variant',0,@n;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances WHERE ItemId=@itemA AND LocationId=@loc);
EXEC test.AssertEq N'stock of the chosen variant',2,@n;
SET @n=(SELECT COALESCE(SUM(OnHand),0) FROM inventory.StockBalances WHERE ItemId=@itemB AND LocationId=@loc);
EXEC test.AssertEq N'stock of the other variant',0,@n;
PRINT 'PASS';
