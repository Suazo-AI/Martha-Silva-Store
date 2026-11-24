using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Savia.Domain;

namespace Savia.Application;

// P9 sync transport (docs/sync/P9-SPEC.md). Every sync rule lives in the V032 procedures (ADR-001 D5):
// planning, ownership, idempotency, gaps, forks and rebuilds. C# authenticates the node and moves JSON text.
// It never reads or rewrites a row.

/// <summary>The local database's side of sync. Every method is one V032 procedure; the JSON passes through unchanged.</summary>
public interface ISyncStore
{
    /// <summary>Binds the database to this node once (sync.usp_SetLocalNode). A database of another node is refused.</summary>
    Task EnsureLocalNodeAsync(Guid nodeId, CancellationToken ct);

    Task<string> SourceStateAsync(CancellationToken ct);

    Task<string> PlanAsync(Guid peer, string stateJson, bool rebuild, CancellationToken ct);

    Task<string> ReadBatchAsync(Guid target, string planJson, Guid? targetFork, CancellationToken ct);

    Task<string> ApplyBatchAsync(Guid peer, string batchJson, CancellationToken ct);

    /// <summary>SHA-256 of the node's secret, or null when the node has no active credential.</summary>
    Task<byte[]?> CredentialHashAsync(Guid nodeId, CancellationToken ct);
}

/// <summary>The hub as a branch sees it: the four sync calls over HTTP.</summary>
public interface ISyncHub
{
    Task<string> StateAsync(CancellationToken ct);

    Task<string> PushPlanAsync(string stateJson, CancellationToken ct);

    Task<string> PushAsync(string batchJson, CancellationToken ct);

    Task<string> PullAsync(string planJson, Guid? fork, CancellationToken ct);
}

/// <summary>Node credentials: <c>SaviaNode &lt;nodeId&gt;.&lt;secret&gt;</c>. Only the SHA-256 of the secret is stored.</summary>
public static class NodeCredential
{
    public const string Scheme = "SaviaNode";

    public static string Header(Guid nodeId, string secret) => $"{nodeId:D}.{secret}";

    public static byte[] Hash(string secret) => SHA256.HashData(Encoding.UTF8.GetBytes(secret));

    /// <summary>Splits the header value; null when it is not <c>SaviaNode &lt;guid&gt;.&lt;secret&gt;</c>.</summary>
    public static (Guid NodeId, string Secret)? Parse(string? authorization)
    {
        if (authorization is null || !authorization.StartsWith(Scheme + " ", StringComparison.Ordinal)) return null;
        var value = authorization[(Scheme.Length + 1)..].Trim();
        var dot = value.IndexOf('.');
        if (dot <= 0 || dot == value.Length - 1 || !Guid.TryParse(value[..dot], out var nodeId)) return null;
        return (nodeId, value[(dot + 1)..]);
    }
}

/// <summary>The hub's sync use cases. The caller's node comes from its credential only, never from the body.</summary>
public sealed class SyncHubService(ISyncStore store, NodeContext node)
{
    private volatile bool bound;

    public async Task<Guid> AuthenticateAsync(string? authorization, CancellationToken ct)
    {
        if (node.Kind != NodeKind.Cloud) throw new SaviaException(Errors.WrongNode);
        var parsed = NodeCredential.Parse(authorization) ?? throw new SaviaException(Errors.NodeUnauthorized);
        var stored = await store.CredentialHashAsync(parsed.NodeId, ct);
        var given = NodeCredential.Hash(parsed.Secret);
        if (stored is null || !CryptographicOperations.FixedTimeEquals(stored, given)) throw new SaviaException(Errors.NodeUnauthorized);
        await BindAsync(ct);
        return parsed.NodeId;
    }

    public Task<string> StateAsync(CancellationToken ct) => store.SourceStateAsync(ct);

    public Task<string> PushPlanAsync(Guid peer, string stateJson, CancellationToken ct) => store.PlanAsync(peer, stateJson, rebuild: false, ct);

    public Task<string> PushAsync(Guid peer, string batchJson, CancellationToken ct) => store.ApplyBatchAsync(peer, batchJson, ct);

    /// <summary>Body <c>{plan, fork}</c>. A rebuild plan needs the branch's current fork; the procedure checks it.</summary>
    public Task<string> PullAsync(Guid peer, string body, CancellationToken ct)
    {
        string plan;
        Guid? fork = null;
        try
        {
            using var doc = JsonDocument.Parse(body);
            plan = doc.RootElement.GetProperty("plan").GetRawText();
            if (doc.RootElement.TryGetProperty("fork", out var f) && f.ValueKind == JsonValueKind.String) fork = f.GetGuid();
        }
        catch (Exception ex) when (ex is JsonException or KeyNotFoundException or InvalidOperationException or FormatException)
        {
            throw new SaviaException(Errors.SyncMalformed, ex);
        }
        return store.ReadBatchAsync(peer, plan, fork, ct);
    }

    private async Task BindAsync(CancellationToken ct)
    {
        if (bound) return;
        await store.EnsureLocalNodeAsync(node.NodeId, ct);
        bound = true;
    }
}

/// <summary>What one branch round moved.</summary>
public sealed record SyncRound(int Pulled, int Pushed, bool Rebuilt);

/// <summary>A rebuild in progress: synced tables finished of all synced tables (D-036, D-041).</summary>
public sealed record SyncProgress(int Done, int Total);

/// <summary>
/// The branch's last sync round as the till shows it. Code is null after a round that worked.
/// Rebuild is set while a rebuild from the hub has pages left, so the recovery message can show how far it got.
/// </summary>
public sealed record SyncStatusView(bool Enabled, DateTimeOffset? LastRoundAt, string? Code, string? Message, SyncProgress? Rebuild = null);

/// <summary>
/// Outcome of the branch's last sync round, so the store sees why its sales are not reaching the hub (D-041: a
/// refused schema is named). Kept in memory: after a restart the till shows no round until the first one ends.
/// </summary>
public sealed class SyncStatus
{
    private volatile SyncStatusView view = new(false, null, null, null);

    public SyncStatusView View => view;

    public void Enable() => view = view with { Enabled = true };

    /// <summary>A rebuild page landed. The progress stays until a round ends without error: the pass survives a failed round.</summary>
    public void Rebuilding(SyncProgress progress) => view = view with { Enabled = true, Rebuild = progress };

    public void Record(DateTimeOffset at, string? code = null, string? message = null) =>
        view = new SyncStatusView(true, at, code, message, code is null ? null : view.Rebuild);
}

/// <summary>
/// One branch round: pull, then push. A restored branch learns it must rebuild from the hub's push plan ('recover'),
/// or, as a fallback, when the hub refuses its push (51854): it pulls every row in rebuild mode, so the hub's copy wins,
/// and pushes again.
/// Each direction moves in pages (D-041): every page starts from a fresh state and plan, so an open pass continues
/// where the last applied page left it, also after a restart. Any other refusal ends the round; the next continues the pass.
/// </summary>
public sealed class BranchSync(ISyncStore store, ISyncHub hub, NodeContext node, SyncStatus? status = null)
{
    public async Task<SyncRound> RunOnceAsync(CancellationToken ct)
    {
        if (node.Kind != NodeKind.Branch) throw new SaviaException(Errors.WrongNode);
        await store.EnsureLocalNodeAsync(node.NodeId, ct);
        // A restored branch rebuilds before any normal pull. A normal pull leaves out the branch's own rows, so rows of
        // other branches that point to rows the restore lost would fail on a foreign key every round (P9 review).
        var state = await store.SourceStateAsync(ct);
        if (NeedsRebuild(state, await hub.PushPlanAsync(state, ct)))
        {
            var rebuilt = await PullAsync(rebuild: true, ct);
            return new SyncRound(rebuilt.Changed, await PushAsync(rebuilt.Hub, ct), Rebuilt: true);
        }
        var pulled = await PullAsync(rebuild: false, ct);
        try
        {
            return new SyncRound(pulled.Changed, await PushAsync(pulled.Hub, ct), pulled.Rebuilt);
        }
        catch (SaviaException ex) when (ex.Error.Code == "sync.rebuild_required")
        {
            pulled = await PullAsync(rebuild: true, ct);
            return new SyncRound(pulled.Changed, await PushAsync(pulled.Hub, ct), Rebuilt: true);
        }
    }

    private async Task<(Guid Hub, int Changed, bool Rebuilt)> PullAsync(bool rebuild, CancellationToken ct)
    {
        var changed = 0;
        var rebuilt = false;
        while (true)
        {
            var hubState = await hub.StateAsync(ct);
            var hubId = ReadGuid(hubState, "node");
            var plan = await store.PlanAsync(hubId, hubState, rebuild, ct);
            // The plan's mode decides, not the request: an open rebuild pass continues as a rebuild (D-041).
            var planRebuild = ReadString(plan, "mode") == "rebuild";
            Guid? fork = planRebuild ? ReadGuid(await store.SourceStateAsync(ct), "fork") : null;
            var page = PageResult.Parse(await store.ApplyBatchAsync(hubId, await hub.PullAsync(plan, fork, ct), ct));
            changed += page.Changed;
            rebuilt |= planRebuild;
            if (planRebuild) status?.Rebuilding(new SyncProgress(page.Done, page.Total));
            if (page.Ends) return (hubId, changed, rebuilt);
        }
    }

    private async Task<int> PushAsync(Guid hubId, CancellationToken ct)
    {
        var changed = 0;
        while (true)
        {
            var plan = await hub.PushPlanAsync(await store.SourceStateAsync(ct), ct);
            var page = PageResult.Parse(await hub.PushAsync(await store.ReadBatchAsync(hubId, plan, null, ct), ct));
            changed += page.Changed;
            if (page.Ends) return changed;
        }
    }

    /// <summary>
    /// usp_ApplyBatch's answer. A direction ends when no pass is open. An open pass whose page applied nothing would
    /// bring the same page forever, so the round stops with a named error and the till shows it.
    /// </summary>
    private sealed record PageResult(int Changed, bool Ends, int Done, int Total)
    {
        public static PageResult Parse(string json)
        {
            using var doc = JsonDocument.Parse(json);
            var r = doc.RootElement;
            var more = r.TryGetProperty("more", out var m) && m.ValueKind == JsonValueKind.True;
            if (more && r.GetProperty("applied").GetInt32() == 0) throw new SaviaException(Errors.SyncStalled);
            return new PageResult(r.GetProperty("changed").GetInt32(), !more,
                r.GetProperty("done").GetInt32(), r.GetProperty("total").GetInt32());
        }
    }

    /// <summary>
    /// The hub plans 'recover' when the branch's fork or version no longer matches its cursor: a restore.
    /// A restored branch the hub has no cursor for gets only 'initial'; its recovery lock (V036, D-036) still needs a
    /// rebuild, because only a rebuild from the hub lifts it.
    /// </summary>
    private static bool NeedsRebuild(string state, string plan)
    {
        using var doc = JsonDocument.Parse(plan);
        var actions = doc.RootElement.GetProperty("tables").EnumerateArray()
            .Select(t => t.TryGetProperty("a", out var a) ? a.GetString() : null).ToList();
        return actions.Contains("recover") || (Recovering(state) && actions.All(a => a == "initial"));
    }

    private static bool Recovering(string state)
    {
        using var doc = JsonDocument.Parse(state);
        return doc.RootElement.TryGetProperty("recovering", out var r) && r.ValueKind == JsonValueKind.True;
    }

    private static Guid ReadGuid(string json, string name)
    {
        using var doc = JsonDocument.Parse(json);
        return doc.RootElement.GetProperty(name).GetGuid();
    }

    private static string? ReadString(string json, string name)
    {
        using var doc = JsonDocument.Parse(json);
        return doc.RootElement.TryGetProperty(name, out var v) ? v.GetString() : null;
    }
}
