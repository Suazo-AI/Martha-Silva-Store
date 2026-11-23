using System.Data;
using System.Data.Common;
using System.Security.Cryptography;
using System.Text;

// D-040 node provisioning. Kept independent of SqlClient so offline tests cover the parsing and the secret.
//   register  node row only (run on each store database for the hub node and for the store's own node)
//   create    register on the hub, then a first credential; refused when the node already has an active one
//   rotate    a new credential for an existing node; the old secret stops working at once (one row per node)
//   revoke    the node's credential stops working; the node row stays
// create and rotate take the secret from SAVIA_NODE_SECRET when it is set, and then print no secret: on Azure the job's
// output goes to Log Analytics. Otherwise they make a new one and print it once, on its own "node-secret: " line.
// SQL receives only its SHA-256.
internal sealed record NodeRequest(string Action, Guid NodeId, string Kind, Guid? BranchId, string? NodeCode)
{
    internal const string SecretPrefix = "node-secret: ";
    internal const string SecretVariable = "SAVIA_NODE_SECRET";
    private static readonly string[] Actions = ["register", "create", "rotate", "revoke"];

    /// <summary>Returns the request, or an error message for exit code 2.</summary>
    internal static (NodeRequest? Request, string? Error) Parse(string action, Func<string, string?> option)
    {
        if (!Actions.Contains(action))
            return (null, "--provision-node takes register, create, rotate or revoke.");
        if (!Guid.TryParse(option("--node-id"), out var nodeId))
            return (null, "--node-id must be a GUID.");
        var kind = option("--node-kind") ?? "branch";
        if (kind is not ("branch" or "azure"))
            return (null, "--node-kind is branch or azure.");
        Guid? branchId = Guid.TryParse(option("--branch-id"), out var b) ? b : null;
        var code = option("--node-code");
        if (action is "register" or "create" && (code is null || (kind == "branch") != branchId.HasValue))
            return (null, "register and create need --node-code, and --branch-id exactly when --node-kind is branch.");
        if (action is "create" or "rotate" && kind != "branch")
            return (null, "only a branch node has a credential.");
        return (new NodeRequest(action, nodeId, kind, branchId, code), null);
    }

    /// <summary>256 random bits, base64url without padding: no '.' so the header splits at the node id.</summary>
    internal static string NewSecret() =>
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)).TrimEnd('=').Replace('+', '-').Replace('/', '_');

    internal static byte[] Hash(string secret) => SHA256.HashData(Encoding.UTF8.GetBytes(secret));

    /// <summary>
    /// Null when a given secret is strong enough: 43 to 256 base64url characters (at least the 256 bits of
    /// <see cref="NewSecret"/>; no '.', space or quote, so the sync header carries it) and at least 16 distinct ones.
    /// The message never contains the value.
    /// </summary>
    internal static string? CheckSecret(string secret) =>
        secret.Length is >= 43 and <= 256 && secret.All(c => char.IsAsciiLetterOrDigit(c) || c is '-' or '_') &&
        secret.Distinct().Count() >= 16
            ? null
            : $"{SecretVariable} must be 43 to 256 characters of A-Z, a-z, 0-9, '-' and '_', with at least 16 different ones " +
              "(the value is not shown). Generate one from 32 random bytes in base64url.";

    /// <summary>
    /// Runs the action and writes its report. A secret from <see cref="SecretVariable"/> is never written; a generated
    /// one is written once, on the <see cref="SecretPrefix"/> line.
    /// </summary>
    internal async Task ReportAsync(DbConnection connection, string? givenSecret, TextWriter output)
    {
        var given = Action is "create" or "rotate" && !string.IsNullOrEmpty(givenSecret) ? givenSecret : null;
        if (given is not null && CheckSecret(given) is { } error)
            throw new InvalidOperationException(error);
        var secret = await RunAsync(connection, given);
        output.WriteLine($"provision: {Action} node {NodeId:D} on database {connection.Database}: done" +
                         (secret is not null && given is not null ? $", credential from {SecretVariable} (not printed)" : ""));
        if (secret is not null && given is null)
            output.WriteLine(SecretPrefix + secret);
    }

    /// <summary>Runs the action. Returns the secret for create and rotate (the given one, or a new one), otherwise null.</summary>
    internal async Task<string?> RunAsync(DbConnection connection, string? givenSecret = null)
    {
        if (Action is "register" or "create")
            await Exec(connection, "sync.usp_ProvisionNode", ("@NodeId", NodeId), ("@Kind", Kind),
                       ("@BranchId", (object?)BranchId ?? DBNull.Value), ("@NodeCode", NodeCode!));
        if (Action == "revoke")
            await Exec(connection, "sync.usp_RevokeNodeCredential", ("@NodeId", NodeId));
        if (Action is "register" or "revoke")
            return null;
        if (Action == "create" && await HasActiveCredential(connection))
            throw new InvalidOperationException("the node already has an active credential; use rotate.");
        var secret = givenSecret ?? NewSecret();
        await Exec(connection, "sync.usp_SetNodeCredential", ("@NodeId", NodeId), ("@SecretHash", Hash(secret)));
        return secret;
    }

    private async Task<bool> HasActiveCredential(DbConnection connection)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = "SELECT COUNT(*) FROM sync.NodeCredentials WHERE NodeId=@NodeId AND RevokedAt IS NULL;";
        Add(command, "@NodeId", NodeId);
        return Convert.ToInt32(await command.ExecuteScalarAsync()) > 0;
    }

    internal static async Task Exec(DbConnection connection, string procedure, params (string Name, object Value)[] parameters)
    {
        await using var command = connection.CreateCommand();
        command.CommandText = procedure;
        command.CommandType = CommandType.StoredProcedure;
        foreach (var (name, value) in parameters)
            Add(command, name, value);
        await command.ExecuteNonQueryAsync();
    }

    private static void Add(DbCommand command, string name, object value)
    {
        var p = command.CreateParameter();
        p.ParameterName = name;
        p.Value = value;
        command.Parameters.Add(p);
    }
}
