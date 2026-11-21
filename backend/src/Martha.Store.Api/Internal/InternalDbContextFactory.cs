using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Martha.Store.Api.Internal;

// For offline migration/model/script generation only. This factory neither reads
// application configuration/environment secrets nor opens a database connection.
// It is not an apply mechanism: EF CLI --connection can override context options.
public sealed class InternalDbContextFactory : IDesignTimeDbContextFactory<InternalDbContext>
{
    public InternalDbContext CreateDbContext(string[] args)
    {
        // Reserved .invalid hostname; never a real deployment target or credential.
        const string connection = "Server=design-time.invalid;Database=SaviaInternalTest_DesignTime;Integrated Security=true;Encrypt=true;Connect Timeout=1";
        InternalDatabaseGuard.Validate(connection);
        return new InternalDbContext(new DbContextOptionsBuilder<InternalDbContext>()
            .UseSqlServer(connection, sql => sql.CommandTimeout(30)).Options);
    }
}
