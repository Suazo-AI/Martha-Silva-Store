-- TEST: a requested or approved transfer can be cancelled; an unknown transfer cannot; a cancelled transfer cannot be locked.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @flag bigint; DECLARE @tmp uniqueidentifier=NEWID();
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@branchB uniqueidentifier=test.Id('branchB'),
  @locA uniqueidentifier=test.Id('locA'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@registerA uniqueidentifier=test.Id('registerA'),
  @manager uniqueidentifier=test.Id('manager'),@customer uniqueidentifier=test.Id('customer'),
  @item uniqueidentifier=test.Id('item'),@nodeA uniqueidentifier=test.Id('nodeA'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@rev uniqueidentifier=NEWID(),
  @credit uniqueidentifier=NEWID(),@t1 uniqueidentifier=NEWID(),@t2 uniqueidentifier=NEWID(),@t3 uniqueidentifier=NEWID(),
  @requestEvent1 uniqueidentifier=NEWID(),@requestEvent2 uniqueidentifier=NEWID(),@requestEvent3 uniqueidentifier=NEWID(),
  @approveEvent2 uniqueidentifier=NEWID(),@lockEvent3 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),
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
  EXEC credits.usp_CancelUnblockedTransfer @TransferId=@tmp,@ActorId=@manager;
  THROW 59002,'ASSERT FAIL: cancel of an unknown transfer was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51623 THROW; END CATCH;

-- Cancel a merely requested transfer.
EXEC credits.usp_RequestTransfer @TransferId=@t1,@CreditId=@credit,
  @FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=10000,
  @RequestedBy=@cashierA,@Reason=N'Ya no hace falta',@OriginNodeId=@nodeA,@EventId=@requestEvent1;
EXEC credits.usp_CancelUnblockedTransfer @TransferId=@t1,@ActorId=@manager;
SET @status=(SELECT Status FROM credits.CreditTransfers WHERE Id=@t1);
SET @flag=CASE WHEN @status='cancelled' THEN 1 ELSE 0 END;
EXEC test.AssertEq N'requested transfer cancelled',1,@flag;

-- Cancel an approved (but not locked) transfer.
EXEC credits.usp_RequestTransfer @TransferId=@t2,@CreditId=@credit,
  @FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=10000,
  @RequestedBy=@cashierA,@Reason=N'Cancelada tras aprobar',@OriginNodeId=@nodeA,@EventId=@requestEvent2;
EXEC credits.usp_ApproveTransfer @TransferId=@t2,@ApproverId=@manager,
  @OriginNodeId=@nodeA,@EventId=@approveEvent2;
EXEC credits.usp_CancelUnblockedTransfer @TransferId=@t2,@ActorId=@manager;
SET @status=(SELECT Status FROM credits.CreditTransfers WHERE Id=@t2);
SET @flag=CASE WHEN @status='cancelled' THEN 1 ELSE 0 END;
EXEC test.AssertEq N'approved transfer cancelled',1,@flag;

-- Cancelling twice is rejected.
BEGIN TRY
  EXEC credits.usp_CancelUnblockedTransfer @TransferId=@t2,@ActorId=@manager;
  THROW 59002,'ASSERT FAIL: double cancel was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51623 THROW; END CATCH;

-- A cancelled transfer cannot be locked.
EXEC credits.usp_RequestTransfer @TransferId=@t3,@CreditId=@credit,
  @FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=10000,
  @RequestedBy=@cashierA,@Reason=N'Cancelar y bloquear',@OriginNodeId=@nodeA,@EventId=@requestEvent3;
EXEC credits.usp_CancelUnblockedTransfer @TransferId=@t3,@ActorId=@manager;
BEGIN TRY
  EXEC credits.usp_LockTransferAtOrigin @TransferId=@t3,
       @OriginLockEventId=@lockEvent3,@OriginNodeId=@nodeA,@ActorId=@cashierA;
  THROW 59002,'ASSERT FAIL: lock of a cancelled transfer was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51615 THROW; END CATCH;

-- No money ever moved in this test.
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'available untouched by cancels',120000,@n;
SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'credit conservation after cancels',0,@n;
PRINT 'PASS';
