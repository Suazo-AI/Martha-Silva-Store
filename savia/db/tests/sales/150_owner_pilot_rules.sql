-- TEST: counted opening, unrestricted manager discount, physical-stock exception, receipt and review conserve stock.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@bad uniqueidentifier=NEWID(),
 @register uniqueidentifier=test.Id('registerA'),@cashier uniqueidentifier=test.Id('cashierA'),
 @manager uniqueidentifier=test.Id('supervisorA'),@branch uniqueidentifier=test.Id('branchA'),
 @loc uniqueidentifier=test.Id('locA'),@node uniqueidentifier=test.Id('nodeA'),@item uniqueidentifier=test.Id('item'),@n bigint;
BEGIN TRY
 EXEC sales.usp_OpenTillCounted @bad,@register,@cashier,'NIO',100000,@node,N'[{"denominationMinor":50000,"quantity":1}]';
 THROW 59002,'ASSERT FAIL: mismatched opening accepted',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51545 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM sales.CashTills WHERE Id=@bad);
EXEC test.AssertEq N'bad opening leaves no till',0,@n;
EXEC sales.usp_OpenTillCounted @till,@register,@cashier,'NIO',100000,@node,N'[{"denominationMinor":50000,"quantity":2}]';
EXEC sales.usp_OpenTillCounted @till,@register,@cashier,'NIO',100000,@node,N'[{"denominationMinor":50000,"quantity":2}]';
SET @n=(SELECT SUM(l.DenominationMinor*l.Quantity) FROM sales.CashCountLines l JOIN sales.CashCounts c ON c.Id=l.CashCountId WHERE c.TillId=@till AND c.CountKind='opening');
EXEC test.AssertEq N'opening breakdown persisted once',100000,@n;
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines VALUES(1,@item,2,120000,216000);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',24000,24000,0);
BEGIN TRY
 EXEC sales.usp_PostSale @sale,@branch,@loc,@cashier,'NIO',@node,@lines,@tenders,@TillId=@till,@DiscountReason=N'Oferta';
 THROW 59002,'ASSERT FAIL: cashier discount accepted',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>51544 THROW; END CATCH;
EXEC sales.usp_PostSale @sale,@branch,@loc,@cashier,'NIO',@node,@lines,@tenders,@TillId=@till,
 @DiscountApproverId=@manager,@DiscountReason=N'Oferta autorizada',@StockExceptionNote=N'El sistema decia 0 y habia existencia fisica';
EXEC sales.usp_PostSale @sale,@branch,@loc,@cashier,'NIO',@node,@lines,@tenders,@TillId=@till,
 @DiscountApproverId=@manager,@DiscountReason=N'Oferta autorizada',@StockExceptionNote=N'El sistema decia 0 y habia existencia fisica';
SET @n=(SELECT COUNT(*) FROM sales.Sales WHERE Id=@sale AND DiscountApprovedBy=@manager AND DiscountReason=N'Oferta autorizada' AND ReceiptSequence=1);
EXEC test.AssertEq N'manager, reason and receipt persisted',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.StockExceptions e JOIN sales.SaleLines l ON l.Id=e.SaleLineId WHERE l.SaleId=@sale AND e.QuantityShort=2 AND e.CashierId=@cashier);
EXEC test.AssertEq N'one traced shortage for the sale line',1,@n;
SET @n=(SELECT SUM(CONVERT(bigint,OnHandDelta)) FROM inventory.StockMovements WHERE ItemId=@item AND LocationId=@loc);
EXEC test.AssertEq N'adjustment plus sale equals zero',0,@n;
DECLARE @exception uniqueidentifier=(SELECT e.Id FROM sales.StockExceptions e JOIN sales.SaleLines l ON l.Id=e.SaleLineId WHERE l.SaleId=@sale);
EXEC sales.usp_ReviewStockException @branch,@exception,@manager,N'Revisado: ingreso omitido';
EXEC sales.usp_ReviewStockException @branch,@exception,@manager,N'Otro intento';
SET @n=(SELECT COUNT(*) FROM sales.StockExceptionReviews WHERE SaleLineId=(SELECT SaleLineId FROM sales.StockExceptions WHERE Id=@exception) AND ReviewerId=@manager AND Outcome=N'Revisado: ingreso omitido' AND Status='resolved');
EXEC test.AssertEq N'review is audited and idempotent',1,@n;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';
