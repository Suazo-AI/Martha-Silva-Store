using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Martha.Store.Api.Internal.Migrations
{
    /// <inheritdoc />
    public partial class FirstCashRegister : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "CashTills",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CashierId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    LocationId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Currency = table.Column<string>(type: "varchar(3)", unicode: false, maxLength: 3, nullable: false, collation: "Latin1_General_100_BIN2"),
                    Exponent = table.Column<int>(type: "int", nullable: false),
                    OpenedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    ClosedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CashTills", x => x.Id);
                    table.UniqueConstraint("AK_CashTills_Id_CashierId_Currency_Exponent", x => new { x.Id, x.CashierId, x.Currency, x.Exponent });
                    table.CheckConstraint("CK_CashTill_Currency", "LEN([Currency])=3 AND [Currency] COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^A-Z]%' AND [Exponent] BETWEEN 0 AND 6");
                    table.CheckConstraint("CK_CashTill_Time", "[ClosedAt] IS NULL OR [ClosedAt]>=[OpenedAt]");
                    table.ForeignKey(
                        name: "FK_CashTills_Locations_LocationId",
                        column: x => x.LocationId,
                        principalSchema: "savia_internal",
                        principalTable: "Locations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CashTills_Staff_CashierId",
                        column: x => x.CashierId,
                        principalSchema: "savia_internal",
                        principalTable: "Staff",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "CashCloses",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TillId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ActorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ExpectedMinor = table.Column<long>(type: "bigint", nullable: false),
                    CountedMinor = table.Column<long>(type: "bigint", nullable: false),
                    DifferenceMinor = table.Column<long>(type: "bigint", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CashCloses", x => x.Id);
                    table.CheckConstraint("CK_CashClose_Amounts", "[ExpectedMinor] BETWEEN 0 AND 9000000000000 AND [CountedMinor] BETWEEN 0 AND 9000000000000 AND [DifferenceMinor]=[CountedMinor]-[ExpectedMinor]");
                    table.ForeignKey(
                        name: "FK_CashCloses_CashTills_TillId",
                        column: x => x.TillId,
                        principalSchema: "savia_internal",
                        principalTable: "CashTills",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CashCloses_Staff_ActorId",
                        column: x => x.ActorId,
                        principalSchema: "savia_internal",
                        principalTable: "Staff",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "CashEntries",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    TillId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    CashierId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ActorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Currency = table.Column<string>(type: "varchar(3)", unicode: false, maxLength: 3, nullable: false, collation: "Latin1_General_100_BIN2"),
                    Exponent = table.Column<int>(type: "int", nullable: false),
                    Kind = table.Column<string>(type: "varchar(16)", unicode: false, maxLength: 16, nullable: false),
                    DeltaMinor = table.Column<long>(type: "bigint", nullable: false),
                    ReceivedMinor = table.Column<long>(type: "bigint", nullable: false),
                    ChangeMinor = table.Column<long>(type: "bigint", nullable: false),
                    SaleId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    ReversalId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CashEntries", x => x.Id);
                    table.CheckConstraint("CK_CashEntry_Bounds", "[DeltaMinor] BETWEEN -9000000000000 AND 9000000000000 AND [ReceivedMinor] BETWEEN 0 AND 9000000000000 AND [ChangeMinor] BETWEEN 0 AND 9000000000000");
                    table.CheckConstraint("CK_CashEntry_Kind", "([Kind]='opening' AND [DeltaMinor]>=0 AND [ReceivedMinor]=0 AND [ChangeMinor]=0 AND [SaleId] IS NULL AND [ReversalId] IS NULL) OR ([Kind]='sale' AND [DeltaMinor]>=0 AND [ReceivedMinor]-[ChangeMinor]=[DeltaMinor] AND [SaleId] IS NOT NULL AND [ReversalId] IS NULL) OR ([Kind]='refund' AND [DeltaMinor]<0 AND [ReceivedMinor]=0 AND [ChangeMinor]=0 AND [SaleId] IS NOT NULL AND [ReversalId] IS NOT NULL)");
                    table.ForeignKey(
                        name: "FK_CashEntries_CashTills_TillId_CashierId_Currency_Exponent",
                        columns: x => new { x.TillId, x.CashierId, x.Currency, x.Exponent },
                        principalSchema: "savia_internal",
                        principalTable: "CashTills",
                        principalColumns: new[] { "Id", "CashierId", "Currency", "Exponent" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CashEntries_SaleReversals_ReversalId",
                        column: x => x.ReversalId,
                        principalSchema: "savia_internal",
                        principalTable: "SaleReversals",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CashEntries_Sales_SaleId",
                        column: x => x.SaleId,
                        principalSchema: "savia_internal",
                        principalTable: "Sales",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CashEntries_Staff_ActorId",
                        column: x => x.ActorId,
                        principalSchema: "savia_internal",
                        principalTable: "Staff",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CashCloses_ActorId",
                schema: "savia_internal",
                table: "CashCloses",
                column: "ActorId");

            migrationBuilder.CreateIndex(
                name: "IX_CashCloses_TillId",
                schema: "savia_internal",
                table: "CashCloses",
                column: "TillId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_CashEntries_ActorId",
                schema: "savia_internal",
                table: "CashEntries",
                column: "ActorId");

            migrationBuilder.CreateIndex(
                name: "IX_CashEntries_ReversalId",
                schema: "savia_internal",
                table: "CashEntries",
                column: "ReversalId",
                unique: true,
                filter: "[ReversalId] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_CashEntries_SaleId",
                schema: "savia_internal",
                table: "CashEntries",
                column: "SaleId",
                unique: true,
                filter: "[Kind]='sale'");

            migrationBuilder.CreateIndex(
                name: "IX_CashEntries_TillId",
                schema: "savia_internal",
                table: "CashEntries",
                column: "TillId",
                unique: true,
                filter: "[Kind]='opening'");

            migrationBuilder.CreateIndex(
                name: "IX_CashEntries_TillId_CashierId_Currency_Exponent",
                schema: "savia_internal",
                table: "CashEntries",
                columns: new[] { "TillId", "CashierId", "Currency", "Exponent" });

            migrationBuilder.CreateIndex(
                name: "IX_CashTills_CashierId",
                schema: "savia_internal",
                table: "CashTills",
                column: "CashierId",
                unique: true,
                filter: "[ClosedAt] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_CashTills_LocationId",
                schema: "savia_internal",
                table: "CashTills",
                column: "LocationId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CashCloses",
                schema: "savia_internal");

            migrationBuilder.DropTable(
                name: "CashEntries",
                schema: "savia_internal");

            migrationBuilder.DropTable(
                name: "CashTills",
                schema: "savia_internal");
        }
    }
}
