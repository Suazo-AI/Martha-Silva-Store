using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Martha.Store.Api.Internal.Migrations
{
    /// <inheritdoc />
    public partial class PhysicalStockException : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ExceptionReason",
                schema: "savia_internal",
                table: "SaleLines",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Size",
                schema: "savia_internal",
                table: "SaleLines",
                type: "nvarchar(80)",
                maxLength: 80,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "StockExceptionReviews",
                schema: "savia_internal",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    SaleLineId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    ReviewerId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    Evidence = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    Outcome = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false),
                    ResponsibleActorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
                    NextReviewAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false),
                    CauseState = table.Column<string>(type: "nvarchar(16)", maxLength: 16, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StockExceptionReviews", x => x.Id);
                    table.CheckConstraint("CK_InternalStockReview_Next", "[NextReviewAt] > [CreatedAt]");
                    table.CheckConstraint("CK_InternalStockReview_Open", "[CauseState] = 'open'");
                    table.ForeignKey(
                        name: "FK_StockExceptionReviews_SaleLines_SaleLineId",
                        column: x => x.SaleLineId,
                        principalSchema: "savia_internal",
                        principalTable: "SaleLines",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_StockExceptionReviews_Staff_ResponsibleActorId",
                        column: x => x.ResponsibleActorId,
                        principalSchema: "savia_internal",
                        principalTable: "Staff",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_StockExceptionReviews_Staff_ReviewerId",
                        column: x => x.ReviewerId,
                        principalSchema: "savia_internal",
                        principalTable: "Staff",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.AddCheckConstraint(
                name: "CK_InternalSaleLine_Exception",
                schema: "savia_internal",
                table: "SaleLines",
                sql: "([ExceptionReason] IS NULL AND [Size] IS NULL) OR ([ExceptionReason] IS NOT NULL AND [Size] IS NOT NULL AND LEN(LTRIM(RTRIM([ExceptionReason]))) > 0 AND LEN(LTRIM(RTRIM([Size]))) > 0)");

            migrationBuilder.CreateIndex(
                name: "IX_StockExceptionReviews_ResponsibleActorId",
                schema: "savia_internal",
                table: "StockExceptionReviews",
                column: "ResponsibleActorId");

            migrationBuilder.CreateIndex(
                name: "IX_StockExceptionReviews_ReviewerId",
                schema: "savia_internal",
                table: "StockExceptionReviews",
                column: "ReviewerId");

            migrationBuilder.CreateIndex(
                name: "IX_StockExceptionReviews_SaleLineId",
                schema: "savia_internal",
                table: "StockExceptionReviews",
                column: "SaleLineId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "StockExceptionReviews",
                schema: "savia_internal");

            migrationBuilder.DropCheckConstraint(
                name: "CK_InternalSaleLine_Exception",
                schema: "savia_internal",
                table: "SaleLines");

            migrationBuilder.DropColumn(
                name: "ExceptionReason",
                schema: "savia_internal",
                table: "SaleLines");

            migrationBuilder.DropColumn(
                name: "Size",
                schema: "savia_internal",
                table: "SaleLines");
        }
    }
}
