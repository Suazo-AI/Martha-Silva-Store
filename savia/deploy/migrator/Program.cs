using System.Text.RegularExpressions;
using Microsoft.Data.SqlClient;

// SAVIA production migration runner.
//
// It applies savia/db/migrations/V*.sql with the same rules as savia/tools/db/saviadb.py:
//   - ledger table dbo.SaviaMigrations(Version, FileName, Sha256, AppliedAt);
//   - checksum = SHA-256 of the file bytes with CRLF normalized to LF;
//   - an applied file is skipped; a changed applied file stops the run (migrations are immutable);
//   - files run in name order, batches split on GO lines, QUOTED_IDENTIFIER ON (sqlcmd -I).
// Extra production safety: one runner at a time (sp_getapplock), a read-only --plan mode,
// and a final check that every file on disk is in the ledger.
//
// Connection string: environment variable Savia__Sql__ConnectionString. In Azure it carries no
// secret ("Authentication=Active Directory Managed Identity"). It is never printed.
//
// Usage: Savia.Migrator [--plan] [--migrations DIR] [--grant-app-user NAME [--external [--client-id GUID]]]
//   --plan                 report applied / pending / changed files; change nothing
//   --grant-app-user NAME  after migrating, give database user NAME the API host permissions
//   --external             create NAME as an Entra ID user (CREATE USER ... FROM EXTERNAL PROVIDER)
//   --client-id GUID       with --external: the identity's client id; the user is created from its SID
//                          (TYPE = E), so the SQL server needs no Directory Readers role for a Graph lookup
//        Savia.Migrator --provision-node register|create|rotate|revoke --node-id GUID
//                       [--node-kind branch|azure] [--branch-id GUID] [--node-code CODE]
//   --provision-node       node rows and credentials only; migrates nothing (see NodeProvisioning.cs and
//                          docs/sync/PROVISIONING.md). create and rotate take SAVIA_NODE_SECRET and print no
//                          secret, or make a new secret and print it once.
//        Savia.Migrator --provision-branch --branch-id GUID --branch-code CODE --branch-name NAME --store-name NAME
//                       --location-id GUID --location-code CODE --location-name NAME
//                       --register-id GUID --register-code CODE --register-name NAME
//        Savia.Migrator --provision-staff --staff-id GUID --login LOGIN --display-name NAME --role ROLE
//                       [--branch-id GUID [--approver]] [--set-password]
//   --provision-branch / --provision-staff  day-zero records on this database only; migrate nothing
//                          (see SiteProvisioning.cs). --set-password reads SAVIA_STAFF_PASSWORD (prints nothing) or
//                          prints a one-time password once, which staff must change at the first sign-in.
// Exit codes: 0 ok, 1 migration or check failed, 2 bad usage or configuration.

var plan = args.Contains("--plan");
var external = args.Contains("--external");
var migrationsDir = Option("--migrations") ?? Environment.GetEnvironmentVariable("SAVIA_MIGRATIONS_DIR") ?? Path.Combine(AppContext.BaseDirectory, "migrations");
var appUser = Option("--grant-app-user");
var clientId = Option("--client-id");
var connectionString = Environment.GetEnvironmentVariable("Savia__Sql__ConnectionString");

if (string.IsNullOrWhiteSpace(connectionString))
    return Fail(2, "Savia__Sql__ConnectionString is required.");
if (Option("--provision-node") is { } provisionAction)
    return await ProvisionNode(connectionString, provisionAction);
if (args.Contains("--provision-branch"))
    return await ProvisionBranch(connectionString);
if (args.Contains("--provision-staff"))
    return await ProvisionStaff(connectionString);
if (!Directory.Exists(migrationsDir))
    return Fail(2, $"migrations folder not found: {migrationsDir}");
if (appUser is not null && !Regex.IsMatch(appUser, "^[A-Za-z0-9_.-]{1,120}$"))
    return Fail(2, "--grant-app-user must be 1-120 letters, digits, '_', '.' or '-'.");
if (clientId is not null && (!external || !Guid.TryParse(clientId, out _)))
    return Fail(2, "--client-id needs --external and a GUID.");

var files = Directory.GetFiles(migrationsDir, "V*.sql")
    .Select(path => new Migration(path))
    .OrderBy(m => m.FileName, StringComparer.Ordinal)
    .ToList();
if (files.Count == 0)
    return Fail(2, $"no V*.sql files in {migrationsDir}");

try
{
    await using var connection = new SqlConnection(connectionString);
    connection.InfoMessage += (_, e) => Console.WriteLine("  sql: " + e.Message);
    await connection.OpenAsync();
    Console.WriteLine($"migrate: database {connection.Database}, {files.Count} files on disk, mode {(plan ? "plan" : "apply")}");
    await Exec(connection, "SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON; " +
                           "SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF;");

    if (!plan)
    {
        // Session lock: a second runner waits up to 60 s and then fails instead of interleaving.
        var lockResult = await Scalar(connection,
            "DECLARE @r int; EXEC @r = sp_getapplock @Resource=N'savia-migrations', @LockMode='Exclusive', " +
            "@LockOwner='Session', @LockTimeout=60000; SELECT @r;");
        if (Convert.ToInt32(lockResult) < 0)
            return Fail(1, "another migration run holds the lock.");
        await Exec(connection, """
            IF OBJECT_ID(N'dbo.SaviaMigrations') IS NULL
              CREATE TABLE dbo.SaviaMigrations(
                Version varchar(20) NOT NULL PRIMARY KEY, FileName nvarchar(200) NOT NULL,
                Sha256 char(64) NOT NULL, AppliedAt datetime2(3) NOT NULL DEFAULT SYSUTCDATETIME());
            """);
    }

    var ledger = await ReadLedger(connection);
    var unknown = ledger.Keys.Except(files.Select(f => f.Version)).OrderBy(v => v, StringComparer.Ordinal).ToList();
    if (unknown.Count > 0)
        Console.WriteLine($"migrate: WARNING database has versions this image does not know: {string.Join(", ", unknown)}");

    var changed = files.Where(f => ledger.TryGetValue(f.Version, out var sha) && sha != f.Sha256).ToList();
    foreach (var f in changed)
        Console.Error.WriteLine($"migrate: {f.FileName} already applied with a different checksum. Migrations are immutable.");
    if (changed.Count > 0)
        return 1;

    var pending = files.Where(f => !ledger.ContainsKey(f.Version)).ToList();
    Console.WriteLine($"migrate: applied {files.Count - pending.Count}, pending {pending.Count}" +
                      (pending.Count > 0 ? ": " + string.Join(", ", pending.Select(p => p.FileName)) : ""));
    if (plan)
        return 0;

    foreach (var migration in pending)
    {
        Console.WriteLine($"migrate: applying {migration.FileName}");
        await MigrationExecution.ApplyAsync(connection, migration);
    }

    var after = await ReadLedger(connection);
    var missing = files.Where(f => !after.TryGetValue(f.Version, out var sha) || sha != f.Sha256).ToList();
    if (missing.Count > 0)
        return Fail(1, "ledger check failed after the run: " + string.Join(", ", missing.Select(m => m.FileName)));
    Console.WriteLine($"migrate: ledger complete ({after.Count} versions); applied now: " +
                      (pending.Count > 0 ? string.Join(", ", pending.Select(p => p.FileName)) : "nothing new"));

    if (appUser is not null)
    {
        await GrantAppUser(connection, appUser, external, clientId);
        Console.WriteLine($"migrate: API host permissions ensured for user {appUser}");
    }
    return 0;
}
catch (SqlException e)
{
    // Server messages name objects, not secrets; the connection string is never echoed.
    return Fail(1, $"SQL error {e.Number}: {e.Message}");
}

async Task<int> ProvisionNode(string connection, string action)
{
    var (request, error) = NodeRequest.Parse(action, Option);
    if (request is null)
        return Fail(2, error!);
    try
    {
        await using var sql = new SqlConnection(connection);
        await sql.OpenAsync();
        await request.ReportAsync(sql, Environment.GetEnvironmentVariable(NodeRequest.SecretVariable), Console.Out);
        return 0;
    }
    catch (Exception e) when (e is SqlException or InvalidOperationException)
    {
        return Fail(1, e is SqlException s ? $"SQL error {s.Number}: {s.Message}" : e.Message);
    }
}

async Task<int> ProvisionBranch(string connection)
{
    var (request, error) = BranchRequest.Parse(Option);
    if (request is null)
        return Fail(2, error!);
    return await Provision(connection, async sql =>
    {
        await request.RunAsync(sql);
        Console.WriteLine($"provision: branch {request.Code} register {request.RegisterCode} on database {sql.Database}: done");
    });
}

async Task<int> ProvisionStaff(string connection)
{
    var (request, error) = StaffRequest.Parse(Option, args.Contains);
    if (request is null)
        return Fail(2, error!);
    return await Provision(connection, sql =>
        request.ReportAsync(sql, Environment.GetEnvironmentVariable(StaffRequest.PasswordVariable), Console.Out));
}

async Task<int> Provision(string connection, Func<SqlConnection, Task> action)
{
    try
    {
        await using var sql = new SqlConnection(connection);
        await sql.OpenAsync();
        await action(sql);
        return 0;
    }
    catch (Exception e) when (e is SqlException or InvalidOperationException)
    {
        return Fail(1, e is SqlException s ? $"SQL error {s.Number}: {s.Message}" : e.Message);
    }
}

string? Option(string name)
{
    var index = Array.IndexOf(args, name);
    return index >= 0 && index + 1 < args.Length ? args[index + 1] : null;
}

static int Fail(int code, string message)
{
    Console.Error.WriteLine("migrate: " + message);
    return code;
}

static async Task Exec(SqlConnection connection, string text, int timeoutSeconds = 60, params SqlParameter[] parameters)
{
    await using var command = new SqlCommand(text, connection) { CommandTimeout = timeoutSeconds };
    command.Parameters.AddRange(parameters);
    await command.ExecuteNonQueryAsync();
}

static async Task<object?> Scalar(SqlConnection connection, string text)
{
    await using var command = new SqlCommand(text, connection) { CommandTimeout = 90 };
    return await command.ExecuteScalarAsync();
}

static async Task<Dictionary<string, string>> ReadLedger(SqlConnection connection)
{
    var result = new Dictionary<string, string>(StringComparer.Ordinal);
    await using var command = new SqlCommand(
        "IF OBJECT_ID(N'dbo.SaviaMigrations') IS NOT NULL SELECT Version, Sha256 FROM dbo.SaviaMigrations;", connection);
    await using var reader = await command.ExecuteReaderAsync();
    while (await reader.ReadAsync())
        result[reader.GetString(0)] = reader.GetString(1).Trim();
    return result;
}

// The API host's permissions live in role savia_api_host, created by migration V035, so local and Azure databases
// get the same grants from one source. This step only creates the user and adds it to the role. Idempotent.
static async Task GrantAppUser(SqlConnection connection, string user, bool external, string? clientId)
{
    var quoted = "[" + user.Replace("]", "]]") + "]";
    var create = (external, clientId) switch
    {
        (true, null) => $"CREATE USER {quoted} FROM EXTERNAL PROVIDER;",
        // Entra SID of a service principal = its client id bytes, the same rule the server admin uses in main.bicep.
        (true, _) => $"CREATE USER {quoted} WITH SID = 0x{Convert.ToHexString(Guid.Parse(clientId).ToByteArray())}, TYPE = E;",
        _ => $"CREATE USER {quoted} FOR LOGIN {quoted};",
    };
    await Exec(connection, $"""
        IF DATABASE_PRINCIPAL_ID(N'savia_api_host') IS NULL THROW 50000, 'Role savia_api_host is missing; migration V035 must run first.', 1;
        IF DATABASE_PRINCIPAL_ID(N'{user}') IS NULL {create}
        IF IS_ROLEMEMBER(N'savia_api_host', N'{user}') = 0 ALTER ROLE [savia_api_host] ADD MEMBER {quoted};
        """);
}
