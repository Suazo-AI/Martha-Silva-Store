-- TEST: D-039 reference data (V053). The hub owns catalog, prices, suppliers, seller rates and exchange rates: its batch carries them to a store, and the hub refuses them from a store. The store that creates a customer owns that row; two customers with one document are flagged for review, never merged. Every synced parent applies before its child.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@b uniqueidentifier=test.Id('nodeB'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @branchA uniqueidentifier=test.Id('branchA'),@cashierA uniqueidentifier=test.Id('cashierA'),@cashierB uniqueidentifier=test.Id('cashierB'),@manager uniqueidentifier=test.Id('manager'),
  @item uniqueidentifier=test.Id('item'),@mine uniqueidentifier=NEWID(),@twin uniqueidentifier=NEWID(),
  @state nvarchar(max),@plan nvarchar(max),@p nvarchar(max),@bad nvarchar(max),@r nvarchar(max),@n bigint,@err int;

SET @n=(SELECT COUNT(*) FROM sync.SyncTables WHERE TableName IN (N'[core].[Currencies]',N'[catalog].[Categories]',N'[catalog].[Brands]',
  N'[catalog].[Sizes]',N'[catalog].[Colors]',N'[sourcing].[Suppliers]',N'[catalog].[Products]',N'[catalog].[Items]',
  N'[catalog].[ItemIdentifiers]',N'[catalog].[PriceHistory]',N'[catalog].[ItemValueHistory]',N'[catalog].[ItemImages]',
  N'[core].[ExchangeRates]',N'[sales].[SellerRates]',N'[sales].[SellerRateHistory]',N'[crm].[Customers]'));
EXEC test.AssertEq N'the reference tables and customers are synced',16,@n;
SET @n=(SELECT COUNT(*) FROM sys.foreign_keys f
        JOIN sync.SyncTables c ON OBJECT_ID(c.TableName)=f.parent_object_id
        JOIN sync.SyncTables p ON OBJECT_ID(p.TableName)=f.referenced_object_id
        WHERE f.parent_object_id<>f.referenced_object_id AND p.ApplyOrder>=c.ApplyOrder);
EXEC test.AssertEq N'every synced parent applies before its child',0,@n;

-- Store A creates a customer: A owns it. The document is stored in one form so the duplicate check compares like with like.
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC crm.usp_CreateCustomer @CustomerId=@mine,@DisplayName=N'Ana Lopez',@DocumentNumber=N'001-010190-0001a',@Phone=NULL,@Email=NULL,@ActorId=@cashierA;
EXEC crm.usp_CreateCustomer @CustomerId=@mine,@DisplayName=N'Ana Lopez',@DocumentNumber=N'001-010190-0001a',@Phone=NULL,@Email=NULL,@ActorId=@cashierA;
SET @n=(SELECT COUNT(*) FROM crm.Customers WHERE Id=@mine AND OriginBranchId=@branchA AND DocumentNumber=N'0010101900001A' AND CustomerCode IS NULL);
EXEC test.AssertEq N'the store that creates a customer is its origin; a retry adds nothing',1,@n;
SET @err=0;
BEGIN TRY EXEC crm.usp_CreateCustomer @CustomerId=@mine,@DisplayName=N'Otra persona',@DocumentNumber=NULL,@Phone=NULL,@Email=NULL,@ActorId=@cashierA;
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'an id reused for another customer is refused',52004,@err;

-- Push A -> hub carries A's customer and no catalog row.
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_PlanJson @PeerNodeId=@a,@StateJson=@state,@Json=@plan OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_ReadBatch @TargetNodeId=@cloud,@PlanJson=@plan,@Json=@p OUTPUT;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@p,'$.tables') t CROSS APPLY OPENJSON(t.value,'$.rows') WITH (Id uniqueidentifier) r
        WHERE JSON_VALUE(t.value,'$.t')=N'[crm].[Customers]' AND r.Id=@mine);
EXEC test.AssertEq N'the store sends its own customer',1,@n;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@p,'$.tables') t CROSS APPLY OPENJSON(t.value,'$.rows')
        WHERE JSON_VALUE(t.value,'$.t')=N'[catalog].[Items]');
EXEC test.AssertEq N'the store sends no catalog row',0,@n;
UPDATE sync.LocalNode SET NodeId=@cloud;
-- A store cannot write the hub's catalog: an item row in its push is refused. Then the genuine push applies.
SET @bad=JSON_MODIFY(@p,'$.tables',JSON_QUERY(N'[{"t":"[catalog].[Items]","a":"initial","f":null,"rows":'
  +(SELECT * FROM catalog.Items WHERE Id=@item FOR JSON PATH, INCLUDE_NULL_VALUES)+N'}]'));
SET @err=0;
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@bad,@Json=@r OUTPUT; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'the hub refuses a catalog row from a store',51851,@err;
EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@p,@Json=@r OUTPUT;

-- The hub changes a price and sets a rate. Its batch for A carries both, not A's own customer, and A applies it
-- (one MERGE per table: an INSTEAD OF trigger on a target would fail that MERGE).
UPDATE catalog.Items SET UnitPriceMinor=UnitPriceMinor+100,ModifiedAt=SYSUTCDATETIME() WHERE Id=@item;
SET @r=CONVERT(nvarchar(36),NEWID());
EXEC core.usp_SetExchangeRate @Id=@r,@EffectiveFrom='2099-01-01',@Rate=36.6243,@ActorId=@manager,@Reason=N'Tasa del hub';
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_PlanJson @PeerNodeId=@cloud,@StateJson=@state,@Json=@plan OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_ReadBatch @TargetNodeId=@a,@PlanJson=@plan,@Json=@p OUTPUT;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@p,'$.tables') t CROSS APPLY OPENJSON(t.value,'$.rows') WITH (Id uniqueidentifier) r
        WHERE JSON_VALUE(t.value,'$.t')=N'[catalog].[Items]' AND r.Id=@item);
EXEC test.AssertEq N'the hub sends its catalog to a store',1,@n;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@p,'$.tables') t CROSS APPLY OPENJSON(t.value,'$.rows') WITH (Id uniqueidentifier) r
        WHERE JSON_VALUE(t.value,'$.t')=N'[crm].[Customers]' AND r.Id=@mine);
EXEC test.AssertEq N'the hub does not send A its own customer',0,@n;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@p,'$.tables') t CROSS APPLY OPENJSON(t.value,'$.rows')
        WHERE JSON_VALUE(t.value,'$.t')=N'[core].[ExchangeRates]');
IF @n=0 THROW 50000,'FAIL: the fixture has no exchange rate to carry',1;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_ApplyBatch @PeerNodeId=@cloud,@BatchJson=@p,@Json=@r OUTPUT;
SET @n=(SELECT COUNT(*) FROM sync.PeerCursors WHERE PeerNodeId=@cloud AND TableName=N'[core].[ExchangeRates]');
EXEC test.AssertEq N'a store applies the hub exchange rates',1,@n;
SET @err=0;
BEGIN TRY UPDATE core.ExchangeRates SET EffectiveFrom=EffectiveFrom; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'exchange rates stay immutable',52107,@err;

-- Store B registers the same person again: both rows stay, and the hub view flags the pair.
UPDATE sync.LocalNode SET NodeId=@b;
EXEC crm.usp_CreateCustomer @CustomerId=@twin,@DisplayName=N'Ana M. Lopez',@DocumentNumber=N'001 010190 0001A',@Phone=NULL,@Email=NULL,@ActorId=@cashierB;
SET @n=(SELECT COUNT(*) FROM crm.Customers WHERE Id IN (@mine,@twin)); EXEC test.AssertEq N'two customers with one document are not merged',2,@n;
SET @n=(SELECT COUNT(*) FROM crm.vw_DuplicateCustomerDocuments WHERE DocumentNumber=N'0010101900001A' AND CustomerId IN (@mine,@twin));
EXEC test.AssertEq N'the duplicate document is flagged on both rows',2,@n;
PRINT 'PASS';
