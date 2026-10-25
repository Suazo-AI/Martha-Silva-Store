IF OBJECT_ID(N'[__EFMigrationsHistory]') IS NULL
BEGIN
    CREATE TABLE [__EFMigrationsHistory] (
        [MigrationId] nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32) NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
END;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    IF SCHEMA_ID(N'savia_internal') IS NULL EXEC(N'CREATE SCHEMA [savia_internal];');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE TABLE [savia_internal].[Items] (
        [Id] uniqueidentifier NOT NULL,
        [Sku] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [Name] nvarchar(200) NOT NULL,
        [UnitPriceMinor] bigint NOT NULL,
        [Currency] varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [Active] bit NOT NULL,
        CONSTRAINT [PK_Items] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_InternalItems_Currency] CHECK (DATALENGTH([Currency]) = 3 AND [Currency] COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^A-Z]%' AND [Currency] <> 'XXX'),
        CONSTRAINT [CK_InternalItems_Name] CHECK (LEN(LTRIM(RTRIM([Name]))) > 0),
        CONSTRAINT [CK_InternalItems_Price] CHECK ([UnitPriceMinor] >= 0 AND [UnitPriceMinor] <= 9000000000000),
        CONSTRAINT [CK_InternalItems_Sku] CHECK (LEN([Sku]) BETWEEN 1 AND 64 AND DATALENGTH([Sku]) = LEN([Sku]) AND [Sku] COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^A-Z0-9_.-]%')
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE TABLE [savia_internal].[Locations] (
        [Id] uniqueidentifier NOT NULL,
        [Name] nvarchar(120) NOT NULL,
        [Active] bit NOT NULL,
        CONSTRAINT [PK_Locations] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_InternalLocations_Name] CHECK (LEN(LTRIM(RTRIM([Name]))) > 0)
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE TABLE [savia_internal].[Parties] (
        [Id] uniqueidentifier NOT NULL,
        [Kind] varchar(8) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [Name] nvarchar(200) NOT NULL,
        [Email] nvarchar(254) NULL,
        [Phone] nvarchar(32) NULL,
        [Active] bit NOT NULL,
        CONSTRAINT [PK_Parties] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_InternalParties_Kind] CHECK ([Kind] IN ('customer', 'supplier')),
        CONSTRAINT [CK_InternalParties_Name] CHECK (LEN(LTRIM(RTRIM([Name]))) > 0)
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE TABLE [savia_internal].[Staff] (
        [Id] uniqueidentifier NOT NULL,
        [LoginName] nvarchar(64) NOT NULL,
        [NormalizedLoginName] nvarchar(64) NOT NULL,
        [DisplayName] nvarchar(120) NOT NULL,
        [PasswordHash] nvarchar(512) NOT NULL,
        [Role] nvarchar(20) NOT NULL,
        [Enabled] bit NOT NULL,
        [SecurityVersion] uniqueidentifier NOT NULL,
        [FailedSignIns] int NOT NULL,
        [LockedUntil] datetimeoffset NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        [UpdatedAt] datetimeoffset NOT NULL,
        [RowVersion] rowversion NOT NULL,
        CONSTRAINT [PK_Staff] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_InternalStaff_FailedSignIns] CHECK ([FailedSignIns] >= 0 AND [FailedSignIns] <= 5),
        CONSTRAINT [CK_InternalStaff_Role] CHECK ([Role] IN ('Owner','Manager','Cashier','Inventory'))
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE TABLE [savia_internal].[StockBalances] (
        [ItemId] uniqueidentifier NOT NULL,
        [LocationId] uniqueidentifier NOT NULL,
        [OnHand] int NOT NULL,
        [Reserved] int NOT NULL,
        [UpdatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_StockBalances] PRIMARY KEY ([ItemId], [LocationId]),
        CONSTRAINT [CK_InternalBalance_Bounds] CHECK ([OnHand] >= 0 AND [OnHand] <= 1000000000 AND [Reserved] >= 0 AND [Reserved] <= [OnHand]),
        CONSTRAINT [FK_StockBalances_Items_ItemId] FOREIGN KEY ([ItemId]) REFERENCES [savia_internal].[Items] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_StockBalances_Locations_LocationId] FOREIGN KEY ([LocationId]) REFERENCES [savia_internal].[Locations] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE TABLE [savia_internal].[PurchaseOrders] (
        [Id] uniqueidentifier NOT NULL,
        [SupplierId] uniqueidentifier NOT NULL,
        [LocationId] uniqueidentifier NOT NULL,
        [SupplierName] nvarchar(200) NOT NULL,
        [Currency] varchar(3) NOT NULL,
        [Reference] nvarchar(100) NULL,
        [Status] varchar(24) NOT NULL,
        [TotalMinor] bigint NOT NULL,
        [CreatedBy] uniqueidentifier NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        [UpdatedBy] uniqueidentifier NOT NULL,
        [UpdatedAt] datetimeoffset NOT NULL,
        [CancelledBy] uniqueidentifier NULL,
        [CancelledAt] datetimeoffset NULL,
        [CancellationReason] nvarchar(500) NULL,
        CONSTRAINT [PK_PurchaseOrders] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_InternalPurchaseOrder_Cancel] CHECK (([Status] = 'cancelled' AND [CancelledBy] IS NOT NULL AND [CancelledAt] IS NOT NULL AND [CancellationReason] IS NOT NULL) OR ([Status] <> 'cancelled' AND [CancelledBy] IS NULL AND [CancelledAt] IS NULL AND [CancellationReason] IS NULL)),
        CONSTRAINT [CK_InternalPurchaseOrder_Currency] CHECK ([Currency] COLLATE Latin1_General_100_BIN2 LIKE '[A-Z][A-Z][A-Z]' AND [Currency] <> 'XXX'),
        CONSTRAINT [CK_InternalPurchaseOrder_Status] CHECK ([Status] IN ('open','partially_received','received','cancelled')),
        CONSTRAINT [CK_InternalPurchaseOrder_Total] CHECK ([TotalMinor] >= 0 AND [TotalMinor] <= 9000000000000),
        CONSTRAINT [FK_PurchaseOrders_Locations_LocationId] FOREIGN KEY ([LocationId]) REFERENCES [savia_internal].[Locations] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_PurchaseOrders_Parties_SupplierId] FOREIGN KEY ([SupplierId]) REFERENCES [savia_internal].[Parties] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE TABLE [savia_internal].[Sales] (
        [Id] uniqueidentifier NOT NULL,
        [LocationId] uniqueidentifier NOT NULL,
        [CustomerId] uniqueidentifier NULL,
        [ActorId] uniqueidentifier NOT NULL,
        [Currency] nvarchar(3) NOT NULL,
        [TotalMinor] bigint NOT NULL,
        [State] nvarchar(24) NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_Sales] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_InternalSale_Currency] CHECK (LEN([Currency]) = 3 AND [Currency] COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^A-Z]%' AND [Currency] <> 'XXX'),
        CONSTRAINT [CK_InternalSale_State] CHECK ([State] IN ('recorded','partially_returned','returned','cancelled')),
        CONSTRAINT [CK_InternalSale_Total] CHECK ([TotalMinor] >= 0 AND [TotalMinor] <= 9000000000000),
        CONSTRAINT [FK_Sales_Locations_LocationId] FOREIGN KEY ([LocationId]) REFERENCES [savia_internal].[Locations] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_Sales_Parties_CustomerId] FOREIGN KEY ([CustomerId]) REFERENCES [savia_internal].[Parties] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE TABLE [savia_internal].[Operations] (
        [Id] uniqueidentifier NOT NULL,
        [ActorId] uniqueidentifier NOT NULL,
        [Scope] varchar(80) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [Key] varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [Fingerprint] varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
        [ResultJson] nvarchar(max) NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_Operations] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_Operations_Staff_ActorId] FOREIGN KEY ([ActorId]) REFERENCES [savia_internal].[Staff] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE TABLE [savia_internal].[Sessions] (
        [Id] uniqueidentifier NOT NULL,
        [StaffId] uniqueidentifier NOT NULL,
        [SecurityVersion] uniqueidentifier NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        [ExpiresAt] datetimeoffset NOT NULL,
        [RevokedAt] datetimeoffset NULL,
        CONSTRAINT [PK_Sessions] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_InternalSession_Expiry] CHECK ([ExpiresAt] > [CreatedAt]),
        CONSTRAINT [FK_Sessions_Staff_StaffId] FOREIGN KEY ([StaffId]) REFERENCES [savia_internal].[Staff] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE TABLE [savia_internal].[StockAdjustments] (
        [Id] uniqueidentifier NOT NULL,
        [ItemId] uniqueidentifier NOT NULL,
        [LocationId] uniqueidentifier NOT NULL,
        [OnHandDelta] int NOT NULL,
        [ActorId] uniqueidentifier NOT NULL,
        [Reason] nvarchar(500) NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_StockAdjustments] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_StockAdjustments_StockBalances_ItemId_LocationId] FOREIGN KEY ([ItemId], [LocationId]) REFERENCES [savia_internal].[StockBalances] ([ItemId], [LocationId]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE TABLE [savia_internal].[StockMovements] (
        [Id] uniqueidentifier NOT NULL,
        [ItemId] uniqueidentifier NOT NULL,
        [LocationId] uniqueidentifier NOT NULL,
        [ActorId] uniqueidentifier NOT NULL,
        [OperationId] uniqueidentifier NOT NULL,
        [Kind] nvarchar(40) NOT NULL,
        [OnHandDelta] int NOT NULL,
        [ReservedDelta] int NOT NULL,
        [OnHandAfter] int NOT NULL,
        [ReservedAfter] int NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_StockMovements] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_InternalMovement_After] CHECK ([OnHandAfter] >= 0 AND [OnHandAfter] <= 1000000000 AND [ReservedAfter] >= 0 AND [ReservedAfter] <= [OnHandAfter]),
        CONSTRAINT [CK_InternalMovement_Nonzero] CHECK ([OnHandDelta] <> 0 OR [ReservedDelta] <> 0),
        CONSTRAINT [FK_StockMovements_StockBalances_ItemId_LocationId] FOREIGN KEY ([ItemId], [LocationId]) REFERENCES [savia_internal].[StockBalances] ([ItemId], [LocationId]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE TABLE [savia_internal].[PurchaseOrderLines] (
        [Id] uniqueidentifier NOT NULL,
        [PurchaseOrderId] uniqueidentifier NOT NULL,
        [ItemId] uniqueidentifier NOT NULL,
        [ItemSku] nvarchar(64) NOT NULL,
        [ItemName] nvarchar(200) NOT NULL,
        [Quantity] int NOT NULL,
        [ReceivedQuantity] int NOT NULL,
        [UnitCostMinor] bigint NOT NULL,
        CONSTRAINT [PK_PurchaseOrderLines] PRIMARY KEY ([Id]),
        CONSTRAINT [AK_PurchaseOrderLines_PurchaseOrderId_Id_ItemId] UNIQUE ([PurchaseOrderId], [Id], [ItemId]),
        CONSTRAINT [CK_InternalPurchaseLine_Cost] CHECK ([UnitCostMinor] >= 0 AND [UnitCostMinor] <= 9000000000000 / [Quantity]),
        CONSTRAINT [CK_InternalPurchaseLine_Quantity] CHECK ([Quantity] BETWEEN 1 AND 1000000 AND [ReceivedQuantity] BETWEEN 0 AND [Quantity]),
        CONSTRAINT [FK_PurchaseOrderLines_Items_ItemId] FOREIGN KEY ([ItemId]) REFERENCES [savia_internal].[Items] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_PurchaseOrderLines_PurchaseOrders_PurchaseOrderId] FOREIGN KEY ([PurchaseOrderId]) REFERENCES [savia_internal].[PurchaseOrders] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE TABLE [savia_internal].[PurchaseReceipts] (
        [Id] uniqueidentifier NOT NULL,
        [PurchaseOrderId] uniqueidentifier NOT NULL,
        [LocationId] uniqueidentifier NOT NULL,
        [Currency] varchar(3) NOT NULL,
        [TotalMinor] bigint NOT NULL,
        [Fingerprint] varchar(64) NOT NULL,
        [OrderStatusAfter] varchar(24) NOT NULL,
        [ReceivedBy] uniqueidentifier NOT NULL,
        [ReceivedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_PurchaseReceipts] PRIMARY KEY ([Id]),
        CONSTRAINT [AK_PurchaseReceipts_Id_PurchaseOrderId] UNIQUE ([Id], [PurchaseOrderId]),
        CONSTRAINT [CK_InternalPurchaseReceipt_Currency] CHECK ([Currency] COLLATE Latin1_General_100_BIN2 LIKE '[A-Z][A-Z][A-Z]' AND [Currency] <> 'XXX'),
        CONSTRAINT [CK_InternalPurchaseReceipt_Status] CHECK ([OrderStatusAfter] IN ('partially_received','received')),
        CONSTRAINT [CK_InternalPurchaseReceipt_Total] CHECK ([TotalMinor] >= 0 AND [TotalMinor] <= 9000000000000),
        CONSTRAINT [FK_PurchaseReceipts_Locations_LocationId] FOREIGN KEY ([LocationId]) REFERENCES [savia_internal].[Locations] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_PurchaseReceipts_PurchaseOrders_PurchaseOrderId] FOREIGN KEY ([PurchaseOrderId]) REFERENCES [savia_internal].[PurchaseOrders] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE TABLE [savia_internal].[SaleLines] (
        [Id] uniqueidentifier NOT NULL,
        [SaleId] uniqueidentifier NOT NULL,
        [ItemId] uniqueidentifier NOT NULL,
        [Sku] nvarchar(80) NOT NULL,
        [Name] nvarchar(200) NOT NULL,
        [Quantity] int NOT NULL,
        [ReturnedQuantity] int NOT NULL,
        [UnitPriceMinor] bigint NOT NULL,
        [TotalMinor] bigint NOT NULL,
        CONSTRAINT [PK_SaleLines] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_InternalSaleLine_Amounts] CHECK ([UnitPriceMinor] >= 0 AND [UnitPriceMinor] <= 9000000000000 AND [TotalMinor] >= 0 AND [TotalMinor] <= 9000000000000 AND CAST([UnitPriceMinor] AS decimal(28,0)) * [Quantity] = [TotalMinor]),
        CONSTRAINT [CK_InternalSaleLine_Quantity] CHECK ([Quantity] >= 1 AND [Quantity] <= 1000000 AND [ReturnedQuantity] >= 0 AND [ReturnedQuantity] <= [Quantity]),
        CONSTRAINT [FK_SaleLines_Items_ItemId] FOREIGN KEY ([ItemId]) REFERENCES [savia_internal].[Items] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_SaleLines_Sales_SaleId] FOREIGN KEY ([SaleId]) REFERENCES [savia_internal].[Sales] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE TABLE [savia_internal].[SaleReversals] (
        [Id] uniqueidentifier NOT NULL,
        [SaleId] uniqueidentifier NOT NULL,
        [ActorId] uniqueidentifier NOT NULL,
        [Kind] nvarchar(16) NOT NULL,
        [Reason] nvarchar(500) NOT NULL,
        [RecordedCreditMinor] bigint NOT NULL,
        [CreatedAt] datetimeoffset NOT NULL,
        CONSTRAINT [PK_SaleReversals] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_InternalReversal_Amount] CHECK ([RecordedCreditMinor] >= 0 AND [RecordedCreditMinor] <= 9000000000000),
        CONSTRAINT [CK_InternalReversal_Kind] CHECK ([Kind] IN ('cancel','return')),
        CONSTRAINT [FK_SaleReversals_Sales_SaleId] FOREIGN KEY ([SaleId]) REFERENCES [savia_internal].[Sales] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE TABLE [savia_internal].[PurchaseReceiptLines] (
        [Id] uniqueidentifier NOT NULL,
        [ReceiptId] uniqueidentifier NOT NULL,
        [PurchaseOrderId] uniqueidentifier NOT NULL,
        [PurchaseOrderLineId] uniqueidentifier NOT NULL,
        [ItemId] uniqueidentifier NOT NULL,
        [Quantity] int NOT NULL,
        [UnitCostMinor] bigint NOT NULL,
        CONSTRAINT [PK_PurchaseReceiptLines] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_InternalReceiptLine_Cost] CHECK ([UnitCostMinor] >= 0 AND [UnitCostMinor] <= 9000000000000 / [Quantity]),
        CONSTRAINT [CK_InternalReceiptLine_Quantity] CHECK ([Quantity] BETWEEN 1 AND 1000000),
        CONSTRAINT [FK_PurchaseReceiptLines_Items_ItemId] FOREIGN KEY ([ItemId]) REFERENCES [savia_internal].[Items] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_PurchaseReceiptLines_PurchaseOrderLines_PurchaseOrderId_PurchaseOrderLineId_ItemId] FOREIGN KEY ([PurchaseOrderId], [PurchaseOrderLineId], [ItemId]) REFERENCES [savia_internal].[PurchaseOrderLines] ([PurchaseOrderId], [Id], [ItemId]) ON DELETE NO ACTION,
        CONSTRAINT [FK_PurchaseReceiptLines_PurchaseReceipts_ReceiptId_PurchaseOrderId] FOREIGN KEY ([ReceiptId], [PurchaseOrderId]) REFERENCES [savia_internal].[PurchaseReceipts] ([Id], [PurchaseOrderId]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE TABLE [savia_internal].[SaleReversalLines] (
        [Id] uniqueidentifier NOT NULL,
        [ReversalId] uniqueidentifier NOT NULL,
        [SaleLineId] uniqueidentifier NOT NULL,
        [Quantity] int NOT NULL,
        [RecordedCreditMinor] bigint NOT NULL,
        CONSTRAINT [PK_SaleReversalLines] PRIMARY KEY ([Id]),
        CONSTRAINT [CK_InternalReversalLine_Bounds] CHECK ([Quantity] >= 1 AND [Quantity] <= 1000000 AND [RecordedCreditMinor] >= 0 AND [RecordedCreditMinor] <= 9000000000000),
        CONSTRAINT [FK_SaleReversalLines_SaleLines_SaleLineId] FOREIGN KEY ([SaleLineId]) REFERENCES [savia_internal].[SaleLines] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_SaleReversalLines_SaleReversals_ReversalId] FOREIGN KEY ([ReversalId]) REFERENCES [savia_internal].[SaleReversals] ([Id]) ON DELETE NO ACTION
    );
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_Items_Active_Name] ON [savia_internal].[Items] ([Active], [Name]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE UNIQUE INDEX [IX_Items_Sku] ON [savia_internal].[Items] ([Sku]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_Locations_Active_Name] ON [savia_internal].[Locations] ([Active], [Name]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE UNIQUE INDEX [IX_Operations_ActorId_Scope_Key] ON [savia_internal].[Operations] ([ActorId], [Scope], [Key]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_Parties_Kind_Active_Name] ON [savia_internal].[Parties] ([Kind], [Active], [Name]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_PurchaseOrderLines_ItemId] ON [savia_internal].[PurchaseOrderLines] ([ItemId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE UNIQUE INDEX [IX_PurchaseOrderLines_PurchaseOrderId_ItemId] ON [savia_internal].[PurchaseOrderLines] ([PurchaseOrderId], [ItemId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_PurchaseOrders_CreatedAt_Id] ON [savia_internal].[PurchaseOrders] ([CreatedAt], [Id]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_PurchaseOrders_LocationId] ON [savia_internal].[PurchaseOrders] ([LocationId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_PurchaseOrders_SupplierId] ON [savia_internal].[PurchaseOrders] ([SupplierId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_PurchaseReceiptLines_ItemId] ON [savia_internal].[PurchaseReceiptLines] ([ItemId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_PurchaseReceiptLines_PurchaseOrderId_PurchaseOrderLineId_ItemId] ON [savia_internal].[PurchaseReceiptLines] ([PurchaseOrderId], [PurchaseOrderLineId], [ItemId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_PurchaseReceiptLines_ReceiptId_PurchaseOrderId] ON [savia_internal].[PurchaseReceiptLines] ([ReceiptId], [PurchaseOrderId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE UNIQUE INDEX [IX_PurchaseReceiptLines_ReceiptId_PurchaseOrderLineId] ON [savia_internal].[PurchaseReceiptLines] ([ReceiptId], [PurchaseOrderLineId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_PurchaseReceipts_LocationId] ON [savia_internal].[PurchaseReceipts] ([LocationId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_PurchaseReceipts_PurchaseOrderId_ReceivedAt] ON [savia_internal].[PurchaseReceipts] ([PurchaseOrderId], [ReceivedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_SaleLines_ItemId] ON [savia_internal].[SaleLines] ([ItemId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE UNIQUE INDEX [IX_SaleLines_SaleId_ItemId] ON [savia_internal].[SaleLines] ([SaleId], [ItemId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE UNIQUE INDEX [IX_SaleReversalLines_ReversalId_SaleLineId] ON [savia_internal].[SaleReversalLines] ([ReversalId], [SaleLineId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_SaleReversalLines_SaleLineId] ON [savia_internal].[SaleReversalLines] ([SaleLineId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_SaleReversals_SaleId] ON [savia_internal].[SaleReversals] ([SaleId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_Sales_CreatedAt] ON [savia_internal].[Sales] ([CreatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_Sales_CustomerId] ON [savia_internal].[Sales] ([CustomerId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_Sales_LocationId] ON [savia_internal].[Sales] ([LocationId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_Sessions_StaffId_ExpiresAt] ON [savia_internal].[Sessions] ([StaffId], [ExpiresAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE UNIQUE INDEX [IX_Staff_NormalizedLoginName] ON [savia_internal].[Staff] ([NormalizedLoginName]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_StockAdjustments_ItemId_LocationId] ON [savia_internal].[StockAdjustments] ([ItemId], [LocationId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_StockBalances_LocationId] ON [savia_internal].[StockBalances] ([LocationId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_StockMovements_ItemId_LocationId_CreatedAt] ON [savia_internal].[StockMovements] ([ItemId], [LocationId], [CreatedAt]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    CREATE INDEX [IX_StockMovements_OperationId] ON [savia_internal].[StockMovements] ([OperationId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261025085402_InitialInternalSavia'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20261025085402_InitialInternalSavia', N'10.0.13');
END;

COMMIT;
GO
