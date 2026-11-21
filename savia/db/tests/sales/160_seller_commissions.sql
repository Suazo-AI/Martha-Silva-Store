-- TEST: two sellers share one ticket; return commission belongs to the return period.
SET NOCOUNT ON;SET XACT_ABORT ON;
DECLARE @one uniqueidentifier=NEWID(),@two uniqueidentifier=NEWID(),@branch uniqueidentifier=test.Id('branchA'),
 @loc uniqueidentifier=test.Id('locA'),@item uniqueidentifier=test.Id('item'),@node uniqueidentifier=test.Id('nodeA'),
 @owner uniqueidentifier=test.Id('manager'),@manager uniqueidentifier=test.Id('supervisorA'),@cashier uniqueidentifier=test.Id('cashierA'),
 @register uniqueidentifier=test.Id('registerA'),@till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),@customer uniqueidentifier=test.Id('customer'),@n bigint;
INSERT security.Staff(Id,LoginName,NormalizedLoginName,DisplayName) VALUES(@one,'seller_one','SELLER_ONE',N'Ana'),(@two,'seller_two','SELLER_TWO',N'Rosa');
INSERT security.StaffRoles(StaffId,RoleId) SELECT x.Id,r.Id FROM (VALUES(@one),(@two)) x(Id) CROSS JOIN security.Roles r WHERE r.Code='SELLER';
INSERT security.StaffBranchAccess(StaffId,BranchId) VALUES(@one,@branch),(@two,@branch);
EXEC test.SeedStock @item,@loc,5;
EXEC sales.usp_OpenTill @till,@register,@cashier,'NIO',0,@node;
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT @lines VALUES(1,@item,2,120000,12000),(2,@item,1,120000,0);
INSERT @tenders(TenderNumber,TenderKind,AmountMinor) VALUES(1,'card',348000);
DECLARE @sellers nvarchar(max)=(SELECT v.lineNumber,v.sellerId FROM (VALUES(1,@one),(2,@two)) v(lineNumber,sellerId) FOR JSON PATH);
EXEC sales.usp_PostSale @sale,@branch,@loc,@cashier,'NIO',@node,@lines,@tenders,@TillId=@till,@DiscountApproverId=@manager,@DiscountReason=N'Oferta',@SellersJson=@sellers;
SET @n=(SELECT SUM(CommissionMinor) FROM sales.SaleLines WHERE SaleId=@sale AND SellerId=@one);EXEC test.AssertEq N'first seller commission',6840,@n;
SET @n=(SELECT SUM(CommissionMinor) FROM sales.SaleLines WHERE SaleId=@sale AND SellerId=@two);EXEC test.AssertEq N'second seller commission',3600,@n;
DECLARE @change uniqueidentifier=NEWID();
EXEC sales.usp_SetSellerRate @change,@one,500,@owner,N'Nueva comisión';
EXEC sales.usp_SetSellerRate @change,@one,500,@owner,N'Nueva comisión';
SET @n=(SELECT CommissionMinor FROM sales.SaleLines WHERE SaleId=@sale AND SellerId=@one);EXEC test.AssertEq N'rate change preserves earned commission',6840,@n;
DECLARE @line uniqueidentifier=(SELECT Id FROM sales.SaleLines WHERE SaleId=@sale AND SellerId=@one),@reverse uniqueidentifier=NEWID(),@credit uniqueidentifier=NEWID();
DECLARE @returns sales.ReturnLineRequest;INSERT @returns VALUES(@line,1,'store');
EXEC sales.usp_PostCreditReturn @ReversalId=@reverse,@CreditId=@credit,@SaleId=@sale,@BranchId=@branch,@ReturnLocationId=@loc,@TillId=@till,@ActorId=@manager,@ApprovedBy=@manager,@CustomerId=@customer,@Reason=N'Talla',@OriginNodeId=@node,@Lines=@returns;
DECLARE @today date=CONVERT(date,DATEADD(hour,-6,SYSUTCDATETIME()));
DECLARE @report TABLE(Json nvarchar(max));INSERT @report EXEC sales.usp_GetCommissions @branch,@one,'day',@today;
SET @n=(SELECT COUNT(*) FROM @report CROSS APPLY OPENJSON(Json));EXEC test.AssertEq N'seller sees one row',1,@n;
SET @n=(SELECT TRY_CONVERT(bigint,JSON_VALUE(Json,'$[0].commissionPayableMinor')) FROM @report);EXEC test.AssertEq N'net commission after one returned unit',3420,@n;
BEGIN TRY EXEC sales.usp_SetSellerRate @change,@one,700,@manager,N'No autorizado';THROW 59002,'ASSERT FAIL: manager changed rate',1;END TRY BEGIN CATCH IF ERROR_NUMBER()<>52001 THROW;END CATCH;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';
