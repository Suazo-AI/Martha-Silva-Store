-- TEST: usp_RegisterItem rejects missing codes (51201), a supplier sku without supplier (51202), a negative price (51203), a reused item id (51211) and codes already in use (51204, 51205) without writing rows.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @product uniqueidentifier=test.Id('product'),@item uniqueidentifier=NEWID(),
  @item2 uniqueidentifier=NEWID(),@item3 uniqueidentifier=NEWID(),@item4 uniqueidentifier=NEWID(),
  @item5 uniqueidentifier=NEWID(),@item6 uniqueidentifier=NEWID(),
  @actor uniqueidentifier=test.Id('manager'),@node uniqueidentifier=test.Id('nodeA'),
  @supplier uniqueidentifier=test.Id('supplier'),@size uniqueidentifier=test.Id('sizeM'),
  @color uniqueidentifier=test.Id('colorBlack'),@event uniqueidentifier=NEWID(),@n bigint;

-- 51201: neither barcode nor supplier sku: the variant could never be scanned.
BEGIN TRY
  EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-ERR-0001',@VariantName=N'Sin Codigo',
    @CurrencyCode='NIO',@UnitPriceMinor=10000,@UnitCostMinor=5000,
    @ActorId=@actor,@ItemId=@item,@OriginNodeId=@node,@EventId=@event;
  THROW 59002,'ASSERT FAIL: a variant without any code was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51201 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Id=@item);
EXEC test.AssertEq N'items after the rejected missing code',0,@n;

-- 51202: supplier sku without supplier.
BEGIN TRY
  EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-ERR-0002',@VariantName=N'Sku Sin Proveedor',
    @CurrencyCode='NIO',@UnitPriceMinor=10000,@UnitCostMinor=5000,@SupplierSku=N'PROV-ERR-1',
    @ActorId=@actor,@ItemId=@item2,@OriginNodeId=@node,@EventId=@event;
  THROW 59002,'ASSERT FAIL: a supplier sku without supplier was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51202 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Id=@item2);
EXEC test.AssertEq N'items after the rejected supplier sku without supplier',0,@n;

-- 51203: negative price.
BEGIN TRY
  EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-ERR-0003',@VariantName=N'Precio Negativo',
    @CurrencyCode='NIO',@UnitPriceMinor=-1,@UnitCostMinor=5000,@Barcode=N'0000333444556',
    @ActorId=@actor,@ItemId=@item3,@OriginNodeId=@node,@EventId=@event;
  THROW 59002,'ASSERT FAIL: a negative price was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51203 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Id=@item3);
EXEC test.AssertEq N'items after the rejected negative price',0,@n;

-- 51204: the barcode already belongs to another variant.
BEGIN TRY
  EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-ERR-0004',@VariantName=N'Barcode Repetido',
    @CurrencyCode='NIO',@UnitPriceMinor=10000,@UnitCostMinor=5000,@Barcode=N'0000123456789',
    @ActorId=@actor,@ItemId=@item4,@OriginNodeId=@node,@EventId=@event;
  THROW 59002,'ASSERT FAIL: a barcode already in use was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51204 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Id=@item4);
EXEC test.AssertEq N'items after the rejected repeated barcode',0,@n;

-- 51205: the supplier sku already belongs to another variant of the same supplier.
BEGIN TRY
  EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-ERR-0005',@VariantName=N'Proveedor Repetido',
    @CurrencyCode='NIO',@UnitPriceMinor=10000,@UnitCostMinor=5000,@SupplierId=@supplier,@SupplierSku=N'PROV-0001',
    @ActorId=@actor,@ItemId=@item5,@OriginNodeId=@node,@EventId=@event;
  THROW 59002,'ASSERT FAIL: a supplier sku already in use was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51205 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Id=@item5);
EXEC test.AssertEq N'items after the rejected repeated supplier sku',0,@n;

-- 51211: the item id is reused for another variant.
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-ERR-0006',@VariantName=N'Variante Primera',
  @CurrencyCode='NIO',@UnitPriceMinor=10000,@UnitCostMinor=5000,@Barcode=N'0000444555667',
  @ActorId=@actor,@ItemId=@item6,@OriginNodeId=@node,@EventId=@event;
BEGIN TRY
  EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-ERR-0007',@VariantName=N'Variante Segunda',
    @CurrencyCode='NIO',@UnitPriceMinor=10000,@UnitCostMinor=5000,@Barcode=N'0000444555668',
    @ActorId=@actor,@ItemId=@item6,@OriginNodeId=@node,@EventId=@event;
  THROW 59002,'ASSERT FAIL: an item id was reused for another variant',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51211 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Id=@item6 AND Sku=N'T-ERR-0006');
EXEC test.AssertEq N'the first variant of the reused id survived',1,@n;
SET @n=(SELECT COUNT(*) FROM catalog.ItemIdentifiers WHERE ItemId=@item6);
EXEC test.AssertEq N'identifiers of the reused item id',1,@n;

-- Nothing rejected left a row behind.
SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Id IN (@item,@item2,@item3,@item4,@item5));
EXEC test.AssertEq N'items created by the rejected registrations',0,@n;
SET @n=(SELECT COUNT(*) FROM catalog.ItemIdentifiers WHERE ItemId IN (@item,@item2,@item3,@item4,@item5));
EXEC test.AssertEq N'identifiers created by the rejected registrations',0,@n;
PRINT 'PASS';
