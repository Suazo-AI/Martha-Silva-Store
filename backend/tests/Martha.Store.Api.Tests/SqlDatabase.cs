using Martha.Store.Api;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace Martha.Store.Api.Tests;

// Each test owns an entirely new migrated database, never a reset of a supplied DB.
public sealed class SqlDatabase : IAsyncDisposable
{
    private readonly string name = "MarthaSynthetic_Test_" + Guid.NewGuid().ToString("N");
    private readonly string adminConnection;
    public string Connection { get; }
    private bool created;

    public SqlDatabase()
    {
        var supplied = Environment.GetEnvironmentVariable("MARTHA_TEST_SQL_CONNECTION")
            ?? throw new InvalidOperationException("Disposable SQL Server connection must be explicitly supplied.");
        var builder = new SqlConnectionStringBuilder(supplied) { InitialCatalog = "master", Pooling = false };
        adminConnection = builder.ConnectionString;
        builder.InitialCatalog = name;
        Connection = builder.ConnectionString;
    }

    public StoreDbContext Context() => new(new DbContextOptionsBuilder<StoreDbContext>().UseSqlServer(Connection).Options);

    public async Task Initialize()
    {
        await using var master = new SqlConnection(adminConnection);
        await master.OpenAsync();
        await using var command = master.CreateCommand();
        command.CommandText = $"CREATE DATABASE [{name}]"; // name is exclusively generated above.
        await command.ExecuteNonQueryAsync();
        created = true;
        await using var db = Context();
        await db.Database.MigrateAsync();
        await SyntheticSeed.Apply(db);
    }

    public async ValueTask DisposeAsync()
    {
        if (!created) return;
        await using var master = new SqlConnection(adminConnection);
        await master.OpenAsync();
        await using var command = master.CreateCommand();
        command.CommandText = $"ALTER DATABASE [{name}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{name}]";
        await command.ExecuteNonQueryAsync();
    }
}
