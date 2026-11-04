using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Martha.Store.Api.Migrations;

// New V2 tables only; existing V1 stock and orders remain independently retained.
public partial class SaviaV2Ledger : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(
            name: "SaviaBalances",
            columns: table => new
            {
                VariantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                LocationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                Mode = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: false, collation: "Latin1_General_100_BIN2"),
                InstanceId = table.Column<string>(type: "varchar(80)", unicode: false, maxLength: 80, nullable: false, collation: "Latin1_General_100_BIN2"),
                Epoch = table.Column<int>(type: "int", nullable: false),
                Sku = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: false),
                Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                UnitPriceMinor = table.Column<long>(type: "bigint", nullable: false),
                Currency = table.Column<string>(type: "varchar(3)", unicode: false, maxLength: 3, nullable: false, collation: "Latin1_General_100_BIN2"),
                OnHand = table.Column<int>(type: "int", nullable: false),
                Reserved = table.Column<int>(type: "int", nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_SaviaBalances", x => new { x.VariantId, x.LocationId });
                table.CheckConstraint("CK_SaviaBalances_Stock", "[OnHand] >= [Reserved] AND [Reserved] >= 0");
                table.CheckConstraint("CK_SaviaBalances_Price", "[UnitPriceMinor] >= 0 AND [UnitPriceMinor] <= 9000000000000 AND [Currency] = 'XXX'");
                table.CheckConstraint("CK_SaviaBalances_Authority", "[Mode] = 'savia' AND [InstanceId] = 'savia-synthetic-v2' AND [Epoch] = 1");
            });
        migrationBuilder.CreateIndex(name: "IX_SaviaBalances_Sku", table: "SaviaBalances", columns: new[] { "Sku" }, unique: true);
        migrationBuilder.CreateTable(
            name: "SaviaAttempts",
            columns: table => new
            {
                AttemptId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                Operation = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: false, collation: "Latin1_General_100_BIN2"),
                IdempotencyKey = table.Column<string>(type: "varchar(128)", unicode: false, maxLength: 128, nullable: false, collation: "Latin1_General_100_BIN2"),
                CanonicalPayload = table.Column<string>(type: "nvarchar(2000)", maxLength: 2000, nullable: false, collation: "Latin1_General_100_BIN2"),
                Mode = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: false, collation: "Latin1_General_100_BIN2"),
                InstanceId = table.Column<string>(type: "varchar(80)", unicode: false, maxLength: 80, nullable: false, collation: "Latin1_General_100_BIN2"),
                Epoch = table.Column<int>(type: "int", nullable: false),
                Outcome = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: false, collation: "Latin1_General_100_BIN2"),
                ResultJson = table.Column<string>(type: "nvarchar(max)", nullable: true),
                Error = table.Column<string>(type: "varchar(64)", unicode: false, maxLength: 64, nullable: true),
                CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_SaviaAttempts", x => x.AttemptId);
                table.CheckConstraint("CK_SaviaAttempts_Authority", "[Mode] = 'savia' AND [InstanceId] = 'savia-synthetic-v2' AND [Epoch] = 1");
                table.CheckConstraint("CK_SaviaAttempts_Operation", "[Operation] IN ('reserve','cancel')");
                table.CheckConstraint("CK_SaviaAttempts_Result", "([Outcome] = 'succeeded' AND [ResultJson] IS NOT NULL AND ISJSON([ResultJson]) = 1 AND [Error] IS NULL) OR ([Outcome] = 'rejected' AND [ResultJson] IS NULL AND [Error] IS NOT NULL)");
            });
        migrationBuilder.CreateIndex(name: "IX_SaviaAttempts_Operation_IdempotencyKey", table: "SaviaAttempts", columns: new[] { "Operation", "IdempotencyKey" }, unique: true);
        migrationBuilder.CreateTable(
            name: "SaviaReservations",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                VariantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                LocationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                Quantity = table.Column<int>(type: "int", nullable: false),
                UnitPriceMinor = table.Column<long>(type: "bigint", nullable: false),
                TotalMinor = table.Column<long>(type: "bigint", nullable: false),
                Currency = table.Column<string>(type: "varchar(3)", unicode: false, maxLength: 3, nullable: false, collation: "Latin1_General_100_BIN2"),
                State = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: false, collation: "Latin1_General_100_BIN2"),
                CreateAttemptId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                CancelledAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true),
                CreationJson = table.Column<string>(type: "nvarchar(max)", nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_SaviaReservations", x => x.Id);
                table.CheckConstraint("CK_SaviaReservations_Quantity", "[Quantity] >= 1 AND [Quantity] <= 100");
                table.CheckConstraint("CK_SaviaReservations_Price", "[UnitPriceMinor] >= 0 AND [UnitPriceMinor] <= 9000000000000 AND [TotalMinor] = [UnitPriceMinor] * [Quantity] AND [Currency] = 'XXX'");
                table.CheckConstraint("CK_SaviaReservations_State", "([State] = 'active' AND [CancelledAt] IS NULL) OR ([State] = 'cancelled' AND [CancelledAt] IS NOT NULL)");
                table.CheckConstraint("CK_SaviaReservations_Receipt", "ISJSON([CreationJson]) = 1");
                table.ForeignKey(name: "FK_SaviaReservations_SaviaBalances_VariantId_LocationId", columns: x => new { x.VariantId, x.LocationId }, principalTable: "SaviaBalances", principalColumns: new[] { "VariantId", "LocationId" }, onDelete: ReferentialAction.Restrict);
                table.ForeignKey(name: "FK_SaviaReservations_SaviaAttempts_CreateAttemptId", columns: x => x.CreateAttemptId, principalTable: "SaviaAttempts", principalColumns: new[] { "AttemptId" }, onDelete: ReferentialAction.Restrict);
            });
        migrationBuilder.CreateIndex(name: "IX_SaviaReservations_CreateAttemptId", table: "SaviaReservations", columns: new[] { "CreateAttemptId" }, unique: true);
        migrationBuilder.CreateIndex(name: "IX_SaviaReservations_VariantId_LocationId", table: "SaviaReservations", columns: new[] { "VariantId", "LocationId" });
        migrationBuilder.CreateTable(
            name: "SaviaMovements",
            columns: table => new
            {
                Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                ReservationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                AttemptId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                VariantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                LocationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                Kind = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: false, collation: "Latin1_General_100_BIN2"),
                OnHandDelta = table.Column<int>(type: "int", nullable: false),
                ReservedDelta = table.Column<int>(type: "int", nullable: false),
                Mode = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: false, collation: "Latin1_General_100_BIN2"),
                InstanceId = table.Column<string>(type: "varchar(80)", unicode: false, maxLength: 80, nullable: false, collation: "Latin1_General_100_BIN2"),
                Epoch = table.Column<int>(type: "int", nullable: false),
                CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
            },
            constraints: table =>
            {
                table.PrimaryKey("PK_SaviaMovements", x => x.Id);
                table.CheckConstraint("CK_SaviaMovements_Authority", "[Mode] = 'savia' AND [InstanceId] = 'savia-synthetic-v2' AND [Epoch] = 1");
                table.CheckConstraint("CK_SaviaMovements_Delta", "[OnHandDelta] = 0 AND (([Kind] = 'reserve' AND [ReservedDelta] BETWEEN 1 AND 100) OR ([Kind] = 'cancel' AND [ReservedDelta] BETWEEN -100 AND -1))");
                table.ForeignKey(name: "FK_SaviaMovements_SaviaReservations_ReservationId", columns: x => x.ReservationId, principalTable: "SaviaReservations", principalColumns: new[] { "Id" }, onDelete: ReferentialAction.Restrict);
                table.ForeignKey(name: "FK_SaviaMovements_SaviaAttempts_AttemptId", columns: x => x.AttemptId, principalTable: "SaviaAttempts", principalColumns: new[] { "AttemptId" }, onDelete: ReferentialAction.Restrict);
                table.ForeignKey(name: "FK_SaviaMovements_SaviaBalances_VariantId_LocationId", columns: x => new { x.VariantId, x.LocationId }, principalTable: "SaviaBalances", principalColumns: new[] { "VariantId", "LocationId" }, onDelete: ReferentialAction.Restrict);
            });
        migrationBuilder.CreateIndex(name: "IX_SaviaMovements_AttemptId", table: "SaviaMovements", columns: new[] { "AttemptId" }, unique: true);
        migrationBuilder.CreateIndex(name: "IX_SaviaMovements_ReservationId", table: "SaviaMovements", columns: new[] { "ReservationId" });
        migrationBuilder.CreateIndex(name: "IX_SaviaMovements_VariantId_LocationId", table: "SaviaMovements", columns: new[] { "VariantId", "LocationId" });
        migrationBuilder.Sql("""
            CREATE TRIGGER [TR_SaviaAttempts_AppendOnly] ON [SaviaAttempts] AFTER UPDATE, DELETE AS
            BEGIN
                SET NOCOUNT ON;
                THROW 51001, 'SAVIA V2 ledger is append-only.', 1;
            END
            """);
        migrationBuilder.Sql("""
            CREATE TRIGGER [TR_SaviaMovements_AppendOnly] ON [SaviaMovements] AFTER UPDATE, DELETE AS
            BEGIN
                SET NOCOUNT ON;
                THROW 51002, 'SAVIA V2 ledger is append-only.', 1;
            END
            """);
        migrationBuilder.Sql("""
            CREATE TRIGGER [TR_SaviaReservations_ImmutableCreation] ON [SaviaReservations] AFTER UPDATE, DELETE AS
            BEGIN
                SET NOCOUNT ON;
                IF EXISTS (SELECT 1 FROM deleted d LEFT JOIN inserted i ON i.Id = d.Id WHERE i.Id IS NULL)
                    THROW 51003, 'SAVIA V2 reservation creation is immutable.', 1;
                IF EXISTS (
                    SELECT [Id], [VariantId], [LocationId], [Quantity], [UnitPriceMinor], [TotalMinor], CONVERT(varbinary(max), [Currency]), [CreateAttemptId], [CreatedAt], CONVERT(varbinary(max), [CreationJson]) FROM inserted
                    EXCEPT
                    SELECT [Id], [VariantId], [LocationId], [Quantity], [UnitPriceMinor], [TotalMinor], CONVERT(varbinary(max), [Currency]), [CreateAttemptId], [CreatedAt], CONVERT(varbinary(max), [CreationJson]) FROM deleted
                )
                    THROW 51003, 'SAVIA V2 reservation creation is immutable.', 1;
                IF EXISTS (
                    SELECT 1 FROM inserted i JOIN deleted d ON i.Id = d.Id
                    WHERE NOT (
                        (d.State = 'active' AND d.CancelledAt IS NULL AND i.State = 'cancelled' AND i.CancelledAt IS NOT NULL)
                        OR (d.State = i.State AND (d.CancelledAt = i.CancelledAt OR (d.CancelledAt IS NULL AND i.CancelledAt IS NULL)))
                    )
                )
                    THROW 51003, 'SAVIA V2 permits only the original cancellation transition.', 1;
            END
            """);
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "SaviaMovements");
        migrationBuilder.DropTable(name: "SaviaReservations");
        migrationBuilder.DropTable(name: "SaviaAttempts");
        migrationBuilder.DropTable(name: "SaviaBalances");
    }
}
