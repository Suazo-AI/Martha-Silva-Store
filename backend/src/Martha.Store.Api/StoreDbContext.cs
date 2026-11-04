using Microsoft.EntityFrameworkCore;

namespace Martha.Store.Api;

public sealed class StoreDbContext(DbContextOptions<StoreDbContext> options) : DbContext(options)
{
    public DbSet<Product> Products => Set<Product>();
    public DbSet<Variant> Variants => Set<Variant>();
    public DbSet<SyntheticOrder> SyntheticOrders => Set<SyntheticOrder>();

    public DbSet<SaviaBalance> SaviaBalances => Set<SaviaBalance>();
    public DbSet<SaviaReservation> SaviaReservations => Set<SaviaReservation>();
    public DbSet<SaviaAttempt> SaviaAttempts => Set<SaviaAttempt>();
    public DbSet<SaviaMovement> SaviaMovements => Set<SaviaMovement>();

    private void GuardSaviaLedger()
    {
        if (ChangeTracker.Entries().Any(e => (e.Entity is SaviaAttempt or SaviaMovement) && e.State is EntityState.Modified or EntityState.Deleted))
            throw new InvalidOperationException("SAVIA attempts and movements are append-only.");
        foreach (var entry in ChangeTracker.Entries<SaviaReservation>())
        {
            if (entry.State == EntityState.Deleted || entry.State == EntityState.Modified &&
                (entry.Properties.Any(p => p.IsModified && p.Metadata.Name is not (nameof(SaviaReservation.State) or nameof(SaviaReservation.CancelledAt)))
                 || entry.OriginalValues.GetValue<string>(nameof(SaviaReservation.State)) != "active"
                 || entry.Entity.State != "cancelled" || entry.Entity.CancelledAt is null))
                throw new InvalidOperationException("SAVIA reservation creation fields are immutable; only cancellation is allowed.");
        }
    }
    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {
        GuardSaviaLedger();
        return base.SaveChanges(acceptAllChangesOnSuccess);
    }
    public override Task<int> SaveChangesAsync(bool acceptAllChangesOnSuccess, CancellationToken cancellationToken = default)
    {
        GuardSaviaLedger();
        return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
    }

    protected override void OnModelCreating(ModelBuilder model)
    {
        SaviaModel.Configure(model);
        model.Entity<Product>(p => { p.HasKey(x => x.Id); p.Property(x => x.Name).HasMaxLength(200); });
        model.Entity<Variant>(v =>
        {
            v.HasKey(x => x.Id);
            v.HasOne<Product>().WithMany().HasForeignKey(x => x.ProductId).OnDelete(DeleteBehavior.Restrict);
            v.Property(x => x.Sku).HasMaxLength(80); v.HasIndex(x => x.Sku).IsUnique();
            v.Property(x => x.Currency).HasMaxLength(3).IsUnicode(false);
            v.ToTable(t =>
            {
                t.HasCheckConstraint("CK_Variants_Stock", "[AvailableQuantity] >= 0");
                t.HasCheckConstraint("CK_Variants_Price", "[UnitPriceMinor] >= 0 AND [UnitPriceMinor] <= 9000000000000");
                t.HasCheckConstraint("CK_Variants_Currency", "[Currency] = 'XXX'");
            });
        });
        model.Entity<SyntheticOrder>(o =>
        {
            o.HasKey(x => x.Id);
            o.HasOne<Variant>().WithMany().HasForeignKey(x => x.VariantId).OnDelete(DeleteBehavior.Restrict);
            o.Property(x => x.Actor).HasMaxLength(40).IsUnicode(false);
            o.Property(x => x.IdempotencyKey).HasMaxLength(128).IsUnicode(false).UseCollation("Latin1_General_100_BIN2");
            o.HasIndex(x => new { x.Actor, x.IdempotencyKey }).IsUnique();
            o.Property(x => x.Currency).HasMaxLength(3).IsUnicode(false);
            o.ToTable(t =>
            {
                t.HasCheckConstraint("CK_SyntheticOrders_Quantity", "[Quantity] >= 1 AND [Quantity] <= 100");
                t.HasCheckConstraint("CK_SyntheticOrders_Total", "[UnitPriceMinor] >= 0 AND [UnitPriceMinor] <= 9000000000000 AND [TotalMinor] = [UnitPriceMinor] * [Quantity]");
                t.HasCheckConstraint("CK_SyntheticOrders_Actor", "[Actor] = 'synthetic-test' AND [Currency] = 'XXX'");
            });
        });
    }
}

public sealed class Product { public Guid Id { get; set; } public string Name { get; set; } = ""; }
public sealed class Variant
{
    public Guid Id { get; set; }
    public Guid ProductId { get; set; }
    public string Sku { get; set; } = "";
    public long UnitPriceMinor { get; set; }
    public string Currency { get; set; } = "XXX";
    public int AvailableQuantity { get; set; }
}
public sealed class SyntheticOrder
{
    public Guid Id { get; set; }
    public string Actor { get; set; } = "synthetic-test";
    public string IdempotencyKey { get; set; } = "";
    public Guid VariantId { get; set; }
    public int Quantity { get; set; }
    public long UnitPriceMinor { get; set; }
    public long TotalMinor { get; set; }
    public string Currency { get; set; } = "XXX";
    public DateTimeOffset CreatedAt { get; set; }
}
