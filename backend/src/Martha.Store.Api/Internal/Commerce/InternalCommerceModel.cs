using Microsoft.EntityFrameworkCore;

namespace Martha.Store.Api.Internal;

public sealed partial class InternalDbContext
{
    partial void ConfigureCommerce(ModelBuilder model)
    {
        var balance = model.Entity<InternalStockBalance>();
        balance.ToTable("StockBalances", t =>
        {
            t.HasCheckConstraint("CK_InternalBalance_Bounds", "[OnHand] >= 0 AND [OnHand] <= 1000000000 AND [Reserved] >= 0 AND [Reserved] <= [OnHand]");
        });
        balance.HasKey(x => new { x.ItemId, x.LocationId });
        balance.HasOne<InternalItem>().WithMany().HasForeignKey(x => x.ItemId).OnDelete(DeleteBehavior.Restrict);
        balance.HasOne<InternalLocation>().WithMany().HasForeignKey(x => x.LocationId).OnDelete(DeleteBehavior.Restrict);

        var movement = model.Entity<InternalStockMovement>();
        movement.ToTable("StockMovements", t =>
        {
            t.HasCheckConstraint("CK_InternalMovement_Nonzero", "[OnHandDelta] <> 0 OR [ReservedDelta] <> 0");
            t.HasCheckConstraint("CK_InternalMovement_After", "[OnHandAfter] >= 0 AND [OnHandAfter] <= 1000000000 AND [ReservedAfter] >= 0 AND [ReservedAfter] <= [OnHandAfter]");
        });
        movement.HasKey(x => x.Id);
        movement.Property(x => x.Kind).HasMaxLength(40).IsRequired();
        movement.HasIndex(x => new { x.ItemId, x.LocationId, x.CreatedAt });
        movement.HasIndex(x => x.OperationId);
        movement.HasOne<InternalStockBalance>().WithMany().HasForeignKey(x => new { x.ItemId, x.LocationId }).OnDelete(DeleteBehavior.Restrict);

        var adjustment = model.Entity<InternalStockAdjustment>();
        adjustment.ToTable("StockAdjustments");
        adjustment.HasKey(x => x.Id);
        adjustment.Property(x => x.Reason).HasMaxLength(500).IsRequired();
        adjustment.HasOne<InternalStockBalance>().WithMany().HasForeignKey(x => new { x.ItemId, x.LocationId }).OnDelete(DeleteBehavior.Restrict);

        var sale = model.Entity<InternalSale>();
        sale.ToTable("Sales", t =>
        {
            t.HasCheckConstraint("CK_InternalSale_Total", "[TotalMinor] >= 0 AND [TotalMinor] <= 9000000000000");
            t.HasCheckConstraint("CK_InternalSale_Currency", "LEN([Currency]) = 3 AND [Currency] COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^A-Z]%' AND [Currency] <> 'XXX'");
            t.HasCheckConstraint("CK_InternalSale_State", "[State] IN ('recorded','partially_returned','returned','cancelled')");
        });
        sale.HasKey(x => x.Id);
        sale.Property(x => x.Currency).HasMaxLength(3).IsRequired();
        sale.Property(x => x.State).HasMaxLength(24).IsRequired();
        sale.HasIndex(x => x.CreatedAt);
        sale.HasOne<InternalLocation>().WithMany().HasForeignKey(x => x.LocationId).OnDelete(DeleteBehavior.Restrict);
        sale.HasOne<InternalParty>().WithMany().HasForeignKey(x => x.CustomerId).OnDelete(DeleteBehavior.Restrict);
        sale.HasMany(x => x.Lines).WithOne().HasForeignKey(x => x.SaleId).OnDelete(DeleteBehavior.Restrict);

        var line = model.Entity<InternalSaleLine>();
        line.ToTable("SaleLines", t =>
        {
            t.HasCheckConstraint("CK_InternalSaleLine_Quantity", "[Quantity] >= 1 AND [Quantity] <= 1000000 AND [ReturnedQuantity] >= 0 AND [ReturnedQuantity] <= [Quantity]");
            t.HasCheckConstraint("CK_InternalSaleLine_Amounts", "[UnitPriceMinor] >= 0 AND [UnitPriceMinor] <= 9000000000000 AND [TotalMinor] >= 0 AND [TotalMinor] <= 9000000000000 AND CAST([UnitPriceMinor] AS decimal(28,0)) * [Quantity] = [TotalMinor]");
        });
        line.HasKey(x => x.Id);
        line.Property(x => x.Sku).HasMaxLength(80).IsRequired();
        line.Property(x => x.Name).HasMaxLength(200).IsRequired();
        line.HasIndex(x => new { x.SaleId, x.ItemId }).IsUnique();
        line.HasOne<InternalItem>().WithMany().HasForeignKey(x => x.ItemId).OnDelete(DeleteBehavior.Restrict);

        var reversal = model.Entity<InternalSaleReversal>();
        reversal.ToTable("SaleReversals", t =>
        {
            t.HasCheckConstraint("CK_InternalReversal_Kind", "[Kind] IN ('cancel','return')");
            t.HasCheckConstraint("CK_InternalReversal_Amount", "[RecordedCreditMinor] >= 0 AND [RecordedCreditMinor] <= 9000000000000");
        });
        reversal.HasKey(x => x.Id);
        reversal.Property(x => x.Kind).HasMaxLength(16).IsRequired();
        reversal.Property(x => x.Reason).HasMaxLength(500).IsRequired();
        reversal.HasIndex(x => x.SaleId);
        reversal.HasOne<InternalSale>().WithMany().HasForeignKey(x => x.SaleId).OnDelete(DeleteBehavior.Restrict);
        reversal.HasMany(x => x.Lines).WithOne().HasForeignKey(x => x.ReversalId).OnDelete(DeleteBehavior.Restrict);

        var reversalLine = model.Entity<InternalSaleReversalLine>();
        reversalLine.ToTable("SaleReversalLines", t =>
        {
            t.HasCheckConstraint("CK_InternalReversalLine_Bounds", "[Quantity] >= 1 AND [Quantity] <= 1000000 AND [RecordedCreditMinor] >= 0 AND [RecordedCreditMinor] <= 9000000000000");
        });
        reversalLine.HasKey(x => x.Id);
        reversalLine.HasIndex(x => new { x.ReversalId, x.SaleLineId }).IsUnique();
        reversalLine.HasOne<InternalSaleLine>().WithMany().HasForeignKey(x => x.SaleLineId).OnDelete(DeleteBehavior.Restrict);
    }
}
