using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Text.Json;
using Martha.Store.Api.Internal;
using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Routing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Xunit;

namespace Martha.Store.Api.Tests;

public sealed class InternalDirectorySecurityTests
{
    [Fact]
    public async Task All_routes_require_read_policy_and_all_nine_mutations_require_owner_and_csrf()
    {
        await using var host = await DirectoryHost.Start();
        var endpoints = ((IEndpointRouteBuilder)host.App).DataSources.SelectMany(x => x.Endpoints).ToArray();
        Assert.Equal(15, endpoints.Length);
        var writes = 0;
        foreach (var endpoint in endpoints)
        {
            var authorization = endpoint.Metadata.GetOrderedMetadata<IAuthorizeData>();
            Assert.Contains(authorization, x => x.Policy == "internal.read");
            Assert.Null(endpoint.Metadata.GetMetadata<IAllowAnonymous>());
            var methods = endpoint.Metadata.GetMetadata<IHttpMethodMetadata>()!.HttpMethods;
            if (methods.Contains("GET")) continue;
            writes++;
            Assert.Contains(authorization, x => x.Policy == "internal.owner");
            Assert.NotNull(endpoint.Metadata.GetMetadata<InternalDirectoryMutationMetadata>());
        }
        Assert.Equal(9, writes);
    }

    [Theory]
    [InlineData(null, 401)] [InlineData("Visitor", 403)]
    [InlineData("Owner", 400)] [InlineData("Manager", 400)]
    [InlineData("Cashier", 400)] [InlineData("Inventory", 400)]
    public async Task Read_authorization_is_enforced_before_invalid_query_validation_without_sql(string? role, int status)
    {
        await using var host = await DirectoryHost.Start();
        using var request = new HttpRequestMessage(HttpMethod.Get, "/internal/api/directory/items?take=101");
        if (role is not null) request.Headers.Add("X-UnitTest-Role", role);
        using var response = await host.Client.SendAsync(request);
        Assert.Equal((HttpStatusCode)status, response.StatusCode);
        if (status == 400) Assert.True(response.Headers.CacheControl?.NoStore);
        Assert.Equal(0, host.Runner.Calls);
    }

    [Theory]
    [InlineData(null, 401)] [InlineData("Visitor", 403)]
    [InlineData("Cashier", 403)] [InlineData("Inventory", 403)]
    [InlineData("Owner", 400)] [InlineData("Manager", 403)]
    public async Task Every_write_requires_owner_and_a_csrf_token(string? role, int status)
    {
        await using var host = await DirectoryHost.Start();
        foreach (var resource in new[] { "items", "locations", "parties" })
        foreach (var method in new[] { HttpMethod.Post, HttpMethod.Put, HttpMethod.Delete })
        {
            var suffix = method == HttpMethod.Post ? "" : "/" + Guid.NewGuid();
            using var request = new HttpRequestMessage(method, "/internal/api/directory/" + resource + suffix);
            if (role is not null) request.Headers.Add("X-UnitTest-Role", role);
            request.Headers.Add("Idempotency-Key", "valid-key-123456789");
            if (method != HttpMethod.Delete) request.Content = resource switch
            {
                "items" => JsonContent.Create(new InternalItemWrite("UNIT-1", "Synthetic Item", 100, "USD")),
                "locations" => JsonContent.Create(new InternalLocationWrite("Synthetic Location")),
                _ => JsonContent.Create(new InternalPartyWrite("customer", "Synthetic Person"))
            };
            using var response = await host.Client.SendAsync(request);
            Assert.Equal((HttpStatusCode)status, response.StatusCode);
        }
        Assert.Equal(0, host.Runner.Calls);
    }

    [Fact]
    public async Task Missing_actor_is_rejected_even_with_manager_role_and_valid_test_csrf()
    {
        await using var host = await DirectoryHost.Start();
        using var request = WriteRequest();
        request.Headers.Add("X-UnitTest-Identity", "not-a-guid");
        using var response = await host.Client.SendAsync(request);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        Assert.Equal(0, host.Runner.Calls);
    }

    [Theory]
    [InlineData(null)] [InlineData("")] [InlineData("short")] [InlineData("invalid key with spaces")]
    [InlineData("one-valid-key-1234,two-valid-key-1234")]
    public async Task Invalid_or_multiple_keys_never_reach_command_runner(string? key)
    {
        await using var host = await DirectoryHost.Start();
        using var request = WriteRequest(key);
        using var response = await host.Client.SendAsync(request);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        Assert.Equal(0, host.Runner.Calls);
    }

    [Fact]
    public async Task Authorized_write_reaches_only_shared_runner_and_never_fake_persistence()
    {
        await using var host = await DirectoryHost.Start();
        using var request = WriteRequest();
        using var response = await host.Client.SendAsync(request);
        Assert.Equal(HttpStatusCode.ServiceUnavailable, response.StatusCode); // Recorder intentionally does not execute SQL.
        Assert.Equal(1, host.Runner.Calls);
        Assert.Equal(DirectoryTestAuthentication.ActorId, host.Runner.Actor);
        Assert.Equal("directory.locations.create", host.Runner.Scope);
    }

    [Theory]
    [InlineData("unauthenticated", 401)]
    [InlineData("unauthorized", 401)]
    [InlineData("forbidden", 403)]
    [InlineData("unknown_outcome", 503)]
    [InlineData("storage_unavailable", 503)]
    [InlineData("idempotency_conflict", 409)]
    public async Task Runner_error_semantics_are_preserved_by_http_mapper(string error, int status)
    {
        await using var host = await DirectoryHost.Start(error);
        using var request = WriteRequest();
        using var response = await host.Client.SendAsync(request);
        Assert.Equal((HttpStatusCode)status, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(error, body.GetProperty("code").GetString());
        Assert.Equal(1, host.Runner.Calls);
    }

    [Theory]
    [InlineData("GET")]
    [InlineData("POST")]
    public async Task Plain_http_is_rejected_before_reads_or_commands(string method)
    {
        await using var host = await DirectoryHost.Start();
        using var request = method == "POST" ? WriteRequest() :
            new HttpRequestMessage(HttpMethod.Get, "/internal/api/directory/items");
        if (method == "GET") request.Headers.Add("X-UnitTest-Role", "Owner");
        request.RequestUri = new Uri("http://localhost" + request.RequestUri!.OriginalString);
        using var response = await host.Client.SendAsync(request);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("https_required", body.GetProperty("code").GetString());
        Assert.Equal(0, host.Runner.Calls);
    }

    private static HttpRequestMessage WriteRequest(string? key = "valid-key-123456789")
    {
        var request = new HttpRequestMessage(HttpMethod.Post, "/internal/api/directory/locations")
        { Content = JsonContent.Create(new InternalLocationWrite("Synthetic Location")) };
        request.Headers.Add("X-UnitTest-Role", "Owner");
        request.Headers.Add("X-UnitTest-Csrf", "unit-only-token");
        if (key is not null) request.Headers.TryAddWithoutValidation("Idempotency-Key", key);
        return request;
    }

    private sealed class DirectoryHost(WebApplication app, HttpClient client, InternalDirectoryCommandTests.RecordingRunner runner) : IAsyncDisposable
    {
        public WebApplication App { get; } = app;
        public HttpClient Client { get; } = client;
        public InternalDirectoryCommandTests.RecordingRunner Runner { get; } = runner;
        public static async Task<DirectoryHost> Start(string runnerError = "storage_unavailable")
        {
            var builder = WebApplication.CreateBuilder(new WebApplicationOptions { EnvironmentName = "Test" });
            builder.WebHost.UseTestServer();
            builder.Logging.ClearProviders();
            builder.Services.AddAuthentication("DirectoryTest").AddScheme<AuthenticationSchemeOptions, DirectoryTestAuthentication>("DirectoryTest", _ => { });
            builder.Services.AddAuthorization(options =>
            {
                options.AddPolicy("internal.read", p => p.RequireAuthenticatedUser().RequireRole("Owner", "Manager", "Cashier", "Inventory"));
                options.AddPolicy("internal.manage", p => p.RequireAuthenticatedUser().RequireRole("Owner", "Manager"));
                options.AddPolicy("internal.owner", p => p.RequireAuthenticatedUser().RequireRole("Owner"));
            });
            builder.Services.AddScoped(_ => InternalDirectoryModelTests.Database());
            var runner = new InternalDirectoryCommandTests.RecordingRunner { Error = runnerError };
            builder.Services.AddSingleton<IInternalCommandRunner>(runner);
            builder.Services.AddSingleton<IAntiforgery, DirectoryTestAntiforgery>();
            var app = builder.Build();
            app.UseAuthentication();
            app.UseAuthorization();
            app.MapInternalDirectory();
            await app.StartAsync();
            var client = app.GetTestClient();
            client.BaseAddress = new Uri("https://localhost");
            return new(app, client, runner);
        }
        public async ValueTask DisposeAsync() { Client.Dispose(); await App.DisposeAsync(); }
    }

    // Authentication and token doubles exist ONLY in this test assembly. They prove
    // route/filter wiring, not production cookie issuance/revocation or SQL behavior.
    private sealed class DirectoryTestAuthentication(IOptionsMonitor<AuthenticationSchemeOptions> options, ILoggerFactory logger, UrlEncoder encoder)
        : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
    {
        public static readonly Guid ActorId = Guid.Parse("70000000-0000-0000-0000-000000000001");
        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            var role = Request.Headers["X-UnitTest-Role"].ToString();
            if (role.Length == 0) return Task.FromResult(AuthenticateResult.NoResult());
            var actor = Request.Headers["X-UnitTest-Identity"].FirstOrDefault() ?? ActorId.ToString();
            var principal = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, actor), new Claim(ClaimTypes.Role, role)], Scheme.Name));
            return Task.FromResult(AuthenticateResult.Success(new AuthenticationTicket(principal, Scheme.Name)));
        }
    }

    private sealed class DirectoryTestAntiforgery : IAntiforgery
    {
        public AntiforgeryTokenSet GetAndStoreTokens(HttpContext httpContext) => throw new NotSupportedException();
        public AntiforgeryTokenSet GetTokens(HttpContext httpContext) => throw new NotSupportedException();
        public Task<bool> IsRequestValidAsync(HttpContext httpContext) => Task.FromResult(httpContext.Request.Headers["X-UnitTest-Csrf"] == "unit-only-token");
        public async Task ValidateRequestAsync(HttpContext httpContext)
        {
            if (!await IsRequestValidAsync(httpContext)) throw new AntiforgeryValidationException("Unit-test missing CSRF token.");
        }
        public void SetCookieTokenAndHeader(HttpContext httpContext) => throw new NotSupportedException();
    }
}
