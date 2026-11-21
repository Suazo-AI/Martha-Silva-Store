using System.Data;
using System.Globalization;
using System.Text;
using Martha.Store.Api.Internal;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Xunit;

namespace Martha.Store.Api.Tests;

// Prepared only. Requires separate approval, Windows Integrated Security, retained TLS and exact server identity.
public sealed class OwnerRecoverySqlFactAttribute : FactAttribute
{
    public OwnerRecoverySqlFactAttribute()
    { if (Environment.GetEnvironmentVariable("SAVIA_OWNER_RECOVERY_SQL_APPROVED") != "yes") Skip="NOT RUN: separately authorized recovery SQL scope required."; }
}
public sealed class OwnerRecoverySqlTheoryAttribute : TheoryAttribute
{
    public OwnerRecoverySqlTheoryAttribute()
    { if (Environment.GetEnvironmentVariable("SAVIA_OWNER_RECOVERY_SQL_APPROVED") != "yes") Skip="NOT RUN: separately authorized recovery SQL scope required."; }
}
public sealed class InternalOwnerRecoverySqlTests
{
    private const string Old = "synthetic-old-input-only";
    private const string Replacement = "synthetic-replacement-only";
    [OwnerRecoverySqlTheory]
    [InlineData("after-revocation")] [InlineData("before-commit")] [InlineData("after-commit")] [InlineData("none")] [InlineData("pre-write-journal")] [InlineData("rollback-failure")] [InlineData("before-transaction-dispose")] [InlineData("receipt-failure")]
    public async Task F5_F9_F12_F13_exact_changes_and_rollback(string point)
    {
        await using var f = await OwnerRecoveryFixture.Create();
        {
            var before = await f.Snapshot();
            var preserved = await f.Snapshot(true);
            var manifest=await f.Manifest();
            InternalStaff oldStaff;await using(var db=f.Context())oldStaff=await db.InternalStaff.AsNoTracking().SingleAsync(x=>x.Id==f.Target);
            var startedAt=DateTimeOffset.UtcNow;
            await using var service=new InternalOwnerRecoveryService(manifest, stage=> { if(stage==point || (point=="rollback-failure" && stage is "before-commit" or "before-rollback")) throw new IOException(); });
            await service.Inspect(default);
            var journal=new Journal(point);
            var outcome=await service.Recover(Replacement,journal,()=>true);
            Assert.Equal(1,journal.IntentAttempts);
            var after=await f.Snapshot(); // Immediate before login probes.
            Assert.Equal(preserved,await f.Snapshot(true));
            await f.AssertMigrations();
            if(point is "after-revocation" or "before-commit" or "pre-write-journal" or "rollback-failure")
            {
                Assert.Equal(point=="rollback-failure" ? OwnerRecoveryOutcome.Unknown : OwnerRecoveryOutcome.Refused,outcome);Assert.Equal(before,after);
                await using var fresh=f.Context();Assert.Equal(manifest.SecurityVersion,(await fresh.InternalStaff.AsNoTracking().SingleAsync(x=>x.Id==f.Target)).SecurityVersion);
            }
            else
            {
                Assert.Equal(point is "after-commit" or "before-transaction-dispose" or "receipt-failure"?OwnerRecoveryOutcome.Unknown:OwnerRecoveryOutcome.Committed,outcome);
                Assert.Equal(before.Where(x=>x.Key is not ("Staff" or "Sessions")),after.Where(x=>x.Key is not ("Staff" or "Sessions")));
                await using var db=f.Context();
                var staff=await db.InternalStaff.SingleAsync(x=>x.Id==f.Target);
                Assert.NotEqual(manifest.SecurityVersion,staff.SecurityVersion);Assert.NotEqual(Guid.Empty,staff.SecurityVersion);
                Assert.Equal(journal.IntentVersion,staff.SecurityVersion);
                Assert.NotEqual(oldStaff.PasswordHash,staff.PasswordHash);Assert.NotEqual(oldStaff.RowVersion,staff.RowVersion);
                Assert.InRange(staff.UpdatedAt,startedAt,DateTimeOffset.UtcNow);
                Assert.Equal(0,staff.FailedSignIns); Assert.Null(staff.LockedUntil);
                Assert.NotEqual(before["Staff"],after["Staff"]);Assert.NotEqual(before["Sessions"],after["Sessions"]);
                Assert.DoesNotContain("COMMITTED",journal.Results.Where(_=>outcome==OwnerRecoveryOutcome.Unknown));
                Assert.All(await db.InternalSessions.Where(x=>x.StaffId==f.Target).ToArrayAsync(),s=>Assert.NotNull(s.RevokedAt));
                // Fixture is disposable; each successful case ends this scope. Same replacement must not repeat.
                Assert.Equal(PasswordVerificationResult.Failed,new PasswordHasher<InternalStaff>().VerifyHashedPassword(staff,staff.PasswordHash,Old));
                Assert.NotEqual(PasswordVerificationResult.Failed,new PasswordHasher<InternalStaff>().VerifyHashedPassword(staff,staff.PasswordHash,Replacement));
            }
        }
    }
    [OwnerRecoverySqlFact]
    public async Task F4_rejected_target_and_same_password_full_no_write()
    {
        await using var f=await OwnerRecoveryFixture.Create();
        var m=await f.Manifest();
        foreach(var wrong in new[] {m with {TargetId=Guid.NewGuid()},m with {Login="OTHER"},m with {SecurityVersion=Guid.NewGuid()},m with {DatabaseGuid=Guid.NewGuid()},m with {Server="wrong-instance"},m with {Catalog="SaviaInternalTest_wrong"},m with {DatabaseId=m.DatabaseId+1},m with {SqlSid="FF"},m with {SecurityVersion=Guid.Empty}})
        {
            var before=await f.Snapshot();
            await Assert.ThrowsAnyAsync<Exception>(async()=> { await using var service=new InternalOwnerRecoveryService(wrong);await service.Inspect(default); });
            Assert.Equal(before,await f.Snapshot());
        }
        await using(var service=new InternalOwnerRecoveryService(m))
        { await service.Inspect(default); var before=await f.Snapshot(); Assert.Equal(OwnerRecoveryOutcome.Refused,await service.Recover(Old,new Journal(),()=>true)); Assert.Equal(before,await f.Snapshot()); }
    }
    [OwnerRecoverySqlTheory]
    [InlineData("recovery")] [InlineData("reset")] [InlineData("login")] [InlineData("demote")]
    public async Task F8_barrier_controlled_races_have_one_serial_winner(string competing)
    {
        await using var f=await OwnerRecoveryFixture.Create();var m=await f.Manifest();
        var hasher=new PasswordHasher<InternalStaff>(Options.Create(new PasswordHasherOptions{IterationCount=210_000}));
        System.Security.Claims.ClaimsPrincipal actor;
        await using(var db=f.Context())
        { var login=await new InternalSecurityService(db,hasher,TimeProvider.System).Login(new("other",Old),default);Assert.True(login.Success);actor=InternalSecurityRules.Principal(login.Value!.Staff,login.Value.Session); }
        using var locked=new ManualResetEventSlim();using var release=new ManualResetEventSlim();
        var admit=new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        await using var observer=new SqlConnection(f.Connection);await observer.OpenAsync();
        var sessions=await DatabaseSessions(observer);
        // Hold the uncommitted write lock. An update lock alone admits shared readers.
        await using var first=new InternalOwnerRecoveryService(m,stage=> {if(stage=="before-commit"){locked.Set();if(!release.Wait(TimeSpan.FromSeconds(20)))throw new TimeoutException();}});
        await first.Inspect(default);
        var firstSession=Assert.Single((await DatabaseSessions(observer)).Except(sessions));
        await using var second=competing=="recovery"?new InternalOwnerRecoveryService(m):null;
        await using var contenderDb=f.Context();
        int contenderSession;
        if(second is not null)
        {
            sessions=await DatabaseSessions(observer);await second.Inspect(default);
            contenderSession=Assert.Single((await DatabaseSessions(observer)).Except(sessions));
        }
        else
        {
            await contenderDb.Database.OpenConnectionAsync();
            await using var id=contenderDb.Database.GetDbConnection().CreateCommand();id.CommandText="SELECT @@SPID";
            contenderSession=Convert.ToInt32(await id.ExecuteScalarAsync(),CultureInfo.InvariantCulture);
        }
        var targetSessions=await contenderDb.InternalSessions.AsNoTracking().Where(x=>x.StaffId==f.Target).ToArrayAsync();
        var targetBefore=await contenderDb.InternalStaff.AsNoTracking().SingleAsync(x=>x.Id==f.Target);
        var oldPrincipals=targetSessions.Where(x=>x.RevokedAt is null).Select(x=>InternalSecurityRules.Principal(targetBefore,x)).ToArray();
        var preserved=await f.Snapshot(true);
        var journal=new Journal();var startedAt=DateTimeOffset.UtcNow;
        var winner=Task.Run(()=>first.Recover(Replacement,journal,()=>true));
        Task? loser=null;
        try
        {
        Assert.True(locked.Wait(TimeSpan.FromSeconds(10)));
        loser=Task.Run(async ()=>
        {
            await admit.Task;
            if(second is not null) {Assert.Equal(OwnerRecoveryOutcome.Refused,await second.Recover("different-synthetic-input",new Journal(),()=>true));return;}
            var service=new InternalSecurityService(contenderDb,hasher,TimeProvider.System);
            if(competing=="reset")Assert.False((await service.ResetPassword(actor,f.Target,new("different-synthetic-input",m.SecurityVersion),default)).Success);
            if(competing=="login")Assert.False((await service.Login(new("owner",Old),default)).Success);
            if(competing=="demote")Assert.False((await service.UpdateStaff(actor,f.Target,new("Synthetic","Manager",true,m.SecurityVersion),default)).Success);
        });
        // Negative control: a scheduled contender deliberately held before SQL cannot qualify.
        Assert.False(await ObserveTargetLockWait(observer,contenderSession,firstSession,TimeSpan.FromMilliseconds(150)));
        Assert.False(loser.IsCompleted);
        admit.SetResult();
        Assert.True(await ObserveTargetLockWait(observer,contenderSession,firstSession,TimeSpan.FromSeconds(8)),
            "The actual contender never waited on the held Staff lock; task scheduling is not SQL contention.");
        Assert.False(winner.IsCompleted);Assert.False(loser.IsCompleted);
        }
        finally
        {
            admit.TrySetResult();
            release.Set();
            // Await every started task before service/database cleanup, including failed assertions.
            await Task.WhenAll(loser is null ? new Task[]{winner} : new Task[]{winner,loser});
        }
        Assert.Equal(OwnerRecoveryOutcome.Committed,await winner);
        Assert.Equal(preserved,await f.Snapshot(true));
        await using var final=f.Context();var staff=await final.InternalStaff.SingleAsync(x=>x.Id==f.Target);
        Assert.Equal("Owner",staff.Role);Assert.True(staff.Enabled);Assert.NotEqual(m.SecurityVersion,staff.SecurityVersion);
        Assert.Equal(journal.IntentVersion,staff.SecurityVersion);
        Assert.NotEqual(PasswordVerificationResult.Failed,hasher.VerifyHashedPassword(staff,staff.PasswordHash,Replacement));
        Assert.Equal(PasswordVerificationResult.Failed,hasher.VerifyHashedPassword(staff,staff.PasswordHash,Old));
        var afterSessions=await final.InternalSessions.AsNoTracking().Where(x=>x.StaffId==f.Target).ToArrayAsync();
        Assert.Equal(targetSessions.Select(x=>x.Id).Order(),afterSessions.Select(x=>x.Id).Order());
        Assert.All(afterSessions,s=> {Assert.NotNull(s.RevokedAt);Assert.Equal(m.SecurityVersion,s.SecurityVersion);});
        Assert.All(afterSessions.Where(x=>f.Revocable.Contains(x.Id)),s=>Assert.InRange(s.RevokedAt!.Value,startedAt,DateTimeOffset.UtcNow));
        var security=new InternalSecurityService(final,hasher,TimeProvider.System);
        foreach(var principal in oldPrincipals)Assert.Null(await security.ValidateSession(principal,default));
    }
    private static async Task<HashSet<int>> DatabaseSessions(SqlConnection observer)
    {
        await using var command=observer.CreateCommand();command.CommandTimeout=2;
        command.CommandText="SELECT session_id FROM sys.dm_exec_sessions WHERE is_user_process=1 AND database_id=DB_ID()";
        var result=new HashSet<int>();await using var rows=await command.ExecuteReaderAsync();
        while(await rows.ReadAsync())result.Add(Convert.ToInt32(rows.GetValue(0),CultureInfo.InvariantCulture));
        return result;
    }
    private static async Task<bool> ObserveTargetLockWait(SqlConnection observer,int contender,int blocker,TimeSpan budget)
    {
        // Missing DMV visibility fails closed. Never grant permissions or fall back to a task-start signal.
        using var deadline=new CancellationTokenSource(budget+TimeSpan.FromSeconds(2));
        var clock=System.Diagnostics.Stopwatch.StartNew();
        do
        {
            await using var command=observer.CreateCommand();command.CommandTimeout=2;
            // CHARINDEX, not LIKE: T-SQL LIKE has no literal-bracket escape, so a bracketed identifier
            // is matched exactly instead of as a wildcard character class.
            command.CommandText="""
                SELECT COUNT(*) FROM sys.dm_exec_requests r
                CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) sql_text
                WHERE r.session_id=@contender AND r.blocking_session_id=@blocker
                  AND r.database_id=DB_ID() AND r.wait_type LIKE N'LCK[_]M[_]%'
                  AND CHARINDEX(N'[Staff]',SUBSTRING(sql_text.text,(r.statement_start_offset/2)+1,
                    ((CASE r.statement_end_offset WHEN -1 THEN DATALENGTH(sql_text.text)
                      ELSE r.statement_end_offset END-r.statement_start_offset)/2)+1))>0
                """;
            command.Parameters.AddWithValue("@contender",contender);command.Parameters.AddWithValue("@blocker",blocker);
            if(Convert.ToInt32(await command.ExecuteScalarAsync(deadline.Token),CultureInfo.InvariantCulture)==1)return true;
            if(clock.Elapsed>=budget)return false;
            await Task.Delay(TimeSpan.FromMilliseconds(20),deadline.Token);
        }while(clock.Elapsed<budget);
        return false;
    }
    [OwnerRecoverySqlTheory]
    [InlineData("disabled")] [InlineData("nonOwner")] [InlineData("empty")] [InlineData("all-disabled")] [InlineData("all-nonOwner")]
    public async Task F4_F11_ineligible_installation_cannot_recover_or_reopen_bootstrap(string kind)
    {
        await using var f=await OwnerRecoveryFixture.Create();var m=await f.Manifest();
        await using(var db=f.Context())
        {
            if(kind=="empty") {await db.Set<InternalBranchAssignmentAudit>().ExecuteDeleteAsync();await db.InternalSessions.ExecuteDeleteAsync();await db.InternalStaff.ExecuteDeleteAsync();}
            else if(kind=="all-disabled")await db.InternalStaff.ExecuteUpdateAsync(u=>u.SetProperty(x=>x.Enabled,false));
            else if(kind=="all-nonOwner")await db.InternalStaff.ExecuteUpdateAsync(u=>u.SetProperty(x=>x.Role,"Manager"));
            else {var target=await db.InternalStaff.SingleAsync(x=>x.Id==f.Target);if(kind=="disabled")target.Enabled=false;else target.Role="Manager";await db.SaveChangesAsync();}
        }
        var before=await f.Snapshot();await using var service=new InternalOwnerRecoveryService(m);
        await Assert.ThrowsAnyAsync<Exception>(()=>service.Inspect(default));Assert.Equal(before,await f.Snapshot());
        if(kind=="empty")
        {
            await using var db=f.Context();var bootstrap=new InternalOwnerBootstrap(db,new PasswordHasher<InternalStaff>(),TimeProvider.System);
            Assert.True((await bootstrap.CreateInitialOwner("new-owner","Synthetic",Replacement,default)).Success);
            Assert.Equal(1,await db.InternalStaff.CountAsync());Assert.Equal(1,await db.InternalStaff.CountAsync(x=>x.Enabled&&x.Role=="Owner"));
            var one=await f.Snapshot();
            Assert.Equal("bootstrap_closed",(await bootstrap.CreateInitialOwner("second-owner","Synthetic",Replacement,default)).Error);
            Assert.Equal(one,await f.Snapshot()); // Second custodian requires the ordinary authorized API.
        }
        else
        {
            await using var db=f.Context();var bootstrap=new InternalOwnerBootstrap(db,new PasswordHasher<InternalStaff>(),TimeProvider.System);
            Assert.Equal("bootstrap_closed",(await bootstrap.CreateInitialOwner("new-owner","Synthetic",Replacement,default)).Error);
            Assert.Equal(before,await f.Snapshot());
        }
    }

    [OwnerRecoverySqlFact]
    public async Task F4_malformed_stored_hash_is_full_no_write()
    {
        await using var f=await OwnerRecoveryFixture.Create();
        await using(var db=f.Context()){(await db.InternalStaff.SingleAsync(x=>x.Id==f.Target)).PasswordHash="malformed";await db.SaveChangesAsync();}
        var before=await f.Snapshot();await using var service=new InternalOwnerRecoveryService(await f.Manifest());await service.Inspect(default);
        Assert.Equal(OwnerRecoveryOutcome.Refused,await service.Recover(Replacement,new Journal(),()=>true));
        Assert.Equal(before,await f.Snapshot());await f.AssertMigrations();
    }
    [OwnerRecoverySqlFact]
    public async Task F4_native_denied_SQL_and_unavailable_metadata_are_full_no_write()
    {
        await using var f=await OwnerRecoveryFixture.Create();var before=await f.Snapshot();
        await using var service=new InternalOwnerRecoveryService(await f.Manifest());await service.Inspect(default);
        // Fixture-only access to the SAME production connection. No product impersonation seam or new SQL user/grant.
        var field=typeof(InternalOwnerRecoveryService).GetField("connection",System.Reflection.BindingFlags.NonPublic|System.Reflection.BindingFlags.Instance)!;
        var connection=(SqlConnection)field.GetValue(service)!;
        await using(var cmd=connection.CreateCommand()){cmd.CommandText="EXECUTE AS USER=N'guest'";await cmd.ExecuteNonQueryAsync();}
        try
        {
            await using(var cmd=connection.CreateCommand())
            {
                cmd.CommandText="SELECT * FROM savia_internal.Staff";
                var denied=await Assert.ThrowsAsync<SqlException>(async()=>{await using var reader=await cmd.ExecuteReaderAsync();});
                Assert.Contains(denied.Number,new[]{229,916});
            }
            // The production identity query now has unavailable metadata or an inaccessible catalog.
            Assert.Equal(OwnerRecoveryOutcome.Refused,await service.Recover(Replacement,new Journal(),()=>true));
        }
        finally {await using var cmd=connection.CreateCommand();cmd.CommandText="REVERT";await cmd.ExecuteNonQueryAsync();}
        Assert.Equal(before,await f.Snapshot());await f.AssertMigrations();
    }
    [OwnerRecoverySqlFact]
    public async Task F12_typed_oracle_detects_each_excluded_category_and_restores()
    {
        await using var f=await OwnerRecoveryFixture.Create();var before=await f.Snapshot();
        var updates=new[]{
            "UPDATE savia_internal.Branches SET Name=N'changed canary'",
            "UPDATE savia_internal.BranchAssignmentAudit SET CreatedAt=DATEADD(second,1,CreatedAt)",
            "UPDATE savia_internal.Staff SET DisplayName=N'changed unrelated' WHERE Id<>@target",
            "UPDATE savia_internal.Sessions SET ExpiresAt=DATEADD(second,1,ExpiresAt) WHERE StaffId<>@target",
            "UPDATE savia_internal.Staff SET DisplayName=N'changed target immutable' WHERE Id=@target",
            "UPDATE savia_internal.Sessions SET RevokedAt=DATEADD(second,1,RevokedAt) WHERE StaffId=@target AND RevokedAt IS NOT NULL"};
        await using var c=new SqlConnection(f.Connection);await c.OpenAsync();
        foreach(var sql in updates)
        {
            await using var tx=(SqlTransaction)await c.BeginTransactionAsync();
            var preserved=await OwnerRecoveryOracle.Capture(c,tx,f.Target,f.Revocable);
            await using(var cmd=c.CreateCommand()){cmd.Transaction=tx;cmd.CommandText=sql;cmd.Parameters.AddWithValue("@target",f.Target);Assert.True(await cmd.ExecuteNonQueryAsync()>0);}
            var changed=await OwnerRecoveryOracle.Capture(c,tx,f.Target,f.Revocable);Assert.Contains(preserved,row=>changed[row.Key]!=row.Value);
            await tx.RollbackAsync();Assert.Equal(before,await f.Snapshot());
        }
    }
    [OwnerRecoverySqlFact]
    public async Task F11_one_owner_is_valid_two_is_operational_not_continuous_invariant()
    {
        await using var f=await OwnerRecoveryFixture.Create();
        await using var db=f.Context();var hasher=new PasswordHasher<InternalStaff>();
        var service=new InternalSecurityService(db,hasher,TimeProvider.System);
        var actor=(await service.Login(new("other",Old),default)).Value!;
        var target=await db.InternalStaff.SingleAsync(x=>x.Id==f.Target);
        Assert.Equal(2,await db.InternalStaff.CountAsync(x=>x.Enabled&&x.Role=="Owner"));
        Assert.True((await service.UpdateStaff(InternalSecurityRules.Principal(actor.Staff,actor.Session),target.Id,new("Synthetic","Manager",true,target.SecurityVersion),default)).Success);
        Assert.Equal(1,await db.InternalStaff.CountAsync(x=>x.Enabled&&x.Role=="Owner"));
        var before=await f.Snapshot();
        Assert.Equal("last_owner_required",(await service.UpdateStaff(InternalSecurityRules.Principal(actor.Staff,actor.Session),actor.Staff.Id,new("Other","Manager",true,actor.Staff.SecurityVersion),default)).Error);
        Assert.Equal(before,await f.Snapshot());
    }
    [OwnerRecoverySqlFact]
    public async Task F11_concurrent_demotions_preserve_one_but_fail_two_owner_readiness()
    {
        await using var f=await OwnerRecoveryFixture.Create();
        await using(var db=f.Context()){await db.InternalStaff.ExecuteUpdateAsync(u=>u.SetProperty(x=>x.LockedUntil,(DateTimeOffset?)null).SetProperty(x=>x.FailedSignIns,0));}
        var principals=new List<System.Security.Claims.ClaimsPrincipal>();
        foreach(var login in new[]{"owner","other"})
        {await using var db=f.Context();var result=await new InternalSecurityService(db,new PasswordHasher<InternalStaff>(),TimeProvider.System).Login(new(login,Old),default);Assert.True(result.Success);principals.Add(InternalSecurityRules.Principal(result.Value!.Staff,result.Value.Session));}
        using var ready=new CountdownEvent(2);using var release=new ManualResetEventSlim();
        async Task<bool> Demote(System.Security.Claims.ClaimsPrincipal actor)
        {
            ready.Signal();if(!release.Wait(TimeSpan.FromSeconds(10)))throw new TimeoutException();
            await using var db=f.Context();
            var id=InternalActor.Id(actor);var version=Guid.Parse(actor.FindFirst(InternalSecurityRules.VersionClaim)!.Value);
            try{return (await new InternalSecurityService(db,new PasswordHasher<InternalStaff>(),TimeProvider.System).UpdateStaff(actor,id,new("Synthetic","Manager",true,version),default)).Success;}
            catch(SqlException error)when(error.Number==1205){return false;}
            catch(DbUpdateException error)when(error.InnerException is SqlException {Number:1205}){return false;}
            // EF's execution strategy rewraps a deadlock as InvalidOperationException around the SqlException.
            catch(InvalidOperationException error)when(error.InnerException is SqlException {Number:1205}){return false;}
        }
        var tasks=principals.Select(actor=>Task.Run(()=>Demote(actor))).ToArray();
        try{Assert.True(ready.Wait(TimeSpan.FromSeconds(10)));}finally{release.Set();await Task.WhenAll(tasks);}
        Assert.Equal(1,tasks.Count(task=>task.Result));
        await using var final=f.Context();var owners=await final.InternalStaff.CountAsync(x=>x.Enabled&&x.Role=="Owner");
        Assert.Equal(1,owners);Assert.False(owners>=2);await f.AssertMigrations();
    }
    [OwnerRecoverySqlFact]
    public async Task F8_real_deadlock_victim_is_not_retried_and_every_task_is_joined()
    {
        await using var f=await OwnerRecoveryFixture.Create();var before=await f.Snapshot();var manifest=await f.Manifest();
        await using var adversary=new SqlConnection(f.Connection);await adversary.OpenAsync();
        await using var tx=(SqlTransaction)await adversary.BeginTransactionAsync();
        await using(var cmd=adversary.CreateCommand())
        {cmd.Transaction=tx;cmd.CommandText="SET DEADLOCK_PRIORITY HIGH; UPDATE savia_internal.Sessions SET ExpiresAt=ExpiresAt WHERE StaffId=@target";cmd.Parameters.AddWithValue("@target",f.Target);await cmd.ExecuteNonQueryAsync();}
        using var locked=new ManualResetEventSlim();using var release=new ManualResetEventSlim();var attempts=0;
        await using var service=new InternalOwnerRecoveryService(manifest,stage=>{if(stage=="after-target-lock"){Interlocked.Increment(ref attempts);locked.Set();if(!release.Wait(TimeSpan.FromSeconds(15)))throw new TimeoutException();}});
        await service.Inspect(default);var recovery=Task.Run(()=>service.Recover(Replacement,new Journal(),()=>true));Task? contender=null;
        try
        {
            Assert.True(locked.Wait(TimeSpan.FromSeconds(10)));
            contender=Task.Run(async()=> {await using var cmd=adversary.CreateCommand();cmd.Transaction=tx;cmd.CommandTimeout=30;cmd.CommandText="UPDATE savia_internal.Staff SET DisplayName=DisplayName WHERE Id=@target";cmd.Parameters.AddWithValue("@target",f.Target);await cmd.ExecuteNonQueryAsync();});
        }
        finally {release.Set();try{await Task.WhenAll(contender is null?new Task[]{recovery}:new Task[]{recovery,contender});}finally{await tx.RollbackAsync();}}
        Assert.Equal(OwnerRecoveryOutcome.Refused,await recovery);Assert.Equal(1,attempts);
        Assert.Equal(before,await f.Snapshot());await f.AssertMigrations();
    }
    [OwnerRecoverySqlFact]
    public async Task F13_backup_restore_and_independent_unknown_reconciliation()
    {
        // This additionally needs a pre-approved SQL-server-local backup directory. It is never created here.
        var directory=Environment.GetEnvironmentVariable("SAVIA_OWNER_RECOVERY_BACKUP_DIRECTORY")??throw new InvalidOperationException();
        await using var f=await OwnerRecoveryFixture.Create();var manifest=await f.Manifest();var before=await f.Snapshot();
        var path=Path.Combine(directory,manifest.Catalog+".bak");
        await f.RecordBackup(path);
        await using(var c=new SqlConnection(f.Connection))
        {await c.OpenAsync();await using var cmd=c.CreateCommand();cmd.CommandText=$"BACKUP DATABASE [{manifest.Catalog}] TO DISK=@path WITH COPY_ONLY, CHECKSUM";cmd.Parameters.AddWithValue("@path",path);await cmd.ExecuteNonQueryAsync();}
        var journal=new Journal("receipt-failure");
        await using(var service=new InternalOwnerRecoveryService(manifest))
        {await service.Inspect(default);Assert.Equal(OwnerRecoveryOutcome.Unknown,await service.Recover(Replacement,journal,()=>true));}
        // Reconciliation is a fresh independent read, never an automatic recovery retry or a login probe.
        await using(var db=f.Context())
        {var actual=await db.InternalStaff.AsNoTracking().SingleAsync(x=>x.Id==f.Target);Assert.Equal(journal.IntentVersion,actual.SecurityVersion);Assert.NotEqual(manifest.SecurityVersion,actual.SecurityVersion);}
        Assert.DoesNotContain("COMMITTED",journal.Results);await f.AssertMigrations();
        await f.BeginOwnedRestore();
        var master=new SqlConnectionStringBuilder(f.Connection){InitialCatalog="master",Pooling=false};
        await using(var c=new SqlConnection(master.ConnectionString))
        {await c.OpenAsync();await using var cmd=c.CreateCommand();cmd.CommandText=$"RESTORE VERIFYONLY FROM DISK=@path WITH CHECKSUM; ALTER DATABASE [{manifest.Catalog}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; RESTORE DATABASE [{manifest.Catalog}] FROM DISK=@path WITH REPLACE,CHECKSUM; ALTER DATABASE [{manifest.Catalog}] SET MULTI_USER";cmd.Parameters.AddWithValue("@path",path);await cmd.ExecuteNonQueryAsync();}
        await f.ReadOwnedRestore();Assert.Equal(before,await f.Snapshot());await f.AssertMigrations();
        // The exact backup name is recorded for its SQL-host custodian; no broad or host-side deletion.
        await f.RecordBackup(path);
    }
    private sealed class Journal(string point="none"):IOwnerRecoveryJournal
    {
        public List<string> Results {get;}=[];
        public Guid IntentVersion {get;private set;}
        public int IntentAttempts {get;private set;}
        public void Write(string result,Guid operation,Guid version)
        {if(result=="INTENT"){IntentAttempts++;IntentVersion=version;}if((point=="pre-write-journal"&&result=="INTENT")||(point=="receipt-failure"&&result=="COMMITTED"))throw new IOException();Results.Add(result);}
    }
}
