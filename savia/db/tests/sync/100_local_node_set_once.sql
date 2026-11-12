-- TEST: a database is set to one node once; a retry is a no-op; another node or an unknown node is rejected (F10).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@b uniqueidentifier=test.Id('nodeB'),@n bigint,@err int;
SET @err=0;
BEGIN TRY EXEC sync.usp_SetLocalNode @NodeId='00000000-0000-0000-0000-00000000DEAD'; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'unknown node rejected',51807,@err;
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC sync.usp_SetLocalNode @NodeId=@a;
SET @n=(SELECT COUNT(*) FROM sync.LocalNode WHERE NodeId=@a);
EXEC test.AssertEq N'one local node row after a retry',1,@n;
SET @err=0;
BEGIN TRY EXEC sync.usp_SetLocalNode @NodeId=@b; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'another node rejected',51806,@err;
SET @err=0;
BEGIN TRY INSERT INTO sync.LocalNode(Singleton,NodeId) VALUES(2,@b); END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'a second row is impossible (CHECK)',547,@err;
PRINT 'PASS';
