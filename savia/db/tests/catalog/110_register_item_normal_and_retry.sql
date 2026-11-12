-- TEST: usp_RegisterItem registers the variant, its codes with their leading zeros and one event; a retry with the same ids changes nothing.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @product uniqueidentifier=test.Id('product'),@item uniqueidentifier=NEWID(),
  @itemDraft uniqueidentifier=NEWID(),@actor uniqueidentifier=test.Id('manager'),
  @node uniqueidentifier=test.Id('nodeA'),@supplier uniqueidentifier=test.Id('supplier'),
  @size uniqueidentifier=test.Id('sizeS'),@color uniqueidentifier=test.Id('colorBlack'),
  @size2 uniqueidentifier=test.Id('sizeL'),@color2 uniqueidentifier=test.Id('colorWhite'),
  @event uniqueidentifier=NEWID(),@event2 uniqueidentifier=NEWID(),@n bigint;

EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-NEW-0001',@VariantName=N'Blusa Roja L',
  @CurrencyCode='NIO',@UnitPriceMinor=99000,@UnitCostMinor=45000,@Barcode=N'0000223344556',
  @SizeId=@size,@ColorId=@color,@SupplierId=@supplier,@SupplierSku=N'PROV-NEW-1',
  @ActorId=@actor,@ItemId=@item,@OriginNodeId=@node,@EventId=@event;

SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Id=@item AND Sku=N'T-NEW-0001' AND ProductId=@product);
EXEC test.AssertEq N'item rows',1,@n;
SET @n=(SELECT UnitPriceMinor FROM catalog.Items WHERE Id=@item);
EXEC test.AssertEq N'unit price',99000,@n;
SET @n=(SELECT UnitCostMinor FROM catalog.Items WHERE Id=@item);
EXEC test.AssertEq N'unit cost',45000,@n;
SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Id=@item AND Status='active');
EXEC test.AssertEq N'item active with price and cost',1,@n;
-- The barcode keeps its leading zeros in the identifier table.
SET @n=(SELECT COUNT(*) FROM catalog.ItemIdentifiers WHERE ItemId=@item AND Kind='barcode'
        AND RawCode=N'0000223344556' AND IsActive=1 AND IsPrimary=1 AND SupplierId IS NULL);
EXEC test.AssertEq N'barcode identifier with leading zeros',1,@n;
SET @n=(SELECT COUNT(*) FROM catalog.ItemIdentifiers WHERE ItemId=@item AND Kind='supplier_sku'
        AND RawCode=N'PROV-NEW-1' AND SupplierId=@supplier);
EXEC test.AssertEq N'supplier sku identifier',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventId=@event AND AggregateType='item'
        AND AggregateId=@item AND EventType='catalog.item_registered');
EXEC test.AssertEq N'catalog.item_registered event in outbox',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventId=@event AND PayloadJson LIKE N'%0000223344556%');
EXEC test.AssertEq N'event payload carries the barcode with leading zeros',1,@n;

-- Retry with the same ids: the client never got the reply.
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-NEW-0001',@VariantName=N'Blusa Roja L',
  @CurrencyCode='NIO',@UnitPriceMinor=99000,@UnitCostMinor=45000,@Barcode=N'0000223344556',
  @SizeId=@size,@ColorId=@color,@SupplierId=@supplier,@SupplierSku=N'PROV-NEW-1',
  @ActorId=@actor,@ItemId=@item,@OriginNodeId=@node,@EventId=@event;

SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Id=@item);
EXEC test.AssertEq N'item rows after the retry',1,@n;
SET @n=(SELECT COUNT(*) FROM catalog.ItemIdentifiers WHERE ItemId=@item);
EXEC test.AssertEq N'identifiers after the retry',2,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@item AND EventType='catalog.item_registered');
EXEC test.AssertEq N'events for the item after the retry',1,@n;

-- Without an approved cost the variant stays in draft: it may enter quarantine but not be sold.
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-NEW-0002',@VariantName=N'Blusa Sin Costo',
  @CurrencyCode='NIO',@UnitPriceMinor=99000,@Barcode=N'0000223344557',
  @SizeId=@size2,@ColorId=@color2,@ActorId=@actor,@ItemId=@itemDraft,@OriginNodeId=@node,@EventId=@event2;
SET @n=(SELECT COUNT(*) FROM catalog.Items WHERE Id=@itemDraft AND Status='draft' AND UnitCostMinor IS NULL);
EXEC test.AssertEq N'variant without cost stays draft',1,@n;
PRINT 'PASS';
