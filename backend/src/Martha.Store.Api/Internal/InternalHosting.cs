using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
namespace Martha.Store.Api.Internal;

public static partial class InternalDatabaseGuard
{
    public static void Validate(string connection)
    {
        SqlConnectionStringBuilder parsed;
        try { parsed = new SqlConnectionStringBuilder(connection); }
        catch (ArgumentException) { throw new StorageUnavailableException(); }
        // Naming prevents accidents; it never establishes permission to operate this server.
        if (!InternalTestName().IsMatch(parsed.InitialCatalog) || parsed.MultipleActiveResultSets)
            throw new StorageUnavailableException();
    }
    [GeneratedRegex(@"\ASaviaInternalTest_[A-Za-z0-9_]{1,64}\z", RegexOptions.CultureInvariant)]
    private static partial Regex InternalTestName();
}

public static class InternalHosting
{
    public static IServiceCollection AddPrivateSavia(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddHttpContextAccessor();
        services.AddDbContext<InternalDbContext>(options =>
        {
            var connection = configuration.GetConnectionString("InternalSavia");
            if (string.IsNullOrWhiteSpace(connection)) throw new StorageUnavailableException();
            InternalDatabaseGuard.Validate(connection);
            options.UseSqlServer(connection, sql => sql.CommandTimeout(30));
        });
        services.AddInternalSecurity();
        services.AddScoped<IInternalCommandRunner, InternalCommandRunner>();
        services.AddInternalCommerce();
        services.AddInternalSupply();
        return services;
    }

    public static IEndpointRouteBuilder MapPrivateSavia(this IEndpointRouteBuilder routes)
    {
        routes.MapInternalSecurity(); routes.MapInternalDirectory(); routes.MapInternalCommerce(); routes.MapInternalSupply();
        // Existing /health/ready belongs to the legacy synthetic context; do not silently redefine it.
        routes.MapGet("/internal/api/readiness", async (HttpContext http, InternalDbContext db, CancellationToken ct) =>
        {
            if (!db.Database.GetMigrations().Any() || !await db.Database.CanConnectAsync(ct)
                || (await db.Database.GetPendingMigrationsAsync(ct)).Any())
                return ApiError.Result(http, 503, "storage_unavailable");
            // Probe actual private tables, not only a connection or migration-history table.
            await db.Set<InternalStaff>().AsNoTracking().Select(x => x.Id).Take(1).ToListAsync(ct);
            await db.Set<InternalItem>().AsNoTracking().Select(x => x.Id).Take(1).ToListAsync(ct);
            await db.Set<InternalOperation>().AsNoTracking().Select(x => x.Id).Take(1).ToListAsync(ct);
            await db.Set<InternalStockBalance>().AsNoTracking().Take(1).ToListAsync(ct);
            await db.Set<InternalSale>().AsNoTracking().Select(x => x.Id).Take(1).ToListAsync(ct);
            await db.Set<InternalPurchaseOrder>().AsNoTracking().Select(x => x.Id).Take(1).ToListAsync(ct);
            return Results.Ok(new { status = "ready", scope = "internal", paymentProcessing = false });
        }).RequireAuthorization("internal.read");
        routes.MapGet("/internal/api/operations/{scope}", async (string scope, HttpContext http, InternalDbContext db, InternalSecurityService security, CancellationToken ct) =>
        {
            var keys = http.Request.Headers["Idempotency-Key"];
            if (keys.Count != 1 || !InternalRules.ValidKey(keys[0])) return ApiError.Result(http, 400, "invalid_request");
            if (!InternalCommandAuthorization.Allowed(http.User, scope)) return ApiError.Result(http, 403, "forbidden");
            await using var transaction = await db.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable, ct);
            var current = await security.ValidateSession(http.User, ct);
            if (current is null) return ApiError.Result(http, 401, "unauthenticated");
            if (!InternalCommandAuthorization.Allowed(current, scope)) return ApiError.Result(http, 403, "forbidden");
            var actorId = InternalActor.Id(current); var key = keys[0]!;
            var operation = await db.Set<InternalOperation>().AsNoTracking().SingleOrDefaultAsync(x => x.ActorId == actorId && x.Scope == scope && x.Key == key, ct);
            if (operation is null) return ApiError.Result(http, 404, "operation_unknown");
            if (!await new InternalBranchAccess(db).CanReadOperation(actorId, operation, ct))
                return ApiError.Result(http, 403, "forbidden");
            using var json = JsonDocument.Parse(operation.ResultJson);
            return Results.Ok(new { status = "completed", result = json.RootElement.Clone() });
        }).RequireAuthorization("internal.read");
        return routes;
    }
}
