using System.Security.Claims;
using System.Text.Json;
using Martha.Store.Api;
using Martha.Store.Api.Internal;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Martha.Store.Api.Tests;

// Real runner + real persisted sessions; reuses the existing explicit disposable-SQL gate.
// Absence of MARTHA_INTERNAL_TEST_SQL_CONNECTION is an explicit skip, not simulated SQL proof.
// The fixture uses EnsureCreated, so even a pass would not verify release migrations or cookie login.
public sealed class InternalRunnerSqlTests
{
    private const string Scope = "directory.items.create";
    private const string Key = "runner-replay-key-0001";
    private static readonly string Fingerprint = InternalRules.Fingerprint(new { Fixture = "runner-replay" });

    [InternalCommerceSqlFact]
    public async Task Replay_identity_isolated_by_actor_scope_and_case_sensitive_key()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        var firstActor = InternalSecurityRules.Principal(fixture.Staff, fixture.Session);
        var secondActor = await SeedIdentity(fixture, "runner-second-owner", "Owner");
        var calls = 0;
        async Task<string> Execute(ClaimsPrincipal principal, string scope, string key, string expected)
        {
            var result = await Run(fixture, principal, scope, key, (_, _) =>
            {
                calls++;
                return Task.FromResult(InternalResult<string>.Ok(expected));
            });
            Assert.True(result.Success, result.Error);
            return result.Value!;
        }
        Assert.Equal("first", await Execute(firstActor, Scope, Key, "first"));
        Assert.Equal("second actor", await Execute(secondActor, Scope, Key, "second actor"));
        Assert.Equal("other scope", await Execute(firstActor, "directory.items.update", Key, "other scope"));
        Assert.Equal("other case", await Execute(firstActor, Scope, Key.ToUpperInvariant(), "other case"));
        Assert.Equal("first", await Execute(firstActor, Scope, Key, "must not execute"));
        Assert.Equal("second actor", await Execute(secondActor, Scope, Key, "must not execute"));
        Assert.Equal(4, calls);
        await using var verify = fixture.Context();
        Assert.Equal(4, await verify.Set<InternalOperation>().CountAsync());
        Assert.Equal(2, await verify.Set<InternalOperation>().Select(operation => operation.ActorId).Distinct().CountAsync());
    }

    [InternalCommerceSqlFact]
    public async Task Persisted_revocation_rejects_both_existing_replay_and_new_action()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        var principal = InternalSecurityRules.Principal(fixture.Staff, fixture.Session);
        var first = await Run(fixture, principal, Scope, Key, (_, _) => Task.FromResult(InternalResult<string>.Ok("original")));
        Assert.True(first.Success, first.Error);
        await using (var db = fixture.Context()) await Security(db).Logout(principal, default);
        var called = false;
        foreach (var key in new[] { Key, "runner-after-revoke-0001" })
        {
            var result = await Run(fixture, principal, Scope, key, (_, _) =>
            {
                called = true;
                return Task.FromResult(InternalResult<string>.Ok("must not execute"));
            });
            Assert.Equal("unauthenticated", result.Error);
            Assert.Null(result.Value); // The persisted original result must not leak through replay.
        }
        Assert.False(called);
        await using var verify = fixture.Context();
        Assert.Equal(1, await verify.Set<InternalOperation>().CountAsync());
    }

    [InternalCommerceSqlFact]
    public async Task Persisted_role_change_revokes_old_permission_before_replay_and_current_role_cannot_replay_it()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        var oldPrincipal = InternalSecurityRules.Principal(fixture.Staff, fixture.Session);
        var otherOwner = await SeedIdentity(fixture, "runner-role-owner", "Owner");
        Assert.True((await Run(fixture, oldPrincipal, Scope, Key,
            (_, _) => Task.FromResult(InternalResult<string>.Ok("owner-only result")))).Success);
        await using (var db = fixture.Context())
        {
            var change = await Security(db).UpdateStaff(otherOwner, fixture.Actor,
                new("Synthetic runner staff", "Cashier", true, fixture.Staff.SecurityVersion), default);
            Assert.True(change.Success, change.Error);
        }
        var called = false;
        Task<InternalResult<string>> Never(InternalDbContext _, CancellationToken __)
        { called = true; return Task.FromResult(InternalResult<string>.Ok("must not execute")); }
        var stale = await Run(fixture, oldPrincipal, Scope, Key, Never);
        Assert.Equal("unauthenticated", stale.Error);
        Assert.Null(stale.Value);
        ClaimsPrincipal current;
        await using (var db = fixture.Context())
        {
            var staff = await db.InternalStaff.SingleAsync(row => row.Id == fixture.Actor);
            var now = DateTimeOffset.UtcNow;
            // Direct synthetic session fixture only; this does not claim a successful cookie/password login.
            var session = new InternalSession { Id = Guid.NewGuid(), StaffId = staff.Id, SecurityVersion = staff.SecurityVersion,
                CreatedAt = now, ExpiresAt = now.Add(InternalSecurityRules.SessionLifetime) };
            db.InternalSessions.Add(session);
            await db.SaveChangesAsync();
            current = InternalSecurityRules.Principal(staff, session);
        }
        var forbidden = await Run(fixture, current, Scope, Key, Never);
        Assert.Equal("forbidden", forbidden.Error);
        Assert.Null(forbidden.Value);
        Assert.False(called);
        await using var verify = fixture.Context();
        Assert.Equal(1, await verify.Set<InternalOperation>().CountAsync());
    }

    [InternalCommerceSqlFact]
    public async Task Typed_replay_preserves_nested_arrays_integer_money_nulls_and_timestamp()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        var principal = InternalSecurityRules.Principal(fixture.Staff, fixture.Session);
        var expected = new ReplayReceipt(Guid.NewGuid(), new DateTimeOffset(2026, 10, 25, 2, 3, 4, TimeSpan.FromHours(-6)),
            [new("SYNTHETIC-Á", 2, InternalRules.MaxMinor), new("SECOND", 1, 0)], null);
        var calls = 0;
        Task<InternalResult<ReplayReceipt>> Action(InternalDbContext _, CancellationToken __)
        { calls++; return Task.FromResult(InternalResult<ReplayReceipt>.Ok(expected)); }
        var first = await Run(fixture, principal, Scope, Key, Action);
        var replay = await Run(fixture, principal, Scope, Key, Action);
        Assert.True(first.Success, first.Error);
        Assert.True(replay.Success, replay.Error);
        Assert.Equal(1, calls);
        Assert.Equal(expected.Id, replay.Value!.Id);
        Assert.Equal(expected.At, replay.Value.At);
        Assert.Equal(expected.At.Offset, replay.Value.At.Offset);
        Assert.Equal(expected.Lines, replay.Value.Lines);
        Assert.Null(replay.Value.Note);
        Assert.Equal(JsonSerializer.Serialize(first), JsonSerializer.Serialize(replay));
        await using var verify = fixture.Context();
        using var json = JsonDocument.Parse((await verify.Set<InternalOperation>().SingleAsync()).ResultJson);
        Assert.Equal(expected.Id, json.RootElement.GetProperty("value").GetProperty("id").GetGuid());
        Assert.Equal(JsonValueKind.Null, json.RootElement.GetProperty("error").ValueKind);
    }

    [InternalCommerceSqlFact]
    public async Task Concurrent_same_identity_serializes_action_once_and_returns_the_same_replay()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        var principal = InternalSecurityRules.Principal(fixture.Staff, fixture.Session);
        var calls = 0;
        var expected = Guid.NewGuid();
        async Task<InternalResult<Guid>> Action(InternalDbContext _, CancellationToken ct)
        {
            Interlocked.Increment(ref calls);
            await Task.Delay(25, ct);
            return InternalResult<Guid>.Ok(expected);
        }
        var outcomes = await Task.WhenAll(Run(fixture, principal, Scope, Key, Action), Run(fixture, principal, Scope, Key, Action));
        Assert.All(outcomes, outcome => { Assert.True(outcome.Success, outcome.Error); Assert.Equal(expected, outcome.Value); });
        Assert.Equal(1, calls);
        await using var verify = fixture.Context();
        Assert.Equal(1, await verify.Set<InternalOperation>().CountAsync());
    }

    [InternalCommerceSqlFact]
    public async Task Storage_exception_after_action_started_is_unknown_not_retried_and_no_partial_write_survives()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        var principal = InternalSecurityRules.Principal(fixture.Staff, fixture.Session);
        var location = Guid.NewGuid();
        var calls = 0;
        var outcome = await Run<string>(fixture, principal, Scope, Key, async (db, ct) =>
        {
            calls++;
            db.Set<InternalLocation>().Add(new() { Id = location, Name = "Synthetic interrupted runner action", Active = true });
            await db.SaveChangesAsync(ct);
            throw new StorageUnavailableException();
        });
        Assert.Equal("unknown_outcome", outcome.Error);
        Assert.Equal(1, calls); // The runner never silently retries an interrupted business callback.
        await using var verify = fixture.Context();
        Assert.False(await verify.Set<InternalLocation>().AnyAsync(row => row.Id == location));
        Assert.False(await verify.Set<InternalOperation>().AnyAsync());
    }

    private static async Task<InternalResult<T>> Run<T>(InternalCommerceSqlDatabase fixture, ClaimsPrincipal principal,
        string scope, string key, Func<InternalDbContext, CancellationToken, Task<InternalResult<T>>> action)
    {
        await using var db = fixture.Context();
        var runner = new InternalCommandRunner(db, Security(db),
            new HttpContextAccessor { HttpContext = new DefaultHttpContext { User = principal } }, TimeProvider.System);
        return await runner.Run(InternalActor.Id(principal), scope, key, Fingerprint, ct => action(db, ct), default);
    }

    private static InternalSecurityService Security(InternalDbContext db) =>
        new(db, new PasswordHasher<InternalStaff>(), TimeProvider.System);

    private static async Task<ClaimsPrincipal> SeedIdentity(InternalCommerceSqlDatabase fixture, string login, string role)
    {
        await using var db = fixture.Context();
        var now = DateTimeOffset.UtcNow;
        var staff = new InternalStaff { Id = Guid.NewGuid(), LoginName = login, NormalizedLoginName = login.ToUpperInvariant(),
            DisplayName = "Synthetic runner test staff", PasswordHash = "session-tests-only-not-a-password-hash", Role = role,
            Enabled = true, SecurityVersion = Guid.NewGuid(), CreatedAt = now, UpdatedAt = now };
        var session = new InternalSession { Id = Guid.NewGuid(), StaffId = staff.Id, SecurityVersion = staff.SecurityVersion,
            CreatedAt = now, ExpiresAt = now.Add(InternalSecurityRules.SessionLifetime) };
        db.Add(staff); db.Add(session);
        await db.SaveChangesAsync();
        return InternalSecurityRules.Principal(staff, session);
    }

    public sealed record ReplayReceipt(Guid Id, DateTimeOffset At, ReplayLine[] Lines, string? Note);
    public sealed record ReplayLine(string Sku, int Quantity, long UnitPriceMinor);
}
