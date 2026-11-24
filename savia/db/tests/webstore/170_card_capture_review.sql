-- TEST: a card capture the order cannot take (other amount, other currency, after cancel, a second capture on a paid
-- order) is recorded with its real amount, puts the order in payment_review (a paid order keeps its status), releases
-- an active reservation once, raises a hub notice and is a no-op on retry. A reserved order with a captured payment
-- cannot be cancelled. A matching capture on a reserved order still marks it paid.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @item uniqueidentifier=test.Id('item'),@locA uniqueidentifier=test.Id('locA'),@manager uniqueidentifier=test.Id('manager'),
  @webA uniqueidentifier=inventory.ufn_StepId(test.Id('locA'),'web_location'),
  @sku nvarchar(100),@n bigint,@err int,@consignment uniqueidentifier=NEWID(),@event uniqueidentifier,@outcome varchar(8);
DECLARE @lines webstore.WebOrderLine;
DECLARE @result TABLE(Outcome varchar(8));
SET @sku=(SELECT Sku FROM catalog.Items WHERE Id=@item);
DECLARE @wrongAmount uniqueidentifier=NEWID(),@wrongCurrency uniqueidentifier=NEWID(),@cancelled uniqueidentifier=NEWID(),
  @paid uniqueidentifier=NEWID(),@guarded uniqueidentifier=NEWID(),@total bigint,@reserved bigint,
  @p1 uniqueidentifier=NEWID(),@p2 uniqueidentifier=NEWID(),@p3 uniqueidentifier=NEWID(),@p4 uniqueidentifier=NEWID(),
  @p5 uniqueidentifier=NEWID();
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC test.SeedStock @item,@locA,6;
EXEC inventory.usp_ConsignToWeb @ConsignmentId=@consignment,@ItemId=@item,@FromLocationId=@locA,@Quantity=6,@ActorId=@manager;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC inventory.usp_ApplyWebConsignments;
INSERT INTO @lines VALUES(1,@sku,1);
DECLARE @orders TABLE(n int IDENTITY,OrderId uniqueidentifier);
INSERT INTO @orders(OrderId) VALUES(@wrongAmount),(@wrongCurrency),(@cancelled),(@paid),(@guarded);
DECLARE @i int=1,@o uniqueidentifier,@email nvarchar(80);
WHILE @i<=5
BEGIN
  SELECT @o=OrderId FROM @orders WHERE n=@i; SET @event=NEWID(); SET @email=CONCAT(N'c',@i,N'@example.test');
  EXEC webstore.usp_CreateWebOrder @OrderId=@o,@RequestHash=0x41,@AccessTokenHash=0x02,@ClientHash=NULL,@Lines=@lines,
    @Name=N'Compradora',@Email=@email,@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
    @Notes=NULL,@Provider='fakecard',@OriginNodeId=@cloud,@EventId=@event;
  SET @i+=1;
END;
SET @total=(SELECT TotalMinor FROM webstore.Orders WHERE Id=@wrongAmount);
SET @reserved=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web');
EXEC test.AssertEq N'five orders reserve five units',5,@reserved;

-- 1. Another amount on a reserved order: recorded, review, reservation released once.
DECLARE @wrong bigint=@total+1;
SET @event=NEWID();
INSERT INTO @result EXEC webstore.usp_RecordCapturedPayment @PaymentId=@p1,@OrderId=@wrongAmount,@Provider=N'fakecard',
  @ExternalPaymentId=N'fk-1',@AmountMinor=@wrong,@CurrencyCode='NIO',@OriginNodeId=@cloud,@EventId=@event;
SET @outcome=(SELECT Outcome FROM @result); DELETE @result;
SET @n=IIF(@outcome='review',1,0); EXEC test.AssertEq N'other amount goes to review',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.Orders WHERE Id=@wrongAmount AND Status='payment_review'); EXEC test.AssertEq N'order in payment_review',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.Payments WHERE Id=@p1 AND AmountMinor=@wrong AND Status='captured'); EXEC test.AssertEq N'real amount recorded',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.PaymentReviews WHERE PaymentId=@p1 AND Reason='amount' AND ResolvedAt IS NULL); EXEC test.AssertEq N'open review, reason amount',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventId=@event AND EventType='web.payment_review'); EXEC test.AssertEq N'review notice recorded',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.EventDeliveries WHERE EventId=@event); EXEC test.AssertEq N'review notice stays on the hub',0,@n;
SET @reserved=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web');
EXEC test.AssertEq N'reservation released',4,@reserved;

-- 2. The same capture again is a no-op; the same provider id with other content is refused.
SET @event=NEWID();
INSERT INTO @result EXEC webstore.usp_RecordCapturedPayment @PaymentId=@p1,@OrderId=@wrongAmount,@Provider=N'fakecard',
  @ExternalPaymentId=N'fk-1',@AmountMinor=@wrong,@CurrencyCode='NIO',@OriginNodeId=@cloud,@EventId=@event;
SET @outcome=(SELECT Outcome FROM @result); DELETE @result;
SET @n=IIF(@outcome='repeat',1,0); EXEC test.AssertEq N'retry is a repeat',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.PaymentReviews WHERE OrderId=@wrongAmount); EXEC test.AssertEq N'one review after retry',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventId=@event); EXEC test.AssertEq N'no second notice',0,@n;
SET @reserved=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web');
EXEC test.AssertEq N'retry releases nothing more',4,@reserved;
SET @err=0;
BEGIN TRY
  EXEC webstore.usp_RecordCapturedPayment @PaymentId=@p1,@OrderId=@wrongAmount,@Provider=N'fakecard',
    @ExternalPaymentId=N'fk-1',@AmountMinor=@total,@CurrencyCode='NIO',@OriginNodeId=@cloud,@EventId=@event;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'provider id reused with other content',51705,@err;

-- 3. Another currency on a reserved order.
SET @event=NEWID();
INSERT INTO @result EXEC webstore.usp_RecordCapturedPayment @PaymentId=@p2,@OrderId=@wrongCurrency,@Provider=N'fakecard',
  @ExternalPaymentId=N'fk-2',@AmountMinor=@total,@CurrencyCode='USD',@OriginNodeId=@cloud,@EventId=@event;
SET @outcome=(SELECT Outcome FROM @result); DELETE @result;
SET @n=IIF(@outcome='review',1,0); EXEC test.AssertEq N'other currency goes to review',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.Payments WHERE Id=@p2 AND CurrencyCode='USD'); EXEC test.AssertEq N'real currency recorded',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.PaymentReviews WHERE PaymentId=@p2 AND Reason='currency'); EXEC test.AssertEq N'reason currency',1,@n;

-- 4. A capture after staff cancelled the order.
DECLARE @noRelease bigint;
EXEC webstore.usp_CancelWebOrder @OrderId=@cancelled,@ActorId=@manager;
SET @noRelease=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web');
SET @event=NEWID();
INSERT INTO @result EXEC webstore.usp_RecordCapturedPayment @PaymentId=@p3,@OrderId=@cancelled,@Provider=N'fakecard',
  @ExternalPaymentId=N'fk-3',@AmountMinor=@total,@CurrencyCode='NIO',@OriginNodeId=@cloud,@EventId=@event;
SET @outcome=(SELECT Outcome FROM @result); DELETE @result;
SET @n=IIF(@outcome='review',1,0); EXEC test.AssertEq N'capture after cancel goes to review',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.Orders WHERE Id=@cancelled AND Status='payment_review'); EXEC test.AssertEq N'cancelled order in review',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.PaymentReviews WHERE PaymentId=@p3 AND Reason='cancelled'); EXEC test.AssertEq N'reason cancelled',1,@n;
SET @reserved=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web');
EXEC test.AssertEq N'capture after cancel does not touch stock',@noRelease,@reserved;

-- 5. A matching capture marks a reserved order paid; a second, different capture is flagged and stock does not move.
SET @event=NEWID();
INSERT INTO @result EXEC webstore.usp_RecordCapturedPayment @PaymentId=@p4,@OrderId=@paid,@Provider=N'fakecard',
  @ExternalPaymentId=N'fk-4',@AmountMinor=@total,@CurrencyCode='NIO',@OriginNodeId=@cloud,@EventId=@event;
SET @outcome=(SELECT Outcome FROM @result); DELETE @result;
SET @n=IIF(@outcome='paid',1,0); EXEC test.AssertEq N'matching capture pays',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.EventDeliveries WHERE EventId=@event AND DestinationNodeId=@a); EXEC test.AssertEq N'paid notice routed to branch A',1,@n;
DECLARE @before bigint=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web');
SET @event=NEWID();
INSERT INTO @result EXEC webstore.usp_RecordCapturedPayment @PaymentId=@p5,@OrderId=@paid,@Provider=N'fakecard',
  @ExternalPaymentId=N'fk-5',@AmountMinor=@total,@CurrencyCode='NIO',@OriginNodeId=@cloud,@EventId=@event;
SET @outcome=(SELECT Outcome FROM @result); DELETE @result;
SET @n=IIF(@outcome='review',1,0); EXEC test.AssertEq N'second capture goes to review',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.Orders WHERE Id=@paid AND Status='paid'); EXEC test.AssertEq N'paid order stays paid',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.Payments WHERE OrderId=@paid AND Status='captured'); EXEC test.AssertEq N'both captures recorded',2,@n;
SET @n=(SELECT COUNT(*) FROM webstore.PaymentReviews WHERE PaymentId=@p5 AND Reason='duplicate'); EXEC test.AssertEq N'reason duplicate',1,@n;
SET @reserved=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web');
EXEC test.AssertEq N'duplicate does not touch stock',@before,@reserved;

-- 6. A reserved order that holds a captured payment row cannot be cancelled.
INSERT INTO webstore.Payments(Id,OrderId,Provider,ExternalPaymentId,AmountMinor,CurrencyCode,Status,VerifiedAt)
  VALUES(NEWID(),@guarded,N'fakecard',N'fk-6',@total,'NIO','captured',SYSUTCDATETIME());
SET @err=0;
BEGIN TRY EXEC webstore.usp_CancelWebOrder @OrderId=@guarded,@ActorId=@manager; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'charged order cannot be cancelled',51747,@err;
SET @n=(SELECT COUNT(*) FROM webstore.Orders WHERE Id=@guarded AND Status='reserved'); EXEC test.AssertEq N'charged order stays reserved',1,@n;

-- 7. Unknown order.
SET @err=0;
DECLARE @unknown uniqueidentifier=NEWID(),@p9 uniqueidentifier=NEWID();
BEGIN TRY
  EXEC webstore.usp_RecordCapturedPayment @PaymentId=@p9,@OrderId=@unknown,@Provider=N'fakecard',
    @ExternalPaymentId=N'fk-9',@AmountMinor=@total,@CurrencyCode='NIO',@OriginNodeId=@cloud,@EventId=@event;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'unknown order',51748,@err;
PRINT 'PASS';
