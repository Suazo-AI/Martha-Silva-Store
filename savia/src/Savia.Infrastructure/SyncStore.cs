using System.Data;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using Microsoft.Data.SqlClient;
using Savia.Application;
using Savia.Contracts;
using Savia.Domain;
using static Savia.Infrastructure.SqlGateway;

namespace Savia.Infrastructure;

/// <summary>The V032 procedures. JSON goes in and comes out as text; no row is parsed here.</summary>
public sealed class SyncStore(SqlGateway sql) : ISyncStore
{
    // A rebuild carries every synced row; it may take longer than an interactive call.
    private const int BatchTimeoutSeconds = 300;

    public Task EnsureLocalNodeAsync(Guid nodeId, CancellationToken ct) =>
        sql.ExecProcAsync("sync.usp_SetLocalNode", ct, P("@NodeId", nodeId));

    public Task<string> SourceStateAsync(CancellationToken ct) => JsonOutAsync("sync.usp_SourceStateJson", ct);

    public Task<string> PlanAsync(Guid peer, string stateJson, bool rebuild, CancellationToken ct) =>
        JsonOutAsync("sync.usp_PlanJson", ct, P("@PeerNodeId", peer), Text("@StateJson", stateJson),
            new SqlParameter("@Mode", SqlDbType.VarChar, 10) { Value = rebuild ? "rebuild" : "normal" });

    public Task<string> ReadBatchAsync(Guid target, string planJson, Guid? targetFork, CancellationToken ct) =>
        JsonOutAsync("sync.usp_ReadBatch", ct, P("@TargetNodeId", target), Text("@PlanJson", planJson), P("@TargetForkGuid", targetFork));

    public Task<string> ApplyBatchAsync(Guid peer, string batchJson, CancellationToken ct) =>
        JsonOutAsync("sync.usp_ApplyBatch", ct, P("@PeerNodeId", peer), Text("@BatchJson", batchJson));

    public async Task<byte[]?> CredentialHashAsync(Guid nodeId, CancellationToken ct) =>
        (await sql.QueryProcAsync("sync.usp_GetNodeCredential", r => (byte[])r[0], ct, P("@NodeId", nodeId))).FirstOrDefault();

    private static SqlParameter Text(string name, string value) => new(name, SqlDbType.NVarChar, -1) { Value = value };

    private async Task<string> JsonOutAsync(string procedure, CancellationToken ct, params SqlParameter[] inputs)
    {
        var output = new SqlParameter("@Json", SqlDbType.NVarChar, -1) { Direction = ParameterDirection.Output };
        await sql.RunAsync(procedure, CommandType.StoredProcedure, [.. inputs, output], async cmd =>
        {
            cmd.CommandTimeout = BatchTimeoutSeconds;
            return await cmd.ExecuteNonQueryAsync(ct);
        }, ct);
        return output.Value as string ?? throw new SaviaException(Errors.SyncMalformed);
    }
}

/// <summary>
/// The hub over HTTP, for the branch worker. Every call carries the node credential.
/// A refusal comes back as the hub's <see cref="ProblemResponse"/> and is raised again with the same code.
/// </summary>
public sealed class HttpSyncHub(HttpClient http, Guid nodeId, string secret) : ISyncHub
{
    public Task<string> StateAsync(CancellationToken ct) => SendAsync(HttpMethod.Get, "sync/v1/state", null, ct);

    public Task<string> PushPlanAsync(string stateJson, CancellationToken ct) => SendAsync(HttpMethod.Post, "sync/v1/push/plan", stateJson, ct);

    public Task<string> PushAsync(string batchJson, CancellationToken ct) => SendAsync(HttpMethod.Post, "sync/v1/push", batchJson, ct);

    public Task<string> PullAsync(string planJson, Guid? fork, CancellationToken ct)
    {
        var forkJson = fork is { } f ? $"\"{f:D}\"" : "null";
        return SendAsync(HttpMethod.Post, "sync/v1/pull", $"{{\"plan\":{planJson},\"fork\":{forkJson}}}", ct);
    }

    private async Task<string> SendAsync(HttpMethod method, string path, string? body, CancellationToken ct)
    {
        using var request = new HttpRequestMessage(method, path);
        request.Headers.Authorization = new AuthenticationHeaderValue(NodeCredential.Scheme, NodeCredential.Header(nodeId, secret));
        if (body is not null) request.Content = new StringContent(body, Encoding.UTF8, "application/json");
        using var response = await http.SendAsync(request, ct);
        if (response.IsSuccessStatusCode) return await response.Content.ReadAsStringAsync(ct);
        ProblemResponse? problem = null;
        try
        {
            problem = await response.Content.ReadFromJsonAsync<ProblemResponse>(ct);
        }
        catch (Exception ex) when (ex is System.Text.Json.JsonException or NotSupportedException)
        {
            // Not a SAVIA answer (a proxy page, for example); the status alone decides.
        }
        throw new SaviaException(new SaviaError(problem?.Code ?? "sync.hub_error", KindOf(response.StatusCode),
            problem?.Message ?? $"El hub respondió {(int)response.StatusCode}."));
    }

    private static ErrorKind KindOf(HttpStatusCode status) => status switch
    {
        HttpStatusCode.UnprocessableEntity or HttpStatusCode.BadRequest => ErrorKind.Validation,
        HttpStatusCode.Unauthorized => ErrorKind.Unauthorized,
        HttpStatusCode.Forbidden => ErrorKind.Forbidden,
        HttpStatusCode.NotFound => ErrorKind.NotFound,
        HttpStatusCode.Conflict => ErrorKind.Conflict,
        HttpStatusCode.ServiceUnavailable => ErrorKind.Unavailable,
        _ => ErrorKind.Internal,
    };
}
