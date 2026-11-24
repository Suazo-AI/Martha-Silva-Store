-- TEST: a replay of the same request returns the order with Replayed=1 and reserves nothing more; another request
-- under the same id is refused (51710). A third unpaid order for one email is refused (51746).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@b uniqueidentifier=test.Id('nodeB'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @item uniqueidentifier=test.Id('item'),@locA uniqueidentifier=test.Id('locA'),@manager uniqueidentifier=test.Id('manager'),
  @webA uniqueidentifier=inventory.ufn_StepId(test.Id('locA'),'web_location'),
  @sku nvarchar(100),@n bigint,@err int,@consignment uniqueidentifier=NEWID(),@event uniqueidentifier;
DECLARE @lines webstore.WebOrderLine;
SET @sku=(SELECT Sku FROM catalog.Items WHERE Id=@item);
DECLARE @o1 uniqueidentifier=NEWID(),@o2 uniqueidentifier=NEWID(),@o3 uniqueidentifier=NEWID();
DECLARE @r TABLE(Id uniqueidentifier,Code varchar(9),Status varchar(24),TotalMinor bigint,ShippingMinor bigint,
  CurrencyCode varchar(3),ExpiresAt datetime2(3),Replayed bit);
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC test.SeedStock @item,@locA,8;
EXEC inventory.usp_ConsignToWeb @ConsignmentId=@consignment,@ItemId=@item,@FromLocationId=@locA,@Quantity=5,@ActorId=@manager;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC inventory.usp_ApplyWebConsignments;
INSERT INTO @lines VALUES(1,@sku,2);
SET @event=NEWID();
INSERT INTO @r EXEC webstore.usp_CreateWebOrder @OrderId=@o1,@RequestHash=0x21,@AccessTokenHash=0x02,@ClientHash=NULL,@Lines=@lines,
  @Name=N'Compradora',@Email=N'misma@example.test',@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
  @Notes=NULL,@Provider='manual',@OriginNodeId=@cloud,@EventId=@event;
SET @event=NEWID();
INSERT INTO @r EXEC webstore.usp_CreateWebOrder @OrderId=@o1,@RequestHash=0x21,@AccessTokenHash=0x02,@ClientHash=NULL,@Lines=@lines,
  @Name=N'Compradora',@Email=N'misma@example.test',@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
  @Notes=NULL,@Provider='manual',@OriginNodeId=@cloud,@EventId=@event;
SET @n=(SELECT COUNT(*) FROM @r WHERE Id=@o1 AND Replayed=1); EXEC test.AssertEq N'replay flagged',1,@n;
SET @n=(SELECT COUNT(DISTINCT Code) FROM @r WHERE Code LIKE 'W%' AND LEN(Code)=9); EXEC test.AssertEq N'one order code W plus 8 characters',1,@n;
SET @n=(SELECT MAX(TotalMinor) FROM @r); EXEC test.AssertEq N'total = 2 x 120000 + managua 50000',290000,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockReservations); EXEC test.AssertEq N'one reservation after the replay',1,@n;
SET @n=(SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web'); EXEC test.AssertEq N'two units reserved once',2,@n;
SET @err=0;
BEGIN TRY
SET @event=NEWID();
EXEC webstore.usp_CreateWebOrder @OrderId=@o1,@RequestHash=0x22,@AccessTokenHash=0x02,@ClientHash=NULL,@Lines=@lines,
  @Name=N'Compradora',@Email=N'misma@example.test',@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
  @Notes=NULL,@Provider='manual',@OriginNodeId=@cloud,@EventId=@event;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'same id with another request refused',51710,@err;
DELETE FROM @lines; INSERT INTO @lines VALUES(1,@sku,1);
SET @event=NEWID();
EXEC webstore.usp_CreateWebOrder @OrderId=@o2,@RequestHash=0x23,@AccessTokenHash=0x02,@ClientHash=NULL,@Lines=@lines,
  @Name=N'Compradora',@Email=N'misma@example.test',@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
  @Notes=NULL,@Provider='manual',@OriginNodeId=@cloud,@EventId=@event;
SET @err=0;
BEGIN TRY
SET @event=NEWID();
EXEC webstore.usp_CreateWebOrder @OrderId=@o3,@RequestHash=0x24,@AccessTokenHash=0x02,@ClientHash=NULL,@Lines=@lines,
  @Name=N'Compradora',@Email=N'misma@example.test',@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
  @Notes=NULL,@Provider='manual',@OriginNodeId=@cloud,@EventId=@event;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'third unpaid order for one email refused',51746,@err;
PRINT 'PASS';
