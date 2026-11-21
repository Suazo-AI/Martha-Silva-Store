using Martha.Store.Api.Internal;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Martha.Store.Api.Tests;

public sealed class InternalCashReadTests
{
    [Theory]
    [InlineData("/internal/api/cash/context")]
    [InlineData("/internal/api/cash/sales/11111111-1111-1111-1111-111111111111/refund-context?skip=0&take=50")]
    public async Task Anonymous_HTTP_reads_deny_before_database_access(string path)
    {
        var builder = WebApplication.CreateBuilder(); builder.WebHost.UseTestServer();
        builder.Configuration.AddInMemoryCollection(new Dictionary<string, string?> {
            ["ConnectionStrings:InternalSavia"] = "Server=offline.invalid;Database=SaviaInternalTest_CashReadNoConnect;Integrated Security=true;Connect Timeout=1" });
        builder.Services.AddPrivateSavia(builder.Configuration);
        await using var app = builder.Build(); app.UseAuthentication(); app.UseAuthorization(); app.MapInternalCash();
        await app.StartAsync();
        using var client = app.GetTestClient(); client.BaseAddress = new Uri("https://localhost");
        using var response = await client.GetAsync(path);
        Assert.Equal(System.Net.HttpStatusCode.Unauthorized, response.StatusCode);
        await using var scope = app.Services.CreateAsyncScope();
        Assert.Equal(System.Data.ConnectionState.Closed, scope.ServiceProvider.GetRequiredService<InternalDbContext>().Database.GetDbConnection().State);
    }

    [Theory]
    [InlineData(-1, 50)] [InlineData(0, 0)] [InlineData(0, 51)] [InlineData(0, int.MaxValue)]
    public async Task Invalid_refund_paging_is_rejected_before_database_access(int skip, int take)
    {
        using var db = new InternalDbContext(new DbContextOptionsBuilder<InternalDbContext>()
            .UseSqlServer("Server=offline.invalid;Database=CashReadTranslation;Integrated Security=true").Options);
        var service = new InternalCashReadService(db, null!, new("USD", 2), null!);
        var result = await service.RefundContext(Guid.NewGuid(), skip, take, new ClaimsPrincipal(), default);
        Assert.Equal("invalid_request", result.Error);
        Assert.Equal(System.Data.ConnectionState.Closed, db.Database.GetDbConnection().State);
    }

    [Fact]
    public async Task Read_routes_keep_required_server_authorization_and_four_existing_writes()
    {
        var builder = WebApplication.CreateBuilder();
        builder.Services.AddLogging();
        // Mark handlers' parameters as DI services while materializing endpoint metadata only.
        builder.Services.AddScoped<InternalCashReadService>(); builder.Services.AddScoped<InternalCashService>();
        await using var app = builder.Build(); app.MapInternalCash();
        var routes = ((IEndpointRouteBuilder)app).DataSources.SelectMany(x => x.Endpoints).OfType<RouteEndpoint>().ToArray();
        var reads = routes.Where(x => x.Metadata.GetMetadata<HttpMethodMetadata>()!.HttpMethods.Contains("GET")).ToArray();
        Assert.Equal(3, reads.Length);
        var context = Assert.Single(reads, x => x.RoutePattern.RawText == "/internal/api/cash/context");
        Assert.Contains(context.Metadata.GetOrderedMetadata<IAuthorizeData>(), x => x.Policy == "internal.sell");
        var refund = Assert.Single(reads, x => x.RoutePattern.RawText!.EndsWith("/refund-context"));
        Assert.Contains(refund.Metadata.GetOrderedMetadata<IAuthorizeData>(), x => x.Policy == "internal.manage");
        // The closing report for the accountant is a read that only Owners and Managers may take.
        var report = Assert.Single(reads, x => x.RoutePattern.RawText!.EndsWith("/closing-report.csv"));
        Assert.Contains(report.Metadata.GetOrderedMetadata<IAuthorizeData>(), x => x.Policy == "internal.manage");
        Assert.Equal(4, routes.Count(x => x.Metadata.GetMetadata<HttpMethodMetadata>()!.HttpMethods.Contains("POST")));
    }

    private static readonly Guid Location = Guid.NewGuid(), Branch = Guid.NewGuid(), Cashier = Guid.NewGuid();
    private static InternalCashTill Till() => new() { Id = Guid.NewGuid(), LocationId = Location,
        CashierId = Cashier, Currency = "USD", Exponent = 3, OpenedAt = DateTimeOffset.UtcNow };
    private static InternalStaff Staff() => new() { Id = Cashier, Role = "Cashier", Enabled = true, BranchId = Branch };
    private static InternalLocation Place() => new() { Id = Location, BranchId = Branch };
    private static InternalBranch ActiveBranch() => new() { Id = Branch, Active = true };
    private static IQueryable<InternalCashTill> Eligible(IEnumerable<InternalCashTill> tills, InternalStaff? staff = null,
        InternalLocation? place = null, InternalBranch? branch = null) => InternalCashReadService.EligiblePayingTills(
            tills.AsQueryable(), new[] { staff ?? Staff() }.AsQueryable(), new[] { place ?? Place() }.AsQueryable(),
            new[] { branch ?? ActiveBranch() }.AsQueryable(), Location, "USD", 3);

    [Fact]
    public void Eligible_cashier_need_not_be_manager_requesting_refund() => Assert.Single(Eligible([Till()]));

    [Theory]
    [InlineData("closed")] [InlineData("foreign_location")] [InlineData("currency")] [InlineData("exponent")]
    [InlineData("disabled")] [InlineData("reassigned")] [InlineData("inactive_branch")]
    [InlineData("inventory")] [InlineData("missing_branch")]
    public void Excludes_ineligible_paying_tills(string change)
    {
        var till = Till(); var staff = Staff(); var place = Place(); var branch = ActiveBranch();
        switch (change)
        {
            case "closed": till.ClosedAt = DateTimeOffset.UtcNow; break;
            case "foreign_location": till.LocationId = Guid.NewGuid(); break;
            case "currency": till.Currency = "EUR"; break;
            case "exponent": till.Exponent = 2; break;
            case "disabled": staff.Enabled = false; break;
            case "reassigned": staff.BranchId = Guid.NewGuid(); break;
            case "inactive_branch": branch.Active = false; break;
            case "inventory": staff.Role = "Inventory"; break;
            case "missing_branch": staff.BranchId = null; break;
        }
        Assert.Empty(Eligible([till], staff, place, branch));
    }

    [Fact]
    public void Owner_has_global_branch_access_but_must_still_be_enabled()
    {
        var staff = Staff(); staff.Role = "Owner"; staff.BranchId = null;
        Assert.Single(Eligible([Till()], staff));
        staff.Enabled = false; Assert.Empty(Eligible([Till()], staff));
    }

    [Fact]
    public void Stable_paging_exceeds_fifty_without_duplicates()
    {
        var rows = Enumerable.Range(0, 103).Select(_ => Till()).ToArray();
        var query = Eligible(rows).OrderBy(x => x.OpenedAt).ThenBy(x => x.Id);
        var first = query.Take(51).ToArray(); var second = query.Skip(50).Take(51).ToArray(); var third = query.Skip(100).Take(51).ToArray();
        Assert.Equal(51, first.Length); Assert.Equal(51, second.Length); Assert.Equal(3, third.Length);
        var ids = first.Take(50).Concat(second.Take(50)).Concat(third).Select(x => x.Id).ToArray();
        Assert.Equal(103, ids.Distinct().Count());
    }

    [Fact]
    public void Paying_till_query_translates_for_actual_relational_provider_without_SQL_execution()
    {
        using var db = new InternalDbContext(new DbContextOptionsBuilder<InternalDbContext>()
            .UseSqlServer("Server=offline.invalid;Database=CashReadTranslation;Integrated Security=true").Options);
        var query = InternalCashReadService.EligiblePayingTills(db.Set<InternalCashTill>(), db.InternalStaff,
            db.InternalLocations, db.Set<InternalBranch>(), Location, "USD", 3)
            .OrderBy(x => x.OpenedAt).ThenBy(x => x.Id).Skip(50).Take(51);
        var sql = query.ToQueryString();
        Assert.Contains("EXISTS", sql); Assert.Contains("OFFSET", sql); Assert.Contains("[ClosedAt] IS NULL", sql);
        Assert.Equal(System.Data.ConnectionState.Closed, db.Database.GetDbConnection().State);
    }
}
