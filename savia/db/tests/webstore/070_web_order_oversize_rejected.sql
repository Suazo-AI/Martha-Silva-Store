-- TEST: a web order larger than the web stock of every single web location is refused (51102) and stores nothing.
-- Invalid shapes are refused before any lock on stock: 11 units (51743), an unknown SKU (51744), an unknown zone (51745).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @item uniqueidentifier=test.Id('item'),@locA uniqueidentifier=test.Id('locA'),@locB uniqueidentifier=test.Id('locB'),
  @manager uniqueidentifier=test.Id('manager'),@sku nvarchar(100),@n bigint,@err int,@order uniqueidentifier=NEWID();
DECLARE @lines webstore.WebOrderLine;
SET @sku=(SELECT Sku FROM catalog.Items WHERE Id=@item);
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC test.SeedStock @item,@locA,5;
EXEC test.SeedStock @item,@locB,5;
DECLARE @c1 uniqueidentifier=NEWID(),@c2 uniqueidentifier=NEWID();
EXEC inventory.usp_ConsignToWeb @ConsignmentId=@c1,@ItemId=@item,@FromLocationId=@locA,@Quantity=2,@ActorId=@manager;
UPDATE sync.LocalNode SET NodeId=test.Id('nodeB');
EXEC inventory.usp_ConsignToWeb @ConsignmentId=@c2,@ItemId=@item,@FromLocationId=@locB,@Quantity=2,@ActorId=@manager;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC inventory.usp_ApplyWebConsignments;
-- Two web locations hold 2 each: 3 units fit in neither, although the sum is 4.
INSERT INTO @lines VALUES(1,@sku,3);
SET @err=0;
BEGIN TRY
  EXEC webstore.usp_CreateWebOrder @OrderId=@order,@RequestHash=0x01,@AccessTokenHash=0x02,@ClientHash=0x03,@Lines=@lines,
    @Name=N'Compradora',@Email=N'c@example.test',@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
    @Notes=NULL,@Provider='manual',@OriginNodeId=@cloud,@EventId=@order;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'order above every single web location refused',51102,@err;
SET @n=(SELECT COUNT(*) FROM webstore.Orders); EXEC test.AssertEq N'no order stored',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockReservations); EXEC test.AssertEq N'no reservation stored',0,@n;
SET @n=(SELECT SUM(Reserved) FROM inventory.StockBalances WHERE Pool='web'); EXEC test.AssertEq N'nothing reserved',0,@n;
DELETE FROM @lines; INSERT INTO @lines VALUES(1,@sku,11);
SET @err=0;
BEGIN TRY
  EXEC webstore.usp_CreateWebOrder @OrderId=@order,@RequestHash=0x01,@AccessTokenHash=0x02,@ClientHash=0x03,@Lines=@lines,
    @Name=N'Compradora',@Email=N'c@example.test',@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
    @Notes=NULL,@Provider='manual',@OriginNodeId=@cloud,@EventId=@order;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'more than 10 units per line refused',51743,@err;
DELETE FROM @lines; INSERT INTO @lines VALUES(1,N'NO-EXISTE',1);
SET @err=0;
BEGIN TRY
  EXEC webstore.usp_CreateWebOrder @OrderId=@order,@RequestHash=0x01,@AccessTokenHash=0x02,@ClientHash=0x03,@Lines=@lines,
    @Name=N'Compradora',@Email=N'c@example.test',@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
    @Notes=NULL,@Provider='manual',@OriginNodeId=@cloud,@EventId=@order;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'unknown SKU refused',51744,@err;
DELETE FROM @lines; INSERT INTO @lines VALUES(1,@sku,1);
SET @err=0;
BEGIN TRY
  EXEC webstore.usp_CreateWebOrder @OrderId=@order,@RequestHash=0x01,@AccessTokenHash=0x02,@ClientHash=0x03,@Lines=@lines,
    @Name=N'Compradora',@Email=N'c@example.test',@Phone=NULL,@ZoneCode='luna',@Address=N'Calle 1',@City=N'Managua',
    @Notes=NULL,@Provider='manual',@OriginNodeId=@cloud,@EventId=@order;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'unknown zone refused',51745,@err;
SET @n=(SELECT COUNT(*) FROM webstore.Orders); EXEC test.AssertEq N'still no order',0,@n;
PRINT 'PASS';
