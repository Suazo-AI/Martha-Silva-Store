-- TEST: correction preserves history, and an invalid or stale USD count rolls back the NIO correction.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @register uniqueidentifier=test.Id('registerA'),@cashier uniqueidentifier=test.Id('cashierA'),
 @node uniqueidentifier=test.Id('nodeA'),@till uniqueidentifier=NEWID(),@usdTill uniqueidentifier,
 @nio1 uniqueidentifier=NEWID(),@usd1 uniqueidentifier=NEWID(),
 @nio2 uniqueidentifier=NEWID(),@usd2 uniqueidentifier=NEWID(),
 @nio3 uniqueidentifier=NEWID(),@usd3 uniqueidentifier=NEWID(),@n bigint;
DECLARE @nioOpen nvarchar(max)=N'[{"denominationMinor":100000,"quantity":1}]',
 @usdOpen nvarchar(max)=N'[{"denominationMinor":1000,"quantity":1}]',
 @nioShort nvarchar(max)=N'[{"denominationMinor":50000,"quantity":1}]',
 @usdShort nvarchar(max)=N'[{"denominationMinor":500,"quantity":1}]';

EXEC sales.usp_OpenTillCounted @till,@register,@cashier,'NIO',100000,@node,@nioOpen,@usdOpen;
SET @usdTill=(SELECT Id FROM sales.CashTills WHERE ParentTillId=@till);
EXEC sales.usp_RecordCashCount @nio1,@till,@cashier,@nioShort,@usd1,@usdShort;
BEGIN TRY
 -- A valid NIO count followed by a denomination that does not exist in USD.
 EXEC sales.usp_RecordCashCount @nio2,@till,@cashier,@nioOpen,@usd2,@nioOpen;
 THROW 59002,'ASSERT FAIL: invalid USD recount was accepted',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51541 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM sales.CashCounts WHERE Id IN (@nio1,@usd1) AND Status='submitted' AND SubmittedAt IS NOT NULL);
EXEC test.AssertEq N'both original counts survive invalid USD',2,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashCounts WHERE Id IN (@nio2,@usd2));
EXEC test.AssertEq N'neither replacement survives invalid USD',0,@n;

EXEC sales.usp_RecordCashCount @nio2,@till,@cashier,@nioOpen,@usd2,@usdOpen;
EXEC sales.usp_RecordCashCount @nio2,@till,@cashier,@nioOpen,@usd2,@usdOpen;
BEGIN TRY
 EXEC sales.usp_RecordCashCount @nio3,@till,@cashier,@nioShort,@usd1,@usdShort;
 THROW 59002,'ASSERT FAIL: stale USD recount was accepted',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51542 THROW; END CATCH;
BEGIN TRY
 EXEC sales.usp_RecordCashCount @nio1,@till,@cashier,@nioShort,@usd3,@usdShort;
 THROW 59002,'ASSERT FAIL: stale NIO recount was accepted',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51542 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM sales.CashCounts WHERE Id IN (@nio3,@usd3));
EXEC test.AssertEq N'mixed stale retries leave no new counts',0,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashCounts WHERE Id IN (@nio2,@usd2) AND Status='submitted' AND SubmittedAt IS NOT NULL);
EXEC test.AssertEq N'both corrected counts stay submitted',2,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashCounts WHERE Id IN (@nio1,@usd1) AND Status='void' AND SubmittedAt IS NULL);
EXEC test.AssertEq N'original counts stay void with no submission timestamp',2,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashCountLines WHERE Quantity=1 AND
 ((CashCountId=@nio1 AND DenominationMinor=50000) OR (CashCountId=@usd1 AND DenominationMinor=500)));
EXEC test.AssertEq N'void counts retain the original denomination lines',2,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashCounts c JOIN sales.CashCountLines l ON l.CashCountId=c.Id
 WHERE c.CountKind='opening' AND c.Status='submitted' AND c.SubmittedAt IS NOT NULL AND l.Quantity=1
   AND ((c.Id=@till AND l.DenominationMinor=100000) OR (c.Id=@usdTill AND l.DenominationMinor=1000)));
EXEC test.AssertEq N'both openings and their lines stay submitted',2,@n;
PRINT 'PASS';
