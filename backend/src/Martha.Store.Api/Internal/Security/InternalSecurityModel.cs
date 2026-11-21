using Microsoft.EntityFrameworkCore;

namespace Martha.Store.Api.Internal;

// One isolated business instance. These identities are not customer accounts or tenants.
public sealed class InternalStaff
{
    public Guid Id { get; set; }
    public string LoginName { get; set; } = "";
    public string NormalizedLoginName { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public string Role { get; set; } = "";
    public Guid? BranchId { get; set; }
    public bool Enabled { get; set; }
    public Guid SecurityVersion { get; set; }
    public int FailedSignIns { get; set; }
    public DateTimeOffset? LockedUntil { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public byte[] RowVersion { get; set; } = [];
}

public sealed class InternalSession
{
    public Guid Id { get; set; }
    public Guid StaffId { get; set; }
    public Guid SecurityVersion { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset ExpiresAt { get; set; }
    public DateTimeOffset? RevokedAt { get; set; }
}

public sealed partial class InternalDbContext
{
    public DbSet<InternalStaff> InternalStaff => Set<InternalStaff>();
    public DbSet<InternalSession> InternalSessions => Set<InternalSession>();

    partial void ConfigureSecurity(ModelBuilder model)
    {
        model.Entity<InternalStaff>(entity =>
        {
            entity.ToTable("Staff", table =>
            {
                table.HasCheckConstraint("CK_InternalStaff_Role", "[Role] IN ('Owner','Manager','Cashier','Inventory')");
                table.HasCheckConstraint("CK_InternalStaff_FailedSignIns", "[FailedSignIns] >= 0 AND [FailedSignIns] <= 5");
            });
            entity.HasKey(x => x.Id);
            entity.Property(x => x.LoginName).HasMaxLength(64).IsRequired();
            entity.Property(x => x.NormalizedLoginName).HasMaxLength(64).IsRequired();
            entity.HasIndex(x => x.NormalizedLoginName).IsUnique();
            entity.Property(x => x.DisplayName).HasMaxLength(120).IsRequired();
            entity.Property(x => x.PasswordHash).HasMaxLength(512).IsRequired();
            entity.Property(x => x.Role).HasMaxLength(20).IsRequired();
            entity.Property(x => x.RowVersion).IsRowVersion();
        });
        model.Entity<InternalSession>(entity =>
        {
            entity.ToTable("Sessions", table => table.HasCheckConstraint("CK_InternalSession_Expiry", "[ExpiresAt] > [CreatedAt]"));
            entity.HasKey(x => x.Id);
            entity.HasOne<InternalStaff>().WithMany().HasForeignKey(x => x.StaffId).OnDelete(DeleteBehavior.Restrict);
            entity.HasIndex(x => new { x.StaffId, x.ExpiresAt });
        });
    }
}
