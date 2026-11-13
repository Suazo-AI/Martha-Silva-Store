using System.Security.Cryptography;
using System.Text;
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
// Usage: Savia.Migrator [--plan] [--migrations DIR] [--grant-app-user NAME [--external [--object-id GUID]]]
//   --plan                 report applied / pending / changed files; change nothing
//   --grant-app-user NAME  after migrating, give database user NAME the API host permissions
//   --external             create NAME as an Entra ID user (CREATE USER ... FROM EXTERNAL PROVIDER)
//   --object-id GUID       with --external: the identity's object id, so SQL needs no Microsoft Graph lookup
// Exit codes: 0 ok, 1 migration or check failed, 2 bad usage or configuration.

var plan = args.Contains("--plan");
var external = args.Contains("--external");
var migrationsDir = Option("--migrations") ?? Environment.GetEnvironmentVariable("SAVIA_MIGRATIONS_DIR") ?? Path.Combine(AppContext.BaseDirectory, "migrations");
var appUser = Option("--grant-app-user");
var objectId = Option("--object-id");
var connectionString = Environment.GetEnvironmentVariable("Savia__Sql__ConnectionString");

if (string.IsNullOrWhiteSpace(connectionString))
    return Fail(2, "Savia__Sql__ConnectionString is required.");
if (!Directory.Exists(migrationsDir))
    return Fail(2, $"migrations folder not found: {migrationsDir}");
if (appUser is not null && !Regex.IsMatch(appUser, "^[A-Za-z0-9_.-]{1,120}$"))
    return Fail(2, "--grant-app-user must be 1-120 letters, digits, '_', '.' or '-'.");
if (objectId is not null && (!external || !Guid.TryParse(objectId, out _)))
    return Fail(2, "--object-id needs --external and a GUID.");

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
        foreach (var batch in migration.Batches())
            await Exec(connection, batch, timeoutSeconds: 1800);
        await Exec(connection, "INSERT INTO dbo.SaviaMigrations(Version,FileName,Sha256) VALUES(@v,@f,@s);", 30,
            new SqlParameter("@v", migration.Version), new SqlParameter("@f", migration.FileName),
            new SqlParameter("@s", migration.Sha256));
    }

    var after = await ReadLedger(connection);
    var missing = files.Where(f => !after.TryGetValue(f.Version, out var sha) || sha != f.Sha256).ToList();
    if (missing.Count > 0)
        return Fail(1, "ledger check failed after the run: " + string.Join(", ", missing.Select(m => m.FileName)));
    Console.WriteLine($"migrate: ledger complete ({after.Count} versions); applied now: " +
                      (pending.Count > 0 ? string.Join(", ", pending.Select(p => p.FileName)) : "nothing new"));

    if (appUser is not null)
    {
        await GrantAppUser(connection, appUser, external, objectId);
        Console.WriteLine($"migrate: API host permissions ensured for user {appUser}");
    }
    return 0;
}
catch (SqlException e)
{
    // Server messages name objects, not secrets; the connection string is never echoed.
    return Fail(1, $"SQL error {e.Number}: {e.Message}");
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

// Least privilege for the API host, derived from savia/src: it reads views and tables, executes
// procedures, and writes security.Sessions and the sign-in columns of security.Staff directly
// (savia/src/Savia.Infrastructure/Auth.cs). It never runs DDL. Idempotent.
static async Task GrantAppUser(SqlConnection connection, string user, bool external, string? objectId)
{
    var quoted = "[" + user.Replace("]", "]]") + "]";
    var withObjectId = objectId is null ? "" : $" WITH OBJECT_ID = '{Guid.Parse(objectId)}'";
    var create = external ? $"CREATE USER {quoted} FROM EXTERNAL PROVIDER{withObjectId};" : $"CREATE USER {quoted} FOR LOGIN {quoted};";
    await Exec(connection, $"""
        IF DATABASE_PRINCIPAL_ID(N'{user}') IS NULL {create}
        IF DATABASE_PRINCIPAL_ID(N'savia_api_host') IS NULL CREATE ROLE [savia_api_host] AUTHORIZATION [dbo];
        GRANT SELECT TO [savia_api_host];
        GRANT EXECUTE TO [savia_api_host];
        GRANT INSERT, UPDATE ON OBJECT::[security].[Sessions] TO [savia_api_host];
        GRANT UPDATE ON OBJECT::[security].[Staff] TO [savia_api_host];
        IF IS_ROLEMEMBER(N'savia_api_host', N'{user}') = 0 ALTER ROLE [savia_api_host] ADD MEMBER {quoted};
        """);
}

sealed class Migration
{
    private static readonly Regex Go = new(@"^[ \t]*GO[ \t]*$", RegexOptions.IgnoreCase);
    private static readonly Regex GoWithCount = new(@"^[ \t]*GO[ \t]+\d+[ \t]*$", RegexOptions.IgnoreCase);

    public Migration(string path)
    {
        Path = path;
        FileName = System.IO.Path.GetFileName(path);
        Version = FileName.Split("__")[0];
        var bytes = File.ReadAllBytes(path);
        Sha256 = Convert.ToHexStringLower(SHA256.HashData(NormalizeNewlines(bytes)));
    }

    public string Path { get; }
    public string FileName { get; }
    public string Version { get; }
    public string Sha256 { get; }

    /// <summary>
    /// sqlcmd batches: the lines between lines that contain only GO, each line kept with its newline,
    /// so module definitions are byte-identical to what saviadb.py (sqlcmd) stores. "GO n" is refused.
    /// </summary>
    public List<string> Batches()
    {
        var text = File.ReadAllText(Path, Encoding.UTF8).Replace("\r\n", "\n");
        var lines = text.Split('\n');
        var count = text.EndsWith('\n') ? lines.Length - 1 : lines.Length;
        var batches = new List<string>();
        var batch = new StringBuilder();
        for (var i = 0; i < count; i++)
        {
            if (GoWithCount.IsMatch(lines[i]))
                throw new InvalidOperationException($"{FileName}: 'GO <count>' is not supported by the production runner.");
            if (Go.IsMatch(lines[i]))
            {
                batches.Add(batch.ToString());
                batch.Clear();
                continue;
            }
            batch.Append(lines[i]).Append('\n');
        }
        batches.Add(batch.ToString());
        return batches.Where(b => !string.IsNullOrWhiteSpace(b)).ToList();
    }

    private static byte[] NormalizeNewlines(byte[] bytes)
    {
        var output = new List<byte>(bytes.Length);
        for (var i = 0; i < bytes.Length; i++)
        {
            if (bytes[i] == (byte)'\r' && i + 1 < bytes.Length && bytes[i + 1] == (byte)'\n')
                continue;
            output.Add(bytes[i]);
        }
        return output.ToArray();
    }
}
