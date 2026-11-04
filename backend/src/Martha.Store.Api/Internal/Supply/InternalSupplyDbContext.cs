using Microsoft.EntityFrameworkCore;

namespace Martha.Store.Api.Internal;

public sealed partial class InternalDbContext
{
    public DbSet<InternalPurchaseOrder> InternalPurchaseOrders => Set<InternalPurchaseOrder>();
    public DbSet<InternalPurchaseOrderLine> InternalPurchaseOrderLines => Set<InternalPurchaseOrderLine>();
    public DbSet<InternalPurchaseReceipt> InternalPurchaseReceipts => Set<InternalPurchaseReceipt>();
    public DbSet<InternalPurchaseReceiptLine> InternalPurchaseReceiptLines => Set<InternalPurchaseReceiptLine>();

    partial void ConfigureSupply(ModelBuilder model)
    {
        model.Entity<InternalPurchaseOrder>(b =>
        {
            b.ToTable("PurchaseOrders", t =>
            {
                t.HasCheckConstraint("CK_InternalPurchaseOrder_Status", "[Status] IN ('open','partially_received','received','cancelled')");
                t.HasCheckConstraint("CK_InternalPurchaseOrder_Total", "[TotalMinor] >= 0 AND [TotalMinor] <= 9000000000000");
                t.HasCheckConstraint("CK_InternalPurchaseOrder_Currency", "[Currency] COLLATE Latin1_General_100_BIN2 LIKE '[A-Z][A-Z][A-Z]' AND [Currency] <> 'XXX'");
                t.HasCheckConstraint("CK_InternalPurchaseOrder_Cancel", "([Status] = 'cancelled' AND [CancelledBy] IS NOT NULL AND [CancelledAt] IS NOT NULL AND [CancellationReason] IS NOT NULL) OR ([Status] <> 'cancelled' AND [CancelledBy] IS NULL AND [CancelledAt] IS NULL AND [CancellationReason] IS NULL)");
            });
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).ValueGeneratedNever();
            b.Property(x => x.SupplierName).HasMaxLength(200);
            b.Property(x => x.Currency).HasMaxLength(3).IsUnicode(false);
            b.Property(x => x.Reference).HasMaxLength(100);
            b.Property(x => x.Status).HasMaxLength(24).IsUnicode(false);
            b.Property(x => x.CancellationReason).HasMaxLength(500);
            b.HasIndex(x => new { x.CreatedAt, x.Id });
            b.HasOne<InternalParty>().WithMany().HasForeignKey(x => x.SupplierId).OnDelete(DeleteBehavior.Restrict);
            b.HasOne<InternalLocation>().WithMany().HasForeignKey(x => x.LocationId).OnDelete(DeleteBehavior.Restrict);
            b.HasMany(x => x.Lines).WithOne().HasForeignKey(x => x.PurchaseOrderId).OnDelete(DeleteBehavior.Restrict);
        });
        model.Entity<InternalPurchaseOrderLine>(b =>
        {
            b.ToTable("PurchaseOrderLines", t =>
            {
                t.HasCheckConstraint("CK_InternalPurchaseLine_Quantity", "[Quantity] BETWEEN 1 AND 1000000 AND [ReceivedQuantity] BETWEEN 0 AND [Quantity]");
                t.HasCheckConstraint("CK_InternalPurchaseLine_Cost", "[UnitCostMinor] >= 0 AND [UnitCostMinor] <= 9000000000000 / [Quantity]");
            });
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).ValueGeneratedNever();
            b.HasIndex(x => new { x.PurchaseOrderId, x.ItemId }).IsUnique();
            b.HasAlternateKey(x => new { x.PurchaseOrderId, x.Id, x.ItemId });
            b.Property(x => x.ItemSku).HasMaxLength(64);
            b.Property(x => x.ItemName).HasMaxLength(200);
            b.HasOne<InternalItem>().WithMany().HasForeignKey(x => x.ItemId).OnDelete(DeleteBehavior.Restrict);
        });
        model.Entity<InternalPurchaseReceipt>(b =>
        {
            b.ToTable("PurchaseReceipts", t =>
            {
                t.HasCheckConstraint("CK_InternalPurchaseReceipt_Total", "[TotalMinor] >= 0 AND [TotalMinor] <= 9000000000000");
                t.HasCheckConstraint("CK_InternalPurchaseReceipt_Status", "[OrderStatusAfter] IN ('partially_received','received')");
                t.HasCheckConstraint("CK_InternalPurchaseReceipt_Currency", "[Currency] COLLATE Latin1_General_100_BIN2 LIKE '[A-Z][A-Z][A-Z]' AND [Currency] <> 'XXX'");
            });
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).ValueGeneratedNever();
            b.Property(x => x.Currency).HasMaxLength(3).IsUnicode(false);
            b.Property(x => x.Fingerprint).HasMaxLength(64).IsUnicode(false);
            b.Property(x => x.OrderStatusAfter).HasMaxLength(24).IsUnicode(false);
            b.HasAlternateKey(x => new { x.Id, x.PurchaseOrderId });
            b.HasIndex(x => new { x.PurchaseOrderId, x.ReceivedAt });
            b.HasOne<InternalPurchaseOrder>().WithMany().HasForeignKey(x => x.PurchaseOrderId).OnDelete(DeleteBehavior.Restrict);
            b.HasOne<InternalLocation>().WithMany().HasForeignKey(x => x.LocationId).OnDelete(DeleteBehavior.Restrict);
            b.HasMany(x => x.Lines).WithOne().HasForeignKey(x => new { x.ReceiptId, x.PurchaseOrderId })
                .HasPrincipalKey(x => new { x.Id, x.PurchaseOrderId }).OnDelete(DeleteBehavior.Restrict);
        });
        model.Entity<InternalPurchaseReceiptLine>(b =>
        {
            b.ToTable("PurchaseReceiptLines", t =>
            {
                t.HasCheckConstraint("CK_InternalReceiptLine_Quantity", "[Quantity] BETWEEN 1 AND 1000000");
                t.HasCheckConstraint("CK_InternalReceiptLine_Cost", "[UnitCostMinor] >= 0 AND [UnitCostMinor] <= 9000000000000 / [Quantity]");
            });
            b.HasKey(x => x.Id);
            b.Property(x => x.Id).ValueGeneratedNever();
            b.HasIndex(x => new { x.ReceiptId, x.PurchaseOrderLineId }).IsUnique();
            b.HasOne<InternalPurchaseOrderLine>().WithMany()
                .HasForeignKey(x => new { x.PurchaseOrderId, x.PurchaseOrderLineId, x.ItemId })
                .HasPrincipalKey(x => new { x.PurchaseOrderId, x.Id, x.ItemId }).OnDelete(DeleteBehavior.Restrict);
            b.HasOne<InternalItem>().WithMany().HasForeignKey(x => x.ItemId).OnDelete(DeleteBehavior.Restrict);
        });
    }
}
