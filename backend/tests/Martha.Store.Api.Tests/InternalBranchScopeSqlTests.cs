using System.Net;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Security.Claims;
using System.Text.Json;
using Martha.Store.Api.Internal;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Martha.Store.Api.Tests;

// BS cases exercise the production SQL queries/runner. Opt-in disposable SQL only.
// EnsureCreated and synthetic sessions do NOT prove migrations, cookie login or browser behavior.
public sealed class InternalBranchScopeSqlTests
{
    [InternalCommerceSqlFact]
    public async Task BS01_03_Unassigned_manager_fails_closed_while_owner_remains_global()
    {
        await using var f = await BranchFixture.Create();
        await using var db = f.Database.Context();
        var access = new InternalBranchAccess(db);
        Assert.Equal(new[] { f.LocationA }, await access.Locations(f.ManagerId).Select(x => x.Id).ToArrayAsync());
        Assert.Equal(2, await access.Locations(f.Database.Actor).CountAsync());
        await db.InternalStaff.Where(x => x.Id == f.ManagerId).ExecuteUpdateAsync(s => s.SetProperty(x => x.BranchId, (Guid?)null));
        Assert.Empty(await access.Locations(f.ManagerId).ToArrayAsync());
        Assert.False(await access.CanAccessLocation(f.ManagerId, f.LocationA, default));
        Assert.Empty(await access.Locations(Guid.Empty).ToArrayAsync());
    }

    [InternalCommerceSqlFact]
    public async Task BS04_06_Sales_and_stock_filter_before_count_and_pagination_not_by_creator()
    {
        await using var f = await BranchFixture.Create();
        await f.SeedSales();
        await using var db = f.Database.Context();
        var service = f.Commerce(db, f.Manager);
        var page1 = await service.Sales(0, 2, default, f.ManagerId);
        var page2 = await service.Sales(2, 2, default, f.ManagerId);
        Assert.Equal(3, page1.Total);
        Assert.Equal(3, page2.Total);
        Assert.Equal(2, page1.Items.Count);
        Assert.Single(page2.Items);
        var all = page1.Items.Concat(page2.Items).ToArray();
        Assert.Equal(3, all.Select(x => x.SaleId).Distinct().Count());
        Assert.All(all, x => Assert.Equal(f.LocationA, x.LocationId));
        Assert.Equal(750L, all.Sum(x => x.TotalMinor));
        Assert.Contains(all, x => x.ActorId != f.ManagerId);
        var owner = await service.Sales(0, 100, default, f.Database.Actor);
        Assert.Equal(7, owner.Total);
        Assert.Equal(6000L, owner.Items.Sum(x => x.TotalMinor));
        var stock = await service.Stock(null, 0, 100, default, f.ManagerId);
        Assert.Equal(1, stock.Total);
        Assert.Equal(2, Assert.Single(stock.Items).OnHand);
        Assert.Empty((await service.Stock(f.LocationB, 0, 100, default, f.ManagerId)).Items);
        Assert.Empty((await service.Sales(0, 100, default)).Items); // Omitted actor never means global.
    }

    [InternalCommerceSqlFact]
    public async Task BS07_12_Foreign_sale_reads_and_reversals_do_not_expose_or_mutate_the_sale()
    {
        await using var f = await BranchFixture.Create();
        var foreign = await f.SellAsOwner(f.LocationB, "bs-foreign-sale-0001");
        await f.SellAsOwner(f.LocationA, "bs-own-sale-key-0001");
        var before = await f.CommercialSnapshot();
        await using (var db = f.Database.Context())
        {
            var service = f.Commerce(db, f.Manager);
            var movements = await service.Movements(null, null, 0, 100, default, f.ManagerId);
            Assert.Equal(1, movements.Total);
            Assert.Equal(f.LocationA, Assert.Single(movements.Items).LocationId);
            Assert.Empty((await service.Movements(null, f.LocationB, 0, 100, default, f.ManagerId)).Items);
            Assert.Null(await service.Sale(foreign.SaleId, default, f.ManagerId));
            Assert.Null(await service.Reversals(foreign.SaleId, default, f.ManagerId));
            var cancel = await service.CancelSale(foreign.SaleId, new("Synthetic denied cancellation"), f.ManagerId, "bs-foreign-cancel-01", default);
            Assert.False(cancel.Success);
            Assert.Null(cancel.Value);
            var returned = await service.ReturnSale(foreign.SaleId,
                new("Synthetic denied return", [new(foreign.Lines[0].SaleLineId, 1)]), f.ManagerId, "bs-foreign-return-01", default);
            Assert.False(returned.Success);
            Assert.Null(returned.Value);
        }
        Assert.Equal(before, await f.CommercialSnapshot());
    }

    [InternalCommerceSqlFact]
    public async Task BS20_22_Reassigned_manager_with_new_valid_session_cannot_replay_original_result()
    {
        await using var f = await BranchFixture.Create();
        const string key = "bs-scope-replay-0001";
        var request = new InternalSaleRequest(f.LocationA, null, [new(f.Database.Item, 1)]);
        InternalResult<InternalSaleReceipt> first;
        await using (var db = f.Database.Context())
            first = await f.Commerce(db, f.Manager).RecordSale(request, f.ManagerId, key, default);
        Assert.True(first.Success, first.Error);
        string original;
        await using (var db = f.Database.Context())
            original = (await db.Set<InternalOperation>().SingleAsync(x => x.ActorId == f.ManagerId && x.Key == key)).ResultJson;
        var before = await f.CommercialSnapshot();
        await f.ReassignManagerToB();
        await using (var db = f.Database.Context())
        {
            var security = new InternalSecurityService(db, new PasswordHasher<InternalStaff>(), TimeProvider.System);
            Assert.NotNull(await security.ValidateSession(f.Manager, default)); // Must test current scope, not stale-cookie rejection.
            var replay = await f.Commerce(db, f.Manager).RecordSale(request, f.ManagerId, key, default);
            Assert.False(replay.Success);
            Assert.Null(replay.Value);
            var operation = await db.Set<InternalOperation>().AsNoTracking().SingleAsync(x => x.ActorId == f.ManagerId && x.Key == key);
            Assert.Equal(original, operation.ResultJson);
            Assert.False(await new InternalBranchAccess(db).CanReadOperation(f.ManagerId, operation, default));
        }
        Assert.Equal(before, await f.CommercialSnapshot());
    }

    [InternalCommerceSqlFact]
    public async Task BS23_Receipt_dedup_with_new_key_cannot_return_original_branch_after_reassignment()
    {
        await using var f = await BranchFixture.Create();
        var supplier = Guid.NewGuid();
        await using (var db = f.Database.Context())
        {
            db.Set<InternalParty>().Add(new() { Id = supplier, Kind = "supplier", Name = "Synthetic supplier", Active = true });
            await db.SaveChangesAsync();
        }
        InternalPurchaseOrderView order;
        await using (var db = f.Database.Context())
        {
            var created = await f.Supply(db, f.Manager).Create(f.ManagerId, "bs-purchase-create01",
                new(supplier, f.LocationA, "USD", [new(f.Database.Item, 2, 80)]), default);
            Assert.True(created.Success, created.Error);
            order = created.Value!;
        }
        var request = new InternalPurchaseReceiptRequest(Guid.NewGuid(), [new(order.Lines[0].Id, 1)]);
        await using (var db = f.Database.Context())
        {
            var first = await f.Supply(db, f.Manager).Receive(f.ManagerId, "bs-receipt-first-001", order.Id, request, default);
            Assert.True(first.Success, first.Error);
        }
        var before = await f.CommercialSnapshot();
        await f.ReassignManagerToB();
        await using (var db = f.Database.Context())
        {
            var duplicate = await f.Supply(db, f.Manager).Receive(f.ManagerId, "bs-receipt-second01", order.Id, request, default);
            Assert.False(duplicate.Success);
            Assert.Null(duplicate.Value);
        }
        Assert.Equal(before, await f.CommercialSnapshot());
    }

    [InternalCommerceSqlFact]
    public async Task BS24_Legacy_operation_fails_closed_for_manager_without_modifying_history()
    {
        await using var f = await BranchFixture.Create();
        await using var db = f.Database.Context();
        var legacy = new InternalOperation { Id = Guid.NewGuid(), ActorId = f.ManagerId, Scope = "commerce.sale.record",
            Key = "bs-legacy-result-001", Fingerprint = new string('A', 64), ResultJson = "{\"value\":\"legacy-canary\",\"error\":null}" };
        var access = new InternalBranchAccess(db);
        Assert.False(await access.CanReadOperation(f.ManagerId, legacy, default));
        Assert.Contains("legacy-canary", legacy.ResultJson);
    }

    [InternalCommerceSqlFact]
    public async Task BS27_Inactive_location_allows_own_historical_reversal_but_not_foreign_reversal()
    {
        await using var f = await BranchFixture.Create();
        var own = await f.SellAsOwner(f.LocationA, "bs-inactive-own-sale1");
        var foreign = await f.SellAsOwner(f.LocationB, "bs-inactive-other-01");
        await using (var db = f.Database.Context())
        {
            await db.Set<InternalLocation>().ExecuteUpdateAsync(s => s.SetProperty(x => x.Active, false));
            await db.Set<InternalItem>().ExecuteUpdateAsync(s => s.SetProperty(x => x.Active, false));
        }
        await using (var db = f.Database.Context())
        {
            var ownResult = await f.Commerce(db, f.Manager).CancelSale(own.SaleId, new("Synthetic historical reversal"), f.ManagerId, "bs-inactive-cancel01", default);
            Assert.True(ownResult.Success, ownResult.Error);
        }
        var before = await f.CommercialSnapshot();
        await using (var db = f.Database.Context())
        {
            var foreignResult = await f.Commerce(db, f.Manager).CancelSale(foreign.SaleId, new("Synthetic foreign reversal"), f.ManagerId, "bs-inactive-foreign1", default);
            Assert.False(foreignResult.Success);
            Assert.Null(foreignResult.Value);
        }
        Assert.Equal(before, await f.CommercialSnapshot());
    }

    [InternalCommerceSqlFact]
    public async Task BS21_25_Operations_http_checks_persisted_scope_and_actor_before_returning_result()
    {
        await using var f = await BranchFixture.Create();
        const string key = "bs-http-result-key01";
        await using (var db = f.Database.Context())
        {
            var sale = await f.Commerce(db, f.Manager).RecordSale(new(f.LocationA, null, [new(f.Database.Item, 1)]), f.ManagerId, key, default);
            Assert.True(sale.Success, sale.Error);
        }
        await using var host = await OperationsHost.Start(f);
        using (var response = await host.Read(key))
        {
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            Assert.Contains("completed", await response.Content.ReadAsStringAsync());
        }
        host.Identity.Principal = InternalSecurityRules.Principal(f.Database.Staff, f.Database.Session);
        using (var response = await host.Read(key))
        {
            Assert.Equal(HttpStatusCode.NotFound, response.StatusCode); // Owner cannot retrieve another actor's key.
            Assert.DoesNotContain("saleId", await response.Content.ReadAsStringAsync());
        }
        await f.ReassignManagerToB();
        host.Identity.Principal = f.Manager; // Fresh valid persisted session, not a stale-cookie negative.
        using (var response = await host.Read(key))
        {
            Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
            Assert.DoesNotContain("saleId", await response.Content.ReadAsStringAsync());
        }
    }

    [InternalCommerceSqlFact]
    public async Task BS29_Historical_location_cannot_be_remapped_to_expose_another_branch()
    {
        await using var f = await BranchFixture.Create();
        var sale = await f.SellAsOwner(f.LocationA, "bs-remap-sale-key01");
        await using var db = f.Database.Context();
        var owner = InternalSecurityRules.Principal(f.Database.Staff, f.Database.Session);
        var directory = new InternalDirectoryService(db, BranchFixture.Runner(db, owner));
        var result = await directory.SaveLocation(f.LocationA, new("Synthetic remap", true, f.BranchB),
            f.Database.Actor, "bs-remap-denied-001", default);
        Assert.False(result.Success);
        Assert.Equal("conflict", result.Error);
        await using var verify = f.Database.Context();
        Assert.Equal(f.BranchA, (await verify.Set<InternalLocation>().SingleAsync(x => x.Id == f.LocationA)).BranchId);
        await f.ReassignManagerToB();
        Assert.Null(await f.Commerce(verify, f.Manager).Sale(sale.SaleId, default, f.ManagerId));
    }

    [InternalCommerceSqlFact]
    public async Task BS28_Cashier_cannot_read_purchase_costs_through_any_supply_get()
    {
        await using var f = await BranchFixture.Create();
        await using var host = await OperationsHost.Start(f);
        var claims = f.Manager.Claims.Where(x => x.Type != ClaimTypes.Role).Append(new Claim(ClaimTypes.Role, "Cashier"));
        host.Identity.Principal = new ClaimsPrincipal(new ClaimsIdentity(claims, "BranchTest"));
        foreach (var path in new[] { "/internal/api/supply/purchase-orders", "/internal/api/supply/purchase-orders/" + Guid.NewGuid(),
            "/internal/api/supply/purchase-orders/" + Guid.NewGuid() + "/receipts" })
        {
            using var response = await host.Get(path);
            Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
            Assert.DoesNotContain("unitCostMinor", await response.Content.ReadAsStringAsync());
        }
    }

    private sealed class TestIdentity { public ClaimsPrincipal Principal { get; set; } = null!; }
    // Authentication transport is synthetic; ValidateSession and endpoint/SQL are production code.
    private sealed class BranchAuthentication(IOptionsMonitor<AuthenticationSchemeOptions> options, ILoggerFactory logger,
        UrlEncoder encoder, TestIdentity identity) : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        protected override Task<AuthenticateResult> HandleAuthenticateAsync() =>
            Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(identity.Principal, Scheme.Name)));
    }
    private sealed class OperationsHost(WebApplication app, HttpClient client, TestIdentity identity) : IAsyncDisposable
    {
        public TestIdentity Identity { get; } = identity;
        public static async Task<OperationsHost> Start(BranchFixture fixture)
        {
            var builder = WebApplication.CreateBuilder(new WebApplicationOptions { EnvironmentName = "Test" });
            builder.WebHost.UseTestServer();
            builder.Logging.ClearProviders();
            builder.Services.AddHttpContextAccessor();
            builder.Services.AddScoped(_ => fixture.Database.Context());
            builder.Services.AddInternalSecurity();
            builder.Services.AddScoped<IInternalCommandRunner, InternalCommandRunner>();
            builder.Services.AddInternalCommerce();
            builder.Services.AddInternalSupply();
            var identity = new TestIdentity { Principal = fixture.Manager };
            builder.Services.AddSingleton(identity);
            builder.Services.AddAuthentication().AddScheme<AuthenticationSchemeOptions, BranchAuthentication>("BranchTest", _ => { });
            builder.Services.AddAuthorization(options => {
                options.AddPolicy("internal.read", policy => policy.AddAuthenticationSchemes("BranchTest").RequireAuthenticatedUser().RequireRole("Owner", "Manager", "Cashier", "Inventory"));
                options.AddPolicy("internal.inventory", policy => policy.AddAuthenticationSchemes("BranchTest").RequireAuthenticatedUser().RequireRole("Owner", "Manager", "Inventory"));
            });
            var app = builder.Build();
            app.UseAuthentication(); app.UseAuthorization(); app.MapPrivateSavia();
            await app.StartAsync();
            var client = app.GetTestClient(); client.BaseAddress = new Uri("https://localhost");
            return new(app, client, identity);
        }
        public Task<HttpResponseMessage> Get(string path) => client.GetAsync(path);
        public async Task<HttpResponseMessage> Read(string key)
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, "/internal/api/operations/commerce.sale.record");
            request.Headers.Add("Idempotency-Key", key);
            return await client.SendAsync(request);
        }
        public async ValueTask DisposeAsync() { client.Dispose(); await app.DisposeAsync(); }
    }

    private sealed class BranchFixture : IAsyncDisposable
    {
        public InternalCommerceSqlDatabase Database { get; }
        public Guid BranchA { get; } = Guid.NewGuid();
        public Guid BranchB { get; } = Guid.NewGuid();
        public Guid LocationA => Database.Location;
        public Guid LocationB { get; } = Guid.NewGuid();
        public Guid ManagerId { get; } = Guid.NewGuid();
        public ClaimsPrincipal Manager { get; private set; } = null!;
        private BranchFixture(InternalCommerceSqlDatabase database) => Database = database;
        public static async Task<BranchFixture> Create()
        {
            var f = new BranchFixture(await InternalCommerceSqlDatabase.Create());
            try
            {
                await using var db = f.Database.Context();
                db.Set<InternalBranch>().AddRange(new InternalBranch { Id = f.BranchA, Name = "Synthetic A", Active = true },
                    new InternalBranch { Id = f.BranchB, Name = "Synthetic B", Active = true });
                (await db.Set<InternalLocation>().SingleAsync()).BranchId = f.BranchA;
                db.Set<InternalLocation>().Add(new() { Id = f.LocationB, BranchId = f.BranchB, Name = "Synthetic B location", Active = true });
                var now = DateTimeOffset.UtcNow;
                var staff = new InternalStaff { Id = f.ManagerId, LoginName = "synthetic.branch.manager", NormalizedLoginName = "SYNTHETIC.BRANCH.MANAGER",
                    DisplayName = "Synthetic manager", PasswordHash = "synthetic-session-only", Role = "Manager", BranchId = f.BranchA,
                    Enabled = true, SecurityVersion = Guid.NewGuid(), CreatedAt = now, UpdatedAt = now };
                var session = NewSession(staff, now);
                db.InternalStaff.Add(staff); db.InternalSessions.Add(session);
                db.Set<InternalStockBalance>().AddRange(
                    new InternalStockBalance { ItemId = f.Database.Item, LocationId = f.LocationA, OnHand = 2, UpdatedAt = now },
                    new InternalStockBalance { ItemId = f.Database.Item, LocationId = f.LocationB, OnHand = 7, UpdatedAt = now });
                await db.SaveChangesAsync();
                f.Manager = InternalSecurityRules.Principal(staff, session);
                return f;
            }
            catch { await f.DisposeAsync(); throw; }
        }
        public InternalCommerceService Commerce(InternalDbContext db, ClaimsPrincipal principal) => new(db, Runner(db, principal), new InternalStockLedger(db));
        public InternalSupplyService Supply(InternalDbContext db, ClaimsPrincipal principal) => new(db, Runner(db, principal), new InternalStockLedger(db));
        public static InternalCommandRunner Runner(InternalDbContext db, ClaimsPrincipal principal) => new(db,
            new InternalSecurityService(db, new PasswordHasher<InternalStaff>(), TimeProvider.System),
            new HttpContextAccessor { HttpContext = new DefaultHttpContext { User = principal } }, TimeProvider.System);
        public async Task<InternalSaleReceipt> SellAsOwner(Guid location, string key)
        {
            await using var db = Database.Context();
            var result = await Commerce(db, InternalSecurityRules.Principal(Database.Staff, Database.Session))
                .RecordSale(new(location, null, [new(Database.Item, 1)]), Database.Actor, key, default);
            Assert.True(result.Success, result.Error);
            return result.Value!;
        }
        public async Task ReassignManagerToB()
        {
            await using var db = Database.Context();
            var staff = await db.InternalStaff.SingleAsync(x => x.Id == ManagerId);
            staff.BranchId = BranchB; staff.SecurityVersion = Guid.NewGuid();
            foreach (var session in await db.InternalSessions.Where(x => x.StaffId == ManagerId).ToListAsync()) session.RevokedAt = DateTimeOffset.UtcNow;
            var current = NewSession(staff, DateTimeOffset.UtcNow); db.InternalSessions.Add(current);
            await db.SaveChangesAsync();
            Manager = InternalSecurityRules.Principal(staff, current);
        }
        private static InternalSession NewSession(InternalStaff staff, DateTimeOffset now) => new()
        { Id = Guid.NewGuid(), StaffId = staff.Id, SecurityVersion = staff.SecurityVersion, CreatedAt = now, ExpiresAt = now.Add(InternalSecurityRules.SessionLifetime) };
        public async Task SeedSales()
        {
            await using var db = Database.Context();
            var at = new DateTimeOffset(2026, 10, 27, 1, 0, 0, TimeSpan.Zero);
            for (var i = 0; i < 7; i++)
            {
                var own = i % 2 == 1;
                var quantity = own ? (i + 1) / 2 : 9 + i / 2;
                var id = Guid.NewGuid();
                db.Set<InternalSale>().Add(new() { Id = id, LocationId = own ? LocationA : LocationB,
                    ActorId = i == 3 ? ManagerId : Database.Actor, Currency = "USD", TotalMinor = quantity * 125,
                    State = "recorded", CreatedAt = at.AddMinutes(i), Lines = [new() { Id = Guid.NewGuid(), SaleId = id,
                        ItemId = Database.Item, Sku = "SQL-TEST-A", Name = "Synthetic item", Quantity = quantity, UnitPriceMinor = 125, TotalMinor = quantity * 125 }] });
            }
            await db.SaveChangesAsync();
        }
        public async Task<string> CommercialSnapshot()
        {
            await using var db = Database.Context();
            return JsonSerializer.Serialize(new {
                Balances = await db.Set<InternalStockBalance>().OrderBy(x => x.LocationId).ThenBy(x => x.ItemId).ToArrayAsync(),
                Sales = await db.Set<InternalSale>().Include(x => x.Lines.OrderBy(line => line.Id)).OrderBy(x => x.Id).ToArrayAsync(),
                Reversals = await db.Set<InternalSaleReversal>().Include(x => x.Lines.OrderBy(line => line.Id)).OrderBy(x => x.Id).ToArrayAsync(),
                Movements = await db.Set<InternalStockMovement>().OrderBy(x => x.Id).ToArrayAsync(),
                Receipts = await db.Set<InternalPurchaseReceipt>().Include(x => x.Lines.OrderBy(line => line.Id)).OrderBy(x => x.Id).ToArrayAsync(),
                Orders = await db.Set<InternalPurchaseOrder>().Include(x => x.Lines.OrderBy(line => line.Id)).OrderBy(x => x.Id).ToArrayAsync()
            });
        }
        public ValueTask DisposeAsync() => Database.DisposeAsync();
    }
}
