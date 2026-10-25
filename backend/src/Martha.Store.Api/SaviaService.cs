using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Martha.Store.Api;

// A single authority, SQL transaction and durable receipt own each operation. No V1 stock is read or written.
public sealed class SaviaService(StoreDbContext db)
{
    public static readonly SaviaAuthority Authority = new("savia", "savia-synthetic-v2", 1);
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    public static bool ValidKey(string? key) => key is { Length: >= 8 and <= 128 } && key.All(c => c is >= '!' and <= '~');
    public static bool ValidRequest(SaviaReserveRequest request) => request.VariantId != Guid.Empty && request.LocationId != Guid.Empty && request.AttemptId != Guid.Empty && request.Quantity is >= 1 and <= 100;

    public async Task CheckSchema(CancellationToken ct)
    {
        _ = await db.SaviaBalances.AsNoTracking().Select(x => x.Reserved).Take(1).ToListAsync(ct);
        _ = await db.SaviaReservations.AsNoTracking().Select(x => x.State).Take(1).ToListAsync(ct);
        _ = await db.SaviaAttempts.AsNoTracking().Select(x => x.ResultJson).Take(1).ToListAsync(ct);
        _ = await db.SaviaMovements.AsNoTracking().Select(x => x.ReservedDelta).Take(1).ToListAsync(ct);
    }
    public async Task<IReadOnlyList<SaviaCatalogItem>> Catalog(CancellationToken ct) =>
        (await db.SaviaBalances.AsNoTracking().OrderBy(x => x.VariantId).ThenBy(x => x.LocationId).ToListAsync(ct))
        .Select(x => new SaviaCatalogItem(x.VariantId, x.LocationId, x.Sku, x.Name, x.UnitPriceMinor, x.Currency, x.OnHand, x.Reserved, x.OnHand - x.Reserved, new(x.Mode, x.InstanceId, x.Epoch), true)).ToList();

    public async Task<SaviaResult<SaviaReservationReceipt>> Reserve(SaviaReserveRequest request, string key, CancellationToken ct)
    {
        if (request.Authority != Authority) return new(null, "authority_mismatch");
        if (!ValidKey(key) || !ValidRequest(request)) return new(null, "invalid_request");
        var payload = JsonSerializer.Serialize(request, Json);
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        await LockIdentities("reserve", request.AttemptId, key, tx, ct);
        var replay = await Replay<SaviaReservationReceipt>("reserve", request.AttemptId, key, payload, ct);
        if (replay is not null) return replay;
        // The arithmetic predicate and update execute together; SQL retains the write lock until receipt commit.
        var affected = await db.SaviaBalances.Where(x => x.VariantId == request.VariantId && x.LocationId == request.LocationId
            && x.Mode == Authority.Mode && x.InstanceId == Authority.InstanceId && x.Epoch == Authority.Epoch
            && x.OnHand - x.Reserved >= request.Quantity)
            .ExecuteUpdateAsync(s => s.SetProperty(x => x.Reserved, x => x.Reserved + request.Quantity), ct);
        if (affected != 1)
        {
            var error = !await db.SaviaBalances.AnyAsync(x => x.VariantId == request.VariantId, ct) ? "unknown_variant"
                : !await db.SaviaBalances.AnyAsync(x => x.VariantId == request.VariantId && x.LocationId == request.LocationId, ct) ? "unknown_location"
                : await db.SaviaBalances.AnyAsync(x => x.VariantId == request.VariantId && x.LocationId == request.LocationId && (x.Mode != Authority.Mode || x.InstanceId != Authority.InstanceId || x.Epoch != Authority.Epoch), ct) ? "authority_mismatch" : "out_of_stock";
            return await Complete<SaviaReservationReceipt>("reserve", request.AttemptId, key, payload, null, error, tx, ct);
        }
        var balance = await db.SaviaBalances.AsNoTracking().SingleAsync(x => x.VariantId == request.VariantId && x.LocationId == request.LocationId, ct);
        var now = DateTimeOffset.UtcNow;
        var receipt = new SaviaReservationReceipt(Guid.NewGuid(), balance.VariantId, balance.LocationId, request.Quantity,
            balance.UnitPriceMinor, balance.Currency, checked(balance.UnitPriceMinor * request.Quantity), "active", request.AttemptId, Authority, now, true);
        db.SaviaReservations.Add(new SaviaReservation
        {
            Id = receipt.ReservationId, VariantId = receipt.VariantId, LocationId = receipt.LocationId, Quantity = receipt.Quantity,
            UnitPriceMinor = receipt.UnitPriceMinor, Currency = receipt.Currency, TotalMinor = receipt.TotalMinor,
            State = "active", CreateAttemptId = request.AttemptId, CreatedAt = now, CreationJson = JsonSerializer.Serialize(receipt, Json)
        });
        db.SaviaMovements.Add(Movement(receipt.ReservationId, request.AttemptId, balance.VariantId, balance.LocationId, "reserve", request.Quantity, now));
        return await Complete("reserve", request.AttemptId, key, payload, receipt, null, tx, ct);
    }

    public async Task<SaviaReservationView?> GetReservation(Guid id, CancellationToken ct)
    {
        var reservation = await db.SaviaReservations.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, ct);
        return reservation is null ? null : new(Read<SaviaReservationReceipt>(reservation.CreationJson), reservation.State, reservation.CancelledAt);
    }
    public async Task<SaviaResult<SaviaCancellationReceipt>> Cancel(Guid reservationId, SaviaCancelRequest request, string key, CancellationToken ct)
    {
        if (request.Authority != Authority) return new(null, "authority_mismatch");
        if (!ValidKey(key) || reservationId == Guid.Empty || request.AttemptId == Guid.Empty) return new(null, "invalid_request");
        var payload = JsonSerializer.Serialize(new SaviaCancelPayload(reservationId, request.AttemptId, request.Authority), Json);
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        await LockIdentities("cancel", request.AttemptId, key, tx, ct);
        var replay = await Replay<SaviaCancellationReceipt>("cancel", request.AttemptId, key, payload, ct);
        if (replay is not null) return replay;
        await Lock("reservation:" + reservationId.ToString("D"), tx, ct);
        var reservation = await db.SaviaReservations.AsNoTracking().SingleOrDefaultAsync(x => x.Id == reservationId, ct);
        if (reservation is null) return await Complete<SaviaCancellationReceipt>("cancel", request.AttemptId, key, payload, null, "reservation_not_found", tx, ct);
        var now = DateTimeOffset.UtcNow;
        var released = 0;
        if (reservation.State == "active")
        {
            if (await db.SaviaReservations.Where(x => x.Id == reservationId && x.State == "active")
                .ExecuteUpdateAsync(s => s.SetProperty(x => x.State, "cancelled").SetProperty(x => x.CancelledAt, now), ct) != 1)
                throw new StorageUnavailableException();
            if (await db.SaviaBalances.Where(x => x.VariantId == reservation.VariantId && x.LocationId == reservation.LocationId
                && x.Mode == Authority.Mode && x.InstanceId == Authority.InstanceId && x.Epoch == Authority.Epoch && x.Reserved >= reservation.Quantity)
                .ExecuteUpdateAsync(s => s.SetProperty(x => x.Reserved, x => x.Reserved - reservation.Quantity), ct) != 1)
                throw new StorageUnavailableException();
            released = reservation.Quantity;
            db.SaviaMovements.Add(Movement(reservationId, request.AttemptId, reservation.VariantId, reservation.LocationId, "cancel", -released, now));
        }
        else if (reservation.State != "cancelled") throw new StorageUnavailableException();
        var receipt = new SaviaCancellationReceipt(reservationId, request.AttemptId, released == 0 ? "already_cancelled" : "cancelled", released, Authority, now, true);
        return await Complete("cancel", request.AttemptId, key, payload, receipt, null, tx, ct);
    }

    public async Task<SaviaAttemptReceipt?> GetAttempt(string operation, Guid attemptId, CancellationToken ct)
    {
        if (operation is not ("reserve" or "cancel") || attemptId == Guid.Empty) return null;
        var attempt = await db.SaviaAttempts.AsNoTracking().SingleOrDefaultAsync(x => x.AttemptId == attemptId && x.Operation == operation, ct);
        return attempt is null ? null : new(attempt.Operation, attempt.AttemptId, new(attempt.Mode, attempt.InstanceId, attempt.Epoch), attempt.Outcome,
            attempt.ResultJson is null ? null : JsonSerializer.Deserialize<JsonElement>(attempt.ResultJson, Json), attempt.Error, attempt.CreatedAt);
    }
    public async Task<IReadOnlyList<SaviaMovementResponse>> Movements(CancellationToken ct) =>
        (await db.SaviaMovements.AsNoTracking().OrderBy(x => x.CreatedAt).ThenBy(x => x.Id).ToListAsync(ct))
        .Select(x => new SaviaMovementResponse(x.Id, x.ReservationId, x.AttemptId, x.VariantId, x.LocationId, x.Kind, x.OnHandDelta, x.ReservedDelta,
            new(x.Mode, x.InstanceId, x.Epoch), x.CreatedAt, true)).ToList();

    private static SaviaMovement Movement(Guid reservationId, Guid attemptId, Guid variantId, Guid locationId, string kind, int delta, DateTimeOffset now) =>
        new() { Id = Guid.NewGuid(), ReservationId = reservationId, AttemptId = attemptId, VariantId = variantId, LocationId = locationId, Kind = kind, OnHandDelta = 0, ReservedDelta = delta, CreatedAt = now };
    private static T Read<T>(string json) => JsonSerializer.Deserialize<T>(json, Json) ?? throw new StorageUnavailableException();
    private async Task<SaviaResult<T>?> Replay<T>(string operation, Guid attemptId, string key, string payload, CancellationToken ct)
    {
        var attempt = await db.SaviaAttempts.AsNoTracking().SingleOrDefaultAsync(x => x.AttemptId == attemptId, ct);
        if (attempt is not null)
            return attempt.Operation == operation && attempt.IdempotencyKey == key && attempt.CanonicalPayload == payload && attempt.Mode == Authority.Mode && attempt.InstanceId == Authority.InstanceId && attempt.Epoch == Authority.Epoch
                ? new(attempt.ResultJson is null ? default : Read<T>(attempt.ResultJson), attempt.Error) : new(default, attempt.Operation == operation && attempt.IdempotencyKey == key ? "idempotency_conflict" : "attempt_conflict");
        return await db.SaviaAttempts.AnyAsync(x => x.Operation == operation && x.IdempotencyKey == key, ct) ? new(default, "idempotency_conflict") : null;
    }
    private async Task<SaviaResult<T>> Complete<T>(string operation, Guid attemptId, string key, string payload, T? value, string? error, IDbContextTransaction tx, CancellationToken ct)
    {
        db.SaviaAttempts.Add(new SaviaAttempt { AttemptId = attemptId, Operation = operation, IdempotencyKey = key, CanonicalPayload = payload,
            Outcome = error is null ? "succeeded" : "rejected", ResultJson = value is null ? null : JsonSerializer.Serialize(value, Json), Error = error, CreatedAt = DateTimeOffset.UtcNow });
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return new(value, error);
    }
    private async Task LockIdentities(string operation, Guid attemptId, string key, IDbContextTransaction tx, CancellationToken ct)
    {
        // Both identities lock in one stable order. A GUID cannot be rebound to a key or operation.
        foreach (var resource in new[] { "attempt:" + attemptId.ToString("D"), "key:" + operation + ":" + key }.Order(StringComparer.Ordinal))
            await Lock(resource, tx, ct);
    }
    private async Task Lock(string identity, IDbContextTransaction tx, CancellationToken ct)
    {
        await using var command = db.Database.GetDbConnection().CreateCommand();
        command.Transaction = tx.GetDbTransaction();
        command.CommandText = "DECLARE @r int; EXEC @r = sys.sp_getapplock @Resource=@resource, @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=15000; SELECT @r;";
        var parameter = command.CreateParameter(); parameter.ParameterName = "@resource";
        parameter.Value = "savia-v2:" + Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(identity))); command.Parameters.Add(parameter);
        if (Convert.ToInt32(await command.ExecuteScalarAsync(ct)) < 0) throw new StorageUnavailableException();
    }
}
