-- PROBE (gap register 2026-11-21): a branch creates a customer offline and sells to her; does its push apply on the hub?
-- Two clones of the test template: this script runs in the branch database; the hub database name is substituted for
-- __HUB__ by the driver. crm.Customers is not in sync.SyncTables, so the customer row never travels.
-- Red: the hub refuses the batch. Control: insert the same customer on the hub and apply the same batch again.
SET NOCOUNT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @loc uniqueidentifier=test.Id('locA'),@branch uniqueidentifier=test.Id('branchA'),@cashier uniqueidentifier=test.Id('cashierA'),
  @item uniqueidentifier=test.Id('item'),@node uniqueidentifier=test.Id('nodeA'),
  @first uniqueidentifier=NEWID(),@second uniqueidentifier=NEWID(),@newCustomer uniqueidentifier=NEWID(),@till uniqueidentifier,
  @state nvarchar(max),@plan nvarchar(max),@batch nvarchar(max),@r nvarchar(max),@msg nvarchar(4000);
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC [__HUB__].sync.usp_SetLocalNode @NodeId=@cloud;

-- Branch A: one sale to the fixture customer (present on both nodes), one to a customer created offline at A.
EXEC test.SeedSale @first,'A';
INSERT INTO crm.Customers(Id,DisplayName) VALUES(@newCustomer,N'Clienta creada sin internet en A');
EXEC test.SeedStock @item,@loc,1;
SET @till=(SELECT TOP(1) Id FROM sales.CashTills WHERE RegisterId=test.Id('registerA') AND Status='open');
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',120000,120000,0);
EXEC sales.usp_PostSale @SaleId=@second,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
     @CurrencyCode='NIO',@CustomerId=@newCustomer,@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders;
DECLARE @n int=(SELECT COUNT(*) FROM sales.Sales WHERE Id IN (@first,@second)); PRINT CONCAT('branch sales posted: ',@n);

-- One push round, as POST /sync/v1/push/plan then POST /sync/v1/push.
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
EXEC [__HUB__].sync.usp_PlanJson @PeerNodeId=@a,@StateJson=@state,@Json=@plan OUTPUT;
EXEC sync.usp_ReadBatch @TargetNodeId=@cloud,@PlanJson=@plan,@Json=@batch OUTPUT;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@batch,'$.tables[1].rows')); PRINT CONCAT('batch sales rows: ',@n);
BEGIN TRY EXEC [__HUB__].sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@batch,@Json=@r OUTPUT; PRINT CONCAT('RED hub apply: OK ',@r);
END TRY BEGIN CATCH SET @msg=CONCAT('RED hub apply: Msg ',ERROR_NUMBER(),' ',ERROR_MESSAGE()); PRINT @msg; END CATCH;
SET @n=(SELECT COUNT(*) FROM [__HUB__].sales.Sales WHERE Id IN (@first,@second)); PRINT CONCAT('hub has the sales after red apply: ',@n);

-- Control: the parent row exists on the hub; the same batch applies.
INSERT INTO [__HUB__].crm.Customers(Id,DisplayName) VALUES(@newCustomer,N'Clienta creada sin internet en A');
BEGIN TRY EXEC [__HUB__].sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@batch,@Json=@r OUTPUT; PRINT CONCAT('CONTROL hub apply: OK ',@r);
END TRY BEGIN CATCH SET @msg=CONCAT('CONTROL hub apply: Msg ',ERROR_NUMBER(),' ',ERROR_MESSAGE()); PRINT @msg; END CATCH;
SET @n=(SELECT COUNT(*) FROM [__HUB__].sales.Sales WHERE Id IN (@first,@second)); PRINT CONCAT('hub has the sales after control apply: ',@n);
GO
