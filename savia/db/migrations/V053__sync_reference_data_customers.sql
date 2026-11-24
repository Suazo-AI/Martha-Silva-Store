-- V053: S4 in docs/production-20261122/README.md (D-039, GAPS G1). Reference data and customers travel by sync.
-- 1. The hub owns the catalog (currencies, categories, brands, sizes, colors, products, items, identifiers, price and
--    value history, images), suppliers, seller rates and exchange rates. Their owner expression names the hub node:
--    a store never sends them, the hub refuses them from a store (51851), and the hub sends them to every store.
-- 2. crm.Customers gains OriginBranchId and DocumentNumber. A customer created at a store belongs to that store's
--    node; a customer without origin belongs to the hub. crm.usp_CreateCustomer is the write. Two customers with one
--    document are listed by crm.vw_DuplicateCustomerDocuments for review and never merged.
-- 3. These tables apply before every transactional table that references them, so they take orders -16 to -1:
--    orders 1 to 23 stay as they are.
-- 4. core.tr_ExchangeRates_Immutable becomes an AFTER trigger. MERGE refuses a target that has an INSTEAD OF trigger
--    for some of its actions (Msg 5316); updates and deletes are still refused with 52107.
-- 5. savia_api_host gets the grants V035 gives every synced table (dynamic SQL in usp_ReadBatch and usp_ApplyBatch).
-- Not synced: security.Staff (each store writes sign-in state), core.Branches, core.Locations, sales.CashRegisters and
-- sync.Nodes. Every node is provisioned with them, with the same ids.
-- Not transactional, like V038: Change Tracking is enabled table by table.

ALTER TABLE [crm].[Customers] ADD
  [OriginBranchId] uniqueidentifier NULL CONSTRAINT [FK_Customers_OriginBranch] REFERENCES [core].[Branches]([Id]),
  [DocumentNumber] nvarchar(32) NULL;
GO
CREATE INDEX [IX_Customers_Document] ON [crm].[Customers]([DocumentNumber]) WHERE [DocumentNumber] IS NOT NULL;
GO

CREATE OR ALTER TRIGGER [core].[tr_ExchangeRates_Immutable] ON [core].[ExchangeRates] AFTER UPDATE,DELETE
AS
BEGIN
 -- Rate history is append-only even for direct SQL writes. A statement that touched no row is not a change.
 IF EXISTS(SELECT 1 FROM deleted) THROW 52107,'Las tasas son inmutables; cree una nueva fecha.',1;
END;
GO

ALTER TABLE [core].[Currencies] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [catalog].[Categories] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [catalog].[Brands] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [catalog].[Sizes] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [catalog].[Colors] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [sourcing].[Suppliers] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [catalog].[Products] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [catalog].[Items] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [catalog].[ItemIdentifiers] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [catalog].[PriceHistory] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [catalog].[ItemValueHistory] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [catalog].[ItemImages] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [core].[ExchangeRates] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [sales].[SellerRates] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [sales].[SellerRateHistory] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [crm].[Customers] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
GO

DECLARE @hub nvarchar(100)=N'(SELECT n.Id FROM sync.Nodes n WHERE n.Kind=''azure'')';
INSERT INTO sync.SyncTables(TableName,ApplyOrder,OwnerExpr)
SELECT v.t,v.o,ISNULL(v.e,@hub)
FROM (VALUES
 (N'[core].[Currencies]',-16,NULL),
 (N'[catalog].[Categories]',-15,NULL),
 (N'[catalog].[Brands]',-14,NULL),
 (N'[catalog].[Sizes]',-13,NULL),
 (N'[catalog].[Colors]',-12,NULL),
 (N'[sourcing].[Suppliers]',-11,NULL),
 (N'[catalog].[Products]',-10,NULL),
 (N'[catalog].[Items]',-9,NULL),
 (N'[catalog].[ItemIdentifiers]',-8,NULL),
 (N'[catalog].[PriceHistory]',-7,NULL),
 (N'[catalog].[ItemValueHistory]',-6,NULL),
 (N'[catalog].[ItemImages]',-5,NULL),
 (N'[core].[ExchangeRates]',-4,NULL),
 (N'[sales].[SellerRates]',-3,NULL),
 (N'[sales].[SellerRateHistory]',-2,NULL),
 (N'[crm].[Customers]',-1,N'(SELECT n.Id FROM sync.Nodes n WHERE (t.OriginBranchId IS NULL AND n.Kind=''azure'') OR (n.Kind=''branch'' AND n.BranchId=t.OriginBranchId))')
) v(t,o,e);
GO

DECLARE @grants nvarchar(max)=(
  SELECT STRING_AGG(CONVERT(nvarchar(max),
           N'GRANT INSERT, UPDATE, VIEW CHANGE TRACKING ON OBJECT::'+TableName+N' TO [savia_api_host];'),NCHAR(10))
  FROM sync.SyncTables WHERE ApplyOrder<0);
EXEC sys.sp_executesql @grants;
GO

-- A store creates a customer offline. The origin is this node's branch, so the row travels as that store's own.
-- The document is kept without separators and in upper case, so the duplicate view compares one form.
CREATE OR ALTER PROCEDURE [crm].[usp_CreateCustomer]
 @CustomerId uniqueidentifier,@DisplayName nvarchar(200),@DocumentNumber nvarchar(40),@Phone nvarchar(40),
 @Email nvarchar(254),@ActorId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @name nvarchar(200)=NULLIF(LTRIM(RTRIM(@DisplayName)),N''),
   @doc nvarchar(40)=NULLIF(UPPER(REPLACE(REPLACE(REPLACE(@DocumentNumber,N'-',N''),N' ',N''),N'.',N'')),N''),
   @origin uniqueidentifier=(SELECT n.BranchId FROM sync.LocalNode l JOIN sync.Nodes n ON n.Id=l.NodeId WHERE n.Kind='branch');
 IF @CustomerId IS NULL OR @name IS NULL OR LEN(@doc)>32 THROW 51902,'Nombre o documento del cliente invalido.',1;
 INSERT crm.Customers(Id,DisplayName,DocumentNumber,Phone,Email,OriginBranchId,CreatedBy)
 SELECT @CustomerId,@name,@doc,NULLIF(LTRIM(RTRIM(@Phone)),N''),NULLIF(LTRIM(RTRIM(@Email)),N''),@origin,@ActorId
 WHERE NOT EXISTS(SELECT 1 FROM crm.Customers WITH (UPDLOCK,HOLDLOCK) WHERE Id=@CustomerId);
 -- A retry of the same request is a no-op; the same id for another person is a client error.
 IF @@ROWCOUNT=0 AND NOT EXISTS(SELECT 1 FROM crm.Customers WHERE Id=@CustomerId AND DisplayName=@name
                                AND ISNULL(DocumentNumber,N'')=ISNULL(@doc,N''))
   THROW 52004,'El identificador ya pertenece a otro cliente.',1;
END;
GO

-- Each customer whose document another customer also holds. Review decides; sync never merges two rows.
CREATE OR ALTER VIEW [crm].[vw_DuplicateCustomerDocuments]
AS
SELECT c.DocumentNumber,c.Id AS CustomerId,c.DisplayName,c.OriginBranchId,c.CreatedAt
FROM crm.Customers c
WHERE c.DocumentNumber IS NOT NULL
  AND EXISTS(SELECT 1 FROM crm.Customers d WHERE d.DocumentNumber=c.DocumentNumber AND d.Id<>c.Id);
GO
