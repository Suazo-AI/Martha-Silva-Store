using Microsoft.EntityFrameworkCore;

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
public sealed record InternalCommandResource(string Kind, Guid Id);

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

    public Task<bool> CanReadOperation(Guid actorId, InternalOperation operation, CancellationToken ct) =>
        db.InternalStaff.AsNoTracking().AnyAsync(staff => operation.ActorId == actorId && staff.Id == actorId && staff.Enabled &&
            (staff.Role == "Owner" || ((staff.Role == "Manager" || staff.Role == "Cashier" || staff.Role == "Inventory")
                && operation.LocationId != null && operation.OriginalBranchId != null
                && staff.BranchId == operation.OriginalBranchId
                && db.Set<InternalBranch>().Any(branch => branch.Id == staff.BranchId && branch.Active)
                && db.InternalLocations.Any(location => location.Id == operation.LocationId && location.BranchId == operation.OriginalBranchId))), ct);

    public Task<Guid?> ResolveLocation(InternalCommandResource resource, CancellationToken ct) => resource.Kind switch
    {
        "location" => db.InternalLocations.Where(x => x.Id == resource.Id).Select(x => (Guid?)x.Id).SingleOrDefaultAsync(ct),
        "sale" => db.Set<InternalSale>().Where(x => x.Id == resource.Id).Select(x => (Guid?)x.LocationId).SingleOrDefaultAsync(ct),
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
