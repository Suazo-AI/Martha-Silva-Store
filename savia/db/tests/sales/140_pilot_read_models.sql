-- TEST: Read models use existing domain writes; exact totals, branch scope, literal search, dates and detail.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @sale uniqueidentifier=NEWID(),@foreign uniqueidentifier=NEWID(),@branch uniqueidentifier=test.Id('branchA'),
 @json nvarchar(max),@n bigint,@date date=CONVERT(date,DATEADD(hour,-6,SYSUTCDATETIME()));
EXEC test.SeedSale @sale,'A';
EXEC test.SeedSale @foreign,'B';
DECLARE @result TABLE(Json nvarchar(max));
INSERT INTO @result EXEC sales.usp_SearchSales @BranchId=@branch,@Query=N'Clienta',@PageSize=1;
SELECT @json=Json FROM @result;
SET @n=CONVERT(bigint,JSON_VALUE(@json,'$.total')); EXEC test.AssertEq N'local sale count',1,@n;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@json,'$.items') WITH(saleId uniqueidentifier) WHERE saleId=@sale);
EXEC test.AssertEq N'local sale only',1,@n;
DECLARE @literal TABLE(Json nvarchar(max));
INSERT INTO @literal EXEC sales.usp_SearchSales @BranchId=@branch,@Query=N'%';
SELECT @json=Json FROM @literal; SET @n=CONVERT(bigint,JSON_VALUE(@json,'$.total'));
EXEC test.AssertEq N'literal percent is not a wildcard',0,@n;
IF JSON_QUERY(@json,'$.items')<>N'[]' OR JSON_QUERY(@json,'$.items') IS NULL THROW 59900,'Empty items must be an array.',1;
DECLARE @detail TABLE(Json nvarchar(max));
INSERT INTO @detail EXEC sales.usp_GetSaleDetail @BranchId=@branch,@SaleId=@sale;
SELECT @json=Json FROM @detail;
SET @n=CONVERT(bigint,JSON_VALUE(@json,'$.lines[0].quantity')); EXEC test.AssertEq N'line quantity',1,@n;
SET @n=CONVERT(bigint,JSON_VALUE(@json,'$.lines[0].returnedQuantity')); EXEC test.AssertEq N'returned quantity',0,@n;
SET @n=CONVERT(bigint,JSON_VALUE(@json,'$.tenders[0].amountMinor')); EXEC test.AssertEq N'tender amount',120000,@n;
DECLARE @day TABLE(Json nvarchar(max));
INSERT INTO @day EXEC sales.usp_GetDayReport @BranchId=@branch,@Date=@date;
SELECT @json=Json FROM @day;
SET @n=CONVERT(bigint,JSON_VALUE(@json,'$.salesCount')); EXEC test.AssertEq N'day count excludes foreign sale',1,@n;
SET @n=CONVERT(bigint,JSON_VALUE(@json,'$.unitsSold')); EXEC test.AssertEq N'unit total',1,@n;
SET @n=CONVERT(bigint,JSON_VALUE(@json,'$.totals[0].totalMinor')); EXEC test.AssertEq N'day gross',120000,@n;
SET @n=CONVERT(bigint,JSON_VALUE(@json,'$.tills[0].expectedMinor')); EXEC test.AssertEq N'till expected',220000,@n;
SET @n=CONVERT(bigint,JSON_VALUE(@json,'$.topItems[0].unitsSold')); EXEC test.AssertEq N'top item',1,@n;
DECLARE @customers TABLE(Id uniqueidentifier,CustomerCode nvarchar(40),DisplayName nvarchar(200),Phone nvarchar(40),Email nvarchar(254));
INSERT INTO @customers EXEC crm.usp_SearchCustomers @Query=N'Clienta';
SET @n=(SELECT COUNT(*) FROM @customers); EXEC test.AssertEq N'active customers',2,@n;
EXEC audit.usp_CheckConservation @Throw=1;
DECLARE @empty TABLE(Json nvarchar(max));
INSERT INTO @empty EXEC sales.usp_GetDayReport @BranchId=@branch,@Date='20000101';
SELECT @json=Json FROM @empty;
IF JSON_QUERY(@json,'$.totals') IS NULL OR JSON_QUERY(@json,'$.tenders') IS NULL
 OR JSON_QUERY(@json,'$.returns') IS NULL OR JSON_QUERY(@json,'$.tills') IS NULL OR JSON_QUERY(@json,'$.topItems') IS NULL
 THROW 59900,'Empty day collections must be arrays.',1;
PRINT 'PASS';
