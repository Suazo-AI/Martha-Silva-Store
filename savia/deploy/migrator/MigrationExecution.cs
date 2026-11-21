using System.Data.Common;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

// Kept independent of SqlClient so offline tests execute this exact production orchestration.
internal static class MigrationExecution
{
    internal static async Task ApplyAsync(DbConnection connection, Migration migration)
    {
        var batches = migration.Batches();
        if (!migration.Transactional)
        {
            foreach (var batch in batches)
                await Execute(connection, null, batch, 1800);
            await Register(connection, null, migration);
            return;
        }

        var xactAbort = Convert.ToInt32(await Scalar(connection, null, "SELECT @@OPTIONS & 16384;")) != 0;
        DbTransaction? transaction = null;
        Exception? failure = null;
        try
        {
            await Execute(connection, null, "SET XACT_ABORT ON;", 60);
            transaction = await connection.BeginTransactionAsync();
            foreach (var batch in batches)
                await Execute(connection, transaction, batch, 1800);
            await Validate(connection, transaction);
            await Register(connection, transaction, migration);
            await Validate(connection, transaction);
            await transaction.CommitAsync();
        }
        catch (Exception error)
        {
            failure = error;
            if (transaction is not null)
            {
                try { await transaction.RollbackAsync(); }
                catch { /* Preserve the original failure, including an uncertain commit outcome. */ }
            }
            throw;
        }
        finally
        {
            try
            {
                if (transaction is not null) await transaction.DisposeAsync();
            }
            catch when (failure is not null) { }
            // SET options survive rollback. Preserve later unmarked migrations' session behavior.
            try { await Execute(connection, null, xactAbort ? "SET XACT_ABORT ON;" : "SET XACT_ABORT OFF;", 60); }
            catch when (failure is not null) { }
        }
    }

    private static async Task Validate(DbConnection connection, DbTransaction transaction)
    {
        var valid = await Scalar(connection, transaction,
            "SELECT CASE WHEN @@TRANCOUNT = 1 AND XACT_STATE() = 1 THEN 1 ELSE 0 END;");
        if (Convert.ToInt32(valid) != 1)
            throw new InvalidOperationException("Migration transaction invalid.");
    }

    private static Task Register(DbConnection connection, DbTransaction? transaction, Migration migration) =>
        Run(connection, transaction, "INSERT INTO dbo.SaviaMigrations(Version,FileName,Sha256) VALUES(@v,@f,@s);", 30,
            async command =>
            {
                foreach (var (name, value) in new[] { ("@v", migration.Version), ("@f", migration.FileName), ("@s", migration.Sha256) })
                {
                    var parameter = command.CreateParameter();
                    parameter.ParameterName = name;
                    parameter.Value = value;
                    command.Parameters.Add(parameter);
                }
                return (object?)await command.ExecuteNonQueryAsync();
            });

    private static Task Execute(DbConnection connection, DbTransaction? transaction, string sql, int timeout) =>
        Run(connection, transaction, sql, timeout, async command => (object?)await command.ExecuteNonQueryAsync());

    private static Task<object?> Scalar(DbConnection connection, DbTransaction? transaction, string sql) =>
        Run(connection, transaction, sql, 90, command => command.ExecuteScalarAsync());

    /// <summary>
    /// Every command goes through here. A failed operation keeps its own exception even when disposing
    /// the command also fails; a disposal failure after a successful operation is still reported.
    /// </summary>
    private static async Task<object?> Run(DbConnection connection, DbTransaction? transaction, string sql, int timeout,
        Func<DbCommand, Task<object?>> operation)
    {
        var command = connection.CreateCommand();
        object? result;
        try
        {
            command.Transaction = transaction;
            command.CommandText = sql;
            command.CommandTimeout = timeout;
            result = await operation(command);
        }
        catch
        {
            try { await command.DisposeAsync(); }
            catch { /* Preserve the operation's failure. */ }
            throw;
        }
        await command.DisposeAsync();
        return result;
    }
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
        Transactional = Encoding.UTF8.GetString(bytes).StartsWith("-- savia:transactional", StringComparison.Ordinal);
        Sha256 = Convert.ToHexStringLower(SHA256.HashData(NormalizeNewlines(bytes)));
    }

    public bool Transactional { get; }
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
