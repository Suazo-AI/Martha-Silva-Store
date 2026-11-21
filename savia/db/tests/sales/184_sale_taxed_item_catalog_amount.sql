-- TEST: the sale catalog gives the screen the amount SQL requires for a taxed item (Codex PR7 sale-logic.mjs:20).
SET NOCOUNT ON;SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),@item uniqueidentifier=test.Id('item2'),
 @node uniqueidentifier=test.Id('nodeA'),@cashier uniqueidentifier=test.Id('cashierA'),
 @register uniqueidentifier=test.Id('registerA'),@till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@n bigint;
EXEC test.SeedStock @item,@loc,1;
EXEC sales.usp_OpenTill @till,@register,@cashier,'NIO',0,@node;
-- The screen builds tenders only from what the sale catalog returns.
DECLARE @cat TABLE(Json nvarchar(max));INSERT @cat EXEC catalog.usp_ListSaleCatalog @loc;
DECLARE @price bigint,@taxBps bigint;
SELECT @price=TRY_CONVERT(bigint,JSON_VALUE(v.value,'$.unitPriceMinor')),@taxBps=COALESCE(TRY_CONVERT(bigint,JSON_VALUE(v.value,'$.taxRateBps')),0)
 FROM @cat c CROSS APPLY OPENJSON(c.Json) p CROSS APPLY OPENJSON(p.value,'$.variants') v WHERE JSON_VALUE(v.value,'$.itemId')=CONVERT(nvarchar(36),@item);
EXEC test.AssertEq N'catalog price of the taxed item',85000,@price;
DECLARE @due bigint=@price+ROUND(@price*@taxBps/10000.0,0);
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT @lines VALUES(1,@item,1,@price,0);
INSERT @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',@due,@due,0);
EXEC sales.usp_PostSale @sale,@branch,@loc,@cashier,'NIO',@node,@lines,@tenders,@TillId=@till;
SET @n=(SELECT TotalMinor FROM sales.Sales WHERE Id=@sale);EXEC test.AssertEq N'sale total includes 15 percent tax',97750,@n;
PRINT 'PASS';
