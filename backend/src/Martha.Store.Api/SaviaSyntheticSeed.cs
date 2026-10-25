using Microsoft.EntityFrameworkCore;

namespace Martha.Store.Api;

// V1 SyntheticSeed remains independently retained. This different fixture never imports or repairs V1 data.
// Explicit invocation only; reruns validate existing V2 state and never replenish inventory.
public static class SaviaSyntheticSeed
{
    public static readonly Guid VariantId = Guid.Parse("33333333-3333-3333-3333-333333333333");
    public static readonly Guid LocationId = Guid.Parse("44444444-4444-4444-4444-444444444444");
    public const string Sku = "SYNTHETIC-SAVIA-V2-001";
    public const string Name = "SYNTHETIC SAVIA V2 PRODUCT - NOT FOR SALE";
    public static async Task Apply(StoreDbContext db)
    {
        await using var tx = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
        var balances = await db.SaviaBalances.AsNoTracking().ToListAsync();
        var reservations = await db.SaviaReservations.AsNoTracking().ToListAsync();
        var attempts = await db.SaviaAttempts.AsNoTracking().ToListAsync();
        var movements = await db.SaviaMovements.AsNoTracking().ToListAsync();
        if (balances.Count == 0 && reservations.Count == 0 && attempts.Count == 0 && movements.Count == 0)
        {
            db.SaviaBalances.Add(new SaviaBalance { VariantId = VariantId, LocationId = LocationId, Sku = Sku, Name = Name, UnitPriceMinor = 1250, Currency = "XXX", OnHand = 5, Reserved = 0 });
            await db.SaveChangesAsync();
        }
        else
        {
            var balance = balances.SingleOrDefault(x => x.VariantId == VariantId && x.LocationId == LocationId);
            if (balances.Count != 1 || balance is null || balance.Mode != "savia" || balance.InstanceId != "savia-synthetic-v2" || balance.Epoch != 1
                || balance.Sku != Sku || balance.Name != Name || balance.UnitPriceMinor != 1250 || balance.Currency != "XXX" || balance.OnHand != 5
                || balance.Reserved < 0 || balance.Reserved > balance.OnHand
                || reservations.Any(x => x.VariantId != VariantId || x.LocationId != LocationId || x.UnitPriceMinor != 1250 || x.Currency != "XXX" || x.TotalMinor != 1250L * x.Quantity || x.Quantity is < 1 or > 100 || (x.State != "active" && x.State != "cancelled") || (x.State == "cancelled") != x.CancelledAt.HasValue)
                || reservations.Where(x => x.State == "active").Sum(x => x.Quantity) != balance.Reserved
                || movements.Sum(x => x.ReservedDelta) != balance.Reserved
                || movements.Any(x => x.OnHandDelta != 0 || x.VariantId != VariantId || x.LocationId != LocationId || x.Mode != "savia" || x.InstanceId != "savia-synthetic-v2" || x.Epoch != 1 || !reservations.Any(r => r.Id == x.ReservationId) || !attempts.Any(a => a.AttemptId == x.AttemptId && a.Outcome == "succeeded" && a.Operation == x.Kind))
                || reservations.Any(r => !attempts.Any(a => a.AttemptId == r.CreateAttemptId && a.Operation == "reserve" && a.Outcome == "succeeded") || movements.Count(m => m.ReservationId == r.Id && m.Kind == "reserve" && m.ReservedDelta == r.Quantity && m.AttemptId == r.CreateAttemptId) != 1 || movements.Count(m => m.ReservationId == r.Id && m.Kind == "cancel" && m.ReservedDelta == -r.Quantity) != (r.State == "cancelled" ? 1 : 0))
                || attempts.Any(a => a.Mode != "savia" || a.InstanceId != "savia-synthetic-v2" || a.Epoch != 1 || !SaviaService.ValidKey(a.IdempotencyKey) || (a.Operation != "reserve" && a.Operation != "cancel") || (a.Outcome == "succeeded" ? a.ResultJson is null || a.Error is not null : a.Outcome != "rejected" || a.ResultJson is not null || a.Error is null)))
                throw new InvalidOperationException("SAVIA V2 fixture is partial or inconsistent; seed will not repair or replenish it.");
        }
        await tx.CommitAsync();
    }
}
