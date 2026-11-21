-- TEST: usp_LookupByScan returns the variant of a known code, nothing for an unknown code, and every candidate for an ambiguous code.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @product uniqueidentifier=NEWID(),@itemA uniqueidentifier=NEWID(),@itemB uniqueidentifier=NEWID(),
  @actor uniqueidentifier=test.Id('manager'),@node uniqueidentifier=test.Id('nodeA'),
  @supplier uniqueidentifier=test.Id('supplier'),@sizeM uniqueidentifier=test.Id('sizeM'),
  @sizeS uniqueidentifier=test.Id('sizeS'),@colorB uniqueidentifier=test.Id('colorBlack'),
  @colorW uniqueidentifier=test.Id('colorWhite'),
  @e1 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),@e3 uniqueidentifier=NEWID(),@n bigint;
DECLARE @hits TABLE(ItemId uniqueidentifier,Sku nvarchar(100),VariantName nvarchar(200),
  UnitPriceMinor bigint,CurrencyCode varchar(3),Status varchar(20),ProductName nvarchar(200),
  SizeCode nvarchar(30),ColorCode nvarchar(30));

-- A known barcode resolves to exactly one variant.
INSERT INTO @hits EXEC catalog.usp_LookupByScan @RawCode=N'0000123456789';
SET @n=(SELECT COUNT(*) FROM @hits);
EXEC test.AssertEq N'rows for a known barcode',1,@n;
SET @n=(SELECT COUNT(*) FROM @hits WHERE ItemId=test.Id('item') AND Sku=N'T-SKU-0001'
        AND UnitPriceMinor=120000 AND CurrencyCode='NIO' AND Status='active');
EXEC test.AssertEq N'the known barcode resolves to the right variant',1,@n;
DELETE FROM @hits;

-- Retry with the same ids: the lookup answers the same thing.
INSERT INTO @hits EXEC catalog.usp_LookupByScan @RawCode=N'0000123456789';
SET @n=(SELECT COUNT(*) FROM @hits);
EXEC test.AssertEq N'rows for the known barcode after the retry',1,@n;
SET @n=(SELECT COUNT(*) FROM @hits WHERE ItemId=test.Id('item'));
EXEC test.AssertEq N'the same variant after the retry',1,@n;
DELETE FROM @hits;

-- An unknown code resolves to nothing: the caller must not invent a variant.
INSERT INTO @hits EXEC catalog.usp_LookupByScan @RawCode=N'NO-EXISTE-9999';SET @n=(SELECT COUNT(*) FROM @hits);
EXEC test.AssertEq N'rows for an unknown code',0,@n;
DELETE FROM @hits;

-- A supplier sku only resolves for its own supplier.
INSERT INTO @hits EXEC catalog.usp_LookupByScan @RawCode=N'PROV-0001',@SupplierId=@supplier;
SET @n=(SELECT COUNT(*) FROM @hits);
EXEC test.AssertEq N'rows for a supplier sku with its supplier',1,@n;
DELETE FROM @hits;
INSERT INTO @hits EXEC catalog.usp_LookupByScan @RawCode=N'PROV-0001';
SET @n=(SELECT COUNT(*) FROM @hits);
EXEC test.AssertEq N'rows for a supplier sku without supplier',0,@n;
DELETE FROM @hits;

-- The same code registered for two variants: the lookup must return both, not pick one.
EXEC catalog.usp_RegisterProduct @ProductId=@product,@Name=N'Producto Ambiguo',@ActorId=@actor,
  @OriginNodeId=@node,@EventId=@e1;
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-AMB-0001',@VariantName=N'Variante A',
  @CurrencyCode='NIO',@UnitPriceMinor=10000,@UnitCostMinor=5000,@Barcode=N'0000777000001',
  @SizeId=@sizeM,@ColorId=@colorB,@ActorId=@actor,@ItemId=@itemA,@OriginNodeId=@node,@EventId=@e2;
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-AMB-0002',@VariantName=N'Variante B',
  @CurrencyCode='NIO',@UnitPriceMinor=10000,@UnitCostMinor=5000,@SupplierId=@supplier,
  @SupplierSku=N'0000777000001',@SizeId=@sizeS,@ColorId=@colorW,@ActorId=@actor,
  @ItemId=@itemB,@OriginNodeId=@node,@EventId=@e3;

INSERT INTO @hits EXEC catalog.usp_LookupByScan @RawCode=N'0000777000001',@SupplierId=@supplier;
SET @n=(SELECT COUNT(*) FROM @hits);
EXEC test.AssertEq N'rows for an ambiguous code seen by its supplier',2,@n;
SET @n=(SELECT COUNT(*) FROM @hits WHERE ItemId IN (@itemA,@itemB));
EXEC test.AssertEq N'both candidates are returned',2,@n;
DELETE FROM @hits;
INSERT INTO @hits EXEC catalog.usp_LookupByScan @RawCode=N'0000777000001';
SET @n=(SELECT COUNT(*) FROM @hits);
EXEC test.AssertEq N'rows for the ambiguous code without supplier',1,@n;
SET @n=(SELECT COUNT(*) FROM @hits WHERE ItemId=@itemA);
EXEC test.AssertEq N'only the own-barcode variant is visible without supplier',1,@n;
PRINT 'PASS';
