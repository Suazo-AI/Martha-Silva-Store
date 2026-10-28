using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
namespace Martha.Store.Api.Internal;

public sealed record InternalResult<T>(T? Value, string? Error)
{
    public bool Success => Error is null;
    public static InternalResult<T> Ok(T value) => new(value, null);
    public static InternalResult<T> Fail(string error) => new(default, error);
}
public static class InternalActor
{
    public static Guid Id(ClaimsPrincipal principal) => Guid.TryParse(principal.FindFirstValue(ClaimTypes.NameIdentifier), out var id) && id != Guid.Empty
        ? id : throw new UnauthorizedAccessException();
}
public static class InternalRules
{
    public const long MaxMinor = 9_000_000_000_000;
    public static bool ValidKey(string? key) => key is { Length: >= 16 and <= 128 } && key.All(c => char.IsAsciiLetterOrDigit(c) || c is '-' or '_');
    public static bool ValidCurrency(string? value) => value is { Length: 3 } && value.All(c => c is >= 'A' and <= 'Z') && value != "XXX";
    public static string Fingerprint<T>(T value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(value))));
}
// Caller must own a SQL transaction on the same scoped InternalDbContext.
// Implementations must not commit here; availability changes must be conditional and atomic.
public interface IInternalStockLedger
{
    Task<InternalResult<bool>> Change(Guid itemId, Guid locationId, int onHandDelta, int reservedDelta,
        Guid actorId, Guid operationId, string kind, CancellationToken ct);
}
// Executes action and stores immutable replay response in ONE transaction. No silent retry/fallback.
public interface IInternalCommandRunner
{
    Task<InternalResult<T>> Run<T>(Guid actorId, string scope, string key, string fingerprint,
        Func<CancellationToken, Task<InternalResult<T>>> action, CancellationToken ct);
    // Older/fake runners must opt in; never silently drop resource authorization.
    Task<InternalResult<T>> RunScoped<T>(Guid actorId, string scope, string key, string fingerprint,
        InternalCommandResource resource, Func<CancellationToken, Task<InternalResult<T>>> action, CancellationToken ct)
        => Task.FromResult(InternalResult<T>.Fail("storage_unavailable"));
}
