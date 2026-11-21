BEGIN TRANSACTION;
DROP TABLE [savia_internal].[StockExceptionReviews];

ALTER TABLE [savia_internal].[SaleLines] DROP CONSTRAINT [CK_InternalSaleLine_Exception];

DECLARE @var nvarchar(max);
SELECT @var = QUOTENAME([d].[name])
FROM [sys].[default_constraints] [d]
INNER JOIN [sys].[columns] [c] ON [d].[parent_column_id] = [c].[column_id] AND [d].[parent_object_id] = [c].[object_id]
WHERE ([d].[parent_object_id] = OBJECT_ID(N'[savia_internal].[SaleLines]') AND [c].[name] = N'ExceptionReason');
IF @var IS NOT NULL EXEC(N'ALTER TABLE [savia_internal].[SaleLines] DROP CONSTRAINT ' + @var + ';');
ALTER TABLE [savia_internal].[SaleLines] DROP COLUMN [ExceptionReason];

DECLARE @var1 nvarchar(max);
SELECT @var1 = QUOTENAME([d].[name])
FROM [sys].[default_constraints] [d]
INNER JOIN [sys].[columns] [c] ON [d].[parent_column_id] = [c].[column_id] AND [d].[parent_object_id] = [c].[object_id]
WHERE ([d].[parent_object_id] = OBJECT_ID(N'[savia_internal].[SaleLines]') AND [c].[name] = N'Size');
IF @var1 IS NOT NULL EXEC(N'ALTER TABLE [savia_internal].[SaleLines] DROP CONSTRAINT ' + @var1 + ';');
ALTER TABLE [savia_internal].[SaleLines] DROP COLUMN [Size];

DELETE FROM [__EFMigrationsHistory]
WHERE [MigrationId] = N'20261106071201_PhysicalStockException';

COMMIT;
GO

BEGIN TRANSACTION;
DROP TABLE [savia_internal].[BranchAssignmentAudit];

ALTER TABLE [savia_internal].[Staff] DROP CONSTRAINT [FK_Staff_Branches_BranchId];

ALTER TABLE [savia_internal].[Locations] DROP CONSTRAINT [FK_Locations_Branches_BranchId];

DROP INDEX [IX_Staff_BranchId] ON [savia_internal].[Staff];

DROP INDEX [IX_Locations_BranchId] ON [savia_internal].[Locations];

DROP INDEX [IX_Operations_OriginalBranchId] ON [savia_internal].[Operations];

DECLARE @var2 nvarchar(max);
SELECT @var2 = QUOTENAME([d].[name])
FROM [sys].[default_constraints] [d]
INNER JOIN [sys].[columns] [c] ON [d].[parent_column_id] = [c].[column_id] AND [d].[parent_object_id] = [c].[object_id]
WHERE ([d].[parent_object_id] = OBJECT_ID(N'[savia_internal].[Staff]') AND [c].[name] = N'BranchId');
IF @var2 IS NOT NULL EXEC(N'ALTER TABLE [savia_internal].[Staff] DROP CONSTRAINT ' + @var2 + ';');
ALTER TABLE [savia_internal].[Staff] DROP COLUMN [BranchId];

DECLARE @var3 nvarchar(max);
SELECT @var3 = QUOTENAME([d].[name])
FROM [sys].[default_constraints] [d]
INNER JOIN [sys].[columns] [c] ON [d].[parent_column_id] = [c].[column_id] AND [d].[parent_object_id] = [c].[object_id]
WHERE ([d].[parent_object_id] = OBJECT_ID(N'[savia_internal].[Locations]') AND [c].[name] = N'BranchId');
IF @var3 IS NOT NULL EXEC(N'ALTER TABLE [savia_internal].[Locations] DROP CONSTRAINT ' + @var3 + ';');
ALTER TABLE [savia_internal].[Locations] DROP COLUMN [BranchId];

DECLARE @var4 nvarchar(max);
SELECT @var4 = QUOTENAME([d].[name])
FROM [sys].[default_constraints] [d]
INNER JOIN [sys].[columns] [c] ON [d].[parent_column_id] = [c].[column_id] AND [d].[parent_object_id] = [c].[object_id]
WHERE ([d].[parent_object_id] = OBJECT_ID(N'[savia_internal].[Operations]') AND [c].[name] = N'LocationId');
IF @var4 IS NOT NULL EXEC(N'ALTER TABLE [savia_internal].[Operations] DROP CONSTRAINT ' + @var4 + ';');
ALTER TABLE [savia_internal].[Operations] DROP COLUMN [LocationId];

DECLARE @var5 nvarchar(max);
SELECT @var5 = QUOTENAME([d].[name])
FROM [sys].[default_constraints] [d]
INNER JOIN [sys].[columns] [c] ON [d].[parent_column_id] = [c].[column_id] AND [d].[parent_object_id] = [c].[object_id]
WHERE ([d].[parent_object_id] = OBJECT_ID(N'[savia_internal].[Operations]') AND [c].[name] = N'OriginalBranchId');
IF @var5 IS NOT NULL EXEC(N'ALTER TABLE [savia_internal].[Operations] DROP CONSTRAINT ' + @var5 + ';');
ALTER TABLE [savia_internal].[Operations] DROP COLUMN [OriginalBranchId];

DROP TABLE [savia_internal].[Branches];

DELETE FROM [__EFMigrationsHistory]
WHERE [MigrationId] = N'20261027224500_InternalBranchScope';

COMMIT;
GO

BEGIN TRANSACTION;
DROP TABLE [savia_internal].[Operations];

DROP TABLE [savia_internal].[PurchaseReceiptLines];

DROP TABLE [savia_internal].[SaleReversalLines];

DROP TABLE [savia_internal].[Sessions];

DROP TABLE [savia_internal].[StockAdjustments];

DROP TABLE [savia_internal].[StockMovements];

DROP TABLE [savia_internal].[PurchaseOrderLines];

DROP TABLE [savia_internal].[PurchaseReceipts];

DROP TABLE [savia_internal].[SaleLines];

DROP TABLE [savia_internal].[SaleReversals];

DROP TABLE [savia_internal].[Staff];

DROP TABLE [savia_internal].[StockBalances];

DROP TABLE [savia_internal].[PurchaseOrders];

DROP TABLE [savia_internal].[Sales];

DROP TABLE [savia_internal].[Items];

DROP TABLE [savia_internal].[Locations];

DROP TABLE [savia_internal].[Parties];

DELETE FROM [__EFMigrationsHistory]
WHERE [MigrationId] = N'20261025085402_InitialInternalSavia';

COMMIT;
GO

