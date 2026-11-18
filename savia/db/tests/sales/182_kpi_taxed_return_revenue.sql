-- TEST: a fully returned taxed sale leaves revenue and gross margin at zero (Codex PR7 V027:1057).
SET NOCOUNT ON;SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),@item uniqueidentifier=test.Id('item2'),
 @node uniqueidentifier=test.Id('nodeA'),@owner uniqueidentifier=test.Id('manager'),@manager uniqueidentifier=test.Id('supervisorA'),@cashier uniqueidentifier=test.Id('cashierA'),
 @register uniqueidentifier=test.Id('registerA'),@till uniqueidentifier=NEWID(),@n bigint,@sale uniqueidentifier=NEWID(),@rev uniqueidentifier=NEWID();
EXEC test.SeedStock @item,@loc,1;
EXEC sales.usp_OpenTill @till,@register,@cashier,'NIO',0,@node;
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT @lines VALUES(1,@item,1,85000,0);
-- 85000 plus 15 percent tax (12750) = 97750.
INSERT @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',97750,97750,0);
EXEC sales.usp_PostSale @sale,@branch,@loc,@cashier,'NIO',@node,@lines,@tenders,@TillId=@till;
DECLARE @r sales.ReturnLineRequest,@none sales.SaleLineRequest,@noTender sales.SaleTenderRequest;
INSERT @r SELECT Id,1,'store' FROM sales.SaleLines WHERE SaleId=@sale;
EXEC sales.usp_PostReturnOutcome @rev,@sale,@branch,@loc,@till,@manager,'cash',N'Talla',NULL,@node,@r,NULL,@none,@noTender;
DECLARE @today date=CONVERT(date,DATEADD(hour,-6,core.ufn_BusinessNow()));
DECLARE @biz TABLE(Json nvarchar(max));INSERT @biz EXEC sales.usp_KpiBusiness @branch,@owner,'day',@today;
SET @n=(SELECT TRY_CONVERT(bigint,JSON_VALUE(Json,'$.netSalesMinor')) FROM @biz);EXEC test.AssertEq N'net sales after full return',0,@n;
SET @n=(SELECT TRY_CONVERT(bigint,JSON_VALUE(Json,'$.costOfGoodsMinor')) FROM @biz);EXEC test.AssertEq N'net cost after full return',0,@n;
SET @n=(SELECT TRY_CONVERT(bigint,JSON_VALUE(Json,'$.revenueMinor')) FROM @biz);EXEC test.AssertEq N'revenue excludes refunded tax',0,@n;
SET @n=(SELECT TRY_CONVERT(bigint,JSON_VALUE(Json,'$.grossMarginMinor')) FROM @biz);EXEC test.AssertEq N'gross margin after full return',0,@n;
PRINT 'PASS';
