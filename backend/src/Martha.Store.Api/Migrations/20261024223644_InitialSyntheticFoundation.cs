using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Martha.Store.Api.Migrations
{
    /// <inheritdoc />
    public partial class InitialSyntheticFoundation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Products",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Products", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Variants",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ProductId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Sku = table.Column<string>(type: "nvarchar(80)", maxLength: 80, nullable: false),
                    UnitPriceMinor = table.Column<long>(type: "bigint", nullable: false),
                    Currency = table.Column<string>(type: "varchar(3)", unicode: false, maxLength: 3, nullable: false),
                    AvailableQuantity = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Variants", x => x.Id);
                    table.CheckConstraint("CK_Variants_Currency", "[Currency] = 'XXX'");
                    table.CheckConstraint("CK_Variants_Price", "[UnitPriceMinor] >= 0 AND [UnitPriceMinor] <= 9000000000000");
                    table.CheckConstraint("CK_Variants_Stock", "[AvailableQuantity] >= 0");
                    table.ForeignKey(
                        name: "FK_Variants_Products_ProductId",
                        column: x => x.ProductId,
                        principalTable: "Products",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "SyntheticOrders",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Actor = table.Column<string>(type: "varchar(40)", unicode: false, maxLength: 40, nullable: false),
                    IdempotencyKey = table.Column<string>(type: "varchar(128)", unicode: false, maxLength: 128, nullable: false, collation: "Latin1_General_100_BIN2"),
                    VariantId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Quantity = table.Column<int>(type: "int", nullable: false),
                    UnitPriceMinor = table.Column<long>(type: "bigint", nullable: false),
                    TotalMinor = table.Column<long>(type: "bigint", nullable: false),
                    Currency = table.Column<string>(type: "varchar(3)", unicode: false, maxLength: 3, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SyntheticOrders", x => x.Id);
                    table.CheckConstraint("CK_SyntheticOrders_Actor", "[Actor] = 'synthetic-test' AND [Currency] = 'XXX'");
                    table.CheckConstraint("CK_SyntheticOrders_Quantity", "[Quantity] >= 1 AND [Quantity] <= 100");
                    table.CheckConstraint("CK_SyntheticOrders_Total", "[UnitPriceMinor] >= 0 AND [UnitPriceMinor] <= 9000000000000 AND [TotalMinor] = [UnitPriceMinor] * [Quantity]");
                    table.ForeignKey(
                        name: "FK_SyntheticOrders_Variants_VariantId",
                        column: x => x.VariantId,
                        principalTable: "Variants",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_SyntheticOrders_Actor_IdempotencyKey",
                table: "SyntheticOrders",
                columns: new[] { "Actor", "IdempotencyKey" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SyntheticOrders_VariantId",
                table: "SyntheticOrders",
                column: "VariantId");

            migrationBuilder.CreateIndex(
                name: "IX_Variants_ProductId",
                table: "Variants",
                column: "ProductId");

            migrationBuilder.CreateIndex(
                name: "IX_Variants_Sku",
                table: "Variants",
                column: "Sku",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "SyntheticOrders");

            migrationBuilder.DropTable(
                name: "Variants");

            migrationBuilder.DropTable(
                name: "Products");
        }
    }
}
