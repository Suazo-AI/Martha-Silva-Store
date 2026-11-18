-- TEST: a till closed with balanced cordobas but short dollars counts as a closure with a difference (Codex PR7 V027:1091).
SET NOCOUNT ON;SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@register uniqueidentifier=test.Id('registerA'),@cashier uniqueidentifier=test.Id('cashierA'),
 @node uniqueidentifier=test.Id('nodeA'),@owner uniqueidentifier=test.Id('manager'),
 @till uniqueidentifier=NEWID(),@c uniqueidentifier=NEWID(),@cu uniqueidentifier=NEWID(),@closure uniqueidentifier=NEWID(),@n bigint;
DECLARE @nio nvarchar(max)=N'[{"denominationMinor":100000,"quantity":1}]',@usdOpen nvarchar(max)=N'[{"denominationMinor":1000,"quantity":1}]',
 @usdShort nvarchar(max)=N'[{"denominationMinor":500,"quantity":1}]';
EXEC sales.usp_OpenTillCounted @till,@register,@cashier,'NIO',100000,@node,@nio,@usdOpen;
EXEC sales.usp_RecordCashCount @c,@till,@cashier,@nio,@cu,@usdShort;
EXEC sales.usp_CloseTill @closure,@till,@c,@cashier,@node,@cu;
SET @n=(SELECT DifferenceMinor FROM sales.CashClosures WHERE Id=@closure);EXEC test.AssertEq N'cordobas balance',0,@n;
SET @n=(SELECT cl.DifferenceMinor FROM sales.CashClosures cl JOIN sales.CashTills t ON t.Id=cl.TillId WHERE t.ParentTillId=@till);EXEC test.AssertEq N'dollars short by 5 USD',-500,@n;
DECLARE @today date=CONVERT(date,DATEADD(hour,-6,core.ufn_BusinessNow()));
DECLARE @biz TABLE(Json nvarchar(max));INSERT @biz EXEC sales.usp_KpiBusiness @branch,@owner,'day',@today;
SET @n=(SELECT TRY_CONVERT(bigint,JSON_VALUE(Json,'$.tillClosures')) FROM @biz);EXEC test.AssertEq N'one closure',1,@n;
SET @n=(SELECT TRY_CONVERT(bigint,JSON_VALUE(Json,'$.tillClosuresWithDifference')) FROM @biz);EXEC test.AssertEq N'closure with a USD difference is counted',1,@n;
PRINT 'PASS';
