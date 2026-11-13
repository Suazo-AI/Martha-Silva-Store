using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Savia.Application;
using Savia.Domain;

namespace Savia.Infrastructure;

public static class ServiceRegistration
{
    /// <summary>
    /// Registers the node identity, the SQL gateway, the ports and the use cases.
    /// Configuration keys: <c>Savia:Node:Kind</c> (Cloud or Branch), <c>Savia:Node:NodeId</c>,
    /// <c>Savia:Node:BranchId</c>, <c>Savia:Node:LocationId</c> and <c>Savia:Sql:ConnectionString</c>.
    /// <c>Savia:Pilot:LocalCatalog</c> defaults to false; the local single-branch pilot enables it explicitly.
    /// Values are read when first needed, so a host (or a test) may add configuration sources late.
    /// The connection string never lives in the repository.
    /// </summary>
    public static IServiceCollection AddSavia(this IServiceCollection services)
    {
        services.AddSingleton(sp => ReadNode(sp.GetRequiredService<IConfiguration>()));
        services.AddSingleton(sp =>
        {
            var connection = sp.GetRequiredService<IConfiguration>()["Savia:Sql:ConnectionString"];
            return string.IsNullOrWhiteSpace(connection)
                ? throw new InvalidOperationException("Savia:Sql:ConnectionString is required.")
                : new SqlGateway(connection);
        });
        services.AddSingleton(TimeProvider.System);
        services.AddSingleton<IPasswordHasher, Pbkdf2PasswordHasher>();
        services.AddSingleton<IAuthStore, AuthStore>();
        services.AddSingleton<AuthService>();
        services.AddSingleton<ISiteStore, SiteStore>();
        services.AddSingleton<SiteService>();
        services.AddSingleton<ICatalogStore, CatalogStore>();
        services.AddSingleton<ICatalogMaintenanceStore, CatalogStore>();
        services.AddSingleton<CatalogService>();
        services.AddSingleton<IReceivingStore, ReceivingStore>();
        services.AddSingleton<ReceivingService>();
        services.AddSingleton<IInventoryStore, InventoryStore>();
        services.AddSingleton<InventoryService>();
        services.AddSingleton<ICashStore, CashStore>();
        services.AddSingleton<CashService>();
        services.AddSingleton<ISalesStore, SalesStore>();
        services.AddSingleton<SalesService>();
        services.AddSingleton<IReturnsStore, ReturnsStore>();
        services.AddSingleton<ReturnsService>();
        services.AddSingleton<ICustomersStore, CustomersStore>();
        services.AddSingleton<CustomersService>();
        services.AddSingleton<IReportsStore, ReportsStore>();
        services.AddSingleton<ReportsService>();
        services.AddSingleton<ICommissionsStore, CommissionsStore>();
        services.AddSingleton<CommissionsService>();
        return services;
    }

    private static NodeContext ReadNode(IConfiguration config)
    {
        var kind = Enum.TryParse<NodeKind>(config["Savia:Node:Kind"], ignoreCase: true, out var parsed)
            ? parsed : throw new InvalidOperationException("Savia:Node:Kind must be Cloud or Branch.");
        Guid? branchId = kind == NodeKind.Branch ? RequiredGuid(config, "Savia:Node:BranchId") : null;
        Guid? locationId = kind == NodeKind.Branch ? RequiredGuid(config, "Savia:Node:LocationId") : null;
        return new NodeContext(kind, RequiredGuid(config, "Savia:Node:NodeId"), branchId, locationId,
            config.GetValue<bool>("Savia:Pilot:LocalCatalog"));
    }

    private static Guid RequiredGuid(IConfiguration config, string key) =>
        Guid.TryParse(config[key], out var value) ? value : throw new InvalidOperationException($"{key} must be a GUID.");
}
