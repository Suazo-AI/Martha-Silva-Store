-- TEST: the paged sale catalog returns the same products as the single answer, whole products per page, then a null key (V042, D-041).
SET NOCOUNT ON;SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@actor uniqueidentifier=test.Id('manager'),@node uniqueidentifier=test.Id('nodeA'),
 @p uniqueidentifier,@i uniqueidentifier,@e uniqueidentifier,@k int=0,@sku nvarchar(100),@code nvarchar(128),@name nvarchar(200),@n bigint,
 @sS uniqueidentifier=test.Id('sizeS'),@sM uniqueidentifier=test.Id('sizeM');
-- Four more products with one or two active variants each; the fixture product "Blusa Test" has two.
WHILE @k<4
BEGIN
 SELECT @k+=1,@p=NEWID(),@e=NEWID(),@name=CONCAT(N'Falda ',@k);
 EXEC catalog.usp_RegisterProduct @ProductId=@p,@Name=@name,@ActorId=@actor,@OriginNodeId=@node,@EventId=@e;
 SELECT @i=NEWID(),@e=NEWID(),@sku=CONCAT(N'T-FAL-',@k,N'-A'),@code=CONCAT(N'99000000',@k,N'1');
 EXEC catalog.usp_RegisterItem @ProductId=@p,@Sku=@sku,@VariantName=@sku,@CurrencyCode='NIO',@UnitPriceMinor=1000,@Barcode=@code,@SizeId=@sS,
   @ActorId=@actor,@ItemId=@i,@OriginNodeId=@node,@EventId=@e;
 IF @k%2=0
 BEGIN
  SELECT @i=NEWID(),@e=NEWID(),@sku=CONCAT(N'T-FAL-',@k,N'-B'),@code=CONCAT(N'99000000',@k,N'2');
  EXEC catalog.usp_RegisterItem @ProductId=@p,@Sku=@sku,@VariantName=@sku,@CurrencyCode='NIO',@UnitPriceMinor=1000,@Barcode=@code,@SizeId=@sM,
    @ActorId=@actor,@ItemId=@i,@OriginNodeId=@node,@EventId=@e;
 END;
END;
UPDATE catalog.Items SET Status='active' WHERE Sku LIKE N'T-FAL-%';

DECLARE @whole TABLE(Json nvarchar(max));
INSERT @whole EXEC catalog.usp_ListSaleCatalog @loc;
DECLARE @expected nvarchar(max)=(SELECT STRING_AGG(CONVERT(nvarchar(max),p.[key]+N':'+JSON_VALUE(p.value,'$.productId')+N'/'+v.Skus),N',')
  WITHIN GROUP (ORDER BY CONVERT(int,p.[key]))
  FROM @whole w CROSS APPLY OPENJSON(w.Json) p
  CROSS APPLY(SELECT STRING_AGG(JSON_VALUE(x.value,'$.sku'),N'+') WITHIN GROUP (ORDER BY CONVERT(int,x.[key])) AS Skus FROM OPENJSON(p.value,'$.variants') x) v);
SET @n=(SELECT COUNT(*) FROM @whole w CROSS APPLY OPENJSON(w.Json));EXEC test.AssertEq N'products in the single answer',5,@n;

-- Pages of at most 2 variants: [Blusa Test 2] [Falda 1] [Falda 2 2] [Falda 3] [Falda 4 2]; Falda 3 + Falda 4 would be 3 -> 5 pages.
DECLARE @page TABLE(Json nvarchar(max),NextAfter uniqueidentifier);
DECLARE @after uniqueidentifier=NULL,@limit int=2,@pages int=0,@seen nvarchar(max)=N'',@base int=0,@variants int,@products int;
WHILE 1=1
BEGIN
 DELETE @page;INSERT @page EXEC catalog.usp_ListSaleCatalog @loc,@after,@limit;
 SET @pages+=1;
 SELECT @products=COUNT(*),@variants=SUM(v.n) FROM @page g CROSS APPLY OPENJSON(g.Json) p
  CROSS APPLY(SELECT COUNT(*) AS n FROM OPENJSON(p.value,'$.variants')) v;
 IF @variants>@limit AND @products>1 THROW 59002,'ASSERT FAIL: a page with several products is larger than the limit',1;
 SET @seen+=(SELECT STRING_AGG(CONVERT(nvarchar(max),CONCAT(@base+CONVERT(int,p.[key]),N':',JSON_VALUE(p.value,'$.productId'),N'/',v.Skus)),N',')
   WITHIN GROUP (ORDER BY CONVERT(int,p.[key]))
   FROM @page g CROSS APPLY OPENJSON(g.Json) p
   CROSS APPLY(SELECT STRING_AGG(JSON_VALUE(x.value,'$.sku'),N'+') WITHIN GROUP (ORDER BY CONVERT(int,x.[key])) AS Skus FROM OPENJSON(p.value,'$.variants') x) v)+N',';
 SET @base+=@products;
 SET @after=(SELECT NextAfter FROM @page);
 IF @after IS NULL BREAK;
 IF @pages>10 THROW 59002,'ASSERT FAIL: paging does not end',1;
END;
EXEC test.AssertEq N'pages of two variants',5,@pages;
SET @n=IIF(LEFT(@seen,LEN(@seen)-1) COLLATE Latin1_General_100_BIN2=@expected,1,0);
IF @n=0 BEGIN PRINT CONCAT(N'expected: ',@expected);PRINT CONCAT(N'pages: ',@seen); END;
EXEC test.AssertEq N'pages joined equal the single answer',1,@n;

-- A product larger than the page still comes whole, alone.
SET @limit=1;SET @after=NULL;DELETE @page;INSERT @page EXEC catalog.usp_ListSaleCatalog @loc,@after,@limit;
SET @n=(SELECT COUNT(*) FROM @page g CROSS APPLY OPENJSON(g.Json) p CROSS APPLY OPENJSON(p.value,'$.variants'));
EXEC test.AssertEq N'first page keeps the whole first product',2,@n;
SET @n=IIF((SELECT NextAfter FROM @page) IS NULL,0,1);EXEC test.AssertEq N'a next key after the oversized page',1,@n;

-- An unknown key is rejected, not read as the start of the list.
SET @after=NEWID();
BEGIN TRY
 INSERT @page EXEC catalog.usp_ListSaleCatalog @loc,@after,@limit;
 THROW 59002,'ASSERT FAIL: an unknown page key was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51230 THROW; END CATCH;
PRINT 'PASS';
