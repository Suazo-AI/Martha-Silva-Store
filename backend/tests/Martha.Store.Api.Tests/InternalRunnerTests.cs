using System.Data.Common;
using System.Security.Claims;
using Martha.Store.Api;
using Martha.Store.Api.Internal;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Xunit;

namespace Martha.Store.Api.Tests;

// Real command runner, but no live SQL and no substitute transaction engine.
// These assertions cover admission only; they do not prove persistence or session revalidation.
public sealed class InternalRunnerTests
{
    private static readonly Guid Actor = Guid.Parse("90000000-0000-0000-0000-000000000001");
    private const string Scope = "directory.items.create";
    private const string Key = "runner-test-key-0001";
    private static readonly string Fingerprint = InternalRules.Fingerprint(new { Fixture = "runner-admission" });

    public static TheoryData<string, string[]> ScopeRoles => new()
    {
        { "directory.items.create", ["Owner", "Manager"] },
        { "directory.items.update", ["Owner", "Manager"] },
        { "directory.items.deactivate", ["Owner", "Manager"] },
        { "directory.locations.create", ["Owner", "Manager"] },
        { "directory.locations.update", ["Owner", "Manager"] },
        { "directory.locations.deactivate", ["Owner", "Manager"] },
        { "directory.parties.create", ["Owner", "Manager"] },
        { "directory.parties.update", ["Owner", "Manager"] },
        { "directory.parties.deactivate", ["Owner", "Manager"] },
        { "supply.purchase.create", ["Owner", "Manager"] },
        { "supply.purchase.cancel", ["Owner", "Manager"] },
        { "commerce.stock.adjust", ["Owner", "Manager", "Inventory"] },
        { "supply.receipt.create", ["Owner", "Manager", "Inventory"] },
        { "commerce.sale.record", ["Owner", "Manager", "Cashier"] },
        { "commerce.sale.cancel", ["Owner", "Manager", "Cashier"] },
        { "commerce.sale.return", ["Owner", "Manager", "Cashier"] }
    };

    [Theory]
    [MemberData(nameof(ScopeRoles))]
    public void Every_known_scope_has_an_exact_role_allowlist_and_requires_authentication(string scope, string[] allowed)
    {
        foreach (var role in new[] { "Owner", "Manager", "Inventory", "Cashier", "Visitor", "owner", "Admin" })
        {
            Assert.Equal(allowed.Contains(role), InternalCommandAuthorization.Allowed(Principal(role), scope));
            Assert.False(InternalCommandAuthorization.Allowed(Principal(role, authenticated: false), scope));
        }
    }

    [Theory]
    [InlineData("")]
    [InlineData("directory.items")]
    [InlineData("Directory.items.create")]
    [InlineData("directory.items.create ")]
    [InlineData("directory.items.create\n")]
    [InlineData("security.staff.create")]
    [InlineData("commerce.sale.refund")]
    public void Unknown_or_noncanonical_scope_is_not_authorized_even_for_owner(string scope) =>
        Assert.False(InternalCommandAuthorization.Allowed(Principal("Owner"), scope));

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("123456789012345")]
    [InlineData("123456789012345 ")]
    [InlineData("123456789012345é")]
    [InlineData("123456789012345\n")]
    [InlineData("first-key-0000001,second-key-000001")]
    public Task Invalid_key_is_rejected_before_storage_or_action(string? key) =>
        AssertRejected("invalid_request", key: key!);

    [Fact]
    public Task Overlength_key_is_rejected_before_storage_or_action() =>
        AssertRejected("invalid_request", key: new string('k', 129));

    [Theory]
    [InlineData(0)]
    [InlineData(63)]
    [InlineData(65)]
    public Task Fingerprint_must_have_exact_digest_length_before_storage_or_action(int length) =>
        AssertRejected("invalid_request", fingerprint: new string('A', length));

    [Theory]
    [InlineData('G')]
    [InlineData(' ')]
    [InlineData('\n')]
    [InlineData('é')]
    public Task Fingerprint_rejects_nonhex_characters_before_storage_or_action(char last) =>
        AssertRejected("invalid_request", fingerprint: new string('A', 63) + last);

    [Fact]
    public Task Empty_actor_is_invalid_before_identity_or_storage() =>
        AssertRejected("invalid_request", actor: Guid.Empty);

    [Theory]
    [InlineData(0)]
    [InlineData(81)]
    public Task Out_of_bounds_scope_is_invalid_before_storage_or_action(int length) =>
        AssertRejected("invalid_request", scope: new string('s', length));

    [Fact]
    public Task Maximum_length_unknown_scope_is_forbidden_not_treated_as_malformed() =>
        AssertRejected("forbidden", scope: new string('s', 80));

    [Fact]
    public Task Different_authenticated_actor_cannot_run_another_actors_operation() =>
        AssertRejected("unauthenticated", principal: Principal("Owner", Guid.NewGuid()));

    [Fact]
    public Task Unauthenticated_role_claim_does_not_authorize_a_command() =>
        AssertRejected("unauthenticated", principal: Principal("Owner", authenticated: false));

    [Fact]
    public Task Missing_http_context_does_not_synthesize_an_actor() =>
        AssertRejected("unauthenticated", missingHttpContext: true);

    [Theory]
    [InlineData("Cashier", "directory.items.create")]
    [InlineData("Inventory", "commerce.sale.record")]
    [InlineData("Cashier", "supply.receipt.create")]
    [InlineData("Inventory", "supply.purchase.cancel")]
    [InlineData("Owner", "unregistered.operation")]
    public Task Forbidden_scope_is_rejected_before_storage_or_action(string role, string scope) =>
        AssertRejected("forbidden", principal: Principal(role), scope: scope);

    [Theory]
    [InlineData(16, false)]
    [InlineData(128, true)]
    public async Task Missing_provider_is_refused_before_callback_without_substituting_a_fake_database(int keyLength, bool lowercaseDigest)
    {
        // No provider at all: this is not SQLite/InMemory and cannot simulate a SQL transaction.
        await using var db = new InternalDbContext(new DbContextOptionsBuilder<InternalDbContext>().Options);
        var runner = Runner(db, Principal("Owner"));
        var called = false;
        var digest = lowercaseDigest ? Fingerprint.ToLowerInvariant() : Fingerprint;
        // EF refuses providerless configuration while inspecting IsSqlServer. This exception is
        // a closed admission path, not the runner's storage_unavailable result or SQL-runtime proof.
        var error = await Assert.ThrowsAsync<InvalidOperationException>(() =>
            runner.Run(Actor, Scope, new string('K', keyLength), digest, _ =>
            {
                called = true;
                return Task.FromResult(InternalResult<string>.Ok("must not execute"));
            }, default));
        Assert.Contains("No database provider has been configured", error.Message);
        Assert.False(called);
    }

    [Fact]
    public async Task Failure_before_connection_open_returns_storage_unavailable_without_action_or_retry()
    {
        var unavailable = new UnavailableBeforeOpen();
        await using var db = new InternalDbContext(new DbContextOptionsBuilder<InternalDbContext>()
            .UseSqlServer("Server=127.0.0.1,1;Database=SaviaInternalTest_RunnerMetadata;Integrated Security=true;Connect Timeout=1")
            .AddInterceptors(unavailable).Options);
        var called = false;
        var result = await Runner(db, Principal("Owner")).Run(Actor, Scope, Key, Fingerprint, _ =>
        {
            called = true;
            return Task.FromResult(InternalResult<string>.Ok("must not execute"));
        }, default);
        Assert.Equal("storage_unavailable", result.Error);
        Assert.False(result.Success);
        Assert.Null(result.Value);
        Assert.False(called);
        Assert.Equal(1, unavailable.Attempts);
        Assert.Null(db.Database.CurrentTransaction);
        Assert.Empty(db.ChangeTracker.Entries());
    }

    private static async Task AssertRejected(string expected, string key = Key, string? fingerprint = null,
        Guid? actor = null, string scope = Scope, ClaimsPrincipal? principal = null, bool missingHttpContext = false)
    {
        var connections = new RejectConnections();
        await using var db = new InternalDbContext(new DbContextOptionsBuilder<InternalDbContext>()
            .UseSqlServer("Server=127.0.0.1,1;Database=SaviaInternalTest_RunnerMetadata;Integrated Security=true;Connect Timeout=1")
            .AddInterceptors(connections).Options);
        var runner = Runner(db, principal ?? Principal("Owner"), missingHttpContext);
        var called = false;
        var result = await runner.Run(actor ?? Actor, scope, key, fingerprint ?? Fingerprint, _ =>
        {
            called = true;
            return Task.FromResult(InternalResult<string>.Ok("must not execute"));
        }, default);
        Assert.Equal(expected, result.Error);
        Assert.False(result.Success);
        Assert.Null(result.Value);
        Assert.False(called);
        Assert.Equal(0, connections.Attempts);
        Assert.Empty(db.ChangeTracker.Entries());
    }

    private static InternalCommandRunner Runner(InternalDbContext db, ClaimsPrincipal principal, bool missingHttpContext = false) =>
        new(db, new InternalSecurityService(db, new PasswordHasher<InternalStaff>(), TimeProvider.System),
            new HttpContextAccessor { HttpContext = missingHttpContext ? null : new DefaultHttpContext { User = principal } }, TimeProvider.System);

    private static ClaimsPrincipal Principal(string role, Guid? actor = null, bool authenticated = true) =>
        new(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, (actor ?? Actor).ToString("D")), new Claim(ClaimTypes.Role, role)],
            authenticated ? "runner-admission-test-only" : null));

    // Injected local availability failure before network open: no transaction or SQL is simulated.
    private sealed class UnavailableBeforeOpen : DbConnectionInterceptor
    {
        public int Attempts { get; private set; }
        public override InterceptionResult ConnectionOpening(DbConnection connection, ConnectionEventData eventData, InterceptionResult result)
        { Attempts++; throw new StorageUnavailableException(); }
        public override ValueTask<InterceptionResult> ConnectionOpeningAsync(DbConnection connection, ConnectionEventData eventData,
            InterceptionResult result, CancellationToken cancellationToken = default)
        { Attempts++; throw new StorageUnavailableException(); }
    }

    // A regression that reaches storage fails locally before any network connection is opened.
    private sealed class RejectConnections : DbConnectionInterceptor
    {
        public int Attempts { get; private set; }
        public override InterceptionResult ConnectionOpening(DbConnection connection, ConnectionEventData eventData, InterceptionResult result)
        { Attempts++; throw new InvalidOperationException("Admission test must not open SQL."); }
        public override ValueTask<InterceptionResult> ConnectionOpeningAsync(DbConnection connection, ConnectionEventData eventData,
            InterceptionResult result, CancellationToken cancellationToken = default)
        { Attempts++; throw new InvalidOperationException("Admission test must not open SQL."); }
    }
}
