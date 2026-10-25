using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using Martha.Store.Api.Internal;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;
using Xunit;

namespace Martha.Store.Api.Tests;

public sealed class InternalSecurityTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 25, 0, 0, 0, TimeSpan.Zero);

    [Theory]
    [InlineData("Owner", true)] [InlineData("Manager", true)] [InlineData("Cashier", true)] [InlineData("Inventory", true)]
    [InlineData("owner", false)] [InlineData("Admin", false)] [InlineData("Owner,Manager", false)] [InlineData(null, false)]
    public void Roles_are_a_closed_server_allowlist(string? role, bool expected) => Assert.Equal(expected, InternalSecurityRules.ValidRole(role));

    [Theory]
    [InlineData("staff.member", true)] [InlineData("TEST-ONLY_01", true)] [InlineData("aa", false)]
    [InlineData("a b", false)] [InlineData(" staff", false)] [InlineData("stáff", false)] [InlineData(null, false)]
    public void Login_names_are_bounded_unambiguous_identifiers(string? name, bool expected) => Assert.Equal(expected, InternalSecurityRules.ValidLoginName(name));

    [Fact]
    public void Password_policy_allows_passphrases_without_silent_truncation()
    {
        Assert.True(InternalSecurityRules.ValidPassword("a synthetic test passphrase"));
        Assert.False(InternalSecurityRules.ValidPassword(new string('x', 14)));
        Assert.True(InternalSecurityRules.ValidPassword(new string('x', 128)));
        Assert.False(InternalSecurityRules.ValidPassword(new string('x', 129)));
        Assert.False(InternalSecurityRules.ValidPassword(new string(' ', 20)));
        Assert.False(InternalSecurityRules.ValidPassword("synthetic test\npassphrase"));
    }

    [Fact]
    public void Credential_request_diagnostics_do_not_print_passwords()
    {
        const string password = "synthetic-redaction-test-input";
        Assert.DoesNotContain(password, new InternalLoginRequest("test-only", password).ToString());
        Assert.DoesNotContain(password, new InternalStaffCreateRequest("test-only", "Fixture", "Owner", password).ToString());
        Assert.DoesNotContain(password, new InternalStaffPasswordRequest(password, Guid.NewGuid()).ToString());
    }

    [Fact]
    public void Persisted_session_and_current_staff_are_both_required()
    {
        var (staff, session) = Fixture();
        var principal = InternalSecurityRules.Principal(staff, session);
        Assert.True(InternalSecurityRules.SessionIsValid(staff, session, principal, Now));
        Assert.False(InternalSecurityRules.SessionIsValid(null, session, principal, Now));
        Assert.False(InternalSecurityRules.SessionIsValid(staff, null, principal, Now));
        Assert.False(InternalSecurityRules.SessionIsValid(staff, session, new ClaimsPrincipal(), Now));
        staff.Enabled = false;
        Assert.False(InternalSecurityRules.SessionIsValid(staff, session, principal, Now));
    }

    [Theory]
    [InlineData("role")] [InlineData("version")] [InlineData("revoked")] [InlineData("expired")]
    [InlineData("future")] [InlineData("too_long")] [InlineData("wrong_staff")] [InlineData("unknown_role")]
    [InlineData("duplicate_role")] [InlineData("duplicate_actor")] [InlineData("missing_session")]
    public void Stale_or_forged_claims_and_invalid_sessions_are_rejected(string mutation)
    {
        var (staff, session) = Fixture();
        var principal = InternalSecurityRules.Principal(staff, session);
        var identity = (ClaimsIdentity)principal.Identity!;
        switch (mutation)
        {
            case "role": staff.Role = "Cashier"; break;
            case "version": staff.SecurityVersion = Guid.NewGuid(); break;
            case "revoked": session.RevokedAt = Now; break;
            case "expired": session.ExpiresAt = Now; break;
            case "future": session.CreatedAt = Now.AddSeconds(1); break;
            case "too_long": session.ExpiresAt = session.CreatedAt.AddHours(9); break;
            case "wrong_staff": session.StaffId = Guid.NewGuid(); break;
            case "unknown_role": staff.Role = "Admin"; break;
            case "duplicate_role": identity.AddClaim(new Claim(ClaimTypes.Role, "Cashier")); break;
            case "duplicate_actor": identity.AddClaim(new Claim(ClaimTypes.NameIdentifier, staff.Id.ToString("D"))); break;
            case "missing_session": identity.RemoveClaim(identity.FindFirst(InternalSecurityRules.SessionClaim)!); break;
        }
        Assert.False(InternalSecurityRules.SessionIsValid(staff, session, principal, Now));
    }

    [Fact]
    public void Lockout_counter_is_bounded_and_resets_only_after_expiry()
    {
        var (staff, _) = Fixture();
        for (var i = 0; i < 5; i++) InternalSecurityRules.RecordFailure(staff, Now);
        Assert.Equal(5, staff.FailedSignIns);
        Assert.Equal(Now.AddMinutes(15), staff.LockedUntil);
        InternalSecurityRules.RecordFailure(staff, Now.AddMinutes(15));
        Assert.Equal(1, staff.FailedSignIns);
        Assert.Null(staff.LockedUntil);
    }

    [Fact]
    public void Login_admission_bounds_concurrency_and_attempts_then_recovers()
    {
        var time = new TestTime(Now);
        var limiter = new InternalLoginLimiter(time);
        var leases = Enumerable.Range(0, 4).Select(i => limiter.TryEnter("127.0.0." + i)).ToArray();
        Assert.All(leases, lease => Assert.NotNull(lease));
        Assert.Null(limiter.TryEnter("127.0.0.9"));
        foreach (var lease in leases) { lease!.Dispose(); lease.Dispose(); }
        for (var i = 0; i < 10; i++) { using var lease = limiter.TryEnter("192.0.2.1"); Assert.NotNull(lease); }
        Assert.Null(limiter.TryEnter("192.0.2.1"));
        Assert.Null(limiter.TryEnter(new string('x', 65)));
        time.Advance(TimeSpan.FromMinutes(1));
        using var recovered = limiter.TryEnter("192.0.2.1");
        Assert.NotNull(recovered);
    }

    [Fact]
    public void Global_login_budget_is_shared_across_addresses_and_recovers_after_window()
    {
        var time = new TestTime(Now);
        var limiter = new InternalLoginLimiter(time);
        for (var i = 0; i < 120; i++) { using var lease = limiter.TryEnter("192.0.2." + i); Assert.NotNull(lease); }
        Assert.Null(limiter.TryEnter("198.51.100.1"));
        time.Advance(TimeSpan.FromMinutes(1));
        using var recovered = limiter.TryEnter("198.51.100.1");
        Assert.NotNull(recovered);
    }

    [Fact]
    public void Registered_password_hasher_uses_salted_hashes_and_rejects_wrong_input()
    {
        var services = new ServiceCollection().AddLogging();
        services.AddInternalSecurity();
        using var provider = services.BuildServiceProvider();
        using var scope = provider.CreateScope();
        var passwords = scope.ServiceProvider.GetRequiredService<IPasswordHasher<InternalStaff>>();
        var staff = new InternalStaff(); // In-memory synthetic fixture only; no identity is persisted/provisioned.
        const string input = "synthetic hashing test input";
        var first = passwords.HashPassword(staff, input);
        var second = passwords.HashPassword(staff, input);
        Assert.NotEqual(first, second);
        Assert.DoesNotContain(input, first);
        Assert.Equal(PasswordVerificationResult.Success, passwords.VerifyHashedPassword(staff, first, input));
        Assert.Equal(PasswordVerificationResult.Failed, passwords.VerifyHashedPassword(staff, first, "different synthetic input"));
        Assert.Equal(210_000, provider.GetRequiredService<IOptions<PasswordHasherOptions>>().Value.IterationCount);
    }

    [Theory]
    [InlineData("internal.owner", "Owner", true)] [InlineData("internal.owner", "Manager", false)]
    [InlineData("internal.manage", "Manager", true)] [InlineData("internal.manage", "Cashier", false)]
    [InlineData("internal.sell", "Cashier", true)] [InlineData("internal.sell", "Inventory", false)]
    [InlineData("internal.inventory", "Inventory", true)] [InlineData("internal.inventory", "Cashier", false)]
    [InlineData("internal.read", "Inventory", true)] [InlineData("internal.read", "Unknown", false)]
    public async Task Policies_enforce_role_boundaries(string policy, string role, bool expected)
    {
        var services = new ServiceCollection().AddLogging();
        services.AddInternalSecurity();
        await using var provider = services.BuildServiceProvider();
        var authorization = provider.GetRequiredService<IAuthorizationService>();
        var principal = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.Role, role)], InternalSecurityRules.Scheme));
        Assert.Equal(expected, (await authorization.AuthorizeAsync(principal, null, policy)).Succeeded);
        Assert.False((await authorization.AuthorizeAsync(new ClaimsPrincipal(), null, policy)).Succeeded);
    }

    [Fact]
    public async Task Cookies_are_host_scoped_strict_secure_http_only_and_not_sliding()
    {
        await using var app = await TestApp();
        var cookie = app.Services.GetRequiredService<IOptionsMonitor<CookieAuthenticationOptions>>().Get(InternalSecurityRules.Scheme);
        Assert.Equal("__Host-Savia.Session", cookie.Cookie.Name);
        Assert.Equal("/", cookie.Cookie.Path);
        Assert.Null(cookie.Cookie.Domain);
        Assert.True(cookie.Cookie.HttpOnly);
        Assert.Equal(CookieSecurePolicy.Always, cookie.Cookie.SecurePolicy);
        Assert.Equal(SameSiteMode.Strict, cookie.Cookie.SameSite);
        Assert.False(cookie.SlidingExpiration);
        Assert.Equal(TimeSpan.FromHours(8), cookie.ExpireTimeSpan);
        var csrf = app.Services.GetRequiredService<IOptions<AntiforgeryOptions>>().Value;
        Assert.Equal("__Host-Savia.Csrf", csrf.Cookie.Name);
        Assert.True(csrf.Cookie.HttpOnly);
        Assert.Equal(CookieSecurePolicy.Always, csrf.Cookie.SecurePolicy);
        Assert.Equal(SameSiteMode.Strict, csrf.Cookie.SameSite);
        Assert.Null(csrf.Cookie.Domain);
    }

    [Fact]
    public async Task Login_and_reusable_mutation_filter_require_a_real_csrf_pair_even_when_anonymous()
    {
        await using var app = await TestApp();
        using var client = app.GetTestClient();
        client.BaseAddress = new Uri("https://localhost");
        var body = new InternalLoginRequest("", ""); // Invalid identity returns before any SQL query after CSRF succeeds.
        var missing = await client.PostAsJsonAsync("/internal/api/security/login", body);
        Assert.Equal(HttpStatusCode.BadRequest, missing.StatusCode);
        Assert.Contains("csrf_invalid", await missing.Content.ReadAsStringAsync());
        var tokenResponse = await client.GetAsync("/internal/api/security/csrf");
        Assert.Equal(HttpStatusCode.OK, tokenResponse.StatusCode);
        Assert.Contains("no-store", tokenResponse.Headers.CacheControl!.ToString());
        var cookie = Assert.Single(tokenResponse.Headers.GetValues("Set-Cookie"));
        Assert.Contains("secure", cookie);
        Assert.Contains("httponly", cookie);
        Assert.Contains("samesite=strict", cookie);
        var token = (await tokenResponse.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("token").GetString();
        client.DefaultRequestHeaders.Add("Cookie", cookie.Split(';')[0]);
        client.DefaultRequestHeaders.Add(InternalSecurity.CsrfHeader, "not-a-token");
        var bad = await client.PostAsJsonAsync("/internal/api/security/login", body);
        Assert.Equal(HttpStatusCode.BadRequest, bad.StatusCode);
        client.DefaultRequestHeaders.Remove(InternalSecurity.CsrfHeader);
        client.DefaultRequestHeaders.Add(InternalSecurity.CsrfHeader, token);
        var admitted = await client.PostAsJsonAsync("/internal/api/security/login", body);
        Assert.Equal(HttpStatusCode.Unauthorized, admitted.StatusCode);
        Assert.Contains("invalid_credentials", await admitted.Content.ReadAsStringAsync());
        Assert.Equal(HttpStatusCode.NoContent, (await client.PostAsync("/test-mutation", null)).StatusCode);
        client.DefaultRequestHeaders.Remove("Cookie");
        Assert.Equal(HttpStatusCode.BadRequest, (await client.PostAsync("/test-mutation", null)).StatusCode);
    }

    [Fact]
    public async Task Anonymous_role_headers_cannot_authorize_staff_endpoints_and_http_cannot_get_tokens()
    {
        await using var app = await TestApp();
        using var client = app.GetTestClient();
        client.BaseAddress = new Uri("https://localhost");
        client.DefaultRequestHeaders.Add("X-Actor-Id", Guid.NewGuid().ToString());
        client.DefaultRequestHeaders.Add("X-Role", "Owner");
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/internal/api/security/me")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/internal/api/security/staff")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await client.GetAsync("http://localhost/internal/api/security/csrf")).StatusCode);
    }

    [Fact]
    public async Task Anonymous_challenges_and_login_csrf_do_not_resolve_database_configuration()
    {
        var databaseResolutions = 0;
        await using var app = await TestApp(() =>
        {
            Interlocked.Increment(ref databaseResolutions);
            throw new InvalidOperationException("Test: missing guarded database configuration must not be resolved anonymously.");
        });
        using var client = app.GetTestClient();
        client.BaseAddress = new Uri("https://localhost");
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/internal/api/security/csrf")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/internal/api/security/me")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/internal/api/security/staff")).StatusCode);
        var login = await client.PostAsJsonAsync("/internal/api/security/login", new InternalLoginRequest("fixture-only", "test-only-input"));
        Assert.Equal(HttpStatusCode.BadRequest, login.StatusCode);
        Assert.Contains("csrf_invalid", await login.Content.ReadAsStringAsync());
        Assert.Equal(0, databaseResolutions);
    }

    [Fact]
    public void Staff_and_sessions_are_in_separate_schema_with_unique_login_and_concurrency_guard()
    {
        using var db = new InternalDbContext(new DbContextOptionsBuilder<InternalDbContext>()
            .UseSqlServer("Server=127.0.0.1,1;Database=MarthaInternal_ModelOnly;Integrated Security=true;Connect Timeout=1").Options);
        var staff = db.Model.FindEntityType(typeof(InternalStaff))!;
        Assert.Equal("savia_internal", staff.GetSchema());
        Assert.Contains(staff.GetIndexes(), index => index.IsUnique && index.Properties.Single().Name == nameof(InternalStaff.NormalizedLoginName));
        Assert.True(staff.FindProperty(nameof(InternalStaff.RowVersion))!.IsConcurrencyToken);
        var sessions = db.Model.FindEntityType(typeof(InternalSession))!;
        Assert.Equal("savia_internal", sessions.GetSchema());
        Assert.Single(sessions.GetForeignKeys());
        var publicFields = typeof(InternalStaffView).GetProperties().Select(property => property.Name);
        Assert.DoesNotContain("PasswordHash", publicFields);
        Assert.DoesNotContain("LockedUntil", publicFields);
    }

    private static (InternalStaff, InternalSession) Fixture()
    {
        var staff = new InternalStaff { Id = Guid.NewGuid(), LoginName = "test-only", Role = "Owner", Enabled = true, SecurityVersion = Guid.NewGuid() };
        var session = new InternalSession { Id = Guid.NewGuid(), StaffId = staff.Id, SecurityVersion = staff.SecurityVersion,
            CreatedAt = Now.AddMinutes(-1), ExpiresAt = Now.AddHours(7) };
        return (staff, session);
    }

    private static async Task<WebApplication> TestApp(Action? resolvingDatabase = null)
    {
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions { EnvironmentName = "Testing" });
        builder.WebHost.UseTestServer();
        builder.Services.AddDataProtection().UseEphemeralDataProtectionProvider();
        builder.Services.AddDbContext<InternalDbContext>(options =>
        {
            resolvingDatabase?.Invoke();
            options.UseSqlServer("Server=127.0.0.1,1;Database=MarthaInternal_NoConnection;Integrated Security=true;Connect Timeout=1");
        });
        builder.Services.AddInternalSecurity();
        var app = builder.Build();
        app.UseAuthentication();
        app.UseAuthorization();
        app.MapInternalSecurity();
        app.MapPost("/test-mutation", () => Results.NoContent()).RequireInternalCsrf();
        await app.StartAsync();
        return app;
    }

    private sealed class TestTime(DateTimeOffset initial) : TimeProvider
    {
        private DateTimeOffset now = initial;
        public override DateTimeOffset GetUtcNow() => now;
        public void Advance(TimeSpan delta) => now += delta;
    }
}
