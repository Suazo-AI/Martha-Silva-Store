-- savia:transactional
-- V049: public web order (ORDER-PATH-SPEC 2.3, 2.4, 4.1, 4.2).
-- usp_CreateWebOrder prices the lines from catalog.Items, picks ONE web location that can fill every line, reserves
-- there with an expiry, and enqueues a hub-only notice. The browser never sends a price, so a price cannot "change".
-- webstore.ShippingZones is here, not in a later file, because the order procedure prices shipping from it.
-- Errors: 51743 invalid order, 51744 unknown or inactive SKU, 51745 unknown shipping zone, 51746 too many unpaid
-- orders for this email or client, 51749 order creation busy, 51102 no single web location has every line (the stock
-- rule of usp_ApplyMovement), 51710 the order id was used with other content (V001).

ALTER TABLE [webstore].[Orders] ADD
  [ExpiresAt] datetime2(3) NULL,
  [AccessTokenHash] varbinary(32) NULL,
  [ClientHash] varbinary(32) NULL,
  [ShippingZoneCode] varchar(20) NULL,
  [PaymentProvider] varchar(20) NULL,
  [Code] AS (CONVERT(varchar(9),'W'+UPPER(LEFT(REPLACE(CONVERT(varchar(36),[Id]),'-',''),8))));
GO
ALTER TABLE [webstore].[Orders] DROP CONSTRAINT [CK_WebOrders_Status];
ALTER TABLE [webstore].[Orders] ADD CONSTRAINT [CK_WebOrders_Status]
  CHECK ([Status] IN ('pending','reserved','paid','fulfilling','fulfilled','cancelled','refunded','expired','payment_review'));
CREATE INDEX [IX_WebOrders_StatusExpiry] ON [webstore].[Orders]([Status],[ExpiresAt]);
GO

CREATE TABLE [webstore].[ShippingZones] (
  [Code] varchar(20) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [Name] nvarchar(100) NOT NULL,
  [PriceMinor] bigint NOT NULL,
  [CurrencyCode] varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [IsActive] bit NOT NULL CONSTRAINT [DF_ShippingZones_Active] DEFAULT(1),
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_webstore_ShippingZones_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_ShippingZones] PRIMARY KEY ([Code]),
  CONSTRAINT [FK_ShippingZones_Currency] FOREIGN KEY ([CurrencyCode]) REFERENCES [core].[Currencies]([Code]),
  CONSTRAINT [CK_ShippingZones_Price] CHECK ([PriceMinor]>=0)
);
GO
-- The storefront demo prices (src/store-api.js): C$500 in Managua, C$800 elsewhere. The owner confirms them.
INSERT INTO webstore.ShippingZones(Code,Name,PriceMinor,CurrencyCode) VALUES
 ('managua',N'Managua',50000,'NIO'),('departamentos',N'Departamentos',80000,'NIO');
GO

CREATE TYPE [webstore].[WebOrderLine] AS TABLE (
  [LineNumber] int NOT NULL PRIMARY KEY,
  [Sku] nvarchar(100) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [Quantity] int NOT NULL
);
GO

-- @RequestHash is computed by the API over the canonical request without the bot token, so a retry with a fresh token
-- is the same request. @AccessTokenHash is SHA-256 of the buyer's order token. @ClientHash identifies the client
-- (a hash of its IP address, never the address itself).
-- Returns one row: the order, and Replayed=1 when the id already existed with the same request.
CREATE OR ALTER PROCEDURE [webstore].[usp_CreateWebOrder]
  @OrderId uniqueidentifier,@RequestHash varbinary(32),@AccessTokenHash varbinary(32),@ClientHash varbinary(32),
  @Lines [webstore].[WebOrderLine] READONLY,
  @Name nvarchar(180),@Email nvarchar(254),@Phone nvarchar(40),
  @ZoneCode varchar(20),@Address nvarchar(350),@City nvarchar(120),@Notes nvarchar(500),
  @Provider varchar(20),@OriginNodeId uniqueidentifier,@EventId uniqueidentifier
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  BEGIN TRANSACTION;
  BEGIN TRY
    -- One order at a time: the unpaid-order limits count rows that a parallel order could add. Web volume is small.
    DECLARE @lock int;
    EXEC @lock=sys.sp_getapplock @Resource=N'savia.webstore.create_order',@LockMode='Exclusive',@LockOwner='Transaction',
      @LockTimeout=10000;
    IF @lock<0 THROW 51749,'Pedidos web ocupados. Reintente.',1;
    DECLARE @replayed bit=0;
    IF EXISTS(SELECT 1 FROM webstore.Orders WHERE Id=@OrderId)
    BEGIN
      IF NOT EXISTS(SELECT 1 FROM webstore.Orders WHERE Id=@OrderId AND RequestHash=@RequestHash)
        THROW 51710,'OrderId duplicado con contenido distinto.',1;
      SET @replayed=1;
    END
    ELSE
    BEGIN
      IF (SELECT COUNT(*) FROM @Lines) NOT BETWEEN 1 AND 20
         OR EXISTS(SELECT 1 FROM @Lines WHERE Quantity NOT BETWEEN 1 AND 10)
         OR (SELECT COUNT(DISTINCT Sku) FROM @Lines)<>(SELECT COUNT(*) FROM @Lines)
         OR LEN(LTRIM(RTRIM(ISNULL(@Name,N''))))=0 OR LEN(LTRIM(RTRIM(ISNULL(@Email,N''))))=0
         OR LEN(LTRIM(RTRIM(ISNULL(@Address,N''))))=0 OR LEN(LTRIM(RTRIM(ISNULL(@City,N''))))=0
         OR @RequestHash IS NULL OR @AccessTokenHash IS NULL OR ISNULL(@Provider,'')=''
        THROW 51743,'Pedido web invalido.',1;
      DECLARE @badSku nvarchar(100)=(SELECT TOP(1) l.Sku FROM @Lines l LEFT JOIN catalog.Items i ON i.Sku=l.Sku AND i.Status='active'
                                      WHERE i.Id IS NULL ORDER BY l.LineNumber);
      IF @badSku IS NOT NULL THROW 51744,'SKU desconocido o inactivo.',1;
      DECLARE @currency varchar(3)=(SELECT MIN(i.CurrencyCode) FROM @Lines l JOIN catalog.Items i ON i.Sku=l.Sku);
      IF (SELECT COUNT(DISTINCT i.CurrencyCode) FROM @Lines l JOIN catalog.Items i ON i.Sku=l.Sku)<>1
        THROW 51743,'Pedido web con monedas distintas.',1;
      DECLARE @shipping bigint=(SELECT PriceMinor FROM webstore.ShippingZones
                                WHERE Code=@ZoneCode AND IsActive=1 AND CurrencyCode=@currency);
      IF @shipping IS NULL THROW 51745,'Zona de envio desconocida.',1;
      IF (SELECT COUNT(*) FROM webstore.Orders o JOIN webstore.OrderAddresses a ON a.OrderId=o.Id AND a.Kind='shipping'
          WHERE o.Status IN ('pending','reserved') AND a.Email=LTRIM(RTRIM(@Email)))>=2
         OR (@ClientHash IS NOT NULL AND (SELECT COUNT(*) FROM webstore.Orders
              WHERE Status IN ('pending','reserved') AND ClientHash=@ClientHash)>=2)
        THROW 51746,'Ya hay dos pedidos sin pagar para este cliente.',1;

      DECLARE @want TABLE(LineNumber int PRIMARY KEY,ItemId uniqueidentifier UNIQUE,Quantity int);
      INSERT INTO @want SELECT l.LineNumber,i.Id,l.Quantity FROM @Lines l JOIN catalog.Items i ON i.Sku=l.Sku;
      -- One order reserves at one web location: the best-ranked location that can fill every line.
      -- UPDLOCK keeps the chosen balances until the reservation movements below take them.
      DECLARE @location uniqueidentifier=(
        SELECT TOP(1) s.WebLocationId FROM webstore.WebLocationSources s
        WHERE NOT EXISTS(SELECT 1 FROM @want w
                LEFT JOIN inventory.StockBalances b WITH (UPDLOCK,HOLDLOCK)
                  ON b.ItemId=w.ItemId AND b.LocationId=s.WebLocationId AND b.Pool='web' AND b.Status='active'
                WHERE ISNULL(b.OnHand-b.Reserved,0)<w.Quantity)
        ORDER BY s.PriorityRank,s.WebLocationId);
      IF @location IS NULL THROW 51102,'Sin existencia web suficiente en una sola tienda.',1;
      DECLARE @webBranch uniqueidentifier=(SELECT BranchId FROM core.Locations WHERE Id=@location),
        @expires datetime2(3)=DATEADD(minute,30,SYSUTCDATETIME());

      DECLARE @calc TABLE(LineNumber int PRIMARY KEY,ItemId uniqueidentifier,Sku nvarchar(100),Quantity int,
        UnitPriceMinor bigint,TaxMinor bigint);
      INSERT INTO @calc
      SELECT w.LineNumber,w.ItemId,i.Sku,w.Quantity,i.UnitPriceMinor,
        CAST(ROUND(CAST(i.UnitPriceMinor AS decimal(28,0))*w.Quantity*i.TaxRateBps/10000.0,0) AS bigint)
      FROM @want w JOIN catalog.Items i ON i.Id=w.ItemId;
      DECLARE @subtotal bigint=(SELECT SUM(UnitPriceMinor*Quantity) FROM @calc),@tax bigint=(SELECT SUM(TaxMinor) FROM @calc);
      INSERT INTO webstore.Orders(Id,RequestHash,CurrencyCode,SubtotalMinor,DiscountMinor,TaxMinor,ShippingMinor,TotalMinor,
        Status,ExpiresAt,AccessTokenHash,ClientHash,ShippingZoneCode,PaymentProvider)
      VALUES(@OrderId,@RequestHash,@currency,@subtotal,0,@tax,@shipping,@subtotal+@tax+@shipping,
        'reserved',@expires,@AccessTokenHash,@ClientHash,@ZoneCode,@Provider);
      INSERT INTO webstore.OrderAddresses(OrderId,Kind,RecipientName,Phone,Email,CountryCode,City,StreetAddress,DeliveryInstructions)
      VALUES(@OrderId,'shipping',LTRIM(RTRIM(@Name)),NULLIF(LTRIM(RTRIM(@Phone)),N''),LTRIM(RTRIM(@Email)),'NI',
        LTRIM(RTRIM(@City)),LTRIM(RTRIM(@Address)),NULLIF(LTRIM(RTRIM(@Notes)),N''));

      -- Lines in item order, so two orders lock balance rows in the same order.
      DECLARE @lineNo int,@item uniqueidentifier,@sku nvarchar(100),@qty int,@unit bigint,@lineTax bigint,
        @lineId uniqueidentifier,@reservation uniqueidentifier,@op uniqueidentifier;
      DECLARE webOrderCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT LineNumber,ItemId,Sku,Quantity,UnitPriceMinor,TaxMinor FROM @calc ORDER BY ItemId;
      OPEN webOrderCursor; FETCH NEXT FROM webOrderCursor INTO @lineNo,@item,@sku,@qty,@unit,@lineTax;
      WHILE @@FETCH_STATUS=0
      BEGIN
        SET @lineId=NEWID(); SET @reservation=inventory.ufn_StepId(@lineId,'reservation');
        SET @op=inventory.ufn_StepId(@reservation,'reserve');
        INSERT INTO inventory.StockReservations(Id,ItemId,LocationId,Pool,Quantity,ReferenceType,ReferenceId,Status,ExpiresAt)
          VALUES(@reservation,@item,@location,'web',@qty,'web_order_line',@lineId,'active',@expires);
        EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@location,@Pool='web',@Kind='reserve',
          @OnHandDelta=0,@ReservedDelta=@qty,@SourceType='web_reservation',@SourceId=@reservation;
        INSERT INTO webstore.OrderLines(Id,OrderId,LineNumber,ItemId,SkuSnapshot,Quantity,UnitPriceMinor,DiscountMinor,TaxMinor,
          TotalMinor,ReservationId)
        VALUES(@lineId,@OrderId,@lineNo,@item,@sku,@qty,@unit,0,@lineTax,@unit*@qty+@lineTax,@reservation);
        FETCH NEXT FROM webOrderCursor INTO @lineNo,@item,@sku,@qty,@unit,@lineTax;
      END;
      CLOSE webOrderCursor; DEALLOCATE webOrderCursor;
      INSERT INTO webstore.Fulfillments(Id,OrderId,BranchId,LocationId,Status)
        VALUES(inventory.ufn_StepId(@OrderId,'fulfillment'),@OrderId,@webBranch,@location,'pending');
      -- The notice carries the code, items and zone; never the address or phone (spec 2.6). It stays on the hub.
      DECLARE @payload nvarchar(max)=(SELECT @OrderId AS orderId,@ZoneCode AS zone,@location AS webLocationId,
         JSON_QUERY((SELECT SkuSnapshot AS sku,Quantity AS qty FROM webstore.OrderLines WHERE OrderId=@OrderId
                     ORDER BY LineNumber FOR JSON PATH)) AS lines
         FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
      EXEC sync.usp_EnqueueEvent @EventId,@OriginNodeId,'web_order',@OrderId,'web.order_reserved',@payload;
    END;
    COMMIT;
  END TRY
  BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
  SELECT Id,Code,Status,TotalMinor,ShippingMinor,CurrencyCode,ExpiresAt,@replayed AS Replayed
  FROM webstore.Orders WHERE Id=@OrderId;
END;
GO
