-- TEST: Change Tracking is on for the six branch tables and a sale shows up as changes since the previous version.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@node uniqueidentifier=test.Id('nodeA'),
  @register uniqueidentifier=test.Id('registerA'),@item uniqueidentifier=test.Id('item'),
  @till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@v0 bigint,@v1 bigint,@n bigint;
SET @n=(SELECT COUNT(*) FROM sys.change_tracking_databases WHERE database_id=DB_ID());
EXEC test.AssertEq N'change tracking on the database',1,@n;
SET @n=(SELECT COUNT(*) FROM sys.change_tracking_tables);
EXEC test.AssertEq N'tracked tables',6,@n;
EXEC test.SeedStock @item,@loc,5;
SET @v0=CHANGE_TRACKING_CURRENT_VERSION();
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,@CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,2,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',240000,240000,0);
EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,@CurrencyCode='NIO',
     @TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders;
SET @n=(SELECT COUNT(*) FROM CHANGETABLE(CHANGES sales.Sales,@v0) c WHERE c.Id=@sale AND c.SYS_CHANGE_OPERATION='I');
EXEC test.AssertEq N'the sale is one insert since v0',1,@n;
SET @n=(SELECT COUNT(*) FROM CHANGETABLE(CHANGES sales.SaleLines,@v0) c);
EXEC test.AssertEq N'sale lines changed',1,@n;
SET @n=(SELECT COUNT(*) FROM CHANGETABLE(CHANGES sales.CashTills,@v0) c WHERE c.Id=@till);
EXEC test.AssertEq N'till changed',1,@n;
SET @n=(SELECT COUNT(*) FROM CHANGETABLE(CHANGES inventory.StockMovements,@v0) c);
EXEC test.AssertEq N'stock movements changed',1,@n;
SET @v1=CHANGE_TRACKING_CURRENT_VERSION();
SET @n=(SELECT COUNT(*) FROM CHANGETABLE(CHANGES sales.Sales,@v1) c);
EXEC test.AssertEq N'nothing new after the current version',0,@n;
PRINT 'PASS';
