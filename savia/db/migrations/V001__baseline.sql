/* SAVIA V001 baseline. GENERATED FILE: do not edit by hand.
   Source: db/handoff-20261112/SAVIA_DB_AzureSQL_Instalar_En_BD_Existente.sql
   Source SHA-256: 5ad497342c1c04aab9b6a4b96fc55dea3029967cf169b845452b3727f1da48d9
   Generator: tools/db/build_baseline.py (named corrections F-001..F-007).
   Run against an EMPTY database chosen by the caller. No CREATE DATABASE, USE or DROP. */
-- F-001: the draft never set these options; filtered indexes then fail with Msg 1934
-- and procedures would be stored with QUOTED_IDENTIFIER OFF.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO
/* SAVIA — Instalador Azure SQL Database para BASE NUEVA.
   IMPORTANTE: Conectarse directamente a la BD Azure antes de abrir este archivo.
   Sin CREATE DATABASE, USE, DROP ni migracion de esquema legado. */
SET NOCOUNT ON;
GO

-- ======= INICIO 01_SAVIA_Schemas_Tables_Indexes.sql =======
/*
SAVIA — Arquitectura Offline-First / SQL Server 2022 + Azure SQL Database
BASE DE DATOS NUEVA. Este instalador es un modelo greenfield, NO es una migración
de la BD legado savia_internal. No contiene DROP ni TRUNCATE.
Dinero en UNIDADES MENORES de la moneda. Tiempos UTC (datetime2).
Las operaciones de cajas, inventario y créditos deben pasar por la API y
procedimientos autorizados. No conceder UPDATE directo sobre ledgers/saldos.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO
IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'catalog')
    THROW 50001, 'SAVIA: schema catalog ya existe. Instalacion solo sobre base vacia; usar migraciones para actualizaciones.', 1;
GO

EXEC(N'CREATE SCHEMA [core] AUTHORIZATION [dbo]');
GO
EXEC(N'CREATE SCHEMA [security] AUTHORIZATION [dbo]');
GO
EXEC(N'CREATE SCHEMA [crm] AUTHORIZATION [dbo]');
GO
EXEC(N'CREATE SCHEMA [sourcing] AUTHORIZATION [dbo]');
GO
EXEC(N'CREATE SCHEMA [catalog] AUTHORIZATION [dbo]');
GO
EXEC(N'CREATE SCHEMA [inventory] AUTHORIZATION [dbo]');
GO
EXEC(N'CREATE SCHEMA [purchasing] AUTHORIZATION [dbo]');
GO
EXEC(N'CREATE SCHEMA [receiving] AUTHORIZATION [dbo]');
GO
EXEC(N'CREATE SCHEMA [sales] AUTHORIZATION [dbo]');
GO
EXEC(N'CREATE SCHEMA [credits] AUTHORIZATION [dbo]');
GO
EXEC(N'CREATE SCHEMA [webstore] AUTHORIZATION [dbo]');
GO
EXEC(N'CREATE SCHEMA [labels] AUTHORIZATION [dbo]');
GO
EXEC(N'CREATE SCHEMA [accounting] AUTHORIZATION [dbo]');
GO
EXEC(N'CREATE SCHEMA [sync] AUTHORIZATION [dbo]');
GO
EXEC(N'CREATE SCHEMA [audit] AUTHORIZATION [dbo]');
GO

-- TABLAS (DEPENDENCIAS EN ORDEN)

CREATE TABLE [core].[Currencies] (
  [Code] varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [Name] nvarchar(80) NOT NULL,
  [Exponent] tinyint NOT NULL,
  [IsActive] bit NOT NULL CONSTRAINT [DF_Currencies_Active] DEFAULT(1),
  CONSTRAINT [PK_Currencies] PRIMARY KEY ([Code]),
  CONSTRAINT [CK_Currencies_Code] CHECK (LEN([Code])=3 AND [Code] NOT LIKE '%[^A-Z]%'),
  CONSTRAINT [CK_Currencies_Exponent] CHECK ([Exponent] BETWEEN 0 AND 4)
);
GO

CREATE TABLE [core].[Branches] (
  [Id] uniqueidentifier NOT NULL CONSTRAINT [DF_Branches_Id] DEFAULT(NEWID()),
  [Code] varchar(20) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [Name] nvarchar(150) NOT NULL,
  [StoreDisplayName] nvarchar(150) NOT NULL,
  [IsActive] bit NOT NULL CONSTRAINT [DF_Branches_Active] DEFAULT(1),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_core_Branches_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_Branches] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_Branches_Code] UNIQUE ([Code]),
  CONSTRAINT [CK_Branches_Names] CHECK (LEN(LTRIM(RTRIM([Name])))>0 AND LEN(LTRIM(RTRIM([StoreDisplayName])))>0)
);
GO

CREATE TABLE [core].[Locations] (
  [Id] uniqueidentifier NOT NULL CONSTRAINT [DF_Locations_Id] DEFAULT(NEWID()),
  [BranchId] uniqueidentifier NOT NULL,
  [Code] varchar(30) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [Name] nvarchar(150) NOT NULL,
  [Kind] varchar(16) NOT NULL,
  [IsActive] bit NOT NULL CONSTRAINT [DF_Locations_Active] DEFAULT(1),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_core_Locations_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_Locations] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_Locations_Code] UNIQUE ([Code]),
  CONSTRAINT [UQ_Locations_Id_Branch] UNIQUE ([Id],[BranchId]),
  CONSTRAINT [FK_Locations_Branches] FOREIGN KEY ([BranchId]) REFERENCES [core].[Branches]([Id]),
  CONSTRAINT [CK_Locations_Kind] CHECK ([Kind] IN ('store','warehouse','transit','returns'))
);
GO

CREATE TABLE [core].[SystemSettings] (
  [SettingKey] nvarchar(100) NOT NULL,
  [SettingValue] nvarchar(1000) NOT NULL,
  [ScopeBranchId] uniqueidentifier NULL,
  [Description] nvarchar(200) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_core_SystemSettings_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_SystemSettings] PRIMARY KEY ([SettingKey]),
  CONSTRAINT [FK_Settings_Branch] FOREIGN KEY ([ScopeBranchId]) REFERENCES [core].[Branches]([Id])
);
GO

CREATE TABLE [security].[Staff] (
  [Id] uniqueidentifier NOT NULL CONSTRAINT [DF_Staff_Id] DEFAULT(NEWID()),
  [LoginName] nvarchar(64) NOT NULL,
  [NormalizedLoginName] nvarchar(64) NOT NULL,
  [DisplayName] nvarchar(120) NOT NULL,
  [PasswordHash] nvarchar(512) NULL,
  [SecurityVersion] uniqueidentifier NOT NULL CONSTRAINT [DF_Staff_SecurityVersion] DEFAULT(NEWID()),
  [FailedSignIns] smallint NOT NULL CONSTRAINT [DF_Staff_Failed] DEFAULT(0),
  [LockedUntil] datetime2(3) NULL,
  [IsEnabled] bit NOT NULL CONSTRAINT [DF_Staff_Enabled] DEFAULT(1),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_security_Staff_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_Staff] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_Staff_Login] UNIQUE ([NormalizedLoginName]),
  CONSTRAINT [CK_Staff_Failed] CHECK ([FailedSignIns] BETWEEN 0 AND 20),
  CONSTRAINT [CK_Staff_Login] CHECK (LEN(LTRIM(RTRIM([LoginName])))>0)
);
GO

CREATE TABLE [security].[Roles] (
  [Id] uniqueidentifier NOT NULL CONSTRAINT [DF_Roles_Id] DEFAULT(NEWID()),
  [Code] varchar(30) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [Description] nvarchar(200) NOT NULL,
  [IsActive] bit NOT NULL CONSTRAINT [DF_Roles_Active] DEFAULT(1),
  CONSTRAINT [PK_Roles] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_Roles_Code] UNIQUE ([Code])
);
GO

CREATE TABLE [security].[StaffRoles] (
  [StaffId] uniqueidentifier NOT NULL,
  [RoleId] uniqueidentifier NOT NULL,
  [AssignedAt] datetime2(3) NOT NULL CONSTRAINT [DF_StaffRoles_AssignedAt] DEFAULT(SYSUTCDATETIME()),
  [AssignedBy] uniqueidentifier NULL,
  CONSTRAINT [PK_StaffRoles] PRIMARY KEY ([StaffId],[RoleId]),
  CONSTRAINT [FK_StaffRoles_Staff] FOREIGN KEY ([StaffId]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [FK_StaffRoles_Role] FOREIGN KEY ([RoleId]) REFERENCES [security].[Roles]([Id])
);
GO

CREATE TABLE [security].[StaffBranchAccess] (
  [StaffId] uniqueidentifier NOT NULL,
  [BranchId] uniqueidentifier NOT NULL,
  [CanApproveTransfers] bit NOT NULL CONSTRAINT [DF_StaffBranch_Transfer] DEFAULT(0),
  [CanApproveReturns] bit NOT NULL CONSTRAINT [DF_StaffBranch_Returns] DEFAULT(0),
  [IsActive] bit NOT NULL CONSTRAINT [DF_StaffBranch_Active] DEFAULT(1),
  CONSTRAINT [PK_StaffBranch] PRIMARY KEY ([StaffId],[BranchId]),
  CONSTRAINT [FK_StaffBranch_Staff] FOREIGN KEY ([StaffId]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [FK_StaffBranch_Branch] FOREIGN KEY ([BranchId]) REFERENCES [core].[Branches]([Id])
);
GO

CREATE TABLE [security].[Sessions] (
  [Id] uniqueidentifier NOT NULL CONSTRAINT [DF_Sessions_Id] DEFAULT(NEWID()),
  [StaffId] uniqueidentifier NOT NULL,
  [SecurityVersion] uniqueidentifier NOT NULL,
  [ExpiresAt] datetime2(3) NOT NULL,
  [RevokedAt] datetime2(3) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_security_Sessions_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_Sessions] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_Sessions_Staff] FOREIGN KEY ([StaffId]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [CK_Sessions_Expires] CHECK ([ExpiresAt]>[CreatedAt])
);
GO

CREATE TABLE [security].[BranchAssignmentAudit] (
  [Id] uniqueidentifier NOT NULL CONSTRAINT [DF_BranchAudit_Id] DEFAULT(NEWID()),
  [StaffId] uniqueidentifier NOT NULL,
  [PreviousBranchId] uniqueidentifier NULL,
  [NextBranchId] uniqueidentifier NULL,
  [ActorId] uniqueidentifier NOT NULL,
  [Reason] nvarchar(400) NOT NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_security_BranchAssignmentAudit_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_BranchAudit] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_BranchAudit_Staff] FOREIGN KEY ([StaffId]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [FK_BranchAudit_Actor] FOREIGN KEY ([ActorId]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [FK_BranchAudit_Previous] FOREIGN KEY ([PreviousBranchId]) REFERENCES [core].[Branches]([Id]),
  CONSTRAINT [FK_BranchAudit_Next] FOREIGN KEY ([NextBranchId]) REFERENCES [core].[Branches]([Id])
);
GO

CREATE TABLE [crm].[Customers] (
  [Id] uniqueidentifier NOT NULL CONSTRAINT [DF_Customers_Id] DEFAULT(NEWID()),
  [CustomerCode] nvarchar(40) NULL,
  [DisplayName] nvarchar(200) NOT NULL,
  [Email] nvarchar(254) NULL,
  [Phone] nvarchar(40) NULL,
  [IsActive] bit NOT NULL CONSTRAINT [DF_Customers_Active] DEFAULT(1),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_crm_Customers_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_Customers] PRIMARY KEY ([Id]),
  CONSTRAINT [CK_Customers_Name] CHECK (LEN(LTRIM(RTRIM([DisplayName])))>0)
);
GO

CREATE TABLE [sourcing].[Suppliers] (
  [Id] uniqueidentifier NOT NULL CONSTRAINT [DF_Suppliers_Id] DEFAULT(NEWID()),
  [SupplierCode] nvarchar(40) NULL,
  [DisplayName] nvarchar(200) NOT NULL,
  [Email] nvarchar(254) NULL,
  [Phone] nvarchar(40) NULL,
  [IsActive] bit NOT NULL CONSTRAINT [DF_Suppliers_Active] DEFAULT(1),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sourcing_Suppliers_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_Suppliers] PRIMARY KEY ([Id]),
  CONSTRAINT [CK_Suppliers_Name] CHECK (LEN(LTRIM(RTRIM([DisplayName])))>0)
);
GO

CREATE TABLE [catalog].[Categories] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [ParentId] uniqueidentifier NULL,
  [Name] nvarchar(120) NOT NULL,
  [IsActive] bit NOT NULL DEFAULT(1),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_catalog_Categories_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_Categories] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_Category_Parent] FOREIGN KEY ([ParentId]) REFERENCES [catalog].[Categories]([Id]),
  CONSTRAINT [CK_Category_NoSelf] CHECK ([ParentId] IS NULL OR [ParentId]<>[Id])
);
GO

CREATE TABLE [catalog].[Brands] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [Name] nvarchar(120) NOT NULL,
  [IsActive] bit NOT NULL DEFAULT(1),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_catalog_Brands_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_Brands] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_Brands_Name] UNIQUE ([Name])
);
GO

CREATE TABLE [catalog].[Sizes] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [Code] nvarchar(30) NOT NULL,
  [Name] nvarchar(70) NOT NULL,
  [SortOrder] int NOT NULL DEFAULT(0),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_catalog_Sizes_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_Sizes] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_Sizes_Code] UNIQUE ([Code])
);
GO

CREATE TABLE [catalog].[Colors] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [Code] nvarchar(30) NOT NULL,
  [Name] nvarchar(70) NOT NULL,
  [HexColor] char(7) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_catalog_Colors_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_Colors] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_Colors_Code] UNIQUE ([Code]),
  CONSTRAINT [CK_Colors_Hex] CHECK ([HexColor] IS NULL OR ([HexColor] LIKE '#[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]' COLLATE Latin1_General_100_BIN2))
);
GO

CREATE TABLE [catalog].[Products] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [CategoryId] uniqueidentifier NULL,
  [BrandId] uniqueidentifier NULL,
  [Name] nvarchar(200) NOT NULL,
  [Description] nvarchar(max) NULL,
  [Status] varchar(20) NOT NULL DEFAULT('active'),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_catalog_Products_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_Products] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_Products_Category] FOREIGN KEY ([CategoryId]) REFERENCES [catalog].[Categories]([Id]),
  CONSTRAINT [FK_Products_Brand] FOREIGN KEY ([BrandId]) REFERENCES [catalog].[Brands]([Id]),
  CONSTRAINT [CK_Products_Name] CHECK (LEN(LTRIM(RTRIM([Name])))>0),
  CONSTRAINT [CK_Products_Status] CHECK ([Status] IN ('active','inactive','archived'))
);
GO

CREATE TABLE [catalog].[Items] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [ProductId] uniqueidentifier NOT NULL,
  [SizeId] uniqueidentifier NULL,
  [ColorId] uniqueidentifier NULL,
  [Sku] nvarchar(100) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [VariantName] nvarchar(200) NOT NULL,
  [CurrencyCode] varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [UnitPriceMinor] bigint NOT NULL,
  [UnitCostMinor] bigint NULL,
  [TaxRateBps] smallint NOT NULL DEFAULT(0),
  [Status] varchar(20) NOT NULL DEFAULT('draft'),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_catalog_Items_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_Items] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_Items_Sku] UNIQUE ([Sku]),
  CONSTRAINT [UQ_Items_Product_Variant] UNIQUE ([ProductId],[SizeId],[ColorId]),
  CONSTRAINT [FK_Items_Product] FOREIGN KEY ([ProductId]) REFERENCES [catalog].[Products]([Id]),
  CONSTRAINT [FK_Items_Size] FOREIGN KEY ([SizeId]) REFERENCES [catalog].[Sizes]([Id]),
  CONSTRAINT [FK_Items_Color] FOREIGN KEY ([ColorId]) REFERENCES [catalog].[Colors]([Id]),
  CONSTRAINT [FK_Items_Currency] FOREIGN KEY ([CurrencyCode]) REFERENCES [core].[Currencies]([Code]),
  CONSTRAINT [CK_Items_Sku] CHECK (LEN(LTRIM(RTRIM([Sku]))) BETWEEN 1 AND 100 AND [Sku]=LTRIM(RTRIM([Sku]))),
  CONSTRAINT [CK_Items_Name] CHECK (LEN(LTRIM(RTRIM([VariantName])))>0),
  CONSTRAINT [CK_Items_Price] CHECK ([UnitPriceMinor] BETWEEN 0 AND 9000000000000 AND ([UnitCostMinor] IS NULL OR [UnitCostMinor] BETWEEN 0 AND 9000000000000)),
  CONSTRAINT [CK_Items_Tax] CHECK ([TaxRateBps] BETWEEN 0 AND 10000),
  CONSTRAINT [CK_Items_Status] CHECK ([Status] IN ('draft','active','inactive','archived'))
);
GO

CREATE TABLE [catalog].[ItemIdentifiers] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [ItemId] uniqueidentifier NOT NULL,
  [SupplierId] uniqueidentifier NULL,
  [Kind] varchar(20) NOT NULL,
  [RawCode] nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [IsPrimary] bit NOT NULL DEFAULT(0),
  [IsActive] bit NOT NULL DEFAULT(1),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_catalog_ItemIdentifiers_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_ItemIdentifiers] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_Identifiers_Item] FOREIGN KEY ([ItemId]) REFERENCES [catalog].[Items]([Id]),
  CONSTRAINT [FK_Identifiers_Supplier] FOREIGN KEY ([SupplierId]) REFERENCES [sourcing].[Suppliers]([Id]),
  CONSTRAINT [CK_Identifiers_Kind] CHECK ([Kind] IN ('barcode','supplier_sku','alias')),
  CONSTRAINT [CK_Identifiers_Scope] CHECK ([Kind] <> 'supplier_sku' OR [SupplierId] IS NOT NULL),
  CONSTRAINT [CK_Identifiers_Code] CHECK (LEN(LTRIM(RTRIM([RawCode]))) BETWEEN 1 AND 128)
);
GO

CREATE TABLE [catalog].[ItemImages] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [ItemId] uniqueidentifier NULL,
  [ProductId] uniqueidentifier NOT NULL,
  [BlobKey] nvarchar(500) NOT NULL,
  [AltText] nvarchar(200) NULL,
  [SortOrder] int NOT NULL DEFAULT(0),
  [IsPrimary] bit NOT NULL DEFAULT(0),
  [Status] varchar(16) NOT NULL DEFAULT('active'),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_catalog_ItemImages_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_ItemImages] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_Image_Product] FOREIGN KEY ([ProductId]) REFERENCES [catalog].[Products]([Id]),
  CONSTRAINT [FK_Image_Item] FOREIGN KEY ([ItemId]) REFERENCES [catalog].[Items]([Id]),
  CONSTRAINT [CK_Image_Status] CHECK ([Status] IN ('active','archived'))
);
GO

CREATE TABLE [catalog].[PriceHistory] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [ItemId] uniqueidentifier NOT NULL,
  [OldPriceMinor] bigint NOT NULL,
  [NewPriceMinor] bigint NOT NULL,
  [CurrencyCode] varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [EffectiveAt] datetime2(3) NOT NULL,
  [Reason] nvarchar(250) NOT NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_catalog_PriceHistory_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_PriceHistory] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_PriceHistory_Item] FOREIGN KEY ([ItemId]) REFERENCES [catalog].[Items]([Id]),
  CONSTRAINT [FK_PriceHistory_Currency] FOREIGN KEY ([CurrencyCode]) REFERENCES [core].[Currencies]([Code]),
  CONSTRAINT [CK_PriceHistory_Price] CHECK ([OldPriceMinor]>=0 AND [NewPriceMinor]>=0)
);
GO

CREATE TABLE [inventory].[StockBalances] (
  [ItemId] uniqueidentifier NOT NULL,
  [LocationId] uniqueidentifier NOT NULL,
  [Pool] varchar(12) NOT NULL,
  [OnHand] int NOT NULL CONSTRAINT [DF_StockBalances_OnHand] DEFAULT(0),
  [Reserved] int NOT NULL CONSTRAINT [DF_StockBalances_Reserved] DEFAULT(0),
  [Status] varchar(12) NOT NULL DEFAULT('active'),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_inventory_StockBalances_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_StockBalances] PRIMARY KEY ([ItemId],[LocationId],[Pool]),
  CONSTRAINT [FK_StockBalances_Item] FOREIGN KEY ([ItemId]) REFERENCES [catalog].[Items]([Id]),
  CONSTRAINT [FK_StockBalances_Location] FOREIGN KEY ([LocationId]) REFERENCES [core].[Locations]([Id]),
  CONSTRAINT [CK_StockBalances_Pool] CHECK ([Pool] IN ('store','web','quarantine')),
  CONSTRAINT [CK_StockBalances_Bounds] CHECK ([OnHand] BETWEEN 0 AND 1000000000 AND [Reserved] BETWEEN 0 AND [OnHand]),
  CONSTRAINT [CK_StockBalances_Status] CHECK ([Status] IN ('active','frozen'))
);
GO

CREATE TABLE [inventory].[StockMovements] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [OperationId] uniqueidentifier NOT NULL,
  [ItemId] uniqueidentifier NOT NULL,
  [LocationId] uniqueidentifier NOT NULL,
  [Pool] varchar(12) NOT NULL,
  [Kind] varchar(24) NOT NULL,
  [OnHandDelta] int NOT NULL,
  [ReservedDelta] int NOT NULL DEFAULT(0),
  [OnHandAfter] int NOT NULL,
  [ReservedAfter] int NOT NULL,
  [UnitCostMinor] bigint NULL,
  [SourceType] varchar(30) NOT NULL,
  [SourceId] uniqueidentifier NOT NULL,
  [ReversesMovementId] uniqueidentifier NULL,
  [Status] varchar(12) NOT NULL DEFAULT('posted'),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_inventory_StockMovements_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_StockMovements] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_StockMovements_Operation] UNIQUE ([OperationId]),
  CONSTRAINT [FK_StockMovements_Balance] FOREIGN KEY ([ItemId],[LocationId],[Pool]) REFERENCES [inventory].[StockBalances]([ItemId],[LocationId],[Pool]),
  CONSTRAINT [FK_StockMovements_Reversal] FOREIGN KEY ([ReversesMovementId]) REFERENCES [inventory].[StockMovements]([Id]),
  CONSTRAINT [CK_StockMovement_Nonzero] CHECK ([OnHandDelta]<>0 OR [ReservedDelta]<>0),
  CONSTRAINT [CK_StockMovement_After] CHECK ([OnHandAfter]>=0 AND [ReservedAfter] BETWEEN 0 AND [OnHandAfter]),
  CONSTRAINT [CK_StockMovement_Kind] CHECK ([Kind] IN ('receive','sale','return','adjust','transfer_in','transfer_out','reserve','release','fulfill','allocate','reverse')),
  CONSTRAINT [CK_StockMovement_Status] CHECK ([Status]='posted'),
  CONSTRAINT [CK_StockMovement_Cost] CHECK ([UnitCostMinor] IS NULL OR [UnitCostMinor]>=0)
);
GO

CREATE TABLE [inventory].[StockAdjustments] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [ItemId] uniqueidentifier NOT NULL,
  [LocationId] uniqueidentifier NOT NULL,
  [Pool] varchar(12) NOT NULL,
  [QuantityDelta] int NOT NULL,
  [Reason] nvarchar(500) NOT NULL,
  [ApprovedBy] uniqueidentifier NULL,
  [MovementOperationId] uniqueidentifier NOT NULL,
  [Status] varchar(16) NOT NULL DEFAULT('posted'),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_inventory_StockAdjustments_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_StockAdjustments] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_StockAdjustments_Operation] UNIQUE ([MovementOperationId]),
  CONSTRAINT [FK_StockAdjustments_Item] FOREIGN KEY ([ItemId]) REFERENCES [catalog].[Items]([Id]),
  CONSTRAINT [FK_StockAdjustments_Location] FOREIGN KEY ([LocationId]) REFERENCES [core].[Locations]([Id]),
  CONSTRAINT [FK_StockAdjustments_Approver] FOREIGN KEY ([ApprovedBy]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [CK_StockAdjustments_Nonzero] CHECK ([QuantityDelta]<>0),
  CONSTRAINT [CK_StockAdjustments_Reason] CHECK (LEN(LTRIM(RTRIM([Reason])))>0)
);
GO

CREATE TABLE [inventory].[StockTransfers] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [FromLocationId] uniqueidentifier NOT NULL,
  [ToLocationId] uniqueidentifier NOT NULL,
  [Status] varchar(20) NOT NULL DEFAULT('requested'),
  [ApprovedBy] uniqueidentifier NULL,
  [ApprovedAt] datetime2(3) NULL,
  [Note] nvarchar(500) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_inventory_StockTransfers_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_StockTransfers] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_StockTransfer_From] FOREIGN KEY ([FromLocationId]) REFERENCES [core].[Locations]([Id]),
  CONSTRAINT [FK_StockTransfer_To] FOREIGN KEY ([ToLocationId]) REFERENCES [core].[Locations]([Id]),
  CONSTRAINT [FK_StockTransfer_Approver] FOREIGN KEY ([ApprovedBy]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [CK_StockTransfer_Different] CHECK ([FromLocationId]<>[ToLocationId]),
  CONSTRAINT [CK_StockTransfer_State] CHECK ([Status] IN ('requested','approved','dispatched','received','cancelled'))
);
GO

CREATE TABLE [inventory].[StockTransferLines] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [TransferId] uniqueidentifier NOT NULL,
  [ItemId] uniqueidentifier NOT NULL,
  [Quantity] int NOT NULL,
  [ReceivedQuantity] int NOT NULL DEFAULT(0),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_inventory_StockTransferLines_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_StockTransferLines] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_StockTransferLines_TransferItem] UNIQUE ([TransferId],[ItemId]),
  CONSTRAINT [FK_StockTransferLines_Transfer] FOREIGN KEY ([TransferId]) REFERENCES [inventory].[StockTransfers]([Id]),
  CONSTRAINT [FK_StockTransferLines_Item] FOREIGN KEY ([ItemId]) REFERENCES [catalog].[Items]([Id]),
  CONSTRAINT [CK_StockTransferLines_Qty] CHECK ([Quantity]>0 AND [ReceivedQuantity] BETWEEN 0 AND [Quantity])
);
GO

CREATE TABLE [inventory].[StockReservations] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [ItemId] uniqueidentifier NOT NULL,
  [LocationId] uniqueidentifier NOT NULL,
  [Pool] varchar(12) NOT NULL DEFAULT('web'),
  [Quantity] int NOT NULL,
  [ReferenceType] varchar(24) NOT NULL,
  [ReferenceId] uniqueidentifier NOT NULL,
  [Status] varchar(16) NOT NULL DEFAULT('active'),
  [ExpiresAt] datetime2(3) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_inventory_StockReservations_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_StockReservations] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_Reservation_Item] FOREIGN KEY ([ItemId]) REFERENCES [catalog].[Items]([Id]),
  CONSTRAINT [FK_Reservation_Location] FOREIGN KEY ([LocationId]) REFERENCES [core].[Locations]([Id]),
  CONSTRAINT [CK_Reservation_Pool] CHECK ([Pool]='web'),
  CONSTRAINT [CK_Reservation_Quantity] CHECK ([Quantity]>0),
  CONSTRAINT [CK_Reservation_Status] CHECK ([Status] IN ('active','fulfilled','released','expired'))
);
GO

CREATE TABLE [purchasing].[PurchaseOrders] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [SupplierId] uniqueidentifier NOT NULL,
  [LocationId] uniqueidentifier NOT NULL,
  [CurrencyCode] varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [SupplierReference] nvarchar(100) NULL,
  [Status] varchar(24) NOT NULL DEFAULT('draft'),
  [TotalMinor] bigint NOT NULL DEFAULT(0),
  [CancelledAt] datetime2(3) NULL,
  [CancellationReason] nvarchar(500) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_purchasing_PurchaseOrders_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_PurchaseOrders] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_PO_Supplier] FOREIGN KEY ([SupplierId]) REFERENCES [sourcing].[Suppliers]([Id]),
  CONSTRAINT [FK_PO_Location] FOREIGN KEY ([LocationId]) REFERENCES [core].[Locations]([Id]),
  CONSTRAINT [FK_PO_Currency] FOREIGN KEY ([CurrencyCode]) REFERENCES [core].[Currencies]([Code]),
  CONSTRAINT [CK_PO_Status] CHECK ([Status] IN ('draft','open','partially_received','received','cancelled')),
  CONSTRAINT [CK_PO_Total] CHECK ([TotalMinor]>=0),
  CONSTRAINT [CK_PO_Cancellation] CHECK (([Status]='cancelled' AND [CancelledAt] IS NOT NULL AND [CancellationReason] IS NOT NULL) OR ([Status]<>'cancelled' AND [CancelledAt] IS NULL))
);
GO

CREATE TABLE [purchasing].[PurchaseOrderLines] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [PurchaseOrderId] uniqueidentifier NOT NULL,
  [LineNumber] int NOT NULL,
  [ItemId] uniqueidentifier NOT NULL,
  [Quantity] int NOT NULL,
  [ReceivedQuantity] int NOT NULL DEFAULT(0),
  [UnitCostMinor] bigint NOT NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_purchasing_PurchaseOrderLines_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_PurchaseOrderLines] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_POLines_Number] UNIQUE ([PurchaseOrderId],[LineNumber]),
  CONSTRAINT [UQ_POLines_Item] UNIQUE ([PurchaseOrderId],[ItemId]),
  CONSTRAINT [FK_POLines_Order] FOREIGN KEY ([PurchaseOrderId]) REFERENCES [purchasing].[PurchaseOrders]([Id]),
  CONSTRAINT [FK_POLines_Item] FOREIGN KEY ([ItemId]) REFERENCES [catalog].[Items]([Id]),
  CONSTRAINT [CK_POLines_Qty] CHECK ([LineNumber]>0 AND [Quantity] BETWEEN 1 AND 1000000 AND [ReceivedQuantity] BETWEEN 0 AND [Quantity]),
  CONSTRAINT [CK_POLines_Cost] CHECK ([UnitCostMinor] BETWEEN 0 AND 9000000000000)
);
GO

CREATE TABLE [receiving].[ImportContainers] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [Reference] nvarchar(100) NOT NULL,
  [SupplierId] uniqueidentifier NOT NULL,
  [LocationId] uniqueidentifier NOT NULL,
  [PurchaseOrderId] uniqueidentifier NULL,
  [ArrivalAt] datetime2(3) NULL,
  [Status] varchar(20) NOT NULL DEFAULT('open'),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_receiving_ImportContainers_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_ImportContainers] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_Containers_SupplierReference] UNIQUE ([SupplierId],[Reference]),
  CONSTRAINT [FK_Container_Supplier] FOREIGN KEY ([SupplierId]) REFERENCES [sourcing].[Suppliers]([Id]),
  CONSTRAINT [FK_Container_Location] FOREIGN KEY ([LocationId]) REFERENCES [core].[Locations]([Id]),
  CONSTRAINT [FK_Container_PO] FOREIGN KEY ([PurchaseOrderId]) REFERENCES [purchasing].[PurchaseOrders]([Id]),
  CONSTRAINT [CK_Container_Ref] CHECK (LEN(LTRIM(RTRIM([Reference])))>0),
  CONSTRAINT [CK_Container_Status] CHECK ([Status] IN ('open','counting','review','closed','cancelled'))
);
GO

CREATE TABLE [receiving].[ImportManifestLines] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [ContainerId] uniqueidentifier NOT NULL,
  [LineNumber] int NOT NULL,
  [ItemId] uniqueidentifier NULL,
  [SupplierSku] nvarchar(128) NULL,
  [SupplierBarcode] nvarchar(128) NULL,
  [Description] nvarchar(300) NULL,
  [ExpectedQuantity] int NULL,
  [UnitCostMinor] bigint NULL,
  [CurrencyCode] varchar(3) COLLATE Latin1_General_100_BIN2 NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_receiving_ImportManifestLines_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_ManifestLines] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_ManifestLines_No] UNIQUE ([ContainerId],[LineNumber]),
  CONSTRAINT [FK_Manifest_Container] FOREIGN KEY ([ContainerId]) REFERENCES [receiving].[ImportContainers]([Id]),
  CONSTRAINT [FK_Manifest_Item] FOREIGN KEY ([ItemId]) REFERENCES [catalog].[Items]([Id]),
  CONSTRAINT [FK_Manifest_Currency] FOREIGN KEY ([CurrencyCode]) REFERENCES [core].[Currencies]([Code]),
  CONSTRAINT [CK_Manifest_LineNo] CHECK ([LineNumber]>0),
  CONSTRAINT [CK_Manifest_Qty] CHECK ([ExpectedQuantity] IS NULL OR [ExpectedQuantity]>=0),
  CONSTRAINT [CK_Manifest_Cost] CHECK ([UnitCostMinor] IS NULL OR [UnitCostMinor]>=0)
);
GO

CREATE TABLE [receiving].[ScanSessions] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [ContainerId] uniqueidentifier NOT NULL,
  [DeviceCode] nvarchar(80) NULL,
  [Status] varchar(16) NOT NULL DEFAULT('counting'),
  [ClosedAt] datetime2(3) NULL,
  [ReviewedBy] uniqueidentifier NULL,
  [ReviewedAt] datetime2(3) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_receiving_ScanSessions_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_ScanSessions] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_ScanSession_Container] FOREIGN KEY ([ContainerId]) REFERENCES [receiving].[ImportContainers]([Id]),
  CONSTRAINT [FK_ScanSession_Reviewer] FOREIGN KEY ([ReviewedBy]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [CK_ScanSession_Status] CHECK ([Status] IN ('counting','review','approved','posted','cancelled')),
  CONSTRAINT [CK_ScanSession_Review] CHECK (([ReviewedAt] IS NULL AND [ReviewedBy] IS NULL) OR ([ReviewedAt] IS NOT NULL AND [ReviewedBy] IS NOT NULL)),
  CONSTRAINT [CK_ScanSession_Close] CHECK ([ClosedAt] IS NULL OR [ClosedAt]>=[CreatedAt])
);
GO

CREATE TABLE [receiving].[ScanEvents] (
  [Id] uniqueidentifier NOT NULL,
  [ScanSessionId] uniqueidentifier NOT NULL,
  [ItemId] uniqueidentifier NULL,
  [RawCode] nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [Quantity] int NOT NULL DEFAULT(1),
  [MatchStatus] varchar(16) NOT NULL,
  [DeviceCode] nvarchar(80) NULL,
  [ResolutionReason] nvarchar(250) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_receiving_ScanEvents_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_ScanEvents] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_ScanEvent_Session] FOREIGN KEY ([ScanSessionId]) REFERENCES [receiving].[ScanSessions]([Id]),
  CONSTRAINT [FK_ScanEvent_Item] FOREIGN KEY ([ItemId]) REFERENCES [catalog].[Items]([Id]),
  CONSTRAINT [CK_ScanEvent_Qty] CHECK ([Quantity] BETWEEN 1 AND 10000),
  CONSTRAINT [CK_ScanEvent_Status] CHECK ([MatchStatus] IN ('matched','unknown','ambiguous','rejected')),
  CONSTRAINT [CK_ScanEvent_Matched] CHECK (([MatchStatus]='matched' AND [ItemId] IS NOT NULL) OR ([MatchStatus]<>'matched' AND [ItemId] IS NULL)),
  CONSTRAINT [CK_ScanEvent_Code] CHECK (LEN(LTRIM(RTRIM([RawCode])))>0)
);
GO

CREATE TABLE [purchasing].[GoodsReceipts] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [ScanSessionId] uniqueidentifier NULL,
  [PurchaseOrderId] uniqueidentifier NULL,
  [ContainerId] uniqueidentifier NULL,
  [LocationId] uniqueidentifier NOT NULL,
  [CurrencyCode] varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [TotalCostMinor] bigint NULL,
  [Status] varchar(16) NOT NULL DEFAULT('posted'),
  [PostedAt] datetime2(3) NOT NULL DEFAULT(SYSUTCDATETIME()),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_purchasing_GoodsReceipts_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_GoodsReceipts] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_GoodsReceipt_ScanSession] FOREIGN KEY ([ScanSessionId]) REFERENCES [receiving].[ScanSessions]([Id]),
  CONSTRAINT [FK_GoodsReceipt_PO] FOREIGN KEY ([PurchaseOrderId]) REFERENCES [purchasing].[PurchaseOrders]([Id]),
  CONSTRAINT [FK_GoodsReceipt_Container] FOREIGN KEY ([ContainerId]) REFERENCES [receiving].[ImportContainers]([Id]),
  CONSTRAINT [FK_GoodsReceipt_Location] FOREIGN KEY ([LocationId]) REFERENCES [core].[Locations]([Id]),
  CONSTRAINT [FK_GoodsReceipt_Currency] FOREIGN KEY ([CurrencyCode]) REFERENCES [core].[Currencies]([Code]),
  CONSTRAINT [CK_GoodsReceipt_Cost] CHECK ([TotalCostMinor] IS NULL OR [TotalCostMinor]>=0),
  CONSTRAINT [CK_GoodsReceipt_Source] CHECK ([ScanSessionId] IS NOT NULL OR [PurchaseOrderId] IS NOT NULL),
  CONSTRAINT [CK_GoodsReceipt_Status] CHECK ([Status] IN ('posted','reversed'))
);
GO

CREATE TABLE [purchasing].[GoodsReceiptLines] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [GoodsReceiptId] uniqueidentifier NOT NULL,
  [LineNumber] int NOT NULL,
  [ItemId] uniqueidentifier NOT NULL,
  [Quantity] int NOT NULL,
  [UnitCostMinor] bigint NULL,
  [Pool] varchar(12) NOT NULL DEFAULT('store'),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_purchasing_GoodsReceiptLines_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_GoodsReceiptLines] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_ReceiptLines_No] UNIQUE ([GoodsReceiptId],[LineNumber]),
  CONSTRAINT [FK_ReceiptLines_Header] FOREIGN KEY ([GoodsReceiptId]) REFERENCES [purchasing].[GoodsReceipts]([Id]),
  CONSTRAINT [FK_ReceiptLines_Item] FOREIGN KEY ([ItemId]) REFERENCES [catalog].[Items]([Id]),
  CONSTRAINT [CK_ReceiptLines_Qty] CHECK ([LineNumber]>0 AND [Quantity]>0 AND [Quantity]<=1000000),
  CONSTRAINT [CK_ReceiptLines_Cost] CHECK ([UnitCostMinor] IS NULL OR [UnitCostMinor]>=0),
  CONSTRAINT [CK_ReceiptLines_Pool] CHECK ([Pool] IN ('store','quarantine'))
);
GO

CREATE TABLE [sales].[Sales] (
  [Id] uniqueidentifier NOT NULL,
  [BranchId] uniqueidentifier NOT NULL,
  [LocationId] uniqueidentifier NOT NULL,
  [CustomerId] uniqueidentifier NULL,
  [CashierId] uniqueidentifier NOT NULL,
  [TillId] uniqueidentifier NULL,
  [RequestHash] varbinary(32) NOT NULL,
  [CurrencyCode] varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [SubtotalMinor] bigint NOT NULL,
  [DiscountMinor] bigint NOT NULL DEFAULT(0),
  [TaxMinor] bigint NOT NULL DEFAULT(0),
  [TotalMinor] bigint NOT NULL,
  [Channel] varchar(16) NOT NULL DEFAULT('pos'),
  [Status] varchar(24) NOT NULL DEFAULT('recorded'),
  [OriginNodeId] uniqueidentifier NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sales_Sales_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_Sales] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_Sales_LocationBranch] FOREIGN KEY ([LocationId],[BranchId]) REFERENCES [core].[Locations]([Id],[BranchId]),
  CONSTRAINT [FK_Sales_Customer] FOREIGN KEY ([CustomerId]) REFERENCES [crm].[Customers]([Id]),
  CONSTRAINT [FK_Sales_Cashier] FOREIGN KEY ([CashierId]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [FK_Sales_Currency] FOREIGN KEY ([CurrencyCode]) REFERENCES [core].[Currencies]([Code]),
  CONSTRAINT [CK_Sales_Amounts] CHECK ([SubtotalMinor]>=0 AND [DiscountMinor]>=0 AND [DiscountMinor]<=[SubtotalMinor] AND [TaxMinor]>=0 AND [TotalMinor]=[SubtotalMinor]-[DiscountMinor]+[TaxMinor]),
  CONSTRAINT [CK_Sales_Status] CHECK ([Status] IN ('recorded','partially_returned','returned','cancelled')),
  CONSTRAINT [CK_Sales_Channel] CHECK ([Channel] IN ('pos','web')),
  CONSTRAINT [CK_Sales_POS_Till] CHECK (([Channel]='pos' AND [TillId] IS NOT NULL) OR ([Channel]='web' AND [TillId] IS NULL))
);
GO

CREATE TABLE [sales].[SaleLines] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [SaleId] uniqueidentifier NOT NULL,
  [LineNumber] int NOT NULL,
  [ItemId] uniqueidentifier NOT NULL,
  [SkuSnapshot] nvarchar(100) NOT NULL,
  [NameSnapshot] nvarchar(200) NOT NULL,
  [Quantity] int NOT NULL,
  [ReturnedQuantity] int NOT NULL DEFAULT(0),
  [UnitPriceMinor] bigint NOT NULL,
  [CostUnitSnapshotMinor] bigint NULL,
  [COGSMinor] bigint NULL,
  [DiscountMinor] bigint NOT NULL DEFAULT(0),
  [TaxMinor] bigint NOT NULL DEFAULT(0),
  [TotalMinor] bigint NOT NULL,
  [StockExceptionReason] nvarchar(500) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sales_SaleLines_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_SaleLines] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_SaleLines_No] UNIQUE ([SaleId],[LineNumber]),
  CONSTRAINT [FK_SaleLines_Sale] FOREIGN KEY ([SaleId]) REFERENCES [sales].[Sales]([Id]),
  CONSTRAINT [FK_SaleLines_Item] FOREIGN KEY ([ItemId]) REFERENCES [catalog].[Items]([Id]),
  CONSTRAINT [CK_SaleLines_Quantity] CHECK ([LineNumber]>0 AND [Quantity] BETWEEN 1 AND 1000000 AND [ReturnedQuantity] BETWEEN 0 AND [Quantity]),
  CONSTRAINT [CK_SaleLines_Cost] CHECK (([CostUnitSnapshotMinor] IS NULL AND [COGSMinor] IS NULL) OR ([CostUnitSnapshotMinor] IS NOT NULL AND [CostUnitSnapshotMinor]>=0 AND [COGSMinor]=[CostUnitSnapshotMinor]*CONVERT(bigint,[Quantity]))),
  CONSTRAINT [CK_SaleLines_Total] CHECK ([UnitPriceMinor]>=0 AND [DiscountMinor]>=0 AND [TaxMinor]>=0 AND CAST([UnitPriceMinor] AS decimal(28,0))*[Quantity]>=[DiscountMinor] AND [TotalMinor]=CAST([UnitPriceMinor] AS decimal(28,0))*[Quantity]-[DiscountMinor]+[TaxMinor])
);
GO

CREATE TABLE [sales].[SaleTenders] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [SaleId] uniqueidentifier NOT NULL,
  [TenderKind] varchar(20) NOT NULL,
  [CurrencyCode] varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [AmountMinor] bigint NOT NULL,
  [Reference] nvarchar(120) NULL,
  [CreditId] uniqueidentifier NULL,
  [ReceivedMinor] bigint NULL,
  [ChangeMinor] bigint NULL,
  [Status] varchar(16) NOT NULL DEFAULT('captured'),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sales_SaleTenders_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_SaleTenders] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_Tenders_Sale] FOREIGN KEY ([SaleId]) REFERENCES [sales].[Sales]([Id]),
  CONSTRAINT [FK_Tenders_Currency] FOREIGN KEY ([CurrencyCode]) REFERENCES [core].[Currencies]([Code]),
  CONSTRAINT [CK_Tenders_Kind] CHECK ([TenderKind] IN ('cash','card','transfer','credit','other')),
  CONSTRAINT [CK_Tenders_Amount] CHECK ([AmountMinor]>0),
  CONSTRAINT [CK_Tenders_Cash] CHECK (([TenderKind]='cash' AND [ReceivedMinor] IS NOT NULL AND [ChangeMinor] IS NOT NULL AND [ReceivedMinor]>=0 AND [ChangeMinor]>=0 AND [ReceivedMinor]-[ChangeMinor]=[AmountMinor]) OR ([TenderKind]<>'cash' AND [ReceivedMinor] IS NULL AND [ChangeMinor] IS NULL)),
  CONSTRAINT [CK_Tenders_Credit] CHECK (([TenderKind]='credit' AND [CreditId] IS NOT NULL) OR ([TenderKind]<>'credit' AND [CreditId] IS NULL)),
  CONSTRAINT [CK_Tenders_Status] CHECK ([Status] IN ('captured','reversed','pending'))
);
GO

CREATE TABLE [sales].[SaleReversals] (
  [Id] uniqueidentifier NOT NULL,
  [SaleId] uniqueidentifier NOT NULL,
  [BranchId] uniqueidentifier NOT NULL,
  [LocationId] uniqueidentifier NOT NULL,
  [TillId] uniqueidentifier NULL,
  [ActorId] uniqueidentifier NOT NULL,
  [Kind] varchar(16) NOT NULL,
  [SettlementKind] varchar(16) NOT NULL,
  [Reason] nvarchar(500) NOT NULL,
  [CreditMinor] bigint NOT NULL,
  [CurrencyCode] varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [Status] varchar(20) NOT NULL DEFAULT('approved'),
  [ApprovedBy] uniqueidentifier NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sales_SaleReversals_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_SaleReversals] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_Reversals_Sale] FOREIGN KEY ([SaleId]) REFERENCES [sales].[Sales]([Id]),
  CONSTRAINT [FK_Reversals_Branch] FOREIGN KEY ([BranchId]) REFERENCES [core].[Branches]([Id]),
  CONSTRAINT [FK_Reversals_LocationBranch] FOREIGN KEY ([LocationId],[BranchId]) REFERENCES [core].[Locations]([Id],[BranchId]),
  CONSTRAINT [FK_Reversals_Actor] FOREIGN KEY ([ActorId]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [FK_Reversals_Currency] FOREIGN KEY ([CurrencyCode]) REFERENCES [core].[Currencies]([Code]),
  CONSTRAINT [FK_Reversals_Approver] FOREIGN KEY ([ApprovedBy]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [CK_Reversals_Kind] CHECK ([Kind] IN ('return','cancel')),
  CONSTRAINT [CK_Reversals_Settlement] CHECK ([SettlementKind] IN ('credit','cash','mixed','none')),
  CONSTRAINT [CK_Reversals_Credit] CHECK ([CreditMinor]>=0),
  CONSTRAINT [CK_Reversals_Reason] CHECK (LEN(LTRIM(RTRIM([Reason])))>0),
  CONSTRAINT [CK_Reversals_Status] CHECK ([Status] IN ('pending','approved','reversed'))
);
GO

CREATE TABLE [sales].[SaleReversalLines] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [ReversalId] uniqueidentifier NOT NULL,
  [SaleLineId] uniqueidentifier NOT NULL,
  [Quantity] int NOT NULL,
  [CreditMinor] bigint NOT NULL,
  [COGSReversedMinor] bigint NULL,
  [RestockPool] varchar(12) NOT NULL DEFAULT('quarantine'),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sales_SaleReversalLines_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_ReversalLines] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_ReversalLines_Link] UNIQUE ([ReversalId],[SaleLineId]),
  CONSTRAINT [FK_ReversalLines_Reversal] FOREIGN KEY ([ReversalId]) REFERENCES [sales].[SaleReversals]([Id]),
  CONSTRAINT [FK_ReversalLines_SaleLine] FOREIGN KEY ([SaleLineId]) REFERENCES [sales].[SaleLines]([Id]),
  CONSTRAINT [CK_ReversalLines_Qty] CHECK ([Quantity]>0),
  CONSTRAINT [CK_ReversalLines_Credit] CHECK ([CreditMinor]>=0),
  CONSTRAINT [CK_ReversalLines_COGS] CHECK ([COGSReversedMinor] IS NULL OR [COGSReversedMinor]>=0),
  CONSTRAINT [CK_ReversalLines_Pool] CHECK ([RestockPool] IN ('store','quarantine'))
);
GO

CREATE TABLE [sales].[StockExceptionReviews] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [SaleLineId] uniqueidentifier NOT NULL,
  [ReviewerId] uniqueidentifier NOT NULL,
  [Evidence] nvarchar(500) NOT NULL,
  [Outcome] nvarchar(500) NOT NULL,
  [ResponsibleActorId] uniqueidentifier NOT NULL,
  [NextReviewAt] datetime2(3) NOT NULL,
  [Status] varchar(16) NOT NULL DEFAULT('open'),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sales_StockExceptionReviews_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_StockExceptionReviews] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_StockException_SaleLine] FOREIGN KEY ([SaleLineId]) REFERENCES [sales].[SaleLines]([Id]),
  CONSTRAINT [FK_StockException_Reviewer] FOREIGN KEY ([ReviewerId]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [FK_StockException_Responsible] FOREIGN KEY ([ResponsibleActorId]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [CK_StockException_Status] CHECK ([Status] IN ('open','resolved')),
  CONSTRAINT [CK_StockException_Next] CHECK ([NextReviewAt]>[CreatedAt])
);
GO

CREATE TABLE [sales].[CashRegisters] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [BranchId] uniqueidentifier NOT NULL,
  [LocationId] uniqueidentifier NOT NULL,
  [Code] nvarchar(40) NOT NULL,
  [Name] nvarchar(120) NOT NULL,
  [IsActive] bit NOT NULL DEFAULT(1),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sales_CashRegisters_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_CashRegisters] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_CashRegisters_BranchCode] UNIQUE ([BranchId],[Code]),
  CONSTRAINT [FK_CashRegister_LocationBranch] FOREIGN KEY ([LocationId],[BranchId]) REFERENCES [core].[Locations]([Id],[BranchId])
);
GO

CREATE TABLE [sales].[CashTills] (
  [Id] uniqueidentifier NOT NULL,
  [RegisterId] uniqueidentifier NOT NULL,
  [CashierId] uniqueidentifier NOT NULL,
  [CurrencyCode] varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [OpenedAt] datetime2(3) NOT NULL DEFAULT(SYSUTCDATETIME()),
  [ClosedAt] datetime2(3) NULL,
  [Status] varchar(16) NOT NULL DEFAULT('open'),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sales_CashTills_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_CashTills] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_CashTills_Id_Currency] UNIQUE ([Id],[CurrencyCode]),
  CONSTRAINT [FK_CashTills_Register] FOREIGN KEY ([RegisterId]) REFERENCES [sales].[CashRegisters]([Id]),
  CONSTRAINT [FK_CashTills_Staff] FOREIGN KEY ([CashierId]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [FK_CashTills_Currency] FOREIGN KEY ([CurrencyCode]) REFERENCES [core].[Currencies]([Code]),
  CONSTRAINT [CK_CashTills_Status] CHECK ([Status] IN ('open','closed')),
  CONSTRAINT [CK_CashTills_CloseState] CHECK (([Status]='open' AND [ClosedAt] IS NULL) OR ([Status]='closed' AND [ClosedAt] IS NOT NULL AND [ClosedAt]>=[OpenedAt]))
);
GO

CREATE TABLE [sales].[CashEntries] (
  [Id] uniqueidentifier NOT NULL,
  [TillId] uniqueidentifier NOT NULL,
  [CurrencyCode] varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [Kind] varchar(16) NOT NULL,
  [DeltaMinor] bigint NOT NULL,
  [SaleTenderId] uniqueidentifier NULL,
  [ReversalId] uniqueidentifier NULL,
  [Reason] nvarchar(400) NULL,
  [ActorId] uniqueidentifier NOT NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sales_CashEntries_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_CashEntries] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_CashEntries_TillCurrency] FOREIGN KEY ([TillId],[CurrencyCode]) REFERENCES [sales].[CashTills]([Id],[CurrencyCode]),
  CONSTRAINT [FK_CashEntries_Tender] FOREIGN KEY ([SaleTenderId]) REFERENCES [sales].[SaleTenders]([Id]),
  CONSTRAINT [FK_CashEntries_Reversal] FOREIGN KEY ([ReversalId]) REFERENCES [sales].[SaleReversals]([Id]),
  CONSTRAINT [FK_CashEntries_Actor] FOREIGN KEY ([ActorId]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [CK_CashEntries_Kind] CHECK ([Kind] IN ('opening','sale','refund','payout','adjustment','deposit')),
  CONSTRAINT [CK_CashEntries_Source] CHECK (([Kind]='sale' AND [SaleTenderId] IS NOT NULL AND [ReversalId] IS NULL AND [DeltaMinor]>0) OR ([Kind]='refund' AND [ReversalId] IS NOT NULL AND [SaleTenderId] IS NULL AND [DeltaMinor]<0) OR ([Kind] NOT IN ('sale','refund') AND [SaleTenderId] IS NULL AND [ReversalId] IS NULL)),
  CONSTRAINT [CK_CashEntries_Opening] CHECK ([Kind]<>'opening' OR [DeltaMinor]>=0),
  CONSTRAINT [CK_CashEntries_Nonzero] CHECK ([Kind] IN ('opening','adjustment') OR [DeltaMinor]<>0)
);
GO

CREATE TABLE [sales].[CashCounts] (
  [Id] uniqueidentifier NOT NULL,
  [TillId] uniqueidentifier NOT NULL,
  [CountedBy] uniqueidentifier NOT NULL,
  [Status] varchar(16) NOT NULL DEFAULT('draft'),
  [SubmittedAt] datetime2(3) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sales_CashCounts_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_CashCounts] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_CashCounts_Till] FOREIGN KEY ([TillId]) REFERENCES [sales].[CashTills]([Id]),
  CONSTRAINT [FK_CashCounts_Actor] FOREIGN KEY ([CountedBy]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [CK_CashCounts_Status] CHECK ([Status] IN ('draft','submitted','void')),
  CONSTRAINT [CK_CashCounts_Submitted] CHECK (([Status]='submitted' AND [SubmittedAt] IS NOT NULL) OR ([Status]<>'submitted' AND [SubmittedAt] IS NULL))
);
GO

CREATE TABLE [sales].[CashCountLines] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [CashCountId] uniqueidentifier NOT NULL,
  [DenominationMinor] bigint NOT NULL,
  [Quantity] int NOT NULL,
  CONSTRAINT [PK_CashCountLines] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_CashCountLines_Denomination] UNIQUE ([CashCountId],[DenominationMinor]),
  CONSTRAINT [FK_CashCountLines_Count] FOREIGN KEY ([CashCountId]) REFERENCES [sales].[CashCounts]([Id]),
  CONSTRAINT [CK_CashCountLines_Values] CHECK ([DenominationMinor]>0 AND [Quantity] BETWEEN 0 AND 1000000)
);
GO

CREATE TABLE [sales].[CashClosures] (
  [Id] uniqueidentifier NOT NULL,
  [TillId] uniqueidentifier NOT NULL,
  [CashCountId] uniqueidentifier NOT NULL,
  [ExpectedMinor] bigint NOT NULL,
  [CountedMinor] bigint NOT NULL,
  [DifferenceMinor] bigint NOT NULL,
  [ClosedBy] uniqueidentifier NOT NULL,
  [ClosedAt] datetime2(3) NOT NULL DEFAULT(SYSUTCDATETIME()),
  [Status] varchar(16) NOT NULL DEFAULT('closed'),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sales_CashClosures_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_CashClosures] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_CashClosures_Till] UNIQUE ([TillId]),
  CONSTRAINT [UQ_CashClosures_Count] UNIQUE ([CashCountId]),
  CONSTRAINT [FK_CashClosures_Till] FOREIGN KEY ([TillId]) REFERENCES [sales].[CashTills]([Id]),
  CONSTRAINT [FK_CashClosures_Count] FOREIGN KEY ([CashCountId]) REFERENCES [sales].[CashCounts]([Id]),
  CONSTRAINT [FK_CashClosures_Actor] FOREIGN KEY ([ClosedBy]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [CK_CashClosures_Amounts] CHECK ([ExpectedMinor]>=0 AND [CountedMinor]>=0 AND [DifferenceMinor]=[CountedMinor]-[ExpectedMinor])
);
GO

CREATE TABLE [credits].[Credits] (
  [Id] uniqueidentifier NOT NULL,
  [CustomerId] uniqueidentifier NOT NULL,
  [SourceReversalId] uniqueidentifier NOT NULL,
  [IssuingBranchId] uniqueidentifier NOT NULL,
  [CurrencyCode] varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [OriginalMinor] bigint NOT NULL,
  [Status] varchar(16) NOT NULL DEFAULT('active'),
  [ExpiresAt] datetime2(3) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_credits_Credits_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_Credits] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_Credits_Reversal] UNIQUE ([SourceReversalId]),
  CONSTRAINT [FK_Credit_Customer] FOREIGN KEY ([CustomerId]) REFERENCES [crm].[Customers]([Id]),
  CONSTRAINT [FK_Credit_Reversal] FOREIGN KEY ([SourceReversalId]) REFERENCES [sales].[SaleReversals]([Id]),
  CONSTRAINT [FK_Credit_Branch] FOREIGN KEY ([IssuingBranchId]) REFERENCES [core].[Branches]([Id]),
  CONSTRAINT [FK_Credit_Currency] FOREIGN KEY ([CurrencyCode]) REFERENCES [core].[Currencies]([Code]),
  CONSTRAINT [CK_Credit_Amount] CHECK ([OriginalMinor]>0),
  CONSTRAINT [CK_Credit_Status] CHECK ([Status] IN ('active','exhausted','blocked','expired'))
);
GO

CREATE TABLE [credits].[CreditAllocations] (
  [CreditId] uniqueidentifier NOT NULL,
  [BranchId] uniqueidentifier NOT NULL,
  [AvailableMinor] bigint NOT NULL DEFAULT(0),
  [HeldMinor] bigint NOT NULL DEFAULT(0),
  [Status] varchar(16) NOT NULL DEFAULT('active'),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_credits_CreditAllocations_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_CreditAllocations] PRIMARY KEY ([CreditId],[BranchId]),
  CONSTRAINT [FK_Allocation_Credit] FOREIGN KEY ([CreditId]) REFERENCES [credits].[Credits]([Id]),
  CONSTRAINT [FK_Allocation_Branch] FOREIGN KEY ([BranchId]) REFERENCES [core].[Branches]([Id]),
  CONSTRAINT [CK_Allocation_Nonnegative] CHECK ([AvailableMinor]>=0 AND [HeldMinor]>=0),
  CONSTRAINT [CK_Allocation_Status] CHECK ([Status] IN ('active','frozen'))
);
GO

CREATE TABLE [credits].[CreditMovements] (
  [Id] uniqueidentifier NOT NULL,
  [CreditId] uniqueidentifier NOT NULL,
  [BranchId] uniqueidentifier NOT NULL,
  [Kind] varchar(24) NOT NULL,
  [AvailableDeltaMinor] bigint NOT NULL,
  [HeldDeltaMinor] bigint NOT NULL DEFAULT(0),
  [SourceType] varchar(30) NOT NULL,
  [SourceId] uniqueidentifier NOT NULL,
  [ActorId] uniqueidentifier NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_credits_CreditMovements_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_CreditMovements] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_CreditMovement_Allocation] FOREIGN KEY ([CreditId],[BranchId]) REFERENCES [credits].[CreditAllocations]([CreditId],[BranchId]),
  CONSTRAINT [FK_CreditMovement_Actor] FOREIGN KEY ([ActorId]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [CK_CreditMovement_Kind] CHECK ([Kind] IN ('issue','redeem','hold','release','transfer_out','transfer_in','accept','reversal')),
  CONSTRAINT [CK_CreditMovement_Nonzero] CHECK ([AvailableDeltaMinor]<>0 OR [HeldDeltaMinor]<>0)
);
GO

CREATE TABLE [credits].[CreditTransfers] (
  [Id] uniqueidentifier NOT NULL,
  [CreditId] uniqueidentifier NOT NULL,
  [FromBranchId] uniqueidentifier NOT NULL,
  [ToBranchId] uniqueidentifier NOT NULL,
  [AmountMinor] bigint NOT NULL,
  [RequestedBy] uniqueidentifier NOT NULL,
  [ApprovedBy] uniqueidentifier NULL,
  [ApprovedAt] datetime2(3) NULL,
  [OriginLockEventId] uniqueidentifier NULL,
  [OriginLockedAt] datetime2(3) NULL,
  [CommittedAt] datetime2(3) NULL,
  [AcceptedAt] datetime2(3) NULL,
  [Status] varchar(20) NOT NULL DEFAULT('requested'),
  [Reason] nvarchar(400) NOT NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_credits_CreditTransfers_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_CreditTransfers] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_CreditTransfer_Credit] FOREIGN KEY ([CreditId]) REFERENCES [credits].[Credits]([Id]),
  CONSTRAINT [FK_CreditTransfer_From] FOREIGN KEY ([FromBranchId]) REFERENCES [core].[Branches]([Id]),
  CONSTRAINT [FK_CreditTransfer_To] FOREIGN KEY ([ToBranchId]) REFERENCES [core].[Branches]([Id]),
  CONSTRAINT [FK_CreditTransfer_Requester] FOREIGN KEY ([RequestedBy]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [FK_CreditTransfer_Approver] FOREIGN KEY ([ApprovedBy]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [CK_CreditTransfer_Branches] CHECK ([FromBranchId]<>[ToBranchId]),
  CONSTRAINT [CK_CreditTransfer_Amount] CHECK ([AmountMinor]>0),
  CONSTRAINT [CK_CreditTransfer_Approver] CHECK ([ApprovedBy] IS NULL OR [ApprovedBy]<>[RequestedBy]),
  CONSTRAINT [CK_CreditTransfer_Status] CHECK ([Status] IN ('requested','approved','origin_locked','in_transit','accepted','rejected','cancelled')),
  CONSTRAINT [CK_CreditTransfer_ApprovalTime] CHECK (([ApprovedBy] IS NULL AND [ApprovedAt] IS NULL) OR ([ApprovedBy] IS NOT NULL AND [ApprovedAt] IS NOT NULL))
);
GO

CREATE TABLE [credits].[CreditRedemptions] (
  [Id] uniqueidentifier NOT NULL,
  [CreditId] uniqueidentifier NOT NULL,
  [BranchId] uniqueidentifier NOT NULL,
  [SaleId] uniqueidentifier NOT NULL,
  [AmountMinor] bigint NOT NULL,
  [ActorId] uniqueidentifier NOT NULL,
  [Status] varchar(16) NOT NULL DEFAULT('posted'),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_credits_CreditRedemptions_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_CreditRedemptions] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_CreditRedemption_Allocation] FOREIGN KEY ([CreditId],[BranchId]) REFERENCES [credits].[CreditAllocations]([CreditId],[BranchId]),
  CONSTRAINT [FK_CreditRedemption_Sale] FOREIGN KEY ([SaleId]) REFERENCES [sales].[Sales]([Id]),
  CONSTRAINT [FK_CreditRedemption_Actor] FOREIGN KEY ([ActorId]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [CK_CreditRedemption_Amount] CHECK ([AmountMinor]>0),
  CONSTRAINT [CK_CreditRedemption_Status] CHECK ([Status] IN ('posted','reversed'))
);
GO

CREATE TABLE [webstore].[Orders] (
  [Id] uniqueidentifier NOT NULL,
  [CustomerId] uniqueidentifier NULL,
  [ExternalOrderRef] nvarchar(100) NULL,
  [RequestHash] varbinary(32) NOT NULL,
  [CurrencyCode] varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [SubtotalMinor] bigint NOT NULL,
  [DiscountMinor] bigint NOT NULL DEFAULT(0),
  [TaxMinor] bigint NOT NULL DEFAULT(0),
  [ShippingMinor] bigint NOT NULL DEFAULT(0),
  [TotalMinor] bigint NOT NULL,
  [Status] varchar(24) NOT NULL DEFAULT('pending'),
  [PlacedAt] datetime2(3) NOT NULL DEFAULT(SYSUTCDATETIME()),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_webstore_Orders_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_WebOrders] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_WebOrders_Customer] FOREIGN KEY ([CustomerId]) REFERENCES [crm].[Customers]([Id]),
  CONSTRAINT [FK_WebOrders_Currency] FOREIGN KEY ([CurrencyCode]) REFERENCES [core].[Currencies]([Code]),
  CONSTRAINT [CK_WebOrders_Total] CHECK ([SubtotalMinor]>=0 AND [DiscountMinor] BETWEEN 0 AND [SubtotalMinor] AND [TaxMinor]>=0 AND [ShippingMinor]>=0 AND [TotalMinor]=[SubtotalMinor]-[DiscountMinor]+[TaxMinor]+[ShippingMinor]),
  CONSTRAINT [CK_WebOrders_Status] CHECK ([Status] IN ('pending','reserved','paid','fulfilling','fulfilled','cancelled','refunded'))
);
GO

CREATE TABLE [webstore].[OrderAddresses] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [OrderId] uniqueidentifier NOT NULL,
  [Kind] varchar(16) NOT NULL,
  [RecipientName] nvarchar(180) NOT NULL,
  [Phone] nvarchar(40) NULL,
  [Email] nvarchar(254) NULL,
  [CountryCode] char(2) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [Region] nvarchar(120) NULL,
  [City] nvarchar(120) NOT NULL,
  [StreetAddress] nvarchar(350) NOT NULL,
  [PostalCode] nvarchar(20) NULL,
  [DeliveryInstructions] nvarchar(500) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_webstore_OrderAddresses_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_OrderAddresses] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_OrderAddresses_Kind] UNIQUE ([OrderId],[Kind]),
  CONSTRAINT [FK_OrderAddresses_Order] FOREIGN KEY ([OrderId]) REFERENCES [webstore].[Orders]([Id]),
  CONSTRAINT [CK_OrderAddresses_Kind] CHECK ([Kind] IN ('billing','shipping')),
  CONSTRAINT [CK_OrderAddresses_Required] CHECK (LEN(LTRIM(RTRIM([RecipientName])))>0 AND LEN(LTRIM(RTRIM([City])))>0 AND LEN(LTRIM(RTRIM([StreetAddress])))>0)
);
GO

CREATE TABLE [webstore].[Carts] (
  [Id] uniqueidentifier NOT NULL,
  [CustomerId] uniqueidentifier NULL,
  [SessionTokenHash] varbinary(32) NULL,
  [CurrencyCode] varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [Status] varchar(16) NOT NULL DEFAULT('active'),
  [ExpiresAt] datetime2(3) NOT NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_webstore_Carts_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_WebCarts] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_WebCart_Customer] FOREIGN KEY ([CustomerId]) REFERENCES [crm].[Customers]([Id]),
  CONSTRAINT [FK_WebCart_Currency] FOREIGN KEY ([CurrencyCode]) REFERENCES [core].[Currencies]([Code]),
  CONSTRAINT [CK_WebCart_Identity] CHECK ([CustomerId] IS NOT NULL OR [SessionTokenHash] IS NOT NULL),
  CONSTRAINT [CK_WebCart_Status] CHECK ([Status] IN ('active','converted','expired'))
);
GO

CREATE TABLE [webstore].[CartLines] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [CartId] uniqueidentifier NOT NULL,
  [ItemId] uniqueidentifier NOT NULL,
  [Quantity] int NOT NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_webstore_CartLines_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_CartLines] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_CartLines_CartItem] UNIQUE ([CartId],[ItemId]),
  CONSTRAINT [FK_CartLine_Cart] FOREIGN KEY ([CartId]) REFERENCES [webstore].[Carts]([Id]),
  CONSTRAINT [FK_CartLine_Item] FOREIGN KEY ([ItemId]) REFERENCES [catalog].[Items]([Id]),
  CONSTRAINT [CK_CartLines_Qty] CHECK ([Quantity] BETWEEN 1 AND 1000)
);
GO

CREATE TABLE [webstore].[OrderLines] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [OrderId] uniqueidentifier NOT NULL,
  [LineNumber] int NOT NULL,
  [ItemId] uniqueidentifier NOT NULL,
  [SkuSnapshot] nvarchar(100) NOT NULL,
  [Quantity] int NOT NULL,
  [UnitPriceMinor] bigint NOT NULL,
  [DiscountMinor] bigint NOT NULL DEFAULT(0),
  [TaxMinor] bigint NOT NULL DEFAULT(0),
  [TotalMinor] bigint NOT NULL,
  [ReservationId] uniqueidentifier NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_webstore_OrderLines_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_OrderLines] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_OrderLines_No] UNIQUE ([OrderId],[LineNumber]),
  CONSTRAINT [FK_OrderLines_Order] FOREIGN KEY ([OrderId]) REFERENCES [webstore].[Orders]([Id]),
  CONSTRAINT [FK_OrderLines_Item] FOREIGN KEY ([ItemId]) REFERENCES [catalog].[Items]([Id]),
  CONSTRAINT [FK_OrderLines_Reservation] FOREIGN KEY ([ReservationId]) REFERENCES [inventory].[StockReservations]([Id]),
  CONSTRAINT [CK_OrderLines_Total] CHECK ([LineNumber]>0 AND [Quantity]>0 AND [UnitPriceMinor]>=0 AND [DiscountMinor]>=0 AND [TaxMinor]>=0 AND [TotalMinor]=CAST([UnitPriceMinor] AS decimal(28,0))*[Quantity]-[DiscountMinor]+[TaxMinor])
);
GO

CREATE TABLE [webstore].[Payments] (
  [Id] uniqueidentifier NOT NULL,
  [OrderId] uniqueidentifier NOT NULL,
  [Provider] nvarchar(80) NOT NULL,
  [ExternalPaymentId] nvarchar(160) NOT NULL,
  [AmountMinor] bigint NOT NULL,
  [CurrencyCode] varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [Status] varchar(20) NOT NULL,
  [VerifiedAt] datetime2(3) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_webstore_Payments_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_WebPayments] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_WebPayments_ProviderId] UNIQUE ([Provider],[ExternalPaymentId]),
  CONSTRAINT [FK_Payments_Order] FOREIGN KEY ([OrderId]) REFERENCES [webstore].[Orders]([Id]),
  CONSTRAINT [FK_Payments_Currency] FOREIGN KEY ([CurrencyCode]) REFERENCES [core].[Currencies]([Code]),
  CONSTRAINT [CK_Payments_Amount] CHECK ([AmountMinor]>0),
  CONSTRAINT [CK_Payments_Status] CHECK ([Status] IN ('initiated','authorized','captured','failed','refunded'))
);
GO

CREATE TABLE [webstore].[Fulfillments] (
  [Id] uniqueidentifier NOT NULL,
  [OrderId] uniqueidentifier NOT NULL,
  [BranchId] uniqueidentifier NOT NULL,
  [LocationId] uniqueidentifier NOT NULL,
  [Status] varchar(20) NOT NULL DEFAULT('pending'),
  [ShippedAt] datetime2(3) NULL,
  [DeliveredAt] datetime2(3) NULL,
  [TrackingRef] nvarchar(120) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_webstore_Fulfillments_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_Fulfillments] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_Fulfillment_Order] FOREIGN KEY ([OrderId]) REFERENCES [webstore].[Orders]([Id]),
  CONSTRAINT [FK_Fulfillment_LocationBranch] FOREIGN KEY ([LocationId],[BranchId]) REFERENCES [core].[Locations]([Id],[BranchId]),
  CONSTRAINT [CK_Fulfillments_Status] CHECK ([Status] IN ('pending','picking','shipped','delivered','cancelled'))
);
GO

CREATE TABLE [labels].[Printers] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [BranchId] uniqueidentifier NOT NULL,
  [Code] nvarchar(60) NOT NULL,
  [Name] nvarchar(150) NOT NULL,
  [DriverLanguage] varchar(12) NOT NULL,
  [DeviceAddress] nvarchar(255) NULL,
  [IsDefault] bit NOT NULL DEFAULT(0),
  [IsActive] bit NOT NULL DEFAULT(1),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_labels_Printers_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_Printers] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_Printers_BranchCode] UNIQUE ([BranchId],[Code]),
  CONSTRAINT [FK_Printer_Branch] FOREIGN KEY ([BranchId]) REFERENCES [core].[Branches]([Id]),
  CONSTRAINT [CK_Printer_Language] CHECK ([DriverLanguage] IN ('ZPL','TSPL','ESC_POS','PDF','SYSTEM'))
);
GO

CREATE TABLE [labels].[Templates] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [Code] nvarchar(80) NOT NULL,
  [Name] nvarchar(150) NOT NULL,
  [LayoutVersion] int NOT NULL DEFAULT(1),
  [PayloadJson] nvarchar(max) NOT NULL,
  [IsActive] bit NOT NULL DEFAULT(1),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_labels_Templates_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_LabelTemplates] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_LabelTemplates_Code] UNIQUE ([Code]),
  CONSTRAINT [CK_LabelTemplates_Version] CHECK ([LayoutVersion]>=1),
  CONSTRAINT [CK_LabelTemplates_Json] CHECK (ISJSON([PayloadJson])=1)
);
GO

CREATE TABLE [labels].[PrintJobs] (
  [Id] uniqueidentifier NOT NULL,
  [ReceiptLineId] uniqueidentifier NULL,
  [ItemId] uniqueidentifier NOT NULL,
  [BranchId] uniqueidentifier NOT NULL,
  [PrinterId] uniqueidentifier NULL,
  [TemplateId] uniqueidentifier NULL,
  [StoreNameSnapshot] nvarchar(150) NOT NULL,
  [SkuSnapshot] nvarchar(100) NOT NULL,
  [BarcodeSnapshot] nvarchar(128) NOT NULL,
  [CopiesRequested] int NOT NULL,
  [CopiesAcknowledged] int NOT NULL DEFAULT(0),
  [Status] varchar(20) NOT NULL DEFAULT('pending'),
  [LastError] nvarchar(500) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_labels_PrintJobs_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_PrintJobs] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_PrintJob_ReceiptLine] FOREIGN KEY ([ReceiptLineId]) REFERENCES [purchasing].[GoodsReceiptLines]([Id]),
  CONSTRAINT [FK_PrintJob_Item] FOREIGN KEY ([ItemId]) REFERENCES [catalog].[Items]([Id]),
  CONSTRAINT [FK_PrintJob_Branch] FOREIGN KEY ([BranchId]) REFERENCES [core].[Branches]([Id]),
  CONSTRAINT [FK_PrintJob_Printer] FOREIGN KEY ([PrinterId]) REFERENCES [labels].[Printers]([Id]),
  CONSTRAINT [FK_PrintJob_Template] FOREIGN KEY ([TemplateId]) REFERENCES [labels].[Templates]([Id]),
  CONSTRAINT [CK_PrintJob_Copies] CHECK ([CopiesRequested] BETWEEN 1 AND 1000000 AND [CopiesAcknowledged] BETWEEN 0 AND [CopiesRequested]),
  CONSTRAINT [CK_PrintJob_Status] CHECK ([Status] IN ('pending','waiting_config','printing','printed','failed','cancelled'))
);
GO

CREATE TABLE [labels].[PrintAttempts] (
  [Id] uniqueidentifier NOT NULL,
  [PrintJobId] uniqueidentifier NOT NULL,
  [AttemptNo] int NOT NULL,
  [PrinterResponse] nvarchar(500) NULL,
  [SentAt] datetime2(3) NOT NULL DEFAULT(SYSUTCDATETIME()),
  [AcknowledgedAt] datetime2(3) NULL,
  [Status] varchar(16) NOT NULL,
  CONSTRAINT [PK_PrintAttempts] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_PrintAttempts_No] UNIQUE ([PrintJobId],[AttemptNo]),
  CONSTRAINT [FK_PrintAttempts_Job] FOREIGN KEY ([PrintJobId]) REFERENCES [labels].[PrintJobs]([Id]),
  CONSTRAINT [CK_PrintAttempts_No] CHECK ([AttemptNo]>0),
  CONSTRAINT [CK_PrintAttempts_Status] CHECK ([Status] IN ('sent','acknowledged','failed','unknown'))
);
GO

CREATE TABLE [accounting].[CloseDocuments] (
  [Id] uniqueidentifier NOT NULL,
  [ClosureId] uniqueidentifier NOT NULL,
  [DocumentNumber] nvarchar(60) NOT NULL,
  [DocumentKind] varchar(28) NOT NULL DEFAULT('accounting_summary'),
  [Status] varchar(24) NOT NULL DEFAULT('prepared'),
  [CurrencyCode] varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [CashExpectedMinor] bigint NOT NULL,
  [CashCountedMinor] bigint NOT NULL,
  [CashDifferenceMinor] bigint NOT NULL,
  [SaleGrossMinor] bigint NOT NULL,
  [SaleTaxMinor] bigint NOT NULL,
  [SaleDiscountMinor] bigint NOT NULL,
  [SaleCount] int NOT NULL,
  [ReturnGrossMinor] bigint NOT NULL DEFAULT(0),
  [NetSalesMinor] bigint NOT NULL DEFAULT(0),
  [SaleCOGSMinor] bigint NOT NULL DEFAULT(0),
  [ReturnedCOGSMinor] bigint NOT NULL DEFAULT(0),
  [NetCOGSMinor] bigint NOT NULL DEFAULT(0),
  [CardCapturedMinor] bigint NOT NULL DEFAULT(0),
  [CreditRedeemedMinor] bigint NOT NULL DEFAULT(0),
  [PeriodStartAt] datetime2(3) NOT NULL,
  [PeriodEndAt] datetime2(3) NOT NULL,
  [ApprovedBy] uniqueidentifier NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_accounting_CloseDocuments_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_CloseDocuments] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_CloseDocuments_Closure] UNIQUE ([ClosureId]),
  CONSTRAINT [UQ_CloseDocuments_Number] UNIQUE ([DocumentNumber]),
  CONSTRAINT [FK_CloseDocuments_Closure] FOREIGN KEY ([ClosureId]) REFERENCES [sales].[CashClosures]([Id]),
  CONSTRAINT [FK_CloseDocuments_Currency] FOREIGN KEY ([CurrencyCode]) REFERENCES [core].[Currencies]([Code]),
  CONSTRAINT [FK_CloseDocuments_Approver] FOREIGN KEY ([ApprovedBy]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [CK_CloseDocuments_Kind] CHECK ([DocumentKind] IN ('accounting_summary','global_invoice_draft')),
  CONSTRAINT [CK_CloseDocuments_Status] CHECK ([Status] IN ('prepared','reviewed','exported','void')),
  CONSTRAINT [CK_CloseDocuments_Amounts] CHECK ([CashExpectedMinor]>=0 AND [CashCountedMinor]>=0 AND [CashDifferenceMinor]=[CashCountedMinor]-[CashExpectedMinor] AND [SaleGrossMinor]>=0 AND [SaleTaxMinor]>=0 AND [SaleDiscountMinor]>=0 AND [SaleCount]>=0 AND [ReturnGrossMinor]>=0 AND [NetSalesMinor]=[SaleGrossMinor]-[ReturnGrossMinor] AND [SaleCOGSMinor]>=0 AND [ReturnedCOGSMinor]>=0 AND [NetCOGSMinor]=[SaleCOGSMinor]-[ReturnedCOGSMinor] AND [CardCapturedMinor]>=0 AND [CreditRedeemedMinor]>=0),
  CONSTRAINT [CK_CloseDocuments_Period] CHECK ([PeriodEndAt]>=[PeriodStartAt])
);
GO

CREATE TABLE [accounting].[CloseDocumentLines] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [CloseDocumentId] uniqueidentifier NOT NULL,
  [LineNo] int NOT NULL,
  [ConceptCode] varchar(40) NOT NULL,
  [ConceptName] nvarchar(150) NOT NULL,
  [AmountMinor] bigint NOT NULL,
  CONSTRAINT [PK_CloseDocumentLines] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_CloseDocumentLines_No] UNIQUE ([CloseDocumentId],[LineNo]),
  CONSTRAINT [FK_CloseDocLines_Header] FOREIGN KEY ([CloseDocumentId]) REFERENCES [accounting].[CloseDocuments]([Id]),
  CONSTRAINT [CK_CloseDocLines_No] CHECK ([LineNo]>0)
);
GO

CREATE TABLE [accounting].[ExportJobs] (
  [Id] uniqueidentifier NOT NULL,
  [CloseDocumentId] uniqueidentifier NOT NULL,
  [RecipientCode] nvarchar(100) NOT NULL,
  [Format] varchar(16) NOT NULL,
  [BlobKey] nvarchar(500) NULL,
  [Status] varchar(20) NOT NULL DEFAULT('pending'),
  [SentAt] datetime2(3) NULL,
  [ConfirmedAt] datetime2(3) NULL,
  [ErrorText] nvarchar(500) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_accounting_ExportJobs_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_ExportJobs] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_ExportJobs_DocFormat] UNIQUE ([CloseDocumentId],[Format],[RecipientCode]),
  CONSTRAINT [FK_ExportJobs_Document] FOREIGN KEY ([CloseDocumentId]) REFERENCES [accounting].[CloseDocuments]([Id]),
  CONSTRAINT [CK_ExportJobs_Format] CHECK ([Format] IN ('PDF','CSV','JSON','XML')),
  CONSTRAINT [CK_ExportJobs_Status] CHECK ([Status] IN ('pending','generating','ready','sent','confirmed','failed'))
);
GO

CREATE TABLE [accounting].[Accounts] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [Code] varchar(30) NOT NULL,
  [Name] nvarchar(150) NOT NULL,
  [Kind] varchar(16) NOT NULL,
  [IsActive] bit NOT NULL DEFAULT(1),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_accounting_Accounts_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_Accounts] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_Accounts_Code] UNIQUE ([Code]),
  CONSTRAINT [CK_Accounts_Kind] CHECK ([Kind] IN ('asset','liability','equity','revenue','expense'))
);
GO

CREATE TABLE [accounting].[JournalEntries] (
  [Id] uniqueidentifier NOT NULL,
  [ExternalRef] nvarchar(120) NOT NULL,
  [DocumentDate] date NOT NULL,
  [Description] nvarchar(350) NOT NULL,
  [Status] varchar(16) NOT NULL DEFAULT('draft'),
  [CurrencyCode] varchar(3) COLLATE Latin1_General_100_BIN2 NOT NULL,
  [PostedAt] datetime2(3) NULL,
  [PostedBy] uniqueidentifier NULL,
  [SourceType] varchar(24) NOT NULL,
  [SourceId] uniqueidentifier NOT NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_accounting_JournalEntries_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_JournalEntries] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_JournalEntries_Reference] UNIQUE ([ExternalRef]),
  CONSTRAINT [FK_JournalEntries_Currency] FOREIGN KEY ([CurrencyCode]) REFERENCES [core].[Currencies]([Code]),
  CONSTRAINT [FK_JournalEntries_Poster] FOREIGN KEY ([PostedBy]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [CK_JournalEntries_Status] CHECK ([Status] IN ('draft','posted','reversed')),
  CONSTRAINT [CK_JournalEntries_Poster] CHECK (([Status]='draft' AND [PostedAt] IS NULL AND [PostedBy] IS NULL) OR ([Status]<>'draft' AND [PostedAt] IS NOT NULL AND [PostedBy] IS NOT NULL))
);
GO

CREATE TABLE [accounting].[JournalLines] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [JournalEntryId] uniqueidentifier NOT NULL,
  [LineNo] int NOT NULL,
  [AccountId] uniqueidentifier NOT NULL,
  [DebitMinor] bigint NOT NULL DEFAULT(0),
  [CreditMinor] bigint NOT NULL DEFAULT(0),
  [Description] nvarchar(200) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_accounting_JournalLines_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_JournalLines] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_JournalLines_No] UNIQUE ([JournalEntryId],[LineNo]),
  CONSTRAINT [FK_JournalLines_Entry] FOREIGN KEY ([JournalEntryId]) REFERENCES [accounting].[JournalEntries]([Id]),
  CONSTRAINT [FK_JournalLines_Account] FOREIGN KEY ([AccountId]) REFERENCES [accounting].[Accounts]([Id]),
  CONSTRAINT [CK_JournalLines_Amounts] CHECK ([DebitMinor]>=0 AND [CreditMinor]>=0 AND (([DebitMinor]>0 AND [CreditMinor]=0) OR ([CreditMinor]>0 AND [DebitMinor]=0)))
);
GO

CREATE TABLE [sync].[Nodes] (
  [Id] uniqueidentifier NOT NULL,
  [BranchId] uniqueidentifier NULL,
  [NodeCode] nvarchar(70) NOT NULL,
  [Kind] varchar(16) NOT NULL,
  [IsEnabled] bit NOT NULL DEFAULT(1),
  [LastSeenAt] datetime2(3) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sync_Nodes_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_SyncNodes] PRIMARY KEY ([Id]),
  CONSTRAINT [UQ_SyncNodes_Code] UNIQUE ([NodeCode]),
  CONSTRAINT [FK_SyncNodes_Branch] FOREIGN KEY ([BranchId]) REFERENCES [core].[Branches]([Id]),
  CONSTRAINT [CK_SyncNodes_Kind] CHECK (([Kind]='azure' AND [BranchId] IS NULL) OR ([Kind]='branch' AND [BranchId] IS NOT NULL))
);
GO

CREATE TABLE [sync].[Outbox] (
  [EventId] uniqueidentifier NOT NULL,
  [OriginNodeId] uniqueidentifier NOT NULL,
  [AggregateType] varchar(50) NOT NULL,
  [AggregateId] uniqueidentifier NOT NULL,
  [EventType] varchar(80) NOT NULL,
  [PayloadJson] nvarchar(max) NOT NULL,
  [SequenceNo] bigint IDENTITY(1,1) NOT NULL,
  [Status] varchar(16) NOT NULL DEFAULT('pending'),
  [AttemptCount] int NOT NULL DEFAULT(0),
  [NextAttemptAt] datetime2(3) NULL,
  [AckedAt] datetime2(3) NULL,
  [LastError] nvarchar(500) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sync_Outbox_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_SyncOutbox] PRIMARY KEY ([EventId]),
  CONSTRAINT [UQ_SyncOutbox_Sequence] UNIQUE ([SequenceNo]),
  CONSTRAINT [FK_SyncOutbox_Node] FOREIGN KEY ([OriginNodeId]) REFERENCES [sync].[Nodes]([Id]),
  CONSTRAINT [CK_SyncOutbox_Status] CHECK ([Status] IN ('pending','retry','acked','dead')),
  CONSTRAINT [CK_SyncOutbox_JSON] CHECK (ISJSON([PayloadJson])=1),
  CONSTRAINT [CK_SyncOutbox_Attempts] CHECK ([AttemptCount]>=0)
);
GO

CREATE TABLE [sync].[EventDeliveries] (
  [EventId] uniqueidentifier NOT NULL,
  [DestinationNodeId] uniqueidentifier NOT NULL,
  [Status] varchar(16) NOT NULL DEFAULT('pending'),
  [AttemptCount] int NOT NULL DEFAULT(0),
  [LastAttemptAt] datetime2(3) NULL,
  [AcknowledgedAt] datetime2(3) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sync_EventDeliveries_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_EventDeliveries] PRIMARY KEY ([EventId],[DestinationNodeId]),
  CONSTRAINT [FK_EventDeliveries_Event] FOREIGN KEY ([EventId]) REFERENCES [sync].[Outbox]([EventId]),
  CONSTRAINT [FK_EventDeliveries_Destination] FOREIGN KEY ([DestinationNodeId]) REFERENCES [sync].[Nodes]([Id]),
  CONSTRAINT [CK_EventDeliveries_Status] CHECK ([Status] IN ('pending','retry','acked','dead')),
  CONSTRAINT [CK_EventDeliveries_Attempts] CHECK ([AttemptCount]>=0)
);
GO

CREATE TABLE [sync].[Inbox] (
  [EventId] uniqueidentifier NOT NULL,
  [OriginNodeId] uniqueidentifier NOT NULL,
  [AggregateType] varchar(50) NOT NULL,
  [AggregateId] uniqueidentifier NOT NULL,
  [PayloadHash] varbinary(32) NOT NULL,
  [Status] varchar(16) NOT NULL DEFAULT('received'),
  [ReceivedAt] datetime2(3) NOT NULL DEFAULT(SYSUTCDATETIME()),
  [AppliedAt] datetime2(3) NULL,
  [ErrorText] nvarchar(500) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sync_Inbox_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_SyncInbox] PRIMARY KEY ([EventId]),
  CONSTRAINT [FK_SyncInbox_Origin] FOREIGN KEY ([OriginNodeId]) REFERENCES [sync].[Nodes]([Id]),
  CONSTRAINT [CK_SyncInbox_Status] CHECK ([Status] IN ('received','applied','rejected')),
  CONSTRAINT [CK_SyncInbox_Applied] CHECK (([Status]='applied' AND [AppliedAt] IS NOT NULL) OR ([Status]<>'applied' AND [AppliedAt] IS NULL))
);
GO

CREATE TABLE [sync].[Cursors] (
  [NodeId] uniqueidentifier NOT NULL,
  [StreamName] varchar(50) NOT NULL,
  [LastSequence] bigint NOT NULL DEFAULT(0),
  [LastSyncedAt] datetime2(3) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sync_Cursors_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_SyncCursors] PRIMARY KEY ([NodeId],[StreamName]),
  CONSTRAINT [FK_SyncCursor_Node] FOREIGN KEY ([NodeId]) REFERENCES [sync].[Nodes]([Id]),
  CONSTRAINT [CK_SyncCursor_Nonnegative] CHECK ([LastSequence]>=0)
);
GO

CREATE TABLE [sync].[SyncErrors] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [NodeId] uniqueidentifier NULL,
  [EventId] uniqueidentifier NULL,
  [Code] varchar(70) NOT NULL,
  [Details] nvarchar(2000) NOT NULL,
  [Status] varchar(16) NOT NULL DEFAULT('open'),
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sync_SyncErrors_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_SyncErrors] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_SyncErrors_Node] FOREIGN KEY ([NodeId]) REFERENCES [sync].[Nodes]([Id]),
  CONSTRAINT [CK_SyncErrors_Status] CHECK ([Status] IN ('open','resolved'))
);
GO

CREATE TABLE [audit].[Operations] (
  [Id] uniqueidentifier NOT NULL,
  [ActorId] uniqueidentifier NULL,
  [BranchId] uniqueidentifier NULL,
  [Scope] varchar(80) NOT NULL,
  [OperationKey] varchar(128) NOT NULL,
  [Fingerprint] varbinary(32) NOT NULL,
  [ResultJson] nvarchar(max) NOT NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_audit_Operations_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_AuditOperations] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_Operations_Staff] FOREIGN KEY ([ActorId]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [FK_Operations_Branch] FOREIGN KEY ([BranchId]) REFERENCES [core].[Branches]([Id]),
  CONSTRAINT [CK_Operations_JSON] CHECK (ISJSON([ResultJson])=1)
);
GO

CREATE TABLE [audit].[EntityChanges] (
  [Id] uniqueidentifier NOT NULL DEFAULT(NEWID()),
  [EntityType] varchar(80) NOT NULL,
  [EntityId] uniqueidentifier NOT NULL,
  [Operation] varchar(20) NOT NULL,
  [ActorId] uniqueidentifier NULL,
  [BranchId] uniqueidentifier NULL,
  [BeforeJson] nvarchar(max) NULL,
  [AfterJson] nvarchar(max) NULL,
  [Reason] nvarchar(350) NULL,
  [CreatedBy] uniqueidentifier NULL,
  [ModifiedBy] uniqueidentifier NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_audit_EntityChanges_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [ModifiedAt] datetime2(3) NULL,
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_EntityChanges] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_EntityChanges_Actor] FOREIGN KEY ([ActorId]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [FK_EntityChanges_Branch] FOREIGN KEY ([BranchId]) REFERENCES [core].[Branches]([Id]),
  CONSTRAINT [CK_EntityChanges_Operation] CHECK ([Operation] IN ('create','update','void','approve','sync_conflict')),
  CONSTRAINT [CK_EntityChanges_Before] CHECK ([BeforeJson] IS NULL OR ISJSON([BeforeJson])=1),
  CONSTRAINT [CK_EntityChanges_After] CHECK ([AfterJson] IS NULL OR ISJSON([AfterJson])=1)
);
GO

-- FK diferidas para romper dependencia circular POS/anticipos
ALTER TABLE [sales].[Sales] WITH CHECK ADD CONSTRAINT [FK_Sales_Till]
  FOREIGN KEY ([TillId]) REFERENCES [sales].[CashTills]([Id]);
GO
ALTER TABLE [sales].[SaleReversals] WITH CHECK ADD CONSTRAINT [FK_Reversals_Till]
  FOREIGN KEY ([TillId]) REFERENCES [sales].[CashTills]([Id]);
GO
ALTER TABLE [sales].[SaleTenders] WITH CHECK ADD CONSTRAINT [FK_Tenders_Credit]
  FOREIGN KEY ([CreditId]) REFERENCES [credits].[Credits]([Id]);
GO


-- INDICES DE CONSULTA Y UNICIDAD FILTRADA

CREATE INDEX [IX_Locations_Branch] ON [core].[Locations] ([BranchId],[IsActive]);
GO

CREATE INDEX [IX_Sessions_Staff_Expires] ON [security].[Sessions] ([StaffId],[ExpiresAt]);
GO

CREATE INDEX [IX_BranchAssignmentAudit_Staff] ON [security].[BranchAssignmentAudit] ([StaffId],[CreatedAt]);
GO

CREATE UNIQUE INDEX [UX_Customers_Code] ON [crm].[Customers] ([CustomerCode]) WHERE [CustomerCode] IS NOT NULL;
GO

CREATE INDEX [IX_Customers_Name] ON [crm].[Customers] ([DisplayName]);
GO

CREATE UNIQUE INDEX [UX_Suppliers_Code] ON [sourcing].[Suppliers] ([SupplierCode]) WHERE [SupplierCode] IS NOT NULL;
GO

CREATE INDEX [IX_Products_Name] ON [catalog].[Products] ([Name]);
GO

CREATE INDEX [IX_Items_Product] ON [catalog].[Items] ([ProductId],[Status]);
GO

CREATE INDEX [IX_Items_VariantName] ON [catalog].[Items] ([VariantName]);
GO

CREATE UNIQUE INDEX [UX_ItemIdentifier_Global] ON [catalog].[ItemIdentifiers] ([Kind],[RawCode]) WHERE [IsActive]=1 AND [SupplierId] IS NULL;
GO

CREATE UNIQUE INDEX [UX_ItemIdentifier_Supplier] ON [catalog].[ItemIdentifiers] ([SupplierId],[Kind],[RawCode]) WHERE [IsActive]=1 AND [SupplierId] IS NOT NULL;
GO

CREATE INDEX [IX_ItemIdentifier_Item] ON [catalog].[ItemIdentifiers] ([ItemId],[IsActive]);
GO

CREATE INDEX [IX_Images_Product] ON [catalog].[ItemImages] ([ProductId],[SortOrder]);
GO

CREATE INDEX [IX_PriceHistory_ItemTime] ON [catalog].[PriceHistory] ([ItemId],[EffectiveAt]);
GO

CREATE INDEX [IX_StockBalances_Location_Pool] ON [inventory].[StockBalances] ([LocationId],[Pool],[ItemId]) INCLUDE ([OnHand],[Reserved]);
GO

CREATE INDEX [IX_StockMovement_ItemLocationDate] ON [inventory].[StockMovements] ([ItemId],[LocationId],[CreatedAt]);
GO

CREATE INDEX [IX_StockMovement_Source] ON [inventory].[StockMovements] ([SourceType],[SourceId]);
GO

CREATE INDEX [IX_StockTransfer_OriginStatus] ON [inventory].[StockTransfers] ([FromLocationId],[Status]);
GO

CREATE UNIQUE INDEX [UX_Reservation_Ref] ON [inventory].[StockReservations] ([ReferenceType],[ReferenceId],[ItemId]);
GO

CREATE INDEX [IX_Reservation_Expiry] ON [inventory].[StockReservations] ([Status],[ExpiresAt]);
GO

CREATE INDEX [IX_PO_LocationDate] ON [purchasing].[PurchaseOrders] ([LocationId],[CreatedAt]);
GO

CREATE INDEX [IX_PO_SupplierStatus] ON [purchasing].[PurchaseOrders] ([SupplierId],[Status]);
GO

CREATE INDEX [IX_Container_LocationStatus] ON [receiving].[ImportContainers] ([LocationId],[Status]);
GO

CREATE INDEX [IX_ScanSession_ContainerStatus] ON [receiving].[ScanSessions] ([ContainerId],[Status]);
GO

CREATE INDEX [IX_ScanEvents_Session_Status] ON [receiving].[ScanEvents] ([ScanSessionId],[MatchStatus]);
GO

CREATE INDEX [IX_ScanEvents_Code] ON [receiving].[ScanEvents] ([RawCode]);
GO

CREATE INDEX [IX_ScanEvents_Item] ON [receiving].[ScanEvents] ([ItemId]);
GO

CREATE UNIQUE INDEX [UX_GoodsReceipt_ScanSession] ON [purchasing].[GoodsReceipts] ([ScanSessionId]) WHERE [ScanSessionId] IS NOT NULL;
GO

CREATE INDEX [IX_GoodsReceipt_LocationDate] ON [purchasing].[GoodsReceipts] ([LocationId],[PostedAt]);
GO

CREATE INDEX [IX_GoodsReceiptLines_Item] ON [purchasing].[GoodsReceiptLines] ([ItemId]);
GO

CREATE INDEX [IX_Sales_BranchDate] ON [sales].[Sales] ([BranchId],[CreatedAt]);
GO

CREATE INDEX [IX_Sales_CustomerDate] ON [sales].[Sales] ([CustomerId],[CreatedAt]);
GO

CREATE INDEX [IX_Sales_Till] ON [sales].[Sales] ([TillId],[CreatedAt]);
GO

CREATE INDEX [IX_SaleLines_Item] ON [sales].[SaleLines] ([ItemId]);
GO

CREATE INDEX [IX_SaleTenders_Sale] ON [sales].[SaleTenders] ([SaleId],[TenderKind]);
GO

CREATE INDEX [IX_Reversals_Sale] ON [sales].[SaleReversals] ([SaleId],[CreatedAt]);
GO

CREATE UNIQUE INDEX [UX_OpenTill_Register] ON [sales].[CashTills] ([RegisterId]) WHERE [Status]='open';
GO

CREATE INDEX [IX_Tills_CashierDate] ON [sales].[CashTills] ([CashierId],[OpenedAt]);
GO

CREATE INDEX [IX_CashEntries_TillDate] ON [sales].[CashEntries] ([TillId],[CreatedAt]);
GO

CREATE UNIQUE INDEX [UX_CashEntries_Tender] ON [sales].[CashEntries] ([SaleTenderId]) WHERE [SaleTenderId] IS NOT NULL;
GO

CREATE UNIQUE INDEX [UX_CashEntries_Refund] ON [sales].[CashEntries] ([ReversalId]) WHERE [ReversalId] IS NOT NULL;
GO

CREATE UNIQUE INDEX [UX_CashEntries_Opening] ON [sales].[CashEntries] ([TillId]) WHERE [Kind]='opening';
GO

CREATE UNIQUE INDEX [UX_CashCounts_TillSubmitted] ON [sales].[CashCounts] ([TillId]) WHERE [Status]='submitted';
GO

CREATE INDEX [IX_Credits_CustomerStatus] ON [credits].[Credits] ([CustomerId],[Status]);
GO

CREATE INDEX [IX_CreditMovement_CreditDate] ON [credits].[CreditMovements] ([CreditId],[CreatedAt]);
GO

CREATE INDEX [IX_CreditTransfers_OriginStatus] ON [credits].[CreditTransfers] ([FromBranchId],[Status]);
GO

CREATE INDEX [IX_CreditTransfers_DestinationStatus] ON [credits].[CreditTransfers] ([ToBranchId],[Status]);
GO

CREATE UNIQUE INDEX [UX_CreditTransfer_LockEvent] ON [credits].[CreditTransfers] ([OriginLockEventId]) WHERE [OriginLockEventId] IS NOT NULL;
GO

CREATE INDEX [IX_CreditRedemption_Sale] ON [credits].[CreditRedemptions] ([SaleId]);
GO

CREATE UNIQUE INDEX [UX_WebOrders_Reference] ON [webstore].[Orders] ([ExternalOrderRef]) WHERE [ExternalOrderRef] IS NOT NULL;
GO

CREATE INDEX [IX_WebOrders_StatusDate] ON [webstore].[Orders] ([Status],[PlacedAt]);
GO

CREATE INDEX [IX_WebCarts_Customer] ON [webstore].[Carts] ([CustomerId],[Status]);
GO

CREATE UNIQUE INDEX [UX_OrderLines_Reservation] ON [webstore].[OrderLines] ([ReservationId]) WHERE [ReservationId] IS NOT NULL;
GO

CREATE INDEX [IX_WebPayments_Order] ON [webstore].[Payments] ([OrderId],[Status]);
GO

CREATE INDEX [IX_Fulfillment_BranchStatus] ON [webstore].[Fulfillments] ([BranchId],[Status]);
GO

CREATE UNIQUE INDEX [UX_Printers_Default] ON [labels].[Printers] ([BranchId]) WHERE [IsDefault]=1 AND [IsActive]=1;
GO

CREATE UNIQUE INDEX [UX_PrintJob_ReceiptLine] ON [labels].[PrintJobs] ([ReceiptLineId]) WHERE [ReceiptLineId] IS NOT NULL;
GO

CREATE INDEX [IX_PrintJobs_BranchStatus] ON [labels].[PrintJobs] ([BranchId],[Status],[CreatedAt]);
GO

CREATE INDEX [IX_CloseDocuments_StatusDate] ON [accounting].[CloseDocuments] ([Status],[CreatedAt]);
GO

CREATE INDEX [IX_ExportJobs_Status] ON [accounting].[ExportJobs] ([Status],[CreatedAt]);
GO

CREATE INDEX [IX_JournalEntries_Source] ON [accounting].[JournalEntries] ([SourceType],[SourceId]);
GO

CREATE UNIQUE INDEX [UX_SyncNodes_Branch] ON [sync].[Nodes] ([BranchId]) WHERE [BranchId] IS NOT NULL;
GO

CREATE INDEX [IX_Outbox_Sendable] ON [sync].[Outbox] ([Status],[NextAttemptAt],[SequenceNo]) INCLUDE ([EventType],[OriginNodeId]);
GO

CREATE INDEX [IX_EventDeliveries_NodeStatus] ON [sync].[EventDeliveries] ([DestinationNodeId],[Status],[EventId]);
GO

CREATE INDEX [IX_SyncInbox_OriginDate] ON [sync].[Inbox] ([OriginNodeId],[ReceivedAt]);
GO

CREATE INDEX [IX_SyncErrors_Status] ON [sync].[SyncErrors] ([Status],[CreatedAt]);
GO

CREATE UNIQUE INDEX [UX_Operations_Idempotency] ON [audit].[Operations] ([Scope],[OperationKey]);
GO

CREATE INDEX [IX_EntityChanges_EntityDate] ON [audit].[EntityChanges] ([EntityType],[EntityId],[CreatedAt]);
GO

-- DATOS DE REFERENCIA MINIMOS (CONFIGURACION REAL DE NEGOCIO PENDIENTE)
INSERT INTO [core].[Currencies] ([Code],[Name],[Exponent]) VALUES
  ('NIO',N'Córdoba nicaragüense',2),('USD',N'Dólar estadounidense',2);
GO
INSERT INTO [security].[Roles] ([Code],[Description]) VALUES
  ('OWNER',N'Propietario del negocio'),('MANAGER',N'Gerente autorizado'),
  ('CASHIER',N'Cajero'),('INVENTORY',N'Inventario'),('ACCOUNTANT',N'Contador');
GO

-- ======= FIN 01_SAVIA_Schemas_Tables_Indexes.sql =======


-- ======= INICIO 02_SAVIA_Procedures.sql =======
/* SAVIA - Procedimientos transaccionales. Los workers .NET orquestan sync,
   impresion real, roles, autenticacion y validacion fiscal externa. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ==============================================================
   SYNC: cola persistente con rutas por nodo (no solo por sucursal).
   Debe invocarse EN LA MISMA transaccion que el cambio de negocio.
   ============================================================= */
CREATE OR ALTER PROCEDURE [sync].[usp_EnqueueEvent]
  @EventId uniqueidentifier, @OriginNodeId uniqueidentifier,
  @AggregateType varchar(50), @AggregateId uniqueidentifier,
  @EventType varchar(80), @PayloadJson nvarchar(max),
  @DestinationNodeId uniqueidentifier = NULL
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  IF @@TRANCOUNT=0 THROW 51000, 'Encolar evento exige transaccion de negocio.', 1;
  IF ISJSON(@PayloadJson) <> 1 THROW 51001, 'Payload JSON invalido.', 1;
  IF NOT EXISTS (SELECT 1 FROM sync.Nodes WHERE Id=@OriginNodeId AND IsEnabled=1)
    THROW 51002, 'Nodo origen no autorizado o no configurado.', 1;
  DECLARE @to uniqueidentifier = @DestinationNodeId;
  IF @to IS NULL AND EXISTS (SELECT 1 FROM sync.Nodes WHERE Id=@OriginNodeId AND Kind='branch')
  BEGIN
    SELECT @to=Id FROM sync.Nodes WHERE Kind='azure' AND IsEnabled=1;
    IF @to IS NULL THROW 51003, 'Nodo Azure no configurado. No se omite la sincronizacion.', 1;
  END;
  IF @to IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sync.Nodes WHERE Id=@to AND IsEnabled=1 AND Id<>@OriginNodeId)
    THROW 51004, 'Nodo destino invalido.', 1;
  -- Evita huecos de commit: otro escritor no obtiene SequenceNo hasta
  -- que la transaccion previa confirma o revierte. Requiere trafico moderado.
  DECLARE @lockResult int;
  EXEC @lockResult=sys.sp_getapplock @Resource=N'savia.sync.outbox_commit_order',
      @LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @lockResult<0 THROW 51016,'No se obtuvo lock de secuencia outbox.',1;
  IF EXISTS (SELECT 1 FROM sync.Outbox WHERE EventId=@EventId)
  BEGIN
    IF EXISTS (SELECT 1 FROM sync.Outbox WHERE EventId=@EventId AND
       (OriginNodeId<>@OriginNodeId OR AggregateType<>@AggregateType OR
        AggregateId<>@AggregateId OR EventType<>@EventType
        OR CONVERT(varbinary(max),PayloadJson)<>CONVERT(varbinary(max),@PayloadJson)))
      THROW 51005, 'EventId reutilizado con diferente contenido.', 1;
    RETURN;
  END;
  INSERT INTO sync.Outbox(EventId,OriginNodeId,AggregateType,AggregateId,EventType,PayloadJson)
    VALUES(@EventId,@OriginNodeId,@AggregateType,@AggregateId,@EventType,@PayloadJson);
  IF @to IS NOT NULL
    INSERT INTO sync.EventDeliveries(EventId,DestinationNodeId) VALUES(@EventId,@to);
END;
GO

CREATE OR ALTER PROCEDURE [sync].[usp_RouteEvent]
  @EventId uniqueidentifier, @DestinationNodeId uniqueidentifier
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  BEGIN TRANSACTION;
  BEGIN TRY
    DECLARE @seq bigint;
    SELECT @seq=SequenceNo FROM sync.Outbox WITH (UPDLOCK,HOLDLOCK) WHERE EventId=@EventId;
    IF @seq IS NULL THROW 51006, 'Evento no existe.', 1;
    IF NOT EXISTS (SELECT 1 FROM sync.Nodes WHERE Id=@DestinationNodeId AND IsEnabled=1)
      THROW 51007, 'Destino no autorizado.', 1;
    IF EXISTS (SELECT 1 FROM sync.Cursors WHERE NodeId=@DestinationNodeId AND LastSequence>=@seq)
      THROW 51008, 'Ruta tardia: nodo ya supero este cursor. Reemitir evento nuevo.', 1;
    IF NOT EXISTS (SELECT 1 FROM sync.EventDeliveries WHERE EventId=@EventId AND DestinationNodeId=@DestinationNodeId)
      INSERT INTO sync.EventDeliveries(EventId,DestinationNodeId) VALUES(@EventId,@DestinationNodeId);
    COMMIT;
  END TRY
  BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [sync].[usp_PullEvents]
  @DestinationNodeId uniqueidentifier, @AfterSequence bigint=0, @BatchSize int=200
AS
BEGIN
  SET NOCOUNT ON;
  IF @BatchSize NOT BETWEEN 1 AND 500 THROW 51009, 'BatchSize fuera de rango.', 1;
  IF @AfterSequence<0 THROW 51010, 'Cursor invalido.', 1;
  SELECT TOP (@BatchSize) e.SequenceNo,e.EventId,e.OriginNodeId,
        e.AggregateType,e.AggregateId,e.EventType,e.PayloadJson
  FROM sync.Outbox e
  JOIN sync.EventDeliveries d ON d.EventId=e.EventId
  WHERE d.DestinationNodeId=@DestinationNodeId
    AND e.SequenceNo>@AfterSequence AND d.Status IN ('pending','retry','acked')
  ORDER BY e.SequenceNo;
  -- acked puede repetirse hasta que el cursor avance: el receptor es idempotente.
END;
GO

CREATE OR ALTER PROCEDURE [sync].[usp_AcknowledgeDelivery]
  @EventId uniqueidentifier, @DestinationNodeId uniqueidentifier
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  BEGIN TRANSACTION;
  BEGIN TRY
    UPDATE sync.EventDeliveries WITH (UPDLOCK)
      SET Status='acked',AcknowledgedAt=COALESCE(AcknowledgedAt,SYSUTCDATETIME())
      WHERE EventId=@EventId AND DestinationNodeId=@DestinationNodeId AND Status<>'dead';
    IF @@ROWCOUNT<>1 THROW 51011, 'Entrega inexistente o bloqueada.', 1;
    IF NOT EXISTS (SELECT 1 FROM sync.EventDeliveries WHERE EventId=@EventId AND Status<>'acked')
      UPDATE sync.Outbox SET Status='acked',AckedAt=SYSUTCDATETIME() WHERE EventId=@EventId;
    COMMIT;
  END TRY
  BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [sync].[usp_RecordAppliedInbox]
  @EventId uniqueidentifier, @OriginNodeId uniqueidentifier,
  @AggregateType varchar(50), @AggregateId uniqueidentifier,
  @PayloadJson nvarchar(max)
AS
BEGIN
  SET NOCOUNT ON;
  -- IMPORTANTE: invocar dentro de la misma TX que el handler del evento.
  IF @@TRANCOUNT=0 THROW 51012, 'Inbox requiere transaccion externa del handler de negocio.', 1;
  IF ISJSON(@PayloadJson)<>1 THROW 51013, 'Payload invalido.', 1;
  DECLARE @hash varbinary(32)=HASHBYTES('SHA2_256',CONVERT(varbinary(max),@PayloadJson));
  IF EXISTS (SELECT 1 FROM sync.Inbox WITH (UPDLOCK,HOLDLOCK) WHERE EventId=@EventId)
  BEGIN
    IF EXISTS(SELECT 1 FROM sync.Inbox WHERE EventId=@EventId AND
        (OriginNodeId<>@OriginNodeId OR PayloadHash<>@hash OR Status<>'applied'))
      THROW 51014, 'Duplicado incompatible o evento no aplicado.', 1;
    RETURN;
  END;
  INSERT INTO sync.Inbox(EventId,OriginNodeId,AggregateType,AggregateId,PayloadHash,Status,AppliedAt)
    VALUES(@EventId,@OriginNodeId,@AggregateType,@AggregateId,@hash,'applied',SYSUTCDATETIME());
END;
GO

CREATE OR ALTER PROCEDURE [sync].[usp_AdvanceCursor]
  @NodeId uniqueidentifier,@StreamName varchar(50),@LastSequence bigint
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  IF @LastSequence<0 THROW 51015,'Cursor negativo.',1;
  BEGIN TRANSACTION;
  BEGIN TRY
    IF EXISTS(SELECT 1 FROM sync.Cursors WITH (UPDLOCK,HOLDLOCK) WHERE NodeId=@NodeId AND StreamName=@StreamName)
      UPDATE sync.Cursors SET LastSequence=CASE WHEN LastSequence<@LastSequence THEN @LastSequence ELSE LastSequence END,
            LastSyncedAt=SYSUTCDATETIME()
        WHERE NodeId=@NodeId AND StreamName=@StreamName;
    ELSE
      INSERT INTO sync.Cursors(NodeId,StreamName,LastSequence,LastSyncedAt)
        VALUES(@NodeId,@StreamName,@LastSequence,SYSUTCDATETIME());
    COMMIT;
  END TRY
  BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* ==============================================================
   INVENTARIO: registro atomico + idempotente de cada movimiento.
   Un movimiento mueve UN pool, sin cantidades negativas.
   ============================================================= */
CREATE OR ALTER PROCEDURE [inventory].[usp_ApplyMovement]
  @OperationId uniqueidentifier, @ItemId uniqueidentifier,@LocationId uniqueidentifier,
  @Pool varchar(12),@Kind varchar(24), @OnHandDelta int,
  @SourceType varchar(30),@SourceId uniqueidentifier,
  @ReservedDelta int=0,@ActorId uniqueidentifier=NULL,@UnitCostMinor bigint=NULL,
  @MovementId uniqueidentifier=NULL OUTPUT
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  DECLARE @ownTran bit=0;
  IF @@TRANCOUNT=0 BEGIN SET @ownTran=1; BEGIN TRANSACTION; END;
  BEGIN TRY
    IF @MovementId IS NULL SET @MovementId=NEWID();
    IF EXISTS(SELECT 1 FROM inventory.StockMovements WITH (UPDLOCK,HOLDLOCK) WHERE OperationId=@OperationId)
    BEGIN
      IF EXISTS(SELECT 1 FROM inventory.StockMovements WHERE OperationId=@OperationId AND
          (ItemId<>@ItemId OR LocationId<>@LocationId OR Pool<>@Pool OR
           OnHandDelta<>@OnHandDelta OR ReservedDelta<>@ReservedDelta OR Kind<>@Kind OR
           SourceType<>@SourceType OR SourceId<>@SourceId))
        THROW 51101,'OperationId repetido con otra instruccion de stock.',1;
      SELECT @MovementId=Id FROM inventory.StockMovements WHERE OperationId=@OperationId;
      IF @ownTran=1 COMMIT;
      RETURN;
    END;
    DECLARE @on bigint,@reserved bigint,@nextOn bigint,@nextReserved bigint;
    SELECT @on=OnHand,@reserved=Reserved
      FROM inventory.StockBalances WITH (UPDLOCK,HOLDLOCK)
      WHERE ItemId=@ItemId AND LocationId=@LocationId AND Pool=@Pool;
    IF @on IS NULL
    BEGIN
      INSERT INTO inventory.StockBalances(ItemId,LocationId,Pool,OnHand,Reserved)
        VALUES(@ItemId,@LocationId,@Pool,0,0);
      SET @on=0; SET @reserved=0;
    END;
    SET @nextOn=@on+CONVERT(bigint,@OnHandDelta);
    SET @nextReserved=@reserved+CONVERT(bigint,@ReservedDelta);
    IF @nextOn<0 OR @nextOn>1000000000 OR @nextReserved<0 OR @nextReserved>@nextOn OR
        (@OnHandDelta=0 AND @ReservedDelta=0)
      THROW 51102,'Movimiento excede el stock disponible o deja saldo invalido.',1;
    UPDATE inventory.StockBalances SET OnHand=CONVERT(int,@nextOn),Reserved=CONVERT(int,@nextReserved),
      ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId
      WHERE ItemId=@ItemId AND LocationId=@LocationId AND Pool=@Pool AND Status='active';
    IF @@ROWCOUNT<>1 THROW 51103,'Pool de inventario congelado.',1;
    INSERT INTO inventory.StockMovements(Id,OperationId,ItemId,LocationId,Pool,Kind,OnHandDelta,
      ReservedDelta,OnHandAfter,ReservedAfter,UnitCostMinor,SourceType,SourceId,CreatedBy)
      VALUES(@MovementId,@OperationId,@ItemId,@LocationId,@Pool,@Kind,@OnHandDelta,@ReservedDelta,
      CONVERT(int,@nextOn),CONVERT(int,@nextReserved),@UnitCostMinor,@SourceType,@SourceId,@ActorId);
    IF @ownTran=1 COMMIT;
  END TRY
  BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* ==============================================================
   CATALOGO: SKU interno unico + codigos externos preservados.
   ============================================================= */
CREATE OR ALTER PROCEDURE [catalog].[usp_RegisterProduct]
 @ProductId uniqueidentifier,@Name nvarchar(200),@OriginNodeId uniqueidentifier,@EventId uniqueidentifier,
 @CategoryId uniqueidentifier=NULL,@BrandId uniqueidentifier=NULL,@ActorId uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF LEN(LTRIM(RTRIM(@Name)))=0 THROW 51200,'Nombre de modelo obligatorio.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
  IF EXISTS(SELECT 1 FROM catalog.Products WHERE Id=@ProductId)
  BEGIN
    IF EXISTS(SELECT 1 FROM catalog.Products WHERE Id=@ProductId AND Name<>@Name)
      THROW 51210,'ProductId reutilizado con otro nombre.',1;
    COMMIT; RETURN;
  END;
  INSERT INTO catalog.Products(Id,CategoryId,BrandId,Name,Status,CreatedBy)
     VALUES(@ProductId,@CategoryId,@BrandId,@Name,'active',@ActorId);
  DECLARE @payload nvarchar(max)=(SELECT @ProductId AS productId,@Name AS name,
     @CategoryId AS categoryId,@BrandId AS brandId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
  EXEC sync.usp_EnqueueEvent @EventId,@OriginNodeId,'product',@ProductId,
     'catalog.product_registered',@payload;
  COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [catalog].[usp_RegisterItem]
 @ProductId uniqueidentifier,@Sku nvarchar(100),@VariantName nvarchar(200),
 @CurrencyCode varchar(3),@UnitPriceMinor bigint,@ItemId uniqueidentifier,
 @OriginNodeId uniqueidentifier,@EventId uniqueidentifier,
 @SizeId uniqueidentifier=NULL,@ColorId uniqueidentifier=NULL,@Barcode nvarchar(128)=NULL,
 @SupplierId uniqueidentifier=NULL,@SupplierSku nvarchar(128)=NULL,
 @UnitCostMinor bigint=NULL,@ActorId uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Barcode IS NULL AND @SupplierSku IS NULL
   THROW 51201,'Registrar codigo del proveedor o barcode antes de habilitar el escaneo.',1;
 IF @SupplierSku IS NOT NULL AND @SupplierId IS NULL
   THROW 51202,'SupplierSku necesita proveedor.',1;
 IF @UnitPriceMinor<0 THROW 51203,'Precio negativo.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM catalog.Items WHERE Id=@ItemId)
   BEGIN
     IF NOT EXISTS(SELECT 1 FROM catalog.Items WHERE Id=@ItemId AND Sku=@Sku AND ProductId=@ProductId)
        THROW 51211,'ItemId reutilizado con otra variante.',1;
     COMMIT; RETURN;
   END;
   IF @Barcode IS NOT NULL AND EXISTS(SELECT 1 FROM catalog.ItemIdentifiers WITH(UPDLOCK,HOLDLOCK)
        WHERE RawCode=@Barcode AND Kind='barcode' AND SupplierId IS NULL AND IsActive=1)
     THROW 51204,'Barcode ya asociado a una variante. Buscar producto antes de crear.',1;
   IF @SupplierSku IS NOT NULL AND EXISTS(SELECT 1 FROM catalog.ItemIdentifiers WITH(UPDLOCK,HOLDLOCK)
        WHERE RawCode=@SupplierSku AND Kind='supplier_sku' AND SupplierId=@SupplierId AND IsActive=1)
     THROW 51205,'SKU del proveedor ya asociado. Revisar variante.',1;
   INSERT INTO catalog.Items(Id,ProductId,SizeId,ColorId,Sku,VariantName,CurrencyCode,
     UnitPriceMinor,UnitCostMinor,Status,CreatedBy)
     VALUES(@ItemId,@ProductId,@SizeId,@ColorId,@Sku,@VariantName,@CurrencyCode,
     @UnitPriceMinor,@UnitCostMinor,CASE WHEN @UnitPriceMinor=0 OR @UnitCostMinor IS NULL THEN 'draft' ELSE 'active' END,@ActorId);
   IF @Barcode IS NOT NULL
     INSERT INTO catalog.ItemIdentifiers(ItemId,Kind,RawCode,IsPrimary,CreatedBy)
       VALUES(@ItemId,'barcode',@Barcode,1,@ActorId);
   IF @SupplierSku IS NOT NULL
     INSERT INTO catalog.ItemIdentifiers(ItemId,SupplierId,Kind,RawCode,CreatedBy)
       VALUES(@ItemId,@SupplierId,'supplier_sku',@SupplierSku,@ActorId);
   DECLARE @payload nvarchar(max)=(SELECT @ItemId AS itemId,@ProductId AS productId,
       @Sku AS sku,@VariantName AS variantName,@SizeId AS sizeId,@ColorId AS colorId,
       @CurrencyCode AS currency,@UnitPriceMinor AS priceMinor,@UnitCostMinor AS costMinor,
       @Barcode AS barcode,@SupplierId AS supplierId,@SupplierSku AS supplierSku
       FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   EXEC sync.usp_EnqueueEvent @EventId,@OriginNodeId,'item',@ItemId,
      'catalog.item_registered',@payload;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [catalog].[usp_ChangePrice]
 @ItemId uniqueidentifier,@NewPriceMinor bigint,@ActorId uniqueidentifier,
 @OriginNodeId uniqueidentifier,@EventId uniqueidentifier,@Reason nvarchar(250)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @NewPriceMinor<0 OR LEN(LTRIM(RTRIM(@Reason)))=0 THROW 51206,'Precio/razon invalida.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   DECLARE @old bigint,@currency varchar(3);
   SELECT @old=UnitPriceMinor,@currency=CurrencyCode FROM catalog.Items WITH(UPDLOCK,HOLDLOCK) WHERE Id=@ItemId AND Status='active';
   IF @old IS NULL THROW 51207,'Variante activa inexistente.',1;
   IF @old<>@NewPriceMinor
   BEGIN
      UPDATE catalog.Items SET UnitPriceMinor=@NewPriceMinor,ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME() WHERE Id=@ItemId;
      INSERT INTO catalog.PriceHistory(ItemId,OldPriceMinor,NewPriceMinor,CurrencyCode,EffectiveAt,Reason,CreatedBy)
         VALUES(@ItemId,@old,@NewPriceMinor,@currency,SYSUTCDATETIME(),@Reason,@ActorId);
   END;
   DECLARE @payload nvarchar(max)=(SELECT @ItemId AS itemId,@NewPriceMinor AS priceMinor,
         @currency AS currency,@EventId AS eventId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   EXEC sync.usp_EnqueueEvent @EventId,@OriginNodeId,'item',@ItemId,'catalog.price_changed',@payload;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* ==============================================================
   RECEPCION DE CONTENEDOR: lectura -> revision -> posting en stock.
   Los desconocidos nunca incrementan existencia automaticamente.
   ============================================================= */
CREATE OR ALTER PROCEDURE [receiving].[usp_RecordScan]
 @ScanId uniqueidentifier,@ScanSessionId uniqueidentifier,@RawCode nvarchar(128),
 @Quantity int=1,@DeviceCode nvarchar(80)=NULL,@ActorId uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Quantity NOT BETWEEN 1 AND 10000 OR LEN(LTRIM(RTRIM(@RawCode)))=0
   THROW 51301,'Lectura invalida.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM receiving.ScanEvents WITH(UPDLOCK,HOLDLOCK) WHERE Id=@ScanId)
   BEGIN
     IF EXISTS(SELECT 1 FROM receiving.ScanEvents WHERE Id=@ScanId AND
         (ScanSessionId<>@ScanSessionId OR RawCode<>@RawCode OR Quantity<>@Quantity))
       THROW 51302,'ScanId repetido con contenido distinto.',1;
     SELECT Id,ItemId,MatchStatus,Quantity FROM receiving.ScanEvents WHERE Id=@ScanId;
     COMMIT;
     RETURN;
   END;
   DECLARE @supplier uniqueidentifier,@status varchar(16),@matched uniqueidentifier=NULL,@matches int;
   SELECT @supplier=c.SupplierId,@status=s.Status FROM receiving.ScanSessions s WITH(UPDLOCK,HOLDLOCK)
     JOIN receiving.ImportContainers c ON c.Id=s.ContainerId WHERE s.Id=@ScanSessionId;
   IF @status IS NULL OR @status<>'counting' THROW 51303,'Sesion de escaneo no abierta.',1;
   DECLARE @candidates TABLE(ItemId uniqueidentifier PRIMARY KEY);
   INSERT INTO @candidates(ItemId)
    SELECT DISTINCT ItemId FROM catalog.ItemIdentifiers
      WHERE RawCode=@RawCode AND IsActive=1 AND
         ((Kind='barcode' AND SupplierId IS NULL)
          OR (SupplierId=@supplier AND Kind IN ('supplier_sku','barcode','alias'))
          OR (Kind='alias' AND SupplierId IS NULL));
   SELECT @matches=COUNT(*),@matched=MIN(ItemId) FROM @candidates;
   SET @status=CASE WHEN @matches=0 THEN 'unknown' WHEN @matches=1 THEN 'matched' ELSE 'ambiguous' END;
   INSERT INTO receiving.ScanEvents(Id,ScanSessionId,ItemId,RawCode,Quantity,MatchStatus,DeviceCode,CreatedBy)
     VALUES(@ScanId,@ScanSessionId,CASE WHEN @matches=1 THEN @matched ELSE NULL END,
            @RawCode,@Quantity,@status,@DeviceCode,@ActorId);
   SELECT @ScanId AS ScanId,CASE WHEN @matches=1 THEN @matched ELSE NULL END AS ItemId,@status AS MatchStatus,@Quantity AS Quantity;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [receiving].[usp_ResolveScan]
 @ScanId uniqueidentifier,@ItemId uniqueidentifier,@ReviewerId uniqueidentifier,@Reason nvarchar(250)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF LEN(LTRIM(RTRIM(@Reason)))=0 THROW 51304,'Motivo obligatorio.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   DECLARE @code nvarchar(128),@supplier uniqueidentifier,@sessionStatus varchar(16);
   SELECT @code=e.RawCode,@supplier=c.SupplierId,@sessionStatus=s.Status
   FROM receiving.ScanEvents e WITH(UPDLOCK,HOLDLOCK)
     JOIN receiving.ScanSessions s ON s.Id=e.ScanSessionId
     JOIN receiving.ImportContainers c ON c.Id=s.ContainerId
   WHERE e.Id=@ScanId AND e.MatchStatus IN ('unknown','ambiguous');
   IF @code IS NULL OR @sessionStatus NOT IN ('counting','review')
     THROW 51305,'Escaneo no resoluble en su estado actual.',1;
   IF NOT EXISTS(SELECT 1 FROM catalog.ItemIdentifiers WHERE ItemId=@ItemId AND RawCode=@code
       AND IsActive=1 AND (SupplierId IS NULL OR SupplierId=@supplier))
     THROW 51306,'Primero registrar el codigo original para esta variante.',1;
   UPDATE receiving.ScanEvents SET ItemId=@ItemId,MatchStatus='matched',ResolutionReason=@Reason,
     ModifiedBy=@ReviewerId,ModifiedAt=SYSUTCDATETIME() WHERE Id=@ScanId;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [receiving].[usp_ApproveScanSession]
 @ScanSessionId uniqueidentifier,@ReviewerId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
   DECLARE @status varchar(16);
   SELECT @status=Status FROM receiving.ScanSessions WITH(UPDLOCK,HOLDLOCK) WHERE Id=@ScanSessionId;
   IF @status NOT IN ('counting','review') OR @status IS NULL
     THROW 51307,'La sesion no puede aprobarse.',1;
   IF NOT EXISTS(SELECT 1 FROM receiving.ScanEvents WHERE ScanSessionId=@ScanSessionId)
     THROW 51308,'Sesion sin lecturas.',1;
   IF EXISTS(SELECT 1 FROM receiving.ScanEvents WHERE ScanSessionId=@ScanSessionId AND MatchStatus<>'matched')
     THROW 51309,'Hay codigos pendientes, ambiguos o rechazados.',1;
   IF EXISTS(SELECT 1 FROM receiving.ScanEvents e JOIN catalog.Items i ON i.Id=e.ItemId
     WHERE e.ScanSessionId=@ScanSessionId AND i.Status NOT IN ('active','draft'))
     THROW 51310,'Variante no habilitada para ingreso.',1;
   UPDATE receiving.ScanSessions SET Status='approved',ReviewedBy=@ReviewerId,ReviewedAt=SYSUTCDATETIME(),
     ClosedAt=SYSUTCDATETIME(),ModifiedBy=@ReviewerId,ModifiedAt=SYSUTCDATETIME()
     WHERE Id=@ScanSessionId;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* ==============================================================
   ETIQUETAS: cola local, no imprime directamente desde SQL.
   El worker local maneja ZPL/TSPL/Windows spooler, reintentos y ACK.
   ============================================================= */
CREATE OR ALTER PROCEDURE [labels].[usp_QueueReceiptLabels]
 @ReceiptId uniqueidentifier,@ActorId uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @ownTran bit=0;
 IF @@TRANCOUNT=0 BEGIN SET @ownTran=1; BEGIN TRANSACTION; END;
 BEGIN TRY
  DECLARE @branch uniqueidentifier,@store nvarchar(150),@printer uniqueidentifier,@template uniqueidentifier;
  SELECT @branch=l.BranchId,@store=b.StoreDisplayName
   FROM purchasing.GoodsReceipts r JOIN core.Locations l ON l.Id=r.LocationId
   JOIN core.Branches b ON b.Id=l.BranchId WHERE r.Id=@ReceiptId;
  IF @branch IS NULL THROW 51401,'Recepcion no existe.',1;
  SELECT @printer=Id FROM labels.Printers WHERE BranchId=@branch AND IsDefault=1 AND IsActive=1;
  SELECT TOP(1) @template=Id FROM labels.Templates WHERE IsActive=1 ORDER BY Code;
  -- Se copian tantas etiquetas como prendas ingresadas, usando el codigo ORIGINAL.
  INSERT INTO labels.PrintJobs(Id,ReceiptLineId,ItemId,BranchId,PrinterId,TemplateId,
    StoreNameSnapshot,SkuSnapshot,BarcodeSnapshot,CopiesRequested,Status,CreatedBy)
  SELECT NEWID(),l.Id,l.ItemId,@branch,@printer,@template,@store,
      COALESCE(sup.RawCode,i.Sku),COALESCE(bar.RawCode,sup.RawCode,i.Sku),
      l.Quantity,CASE WHEN @printer IS NULL OR @template IS NULL THEN 'waiting_config' ELSE 'pending' END,@ActorId
  FROM purchasing.GoodsReceiptLines l
  JOIN catalog.Items i ON i.Id=l.ItemId
  OUTER APPLY (SELECT TOP(1) x.RawCode FROM catalog.ItemIdentifiers x
      WHERE x.ItemId=l.ItemId AND x.Kind='supplier_sku' AND x.IsActive=1
        AND (x.SupplierId=(SELECT c.SupplierId FROM purchasing.GoodsReceipts gr
          JOIN receiving.ImportContainers c ON c.Id=gr.ContainerId WHERE gr.Id=@ReceiptId))
      ORDER BY x.IsPrimary DESC,x.CreatedAt) sup
  OUTER APPLY (SELECT TOP(1) x.RawCode FROM catalog.ItemIdentifiers x
      WHERE x.ItemId=l.ItemId AND x.Kind='barcode' AND x.IsActive=1
      ORDER BY CASE WHEN x.SupplierId IS NULL THEN 0 ELSE 1 END,x.IsPrimary DESC) bar
  WHERE l.GoodsReceiptId=@ReceiptId
    AND NOT EXISTS(SELECT 1 FROM labels.PrintJobs q WITH(UPDLOCK,HOLDLOCK) WHERE q.ReceiptLineId=l.Id);
  IF @ownTran=1 COMMIT;
 END TRY
 BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [labels].[usp_AcknowledgePrint]
 @PrintJobId uniqueidentifier,@AttemptId uniqueidentifier,@AttemptNo int,
 @Successful bit,@PrinterResponse nvarchar(500)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
   DECLARE @status varchar(20),@copies int;
   SELECT @status=Status,@copies=CopiesRequested FROM labels.PrintJobs WITH(UPDLOCK,HOLDLOCK) WHERE Id=@PrintJobId;
   IF @status IS NULL THROW 51402,'Trabajo de impresion inexistente.',1;
   IF EXISTS(SELECT 1 FROM labels.PrintAttempts WHERE Id=@AttemptId)
   BEGIN COMMIT; RETURN; END;
   IF @status IN ('printed','cancelled') THROW 51403,'No se pueden registrar mas impresiones para este trabajo.',1;
   INSERT INTO labels.PrintAttempts(Id,PrintJobId,AttemptNo,PrinterResponse,Status,AcknowledgedAt)
     VALUES(@AttemptId,@PrintJobId,@AttemptNo,@PrinterResponse,
       CASE WHEN @Successful=1 THEN 'acknowledged' ELSE 'failed' END,
       CASE WHEN @Successful=1 THEN SYSUTCDATETIME() ELSE NULL END);
   UPDATE labels.PrintJobs SET
     CopiesAcknowledged=CASE WHEN @Successful=1 THEN @copies ELSE CopiesAcknowledged END,
     Status=CASE WHEN @Successful=1 THEN 'printed' ELSE 'failed' END,
     LastError=CASE WHEN @Successful=0 THEN @PrinterResponse ELSE NULL END,
     ModifiedAt=SYSUTCDATETIME()
     WHERE Id=@PrintJobId;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [receiving].[usp_PostScanSession]
 @ScanSessionId uniqueidentifier,@ActorId uniqueidentifier,@OriginNodeId uniqueidentifier,
 @ReceiptId uniqueidentifier OUTPUT,@CurrencyCode varchar(3)='NIO' 
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
  DECLARE @status varchar(16),@location uniqueidentifier,@container uniqueidentifier,@po uniqueidentifier;
  SELECT @status=s.Status,@location=c.LocationId,@container=c.Id,@po=c.PurchaseOrderId
    FROM receiving.ScanSessions s WITH(UPDLOCK,HOLDLOCK)
    JOIN receiving.ImportContainers c ON c.Id=s.ContainerId WHERE s.Id=@ScanSessionId;
  IF @status='posted'
  BEGIN
    SELECT @ReceiptId=Id FROM purchasing.GoodsReceipts WHERE ScanSessionId=@ScanSessionId;
    IF @ReceiptId IS NULL THROW 51311,'Sesion marcada posted sin comprobante.',1;
    COMMIT; RETURN;
  END;
  IF @status IS NULL OR @status<>'approved' THROW 51312,'Sesion requiere aprobacion previa.',1;
  IF NOT EXISTS(SELECT 1 FROM receiving.ScanEvents WHERE ScanSessionId=@ScanSessionId)
    THROW 51313,'No hay lecturas.',1;
  IF EXISTS(SELECT 1 FROM receiving.ScanEvents WHERE ScanSessionId=@ScanSessionId AND MatchStatus<>'matched')
    THROW 51314,'Hay codigos no resueltos.',1;
  IF EXISTS(SELECT 1 FROM receiving.ScanEvents e JOIN catalog.Items i ON i.Id=e.ItemId
    WHERE e.ScanSessionId=@ScanSessionId AND (i.Status NOT IN ('active','draft') OR i.CurrencyCode<>@CurrencyCode))
    THROW 51315,'Variante no activa o moneda distinta a la recepcion.',1;
  DECLARE @rows TABLE(RowNo int IDENTITY(1,1) PRIMARY KEY, ItemId uniqueidentifier,Qty int,Cost bigint NULL,Pool varchar(12));
  INSERT INTO @rows(ItemId,Qty,Cost,Pool)
   SELECT e.ItemId,SUM(e.Quantity),i.UnitCostMinor,
     CASE WHEN i.UnitCostMinor IS NULL OR i.Status<>'active' THEN 'quarantine' ELSE 'store' END
   FROM receiving.ScanEvents e JOIN catalog.Items i ON i.Id=e.ItemId
   WHERE e.ScanSessionId=@ScanSessionId GROUP BY e.ItemId,i.UnitCostMinor,i.Status;
  IF EXISTS(SELECT 1 FROM @rows WHERE Qty NOT BETWEEN 1 AND 1000000)
    THROW 51316,'Cantidad agrupada fuera de rango.',1;
  SET @ReceiptId=NEWID();
  INSERT INTO purchasing.GoodsReceipts(Id,ScanSessionId,PurchaseOrderId,ContainerId,LocationId,CurrencyCode,TotalCostMinor,CreatedBy)
     SELECT @ReceiptId,@ScanSessionId,@po,@container,@location,@CurrencyCode,
      CASE WHEN EXISTS(SELECT 1 FROM @rows WHERE Cost IS NULL) THEN NULL
      ELSE (SELECT SUM(CAST(Qty AS bigint)*Cost) FROM @rows) END,@ActorId;
  DECLARE @n int=1,@max int=(SELECT MAX(RowNo) FROM @rows),@item uniqueidentifier,
      @qty int,@cost bigint,@pool varchar(12),@line uniqueidentifier,@op uniqueidentifier,@movement uniqueidentifier;
  WHILE @n<=@max
  BEGIN
    SELECT @item=ItemId,@qty=Qty,@cost=Cost,@pool=Pool FROM @rows WHERE RowNo=@n;
    SET @line=NEWID(); SET @op=NEWID(); SET @movement=NULL;
    INSERT INTO purchasing.GoodsReceiptLines(Id,GoodsReceiptId,LineNumber,ItemId,Quantity,UnitCostMinor,Pool,CreatedBy)
      VALUES(@line,@ReceiptId,@n,@item,@qty,@cost,@pool,@ActorId);
    EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@location,@Pool=@pool,
      @Kind='receive',@OnHandDelta=@qty,@SourceType='goods_receipt_line',@SourceId=@line,
      @ActorId=@ActorId,@UnitCostMinor=@cost,@MovementId=@movement OUTPUT;
    SET @n+=1;
  END;
  UPDATE receiving.ScanSessions SET Status='posted',ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME()
    WHERE Id=@ScanSessionId;
  EXEC labels.usp_QueueReceiptLabels @ReceiptId,@ActorId;
  DECLARE @event uniqueidentifier=NEWID(),@payload nvarchar(max)=(
    SELECT @ReceiptId AS receiptId,@ScanSessionId AS scanSessionId,@container AS containerId,
       @location AS locationId,@OriginNodeId AS originNodeId,
       JSON_QUERY((SELECT ItemId,Quantity,Pool,UnitCostMinor FROM purchasing.GoodsReceiptLines
         WHERE GoodsReceiptId=@ReceiptId ORDER BY LineNumber FOR JSON PATH)) AS lines
       FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
  EXEC sync.usp_EnqueueEvent @event,@OriginNodeId,'goods_receipt',@ReceiptId,'inventory.receipt_posted',@payload;
  COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* ==============================================================
   POS: tipos TVP para venta y devolucion en una unica transaccion.
   ============================================================= */
CREATE TYPE [sales].[SaleLineRequest] AS TABLE (
  [LineNumber] int NOT NULL PRIMARY KEY,
  [ItemId] uniqueidentifier NOT NULL,
  [Quantity] int NOT NULL,
  [UnitPriceMinor] bigint NOT NULL,
  [DiscountMinor] bigint NOT NULL
);
GO
CREATE TYPE [sales].[SaleTenderRequest] AS TABLE (
  [TenderNumber] int NOT NULL PRIMARY KEY,
  [TenderKind] varchar(20) NOT NULL,
  [AmountMinor] bigint NOT NULL,
  [CreditId] uniqueidentifier NULL,
  [ReceivedMinor] bigint NULL,
  [ChangeMinor] bigint NULL,
  [Reference] nvarchar(120) NULL
);
GO
CREATE TYPE [sales].[ReturnLineRequest] AS TABLE (
  [SaleLineId] uniqueidentifier NOT NULL PRIMARY KEY,
  [Quantity] int NOT NULL,
  [RestockPool] varchar(12) NOT NULL
);
GO

CREATE OR ALTER PROCEDURE [sales].[usp_OpenTill]
 @TillId uniqueidentifier,@RegisterId uniqueidentifier,@CashierId uniqueidentifier,
 @CurrencyCode varchar(3),@OpeningMinor bigint,@OriginNodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @OpeningMinor<0 THROW 51501,'Fondo inicial invalido.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@TillId)
   BEGIN
     IF EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@TillId AND
        (RegisterId<>@RegisterId OR CashierId<>@CashierId OR CurrencyCode<>@CurrencyCode))
       THROW 51502,'TillId reutilizado incorrectamente.',1;
     COMMIT; RETURN;
   END;
   DECLARE @branch uniqueidentifier;
   SELECT @branch=BranchId FROM sales.CashRegisters WHERE Id=@RegisterId AND IsActive=1;
   IF @branch IS NULL THROW 51503,'Caja registradora inexistente o inactiva.',1;
   IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a JOIN security.Staff s ON s.Id=a.StaffId
      WHERE a.StaffId=@CashierId AND a.BranchId=@branch AND a.IsActive=1 AND s.IsEnabled=1)
      THROW 51504,'Cajero no autorizado en sucursal.',1;
   INSERT INTO sales.CashTills(Id,RegisterId,CashierId,CurrencyCode,CreatedBy)
     VALUES(@TillId,@RegisterId,@CashierId,@CurrencyCode,@CashierId);
   INSERT INTO sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,ActorId,CreatedBy)
     VALUES(NEWID(),@TillId,@CurrencyCode,'opening',@OpeningMinor,@CashierId,@CashierId);
   DECLARE @evt uniqueidentifier=NEWID(),@payload nvarchar(max)=(SELECT @TillId AS tillId,
      @RegisterId AS registerId,@OpeningMinor AS openingMinor,@CurrencyCode AS currency
      FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   EXEC sync.usp_EnqueueEvent @evt,@OriginNodeId,'cash_till',@TillId,'cash.till_opened',@payload;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [sales].[usp_RecordCashEntry]
 @EntryId uniqueidentifier,@TillId uniqueidentifier,@ActorId uniqueidentifier,
 @Kind varchar(16),@DeltaMinor bigint,@Reason nvarchar(400),@OriginNodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Kind NOT IN ('payout','deposit','adjustment') OR LEN(LTRIM(RTRIM(@Reason)))=0
   THROW 51505,'Solo operaciones manuales justificadas.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM sales.CashEntries WHERE Id=@EntryId)
   BEGIN COMMIT; RETURN; END;
   DECLARE @currency varchar(3),@status varchar(16);
   SELECT @currency=CurrencyCode,@status=Status FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TillId;
   IF @status IS NULL OR @status<>'open' THROW 51506,'Turno de caja cerrado.',1;
   INSERT INTO sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,ActorId,Reason,CreatedBy)
     VALUES(@EntryId,@TillId,@currency,@Kind,@DeltaMinor,@ActorId,@Reason,@ActorId);
   DECLARE @evt uniqueidentifier=NEWID(),@payload nvarchar(max)=(SELECT @EntryId AS cashEntryId,
      @TillId AS tillId,@Kind AS kind,@DeltaMinor AS amountMinor,@currency AS currency
      FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   EXEC sync.usp_EnqueueEvent @evt,@OriginNodeId,'cash_entry',@EntryId,'cash.manual_entry',@payload;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* La venta soporta pago mixto; el anticipo se canjea dentro de la MISMA TX.
   Tarjetas y transferencias deben estar autorizadas por el proveedor antes
   de invocar el SP; offline no significa pago electronico garantizado. */
CREATE OR ALTER PROCEDURE [sales].[usp_PostSale]
 @SaleId uniqueidentifier,@BranchId uniqueidentifier,@LocationId uniqueidentifier,
 @CashierId uniqueidentifier,@CurrencyCode varchar(3),@OriginNodeId uniqueidentifier,
 @Lines [sales].[SaleLineRequest] READONLY,
 @Tenders [sales].[SaleTenderRequest] READONLY,
 @CustomerId uniqueidentifier=NULL,@TillId uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF NOT EXISTS(SELECT 1 FROM @Lines) THROW 51507,'Venta sin articulos.',1;
 IF EXISTS(SELECT 1 FROM @Lines WHERE Quantity NOT BETWEEN 1 AND 1000000 OR
      UnitPriceMinor<0 OR DiscountMinor<0 OR
      CAST(UnitPriceMinor AS decimal(28,0))*Quantity<DiscountMinor)
   THROW 51508,'Linea de venta invalida.',1;
 IF EXISTS(SELECT 1 FROM @Tenders WHERE AmountMinor<=0 OR TenderKind NOT IN
   ('cash','card','transfer','credit','other') OR
   (TenderKind='credit' AND (CreditId IS NULL OR @CustomerId IS NULL)) OR
   (TenderKind<>'credit' AND CreditId IS NOT NULL) OR
   (TenderKind='cash' AND (ReceivedMinor IS NULL OR ChangeMinor IS NULL OR
      ReceivedMinor-ChangeMinor<>AmountMinor)) OR
   (TenderKind<>'cash' AND (ReceivedMinor IS NOT NULL OR ChangeMinor IS NOT NULL)) OR
   (TenderKind IN ('card','transfer') AND (Reference IS NULL OR LEN(LTRIM(RTRIM(Reference)))=0)))
   THROW 51509,'Formas de pago invalidas o sin autorizacion de referencia.',1;
 DECLARE @input nvarchar(max)=(SELECT @BranchId AS branchId,@LocationId AS locationId,
   @CashierId AS cashierId,@CurrencyCode AS currency,@CustomerId AS customerId,@TillId AS tillId,
   JSON_QUERY((SELECT * FROM @Lines ORDER BY LineNumber FOR JSON PATH)) AS lines,
   JSON_QUERY((SELECT * FROM @Tenders ORDER BY TenderNumber FOR JSON PATH)) AS tenders
   FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
 DECLARE @fingerprint varbinary(32)=HASHBYTES('SHA2_256',CONVERT(varbinary(max),@input));
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM sales.Sales WITH(UPDLOCK,HOLDLOCK) WHERE Id=@SaleId)
   BEGIN
     IF EXISTS(SELECT 1 FROM sales.Sales WHERE Id=@SaleId AND RequestHash<>@fingerprint)
       THROW 51510,'SaleId reutilizado con datos distintos.',1;
     COMMIT; RETURN;
   END;
   IF NOT EXISTS(SELECT 1 FROM core.Locations WHERE Id=@LocationId AND BranchId=@BranchId)
      THROW 51511,'Ubicacion no pertenece a sucursal.',1;
   IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a JOIN security.Staff s ON s.Id=a.StaffId
      WHERE a.StaffId=@CashierId AND a.BranchId=@BranchId AND a.IsActive=1 AND s.IsEnabled=1)
      THROW 51512,'Cajero sin acceso a sucursal.',1;
   IF EXISTS(SELECT 1 FROM @Lines l LEFT JOIN catalog.Items i ON i.Id=l.ItemId
       WHERE i.Id IS NULL OR i.Status<>'active' OR i.UnitCostMinor IS NULL OR i.CurrencyCode<>@CurrencyCode
        OR i.UnitPriceMinor<>l.UnitPriceMinor)
      THROW 51513,'Producto, moneda o precio desactualizado.',1;
   IF @TillId IS NULL THROW 51514,'Venta POS requiere turno de caja abierto, incluso con tarjeta.',1;
   BEGIN

     IF NOT EXISTS(SELECT 1 FROM sales.CashTills t JOIN sales.CashRegisters r ON r.Id=t.RegisterId
         WHERE t.Id=@TillId AND t.Status='open' AND t.CurrencyCode=@CurrencyCode
         AND r.BranchId=@BranchId AND r.LocationId=@LocationId AND t.CashierId=@CashierId)
        THROW 51515,'El turno de caja no coincide con la venta.',1;
   END;
   DECLARE @calc TABLE(LineNumber int PRIMARY KEY,ItemId uniqueidentifier,Quantity int,
      UnitPriceMinor bigint,DiscountMinor bigint,TaxMinor bigint,TotalMinor bigint);
   INSERT INTO @calc(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor,TaxMinor,TotalMinor)
   SELECT l.LineNumber,l.ItemId,l.Quantity,l.UnitPriceMinor,l.DiscountMinor,
      CAST(ROUND((CAST(l.UnitPriceMinor AS decimal(28,0))*l.Quantity-l.DiscountMinor)
          *i.TaxRateBps/10000.0,0) AS bigint),
      CAST(l.UnitPriceMinor AS bigint)*l.Quantity-l.DiscountMinor+
        CAST(ROUND((CAST(l.UnitPriceMinor AS decimal(28,0))*l.Quantity-l.DiscountMinor)
          *i.TaxRateBps/10000.0,0) AS bigint)
   FROM @Lines l JOIN catalog.Items i ON i.Id=l.ItemId;
   DECLARE @subtotal bigint=(SELECT SUM(CAST(UnitPriceMinor AS bigint)*Quantity) FROM @calc),
     @discount bigint=(SELECT SUM(DiscountMinor) FROM @calc),
     @tax bigint=(SELECT SUM(TaxMinor) FROM @calc),
     @total bigint=(SELECT SUM(TotalMinor) FROM @calc);
   IF @total IS NULL OR @total<0 OR @total>9000000000000
      THROW 51516,'Total de venta invalido.',1;
   IF (SELECT COALESCE(SUM(AmountMinor),0) FROM @Tenders)<>@total
      THROW 51517,'Pagos no coinciden con total.',1;
   INSERT INTO sales.Sales(Id,BranchId,LocationId,CustomerId,CashierId,TillId,CurrencyCode,
     SubtotalMinor,DiscountMinor,TaxMinor,TotalMinor,Channel,OriginNodeId,RequestHash,CreatedBy)
     VALUES(@SaleId,@BranchId,@LocationId,@CustomerId,@CashierId,@TillId,@CurrencyCode,
     @subtotal,@discount,@tax,@total,'pos',@OriginNodeId,@fingerprint,@CashierId);
   INSERT INTO sales.SaleLines(SaleId,LineNumber,ItemId,SkuSnapshot,NameSnapshot,
     Quantity,UnitPriceMinor,CostUnitSnapshotMinor,COGSMinor,DiscountMinor,TaxMinor,TotalMinor,CreatedBy)
   SELECT @SaleId,c.LineNumber,c.ItemId,i.Sku,i.VariantName,c.Quantity,c.UnitPriceMinor,
     i.UnitCostMinor,i.UnitCostMinor*CONVERT(bigint,c.Quantity),
     c.DiscountMinor,c.TaxMinor,c.TotalMinor,@CashierId
   FROM @calc c JOIN catalog.Items i ON i.Id=c.ItemId;
   DECLARE @item uniqueidentifier,@qty int,@op uniqueidentifier,@mv uniqueidentifier,@negQty int;
   DECLARE lineCursor CURSOR LOCAL FAST_FORWARD FOR SELECT ItemId,Quantity FROM @calc ORDER BY LineNumber;
   OPEN lineCursor; FETCH NEXT FROM lineCursor INTO @item,@qty;
   WHILE @@FETCH_STATUS=0
   BEGIN
     SET @op=NEWID(); SET @mv=NULL; SET @negQty=-@qty;
     EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@LocationId,
       @Pool='store',@Kind='sale',@OnHandDelta=@negQty,
       @SourceType='sale',@SourceId=@SaleId,@ActorId=@CashierId,@MovementId=@mv OUTPUT;
     FETCH NEXT FROM lineCursor INTO @item,@qty;
   END;
   CLOSE lineCursor; DEALLOCATE lineCursor;
   DECLARE @tno int,@tkind varchar(20),@amt bigint,@credit uniqueidentifier,
      @received bigint,@change bigint,@ref nvarchar(120),@tenderId uniqueidentifier,@redeemId uniqueidentifier;
   DECLARE tenderCursor CURSOR LOCAL FAST_FORWARD FOR
      SELECT TenderNumber,TenderKind,AmountMinor,CreditId,ReceivedMinor,ChangeMinor,Reference
      FROM @Tenders ORDER BY TenderNumber;
   OPEN tenderCursor; FETCH NEXT FROM tenderCursor INTO @tno,@tkind,@amt,@credit,@received,@change,@ref;
   WHILE @@FETCH_STATUS=0
   BEGIN
     SET @tenderId=NEWID();
     INSERT INTO sales.SaleTenders(Id,SaleId,TenderKind,CurrencyCode,AmountMinor,Reference,
       CreditId,ReceivedMinor,ChangeMinor,CreatedBy)
       VALUES(@tenderId,@SaleId,@tkind,@CurrencyCode,@amt,@ref,@credit,@received,@change,@CashierId);
     IF @tkind='cash'
       INSERT INTO sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,SaleTenderId,ActorId,CreatedBy)
         VALUES(NEWID(),@TillId,@CurrencyCode,'sale',@amt,@tenderId,@CashierId,@CashierId);
     IF @tkind='credit'
     BEGIN
       SET @redeemId=NEWID();
       EXEC credits.usp_RedeemCredit @RedemptionId=@redeemId,@CreditId=@credit,@BranchId=@BranchId,
          @SaleId=@SaleId,@AmountMinor=@amt,@ActorId=@CashierId;
     END;
     FETCH NEXT FROM tenderCursor INTO @tno,@tkind,@amt,@credit,@received,@change,@ref;
   END;
   CLOSE tenderCursor; DEALLOCATE tenderCursor;
   DECLARE @event uniqueidentifier=NEWID(),@payload nvarchar(max)=(
     SELECT @SaleId AS saleId,@BranchId AS branchId,@LocationId AS locationId,
        @CurrencyCode AS currency,@total AS totalMinor,@OriginNodeId AS originNodeId,
        JSON_QUERY((SELECT sl.ItemId,sl.Quantity,sl.UnitPriceMinor,sl.TaxMinor,sl.TotalMinor
          FROM sales.SaleLines sl WHERE sl.SaleId=@SaleId FOR JSON PATH)) AS lines,
        JSON_QUERY((SELECT st.TenderKind,st.AmountMinor,st.CreditId
          FROM sales.SaleTenders st WHERE st.SaleId=@SaleId FOR JSON PATH)) AS tenders
       FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   EXEC sync.usp_EnqueueEvent @event,@OriginNodeId,'sale',@SaleId,'sales.sale_posted',@payload;
   COMMIT;
 END TRY
 BEGIN CATCH
   IF CURSOR_STATUS('local','lineCursor')>=0 BEGIN CLOSE lineCursor; DEALLOCATE lineCursor; END;
   IF CURSOR_STATUS('local','tenderCursor')>=0 BEGIN CLOSE tenderCursor; DEALLOCATE tenderCursor; END;
   IF @@TRANCOUNT>0 ROLLBACK;
   THROW;
 END CATCH;
END;
GO

/* Cierre: el arqueo cuenta billetes y monedas; esperado desde movimientos.
   La salida contable no es una segunda factura fiscal de las ventas. */
CREATE OR ALTER PROCEDURE [sales].[usp_SubmitCashCount]
 @CashCountId uniqueidentifier,@ActorId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
  DECLARE @till uniqueidentifier,@status varchar(16);
  SELECT @till=TillId,@status=Status FROM sales.CashCounts WITH(UPDLOCK,HOLDLOCK) WHERE Id=@CashCountId;
  IF @status IS NULL OR @status<>'draft' THROW 51518,'Arqueo no editable.',1;
  IF NOT EXISTS(SELECT 1 FROM sales.CashCountLines WHERE CashCountId=@CashCountId)
     THROW 51519,'El arqueo debe incluir denominaciones.',1;
  IF NOT EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@till AND Status='open')
     THROW 51520,'Turno cerrado.',1;
  UPDATE sales.CashCounts SET Status='submitted',SubmittedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId,
    ModifiedAt=SYSUTCDATETIME() WHERE Id=@CashCountId;
  COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [sales].[usp_CloseTill]
 @ClosureId uniqueidentifier,@TillId uniqueidentifier,@CashCountId uniqueidentifier,
 @ActorId uniqueidentifier,@OriginNodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM sales.CashClosures WHERE TillId=@TillId)
   BEGIN
     IF NOT EXISTS(SELECT 1 FROM sales.CashClosures WHERE Id=@ClosureId AND TillId=@TillId AND CashCountId=@CashCountId)
       THROW 51521,'Turno ya cerrado con otro comprobante.',1;
     COMMIT; RETURN;
   END;
   DECLARE @status varchar(16),@currency varchar(3),@opened datetime2(3);
   SELECT @status=Status,@currency=CurrencyCode,@opened=OpenedAt FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TillId;
   IF @status IS NULL OR @status<>'open' THROW 51522,'Turno no abierto.',1;
   IF NOT EXISTS(SELECT 1 FROM sales.CashCounts WITH(UPDLOCK,HOLDLOCK)
       WHERE Id=@CashCountId AND TillId=@TillId AND Status='submitted')
       THROW 51523,'Arqueo no presentado o no corresponde al turno.',1;
   DECLARE @expected bigint=(SELECT COALESCE(SUM(DeltaMinor),0) FROM sales.CashEntries WHERE TillId=@TillId);
   DECLARE @counted bigint=(SELECT COALESCE(SUM(CONVERT(bigint,DenominationMinor)*Quantity),0)
      FROM sales.CashCountLines WHERE CashCountId=@CashCountId);
   IF @expected<0 OR @counted<0 THROW 51524,'Arqueo negativo o caja sin fondos.',1;
   INSERT INTO sales.CashClosures(Id,TillId,CashCountId,ExpectedMinor,CountedMinor,
     DifferenceMinor,ClosedBy,CreatedBy)
      VALUES(@ClosureId,@TillId,@CashCountId,@expected,@counted,@counted-@expected,@ActorId,@ActorId);
   UPDATE sales.CashTills SET Status='closed',ClosedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId,
     ModifiedAt=SYSUTCDATETIME() WHERE Id=@TillId;
   DECLARE @doc uniqueidentifier=NEWID(),@gross bigint=0,@tax bigint=0,@discount bigint=0,
      @sales int=0,@returns bigint=0,@card bigint=0,@credit bigint=0,
      @saleCOGS bigint=0,@returnCOGS bigint=0;
   SELECT @gross=COALESCE(SUM(s.TotalMinor),0),@tax=COALESCE(SUM(s.TaxMinor),0),
        @discount=COALESCE(SUM(s.DiscountMinor),0),@sales=COUNT(*)
      FROM sales.Sales s WHERE s.TillId=@TillId;
   SELECT @returns=COALESCE(SUM(CreditMinor),0) FROM sales.SaleReversals
      WHERE TillId=@TillId AND Status='approved';
   SELECT @saleCOGS=COALESCE(SUM(l.COGSMinor),0) FROM sales.SaleLines l
     JOIN sales.Sales s ON s.Id=l.SaleId WHERE s.TillId=@TillId;
   SELECT @returnCOGS=COALESCE(SUM(l.COGSReversedMinor),0) FROM sales.SaleReversalLines l
     JOIN sales.SaleReversals r ON r.Id=l.ReversalId
     WHERE r.TillId=@TillId AND r.Status='approved';
   SELECT @card=COALESCE(SUM(st.AmountMinor),0) FROM sales.SaleTenders st
     JOIN sales.Sales s ON s.Id=st.SaleId
     WHERE s.TillId=@TillId AND st.TenderKind='card' AND st.Status='captured';
   SELECT @credit=COALESCE(SUM(st.AmountMinor),0) FROM sales.SaleTenders st
     JOIN sales.Sales s ON s.Id=st.SaleId
     WHERE s.TillId=@TillId AND st.TenderKind='credit' AND st.Status='captured';
   INSERT INTO accounting.CloseDocuments(Id,ClosureId,DocumentNumber,DocumentKind,Status,
      CurrencyCode,CashExpectedMinor,CashCountedMinor,CashDifferenceMinor,SaleGrossMinor,
      SaleTaxMinor,SaleDiscountMinor,SaleCount,ReturnGrossMinor,NetSalesMinor,
      SaleCOGSMinor,ReturnedCOGSMinor,NetCOGSMinor,CardCapturedMinor,CreditRedeemedMinor,
      PeriodStartAt,PeriodEndAt,CreatedBy)
     VALUES(@doc,@ClosureId,CONCAT(N'CIERRE-',CONVERT(nvarchar(36),@ClosureId)),
       'accounting_summary','prepared',@currency,@expected,@counted,@counted-@expected,
       @gross,@tax,@discount,@sales,@returns,@gross-@returns,
       @saleCOGS,@returnCOGS,@saleCOGS-@returnCOGS,@card,@credit,
       @opened,SYSUTCDATETIME(),@ActorId);
   INSERT INTO accounting.CloseDocumentLines(CloseDocumentId,[LineNo],ConceptCode,ConceptName,AmountMinor)
      VALUES(@doc,1,'EXPECTED_CASH',N'Efectivo esperado',@expected),
            (@doc,2,'COUNTED_CASH',N'Efectivo contado',@counted),
            (@doc,3,'CASH_DIFFERENCE',N'Diferencia de caja',@counted-@expected),
            (@doc,4,'SALE_GROSS',N'Ventas del turno (todos los medios)',@gross),
            (@doc,5,'RETURN_GROSS',N'Devoluciones del turno',-@returns),
            (@doc,6,'NET_SALES',N'Venta neta del turno',@gross-@returns),
            (@doc,7,'CARD_TENDERS',N'Pagos con tarjeta registrados',@card),
            (@doc,8,'CREDIT_REDEMPTIONS',N'Anticipos canjeados',@credit),
            (@doc,9,'COGS_GROSS',N'Costo de venta del turno (costo snapshot)',@saleCOGS),
            (@doc,10,'COGS_RETURNED',N'Costo revertido por devoluciones',-@returnCOGS),
            (@doc,11,'COGS_NET',N'Costo de venta neto',@saleCOGS-@returnCOGS);
   -- Se crea salida contable automatica; no se inventa una factura fiscal.
   INSERT INTO accounting.ExportJobs(Id,CloseDocumentId,RecipientCode,Format,Status,CreatedBy)
     VALUES(NEWID(),@doc,N'ACCOUNTANT','PDF','pending',@ActorId);
   DECLARE @evt uniqueidentifier=NEWID(),@payload nvarchar(max)=(
     SELECT @ClosureId AS closureId,@TillId AS tillId,@CashCountId AS cashCountId,
        @doc AS accountingDocumentId,@expected AS expectedMinor,@counted AS countedMinor,
        @currency AS currency FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   EXEC sync.usp_EnqueueEvent @evt,@OriginNodeId,'cash_closure',@ClosureId,'cash.till_closed',@payload;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* ==============================================================
   ANTICIPOS: saldos exclusivos por sucursal.
   No hay "ultimo cambio gana". Una transferencia A->B exige
   lock en A, ACK de Azure y recepcion de derecho de gasto en B.
   ============================================================= */
CREATE OR ALTER PROCEDURE [credits].[usp_IssueFromReturn]
 @CreditId uniqueidentifier,@ReversalId uniqueidentifier,@ActorId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @ownTran bit=0;
 IF @@TRANCOUNT=0 BEGIN SET @ownTran=1; BEGIN TRANSACTION; END;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM credits.Credits WHERE SourceReversalId=@ReversalId)
   BEGIN
     IF NOT EXISTS(SELECT 1 FROM credits.Credits WHERE Id=@CreditId AND SourceReversalId=@ReversalId)
       THROW 51601,'Devolucion ya genero otro anticipo.',1;
     IF @ownTran=1 COMMIT; RETURN;
   END;
   DECLARE @customer uniqueidentifier,@branch uniqueidentifier,@currency varchar(3),
       @amount bigint,@settlement varchar(16),@status varchar(20);
   SELECT @customer=s.CustomerId,@branch=r.BranchId,@currency=r.CurrencyCode,
     @amount=r.CreditMinor,@settlement=r.SettlementKind,@status=r.Status
   FROM sales.SaleReversals r WITH(UPDLOCK,HOLDLOCK)
   JOIN sales.Sales s ON s.Id=r.SaleId WHERE r.Id=@ReversalId;
   IF @status IS NULL OR @status<>'approved' OR @settlement<>'credit' OR
     @customer IS NULL OR @amount<=0 THROW 51602,'Devolucion no elegible para anticipo.',1;
   IF (SELECT COALESCE(SUM(CreditMinor),0) FROM sales.SaleReversalLines WHERE ReversalId=@ReversalId)<>@amount
     THROW 51603,'Credito distinto al valor aprobado de las lineas devueltas.',1;
   INSERT INTO credits.Credits(Id,CustomerId,SourceReversalId,IssuingBranchId,CurrencyCode,
     OriginalMinor,CreatedBy) VALUES(@CreditId,@customer,@ReversalId,@branch,@currency,@amount,@ActorId);
   INSERT INTO credits.CreditAllocations(CreditId,BranchId,AvailableMinor,HeldMinor,CreatedBy)
     VALUES(@CreditId,@branch,@amount,0,@ActorId);
   INSERT INTO credits.CreditMovements(Id,CreditId,BranchId,Kind,AvailableDeltaMinor,
     SourceType,SourceId,ActorId,CreatedBy)
     VALUES(NEWID(),@CreditId,@branch,'issue',@amount,'sale_reversal',@ReversalId,@ActorId,@ActorId);
   IF @ownTran=1 COMMIT;
 END TRY
 BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [credits].[usp_RedeemCredit]
 @RedemptionId uniqueidentifier,@CreditId uniqueidentifier,@BranchId uniqueidentifier,
 @SaleId uniqueidentifier,@AmountMinor bigint,@ActorId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @AmountMinor<=0 THROW 51604,'Importe de canje invalido.',1;
 DECLARE @ownTran bit=0;
 IF @@TRANCOUNT=0 BEGIN SET @ownTran=1; BEGIN TRANSACTION; END;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM credits.CreditRedemptions WHERE Id=@RedemptionId)
   BEGIN
     IF EXISTS(SELECT 1 FROM credits.CreditRedemptions WHERE Id=@RedemptionId AND
       (CreditId<>@CreditId OR SaleId<>@SaleId OR AmountMinor<>@AmountMinor))
       THROW 51605,'Canje duplicado con otro contenido.',1;
     IF @ownTran=1 COMMIT; RETURN;
   END;
   IF NOT EXISTS(SELECT 1 FROM sales.Sales s JOIN credits.Credits c ON c.Id=@CreditId
       WHERE s.Id=@SaleId AND s.BranchId=@BranchId AND s.CustomerId=c.CustomerId
         AND s.CurrencyCode=c.CurrencyCode AND c.Status='active')
     THROW 51606,'La venta no pertenece al cliente/moneda del anticipo.',1;
   UPDATE credits.CreditAllocations WITH(UPDLOCK,SERIALIZABLE)
      SET AvailableMinor=AvailableMinor-@AmountMinor,ModifiedBy=@ActorId,
          ModifiedAt=SYSUTCDATETIME()
      WHERE CreditId=@CreditId AND BranchId=@BranchId AND Status='active'
        AND AvailableMinor>=@AmountMinor;
   IF @@ROWCOUNT<>1 THROW 51607,'Saldo de anticipo insuficiente en esta sucursal.',1;
   INSERT INTO credits.CreditRedemptions(Id,CreditId,BranchId,SaleId,AmountMinor,ActorId,CreatedBy)
      VALUES(@RedemptionId,@CreditId,@BranchId,@SaleId,@AmountMinor,@ActorId,@ActorId);
   INSERT INTO credits.CreditMovements(Id,CreditId,BranchId,Kind,AvailableDeltaMinor,
     SourceType,SourceId,ActorId,CreatedBy)
      VALUES(NEWID(),@CreditId,@BranchId,'redeem',-@AmountMinor,'sale',@SaleId,@ActorId,@ActorId);
   IF NOT EXISTS(SELECT 1 FROM credits.CreditAllocations WHERE CreditId=@CreditId AND
       (AvailableMinor<>0 OR HeldMinor<>0))
      UPDATE credits.Credits SET Status='exhausted',ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId
       WHERE Id=@CreditId;
   IF @ownTran=1 COMMIT;
 END TRY
 BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [credits].[usp_RequestTransfer]
 @TransferId uniqueidentifier,@CreditId uniqueidentifier,@FromBranchId uniqueidentifier,
 @ToBranchId uniqueidentifier,@AmountMinor bigint,@RequestedBy uniqueidentifier,
 @Reason nvarchar(400),@OriginNodeId uniqueidentifier,@EventId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @FromBranchId=@ToBranchId OR @AmountMinor<=0 OR LEN(LTRIM(RTRIM(@Reason)))=0
   THROW 51608,'Solicitud de transferencia invalida.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
  IF EXISTS(SELECT 1 FROM credits.CreditTransfers WHERE Id=@TransferId)
  BEGIN
    IF EXISTS(SELECT 1 FROM credits.CreditTransfers WHERE Id=@TransferId AND
      (CreditId<>@CreditId OR FromBranchId<>@FromBranchId OR ToBranchId<>@ToBranchId OR AmountMinor<>@AmountMinor))
      THROW 51609,'TransferId repetido con distinto contenido.',1;
    COMMIT; RETURN;
  END;
  IF NOT EXISTS(SELECT 1 FROM credits.Credits WHERE Id=@CreditId AND Status='active')
     THROW 51610,'Anticipo no activo.',1;
  IF NOT EXISTS(SELECT 1 FROM credits.CreditAllocations WHERE CreditId=@CreditId AND BranchId=@FromBranchId)
     THROW 51611,'Saldo no pertenece a la sucursal origen.',1;
  INSERT INTO credits.CreditTransfers(Id,CreditId,FromBranchId,ToBranchId,AmountMinor,
    RequestedBy,Reason,CreatedBy)
    VALUES(@TransferId,@CreditId,@FromBranchId,@ToBranchId,@AmountMinor,@RequestedBy,@Reason,@RequestedBy);
  DECLARE @payload nvarchar(max)=(SELECT @TransferId AS transferId,@CreditId AS creditId,
     @FromBranchId AS fromBranchId,@ToBranchId AS toBranchId,@AmountMinor AS amountMinor,
     @RequestedBy AS requesterId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
  EXEC sync.usp_EnqueueEvent @EventId,@OriginNodeId,'credit_transfer',@TransferId,
     'credits.transfer_requested',@payload;
  COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [credits].[usp_ApproveTransfer]
 @TransferId uniqueidentifier,@ApproverId uniqueidentifier,
 @OriginNodeId uniqueidentifier,@EventId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
  DECLARE @from uniqueidentifier,@requester uniqueidentifier,@state varchar(20);
  SELECT @from=FromBranchId,@requester=RequestedBy,@state=Status
    FROM credits.CreditTransfers WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TransferId;
  IF @state IS NULL OR @state<>'requested' OR @requester=@ApproverId
    THROW 51612,'Solicitud inexistente o aprobacion incompatible.',1;
  IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a JOIN security.Staff s ON s.Id=a.StaffId
     WHERE a.StaffId=@ApproverId AND a.BranchId=@from AND a.CanApproveTransfers=1
         AND a.IsActive=1 AND s.IsEnabled=1)
     THROW 51613,'Supervisor sin permisos.',1;
  UPDATE credits.CreditTransfers SET Status='approved',ApprovedBy=@ApproverId,
    ApprovedAt=SYSUTCDATETIME(),ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ApproverId
    WHERE Id=@TransferId;
  DECLARE @payload nvarchar(max)=(SELECT @TransferId AS transferId,@from AS originBranchId,
     @ApproverId AS approverId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
  DECLARE @kind varchar(16)=(SELECT Kind FROM sync.Nodes WHERE Id=@OriginNodeId);
  IF @kind IS NULL THROW 51624,'Nodo que aprueba no configurado.',1;
  EXEC sync.usp_EnqueueEvent @EventId,@OriginNodeId,'credit_transfer',@TransferId,
    'credits.transfer_approved',@payload;
  IF @kind='azure'
  BEGIN
    DECLARE @dest uniqueidentifier=(SELECT Id FROM sync.Nodes WHERE Kind='branch' AND BranchId=@from);
    IF @dest IS NULL THROW 51625,'Sucursal origen no tiene nodo sync.',1;
    EXEC sync.usp_RouteEvent @EventId,@dest;
  END;
  COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* Se ejecuta en el ORIGEN. El evento debe llegar y aplicarse en Azure.
   Para reproducir el evento en la proyeccion de Azure, EmitEvent=0. */
CREATE OR ALTER PROCEDURE [credits].[usp_LockTransferAtOrigin]
 @TransferId uniqueidentifier,@OriginLockEventId uniqueidentifier,
 @OriginNodeId uniqueidentifier,@ActorId uniqueidentifier,@EmitEvent bit=1
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
  DECLARE @credit uniqueidentifier,@from uniqueidentifier,@to uniqueidentifier,@amt bigint,@status varchar(20);
  SELECT @credit=CreditId,@from=FromBranchId,@to=ToBranchId,@amt=AmountMinor,@status=Status
    FROM credits.CreditTransfers WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TransferId;
  IF @status='origin_locked'
  BEGIN
    IF NOT EXISTS(SELECT 1 FROM credits.CreditTransfers WHERE Id=@TransferId AND OriginLockEventId=@OriginLockEventId)
       THROW 51614,'Transferencia ya bloqueada con otro evento.',1;
    COMMIT; RETURN;
  END;
  IF @status IS NULL OR @status<>'approved' THROW 51615,'Transferencia no aprobada.',1;
  IF @EmitEvent=1 AND NOT EXISTS(SELECT 1 FROM sync.Nodes WHERE Id=@OriginNodeId AND BranchId=@from AND Kind='branch')
    THROW 51616,'El origen del bloqueo no coincide con la sucursal.',1;
  UPDATE credits.CreditAllocations WITH(UPDLOCK,SERIALIZABLE)
    SET AvailableMinor=AvailableMinor-@amt,HeldMinor=HeldMinor+@amt,
      ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId
    WHERE CreditId=@credit AND BranchId=@from AND AvailableMinor>=@amt AND Status='active';
  IF @@ROWCOUNT<>1 THROW 51617,'Saldo disponible insuficiente; sin bloqueo.',1;
  UPDATE credits.CreditTransfers SET Status='origin_locked',OriginLockEventId=@OriginLockEventId,
    OriginLockedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME()
    WHERE Id=@TransferId;
  INSERT INTO credits.CreditMovements(Id,CreditId,BranchId,Kind,AvailableDeltaMinor,
     HeldDeltaMinor,SourceType,SourceId,ActorId,CreatedBy)
    VALUES(NEWID(),@credit,@from,'hold',-@amt,@amt,'credit_transfer',@TransferId,@ActorId,@ActorId);
  IF @EmitEvent=1
  BEGIN
    DECLARE @payload nvarchar(max)=(SELECT @TransferId AS transferId,@credit AS creditId,
      @from AS fromBranchId,@to AS toBranchId,@amt AS amountMinor,
      @OriginLockEventId AS originLockEventId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
    EXEC sync.usp_EnqueueEvent @OriginLockEventId,@OriginNodeId,
       'credit_transfer',@TransferId,'credits.origin_locked',@payload;
  END;
  COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* Transferencia central/replicada: solo tras prueba del bloqueo.
   Azure exige inbox.applied; en A exige outbox.acked.
   El saldo permanece HELD en B hasta su recepcion local. */
CREATE OR ALTER PROCEDURE [credits].[usp_CommitTransfer]
 @TransferId uniqueidentifier,@ActorId uniqueidentifier=NULL,
 @OriginNodeId uniqueidentifier=NULL,@EventId uniqueidentifier=NULL,@EmitEvent bit=1
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
  DECLARE @credit uniqueidentifier,@from uniqueidentifier,@to uniqueidentifier,@amt bigint,
     @lockEvent uniqueidentifier,@status varchar(20);
  SELECT @credit=CreditId,@from=FromBranchId,@to=ToBranchId,@amt=AmountMinor,
    @lockEvent=OriginLockEventId,@status=Status
    FROM credits.CreditTransfers WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TransferId;
  IF @status='in_transit' OR @status='accepted' BEGIN COMMIT; RETURN; END;
  IF @status IS NULL OR @status<>'origin_locked' OR @lockEvent IS NULL
      THROW 51618,'Transferencia sin bloqueo de origen.',1;
  IF NOT EXISTS(SELECT 1 FROM sync.Inbox i JOIN sync.Nodes n ON n.Id=i.OriginNodeId
        WHERE i.EventId=@lockEvent AND i.Status='applied' AND n.BranchId=@from)
     AND NOT EXISTS(SELECT 1 FROM sync.Outbox WHERE EventId=@lockEvent AND Status='acked')
     THROW 51619,'No existe constancia de que Azure acepto el bloqueo.',1;
  UPDATE credits.CreditAllocations WITH(UPDLOCK,SERIALIZABLE) SET HeldMinor=HeldMinor-@amt,
     ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId
     WHERE CreditId=@credit AND BranchId=@from AND HeldMinor>=@amt;
  IF @@ROWCOUNT<>1 THROW 51620,'Bloqueo no disponible.',1;
  IF EXISTS(SELECT 1 FROM credits.CreditAllocations WITH(UPDLOCK,HOLDLOCK)
      WHERE CreditId=@credit AND BranchId=@to)
    UPDATE credits.CreditAllocations SET HeldMinor=HeldMinor+@amt,
      ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId WHERE CreditId=@credit AND BranchId=@to;
  ELSE
    INSERT INTO credits.CreditAllocations(CreditId,BranchId,AvailableMinor,HeldMinor,CreatedBy)
      VALUES(@credit,@to,0,@amt,@ActorId);
  UPDATE credits.CreditTransfers SET Status='in_transit',CommittedAt=SYSUTCDATETIME(),
     ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME() WHERE Id=@TransferId;
  INSERT INTO credits.CreditMovements(Id,CreditId,BranchId,Kind,AvailableDeltaMinor,HeldDeltaMinor,
    SourceType,SourceId,ActorId,CreatedBy)
    VALUES(NEWID(),@credit,@from,'transfer_out',0,-@amt,'credit_transfer',@TransferId,@ActorId,@ActorId),
          (NEWID(),@credit,@to,'transfer_in',0,@amt,'credit_transfer',@TransferId,@ActorId,@ActorId);
  IF @EmitEvent=1
  BEGIN
    IF NOT EXISTS(SELECT 1 FROM sync.Nodes WHERE Id=@OriginNodeId AND Kind='azure')
       THROW 51626,'El commit de transferencia debe originarse en Azure.',1;
    IF @EventId IS NULL THROW 51627,'EventId obligatorio.',1;
    DECLARE @payload nvarchar(max)=(SELECT @TransferId AS transferId,@credit AS creditId,
       @from AS fromBranchId,@to AS toBranchId,@amt AS amountMinor,
       @lockEvent AS originLockEventId FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
    EXEC sync.usp_EnqueueEvent @EventId,@OriginNodeId,'credit_transfer',@TransferId,
      'credits.transfer_committed',@payload;
    DECLARE @destA uniqueidentifier=(SELECT Id FROM sync.Nodes WHERE Kind='branch' AND BranchId=@from),
            @destB uniqueidentifier=(SELECT Id FROM sync.Nodes WHERE Kind='branch' AND BranchId=@to);
    IF @destA IS NULL OR @destB IS NULL THROW 51628,'Ambas sucursales deben tener nodo configurado.',1;
    EXEC sync.usp_RouteEvent @EventId,@destA;
    EXEC sync.usp_RouteEvent @EventId,@destB;
  END;
  COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* En B se confirma el derecho de gasto. Requiere haber instalado
   una proyeccion in_transit firmada por Azure en la BD local. */
CREATE OR ALTER PROCEDURE [credits].[usp_AcceptTransfer]
 @TransferId uniqueidentifier,@ActorId uniqueidentifier,
 @OriginNodeId uniqueidentifier=NULL,@EventId uniqueidentifier=NULL,@EmitEvent bit=1
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
  DECLARE @credit uniqueidentifier,@to uniqueidentifier,@amt bigint,@status varchar(20);
  SELECT @credit=CreditId,@to=ToBranchId,@amt=AmountMinor,@status=Status
      FROM credits.CreditTransfers WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TransferId;
  IF @status='accepted' BEGIN COMMIT; RETURN; END;
  IF @status IS NULL OR @status<>'in_transit' THROW 51621,'Saldo no transferido oficialmente.',1;
  UPDATE credits.CreditAllocations WITH(UPDLOCK,SERIALIZABLE)
     SET HeldMinor=HeldMinor-@amt,AvailableMinor=AvailableMinor+@amt,
      ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId
     WHERE CreditId=@credit AND BranchId=@to AND HeldMinor>=@amt AND Status='active';
  IF @@ROWCOUNT<>1 THROW 51622,'Derecho de gasto no instalado en destino.',1;
  UPDATE credits.CreditTransfers SET Status='accepted',AcceptedAt=SYSUTCDATETIME(),
       ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME() WHERE Id=@TransferId;
  INSERT INTO credits.CreditMovements(Id,CreditId,BranchId,Kind,AvailableDeltaMinor,HeldDeltaMinor,
       SourceType,SourceId,ActorId,CreatedBy)
       VALUES(NEWID(),@credit,@to,'accept',@amt,-@amt,'credit_transfer',@TransferId,@ActorId,@ActorId);
  IF @EmitEvent=1
  BEGIN
    IF NOT EXISTS(SELECT 1 FROM sync.Nodes WHERE Id=@OriginNodeId AND Kind='branch' AND BranchId=@to)
      THROW 51629,'La aceptacion debe registrarse desde la sucursal destino.',1;
    IF @EventId IS NULL THROW 51630,'EventId obligatorio.',1;
    DECLARE @payload nvarchar(max)=(SELECT @TransferId AS transferId,@credit AS creditId,
       @to AS destinationBranchId,@amt AS amountMinor FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
    EXEC sync.usp_EnqueueEvent @EventId,@OriginNodeId,'credit_transfer',@TransferId,
        'credits.transfer_accepted',@payload;
  END;
  COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [credits].[usp_CancelUnblockedTransfer]
 @TransferId uniqueidentifier,@ActorId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
  UPDATE credits.CreditTransfers WITH(UPDLOCK) SET Status='cancelled',ModifiedAt=SYSUTCDATETIME(),
    ModifiedBy=@ActorId WHERE Id=@TransferId AND Status IN ('requested','approved');
  IF @@ROWCOUNT<>1 THROW 51623,'Transferencia bloqueada: requiere protocolo de liberacion central.',1;
  COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* ==============================================================
   DEVOLUCIONES CON ANTICIPO. El flujo cash/mixed requiere otros
   procedimientos autorizados y validacion fiscal; no se simula aqui.
   ============================================================= */
CREATE OR ALTER PROCEDURE [sales].[usp_PostCreditReturn]
 @ReversalId uniqueidentifier,@CreditId uniqueidentifier,@SaleId uniqueidentifier,
 @BranchId uniqueidentifier,@ReturnLocationId uniqueidentifier,@TillId uniqueidentifier,
 @ActorId uniqueidentifier,@ApprovedBy uniqueidentifier,@CustomerId uniqueidentifier,
 @Reason nvarchar(500),@OriginNodeId uniqueidentifier,
 @Lines [sales].[ReturnLineRequest] READONLY
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF NOT EXISTS(SELECT 1 FROM @Lines) OR LEN(LTRIM(RTRIM(@Reason)))=0
    THROW 51525,'Devolucion sin prendas o motivo.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
  IF EXISTS(SELECT 1 FROM sales.SaleReversals WHERE Id=@ReversalId)
  BEGIN
    IF NOT EXISTS(SELECT 1 FROM credits.Credits WHERE Id=@CreditId AND SourceReversalId=@ReversalId)
      THROW 51526,'Devolucion ya existe sin ese anticipo.',1;
    COMMIT; RETURN;
  END;
  IF NOT EXISTS(SELECT 1 FROM core.Locations WHERE Id=@ReturnLocationId AND BranchId=@BranchId)
    THROW 51527,'Ubicacion de devolucion no pertenece a sucursal.',1;
  IF NOT EXISTS(SELECT 1 FROM sales.CashTills t JOIN sales.CashRegisters r ON r.Id=t.RegisterId
     WHERE t.Id=@TillId AND t.Status='open' AND r.BranchId=@BranchId AND r.LocationId=@ReturnLocationId)
    THROW 51528,'Turno de devolucion no abierto.',1;
  IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a WHERE a.StaffId=@ApprovedBy
      AND a.BranchId=@BranchId AND a.CanApproveReturns=1 AND a.IsActive=1)
    THROW 51529,'Supervisor sin permiso para devoluciones.',1;
  DECLARE @currency varchar(3),@saleCustomer uniqueidentifier,@saleStatus varchar(24);
  SELECT @currency=CurrencyCode,@saleCustomer=CustomerId,@saleStatus=Status
     FROM sales.Sales WITH(UPDLOCK,HOLDLOCK) WHERE Id=@SaleId;
  IF @saleStatus IS NULL OR @saleStatus IN ('cancelled','returned') OR
       @saleCustomer IS NULL OR @saleCustomer<>@CustomerId
    THROW 51530,'Venta original o cliente no verificado.',1;
  IF EXISTS(SELECT 1 FROM @Lines WHERE Quantity<=0 OR RestockPool NOT IN ('store','quarantine'))
    THROW 51531,'Cantidad o condicion no valida.',1;
  DECLARE @line uniqueidentifier,@qty int,@pool varchar(12),@item uniqueidentifier,
    @oldReturned int,@originalQty int,@lineTotal bigint,@unitCost bigint,@priorCredit bigint,@part bigint,
    @total bigint=0,@op uniqueidentifier,@mv uniqueidentifier;
  -- Validacion y registro del documento antes de la emision del credito.
  INSERT INTO sales.SaleReversals(Id,SaleId,BranchId,LocationId,TillId,ActorId,Kind,
    SettlementKind,Reason,CreditMinor,CurrencyCode,Status,ApprovedBy,CreatedBy)
    VALUES(@ReversalId,@SaleId,@BranchId,@ReturnLocationId,@TillId,@ActorId,'return',
      'credit',@Reason,0,@currency,'approved',@ApprovedBy,@ActorId);
  DECLARE returnCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT SaleLineId,Quantity,RestockPool FROM @Lines ORDER BY SaleLineId;
  OPEN returnCursor; FETCH NEXT FROM returnCursor INTO @line,@qty,@pool;
  WHILE @@FETCH_STATUS=0
  BEGIN
     SET @item=NULL; SET @priorCredit=0;
     SELECT @item=ItemId,@oldReturned=ReturnedQuantity,@originalQty=Quantity,@lineTotal=TotalMinor,@unitCost=CostUnitSnapshotMinor
        FROM sales.SaleLines WITH(UPDLOCK,HOLDLOCK) WHERE Id=@line AND SaleId=@SaleId;
     IF @item IS NULL OR @oldReturned+@qty>@originalQty
        THROW 51532,'Intento de devolver unidades ya devueltas.',1;
     SELECT @priorCredit=COALESCE(SUM(rl.CreditMinor),0)
       FROM sales.SaleReversalLines rl JOIN sales.SaleReversals r ON r.Id=rl.ReversalId
       WHERE rl.SaleLineId=@line AND r.Status='approved';
     SET @part=CASE WHEN @oldReturned+@qty=@originalQty THEN @lineTotal-@priorCredit
       ELSE CONVERT(bigint,ROUND(CONVERT(decimal(28,4),@lineTotal)*@qty/@originalQty,0)) END;
     IF @part<0 OR @priorCredit+@part>@lineTotal THROW 51533,'Credito supera importe original.',1;
     UPDATE sales.SaleLines SET ReturnedQuantity=ReturnedQuantity+@qty,
       ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME() WHERE Id=@line;
     INSERT INTO sales.SaleReversalLines(ReversalId,SaleLineId,Quantity,CreditMinor,COGSReversedMinor,RestockPool,CreatedBy)
       VALUES(@ReversalId,@line,@qty,@part,CASE WHEN @unitCost IS NULL THEN NULL ELSE @unitCost*CONVERT(bigint,@qty) END,@pool,@ActorId);
     SET @op=NEWID(); SET @mv=NULL;
     EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@ReturnLocationId,
       @Pool=@pool,@Kind='return',@OnHandDelta=@qty,@SourceType='sale_reversal',
       @SourceId=@ReversalId,@ActorId=@ActorId,@MovementId=@mv OUTPUT;
     SET @total+=@part;
     FETCH NEXT FROM returnCursor INTO @line,@qty,@pool;
  END;
  CLOSE returnCursor; DEALLOCATE returnCursor;
  IF @total<=0 THROW 51534,'Anticipo debe tener valor mayor a cero.',1;
  UPDATE sales.SaleReversals SET CreditMinor=@total WHERE Id=@ReversalId;
  UPDATE sales.Sales SET Status=CASE WHEN NOT EXISTS(SELECT 1 FROM sales.SaleLines WHERE SaleId=@SaleId AND ReturnedQuantity<Quantity)
     THEN 'returned' ELSE 'partially_returned' END,
     ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME() WHERE Id=@SaleId;
  EXEC credits.usp_IssueFromReturn @CreditId,@ReversalId,@ActorId;
  DECLARE @evt uniqueidentifier=NEWID(),@payload nvarchar(max)=(SELECT @ReversalId AS returnId,
     @CreditId AS creditId,@SaleId AS saleId,@BranchId AS branchId,@total AS creditMinor,
     JSON_QUERY((SELECT SaleLineId,Quantity,CreditMinor,RestockPool
        FROM sales.SaleReversalLines WHERE ReversalId=@ReversalId FOR JSON PATH)) AS lines
     FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
  EXEC sync.usp_EnqueueEvent @evt,@OriginNodeId,'sale_return',@ReversalId,'sales.credit_return_posted',@payload;
  COMMIT;
 END TRY
 BEGIN CATCH
  IF CURSOR_STATUS('local','returnCursor')>=0 BEGIN CLOSE returnCursor; DEALLOCATE returnCursor; END;
  IF @@TRANCOUNT>0 ROLLBACK; THROW;
 END CATCH;
END;
GO

/* ==============================================================
   APARTADO DE STOCK ONLINE: particion explicita 'store' y 'web'.
   Se asigna primero en la BD local; Azure habilita e-commerce
   SOLO cuando confirma el evento de asignacion (handler .NET).
   ============================================================= */
CREATE OR ALTER PROCEDURE [inventory].[usp_AllocateToWeb]
 @AllocationId uniqueidentifier,@ItemId uniqueidentifier,@LocationId uniqueidentifier,
 @Quantity int,@ActorId uniqueidentifier,@OriginNodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Quantity<=0 THROW 51104,'Cantidad de asignacion invalida.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM audit.Operations WHERE Id=@AllocationId)
   BEGIN COMMIT; RETURN; END;
   DECLARE @out uniqueidentifier=NEWID(),@in uniqueidentifier=NEWID(),@mv uniqueidentifier=NULL,@negQuantity int=-@Quantity;
   EXEC inventory.usp_ApplyMovement @OperationId=@out,@ItemId=@ItemId,@LocationId=@LocationId,
     @Pool='store',@Kind='allocate',@OnHandDelta=@negQuantity,
     @SourceType='web_allocation',@SourceId=@AllocationId,@ActorId=@ActorId,@MovementId=@mv OUTPUT;
   SET @mv=NULL;
   EXEC inventory.usp_ApplyMovement @OperationId=@in,@ItemId=@ItemId,@LocationId=@LocationId,
     @Pool='web',@Kind='allocate',@OnHandDelta=@Quantity,
     @SourceType='web_allocation',@SourceId=@AllocationId,@ActorId=@ActorId,@MovementId=@mv OUTPUT;
   DECLARE @event uniqueidentifier=NEWID(),@payload nvarchar(max)=(
     SELECT @AllocationId AS allocationId,@ItemId AS itemId,@LocationId AS locationId,
        @Quantity AS quantity, @out AS storeMovementId,@in AS webMovementId
        FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   INSERT INTO audit.Operations(Id,ActorId,Scope,OperationKey,Fingerprint,ResultJson,CreatedBy)
     VALUES(@AllocationId,@ActorId,'inventory.web_allocation',CONVERT(varchar(36),@AllocationId),
       HASHBYTES('SHA2_256',CONVERT(varbinary(max),@payload)),@payload,@ActorId);
   EXEC sync.usp_EnqueueEvent @event,@OriginNodeId,'web_allocation',@AllocationId,
      'inventory.web_allocated',@payload;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [inventory].[usp_PostAdjustment]
 @AdjustmentId uniqueidentifier,@ItemId uniqueidentifier,@LocationId uniqueidentifier,
 @Pool varchar(12),@Delta int,@ActorId uniqueidentifier,@ApproverId uniqueidentifier,
 @Reason nvarchar(500),@OriginNodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Delta=0 OR LEN(LTRIM(RTRIM(@Reason)))=0 THROW 51105,'Ajuste invalido.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
  IF EXISTS(SELECT 1 FROM inventory.StockAdjustments WHERE Id=@AdjustmentId)
    BEGIN COMMIT; RETURN; END;
  IF @ActorId=@ApproverId THROW 51106,'Aprobador debe ser distinto del solicitante.',1;
  DECLARE @op uniqueidentifier=NEWID(),@mv uniqueidentifier=NULL;
  INSERT INTO inventory.StockAdjustments(Id,ItemId,LocationId,Pool,QuantityDelta,Reason,
    ApprovedBy,MovementOperationId,CreatedBy)
    VALUES(@AdjustmentId,@ItemId,@LocationId,@Pool,@Delta,@Reason,@ApproverId,@op,@ActorId);
  EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@ItemId,@LocationId=@LocationId,
    @Pool=@Pool,@Kind='adjust',@OnHandDelta=@Delta,
    @SourceType='stock_adjustment',@SourceId=@AdjustmentId,@ActorId=@ActorId,@MovementId=@mv OUTPUT;
  DECLARE @event uniqueidentifier=NEWID(),@payload nvarchar(max)=(
   SELECT @AdjustmentId AS adjustmentId,@ItemId AS itemId,@LocationId AS locationId,
     @Pool AS pool,@Delta AS quantityDelta,@Reason AS reason FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
  EXEC sync.usp_EnqueueEvent @event,@OriginNodeId,'stock_adjustment',@AdjustmentId,
    'inventory.adjusted',@payload;
  COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* ==============================================================
   E-COMMERCE: reservar SOLO pool 'web'. El dinero se captura por
   integracion validada en el backend, nunca desde el navegador.
   ============================================================= */
CREATE TYPE [webstore].[OrderLineRequest] AS TABLE (
  [LineNumber] int NOT NULL PRIMARY KEY,
  [ItemId] uniqueidentifier NOT NULL,
  [Quantity] int NOT NULL,
  [UnitPriceMinor] bigint NOT NULL,
  [DiscountMinor] bigint NOT NULL
);
GO
CREATE OR ALTER PROCEDURE [webstore].[usp_CreateReservedOrder]
 @OrderId uniqueidentifier,@CurrencyCode varchar(3),@LocationId uniqueidentifier,@BranchId uniqueidentifier,
 @OriginNodeId uniqueidentifier,@EventId uniqueidentifier,
 @Lines [webstore].[OrderLineRequest] READONLY,
 @CustomerId uniqueidentifier=NULL,@ShippingMinor bigint=0
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @ShippingMinor<0 OR NOT EXISTS(SELECT 1 FROM @Lines)
    THROW 51701,'Pedido vacio o costo envio invalido.',1;
 DECLARE @input nvarchar(max)=(SELECT @OrderId AS orderId,@CurrencyCode AS currency,
     @CustomerId AS customerId,@LocationId AS locationId,@ShippingMinor AS shippingMinor,
     JSON_QUERY((SELECT * FROM @Lines ORDER BY LineNumber FOR JSON PATH)) AS lines
     FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
 DECLARE @hash varbinary(32)=HASHBYTES('SHA2_256',CONVERT(varbinary(max),@input));
 BEGIN TRANSACTION;
 BEGIN TRY
  IF EXISTS(SELECT 1 FROM webstore.Orders WHERE Id=@OrderId)
  BEGIN
    IF EXISTS(SELECT 1 FROM webstore.Orders WHERE Id=@OrderId AND RequestHash<>@hash)
      THROW 51710,'OrderId duplicado con contenido distinto.',1;
    COMMIT; RETURN;
  END;
  IF NOT EXISTS(SELECT 1 FROM core.Locations WHERE Id=@LocationId AND BranchId=@BranchId)
    THROW 51702,'Sucursal de cumplimiento invalida.',1;
  IF EXISTS(SELECT 1 FROM @Lines l LEFT JOIN catalog.Items i ON i.Id=l.ItemId
     WHERE i.Id IS NULL OR i.Status<>'active' OR i.CurrencyCode<>@CurrencyCode OR
       i.UnitPriceMinor<>l.UnitPriceMinor OR l.Quantity<=0 OR l.DiscountMinor<0 OR
       CAST(l.UnitPriceMinor AS decimal(28,0))*l.Quantity<l.DiscountMinor)
     THROW 51703,'Precio/cantidad de pedido invalido.',1;
  DECLARE @calc TABLE(LineNumber int PRIMARY KEY,ItemId uniqueidentifier,Quantity int,
    UnitPriceMinor bigint,DiscountMinor bigint,TaxMinor bigint,TotalMinor bigint);
  INSERT INTO @calc
  SELECT l.LineNumber,l.ItemId,l.Quantity,l.UnitPriceMinor,l.DiscountMinor,
    CAST(ROUND((CAST(l.UnitPriceMinor AS decimal(28,0))*l.Quantity-l.DiscountMinor)
          *i.TaxRateBps/10000.0,0) AS bigint),
    CAST(l.UnitPriceMinor AS bigint)*l.Quantity-l.DiscountMinor+
      CAST(ROUND((CAST(l.UnitPriceMinor AS decimal(28,0))*l.Quantity-l.DiscountMinor)
          *i.TaxRateBps/10000.0,0) AS bigint)
  FROM @Lines l JOIN catalog.Items i ON i.Id=l.ItemId;
  DECLARE @subtotal bigint=(SELECT SUM(CAST(UnitPriceMinor AS bigint)*Quantity) FROM @calc),
   @discount bigint=(SELECT SUM(DiscountMinor) FROM @calc),
   @tax bigint=(SELECT SUM(TaxMinor) FROM @calc),
   @total bigint=(SELECT SUM(TotalMinor) FROM @calc)+@ShippingMinor;
  INSERT INTO webstore.Orders(Id,CustomerId,RequestHash,CurrencyCode,SubtotalMinor,DiscountMinor,TaxMinor,
    ShippingMinor,TotalMinor,Status) VALUES(@OrderId,@CustomerId,@hash,@CurrencyCode,
    @subtotal,@discount,@tax,@ShippingMinor,@total,'reserved');
  DECLARE @lineNo int,@item uniqueidentifier,@qty int,@unit bigint,@disc bigint,@lineTax bigint,
    @lineTotal bigint,@lineId uniqueidentifier,@reservation uniqueidentifier,@op uniqueidentifier,@mv uniqueidentifier;
  DECLARE webCursor CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @calc ORDER BY LineNumber;
  OPEN webCursor; FETCH NEXT FROM webCursor INTO @lineNo,@item,@qty,@unit,@disc,@lineTax,@lineTotal;
  WHILE @@FETCH_STATUS=0
  BEGIN
    SET @lineId=NEWID(); SET @reservation=NEWID(); SET @op=NEWID(); SET @mv=NULL;
    INSERT INTO inventory.StockReservations(Id,ItemId,LocationId,Pool,Quantity,
      ReferenceType,ReferenceId,Status) VALUES(@reservation,@item,@LocationId,'web',@qty,
      'web_order_line',@lineId,'active');
    EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@LocationId,
      @Pool='web',@Kind='reserve',@OnHandDelta=0,@ReservedDelta=@qty,
      @SourceType='web_reservation',@SourceId=@reservation,@MovementId=@mv OUTPUT;
    INSERT INTO webstore.OrderLines(OrderId,LineNumber,ItemId,SkuSnapshot,Quantity,
      UnitPriceMinor,DiscountMinor,TaxMinor,TotalMinor,ReservationId)
      SELECT @OrderId,@lineNo,@item,Sku,@qty,@unit,@disc,@lineTax,@lineTotal,@reservation
      FROM catalog.Items WHERE Id=@item;
    FETCH NEXT FROM webCursor INTO @lineNo,@item,@qty,@unit,@disc,@lineTax,@lineTotal;
  END;
  CLOSE webCursor; DEALLOCATE webCursor;
  INSERT INTO webstore.Fulfillments(Id,OrderId,BranchId,LocationId,Status)
    VALUES(NEWID(),@OrderId,@BranchId,@LocationId,'pending');
  DECLARE @payload nvarchar(max)=(SELECT @OrderId AS orderId,@BranchId AS fulfillBranchId,
     @LocationId AS fulfillLocationId,@total AS totalMinor,@CurrencyCode AS currency,
     JSON_QUERY((SELECT ItemId,Quantity,UnitPriceMinor,TotalMinor FROM webstore.OrderLines
       WHERE OrderId=@OrderId ORDER BY LineNumber FOR JSON PATH)) AS lines
     FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
  EXEC sync.usp_EnqueueEvent @EventId,@OriginNodeId,'web_order',@OrderId,
     'web.order_reserved',@payload;
  DECLARE @dest uniqueidentifier=(SELECT Id FROM sync.Nodes WHERE BranchId=@BranchId AND Kind='branch' AND IsEnabled=1);
  IF @dest IS NULL THROW 51711,'No existe nodo local de preparacion para este pedido.',1;
  EXEC sync.usp_RouteEvent @EventId,@dest;
  COMMIT;
 END TRY
 BEGIN CATCH
  IF CURSOR_STATUS('local','webCursor')>=0 BEGIN CLOSE webCursor; DEALLOCATE webCursor; END;
  IF @@TRANCOUNT>0 ROLLBACK; THROW;
 END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [webstore].[usp_RecordVerifiedPayment]
 @PaymentId uniqueidentifier,@OrderId uniqueidentifier,@Provider nvarchar(80),
 @ExternalPaymentId nvarchar(160),@AmountMinor bigint,@CurrencyCode varchar(3),
 @VerifiedByTrustedService bit,@OriginNodeId uniqueidentifier,@EventId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @VerifiedByTrustedService<>1
   THROW 51704,'Firma de pago no verificada por el backend.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM webstore.Payments WHERE Provider=@Provider AND ExternalPaymentId=@ExternalPaymentId)
   BEGIN
     IF NOT EXISTS(SELECT 1 FROM webstore.Payments WHERE Id=@PaymentId AND OrderId=@OrderId
       AND AmountMinor=@AmountMinor AND CurrencyCode=@CurrencyCode)
       THROW 51705,'Id de pasarela reusado para otro pago.',1;
     COMMIT; RETURN;
   END;
   IF NOT EXISTS(SELECT 1 FROM webstore.Orders WITH(UPDLOCK,HOLDLOCK)
      WHERE Id=@OrderId AND CurrencyCode=@CurrencyCode AND TotalMinor=@AmountMinor
       AND Status='reserved')
     THROW 51706,'Pago distinto al pedido o pedido sin reserva.',1;
   INSERT INTO webstore.Payments(Id,OrderId,Provider,ExternalPaymentId,AmountMinor,
     CurrencyCode,Status,VerifiedAt)
       VALUES(@PaymentId,@OrderId,@Provider,@ExternalPaymentId,@AmountMinor,
         @CurrencyCode,'captured',SYSUTCDATETIME());
   UPDATE webstore.Orders SET Status='paid',ModifiedAt=SYSUTCDATETIME() WHERE Id=@OrderId;
   DECLARE @payload nvarchar(max)=(SELECT @OrderId AS orderId,@PaymentId AS paymentId,
       @Provider AS provider,@AmountMinor AS amountMinor FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   EXEC sync.usp_EnqueueEvent @EventId,@OriginNodeId,'web_order',@OrderId,'web.payment_captured',@payload;
   DECLARE @dest uniqueidentifier=(SELECT TOP(1) n.Id FROM webstore.Fulfillments f
       JOIN sync.Nodes n ON n.BranchId=f.BranchId AND n.Kind='branch' AND n.IsEnabled=1
       WHERE f.OrderId=@OrderId ORDER BY n.NodeCode);
   IF @dest IS NULL THROW 51712,'No existe nodo de cumplimiento.',1;
   EXEC sync.usp_RouteEvent @EventId,@dest;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [webstore].[usp_FulfillPaidOrder]
 @OrderId uniqueidentifier,@OriginNodeId uniqueidentifier,@EventId uniqueidentifier,
 @ActorId uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
  DECLARE @status varchar(24),@location uniqueidentifier;
  SELECT @status=Status FROM webstore.Orders WITH(UPDLOCK,HOLDLOCK) WHERE Id=@OrderId;
  IF @status='fulfilled' BEGIN COMMIT; RETURN; END;
  IF @status IS NULL OR @status<>'paid' THROW 51707,'Pedido no pagado.',1;
  SELECT @location=LocationId FROM webstore.Fulfillments WHERE OrderId=@OrderId AND Status='pending';
  IF @location IS NULL THROW 51708,'No hay origen de cumplimiento.',1;
  DECLARE @reservation uniqueidentifier,@item uniqueidentifier,@qty int,@op uniqueidentifier,@mv uniqueidentifier,@negQty int;
  DECLARE fulfillCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT ol.ReservationId,ol.ItemId,ol.Quantity FROM webstore.OrderLines ol WHERE ol.OrderId=@OrderId ORDER BY ol.LineNumber;
  OPEN fulfillCursor; FETCH NEXT FROM fulfillCursor INTO @reservation,@item,@qty;
  WHILE @@FETCH_STATUS=0
  BEGIN
    IF NOT EXISTS(SELECT 1 FROM inventory.StockReservations WHERE Id=@reservation AND Status='active'
       AND LocationId=@location AND Quantity=@qty)
      THROW 51709,'Reserva faltante o distinta de la compra.',1;
    SET @op=NEWID(); SET @mv=NULL; SET @negQty=-@qty;
    EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@location,
      @Pool='web',@Kind='fulfill',@OnHandDelta=@negQty,@ReservedDelta=@negQty,
      @SourceType='web_order',@SourceId=@OrderId,@ActorId=@ActorId,@MovementId=@mv OUTPUT;
    UPDATE inventory.StockReservations SET Status='fulfilled',ModifiedAt=SYSUTCDATETIME() WHERE Id=@reservation;
    FETCH NEXT FROM fulfillCursor INTO @reservation,@item,@qty;
  END;
  CLOSE fulfillCursor; DEALLOCATE fulfillCursor;
  UPDATE webstore.Orders SET Status='fulfilled',ModifiedAt=SYSUTCDATETIME() WHERE Id=@OrderId;
  UPDATE webstore.Fulfillments SET Status='shipped',ShippedAt=SYSUTCDATETIME(),ModifiedAt=SYSUTCDATETIME()
      WHERE OrderId=@OrderId AND Status='pending';
  DECLARE @payload nvarchar(max)=(SELECT @OrderId AS orderId,@location AS locationId,
        JSON_QUERY((SELECT ItemId,Quantity FROM webstore.OrderLines WHERE OrderId=@OrderId FOR JSON PATH)) AS lines
        FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
  EXEC sync.usp_EnqueueEvent @EventId,@OriginNodeId,'web_order',@OrderId,'web.fulfilled',@payload;
  COMMIT;
 END TRY
 BEGIN CATCH
  IF CURSOR_STATUS('local','fulfillCursor')>=0 BEGIN CLOSE fulfillCursor; DEALLOCATE fulfillCursor; END;
  IF @@TRANCOUNT>0 ROLLBACK; THROW;
 END CATCH;
END;
GO

/* ==============================================================
   CONTABILIDAD: documentos de cierre, exportacion y asientos.
   El cierre es SOPORTE contable, NO comprobante tributario nuevo.
   ============================================================= */
CREATE OR ALTER PROCEDURE [accounting].[usp_QueueExport]
 @ExportId uniqueidentifier,@CloseDocumentId uniqueidentifier,
 @RecipientCode nvarchar(100),@Format varchar(16),@ActorId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Format NOT IN ('PDF','CSV','JSON','XML') THROW 51801,'Formato no soportado.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM accounting.ExportJobs WHERE CloseDocumentId=@CloseDocumentId
       AND RecipientCode=@RecipientCode AND Format=@Format)
     BEGIN COMMIT; RETURN; END;
   INSERT INTO accounting.ExportJobs(Id,CloseDocumentId,RecipientCode,Format,Status,CreatedBy)
     VALUES(@ExportId,@CloseDocumentId,@RecipientCode,@Format,'pending',@ActorId);
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [accounting].[usp_MarkExportSent]
 @ExportId uniqueidentifier,@BlobKey nvarchar(500),@Delivered bit
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF @Delivered=1
     UPDATE accounting.ExportJobs SET Status='sent',BlobKey=@BlobKey,SentAt=SYSUTCDATETIME(),
        ModifiedAt=SYSUTCDATETIME() WHERE Id=@ExportId AND Status IN ('pending','ready','generating','sent');
   ELSE
     UPDATE accounting.ExportJobs SET Status='ready',BlobKey=@BlobKey,
        ModifiedAt=SYSUTCDATETIME() WHERE Id=@ExportId AND Status IN ('pending','generating','ready');
   IF @@ROWCOUNT<>1 THROW 51802,'No se puede marcar una exportacion inexistente o finalizada.',1;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [accounting].[usp_PostJournal]
 @EntryId uniqueidentifier,@PosterId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF NOT EXISTS(SELECT 1 FROM accounting.JournalEntries WITH(UPDLOCK,HOLDLOCK)
       WHERE Id=@EntryId AND Status='draft')
       THROW 51803,'Asiento no existe o ya publicado.',1;
   DECLARE @debit bigint=(SELECT COALESCE(SUM(DebitMinor),0) FROM accounting.JournalLines WHERE JournalEntryId=@EntryId),
       @credit bigint=(SELECT COALESCE(SUM(CreditMinor),0) FROM accounting.JournalLines WHERE JournalEntryId=@EntryId);
   IF @debit=0 OR @debit<>@credit OR
      (SELECT COUNT(*) FROM accounting.JournalLines WHERE JournalEntryId=@EntryId)<2
      THROW 51804,'Asiento no balanceado o incompleto.',1;
   IF EXISTS(SELECT 1 FROM accounting.JournalLines l JOIN accounting.Accounts a ON a.Id=l.AccountId
        WHERE l.JournalEntryId=@EntryId AND a.IsActive=0)
     THROW 51805,'Cuenta contable inactiva.',1;
   UPDATE accounting.JournalEntries SET Status='posted',PostedAt=SYSUTCDATETIME(),PostedBy=@PosterId,
      ModifiedBy=@PosterId,ModifiedAt=SYSUTCDATETIME() WHERE Id=@EntryId;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* ==============================================================
   VISTAS: consulta y diagnostico, sin persistir totales de negocio.
   ============================================================= */
CREATE OR ALTER VIEW [inventory].[vw_StockAvailable]
AS
SELECT b.ItemId,i.Sku,i.VariantName,b.LocationId,l.BranchId,b.Pool,
   b.OnHand,b.Reserved,(b.OnHand-b.Reserved) AS Available,b.ModifiedAt
FROM inventory.StockBalances b
JOIN catalog.Items i ON i.Id=b.ItemId
JOIN core.Locations l ON l.Id=b.LocationId;
GO

CREATE OR ALTER VIEW [credits].[vw_CreditBalanceByBranch]
AS
SELECT c.Id AS CreditId,c.CustomerId,a.BranchId,c.CurrencyCode,
       a.AvailableMinor,a.HeldMinor,c.OriginalMinor,c.Status
FROM credits.Credits c JOIN credits.CreditAllocations a ON a.CreditId=c.Id;
GO

CREATE OR ALTER VIEW [receiving].[vw_SessionProgress]
AS
SELECT s.Id AS ScanSessionId,c.Id AS ContainerId,c.Reference,
   c.LocationId,s.Status,
   COUNT(e.Id) AS ScanEvents,
   COALESCE(SUM(CASE WHEN e.MatchStatus='matched' THEN CONVERT(bigint,e.Quantity) ELSE 0 END),0) AS MatchedUnits,
   COALESCE(SUM(CASE WHEN e.MatchStatus<>'matched' THEN CONVERT(bigint,e.Quantity) ELSE 0 END),0) AS UnitsPendingReview
FROM receiving.ScanSessions s JOIN receiving.ImportContainers c ON c.Id=s.ContainerId
LEFT JOIN receiving.ScanEvents e ON e.ScanSessionId=s.Id
GROUP BY s.Id,c.Id,c.Reference,c.LocationId,s.Status;
GO

CREATE OR ALTER VIEW [sales].[vw_ClosuresWithAccounting]
AS
SELECT c.Id AS ClosureId,t.Id AS TillId,r.BranchId,r.LocationId,c.ClosedAt,
  c.ExpectedMinor,c.CountedMinor,c.DifferenceMinor,d.Id AS DocumentId,
  d.DocumentKind,d.Status AS DocumentStatus,d.SaleGrossMinor,d.ReturnGrossMinor,
  d.NetSalesMinor,d.SaleTaxMinor,d.CardCapturedMinor,d.CreditRedeemedMinor
FROM sales.CashClosures c
JOIN sales.CashTills t ON t.Id=c.TillId
JOIN sales.CashRegisters r ON r.Id=t.RegisterId
LEFT JOIN accounting.CloseDocuments d ON d.ClosureId=c.Id;
GO

CREATE OR ALTER VIEW [sync].[vw_PendingByNode]
AS
SELECT d.DestinationNodeId,COUNT_BIG(*) AS PendingDeliveries,
   MIN(e.CreatedAt) AS OldestEventAt
FROM sync.EventDeliveries d JOIN sync.Outbox e ON e.EventId=d.EventId
WHERE d.Status IN ('pending','retry')
GROUP BY d.DestinationNodeId;
GO

/* ==============================================================
   ACTIVACION DE VARIANTE: sin precio/costo aprobado, la mercancia
   puede ingresar a cuarentena, pero no estar disponible para venta.
   ============================================================= */
CREATE OR ALTER PROCEDURE [catalog].[usp_ActivateItem]
 @ItemId uniqueidentifier,@UnitPriceMinor bigint,@UnitCostMinor bigint,
 @ActorId uniqueidentifier,@OriginNodeId uniqueidentifier,@EventId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @UnitPriceMinor<=0 OR @UnitCostMinor<0 THROW 51220,'Precio y costo deben estar aprobados.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF NOT EXISTS(SELECT 1 FROM catalog.Items WITH(UPDLOCK,HOLDLOCK)
      WHERE Id=@ItemId AND Status IN ('draft','active'))
      THROW 51221,'Variante no existe o inactiva.',1;
   UPDATE catalog.Items SET Status='active',UnitPriceMinor=@UnitPriceMinor,
      UnitCostMinor=@UnitCostMinor,ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId WHERE Id=@ItemId;
   DECLARE @payload nvarchar(max)=(SELECT @ItemId AS itemId,@UnitPriceMinor AS priceMinor,
        @UnitCostMinor AS costMinor,N'active' AS status FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   EXEC sync.usp_EnqueueEvent @EventId,@OriginNodeId,'item',@ItemId,'catalog.item_activated',@payload;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [inventory].[usp_ReleaseQuarantine]
 @ReleaseId uniqueidentifier,@ItemId uniqueidentifier,@LocationId uniqueidentifier,
 @Quantity int,@ActorId uniqueidentifier,@ApproverId uniqueidentifier,
 @OriginNodeId uniqueidentifier,@Reason nvarchar(350)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Quantity<=0 OR @ActorId=@ApproverId OR LEN(LTRIM(RTRIM(@Reason)))=0
   THROW 51120,'Liberacion requiere cantidad y doble aprobacion.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM audit.Operations WHERE Id=@ReleaseId)
      BEGIN COMMIT; RETURN; END;
   IF NOT EXISTS(SELECT 1 FROM catalog.Items WHERE Id=@ItemId AND Status='active'
       AND UnitPriceMinor>0 AND UnitCostMinor IS NOT NULL)
      THROW 51121,'Variante sin precio/costo aprobado.',1;
   DECLARE @branch uniqueidentifier;
   SELECT @branch=BranchId FROM core.Locations WHERE Id=@LocationId;
   IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a
       WHERE a.StaffId=@ApproverId AND a.BranchId=@branch AND a.IsActive=1)
      THROW 51122,'Aprobador no pertenece a sucursal.',1;
   DECLARE @op1 uniqueidentifier=NEWID(),@op2 uniqueidentifier=NEWID(),@mv uniqueidentifier=NULL,@negQuantity int=-@Quantity;
   EXEC inventory.usp_ApplyMovement @OperationId=@op1,@ItemId=@ItemId,@LocationId=@LocationId,
     @Pool='quarantine',@Kind='transfer_out',@OnHandDelta=@negQuantity,
     @SourceType='quarantine_release',@SourceId=@ReleaseId,@ActorId=@ActorId,@MovementId=@mv OUTPUT;
   SET @mv=NULL;
   EXEC inventory.usp_ApplyMovement @OperationId=@op2,@ItemId=@ItemId,@LocationId=@LocationId,
     @Pool='store',@Kind='transfer_in',@OnHandDelta=@Quantity,
     @SourceType='quarantine_release',@SourceId=@ReleaseId,@ActorId=@ActorId,@MovementId=@mv OUTPUT;
   DECLARE @payload nvarchar(max)=(SELECT @ReleaseId AS releaseId,@ItemId AS itemId,
      @LocationId AS locationId,@Quantity AS quantity,@Reason AS reason
      FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   INSERT INTO audit.Operations(Id,ActorId,BranchId,Scope,OperationKey,Fingerprint,ResultJson,CreatedBy)
     VALUES(@ReleaseId,@ActorId,@branch,'inventory.quarantine_release',CONVERT(varchar(36),@ReleaseId),
       HASHBYTES('SHA2_256',CONVERT(varbinary(max),@payload)),@payload,@ActorId);
   DECLARE @event uniqueidentifier=NEWID();
   EXEC sync.usp_EnqueueEvent @event,@OriginNodeId,'quarantine_release',@ReleaseId,
     'inventory.quarantine_released',@payload;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* Configuracion de tabla de precios / lectura eficiente por barcode.
   Resuelve ambiguedades en vez de escoger arbitrariamente una variante. */
CREATE OR ALTER PROCEDURE [catalog].[usp_LookupByScan]
 @RawCode nvarchar(128),@SupplierId uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SELECT DISTINCT i.Id AS ItemId,i.Sku,i.VariantName,i.UnitPriceMinor,
    i.CurrencyCode,i.Status,p.Name AS ProductName,sz.Code AS SizeCode,co.Code AS ColorCode
 FROM catalog.ItemIdentifiers id
 JOIN catalog.Items i ON i.Id=id.ItemId
 JOIN catalog.Products p ON p.Id=i.ProductId
 LEFT JOIN catalog.Sizes sz ON sz.Id=i.SizeId
 LEFT JOIN catalog.Colors co ON co.Id=i.ColorId
 WHERE id.RawCode=@RawCode AND id.IsActive=1
   AND ((id.Kind='barcode' AND id.SupplierId IS NULL)
     OR (id.SupplierId=@SupplierId AND id.Kind IN ('barcode','supplier_sku','alias'))
     OR (id.Kind='alias' AND id.SupplierId IS NULL));
 -- El consumidor debe rechazar si devuelve mas de una fila.
END;
GO

-- ======= FIN 02_SAVIA_Procedures.sql =======


-- ======= INICIO 04_SAVIA_Roles.sql =======
/* SAVIA - Roles de menor privilegio. No crea logins ni credenciales. */
CREATE ROLE [savia_pos_app] AUTHORIZATION [dbo];
CREATE ROLE [savia_inventory_app] AUTHORIZATION [dbo];
CREATE ROLE [savia_manager_app] AUTHORIZATION [dbo];
CREATE ROLE [savia_web_checkout] AUTHORIZATION [dbo];
CREATE ROLE [savia_payment_worker] AUTHORIZATION [dbo];
CREATE ROLE [savia_fulfillment_worker] AUTHORIZATION [dbo];
CREATE ROLE [savia_sync_worker] AUTHORIZATION [dbo];
CREATE ROLE [savia_label_worker] AUTHORIZATION [dbo];
CREATE ROLE [savia_accounting_worker] AUTHORIZATION [dbo];
GO
GRANT EXECUTE ON OBJECT::[sales].[usp_OpenTill] TO [savia_pos_app];
GRANT EXECUTE ON OBJECT::[sales].[usp_PostSale] TO [savia_pos_app];
GRANT EXECUTE ON OBJECT::[sales].[usp_RecordCashEntry] TO [savia_pos_app];
GRANT EXECUTE ON OBJECT::[sales].[usp_PostCreditReturn] TO [savia_pos_app];
GRANT EXECUTE ON OBJECT::[receiving].[usp_RecordScan] TO [savia_inventory_app];
GRANT EXECUTE ON OBJECT::[catalog].[usp_LookupByScan] TO [savia_inventory_app];
GRANT EXECUTE ON OBJECT::[receiving].[usp_ApproveScanSession] TO [savia_manager_app];
GRANT EXECUTE ON OBJECT::[receiving].[usp_ResolveScan] TO [savia_manager_app];
GRANT EXECUTE ON OBJECT::[receiving].[usp_PostScanSession] TO [savia_manager_app];
GRANT EXECUTE ON OBJECT::[catalog].[usp_RegisterProduct] TO [savia_manager_app];
GRANT EXECUTE ON OBJECT::[catalog].[usp_RegisterItem] TO [savia_manager_app];
GRANT EXECUTE ON OBJECT::[catalog].[usp_ActivateItem] TO [savia_manager_app];
GRANT EXECUTE ON OBJECT::[catalog].[usp_ChangePrice] TO [savia_manager_app];
GRANT EXECUTE ON OBJECT::[inventory].[usp_ReleaseQuarantine] TO [savia_manager_app];
GRANT EXECUTE ON OBJECT::[inventory].[usp_AllocateToWeb] TO [savia_manager_app];
GRANT EXECUTE ON OBJECT::[inventory].[usp_PostAdjustment] TO [savia_manager_app];
GRANT EXECUTE ON OBJECT::[credits].[usp_RequestTransfer] TO [savia_manager_app];
GRANT EXECUTE ON OBJECT::[credits].[usp_ApproveTransfer] TO [savia_manager_app];
GRANT EXECUTE ON OBJECT::[credits].[usp_LockTransferAtOrigin] TO [savia_manager_app];
GRANT EXECUTE ON OBJECT::[credits].[usp_AcceptTransfer] TO [savia_manager_app];
GRANT EXECUTE ON OBJECT::[credits].[usp_CancelUnblockedTransfer] TO [savia_manager_app];
GRANT EXECUTE ON OBJECT::[sales].[usp_SubmitCashCount] TO [savia_manager_app];
GRANT EXECUTE ON OBJECT::[sales].[usp_CloseTill] TO [savia_manager_app];
GRANT EXECUTE ON OBJECT::[webstore].[usp_CreateReservedOrder] TO [savia_web_checkout];
GRANT EXECUTE ON OBJECT::[webstore].[usp_RecordVerifiedPayment] TO [savia_payment_worker];
GRANT EXECUTE ON OBJECT::[webstore].[usp_FulfillPaidOrder] TO [savia_fulfillment_worker];
GRANT EXECUTE ON OBJECT::[sync].[usp_EnqueueEvent] TO [savia_sync_worker];
GRANT EXECUTE ON OBJECT::[sync].[usp_RouteEvent] TO [savia_sync_worker];
GRANT EXECUTE ON OBJECT::[sync].[usp_PullEvents] TO [savia_sync_worker];
GRANT EXECUTE ON OBJECT::[sync].[usp_AcknowledgeDelivery] TO [savia_sync_worker];
GRANT EXECUTE ON OBJECT::[sync].[usp_RecordAppliedInbox] TO [savia_sync_worker];
GRANT EXECUTE ON OBJECT::[sync].[usp_AdvanceCursor] TO [savia_sync_worker];
GRANT EXECUTE ON OBJECT::[credits].[usp_CommitTransfer] TO [savia_sync_worker];
GRANT EXECUTE ON OBJECT::[credits].[usp_LockTransferAtOrigin] TO [savia_sync_worker];
GRANT EXECUTE ON OBJECT::[credits].[usp_AcceptTransfer] TO [savia_sync_worker];
GRANT EXECUTE ON OBJECT::[labels].[usp_AcknowledgePrint] TO [savia_label_worker];
GRANT EXECUTE ON OBJECT::[accounting].[usp_QueueExport] TO [savia_accounting_worker];
GRANT EXECUTE ON OBJECT::[accounting].[usp_MarkExportSent] TO [savia_accounting_worker];
GRANT EXECUTE ON OBJECT::[accounting].[usp_PostJournal] TO [savia_accounting_worker];
GO
/* TVP: las cuentas ejecutoras necesitan REFERENCES sobre cada tipo de tabla
   ademas del EXECUTE del procedimiento que lo recibe. */
GRANT EXECUTE, REFERENCES ON TYPE::[sales].[SaleLineRequest] TO [savia_pos_app];
GRANT EXECUTE, REFERENCES ON TYPE::[sales].[SaleTenderRequest] TO [savia_pos_app];
GRANT EXECUTE, REFERENCES ON TYPE::[sales].[ReturnLineRequest] TO [savia_pos_app];
GRANT EXECUTE, REFERENCES ON TYPE::[webstore].[OrderLineRequest] TO [savia_web_checkout];
GO
GRANT SELECT ON OBJECT::[inventory].[vw_StockAvailable] TO [savia_pos_app];
GRANT SELECT ON OBJECT::[inventory].[vw_StockAvailable] TO [savia_inventory_app];
GRANT SELECT ON OBJECT::[inventory].[vw_StockAvailable] TO [savia_web_checkout];
GRANT SELECT ON OBJECT::[credits].[vw_CreditBalanceByBranch] TO [savia_pos_app];
GRANT SELECT ON OBJECT::[receiving].[vw_SessionProgress] TO [savia_inventory_app];
GRANT SELECT ON OBJECT::[sales].[vw_ClosuresWithAccounting] TO [savia_accounting_worker];
GRANT SELECT ON OBJECT::[sync].[vw_PendingByNode] TO [savia_sync_worker];
GO
/* Los servicios deben usar cuentas separadas por rol. Una cuenta con db_owner
   anula este aislamiento. La API tambien valida autorizacion por sucursal y
   identidad del nodo; estos grants no sustituyen JWT/mTLS/roles del dominio. */

-- ======= FIN 04_SAVIA_Roles.sql =======
