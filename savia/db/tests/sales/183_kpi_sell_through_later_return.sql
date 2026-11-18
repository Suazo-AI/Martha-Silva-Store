-- TEST: a return made after a past period does not change that period's sell-through (Codex PR7 V027:1079).
SET NOCOUNT ON;SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),@item uniqueidentifier=test.Id('item'),
 @node uniqueidentifier=test.Id('nodeA'),@owner uniqueidentifier=test.Id('manager'),@manager uniqueidentifier=test.Id('supervisorA'),@cashier uniqueidentifier=test.Id('cashierA'),
 @register uniqueidentifier=test.Id('registerA'),@till uniqueidentifier=NEWID(),@n bigint,@before bigint,@sale uniqueidentifier=NEWID(),@rev uniqueidentifier=NEWID(),
 @product uniqueidentifier=(SELECT ProductId FROM catalog.Items WHERE Id=test.Id('item'));
EXEC test.SeedStock @item,@loc,10;
EXEC sales.usp_OpenTill @till,@register,@cashier,'NIO',0,@node;
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT @lines VALUES(1,@item,1,120000,0);
INSERT @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',120000,120000,0);
EXEC sales.usp_PostSale @sale,@branch,@loc,@cashier,'NIO',@node,@lines,@tenders,@TillId=@till;
-- Move the receipt and the sale to yesterday; the return below happens today.
UPDATE sales.Sales SET CreatedAt=DATEADD(day,-1,CreatedAt) WHERE Id=@sale;
UPDATE inventory.StockMovements SET CreatedAt=DATEADD(day,-1,CreatedAt) WHERE ItemId=@item AND Kind='receive';
DECLARE @yesterday date=DATEADD(day,-1,CONVERT(date,DATEADD(hour,-6,core.ufn_BusinessNow())));
DECLARE @biz TABLE(Json nvarchar(max));INSERT @biz EXEC sales.usp_KpiBusiness @branch,@owner,'day',@yesterday;
SET @before=(SELECT TRY_CONVERT(bigint,JSON_VALUE(value,'$.unitsSold')) FROM @biz CROSS APPLY OPENJSON(Json,'$.sellThrough') WHERE JSON_VALUE(value,'$.productId')=CONVERT(nvarchar(36),@product));
EXEC test.AssertEq N'yesterday sold one unit',1,@before;
DECLARE @r sales.ReturnLineRequest,@none sales.SaleLineRequest,@noTender sales.SaleTenderRequest;
INSERT @r SELECT Id,1,'store' FROM sales.SaleLines WHERE SaleId=@sale;
EXEC sales.usp_PostReturnOutcome @rev,@sale,@branch,@loc,@till,@manager,'cash',N'Talla',NULL,@node,@r,NULL,@none,@noTender;
DELETE @biz;INSERT @biz EXEC sales.usp_KpiBusiness @branch,@owner,'day',@yesterday;
SET @n=(SELECT TRY_CONVERT(bigint,JSON_VALUE(value,'$.unitsSold')) FROM @biz CROSS APPLY OPENJSON(Json,'$.sellThrough') WHERE JSON_VALUE(value,'$.productId')=CONVERT(nvarchar(36),@product));
EXEC test.AssertEq N'past period keeps its sold unit after a later return',@before,@n;
PRINT 'PASS';
