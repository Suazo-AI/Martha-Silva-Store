using System.Reflection;
using Savia.Application;
using Savia.Contracts;
using Savia.Domain;
using Savia.Infrastructure;

namespace Savia.Tests;

/// <summary>ADR-001 D3: the layer rule is a test, so a wrong reference fails the build pipeline.</summary>
public sealed class ArchitectureTests
{
    [Fact]
    public void Each_layer_references_only_the_layers_it_may()
    {
        AssertSaviaReferences(typeof(SaviaError).Assembly);                                   // Domain: nothing
        AssertSaviaReferences(typeof(ProblemResponse).Assembly);                              // Contracts: nothing
        AssertSaviaReferences(typeof(NodeContext).Assembly, "Savia.Domain", "Savia.Contracts");
        AssertSaviaReferences(typeof(SqlGateway).Assembly, "Savia.Application", "Savia.Domain", "Savia.Contracts");
    }

    [Fact]
    public void Only_infrastructure_talks_to_sql_server()
    {
        foreach (var assembly in new[] { typeof(SaviaError).Assembly, typeof(ProblemResponse).Assembly, typeof(NodeContext).Assembly, typeof(Program).Assembly })
            Assert.DoesNotContain(assembly.GetReferencedAssemblies(), r => r.Name == "Microsoft.Data.SqlClient");
    }

    [Fact]
    public async Task The_api_publishes_its_contract()
    {
        var database = await TestSql.CloneAsync("openapi");
        try
        {
            await using var node = SaviaNode.BranchA(database);
            var document = await node.CreateClient().GetStringAsync("/openapi/v1.json");
            foreach (var path in new[] { "/api/v1/auth/login", "/api/v1/receiving/sessions/{sessionId}/scans", "/api/v1/sales", "/api/v1/cash/tills/{tillId}/close" })
                Assert.Contains($"\"{path}\"", document);
            Assert.DoesNotContain("/api/v1/catalog/products", document);   // a branch node has no catalog writes
        }
        finally
        {
            await TestSql.DropAsync(database);
        }
    }

    private static void AssertSaviaReferences(Assembly assembly, params string[] allowed)
    {
        var actual = assembly.GetReferencedAssemblies().Select(r => r.Name!).Where(n => n.StartsWith("Savia.", StringComparison.Ordinal));
        Assert.Empty(actual.Except(allowed));
    }
}
