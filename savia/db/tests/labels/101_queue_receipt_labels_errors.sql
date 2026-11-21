-- TEST: usp_QueueReceiptLabels rejects a receipt that does not exist (51401) and queues nothing.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @missing uniqueidentifier=NEWID(),@actor uniqueidentifier=test.Id('manager'),@n bigint;

BEGIN TRY
  EXEC labels.usp_QueueReceiptLabels @ReceiptId=@missing,@ActorId=@actor;
  THROW 59002,'ASSERT FAIL: a receipt that does not exist was queued',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51401 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM labels.PrintJobs);
EXEC test.AssertEq N'label jobs after the rejection',0,@n;
SET @n=(SELECT COUNT(*) FROM labels.PrintAttempts);
EXEC test.AssertEq N'print attempts after the rejection',0,@n;
PRINT 'PASS';
