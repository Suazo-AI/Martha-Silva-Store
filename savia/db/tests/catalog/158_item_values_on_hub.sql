-- TEST: S9 (D-039). The hub has no branch: its owner reads prices and costs with no branch grant (V061); a manager
-- does not. A store read (with a branch) keeps the V019 check.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @owner uniqueidentifier=test.Id('manager'),@supervisor uniqueidentifier=test.Id('supervisorA'),
  @branch uniqueidentifier=test.Id('branchA'),@err int,@n int;
DECLARE @out TABLE(Json nvarchar(max));
INSERT @out EXEC catalog.usp_GetItemValues @BranchId=NULL,@ActorId=@owner,@Query=N'';
SET @n=(SELECT COUNT(*) FROM @out o CROSS APPLY OPENJSON(o.Json) j);
SET @n=IIF(@n>0,1,0); EXEC test.AssertEq N'the hub owner reads item values with no branch',1,@n;
SET @err=0;
BEGIN TRY INSERT @out EXEC catalog.usp_GetItemValues @BranchId=NULL,@ActorId=@supervisor,@Query=N''; END TRY
BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'a manager on the hub: 52001',52001,@err;
DELETE @out;
INSERT @out EXEC catalog.usp_GetItemValues @BranchId=@branch,@ActorId=@supervisor,@Query=N'';
SET @n=(SELECT COUNT(*) FROM @out); EXEC test.AssertEq N'a store manager with the branch grant still reads',1,@n;
PRINT 'PASS';
