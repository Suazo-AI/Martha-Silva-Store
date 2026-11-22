-- savia:transactional
-- V041 (P3, production readiness 2026-11-22): catalog search reads one narrow, pre-normalized row per item.
-- Before, every search compared four columns per item in Latin1_General_100_CI_AI and probed the identifiers of
-- every item (A-10: 1.5 M reads and about 2 s for a code with no match). Now the words are lowered and stripped of
-- accents once, when the item changes, and the search compares them in BIN2.
-- An exact SKU or code is found through an index seek before any scan.
CREATE OR ALTER FUNCTION catalog.ufn_SearchKey(@Text nvarchar(4000)) RETURNS nvarchar(4000) WITH SCHEMABINDING
AS
BEGIN
 -- Spanish accents and tildes only: ligatures such as ae or ss are not folded (Latin1_General_100_CI_AI folded them).
 RETURN TRANSLATE(LOWER(@Text) COLLATE Latin1_General_100_BIN2,
  N'áàâäãåéèêëíìîïóòôöõúùûüñçýÿ',N'aaaaaaeeeeiiiiooooouuuuncyy');
END;
GO

-- NCHAR(1) separates the fields so a term never matches across two of them.
-- SKU and codes are BIN2 and names are not: one collation for the concatenation, the key function compares in BIN2.
CREATE OR ALTER VIEW catalog.vw_ItemSearchSource
AS
SELECT i.Id AS ItemId,p.Name AS ProductName,i.Sku,i.Status,
 catalog.ufn_SearchKey(LEFT(CONCAT(p.Name,NCHAR(1),i.VariantName,NCHAR(1),i.Sku COLLATE DATABASE_DEFAULT,NCHAR(1),
  (SELECT STRING_AGG(CONVERT(nvarchar(max),x.RawCode) COLLATE DATABASE_DEFAULT,NCHAR(1)) FROM catalog.ItemIdentifiers x
   WHERE x.ItemId=i.Id AND x.IsActive=1)),4000)) AS SearchText
FROM catalog.Items i JOIN catalog.Products p ON p.Id=i.ProductId;
GO

-- Clustered in the search order (product name, SKU): a common word stops after the first page of hits.
CREATE TABLE catalog.ItemSearch(
 ItemId uniqueidentifier NOT NULL CONSTRAINT PK_ItemSearch PRIMARY KEY NONCLUSTERED,
 ProductName nvarchar(200) NOT NULL,
 Sku nvarchar(100) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Status varchar(20) NOT NULL,
 SearchText nvarchar(4000) COLLATE Latin1_General_100_BIN2 NOT NULL);
CREATE UNIQUE CLUSTERED INDEX CX_ItemSearch_Order ON catalog.ItemSearch(ProductName,Sku);
INSERT catalog.ItemSearch(ItemId,ProductName,Sku,Status,SearchText) SELECT ItemId,ProductName,Sku,Status,SearchText FROM catalog.vw_ItemSearchSource;
-- Exact code lookup for search; scans use the scoped unique indexes instead.
CREATE INDEX IX_ItemIdentifiers_RawCode ON catalog.ItemIdentifiers(RawCode) INCLUDE(ItemId) WHERE IsActive=1;
GO

-- Every writer of items, product names and codes (procedures, import, fixtures, direct inserts) keeps the table current.
CREATE OR ALTER TRIGGER catalog.tr_Items_Search ON catalog.Items AFTER INSERT,UPDATE,DELETE
AS
BEGIN
 SET NOCOUNT ON;
 -- Price, cost and tax changes do not touch the searched text.
 IF EXISTS(SELECT 1 FROM inserted) AND EXISTS(SELECT 1 FROM deleted)
  AND NOT (UPDATE(Sku) OR UPDATE(VariantName) OR UPDATE(Status) OR UPDATE(ProductId)) RETURN;
 DELETE s FROM catalog.ItemSearch s WHERE s.ItemId IN (SELECT Id FROM inserted UNION SELECT Id FROM deleted);
 INSERT catalog.ItemSearch(ItemId,ProductName,Sku,Status,SearchText)
  SELECT v.ItemId,v.ProductName,v.Sku,v.Status,v.SearchText FROM catalog.vw_ItemSearchSource v WHERE v.ItemId IN (SELECT Id FROM inserted);
END;
GO

CREATE OR ALTER TRIGGER catalog.tr_Products_Search ON catalog.Products AFTER UPDATE
AS
BEGIN
 SET NOCOUNT ON;
 IF NOT UPDATE(Name) RETURN;
 UPDATE s SET ProductName=v.ProductName,SearchText=v.SearchText
  FROM catalog.ItemSearch s JOIN catalog.vw_ItemSearchSource v ON v.ItemId=s.ItemId
  JOIN catalog.Items i ON i.Id=s.ItemId JOIN inserted p ON p.Id=i.ProductId;
END;
GO

CREATE OR ALTER TRIGGER catalog.tr_ItemIdentifiers_Search ON catalog.ItemIdentifiers AFTER INSERT,UPDATE,DELETE
AS
BEGIN
 SET NOCOUNT ON;
 -- Delete and insert, as tr_Items_Search does: an UPDATE through the view cost about 4 ms per imported row.
 DELETE s FROM catalog.ItemSearch s WHERE s.ItemId IN (SELECT ItemId FROM inserted UNION SELECT ItemId FROM deleted);
 INSERT catalog.ItemSearch(ItemId,ProductName,Sku,Status,SearchText)
  SELECT v.ItemId,v.ProductName,v.Sku,v.Status,v.SearchText FROM catalog.vw_ItemSearchSource v
  WHERE v.ItemId IN (SELECT ItemId FROM inserted UNION SELECT ItemId FROM deleted);
END;
GO

-- Same rows, columns and order as the inline query of CatalogStore.SearchAsync before V041.
CREATE OR ALTER PROCEDURE catalog.usp_SearchItems @Text nvarchar(100),@LocationId uniqueidentifier=NULL,@Limit int
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @key nvarchar(4000)=catalog.ufn_SearchKey(@Text);
 DECLARE @hits TABLE(ItemId uniqueidentifier NOT NULL PRIMARY KEY);
 -- A whole SKU or code typed or pasted: seek, and list only the items it names.
 INSERT @hits(ItemId)
  SELECT i.Id FROM catalog.Items i WHERE i.Sku IN (@Text,UPPER(@Text)) AND i.Status IN ('active','draft')
  UNION SELECT x.ItemId FROM catalog.ItemIdentifiers x JOIN catalog.Items i ON i.Id=x.ItemId
  WHERE x.RawCode=@Text AND x.IsActive=1 AND i.Status IN ('active','draft');
 IF @@ROWCOUNT=0 AND CHARINDEX(NCHAR(1),@key)=0
  INSERT @hits(ItemId)
   SELECT TOP(@Limit) s.ItemId FROM catalog.ItemSearch s
   WHERE s.Status IN ('active','draft') AND CHARINDEX(@key,s.SearchText)>0 ORDER BY s.ProductName,s.Sku;
 SELECT TOP(@Limit) i.Id,i.Sku,p.Name,i.VariantName,sz.Code,co.Code,
  (SELECT TOP(1) x.RawCode FROM catalog.ItemIdentifiers x WHERE x.ItemId=i.Id AND x.Kind='barcode' AND x.IsActive=1
   ORDER BY x.IsPrimary DESC,x.CreatedAt,x.Id),
  i.UnitPriceMinor,i.CurrencyCode,i.Status,
  CASE WHEN @LocationId IS NULL THEN NULL ELSE ISNULL(st.OnHand,0) END,
  CASE WHEN @LocationId IS NULL THEN NULL ELSE ISNULL(st.Available,0) END
 FROM @hits h JOIN catalog.Items i ON i.Id=h.ItemId JOIN catalog.Products p ON p.Id=i.ProductId
 LEFT JOIN catalog.Sizes sz ON sz.Id=i.SizeId LEFT JOIN catalog.Colors co ON co.Id=i.ColorId
 OUTER APPLY(SELECT SUM(v.OnHand) AS OnHand,SUM(v.Available) AS Available FROM inventory.vw_StockAvailable v
  WHERE v.ItemId=i.Id AND v.LocationId=@LocationId AND v.Pool='store') st
 ORDER BY p.Name,i.Sku;
END;
GO
