using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Martha.Store.Api.Internal;

// One SQL authority. The enclosing command runner owns commit/replay and rolls back failed actions.
public sealed class InternalStockLedger(InternalDbContext db) : IInternalStockLedger
{
    public const int MaxStock = 1_000_000_000;

    public async Task<InternalResult<bool>> Change(Guid itemId, Guid locationId, int onHandDelta, int reservedDelta,
        Guid actorId, Guid operationId, string kind, CancellationToken ct)
    {
        if (!ValidChange(itemId, locationId, onHandDelta, reservedDelta, actorId, operationId, kind))
            return InternalResult<bool>.Fail("invalid_request");
        if (!db.Database.IsSqlServer() || db.Database.CurrentTransaction is not { } transaction ||
            transaction.GetDbTransaction().IsolationLevel != IsolationLevel.Serializable)
            throw new InvalidOperationException("Internal stock changes require the caller's serializable SQL transaction on the same scoped context.");
        if (!await db.Set<InternalItem>().AnyAsync(x => x.Id == itemId, ct)) return InternalResult<bool>.Fail("item_not_found");
        if (!await db.Set<InternalLocation>().AnyAsync(x => x.Id == locationId, ct)) return InternalResult<bool>.Fail("location_not_found");

        var now = DateTimeOffset.UtcNow;
        // Range/update locks serialize zero initialization with other changes to this exact key.
        // New balances are always zero, never seeded with a synthetic or invented quantity.
        await db.Database.ExecuteSqlInterpolatedAsync($"""
            INSERT INTO [savia_internal].[StockBalances] ([ItemId],[LocationId],[OnHand],[Reserved],[UpdatedAt])
            SELECT {itemId},{locationId},0,0,{now}
            WHERE NOT EXISTS (SELECT 1 FROM [savia_internal].[StockBalances] WITH (UPDLOCK,HOLDLOCK)
                              WHERE [ItemId]={itemId} AND [LocationId]={locationId});
            """, ct);

        // The predicate and arithmetic execute together in SQL; wider intermediates avoid overflow.
        var changed = await db.Set<InternalStockBalance>()
            .Where(x => x.ItemId == itemId && x.LocationId == locationId
                && (long)x.OnHand + onHandDelta >= 0 && (long)x.OnHand + onHandDelta <= MaxStock
                && (long)x.Reserved + reservedDelta >= 0 && (long)x.Reserved + reservedDelta <= MaxStock
                && (long)x.OnHand + onHandDelta >= (long)x.Reserved + reservedDelta)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.OnHand, x => x.OnHand + onHandDelta)
                .SetProperty(x => x.Reserved, x => x.Reserved + reservedDelta).SetProperty(x => x.UpdatedAt, now), ct);
        if (changed != 1) return InternalResult<bool>.Fail("stock_unavailable");
        var balance = await db.Set<InternalStockBalance>().AsNoTracking().SingleAsync(x => x.ItemId == itemId && x.LocationId == locationId, ct);
        db.Set<InternalStockMovement>().Add(new()
        {
            Id = Guid.NewGuid(), ItemId = itemId, LocationId = locationId, ActorId = actorId, OperationId = operationId,
            Kind = kind, OnHandDelta = onHandDelta, ReservedDelta = reservedDelta,
            OnHandAfter = balance.OnHand, ReservedAfter = balance.Reserved, CreatedAt = now
        });
        await db.SaveChangesAsync(ct);
        return InternalResult<bool>.Ok(true);
    }

    public static bool ValidChange(Guid itemId, Guid locationId, int onHandDelta, int reservedDelta,
        Guid actorId, Guid operationId, string? kind) =>
        itemId != Guid.Empty && locationId != Guid.Empty && actorId != Guid.Empty && operationId != Guid.Empty
        && onHandDelta is >= -MaxStock and <= MaxStock && reservedDelta is >= -MaxStock and <= MaxStock
        && (onHandDelta != 0 || reservedDelta != 0)
        && kind is { Length: >= 1 and <= 40 } && kind.All(c => c is >= 'a' and <= 'z' or '_');
}

public static class InternalCommerceRules
{
    public const int MaxLines = 100;
    public const int MaxLineQuantity = 1_000_000;
    public static bool ValidReason(string? reason) => reason is { Length: >= 1 and <= 500 } && reason.Trim().Length >= 1 && !reason.Any(char.IsControl);
    public static bool ValidSale(InternalSaleRequest request) => request.LocationId != Guid.Empty && request.CustomerId != Guid.Empty
        && request.Lines is { Count: >= 1 and <= MaxLines }
        && request.Lines.All(x => x is not null && x.ItemId != Guid.Empty && x.Quantity is >= 1 and <= MaxLineQuantity)
        && request.Lines.Select(x => x.ItemId).Distinct().Count() == request.Lines.Count;
    public static bool ValidReturn(InternalSaleReturnRequest request) => ValidReason(request.Reason)
        && request.Lines is { Count: >= 1 and <= MaxLines }
        && request.Lines.All(x => x is not null && x.SaleLineId != Guid.Empty && x.Quantity is >= 1 and <= MaxLineQuantity)
        && request.Lines.Select(x => x.SaleLineId).Distinct().Count() == request.Lines.Count;
    public static bool TryTotal(IEnumerable<(long UnitPriceMinor, int Quantity)> lines, out long total)
    {
        total = 0;
        foreach (var (price, quantity) in lines)
        {
            if (price is < 0 or > InternalRules.MaxMinor || quantity is < 1 or > MaxLineQuantity) return false;
            // Division verifies both overflow and the aggregate money bound before multiplication.
            if (price > (InternalRules.MaxMinor - total) / quantity) return false;
            total += price * quantity;
        }
        return true;
    }
}
