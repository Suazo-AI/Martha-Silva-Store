-- TEST: usp_IssueFromReturn rejects a reversal that is not an approved credit settlement, an unknown reversal, or one whose lines do not sum to the approved value.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @flag bigint; DECLARE @tmp uniqueidentifier=NEWID();
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@locA uniqueidentifier=test.Id('locA'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@registerA uniqueidentifier=test.Id('registerA'),
  @manager uniqueidentifier=test.Id('manager'),@customer uniqueidentifier=test.Id('customer'),
  @item uniqueidentifier=test.Id('item'),@nodeA uniqueidentifier=test.Id('nodeA'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@rev uniqueidentifier=NEWID(),
  @rev2 uniqueidentifier=NEWID(),@rev3 uniqueidentifier=NEWID(),@rev4 uniqueidentifier=NEWID(),
  @credit uniqueidentifier=NEWID(),@n bigint,@lineId uniqueidentifier;

EXEC test.SeedStock @item,@locA,5;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@registerA,@CashierId=@cashierA,
     @CurrencyCode='NIO',@OpeningMinor=100000,@OriginNodeId=@nodeA;
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',120000,120000,0);
EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branchA,@LocationId=@locA,@CashierId=@cashierA,
     @CurrencyCode='NIO',@CustomerId=@customer,@TillId=@till,@OriginNodeId=@nodeA,@Lines=@lines,@Tenders=@tenders;
SET @lineId=(SELECT Id FROM sales.SaleLines WHERE SaleId=@sale AND LineNumber=1);

-- Reversal that does not exist at all.
BEGIN TRY
  EXEC credits.usp_IssueFromReturn @CreditId=@tmp,@ReversalId=@rev,@ActorId=@manager;
  THROW 59002,'ASSERT FAIL: unknown reversal was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51602 THROW; END CATCH;

-- Approved reversal but settled in cash, not credit.
INSERT INTO sales.SaleReversals(Id,SaleId,BranchId,LocationId,TillId,ActorId,Kind,SettlementKind,
    Reason,CreditMinor,CurrencyCode,Status,ApprovedBy,CreatedBy)
  VALUES(@rev2,@sale,@branchA,@locA,@till,@cashierA,'return','cash',N'cash refund',120000,'NIO','approved',@manager,@cashierA);
INSERT INTO sales.SaleReversalLines(ReversalId,SaleLineId,Quantity,CreditMinor,RestockPool,CreatedBy)
  VALUES(@rev2,@lineId,1,120000,'quarantine',@cashierA);
BEGIN TRY
  EXEC credits.usp_IssueFromReturn @CreditId=@tmp,@ReversalId=@rev2,@ActorId=@manager;
  THROW 59002,'ASSERT FAIL: cash settlement reversal was accepted for a credit',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51602 THROW; END CATCH;

-- Draft (not approved) credit reversal.
INSERT INTO sales.SaleReversals(Id,SaleId,BranchId,LocationId,TillId,ActorId,Kind,SettlementKind,
    Reason,CreditMinor,CurrencyCode,Status,ApprovedBy,CreatedBy)
  VALUES(@rev3,@sale,@branchA,@locA,@till,@cashierA,'return','credit',N'pendiente',120000,'NIO','pending',@manager,@cashierA);
INSERT INTO sales.SaleReversalLines(ReversalId,SaleLineId,Quantity,CreditMinor,RestockPool,CreatedBy)
  VALUES(@rev3,@lineId,1,120000,'quarantine',@cashierA);
BEGIN TRY
  EXEC credits.usp_IssueFromReturn @CreditId=@tmp,@ReversalId=@rev3,@ActorId=@manager;
  THROW 59002,'ASSERT FAIL: unapproved reversal was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51602 THROW; END CATCH;

-- Approved credit reversal whose lines do not sum to the approved value.
INSERT INTO sales.SaleReversals(Id,SaleId,BranchId,LocationId,TillId,ActorId,Kind,SettlementKind,
    Reason,CreditMinor,CurrencyCode,Status,ApprovedBy,CreatedBy)
  VALUES(@rev4,@sale,@branchA,@locA,@till,@cashierA,'return','credit',N'lines mismatch',120000,'NIO','approved',@manager,@cashierA);
INSERT INTO sales.SaleReversalLines(ReversalId,SaleLineId,Quantity,CreditMinor,RestockPool,CreatedBy)
  VALUES(@rev4,@lineId,1,100000,'quarantine',@cashierA);
BEGIN TRY
  EXEC credits.usp_IssueFromReturn @CreditId=@tmp,@ReversalId=@rev4,@ActorId=@manager;
  THROW 59002,'ASSERT FAIL: reversal whose lines do not match was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51603 THROW; END CATCH;

SET @n=(SELECT COUNT(*) FROM credits.Credits);
EXEC test.AssertEq N'no credit issued from invalid reversals',0,@n;
PRINT 'PASS';
