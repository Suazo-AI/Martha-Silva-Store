-- TEST: a cursor is created on first advance, never moves backwards, and a negative sequence is rejected.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @nodeA uniqueidentifier=test.Id('nodeA'),@nodeB uniqueidentifier=test.Id('nodeB'),
  @n bigint,@last bigint;

-- First advance creates the cursor.
EXEC sync.usp_AdvanceCursor @NodeId=@nodeA,@StreamName='outbox',@LastSequence=5;
SET @n=(SELECT COUNT(*) FROM sync.Cursors WHERE NodeId=@nodeA AND StreamName='outbox' AND LastSequence=5);
EXEC test.AssertEq N'cursor created at 5',1,@n;

-- An older sequence never moves the cursor backwards.
EXEC sync.usp_AdvanceCursor @NodeId=@nodeA,@StreamName='outbox',@LastSequence=3;
SET @last=(SELECT LastSequence FROM sync.Cursors WHERE NodeId=@nodeA AND StreamName='outbox');
EXEC test.AssertEq N'cursor stays at 5 after an older value',5,@last;

-- A newer sequence moves it forward.
EXEC sync.usp_AdvanceCursor @NodeId=@nodeA,@StreamName='outbox',@LastSequence=9;
SET @last=(SELECT LastSequence FROM sync.Cursors WHERE NodeId=@nodeA AND StreamName='outbox');
EXEC test.AssertEq N'cursor advanced to 9',9,@last;

-- Streams are independent.
EXEC sync.usp_AdvanceCursor @NodeId=@nodeA,@StreamName='inbox',@LastSequence=2;
SET @n=(SELECT COUNT(*) FROM sync.Cursors WHERE NodeId=@nodeA AND StreamName='inbox' AND LastSequence=2);
EXEC test.AssertEq N'second stream created',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Cursors WHERE NodeId=@nodeA);
EXEC test.AssertEq N'cursor rows per stream',2,@n;

-- A different node gets its own cursor.
EXEC sync.usp_AdvanceCursor @NodeId=@nodeB,@StreamName='outbox',@LastSequence=1;
SET @n=(SELECT COUNT(*) FROM sync.Cursors WHERE NodeId=@nodeB AND StreamName='outbox' AND LastSequence=1);
EXEC test.AssertEq N'cursor per node',1,@n;

-- Negative sequence.
BEGIN TRY
  EXEC sync.usp_AdvanceCursor @NodeId=@nodeB,@StreamName='outbox',@LastSequence=-1;
  THROW 59002,'ASSERT FAIL: negative cursor was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51015 THROW; END CATCH;
SET @last=(SELECT LastSequence FROM sync.Cursors WHERE NodeId=@nodeB AND StreamName='outbox');
EXEC test.AssertEq N'cursor unchanged after rejection',1,@last;
PRINT 'PASS';
