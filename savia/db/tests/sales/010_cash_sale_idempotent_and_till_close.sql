-- TEST: a cash sale lowers stock once even when retried; the till closes with expected = opening + cash sales and one accounting document.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@supervisor uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@register uniqueidentifier=test.Id('registerA'),
  @item uniqueidentifier=test.Id('item'),@till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),
  @count uniqueidentifier=NEWID(),@close uniqueidentifier=NEWID(),@n bigint;

EXEC test.SeedStock @item,@loc,5;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=100000,@OriginNodeId=@node;

DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,2,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',240000,300000,60000);
EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
     @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders;
-- Same request again (the POS did not get the reply): nothing may change.
EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
     @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders;

SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');
EXEC test.AssertEq N'stock after one sale of 2 (and a retry)',3,@n;
SET @n=(SELECT COUNT(*) FROM sales.Sales WHERE Id=@sale);
EXEC test.AssertEq N'sales rows',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@sale AND EventType='sales.sale_posted');
EXEC test.AssertEq N'sale events in outbox',1,@n;
SET @n=(SELECT COALESCE(SUM(DeltaMinor),0) FROM sales.CashEntries WHERE TillId=@till AND Kind='sale');
EXEC test.AssertEq N'cash entries for the sale',240000,@n;

-- Same SaleId with a different content must be rejected, not merged.
DECLARE @lines2 sales.SaleLineRequest;
INSERT INTO @lines2(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
DECLARE @tenders2 sales.SaleTenderRequest;
INSERT INTO @tenders2(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',120000,120000,0);
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines2,@Tenders=@tenders2;
  THROW 59002,'ASSERT FAIL: SaleId reused with different content was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51510 THROW; END CATCH;

-- Count 3 x 100000 + 4 x 10000 = 340000 = opening 100000 + sale 240000.
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES(@count,@till,@cashier,'draft',@cashier);
INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity) VALUES(@count,100000,3),(@count,10000,4);
EXEC sales.usp_SubmitCashCount @CashCountId=@count,@ActorId=@cashier;
EXEC sales.usp_CloseTill @ClosureId=@close,@TillId=@till,@CashCountId=@count,@ActorId=@supervisor,@OriginNodeId=@node;
EXEC sales.usp_CloseTill @ClosureId=@close,@TillId=@till,@CashCountId=@count,@ActorId=@supervisor,@OriginNodeId=@node;

SET @n=(SELECT COUNT(*) FROM sales.CashClosures WHERE TillId=@till AND ExpectedMinor=340000 AND CountedMinor=340000 AND DifferenceMinor=0);
EXEC test.AssertEq N'closure with expected 340000 and no difference',1,@n;
SET @n=(SELECT COUNT(*) FROM accounting.CloseDocuments d WHERE d.ClosureId=@close AND d.SaleGrossMinor=240000 AND d.SaleCount=1);
EXEC test.AssertEq N'accounting close documents',1,@n;
SET @n=(SELECT COUNT(*) FROM accounting.ExportJobs e JOIN accounting.CloseDocuments d ON d.Id=e.CloseDocumentId WHERE d.ClosureId=@close);
EXEC test.AssertEq N'accountant export jobs',1,@n;

-- A sale on a closed till must be rejected.
DECLARE @sale2 uniqueidentifier=NEWID();
BEGIN TRY
  EXEC sales.usp_PostSale @SaleId=@sale2,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
       @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines2,@Tenders=@tenders2;
  THROW 59002,'ASSERT FAIL: sale on a closed till was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51515 THROW; END CATCH;
PRINT 'PASS';
