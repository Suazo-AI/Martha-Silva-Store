-- TEST: catalog.ItemSearch equals a fresh compute after every kind of catalog change, so search never drifts (V041 triggers).
SET NOCOUNT ON;SET XACT_ABORT ON;
GO
CREATE PROCEDURE test.AssertItemSearchCurrent @Step nvarchar(100)
AS BEGIN
 SET NOCOUNT ON;
 -- Exact comparison: every text column in BIN2.
 DECLARE @drift bigint=(SELECT COUNT(*) FROM (
   (SELECT ItemId,ProductName COLLATE Latin1_General_100_BIN2 AS ProductName,Sku,Status,SearchText FROM catalog.ItemSearch
    EXCEPT SELECT ItemId,ProductName COLLATE Latin1_General_100_BIN2,Sku,Status,SearchText COLLATE Latin1_General_100_BIN2 FROM catalog.vw_ItemSearchSource)
   UNION ALL
   (SELECT ItemId,ProductName COLLATE Latin1_General_100_BIN2,Sku,Status,SearchText COLLATE Latin1_General_100_BIN2 FROM catalog.vw_ItemSearchSource
    EXCEPT SELECT ItemId,ProductName COLLATE Latin1_General_100_BIN2,Sku,Status,SearchText FROM catalog.ItemSearch)) d);
 DECLARE @what nvarchar(200)=CONCAT(N'ItemSearch rows that differ from the source after: ',@Step);
 EXEC test.AssertEq @what,0,@drift;
END;
GO
DECLARE @product uniqueidentifier=test.Id('product'),@item uniqueidentifier=test.Id('item'),@item2 uniqueidentifier=test.Id('item2'),
 @actor uniqueidentifier=test.Id('manager'),@node uniqueidentifier=test.Id('nodeA'),@new uniqueidentifier=NEWID(),
 @e1 uniqueidentifier=NEWID(),@n bigint;
EXEC test.AssertItemSearchCurrent N'fixture';
SET @n=(SELECT COUNT(*) FROM catalog.ItemSearch);EXEC test.AssertEq N'one search row per item',3,@n;

EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-SKU-0009',@VariantName=N'Blusa Verde XL',
  @CurrencyCode='NIO',@UnitPriceMinor=99000,@Barcode=N'0000999000999',@ActorId=@actor,@ItemId=@new,@OriginNodeId=@node,@EventId=@e1;
EXEC test.AssertItemSearchCurrent N'new item with a barcode';

UPDATE catalog.Products SET Name=N'Blusa Lúcida' WHERE Id=@product;
EXEC test.AssertItemSearchCurrent N'product rename';

UPDATE catalog.Items SET VariantName=N'Blusa Negra Mediana',Sku=N'T-SKU-0001B' WHERE Id=@item;
UPDATE catalog.Items SET Status='inactive' WHERE Id=@item2;
EXEC test.AssertItemSearchCurrent N'variant name, SKU and status change';

UPDATE catalog.Items SET UnitPriceMinor=UnitPriceMinor+1 WHERE Id=@item;
EXEC test.AssertItemSearchCurrent N'price change';

UPDATE catalog.ItemIdentifiers SET IsActive=0 WHERE ItemId=@item AND Kind='barcode';
EXEC test.AssertItemSearchCurrent N'barcode deactivated';
INSERT catalog.ItemIdentifiers(ItemId,Kind,RawCode,IsActive) VALUES(@item,'barcode',N'5550001112223',1);
EXEC test.AssertItemSearchCurrent N'barcode added';
DELETE catalog.ItemIdentifiers WHERE ItemId=@new;
DELETE catalog.Items WHERE Id=@new;
EXEC test.AssertItemSearchCurrent N'item deleted';

-- Search reads the new text: the renamed product and the new code; the old barcode is gone.
DECLARE @Rows TABLE(Id uniqueidentifier,Sku nvarchar(100),Name nvarchar(200),Variant nvarchar(200),SizeCode nvarchar(20),ColorCode nvarchar(20),
 Barcode nvarchar(128),Price bigint,Currency char(3),Status varchar(20),OnHand int,Available int);
DECLARE @loc uniqueidentifier=NULL,@text nvarchar(100)=N'lucida';
INSERT @Rows EXEC catalog.usp_SearchItems @text,@loc,25;
SET @n=(SELECT COUNT(*) FROM @Rows);EXEC test.AssertEq N'renamed product found without its accent',2,@n;
DELETE @Rows;SET @text=N'5550001112223';INSERT @Rows EXEC catalog.usp_SearchItems @text,@loc,25;
SET @n=(SELECT COUNT(*) FROM @Rows WHERE Id=@item);EXEC test.AssertEq N'new barcode found',1,@n;
DELETE @Rows;SET @text=N'0000123456789';INSERT @Rows EXEC catalog.usp_SearchItems @text,@loc,25;
SET @n=(SELECT COUNT(*) FROM @Rows);EXEC test.AssertEq N'deactivated barcode no longer found',0,@n;
PRINT 'PASS';
