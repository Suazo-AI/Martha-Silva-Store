using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Text.Json.Nodes;
using Savia.Application;

namespace Savia.Tests;

/// <summary>P9 hub endpoints over real HTTP and real SQL: node authentication, A-04 duplicates and row ownership.</summary>
public sealed class SyncTransportTests
{
    [Fact]
    public async Task Hub_refuses_a_call_without_a_valid_node_credential()
    {
        await using var f = await SyncFixture.CreateAsync();
        var client = f.Cloud.CreateClient();
        await HttpAssert.ProblemAsync(await client.GetAsync("/sync/v1/state"), HttpStatusCode.Unauthorized, "sync.unauthorized");
        foreach (var header in new[]
                 {
                     new AuthenticationHeaderValue("Bearer", "x"),
                     new AuthenticationHeaderValue(NodeCredential.Scheme, NodeCredential.Header(Ids.NodeA, "wrong-secret")),
                     new AuthenticationHeaderValue(NodeCredential.Scheme, NodeCredential.Header(Ids.NodeC, SyncFixture.SecretA)),
                     new AuthenticationHeaderValue(NodeCredential.Scheme, NodeCredential.Header(Ids.NodeB, SyncFixture.SecretA)),
                     new AuthenticationHeaderValue(NodeCredential.Scheme, "not-a-guid." + SyncFixture.SecretA),
                 })
        {
            client.DefaultRequestHeaders.Authorization = header;
            await HttpAssert.ProblemAsync(await client.GetAsync("/sync/v1/state"), HttpStatusCode.Unauthorized, "sync.unauthorized");
        }

        // A revoked credential stops working at once.
        await SyncFixture.ExecAsync(f.CloudDb, $"EXEC sync.usp_RevokeNodeCredential @NodeId='{Ids.NodeB}';");
        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue(NodeCredential.Scheme, NodeCredential.Header(Ids.NodeB, SyncFixture.SecretB));
        await HttpAssert.ProblemAsync(await client.GetAsync("/sync/v1/state"), HttpStatusCode.Unauthorized, "sync.unauthorized");

        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue(NodeCredential.Scheme, NodeCredential.Header(Ids.NodeA, SyncFixture.SecretA));
        var state = await client.GetAsync("/sync/v1/state");
        Assert.Equal(HttpStatusCode.OK, state.StatusCode);
        using var doc = JsonDocument.Parse(await state.Content.ReadAsStringAsync());
        Assert.Equal(Ids.NodeCloud, doc.RootElement.GetProperty("node").GetGuid());

        // A branch node does not serve sync at all.
        var branchClient = f.Branch.CreateClient();
        branchClient.DefaultRequestHeaders.Authorization = client.DefaultRequestHeaders.Authorization;
        Assert.Equal(HttpStatusCode.NotFound, (await branchClient.GetAsync("/sync/v1/state")).StatusCode);
    }

    [Fact]
    public async Task Duplicate_push_changes_nothing()
    {
        await using var f = await SyncFixture.CreateAsync();
        var sale = await f.SellAsync();
        var first = await f.Round().RunOnceAsync(CancellationToken.None);
        Assert.True(first.Pushed > 0, "the first push carries the sale");
        Assert.Equal(1, await f.SaleCountAsync(f.CloudDb, sale));
        var lines = await f.CountAsync(f.CloudDb, "SELECT COUNT(*) FROM sales.SaleLines");

        // The same batch delivered again: accepted, every table skipped, no row written.
        var again = await f.PostAsync(SyncFixture.PushPath, f.LastPush, Ids.NodeA, SyncFixture.SecretA);
        var result = JsonNode.Parse(await again.Content.ReadAsStringAsync())!;
        Assert.Equal(HttpStatusCode.OK, again.StatusCode);
        Assert.Equal(0, (int)result["changed"]!);
        Assert.Equal(0, (int)result["applied"]!);
        Assert.Equal(1, await f.SaleCountAsync(f.CloudDb, sale));
        Assert.Equal(lines, await f.CountAsync(f.CloudDb, "SELECT COUNT(*) FROM sales.SaleLines"));
        await f.AssertConservationAsync();
    }

    [Fact]
    public async Task Hub_refuses_rows_owned_by_another_node()
    {
        await using var f = await SyncFixture.CreateAsync();
        await f.SellAsync();
        f.Faults.DropBefore = SyncFixture.PushPath;   // the worker reads its batch, but the hub never gets it
        await Assert.ThrowsAsync<HttpRequestException>(() => f.Round().RunOnceAsync(CancellationToken.None));
        var batch = f.LastPush;

        // Node B presents A's batch.
        await HttpAssert.ProblemAsync(await f.PostAsync(SyncFixture.PushPath, batch, Ids.NodeB, SyncFixture.SecretB),
            HttpStatusCode.Forbidden, "sync.wrong_peer");

        // A claims a stock balance at B's location.
        var forged = JsonNode.Parse(batch)!;
        var balances = forged["tables"]!.AsArray().Single(t => (string)t!["t"]! == "[inventory].[StockBalances]")!.DeepClone();
        forged["tables"] = new JsonArray(balances);
        var json = forged.ToJsonString().Replace(Ids.LocA.ToString(), Ids.LocB.ToString(), StringComparison.OrdinalIgnoreCase);
        await HttpAssert.ProblemAsync(await f.PostAsync(SyncFixture.PushPath, json, Ids.NodeA, SyncFixture.SecretA),
            HttpStatusCode.Forbidden, "sync.foreign_row");
        Assert.Equal(0, await f.CountAsync(f.CloudDb, $"SELECT COUNT(*) FROM sync.PeerCursors WHERE PeerNodeId='{Ids.NodeA}'"));

        // The refusals moved nothing: the honest batch still applies in full.
        var honest = await f.PostAsync(SyncFixture.PushPath, batch, Ids.NodeA, SyncFixture.SecretA);
        Assert.Equal(HttpStatusCode.OK, honest.StatusCode);
        Assert.True((int)JsonNode.Parse(await honest.Content.ReadAsStringAsync())!["changed"]! > 0);
        await f.AssertConservationAsync();
    }
}
