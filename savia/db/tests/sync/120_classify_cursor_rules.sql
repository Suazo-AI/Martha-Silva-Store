-- TEST: the receiver classifies a cursor as initial, incremental, reinit or recover (F1, F6, F7).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @peer uniqueidentifier=test.Id('nodeA'),@t sysname=N'[sales].[Sales]',
  @fork uniqueidentifier=NEWID(),@other uniqueidentifier=NEWID(),@a varchar(16),@from bigint,@isNull int,@ok int;
DECLARE @r TABLE([Action] varchar(16),FromVersion bigint);
-- No cursor yet.
INSERT @r EXEC sync.usp_ClassifyCursor @peer,@t,@fork,50,0;
SELECT @a=[Action],@from=FromVersion FROM @r; DELETE @r;
SET @ok=CASE WHEN @a='initial' THEN 1 ELSE 0 END; EXEC test.AssertEq N'no cursor -> initial',1,@ok;
EXEC sync.usp_AdvancePeerCursor @peer,@t,@fork,40;
-- Same fork, cursor inside the valid window.
INSERT @r EXEC sync.usp_ClassifyCursor @peer,@t,@fork,50,10;
SELECT @a=[Action],@from=FromVersion FROM @r; DELETE @r;
SET @ok=CASE WHEN @a='incremental' THEN 1 ELSE 0 END; EXEC test.AssertEq N'valid cursor -> incremental',1,@ok;
EXEC test.AssertEq N'incremental from the stored version',40,@from;
-- Changes before the cursor were cleaned up.
INSERT @r EXEC sync.usp_ClassifyCursor @peer,@t,@fork,90,41;
SELECT @a=[Action],@isNull=CASE WHEN FromVersion IS NULL THEN 1 ELSE 0 END FROM @r; DELETE @r;
SET @ok=CASE WHEN @a='reinit' THEN 1 ELSE 0 END; EXEC test.AssertEq N'cursor below min valid -> reinit',1,@ok;
EXEC test.AssertEq N'reinit has no FromVersion',1,@isNull;
-- The sender was restored: new fork, versions not comparable even when larger.
INSERT @r EXEC sync.usp_ClassifyCursor @peer,@t,@other,60,0;
SELECT @a=[Action] FROM @r; DELETE @r;
SET @ok=CASE WHEN @a='recover' THEN 1 ELSE 0 END; EXEC test.AssertEq N'new fork -> recover',1,@ok;
-- Same fork but the sender is behind the cursor.
INSERT @r EXEC sync.usp_ClassifyCursor @peer,@t,@fork,30,0;
SELECT @a=[Action] FROM @r; DELETE @r;
SET @ok=CASE WHEN @a='recover' THEN 1 ELSE 0 END; EXEC test.AssertEq N'version went backwards -> recover',1,@ok;
PRINT 'PASS';
