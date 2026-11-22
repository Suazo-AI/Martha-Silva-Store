-- TEST: a user that is only a member of savia_api_host reads and applies an initial and an incremental sync batch.
-- The sync procedures build dynamic SQL, which runs with the caller's permissions, so sa-only tests cannot see a gap.
-- One database plays both nodes, as in sync/210; sync.LocalNode is switched as dbo between the calls.
-- Same steps as savia/docs/evidence/gap-register-20261121/probe-hub-api-role.sql (gap G2), as assertions.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @state nvarchar(max),@plan nvarchar(max),@batch nvarchar(max),@dboBatch nvarchar(max),@r nvarchar(max),@n bigint,@err int,@id uniqueidentifier;
CREATE USER [api_host_probe] WITHOUT LOGIN;
ALTER ROLE [savia_api_host] ADD MEMBER [api_host_probe];

DECLARE @round int=1;
EXEC sync.usp_SetLocalNode @NodeId=@a;
WHILE @round<=2
BEGIN
  SET @id=NEWID();
  UPDATE sync.LocalNode SET NodeId=@a;
  EXEC test.SeedSale @id,'A';
  EXECUTE AS USER=N'api_host_probe';
  EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
  REVERT;
  UPDATE sync.LocalNode SET NodeId=@cloud;
  EXECUTE AS USER=N'api_host_probe';
  EXEC sync.usp_PlanJson @PeerNodeId=@a,@StateJson=@state,@Json=@plan OUTPUT;
  REVERT;
  SET @n=(SELECT COUNT(*) FROM OPENJSON(@plan,'$.tables') WITH (a varchar(20))
          WHERE a=CASE @round WHEN 1 THEN 'initial' ELSE 'incremental' END);
  EXEC test.AssertEq N'plan kind for every table',23,@n;
  UPDATE sync.LocalNode SET NodeId=@a;
  EXECUTE AS USER=N'api_host_probe';
  EXEC sync.usp_ReadBatch @TargetNodeId=@cloud,@PlanJson=@plan,@Json=@batch OUTPUT;   -- incremental: CHANGETABLE
  REVERT;
  EXEC sync.usp_ReadBatch @TargetNodeId=@cloud,@PlanJson=@plan,@Json=@dboBatch OUTPUT;
  SET @n=IIF(@batch=@dboBatch,1,0); EXEC test.AssertEq N'the role reads the same batch as dbo',1,@n;
  SET @n=(SELECT COUNT(*) FROM OPENJSON(@batch,'$.tables[1].rows')); EXEC test.AssertEq N'the new sale travels',1,@n;
  UPDATE sync.LocalNode SET NodeId=@cloud;
  EXECUTE AS USER=N'api_host_probe';
  EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@batch,@Json=@r OUTPUT;            -- MERGE into synced tables
  REVERT;
  SET @n=JSON_VALUE(@r,'$.applied'); EXEC test.AssertEq N'every table applied',23,@n;
  SET @round+=1;
END;

-- The role still cannot delete synced rows or change the schema.
EXECUTE AS USER=N'api_host_probe';
SET @err=0;
BEGIN TRY DELETE TOP (1) FROM sales.Sales; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'DELETE on a synced table is denied',229,@err;
SET @err=0;
BEGIN TRY EXEC(N'CREATE TABLE dbo.ApiHostProbe(Id int);'); END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'DDL is denied',262,@err;
REVERT;
PRINT 'PASS';
