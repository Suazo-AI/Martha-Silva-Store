-- A normal sale stores no identity. A manager may choose the recipient only when issuing the return advance.
DECLARE @definition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'sales.usp_PostCreditReturn'));
IF CHARINDEX(N'@saleCustomer IS NULL OR @saleCustomer<>@CustomerId',@definition)=0 THROW 52007,'Return contract incompatible.',1;
SET @definition=REPLACE(REPLACE(@definition,N'CREATE   PROCEDURE',N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE',N'CREATE OR ALTER PROCEDURE');
SET @definition=REPLACE(@definition,N'@saleCustomer IS NULL OR @saleCustomer<>@CustomerId',N'(@saleCustomer IS NOT NULL AND @saleCustomer<>@CustomerId) OR @CustomerId IS NULL OR NOT EXISTS(SELECT 1 FROM crm.Customers WHERE Id=@CustomerId AND IsActive=1)');
SET @definition=REPLACE(@definition,N'EXEC credits.usp_IssueFromReturn @CreditId,@ReversalId,@ActorId',N'EXEC credits.usp_IssueFromReturn @CreditId,@ReversalId,@ActorId,@CustomerId');
EXEC sys.sp_executesql @definition;
GO
DECLARE @definition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'credits.usp_IssueFromReturn'));
SET @definition=REPLACE(REPLACE(@definition,N'CREATE   PROCEDURE',N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE',N'CREATE OR ALTER PROCEDURE');
SET @definition=REPLACE(@definition,N'@CreditId uniqueidentifier,@ReversalId uniqueidentifier,@ActorId uniqueidentifier',N'@CreditId uniqueidentifier,@ReversalId uniqueidentifier,@ActorId uniqueidentifier,@CustomerId uniqueidentifier=NULL');
SET @definition=REPLACE(@definition,N'@customer=s.CustomerId',N'@customer=COALESCE(s.CustomerId,@CustomerId)');
EXEC sys.sp_executesql @definition;
GO
