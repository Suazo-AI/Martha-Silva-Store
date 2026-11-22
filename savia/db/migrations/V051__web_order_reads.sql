-- savia:transactional
-- V051: reads behind the public order API and the staff web-orders screen (ORDER-PATH-SPEC 4.2).
-- Each procedure answers one JSON column, read by SqlJson in the API. Times are cast to datetimeoffset so the JSON
-- carries +00:00 and the API never reads a UTC time as local.

-- Public catalog. "available" is what one order can reserve: the best single web location, as usp_CreateWebOrder
-- requires, capped at 10 so the exact stock does not leak.
CREATE OR ALTER PROCEDURE [webstore].[usp_PublicCatalogJson]
AS
BEGIN
  SET NOCOUNT ON;
  SELECT (SELECT i.Sku AS sku,i.ProductId AS productId,p.Name AS name,sz.Name AS size,co.Name AS color,
            i.UnitPriceMinor AS unitPriceMinor,i.CurrencyCode AS currency,
            ISNULL((SELECT CASE WHEN MAX(b.OnHand-b.Reserved)>10 THEN 10 WHEN MAX(b.OnHand-b.Reserved)<0 THEN 0
                                ELSE MAX(b.OnHand-b.Reserved) END
                    FROM inventory.StockBalances b JOIN webstore.WebLocationSources s ON s.WebLocationId=b.LocationId
                    WHERE b.ItemId=i.Id AND b.Pool='web' AND b.Status='active'),0) AS available
          FROM catalog.Items i JOIN catalog.Products p ON p.Id=i.ProductId AND p.Status='active'
          LEFT JOIN catalog.Sizes sz ON sz.Id=i.SizeId LEFT JOIN catalog.Colors co ON co.Id=i.ColorId
          WHERE i.Status='active' ORDER BY p.Name,i.Sku FOR JSON PATH,INCLUDE_NULL_VALUES) AS items_json;
END;
GO

-- One order, only for the holder of its access token (a wrong token reads as an unknown order). requestHash lets the
-- API answer a same-key retry without a new bot check.
CREATE OR ALTER PROCEDURE [webstore].[usp_WebOrderJson] @OrderId uniqueidentifier,@AccessTokenHash varbinary(32)
AS
BEGIN
  SET NOCOUNT ON;
  SELECT (SELECT o.Id AS orderId,o.Code AS code,o.Status AS status,o.TotalMinor AS totalMinor,
            o.ShippingMinor AS shippingMinor,o.CurrencyCode AS currency,CAST(o.ExpiresAt AS datetimeoffset(3)) AS expiresAt,
            o.PaymentProvider AS provider,o.RequestHash AS requestHash,
            JSON_QUERY((SELECT SkuSnapshot AS sku,Quantity AS qty FROM webstore.OrderLines WHERE OrderId=o.Id
                        ORDER BY LineNumber FOR JSON PATH)) AS lines
          FROM webstore.Orders o
          WHERE o.Id=@OrderId AND o.AccessTokenHash=@AccessTokenHash AND @AccessTokenHash IS NOT NULL
          FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS order_json;
END;
GO

-- Staff list, newest first, at most 500 rows (D-041). The source store tells staff where the garments are.
CREATE OR ALTER PROCEDURE [webstore].[usp_WebOrdersJson] @Status varchar(24)=NULL
AS
BEGIN
  SET NOCOUNT ON;
  SELECT (SELECT TOP(500) o.Id AS id,o.Code AS code,o.Status AS status,o.TotalMinor AS totalMinor,
            o.ShippingMinor AS shippingMinor,o.CurrencyCode AS currency,CAST(o.CreatedAt AS datetimeoffset(3)) AS createdAt,
            CAST(o.ExpiresAt AS datetimeoffset(3)) AS expiresAt,
            o.PaymentProvider AS provider,o.ShippingZoneCode AS zone,a.RecipientName AS name,a.Email AS email,
            a.Phone AS phone,a.City AS city,a.StreetAddress AS address,a.DeliveryInstructions AS notes,
            src.Name AS sourceStore,
            JSON_QUERY((SELECT SkuSnapshot AS sku,Quantity AS qty FROM webstore.OrderLines WHERE OrderId=o.Id
                        ORDER BY LineNumber FOR JSON PATH)) AS lines
          FROM webstore.Orders o
          JOIN webstore.OrderAddresses a ON a.OrderId=o.Id AND a.Kind='shipping'
          LEFT JOIN webstore.Fulfillments f ON f.Id=inventory.ufn_StepId(o.Id,'fulfillment')
          LEFT JOIN webstore.WebLocationSources s ON s.WebLocationId=f.LocationId
          LEFT JOIN core.Locations src ON src.Id=s.SourceLocationId
          WHERE o.AccessTokenHash IS NOT NULL AND (@Status IS NULL OR o.Status=@Status)
          ORDER BY o.CreatedAt DESC,o.Id FOR JSON PATH,INCLUDE_NULL_VALUES) AS orders_json;
END;
GO

-- Reserved orders past their expiry, oldest first, for the expiry job.
CREATE OR ALTER PROCEDURE [webstore].[usp_DueWebOrdersJson] @Limit int=50
AS
BEGIN
  SET NOCOUNT ON;
  SELECT (SELECT TOP(@Limit) o.Id AS orderId,o.PaymentProvider AS provider,o.TotalMinor AS totalMinor,
            o.CurrencyCode AS currency
          FROM webstore.Orders o WITH (READPAST)
          WHERE o.Status='reserved' AND o.ExpiresAt<=SYSUTCDATETIME()
          ORDER BY o.ExpiresAt FOR JSON PATH) AS due_json;
END;
GO
