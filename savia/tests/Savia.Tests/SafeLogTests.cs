using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Logging;
using Savia.Api;
using Savia.Domain;

namespace Savia.Tests;

/// <summary>
/// SEC-46 (docs/public-software/SECURITY-RULES.md): a logged exception never carries contact details. A real SQL
/// duplicate key quotes the row value in its message; the log keeps the error code, number and location only.
/// </summary>
public sealed class SafeLogTests
{
    private const string Email = "ana.prueba@example.com";

    private sealed class Capture : ILogger
    {
        public List<string> Lines { get; } = [];
        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
        public bool IsEnabled(LogLevel logLevel) => true;
        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception? exception, Func<TState, Exception?, string> formatter) =>
            Lines.Add(formatter(state, exception) + (exception is null ? "" : "\n" + exception));
    }

    [Fact]
    public async Task A_sql_error_that_quotes_an_email_is_logged_without_it()
    {
        await using var connection = new SqlConnection(TestSql.ConnectionFor("master"));
        await connection.OpenAsync();
        await using var command = new SqlCommand(
            $"CREATE TABLE #c(Email nvarchar(100) PRIMARY KEY); INSERT #c VALUES('{Email}'); INSERT #c VALUES('{Email}');", connection);
        var sql = await Assert.ThrowsAsync<SqlException>(() => command.ExecuteNonQueryAsync());
        Assert.Contains(Email, sql.ToString());   // the raw exception does leak it

        var wrapped = new SaviaException(DbErrors.FromSql(sql.Number, sql.Message), sql);
        var described = SafeLog.Describe(wrapped);
        Assert.Equal("db.duplicate <- SqlException 2627 in batch line 1", described);

        var log = new Capture();
        log.Failure(wrapped, "Unhandled database error on /api/v1/x");
        var line = Assert.Single(log.Lines);
        Assert.DoesNotContain(Email, line);
        Assert.Contains("db.duplicate <- SqlException 2627", line);
        Assert.Contains("--- inner ---", line);   // the stack trace of the SQL error is kept
        Assert.Contains("Microsoft.Data.SqlClient.SqlCommand", line);
    }
}
