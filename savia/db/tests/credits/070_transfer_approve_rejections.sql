-- TEST: an approval requires an existing requested transfer, an approver who is not the requester and holds CanApproveTransfers in the origin branch; approving twice is rejected.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @flag bigint; DECLARE @tmp uniqueidentifier=NEWID();
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@branchB uniqueidentifier=test.Id('branchB'),
  @locA uniqueidentifier=test.Id('locA'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@cashierB uniqueidentifier=test.Id('cashierB'),
  @supervisorB uniqueidentifier=test.Id('supervisorB'),
  @registerA uniqueidentifier=test.Id('registerA'),
  @manager uniqueidentifier=test.Id('manager'),@customer uniqueidentifier=test.Id('customer'),
  @item uniqueidentifier=test.Id('item'),@nodeA uniqueidentifier=test.Id('nodeA'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@rev uniqueidentifier=NEWID(),
  @credit uniqueidentifier=NEWID(),@t1 uniqueidentifier=NEWID(),@t2 uniqueidentifier=NEWID(),
  @requestEvent uniqueidentifier=NEWID(),@approveEvent uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),
  @n bigint,@lineId uniqueidentifier,@status varchar(20);

EXEC test.SeedStock @item,@locA,5;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@registerA,@CashierId=@cashierA,
     @CurrencyCode='NIO',@OpeningMinor=100000,@OriginNodeId=@nodeA;
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',120000,120000,0);
EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branchA,@LocationId=@locA,@CashierId=@cashierA,
     @CurrencyCode='NIO',@CustomerId=@customer,@TillId=@till,@OriginNodeId=@nodeA,@Lines=@lines,@Tenders=@tenders;
SET @lineId=(SELECT Id FROM sales.SaleLines WHERE SaleId=@sale AND LineNumber=1);
DECLARE @ret sales.ReturnLineRequest;
INSERT INTO @ret(SaleLineId,Quantity,RestockPool) VALUES(@lineId,1,'quarantine');
EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@sale,@BranchId=@branchA,
     @ReturnLocationId=@locA,@TillId=@till,@ActorId=@cashierA,@ApprovedBy=@manager,@CustomerId=@customer,
     @Reason=N'Talla equivocada',@OriginNodeId=@nodeA,@Lines=@ret;

-- Unknown transfer.
BEGIN TRY
  EXEC credits.usp_ApproveTransfer @TransferId=@tmp,@ApproverId=@manager,
       @OriginNodeId=@nodeA,@EventId=@e2;
  THROW 59002,'ASSERT FAIL: approval of an unknown transfer was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51612 THROW; END CATCH;

EXEC credits.usp_RequestTransfer @TransferId=@t1,@CreditId=@credit,
  @FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,
  @RequestedBy=@cashierA,@Reason=N'Canje en otra sucursal',@OriginNodeId=@nodeA,@EventId=@requestEvent;

-- The requester cannot approve his own request.
BEGIN TRY
  EXEC credits.usp_ApproveTransfer @TransferId=@t1,@ApproverId=@cashierA,
       @OriginNodeId=@nodeA,@EventId=@e2;
  THROW 59002,'ASSERT FAIL: self-approval was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51612 THROW; END CATCH;

-- An approver without CanApproveTransfers in the origin branch (cashier B has no access to A).
BEGIN TRY
  EXEC credits.usp_ApproveTransfer @TransferId=@t1,@ApproverId=@cashierB,
       @OriginNodeId=@nodeA,@EventId=@e2;
  THROW 59002,'ASSERT FAIL: approval by staff without permission was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51613 THROW; END CATCH;

-- A supervisor of another branch (B) also has no rights in the origin A.
BEGIN TRY
  EXEC credits.usp_ApproveTransfer @TransferId=@t1,@ApproverId=@supervisorB,
       @OriginNodeId=@nodeA,@EventId=@e2;
  THROW 59002,'ASSERT FAIL: approval by another branch supervisor was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51613 THROW; END CATCH;

-- Normal approval by the manager: status approved and recorded.
EXEC credits.usp_ApproveTransfer @TransferId=@t1,@ApproverId=@manager,
  @OriginNodeId=@nodeA,@EventId=@approveEvent;
SET @status=(SELECT Status FROM credits.CreditTransfers WHERE Id=@t1);
SET @flag=CASE WHEN @status='approved' THEN 1 ELSE 0 END;
EXEC test.AssertEq N'transfer approved',1,@flag;
SET @n=(SELECT COUNT(*) FROM credits.CreditTransfers WHERE Id=@t1 AND ApprovedBy=@manager);
EXEC test.AssertEq N'approver recorded',1,@n;

-- Approving twice is rejected: the status is no longer requested.
BEGIN TRY
  EXEC credits.usp_ApproveTransfer @TransferId=@t1,@ApproverId=@manager,
       @OriginNodeId=@nodeA,@EventId=@e2;
  THROW 59002,'ASSERT FAIL: double approval was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51612 THROW; END CATCH;

-- Approval moves no money.
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'available unchanged by approval',120000,@n;
SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'credit conservation after approval',0,@n;
PRINT 'PASS';
