using Microsoft.EntityFrameworkCore;

namespace Martha.Store.Api;

// No historic catalog, customer or payment data. This seed is opt-in CLI only, never automatic at startup.
public static class SyntheticSeed
{
    public static readonly Guid ProductId = Guid.Parse("11111111-1111-1111-1111-111111111111");
    public static readonly Guid VariantId = Guid.Parse("22222222-2222-2222-2222-222222222222");
    public static async Task Apply(StoreDbContext db)
    {
        await using var tx = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
        if (!await db.Products.AnyAsync(p => p.Id == ProductId))
        {
            db.Products.Add(new Product { Id = ProductId, Name = "SYNTHETIC TEST PRODUCT — NOT FOR SALE" });
            db.Variants.Add(new Variant { Id = VariantId, ProductId = ProductId, Sku = "SYNTHETIC-ONLY-001", UnitPriceMinor = 1250, Currency = "XXX", AvailableQuantity = 1 });
            await db.SaveChangesAsync();
        }
        // Repeating seed never replenishes reserved stock or clears orders.
        await tx.CommitAsync();
    }
}
