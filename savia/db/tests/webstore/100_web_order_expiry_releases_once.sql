-- TEST: expiry releases the reservation once; a second run returns Expired=0. An order is not expired before its time.
-- A cancel of an expired order is refused (51747); a cancel of a reserved order releases it once; unknown order 51748.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@b uniqueidentifier=test.Id('nodeB'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @item uniqueidentifier=test.Id('item'),@locA uniqueidentifier=test.Id('locA'),@manager uniqueidentifier=test.Id('manager'),
  @webA uniqueidentifier=inventory.ufn_StepId(test.Id('locA'),'web_location'),
  @sku nvarchar(100),@n bigint,@err int,@consignment uniqueidentifier=NEWID(),@event uniqueidentifier;
DECLARE @lines webstore.WebOrderLine;
SET @sku=(SELECT Sku FROM catalog.Items WHERE Id=@item);
DECLARE @o1 uniqueidentifier=NEWID(),@o2 uniqueidentifier=NEWID();
DECLARE @x TABLE(Expired int);
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC test.SeedStock @item,@locA,4;
EXEC inventory.usp_ConsignToWeb @ConsignmentId=@consignment,@ItemId=@item,@FromLocationId=@locA,@Quantity=4,@ActorId=@manager;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC inventory.usp_ApplyWebConsignments;
INSERT INTO @lines VALUES(1,@sku,3);
SET @event=NEWID();
EXEC webstore.usp_CreateWebOrder @OrderId=@o1,@RequestHash=0x31,@AccessTokenHash=0x02,@ClientHash=NULL,@Lines=@lines,
  @Name=N'Compradora',@Email=N'uno@example.test',@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
  @Notes=NULL,@Provider='manual',@OriginNodeId=@cloud,@EventId=@event;
INSERT INTO @x EXEC webstore.usp_ExpireReservation @OrderId=@o1;
SET @n=(SELECT SUM(Expired) FROM @x); EXEC test.AssertEq N'not expired before its time',0,@n;
UPDATE webstore.Orders SET ExpiresAt=DATEADD(minute,-1,SYSUTCDATETIME()) WHERE Id=@o1;
DELETE FROM @x; INSERT INTO @x EXEC webstore.usp_ExpireReservation @OrderId=@o1;
SET @n=(SELECT SUM(Expired) FROM @x); EXEC test.AssertEq N'expired once',1,@n;
DELETE FROM @x; INSERT INTO @x EXEC webstore.usp_ExpireReservation @OrderId=@o1;
SET @n=(SELECT SUM(Expired) FROM @x); EXEC test.AssertEq N'second run does nothing',0,@n;
SET @n=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web'); EXEC test.AssertEq N'reservation released',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE Kind='release' AND LocationId=@webA); EXEC test.AssertEq N'one release movement',1,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockReservations WHERE Status='expired'); EXEC test.AssertEq N'reservation marked expired',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.Fulfillments WHERE OrderId=@o1 AND Status='cancelled'); EXEC test.AssertEq N'fulfillment cancelled',1,@n;
SET @err=0;
BEGIN TRY
  EXEC webstore.usp_CancelWebOrder @OrderId=@o1,@ActorId=@manager;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'cancel of an expired order refused',51747,@err;
SET @event=NEWID();
EXEC webstore.usp_CreateWebOrder @OrderId=@o2,@RequestHash=0x32,@AccessTokenHash=0x02,@ClientHash=NULL,@Lines=@lines,
  @Name=N'Compradora',@Email=N'dos@example.test',@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
  @Notes=NULL,@Provider='manual',@OriginNodeId=@cloud,@EventId=@event;
EXEC webstore.usp_CancelWebOrder @OrderId=@o2,@ActorId=@manager;
EXEC webstore.usp_CancelWebOrder @OrderId=@o2,@ActorId=@manager;
SET @n=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web'); EXEC test.AssertEq N'cancel released the stock once',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE Kind='release' AND LocationId=@webA); EXEC test.AssertEq N'two release movements in all',2,@n;
SET @n=(SELECT COUNT(*) FROM webstore.Orders WHERE Id=@o2 AND Status='cancelled'); EXEC test.AssertEq N'order cancelled',1,@n;
SET @err=0;
BEGIN TRY
  EXEC webstore.usp_CancelWebOrder @OrderId=@consignment,@ActorId=@manager;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'unknown order',51748,@err;
PRINT 'PASS';
