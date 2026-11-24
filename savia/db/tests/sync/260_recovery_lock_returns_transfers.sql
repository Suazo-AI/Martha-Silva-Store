-- TEST: D-036 recovery lock, second part (V052). While a branch is recovering it also refuses returns (credit and outcome), credit transfer dispatch, transfer receipt and web consignment (51864); each call would succeed once the lock lifts.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@b uniqueidentifier=test.Id('nodeB'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @branchA uniqueidentifier=test.Id('branchA'),@branchB uniqueidentifier=test.Id('branchB'),@locA uniqueidentifier=test.Id('locA'),
  @cashierA uniqueidentifier=test.Id('cashierA'),@cashierB uniqueidentifier=test.Id('cashierB'),@manager uniqueidentifier=test.Id('manager'),
  @customer uniqueidentifier=test.Id('customer'),@item uniqueidentifier=test.Id('item'),
  @fork uniqueidentifier=(SELECT recovery_fork_guid FROM sys.database_recovery_status WHERE database_id=DB_ID()),
  @credit uniqueidentifier=NEWID(),@transfer uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),
  @x uniqueidentifier=NEWID(),@till uniqueidentifier,@line uniqueidentifier,@n bigint,@err int,@before bigint;
DECLARE @ret sales.ReturnLineRequest,@none sales.SaleLineRequest,@noTender sales.SaleTenderRequest;
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC test.SeedCredit @credit;
EXEC test.SeedSale @sale,'A';
EXEC test.SeedStock @item,@locA,2;
SET @till=(SELECT TillId FROM sales.Sales WHERE Id=@sale);
SET @line=(SELECT Id FROM sales.SaleLines WHERE SaleId=@sale AND LineNumber=1);
INSERT @ret(SaleLineId,Quantity,RestockPool) VALUES(@line,1,'quarantine');
EXEC credits.usp_TransferRequest @TransferId=@transfer,@CreditId=@credit,@FromBranchId=@branchA,@ToBranchId=@branchB,
  @AmountMinor=50000,@RequestedBy=@cashierB,@Reason=N'Canje en B',@NodeId=@b;
EXEC credits.usp_TransferApprove @TransferId=@transfer,@ApproverId=@manager,@NodeId=@cloud;
SET @before=(SELECT COUNT(*) FROM sales.SaleReversals)+(SELECT COUNT(*) FROM credits.TransferDispatches)
  +(SELECT COUNT(*) FROM credits.TransferReceipts)+(SELECT COUNT(*) FROM inventory.WebConsignments);

-- A database cannot restore itself inside a test, so the bound fork is moved: the same state a restore leaves.
UPDATE sync.LocalNode SET ForkGuid=NEWID();
SET @err=0;
BEGIN TRY EXEC sales.usp_PostCreditReturn @ReversalId=@x,@CreditId=NULL,@SaleId=@sale,@BranchId=@branchA,@ReturnLocationId=@locA,
  @TillId=@till,@ActorId=@cashierA,@ApprovedBy=@manager,@CustomerId=@customer,@Reason=N'Talla',@OriginNodeId=@a,@Lines=@ret;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'credit return refused while recovering',51864,@err;
SET @err=0;
BEGIN TRY EXEC sales.usp_PostReturnOutcome @x,@sale,@branchA,@locA,@till,@manager,'cash',N'Talla',NULL,@a,@ret,NULL,@none,@noTender;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'return outcome refused while recovering',51864,@err;
SET @err=0;
BEGIN TRY EXEC credits.usp_TransferDispatch @TransferId=@transfer,@ActorId=@cashierA,@NodeId=@a; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'transfer dispatch refused while recovering',51864,@err;
SET @err=0;
BEGIN TRY EXEC inventory.usp_ConsignToWeb @ConsignmentId=@x,@ItemId=@item,@FromLocationId=@locA,@Quantity=1,@ActorId=@manager;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'web consignment refused while recovering',51864,@err;

-- The lock lifts: the dispatch goes through. Then the node recovers again before the receipt.
UPDATE sync.LocalNode SET ForkGuid=@fork;
EXEC credits.usp_TransferDispatch @TransferId=@transfer,@ActorId=@cashierA,@NodeId=@a;
UPDATE sync.LocalNode SET ForkGuid=NEWID();
SET @err=0;
BEGIN TRY EXEC credits.usp_TransferReceive @TransferId=@transfer,@ActorId=@cashierB,@NodeId=@b; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'transfer receipt refused while recovering',51864,@err;
SET @n=(SELECT COUNT(*) FROM sales.SaleReversals)+(SELECT COUNT(*) FROM credits.TransferDispatches)
  +(SELECT COUNT(*) FROM credits.TransferReceipts)+(SELECT COUNT(*) FROM inventory.WebConsignments)-@before;
EXEC test.AssertEq N'only the dispatch made after the lock lifted was written',1,@n;

UPDATE sync.LocalNode SET ForkGuid=@fork;
EXEC credits.usp_TransferReceive @TransferId=@transfer,@ActorId=@cashierB,@NodeId=@b;
SET @n=(SELECT COUNT(*) FROM credits.TransferReceipts WHERE TransferId=@transfer); EXEC test.AssertEq N'receipt accepted after the lock lifts',1,@n;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';
