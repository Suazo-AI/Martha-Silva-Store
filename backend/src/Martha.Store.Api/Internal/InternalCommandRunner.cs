using System.Data;
using System.Data.Common;
using System.Security.Claims;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
namespace Martha.Store.Api.Internal;

public sealed class InternalOperation
{
    public Guid Id { get; set; }
    public Guid ActorId { get; set; }
    public string Scope { get; set; } = "";
    public string Key { get; set; } = "";
    public string Fingerprint { get; set; } = "";
    public string ResultJson { get; set; } = "";
    public DateTimeOffset CreatedAt { get; set; }
}

public static class InternalCommandAuthorization
{
    public static bool Allowed(ClaimsPrincipal principal, string scope)
    {
        string[] roles = scope switch
        {
            "directory.items.create" or "directory.items.update" or "directory.items.deactivate"
            or "directory.locations.create" or "directory.locations.update" or "directory.locations.deactivate"
            or "directory.parties.create" or "directory.parties.update" or "directory.parties.deactivate"
            or "supply.purchase.create" or "supply.purchase.cancel"
            or "commerce.sale.cancel" or "commerce.sale.return" => ["Owner", "Manager"],
            "commerce.stock.adjust" or "supply.receipt.create" => ["Owner", "Manager", "Inventory"],
            "commerce.sale.record" => ["Owner", "Manager", "Cashier"],
            _ => []
        };
        return principal.Identity?.IsAuthenticated == true && roles.Any(principal.IsInRole);
    }
}

public sealed class InternalCommandRunner(InternalDbContext db, InternalSecurityService security,
    IHttpContextAccessor http, TimeProvider time) : IInternalCommandRunner
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    public async Task<InternalResult<T>> Run<T>(Guid actorId, string scope, string key, string fingerprint,
        Func<CancellationToken, Task<InternalResult<T>>> action, CancellationToken ct)
    {
        if (actorId == Guid.Empty || !InternalRules.ValidKey(key) || scope is not { Length: >= 1 and <= 80 }
            || fingerprint is not { Length: 64 } || !fingerprint.All(Uri.IsHexDigit))
            return InternalResult<T>.Fail("invalid_request");
        var principal = http.HttpContext?.User;
        if (principal?.Identity?.IsAuthenticated != true || InternalActor.Id(principal) != actorId)
            return InternalResult<T>.Fail("unauthenticated");
        if (!InternalCommandAuthorization.Allowed(principal, scope)) return InternalResult<T>.Fail("forbidden");
        if (!db.Database.IsSqlServer()) return InternalResult<T>.Fail("storage_unavailable");
        bool actionStarted = false;
        try
        {
            await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            // Validate persisted session and current role in the SAME transaction as the business write.
            var current = await security.ValidateSession(principal, ct);
            if (current is null || InternalActor.Id(current) != actorId) return InternalResult<T>.Fail("unauthenticated");
            if (!InternalCommandAuthorization.Allowed(current, scope)) return InternalResult<T>.Fail("forbidden");
            // Serialize the exact identity; SQL uniqueness uses binary collation with identical case semantics.
            var resource = "SaviaInternal:op:" + InternalRules.Fingerprint(new { actorId, scope, key });
            await using (var command = db.Database.GetDbConnection().CreateCommand())
            {
                command.Transaction = transaction.GetDbTransaction();
                command.CommandTimeout = 30;
                command.CommandText = "DECLARE @result int; EXEC @result=sys.sp_getapplock @Resource=@resource,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000; SELECT @result;";
                var parameter = command.CreateParameter(); parameter.ParameterName = "@resource"; parameter.Value = resource; command.Parameters.Add(parameter);
                var result = Convert.ToInt32(await command.ExecuteScalarAsync(ct));
                if (result < 0) return InternalResult<T>.Fail("storage_unavailable");
            }
            var prior = await db.Set<InternalOperation>().AsNoTracking()
                .SingleOrDefaultAsync(x => x.ActorId == actorId && x.Scope == scope && x.Key == key, ct);
            if (prior is not null)
                return prior.Fingerprint != fingerprint ? InternalResult<T>.Fail("idempotency_conflict")
                    : JsonSerializer.Deserialize<InternalResult<T>>(prior.ResultJson, Json)
                      ?? InternalResult<T>.Fail("unknown_outcome");
            await transaction.CreateSavepointAsync("BeforeInternalAction", ct);
            actionStarted = true;
            var outcome = await action(ct);
            if (!outcome.Success)
            {
                // Rejection is durable, but NONE of its partially tracked or persisted effects may survive.
                await transaction.RollbackToSavepointAsync("BeforeInternalAction", ct);
                db.ChangeTracker.Clear();
            }
            db.Set<InternalOperation>().Add(new InternalOperation
            {
                Id = Guid.NewGuid(), ActorId = actorId, Scope = scope, Key = key, Fingerprint = fingerprint,
                ResultJson = JsonSerializer.Serialize(outcome, Json), CreatedAt = time.GetUtcNow()
            });
            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
            return outcome;
        }
        catch (OperationCanceledException) when (ct.IsCancellationRequested) { throw; }
        catch (Exception ex) when (ex is DbException or DbUpdateException or StorageUnavailableException or JsonException)
        {
            db.ChangeTracker.Clear();
            // An interrupted write/commit is not proof of rollback. Reconcile with the SAME operation identity.
            return InternalResult<T>.Fail(actionStarted ? "unknown_outcome" : "storage_unavailable");
        }
    }
}
