-- V042 (P4, production readiness 2026-11-22, D-041): the sale catalog is read in pages of at most 500 variants.
-- Before, one call returned every product as one JSON value (A-10: 3.4 M reads, 8 s, over 1 MB on the load data).
-- @After is the last product of the previous page; the order (Name, Id) is the same as before, so a page never splits a product.
-- @Limit NULL keeps the old answer, one Json column, for the previous API release and for INSERT ... EXEC callers.
CREATE OR ALTER PROCEDURE catalog.usp_ListSaleCatalog @LocationId uniqueidentifier,@After uniqueidentifier=NULL,@Limit int=NULL
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @afterName nvarchar(200);
 IF @After IS NOT NULL
 BEGIN
  SELECT @afterName=Name FROM catalog.Products WHERE Id=@After;
  IF @afterName IS NULL THROW 51230,'Catalogo: la pagina anterior no existe.',1;
 END;
 -- Every listed product has at least one variant, so @Limit+1 products always cover a full page plus the next one.
 SELECT TOP(CASE WHEN @Limit IS NULL THEN 2147483647 ELSE @Limit+1 END) p.Id,p.Name,v.Variants INTO #p
  FROM catalog.Products p
  CROSS APPLY(SELECT COUNT(*) AS Variants FROM catalog.Items i WHERE i.ProductId=p.Id AND i.Status='active') v
  WHERE v.Variants>0 AND (@After IS NULL OR (p.Name>=@afterName AND (p.Name>@afterName OR p.Id>@After)))
  ORDER BY p.Name,p.Id;
 -- Whole products while the variants fit; the first product always goes, even when it alone is larger than a page.
 WITH r AS (SELECT SUM(Variants) OVER(ORDER BY Name,Id ROWS UNBOUNDED PRECEDING) AS Running,
   ROW_NUMBER() OVER(ORDER BY Name,Id) AS Seq FROM #p)
 DELETE r WHERE Running>@Limit AND Seq>1;
 DECLARE @next uniqueidentifier=CASE WHEN @@ROWCOUNT>0 THEN (SELECT TOP(1) Id FROM #p ORDER BY Name DESC,Id DESC) END;
 DECLARE @json nvarchar(max)=COALESCE((SELECT p.Id AS productId,p.Name AS name,
   CASE
    WHEN p.Name COLLATE Latin1_General_100_CI_AI LIKE N'Blusa%' THEN N'Blusas'
    WHEN p.Name COLLATE Latin1_General_100_CI_AI LIKE N'Vestido%' THEN N'Vestidos'
    WHEN p.Name COLLATE Latin1_General_100_CI_AI LIKE N'Falda%' THEN N'Faldas'
    WHEN p.Name COLLATE Latin1_General_100_CI_AI LIKE N'Pantalon%' THEN N'Pantalones'
    WHEN p.Name COLLATE Latin1_General_100_CI_AI LIKE N'Jeans%' THEN N'Jeans'
    WHEN p.Name COLLATE Latin1_General_100_CI_AI LIKE N'Top%' THEN N'Tops'
    WHEN p.Name COLLATE Latin1_General_100_CI_AI LIKE N'Cardigan%' THEN N'Cardigans'
    ELSE N'Otras prendas' END AS type,
   JSON_QUERY((SELECT i.Id AS itemId,i.Sku AS sku,i.VariantName AS variantName,
     p.Name AS productName,sz.Code AS sizeCode,i.UnitPriceMinor AS unitPriceMinor,i.TaxRateBps AS taxRateBps,
     i.CurrencyCode AS currencyCode,i.Status AS status,
     ISNULL(st.OnHand,0) AS onHand,ISNULL(st.Available,0) AS available
     FROM catalog.Items i LEFT JOIN catalog.Sizes sz ON sz.Id=i.SizeId
     OUTER APPLY(SELECT SUM(v.OnHand) AS OnHand,SUM(v.Available) AS Available
       FROM inventory.vw_StockAvailable v WHERE v.ItemId=i.Id AND v.LocationId=@LocationId AND v.Pool='store') st
     WHERE i.ProductId=p.Id AND i.Status='active'
     ORDER BY sz.SortOrder,i.Sku FOR JSON PATH)) AS variants
   FROM #p pg JOIN catalog.Products p ON p.Id=pg.Id
   ORDER BY p.Name,p.Id FOR JSON PATH),N'[]');
 IF @Limit IS NULL SELECT @json AS Json;
 ELSE SELECT @json AS Json,@next AS NextAfter;
END;
GO
