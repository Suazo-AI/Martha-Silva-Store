using System.Text.Json;
using Martha.Store.Api.Internal;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Martha.Store.Api.Tests;

// Real SQL-only tests, intentionally gated twice and NOT executed in this lot.
// Synthetic identities/data exist only in an explicitly authorized new disposable
// database. No SQLite/InMemory substitute, credentials, mock runner or mock ledger.
public sealed class InternalSupplySqlServerTests
{
    [InternalSupplySqlFact]
    public async Task Partial_multiline_receipt_replays_without_duplicate_stock_and_completes_remainder()
    {
        await using var fixture = await SupplySqlFixture.Create();
        var order = await fixture.Purchase();
        var first = order.Lines.Single(x => x.ItemId == SupplySqlFixture.FirstItem);
        var second = order.Lines.Single(x => x.ItemId == SupplySqlFixture.SecondItem);
        var request = new InternalPurchaseReceiptRequest(Guid.NewGuid(), [new(first.Id, 2), new(second.Id, 5)]);
        var receipt = await fixture.Run(service => service.Receive(fixture.Actor.Id, "synthetic-receipt-0001", order.Id, request, default));
        Assert.True(receipt.Success, receipt.Error);
        Assert.Equal(InternalPurchaseStatus.Partial, receipt.Value!.OrderStatusAfter);
        Assert.Equal(2 * 250 + 5 * 400, receipt.Value.TotalMinor); // Frozen procurement cost, not retail price.
        var keyReplay = await fixture.Run(service => service.Receive(fixture.Actor.Id, "synthetic-receipt-0001", order.Id, request, default));
        var identityReplay = await fixture.Run(service => service.Receive(fixture.Actor.Id, "synthetic-receipt-0002", order.Id, request, default));
        Assert.Equal(JsonSerializer.Serialize(receipt), JsonSerializer.Serialize(keyReplay));
        Assert.Equal(JsonSerializer.Serialize(receipt), JsonSerializer.Serialize(identityReplay));
        await using (var db = fixture.Context())
        {
            Assert.Equal(2, await db.Set<InternalStockMovement>().CountAsync());
            Assert.Equal(1, await db.Set<InternalPurchaseReceipt>().CountAsync());
            Assert.Equal(2, (await db.Set<InternalStockBalance>().SingleAsync(x => x.ItemId == first.ItemId)).OnHand);
            Assert.Equal(5, (await db.Set<InternalStockBalance>().SingleAsync(x => x.ItemId == second.ItemId)).OnHand);
        }
        var finish = await fixture.Run(service => service.Receive(fixture.Actor.Id, "synthetic-receipt-0003", order.Id,
            new(Guid.NewGuid(), [new(first.Id, 3)]), default));
        Assert.True(finish.Success, finish.Error);
        Assert.Equal(InternalPurchaseStatus.Received, finish.Value!.OrderStatusAfter);
        await using var after = fixture.Context();
        Assert.All(await after.Set<InternalPurchaseOrderLine>().ToListAsync(), line => Assert.Equal(line.Quantity, line.ReceivedQuantity));
        Assert.All(await after.Set<InternalStockBalance>().ToListAsync(), balance => Assert.Equal(5, balance.OnHand));
        Assert.All(await after.Set<InternalStockMovement>().ToListAsync(), movement => Assert.Equal(fixture.Actor.Id, movement.ActorId));
    }

    [InternalSupplySqlFact]
    public async Task Overreceipt_rejects_every_line_and_conflicting_receipt_identity_cannot_be_reused()
    {
        await using var fixture = await SupplySqlFixture.Create();
        var order = await fixture.Purchase();
        var first = order.Lines.Single(x => x.ItemId == SupplySqlFixture.FirstItem);
        var second = order.Lines.Single(x => x.ItemId == SupplySqlFixture.SecondItem);
        var excess = await fixture.Run(service => service.Receive(fixture.Actor.Id, "synthetic-overreceipt-01", order.Id,
            new(Guid.NewGuid(), [new(first.Id, 1), new(second.Id, 6)]), default));
        Assert.Equal("receipt_exceeds_remaining", excess.Error);
        await using (var db = fixture.Context())
        {
            Assert.Empty(await db.Set<InternalStockMovement>().ToListAsync());
            Assert.Empty(await db.Set<InternalPurchaseReceipt>().ToListAsync());
            Assert.All(await db.Set<InternalPurchaseOrderLine>().ToListAsync(), line => Assert.Equal(0, line.ReceivedQuantity));
        }
        var receiptId = Guid.NewGuid();
        Assert.True((await fixture.Run(service => service.Receive(fixture.Actor.Id, "synthetic-receipt-good1", order.Id,
            new(receiptId, [new(first.Id, 1)]), default))).Success);
        var conflict = await fixture.Run(service => service.Receive(fixture.Actor.Id, "synthetic-receipt-bad01", order.Id,
            new(receiptId, [new(first.Id, 2)]), default));
        Assert.Equal("receipt_identity_conflict", conflict.Error);
        var otherOrder = await fixture.Purchase("synthetic-purchase-002");
        var otherConflict = await fixture.Run(service => service.Receive(fixture.Actor.Id, "synthetic-receipt-bad02", otherOrder.Id,
            new(receiptId, [new(otherOrder.Lines[0].Id, 1)]), default));
        Assert.Equal("receipt_identity_conflict", otherConflict.Error);
        await using var after = fixture.Context();
        Assert.Single(await after.Set<InternalPurchaseReceipt>().ToListAsync());
        Assert.Single(await after.Set<InternalStockMovement>().ToListAsync());
    }

    [InternalSupplySqlFact]
    public async Task Cancelling_partial_order_preserves_received_stock_and_closes_only_remainder()
    {
        await using var fixture = await SupplySqlFixture.Create();
        var order = await fixture.Purchase();
        var line = order.Lines.Single(x => x.ItemId == SupplySqlFixture.FirstItem);
        Assert.True((await fixture.Run(service => service.Receive(fixture.Actor.Id, "synthetic-partial-0001", order.Id,
            new(Guid.NewGuid(), [new(line.Id, 2)]), default))).Success);
        var cancel = await fixture.Run(service => service.Cancel(fixture.Actor.Id, "synthetic-cancel-00001", order.Id,
            new("Synthetic supplier remainder cancelled"), default));
        Assert.True(cancel.Success, cancel.Error);
        Assert.Equal(InternalPurchaseStatus.Cancelled, cancel.Value!.Status);
        Assert.Equal(fixture.Actor.Id, cancel.Value.CancelledBy);
        var cancelledLine = cancel.Value.Lines.Single(x => x.Id == line.Id);
        Assert.Equal(2, cancelledLine.ReceivedQuantity);
        Assert.Equal(3, cancelledLine.CancelledQuantity);
        Assert.Equal(0, cancelledLine.RemainingReceivableQuantity);
        var lateReceipt = await fixture.Run(service => service.Receive(fixture.Actor.Id, "synthetic-after-cancel", order.Id,
            new(Guid.NewGuid(), [new(line.Id, 1)]), default));
        Assert.Equal("purchase_order_closed", lateReceipt.Error);
        await using var db = fixture.Context();
        Assert.Equal(2, (await db.Set<InternalStockBalance>().SingleAsync()).OnHand);
        Assert.Single(await db.Set<InternalStockMovement>().ToListAsync());
        Assert.Single(await db.Set<InternalPurchaseReceipt>().ToListAsync());
    }

    [InternalSupplySqlFact]
    public async Task Second_line_stock_failure_rolls_back_first_counter_stock_movement_and_receipt()
    {
        await using var fixture = await SupplySqlFixture.Create();
        await using (var setup = fixture.Context())
        {
            setup.Set<InternalStockBalance>().Add(new() { ItemId = SupplySqlFixture.SecondItem,
                LocationId = SupplySqlFixture.Location, OnHand = InternalStockLedger.MaxStock, UpdatedAt = DateTimeOffset.UtcNow });
            await setup.SaveChangesAsync();
        }
        var order = await fixture.Purchase();
        var request = new InternalPurchaseReceiptRequest(Guid.NewGuid(), order.Lines.Select(x => new InternalReceiptLineRequest(x.Id, 1)).ToArray());
        var failure = await fixture.Run(service => service.Receive(fixture.Actor.Id, "synthetic-rollback-001", order.Id, request, default));
        Assert.Equal("stock_unavailable", failure.Error);
        await using (var after = fixture.Context())
        {
            Assert.Empty(await after.Set<InternalPurchaseReceipt>().ToListAsync());
            Assert.Empty(await after.Set<InternalStockMovement>().ToListAsync());
            Assert.All(await after.Set<InternalPurchaseOrderLine>().ToListAsync(), line => Assert.Equal(0, line.ReceivedQuantity));
            var onlyBalance = Assert.Single(await after.Set<InternalStockBalance>().ToListAsync());
            Assert.Equal(SupplySqlFixture.SecondItem, onlyBalance.ItemId);
            Assert.Equal(InternalStockLedger.MaxStock, onlyBalance.OnHand);
            Assert.Equal(InternalPurchaseStatus.Open, (await after.Set<InternalPurchaseOrder>().SingleAsync()).Status);
            await after.Set<InternalStockBalance>().ExecuteUpdateAsync(update => update.SetProperty(x => x.OnHand, 0));
        }
        // A recorded failure is immutable even after the business condition changes.
        var failureReplay = await fixture.Run(service => service.Receive(fixture.Actor.Id, "synthetic-rollback-001", order.Id, request, default));
        Assert.Equal("stock_unavailable", failureReplay.Error);
        await using var final = fixture.Context();
        Assert.Empty(await final.Set<InternalPurchaseReceipt>().ToListAsync());
        Assert.Empty(await final.Set<InternalStockMovement>().ToListAsync());
    }

    [InternalSupplySqlFact]
    public async Task Concurrent_duplicate_physical_receipts_never_increment_twice()
    {
        await using var fixture = await SupplySqlFixture.Create();
        var order = await fixture.Purchase();
        var line = order.Lines.Single(x => x.ItemId == SupplySqlFixture.FirstItem);
        var request = new InternalPurchaseReceiptRequest(Guid.NewGuid(), [new(line.Id, 2)]);
        var outcomes = await Task.WhenAll(
            fixture.Run(service => service.Receive(fixture.Actor.Id, "synthetic-race-same-01", order.Id, request, default)),
            fixture.Run(service => service.Receive(fixture.Actor.Id, "synthetic-race-same-02", order.Id, request, default)));
        Assert.Contains(outcomes, x => x.Success);
        Assert.All(outcomes.Where(x => !x.Success), x => Assert.Contains(x.Error, new[] { "storage_unavailable", "unknown_outcome", "outcome_unknown" }));
        await using var db = fixture.Context();
        Assert.Single(await db.Set<InternalPurchaseReceipt>().ToListAsync());
        Assert.Single(await db.Set<InternalStockMovement>().ToListAsync());
        Assert.Equal(2, (await db.Set<InternalStockBalance>().SingleAsync()).OnHand);
        Assert.Equal(2, (await db.Set<InternalPurchaseOrderLine>().SingleAsync(x => x.Id == line.Id)).ReceivedQuantity);
    }

    [InternalSupplySqlFact]
    public async Task Competing_receipts_for_last_units_cannot_overreceive()
    {
        await using var fixture = await SupplySqlFixture.Create();
        var order = await fixture.Purchase();
        var line = order.Lines.Single(x => x.ItemId == SupplySqlFixture.FirstItem);
        var outcomes = await Task.WhenAll(
            fixture.Run(service => service.Receive(fixture.Actor.Id, "synthetic-race-last-01", order.Id,
                new(Guid.NewGuid(), [new(line.Id, 5)]), default)),
            fixture.Run(service => service.Receive(fixture.Actor.Id, "synthetic-race-last-02", order.Id,
                new(Guid.NewGuid(), [new(line.Id, 5)]), default)));
        Assert.Single(outcomes, x => x.Success);
        Assert.All(outcomes.Where(x => !x.Success), x => Assert.Contains(x.Error,
            new[] { "receipt_exceeds_remaining", "purchase_order_closed", "storage_unavailable", "unknown_outcome", "outcome_unknown" }));
        await using var db = fixture.Context();
        Assert.Single(await db.Set<InternalPurchaseReceipt>().ToListAsync());
        Assert.Equal(5, (await db.Set<InternalStockBalance>().SingleAsync()).OnHand);
        Assert.Equal(5, (await db.Set<InternalPurchaseOrderLine>().SingleAsync(x => x.Id == line.Id)).ReceivedQuantity);
    }

    [InternalSupplySqlFact]
    public async Task Revoked_staff_session_cannot_mutate_or_replay_supply_commands()
    {
        await using var fixture = await SupplySqlFixture.Create();
        _ = await fixture.Purchase();
        await using (var setup = fixture.Context())
            await setup.Set<InternalSession>().ExecuteUpdateAsync(update => update.SetProperty(x => x.RevokedAt, (DateTimeOffset?)DateTimeOffset.UtcNow));
        var denied = await fixture.Run(service => service.Create(fixture.Actor.Id, "synthetic-purchase-001", fixture.OrderRequest(), default));
        Assert.False(denied.Success);
        Assert.Contains(denied.Error, new[] { "unauthenticated", "forbidden" });
        await using var db = fixture.Context();
        Assert.Single(await db.Set<InternalPurchaseOrder>().ToListAsync());
        Assert.Empty(await db.Set<InternalStockMovement>().ToListAsync());
    }

    private sealed class SupplySqlFixture : IAsyncDisposable
    {
        internal static readonly Guid FirstItem = Guid.Parse("10000000-0000-0000-0000-000000000001");
        internal static readonly Guid SecondItem = Guid.Parse("20000000-0000-0000-0000-000000000002");
        internal static readonly Guid Location = Guid.Parse("30000000-0000-0000-0000-000000000003");
        private static readonly Guid Supplier = Guid.Parse("40000000-0000-0000-0000-000000000004");
        private readonly string name = "SaviaInternalTest_Supply_" + Guid.NewGuid().ToString("N");
        private readonly string adminConnection;
        private readonly string connection;
        private bool created;
        public InternalStaff Actor { get; } = new() { Id = Guid.NewGuid(), LoginName = "synthetic-supply-owner",
            NormalizedLoginName = "SYNTHETIC-SUPPLY-OWNER", DisplayName = "Synthetic Supply Owner", Role = "Owner",
            Enabled = true, SecurityVersion = Guid.NewGuid(), PasswordHash = "SYNTHETIC_NONLOGIN_HASH",
            CreatedAt = DateTimeOffset.UtcNow, UpdatedAt = DateTimeOffset.UtcNow };
        private InternalSession Session { get; }
        private SupplySqlFixture()
        {
            if (Environment.GetEnvironmentVariable("SAVIA_INTERNAL_SQL_TESTS_AUTHORIZED") != "1")
                throw new InvalidOperationException("Explicit disposable SQL authorization is required.");
            var supplied = Environment.GetEnvironmentVariable("SAVIA_INTERNAL_TEST_SQL_CONNECTION")
                ?? throw new InvalidOperationException("An explicitly authorized disposable SQL connection is required.");
            var builder = new SqlConnectionStringBuilder(supplied) { InitialCatalog = "master", Pooling = false, MultipleActiveResultSets = false };
            adminConnection = builder.ConnectionString;
            builder.InitialCatalog = name;
            connection = builder.ConnectionString;
            Session = new() { Id = Guid.NewGuid(), StaffId = Actor.Id, SecurityVersion = Actor.SecurityVersion,
                CreatedAt = DateTimeOffset.UtcNow, ExpiresAt = DateTimeOffset.UtcNow.AddHours(7) };
        }
        public static async Task<SupplySqlFixture> Create()
        {
            var fixture = new SupplySqlFixture();
            try
            {
                await using var master = new SqlConnection(fixture.adminConnection);
                await master.OpenAsync();
                await using var command = master.CreateCommand();
                command.CommandText = $"CREATE DATABASE [{fixture.name}]"; // Entirely generated name; no supplied SQL identifier.
                await command.ExecuteNonQueryAsync();
                fixture.created = true;
                await using var db = fixture.Context();
                await db.Database.EnsureCreatedAsync(); // Disposable model test, not migration validation or startup behavior.
                db.Set<InternalStaff>().Add(fixture.Actor);
                db.Set<InternalSession>().Add(fixture.Session);
                db.Set<InternalParty>().Add(new() { Id = Supplier, Kind = "supplier", Name = "Synthetic Supply Supplier", Active = true });
                db.Set<InternalLocation>().Add(new() { Id = Location, Name = "Synthetic Supply Location", Active = true });
                db.Set<InternalItem>().AddRange(new InternalItem { Id = FirstItem, Sku = "SYNTH-SUPPLY-1", Name = "Synthetic supply item 1", UnitPriceMinor = 1000, Currency = "HNL", Active = true },
                    new InternalItem { Id = SecondItem, Sku = "SYNTH-SUPPLY-2", Name = "Synthetic supply item 2", UnitPriceMinor = 1500, Currency = "HNL", Active = true });
                await db.SaveChangesAsync();
                return fixture;
            }
            catch { await fixture.DisposeAsync(); throw; }
        }
        public InternalDbContext Context() => new(new DbContextOptionsBuilder<InternalDbContext>().UseSqlServer(connection).Options);
        public InternalPurchaseOrderRequest OrderRequest() => new(Supplier, Location, "HNL", [new(FirstItem, 5, 250), new(SecondItem, 5, 400)], "SYNTHETIC-ONLY");
        public async Task<InternalPurchaseOrderView> Purchase(string key = "synthetic-purchase-001")
        {
            var result = await Run(service => service.Create(Actor.Id, key, OrderRequest(), default));
            Assert.True(result.Success, result.Error);
            return result.Value!;
        }
        public async Task<T> Run<T>(Func<InternalSupplyService, Task<T>> action)
        {
            await using var db = Context();
            var http = new HttpContextAccessor { HttpContext = new DefaultHttpContext { User = InternalSecurityRules.Principal(Actor, Session) } };
            var security = new InternalSecurityService(db, new PasswordHasher<InternalStaff>(), TimeProvider.System);
            var runner = new InternalCommandRunner(db, security, http, TimeProvider.System);
            return await action(new InternalSupplyService(db, runner, new InternalStockLedger(db)));
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
}

public sealed class InternalSupplySqlFactAttribute : FactAttribute
{
    public InternalSupplySqlFactAttribute()
    {
        if (Environment.GetEnvironmentVariable("SAVIA_INTERNAL_SQL_TESTS_AUTHORIZED") != "1" ||
            string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("SAVIA_INTERNAL_TEST_SQL_CONNECTION")))
            Skip = "Not run: real disposable SQL Server and explicit SAVIA_INTERNAL_SQL_TESTS_AUTHORIZED=1 authorization are required; no SQL/EULA execution is authorized in this lot.";
    }
}
