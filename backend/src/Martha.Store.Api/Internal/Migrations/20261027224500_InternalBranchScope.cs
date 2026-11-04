using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable
namespace Martha.Store.Api.Internal.Migrations;

// Additive candidate only: no production assignments, seeds, or inferred backfill.
public partial class InternalBranchScope : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.CreateTable(name: "Branches", schema: "savia_internal", columns: table => new
        {
            Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
            Name = table.Column<string>(type: "nvarchar(120)", maxLength: 120, nullable: false),
            Active = table.Column<bool>(type: "bit", nullable: false)
        }, constraints: table => table.PrimaryKey("PK_Branches", x => x.Id));
        migrationBuilder.AddColumn<Guid>(name: "BranchId", schema: "savia_internal", table: "Staff", type: "uniqueidentifier", nullable: true);
        migrationBuilder.AddColumn<Guid>(name: "BranchId", schema: "savia_internal", table: "Locations", type: "uniqueidentifier", nullable: true);
        migrationBuilder.AddColumn<Guid>(name: "LocationId", schema: "savia_internal", table: "Operations", type: "uniqueidentifier", nullable: true);
        migrationBuilder.AddColumn<Guid>(name: "OriginalBranchId", schema: "savia_internal", table: "Operations", type: "uniqueidentifier", nullable: true);
        migrationBuilder.CreateIndex(name: "IX_Staff_BranchId", schema: "savia_internal", table: "Staff", column: "BranchId");
        migrationBuilder.CreateIndex(name: "IX_Locations_BranchId", schema: "savia_internal", table: "Locations", column: "BranchId");
        migrationBuilder.CreateIndex(name: "IX_Operations_OriginalBranchId", schema: "savia_internal", table: "Operations", column: "OriginalBranchId");
        migrationBuilder.AddForeignKey(name: "FK_Staff_Branches_BranchId", schema: "savia_internal", table: "Staff", column: "BranchId", principalSchema: "savia_internal", principalTable: "Branches", principalColumn: "Id", onDelete: ReferentialAction.Restrict);
        migrationBuilder.AddForeignKey(name: "FK_Locations_Branches_BranchId", schema: "savia_internal", table: "Locations", column: "BranchId", principalSchema: "savia_internal", principalTable: "Branches", principalColumn: "Id", onDelete: ReferentialAction.Restrict);
        migrationBuilder.CreateTable(name: "BranchAssignmentAudit", schema: "savia_internal", columns: table => new
        {
            Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
            ActorId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
            StaffId = table.Column<Guid>(type: "uniqueidentifier", nullable: false),
            PreviousBranchId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
            BranchId = table.Column<Guid>(type: "uniqueidentifier", nullable: true),
            CreatedAt = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false)
        }, constraints: table =>
        {
            table.PrimaryKey("PK_BranchAssignmentAudit", x => x.Id);
            table.ForeignKey(name: "FK_BranchAssignmentAudit_Staff_ActorId", column: x => x.ActorId, principalSchema: "savia_internal", principalTable: "Staff", principalColumn: "Id", onDelete: ReferentialAction.Restrict);
            table.ForeignKey(name: "FK_BranchAssignmentAudit_Staff_StaffId", column: x => x.StaffId, principalSchema: "savia_internal", principalTable: "Staff", principalColumn: "Id", onDelete: ReferentialAction.Restrict);
        });
        migrationBuilder.CreateIndex(name: "IX_BranchAssignmentAudit_ActorId", schema: "savia_internal", table: "BranchAssignmentAudit", column: "ActorId");
        migrationBuilder.CreateIndex(name: "IX_BranchAssignmentAudit_StaffId", schema: "savia_internal", table: "BranchAssignmentAudit", column: "StaffId");
    }
    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropTable(name: "BranchAssignmentAudit", schema: "savia_internal");
        migrationBuilder.DropForeignKey(name: "FK_Staff_Branches_BranchId", schema: "savia_internal", table: "Staff");
        migrationBuilder.DropForeignKey(name: "FK_Locations_Branches_BranchId", schema: "savia_internal", table: "Locations");
        migrationBuilder.DropIndex(name: "IX_Staff_BranchId", schema: "savia_internal", table: "Staff");
        migrationBuilder.DropIndex(name: "IX_Locations_BranchId", schema: "savia_internal", table: "Locations");
        migrationBuilder.DropIndex(name: "IX_Operations_OriginalBranchId", schema: "savia_internal", table: "Operations");
        migrationBuilder.DropColumn(name: "BranchId", schema: "savia_internal", table: "Staff");
        migrationBuilder.DropColumn(name: "BranchId", schema: "savia_internal", table: "Locations");
        migrationBuilder.DropColumn(name: "LocationId", schema: "savia_internal", table: "Operations");
        migrationBuilder.DropColumn(name: "OriginalBranchId", schema: "savia_internal", table: "Operations");
        migrationBuilder.DropTable(name: "Branches", schema: "savia_internal");
    }
}
