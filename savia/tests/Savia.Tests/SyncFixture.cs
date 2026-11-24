using System.Net.Http.Headers;
using System.Text;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.DependencyInjection;
using Savia.Application;
using Savia.Infrastructure;

namespace Savia.Tests;

/// <summary>
/// A hub and branch A, each in memory over its own cloned database, joined by real HTTP through the test server.
/// The hub holds credentials for nodes A and B. <see cref="Faults"/> sits between the branch worker and the hub.
/// </summary>
public sealed class SyncFixture : IAsyncDisposable
{
    public const string SecretA = "sync-test-secret-node-a";   // test values, not credentials of any real system
    public const string SecretB = "sync-test-secret-node-b";
    public const string PushPath = "/sync/v1/push";

    public required string CloudDb { get; init; }
    public required string BranchDb { get; init; }
    public required SaviaNode Cloud { get; init; }
    public required SaviaNode Branch { get; init; }
    public FaultHandler Faults { get; } = new();

    public static async Task<SyncFixture> CreateAsync()
    {
        var cloudDb = await TestSql.CloneAsync("synchub");
        var branchDb = await TestSql.CloneAsync("synca");
        await ExecAsync(cloudDb, $"""
            EXEC sync.usp_SetNodeCredential @NodeId='{Ids.NodeA}',@SecretHash=0x{Convert.ToHexString(NodeCredential.Hash(SecretA))};
            EXEC sync.usp_SetNodeCredential @NodeId='{Ids.NodeB}',@SecretHash=0x{Convert.ToHexString(NodeCredential.Hash(SecretB))};
            """);
        return new SyncFixture { CloudDb = cloudDb, BranchDb = branchDb, Cloud = SaviaNode.Cloud(cloudDb), Branch = SaviaNode.BranchA(branchDb) };
    }

    private HttpClient? hubClient;

    /// <summary>The production branch round, talking to the in-memory hub through <see cref="Faults"/>.</summary>
    /// <remarks>One client per fixture: a <see cref="DelegatingHandler"/> cannot be chained again once it has sent.</remarks>
    public BranchSync Round(SyncStatus? status = null) => new(Branch.Services.GetRequiredService<ISyncStore>(),
        new HttpSyncHub(hubClient ??= Cloud.CreateDefaultClient(Faults), Ids.NodeA, SecretA), Branch.Services.GetRequiredService<NodeContext>(), status);

    /// <summary>The last push body the worker sent (recorded even when the call was dropped).</summary>
    public string LastPush => Faults.Posts.Last(p => p.Path == PushPath).Body;

    /// <summary>Sends a raw sync call to the hub as the given node, as a replaying or hostile client would.</summary>
    public Task<HttpResponseMessage> PostAsync(string path, string body, Guid nodeId, string secret)
    {
        var client = Cloud.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(NodeCredential.Scheme, NodeCredential.Header(nodeId, secret));
        return client.PostAsync(path, new StringContent(body, Encoding.UTF8, "application/json"));
    }

    /// <summary>One cash sale at branch A, written on the branch database by the sale procedure.</summary>
    public async Task<Guid> SellAsync()
    {
        var sale = Guid.NewGuid();
        await ExecAsync(BranchDb, $"EXEC test.SeedSale '{sale}','A';");
        return sale;
    }

    public Task<int> CountAsync(string database, string sql) => TestSql.ScalarAsync<int>(database, sql);

    public Task<int> SaleCountAsync(string database, Guid sale) => CountAsync(database, $"SELECT COUNT(*) FROM sales.Sales WHERE Id='{sale}'");

    public async Task AssertConservationAsync()
    {
        await TestSql.AssertConservationAsync(CloudDb);
        await TestSql.AssertConservationAsync(BranchDb);
    }

    /// <summary>Every conservation violation on a database as <c>check key</c>, without throwing.</summary>
    public static async Task<List<string>> ViolationsAsync(string database)
    {
        await using var connection = new SqlConnection(TestSql.ConnectionFor(database));
        await connection.OpenAsync();
        await using var command = new SqlCommand("EXEC audit.usp_CheckConservation @Throw=0", connection);
        await using var reader = await command.ExecuteReaderAsync();
        var rows = new List<string>();
        do
        {
            rows.Clear();
            while (await reader.ReadAsync()) rows.Add($"{reader.GetString(0)} {reader.GetString(1)}");
        }
        while (await reader.NextResultAsync());   // the last result set is the violation list
        return rows;
    }

    public static async Task ExecAsync(string database, string sql)
    {
        await using var connection = new SqlConnection(TestSql.ConnectionFor(database));
        await connection.OpenAsync();
        await using var command = new SqlCommand(sql, connection) { CommandTimeout = 120 };
        await command.ExecuteNonQueryAsync();
    }

    public async ValueTask DisposeAsync()
    {
        hubClient?.Dispose();
        await Cloud.DisposeAsync();
        await Branch.DisposeAsync();
        SqlConnection.ClearAllPools();
        await TestSql.DropAsync(CloudDb);
        await TestSql.DropAsync(BranchDb);
    }
}

/// <summary>Records every POST and can drop one call before it reaches the hub, or lose the hub's answer after it.</summary>
public sealed class FaultHandler : DelegatingHandler
{
    public List<(string Path, string Body)> Posts { get; } = [];

    /// <summary>Next call to this path fails before the hub sees it.</summary>
    public string? DropBefore { get; set; }

    /// <summary>Calls to <see cref="DropBefore"/> that still reach the hub before the one that is dropped.</summary>
    public int PassBeforeDrop { get; set; }

    /// <summary>Next call to this path reaches the hub, which commits; then the answer is lost.</summary>
    public string? LoseAnswer { get; set; }

    /// <summary>Next call whose body contains this text reaches the hub; then the answer is lost.</summary>
    public string? LoseAnswerIfBodyHas { get; set; }

    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        var path = request.RequestUri!.AbsolutePath;
        var body = request.Content is null ? "" : await request.Content.ReadAsStringAsync(cancellationToken);
        if (request.Method == HttpMethod.Post) Posts.Add((path, body));
        if (LoseAnswerIfBodyHas is { } text && body.Contains(text, StringComparison.Ordinal))
        {
            LoseAnswerIfBodyHas = null;
            LoseAnswer = path;
        }
        if (path == DropBefore && PassBeforeDrop-- == 0)
        {
            (DropBefore, PassBeforeDrop) = (null, 0);
            throw new HttpRequestException("test: connection dropped before the hub received the call");
        }
        var response = await base.SendAsync(request, cancellationToken);
        if (path != LoseAnswer) return response;
        LoseAnswer = null;
        response.Dispose();
        throw new HttpRequestException("test: connection dropped after the hub answered");
    }
}
