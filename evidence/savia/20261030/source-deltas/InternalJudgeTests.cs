using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using System.Text.RegularExpressions;
using Martha.Store.Api.Internal;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Martha.Store.Api.Tests;

// Independent contract checks owned by the judge, not by an implementation module.
// These tests never prove SQL persistence, transaction isolation or live authentication.
public sealed class InternalJudgeTests
{
    [Theory]
    [InlineData(16)]
    [InlineData(128)]
    public void Idempotency_key_accepts_exact_documented_length_boundaries(int length)
    {
        Assert.True(InternalRules.ValidKey(new string('a', length)));
        Assert.True(InternalRules.ValidKey("A0_-" + new string('z', length - 4)));
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("123456789012345")]
    [InlineData("123456789012345 ")]
    [InlineData("123456789012345\n")]
    [InlineData("123456789012345é")]
    [InlineData("123456789012345,")]
    [InlineData("123456789012345.")]
    [InlineData("１２３４５６７８９０１２３４５６")]
    public void Idempotency_key_rejects_noncanonical_input(string? key) => Assert.False(InternalRules.ValidKey(key));

    [Fact]
    public void Idempotency_key_rejects_overlength_input() => Assert.False(InternalRules.ValidKey(new string('a', 129)));

    [Theory]
    [InlineData("USD", true)]
    [InlineData("EUR", true)]
    [InlineData("HNL", true)]
    [InlineData("XXX", false)]
    [InlineData("usd", false)]
    [InlineData(" USD", false)]
    [InlineData("USD ", false)]
    [InlineData("US", false)]
    [InlineData("USDD", false)]
    [InlineData("US1", false)]
    [InlineData("ＵＳＤ", false)]
    [InlineData(null, false)]
    public void Currency_rule_is_explicit_ascii_and_never_accepts_fixture_currency(string? currency, bool valid) =>
        Assert.Equal(valid, InternalRules.ValidCurrency(currency));

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("not-a-guid")]
    [InlineData("00000000-0000-0000-0000-000000000000")]
    public void Actor_identifier_missing_malformed_or_empty_is_not_synthesized(string? id)
    {
        var claims = id is null ? Array.Empty<Claim>() : [new Claim(ClaimTypes.NameIdentifier, id)];
        var principal = new ClaimsPrincipal(new ClaimsIdentity(claims, "test-contract"));
        Assert.Throws<UnauthorizedAccessException>(() => InternalActor.Id(principal));
    }

    [Fact]
    public void Actor_identifier_is_the_principal_identifier_not_a_generated_identity()
    {
        var id = Guid.Parse("11111111-2222-3333-4444-555555555555");
        var principal = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, id.ToString("D"))], "test-contract"));
        Assert.Equal(id, InternalActor.Id(principal));
    }

    [Fact]
    public void Payload_fingerprint_is_deterministic_and_changes_with_business_input()
    {
        var first = InternalRules.Fingerprint(new { ItemId = "test-item", Quantity = 1 });
        Assert.Equal(64, first.Length);
        Assert.Equal(first, InternalRules.Fingerprint(new { ItemId = "test-item", Quantity = 1 }));
        Assert.NotEqual(first, InternalRules.Fingerprint(new { ItemId = "test-item", Quantity = 2 }));
    }

    [Theory]
    [InlineData("Development", null)]
    [InlineData("Development", false)]
    [InlineData("Production", false)]
    [InlineData("Production", true)]
    [InlineData("Staging", true)]
    [InlineData("Testing", true)]
    public async Task Real_program_exposes_no_internal_endpoints_without_the_explicit_development_gate(string environment, bool? enabled)
    {
        await using var factory = new JudgeFactory(environment, enabled);
        using var client = Client(factory);
        Assert.Empty(InternalRoutes(factory));
        foreach (var path in new[] { "/internal", "/internal/", "/internal/login", "/internal/api/security/csrf",
                     "/internal/api/security/me", "/internal/api/directory/items", "/internal/api/commerce/sales", "/internal/api/supply/purchase-orders",
                     "/internal/login.mjs", "/internal/styles.css", "/internal/app.mjs", "/internal/client.mjs", "/internal/api/readiness" })
        {
            using var response = await client.GetAsync(path);
            Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        }
    }

    [Fact]
    public async Task Real_program_maps_only_the_two_intended_anonymous_internal_api_routes()
    {
        await using var factory = new JudgeFactory();
        using var client = Client(factory);
        var routes = InternalRoutes(factory).Where(endpoint => endpoint.RoutePattern.RawText!.StartsWith("/internal/api/", StringComparison.Ordinal)).ToArray();
        Assert.NotEmpty(routes);
        foreach (var module in new[] { "security", "directory", "commerce", "supply" })
            Assert.Contains(routes, route => route.RoutePattern.RawText!.StartsWith($"/internal/api/{module}/", StringComparison.Ordinal));
        var anonymous = new HashSet<string>(StringComparer.Ordinal)
        { "/internal/api/security/login", "/internal/api/security/csrf" };
        var policies = new HashSet<string>(StringComparer.Ordinal)
        { "internal.owner", "internal.manage", "internal.sell", "internal.inventory", "internal.read" };
        foreach (var route in routes)
        {
            var path = route.RoutePattern.RawText!;
            if (anonymous.Contains(path))
            {
                Assert.NotNull(route.Metadata.GetMetadata<IAllowAnonymous>());
                continue;
            }
            Assert.Null(route.Metadata.GetMetadata<IAllowAnonymous>());
            var authorization = route.Metadata.GetOrderedMetadata<IAuthorizeData>();
            Assert.NotEmpty(authorization);
            Assert.All(authorization, requirement => Assert.Contains(requirement.Policy!, policies));
        }
        Assert.Equal(anonymous.Order(), routes.Where(route => route.Metadata.GetMetadata<IAllowAnonymous>() is not null)
            .Select(route => route.RoutePattern.RawText!).Order());
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Every_protected_internal_api_rejects_anonymous_or_tampered_identity_before_business_storage(bool tampered)
    {
        await using var factory = new JudgeFactory();
        using var client = Client(factory);
        if (tampered)
        {
            client.DefaultRequestHeaders.Add("Cookie", "__Host-Savia.Session=not-a-valid-session");
            client.DefaultRequestHeaders.Add("X-Actor-Id", "11111111-2222-3333-4444-555555555555");
            client.DefaultRequestHeaders.Add("X-Role", "Owner");
            client.DefaultRequestHeaders.Add("X-User-Id", "11111111-2222-3333-4444-555555555555");
        }
        var routes = InternalRoutes(factory).Where(endpoint => endpoint.RoutePattern.RawText!.StartsWith("/internal/api/", StringComparison.Ordinal)
            && endpoint.Metadata.GetMetadata<IAllowAnonymous>() is null).ToArray();
        Assert.NotEmpty(routes);
        foreach (var route in routes)
        {
            var path = Regex.Replace(route.RoutePattern.RawText!, @"\{[^}]+\}", "11111111-2222-3333-4444-555555555555");
            var methods = route.Metadata.GetMetadata<HttpMethodMetadata>()!.HttpMethods;
            foreach (var method in methods)
            {
                using var request = new HttpRequestMessage(new HttpMethod(method), path);
                if (method is not ("GET" or "HEAD" or "OPTIONS")) request.Content = JsonContent.Create(new { });
                using var response = await client.SendAsync(request);
                Assert.True(response.StatusCode == HttpStatusCode.Unauthorized,
                    $"{method} {path}: expected authentication rejection, received {(int)response.StatusCode}.");
                Assert.Null(response.Headers.Location);
                Assert.DoesNotContain("storage_unavailable", await response.Content.ReadAsStringAsync());
                Assert.Contains("no-store", response.Headers.CacheControl?.ToString() ?? "");
            }
        }
    }

    [Fact]
    public async Task Private_internal_gate_does_not_enable_synthetic_v1_or_v2()
    {
        await using var factory = new JudgeFactory();
        using var client = Client(factory);
        using var v1 = await client.PostAsJsonAsync("/api/v1/synthetic/orders", new { });
        using var v2 = await client.GetAsync("/api/v2/synthetic/capabilities");
        Assert.Equal(HttpStatusCode.NotFound, v1.StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, v2.StatusCode);
    }

    [Theory]
    [InlineData("/internal/api/security/csrf")]
    [InlineData("/internal/api/security/me")]
    [InlineData("/internal/api/directory/items")]
    [InlineData("/INTERNAL/api/directory/items")]
    public async Task Real_program_rejects_insecure_internal_transport_before_identity_or_storage(string path)
    {
        await using var factory = new JudgeFactory();
        using var client = Client(factory);
        using var response = await client.GetAsync("http://localhost" + path);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Contains("https_required", await response.Content.ReadAsStringAsync());
        Assert.Contains("no-store", response.Headers.CacheControl?.ToString() ?? "");
    }

    [Fact]
    public async Task Real_program_issues_real_csrf_tokens_but_rejects_missing_or_invalid_pairs_without_database_configuration()
    {
        await using var factory = new JudgeFactory();
        using var client = Client(factory);
        using var missing = await client.PostAsJsonAsync("/internal/api/security/login", new { loginName = "", password = "" });
        Assert.Equal(HttpStatusCode.BadRequest, missing.StatusCode);
        Assert.Contains("csrf_invalid", await missing.Content.ReadAsStringAsync());

        using var tokenResponse = await client.GetAsync("/internal/api/security/csrf");
        Assert.Equal(HttpStatusCode.OK, tokenResponse.StatusCode);
        Assert.Contains("no-store", tokenResponse.Headers.CacheControl?.ToString() ?? "");
        var body = await tokenResponse.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("X-CSRF-TOKEN", body.GetProperty("headerName").GetString());
        Assert.False(string.IsNullOrWhiteSpace(body.GetProperty("token").GetString()));
        var cookie = Assert.Single(tokenResponse.Headers.GetValues("Set-Cookie"));
        Assert.StartsWith("__Host-Savia.Csrf=", cookie);
        Assert.Contains("secure", cookie);
        Assert.Contains("httponly", cookie);
        Assert.Contains("samesite=strict", cookie);
        Assert.DoesNotContain("domain=", cookie, StringComparison.OrdinalIgnoreCase);

        client.DefaultRequestHeaders.Add("Cookie", cookie.Split(';')[0]);
        client.DefaultRequestHeaders.Add("X-CSRF-TOKEN", "not-a-real-antiforgery-token");
        using var bad = await client.PostAsJsonAsync("/internal/api/security/login", new { loginName = "", password = "" });
        Assert.Equal(HttpStatusCode.BadRequest, bad.StatusCode);
        Assert.Contains("csrf_invalid", await bad.Content.ReadAsStringAsync());
        Assert.False(bad.Headers.TryGetValues("Set-Cookie", out var issued) && issued.Any(value => value.StartsWith("__Host-Savia.Session=", StringComparison.Ordinal)));
    }

    [Theory]
    [InlineData("Owner")]
    [InlineData("Manager")]
    [InlineData("Cashier")]
    [InlineData("Inventory")]
    [InlineData("owner")]
    [InlineData("Admin")]
    [InlineData("Owner,Manager")]
    public void Transaction_command_role_matrix_is_closed_and_matches_each_module_scope(string role)
    {
        var scopes = new Dictionary<string, string[]>(StringComparer.Ordinal)
        {
            ["directory.items.create"] = ["Owner"],
            ["directory.items.update"] = ["Owner"],
            ["directory.items.deactivate"] = ["Owner"],
            ["directory.locations.create"] = ["Owner"],
            ["directory.locations.update"] = ["Owner"],
            ["directory.locations.deactivate"] = ["Owner"],
            ["directory.parties.create"] = ["Owner"],
            ["directory.parties.update"] = ["Owner"],
            ["directory.parties.deactivate"] = ["Owner"],
            ["commerce.stock.adjust"] = ["Owner", "Manager", "Inventory"],
            ["commerce.sale.record"] = ["Owner", "Manager", "Cashier"],
            ["commerce.sale.cancel"] = ["Owner", "Manager"],
            ["commerce.sale.return"] = ["Owner", "Manager"],
            ["supply.purchase.create"] = ["Owner", "Manager"],
            ["supply.purchase.cancel"] = ["Owner", "Manager"],
            ["supply.receipt.create"] = ["Owner", "Manager", "Inventory"]
        };
        var principal = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.Role, role)], "test-policy-only"));
        foreach (var (scope, roles) in scopes)
        {
            Assert.Equal(roles.Contains(role, StringComparer.Ordinal), InternalCommandAuthorization.Allowed(principal, scope));
            Assert.False(InternalCommandAuthorization.Allowed(new ClaimsPrincipal(), scope));
            Assert.False(InternalCommandAuthorization.Allowed(principal, scope.ToUpperInvariant()));
        }
        foreach (var scope in new[] { "", "*", "directory.*", "security.staff.create", "commerce.sale.record ", "unknown" })
            Assert.False(InternalCommandAuthorization.Allowed(principal, scope));
    }

    [Theory]
    [InlineData("/internal/api/commerce/sales", "internal.sell")]
    [InlineData("/internal/api/commerce/sales/{id:guid}/cancel", "internal.manage")]
    [InlineData("/internal/api/commerce/sales/{id:guid}/returns", "internal.manage")]
    public async Task Sale_and_reversal_routes_have_exact_server_policies_without_business_storage(string path, string mutationPolicy)
    {
        await using var factory = new JudgeFactory();
        using var client = Client(factory);
        var route = Assert.Single(InternalRoutes(factory), endpoint => endpoint.RoutePattern.RawText == path
            && endpoint.Metadata.GetMetadata<HttpMethodMetadata>()!.HttpMethods.Contains("POST"));
        Assert.Null(route.Metadata.GetMetadata<IAllowAnonymous>());
        var authorization = route.Metadata.GetOrderedMetadata<IAuthorizeData>();
        Assert.Equal(new[] { "internal.read", mutationPolicy }.Order(), authorization.Select(value => value.Policy!).Order());

        // Policy-only principals do not simulate cookie validation or a persisted session.
        // The real Program has no database connection configured in this test.
        var policy = await AuthorizationPolicy.CombineAsync(factory.Services.GetRequiredService<IAuthorizationPolicyProvider>(), authorization);
        Assert.NotNull(policy);
        var service = factory.Services.GetRequiredService<IAuthorizationService>();
        foreach (var role in new[] { "Owner", "Manager", "Cashier", "Inventory", "Visitor", "owner" })
        {
            var principal = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.Role, role)], "policy-only"));
            var expected = role is "Owner" or "Manager" || (mutationPolicy == "internal.sell" && role == "Cashier");
            Assert.Equal(expected, (await service.AuthorizeAsync(principal, null, policy!)).Succeeded);
            var anonymous = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.Role, role)]));
            Assert.False((await service.AuthorizeAsync(anonymous, null, policy!)).Succeeded);
        }
    }

    [Theory]
    [InlineData("")]
    [InlineData("not a connection string")]
    [InlineData("Server=127.0.0.1;Database=master;Integrated Security=true")]
    [InlineData("Server=127.0.0.1;Database=MarthaSynthetic_Test;Integrated Security=true")]
    [InlineData("Server=127.0.0.1;Database=SaviaInternalTest_;Integrated Security=true")]
    [InlineData("Server=127.0.0.1;Database=saviainternaltest_case;Integrated Security=true")]
    [InlineData("Server=127.0.0.1;Database=\"SaviaInternalTest_Allowed\n\";Integrated Security=true")]
    [InlineData("Server=127.0.0.1;Database=SaviaInternalTest_Allowed;Integrated Security=true;MultipleActiveResultSets=true")]
    public void Internal_database_guard_rejects_unsafe_catalog_or_savepoint_incompatible_options_before_open(string connection) =>
        Assert.Throws<Martha.Store.Api.StorageUnavailableException>(() => InternalDatabaseGuard.Validate(connection));

    [Fact]
    public void Internal_database_guard_accepts_only_test_catalog_with_exact_suffix_bounds_without_opening_sql()
    {
        InternalDatabaseGuard.Validate("Server=127.0.0.1,1;Database=SaviaInternalTest_A;Integrated Security=true");
        InternalDatabaseGuard.Validate("Server=127.0.0.1,1;Database=SaviaInternalTest_" + new string('a', 64) + ";Integrated Security=true");
        Assert.Throws<Martha.Store.Api.StorageUnavailableException>(() => InternalDatabaseGuard.Validate(
            "Server=127.0.0.1,1;Database=SaviaInternalTest_" + new string('a', 65) + ";Integrated Security=true"));
    }

    [Fact]
    public void Operation_replay_identity_has_binary_sql_semantics_unique_actor_scope_key_and_no_seed()
    {
        using var db = ModelOnlyDatabase();
        var entity = db.GetService<IDesignTimeModel>().Model.FindEntityType(typeof(InternalOperation))!;
        Assert.Equal("savia_internal", entity.GetSchema());
        Assert.Contains(entity.GetIndexes(), index => index.IsUnique && index.Properties.Select(property => property.Name)
            .SequenceEqual(new[] { "ActorId", "Scope", "Key" }));
        foreach (var field in new[] { "Scope", "Key", "Fingerprint" })
            Assert.Equal("Latin1_General_100_BIN2", entity.FindProperty(field)!.GetCollation());
        Assert.Empty(entity.GetSeedData());
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Tracked_audit_record_rewrite_or_delete_is_rejected_before_sql(bool delete)
    {
        // EF tracked-write guard only. Bulk/direct SQL immutability requires the separate migration/SQL gate.
        object[] records = [new InternalOperation { Id = Guid.NewGuid() }, new InternalStockMovement { Id = Guid.NewGuid() },
            new InternalStockAdjustment { Id = Guid.NewGuid() }, new InternalSaleReversal { Id = Guid.NewGuid() },
            new InternalSaleReversalLine { Id = Guid.NewGuid() }, new InternalPurchaseReceipt { Id = Guid.NewGuid() },
            new InternalPurchaseReceiptLine { Id = Guid.NewGuid() }];
        foreach (var record in records)
        {
            await using var db = ModelOnlyDatabase();
            db.Entry(record).State = delete ? EntityState.Deleted : EntityState.Modified;
            var failure = await Assert.ThrowsAsync<InvalidOperationException>(() => db.SaveChangesAsync());
            Assert.Contains("append-only", failure.Message);
            Assert.Equal(System.Data.ConnectionState.Closed, db.Database.GetDbConnection().State);
        }
    }

    private static InternalDbContext ModelOnlyDatabase() => new(new DbContextOptionsBuilder<InternalDbContext>().UseSqlServer(
        "Server=127.0.0.1,1;Database=SaviaInternalTest_JudgeModelOnly;Integrated Security=true;Connect Timeout=1").Options);

    [Theory]
    [InlineData("/internal/login", "text/html")]
    [InlineData("/internal/login.mjs", "text/javascript")]
    [InlineData("/internal/styles.css", "text/css")]
    public async Task Public_login_resources_are_unambiguous_uncached_and_contain_no_prefilled_identity(string path, string contentType)
    {
        await using var factory = new JudgeFactory();
        using var client = Client(factory);
        using var response = await client.GetAsync(path);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal(contentType, response.Content.Headers.ContentType?.MediaType);
        AssertPrivateHeaders(response);
        var body = await response.Content.ReadAsStringAsync();
        Assert.False(string.IsNullOrWhiteSpace(body));
        Assert.DoesNotContain("PasswordHash", body, StringComparison.OrdinalIgnoreCase);
        Assert.False(response.Headers.TryGetValues("Set-Cookie", out var cookies)
            && cookies.Any(cookie => cookie.StartsWith("__Host-Savia.Session=", StringComparison.Ordinal)));
        if (contentType == "text/html")
        {
            Assert.Contains("name=\"loginName\"", body);
            Assert.Contains("type=\"password\"", body);
            Assert.False(Regex.IsMatch(body, @"<input\b[^>]*\bvalue\s*=", RegexOptions.IgnoreCase));
        }
    }

    [Theory]
    [InlineData("/internal", "/internal/")]
    [InlineData("/internal/", "/internal/login")]
    [InlineData("/internal/login/", "/internal/login")]
    public async Task Canonical_ui_routes_redirect_without_ambiguous_endpoint_matches(string path, string location)
    {
        await using var factory = new JudgeFactory();
        using var client = Client(factory);
        using var response = await client.GetAsync(path);
        Assert.Equal(HttpStatusCode.Redirect, response.StatusCode);
        Assert.Equal(location, response.Headers.Location?.OriginalString);
        AssertPrivateHeaders(response);
    }

    [Theory]
    [InlineData("/internal/app.mjs")]
    [InlineData("/internal/client.mjs")]
    public async Task Staff_application_sources_are_not_public_static_files(string path)
    {
        await using var factory = new JudgeFactory();
        using var client = Client(factory);
        using var response = await client.GetAsync(path);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        AssertPrivateHeaders(response);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        var route = Assert.Single(InternalRoutes(factory), endpoint => endpoint.RoutePattern.RawText == path);
        Assert.Null(route.Metadata.GetMetadata<IAllowAnonymous>());
        Assert.Contains(route.Metadata.GetOrderedMetadata<IAuthorizeData>(), policy => policy.Policy == "internal.read");
    }

    private static void AssertPrivateHeaders(HttpResponseMessage response)
    {
        Assert.Contains("no-store", response.Headers.CacheControl?.ToString() ?? "");
        Assert.Equal("nosniff", Assert.Single(response.Headers.GetValues("X-Content-Type-Options")));
        Assert.Equal("no-referrer", Assert.Single(response.Headers.GetValues("Referrer-Policy")));
        Assert.Contains("frame-ancestors 'none'", Assert.Single(response.Headers.GetValues("Content-Security-Policy")));
    }

    [InternalJudgeHttpSqlFact]
    public async Task Real_program_sql_login_issues_cookie_and_logout_revokes_even_the_replayed_old_cookie()
    {
        // Opt-in future acceptance test: generated disposable database, synthetic identity only, never bootstrap.
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        var connection = await PrepareHttpFixture(fixture);
        await using var factory = new JudgeFactory(connection: connection);
        using var session = new HttpSession(Client(factory));
        await Login(session, fixture.Staff.LoginName);
        using (var me = await session.Send(HttpMethod.Get, "/internal/api/security/me"))
        {
            Assert.Equal(HttpStatusCode.OK, me.StatusCode);
            Assert.Equal(fixture.Actor, (await me.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid());
        }
        var oldCookies = session.CookieHeader;
        var token = await Csrf(session);
        using (var logout = await session.Send(HttpMethod.Post, "/internal/api/security/logout", csrf: token))
            Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);
        using (var me = await session.Send(HttpMethod.Get, "/internal/api/security/me")) Assert.Equal(HttpStatusCode.Unauthorized, me.StatusCode);
        using var replay = Client(factory);
        replay.DefaultRequestHeaders.Add("Cookie", oldCookies);
        using var rejected = await replay.GetAsync("/internal/api/security/me");
        Assert.Equal(HttpStatusCode.Unauthorized, rejected.StatusCode);
    }

    [InternalJudgeHttpSqlFact]
    public async Task Real_program_sql_role_change_and_disablement_revoke_cookies_and_enforce_new_role()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        var connection = await PrepareHttpFixture(fixture);
        var now = DateTimeOffset.UtcNow;
        var staff = new InternalStaff { Id = Guid.NewGuid(), LoginName = "judge.http.fixture", NormalizedLoginName = "JUDGE.HTTP.FIXTURE",
            DisplayName = "Synthetic HTTP fixture", Role = "Cashier", Enabled = true, SecurityVersion = Guid.NewGuid(), CreatedAt = now, UpdatedAt = now };
        staff.PasswordHash = new PasswordHasher<InternalStaff>().HashPassword(staff, HttpFixturePassword);
        await using (var db = fixture.Context()) { db.Add(staff); await db.SaveChangesAsync(); }
        await using var factory = new JudgeFactory(connection: connection);
        using var owner = new HttpSession(Client(factory));
        using var member = new HttpSession(Client(factory));
        await Login(owner, fixture.Staff.LoginName);
        await Login(member, staff.LoginName);
        using (var forbidden = await member.Send(HttpMethod.Get, "/internal/api/security/staff")) Assert.Equal(HttpStatusCode.Forbidden, forbidden.StatusCode);
        var ownerToken = await Csrf(owner);
        Guid changedVersion;
        using (var changed = await owner.Send(HttpMethod.Put, $"/internal/api/security/staff/{staff.Id}",
            new { displayName = staff.DisplayName, role = "Inventory", enabled = true, version = staff.SecurityVersion }, ownerToken))
        {
            Assert.Equal(HttpStatusCode.OK, changed.StatusCode);
            changedVersion = (await changed.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("version").GetGuid();
        }
        using (var stale = await member.Send(HttpMethod.Get, "/internal/api/security/me")) Assert.Equal(HttpStatusCode.Unauthorized, stale.StatusCode);
        await Login(member, staff.LoginName);
        using (var current = await member.Send(HttpMethod.Get, "/internal/api/security/me"))
        {
            Assert.Equal(HttpStatusCode.OK, current.StatusCode);
            Assert.Equal("Inventory", (await current.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("role").GetString());
        }
        var memberToken = await Csrf(member);
        using (var forbidden = await member.Send(HttpMethod.Post, "/internal/api/directory/items", new { }, memberToken))
            Assert.Equal(HttpStatusCode.Forbidden, forbidden.StatusCode);
        using (var disabled = await owner.Send(HttpMethod.Put, $"/internal/api/security/staff/{staff.Id}",
            new { displayName = staff.DisplayName, role = "Inventory", enabled = false, version = changedVersion }, ownerToken))
            Assert.Equal(HttpStatusCode.OK, disabled.StatusCode);
        using var revoked = await member.Send(HttpMethod.Get, "/internal/api/security/me");
        Assert.Equal(HttpStatusCode.Unauthorized, revoked.StatusCode);
    }

    private const string HttpFixturePassword = "synthetic-http-fixture-input-only";
    private static async Task<string> PrepareHttpFixture(InternalCommerceSqlDatabase fixture)
    {
        await using var db = fixture.Context();
        var staff = await db.Set<InternalStaff>().SingleAsync(candidate => candidate.Id == fixture.Actor);
        staff.PasswordHash = new PasswordHasher<InternalStaff>().HashPassword(staff, HttpFixturePassword);
        await db.SaveChangesAsync();
        return db.Database.GetConnectionString()!; // Never logged; scoped to the generated disposable fixture database.
    }

    private static async Task Login(HttpSession session, string loginName)
    {
        var token = await Csrf(session);
        using var response = await session.Send(HttpMethod.Post, "/internal/api/security/login",
            new { loginName, password = HttpFixturePassword }, token);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.True(response.Headers.TryGetValues("Set-Cookie", out var cookies) && cookies.Any(cookie =>
            cookie.StartsWith("__Host-Savia.Session=", StringComparison.Ordinal) && cookie.Contains("secure", StringComparison.OrdinalIgnoreCase)
            && cookie.Contains("httponly", StringComparison.OrdinalIgnoreCase) && cookie.Contains("samesite=strict", StringComparison.OrdinalIgnoreCase)));
    }

    private static async Task<string> Csrf(HttpSession session)
    {
        using var response = await session.Send(HttpMethod.Get, "/internal/api/security/csrf");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        return (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("token").GetString()!;
    }

    private sealed class HttpSession(HttpClient client) : IDisposable
    {
        private readonly Dictionary<string, string> cookies = new(StringComparer.Ordinal);
        public string CookieHeader => string.Join("; ", cookies.Select(cookie => cookie.Key + "=" + cookie.Value));
        public async Task<HttpResponseMessage> Send(HttpMethod method, string path, object? body = null, string? csrf = null)
        {
            using var request = new HttpRequestMessage(method, path);
            if (body is not null) request.Content = JsonContent.Create(body);
            if (cookies.Count != 0) request.Headers.Add("Cookie", CookieHeader);
            if (csrf is not null) request.Headers.Add("X-CSRF-TOKEN", csrf);
            var response = await client.SendAsync(request);
            if (response.Headers.TryGetValues("Set-Cookie", out var values))
                foreach (var value in values)
                {
                    var pair = value.Split(';')[0].Split('=', 2);
                    if (pair[1].Length == 0) cookies.Remove(pair[0]); else cookies[pair[0]] = pair[1];
                }
            return response;
        }
        public void Dispose() => client.Dispose();
    }

    private static HttpClient Client(JudgeFactory factory) => factory.CreateClient(new WebApplicationFactoryClientOptions
    { BaseAddress = new Uri("https://localhost"), AllowAutoRedirect = false, HandleCookies = false });

    private static RouteEndpoint[] InternalRoutes(JudgeFactory factory) => factory.Services.GetRequiredService<EndpointDataSource>()
        .Endpoints.OfType<RouteEndpoint>().Where(endpoint => endpoint.RoutePattern.RawText?.StartsWith("/internal", StringComparison.Ordinal) == true).ToArray();

    // Real Program and real cookie authentication; only configuration and ephemeral test key storage differ.
    // No fake principal, authentication handler, database provider or command runner is installed.
    private sealed class JudgeFactory(string environment = "Development", bool? enabled = true, string? connection = null) : WebApplicationFactory<Program>
    {
        protected override void ConfigureWebHost(IWebHostBuilder builder)
        {
            builder.UseEnvironment(environment);
            builder.UseSetting("Synthetic:Enabled", "false");
            if (enabled is { } value) builder.UseSetting("InternalSavia:Enabled", value.ToString());
            builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["Synthetic:Enabled"] = "false",
                ["InternalSavia:Enabled"] = enabled?.ToString(),
                ["ConnectionStrings:Store"] = "",
                ["ConnectionStrings:InternalSavia"] = connection ?? ""
            }));
            builder.ConfigureServices(services => services.AddDataProtection().UseEphemeralDataProtectionProvider());
        }
    }
}

// Two explicit authorization flags AND a private endpoint are required. Never executed in the current no-SQL lot.
public sealed class InternalJudgeHttpSqlFactAttribute : FactAttribute
{
    public InternalJudgeHttpSqlFactAttribute()
    {
        if (Environment.GetEnvironmentVariable("SAVIA_INTERNAL_SQL_TESTS_AUTHORIZED") != "1"
            || Environment.GetEnvironmentVariable("SAVIA_INTERNAL_HTTP_SQL_TESTS_AUTHORIZED") != "1"
            || string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("MARTHA_INTERNAL_TEST_SQL_CONNECTION")))
            Skip = "Not run: actual HTTP+SQL acceptance needs SAVIA_INTERNAL_SQL_TESTS_AUTHORIZED=1, SAVIA_INTERNAL_HTTP_SQL_TESTS_AUTHORIZED=1 and an authorized disposable MARTHA_INTERNAL_TEST_SQL_CONNECTION. No bootstrap or SQL execution in this lot.";
    }
}
