namespace Martha.Store.Api;

// The port never chooses another provider after a timeout or uncertain outcome.
public interface IErpPort
{
    SaviaAuthority? Authority { get; }
    ErpCapabilityReport Capabilities { get; }
    Task<IReadOnlyList<SaviaCatalogItem>> Catalog(CancellationToken ct);
    Task<SaviaResult<SaviaReservationReceipt>> Reserve(SaviaReserveRequest request, string key, CancellationToken ct);
    Task<SaviaReservationView?> GetReservation(Guid reservationId, CancellationToken ct);
    Task<SaviaResult<SaviaCancellationReceipt>> Cancel(Guid reservationId, SaviaCancelRequest request, string key, CancellationToken ct);
    Task<SaviaAttemptReceipt?> GetAttempt(string operation, Guid attemptId, CancellationToken ct);
    Task<IReadOnlyList<SaviaMovementResponse>> Movements(CancellationToken ct);
}

public sealed record ErpCapabilities(bool Catalog, bool Reserve, bool GetReservation, bool Cancel,
    bool AttemptLookup, bool Movements, bool Expiration, bool Sale, bool Shipment, bool Return, bool Payments);

public sealed record ErpCapabilityReport(string Mode, SaviaAuthority? Authority, string ImplementationStatus,
    string SqlVerification, ErpCapabilities Capabilities)
{
    // Implemented synthetic code is not evidence of a verified SQL runtime or commercial integration.
    public static ErpCapabilityReport Savia { get; } = new("savia", SaviaService.Authority,
        "synthetic_code_implemented", "not_verified", new(true, true, true, true, true, true, false, false, false, false, false));
    public static ErpCapabilityReport Cga { get; } = new("cga", null,
        "not_verified", "not_verified", new(false, false, false, false, false, false, false, false, false, false, false));
}

public sealed class SaviaErpAdapter(SaviaService service) : IErpPort
{
    public SaviaAuthority Authority => SaviaService.Authority;
    public ErpCapabilityReport Capabilities => ErpCapabilityReport.Savia;
    public Task<IReadOnlyList<SaviaCatalogItem>> Catalog(CancellationToken ct) => service.Catalog(ct);
    public Task<SaviaResult<SaviaReservationReceipt>> Reserve(SaviaReserveRequest request, string key, CancellationToken ct) => service.Reserve(request, key, ct);
    public Task<SaviaReservationView?> GetReservation(Guid reservationId, CancellationToken ct) => service.GetReservation(reservationId, ct);
    public Task<SaviaResult<SaviaCancellationReceipt>> Cancel(Guid reservationId, SaviaCancelRequest request, string key, CancellationToken ct) => service.Cancel(reservationId, request, key, ct);
    public Task<SaviaAttemptReceipt?> GetAttempt(string operation, Guid attemptId, CancellationToken ct) => service.GetAttempt(operation, attemptId, ct);
    public Task<IReadOnlyList<SaviaMovementResponse>> Movements(CancellationToken ct) => service.Movements(ct);
}

// Capability-only stub: no credentials, connection, HTTP route, registration, or write implementation.
public sealed class CgaCapabilityAdapter : IErpPort
{
    public SaviaAuthority? Authority => null;
    public ErpCapabilityReport Capabilities => ErpCapabilityReport.Cga;
    public Task<IReadOnlyList<SaviaCatalogItem>> Catalog(CancellationToken ct) => throw Unsupported();
    public Task<SaviaResult<SaviaReservationReceipt>> Reserve(SaviaReserveRequest request, string key, CancellationToken ct) => throw Unsupported();
    public Task<SaviaReservationView?> GetReservation(Guid reservationId, CancellationToken ct) => throw Unsupported();
    public Task<SaviaResult<SaviaCancellationReceipt>> Cancel(Guid reservationId, SaviaCancelRequest request, string key, CancellationToken ct) => throw Unsupported();
    public Task<SaviaAttemptReceipt?> GetAttempt(string operation, Guid attemptId, CancellationToken ct) => throw Unsupported();
    public Task<IReadOnlyList<SaviaMovementResponse>> Movements(CancellationToken ct) => throw Unsupported();
    private static NotSupportedException Unsupported() => new("CGA capabilities are not verified; no operation is supported.");
}
