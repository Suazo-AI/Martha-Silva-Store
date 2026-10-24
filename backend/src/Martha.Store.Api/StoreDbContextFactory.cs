using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Martha.Store.Api;

public sealed class StoreDbContextFactory : IDesignTimeDbContextFactory<StoreDbContext>
{
    public StoreDbContext CreateDbContext(string[] args)
    {
        // Without explicit connection this supports offline model/script generation only.
        // Explicit environment configuration is guarded here as an accidental-target safeguard.
        // EF CLI --connection can override options: direct EF apply is unsupported; use guarded --migrate.
        var configured = Environment.GetEnvironmentVariable("ConnectionStrings__Store");
        if (!string.IsNullOrWhiteSpace(configured))
        {
            var environment = Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT")
                ?? Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT");
            if (!string.Equals(environment, "Development", StringComparison.OrdinalIgnoreCase)
                || !bool.TryParse(Environment.GetEnvironmentVariable("Synthetic__Enabled"), out var enabled) || !enabled)
                throw new InvalidOperationException("EF connection requires Development and Synthetic__Enabled=true.");
        }
        var connection = configured ?? "Server=localhost;Database=MarthaSynthetic_DesignOnly;Integrated Security=true;Encrypt=true";
        StoreDatabaseGuard.Validate(connection);
        return new StoreDbContext(new DbContextOptionsBuilder<StoreDbContext>().UseSqlServer(connection).Options);
    }
}
