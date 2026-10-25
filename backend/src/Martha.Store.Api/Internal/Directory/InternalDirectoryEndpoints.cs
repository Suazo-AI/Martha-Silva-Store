using System.Data.Common;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.EntityFrameworkCore;

namespace Martha.Store.Api.Internal;

public static class InternalDirectoryEndpoints
{
    public static IEndpointRouteBuilder MapInternalDirectory(this IEndpointRouteBuilder endpoints)
    {
        var directory = endpoints.MapGroup("/internal/api/directory").RequireAuthorization("internal.read")
            .AddEndpointFilter(async (context, next) =>
            {
                context.HttpContext.Response.Headers.CacheControl = "no-store";
                if (!context.HttpContext.Request.IsHttps) return Error("https_required", 400);
                return await next(context);
            });
        directory.MapGet("/items", ListItems);
        directory.MapGet("/locations", ListLocations);
        directory.MapGet("/parties", ListParties);
        directory.MapGet("/items/{id:guid}", (Guid id, InternalDbContext db, CancellationToken ct) =>
            ReadOne<InternalItem, InternalItemView>(id, db, InternalDirectoryService.View, ct));
        directory.MapGet("/locations/{id:guid}", (Guid id, InternalDbContext db, CancellationToken ct) =>
            ReadOne<InternalLocation, InternalLocationView>(id, db, InternalDirectoryService.View, ct));
        directory.MapGet("/parties/{id:guid}", (Guid id, InternalDbContext db, CancellationToken ct) =>
            ReadOne<InternalParty, InternalPartyView>(id, db, InternalDirectoryService.View, ct));

        Protect(directory.MapPost("/items", async (InternalItemWrite request, HttpContext http, InternalDbContext db, IInternalCommandRunner runner, CancellationToken ct) =>
            Result(await new InternalDirectoryService(db, runner).SaveItem(null, request, InternalActor.Id(http.User), Key(http), ct), true)));
        Protect(directory.MapPut("/items/{id:guid}", async (Guid id, InternalItemWrite request, HttpContext http, InternalDbContext db, IInternalCommandRunner runner, CancellationToken ct) =>
            Result(await new InternalDirectoryService(db, runner).SaveItem(id, request, InternalActor.Id(http.User), Key(http), ct))));
        Protect(directory.MapDelete("/items/{id:guid}", async (Guid id, HttpContext http, InternalDbContext db, IInternalCommandRunner runner, CancellationToken ct) =>
            Result(await new InternalDirectoryService(db, runner).DeactivateItem(id, InternalActor.Id(http.User), Key(http), ct))));
        Protect(directory.MapPost("/locations", async (InternalLocationWrite request, HttpContext http, InternalDbContext db, IInternalCommandRunner runner, CancellationToken ct) =>
            Result(await new InternalDirectoryService(db, runner).SaveLocation(null, request, InternalActor.Id(http.User), Key(http), ct), true)));
        Protect(directory.MapPut("/locations/{id:guid}", async (Guid id, InternalLocationWrite request, HttpContext http, InternalDbContext db, IInternalCommandRunner runner, CancellationToken ct) =>
            Result(await new InternalDirectoryService(db, runner).SaveLocation(id, request, InternalActor.Id(http.User), Key(http), ct))));
        Protect(directory.MapDelete("/locations/{id:guid}", async (Guid id, HttpContext http, InternalDbContext db, IInternalCommandRunner runner, CancellationToken ct) =>
            Result(await new InternalDirectoryService(db, runner).DeactivateLocation(id, InternalActor.Id(http.User), Key(http), ct))));
        Protect(directory.MapPost("/parties", async (InternalPartyWrite request, HttpContext http, InternalDbContext db, IInternalCommandRunner runner, CancellationToken ct) =>
            Result(await new InternalDirectoryService(db, runner).SaveParty(null, request, InternalActor.Id(http.User), Key(http), ct), true)));
        Protect(directory.MapPut("/parties/{id:guid}", async (Guid id, InternalPartyWrite request, HttpContext http, InternalDbContext db, IInternalCommandRunner runner, CancellationToken ct) =>
            Result(await new InternalDirectoryService(db, runner).SaveParty(id, request, InternalActor.Id(http.User), Key(http), ct))));
        Protect(directory.MapDelete("/parties/{id:guid}", async (Guid id, HttpContext http, InternalDbContext db, IInternalCommandRunner runner, CancellationToken ct) =>
            Result(await new InternalDirectoryService(db, runner).DeactivateParty(id, InternalActor.Id(http.User), Key(http), ct))));
        return endpoints;
    }

    private static void Protect(RouteHandlerBuilder route) => route.RequireAuthorization("internal.manage")
        .WithMetadata(new InternalDirectoryMutationMetadata())
        .AddEndpointFilter<InternalDirectoryMutationFilter>();

    private static string Key(HttpContext http) => http.Request.Headers["Idempotency-Key"].ToString();

    private static Task<IResult> ListItems(InternalDbContext db, string? q, bool? includeInactive, int? skip, int? take, CancellationToken ct) => Read(async () =>
    {
        var offset = skip ?? 0;
        var limit = take ?? 50;
        if (!InternalDirectoryValidation.Query(q, offset, limit, out var search)) return Error("invalid_request", 400);
        var query = db.Set<InternalItem>().AsNoTracking().Where(x => includeInactive == true || x.Active);
        if (search is not null) query = query.Where(x => x.Name.Contains(search) || x.Sku.Contains(search.ToUpperInvariant()));
        var total = await query.CountAsync(ct);
        var items = await query.OrderBy(x => x.Name).ThenBy(x => x.Id).Skip(offset).Take(limit)
            .Select(x => new InternalItemView(x.Id, x.Sku, x.Name, x.UnitPriceMinor, x.Currency, x.Active)).ToListAsync(ct);
        return Results.Ok(new InternalDirectoryPage<InternalItemView>(items, total, offset, limit));
    });

    private static Task<IResult> ListLocations(InternalDbContext db, string? q, bool? includeInactive, int? skip, int? take, CancellationToken ct) => Read(async () =>
    {
        var offset = skip ?? 0;
        var limit = take ?? 50;
        if (!InternalDirectoryValidation.Query(q, offset, limit, out var search)) return Error("invalid_request", 400);
        var query = db.Set<InternalLocation>().AsNoTracking().Where(x => includeInactive == true || x.Active);
        if (search is not null) query = query.Where(x => x.Name.Contains(search));
        var total = await query.CountAsync(ct);
        var locations = await query.OrderBy(x => x.Name).ThenBy(x => x.Id).Skip(offset).Take(limit)
            .Select(x => new InternalLocationView(x.Id, x.Name, x.Active)).ToListAsync(ct);
        return Results.Ok(new InternalDirectoryPage<InternalLocationView>(locations, total, offset, limit));
    });

    private static Task<IResult> ListParties(InternalDbContext db, string? q, string? kind, bool? includeInactive, int? skip, int? take, CancellationToken ct) => Read(async () =>
    {
        var offset = skip ?? 0;
        var limit = take ?? 50;
        if (!InternalDirectoryValidation.Query(q, offset, limit, out var search) || kind is not (null or "customer" or "supplier"))
            return Error("invalid_request", 400);
        var query = db.Set<InternalParty>().AsNoTracking().Where(x => includeInactive == true || x.Active);
        if (kind is not null) query = query.Where(x => x.Kind == kind);
        if (search is not null) query = query.Where(x => x.Name.Contains(search) || (x.Email != null && x.Email.Contains(search)) || (x.Phone != null && x.Phone.Contains(search)));
        var total = await query.CountAsync(ct);
        var parties = await query.OrderBy(x => x.Name).ThenBy(x => x.Id).Skip(offset).Take(limit)
            .Select(x => new InternalPartyView(x.Id, x.Kind, x.Name, x.Email, x.Phone, x.Active)).ToListAsync(ct);
        return Results.Ok(new InternalDirectoryPage<InternalPartyView>(parties, total, offset, limit));
    });

    private static Task<IResult> ReadOne<TEntity, TView>(Guid id, InternalDbContext db, Func<TEntity, TView> view, CancellationToken ct) where TEntity : class => Read(async () =>
    {
        if (id == Guid.Empty) return Error("invalid_request", 400);
        var entity = await db.Set<TEntity>().AsNoTracking().SingleOrDefaultAsync(x => EF.Property<Guid>(x, "Id") == id, ct);
        return entity is null ? Error("not_found", 404) : Results.Ok(view(entity));
    });

    private static async Task<IResult> Read(Func<Task<IResult>> query)
    {
        try { return await query(); }
        catch (DbException) { return Error("storage_unavailable", 503); }
        catch (DbUpdateException) { return Error("storage_unavailable", 503); }
    }

    private static IResult Result<T>(InternalResult<T> result, bool created = false)
    {
        if (result.Success) return Results.Json(result.Value, statusCode: created ? 201 : 200);
        return Error(result.Error!, result.Error switch
        {
            "not_found" => 404,
            "duplicate_sku" or "party_kind_immutable" or "key_conflict" or "idempotency_conflict" or "conflict" => 409,
            "invalid_request" or "invalid_key" => 400,
            "unauthorized" or "unauthenticated" => 401,
            "forbidden" => 403,
            _ => 503
        });
    }

    public static IResult Error(string code, int status) => Results.Problem(statusCode: status,
        title: "The directory request could not be completed.", extensions: new Dictionary<string, object?> { ["code"] = code });
}

// Testable metadata advertises the explicit CSRF filter without falsely relying on
// automatic form-only antiforgery behavior for JSON requests.
public sealed record InternalDirectoryMutationMetadata;

public sealed class InternalDirectoryMutationFilter(IAntiforgery antiforgery) : IEndpointFilter
{
    public async ValueTask<object?> InvokeAsync(EndpointFilterInvocationContext context, EndpointFilterDelegate next)
    {
        var http = context.HttpContext;
        if (http.User.Identity?.IsAuthenticated != true) return InternalDirectoryEndpoints.Error("unauthorized", 401);
        try { _ = InternalActor.Id(http.User); }
        catch (UnauthorizedAccessException) { return InternalDirectoryEndpoints.Error("unauthorized", 401); }
        try { await antiforgery.ValidateRequestAsync(http); }
        catch (AntiforgeryValidationException) { return InternalDirectoryEndpoints.Error("invalid_csrf", 400); }
        var keys = http.Request.Headers["Idempotency-Key"];
        if (keys.Count != 1 || !InternalRules.ValidKey(keys[0])) return InternalDirectoryEndpoints.Error("invalid_key", 400);
        return await next(context);
    }
}
