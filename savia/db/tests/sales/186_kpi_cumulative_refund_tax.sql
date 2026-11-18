-- TEST: split refunds reverse the original tax and base across period boundaries, and sell-through uses the same cutoff.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
 @item uniqueidentifier=test.Id('item2'),@freeItem uniqueidentifier=test.Id('item'),@register uniqueidentifier=test.Id('registerA'),
 @node uniqueidentifier=test.Id('nodeA'),@cashier uniqueidentifier=test.Id('cashierA'),
 @manager uniqueidentifier=test.Id('supervisorA'),@owner uniqueidentifier=test.Id('manager'),
 @sale uniqueidentifier=NEWID(),@till uniqueidentifier=NEWID(),@n bigint,
 @r1 uniqueidentifier=NEWID(),@r2 uniqueidentifier=NEWID(),@r3 uniqueidentifier=NEWID();
DECLARE @product uniqueidentifier=(SELECT ProductId FROM catalog.Items WHERE Id=@item);

UPDATE catalog.Items SET UnitPriceMinor=1,TaxRateBps=3333 WHERE Id=@item;
UPDATE catalog.Items SET UnitPriceMinor=0 WHERE Id=@freeItem;
EXEC test.SeedStock @item,@loc,30;
EXEC test.SeedStock @freeItem,@loc,10;
EXEC sales.usp_OpenTill @till,@register,@cashier,'NIO',0,@node;
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT @lines VALUES(1,@item,3,1,0),(2,@freeItem,1,0,0);
INSERT @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',4,4,0);
EXEC sales.usp_PostSale @sale,@branch,@loc,@cashier,'NIO',@node,@lines,@tenders,@TillId=@till;
SET @n=(SELECT TaxMinor FROM sales.SaleLines WHERE SaleId=@sale AND LineNumber=1);
EXEC test.AssertEq N'original gross 4 includes tax 1',1,@n;

DECLARE @returnLines sales.ReturnLineRequest,@none sales.SaleLineRequest,@noTender sales.SaleTenderRequest;
INSERT @returnLines SELECT Id,1,'store' FROM sales.SaleLines WHERE SaleId=@sale;
EXEC sales.usp_PostReturnOutcome @r1,@sale,@branch,@loc,@till,@manager,'cash',N'Talla',NULL,@node,@returnLines,NULL,@none,@noTender;
-- The first refund includes a free line, so the allocation also encounters an original gross of zero.
SET @n=(SELECT rl.CreditMinor FROM sales.SaleReversalLines rl JOIN sales.SaleLines l ON l.Id=rl.SaleLineId
 WHERE rl.ReversalId=@r1 AND l.LineNumber=2 AND l.TotalMinor=0);
EXEC test.AssertEq N'free line has zero original gross and zero refund',0,@n;
DELETE @returnLines WHERE SaleLineId=(SELECT Id FROM sales.SaleLines WHERE SaleId=@sale AND LineNumber=2);
EXEC sales.usp_PostReturnOutcome @r2,@sale,@branch,@loc,@till,@manager,'cash',N'Talla',NULL,@node,@returnLines,NULL,@none,@noTender;
EXEC sales.usp_PostReturnOutcome @r3,@sale,@branch,@loc,@till,@manager,'cash',N'Talla',NULL,@node,@returnLines,NULL,@none,@noTender;

DECLARE @today date=CONVERT(date,DATEADD(hour,-6,core.ufn_BusinessNow()));
DECLARE @day0 date=DATEADD(day,-3,@today),@day1 date=DATEADD(day,-2,@today),@day2 date=DATEADD(day,-1,@today);
-- Place each event exactly at the start of a different business day.
UPDATE sales.Sales SET CreatedAt=DATEADD(hour,6,CONVERT(datetime2,@day0)) WHERE Id=@sale;
UPDATE inventory.StockMovements SET CreatedAt=DATEADD(hour,6,CONVERT(datetime2,@day0))
 WHERE ItemId IN (@item,@freeItem) AND LocationId=@loc AND Kind='receive';
UPDATE sales.SaleReversals
 SET CreatedAt=DATEADD(hour,6,CONVERT(datetime2,CASE Id WHEN @r1 THEN @day1 WHEN @r2 THEN @day2 ELSE @today END))
 WHERE Id IN (@r1,@r2,@r3);

DECLARE @biz TABLE(Json nvarchar(max));
INSERT @biz EXEC sales.usp_KpiBusiness @branch,@owner,'day',@day0;
SET @n=(SELECT CONVERT(bigint,JSON_VALUE(Json,'$.revenueMinor')) FROM @biz);
EXEC test.AssertEq N'sale day revenue is the original base',3,@n;
SET @n=(SELECT CONVERT(bigint,JSON_VALUE(value,'$.sellThroughBps')) FROM @biz CROSS APPLY OPENJSON(Json,'$.sellThrough')
 WHERE JSON_VALUE(value,'$.productId')=CONVERT(nvarchar(36),@product));
EXEC test.AssertEq N'original four of forty sold stays at 1000 bps',1000,@n;

DECLARE @day date=@day1,@revenue bigint,@reversed bigint=0,@grossMinor bigint;
WHILE @day<=@today
BEGIN
 DELETE @biz;
 INSERT @biz EXEC sales.usp_KpiBusiness @branch,@owner,'day',@day;
 SELECT @revenue=CONVERT(bigint,JSON_VALUE(Json,'$.revenueMinor')),
        @n=CONVERT(bigint,JSON_VALUE(Json,'$.grossMarginBps')),
        @grossMinor=CONVERT(bigint,JSON_VALUE(Json,'$.returnsMinor'))
 FROM @biz;
 IF @grossMinor IS NULL OR @grossMinor<>CASE WHEN @day=@today THEN 2 ELSE 1 END
  THROW 59002,'ASSERT FAIL: gross refunds must remain 1, 1, 2',1;
 EXEC test.AssertEq N'each date reverses one minor unit of base',-1,@revenue;
 EXEC test.AssertEq N'refund-only period has zero margin bps',0,@n;
 SET @reversed-=@revenue;
 SET @day=DATEADD(day,1,@day);
END;
EXEC test.AssertEq N'all refund dates reverse exactly the original base',3,@reversed;
SET @n=(SELECT CONVERT(bigint,JSON_VALUE(value,'$.unitsSold')) FROM @biz CROSS APPLY OPENJSON(Json,'$.sellThrough')
 WHERE JSON_VALUE(value,'$.productId')=CONVERT(nvarchar(36),@product));
EXEC test.AssertEq N'all four returned units count at the last cutoff',0,@n;
PRINT 'PASS';
