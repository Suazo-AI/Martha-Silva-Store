-- TEST: a consignment moves store stock to the web once: a replay and a second hub run change nothing. The same id
-- with other content is refused (51741); 0 units (51742); more than the store holds (51102); a consign on the hub (51740).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@b uniqueidentifier=test.Id('nodeB'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @item uniqueidentifier=test.Id('item'),@locA uniqueidentifier=test.Id('locA'),@manager uniqueidentifier=test.Id('manager'),
  @webA uniqueidentifier=inventory.ufn_StepId(test.Id('locA'),'web_location'),
  @sku nvarchar(100),@n bigint,@err int,@consignment uniqueidentifier=NEWID(),@event uniqueidentifier;
DECLARE @lines webstore.WebOrderLine;
SET @sku=(SELECT Sku FROM catalog.Items WHERE Id=@item);
DECLARE @x TABLE(Applied int);
DECLARE @other uniqueidentifier=NEWID();
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC test.SeedStock @item,@locA,5;
EXEC inventory.usp_ConsignToWeb @ConsignmentId=@consignment,@ItemId=@item,@FromLocationId=@locA,@Quantity=3,@ActorId=@manager;
EXEC inventory.usp_ConsignToWeb @ConsignmentId=@consignment,@ItemId=@item,@FromLocationId=@locA,@Quantity=3,@ActorId=@manager;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='store'); EXEC test.AssertEq N'store pool lost 3 once',2,@n;
SET @err=0;
BEGIN TRY
  EXEC inventory.usp_ConsignToWeb @ConsignmentId=@consignment,@ItemId=@item,@FromLocationId=@locA,@Quantity=2,@ActorId=@manager;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'id reused with other content',51741,@err;
SET @err=0;
BEGIN TRY
  EXEC inventory.usp_ConsignToWeb @ConsignmentId=@other,@ItemId=@item,@FromLocationId=@locA,@Quantity=0,@ActorId=@manager;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'zero units refused',51742,@err;
SET @err=0;
BEGIN TRY
  EXEC inventory.usp_ConsignToWeb @ConsignmentId=@other,@ItemId=@item,@FromLocationId=@locA,@Quantity=9,@ActorId=@manager;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'more than the store holds refused',51102,@err;
UPDATE sync.LocalNode SET NodeId=@cloud;
SET @err=0;
BEGIN TRY
  EXEC inventory.usp_ConsignToWeb @ConsignmentId=@other,@ItemId=@item,@FromLocationId=@locA,@Quantity=1,@ActorId=@manager;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'consign on the hub refused',51740,@err;
INSERT INTO @x EXEC inventory.usp_ApplyWebConsignments;
INSERT INTO @x EXEC inventory.usp_ApplyWebConsignments;
SET @n=(SELECT SUM(Applied) FROM @x); EXEC test.AssertEq N'applied once',1,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web'); EXEC test.AssertEq N'web pool holds 3',3,@n;
SET @n=(SELECT COUNT(*) FROM webstore.WebLocationSources WHERE WebLocationId=@webA AND SourceLocationId=@locA); EXEC test.AssertEq N'web location source is store A',1,@n;
PRINT 'PASS';
