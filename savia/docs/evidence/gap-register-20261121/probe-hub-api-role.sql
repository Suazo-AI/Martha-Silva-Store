-- PROBE (gap register 2026-11-21): can the hub API database role run the P9 sync procedures?
-- The role and grants copy savia/deploy/migrator/Program.cs:167-172 (what the Azure API identity gets).
-- One database plays both nodes, as db/tests/sync/210 does. Branch steps run as dbo; hub steps run as the role.
-- Run on a disposable clone of the test template (fixture loaded). Prints one line per step.
SET NOCOUNT ON;
IF DATABASE_PRINCIPAL_ID(N'savia_api_host') IS NULL CREATE ROLE [savia_api_host] AUTHORIZATION [dbo];
GRANT SELECT TO [savia_api_host];
GRANT EXECUTE TO [savia_api_host];
GRANT INSERT, UPDATE ON OBJECT::[security].[Sessions] TO [savia_api_host];
GRANT UPDATE ON OBJECT::[security].[Staff] TO [savia_api_host];
CREATE USER [probe_api] WITHOUT LOGIN;
ALTER ROLE [savia_api_host] ADD MEMBER [probe_api];
GO
SET NOCOUNT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@cloud uniqueidentifier=test.Id('nodeCloud'),@id uniqueidentifier=NEWID(),
  @state nvarchar(max),@hubState nvarchar(max),@plan nvarchar(max),@pullPlan nvarchar(max),@batch nvarchar(max),
  @pull nvarchar(max),@r nvarchar(max),@msg nvarchar(4000);
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC test.SeedSale @id,'A';
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;                       -- branch A, as dbo

-- Hub step 1 (POST /sync/v1/push/plan): usp_PlanJson as the API role.
UPDATE sync.LocalNode SET NodeId=@cloud;
EXECUTE AS USER='probe_api';
BEGIN TRY EXEC sync.usp_PlanJson @PeerNodeId=@a,@StateJson=@state,@Json=@plan OUTPUT; PRINT 'HUB-ROLE usp_PlanJson: OK';
END TRY BEGIN CATCH SET @msg=CONCAT('HUB-ROLE usp_PlanJson: Msg ',ERROR_NUMBER(),' ',ERROR_MESSAGE()); PRINT @msg; END CATCH;
REVERT;
IF @plan IS NULL EXEC sync.usp_PlanJson @PeerNodeId=@a,@StateJson=@state,@Json=@plan OUTPUT;

-- Branch A reads its push batch, as dbo.
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_ReadBatch @TargetNodeId=@cloud,@PlanJson=@plan,@Json=@batch OUTPUT;

-- Hub step 2 (POST /sync/v1/push): usp_ApplyBatch as the API role.
UPDATE sync.LocalNode SET NodeId=@cloud;
EXECUTE AS USER='probe_api';
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@batch,@Json=@r OUTPUT; PRINT CONCAT('HUB-ROLE usp_ApplyBatch: OK ',@r);
END TRY BEGIN CATCH SET @msg=CONCAT('HUB-ROLE usp_ApplyBatch: Msg ',ERROR_NUMBER(),' ',ERROR_MESSAGE()); PRINT @msg; END CATCH;
REVERT;
DECLARE @cursors int=(SELECT COUNT(*) FROM sync.PeerCursors WHERE PeerNodeId=@a);
PRINT CONCAT('HUB-ROLE cursors after role apply: ',@cursors);

-- Control: the same batch as dbo (what every existing test does).
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@batch,@Json=@r OUTPUT; PRINT CONCAT('DBO usp_ApplyBatch: OK ',@r);
END TRY BEGIN CATCH SET @msg=CONCAT('DBO usp_ApplyBatch: Msg ',ERROR_NUMBER(),' ',ERROR_MESSAGE()); PRINT @msg; END CATCH;

-- Hub step 3 (GET /sync/v1/state): usp_SourceStateJson as the API role.
EXECUTE AS USER='probe_api';
BEGIN TRY EXEC sync.usp_SourceStateJson @Json=@hubState OUTPUT; PRINT 'HUB-ROLE usp_SourceStateJson: OK';
END TRY BEGIN CATCH SET @msg=CONCAT('HUB-ROLE usp_SourceStateJson: Msg ',ERROR_NUMBER(),' ',ERROR_MESSAGE()); PRINT @msg; END CATCH;
REVERT;
IF @hubState IS NULL EXEC sync.usp_SourceStateJson @Json=@hubState OUTPUT;

-- Branch A plans its pull, as dbo.
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_PlanJson @PeerNodeId=@cloud,@StateJson=@hubState,@Json=@pullPlan OUTPUT;

-- Hub step 4 (POST /sync/v1/pull): usp_ReadBatch for A as the API role.
UPDATE sync.LocalNode SET NodeId=@cloud;
EXECUTE AS USER='probe_api';
BEGIN TRY EXEC sync.usp_ReadBatch @TargetNodeId=@a,@PlanJson=@pullPlan,@Json=@pull OUTPUT; PRINT 'HUB-ROLE usp_ReadBatch (initial plan): OK';
END TRY BEGIN CATCH SET @msg=CONCAT('HUB-ROLE usp_ReadBatch (initial plan): Msg ',ERROR_NUMBER(),' ',ERROR_MESSAGE()); PRINT @msg; END CATCH;
REVERT;

-- Same answer? Source state as the role and as dbo (the min versions come from Change Tracking).
DECLARE @roleState nvarchar(max),@dboState nvarchar(max);
EXECUTE AS USER='probe_api'; EXEC sync.usp_SourceStateJson @Json=@roleState OUTPUT; REVERT;
EXEC sync.usp_SourceStateJson @Json=@dboState OUTPUT;
PRINT CONCAT('SourceStateJson role = dbo: ',IIF(@roleState=@dboState,'yes','NO'));
DECLARE @minRole int,@minDbo int;
SELECT @minRole=COUNT(*) FROM OPENJSON(@roleState,'$.tables') WITH (m bigint '$.min') WHERE m IS NOT NULL;
SELECT @minDbo=COUNT(*) FROM OPENJSON(@dboState,'$.tables') WITH (m bigint '$.min') WHERE m IS NOT NULL;
PRINT CONCAT('SourceStateJson tables with min: role=',@minRole,' dbo=',@minDbo);

-- Second round: A applies the initial pull, branch B sells, then the hub reads an incremental pull (CHANGETABLE path) as the role.
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_ApplyBatch @PeerNodeId=@cloud,@BatchJson=@pull,@Json=@r OUTPUT;
SET @id=NEWID(); EXEC test.SeedSale @id,'B';
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_SourceStateJson @Json=@hubState OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_PlanJson @PeerNodeId=@cloud,@StateJson=@hubState,@Json=@pullPlan OUTPUT;
DECLARE @inc int=(SELECT COUNT(*) FROM OPENJSON(@pullPlan,'$.tables') WITH (a varchar(20)) WHERE a='incremental');
PRINT CONCAT('second pull plan: incremental tables=',@inc);
UPDATE sync.LocalNode SET NodeId=@cloud;
DECLARE @rolePull nvarchar(max),@dboPull nvarchar(max);
EXECUTE AS USER='probe_api';
BEGIN TRY EXEC sync.usp_ReadBatch @TargetNodeId=@a,@PlanJson=@pullPlan,@Json=@rolePull OUTPUT; PRINT 'HUB-ROLE usp_ReadBatch (incremental plan): OK';
END TRY BEGIN CATCH SET @msg=CONCAT('HUB-ROLE usp_ReadBatch (incremental plan): Msg ',ERROR_NUMBER(),' ',ERROR_MESSAGE()); PRINT @msg; END CATCH;
REVERT;
EXEC sync.usp_ReadBatch @TargetNodeId=@a,@PlanJson=@pullPlan,@Json=@dboPull OUTPUT;
DECLARE @rowsRole int,@rowsDbo int;
SELECT @rowsRole=SUM(x.n) FROM OPENJSON(@rolePull,'$.tables') WITH (r nvarchar(max) '$.rows' AS JSON) t CROSS APPLY (SELECT COUNT(*) AS n FROM OPENJSON(t.r)) x;
SELECT @rowsDbo=SUM(x.n) FROM OPENJSON(@dboPull,'$.tables') WITH (r nvarchar(max) '$.rows' AS JSON) t CROSS APPLY (SELECT COUNT(*) AS n FROM OPENJSON(t.r)) x;
PRINT CONCAT('incremental pull rows: role=',@rowsRole,' dbo=',@rowsDbo,' identical batch=',IIF(@rolePull=@dboPull,'yes','no (token/version fields may differ)'));
GO
