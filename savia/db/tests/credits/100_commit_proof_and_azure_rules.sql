-- TEST: commit needs proof that the origin lock reached Azure (inbox applied or outbox acked); commit must come from the Azure node with an EventId; retry changes nothing.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @flag bigint; DECLARE @tmp uniqueidentifier=NEWID();
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@branchB uniqueidentifier=test.Id('branchB'),
  @locA uniqueidentifier=test.Id('locA'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@registerA uniqueidentifier=test.Id('registerA'),
  @manager uniqueidentifier=test.Id('manager'),@customer uniqueidentifier=test.Id('customer'),
  @item uniqueidentifier=test.Id('item'),
  @nodeA uniqueidentifier=test.Id('nodeA'),@nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@rev uniqueidentifier=NEWID(),
  @credit uniqueidentifier=NEWID(),@t1 uniqueidentifier=NEWID(),@t2 uniqueidentifier=NEWID(),
  @requestEvent1 uniqueidentifier=NEWID(),@approveEvent1 uniqueidentifier=NEWID(),
  @requestEvent2 uniqueidentifier=NEWID(),@approveEvent2 uniqueidentifier=NEWID(),
  @lockEvent1 uniqueidentifier=NEWID(),@lockEvent2 uniqueidentifier=NEWID(),
  @commitEvent1 uniqueidentifier=NEWID(),@commitEvent2 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),
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

EXEC credits.usp_RequestTransfer @TransferId=@t1,@CreditId=@credit,
  @FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,
  @RequestedBy=@cashierA,@Reason=N'Canje en otra sucursal',@OriginNodeId=@nodeA,@EventId=@requestEvent1;
EXEC credits.usp_ApproveTransfer @TransferId=@t1,@ApproverId=@manager,
  @OriginNodeId=@nodeA,@EventId=@approveEvent1;
EXEC credits.usp_LockTransferAtOrigin @TransferId=@t1,
  @OriginLockEventId=@lockEvent1,@OriginNodeId=@nodeA,@ActorId=@cashierA;

-- Commit without any proof that Azure applied the lock.
BEGIN TRY
  EXEC credits.usp_CommitTransfer @TransferId=@t1,@ActorId=@manager,
       @OriginNodeId=@nodeCloud,@EventId=@e2;
  THROW 59002,'ASSERT FAIL: commit without lock proof was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51619 THROW; END CATCH;
SET @n=(SELECT HeldMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'hold intact after rejected commit',50000,@n;

-- Proof path 1: Azure applied the lock event (recorded in the inbox).
BEGIN TRANSACTION;
SET @lockPayload=(SELECT PayloadJson FROM sync.Outbox WHERE EventId=@lockEvent1);
EXEC sync.usp_RecordAppliedInbox @EventId=@lockEvent1,@OriginNodeId=@nodeA,
  @AggregateType='credit_transfer',@AggregateId=@t1,@PayloadJson=@lockPayload;
COMMIT;

-- Commit must be emitted from the Azure node.
BEGIN TRY
  EXEC credits.usp_CommitTransfer @TransferId=@t1,@ActorId=@manager,
       @OriginNodeId=@nodeA,@EventId=@e2;
  THROW 59002,'ASSERT FAIL: commit from a branch node was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51626 THROW; END CATCH;
SET @n=(SELECT HeldMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'hold intact after rejected non-azure commit',50000,@n;

-- Commit from Azure needs an EventId.
BEGIN TRY
  EXEC credits.usp_CommitTransfer @TransferId=@t1,@ActorId=@manager,
       @OriginNodeId=@nodeCloud,@EventId=NULL;
  THROW 59002,'ASSERT FAIL: commit without EventId was accepted',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51627 THROW; END CATCH;

-- Normal commit from Azure: A loses the hold, B holds it in transit.
EXEC credits.usp_CommitTransfer @TransferId=@t1,@ActorId=@manager,
  @OriginNodeId=@nodeCloud,@EventId=@commitEvent1;
SET @n=(SELECT HeldMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA);
EXEC test.AssertEq N'origin hold released at commit',0,@n;
SET @n=(SELECT HeldMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchB);
EXEC test.AssertEq N'destination hold at commit',50000,@n;
SET @status=(SELECT Status FROM credits.CreditTransfers WHERE Id=@t1);
SET @flag=CASE WHEN @status='in_transit' THEN 1 ELSE 0 END;
EXEC test.AssertEq N'transfer in transit',1,@flag;
SET @n=(SELECT COUNT(*) FROM sync.EventDeliveries WHERE EventId=@commitEvent1);
EXEC test.AssertEq N'commit event routed to both branches',2,@n;

-- Retry of the same commit: nothing changes.
EXEC credits.usp_CommitTransfer @TransferId=@t1,@ActorId=@manager,
  @OriginNodeId=@nodeCloud,@EventId=@e2;
SET @n=(SELECT COUNT(*) FROM credits.CreditMovements WHERE CreditId=@credit AND Kind='transfer_in');
EXEC test.AssertEq N'no duplicate transfer movements after retry',1,@n;

-- Proof path 2: the origin branch outbox shows the lock event acked by Azure.
EXEC credits.usp_RequestTransfer @TransferId=@t2,@CreditId=@credit,
  @FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=20000,
  @RequestedBy=@cashierA,@Reason=N'Segundo envio',@OriginNodeId=@nodeA,@EventId=@requestEvent2;
EXEC credits.usp_ApproveTransfer @TransferId=@t2,@ApproverId=@manager,
  @OriginNodeId=@nodeA,@EventId=@approveEvent2;
EXEC credits.usp_LockTransferAtOrigin @TransferId=@t2,
  @OriginLockEventId=@lockEvent2,@OriginNodeId=@nodeA,@ActorId=@cashierA;
EXEC sync.usp_AcknowledgeDelivery @EventId=@lockEvent2,@DestinationNodeId=@nodeCloud;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventId=@lockEvent2 AND Status='acked');
EXEC test.AssertEq N'lock event acked in outbox',1,@n;
EXEC credits.usp_CommitTransfer @TransferId=@t2,@ActorId=@manager,
  @OriginNodeId=@nodeCloud,@EventId=@commitEvent2;
SET @status=(SELECT Status FROM credits.CreditTransfers WHERE Id=@t2);
SET @flag=CASE WHEN @status='in_transit' THEN 1 ELSE 0 END;
EXEC test.AssertEq N'second transfer in transit via outbox proof',1,@flag;

SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'credit conservation after commits',0,@n;
PRINT 'PASS';
