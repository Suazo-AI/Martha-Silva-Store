-- TEST: transfer order is strict: locking before approval, committing before lock and accepting before commit are rejected; a locked transfer cannot be cancelled.
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
  @credit uniqueidentifier=NEWID(),@t1 uniqueidentifier=NEWID(),@t2 uniqueidentifier=NEWID(),
  @requestEvent uniqueidentifier=NEWID(),@approveEvent uniqueidentifier=NEWID(),
  @lockEvent uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),
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

EXEC credits.usp_RequestTransfer @TransferId=@t1,@CreditId=@credit,
  @FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,
  @RequestedBy=@cashierA,@Reason=N'Canje en otra sucursal',@OriginNodeId=@nodeA,@EventId=@requestEvent;

-- Lock before approval.
BEGIN TRY
  EXEC credits.usp_LockTransferAtOrigin @TransferId=@t1,
       @OriginLockEventId=@lockEvent,@OriginNodeId=@nodeA,@ActorId=@cashierA;
  THROW 59002,'ASSERT FAIL: lock before approval was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51615 THROW; END CATCH;

-- Commit before lock.
BEGIN TRY
  EXEC credits.usp_CommitTransfer @TransferId=@t1,@ActorId=@manager,
       @OriginNodeId=@nodeCloud,@EventId=@e2;
  THROW 59002,'ASSERT FAIL: commit before lock was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51618 THROW; END CATCH;

-- Accept before commit.
BEGIN TRY
  EXEC credits.usp_AcceptTransfer @TransferId=@t1,@ActorId=@manager,
       @OriginNodeId=@nodeB,@EventId=@e2;
  THROW 59002,'ASSERT FAIL: accept before commit was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51621 THROW; END CATCH;

EXEC credits.usp_ApproveTransfer @TransferId=@t1,@ApproverId=@manager,
  @OriginNodeId=@nodeA,@EventId=@approveEvent;
EXEC credits.usp_LockTransferAtOrigin @TransferId=@t1,
  @OriginLockEventId=@lockEvent,@OriginNodeId=@nodeA,@ActorId=@cashierA;

-- Cancel after the lock is rejected.
BEGIN TRY
  EXEC credits.usp_CancelUnblockedTransfer @TransferId=@t1,@ActorId=@manager;
  THROW 59002,'ASSERT FAIL: cancel after lock was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51623 THROW; END CATCH;
SET @status=(SELECT Status FROM credits.CreditTransfers WHERE Id=@t1);
SET @flag=CASE WHEN @status='origin_locked' THEN 1 ELSE 0 END;
EXEC test.AssertEq N'locked transfer not cancelled',1,@flag;

-- The held amount survives the rejected cancel.
SET @n=(SELECT HeldMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'held intact after rejected cancel',50000,@n;
SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'credit conservation after order violations',0,@n;
PRINT 'PASS';
