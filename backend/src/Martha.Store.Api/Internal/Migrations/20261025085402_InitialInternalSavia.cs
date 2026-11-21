using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Martha.Store.Api.Internal.Migrations
{
    /// <inheritdoc />
    public partial class InitialInternalSavia : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.EnsureSchema(
                name: "savia_internal");

            migrationBuilder.CreateTable(
                name: "Items",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Sku = table.Column<string>(type: "varchar(64)", unicode: false, maxLength: 64, nullable: false, collation: "Latin1_General_100_BIN2"),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    UnitPriceMinor = table.Column<long>(type: "bigint", nullable: false),
                    Currency = table.Column<string>(type: "varchar(3)", unicode: false, maxLength: 3, nullable: false, collation: "Latin1_General_100_BIN2"),
                    Active = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Items", x => x.Id);
                    table.CheckConstraint("CK_InternalItems_Currency", "DATALENGTH([Currency]) = 3 AND [Currency] COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^A-Z]%' AND [Currency] <> 'XXX'");
                    table.CheckConstraint("CK_InternalItems_Name", "LEN(LTRIM(RTRIM([Name]))) > 0");
                    table.CheckConstraint("CK_InternalItems_Price", "[UnitPriceMinor] >= 0 AND [UnitPriceMinor] <= 9000000000000");
                    table.CheckConstraint("CK_InternalItems_Sku", "LEN([Sku]) BETWEEN 1 AND 64 AND DATALENGTH([Sku]) = LEN([Sku]) AND [Sku] COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^A-Z0-9_.-]%'");
                });

            migrationBuilder.CreateTable(
                name: "Locations",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    Active = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Locations", x => x.Id);
                    table.CheckConstraint("CK_InternalLocations_Name", "LEN(LTRIM(RTRIM([Name]))) > 0");
                });

            migrationBuilder.CreateTable(
                name: "Parties",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Kind = table.Column<string>(type: "varchar(8)", unicode: false, maxLength: 8, nullable: false, collation: "Latin1_General_100_BIN2"),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Email = table.Column<string>(type: "nvarchar(254)", maxLength: 254, nullable: true),
                    Phone = table.Column<string>(type: "nvarchar(32)", maxLength: 32, nullable: true),
                    Active = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Parties", x => x.Id);
                    table.CheckConstraint("CK_InternalParties_Kind", "[Kind] IN ('customer', 'supplier')");
                    table.CheckConstraint("CK_InternalParties_Name", "LEN(LTRIM(RTRIM([Name]))) > 0");
                });

            migrationBuilder.CreateTable(
                name: "Staff",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    LoginName = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    NormalizedLoginName = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    DisplayName = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
                    PasswordHash = table.Column<string>(type: "nvarchar(512)", maxLength: 512, nullable: false),
                    Role = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false),
                    Enabled = table.Column<bool>(type: "bit", nullable: false),
                    SecurityVersion = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    FailedSignIns = table.Column<int>(type: "int", nullable: false),
                    LockedUntil = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    RowVersion = table.Column<byte[]>(type: "rowversion", rowVersion: true, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Staff", x => x.Id);
                    table.CheckConstraint("CK_InternalStaff_FailedSignIns", "[FailedSignIns] >= 0 AND [FailedSignIns] <= 5");
                    table.CheckConstraint("CK_InternalStaff_Role", "[Role] IN ('Owner','Manager','Cashier','Inventory')");
                });

            migrationBuilder.CreateTable(
                name: "StockBalances",
                schema: "savia_internal",
                columns: table => new
                {
                    ItemId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    LocationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    OnHand = table.Column<int>(type: "int", nullable: false),
                    Reserved = table.Column<int>(type: "int", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StockBalances", x => new { x.ItemId, x.LocationId });
                    table.CheckConstraint("CK_InternalBalance_Bounds", "[OnHand] >= 0 AND [OnHand] <= 1000000000 AND [Reserved] >= 0 AND [Reserved] <= [OnHand]");
                    table.ForeignKey(
                        name: "FK_StockBalances_Items_ItemId",
                        column: x => x.ItemId,
                        principalSchema: "savia_internal",
                        principalTable: "Items",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_StockBalances_Locations_LocationId",
                        column: x => x.LocationId,
                        principalSchema: "savia_internal",
                        principalTable: "Locations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "PurchaseOrders",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SupplierId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    LocationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SupplierName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Currency = table.Column<string>(type: "varchar(3)", unicode: false, maxLength: 3, nullable: false),
                    Reference = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true),
                    Status = table.Column<string>(type: "varchar(24)", unicode: false, maxLength: 24, nullable: false),
                    TotalMinor = table.Column<long>(type: "bigint", nullable: false),
                    CreatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    UpdatedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    CancelledBy = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CancelledAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                    CancellationReason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PurchaseOrders", x => x.Id);
                    table.CheckConstraint("CK_InternalPurchaseOrder_Cancel", "([Status] = 'cancelled' AND [CancelledBy] IS NOT NULL AND [CancelledAt] IS NOT NULL AND [CancellationReason] IS NOT NULL) OR ([Status] <> 'cancelled' AND [CancelledBy] IS NULL AND [CancelledAt] IS NULL AND [CancellationReason] IS NULL)");
                    table.CheckConstraint("CK_InternalPurchaseOrder_Currency", "[Currency] COLLATE Latin1_General_100_BIN2 LIKE '[A-Z][A-Z][A-Z]' AND [Currency] <> 'XXX'");
                    table.CheckConstraint("CK_InternalPurchaseOrder_Status", "[Status] IN ('open','partially_received','received','cancelled')");
                    table.CheckConstraint("CK_InternalPurchaseOrder_Total", "[TotalMinor] >= 0 AND [TotalMinor] <= 9000000000000");
                    table.ForeignKey(
                        name: "FK_PurchaseOrders_Locations_LocationId",
                        column: x => x.LocationId,
                        principalSchema: "savia_internal",
                        principalTable: "Locations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PurchaseOrders_Parties_SupplierId",
                        column: x => x.SupplierId,
                        principalSchema: "savia_internal",
                        principalTable: "Parties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Sales",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    LocationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CustomerId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    ActorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Currency = table.Column<string>(type: "nvarchar(3)", maxLength: 3, nullable: false),
                    TotalMinor = table.Column<long>(type: "bigint", nullable: false),
                    State = table.Column<string>(type: "nvarchar(24)", maxLength: 24, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Sales", x => x.Id);
                    table.CheckConstraint("CK_InternalSale_Currency", "LEN([Currency]) = 3 AND [Currency] COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^A-Z]%' AND [Currency] <> 'XXX'");
                    table.CheckConstraint("CK_InternalSale_State", "[State] IN ('recorded','partially_returned','returned','cancelled')");
                    table.CheckConstraint("CK_InternalSale_Total", "[TotalMinor] >= 0 AND [TotalMinor] <= 9000000000000");
                    table.ForeignKey(
                        name: "FK_Sales_Locations_LocationId",
                        column: x => x.LocationId,
                        principalSchema: "savia_internal",
                        principalTable: "Locations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Sales_Parties_CustomerId",
                        column: x => x.CustomerId,
                        principalSchema: "savia_internal",
                        principalTable: "Parties",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Operations",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ActorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Scope = table.Column<string>(type: "varchar(80)", unicode: false, maxLength: 80, nullable: false, collation: "Latin1_General_100_BIN2"),
                    Key = table.Column<string>(type: "varchar(128)", unicode: false, maxLength: 128, nullable: false, collation: "Latin1_General_100_BIN2"),
                    Fingerprint = table.Column<string>(type: "varchar(64)", unicode: false, maxLength: 64, nullable: false, collation: "Latin1_General_100_BIN2"),
                    ResultJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Operations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Operations_Staff_ActorId",
                        column: x => x.ActorId,
                        principalSchema: "savia_internal",
                        principalTable: "Staff",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Sessions",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    StaffId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SecurityVersion = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    ExpiresAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    RevokedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Sessions", x => x.Id);
                    table.CheckConstraint("CK_InternalSession_Expiry", "[ExpiresAt] > [CreatedAt]");
                    table.ForeignKey(
                        name: "FK_Sessions_Staff_StaffId",
                        column: x => x.StaffId,
                        principalSchema: "savia_internal",
                        principalTable: "Staff",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "StockAdjustments",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ItemId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    LocationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    OnHandDelta = table.Column<int>(type: "int", nullable: false),
                    ActorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Reason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StockAdjustments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_StockAdjustments_StockBalances_ItemId_LocationId",
                        columns: x => new { x.ItemId, x.LocationId },
                        principalSchema: "savia_internal",
                        principalTable: "StockBalances",
                        principalColumns: new[] { "ItemId", "LocationId" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "StockMovements",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ItemId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    LocationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ActorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    OperationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Kind = table.Column<string>(type: "nvarchar(40)", maxLength: 40, nullable: false),
                    OnHandDelta = table.Column<int>(type: "int", nullable: false),
                    ReservedDelta = table.Column<int>(type: "int", nullable: false),
                    OnHandAfter = table.Column<int>(type: "int", nullable: false),
                    ReservedAfter = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StockMovements", x => x.Id);
                    table.CheckConstraint("CK_InternalMovement_After", "[OnHandAfter] >= 0 AND [OnHandAfter] <= 1000000000 AND [ReservedAfter] >= 0 AND [ReservedAfter] <= [OnHandAfter]");
                    table.CheckConstraint("CK_InternalMovement_Nonzero", "[OnHandDelta] <> 0 OR [ReservedDelta] <> 0");
                    table.ForeignKey(
                        name: "FK_StockMovements_StockBalances_ItemId_LocationId",
                        columns: x => new { x.ItemId, x.LocationId },
                        principalSchema: "savia_internal",
                        principalTable: "StockBalances",
                        principalColumns: new[] { "ItemId", "LocationId" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "PurchaseOrderLines",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PurchaseOrderId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ItemId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ItemSku = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: false),
                    ItemName = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Quantity = table.Column<int>(type: "int", nullable: false),
                    ReceivedQuantity = table.Column<int>(type: "int", nullable: false),
                    UnitCostMinor = table.Column<long>(type: "bigint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PurchaseOrderLines", x => x.Id);
                    table.UniqueConstraint("AK_PurchaseOrderLines_PurchaseOrderId_Id_ItemId", x => new { x.PurchaseOrderId, x.Id, x.ItemId });
                    table.CheckConstraint("CK_InternalPurchaseLine_Cost", "[UnitCostMinor] >= 0 AND [UnitCostMinor] <= 9000000000000 / [Quantity]");
                    table.CheckConstraint("CK_InternalPurchaseLine_Quantity", "[Quantity] BETWEEN 1 AND 1000000 AND [ReceivedQuantity] BETWEEN 0 AND [Quantity]");
                    table.ForeignKey(
                        name: "FK_PurchaseOrderLines_Items_ItemId",
                        column: x => x.ItemId,
                        principalSchema: "savia_internal",
                        principalTable: "Items",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PurchaseOrderLines_PurchaseOrders_PurchaseOrderId",
                        column: x => x.PurchaseOrderId,
                        principalSchema: "savia_internal",
                        principalTable: "PurchaseOrders",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "PurchaseReceipts",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PurchaseOrderId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    LocationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Currency = table.Column<string>(type: "varchar(3)", unicode: false, maxLength: 3, nullable: false),
                    TotalMinor = table.Column<long>(type: "bigint", nullable: false),
                    Fingerprint = table.Column<string>(type: "varchar(64)", unicode: false, maxLength: 64, nullable: false),
                    OrderStatusAfter = table.Column<string>(type: "varchar(24)", unicode: false, maxLength: 24, nullable: false),
                    ReceivedBy = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ReceivedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PurchaseReceipts", x => x.Id);
                    table.UniqueConstraint("AK_PurchaseReceipts_Id_PurchaseOrderId", x => new { x.Id, x.PurchaseOrderId });
                    table.CheckConstraint("CK_InternalPurchaseReceipt_Currency", "[Currency] COLLATE Latin1_General_100_BIN2 LIKE '[A-Z][A-Z][A-Z]' AND [Currency] <> 'XXX'");
                    table.CheckConstraint("CK_InternalPurchaseReceipt_Status", "[OrderStatusAfter] IN ('partially_received','received')");
                    table.CheckConstraint("CK_InternalPurchaseReceipt_Total", "[TotalMinor] >= 0 AND [TotalMinor] <= 9000000000000");
                    table.ForeignKey(
                        name: "FK_PurchaseReceipts_Locations_LocationId",
                        column: x => x.LocationId,
                        principalSchema: "savia_internal",
                        principalTable: "Locations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PurchaseReceipts_PurchaseOrders_PurchaseOrderId",
                        column: x => x.PurchaseOrderId,
                        principalSchema: "savia_internal",
                        principalTable: "PurchaseOrders",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SaleLines",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SaleId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ItemId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Sku = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: false),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Quantity = table.Column<int>(type: "int", nullable: false),
                    ReturnedQuantity = table.Column<int>(type: "int", nullable: false),
                    UnitPriceMinor = table.Column<long>(type: "bigint", nullable: false),
                    TotalMinor = table.Column<long>(type: "bigint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SaleLines", x => x.Id);
                    table.CheckConstraint("CK_InternalSaleLine_Amounts", "[UnitPriceMinor] >= 0 AND [UnitPriceMinor] <= 9000000000000 AND [TotalMinor] >= 0 AND [TotalMinor] <= 9000000000000 AND CAST([UnitPriceMinor] AS decimal(28,0)) * [Quantity] = [TotalMinor]");
                    table.CheckConstraint("CK_InternalSaleLine_Quantity", "[Quantity] >= 1 AND [Quantity] <= 1000000 AND [ReturnedQuantity] >= 0 AND [ReturnedQuantity] <= [Quantity]");
                    table.ForeignKey(
                        name: "FK_SaleLines_Items_ItemId",
                        column: x => x.ItemId,
                        principalSchema: "savia_internal",
                        principalTable: "Items",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SaleLines_Sales_SaleId",
                        column: x => x.SaleId,
                        principalSchema: "savia_internal",
                        principalTable: "Sales",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SaleReversals",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SaleId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ActorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Kind = table.Column<string>(type: "nvarchar(16)", maxLength: 16, nullable: false),
                    Reason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    RecordedCreditMinor = table.Column<long>(type: "bigint", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SaleReversals", x => x.Id);
                    table.CheckConstraint("CK_InternalReversal_Amount", "[RecordedCreditMinor] >= 0 AND [RecordedCreditMinor] <= 9000000000000");
                    table.CheckConstraint("CK_InternalReversal_Kind", "[Kind] IN ('cancel','return')");
                    table.ForeignKey(
                        name: "FK_SaleReversals_Sales_SaleId",
                        column: x => x.SaleId,
                        principalSchema: "savia_internal",
                        principalTable: "Sales",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "PurchaseReceiptLines",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ReceiptId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PurchaseOrderId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    PurchaseOrderLineId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ItemId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Quantity = table.Column<int>(type: "int", nullable: false),
                    UnitCostMinor = table.Column<long>(type: "bigint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PurchaseReceiptLines", x => x.Id);
                    table.CheckConstraint("CK_InternalReceiptLine_Cost", "[UnitCostMinor] >= 0 AND [UnitCostMinor] <= 9000000000000 / [Quantity]");
                    table.CheckConstraint("CK_InternalReceiptLine_Quantity", "[Quantity] BETWEEN 1 AND 1000000");
                    table.ForeignKey(
                        name: "FK_PurchaseReceiptLines_Items_ItemId",
                        column: x => x.ItemId,
                        principalSchema: "savia_internal",
                        principalTable: "Items",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PurchaseReceiptLines_PurchaseOrderLines_PurchaseOrderId_PurchaseOrderLineId_ItemId",
                        columns: x => new { x.PurchaseOrderId, x.PurchaseOrderLineId, x.ItemId },
                        principalSchema: "savia_internal",
                        principalTable: "PurchaseOrderLines",
                        principalColumns: new[] { "PurchaseOrderId", "Id", "ItemId" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PurchaseReceiptLines_PurchaseReceipts_ReceiptId_PurchaseOrderId",
                        columns: x => new { x.ReceiptId, x.PurchaseOrderId },
                        principalSchema: "savia_internal",
                        principalTable: "PurchaseReceipts",
                        principalColumns: new[] { "Id", "PurchaseOrderId" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SaleReversalLines",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ReversalId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SaleLineId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Quantity = table.Column<int>(type: "int", nullable: false),
                    RecordedCreditMinor = table.Column<long>(type: "bigint", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SaleReversalLines", x => x.Id);
                    table.CheckConstraint("CK_InternalReversalLine_Bounds", "[Quantity] >= 1 AND [Quantity] <= 1000000 AND [RecordedCreditMinor] >= 0 AND [RecordedCreditMinor] <= 9000000000000");
                    table.ForeignKey(
                        name: "FK_SaleReversalLines_SaleLines_SaleLineId",
                        column: x => x.SaleLineId,
                        principalSchema: "savia_internal",
                        principalTable: "SaleLines",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SaleReversalLines_SaleReversals_ReversalId",
                        column: x => x.ReversalId,
                        principalSchema: "savia_internal",
                        principalTable: "SaleReversals",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Items_Active_Name",
                schema: "savia_internal",
                table: "Items",
                columns: new[] { "Active", "Name" });

            migrationBuilder.CreateIndex(
                name: "IX_Items_Sku",
                schema: "savia_internal",
                table: "Items",
                column: "Sku",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Locations_Active_Name",
                schema: "savia_internal",
                table: "Locations",
                columns: new[] { "Active", "Name" });

            migrationBuilder.CreateIndex(
                name: "IX_Operations_ActorId_Scope_Key",
                schema: "savia_internal",
                table: "Operations",
                columns: new[] { "ActorId", "Scope", "Key" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Parties_Kind_Active_Name",
                schema: "savia_internal",
                table: "Parties",
                columns: new[] { "Kind", "Active", "Name" });

            migrationBuilder.CreateIndex(
                name: "IX_PurchaseOrderLines_ItemId",
                schema: "savia_internal",
                table: "PurchaseOrderLines",
                column: "ItemId");

            migrationBuilder.CreateIndex(
                name: "IX_PurchaseOrderLines_PurchaseOrderId_ItemId",
                schema: "savia_internal",
                table: "PurchaseOrderLines",
                columns: new[] { "PurchaseOrderId", "ItemId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PurchaseOrders_CreatedAt_Id",
                schema: "savia_internal",
                table: "PurchaseOrders",
                columns: new[] { "CreatedAt", "Id" });

            migrationBuilder.CreateIndex(
                name: "IX_PurchaseOrders_LocationId",
                schema: "savia_internal",
                table: "PurchaseOrders",
                column: "LocationId");

            migrationBuilder.CreateIndex(
                name: "IX_PurchaseOrders_SupplierId",
                schema: "savia_internal",
                table: "PurchaseOrders",
                column: "SupplierId");

            migrationBuilder.CreateIndex(
                name: "IX_PurchaseReceiptLines_ItemId",
                schema: "savia_internal",
                table: "PurchaseReceiptLines",
                column: "ItemId");

            migrationBuilder.CreateIndex(
                name: "IX_PurchaseReceiptLines_PurchaseOrderId_PurchaseOrderLineId_ItemId",
                schema: "savia_internal",
                table: "PurchaseReceiptLines",
                columns: new[] { "PurchaseOrderId", "PurchaseOrderLineId", "ItemId" });

            migrationBuilder.CreateIndex(
                name: "IX_PurchaseReceiptLines_ReceiptId_PurchaseOrderId",
                schema: "savia_internal",
                table: "PurchaseReceiptLines",
                columns: new[] { "ReceiptId", "PurchaseOrderId" });

            migrationBuilder.CreateIndex(
                name: "IX_PurchaseReceiptLines_ReceiptId_PurchaseOrderLineId",
                schema: "savia_internal",
                table: "PurchaseReceiptLines",
                columns: new[] { "ReceiptId", "PurchaseOrderLineId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PurchaseReceipts_LocationId",
                schema: "savia_internal",
                table: "PurchaseReceipts",
                column: "LocationId");

            migrationBuilder.CreateIndex(
                name: "IX_PurchaseReceipts_PurchaseOrderId_ReceivedAt",
                schema: "savia_internal",
                table: "PurchaseReceipts",
                columns: new[] { "PurchaseOrderId", "ReceivedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_SaleLines_ItemId",
                schema: "savia_internal",
                table: "SaleLines",
                column: "ItemId");

            migrationBuilder.CreateIndex(
                name: "IX_SaleLines_SaleId_ItemId",
                schema: "savia_internal",
                table: "SaleLines",
                columns: new[] { "SaleId", "ItemId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SaleReversalLines_ReversalId_SaleLineId",
                schema: "savia_internal",
                table: "SaleReversalLines",
                columns: new[] { "ReversalId", "SaleLineId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SaleReversalLines_SaleLineId",
                schema: "savia_internal",
                table: "SaleReversalLines",
                column: "SaleLineId");

            migrationBuilder.CreateIndex(
                name: "IX_SaleReversals_SaleId",
                schema: "savia_internal",
                table: "SaleReversals",
                column: "SaleId");

            migrationBuilder.CreateIndex(
                name: "IX_Sales_CreatedAt",
                schema: "savia_internal",
                table: "Sales",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_Sales_CustomerId",
                schema: "savia_internal",
                table: "Sales",
                column: "CustomerId");

            migrationBuilder.CreateIndex(
                name: "IX_Sales_LocationId",
                schema: "savia_internal",
                table: "Sales",
                column: "LocationId");

            migrationBuilder.CreateIndex(
                name: "IX_Sessions_StaffId_ExpiresAt",
                schema: "savia_internal",
                table: "Sessions",
                columns: new[] { "StaffId", "ExpiresAt" });

            migrationBuilder.CreateIndex(
                name: "IX_Staff_NormalizedLoginName",
                schema: "savia_internal",
                table: "Staff",
                column: "NormalizedLoginName",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_StockAdjustments_ItemId_LocationId",
                schema: "savia_internal",
                table: "StockAdjustments",
                columns: new[] { "ItemId", "LocationId" });

            migrationBuilder.CreateIndex(
                name: "IX_StockBalances_LocationId",
                schema: "savia_internal",
                table: "StockBalances",
                column: "LocationId");

            migrationBuilder.CreateIndex(
                name: "IX_StockMovements_ItemId_LocationId_CreatedAt",
                schema: "savia_internal",
                table: "StockMovements",
                columns: new[] { "ItemId", "LocationId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_StockMovements_OperationId",
                schema: "savia_internal",
                table: "StockMovements",
                column: "OperationId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Operations",
                schema: "savia_internal");

            migrationBuilder.DropTable(
                name: "PurchaseReceiptLines",
                schema: "savia_internal");

            migrationBuilder.DropTable(
                name: "SaleReversalLines",
                schema: "savia_internal");

            migrationBuilder.DropTable(
                name: "Sessions",
                schema: "savia_internal");

            migrationBuilder.DropTable(
                name: "StockAdjustments",
                schema: "savia_internal");

            migrationBuilder.DropTable(
                name: "StockMovements",
                schema: "savia_internal");

            migrationBuilder.DropTable(
                name: "PurchaseOrderLines",
                schema: "savia_internal");

            migrationBuilder.DropTable(
                name: "PurchaseReceipts",
                schema: "savia_internal");

            migrationBuilder.DropTable(
                name: "SaleLines",
                schema: "savia_internal");

            migrationBuilder.DropTable(
                name: "SaleReversals",
                schema: "savia_internal");

            migrationBuilder.DropTable(
                name: "Staff",
                schema: "savia_internal");

            migrationBuilder.DropTable(
                name: "StockBalances",
                schema: "savia_internal");

            migrationBuilder.DropTable(
                name: "PurchaseOrders",
                schema: "savia_internal");

            migrationBuilder.DropTable(
                name: "Sales",
                schema: "savia_internal");

            migrationBuilder.DropTable(
                name: "Items",
                schema: "savia_internal");

            migrationBuilder.DropTable(
                name: "Locations",
                schema: "savia_internal");

            migrationBuilder.DropTable(
                name: "Parties",
                schema: "savia_internal");
        }
    }
}
