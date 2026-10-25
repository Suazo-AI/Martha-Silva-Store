using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Martha.Store.Api;
using Microsoft.EntityFrameworkCore;
using Xunit;
using static Martha.Store.Api.Tests.SaviaContractTests;

namespace Martha.Store.Api.Tests;

// Real SQL only: never replace these transaction/concurrency checks with InMemory or SQLite.
[Trait("Category", "SqlServer")]
public sealed class SaviaSqlServerIntegrationTests
{
    private static async Task<SqlDatabase> Database(int onHand = 5)
    {
        var database = new SqlDatabase();
        try
        {
            await database.Initialize();
            await using var db = database.Context();
            await SaviaSyntheticSeed.Apply(db);
            if (onHand != 5)
                await db.SaviaBalances.ExecuteUpdateAsync(s => s.SetProperty(x => x.OnHand, onHand));
            return database;
        }
        catch { await database.DisposeAsync(); throw; }
    }

    private static Task<HttpResponseMessage> Reserve(HttpClient client, Guid attempt, string key, int quantity = 1) =>
        Send(client, "/reservations", ReserveBody(attempt, quantity), key);
    private static Task<HttpResponseMessage> Cancel(HttpClient client, Guid id, Guid attempt, string key) =>
        Send(client, $"/reservations/{id}/cancel", new { attemptId = attempt, authority = Authority }, key);
    private static async Task<JsonElement> Read(HttpResponseMessage response, HttpStatusCode status)
    {
        Assert.Equal(status, response.StatusCode);
        return await response.Content.ReadFromJsonAsync<JsonElement>();
    }
    private static async Task<JsonElement> Get(HttpClient client, string path)
    {
        using var response = await client.GetAsync(Prefix + path);
        return await Read(response, HttpStatusCode.OK);
    }
    private static async Task AssertBalances(SqlDatabase database, int onHand, int reserved)
    {
        await using var db = database.Context();
        var balance = await db.SaviaBalances.AsNoTracking().SingleAsync();
        Assert.Equal(onHand, balance.OnHand);
        Assert.Equal(reserved, balance.Reserved);
        Assert.InRange(balance.Reserved, 0, balance.OnHand);
        var movements = await db.SaviaMovements.AsNoTracking().ToListAsync();
        Assert.Equal(reserved, movements.Sum(x => x.ReservedDelta));
        Assert.All(movements, m => Assert.Equal(0, m.OnHandDelta));
        // V2 activity must never decrement the separate V1 fixture.
        Assert.Equal(1, (await db.Variants.AsNoTracking().SingleAsync()).AvailableQuantity);
        Assert.Empty(await db.SyntheticOrders.AsNoTracking().ToListAsync());
    }

    [SqlServerFact]
    public async Task Twenty_distinct_reservations_for_last_unit_have_one_winner_and_balanced_ledger()
    {
        await using var database = await Database(1);
        await using var factory = new TestApiFactory(connection: database.Connection);
        using var client = factory.CreateClient();
        var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var tasks = Enumerable.Range(0, 20).Select(async i =>
        { await start.Task; return await Reserve(client, Guid.NewGuid(), $"v2-last-unit-{i:D3}"); }).ToArray();
        start.SetResult();
        var responses = await Task.WhenAll(tasks);
        try
        {
            Assert.Single(responses, r => r.StatusCode == HttpStatusCode.Created);
            Assert.Equal(19, responses.Count(r => r.StatusCode == HttpStatusCode.Conflict));
            foreach (var response in responses.Where(r => r.StatusCode == HttpStatusCode.Conflict))
                await AssertError(response, HttpStatusCode.Conflict, "out_of_stock");
        }
        finally { foreach (var response in responses) response.Dispose(); }
        await AssertBalances(database, 1, 1);
        await using var db = database.Context();
        Assert.Single(await db.SaviaReservations.ToListAsync());
        Assert.Single(await db.SaviaMovements.ToListAsync());
        Assert.Equal(20, await db.SaviaAttempts.CountAsync());
        Assert.Equal(19, await db.SaviaAttempts.CountAsync(x => x.Outcome == "rejected" && x.Error == "out_of_stock"));
    }

    [SqlServerFact]
    public async Task Concurrent_same_key_replays_creation_and_changed_payload_conflicts()
    {
        await using var database = await Database();
        await using var factory = new TestApiFactory(connection: database.Connection);
        using var client = factory.CreateClient();
        var attempt = Guid.NewGuid();
        const string key = "v2-same-key-001";
        var responses = await Task.WhenAll(Enumerable.Range(0, 20).Select(_ => Reserve(client, attempt, key)));
        string original;
        try
        {
            Assert.All(responses, r => Assert.Equal(HttpStatusCode.Created, r.StatusCode));
            var bodies = await Task.WhenAll(responses.Select(r => r.Content.ReadAsStringAsync()));
            original = Assert.Single(bodies.Distinct());
            Assert.Single(responses.Select(r => r.Headers.Location?.ToString()).Distinct());
        }
        finally { foreach (var response in responses) response.Dispose(); }
        // JSON order/case of GUID text is irrelevant after DTO canonicalization.
        using var canonicalReplay = await Send(client, "/reservations", new
        { authority = Authority, attemptId = attempt.ToString("D").ToUpperInvariant(), quantity = 1, locationId = LocationId, variantId = VariantId }, key);
        Assert.Equal(HttpStatusCode.Created, canonicalReplay.StatusCode);
        Assert.Equal(original, await canonicalReplay.Content.ReadAsStringAsync());
        using var changedPayload = await Reserve(client, attempt, key, 2);
        await AssertError(changedPayload, HttpStatusCode.Conflict, "idempotency_conflict");
        using var conflict = await Reserve(client, Guid.NewGuid(), key, 2);
        await AssertError(conflict, HttpStatusCode.Conflict, "idempotency_conflict");
        using var rebindAttempt = await Reserve(client, attempt, "v2-other-key-001");
        await AssertError(rebindAttempt, HttpStatusCode.Conflict, "attempt_conflict");
        await AssertBalances(database, 5, 1);
        await using var db = database.Context();
        Assert.Single(await db.SaviaReservations.ToListAsync());
        Assert.Single(await db.SaviaAttempts.ToListAsync());
    }

    [SqlServerFact]
    public async Task Repeated_and_concurrent_cancellation_releases_once_without_changing_on_hand()
    {
        await using var database = await Database();
        await using var factory = new TestApiFactory(connection: database.Connection);
        using var client = factory.CreateClient();
        using var created = await Reserve(client, Guid.NewGuid(), "v2-cancel-create-001", 2);
        var id = (await Read(created, HttpStatusCode.Created)).GetProperty("reservationId").GetGuid();
        var attempts = Enumerable.Range(0, 20).Select(i => (Id: Guid.NewGuid(), Key: $"v2-cancel-race-{i:D3}")).ToArray();
        var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var tasks = attempts.Select(async a => { await start.Task; return await Cancel(client, id, a.Id, a.Key); }).ToArray();
        start.SetResult();
        var responses = await Task.WhenAll(tasks);
        try
        {
            var bodies = await Task.WhenAll(responses.Select(async r => await Read(r, HttpStatusCode.OK)));
            Assert.Equal(2, bodies.Sum(b => b.GetProperty("releasedQuantity").GetInt32()));
            var winner = Assert.Single(Enumerable.Range(0, bodies.Length), i => bodies[i].GetProperty("releasedQuantity").GetInt32() == 2);
            Assert.Equal(19, bodies.Count(b => b.GetProperty("status").GetString() == "already_cancelled"));
            using var replay = await Cancel(client, id, attempts[winner].Id, attempts[winner].Key);
            Assert.Equal(await responses[winner].Content.ReadAsStringAsync(), await replay.Content.ReadAsStringAsync());
        }
        finally { foreach (var response in responses) response.Dispose(); }
        await AssertBalances(database, 5, 0);
        await using var db = database.Context();
        Assert.Equal("cancelled", (await db.SaviaReservations.SingleAsync()).State);
        Assert.Equal(2, await db.SaviaMovements.CountAsync());
        Assert.Single(await db.SaviaMovements.Where(x => x.Kind == "cancel").ToListAsync());
        Assert.Equal(21, await db.SaviaAttempts.CountAsync());
    }

    [SqlServerFact]
    public async Task Failed_reservation_movement_rolls_back_balance_reservation_and_attempt()
    {
        await using var database = await Database();
        await using (var db = database.Context())
            await db.Database.ExecuteSqlRawAsync("ALTER TABLE [SaviaMovements] ADD CONSTRAINT [CK_Test_SaviaReserveRollback] CHECK ([ReservedDelta] <= 0)");
        await using var factory = new TestApiFactory(connection: database.Connection);
        using var client = factory.CreateClient();
        var attempt = Guid.NewGuid();
        using var failed = await Reserve(client, attempt, "v2-reserve-rollback-001");
        await AssertError(failed, HttpStatusCode.ServiceUnavailable, "storage_unavailable");
        await AssertBalances(database, 5, 0);
        await using (var db = database.Context())
        {
            Assert.Empty(await db.SaviaReservations.ToListAsync());
            Assert.Empty(await db.SaviaAttempts.ToListAsync());
            await db.Database.ExecuteSqlRawAsync("ALTER TABLE [SaviaMovements] DROP CONSTRAINT [CK_Test_SaviaReserveRollback]");
        }
        using var retry = await Reserve(client, attempt, "v2-reserve-rollback-001");
        await Read(retry, HttpStatusCode.Created);
        await AssertBalances(database, 5, 1);
    }

    [SqlServerFact]
    public async Task Failed_cancellation_movement_rolls_back_release_state_and_attempt()
    {
        await using var database = await Database();
        await using var factory = new TestApiFactory(connection: database.Connection);
        using var client = factory.CreateClient();
        using var created = await Reserve(client, Guid.NewGuid(), "v2-cancel-rollback-create");
        var id = (await Read(created, HttpStatusCode.Created)).GetProperty("reservationId").GetGuid();
        await using (var db = database.Context())
            await db.Database.ExecuteSqlRawAsync("ALTER TABLE [SaviaMovements] ADD CONSTRAINT [CK_Test_SaviaCancelRollback] CHECK ([ReservedDelta] >= 0)");
        var attempt = Guid.NewGuid();
        using var failed = await Cancel(client, id, attempt, "v2-cancel-rollback-001");
        await AssertError(failed, HttpStatusCode.ServiceUnavailable, "storage_unavailable");
        await AssertBalances(database, 5, 1);
        await using (var db = database.Context())
        {
            var reservation = await db.SaviaReservations.SingleAsync();
            Assert.Equal("active", reservation.State);
            Assert.Null(reservation.CancelledAt);
            Assert.Single(await db.SaviaAttempts.ToListAsync());
            Assert.Single(await db.SaviaMovements.ToListAsync());
            await db.Database.ExecuteSqlRawAsync("ALTER TABLE [SaviaMovements] DROP CONSTRAINT [CK_Test_SaviaCancelRollback]");
        }
        using var retry = await Cancel(client, id, attempt, "v2-cancel-rollback-001");
        Assert.Equal(1, (await Read(retry, HttpStatusCode.OK)).GetProperty("releasedQuantity").GetInt32());
        await AssertBalances(database, 5, 0);
    }

    [SqlServerFact]
    public async Task Creation_replay_is_original_after_cancellation_while_get_is_current()
    {
        await using var database = await Database();
        await using var factory = new TestApiFactory(connection: database.Connection);
        using var client = factory.CreateClient();
        var attempt = Guid.NewGuid();
        using var created = await Reserve(client, attempt, "v2-original-receipt-001");
        var original = await created.Content.ReadAsStringAsync();
        var receipt = await Read(created, HttpStatusCode.Created);
        var id = receipt.GetProperty("reservationId").GetGuid();
        using var cancelled = await Cancel(client, id, Guid.NewGuid(), "v2-original-cancel-001");
        await Read(cancelled, HttpStatusCode.OK);
        using var replay = await Reserve(client, attempt, "v2-original-receipt-001");
        Assert.Equal(HttpStatusCode.Created, replay.StatusCode);
        Assert.Equal(original, await replay.Content.ReadAsStringAsync());
        var view = await Get(client, $"/reservations/{id}");
        Assert.Equal("cancelled", view.GetProperty("status").GetString());
        Assert.NotEqual(JsonValueKind.Null, view.GetProperty("cancelledAt").ValueKind);
        Assert.Equal(receipt.GetRawText(), view.GetProperty("creation").GetRawText());
        Assert.Equal("active", view.GetProperty("creation").GetProperty("status").GetString());
        await AssertBalances(database, 5, 0);
    }

    [SqlServerFact]
    public async Task Lost_response_after_commit_is_recovered_by_lookup_and_stable_retry()
    {
        await using var database = await Database();
        await using var factory = new TestApiFactory(connection: database.Connection);
        using var client = factory.CreateClient();
        var attempt = Guid.NewGuid();
        // Dispose a completed response unread: the client no longer has the receipt after SQL committed.
        using (var lost = await Reserve(client, attempt, "v2-lost-create-001"))
            Assert.Equal(HttpStatusCode.Created, lost.StatusCode);
        var lookup = await Get(client, $"/attempts/reserve/{attempt}");
        Assert.Equal("succeeded", lookup.GetProperty("outcome").GetString());
        Assert.Equal(attempt, lookup.GetProperty("attemptId").GetGuid());
        AssertAuthority(lookup.GetProperty("authority"));
        using var retry = await Reserve(client, attempt, "v2-lost-create-001");
        Assert.Equal(lookup.GetProperty("result").GetRawText(), (await Read(retry, HttpStatusCode.Created)).GetRawText());
        var id = lookup.GetProperty("result").GetProperty("reservationId").GetGuid();
        var cancelAttempt = Guid.NewGuid();
        using (var lost = await Cancel(client, id, cancelAttempt, "v2-lost-cancel-001"))
            Assert.Equal(HttpStatusCode.OK, lost.StatusCode);
        var cancelLookup = await Get(client, $"/attempts/cancel/{cancelAttempt}");
        using var cancelRetry = await Cancel(client, id, cancelAttempt, "v2-lost-cancel-001");
        Assert.Equal(cancelLookup.GetProperty("result").GetRawText(), (await Read(cancelRetry, HttpStatusCode.OK)).GetRawText());
        using var missing = await client.GetAsync(Prefix + $"/attempts/reserve/{Guid.NewGuid()}");
        await AssertError(missing, HttpStatusCode.NotFound, "attempt_unknown");
        await AssertBalances(database, 5, 0);
        await using var db = database.Context();
        Assert.Equal(2, await db.SaviaAttempts.CountAsync());
        Assert.Equal(2, await db.SaviaMovements.CountAsync());
    }

    [SqlServerFact]
    public async Task Authority_mismatch_cannot_mutate_or_rewrite_persisted_authority()
    {
        await using var database = await Database();
        await using var factory = new TestApiFactory(connection: database.Connection);
        using var client = factory.CreateClient();
        var attempt = Guid.NewGuid();
        using var created = await Reserve(client, attempt, "v2-authority-create-001");
        var receipt = await Read(created, HttpStatusCode.Created);
        var id = receipt.GetProperty("reservationId").GetGuid();
        var mismatch = new { mode = "savia", instanceId = "another-instance", epoch = 2 };
        using var rejected = await Send(client, $"/reservations/{id}/cancel", new { attemptId = Guid.NewGuid(), authority = mismatch }, "v2-authority-cancel-001");
        await AssertError(rejected, HttpStatusCode.Conflict, "authority_mismatch");
        var lookup = await Get(client, $"/attempts/reserve/{attempt}");
        AssertAuthority(lookup.GetProperty("authority"));
        Assert.Equal(receipt.GetRawText(), lookup.GetProperty("result").GetRawText());
        await using (var db = database.Context())
        {
            var persisted = await db.SaviaAttempts.SingleAsync();
            persisted.Epoch = 2;
            await Assert.ThrowsAsync<InvalidOperationException>(() => db.SaveChangesAsync());
        }
        await using (var db = database.Context())
        {
            var movement = await db.SaviaMovements.SingleAsync();
            movement.InstanceId = "rewritten-authority";
            await Assert.ThrowsAsync<InvalidOperationException>(() => db.SaveChangesAsync());
        }
        await using (var db = database.Context())
        {
            var persisted = await db.SaviaAttempts.AsNoTracking().SingleAsync();
            Assert.Equal(1, persisted.Epoch);
            Assert.Equal("savia-synthetic-v2", persisted.InstanceId);
            Assert.Equal("savia", persisted.Mode);
            Assert.Equal("savia-synthetic-v2", (await db.SaviaMovements.AsNoTracking().SingleAsync()).InstanceId);
        }
        await AssertBalances(database, 5, 1);
    }

    [SqlServerFact]
    public async Task Repeating_seed_preserves_reserved_and_released_balances_and_ledger()
    {
        await using var database = await Database();
        await using var factory = new TestApiFactory(connection: database.Connection);
        using var client = factory.CreateClient();
        using var created = await Reserve(client, Guid.NewGuid(), "v2-seed-repeat-create", 3);
        var id = (await Read(created, HttpStatusCode.Created)).GetProperty("reservationId").GetGuid();
        await using (var db = database.Context()) { await SaviaSyntheticSeed.Apply(db); await SaviaSyntheticSeed.Apply(db); }
        await AssertBalances(database, 5, 3);
        using var cancelled = await Cancel(client, id, Guid.NewGuid(), "v2-seed-repeat-cancel");
        await Read(cancelled, HttpStatusCode.OK);
        await using (var db = database.Context()) { await SaviaSyntheticSeed.Apply(db); await SaviaSyntheticSeed.Apply(db); }
        await AssertBalances(database, 5, 0);
        await using var final = database.Context();
        Assert.Single(await final.SaviaBalances.ToListAsync());
        Assert.Single(await final.SaviaReservations.ToListAsync());
        Assert.Equal(2, await final.SaviaAttempts.CountAsync());
        Assert.Equal(2, await final.SaviaMovements.CountAsync());
    }

    [SqlServerFact]
    public async Task Partial_or_inconsistent_seed_is_rejected_without_replenishment()
    {
        await using var database = await Database();
        await using var factory = new TestApiFactory(connection: database.Connection);
        using var client = factory.CreateClient();
        using var created = await Reserve(client, Guid.NewGuid(), "v2-seed-corrupt-create");
        await Read(created, HttpStatusCode.Created);
        string originalSku;
        await using (var db = database.Context())
        {
            originalSku = (await db.SaviaBalances.AsNoTracking().SingleAsync()).Sku;
            await db.SaviaBalances.ExecuteUpdateAsync(s => s.SetProperty(x => x.Sku, "CORRUPT-SYNTHETIC-FIXTURE"));
            await Assert.ThrowsAsync<InvalidOperationException>(() => SaviaSyntheticSeed.Apply(db));
        }
        await using (var db = database.Context())
        {
            Assert.Equal("CORRUPT-SYNTHETIC-FIXTURE", (await db.SaviaBalances.AsNoTracking().SingleAsync()).Sku);
            await db.SaviaBalances.ExecuteUpdateAsync(s => s.SetProperty(x => x.Sku, originalSku));
            // Deliberate test-only partial fixture: retain reservation/attempt/balance, remove its ledger.
            await db.SaviaMovements.ExecuteDeleteAsync();
            await Assert.ThrowsAsync<InvalidOperationException>(() => SaviaSyntheticSeed.Apply(db));
        }
        await using var final = database.Context();
        Assert.Equal(5, (await final.SaviaBalances.AsNoTracking().SingleAsync()).OnHand);
        Assert.Equal(1, (await final.SaviaBalances.AsNoTracking().SingleAsync()).Reserved);
        Assert.Single(await final.SaviaReservations.ToListAsync());
        Assert.Single(await final.SaviaAttempts.ToListAsync());
        Assert.Empty(await final.SaviaMovements.ToListAsync());
    }

    [SqlServerFact]
    public async Task Movement_ledger_reconciles_balances_and_reservation_states()
    {
        await using var database = await Database();
        await using var factory = new TestApiFactory(connection: database.Connection);
        using var client = factory.CreateClient();
        var ids = new List<Guid>();
        for (var i = 0; i < 5; i++)
        {
            using var created = await Reserve(client, Guid.NewGuid(), $"v2-reconcile-create-{i:D3}");
            ids.Add((await Read(created, HttpStatusCode.Created)).GetProperty("reservationId").GetGuid());
        }
        foreach (var id in ids.Take(3))
        {
            using var cancelled = await Cancel(client, id, Guid.NewGuid(), $"v2-reconcile-cancel-{id:N}");
            await Read(cancelled, HttpStatusCode.OK);
        }
        await AssertBalances(database, 5, 2);
        var catalog = await Get(client, "/catalog");
        var item = Assert.Single(catalog.GetProperty("items").EnumerateArray());
        Assert.Equal(3, item.GetProperty("available").GetInt32());
        Assert.Equal(2, item.GetProperty("reserved").GetInt32());
        Assert.Equal(5, item.GetProperty("onHand").GetInt32());
        AssertAuthority(item.GetProperty("authority"));
        var ledger = await Get(client, "/movements");
        Assert.Equal(8, ledger.GetProperty("items").GetArrayLength());
        await using var db = database.Context();
        var movements = await db.SaviaMovements.AsNoTracking().ToListAsync();
        foreach (var reservation in await db.SaviaReservations.AsNoTracking().ToListAsync())
            Assert.Equal(reservation.State == "active" ? reservation.Quantity : 0, movements.Where(m => m.ReservationId == reservation.Id).Sum(m => m.ReservedDelta));
        var attempts = await db.SaviaAttempts.AsNoTracking().ToListAsync();
        Assert.All(movements, m => Assert.Contains(attempts, a => a.AttemptId == m.AttemptId && a.Outcome == "succeeded"));
        Assert.Equal(movements.Count, movements.Select(m => m.Id).Distinct().Count());
        await SaviaSyntheticSeed.Apply(db); // Reconciliation must also satisfy the seed's consistency guard.
    }

    [SqlServerFact]
    public async Task Durable_rejection_replays_after_availability_changes_and_attempt_conflicts()
    {
        await using var database = await Database(1);
        await using var factory = new TestApiFactory(connection: database.Connection);
        using var client = factory.CreateClient();
        using var first = await Reserve(client, Guid.NewGuid(), "v2-rejection-winner-001");
        var id = (await Read(first, HttpStatusCode.Created)).GetProperty("reservationId").GetGuid();
        var attempt = Guid.NewGuid();
        using var rejected = await Reserve(client, attempt, "v2-rejected-attempt-001");
        await AssertError(rejected, HttpStatusCode.Conflict, "out_of_stock");
        var lookupBefore = await Get(client, $"/attempts/reserve/{attempt}");
        Assert.Equal("rejected", lookupBefore.GetProperty("outcome").GetString());
        Assert.Equal("out_of_stock", lookupBefore.GetProperty("error").GetString());
        Assert.Equal(JsonValueKind.Null, lookupBefore.GetProperty("result").ValueKind);
        using var cancelled = await Cancel(client, id, Guid.NewGuid(), "v2-rejection-release-001");
        await Read(cancelled, HttpStatusCode.OK);
        using var retry = await Reserve(client, attempt, "v2-rejected-attempt-001");
        await AssertError(retry, HttpStatusCode.Conflict, "out_of_stock");
        var lookupAfter = await Get(client, $"/attempts/reserve/{attempt}");
        Assert.Equal(lookupBefore.GetRawText(), lookupAfter.GetRawText());
        using var conflict = await Reserve(client, attempt, "v2-rebound-attempt-001");
        await AssertError(conflict, HttpStatusCode.Conflict, "attempt_conflict");
        using var crossOperation = await Cancel(client, id, attempt, "v2-rejected-attempt-001");
        await AssertError(crossOperation, HttpStatusCode.Conflict, "attempt_conflict");
        await AssertBalances(database, 1, 0);
        await using var db = database.Context();
        Assert.Equal(3, await db.SaviaAttempts.CountAsync());
        Assert.Single(await db.SaviaReservations.ToListAsync());
        Assert.Equal(2, await db.SaviaMovements.CountAsync());
    }
}
