-- TEST: an operator can correct a saved closing count before closing the till (Codex PR7 cash.mjs:48).
SET NOCOUNT ON;SET XACT_ABORT ON;
DECLARE @register uniqueidentifier=test.Id('registerA'),@cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
 @till uniqueidentifier=NEWID(),@c1 uniqueidentifier=NEWID(),@c2 uniqueidentifier=NEWID(),@closure uniqueidentifier=NEWID(),
 @usd1 uniqueidentifier=NEWID(),@usd2 uniqueidentifier=NEWID(),@n bigint,@id uniqueidentifier;
DECLARE @open nvarchar(max)=N'[{"denominationMinor":100000,"quantity":1}]',@usd nvarchar(max)=N'[{"denominationMinor":1000,"quantity":1}]';
EXEC sales.usp_OpenTillCounted @till,@register,@cashier,'NIO',100000,@node,@open,@usd;
-- First save: a miscount.
DECLARE @wrong nvarchar(max)=N'[{"denominationMinor":50000,"quantity":1}]';
EXEC sales.usp_RecordCashCount @c1,@till,@cashier,@wrong,@usd1,@usd;
-- Second save after recounting: the UI sends new count ids for the changed lines.
EXEC sales.usp_RecordCashCount @c2,@till,@cashier,@open,@usd2,@usd;
EXEC sales.usp_CloseTill @closure,@till,@c2,@cashier,@node,@usd2;
SET @id=(SELECT CashCountId FROM sales.CashClosures WHERE Id=@closure);
SET @n=CASE WHEN @id=@c2 THEN 1 ELSE 0 END;EXEC test.AssertEq N'closure uses the corrected count',1,@n;
SET @n=(SELECT DifferenceMinor FROM sales.CashClosures WHERE Id=@closure);EXEC test.AssertEq N'corrected count balances',0,@n;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';
