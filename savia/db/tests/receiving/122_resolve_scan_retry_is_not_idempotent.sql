-- TEST: resolving the same read again with the same ids is a no-op that keeps the resolution.
-- XFAIL: D-A-01 usp_ResolveScan is not idempotent: a retry with the same ids fails with 51305 instead of returning the resolution.
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
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-RETRY-0001',@VariantName=N'Variante A',
  @CurrencyCode='NIO',@UnitPriceMinor=10000,@UnitCostMinor=5000,@Barcode=N'0000777000001',
  @SizeId=@sizeM,@ColorId=@colorB,@ActorId=@manager,@ItemId=@itemA,@OriginNodeId=@node,@EventId=@e2;
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-RETRY-0002',@VariantName=N'Variante B',
  @CurrencyCode='NIO',@UnitPriceMinor=10000,@UnitCostMinor=5000,@SupplierId=@supplier,
  @SupplierSku=N'0000777000001',@SizeId=@sizeS,@ColorId=@colorW,@ActorId=@manager,
  @ItemId=@itemB,@OriginNodeId=@node,@EventId=@e3;

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-RESRETRY',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000777000001',2,NULL,@actor;

EXEC receiving.usp_ResolveScan @scan,@itemA,@reviewer,N'Revisado: es la variante negra';

-- Retry with the same ids: the client never got the reply.
EXEC receiving.usp_ResolveScan @scan,@itemA,@reviewer,N'Revisado: es la variante negra';

SET @n=(SELECT COUNT(*) FROM receiving.ScanEvents WHERE Id=@scan AND ItemId=@itemA
        AND MatchStatus='matched' AND ResolutionReason=N'Revisado: es la variante negra');
EXEC test.AssertEq N'the read keeps its resolution',1,@n;
PRINT 'PASS';
