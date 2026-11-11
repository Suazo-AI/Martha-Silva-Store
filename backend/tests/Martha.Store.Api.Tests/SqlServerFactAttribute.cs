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

// Host-only case: it needs the disposable database that the local recovery orchestrator owns and
// recorded (owned-resources.json plus its backup), so it only runs when that orchestrator produced
// the evidence in this run. On a CI runner there is no orchestrator, so the case is skipped and
// never counted as executed proof.
public sealed class OwnerRecoveryOrchestratorFactAttribute : FactAttribute
{
    public OwnerRecoveryOrchestratorFactAttribute()
    {
        var evidence = Environment.GetEnvironmentVariable("SAVIA_PILOT_EVIDENCE");
        if (string.IsNullOrWhiteSpace(evidence)
            || !File.Exists(Path.Combine(evidence, "owned-resources.json")))
            Skip = "Not run: the local recovery orchestrator did not produce owned-resources.json in this run.";
    }
}
