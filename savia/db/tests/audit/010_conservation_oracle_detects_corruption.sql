-- TEST: the conservation oracle returns zero rows after real operations and reports each kind of corruption introduced by hand.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@supervisor uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@register uniqueidentifier=test.Id('registerA'),
  @item uniqueidentifier=test.Id('item'),@customer uniqueidentifier=test.Id('customer'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@count uniqueidentifier=NEWID(),
  @return uniqueidentifier=NEWID(),@credit uniqueidentifier=NEWID(),@n bigint;
DECLARE @found TABLE(CheckName varchar(60),KeyText nvarchar(200),Expected bigint,Actual bigint);

-- Real operations: receive 5, sell 2 to a customer, return 1 for credit.
EXEC test.SeedStock @item,@loc,5;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,@CurrencyCode='NIO',@OpeningMinor=50000,@OriginNodeId=@node;
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest,@ret sales.ReturnLineRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,2,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',240000,240000,0);
EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,@CurrencyCode='NIO',
     @CustomerId=@customer,@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders;
INSERT INTO @ret(SaleLineId,Quantity,RestockPool) SELECT Id,1,'quarantine' FROM sales.SaleLines WHERE SaleId=@sale;
EXEC sales.usp_PostCreditReturn @ReversalId=@return,@CreditId=@credit,@SaleId=@sale,@BranchId=@branch,
     @ReturnLocationId=@loc,@TillId=@till,@ActorId=@cashier,@ApprovedBy=@supervisor,@CustomerId=@customer,
     @Reason=N'Talla',@OriginNodeId=@node,@Lines=@ret;

-- Clean books: zero rows, and @Throw=1 does not throw.
INSERT INTO @found EXEC audit.usp_CheckConservation;
SET @n=(SELECT COUNT(*) FROM @found);
EXEC test.AssertEq N'violations on clean books',0,@n;
EXEC audit.usp_CheckConservation @Throw=1;

-- Corruption 1: a balance changed without a movement.
UPDATE inventory.StockBalances SET OnHand=OnHand+1 WHERE ItemId=@item AND LocationId=@loc AND Pool='store';
DELETE FROM @found; INSERT INTO @found EXEC audit.usp_CheckConservation;
SET @n=(SELECT COUNT(*) FROM @found WHERE CheckName='stock.onhand_vs_movements' AND Expected=3 AND Actual=4);
EXEC test.AssertEq N'detects a balance without a movement',1,@n;
UPDATE inventory.StockBalances SET OnHand=OnHand-1 WHERE ItemId=@item AND LocationId=@loc AND Pool='store';

-- Corruption 2: cash moved without a tender.
UPDATE sales.CashEntries SET DeltaMinor=DeltaMinor-1000 WHERE Kind='sale' AND TillId=@till;
DELETE FROM @found; INSERT INTO @found EXEC audit.usp_CheckConservation;
SET @n=(SELECT COUNT(*) FROM @found WHERE CheckName='sale.cash_tender_vs_cash_entry' AND Expected=240000 AND Actual=239000);
EXEC test.AssertEq N'detects cash that does not match its tender',1,@n;
UPDATE sales.CashEntries SET DeltaMinor=DeltaMinor+1000 WHERE Kind='sale' AND TillId=@till;

-- Corruption 3: credit created from nothing.
UPDATE credits.CreditAllocations SET AvailableMinor=AvailableMinor+500 WHERE CreditId=@credit;
DELETE FROM @found; INSERT INTO @found EXEC audit.usp_CheckConservation;
SET @n=(SELECT COUNT(*) FROM @found WHERE CheckName IN ('credit.conservation','credit.available_vs_movements'));
EXEC test.AssertEq N'detects credit created from nothing (two checks)',2,@n;
BEGIN TRY
  EXEC audit.usp_CheckConservation @Throw=1;
  THROW 59002,'ASSERT FAIL: the oracle did not throw on corrupted books',1;
END TRY BEGIN CATCH IF ERROR_NUMBER()<>59100 THROW; END CATCH;
UPDATE credits.CreditAllocations SET AvailableMinor=AvailableMinor-500 WHERE CreditId=@credit;

-- Corruption 4: the sale event that the cloud must receive has disappeared.
-- (Changing a line total by hand is not even possible: CK_SaleLines_Total rejects it.)
DELETE FROM sync.EventDeliveries WHERE EventId IN (SELECT EventId FROM sync.Outbox WHERE AggregateId=@sale);
DELETE FROM sync.Outbox WHERE AggregateId=@sale;
DELETE FROM @found; INSERT INTO @found EXEC audit.usp_CheckConservation;
SET @n=(SELECT COUNT(*) FROM @found WHERE CheckName='sale.outbox_event' AND Expected=1 AND Actual=0);
EXEC test.AssertEq N'detects a sale without its sync event',1,@n;

-- Close the till and check the closure rules too.
DECLARE @json nvarchar(max)=N'[{"denominationMinor":10000,"quantity":29}]',@close uniqueidentifier=NEWID();
EXEC sales.usp_RecordCashCount @CashCountId=@count,@TillId=@till,@ActorId=@cashier,@LinesJson=@json;
EXEC sales.usp_CloseTill @ClosureId=@close,@TillId=@till,@CashCountId=@count,@ActorId=@supervisor,@OriginNodeId=@node;
-- CK_CashClosures_Amounts keeps difference = counted - expected, so the forgery must move both columns.
UPDATE sales.CashClosures SET ExpectedMinor=ExpectedMinor+1,DifferenceMinor=DifferenceMinor-1 WHERE Id=@close;
DELETE FROM @found; INSERT INTO @found EXEC audit.usp_CheckConservation;
SET @n=(SELECT COUNT(*) FROM @found WHERE CheckName='cash.closure_expected_vs_entries');
EXEC test.AssertEq N'detects a closure that does not match its entries',1,@n;
PRINT 'PASS';
