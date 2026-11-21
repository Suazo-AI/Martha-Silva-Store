using Microsoft.EntityFrameworkCore;

namespace Martha.Store.Api.Internal;

public sealed partial class InternalDbContext
{
    private void ConfigureCash(ModelBuilder model)
    {
        var till = model.Entity<InternalCashTill>();
        till.ToTable("CashTills", t => {
            t.HasCheckConstraint("CK_CashTill_Currency", "LEN([Currency])=3 AND [Currency] COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^A-Z]%' AND [Exponent] BETWEEN 0 AND 6");
            t.HasCheckConstraint("CK_CashTill_Time", "[ClosedAt] IS NULL OR [ClosedAt]>=[OpenedAt]");
        });
        till.HasKey(x => x.Id);
        till.HasAlternateKey(x => new { x.Id, x.CashierId, x.Currency, x.Exponent });
        till.Property(x => x.Currency).HasMaxLength(3).IsUnicode(false).UseCollation("Latin1_General_100_BIN2");
        till.HasIndex(x => x.CashierId).IsUnique().HasFilter("[ClosedAt] IS NULL");
        till.HasOne<InternalStaff>().WithMany().HasForeignKey(x => x.CashierId).OnDelete(DeleteBehavior.Restrict);
        till.HasOne<InternalLocation>().WithMany().HasForeignKey(x => x.LocationId).OnDelete(DeleteBehavior.Restrict);
        var entry = model.Entity<InternalCashEntry>();
        entry.ToTable("CashEntries", t => {
            t.HasCheckConstraint("CK_CashEntry_Bounds", "[DeltaMinor] BETWEEN -9000000000000 AND 9000000000000 AND [ReceivedMinor] BETWEEN 0 AND 9000000000000 AND [ChangeMinor] BETWEEN 0 AND 9000000000000");
            t.HasCheckConstraint("CK_CashEntry_Kind", "([Kind]='opening' AND [DeltaMinor]>=0 AND [ReceivedMinor]=0 AND [ChangeMinor]=0 AND [SaleId] IS NULL AND [ReversalId] IS NULL) OR ([Kind]='sale' AND [DeltaMinor]>=0 AND [ReceivedMinor]-[ChangeMinor]=[DeltaMinor] AND [SaleId] IS NOT NULL AND [ReversalId] IS NULL) OR ([Kind]='refund' AND [DeltaMinor]<0 AND [ReceivedMinor]=0 AND [ChangeMinor]=0 AND [SaleId] IS NOT NULL AND [ReversalId] IS NOT NULL)");
        });
        entry.HasKey(x => x.Id);
        entry.Property(x => x.Currency).HasMaxLength(3).IsUnicode(false).UseCollation("Latin1_General_100_BIN2");
        entry.Property(x => x.Kind).HasMaxLength(16).IsUnicode(false);
        entry.HasIndex(x => x.TillId).IsUnique().HasFilter("[Kind]='opening'");
        entry.HasIndex(x => x.SaleId).IsUnique().HasFilter("[Kind]='sale'");
        entry.HasIndex(x => x.ReversalId).IsUnique().HasFilter("[ReversalId] IS NOT NULL");
        entry.HasOne<InternalCashTill>().WithMany().HasForeignKey(x => new { x.TillId, x.CashierId, x.Currency, x.Exponent })
            .HasPrincipalKey(x => new { x.Id, x.CashierId, x.Currency, x.Exponent }).OnDelete(DeleteBehavior.Restrict);
        entry.HasOne<InternalStaff>().WithMany().HasForeignKey(x => x.ActorId).OnDelete(DeleteBehavior.Restrict);
        entry.HasOne<InternalSale>().WithMany().HasForeignKey(x => x.SaleId).OnDelete(DeleteBehavior.Restrict);
        entry.HasOne<InternalSaleReversal>().WithMany().HasForeignKey(x => x.ReversalId).OnDelete(DeleteBehavior.Restrict);
        var close = model.Entity<InternalCashClose>();
        close.ToTable("CashCloses", t => t.HasCheckConstraint("CK_CashClose_Amounts", "[ExpectedMinor] BETWEEN 0 AND 9000000000000 AND [CountedMinor] BETWEEN 0 AND 9000000000000 AND [DifferenceMinor]=[CountedMinor]-[ExpectedMinor]"));
        close.HasKey(x => x.Id); close.HasIndex(x => x.TillId).IsUnique();
        close.HasOne<InternalCashTill>().WithMany().HasForeignKey(x => x.TillId).OnDelete(DeleteBehavior.Restrict);
        close.HasOne<InternalStaff>().WithMany().HasForeignKey(x => x.ActorId).OnDelete(DeleteBehavior.Restrict);
    }
}
