-- TEST: catalog.usp_SearchItems returns the same rows, in the same order, as the inline search it replaced (V041, P3).
SET NOCOUNT ON;SET XACT_ABORT ON;
GO
-- The query of CatalogStore.SearchAsync before V041, with its escaping, kept here as the reference.
CREATE PROCEDURE test.usp_SearchInline @Text nvarchar(100),@LocationId uniqueidentifier,@Limit int
AS BEGIN
 SET NOCOUNT ON;
 DECLARE @pattern nvarchar(400)=N'%'+REPLACE(REPLACE(REPLACE(REPLACE(@Text,N'\',N'\\'),N'%',N'\%'),N'_',N'\_'),N'[',N'\[')+N'%';
 SELECT TOP (@Limit) i.Id,i.Sku,p.Name,i.VariantName,sz.Code,co.Code,
   (SELECT TOP (1) x.RawCode FROM catalog.ItemIdentifiers x
     WHERE x.ItemId=i.Id AND x.Kind='barcode' AND x.IsActive=1 ORDER BY x.IsPrimary DESC,x.CreatedAt,x.Id),
   i.UnitPriceMinor,i.CurrencyCode,i.Status,
   CASE WHEN @LocationId IS NULL THEN NULL ELSE ISNULL(st.OnHand,0) END,
   CASE WHEN @LocationId IS NULL THEN NULL ELSE ISNULL(st.Available,0) END
 FROM catalog.Items i
 JOIN catalog.Products p ON p.Id=i.ProductId
 LEFT JOIN catalog.Sizes sz ON sz.Id=i.SizeId
 LEFT JOIN catalog.Colors co ON co.Id=i.ColorId
 OUTER APPLY (SELECT SUM(v.OnHand) AS OnHand,SUM(v.Available) AS Available FROM inventory.vw_StockAvailable v
              WHERE v.ItemId=i.Id AND v.LocationId=@LocationId AND v.Pool='store') st
 WHERE i.Status IN ('active','draft')
   AND (p.Name COLLATE Latin1_General_100_CI_AI LIKE @pattern ESCAPE '\'
     OR i.VariantName COLLATE Latin1_General_100_CI_AI LIKE @pattern ESCAPE '\'
     OR i.Sku COLLATE Latin1_General_100_CI_AI LIKE @pattern ESCAPE '\'
     OR EXISTS (SELECT 1 FROM catalog.ItemIdentifiers x WHERE x.ItemId=i.Id AND x.IsActive=1
                AND x.RawCode COLLATE Latin1_General_100_CI_AI LIKE @pattern ESCAPE '\'))
 ORDER BY p.Name,i.Sku;
END;
GO
DECLARE @loc uniqueidentifier=test.Id('locA'),@item uniqueidentifier=test.Id('item'),@actor uniqueidentifier=test.Id('manager'),
 @node uniqueidentifier=test.Id('nodeA'),@pants uniqueidentifier=NEWID(),@pantsItem uniqueidentifier=NEWID(),
 @e1 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),@sM uniqueidentifier=test.Id('sizeM');
EXEC test.SeedStock @item,@loc,3;
-- Accents, tildes and upper case in the stored text.
EXEC catalog.usp_RegisterProduct @ProductId=@pants,@Name=N'Pantalón Ñandú',@ActorId=@actor,@OriginNodeId=@node,@EventId=@e1;
EXEC catalog.usp_RegisterItem @ProductId=@pants,@Sku=N'T-PAN-0001',@VariantName=N'PANTALÓN AZUL M',
  @CurrencyCode='NIO',@UnitPriceMinor=150000,@Barcode=N'7700000000017',@SizeId=@sM,@ActorId=@actor,@ItemId=@pantsItem,
  @OriginNodeId=@node,@EventId=@e2;

DECLARE @terms TABLE(Seq int IDENTITY,Term nvarchar(100),Lim int);
INSERT @terms(Term,Lim) VALUES(N'blusa',25),(N'BLÚSA',25),(N'blusa',1),(N'sku-0002',25),(N'PROV-00',25),(N'1234567',25),
 (N'T%SKU',25),(N'T-SKU',2),(N'T-SKU-0001',25),(N'prov-0001',25),(N'negra m',25),(N'pantalon nandu',25),(N'PANTALÓN',25),
 (N'ñand',25),(N'azul',25),(N'zzqx',25),(N'_',25),(N'[a',25),(N'0000',25),(N'Test',25);
DECLARE @Rows TABLE(Id uniqueidentifier,Sku nvarchar(100),Name nvarchar(200),Variant nvarchar(200),SizeCode nvarchar(20),ColorCode nvarchar(20),
 Barcode nvarchar(128),Price bigint,Currency char(3),Status varchar(20),OnHand int,Available int,Seq int IDENTITY);
DECLARE @seq int=0,@term nvarchar(100),@lim int,@old nvarchar(max),@new nvarchar(max),@same bigint,@what nvarchar(200),@where uniqueidentifier;
WHILE 1=1
BEGIN
 SELECT TOP(1) @seq=Seq,@term=Term,@lim=Lim FROM @terms WHERE Seq>@seq ORDER BY Seq;
 IF @@ROWCOUNT=0 BREAK;
 -- Both stock modes: a branch location and the cloud (no location).
 SET @where=@loc;
 WHILE 1=1
 BEGIN
  DELETE @Rows;INSERT @Rows(Id,Sku,Name,Variant,SizeCode,ColorCode,Barcode,Price,Currency,Status,OnHand,Available)
   EXEC test.usp_SearchInline @term,@where,@lim;
  SET @old=(SELECT Id,Sku,Name,Variant,SizeCode,ColorCode,Barcode,Price,Currency,Status,OnHand,Available FROM @Rows ORDER BY Seq FOR JSON PATH,INCLUDE_NULL_VALUES);
  DELETE @Rows;INSERT @Rows(Id,Sku,Name,Variant,SizeCode,ColorCode,Barcode,Price,Currency,Status,OnHand,Available)
   EXEC catalog.usp_SearchItems @term,@where,@lim;
  SET @new=(SELECT Id,Sku,Name,Variant,SizeCode,ColorCode,Barcode,Price,Currency,Status,OnHand,Available FROM @Rows ORDER BY Seq FOR JSON PATH,INCLUDE_NULL_VALUES);
  SET @same=IIF(ISNULL(@old,N'') COLLATE Latin1_General_100_BIN2=ISNULL(@new,N''),1,0);
  IF @same=0 BEGIN PRINT CONCAT(N'old: ',@old);PRINT CONCAT(N'new: ',@new); END;
  SET @what=CONCAT(N'same rows for "',@term,N'" limit ',@lim,IIF(@where IS NULL,N' (cloud)',N''));
  EXEC test.AssertEq @what,1,@same;
  IF @where IS NULL BREAK;
  SET @where=NULL;
 END;
END;
PRINT 'PASS';
