-- TEST: a close with a shortage in both drawers counts once and reports each currency separately.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@register uniqueidentifier=test.Id('registerA'),
 @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
 @owner uniqueidentifier=test.Id('manager'),@till uniqueidentifier=NEWID(),@nio uniqueidentifier=NEWID(),
 @usd uniqueidentifier=NEWID(),@closure uniqueidentifier=NEWID(),@n bigint;
DECLARE @nioOpen nvarchar(max)=N'[{"denominationMinor":100000,"quantity":1}]',
 @usdOpen nvarchar(max)=N'[{"denominationMinor":1000,"quantity":1}]',
 @nioShort nvarchar(max)=N'[{"denominationMinor":50000,"quantity":1}]',
 @usdShort nvarchar(max)=N'[{"denominationMinor":500,"quantity":1}]';

EXEC sales.usp_OpenTillCounted @till,@register,@cashier,'NIO',100000,@node,@nioOpen,@usdOpen;
EXEC sales.usp_RecordCashCount @nio,@till,@cashier,@nioShort,@usd,@usdShort;
EXEC sales.usp_CloseTill @closure,@till,@nio,@cashier,@node,@usd;
DECLARE @today date=CONVERT(date,DATEADD(hour,-6,core.ufn_BusinessNow()));
DECLARE @biz TABLE(Json nvarchar(max));
INSERT @biz EXEC sales.usp_KpiBusiness @branch,@owner,'day',@today;
SET @n=(SELECT CONVERT(bigint,JSON_VALUE(Json,'$.tillClosures')) FROM @biz);
EXEC test.AssertEq N'one parent close',1,@n;
SET @n=(SELECT CONVERT(bigint,JSON_VALUE(Json,'$.tillClosuresWithDifference')) FROM @biz);
EXEC test.AssertEq N'two differences count as one close',1,@n;
SET @n=(SELECT CONVERT(bigint,JSON_VALUE(Json,'$.tillDifferenceMinor')) FROM @biz);
EXEC test.AssertEq N'NIO shortage is reported in NIO minor units',-50000,@n;
SET @n=(SELECT CONVERT(bigint,JSON_VALUE(Json,'$.usdTillDifferenceMinor')) FROM @biz);
EXEC test.AssertEq N'USD shortage is reported in USD minor units',-500,@n;
PRINT 'PASS';
