using Microsoft.EntityFrameworkCore;
namespace Martha.Store.Api.Internal;

// Separate bounded context; V1/V2 synthetic tables and responses remain unchanged.
public sealed partial class InternalDbContext(DbContextOptions<InternalDbContext> options) : DbContext(options)
{
    protected override void OnModelCreating(ModelBuilder model)
    {
        model.HasDefaultSchema("savia_internal");
        ConfigureSecurity(model); ConfigureDirectory(model); ConfigureCommerce(model); ConfigureSupply(model);
        ConfigureBranches(model); ConfigureStockExceptions(model); ConfigureCash(model);
        model.Entity<InternalOperation>(e =>
        {
            e.ToTable("Operations"); e.HasKey(x => x.Id);
            e.Property(x => x.Scope).HasMaxLength(80).IsUnicode(false).UseCollation("Latin1_General_100_BIN2");
            e.Property(x => x.Key).HasMaxLength(128).IsUnicode(false).UseCollation("Latin1_General_100_BIN2");
            e.Property(x => x.Fingerprint).HasMaxLength(64).IsUnicode(false).UseCollation("Latin1_General_100_BIN2");
            e.Property(x => x.ResultJson).IsRequired();
            e.HasIndex(x => new { x.ActorId, x.Scope, x.Key }).IsUnique();
            e.HasOne<InternalStaff>().WithMany().HasForeignKey(x => x.ActorId).OnDelete(DeleteBehavior.Restrict);
        });
    }
    private void GuardAudit()
    {
        foreach (var entry in ChangeTracker.Entries<InternalCashTill>())
        {
            if (entry.State == EntityState.Deleted || (entry.State == EntityState.Modified &&
                (entry.Properties.Any(p => p.IsModified && p.Metadata.Name != nameof(InternalCashTill.ClosedAt))
                 || entry.Property(x => x.ClosedAt).OriginalValue != null || entry.Entity.ClosedAt == null)))
                throw new InvalidOperationException("Cash till provenance is immutable; closing is one-way.");
        }
        if (ChangeTracker.Entries().Any(e => e.Entity is InternalCashEntry or InternalCashClose or InternalStockExceptionReview or InternalOperation or InternalStockMovement or InternalStockAdjustment
            or InternalSaleReversal or InternalSaleReversalLine or InternalPurchaseReceipt or InternalPurchaseReceiptLine or InternalBranchAssignmentAudit
            && e.State is EntityState.Modified or EntityState.Deleted))
            throw new InvalidOperationException("Internal operation and inventory audit records are append-only.");
    }
    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    { GuardAudit(); return base.SaveChanges(acceptAllChangesOnSuccess); }
    public override Task<int> SaveChangesAsync(bool acceptAllChangesOnSuccess, CancellationToken cancellationToken = default)
    { GuardAudit(); return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken); }
    partial void ConfigureSecurity(ModelBuilder model);
    partial void ConfigureDirectory(ModelBuilder model);
    partial void ConfigureCommerce(ModelBuilder model);
    partial void ConfigureSupply(ModelBuilder model);
}
