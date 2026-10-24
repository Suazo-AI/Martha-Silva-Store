using Xunit;

namespace Martha.Store.Api.Tests;

// A missing SQL endpoint is explicitly skipped, never silently substituted with
// SQLite/InMemory. The eventual integration CI job must require this variable.
public sealed class SqlServerFactAttribute : FactAttribute
{
    public SqlServerFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("MARTHA_TEST_SQL_CONNECTION")))
            Skip = "Real disposable SQL Server not configured: MARTHA_TEST_SQL_CONNECTION is required.";
    }
}
