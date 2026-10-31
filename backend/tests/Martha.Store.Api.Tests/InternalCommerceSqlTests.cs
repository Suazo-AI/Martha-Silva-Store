using System.Data;
using Martha.Store.Api.Internal;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Martha.Store.Api.Tests;

// These are real SQL Server tests, not SQLite/InMemory substitutes. The opt-in variable
// authorizes a disposable CREATE/DROP database fixture; no database is started by this suite.
public sealed class InternalCommerceSqlFactAttribute : FactAttribute
{
    public InternalCommerceSqlFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("MARTHA_INTERNAL_TEST_SQL_CONNECTION")))
            Skip = "Not run: authorized disposable SQL Server endpoint MARTHA_INTERNAL_TEST_SQL_CONNECTION is absent. No persistence/concurrency proof.";
    }
}

public sealed class InternalCommerceSqlTests
{
    [InternalCommerceSqlFact]
    public async Task Ledger_creates_only_zero_based_balance_and_records_server_actor()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        await using var db = fixture.Context();
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        var operation = Guid.NewGuid();
        var result = await new InternalStockLedger(db).Change(fixture.Item, fixture.Location, 4, 0, fixture.Actor, operation, "purchase_receipt", default);
        Assert.True(result.Success);
        Assert.Same(tx, db.Database.CurrentTransaction); // Ledger did not commit/dispose its caller's transaction.
        await tx.CommitAsync();
        await using var verify = fixture.Context();
        var balance = await verify.Set<InternalStockBalance>().SingleAsync();
        Assert.Equal(4, balance.OnHand);
        Assert.Equal(0, balance.Reserved);
        var movement = await verify.Set<InternalStockMovement>().SingleAsync();
        Assert.Equal(fixture.Actor, movement.ActorId);
        Assert.Equal(operation, movement.OperationId);
        Assert.Equal(4, movement.OnHandDelta);
        Assert.Equal(4, movement.OnHandAfter);
    }

    [InternalCommerceSqlFact]
    public async Task Reserved_units_and_upper_stock_bound_cannot_be_consumed_or_overflowed()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        await using var db = fixture.Context();
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        var ledger = new InternalStockLedger(db);
        Assert.True((await ledger.Change(fixture.Item, fixture.Location, 10, 3, fixture.Actor, Guid.NewGuid(), "adjustment", default)).Success);
        Assert.Equal("stock_unavailable", (await ledger.Change(fixture.Item, fixture.Location, -8, 0, fixture.Actor, Guid.NewGuid(), "sale", default)).Error);
        Assert.Equal("stock_unavailable", (await ledger.Change(fixture.Item, fixture.Location, InternalStockLedger.MaxStock, 0, fixture.Actor, Guid.NewGuid(), "adjustment", default)).Error);
        Assert.Equal("stock_unavailable", (await ledger.Change(fixture.Item, fixture.Location, 0, -4, fixture.Actor, Guid.NewGuid(), "release", default)).Error);
        Assert.Single(await db.Set<InternalStockMovement>().ToListAsync());
        var balance = await db.Set<InternalStockBalance>().SingleAsync();
        Assert.Equal(10, balance.OnHand);
        Assert.Equal(3, balance.Reserved);
        await tx.RollbackAsync();
    }

    [InternalCommerceSqlFact]
    public async Task Concurrent_first_receipts_initialize_one_balance_without_lost_quantity()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        var results = await Task.WhenAll(Change(fixture, 1), Change(fixture, 1));
        Assert.All(results, result => Assert.True(result.Success));
        await using var verify = fixture.Context();
        Assert.Equal(2, (await verify.Set<InternalStockBalance>().SingleAsync()).OnHand);
        Assert.Equal(2, await verify.Set<InternalStockMovement>().CountAsync());
    }

    [InternalCommerceSqlFact]
    public async Task Concurrent_consumers_cannot_oversell_one_available_unit()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        Assert.True((await Change(fixture, 1)).Success);
        var results = await Task.WhenAll(Change(fixture, -1), Change(fixture, -1));
        Assert.Single(results, result => result.Success);
        Assert.Single(results, result => result.Error == "stock_unavailable");
        await using var verify = fixture.Context();
        Assert.Equal(0, (await verify.Set<InternalStockBalance>().SingleAsync()).OnHand);
        Assert.Equal(2, await verify.Set<InternalStockMovement>().CountAsync());
    }

    [InternalCommerceSqlFact]
    public async Task Caller_rollback_removes_prior_line_updates_and_their_saved_movement_rows()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        Assert.True((await Change(fixture, 1)).Success);
        var operation = Guid.NewGuid();
        await using (var db = fixture.Context())
        {
            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            var ledger = new InternalStockLedger(db);
            Assert.True((await ledger.Change(fixture.Item, fixture.Location, -1, 0, fixture.Actor, operation, "sale", default)).Success);
            Assert.Equal("stock_unavailable", (await ledger.Change(fixture.SecondItem, fixture.Location, -1, 0, fixture.Actor, operation, "sale", default)).Error);
            await tx.RollbackAsync();
        }
        await using var verify = fixture.Context();
        Assert.Equal(1, (await verify.Set<InternalStockBalance>().SingleAsync()).OnHand);
        Assert.False(await verify.Set<InternalStockMovement>().AnyAsync(x => x.OperationId == operation));
        Assert.False(await verify.Set<InternalStockBalance>().AnyAsync(x => x.ItemId == fixture.SecondItem));
    }

    [InternalCommerceSqlFact]
    public async Task Ledger_rejects_lower_isolation_before_mutating_SQL()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        await using var db = fixture.Context();
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.ReadCommitted);
        await Assert.ThrowsAsync<InvalidOperationException>(() => new InternalStockLedger(db)
            .Change(fixture.Item, fixture.Location, 1, 0, fixture.Actor, Guid.NewGuid(), "adjustment", default));
        Assert.False(await db.Set<InternalStockBalance>().AnyAsync());
    }

    private static async Task<InternalResult<bool>> Change(InternalCommerceSqlDatabase fixture, int delta)
    {
        await using var db = fixture.Context();
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        var result = await new InternalStockLedger(db).Change(fixture.Item, fixture.Location, delta, 0, fixture.Actor, Guid.NewGuid(), "adjustment", default);
        if (result.Success) await tx.CommitAsync();
        else await tx.RollbackAsync();
        return result;
    }
}

// Independent database with internal model DDL only. Passing these tests would NOT verify migrations,
// authentication, deployment, or bank payments. The harness creates no real customer/account data.
internal sealed class InternalCommerceSqlDatabase : IAsyncDisposable
{
    private readonly string name = "SaviaInternalTest_Commerce_" + Guid.NewGuid().ToString("N");
    private readonly string adminConnection;
    private readonly string connection;
    private bool created;
    public Guid Item { get; } = Guid.Parse("10000000-0000-0000-0000-000000000001");
    public Guid SecondItem { get; } = Guid.Parse("20000000-0000-0000-0000-000000000002");
    public Guid Location { get; } = Guid.NewGuid();
    public Guid Actor { get; } = Guid.NewGuid();
    public InternalStaff Staff { get; private set; } = null!;
    public InternalSession Session { get; private set; } = null!;

    private InternalCommerceSqlDatabase()
    {
        var supplied = Environment.GetEnvironmentVariable("MARTHA_INTERNAL_TEST_SQL_CONNECTION")
            ?? throw new InvalidOperationException("Authorized disposable SQL endpoint was not supplied.");
        var builder = new SqlConnectionStringBuilder(supplied) { InitialCatalog = "master", Pooling = false };
        adminConnection = builder.ConnectionString;
        builder.InitialCatalog = name;
        connection = builder.ConnectionString;
    }

    public InternalDbContext Context() => new(new DbContextOptionsBuilder<InternalDbContext>().UseSqlServer(connection).Options);
    public static async Task<InternalCommerceSqlDatabase> Create()
    {
        var fixture = new InternalCommerceSqlDatabase();
        try
        {
            await using var master = new SqlConnection(fixture.adminConnection);
            await master.OpenAsync();
            await using var command = master.CreateCommand();
            command.CommandText = $"CREATE DATABASE [{fixture.name}]"; // Exclusively generated identifier, never supplied SQL.
            await command.ExecuteNonQueryAsync();
            fixture.created = true;
            await using var db = fixture.Context();
            await db.Database.EnsureCreatedAsync();
            db.Set<InternalItem>().AddRange(
                new InternalItem { Id = fixture.Item, Sku = "SQL-TEST-A", Name = "Disposable test item A", Currency = "USD", UnitPriceMinor = 125, Active = true },
                new InternalItem { Id = fixture.SecondItem, Sku = "SQL-TEST-B", Name = "Disposable test item B", Currency = "USD", UnitPriceMinor = 275, Active = true });
            db.Set<InternalLocation>().Add(new() { Id = fixture.Location, Name = "Disposable test location", Active = true });
            var now = DateTimeOffset.UtcNow;
            fixture.Staff = new InternalStaff
            {
                Id = fixture.Actor, LoginName = "disposable.test.owner", NormalizedLoginName = "DISPOSABLE.TEST.OWNER",
                DisplayName = "Disposable SQL test owner", PasswordHash = "session-tests-only-not-a-password-hash",
                Role = "Owner", Enabled = true, SecurityVersion = Guid.NewGuid(), CreatedAt = now, UpdatedAt = now
            };
            fixture.Session = new InternalSession
            {
                Id = Guid.NewGuid(), StaffId = fixture.Actor, SecurityVersion = fixture.Staff.SecurityVersion,
                CreatedAt = now, ExpiresAt = now.Add(InternalSecurityRules.SessionLifetime)
            };
            db.Set<InternalStaff>().Add(fixture.Staff);
            db.Set<InternalSession>().Add(fixture.Session);
            await db.SaveChangesAsync();
            return fixture;
        }
        catch
        {
            await fixture.DisposeAsync();
            throw;
        }
    }

    public async Task<T> Execute<T>(Func<InternalCommerceService, Task<T>> action)
    {
        await using var db = Context();
        var security = new InternalSecurityService(db, new PasswordHasher<InternalStaff>(), TimeProvider.System);
        var http = new HttpContextAccessor
        {
            HttpContext = new DefaultHttpContext { User = InternalSecurityRules.Principal(Staff, Session) }
        };
        var commands = new InternalCommandRunner(db, security, http, TimeProvider.System);
        return await action(new InternalCommerceService(db, commands, new InternalStockLedger(db)));
    }

    public async ValueTask DisposeAsync()
    {
        if (!created) return;
        await using var master = new SqlConnection(adminConnection);
        await master.OpenAsync();
        await using var command = master.CreateCommand();
        command.CommandText = $"ALTER DATABASE [{name}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{name}]";
        await command.ExecuteNonQueryAsync();
        created = false;
    }
}
