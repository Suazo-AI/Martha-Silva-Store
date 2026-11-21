-- TEST: seller cap, return window, cash/transfer/exchange outcomes, refunds by kind and conservation.
SET NOCOUNT ON;SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),@item uniqueidentifier=test.Id('item'),@item2 uniqueidentifier=test.Id('item2'),
 @node uniqueidentifier=test.Id('nodeA'),@owner uniqueidentifier=test.Id('manager'),@manager uniqueidentifier=test.Id('supervisorA'),@cashier uniqueidentifier=test.Id('cashierA'),
 @register uniqueidentifier=test.Id('registerA'),@till uniqueidentifier=NEWID(),@n bigint,@s nvarchar(max);
DECLARE @a uniqueidentifier=NEWID(),@b uniqueidentifier=NEWID(),@c uniqueidentifier=NEWID(),@d uniqueidentifier=NEWID();
INSERT security.Staff(Id,LoginName,NormalizedLoginName,DisplayName) VALUES(@a,'s_a','S_A',N'Ana'),(@b,'s_b','S_B',N'Bea'),(@c,'s_c','S_C',N'Caro'),(@d,'s_d','S_D',N'Dina');
INSERT security.StaffRoles(StaffId,RoleId) SELECT x.Id,r.Id FROM (VALUES(@a),(@b),(@c),(@d)) x(Id) CROSS JOIN security.Roles r WHERE r.Code='SELLER';
INSERT security.StaffBranchAccess(StaffId,BranchId) VALUES(@a,@branch),(@b,@branch),(@c,@branch),(@d,@branch);
EXEC test.SeedStock @item,@loc,20;EXEC test.SeedStock @item2,@loc,10;
EXEC sales.usp_OpenTill @till,@register,@cashier,'NIO',0,@node;

-- 1. Four sellers on one ticket are rejected; three are accepted.
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest,@sale uniqueidentifier=NEWID();
INSERT @lines VALUES(1,@item,1,120000,0),(2,@item,1,120000,0),(3,@item,1,120000,0),(4,@item,1,120000,0);
INSERT @tenders(TenderNumber,TenderKind,AmountMinor) VALUES(1,'card',480000);
SET @s=(SELECT v.lineNumber,v.sellerId FROM (VALUES(1,@a),(2,@b),(3,@c),(4,@d)) v(lineNumber,sellerId) FOR JSON PATH);
BEGIN TRY EXEC sales.usp_PostSale @sale,@branch,@loc,@cashier,'NIO',@node,@lines,@tenders,@TillId=@till,@SellersJson=@s;THROW 59002,'ASSERT FAIL: four sellers accepted',1;END TRY BEGIN CATCH IF ERROR_NUMBER()<>52009 THROW;END CATCH;
SET @s=(SELECT v.lineNumber,v.sellerId FROM (VALUES(1,@a),(2,@b),(3,@c),(4,@a)) v(lineNumber,sellerId) FOR JSON PATH);
EXEC sales.usp_PostSale @sale,@branch,@loc,@cashier,'NIO',@node,@lines,@tenders,@TillId=@till,@SellersJson=@s;
SET @n=(SELECT COUNT(DISTINCT SellerId) FROM sales.SaleLines WHERE SaleId=@sale);EXEC test.AssertEq N'three sellers on one ticket',3,@n;

-- 2. Cash sale puts 120000 in the till. A cash refund of 120000 empties it; the next cash refund is refused.
DECLARE @cashSale uniqueidentifier=NEWID();DELETE @lines;DELETE @tenders;
INSERT @lines VALUES(1,@item,1,120000,0);INSERT @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',120000,120000,0);
SET @s=(SELECT 1 AS lineNumber,@a AS sellerId FOR JSON PATH);
EXEC sales.usp_PostSale @cashSale,@branch,@loc,@cashier,'NIO',@node,@lines,@tenders,@TillId=@till,@SellersJson=@s;
DECLARE @r sales.ReturnLineRequest,@none sales.SaleLineRequest,@noTender sales.SaleTenderRequest,@rev uniqueidentifier=NEWID(),
 @line uniqueidentifier=(SELECT Id FROM sales.SaleLines WHERE SaleId=@sale AND LineNumber=1);
INSERT @r VALUES(@line,1,'store');
BEGIN TRY EXEC sales.usp_PostReturnOutcome @rev,@sale,@branch,@loc,@till,@cashier,'cash',N'Talla',NULL,@node,@r,NULL,@none,@noTender;THROW 59002,'ASSERT FAIL: cashier approved',1;END TRY BEGIN CATCH IF ERROR_NUMBER()<>51529 THROW;END CATCH;
EXEC sales.usp_PostReturnOutcome @rev,@sale,@branch,@loc,@till,@manager,'cash',N'Talla',NULL,@node,@r,NULL,@none,@noTender;
EXEC sales.usp_PostReturnOutcome @rev,@sale,@branch,@loc,@till,@manager,'cash',N'Talla',NULL,@node,@r,NULL,@none,@noTender;
SET @n=(SELECT SUM(DeltaMinor) FROM sales.CashEntries WHERE TillId=@till);EXEC test.AssertEq N'cash refund lowers expected cash once',0,@n;
SET @n=(SELECT CommissionMinor FROM sales.SaleLines WHERE Id=@line);EXEC test.AssertEq N'line commission kept for reversal',3600,@n;
DECLARE @rev2 uniqueidentifier=NEWID();DELETE @r;INSERT @r SELECT Id,1,'store' FROM sales.SaleLines WHERE SaleId=@sale AND LineNumber=2;
BEGIN TRY EXEC sales.usp_PostReturnOutcome @rev2,@sale,@branch,@loc,@till,@manager,'cash',N'Talla',NULL,@node,@r,NULL,@none,@noTender;THROW 59002,'ASSERT FAIL: refund without cash',1;END TRY BEGIN CATCH IF ERROR_NUMBER()<>52024 THROW;END CATCH;

-- 3. Transfer needs a reference and leaves the till alone.
BEGIN TRY EXEC sales.usp_PostReturnOutcome @rev2,@sale,@branch,@loc,@till,@manager,'transfer',N'Talla',N' ',@node,@r,NULL,@none,@noTender;THROW 59002,'ASSERT FAIL: transfer without reference',1;END TRY BEGIN CATCH IF ERROR_NUMBER()<>52021 THROW;END CATCH;
EXEC sales.usp_PostReturnOutcome @rev2,@sale,@branch,@loc,@till,@manager,'transfer',N'Talla',N'BAC 778899',@node,@r,NULL,@none,@noTender;
SET @n=(SELECT SUM(DeltaMinor) FROM sales.CashEntries WHERE TillId=@till);EXEC test.AssertEq N'transfer leaves till',0,@n;
SET @n=(SELECT AmountMinor FROM sales.ReturnSettlements WHERE ReversalId=@rev2 AND Kind='transfer' AND Reference=N'BAC 778899');EXEC test.AssertEq N'transfer recorded',120000,@n;

-- 4. Exchange for a cheaper garment: difference 22250 must be returned; by transfer here.
DECLARE @rev3 uniqueidentifier=NEWID(),@ex uniqueidentifier=NEWID();DELETE @r;INSERT @r SELECT Id,1,'store' FROM sales.SaleLines WHERE SaleId=@sale AND LineNumber=3;
DECLARE @new sales.SaleLineRequest;INSERT @new VALUES(1,@item2,1,85000,0);
SET @s=(SELECT 1 AS lineNumber,@c AS sellerId FOR JSON PATH);
BEGIN TRY EXEC sales.usp_PostReturnOutcome @rev3,@sale,@branch,@loc,@till,@manager,'exchange',N'Cambio',NULL,@node,@r,@ex,@new,@noTender,@s;THROW 59002,'ASSERT FAIL: difference not chosen',1;END TRY BEGIN CATCH IF ERROR_NUMBER()<>52025 THROW;END CATCH;
EXEC sales.usp_PostReturnOutcome @rev3,@sale,@branch,@loc,@till,@manager,'exchange',N'Cambio',NULL,@node,@r,@ex,@new,@noTender,@s,'transfer',N'BAC 1';
SET @n=(SELECT TotalMinor FROM sales.Sales WHERE Id=@ex);EXEC test.AssertEq N'exchange sale total',97750,@n;
SET @n=(SELECT AmountMinor FROM sales.ReturnSettlements WHERE ReversalId=@rev3 AND Kind='exchange');EXEC test.AssertEq N'exchange applied',97750,@n;
SET @n=(SELECT AmountMinor FROM sales.ReturnSettlements WHERE ReversalId=@rev3 AND Kind='transfer');EXEC test.AssertEq N'exchange difference returned',22250,@n;

-- 5. Exchange for a dearer garment: the customer pays 22250 in cash.
DECLARE @rev4 uniqueidentifier=NEWID(),@ex2 uniqueidentifier=NEWID();DELETE @r;INSERT @r SELECT Id,1,'store' FROM sales.SaleLines WHERE SaleId=@ex AND LineNumber=1;
DELETE @new;INSERT @new VALUES(1,@item,1,120000,0);
DECLARE @pay sales.SaleTenderRequest;INSERT @pay(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',22250,22250,0);
SET @s=(SELECT 1 AS lineNumber,@a AS sellerId FOR JSON PATH);
EXEC sales.usp_PostReturnOutcome @rev4,@ex,@branch,@loc,@till,@manager,'exchange',N'Cambio',NULL,@node,@r,@ex2,@new,@pay,@s;
SET @n=(SELECT SUM(DeltaMinor) FROM sales.CashEntries WHERE TillId=@till);EXEC test.AssertEq N'difference paid in cash',22250,@n;

-- 6. Window: an old sale is refused for every outcome, including store credit.
EXEC sales.usp_SetReturnWindow @rev,@branch,30,@owner,N'Politica';
BEGIN TRY EXEC sales.usp_SetReturnWindow @rev4,@branch,10,@manager,N'No';THROW 59002,'ASSERT FAIL: manager changed window',1;END TRY BEGIN CATCH IF ERROR_NUMBER()<>52001 THROW;END CATCH;
UPDATE sales.Sales SET CreatedAt=DATEADD(day,-31,core.ufn_BusinessNow()) WHERE Id=@cashSale;
DECLARE @rev5 uniqueidentifier=NEWID();DELETE @r;INSERT @r SELECT Id,1,'store' FROM sales.SaleLines WHERE SaleId=@cashSale;
BEGIN TRY EXEC sales.usp_PostReturnOutcome @rev5,@cashSale,@branch,@loc,@till,@manager,'transfer',N'Tarde',N'BAC 2',@node,@r,NULL,@none,@noTender;THROW 59002,'ASSERT FAIL: late return',1;END TRY BEGIN CATCH IF ERROR_NUMBER()<>52023 THROW;END CATCH;
BEGIN TRY EXEC sales.usp_PostCreditReturn @ReversalId=@rev5,@CreditId=@rev5,@SaleId=@cashSale,@BranchId=@branch,@ReturnLocationId=@loc,@TillId=@till,@ActorId=@manager,@ApprovedBy=@manager,@CustomerId=NULL,@Reason=N'Tarde',@OriginNodeId=@node,@Lines=@r;THROW 59002,'ASSERT FAIL: late credit',1;END TRY BEGIN CATCH IF ERROR_NUMBER()<>52023 THROW;END CATCH;
EXEC sales.usp_SetReturnWindow @rev5,@branch,40,@owner,N'Temporada';
EXEC sales.usp_PostReturnOutcome @rev5,@cashSale,@branch,@loc,@till,@manager,'transfer',N'Tarde',N'BAC 2',@node,@r,NULL,@none,@noTender;

-- 7. Commission reversal covers every outcome; day report and till close show refunds by kind.
DECLARE @today date=CONVERT(date,DATEADD(hour,-6,core.ufn_BusinessNow()));
DECLARE @report TABLE(Json nvarchar(max));INSERT @report EXEC sales.usp_GetCommissions @branch,@a,'day',@today;
SET @n=(SELECT TRY_CONVERT(bigint,JSON_VALUE(Json,'$[0].commissionPayableMinor')) FROM @report);
EXEC test.AssertEq N'seller A: three lines today, two returns today (one of an old sale)',3600,@n;
DECLARE @kinds TABLE(Json nvarchar(max));INSERT @kinds EXEC sales.usp_GetReturnsByKind @branch,@today;
SET @n=(SELECT SUM(TRY_CONVERT(bigint,JSON_VALUE(value,'$.amountMinor'))) FROM @kinds CROSS APPLY OPENJSON(Json) WHERE JSON_VALUE(value,'$.kind')='transfer');
EXEC test.AssertEq N'transfer refunds of the day',240000,@n;
DECLARE @count uniqueidentifier=NEWID(),@close uniqueidentifier=NEWID(),@counted bigint=(SELECT SUM(DeltaMinor) FROM sales.CashEntries WHERE TillId=@till);
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES(@count,@till,@cashier,'draft',@cashier);
INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity) VALUES(@count,1000,22);
EXEC sales.usp_SubmitCashCount @CashCountId=@count,@ActorId=@cashier;
EXEC sales.usp_CloseTill @close,@till,@count,@manager,@node;
SET @n=(SELECT COUNT(*) FROM accounting.CloseDocumentLines dl JOIN accounting.CloseDocuments d ON d.Id=dl.CloseDocumentId WHERE d.ClosureId=@close AND dl.ConceptCode LIKE 'REFUND[_]%');
EXEC test.AssertEq N'close lists cash, exchange and transfer returns',3,@n;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';
