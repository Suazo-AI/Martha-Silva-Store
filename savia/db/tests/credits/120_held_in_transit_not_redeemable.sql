-- TEST: an amount in transit is spendable nowhere: the origin keeps only its free part and the destination cannot redeem until it accepts; after accept the destination can spend it.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branchA uniqueidentifier=test.Id('branchA'),@branchB uniqueidentifier=test.Id('branchB'),
  @locA uniqueidentifier=test.Id('locA'),@locB uniqueidentifier=test.Id('locB'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@cashierB uniqueidentifier=test.Id('cashierB'),
  @registerA uniqueidentifier=test.Id('registerA'),@registerB uniqueidentifier=test.Id('registerB'),
  @manager uniqueidentifier=test.Id('manager'),@customer uniqueidentifier=test.Id('customer'),
  @item uniqueidentifier=test.Id('item'),
  @nodeA uniqueidentifier=test.Id('nodeA'),@nodeB uniqueidentifier=test.Id('nodeB'),
  @nodeCloud uniqueidentifier=test.Id('nodeCloud'),
  @tillA uniqueidentifier=NEWID(),@tillB uniqueidentifier=NEWID(),
  @saleA uniqueidentifier=NEWID(),@saleB uniqueidentifier=NEWID(),@rev uniqueidentifier=NEWID(),
  @credit uniqueidentifier=NEWID(),@transfer uniqueidentifier=NEWID(),
  @requestEvent uniqueidentifier=NEWID(),@approveEvent uniqueidentifier=NEWID(),
  @lockEvent uniqueidentifier=NEWID(),@commitEvent uniqueidentifier=NEWID(),
  @acceptEvent uniqueidentifier=NEWID(),
  @r1 uniqueidentifier=NEWID(),@r2 uniqueidentifier=NEWID(),@r3 uniqueidentifier=NEWID(),@r4 uniqueidentifier=NEWID(),
  @n bigint,@lineIdA uniqueidentifier,@lineIdB uniqueidentifier;

EXEC test.SeedStock @item,@locA,5;
EXEC test.SeedStock @item,@locB,5;
EXEC sales.usp_OpenTill @TillId=@tillA,@RegisterId=@registerA,@CashierId=@cashierA,
     @CurrencyCode='NIO',@OpeningMinor=100000,@OriginNodeId=@nodeA;
EXEC sales.usp_OpenTill @TillId=@tillB,@RegisterId=@registerB,@CashierId=@cashierB,
     @CurrencyCode='NIO',@OpeningMinor=100000,@OriginNodeId=@nodeB;
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',120000,120000,0);
EXEC sales.usp_PostSale @SaleId=@saleA,@BranchId=@branchA,@LocationId=@locA,@CashierId=@cashierA,
     @CurrencyCode='NIO',@CustomerId=@customer,@TillId=@tillA,@OriginNodeId=@nodeA,@Lines=@lines,@Tenders=@tenders;
EXEC sales.usp_PostSale @SaleId=@saleB,@BranchId=@branchB,@LocationId=@locB,@CashierId=@cashierB,
     @CurrencyCode='NIO',@CustomerId=@customer,@TillId=@tillB,@OriginNodeId=@nodeB,@Lines=@lines,@Tenders=@tenders;
SET @lineIdA=(SELECT Id FROM sales.SaleLines WHERE SaleId=@saleA AND LineNumber=1);
SET @lineIdB=(SELECT Id FROM sales.SaleLines WHERE SaleId=@saleB AND LineNumber=1);
DECLARE @ret sales.ReturnLineRequest;
INSERT INTO @ret(SaleLineId,Quantity,RestockPool) VALUES(@lineIdA,1,'quarantine');
EXEC sales.usp_PostCreditReturn @ReversalId=@rev,@CreditId=@credit,@SaleId=@saleA,@BranchId=@branchA,
     @ReturnLocationId=@locA,@TillId=@tillA,@ActorId=@cashierA,@ApprovedBy=@manager,@CustomerId=@customer,
     @Reason=N'Talla equivocada',@OriginNodeId=@nodeA,@Lines=@ret;

EXEC credits.usp_RequestTransfer @TransferId=@transfer,@CreditId=@credit,
  @FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,
  @RequestedBy=@cashierA,@Reason=N'Canje en otra sucursal',@OriginNodeId=@nodeA,@EventId=@requestEvent;
EXEC credits.usp_ApproveTransfer @TransferId=@transfer,@ApproverId=@manager,
  @OriginNodeId=@nodeA,@EventId=@approveEvent;
EXEC credits.usp_LockTransferAtOrigin @TransferId=@transfer,
  @OriginLockEventId=@lockEvent,@OriginNodeId=@nodeA,@ActorId=@cashierA;
BEGIN TRANSACTION;
DECLARE @lockPayload nvarchar(max)=(SELECT PayloadJson FROM sync.Outbox WHERE EventId=@lockEvent);
EXEC sync.usp_RecordAppliedInbox @EventId=@lockEvent,@OriginNodeId=@nodeA,
  @AggregateType='credit_transfer',@AggregateId=@transfer,@PayloadJson=@lockPayload;
COMMIT;
EXEC credits.usp_CommitTransfer @TransferId=@transfer,@ActorId=@manager,
  @OriginNodeId=@nodeCloud,@EventId=@commitEvent;

-- In transit: the origin cannot redeem the part it no longer holds.
BEGIN TRY
  EXEC credits.usp_RedeemCredit @RedemptionId=@r1,@CreditId=@credit,@BranchId=@branchA,
       @SaleId=@saleA,@AmountMinor=80000,@ActorId=@cashierA;
  THROW 59002,'ASSERT FAIL: origin redeemed the in-transit amount',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51607 THROW; END CATCH;

-- In transit: the destination cannot redeem either (it is not its money yet).
BEGIN TRY
  EXEC credits.usp_RedeemCredit @RedemptionId=@r2,@CreditId=@credit,@BranchId=@branchB,
       @SaleId=@saleB,@AmountMinor=1000,@ActorId=@cashierB;
  THROW 59002,'ASSERT FAIL: destination redeemed an in-transit amount',1;
END TRY
BEGIN CATCH IF ERROR_NUMBER()<>51607 THROW; END CATCH;
SET @n=(SELECT COUNT(*) FROM credits.CreditRedemptions WHERE CreditId=@credit);
EXEC test.AssertEq N'no redemption while in transit',0,@n;
SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'conservation while in transit',0,@n;

-- The origin can still spend its free 70000 during transit.
EXEC credits.usp_RedeemCredit @RedemptionId=@r3,@CreditId=@credit,@BranchId=@branchA,
     @SaleId=@saleA,@AmountMinor=70000,@ActorId=@cashierA;
SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'conservation after origin spends free part',0,@n;

EXEC credits.usp_AcceptTransfer @TransferId=@transfer,@ActorId=@manager,
  @OriginNodeId=@nodeB,@EventId=@acceptEvent;
-- After accept the destination owns 50000 and can spend it on its own sale.
EXEC credits.usp_RedeemCredit @RedemptionId=@r4,@CreditId=@credit,@BranchId=@branchB,
     @SaleId=@saleB,@AmountMinor=50000,@ActorId=@cashierB;
SET @n=(SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchB);
EXEC test.AssertEq N'B available after destination redeem',0,@n;
SET @n=(SELECT c.OriginalMinor-COALESCE((SELECT SUM(a.AvailableMinor+a.HeldMinor) FROM credits.CreditAllocations a WHERE a.CreditId=c.Id),0)
       -COALESCE((SELECT SUM(r.AmountMinor) FROM credits.CreditRedemptions r WHERE r.CreditId=c.Id AND r.Status='posted'),0)
  FROM credits.Credits c WHERE c.Id=@credit);
EXEC test.AssertEq N'conservation after destination redeem',0,@n;
PRINT 'PASS';
