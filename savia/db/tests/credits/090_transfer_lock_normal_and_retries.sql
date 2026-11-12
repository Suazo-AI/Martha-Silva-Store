-- TEST: locking at origin moves available to held exactly once; a retry with the same lock event changes nothing, another event id is rejected, a lock without enough balance is rejected and the origin node must be the branch node.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @flag bigint; DECLARE @tmp uniqueidentifier=NEWID();
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@branchB uniqueidentifier=test.Id('branchB'),
  @locA uniqueidentifier=test.Id('locA'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@registerA uniqueidentifier=test.Id('registerA'),
  @manager uniqueidentifier=test.Id('manager'),@customer uniqueidentifier=test.Id('customer'),
  @item uniqueidentifier=test.Id('item'),
  @nodeA uniqueidentifier=test.Id('nodeA'),@nodeB uniqueidentifier=test.Id('nodeB'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@rev uniqueidentifier=NEWID(),
  @credit uniqueidentifier=NEWID(),@t1 uniqueidentifier=NEWID(),@t2 uniqueidentifier=NEWID(),
  @requestEvent uniqueidentifier=NEWID(),@approveEvent uniqueidentifier=NEWID(),
  @lockEvent uniqueidentifier=NEWID(),@wrongNodeEvent uniqueidentifier=NEWID(),
  @t2RequestEvent uniqueidentifier=NEWID(),@t2ApproveEvent uniqueidentifier=NEWID(),
  @n bigint,@lineId uniqueidentifier;

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

-- Lock from a node that is not the origin branch node.
EXEC credits.usp_RequestTransfer @TransferId=@t1,@CreditId=@credit,
  @FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,
  @RequestedBy=@cashierA,@Reason=N'Canje en otra sucursal',@OriginNodeId=@nodeA,@EventId=@requestEvent;
EXEC credits.usp_ApproveTransfer @TransferId=@t1,@ApproverId=@manager,
  @OriginNodeId=@nodeA,@EventId=@approveEvent;
BEGIN TRY
  EXEC credits.usp_LockTransferAtOrigin @TransferId=@t1,
       @OriginLockEventId=@wrongNodeEvent,@OriginNodeId=@nodeB,@ActorId=@cashierA;
  THROW 59002,'ASSERT FAIL: lock from a foreign node was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51616 THROW; END CATCH;

-- A second transfer approved for more than the balance: lock must be rejected.
EXEC credits.usp_RequestTransfer @TransferId=@t2,@CreditId=@credit,
  @FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=200000,
  @RequestedBy=@cashierA,@Reason=N'mas de lo que hay',@OriginNodeId=@nodeA,@EventId=@t2RequestEvent;
EXEC credits.usp_ApproveTransfer @TransferId=@t2,@ApproverId=@manager,
  @OriginNodeId=@nodeA,@EventId=@t2ApproveEvent;
BEGIN TRY
  EXEC credits.usp_LockTransferAtOrigin @TransferId=@t2,
       @OriginLockEventId=@tmp,@OriginNodeId=@nodeA,@ActorId=@cashierA;
  THROW 59002,'ASSERT FAIL: lock above the balance was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51617 THROW; END CATCH;

-- Normal lock of 50000 with proof event.
EXEC credits.usp_LockTransferAtOrigin @TransferId=@t1,
  @OriginLockEventId=@lockEvent,@OriginNodeId=@nodeA,@ActorId=@cashierA;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'available after lock',70000,@n;
SET @n=(SELECT HeldMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'held after lock',50000,@n;
SET @n=(SELECT COUNT(*) FROM credits.CreditMovements WHERE CreditId=@credit AND Kind='hold' AND AvailableDeltaMinor=-50000 AND HeldDeltaMinor=50000);
EXEC test.AssertEq N'hold movement recorded once',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventId=@lockEvent AND EventType='credits.origin_locked');
EXEC test.AssertEq N'lock event in outbox',1,@n;

-- Retry with the same lock event: nothing changes.
EXEC credits.usp_LockTransferAtOrigin @TransferId=@t1,
  @OriginLockEventId=@lockEvent,@OriginNodeId=@nodeA,@ActorId=@cashierA;
SET @n=(SELECT COUNT(*) FROM credits.CreditMovements WHERE CreditId=@credit AND Kind='hold');
EXEC test.AssertEq N'no duplicate hold movement after retry',1,@n;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'available unchanged after retry',70000,@n;

-- Retry with a different event id on an already locked transfer.
BEGIN TRY
  EXEC credits.usp_LockTransferAtOrigin @TransferId=@t1,
       @OriginLockEventId=@wrongNodeEvent,@OriginNodeId=@nodeA,@ActorId=@cashierA;
  THROW 59002,'ASSERT FAIL: second lock with another event id was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51614 THROW; END CATCH;

SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'credit conservation after locks',0,@n;
PRINT 'PASS';
