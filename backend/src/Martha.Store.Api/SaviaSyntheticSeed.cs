using System.Text.Json;
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
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
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
        else Validate(balances, reservations, attempts, movements);
        await tx.CommitAsync();
    }

    private static void Validate(List<SaviaBalance> balances, List<SaviaReservation> reservations, List<SaviaAttempt> attempts, List<SaviaMovement> movements)
    {
        Require(balances.Count == 1);
        var balance = balances[0];
        Require(balance.VariantId == VariantId && balance.LocationId == LocationId && IsAuthority(balance.Mode, balance.InstanceId, balance.Epoch)
            && balance.Sku == Sku && balance.Name == Name && balance.UnitPriceMinor == 1250 && balance.Currency == "XXX" && balance.OnHand == 5
            && balance.Reserved >= 0 && balance.Reserved <= balance.OnHand);
        Require(reservations.Where(x => x.State == "active").Sum(x => (long)x.Quantity) == balance.Reserved
            && movements.Sum(x => (long)x.ReservedDelta) == balance.Reserved);
        foreach (var reservation in reservations)
        {
            Require(reservation.VariantId == VariantId && reservation.LocationId == LocationId && reservation.Quantity is >= 1 and <= 100
                && reservation.UnitPriceMinor == 1250 && reservation.Currency == "XXX" && reservation.TotalMinor == 1250L * reservation.Quantity
                && (reservation.State == "active" && reservation.CancelledAt is null || reservation.State == "cancelled" && reservation.CancelledAt is not null));
            var expected = new SaviaReservationReceipt(reservation.Id, VariantId, LocationId, reservation.Quantity, 1250, "XXX", reservation.TotalMinor,
                "active", reservation.CreateAttemptId, SaviaService.Authority, reservation.CreatedAt, true);
            Require(Parse<SaviaReservationReceipt>(reservation.CreationJson) == expected && JsonSerializer.Serialize(expected, Json) == reservation.CreationJson);
            Require(attempts.Count(a => a.AttemptId == reservation.CreateAttemptId && a.Operation == "reserve" && a.Outcome == "succeeded" && a.ResultJson == reservation.CreationJson) == 1);
            Require(movements.Count(m => m.ReservationId == reservation.Id && m.Kind == "reserve" && m.ReservedDelta == reservation.Quantity && m.AttemptId == reservation.CreateAttemptId && m.CreatedAt == reservation.CreatedAt) == 1);
            Require(movements.Count(m => m.ReservationId == reservation.Id && m.Kind == "cancel" && m.ReservedDelta == -reservation.Quantity && m.CreatedAt == reservation.CancelledAt) == (reservation.State == "cancelled" ? 1 : 0));
        }
        foreach (var movement in movements)
        {
            Require(movement.OnHandDelta == 0 && movement.VariantId == VariantId && movement.LocationId == LocationId && IsAuthority(movement.Mode, movement.InstanceId, movement.Epoch)
                && reservations.Count(r => r.Id == movement.ReservationId) == 1
                && attempts.Count(a => a.AttemptId == movement.AttemptId && a.Operation == movement.Kind && a.Outcome == "succeeded") == 1);
            var reservation = reservations.Single(r => r.Id == movement.ReservationId);
            Require(movement.Kind == "reserve" && movement.ReservedDelta == reservation.Quantity || movement.Kind == "cancel" && movement.ReservedDelta == -reservation.Quantity);
        }
        foreach (var attempt in attempts)
        {
            Require(IsAuthority(attempt.Mode, attempt.InstanceId, attempt.Epoch) && attempt.AttemptId != Guid.Empty && SaviaService.ValidKey(attempt.IdempotencyKey));
            Guid requestedReservation = Guid.Empty;
            SaviaReserveRequest? reserve = null;
            if (attempt.Operation == "reserve")
            {
                reserve = Parse<SaviaReserveRequest>(attempt.CanonicalPayload);
                Require(SaviaService.ValidRequest(reserve) && reserve.AttemptId == attempt.AttemptId && reserve.Authority == SaviaService.Authority
                    && JsonSerializer.Serialize(reserve, Json) == attempt.CanonicalPayload);
            }
            else
            {
                Require(attempt.Operation == "cancel");
                var cancel = Parse<SaviaCancelPayload>(attempt.CanonicalPayload);
                Require(cancel.ReservationId != Guid.Empty && cancel.AttemptId == attempt.AttemptId && cancel.Authority == SaviaService.Authority
                    && JsonSerializer.Serialize(cancel, Json) == attempt.CanonicalPayload);
                requestedReservation = cancel.ReservationId;
            }
            var ownMovements = movements.Where(x => x.AttemptId == attempt.AttemptId).ToList();
            if (attempt.Outcome == "rejected")
            {
                Require(attempt.ResultJson is null && ownMovements.Count == 0 && !reservations.Any(x => x.CreateAttemptId == attempt.AttemptId));
                Require(attempt.Operation == "reserve" ? attempt.Error is "unknown_variant" or "unknown_location" or "out_of_stock" or "authority_mismatch" : attempt.Error == "reservation_not_found");
                continue;
            }
            Require(attempt.Outcome == "succeeded" && attempt.Error is null && attempt.ResultJson is not null);
            if (attempt.Operation == "reserve")
            {
                var receipt = Parse<SaviaReservationReceipt>(attempt.ResultJson!);
                Require(reservations.Count(r => r.Id == receipt.ReservationId && r.CreateAttemptId == attempt.AttemptId && r.CreationJson == attempt.ResultJson) == 1
                    && reserve is not null && receipt.VariantId == reserve.VariantId && receipt.LocationId == reserve.LocationId && receipt.Quantity == reserve.Quantity
                    && receipt.AttemptId == attempt.AttemptId && receipt.Authority == SaviaService.Authority && receipt.Status == "active" && receipt.Synthetic
                    && ownMovements.Count == 1 && ownMovements[0].Kind == "reserve" && ownMovements[0].ReservationId == receipt.ReservationId && ownMovements[0].ReservedDelta == receipt.Quantity);
            }
            else
            {
                var receipt = Parse<SaviaCancellationReceipt>(attempt.ResultJson!);
                Require(JsonSerializer.Serialize(receipt, Json) == attempt.ResultJson);
                Require(receipt.ReservationId == requestedReservation && receipt.AttemptId == attempt.AttemptId && receipt.Authority == SaviaService.Authority && receipt.Synthetic
                    && reservations.Count(r => r.Id == receipt.ReservationId && r.State == "cancelled") == 1);
                var reservation = reservations.Single(r => r.Id == receipt.ReservationId);
                Require(receipt.Status == "cancelled"
                    ? receipt.ReleasedQuantity == reservation.Quantity && receipt.CancelledAt == reservation.CancelledAt && ownMovements.Count == 1 && ownMovements[0].Kind == "cancel" && ownMovements[0].ReservationId == receipt.ReservationId && ownMovements[0].ReservedDelta == -receipt.ReleasedQuantity && ownMovements[0].CreatedAt == receipt.CancelledAt
                    : receipt.Status == "already_cancelled" && receipt.ReleasedQuantity == 0 && ownMovements.Count == 0);
            }
        }
    }
    private static bool IsAuthority(string mode, string instanceId, int epoch) => mode == "savia" && instanceId == "savia-synthetic-v2" && epoch == 1;
    private static T Parse<T>(string json)
    {
        try { return JsonSerializer.Deserialize<T>(json, Json) ?? throw Inconsistent(); }
        catch (JsonException) { throw Inconsistent(); }
    }
    private static void Require(bool condition) { if (!condition) throw Inconsistent(); }
    private static InvalidOperationException Inconsistent() => new("SAVIA V2 fixture is partial or inconsistent; seed will not repair or replenish it.");
}
