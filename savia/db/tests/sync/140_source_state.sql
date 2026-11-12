-- TEST: the source state reports the local node, the recovery fork, the current version and one row per tracked table.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @node uniqueidentifier=test.Id('nodeA'),@n bigint;
EXEC sync.usp_SetLocalNode @NodeId=@node;
DECLARE @s TABLE(NodeId uniqueidentifier,ForkGuid uniqueidentifier,CurrentVersion bigint,TableName sysname,MinValidVersion bigint);
INSERT @s EXEC sync.usp_GetSourceState;
SET @n=(SELECT COUNT(*) FROM @s); EXEC test.AssertEq N'one row per tracked table',6,@n;
SET @n=(SELECT COUNT(*) FROM @s WHERE NodeId=@node); EXEC test.AssertEq N'rows carry the local node',6,@n;
SET @n=(SELECT COUNT(*) FROM @s WHERE ForkGuid IS NULL OR CurrentVersion IS NULL OR MinValidVersion IS NULL);
EXEC test.AssertEq N'no null fork or version',0,@n;
SET @n=(SELECT COUNT(*) FROM @s WHERE MinValidVersion>CurrentVersion);
EXEC test.AssertEq N'min valid never above current',0,@n;
SET @n=(SELECT COUNT(DISTINCT ForkGuid) FROM @s); EXEC test.AssertEq N'one fork',1,@n;
PRINT 'PASS';
