-- TEST: the cursor only moves forward inside a fork, a retry is a no-op, a new fork replaces it, untracked tables are rejected.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @peer uniqueidentifier=test.Id('nodeB'),@t sysname=N'[sales].[CashEntries]',
  @fork uniqueidentifier=NEWID(),@fork2 uniqueidentifier=NEWID(),@n bigint,@err int;
EXEC sync.usp_AdvancePeerCursor @peer,@t,@fork,10;
EXEC sync.usp_AdvancePeerCursor @peer,@t,@fork,10;
EXEC sync.usp_AdvancePeerCursor @peer,@t,@fork,25;
SET @n=(SELECT [Version] FROM sync.PeerCursors WHERE PeerNodeId=@peer AND TableName=@t);
EXEC test.AssertEq N'cursor moved forward',25,@n;
SET @err=0;
BEGIN TRY EXEC sync.usp_AdvancePeerCursor @peer,@t,@fork,20; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'backwards in the same fork rejected',51808,@err;
SET @n=(SELECT [Version] FROM sync.PeerCursors WHERE PeerNodeId=@peer AND TableName=@t);
EXEC test.AssertEq N'cursor unchanged after the rejection',25,@n;
EXEC sync.usp_AdvancePeerCursor @peer,@t,@fork2,3;
SET @n=(SELECT COUNT(*) FROM sync.PeerCursors WHERE PeerNodeId=@peer AND TableName=@t AND ForkGuid=@fork2 AND [Version]=3);
EXEC test.AssertEq N'a new fork replaces the cursor after recovery',1,@n;
SET @err=0;
BEGIN TRY EXEC sync.usp_AdvancePeerCursor @peer,N'[security].[Staff]',@fork,1; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'untracked table rejected',51809,@err;
PRINT 'PASS';
