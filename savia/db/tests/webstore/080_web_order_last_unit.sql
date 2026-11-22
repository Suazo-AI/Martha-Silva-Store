-- TEST: two orders for the last web unit: the first reserves it, the second is refused (51102); no oversell.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@b uniqueidentifier=test.Id('nodeB'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @item uniqueidentifier=test.Id('item'),@locA uniqueidentifier=test.Id('locA'),@manager uniqueidentifier=test.Id('manager'),
  @webA uniqueidentifier=inventory.ufn_StepId(test.Id('locA'),'web_location'),
  @sku nvarchar(100),@n bigint,@err int,@consignment uniqueidentifier=NEWID(),@event uniqueidentifier;
DECLARE @lines webstore.WebOrderLine;
SET @sku=(SELECT Sku FROM catalog.Items WHERE Id=@item);
DECLARE @o1 uniqueidentifier=NEWID(),@o2 uniqueidentifier=NEWID();
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC test.SeedStock @item,@locA,3;
EXEC inventory.usp_ConsignToWeb @ConsignmentId=@consignment,@ItemId=@item,@FromLocationId=@locA,@Quantity=1,@ActorId=@manager;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC inventory.usp_ApplyWebConsignments;
INSERT INTO @lines VALUES(1,@sku,1);
SET @event=NEWID();
EXEC webstore.usp_CreateWebOrder @OrderId=@o1,@RequestHash=0x11,@AccessTokenHash=0x02,@ClientHash=NULL,@Lines=@lines,
  @Name=N'Compradora',@Email=N'uno@example.test',@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
  @Notes=NULL,@Provider='manual',@OriginNodeId=@cloud,@EventId=@event;
SET @err=0;
BEGIN TRY
SET @event=NEWID();
EXEC webstore.usp_CreateWebOrder @OrderId=@o2,@RequestHash=0x12,@AccessTokenHash=0x02,@ClientHash=NULL,@Lines=@lines,
  @Name=N'Compradora',@Email=N'dos@example.test',@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
  @Notes=NULL,@Provider='manual',@OriginNodeId=@cloud,@EventId=@event;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'second order for the last unit refused',51102,@err;
SET @n=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web'); EXEC test.AssertEq N'one unit reserved',1,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web'); EXEC test.AssertEq N'web on hand unchanged by a reservation',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.Orders); EXEC test.AssertEq N'one order stored',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.Orders WHERE Id=@o1 AND Status='reserved' AND ExpiresAt>SYSUTCDATETIME()); EXEC test.AssertEq N'first order reserved with a future expiry',1,@n;
SET @n=(SELECT COUNT(*) FROM webstore.Fulfillments WHERE OrderId=@o1 AND LocationId=@webA AND Status='pending'); EXEC test.AssertEq N'fulfillment pending at the web location',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@o1 AND EventType='web.order_reserved' AND PayloadJson NOT LIKE N'%Calle%'); EXEC test.AssertEq N'reserved notice without the address',1,@n;
PRINT 'PASS';
