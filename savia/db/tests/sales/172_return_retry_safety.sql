-- TEST: V029 exact retries, independent financial identity mutations, current permission, legacy fail-closed and zero-row changes.
-- Prepared for the existing disposable-database SQL harness. Worker runtime NOT RUN.
SET NOCOUNT ON; SET XACT_ABORT ON;
GO
-- Exact ordered row images across ALL financial/sync tables, including accounting and deliveries.
CREATE PROCEDURE test.ReturnSafetySnapshot @Image nvarchar(max) OUTPUT
AS
BEGIN
 SET NOCOUNT ON;
 SET @Image=N'';
 DECLARE @object int,@name nvarchar(300),@order nvarchar(max),@sql nvarchar(max),@rows nvarchar(max);
 DECLARE snapshots CURSOR LOCAL FAST_FORWARD FOR
 SELECT t.object_id,QUOTENAME(s.name)+N'.'+QUOTENAME(t.name) FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
 WHERE s.name IN ('sales','inventory','credits','accounting','sync','audit') ORDER BY s.name,t.name;
 OPEN snapshots; FETCH NEXT FROM snapshots INTO @object,@name;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SELECT @order=STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(c.name)),N',') WITHIN GROUP(ORDER BY ic.key_ordinal)
   FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
   JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@object AND i.is_primary_key=1;
  IF @order IS NULL THROW 59002,'ASSERT FAIL: snapshot needs primary key',1;
  SET @sql=N'SELECT @r=(SELECT * FROM '+@name+N' ORDER BY '+@order+N' FOR JSON PATH,INCLUDE_NULL_VALUES);';
  EXEC sys.sp_executesql @sql,N'@r nvarchar(max) OUTPUT',@r=@rows OUTPUT;
  SET @Image+=@name+N':'+CONVERT(nvarchar(20),DATALENGTH(@rows))+N':'+@rows;
  FETCH NEXT FROM snapshots INTO @object,@name;
 END;
 CLOSE snapshots; DEALLOCATE snapshots;
END;
GO
-- This adapter uses the real TVP and procedure parameter contracts, without production changes.
CREATE PROCEDURE test.CallReturnSafety @Request nvarchar(max)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @rev uniqueidentifier=JSON_VALUE(@Request,'$.reversalId'),@sale uniqueidentifier=JSON_VALUE(@Request,'$.saleId'),
  @branch uniqueidentifier=JSON_VALUE(@Request,'$.branchId'),@location uniqueidentifier=JSON_VALUE(@Request,'$.locationId'),
  @till uniqueidentifier=JSON_VALUE(@Request,'$.tillId'),@actor uniqueidentifier=JSON_VALUE(@Request,'$.actorId'),
  @approved uniqueidentifier=JSON_VALUE(@Request,'$.approvedBy'),@credit uniqueidentifier=JSON_VALUE(@Request,'$.creditId'),
  @customer uniqueidentifier=JSON_VALUE(@Request,'$.customerId'),@node uniqueidentifier=JSON_VALUE(@Request,'$.nodeId'),
  @exchange uniqueidentifier=JSON_VALUE(@Request,'$.exchangeSaleId'),@outcome varchar(16)=JSON_VALUE(@Request,'$.outcome'),
  @reason nvarchar(500)=JSON_VALUE(@Request,'$.reason'),@reference nvarchar(120)=JSON_VALUE(@Request,'$.reference'),
  @difference varchar(16)=JSON_VALUE(@Request,'$.differenceKind'),@differenceRef nvarchar(120)=JSON_VALUE(@Request,'$.differenceReference'),
  @sellers nvarchar(max)=JSON_QUERY(@Request,'$.sellers'),@fx nvarchar(max)=JSON_QUERY(@Request,'$.fx');
 DECLARE @lines sales.ReturnLineRequest,@new sales.SaleLineRequest,@pay sales.SaleTenderRequest;
 INSERT @lines SELECT SaleLineId,Quantity,RestockPool FROM OPENJSON(@Request,'$.returnLines') WITH(SaleLineId uniqueidentifier,Quantity int,RestockPool varchar(12));
 INSERT @new SELECT LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor FROM OPENJSON(@Request,'$.newLines') WITH(LineNumber int,ItemId uniqueidentifier,Quantity int,UnitPriceMinor bigint,DiscountMinor bigint);
 INSERT @pay SELECT TenderNumber,TenderKind,AmountMinor,CreditId,ReceivedMinor,ChangeMinor,Reference FROM OPENJSON(@Request,'$.tenders') WITH(TenderNumber int,TenderKind varchar(20),AmountMinor bigint,CreditId uniqueidentifier,ReceivedMinor bigint,ChangeMinor bigint,Reference nvarchar(120));
 IF JSON_VALUE(@Request,'$.endpoint')='credit'
  EXEC sales.usp_PostCreditReturn @rev,@credit,@sale,@branch,@location,@till,@actor,@approved,@customer,@reason,@node,@lines;
 ELSE EXEC sales.usp_PostReturnOutcome @rev,@sale,@branch,@location,@till,@actor,@outcome,@reason,@reference,@node,@lines,@exchange,@new,@pay,@sellers,@difference,@differenceRef,@fx;
END;
GO
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),@node uniqueidentifier=test.Id('nodeA'),
 @manager uniqueidentifier=test.Id('manager'),@cashier uniqueidentifier=test.Id('cashierA'),@customer uniqueidentifier=test.Id('customer'),
 @item uniqueidentifier=test.Id('item'),@seller uniqueidentifier=NEWID(),@seller2 uniqueidentifier=NEWID(),@scenario int=0,@n bigint;
INSERT security.Staff(Id,LoginName,NormalizedLoginName,DisplayName) VALUES(@seller,'retry_s1','RETRY_S1',N'S1'),(@seller2,'retry_s2','RETRY_S2',N'S2');
INSERT security.StaffRoles(StaffId,RoleId) SELECT v.Id,r.Id FROM (VALUES(@seller),(@seller2)) v(Id) CROSS JOIN security.Roles r WHERE r.Code='SELLER';
INSERT security.StaffBranchAccess(StaffId,BranchId) VALUES(@seller,@branch),(@seller2,@branch);
EXEC test.SeedStock @item,@loc,100;
DECLARE @taxItem uniqueidentifier=test.Id('item2'); EXEC test.SeedStock @taxItem,@loc,20;
-- 0 cash; 1 transfer; 2 credit; 3 equal exchange; 4 cheaper exchange; 5 dearer exchange.
WHILE @scenario<6
BEGIN
 DECLARE @sale uniqueidentifier=NEWID(),@rev uniqueidentifier=NEWID(),@credit uniqueidentifier=NEWID(),@exchange uniqueidentifier=NEWID(),@till uniqueidentifier;
 EXEC test.SeedSale @sale,'A';
 SELECT @till=TillId FROM sales.Sales WHERE Id=@sale;
 DECLARE @line uniqueidentifier=(SELECT Id FROM sales.SaleLines WHERE SaleId=@sale),@request nvarchar(max),@retry nvarchar(max),
  @before nvarchar(max),@after nvarchar(max),@expected int,@caught int,@case int,@count int,@label nvarchar(100),@path nvarchar(100),@value nvarchar(100);
 DECLARE @returnJson nvarchar(max)=(SELECT @line AS SaleLineId,1 AS Quantity,'store' AS RestockPool FOR JSON PATH),
  @newJson nvarchar(max)=N'[]',@tenderJson nvarchar(max)=N'[]',@sellersJson nvarchar(max)=NULL;
 IF @scenario>=3
 BEGIN
  -- Equal/cheaper use the catalog's actual prices. Dearer uses two full-price lines.
  DECLARE @price bigint=CASE WHEN @scenario=4 THEN 85000 ELSE 120000 END,
   @newItem uniqueidentifier=CASE WHEN @scenario=4 THEN test.Id('item2') ELSE @item END;
  SET @newJson=(SELECT x.LineNumber,@newItem AS ItemId,1 AS Quantity,@price AS UnitPriceMinor,0 AS DiscountMinor FROM (VALUES(1),(2)) x(LineNumber) WHERE x.LineNumber=1 OR @scenario=5 FOR JSON PATH);
  SET @sellersJson=(SELECT x.lineNumber,x.sellerId FROM (VALUES(1,@seller),(2,@seller2)) x(lineNumber,sellerId) WHERE x.lineNumber=1 OR @scenario=5 FOR JSON PATH);
 END;
 IF @scenario=5 SET @tenderJson=N'[{"TenderNumber":1,"TenderKind":"cash","AmountMinor":60000,"ReceivedMinor":70000,"ChangeMinor":10000},{"TenderNumber":2,"TenderKind":"transfer","AmountMinor":60000,"Reference":"BAC paid"}]';
 SET @request=(SELECT @rev AS reversalId,@sale AS saleId,@branch AS branchId,@loc AS locationId,@till AS tillId,CASE WHEN @scenario=2 THEN @cashier ELSE @manager END AS actorId,@manager AS approvedBy,
  @credit AS creditId,@customer AS customerId,@node AS nodeId,CASE WHEN @scenario>=3 THEN @exchange END AS exchangeSaleId,
  CASE WHEN @scenario=2 THEN 'credit' ELSE 'outcome' END AS endpoint,
  CASE @scenario WHEN 0 THEN 'cash' WHEN 1 THEN 'transfer' WHEN 2 THEN 'credit' ELSE 'exchange' END AS outcome,
  N'Talla' AS reason,N'BAC refund' AS reference,CASE WHEN @scenario>=3 THEN 'transfer' END AS differenceKind,
  CASE WHEN @scenario>=3 THEN N'BAC difference' END AS differenceReference,
  JSON_QUERY(@returnJson) AS returnLines,JSON_QUERY(@newJson) AS newLines,JSON_QUERY(@tenderJson) AS tenders,JSON_QUERY(@sellersJson) AS sellers
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
 EXEC test.CallReturnSafety @request;
 IF NOT EXISTS(SELECT 1 FROM sales.SaleReversals WHERE Id=@rev AND RequestIdentityVersion=1 AND DATALENGTH(RequestIdentityHash)=32)
  THROW 59002,'ASSERT FAIL: new identity missing',1;
 EXEC audit.usp_CheckConservation @Throw=1;
 DECLARE @cases TABLE(Id int IDENTITY PRIMARY KEY,Label nvarchar(100),Path nvarchar(100),Value nvarchar(100),Expected int NOT NULL DEFAULT 51538);
 INSERT @cases(Label,Path,Value) VALUES
 ('sale','$.saleId',CONVERT(nvarchar(36),NEWID())),('node','$.nodeId',CONVERT(nvarchar(36),test.Id('nodeB'))),
 ('location','$.locationId',CONVERT(nvarchar(36),test.Id('locB'))),('till','$.tillId',CONVERT(nvarchar(36),NEWID())),
 ('branch','$.branchId',CONVERT(nvarchar(36),test.Id('branchB'))),('reason','$.reason',N'Otro motivo'),('pool only','$.returnLines[0].RestockPool','quarantine'),
 ('return line','$.returnLines[0].SaleLineId',CONVERT(nvarchar(36),NEWID())),('return quantity','$.returnLines[0].Quantity','2');
 IF @scenario=2 INSERT @cases(Label,Path,Value) VALUES
 ('credit','$.creditId',CONVERT(nvarchar(36),NEWID())),('customer','$.customerId',CONVERT(nvarchar(36),test.Id('customer2')));
 ELSE INSERT @cases(Label,Path,Value) VALUES ('reference','$.reference',N'BAC alternate');
 IF @scenario IN (0,1) INSERT @cases(Label,Path,Value) VALUES ('outcome','$.outcome',CASE @scenario WHEN 0 THEN 'transfer' ELSE 'cash' END);
 IF @scenario>=3
 BEGIN
  INSERT @cases(Label,Path,Value) VALUES ('exchange ID','$.exchangeSaleId',CONVERT(nvarchar(36),NEWID())),
   ('new line number','$.newLines[0].LineNumber','3'),('new item','$.newLines[0].ItemId',CONVERT(nvarchar(36),CASE WHEN @scenario=4 THEN @item ELSE test.Id('item2') END)),
   ('new quantity','$.newLines[0].Quantity','2'),('new price','$.newLines[0].UnitPriceMinor','61000'),('new discount','$.newLines[0].DiscountMinor','10'),
   ('seller equal total','$.sellers[0].sellerId',CONVERT(nvarchar(36),@seller2)),('difference kind','$.differenceKind','cash'),
   ('difference reference','$.differenceReference',N'BAC other');
 END;
 IF @scenario=5 INSERT @cases(Label,Path,Value) VALUES
 ('tender number','$.tenders[0].TenderNumber','3'),('tender kind','$.tenders[1].TenderKind','card'),
 ('tender amount','$.tenders[0].AmountMinor','11000'),('tender credit','$.tenders[0].CreditId',CONVERT(nvarchar(36),NEWID())),
 ('tender received','$.tenders[0].ReceivedMinor','30000'),('tender change','$.tenders[0].ChangeMinor','20000'),('tender reference','$.tenders[1].Reference',N'BAC alternate');
 -- Equivalent replay, including after till closure and expiration, must not write even metadata.
 EXEC test.ReturnSafetySnapshot @before OUTPUT;
 EXEC test.CallReturnSafety @request;
 EXEC test.ReturnSafetySnapshot @after OUTPUT;
 IF CONVERT(varbinary(max),@before)<>CONVERT(varbinary(max),@after) THROW 59002,'ASSERT FAIL: exact replay changed rows',1;
 IF @scenario>=3
 BEGIN
  SET @retry=JSON_MODIFY(@request,'$.newLines',JSON_QUERY((SELECT LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor FROM OPENJSON(@newJson) WITH(LineNumber int,ItemId uniqueidentifier,Quantity int,UnitPriceMinor bigint,DiscountMinor bigint) ORDER BY LineNumber DESC FOR JSON PATH)));
  SET @retry=JSON_MODIFY(@retry,'$.sellers',JSON_QUERY((SELECT sellerId,lineNumber FROM OPENJSON(@sellersJson) WITH(lineNumber int,sellerId uniqueidentifier) ORDER BY lineNumber DESC FOR JSON PATH)));
  SET @retry=JSON_MODIFY(@retry,'$.tenders',JSON_QUERY((SELECT TenderNumber,TenderKind,AmountMinor,CreditId,ReceivedMinor,ChangeMinor,Reference FROM OPENJSON(@tenderJson) WITH(TenderNumber int,TenderKind varchar(20),AmountMinor bigint,CreditId uniqueidentifier,ReceivedMinor bigint,ChangeMinor bigint,Reference nvarchar(120)) ORDER BY TenderNumber DESC FOR JSON PATH)));
  EXEC test.CallReturnSafety @retry;
  EXEC test.ReturnSafetySnapshot @after OUTPUT;
  IF CONVERT(varbinary(max),@before)<>CONVERT(varbinary(max),@after) THROW 59002,'ASSERT FAIL: reordered replay changed rows',1;
 END;
 IF @scenario=5
 BEGIN
  -- Change the tender split while total remains fixed and cash arithmetic remains valid.
  SET @retry=JSON_MODIFY(@request,'$.tenders[0].AmountMinor',CONVERT(bigint,50000));
  SET @retry=JSON_MODIFY(@retry,'$.tenders[0].ReceivedMinor',CONVERT(bigint,60000));
  SET @retry=JSON_MODIFY(@retry,'$.tenders[1].AmountMinor',CONVERT(bigint,70000));
  EXEC test.ReturnSafetySnapshot @before OUTPUT; SET @caught=0;
  BEGIN TRY EXEC test.CallReturnSafety @retry; END TRY BEGIN CATCH SET @caught=ERROR_NUMBER(); END CATCH;
  IF @caught<>51538 THROW 59002,'ASSERT FAIL: equal-total tender split accepted',1;
  EXEC test.ReturnSafetySnapshot @after OUTPUT;
  IF CONVERT(varbinary(max),@before)<>CONVERT(varbinary(max),@after) THROW 59002,'ASSERT FAIL: tender split changed rows',1;
 END;
 IF @scenario<>2
 BEGIN
  SET @retry=JSON_MODIFY(@request,'$.fx',JSON_QUERY(N'[]'));SET @caught=0;
  EXEC test.ReturnSafetySnapshot @before OUTPUT;
  BEGIN TRY EXEC test.CallReturnSafety @retry; END TRY BEGIN CATCH SET @caught=ERROR_NUMBER(); END CATCH;
  IF @caught<>52102 THROW 59002,'ASSERT FAIL: FX accepted',1;
  EXEC test.ReturnSafetySnapshot @after OUTPUT;
  IF CONVERT(varbinary(max),@before)<>CONVERT(varbinary(max),@after) THROW 59002,'ASSERT FAIL: FX changed rows',1;
 END;
 -- The credit actor (cashierA) has no access to branchB. Current authorization runs before the identity check,
 -- so that replay is refused with 51529, not 51538. The manager, used elsewhere, has access to every branch.
 IF @scenario=2 UPDATE @cases SET Expected=51529 WHERE Label='branch';
 SELECT @case=MIN(Id),@count=MAX(Id) FROM @cases;
 WHILE @case<=@count
 BEGIN
  SELECT @label=Label,@path=Path,@value=Value,@expected=Expected FROM @cases WHERE Id=@case;
  SET @retry=JSON_MODIFY(@request,@path,@value);SET @caught=0;
  EXEC test.ReturnSafetySnapshot @before OUTPUT;
  BEGIN TRY EXEC test.CallReturnSafety @retry; END TRY BEGIN CATCH SET @caught=ERROR_NUMBER(); END CATCH;
  IF @caught<>@expected BEGIN PRINT CONCAT(@label,' scenario=',@scenario,' expected=',@expected,' caught=',@caught); THROW 59002,'ASSERT FAIL: mutation did not throw the expected error',1; END;
  EXEC test.ReturnSafetySnapshot @after OUTPUT;
  IF CONVERT(varbinary(max),@before)<>CONVERT(varbinary(max),@after) BEGIN PRINT @label; THROW 59002,'ASSERT FAIL: mutation changed rows',1; END;
  SET @case+=1;
 END;
 -- Permission revocation applies even when the digest matches.
 UPDATE security.StaffBranchAccess SET CanApproveReturns=0 WHERE StaffId=@manager AND BranchId=@branch;
 EXEC test.ReturnSafetySnapshot @before OUTPUT; SET @caught=0;
 BEGIN TRY EXEC test.CallReturnSafety @request; END TRY BEGIN CATCH SET @caught=ERROR_NUMBER(); END CATCH;
 IF @caught<>51529 THROW 59002,'ASSERT FAIL: revoked permission accepted',1;
 EXEC test.ReturnSafetySnapshot @after OUTPUT;
 IF CONVERT(varbinary(max),@before)<>CONVERT(varbinary(max),@after) THROW 59002,'ASSERT FAIL: revoked replay changed rows',1;
 UPDATE security.StaffBranchAccess SET CanApproveReturns=1 WHERE StaffId=@manager AND BranchId=@branch;
 -- Independent current authorization controls. Credit actor differs from its approver.
 DECLARE @authCase int=0,@subject uniqueidentifier,
  @currentActor uniqueidentifier=TRY_CONVERT(uniqueidentifier,JSON_VALUE(@request,'$.actorId'));
 WHILE @authCase<6
 BEGIN
  -- 0/1 disabled actor/approver; 2/3 inactive actor/approver; 4/5 revoked branch access.
  -- Outcome has one supervisor actor; credit exercises both distinct subjects.
  SET @subject=CASE WHEN @authCase%2=0 THEN @currentActor ELSE @manager END;
  IF @authCase<2 UPDATE security.Staff SET IsEnabled=0 WHERE Id=@subject;
  ELSE UPDATE security.StaffBranchAccess SET IsActive=0 WHERE StaffId=@subject AND BranchId=@branch;
  -- Revoked access is absence, rather than only the inactive flag.
  IF @authCase>=4 DELETE security.StaffBranchAccess WHERE StaffId=@subject AND BranchId=@branch;
  EXEC test.ReturnSafetySnapshot @before OUTPUT; SET @caught=0;
  BEGIN TRY EXEC test.CallReturnSafety @request; END TRY BEGIN CATCH SET @caught=ERROR_NUMBER(); END CATCH;
  EXEC test.ReturnSafetySnapshot @after OUTPUT;
  -- Restore before assertions so an expected failure cannot leave a disabled fixture user.
  IF @authCase<2 UPDATE security.Staff SET IsEnabled=1 WHERE Id=@subject;
  ELSE IF @authCase<4 UPDATE security.StaffBranchAccess SET IsActive=1 WHERE StaffId=@subject AND BranchId=@branch;
  ELSE INSERT security.StaffBranchAccess(StaffId,BranchId,CanApproveTransfers,CanApproveReturns,IsActive)
   VALUES(@subject,@branch,CASE WHEN @subject=@manager THEN 1 ELSE 0 END,CASE WHEN @subject=@manager THEN 1 ELSE 0 END,1);
  IF @caught<>51529 THROW 59002,'ASSERT FAIL: disabled/inactive/revoked actor or approver accepted',1;
  IF CONVERT(varbinary(max),@before)<>CONVERT(varbinary(max),@after) THROW 59002,'ASSERT FAIL: unauthorized retry changed financial/sync rows',1;
  SET @authCase+=1;
 END;
 -- Identity excludes the CURRENT authorized supervisor, but original attribution is immutable.
 SET @retry=JSON_MODIFY(@request,CASE WHEN @scenario=2 THEN '$.approvedBy' ELSE '$.actorId' END,
  CONVERT(nvarchar(36),test.Id('supervisorA')));
 EXEC test.ReturnSafetySnapshot @before OUTPUT;
 EXEC test.CallReturnSafety @retry;
 EXEC test.ReturnSafetySnapshot @after OUTPUT;
 IF CONVERT(varbinary(max),@before)<>CONVERT(varbinary(max),@after) THROW 59002,'ASSERT FAIL: different supervisor rewrote original rows',1;
 -- Eligibility is intentionally made stale; snapshots start AFTER fixture changes.
 UPDATE sales.CashTills SET Status='closed',ClosedAt=core.ufn_BusinessNow() WHERE Id=@till;
 UPDATE sales.Sales SET CreatedAt=DATEADD(day,-400,core.ufn_BusinessNow()) WHERE Id=@sale;
 EXEC test.ReturnSafetySnapshot @before OUTPUT;
 EXEC test.CallReturnSafety @request;
 EXEC test.ReturnSafetySnapshot @after OUTPUT;
 IF CONVERT(varbinary(max),@before)<>CONVERT(varbinary(max),@after) THROW 59002,'ASSERT FAIL: closed/expired replay changed rows',1;
 UPDATE sales.CashTills SET Status='open',ClosedAt=NULL WHERE Id=@till;
 -- Simulate a pre-V029 committed row. Never infer a digest from the retry.
 UPDATE sales.SaleReversals SET RequestIdentityVersion=NULL,RequestIdentityHash=NULL WHERE Id=@rev;
 EXEC test.ReturnSafetySnapshot @before OUTPUT; SET @caught=0;
 BEGIN TRY EXEC test.CallReturnSafety @request; END TRY BEGIN CATCH SET @caught=ERROR_NUMBER(); END CATCH;
 IF @caught<>51538 THROW 59002,'ASSERT FAIL: legacy replay accepted',1;
 EXEC test.ReturnSafetySnapshot @after OUTPUT;
 IF CONVERT(varbinary(max),@before)<>CONVERT(varbinary(max),@after) THROW 59002,'ASSERT FAIL: legacy retry backfilled/wrote',1;
 DECLARE @receipt TABLE(Json nvarchar(max));
 INSERT @receipt EXEC sales.usp_GetSaleDetail @branch,@sale;
 IF NOT EXISTS(SELECT 1 FROM @receipt CROSS APPLY OPENJSON(Json,'$.reversals') r WHERE TRY_CONVERT(uniqueidentifier,JSON_VALUE(r.value,'$.reversalId'))=@rev)
  THROW 59002,'ASSERT FAIL: legacy GET receipt lost',1;
 DELETE @receipt;
 DELETE @cases;
 SET @scenario+=1;
END;
-- Positive TWO-original-line ordering equivalence for BOTH endpoints.
DECLARE @orderingEndpoint int=0;
WHILE @orderingEndpoint<2
BEGIN
 DECLARE @orderSale uniqueidentifier=NEWID(),@orderRev uniqueidentifier=NEWID(),@orderCredit uniqueidentifier=NEWID(),
  @orderTill uniqueidentifier=(SELECT TOP(1) Id FROM sales.CashTills WHERE RegisterId=test.Id('registerA') AND Status='open'),
  @orderLines sales.SaleLineRequest,@orderPay sales.SaleTenderRequest;
 INSERT @orderLines VALUES(1,@item,1,120000,0),(2,@item,1,120000,0);
 INSERT @orderPay(TenderNumber,TenderKind,AmountMinor) VALUES(1,'card',240000);
 EXEC sales.usp_PostSale @SaleId=@orderSale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
  @CurrencyCode='NIO',@OriginNodeId=@node,@Lines=@orderLines,@Tenders=@orderPay,@TillId=@orderTill,@CustomerId=@customer;
 DECLARE @forward nvarchar(max)=(SELECT Id AS SaleLineId,1 AS Quantity,'store' AS RestockPool
   FROM sales.SaleLines WHERE SaleId=@orderSale ORDER BY Id FOR JSON PATH),
  @backward nvarchar(max)=(SELECT Id AS SaleLineId,1 AS Quantity,'store' AS RestockPool
   FROM sales.SaleLines WHERE SaleId=@orderSale ORDER BY Id DESC FOR JSON PATH);
 IF (SELECT COUNT(*) FROM sales.SaleLines WHERE SaleId=@orderSale)<>2 OR @forward=@backward
  THROW 59002,'ASSERT FAIL: ordering control needs two distinct original lines',1;
 SET @request=(SELECT @orderRev AS reversalId,@orderSale AS saleId,@branch AS branchId,@loc AS locationId,
  @orderTill AS tillId,@manager AS actorId,@manager AS approvedBy,@orderCredit AS creditId,@customer AS customerId,
  @node AS nodeId,CASE WHEN @orderingEndpoint=1 THEN 'credit' ELSE 'outcome' END AS endpoint,
  'transfer' AS outcome,N'ordering' AS reason,N'BAC ordering' AS reference,JSON_QUERY(@forward) AS returnLines
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
 EXEC test.CallReturnSafety @request;
 IF (SELECT COUNT(*) FROM sales.SaleReversalLines WHERE ReversalId=@orderRev)<>2
  THROW 59002,'ASSERT FAIL: ordering control did not return both lines',1;
 EXEC test.ReturnSafetySnapshot @before OUTPUT;
 SET @retry=JSON_MODIFY(@request,'$.returnLines',JSON_QUERY(@backward));
 EXEC test.CallReturnSafety @retry;
 EXEC test.ReturnSafetySnapshot @after OUTPUT;
 IF CONVERT(varbinary(max),@before)<>CONVERT(varbinary(max),@after)
  THROW 59002,'ASSERT FAIL: reversed original lines changed exact financial/sync images',1;
 EXEC audit.usp_CheckConservation @Throw=1;
 DELETE @orderLines; DELETE @orderPay;
 SET @orderingEndpoint+=1;
END;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';
