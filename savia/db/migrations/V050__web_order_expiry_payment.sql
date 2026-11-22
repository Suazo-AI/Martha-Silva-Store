-- savia:transactional
-- V050: expiry, cancel and late payment of web orders (ORDER-PATH-SPEC 2.3 and 4.1).
-- reserved -> expired   usp_ExpireReservation, after the expiry job asked the provider; releases the reservations.
-- reserved -> cancelled usp_CancelWebOrder (staff); releases the reservations.
-- expired  -> payment_review  a verified payment after expiry; stock does not change, staff refund or re-reserve.
-- Every transition changes the order only WHERE Status='reserved' under an update lock, so expiry, cancel and payment
-- cannot both win: the loser sees another status and does nothing (expiry) or is refused (cancel, payment).
-- Errors: 51747 the order's status does not allow this action, 51748 unknown order.

-- Releases the active reservations of one order. Runs inside the caller's transaction.
CREATE OR ALTER PROCEDURE [webstore].[usp_ReleaseOrderReservations]
  @OrderId uniqueidentifier,@ReservationStatus varchar(16),@ActorId uniqueidentifier
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  IF @@TRANCOUNT=0 THROW 51747,'Liberar reservas exige la transaccion del pedido.',1;
  DECLARE @reservation uniqueidentifier,@item uniqueidentifier,@location uniqueidentifier,@qty int,@op uniqueidentifier;
  DECLARE releaseOrderCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT r.Id,r.ItemId,r.LocationId,-r.Quantity FROM webstore.OrderLines ol
    JOIN inventory.StockReservations r ON r.Id=ol.ReservationId AND r.Status='active'
    WHERE ol.OrderId=@OrderId ORDER BY r.ItemId;
  OPEN releaseOrderCursor; FETCH NEXT FROM releaseOrderCursor INTO @reservation,@item,@location,@qty;
  WHILE @@FETCH_STATUS=0
  BEGIN
    SET @op=inventory.ufn_StepId(@reservation,'release');
    EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@location,@Pool='web',@Kind='release',
      @OnHandDelta=0,@ReservedDelta=@qty,@SourceType='web_reservation',@SourceId=@reservation,@ActorId=@ActorId;
    UPDATE inventory.StockReservations SET Status=@ReservationStatus,ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId
      WHERE Id=@reservation;
    FETCH NEXT FROM releaseOrderCursor INTO @reservation,@item,@location,@qty;
  END;
  CLOSE releaseOrderCursor; DEALLOCATE releaseOrderCursor;
  UPDATE webstore.Fulfillments SET Status='cancelled',ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId
    WHERE OrderId=@OrderId AND Status='pending';
END;
GO

-- Idempotent: an order that is no longer reserved (expired, paid, cancelled) or not yet due is left as it is.
-- Returns Expired 0 or 1.
CREATE OR ALTER PROCEDURE [webstore].[usp_ExpireReservation] @OrderId uniqueidentifier
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  BEGIN TRANSACTION;
  BEGIN TRY
    UPDATE webstore.Orders WITH (UPDLOCK,HOLDLOCK) SET Status='expired',ModifiedAt=SYSUTCDATETIME()
      WHERE Id=@OrderId AND Status='reserved' AND ExpiresAt<=SYSUTCDATETIME();
    DECLARE @expired int=@@ROWCOUNT;
    IF @expired=1 EXEC webstore.usp_ReleaseOrderReservations @OrderId=@OrderId,@ReservationStatus='expired',@ActorId=NULL;
    COMMIT;
  END TRY
  BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
  SELECT @expired AS Expired;
END;
GO

-- Staff cancel of a reserved order. A retry of a cancel already done is accepted.
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
    UPDATE webstore.Orders SET Status='cancelled',ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId WHERE Id=@OrderId;
    EXEC webstore.usp_ReleaseOrderReservations @OrderId=@OrderId,@ReservationStatus='released',@ActorId=@ActorId;
    COMMIT;
  END TRY
  BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

-- V001 behaviour plus: a payment on an expired order goes to payment_review with no stock change; a web order's
-- notice goes to the branch node of the source store (webstore.WebLocationSources) or stays on the hub when that store
-- has no node, instead of failing with 51712. @ActorId records who verified a manual payment.
CREATE OR ALTER PROCEDURE [webstore].[usp_RecordVerifiedPayment]
 @PaymentId uniqueidentifier,@OrderId uniqueidentifier,@Provider nvarchar(80),
 @ExternalPaymentId nvarchar(160),@AmountMinor bigint,@CurrencyCode varchar(3),
 @VerifiedByTrustedService bit,@OriginNodeId uniqueidentifier,@EventId uniqueidentifier,
 @ActorId uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @VerifiedByTrustedService<>1
   THROW 51704,'Firma de pago no verificada por el backend.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM webstore.Payments WHERE Provider=@Provider AND ExternalPaymentId=@ExternalPaymentId)
   BEGIN
     IF NOT EXISTS(SELECT 1 FROM webstore.Payments WHERE Id=@PaymentId AND OrderId=@OrderId
       AND AmountMinor=@AmountMinor AND CurrencyCode=@CurrencyCode)
       THROW 51705,'Id de pasarela reusado para otro pago.',1;
     COMMIT; RETURN;
   END;
   DECLARE @status varchar(24)=(SELECT Status FROM webstore.Orders WITH(UPDLOCK,HOLDLOCK)
      WHERE Id=@OrderId AND CurrencyCode=@CurrencyCode AND TotalMinor=@AmountMinor AND Status IN ('reserved','expired'));
   IF @status IS NULL THROW 51706,'Pago distinto al pedido o pedido sin reserva.',1;
   DECLARE @next varchar(24)=IIF(@status='reserved','paid','payment_review');
   INSERT INTO webstore.Payments(Id,OrderId,Provider,ExternalPaymentId,AmountMinor,CurrencyCode,Status,VerifiedAt,CreatedBy)
     VALUES(@PaymentId,@OrderId,@Provider,@ExternalPaymentId,@AmountMinor,@CurrencyCode,'captured',SYSUTCDATETIME(),@ActorId);
   UPDATE webstore.Orders SET Status=@next,ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId WHERE Id=@OrderId;
   DECLARE @payload nvarchar(max)=(SELECT @OrderId AS orderId,@PaymentId AS paymentId,
       @Provider AS provider,@AmountMinor AS amountMinor FOR JSON PATH,WITHOUT_ARRAY_WRAPPER),
     @event varchar(80)=IIF(@next='paid','web.payment_captured','web.payment_review');
   EXEC sync.usp_EnqueueEvent @EventId,@OriginNodeId,'web_order',@OrderId,@event,@payload;
   IF @next='paid'
   BEGIN
     DECLARE @web bit=IIF(EXISTS(SELECT 1 FROM webstore.Fulfillments f JOIN webstore.WebLocationSources s
                                  ON s.WebLocationId=f.LocationId WHERE f.OrderId=@OrderId),1,0);
     DECLARE @dest uniqueidentifier=(SELECT TOP(1) n.Id FROM webstore.Fulfillments f
         LEFT JOIN webstore.WebLocationSources s ON s.WebLocationId=f.LocationId
         JOIN sync.Nodes n ON n.BranchId=ISNULL(s.SourceBranchId,f.BranchId) AND n.Kind='branch' AND n.IsEnabled=1
         WHERE f.OrderId=@OrderId ORDER BY n.NodeCode);
     IF @dest IS NULL AND @web=0 THROW 51712,'No existe nodo de cumplimiento.',1;
     IF @dest IS NOT NULL EXEC sync.usp_RouteEvent @EventId,@dest;
   END;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO
