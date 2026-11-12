-- TEST: the full transfer A->B keeps credit conservation at every step and installs exactly 50000 in B; accepting twice changes nothing.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @flag bigint; DECLARE @tmp uniqueidentifier=NEWID();
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@branchB uniqueidentifier=test.Id('branchB'),
  @locA uniqueidentifier=test.Id('locA'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@registerA uniqueidentifier=test.Id('registerA'),
  @manager uniqueidentifier=test.Id('manager'),@customer uniqueidentifier=test.Id('customer'),
  @item uniqueidentifier=test.Id('item'),
  @nodeA uniqueidentifier=test.Id('nodeA'),@nodeB uniqueidentifier=test.Id('nodeB'),
  @nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@rev uniqueidentifier=NEWID(),
  @credit uniqueidentifier=NEWID(),@transfer uniqueidentifier=NEWID(),
  @requestEvent uniqueidentifier=NEWID(),@approveEvent uniqueidentifier=NEWID(),
  @lockEvent uniqueidentifier=NEWID(),@commitEvent uniqueidentifier=NEWID(),
  @acceptEvent uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),
  @n bigint,@lineId uniqueidentifier,@lockPayload nvarchar(max),@status varchar(20);

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
SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'conservation after issue',0,@n;

EXEC credits.usp_RequestTransfer @TransferId=@transfer,@CreditId=@credit,
  @FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,
  @RequestedBy=@cashierA,@Reason=N'Canje en otra sucursal',@OriginNodeId=@nodeA,@EventId=@requestEvent;
SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'conservation after request',0,@n;

EXEC credits.usp_ApproveTransfer @TransferId=@transfer,@ApproverId=@manager,
  @OriginNodeId=@nodeA,@EventId=@approveEvent;
SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'conservation after approval',0,@n;

EXEC credits.usp_LockTransferAtOrigin @TransferId=@transfer,
  @OriginLockEventId=@lockEvent,@OriginNodeId=@nodeA,@ActorId=@cashierA;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'A available 70000 after lock',70000,@n;
SET @n=(SELECT HeldMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'A held 50000 after lock',50000,@n;
SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'conservation after lock',0,@n;

BEGIN TRANSACTION;
SET @lockPayload=(SELECT PayloadJson FROM sync.Outbox WHERE EventId=@lockEvent);
EXEC sync.usp_RecordAppliedInbox @EventId=@lockEvent,@OriginNodeId=@nodeA,
  @AggregateType='credit_transfer',@AggregateId=@transfer,@PayloadJson=@lockPayload;
COMMIT;

EXEC credits.usp_CommitTransfer @TransferId=@transfer,@ActorId=@manager,
  @OriginNodeId=@nodeCloud,@EventId=@commitEvent;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'A available 70000 after commit',70000,@n;
SET @n=(SELECT HeldMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'A held 0 after commit',0,@n;
SET @n=(SELECT HeldMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchB);
EXEC test.AssertEq N'B held 50000 after commit',50000,@n;
SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'conservation after commit',0,@n;

-- Accept from the wrong node is rejected.
BEGIN TRY
  EXEC credits.usp_AcceptTransfer @TransferId=@transfer,@ActorId=@manager,
       @OriginNodeId=@nodeA,@EventId=@acceptEvent;
  THROW 59002,'ASSERT FAIL: accept from a non-destination node was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51629 THROW; END CATCH;

-- Accept from Azure without EventId is rejected.
BEGIN TRY
  EXEC credits.usp_AcceptTransfer @TransferId=@transfer,@ActorId=@manager,
       @OriginNodeId=@nodeB,@EventId=NULL;
  THROW 59002,'ASSERT FAIL: accept without EventId was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51630 THROW; END CATCH;

-- Normal accept at the destination branch.
EXEC credits.usp_AcceptTransfer @TransferId=@transfer,@ActorId=@manager,
  @OriginNodeId=@nodeB,@EventId=@acceptEvent;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchB);
EXEC test.AssertEq N'B available 50000 after accept',50000,@n;
SET @n=(SELECT HeldMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchB);
EXEC test.AssertEq N'B held 0 after accept',0,@n;
SET @n=(SELECT COUNT(*) FROM credits.CreditMovements WHERE CreditId=@credit AND Kind='accept' AND AvailableDeltaMinor=50000 AND HeldDeltaMinor=-50000);
EXEC test.AssertEq N'accept movement recorded once',1,@n;
SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'conservation after accept',0,@n;

-- Retry of the accept (lost reply): nothing changes.
EXEC credits.usp_AcceptTransfer @TransferId=@transfer,@ActorId=@manager,
  @OriginNodeId=@nodeB,@EventId=@e2;
SET @n=(SELECT COUNT(*) FROM credits.CreditMovements WHERE CreditId=@credit AND Kind='accept');
EXEC test.AssertEq N'no duplicate accept movement after retry',1,@n;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchB);
EXEC test.AssertEq N'B available unchanged after retry',50000,@n;
SET @status=(SELECT Status FROM credits.CreditTransfers WHERE Id=@transfer);
SET @flag=CASE WHEN @status='accepted' THEN 1 ELSE 0 END;
EXEC test.AssertEq N'transfer accepted',1,@flag;
PRINT 'PASS';
