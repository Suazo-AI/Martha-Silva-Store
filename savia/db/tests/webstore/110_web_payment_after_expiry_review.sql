-- TEST: a verified payment on a reserved web order marks it paid and routes the notice to the source branch; a verified
-- payment after expiry puts the order in payment_review and leaves stock unchanged. Another amount is refused (51706).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@b uniqueidentifier=test.Id('nodeB'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @item uniqueidentifier=test.Id('item'),@locA uniqueidentifier=test.Id('locA'),@manager uniqueidentifier=test.Id('manager'),
  @webA uniqueidentifier=inventory.ufn_StepId(test.Id('locA'),'web_location'),
  @sku nvarchar(100),@n bigint,@err int,@consignment uniqueidentifier=NEWID(),@event uniqueidentifier;
DECLARE @lines webstore.WebOrderLine;
SET @sku=(SELECT Sku FROM catalog.Items WHERE Id=@item);
DECLARE @o1 uniqueidentifier=NEWID(),@o2 uniqueidentifier=NEWID(),@total bigint,@onHand bigint,@reserved bigint,
  @p0 uniqueidentifier=NEWID(),@p1 uniqueidentifier=NEWID(),@p2 uniqueidentifier=NEWID(),
  @e0 uniqueidentifier=NEWID(),@e1 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID();
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC test.SeedStock @item,@locA,4;
EXEC inventory.usp_ConsignToWeb @ConsignmentId=@consignment,@ItemId=@item,@FromLocationId=@locA,@Quantity=4,@ActorId=@manager;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC inventory.usp_ApplyWebConsignments;
INSERT INTO @lines VALUES(1,@sku,1);
SET @event=NEWID();
EXEC webstore.usp_CreateWebOrder @OrderId=@o1,@RequestHash=0x41,@AccessTokenHash=0x02,@ClientHash=NULL,@Lines=@lines,
  @Name=N'Compradora',@Email=N'uno@example.test',@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
  @Notes=NULL,@Provider='manual',@OriginNodeId=@cloud,@EventId=@event;
SET @event=NEWID();
EXEC webstore.usp_CreateWebOrder @OrderId=@o2,@RequestHash=0x42,@AccessTokenHash=0x02,@ClientHash=NULL,@Lines=@lines,
  @Name=N'Compradora',@Email=N'dos@example.test',@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
  @Notes=NULL,@Provider='manual',@OriginNodeId=@cloud,@EventId=@event;
SET @total=(SELECT TotalMinor FROM webstore.Orders WHERE Id=@o1);
SET @err=0;
BEGIN TRY
EXEC webstore.usp_RecordVerifiedPayment @PaymentId=@p0,@OrderId=@o1,@Provider=N'manual',@ExternalPaymentId=N'm-0',
  @AmountMinor=1,@CurrencyCode='NIO',@VerifiedByTrustedService=1,@OriginNodeId=@cloud,@EventId=@e0,@ActorId=@manager;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'payment of another amount refused',51706,@err;
EXEC webstore.usp_RecordVerifiedPayment @PaymentId=@p1,@OrderId=@o1,@Provider=N'manual',@ExternalPaymentId=N'm-1',
  @AmountMinor=@total,@CurrencyCode='NIO',@VerifiedByTrustedService=1,@OriginNodeId=@cloud,@EventId=@e1,@ActorId=@manager;
SET @n=(SELECT COUNT(*) FROM webstore.Orders WHERE Id=@o1 AND Status='paid'); EXEC test.AssertEq N'reserved order paid',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.Payments WHERE Id=@p1 AND CreatedBy=@manager); EXEC test.AssertEq N'verifier recorded',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.EventDeliveries WHERE EventId=@e1 AND DestinationNodeId=@a); EXEC test.AssertEq N'paid notice routed to branch A',1,@n;
UPDATE webstore.Orders SET ExpiresAt=DATEADD(minute,-1,SYSUTCDATETIME()) WHERE Id=@o2;
EXEC webstore.usp_ExpireReservation @OrderId=@o2;
SELECT @onHand=OnHand,@reserved=Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web';
EXEC webstore.usp_RecordVerifiedPayment @PaymentId=@p2,@OrderId=@o2,@Provider=N'manual',@ExternalPaymentId=N'm-2',
  @AmountMinor=@total,@CurrencyCode='NIO',@VerifiedByTrustedService=1,@OriginNodeId=@cloud,@EventId=@e2,@ActorId=@manager;
SET @n=(SELECT COUNT(*) FROM webstore.Orders WHERE Id=@o2 AND Status='payment_review'); EXEC test.AssertEq N'late payment goes to review',1,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web' AND OnHand=@onHand AND Reserved=@reserved); EXEC test.AssertEq N'late payment does not change stock',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventId=@e2 AND EventType='web.payment_review'); EXEC test.AssertEq N'review notice recorded',1,@n;
PRINT 'PASS';
