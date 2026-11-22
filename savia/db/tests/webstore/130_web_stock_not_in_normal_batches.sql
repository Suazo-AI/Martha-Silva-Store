-- TEST: web stock never travels in a normal batch: not in the hub's batch to a branch, not in a branch's push.
-- A rebuild of branch A from the hub carries it, and A has the web location to receive it.
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
DECLARE @o1 uniqueidentifier=NEWID();
INSERT INTO @lines VALUES(1,@sku,1);
SET @event=NEWID();
EXEC webstore.usp_CreateWebOrder @OrderId=@o1,@RequestHash=0x51,@AccessTokenHash=0x02,@ClientHash=NULL,@Lines=@lines,
  @Name=N'Compradora',@Email=N'uno@example.test',@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
  @Notes=NULL,@Provider='manual',@OriginNodeId=@cloud,@EventId=@event;
SET @webText=CONVERT(nvarchar(36),@webA);
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@b;
EXEC sync.usp_PlanJson @PeerNodeId=@cloud,@StateJson=@state,@Json=@plan OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_ReadBatch @TargetNodeId=@b,@PlanJson=@plan,@Json=@p OUTPUT;
SET @n=(SELECT CHARINDEX(@webText,@p)); EXEC test.AssertEq N'hub batch to B has no web location row',0,@n;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_PlanJson @PeerNodeId=@a,@StateJson=@state,@Json=@plan OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_ReadBatch @TargetNodeId=@cloud,@PlanJson=@plan,@Json=@p OUTPUT;
SET @n=(SELECT CHARINDEX(@webText,@p)); EXEC test.AssertEq N'A push has no web location row',0,@n;
SET @n=(SELECT IIF(CHARINDEX(CONVERT(nvarchar(36),@consignment),@p)>0,1,0)); EXEC test.AssertEq N'A push carries the consignment',1,@n;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_PlanJson @PeerNodeId=@cloud,@StateJson=@state,@Mode='rebuild',@Json=@plan OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_ReadBatch @TargetNodeId=@a,@PlanJson=@plan,@TargetForkGuid=@fork,@Json=@p OUTPUT;
SET @n=(SELECT IIF(CHARINDEX(@webText,@p)>0,1,0)); EXEC test.AssertEq N'rebuild of A carries web stock',1,@n;
SET @n=(SELECT COUNT(*) FROM core.Locations WHERE Id=@webA); EXEC test.AssertEq N'A has the web location row',1,@n;
PRINT 'PASS';
