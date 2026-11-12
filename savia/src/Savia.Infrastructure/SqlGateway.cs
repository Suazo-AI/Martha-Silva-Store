using System.Data;
using Microsoft.Data.SqlClient;
using Savia.Domain;

namespace Savia.Infrastructure;

/// <summary>
/// The only door to SQL Server. Opens one connection per call and turns SQL errors into
/// <see cref="SaviaException"/> with a stable code. It holds no business rule.
/// </summary>
public sealed class SqlGateway(string connectionString)
{
    public static SqlParameter P(string name, object? value) => new(name, value ?? DBNull.Value);

    public static SqlParameter Out(string name, SqlDbType type) => new(name, type) { Direction = ParameterDirection.Output };

    /// <summary>Table-valued parameter. <paramref name="typeName"/> is the SQL table type, for example sales.SaleLineRequest.</summary>
    public static SqlParameter Table(string name, string typeName, DataTable rows) =>
        new(name, SqlDbType.Structured) { TypeName = typeName, Value = rows };

    public Task ExecProcAsync(string procedure, CancellationToken ct, params SqlParameter[] parameters) =>
        RunAsync(procedure, CommandType.StoredProcedure, parameters, async cmd => { await cmd.ExecuteNonQueryAsync(ct); return 0; }, ct);

    public Task<int> ExecAsync(string sql, CancellationToken ct, params SqlParameter[] parameters) =>
        RunAsync(sql, CommandType.Text, parameters, cmd => cmd.ExecuteNonQueryAsync(ct), ct);

    public Task<List<T>> QueryAsync<T>(string sql, Func<SqlDataReader, T> map, CancellationToken ct, params SqlParameter[] parameters) =>
        RunAsync(sql, CommandType.Text, parameters, cmd => ReadAllAsync(cmd, map, ct), ct);

    public Task<List<T>> QueryProcAsync<T>(string procedure, Func<SqlDataReader, T> map, CancellationToken ct, params SqlParameter[] parameters) =>
        RunAsync(procedure, CommandType.StoredProcedure, parameters, cmd => ReadAllAsync(cmd, map, ct), ct);

    public async Task<T?> FirstAsync<T>(string sql, Func<SqlDataReader, T> map, CancellationToken ct, params SqlParameter[] parameters)
        where T : class => (await QueryAsync(sql, map, ct, parameters)).FirstOrDefault();

    public async Task<TResult> RunAsync<TResult>(string text, CommandType type, SqlParameter[] parameters,
        Func<SqlCommand, Task<TResult>> work, CancellationToken ct)
    {
        try
        {
            await using var connection = new SqlConnection(connectionString);
            await connection.OpenAsync(ct);
            await using var command = new SqlCommand(text, connection) { CommandType = type, CommandTimeout = 30 };
            command.Parameters.AddRange(parameters);
            return await work(command);
        }
        catch (SqlException ex)
        {
            throw Translate(ex);
        }
    }

    private static async Task<List<T>> ReadAllAsync<T>(SqlCommand command, Func<SqlDataReader, T> map, CancellationToken ct)
    {
        var rows = new List<T>();
        await using var reader = await command.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct)) rows.Add(map(reader));
        return rows;
    }

    /// <summary>A procedure rejects with THROW 5xxxx; that number wins over any follow-up engine error.</summary>
    internal static SaviaException Translate(SqlException ex)
    {
        var business = ex.Errors.Cast<SqlError>().FirstOrDefault(e => e.Number is >= 50000 and <= 59999);
        return new SaviaException(DbErrors.FromSql(business?.Number ?? ex.Number, business?.Message ?? ex.Message), ex);
    }
}

internal static class ReaderExtensions
{
    public static Guid? GuidOrNull(this SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetGuid(i);
    public static string? StringOrNull(this SqlDataReader r, int i) => r.IsDBNull(i) ? null : r.GetString(i);
}
