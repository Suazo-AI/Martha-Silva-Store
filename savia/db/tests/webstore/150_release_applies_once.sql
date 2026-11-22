-- TEST: a release returns web stock to a store once: a replay and a second branch run change nothing. Releasing
-- reserved web stock is refused (51102); the same id with other content (51741); a release on a branch (51740).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@b uniqueidentifier=test.Id('nodeB'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @item uniqueidentifier=test.Id('item'),@locA uniqueidentifier=test.Id('locA'),@manager uniqueidentifier=test.Id('manager'),
  @webA uniqueidentifier=inventory.ufn_StepId(test.Id('locA'),'web_location'),
  @sku nvarchar(100),@n bigint,@err int,@consignment uniqueidentifier=NEWID(),@event uniqueidentifier;
DECLARE @lines webstore.WebOrderLine;
SET @sku=(SELECT Sku FROM catalog.Items WHERE Id=@item);
DECLARE @x TABLE(Applied int);
DECLARE @release uniqueidentifier=NEWID(),@big uniqueidentifier=NEWID(),@o1 uniqueidentifier=NEWID();
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC test.SeedStock @item,@locA,5;
EXEC inventory.usp_ConsignToWeb @ConsignmentId=@consignment,@ItemId=@item,@FromLocationId=@locA,@Quantity=3,@ActorId=@manager;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC inventory.usp_ApplyWebConsignments;
INSERT INTO @lines VALUES(1,@sku,1);
SET @event=NEWID();
EXEC webstore.usp_CreateWebOrder @OrderId=@o1,@RequestHash=0x61,@AccessTokenHash=0x02,@ClientHash=NULL,@Lines=@lines,
  @Name=N'Compradora',@Email=N'uno@example.test',@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
  @Notes=NULL,@Provider='manual',@OriginNodeId=@cloud,@EventId=@event;
EXEC inventory.usp_ReleaseFromWeb @ReleaseId=@release,@ItemId=@item,@TargetLocationId=@locA,@Quantity=1,@Reason=N'Vuelve a tienda',@ActorId=@manager;
EXEC inventory.usp_ReleaseFromWeb @ReleaseId=@release,@ItemId=@item,@TargetLocationId=@locA,@Quantity=1,@Reason=N'Vuelve a tienda',@ActorId=@manager;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web'); EXEC test.AssertEq N'web pool lost 1 once',2,@n;
SET @err=0;
BEGIN TRY
  EXEC inventory.usp_ReleaseFromWeb @ReleaseId=@big,@ItemId=@item,@TargetLocationId=@locA,@Quantity=2,@Reason=N'x',@ActorId=@manager;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'release of reserved stock refused',51102,@err;
SET @err=0;
BEGIN TRY
  EXEC inventory.usp_ReleaseFromWeb @ReleaseId=@release,@ItemId=@item,@TargetLocationId=@locA,@Quantity=2,@Reason=N'x',@ActorId=@manager;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'same id with other content refused',51741,@err;
UPDATE sync.LocalNode SET NodeId=@a;
SET @err=0;
BEGIN TRY
  EXEC inventory.usp_ReleaseFromWeb @ReleaseId=@big,@ItemId=@item,@TargetLocationId=@locA,@Quantity=1,@Reason=N'x',@ActorId=@manager;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'release on a branch refused',51740,@err;
INSERT INTO @x EXEC inventory.usp_ApplyWebReleases;
INSERT INTO @x EXEC inventory.usp_ApplyWebReleases;
SET @n=(SELECT SUM(Applied) FROM @x); EXEC test.AssertEq N'applied once',1,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='store'); EXEC test.AssertEq N'store pool got 1 back',3,@n;
UPDATE sync.LocalNode SET NodeId=@b;
DELETE FROM @x; INSERT INTO @x EXEC inventory.usp_ApplyWebReleases;
SET @n=(SELECT SUM(Applied) FROM @x); EXEC test.AssertEq N'branch B applies nothing for A',0,@n;
PRINT 'PASS';
