-- TEST: a branch cannot write web stock. A's push with its store balance relabelled to the web location is refused
-- by the hub (51851): the WEB branch has no node, so no branch owns a web-location row.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@b uniqueidentifier=test.Id('nodeB'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @item uniqueidentifier=test.Id('item'),@locA uniqueidentifier=test.Id('locA'),@manager uniqueidentifier=test.Id('manager'),
  @webA uniqueidentifier=inventory.ufn_StepId(test.Id('locA'),'web_location'),
  @sku nvarchar(100),@n bigint,@err int,@consignment uniqueidentifier=NEWID(),@event uniqueidentifier;
DECLARE @lines webstore.WebOrderLine;
SET @sku=(SELECT Sku FROM catalog.Items WHERE Id=@item);
DECLARE @state nvarchar(max),@plan nvarchar(max),@p nvarchar(max),@bad nvarchar(max),@r nvarchar(max),@webText nvarchar(36),@fork uniqueidentifier=NEWID();
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC test.SeedStock @item,@locA,5;
EXEC inventory.usp_ConsignToWeb @ConsignmentId=@consignment,@ItemId=@item,@FromLocationId=@locA,@Quantity=2,@ActorId=@manager;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC inventory.usp_ApplyWebConsignments;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_PlanJson @PeerNodeId=@a,@StateJson=@state,@Json=@plan OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_ReadBatch @TargetNodeId=@cloud,@PlanJson=@plan,@Json=@p OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
SET @bad=(SELECT JSON_MODIFY(@p,'$.tables',JSON_QUERY(N'['+value+N']')) FROM OPENJSON(@p,'$.tables')
          WHERE JSON_VALUE(value,'$.t')=N'[inventory].[StockBalances]');
SET @n=(SELECT IIF(CHARINDEX(CONVERT(nvarchar(36),@locA),@bad)>0,1,0)); EXEC test.AssertEq N'A pushes its store balance',1,@n;
SET @bad=REPLACE(@bad,CONVERT(nvarchar(36),@locA),CONVERT(nvarchar(36),@webA));
SET @err=0;
BEGIN TRY
  EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@bad,@Json=@r OUTPUT;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'hub refuses a branch row at a web location',51851,@err;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@webA AND Pool='web'); EXEC test.AssertEq N'web stock unchanged',2,@n;
PRINT 'PASS';
