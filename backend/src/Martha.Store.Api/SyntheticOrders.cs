using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Martha.Store.Api;

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record CreateSyntheticOrder(Guid VariantId, int Quantity);
public sealed record OrderResponse(Guid OrderId, Guid VariantId, int Quantity, long UnitPriceMinor,
    string Currency, long TotalMinor, string Status, DateTimeOffset CreatedAt, bool Synthetic)
{
    public static OrderResponse From(SyntheticOrder o) => new(o.Id, o.VariantId, o.Quantity,
        o.UnitPriceMinor, o.Currency, o.TotalMinor, "reserved", o.CreatedAt, true);
}
public sealed record ReservationResult(OrderResponse? Order, string? Error);

public sealed class SyntheticOrders(StoreDbContext db)
{
    public const string Actor = "synthetic-test";
    public static bool ValidKey(string? key) => key is { Length: >= 8 and <= 128 } && key.All(c => c >= '!' && c <= '~');
    public static bool ValidRequest(CreateSyntheticOrder request) => request.VariantId != Guid.Empty && request.Quantity is >= 1 and <= 100;

    public async Task<ReservationResult> Reserve(CreateSyntheticOrder request, string key, CancellationToken ct)
    {
        if (!ValidKey(key) || !ValidRequest(request)) return new(null, "invalid_request");
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        // Database-scoped lock, owned by this transaction: same logical attempt cannot execute twice.
        // SHA256 preserves exact case and avoids SQL trailing-space/collation ambiguities.
        var resource = "synthetic-order:" + Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(Actor + ":" + key)));
        await using (var command = db.Database.GetDbConnection().CreateCommand())
        {
            command.Transaction = tx.GetDbTransaction();
            command.CommandText = "DECLARE @r int; EXEC @r = sys.sp_getapplock @Resource=@resource, @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=15000; SELECT @r;";
            var parameter = command.CreateParameter(); parameter.ParameterName = "@resource"; parameter.Value = resource; command.Parameters.Add(parameter);
            if (Convert.ToInt32(await command.ExecuteScalarAsync(ct)) < 0) throw new StorageUnavailableException();
        }
        var existing = await db.SyntheticOrders.AsNoTracking().SingleOrDefaultAsync(o => o.Actor == Actor && o.IdempotencyKey == key, ct);
        if (existing is not null)
            return existing.VariantId == request.VariantId && existing.Quantity == request.Quantity
                ? new(OrderResponse.From(existing), null) : new(null, "idempotency_conflict");
        // One SQL conditional UPDATE, not a read-modify-write stock decision. Concurrent contenders serialize in SQL.
        var affected = await db.Variants.Where(v => v.Id == request.VariantId && v.AvailableQuantity >= request.Quantity)
            .ExecuteUpdateAsync(set => set.SetProperty(v => v.AvailableQuantity, v => v.AvailableQuantity - request.Quantity), ct);
        if (affected != 1)
            return new(null, await db.Variants.AnyAsync(v => v.Id == request.VariantId, ct) ? "out_of_stock" : "unknown_variant");
        // Read price only after obtaining the stock update lock, held through commit.
        var variant = await db.Variants.AsNoTracking().SingleAsync(v => v.Id == request.VariantId, ct);
        var order = new SyntheticOrder
        {
            Id = Guid.NewGuid(), Actor = Actor, IdempotencyKey = key, VariantId = variant.Id, Quantity = request.Quantity,
            UnitPriceMinor = variant.UnitPriceMinor, Currency = variant.Currency,
            TotalMinor = checked(variant.UnitPriceMinor * request.Quantity), CreatedAt = DateTimeOffset.UtcNow
        };
        db.SyntheticOrders.Add(order);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return new(OrderResponse.From(order), null);
    }
}
public sealed class StorageUnavailableException : Exception;
