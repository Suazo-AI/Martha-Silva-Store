using Microsoft.EntityFrameworkCore;
using System.Text.Json;

namespace Martha.Store.Api.Internal;

// Branch is explicit: a location/bodega is not inferred to be a branch by name.
public sealed class InternalBranch
{
    public Guid Id { get; set; }
    public string Name { get; set; } = "";
    public bool Active { get; set; } = true;
}
public sealed class InternalBranchAssignmentAudit
{
    public Guid Id { get; set; }
    public Guid ActorId { get; set; }
    public Guid StaffId { get; set; }
    public Guid? PreviousBranchId { get; set; }
    public Guid? BranchId { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}
public sealed record InternalCommandResource(string Kind, Guid Id, Guid? PayingTillId = null);

// No ambient claims, null=global, name-based mapping or cached permissions.
// Mutations use this resolver INSIDE the runner's serializable transaction.
public sealed class InternalBranchAccess(InternalDbContext db)
{
    public IQueryable<InternalLocation> Locations(Guid actorId) => db.InternalLocations.AsNoTracking().Where(location =>
        db.InternalStaff.Any(staff => staff.Id == actorId && staff.Enabled &&
            (staff.Role == "Owner" || ((staff.Role == "Manager" || staff.Role == "Cashier" || staff.Role == "Inventory")
                && staff.BranchId != null && location.BranchId == staff.BranchId
                && db.Set<InternalBranch>().Any(branch => branch.Id == staff.BranchId && branch.Active)))));

    public Task<bool> CanAccessLocation(Guid actorId, Guid locationId, CancellationToken ct) =>
        Locations(actorId).AnyAsync(x => x.Id == locationId, ct);

    private Task<bool> CanReadLocationOperation(Guid actorId, InternalOperation operation, CancellationToken ct) =>
        db.InternalStaff.AsNoTracking().AnyAsync(staff => operation.ActorId == actorId && staff.Id == actorId && staff.Enabled &&
            (staff.Role == "Owner" || ((staff.Role == "Manager" || staff.Role == "Cashier" || staff.Role == "Inventory")
                && operation.LocationId != null && operation.OriginalBranchId != null
                && staff.BranchId == operation.OriginalBranchId
                && db.Set<InternalBranch>().Any(branch => branch.Id == staff.BranchId && branch.Active)
                && db.InternalLocations.Any(location => location.Id == operation.LocationId && location.BranchId == operation.OriginalBranchId))), ct);

    public async Task<bool> CanReadOperation(Guid actorId, InternalOperation operation, CancellationToken ct)
    {
        if (!await CanReadLocationOperation(actorId, operation, ct)) return false;
        if (!operation.Scope.StartsWith("cash.", StringComparison.Ordinal)) return true;
        try
        {
            using var document = JsonDocument.Parse(operation.ResultJson);
            var root = document.RootElement;
            if (root.TryGetProperty("error", out var error) && error.ValueKind != JsonValueKind.Null) return true;
            var value = root.GetProperty("value");
            if (operation.Scope == "cash.refund")
            {
                var refund = value.GetProperty("refund");
                return await CanUseCashResource(actorId, operation.Scope, new("cash_refund",
                    refund.GetProperty("saleId").GetGuid(), refund.GetProperty("tillId").GetGuid()), ct);
            }
            var tillId = operation.Scope == "cash.sale" ? value.GetProperty("payment").GetProperty("tillId").GetGuid()
                : value.GetProperty("till").GetProperty("id").GetGuid();
            // Open recovery must also recheck immutable till custody.
            return await CanUseCashResource(actorId, "cash.till.close", new("till", tillId), ct);
        }
        catch (Exception ex) when (ex is JsonException or KeyNotFoundException or InvalidOperationException or FormatException)
        { return false; }
    }

    public async Task<bool> CanUseCashResource(Guid actor, string scope, InternalCommandResource? resource, CancellationToken ct)
    {
        if (!scope.StartsWith("cash.", StringComparison.Ordinal) || scope == "cash.till.open") return true;
        if (resource is null) return false;
        var tillId = scope == "cash.refund" ? resource.PayingTillId : resource.Id;
        var till = await db.Set<InternalCashTill>().AsNoTracking().SingleOrDefaultAsync(x => x.Id == tillId, ct);
        if (till is null || !await CanAccessLocation(actor, till.LocationId, ct)) return false;
        if (scope != "cash.refund") return till.CashierId == actor;
        return await CanAccessLocation(till.CashierId, till.LocationId, ct)
            && await db.InternalStaff.AnyAsync(x => x.Id == till.CashierId && x.Enabled && (x.Role == "Owner" || x.Role == "Manager" || x.Role == "Cashier"), ct)
            && await db.Set<InternalSale>().AnyAsync(x => x.Id == resource.Id && x.LocationId == till.LocationId, ct);
    }

    public Task<Guid?> ResolveLocation(InternalCommandResource resource, CancellationToken ct) => resource.Kind switch
    {
        "location" => db.InternalLocations.Where(x => x.Id == resource.Id).Select(x => (Guid?)x.Id).SingleOrDefaultAsync(ct),
        "sale" => db.Set<InternalSale>().Where(x => x.Id == resource.Id).Select(x => (Guid?)x.LocationId).SingleOrDefaultAsync(ct),
        "till" => db.Set<InternalCashTill>().Where(x => x.Id == resource.Id).Select(x => (Guid?)x.LocationId).SingleOrDefaultAsync(ct),
        "cash_refund" => db.Set<InternalSale>().Where(x => x.Id == resource.Id).Select(x => (Guid?)x.LocationId).SingleOrDefaultAsync(ct),
        "purchase" => db.Set<InternalPurchaseOrder>().Where(x => x.Id == resource.Id).Select(x => (Guid?)x.LocationId).SingleOrDefaultAsync(ct),
        _ => Task.FromResult<Guid?>(null)
    };
}

public sealed partial class InternalDbContext
{
    private void ConfigureBranches(ModelBuilder model)
    {
        model.Entity<InternalBranch>(e =>
        {
            e.ToTable("Branches"); e.HasKey(x => x.Id); e.Property(x => x.Id).ValueGeneratedNever();
            e.Property(x => x.Name).IsRequired().HasMaxLength(120);
        });
        model.Entity<InternalStaff>().HasOne<InternalBranch>().WithMany().HasForeignKey(x => x.BranchId).OnDelete(DeleteBehavior.Restrict);
        model.Entity<InternalLocation>().HasOne<InternalBranch>().WithMany().HasForeignKey(x => x.BranchId).OnDelete(DeleteBehavior.Restrict);
        model.Entity<InternalOperation>().HasIndex(x => x.OriginalBranchId);
        // Immutable resource metadata, no FK to a mutable mapping and no backfill of old results.
        model.Entity<InternalBranchAssignmentAudit>(e =>
        {
            e.ToTable("BranchAssignmentAudit"); e.HasKey(x => x.Id);
            e.HasOne<InternalStaff>().WithMany().HasForeignKey(x => x.ActorId).OnDelete(DeleteBehavior.Restrict);
            e.HasOne<InternalStaff>().WithMany().HasForeignKey(x => x.StaffId).OnDelete(DeleteBehavior.Restrict);
        });
    }
}
