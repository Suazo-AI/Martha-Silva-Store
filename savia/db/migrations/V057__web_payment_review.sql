-- savia:transactional
-- V057: money taken is never invisible (checklist W4 seam). A card capture the order cannot take is recorded with its
-- real amount and currency and put in front of staff, instead of failing with 51706 while the order stays reserved.
--   reserved, same amount and currency   -> paid (usp_RecordVerifiedPayment, unchanged)
--   reserved, other amount or currency   -> payment_review; the reservation is released once
--   expired or cancelled                 -> payment_review; stock does not change
--   paid, shipped or already in review   -> status kept; the second capture is flagged for review
-- Staff then mark the money refunded (order cancelled) or accept it and re-reserve (order paid).
-- usp_RecordVerifiedPayment keeps its V050 behaviour for the manual staff path.
-- Errors: 51102 no stock to re-reserve, 51705 provider id reused, 51706 captured amount differs from the total,
-- 51743 missing refund reference, 51747 the order's status does not allow this action, 51748 unknown order.

-- One row per capture that needs a person. It keeps its own amount and currency, so a capture in a currency that
-- core.Currencies does not hold (no webstore.Payments row is possible) is still on record. Hub only: not synced.
CREATE TABLE [webstore].[PaymentReviews] (
  [PaymentId] uniqueidentifier NOT NULL,
  [OrderId] uniqueidentifier NOT NULL,
  [Provider] nvarchar(80) NOT NULL,
  [ExternalPaymentId] nvarchar(160) NOT NULL,
  [AmountMinor] bigint NOT NULL,
  [CurrencyCode] varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [Reason] varchar(16) NOT NULL,
  [OpenedAt] datetime2(3) NOT NULL CONSTRAINT [DF_PaymentReviews_OpenedAt] DEFAULT (SYSUTCDATETIME()),
  [Resolution] varchar(16) NULL,
  [RefundReference] nvarchar(160) NULL,
  [ResolvedAt] datetime2(3) NULL,
  [ResolvedBy] uniqueidentifier NULL,
  CONSTRAINT [PK_PaymentReviews] PRIMARY KEY ([PaymentId]),
  CONSTRAINT [UQ_PaymentReviews_ProviderId] UNIQUE ([Provider],[ExternalPaymentId]),
  CONSTRAINT [FK_PaymentReviews_Order] FOREIGN KEY ([OrderId]) REFERENCES [webstore].[Orders]([Id]),
  CONSTRAINT [CK_PaymentReviews_Reason] CHECK ([Reason] IN ('amount','currency','late','cancelled','duplicate')),
  CONSTRAINT [CK_PaymentReviews_Resolution] CHECK (([Resolution] IS NULL AND [ResolvedAt] IS NULL AND [ResolvedBy] IS NULL)
    OR ([Resolution]='accepted' AND [ResolvedAt] IS NOT NULL)
    OR ([Resolution]='refunded' AND [ResolvedAt] IS NOT NULL AND [RefundReference] IS NOT NULL))
);
GO
CREATE INDEX [IX_PaymentReviews_Open] ON [webstore].[PaymentReviews]([OrderId]) WHERE [ResolvedAt] IS NULL;
GO

-- V050 plus: a reserved order that holds captured money or an open review is never cancelled.
CREATE OR ALTER PROCEDURE [webstore].[usp_CancelWebOrder] @OrderId uniqueidentifier,@ActorId uniqueidentifier
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  BEGIN TRANSACTION;
  BEGIN TRY
    DECLARE @status varchar(24)=(SELECT Status FROM webstore.Orders WITH (UPDLOCK,HOLDLOCK) WHERE Id=@OrderId);
    IF @status IS NULL THROW 51748,'Pedido web desconocido.',1;
    IF @status='cancelled' BEGIN COMMIT; RETURN; END;
    IF @status<>'reserved' THROW 51747,'Solo se cancela un pedido reservado sin pagar.',1;
    IF EXISTS(SELECT 1 FROM webstore.Payments WHERE OrderId=@OrderId AND Status='captured')
       OR EXISTS(SELECT 1 FROM webstore.PaymentReviews WHERE OrderId=@OrderId AND ResolvedAt IS NULL)
      THROW 51747,'El pedido tiene un pago cobrado: no se cancela.',1;
    UPDATE webstore.Orders SET Status='cancelled',ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId WHERE Id=@OrderId;
    EXEC webstore.usp_ReleaseOrderReservations @OrderId=@OrderId,@ReservationStatus='released',@ActorId=@ActorId;
    COMMIT;
  END TRY
  BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

-- Every capture a card path confirms (return page, webhook, sweep). Returns Outcome paid, review or repeat.
-- The order row is locked first, so a capture, an expiry and a staff cancel of one order run one after another.
CREATE OR ALTER PROCEDURE [webstore].[usp_RecordCapturedPayment]
  @PaymentId uniqueidentifier,@OrderId uniqueidentifier,@Provider nvarchar(80),@ExternalPaymentId nvarchar(160),
  @AmountMinor bigint,@CurrencyCode varchar(3),@OriginNodeId uniqueidentifier,@EventId uniqueidentifier
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  DECLARE @outcome varchar(8);
  BEGIN TRANSACTION;
  BEGIN TRY
    DECLARE @status varchar(24),@total bigint,@currency varchar(3);
    SELECT @status=Status,@total=TotalMinor,@currency=CurrencyCode FROM webstore.Orders WITH (UPDLOCK,HOLDLOCK) WHERE Id=@OrderId;
    IF @status IS NULL THROW 51748,'Pedido web desconocido.',1;
    IF EXISTS(SELECT 1 FROM webstore.Payments WHERE Provider=@Provider AND ExternalPaymentId=@ExternalPaymentId)
       OR EXISTS(SELECT 1 FROM webstore.PaymentReviews WHERE Provider=@Provider AND ExternalPaymentId=@ExternalPaymentId)
    BEGIN
      IF NOT EXISTS(SELECT 1 FROM webstore.Payments WHERE Id=@PaymentId AND OrderId=@OrderId
                      AND AmountMinor=@AmountMinor AND CurrencyCode=@CurrencyCode)
         AND NOT EXISTS(SELECT 1 FROM webstore.PaymentReviews WHERE PaymentId=@PaymentId AND OrderId=@OrderId
                      AND AmountMinor=@AmountMinor AND CurrencyCode=@CurrencyCode)
        THROW 51705,'Id de pasarela reusado para otro pago.',1;
      SET @outcome='repeat';
    END
    ELSE IF @status='reserved' AND @AmountMinor=@total AND @CurrencyCode=@currency
    BEGIN
      EXEC webstore.usp_RecordVerifiedPayment @PaymentId=@PaymentId,@OrderId=@OrderId,@Provider=@Provider,
        @ExternalPaymentId=@ExternalPaymentId,@AmountMinor=@AmountMinor,@CurrencyCode=@CurrencyCode,
        @VerifiedByTrustedService=1,@OriginNodeId=@OriginNodeId,@EventId=@EventId;
      SET @outcome='paid';
    END
    ELSE
    BEGIN
      DECLARE @reason varchar(16)=CASE
        WHEN @status='reserved' AND @CurrencyCode<>@currency THEN 'currency'
        WHEN @status='reserved' THEN 'amount'
        WHEN @status='expired' THEN 'late'
        WHEN @status IN ('paid','fulfilling','fulfilled','payment_review') THEN 'duplicate'
        ELSE 'cancelled' END;
      IF EXISTS(SELECT 1 FROM core.Currencies WHERE Code=@CurrencyCode)
        INSERT INTO webstore.Payments(Id,OrderId,Provider,ExternalPaymentId,AmountMinor,CurrencyCode,Status,VerifiedAt)
          VALUES(@PaymentId,@OrderId,@Provider,@ExternalPaymentId,@AmountMinor,@CurrencyCode,'captured',SYSUTCDATETIME());
      INSERT INTO webstore.PaymentReviews(PaymentId,OrderId,Provider,ExternalPaymentId,AmountMinor,CurrencyCode,Reason)
        VALUES(@PaymentId,@OrderId,@Provider,@ExternalPaymentId,@AmountMinor,@CurrencyCode,@reason);
      IF @status='reserved' EXEC webstore.usp_ReleaseOrderReservations @OrderId=@OrderId,@ReservationStatus='released',@ActorId=NULL;
      IF @reason<>'duplicate'
        UPDATE webstore.Orders SET Status='payment_review',ModifiedAt=SYSUTCDATETIME() WHERE Id=@OrderId;
      -- A hub notice only: no branch acts on money that staff have not accepted.
      DECLARE @payload nvarchar(max)=(SELECT @OrderId AS orderId,@PaymentId AS paymentId,@Provider AS provider,
          @AmountMinor AS amountMinor,@CurrencyCode AS currency,@reason AS reason FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
      EXEC sync.usp_EnqueueEvent @EventId,@OriginNodeId,'web_order',@OrderId,'web.payment_review',@payload;
      SET @outcome='review';
    END;
    COMMIT;
  END TRY
  BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
  SELECT @outcome AS Outcome;
END;
GO

-- The V050 manual path puts a late payment in payment_review without a review row. Staff resolve every captured
-- payment of such an order, so the missing rows are added first. Runs inside the caller's transaction.
CREATE OR ALTER PROCEDURE [webstore].[usp_OpenLateReviews] @OrderId uniqueidentifier
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  IF @@TRANCOUNT=0 THROW 51747,'Abrir revisiones exige la transaccion del pedido.',1;
  INSERT INTO webstore.PaymentReviews(PaymentId,OrderId,Provider,ExternalPaymentId,AmountMinor,CurrencyCode,Reason)
  SELECT p.Id,p.OrderId,p.Provider,p.ExternalPaymentId,p.AmountMinor,p.CurrencyCode,'late'
  FROM webstore.Payments p JOIN webstore.Orders o ON o.Id=p.OrderId AND o.Status='payment_review'
  WHERE p.OrderId=@OrderId AND p.Status='captured'
    AND NOT EXISTS(SELECT 1 FROM webstore.PaymentReviews r WHERE r.PaymentId=p.Id);
END;
GO

-- Staff record that the money under review went back to the buyer. A payment_review order is cancelled; a paid order
-- keeps its status and only the flagged second capture is refunded. Stock does not change. A retry with the same
-- reference is accepted.
CREATE OR ALTER PROCEDURE [webstore].[usp_RefundPaymentReview]
  @OrderId uniqueidentifier,@RefundReference nvarchar(160),@ActorId uniqueidentifier
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  DECLARE @reference nvarchar(160)=NULLIF(LTRIM(RTRIM(@RefundReference)),N'');
  IF @reference IS NULL THROW 51743,'Falta la referencia del reembolso.',1;
  BEGIN TRANSACTION;
  BEGIN TRY
    DECLARE @status varchar(24)=(SELECT Status FROM webstore.Orders WITH (UPDLOCK,HOLDLOCK) WHERE Id=@OrderId);
    IF @status IS NULL THROW 51748,'Pedido web desconocido.',1;
    EXEC webstore.usp_OpenLateReviews @OrderId=@OrderId;
    IF NOT EXISTS(SELECT 1 FROM webstore.PaymentReviews WHERE OrderId=@OrderId AND ResolvedAt IS NULL)
    BEGIN
      IF EXISTS(SELECT 1 FROM webstore.PaymentReviews WHERE OrderId=@OrderId AND Resolution='refunded' AND RefundReference=@reference)
      BEGIN COMMIT; RETURN; END;
      THROW 51747,'El pedido no tiene pagos en revision.',1;
    END;
    UPDATE p SET Status='refunded',ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId
    FROM webstore.Payments p JOIN webstore.PaymentReviews r ON r.PaymentId=p.Id
    WHERE r.OrderId=@OrderId AND r.ResolvedAt IS NULL;
    UPDATE webstore.PaymentReviews SET Resolution='refunded',RefundReference=@reference,ResolvedAt=SYSUTCDATETIME(),
      ResolvedBy=@ActorId WHERE OrderId=@OrderId AND ResolvedAt IS NULL;
    IF @status='payment_review'
      UPDATE webstore.Orders SET Status='cancelled',ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId WHERE Id=@OrderId;
    COMMIT;
  END TRY
  BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

-- Staff accept the money of a payment_review order: the captured payments in the order's currency must add up to the
-- total. The lines are reserved again at the order's web location, under the same lock as a new order, so a buyer and
-- this action cannot both take the last unit. Then the order is paid and its notice goes to the source store.
CREATE OR ALTER PROCEDURE [webstore].[usp_AcceptPaymentReview]
  @OrderId uniqueidentifier,@OriginNodeId uniqueidentifier,@EventId uniqueidentifier,@ActorId uniqueidentifier
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  BEGIN TRANSACTION;
  BEGIN TRY
    DECLARE @lock int;
    EXEC @lock=sys.sp_getapplock @Resource=N'savia.webstore.create_order',@LockMode='Exclusive',@LockOwner='Transaction',
      @LockTimeout=10000;
    IF @lock<0 THROW 51749,'Pedidos web ocupados. Reintente.',1;
    DECLARE @status varchar(24),@total bigint,@currency varchar(3);
    SELECT @status=Status,@total=TotalMinor,@currency=CurrencyCode FROM webstore.Orders WITH (UPDLOCK,HOLDLOCK) WHERE Id=@OrderId;
    IF @status IS NULL THROW 51748,'Pedido web desconocido.',1;
    IF @status<>'payment_review' THROW 51747,'Solo se acepta un pedido en revision de pago.',1;
    EXEC webstore.usp_OpenLateReviews @OrderId=@OrderId;
    IF ISNULL((SELECT SUM(AmountMinor) FROM webstore.Payments WHERE OrderId=@OrderId AND Status='captured'
               AND CurrencyCode=@currency),0)<>@total
       OR EXISTS(SELECT 1 FROM webstore.PaymentReviews WHERE OrderId=@OrderId AND ResolvedAt IS NULL AND CurrencyCode<>@currency)
      THROW 51706,'El monto cobrado no es el total del pedido.',1;
    DECLARE @fulfillment uniqueidentifier=inventory.ufn_StepId(@OrderId,'fulfillment');
    DECLARE @location uniqueidentifier=(SELECT LocationId FROM webstore.Fulfillments WHERE Id=@fulfillment);
    IF EXISTS(SELECT 1 FROM webstore.OrderLines ol
              LEFT JOIN inventory.StockBalances b WITH (UPDLOCK,HOLDLOCK)
                ON b.ItemId=ol.ItemId AND b.LocationId=@location AND b.Pool='web' AND b.Status='active'
              WHERE ol.OrderId=@OrderId AND ISNULL(b.OnHand-b.Reserved,0)<ol.Quantity)
      THROW 51102,'Sin existencia web para reservar de nuevo.',1;
    -- New reservation ids: the released ones keep their history.
    DECLARE @lineId uniqueidentifier,@item uniqueidentifier,@qty int,@reservation uniqueidentifier,@op uniqueidentifier;
    DECLARE reReserveCursor CURSOR LOCAL FAST_FORWARD FOR
      SELECT Id,ItemId,Quantity FROM webstore.OrderLines WHERE OrderId=@OrderId ORDER BY ItemId;
    OPEN reReserveCursor; FETCH NEXT FROM reReserveCursor INTO @lineId,@item,@qty;
    WHILE @@FETCH_STATUS=0
    BEGIN
      SET @reservation=inventory.ufn_StepId(@lineId,'rereserve'); SET @op=inventory.ufn_StepId(@reservation,'reserve');
      INSERT INTO inventory.StockReservations(Id,ItemId,LocationId,Pool,Quantity,ReferenceType,ReferenceId,Status,CreatedBy)
        VALUES(@reservation,@item,@location,'web',@qty,'web_order_rereserve',@lineId,'active',@ActorId);
      EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@location,@Pool='web',@Kind='reserve',
        @OnHandDelta=0,@ReservedDelta=@qty,@SourceType='web_reservation',@SourceId=@reservation,@ActorId=@ActorId;
      UPDATE webstore.OrderLines SET ReservationId=@reservation WHERE Id=@lineId;
      FETCH NEXT FROM reReserveCursor INTO @lineId,@item,@qty;
    END;
    CLOSE reReserveCursor; DEALLOCATE reReserveCursor;
    UPDATE webstore.Fulfillments SET Status='pending',ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId
      WHERE Id=@fulfillment AND Status='cancelled';
    UPDATE webstore.Orders SET Status='paid',ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId WHERE Id=@OrderId;
    UPDATE webstore.PaymentReviews SET Resolution='accepted',ResolvedAt=SYSUTCDATETIME(),ResolvedBy=@ActorId
      WHERE OrderId=@OrderId AND ResolvedAt IS NULL;
    -- The same notice and route as a payment that arrived in time (V050).
    DECLARE @payload nvarchar(max)=(SELECT @OrderId AS orderId,@total AS amountMinor,@ActorId AS acceptedBy
        FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
    EXEC sync.usp_EnqueueEvent @EventId,@OriginNodeId,'web_order',@OrderId,'web.payment_captured',@payload;
    DECLARE @web bit=IIF(EXISTS(SELECT 1 FROM webstore.Fulfillments f JOIN webstore.WebLocationSources s
                                  ON s.WebLocationId=f.LocationId WHERE f.OrderId=@OrderId),1,0);
    DECLARE @dest uniqueidentifier=(SELECT TOP(1) n.Id FROM webstore.Fulfillments f
        LEFT JOIN webstore.WebLocationSources s ON s.WebLocationId=f.LocationId
        JOIN sync.Nodes n ON n.BranchId=ISNULL(s.SourceBranchId,f.BranchId) AND n.Kind='branch' AND n.IsEnabled=1
        WHERE f.OrderId=@OrderId ORDER BY n.NodeCode);
    IF @dest IS NULL AND @web=0 THROW 51712,'No existe nodo de cumplimiento.',1;
    IF @dest IS NOT NULL EXEC sync.usp_RouteEvent @EventId,@dest;
    COMMIT;
  END TRY
  BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

-- V051 plus: each order carries its payments (with the open review reason) and needsReview. The status filter
-- 'review' lists payment_review orders and paid orders with a flagged second capture; other filters are unchanged.
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
                        ORDER BY LineNumber FOR JSON PATH)) AS lines,
            JSON_QUERY((SELECT x.amountMinor,x.currency,x.provider,x.status,x.review FROM (
                SELECT p.AmountMinor AS amountMinor,p.CurrencyCode AS currency,p.Provider AS provider,p.Status AS status,
                  IIF(r.ResolvedAt IS NULL,r.Reason,NULL) AS review,p.CreatedAt AS at
                FROM webstore.Payments p LEFT JOIN webstore.PaymentReviews r ON r.PaymentId=p.Id WHERE p.OrderId=o.Id
                UNION ALL
                SELECT r.AmountMinor,r.CurrencyCode,r.Provider,IIF(r.Resolution='refunded','refunded','captured'),
                  IIF(r.ResolvedAt IS NULL,r.Reason,NULL),r.OpenedAt
                FROM webstore.PaymentReviews r
                WHERE r.OrderId=o.Id AND NOT EXISTS(SELECT 1 FROM webstore.Payments p WHERE p.Id=r.PaymentId)) x
              ORDER BY x.at FOR JSON PATH)) AS payments,
            CAST(IIF(o.Status='payment_review' OR rv.OrderId IS NOT NULL,1,0) AS bit) AS needsReview
          FROM webstore.Orders o
          JOIN webstore.OrderAddresses a ON a.OrderId=o.Id AND a.Kind='shipping'
          LEFT JOIN webstore.Fulfillments f ON f.Id=inventory.ufn_StepId(o.Id,'fulfillment')
          LEFT JOIN webstore.WebLocationSources s ON s.WebLocationId=f.LocationId
          LEFT JOIN core.Locations src ON src.Id=s.SourceLocationId
          OUTER APPLY (SELECT TOP(1) r.OrderId FROM webstore.PaymentReviews r WHERE r.OrderId=o.Id AND r.ResolvedAt IS NULL) rv
          WHERE o.AccessTokenHash IS NOT NULL
            AND (@Status IS NULL OR o.Status=@Status
                 OR (@Status='review' AND (o.Status='payment_review' OR rv.OrderId IS NOT NULL)))
          ORDER BY o.CreatedAt DESC,o.Id FOR JSON PATH,INCLUDE_NULL_VALUES) AS orders_json;
END;
GO
