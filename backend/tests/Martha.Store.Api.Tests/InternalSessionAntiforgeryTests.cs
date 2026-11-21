using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using Martha.Store.Api.Internal;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Xunit;

namespace Martha.Store.Api.Tests;

public sealed class InternalSessionAntiforgeryTests
{
    private const string S1 = "11111111-1111-4111-8111-111111111111";
    private const string S2 = "22222222-2222-4222-8222-222222222222";
    private const string UserId = "33333333-3333-4333-8333-333333333333";
    private static ClaimsPrincipal Principal(string? session = S1, string user = UserId) => new(new ClaimsIdentity(
        new[] { new Claim(ClaimTypes.NameIdentifier, user), new Claim(ClaimTypes.Name, "synthetic.owner"),
            new Claim(ClaimTypes.Role, "Owner"), new Claim(InternalSecurityRules.VersionClaim, UserId) }
            .Concat(session is null ? [] : new[] { new Claim(InternalSecurityRules.SessionClaim, session) }), InternalSecurityRules.Scheme));

    [Fact]
    public async Task Actual_framework_provider_is_replaced_after_registration()
    {
        await using var f = await Fixture.Create();
        Assert.IsType<InternalSessionAntiforgeryAdditionalDataProvider>(f.Provider);
        var http = new DefaultHttpContext { User = Principal() };
        Assert.Equal("s1:" + S1, f.Provider.GetAdditionalData(http));
        Assert.False(f.Provider.ValidateAdditionalData(http, ""));
        Assert.False(f.Provider.ValidateAdditionalData(http, "S1:" + S1));
        http.User = new ClaimsPrincipal(new ClaimsIdentity());
        Assert.Equal("", f.Provider.GetAdditionalData(http));
        Assert.True(f.Provider.ValidateAdditionalData(http, ""));
        Assert.False(f.Provider.ValidateAdditionalData(http, "s1:" + S1));
    }

    [Theory]
    [InlineData("/common")]
    [InlineData("/directory")]
    public async Task Session_transition_rejects_stale_token_before_handler(string path)
    {
        await using var f = await Fixture.Create();
        var original = f.User.Claims.Select(c => (c.Type, c.Value)).ToArray();
        var t1 = await f.Token();
        Assert.Equal(HttpStatusCode.NoContent, await f.Post(path, t1));
        f.User = Principal(S2);
        Assert.Equal(original.Where(c => c.Type != InternalSecurityRules.SessionClaim),
            f.User.Claims.Where(c => c.Type != InternalSecurityRules.SessionClaim).Select(c => (c.Type, c.Value)));
        var before = f.Writes;
        Assert.Equal(HttpStatusCode.BadRequest, await f.Post(path, t1));
        Assert.Equal(before, f.Writes);
        var t2 = await f.Token();
        var t3 = await f.Token();
        foreach (var token in new[] { t2, t2, t3 }) Assert.Equal(HttpStatusCode.NoContent, await f.Post(path, token));
        Assert.Equal(before + 3, f.Writes);
        f.NoLeaks();
    }

    [Theory]
    [InlineData("/common")]
    [InlineData("/directory")]
    public async Task Invalid_principals_and_transport_never_reach_handler(string path)
    {
        await using var f = await Fixture.Create();
        var token = await f.Token();
        var invalid = new List<ClaimsPrincipal> { Principal(null), Principal(""), Principal("bad-private-claim"),
            Principal(Guid.Empty.ToString("D")), Principal(S1.Replace("-", "")), Principal(S1.ToUpperInvariant().Replace("11111111", "AAAAAAAA")) };
        var duplicate = Principal();
        ((ClaimsIdentity)duplicate.Identity!).AddClaim(new Claim(InternalSecurityRules.SessionClaim, S1));
        invalid.Add(duplicate);
        var differentDuplicate = Principal();
        ((ClaimsIdentity)differentDuplicate.Identity!).AddClaim(new Claim(InternalSecurityRules.SessionClaim, S2));
        invalid.Add(differentDuplicate);
        invalid.Add(new ClaimsPrincipal(new[] { (ClaimsIdentity)Principal().Identity!, (ClaimsIdentity)Principal(S2).Identity! }));
        invalid.Add(new ClaimsPrincipal(new[] { (ClaimsIdentity)Principal().Identity!, new ClaimsIdentity(new[] { new Claim(InternalSecurityRules.SessionClaim, S1) }) }));
        invalid.Add(new ClaimsPrincipal(new[] { new ClaimsIdentity(new[] { new Claim(InternalSecurityRules.SessionClaim, S1) }), (ClaimsIdentity)Principal(null).Identity! }));
        foreach (var principal in invalid)
        {
            f.User = principal;
            f.Secrets.AddRange(principal.FindAll(InternalSecurityRules.SessionClaim).Select(c => c.Value));
            // Directory rejects an unauthenticated primary identity before its direct CSRF validator.
            var status = path == "/directory" && principal.Identity?.IsAuthenticated != true
                ? HttpStatusCode.Unauthorized : HttpStatusCode.BadRequest;
            Assert.Equal(status, await f.Post(path, token));
            Assert.False(f.Provider.ValidateAdditionalData(new DefaultHttpContext { User = principal }, "s1:" + S1));
            var error = await Assert.ThrowsAsync<InvalidOperationException>(() => f.Token());
            Assert.Equal("Invalid internal session identity.", error.Message);
        }
        f.User = Principal(S1, "44444444-4444-4444-8444-444444444444");
        Assert.Equal(HttpStatusCode.BadRequest, await f.Post(path, token));
        f.User = Principal();
        Assert.Equal(HttpStatusCode.BadRequest, await f.Post(path, null));
        Assert.Equal(HttpStatusCode.BadRequest, await f.Post(path, token, cookie: ""));
        Assert.Equal(HttpStatusCode.BadRequest, await f.Post(path, token, cookie: "__Host-Savia.Csrf=synthetic-wrong-cookie"));
        Assert.Equal(HttpStatusCode.BadRequest, await f.Post(path, token, duplicate: true));
        Assert.Equal(0, f.Writes);
        f.NoLeaks();
    }

    [Fact]
    public async Task Anonymous_empty_additional_data_still_works_and_authenticated_legacy_is_rejected()
    {
        await using var f = await Fixture.Create();
        f.User = new ClaimsPrincipal(new ClaimsIdentity());
        var anonymous = await f.Token();
        Assert.Equal(HttpStatusCode.NoContent, await f.Post("/common", anonymous));
        f.User = Principal();
        Assert.Equal(HttpStatusCode.BadRequest, await f.Post("/common", anonymous));
        Assert.Equal(HttpStatusCode.BadRequest, await f.Post("/common", anonymous, http: true));
        // A separate genuine framework host issues a legacy token with the SAME data-protection provider and cookie.
        await using var legacy = await Fixture.Create(f.Protection, legacy: true);
        var old = await legacy.Token(f.Cookie);
        Assert.Equal(HttpStatusCode.BadRequest, await f.Post("/common", old));
        Assert.Equal(HttpStatusCode.BadRequest, await f.Post("/directory", old));
        f.NoLeaks();
    }

    private sealed class Fixture : IAsyncDisposable
    {
        public ClaimsPrincipal User = Principal();
        public int Writes;
        public string Cookie = "";
        public readonly List<string> Secrets = new() { "bad-private-claim", "synthetic-wrong-cookie", "synthetic-password" };
        public readonly List<string> Observed = new();
        public IDataProtectionProvider Protection = new EphemeralDataProtectionProvider();
        public IAntiforgeryAdditionalDataProvider Provider => app.Services.GetRequiredService<IAntiforgeryAdditionalDataProvider>();
        private WebApplication app = null!;
        private HttpClient client = null!;
        public static async Task<Fixture> Create(IDataProtectionProvider? protection = null, bool legacy = false)
        {
            var f = new Fixture();
            if (protection is not null) f.Protection = protection;
            var b = WebApplication.CreateBuilder(new WebApplicationOptions { EnvironmentName = "Testing", ApplicationName = typeof(InternalSecurity).Assembly.GetName().Name });
            b.WebHost.UseTestServer();
            b.Logging.ClearProviders();
            b.Logging.AddProvider(new Capture(f.Observed));
            b.Services.AddSingleton(f.Protection);
            b.Services.AddInternalSecurity();
            if (legacy) b.Services.AddSingleton<IAntiforgeryAdditionalDataProvider, EmptyAdditionalData>();
            f.app = b.Build();
            f.app.Use(async (http, next) => { http.User = f.User; await next(http); });
            f.app.MapGet("/token", (HttpContext h, IAntiforgery a) => a.GetAndStoreTokens(h).RequestToken!);
            f.app.MapPost("/common", () => { f.Writes++; return Results.NoContent(); }).RequireInternalCsrf();
            f.app.MapPost("/directory", () => { f.Writes++; return Results.NoContent(); }).AddEndpointFilter<InternalDirectoryMutationFilter>();
            await f.app.StartAsync();
            f.client = f.app.GetTestClient(); f.client.BaseAddress = new Uri("https://localhost");
            return f;
        }
        public async Task<string> Token(string? cookie = null)
        {
            using var r = new HttpRequestMessage(HttpMethod.Get, "/token");
            if ((cookie ?? Cookie).Length > 0) r.Headers.Add("Cookie", cookie ?? Cookie);
            using var response = await client.SendAsync(r);
            response.EnsureSuccessStatusCode();
            if (response.Headers.TryGetValues("Set-Cookie", out var values)) Cookie = values.Single().Split(';')[0];
            var token = await response.Content.ReadAsStringAsync(); Secrets.Add(token); Secrets.Add(Cookie); if (Cookie.Contains('=')) Secrets.Add(Cookie.Split('=', 2)[1]);
            return token;
        }
        public async Task<HttpStatusCode> Post(string path, string? token, string? cookie = null, bool duplicate = false, bool http = false)
        {
            using var r = new HttpRequestMessage(HttpMethod.Post, (http ? "http://localhost" : "https://localhost") + path);
            if ((cookie ?? Cookie).Length > 0) r.Headers.Add("Cookie", cookie ?? Cookie);
            if (token is not null) r.Headers.Add(InternalSecurity.CsrfHeader, duplicate ? new[] { token, token } : new[] { token });
            r.Headers.Add("Idempotency-Key", "synthetic-session-csrf-key");
            r.Content = JsonContent.Create(new { password = "synthetic-password" });
            using var response = await client.SendAsync(r);
            Observed.Add(await response.Content.ReadAsStringAsync());
            Observed.Add(response.Headers.ToString());
            return response.StatusCode;
        }
        public void NoLeaks()
        {
            var output = string.Join("\n", Observed);
            foreach (var secret in Secrets.Where(s => s.Length > 0)) Assert.DoesNotContain(secret, output);
        }
        public async ValueTask DisposeAsync() { client.Dispose(); await app.DisposeAsync(); }
    }
    private sealed class EmptyAdditionalData : IAntiforgeryAdditionalDataProvider
    {
        public string GetAdditionalData(HttpContext context) => "";
        public bool ValidateAdditionalData(HttpContext context, string additionalData) => additionalData == "";
    }
    private sealed class Capture(List<string> lines) : ILoggerProvider
    {
        public ILogger CreateLogger(string categoryName) => new Sink(lines);
        public void Dispose() { }
        private sealed class Sink(List<string> lines) : ILogger
        {
            public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
            public bool IsEnabled(LogLevel level) => true;
            public void Log<TState>(LogLevel level, EventId id, TState state, Exception? exception, Func<TState, Exception?, string> formatter)
            { lock (lines) lines.Add(formatter(state, exception)); }
        }
    }
}
