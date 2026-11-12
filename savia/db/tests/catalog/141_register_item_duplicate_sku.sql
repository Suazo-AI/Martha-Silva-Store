-- TEST: registering a variant whose internal SKU is already used by another variant is rejected with a catalog domain error, not with a raw SQL constraint violation.
-- XFAIL: D-A-04 usp_RegisterItem rejects a repeated internal SKU with raw SQL error 2627 instead of a catalog domain error like 51204/51205.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @product uniqueidentifier=test.Id('product'),@item1 uniqueidentifier=NEWID(),
  @item2 uniqueidentifier=NEWID(),@actor uniqueidentifier=test.Id('manager'),
  @node uniqueidentifier=test.Id('nodeA'),@event uniqueidentifier=NEWID(),@n bigint,
  @raw int,@msg nvarchar(600);

EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-DUP-0001',@VariantName=N'Variante Con SKU',
  @CurrencyCode='NIO',@UnitPriceMinor=10000,@UnitCostMinor=5000,@Barcode=N'0000888111222',
  @ActorId=@actor,@ItemId=@item1,@OriginNodeId=@node,@EventId=@event;

BEGIN TRY
  EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-DUP-0001',@VariantName=N'Variante Con El Mismo SKU',
    @CurrencyCode='NIO',@UnitPriceMinor=10000,@UnitCostMinor=5000,@Barcode=N'0000888111223',
    @ActorId=@actor,@ItemId=@item2,@OriginNodeId=@node,@EventId=@event;
  THROW 59002,'ASSERT FAIL: a repeated internal SKU was accepted',1;
END TRY
BEGIN CATCH
  IF ERROR_NUMBER()=59002 THROW;
  SET @raw=ERROR_NUMBER();
  IF @raw<51200 OR @raw>51299
  BEGIN
    SET @msg=CONCAT(N'ASSERT FAIL: the repeated SKU was rejected with raw SQL error ',@raw,
      N' instead of a catalog domain error');
    THROW 59003,@msg,1;
  END;
END CATCH;

SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Sku=N'T-DUP-0001');
EXEC test.AssertEq N'variants with that SKU',1,@n;
SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Id=@item2);
EXEC test.AssertEq N'the rejected variant',0,@n;
PRINT 'PASS';
