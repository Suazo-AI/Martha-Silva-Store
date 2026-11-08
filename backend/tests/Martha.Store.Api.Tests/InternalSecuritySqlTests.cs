using System.Data.Common;
using System.Security.Claims;
using Martha.Store.Api.Internal;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Xunit;

namespace Martha.Store.Api.Tests;

// These tests are deliberately opt-in and are NOT replaced with SQLite/InMemory.
// They create/drop only a generated database on an explicitly authorized disposable SQL Server.
public sealed class InternalSecuritySqlFactAttribute : FactAttribute
{
    public InternalSecuritySqlFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("MARTHA_INTERNAL_TEST_SQL_CONNECTION")))
            Skip = "Real authorized disposable SQL Server not configured: MARTHA_INTERNAL_TEST_SQL_CONNECTION is required; no bootstrap is executed.";
    }
}

public sealed class InternalSecuritySqlTests
{
    private static readonly DateTimeOffset Now = new(2026, 10, 25, 0, 0, 0, TimeSpan.Zero);
    // Only a synthetic test input; not an account provisioned by the application or an operator credential.
    private const string FixturePassword = "synthetic-test-input-only";
    private static readonly TimeProvider Clock = new FixedTime();
    private static PasswordHasher<InternalStaff> Hasher() => new(Options.Create(new PasswordHasherOptions { IterationCount = 210_000 }));
    private static InternalSecurityService Service(InternalDbContext db) => new(db, Hasher(), Clock);

    [InternalSecuritySqlFact]
    public async Task Successful_login_is_persisted_replaces_previous_session_and_logout_revokes_it()
    {
        await using var fixture = new SecuritySqlDatabase();
        await fixture.Initialize();
        var (_, oldPrincipal) = await SeedStaff(fixture, "fixture-owner", "Owner");
        InternalLoginResult login;
        await using (var db = fixture.Context())
        {
            var result = await Service(db).Login(new("FIXTURE-OWNER", FixturePassword), default);
            Assert.True(result.Success);
            login = result.Value!;
        }
        var current = InternalSecurityRules.Principal(login.Staff, login.Session);
        await using (var db = fixture.Context())
        {
            Assert.Null(await Service(db).ValidateSession(oldPrincipal, default));
            Assert.NotNull(await Service(db).ValidateSession(current, default));
            Assert.Equal(2, await db.InternalSessions.CountAsync());
            await Service(db).Logout(current, default);
        }
        await using (var db = fixture.Context()) Assert.Null(await Service(db).ValidateSession(current, default));
    }

    [InternalSecuritySqlFact]
    public async Task Failed_login_lockout_is_persisted_across_scopes_and_correct_password_cannot_bypass_it()
    {
        await using var fixture = new SecuritySqlDatabase();
        await fixture.Initialize();
        var (staffId, _) = await SeedStaff(fixture, "fixture-cashier", "Cashier");
        for (var attempt = 0; attempt < 5; attempt++)
        {
            await using var db = fixture.Context();
            Assert.Equal("invalid_credentials", (await Service(db).Login(new("fixture-cashier", "incorrect-test-input"), default)).Error);
        }
        await using (var db = fixture.Context())
        {
            Assert.Equal("invalid_credentials", (await Service(db).Login(new("fixture-cashier", FixturePassword), default)).Error);
            var persisted = await db.InternalStaff.AsNoTracking().SingleAsync(x => x.Id == staffId);
            Assert.Equal(5, persisted.FailedSignIns);
            Assert.Equal(Now.AddMinutes(15), persisted.LockedUntil);
        }
    }

    [InternalSecuritySqlFact]
    public async Task Owner_role_change_and_disablement_revoke_old_cookies_and_stale_versions_conflict()
    {
        await using var fixture = new SecuritySqlDatabase();
        await fixture.Initialize();
        var (_, ownerPrincipal) = await SeedStaff(fixture, "fixture-owner", "Owner");
        var (staffId, oldPrincipal) = await SeedStaff(fixture, "fixture-staff", "Manager");
        var version = Guid.Parse(oldPrincipal.FindFirstValue(InternalSecurityRules.VersionClaim)!);
        Guid newVersion;
        await using (var db = fixture.Context())
        {
            var result = await Service(db).UpdateStaff(ownerPrincipal, staffId, new("Fixture staff", "Cashier", true, version), default);
            Assert.True(result.Success);
            newVersion = result.Value!.Version;
            Assert.NotEqual(version, newVersion);
        }
        await using (var db = fixture.Context())
        {
            Assert.Null(await Service(db).ValidateSession(oldPrincipal, default));
            Assert.Equal("version_conflict", (await Service(db).UpdateStaff(ownerPrincipal, staffId,
                new("Fixture staff", "Owner", true, version), default)).Error);
        }
        ClaimsPrincipal fresh;
        await using (var db = fixture.Context())
        {
            var login = (await Service(db).Login(new("fixture-staff", FixturePassword), default)).Value!;
            fresh = InternalSecurityRules.Principal(login.Staff, login.Session);
            Assert.True(fresh.IsInRole("Cashier"));
        }
        await using (var db = fixture.Context())
            Assert.True((await Service(db).UpdateStaff(ownerPrincipal, staffId, new("Fixture staff", "Cashier", false, newVersion), default)).Success);
        await using (var db = fixture.Context())
        {
            Assert.Null(await Service(db).ValidateSession(fresh, default));
            Assert.Equal("invalid_credentials", (await Service(db).Login(new("fixture-staff", FixturePassword), default)).Error);
        }
    }

    [InternalSecuritySqlFact]
    public async Task Last_owner_cannot_be_disabled_or_demoted_and_non_owner_cannot_create_staff()
    {
        await using var fixture = new SecuritySqlDatabase();
        await fixture.Initialize();
        var (ownerId, owner) = await SeedStaff(fixture, "fixture-owner", "Owner");
        var (_, cashier) = await SeedStaff(fixture, "fixture-cashier", "Cashier");
        var version = Guid.Parse(owner.FindFirstValue(InternalSecurityRules.VersionClaim)!);
        await using (var db = fixture.Context())
            Assert.Equal("last_owner_required", (await Service(db).UpdateStaff(owner, ownerId, new("Fixture owner", "Owner", false, version), default)).Error);
        await using (var db = fixture.Context())
            Assert.Equal("last_owner_required", (await Service(db).UpdateStaff(owner, ownerId, new("Fixture owner", "Manager", true, version), default)).Error);
        await using (var db = fixture.Context())
            Assert.Equal("forbidden", (await Service(db).CreateStaff(cashier, new("fixture-new", "Fixture new", "Owner", FixturePassword), default)).Error);
    }

    [InternalSecuritySqlFact]
    public async Task Concurrent_owner_demotions_cannot_remove_every_enabled_owner()
    {
        await using var fixture = new SecuritySqlDatabase();
        await fixture.Initialize();
        var first = await SeedStaff(fixture, "fixture-owner-one", "Owner");
        var second = await SeedStaff(fixture, "fixture-owner-two", "Owner");
        async Task<bool> Demote((Guid Id, ClaimsPrincipal Principal) owner)
        {
            await using var db = fixture.Context();
            try
            {
                return (await Service(db).UpdateStaff(owner.Principal, owner.Id, new("Fixture owner", "Manager", true,
                    Guid.Parse(owner.Principal.FindFirstValue(InternalSecurityRules.VersionClaim)!)), default)).Success;
            }
            catch (Exception error) when (error is DbException or DbUpdateException
                or InvalidOperationException { InnerException: SqlException { Number: 1205 } })
            {
                // SQL may abort a serializable deadlock victim. It must not weaken isolation or silently retry.
                return false;
            }
        }
        var outcomes = await Task.WhenAll(Demote(first), Demote(second));
        Assert.True(outcomes.Count(x => x) <= 1);
        await using var check = fixture.Context();
        Assert.True(await check.InternalStaff.CountAsync(x => x.Enabled && x.Role == "Owner") >= 1);
    }

    [InternalSecuritySqlFact]
    public async Task Password_reset_rotates_version_and_revokes_sessions_without_exposing_hash()
    {
        await using var fixture = new SecuritySqlDatabase();
        await fixture.Initialize();
        var (_, owner) = await SeedStaff(fixture, "fixture-owner", "Owner");
        var (staffId, prior) = await SeedStaff(fixture, "fixture-staff", "Inventory");
        await using (var db = fixture.Context())
        {
            var result = await Service(db).ResetPassword(owner, staffId, new("replacement-synthetic-test-input",
                Guid.Parse(prior.FindFirstValue(InternalSecurityRules.VersionClaim)!)), default);
            Assert.True(result.Success);
        }
        await using (var db = fixture.Context())
        {
            Assert.Null(await Service(db).ValidateSession(prior, default));
            Assert.Equal("invalid_credentials", (await Service(db).Login(new("fixture-staff", FixturePassword), default)).Error);
        }
        await using (var db = fixture.Context())
            Assert.True((await Service(db).Login(new("fixture-staff", "replacement-synthetic-test-input"), default)).Success);
    }

    [InternalSecuritySqlFact]
    public async Task Owner_can_disable_staff_with_an_inactive_retained_branch_without_reassigning_it()
    {
        await using var fixture = new SecuritySqlDatabase();
        await fixture.Initialize();
        var (_, owner) = await SeedStaff(fixture, "fixture-owner", "Owner");
        var (staffId, prior) = await SeedStaff(fixture, "fixture-manager", "Manager");
        var branchId = Guid.NewGuid();
        var version = Guid.Parse(prior.FindFirstValue(InternalSecurityRules.VersionClaim)!);
        await using (var db = fixture.Context())
        {
            db.Set<InternalBranch>().Add(new() { Id = branchId, Name = "Synthetic inactive branch", Active = false });
            (await db.InternalStaff.SingleAsync(x => x.Id == staffId)).BranchId = branchId;
            await db.SaveChangesAsync();
        }
        await using (var db = fixture.Context())
        {
            // Explicit assignment to an inactive branch remains rejected, even if
            // the same Owner wants to disable the employee in that request.
            Assert.Equal("invalid_branch", (await Service(db).UpdateStaff(owner, staffId,
                new("Synthetic manager", "Manager", false, version, branchId), default)).Error);
        }
        await using (var db = fixture.Context())
        {
            var result = await Service(db).UpdateStaff(owner, staffId,
                new("Synthetic manager", "Manager", false, version), default);
            Assert.True(result.Success);
            Assert.Equal(branchId, result.Value!.BranchId);
            Assert.False(result.Value.Enabled);
            Assert.NotEqual(version, result.Value.Version);
        }
        await using (var db = fixture.Context())
        {
            Assert.Null(await Service(db).ValidateSession(prior, default));
            Assert.NotNull((await db.InternalSessions.SingleAsync(x => x.StaffId == staffId)).RevokedAt);
            Assert.Equal(branchId, (await db.InternalStaff.SingleAsync(x => x.Id == staffId)).BranchId);
            Assert.Empty(await db.Set<InternalBranchAssignmentAudit>().ToListAsync());
        }
    }

    [InternalSecuritySqlFact]
    public async Task Recovery_F7_authenticated_owner_self_reset_revokes_actor_session()
    {
        await using var fixture=new SecuritySqlDatabase(recovery:true);await fixture.Initialize();
        var (id,owner)=await SeedStaff(fixture,"self-owner","Owner");
        var version=Guid.Parse(owner.FindFirstValue(InternalSecurityRules.VersionClaim)!);
        string connection;HashSet<Guid> revocable;
        await using(var db=fixture.Context()){connection=db.Database.GetConnectionString()!;revocable=(await db.InternalSessions.Where(x=>x.StaffId==id&&x.RevokedAt==null).Select(x=>x.Id).ToArrayAsync()).ToHashSet();}
        var preserved=await OwnerRecoveryOracle.Capture(connection,id,revocable);
        await using(var db=fixture.Context())
        { Assert.True((await Service(db).ResetPassword(owner,id,new("replacement-self-fixture-only",version),default)).Success); }
        Assert.Equal(preserved,await OwnerRecoveryOracle.Capture(connection,id,revocable));
        await using(var db=fixture.Context())
        {
            Assert.Null(await Service(db).ValidateSession(owner,default));
            var staff=await db.InternalStaff.SingleAsync(x=>x.Id==id);
            Assert.Equal("Owner",staff.Role);Assert.True(staff.Enabled);Assert.NotEqual(version,staff.SecurityVersion);
            Assert.All(await db.InternalSessions.ToArrayAsync(),s=>Assert.NotNull(s.RevokedAt));
        }
        await using(var db=fixture.Context())
            Assert.True((await Service(db).Login(new("self-owner","replacement-self-fixture-only"),default)).Success);
    }
    [InternalSecuritySqlFact]
    public async Task Recovery_F7_second_owner_reset_preserves_disabled_state_and_stale_update_refuses()
    {
        await using var fixture=new SecuritySqlDatabase(recovery:true);await fixture.Initialize();
        var (_,actor)=await SeedStaff(fixture,"actor-owner","Owner");
        var (id,target)=await SeedStaff(fixture,"disabled-owner","Owner");
        var version=Guid.Parse(target.FindFirstValue(InternalSecurityRules.VersionClaim)!);
        await using(var db=fixture.Context())
        { (await db.InternalStaff.SingleAsync(x=>x.Id==id)).Enabled=false;await db.SaveChangesAsync(); }
        string connection;HashSet<Guid> revocable;
        await using(var db=fixture.Context()){connection=db.Database.GetConnectionString()!;revocable=(await db.InternalSessions.Where(x=>x.StaffId==id&&x.RevokedAt==null).Select(x=>x.Id).ToArrayAsync()).ToHashSet();}
        var preserved=await OwnerRecoveryOracle.Capture(connection,id,revocable);
        await using(var db=fixture.Context())
            Assert.True((await Service(db).ResetPassword(actor,id,new("replacement-disabled-only",version),default)).Success);
        Assert.Equal(preserved,await OwnerRecoveryOracle.Capture(connection,id,revocable));
        var fullBefore=await OwnerRecoveryOracle.Capture(connection);
        await using(var db=fixture.Context())
        {
            var before=await db.InternalStaff.AsNoTracking().SingleAsync(x=>x.Id==id);
            Assert.False(before.Enabled);
            Assert.Equal("version_conflict",(await Service(db).UpdateStaff(actor,id,new("Changed","Owner",true,version),default)).Error);
            db.ChangeTracker.Clear();var after=await db.InternalStaff.AsNoTracking().SingleAsync(x=>x.Id==id);
            Assert.Equal(before.SecurityVersion,after.SecurityVersion);Assert.Equal(before.RowVersion,after.RowVersion);
            Assert.Equal(before.PasswordHash,after.PasswordHash);Assert.False(after.Enabled);
        }
        Assert.Equal(fullBefore,await OwnerRecoveryOracle.Capture(connection));
    }

    private static async Task<(Guid Id, ClaimsPrincipal Principal)> SeedStaff(SecuritySqlDatabase fixture, string loginName, string role)
    {
        // Direct synthetic fixtures only: intentionally never invoke InternalOwnerBootstrap.
        await using var db = fixture.Context();
        var staff = new InternalStaff { Id = Guid.NewGuid(), LoginName = loginName, NormalizedLoginName = loginName.ToUpperInvariant(),
            DisplayName = "Synthetic security fixture", Role = role, Enabled = true, SecurityVersion = Guid.NewGuid(), CreatedAt = Now, UpdatedAt = Now };
        staff.PasswordHash = Hasher().HashPassword(staff, FixturePassword);
        var session = new InternalSession { Id = Guid.NewGuid(), StaffId = staff.Id, SecurityVersion = staff.SecurityVersion,
            CreatedAt = Now, ExpiresAt = Now.AddHours(8) };
        db.Add(staff); db.Add(session);
        await db.SaveChangesAsync();
        return (staff.Id, InternalSecurityRules.Principal(staff, session));
    }

    private sealed class FixedTime : TimeProvider { public override DateTimeOffset GetUtcNow() => Now; }

    private sealed class SecuritySqlDatabase : IAsyncDisposable
    {
        private readonly string name = "MarthaInternal_Test_" + Guid.NewGuid().ToString("N");
        private readonly string adminConnection;
        private readonly string connection;
        private bool created;
        private readonly bool recovery;
        private OwnerRecoveryDatabaseLease? recoveryLease;
        public SecuritySqlDatabase(bool recovery=false)
        {
            this.recovery=recovery;
            if(recovery)name="SaviaInternalTest_Recovery_"+Guid.NewGuid().ToString("N");
            var supplied = Environment.GetEnvironmentVariable("MARTHA_INTERNAL_TEST_SQL_CONNECTION")
                ?? throw new InvalidOperationException("Explicit authorized disposable SQL Server required.");
            var builder = new SqlConnectionStringBuilder(supplied) { InitialCatalog = "master", Pooling = false };
            if(recovery)builder.ConnectRetryCount=0;
            adminConnection = builder.ConnectionString;
            builder.InitialCatalog = name;
            connection = builder.ConnectionString;
        }
        public InternalDbContext Context() => new(new DbContextOptionsBuilder<InternalDbContext>().UseSqlServer(connection).Options);
        public async Task Initialize()
        {
            await using var master = new SqlConnection(adminConnection);
            await master.OpenAsync();
            await using var command = master.CreateCommand();
            if(recovery)recoveryLease=await OwnerRecoveryDatabaseLease.Create(adminConnection,name);
            else
            {
                command.CommandText = $"CREATE DATABASE [{name}]"; // Exclusively generated above, never user-supplied SQL identifiers.
                await command.ExecuteNonQueryAsync();
            }
            created = true;
            await using var db = Context();
            await db.Database.EnsureCreatedAsync(); // Relational model test, not evidence for the release migration procedure.
        }
        public async ValueTask DisposeAsync()
        {
            if(recoveryLease is not null){await recoveryLease.DisposeAsync();created=false;return;}
            if (!created) return;
            await using var master = new SqlConnection(adminConnection);
            await master.OpenAsync();
            await using var command = master.CreateCommand();
            command.CommandText = $"ALTER DATABASE [{name}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{name}]";
            await command.ExecuteNonQueryAsync();
        }
    }
}
