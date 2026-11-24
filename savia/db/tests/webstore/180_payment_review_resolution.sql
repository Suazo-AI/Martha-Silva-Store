-- TEST: staff resolve a payment_review order. "Accept" re-reserves the lines when the captured amount equals the total
-- and stock is there, marks the order paid, routes the paid notice and lets it ship; without stock it is refused (51102)
-- and another amount is refused (51706). "Refunded" records the reference, cancels the order and does not touch stock;
-- a retry is a no-op. On a paid order it refunds only the flagged second capture. A review left by the manual late
-- path (no review row) is resolved too. Every resolution keeps the staff id.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @item uniqueidentifier=test.Id('item'),@locA uniqueidentifier=test.Id('locA'),@manager uniqueidentifier=test.Id('manager'),
  @webA uniqueidentifier=inventory.ufn_StepId(test.Id('locA'),'web_location'),
  @sku nvarchar(100),@n bigint,@err int,@consignment uniqueidentifier=NEWID(),@event uniqueidentifier,@total bigint,
  @onHand bigint,@reserved bigint,@wrong bigint;
DECLARE @lines webstore.WebOrderLine;
DECLARE @four webstore.WebOrderLine;
DECLARE @result TABLE(Outcome varchar(8));
SET @sku=(SELECT Sku FROM catalog.Items WHERE Id=@item);
DECLARE @late uniqueidentifier=NEWID(),@amount uniqueidentifier=NEWID(),@duplicate uniqueidentifier=NEWID(),
  @manual uniqueidentifier=NEWID(),@noStock uniqueidentifier=NEWID(),@filler uniqueidentifier=NEWID(),
  @pLate uniqueidentifier=NEWID(),@pAmount uniqueidentifier=NEWID(),@pFirst uniqueidentifier=NEWID(),
  @pSecond uniqueidentifier=NEWID(),@pManual uniqueidentifier=NEWID(),@pNoStock uniqueidentifier=NEWID();
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC test.SeedStock @item,@locA,6;
EXEC inventory.usp_ConsignToWeb @ConsignmentId=@consignment,@ItemId=@item,@FromLocationId=@locA,@Quantity=6,@ActorId=@manager;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC inventory.usp_ApplyWebConsignments;
INSERT INTO @lines VALUES(1,@sku,1);
INSERT INTO @four VALUES(1,@sku,4);
DECLARE @orders TABLE(n int IDENTITY,OrderId uniqueidentifier);
INSERT INTO @orders(OrderId) VALUES(@late),(@amount),(@duplicate),(@manual),(@noStock);
DECLARE @i int=1,@o uniqueidentifier,@email nvarchar(80);
WHILE @i<=5
BEGIN
  SELECT @o=OrderId FROM @orders WHERE n=@i; SET @event=NEWID(); SET @email=CONCAT(N'r',@i,N'@example.test');
  EXEC webstore.usp_CreateWebOrder @OrderId=@o,@RequestHash=0x41,@AccessTokenHash=0x02,@ClientHash=NULL,@Lines=@lines,
    @Name=N'Compradora',@Email=@email,@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
    @Notes=NULL,@Provider='fakecard',@OriginNodeId=@cloud,@EventId=@event;
  SET @i+=1;
END;
SET @total=(SELECT TotalMinor FROM webstore.Orders WHERE Id=@late); SET @wrong=@total-1;
UPDATE webstore.Orders SET ExpiresAt=DATEADD(minute,-1,SYSUTCDATETIME()) WHERE Id IN (@late,@manual,@noStock);
EXEC webstore.usp_ExpireReservation @OrderId=@late;
EXEC webstore.usp_ExpireReservation @OrderId=@manual;
EXEC webstore.usp_ExpireReservation @OrderId=@noStock;
SET @event=NEWID();
INSERT INTO @result EXEC webstore.usp_RecordCapturedPayment @PaymentId=@pLate,@OrderId=@late,@Provider=N'fakecard',
  @ExternalPaymentId=N'fr-1',@AmountMinor=@total,@CurrencyCode='NIO',@OriginNodeId=@cloud,@EventId=@event;
SET @event=NEWID();
INSERT INTO @result EXEC webstore.usp_RecordCapturedPayment @PaymentId=@pAmount,@OrderId=@amount,@Provider=N'fakecard',
  @ExternalPaymentId=N'fr-2',@AmountMinor=@wrong,@CurrencyCode='NIO',@OriginNodeId=@cloud,@EventId=@event;
SET @event=NEWID();
INSERT INTO @result EXEC webstore.usp_RecordCapturedPayment @PaymentId=@pFirst,@OrderId=@duplicate,@Provider=N'fakecard',
  @ExternalPaymentId=N'fr-3',@AmountMinor=@total,@CurrencyCode='NIO',@OriginNodeId=@cloud,@EventId=@event;
SET @event=NEWID();
INSERT INTO @result EXEC webstore.usp_RecordCapturedPayment @PaymentId=@pSecond,@OrderId=@duplicate,@Provider=N'fakecard',
  @ExternalPaymentId=N'fr-4',@AmountMinor=@total,@CurrencyCode='NIO',@OriginNodeId=@cloud,@EventId=@event;
SET @event=NEWID();
EXEC webstore.usp_RecordVerifiedPayment @PaymentId=@pManual,@OrderId=@manual,@Provider=N'manual',@ExternalPaymentId=N'fr-5',
  @AmountMinor=@total,@CurrencyCode='NIO',@VerifiedByTrustedService=1,@OriginNodeId=@cloud,@EventId=@event,@ActorId=@manager;
SET @event=NEWID();
INSERT INTO @result EXEC webstore.usp_RecordCapturedPayment @PaymentId=@pNoStock,@OrderId=@noStock,@Provider=N'fakecard',
  @ExternalPaymentId=N'fr-6',@AmountMinor=@total,@CurrencyCode='NIO',@OriginNodeId=@cloud,@EventId=@event;
SET @n=(SELECT COUNT(*) FROM @result WHERE Outcome='review'); EXEC test.AssertEq N'four captures went to review',4,@n;
SET @reserved=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web');
EXEC test.AssertEq N'only the paid order holds stock',1,@reserved;

-- Accept a late capture: re-reserve, paid, notice routed, then it ships.
SET @event=NEWID();
EXEC webstore.usp_AcceptPaymentReview @OrderId=@late,@OriginNodeId=@cloud,@EventId=@event,@ActorId=@manager;
SET @n=(SELECT COUNT(*) FROM webstore.Orders WHERE Id=@late AND Status='paid' AND ModifiedBy=@manager); EXEC test.AssertEq N'accepted order paid',1,@n;
SET @reserved=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web');
EXEC test.AssertEq N'accepted order re-reserved',2,@reserved;
SET @n=(SELECT COUNT(*) FROM webstore.PaymentReviews WHERE PaymentId=@pLate AND Resolution='accepted' AND ResolvedBy=@manager);
EXEC test.AssertEq N'review resolved as accepted',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.EventDeliveries WHERE EventId=@event AND DestinationNodeId=@a); EXEC test.AssertEq N'paid notice routed',1,@n;
SET @event=NEWID();
EXEC webstore.usp_FulfillPaidOrder @OrderId=@late,@OriginNodeId=@cloud,@EventId=@event,@ActorId=@manager;
SET @n=(SELECT COUNT(*) FROM webstore.Orders WHERE Id=@late AND Status='fulfilled'); EXEC test.AssertEq N'accepted order ships',1,@n;
SET @err=0;
BEGIN TRY EXEC webstore.usp_AcceptPaymentReview @OrderId=@late,@OriginNodeId=@cloud,@EventId=@event,@ActorId=@manager; END TRY
BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'accept outside review refused',51747,@err;

-- Accept with another amount is refused; refund cancels it without a stock change, and a retry is a no-op.
SET @err=0; SET @event=NEWID();
BEGIN TRY EXEC webstore.usp_AcceptPaymentReview @OrderId=@amount,@OriginNodeId=@cloud,@EventId=@event,@ActorId=@manager; END TRY
BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'accept of another amount refused',51706,@err;
SELECT @onHand=OnHand,@reserved=Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web';
EXEC webstore.usp_RefundPaymentReview @OrderId=@amount,@RefundReference=N'RF-100',@ActorId=@manager;
EXEC webstore.usp_RefundPaymentReview @OrderId=@amount,@RefundReference=N'RF-100',@ActorId=@manager;
SET @n=(SELECT COUNT(*) FROM webstore.Orders WHERE Id=@amount AND Status='cancelled' AND ModifiedBy=@manager); EXEC test.AssertEq N'refunded order cancelled',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.Payments WHERE Id=@pAmount AND Status='refunded' AND ModifiedBy=@manager); EXEC test.AssertEq N'payment marked refunded',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.PaymentReviews WHERE PaymentId=@pAmount AND Resolution='refunded' AND RefundReference=N'RF-100' AND ResolvedBy=@manager);
EXEC test.AssertEq N'refund reference kept',1,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web' AND OnHand=@onHand AND Reserved=@reserved);
EXEC test.AssertEq N'refund does not touch stock',1,@n;
SET @err=0;
BEGIN TRY EXEC webstore.usp_RefundPaymentReview @OrderId=@amount,@RefundReference=N'RF-999',@ActorId=@manager; END TRY
BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'second refund with another reference refused',51747,@err;
SET @err=0;
BEGIN TRY EXEC webstore.usp_RefundPaymentReview @OrderId=@noStock,@RefundReference=N' ',@ActorId=@manager; END TRY
BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'refund needs a reference',51743,@err;

-- A paid order with a flagged second capture: only that capture is refunded and the order stays paid.
EXEC webstore.usp_RefundPaymentReview @OrderId=@duplicate,@RefundReference=N'RF-200',@ActorId=@manager;
SET @n=(SELECT COUNT(*) FROM webstore.Orders WHERE Id=@duplicate AND Status='paid'); EXEC test.AssertEq N'paid order stays paid',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.Payments WHERE Id=@pFirst AND Status='captured'); EXEC test.AssertEq N'first capture kept',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.Payments WHERE Id=@pSecond AND Status='refunded'); EXEC test.AssertEq N'second capture refunded',1,@n;

-- The manual late path left no review row: refund still resolves it and keeps a row for the record.
EXEC webstore.usp_RefundPaymentReview @OrderId=@manual,@RefundReference=N'RF-300',@ActorId=@manager;
SET @n=(SELECT COUNT(*) FROM webstore.Orders WHERE Id=@manual AND Status='cancelled'); EXEC test.AssertEq N'manual late order cancelled',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.PaymentReviews WHERE PaymentId=@pManual AND Reason='late' AND Resolution='refunded');
EXEC test.AssertEq N'manual late review recorded',1,@n;

-- Accept without stock: another buyer took the units first.
SET @event=NEWID();
EXEC webstore.usp_CreateWebOrder @OrderId=@filler,@RequestHash=0x41,@AccessTokenHash=0x02,@ClientHash=NULL,@Lines=@four,
  @Name=N'Compradora',@Email=N'fill@example.test',@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
  @Notes=NULL,@Provider='fakecard',@OriginNodeId=@cloud,@EventId=@event;
SET @err=0; SET @event=NEWID();
BEGIN TRY EXEC webstore.usp_AcceptPaymentReview @OrderId=@noStock,@OriginNodeId=@cloud,@EventId=@event,@ActorId=@manager; END TRY
BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'accept without stock refused',51102,@err;
SET @n=(SELECT COUNT(*) FROM webstore.Orders WHERE Id=@noStock AND Status='payment_review'); EXEC test.AssertEq N'order stays in review',1,@n;

-- Unknown order.
SET @err=0; SET @o=NEWID();
BEGIN TRY EXEC webstore.usp_RefundPaymentReview @OrderId=@o,@RefundReference=N'RF-1',@ActorId=@manager; END TRY
BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'unknown order',51748,@err;
PRINT 'PASS';
