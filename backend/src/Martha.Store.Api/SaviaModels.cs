using System.Text.Json;
using System.Text.Json.Serialization;

namespace Martha.Store.Api;

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record SaviaAuthority(string Mode, string InstanceId, int Epoch);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record SaviaReserveRequest(Guid VariantId, Guid LocationId, int Quantity, Guid AttemptId, SaviaAuthority Authority);
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record SaviaCancelRequest(Guid AttemptId, SaviaAuthority Authority);
public sealed record SaviaResult<T>(T? Value, string? Error);
public sealed record SaviaCatalogItem(Guid VariantId, Guid LocationId, string Sku, string Name, long UnitPriceMinor, string Currency, int OnHand, int Reserved, int Available, SaviaAuthority Authority, bool Synthetic);
public sealed record SaviaReservationReceipt(Guid ReservationId, Guid VariantId, Guid LocationId, int Quantity, long UnitPriceMinor, string Currency, long TotalMinor, string Status, Guid AttemptId, SaviaAuthority Authority, DateTimeOffset CreatedAt, bool Synthetic);
public sealed record SaviaReservationView(SaviaReservationReceipt Creation, string Status, DateTimeOffset? CancelledAt);
public sealed record SaviaCancellationReceipt(Guid ReservationId, Guid AttemptId, string Status, int ReleasedQuantity, SaviaAuthority Authority, DateTimeOffset CancelledAt, bool Synthetic);
public sealed record SaviaAttemptReceipt(string Operation, Guid AttemptId, SaviaAuthority Authority, string Outcome, JsonElement? Result, string? Error, DateTimeOffset CreatedAt);
public sealed record SaviaMovementResponse(Guid MovementId, Guid ReservationId, Guid AttemptId, Guid VariantId, Guid LocationId, string Kind, int OnHandDelta, int ReservedDelta, SaviaAuthority Authority, DateTimeOffset CreatedAt, bool Synthetic);

public sealed class SaviaBalance
{
    public Guid VariantId { get; set; }
    public Guid LocationId { get; set; }
    public string Mode { get; set; } = "savia";
    public string InstanceId { get; set; } = "savia-synthetic-v2";
    public int Epoch { get; set; } = 1;
    public string Sku { get; set; } = "";
    public string Name { get; set; } = "";
    public long UnitPriceMinor { get; set; }
    public string Currency { get; set; } = "XXX";
    public int OnHand { get; set; }
    public int Reserved { get; set; }
}
public sealed class SaviaReservation
{
    public Guid Id { get; set; }
    public Guid VariantId { get; set; }
    public Guid LocationId { get; set; }
    public int Quantity { get; set; }
    public long UnitPriceMinor { get; set; }
    public long TotalMinor { get; set; }
    public string Currency { get; set; } = "XXX";
    public string State { get; set; } = "active";
    public Guid CreateAttemptId { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? CancelledAt { get; set; }
    public string CreationJson { get; set; } = "";
}
public sealed class SaviaAttempt
{
    public Guid AttemptId { get; set; }
    public string Operation { get; set; } = "";
    public string IdempotencyKey { get; set; } = "";
    public string CanonicalPayload { get; set; } = "";
    public string Mode { get; set; } = "savia";
    public string InstanceId { get; set; } = "savia-synthetic-v2";
    public int Epoch { get; set; } = 1;
    public string Outcome { get; set; } = "";
    public string? ResultJson { get; set; }
    public string? Error { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}
public sealed class SaviaMovement
{
    public Guid Id { get; set; }
    public Guid ReservationId { get; set; }
    public Guid AttemptId { get; set; }
    public Guid VariantId { get; set; }
    public Guid LocationId { get; set; }
    public string Kind { get; set; } = "";
    public int OnHandDelta { get; set; }
    public int ReservedDelta { get; set; }
    public string Mode { get; set; } = "savia";
    public string InstanceId { get; set; } = "savia-synthetic-v2";
    public int Epoch { get; set; } = 1;
    public DateTimeOffset CreatedAt { get; set; }
}
