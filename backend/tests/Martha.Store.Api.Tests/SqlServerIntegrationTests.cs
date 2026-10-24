using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Martha.Store.Api;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Martha.Store.Api.Tests;

[Trait("Category", "SqlServer")]
public sealed class SqlServerIntegrationTests
{
    private static async Task<HttpResponseMessage> Order(HttpClient client, string key, int quantity = 1)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, "/api/v1/synthetic/orders")
        {
            Content = JsonContent.Create(new { variantId = SyntheticSeed.VariantId, quantity })
        };
        request.Headers.Add("Idempotency-Key", key);
        return await client.SendAsync(request);
    }

    [SqlServerFact]
    public async Task Migrated_database_exposes_only_synthetic_catalog_and_seed_is_non_replenishing()
    {
        await using var database = new SqlDatabase();
        await database.Initialize();
        await using var factory = new TestApiFactory(connection: database.Connection);
        using var client = factory.CreateClient();
        Assert.Equal(HttpStatusCode.OK, (await client.GetAsync("/health/ready")).StatusCode);
        var catalog = await client.GetFromJsonAsync<JsonElement>("/api/v1/catalog");
        Assert.True(catalog.GetProperty("synthetic").GetBoolean());
        var product = Assert.Single(catalog.GetProperty("items").EnumerateArray());
        Assert.Equal(SyntheticSeed.ProductId, product.GetProperty("productId").GetGuid());
        var variant = Assert.Single(product.GetProperty("variants").EnumerateArray());
        Assert.Equal("XXX", variant.GetProperty("currency").GetString());
        Assert.Equal(1250, variant.GetProperty("unitPriceMinor").GetInt64());
        Assert.Equal(1, variant.GetProperty("availableQuantity").GetInt32());
        using var response = await Order(client, "seed-repeat-001");
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        await using var db = database.Context();
        await SyntheticSeed.Apply(db);
        Assert.Equal(0, (await db.Variants.SingleAsync()).AvailableQuantity);
        Assert.Equal(1, await db.Products.CountAsync());
        Assert.Equal(1, await db.SyntheticOrders.CountAsync());
    }

    [SqlServerFact]
    public async Task Invalid_quantities_reject_without_any_persistent_change()
    {
        await using var database = new SqlDatabase();
        await database.Initialize();
        await using var factory = new TestApiFactory(connection: database.Connection);
        using var client = factory.CreateClient();
        foreach (var quantity in new[] { -1, 0, 101, int.MaxValue })
        {
            using var response = await Order(client, "invalid-quantity-" + quantity, quantity);
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
            Assert.Equal("invalid_request", (await response.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString());
        }
        await using var db = database.Context();
        Assert.Equal(1, (await db.Variants.SingleAsync()).AvailableQuantity);
        Assert.Empty(await db.SyntheticOrders.ToListAsync());
    }

    [SqlServerFact]
    public async Task Client_supplied_price_total_and_customer_fields_are_rejected_without_mutation()
    {
        await using var database = new SqlDatabase();
        await database.Initialize();
        await using var factory = new TestApiFactory(connection: database.Connection);
        using var client = factory.CreateClient();
        foreach (var extra in new[] { "unitPriceMinor", "totalMinor", "customer" })
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, "/api/v1/synthetic/orders");
            request.Headers.Add("Idempotency-Key", "reject-extra-" + extra);
            request.Content = JsonContent.Create(new Dictionary<string, object>
            {
                ["variantId"] = SyntheticSeed.VariantId, ["quantity"] = 1, [extra] = 0
            });
            using var response = await client.SendAsync(request);
            Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        }
        await using var db = database.Context();
        Assert.Equal(1, (await db.Variants.SingleAsync()).AvailableQuantity);
        Assert.Empty(await db.SyntheticOrders.ToListAsync());
    }

    [SqlServerFact]
    public async Task Twenty_distinct_requests_for_last_unit_have_exactly_one_winner()
    {
        await using var database = new SqlDatabase();
        await database.Initialize();
        await using var factory = new TestApiFactory(connection: database.Connection);
        using var client = factory.CreateClient();
        var start = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var tasks = Enumerable.Range(0, 20).Select(async i => { await start.Task; return await Order(client, $"last-unit-{i:D3}"); }).ToArray();
        start.SetResult();
        var responses = await Task.WhenAll(tasks);
        try
        {
            Assert.Single(responses, r => r.StatusCode == HttpStatusCode.Created);
            Assert.Equal(19, responses.Count(r => r.StatusCode == HttpStatusCode.Conflict));
            foreach (var loser in responses.Where(r => r.StatusCode == HttpStatusCode.Conflict))
                Assert.Equal("out_of_stock", (await loser.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString());
        }
        finally { foreach (var response in responses) response.Dispose(); }
        await using var db = database.Context();
        Assert.Equal(0, (await db.Variants.SingleAsync()).AvailableQuantity);
        var order = Assert.Single(await db.SyntheticOrders.ToListAsync());
        Assert.Equal(1, order.Quantity);
        Assert.Equal(1250, order.TotalMinor);
    }

    [SqlServerFact]
    public async Task Concurrent_same_key_replays_exact_response_and_conflicting_payload_is_409()
    {
        await using var database = new SqlDatabase();
        await database.Initialize();
        await using var factory = new TestApiFactory(connection: database.Connection);
        using var client = factory.CreateClient();
        const string key = "same-request-key-001";
        var responses = await Task.WhenAll(Enumerable.Range(0, 20).Select(_ => Order(client, key)));
        try
        {
            Assert.All(responses, response => Assert.Equal(HttpStatusCode.Created, response.StatusCode));
            var bodies = await Task.WhenAll(responses.Select(r => r.Content.ReadAsStringAsync()));
            Assert.Single(bodies.Distinct());
            var result = JsonSerializer.Deserialize<JsonElement>(bodies[0]);
            var fetched = await client.GetAsync($"/api/v1/synthetic/orders/{result.GetProperty("orderId").GetGuid()}");
            Assert.Equal(HttpStatusCode.OK, fetched.StatusCode);
            Assert.Equal(bodies[0], await fetched.Content.ReadAsStringAsync());
        }
        finally { foreach (var response in responses) response.Dispose(); }
        using var conflict = await Order(client, key, 2);
        Assert.Equal(HttpStatusCode.Conflict, conflict.StatusCode);
        Assert.Equal("idempotency_conflict", (await conflict.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString());
        await using var db = database.Context();
        Assert.Equal(0, (await db.Variants.SingleAsync()).AvailableQuantity);
        Assert.Single(await db.SyntheticOrders.ToListAsync());
    }

    [SqlServerFact]
    public async Task Failed_insert_rolls_back_stock_and_leaves_no_order_or_idempotency_fragment()
    {
        await using var database = new SqlDatabase();
        await database.Initialize();
        await using (var db = database.Context())
        {
            // CHECK rejects the insert after the application's conditional stock decrement.
            // No production test hooks and no trigger/OUTPUT compatibility false positive.
            await db.Database.ExecuteSqlRawAsync("ALTER TABLE [SyntheticOrders] ADD CONSTRAINT [CK_Test_ForceRollback] CHECK ([Quantity] < 0)");
        }
        await using var factory = new TestApiFactory(connection: database.Connection);
        using var client = factory.CreateClient();
        using var failed = await Order(client, "rollback-retry-001");
        Assert.Equal(HttpStatusCode.ServiceUnavailable, failed.StatusCode);
        Assert.Equal("storage_unavailable", (await failed.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("code").GetString());
        await using (var db = database.Context())
        {
            Assert.Equal(1, (await db.Variants.SingleAsync()).AvailableQuantity);
            Assert.Empty(await db.SyntheticOrders.ToListAsync());
            await db.Database.ExecuteSqlRawAsync("ALTER TABLE [SyntheticOrders] DROP CONSTRAINT [CK_Test_ForceRollback]");
        }
        using var retry = await Order(client, "rollback-retry-001");
        Assert.Equal(HttpStatusCode.Created, retry.StatusCode);
        await using var final = database.Context();
        Assert.Equal(0, (await final.Variants.SingleAsync()).AvailableQuantity);
        Assert.Single(await final.SyntheticOrders.ToListAsync());
    }
}
