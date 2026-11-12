using System.Diagnostics;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Savia.Application;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Tests;

/// <summary>Ids created by savia/db/tests/_fixture.sql. Keep both files in step.</summary>
public static class Ids
{
    public static readonly Guid BranchA = new("A0000000-0000-0000-0000-00000000000A");
    public static readonly Guid BranchB = new("B0000000-0000-0000-0000-00000000000B");
    public static readonly Guid BranchC = new("C0000000-0000-0000-0000-00000000000C");
    public static readonly Guid LocA = new("A0000000-0000-0000-0000-0000000000A1");
    public static readonly Guid LocB = new("B0000000-0000-0000-0000-0000000000B1");
    public static readonly Guid LocC = new("C0000000-0000-0000-0000-0000000000C1");
    public static readonly Guid NodeCloud = new("00000000-0000-0000-0000-0000000C10D0");
    public static readonly Guid NodeA = new("A0000000-0000-0000-0000-0000000000A2");
    public static readonly Guid NodeB = new("B0000000-0000-0000-0000-0000000000B2");
    public static readonly Guid NodeC = new("C0000000-0000-0000-0000-0000000000C2");
    public static readonly Guid RegisterA = new("A0000000-0000-0000-0000-0000000000A3");
    public static readonly Guid RegisterB = new("B0000000-0000-0000-0000-0000000000B3");
    public static readonly Guid CashierA = new("A0000000-0000-0000-0000-0000000000A4");
    public static readonly Guid CashierB = new("B0000000-0000-0000-0000-0000000000B4");
    public static readonly Guid SupervisorA = new("A0000000-0000-0000-0000-0000000000A5");
    public static readonly Guid Manager = new("00000000-0000-0000-0000-00000000AD01");
    public static readonly Guid Supplier = new("00000000-0000-0000-0000-0000000050A1");
    public static readonly Guid Item = new("00000000-0000-0000-0000-0000000017E1");
    public const string ItemBarcode = "0000123456789";
    public const string Password = "prueba-local-2026";   // test fixture value, not a credential of any real system
}

/// <summary>Real SQL Server 2022 from the dev container. No SQL means the test fails; it is never skipped as a pass.</summary>
public static class TestSql
{
    private static readonly Lazy<string> Server = new(ResolveServer);
    public static readonly string SaviaRoot = FindRoot();

    public static string ConnectionFor(string database) =>
        new SqlConnectionStringBuilder(Server.Value) { InitialCatalog = database }.ConnectionString;

    /// <summary>Fresh database cloned from the migrated template (all migrations + the test fixture).</summary>
    public static async Task<string> CloneAsync(string label)
    {
        var name = $"SAVIA_T_{label}_{Guid.NewGuid():N}";
        await RunAsync(Python, $"\"{Path.Combine(SaviaRoot, "tools", "db", "saviadb.py")}\" clone {name}");
        return name;
    }

    public static Task DropAsync(string name) =>
        RunAsync(Python, $"\"{Path.Combine(SaviaRoot, "tools", "db", "saviadb.py")}\" drop {name}");

    public static async Task<T> ScalarAsync<T>(string database, string sql)
    {
        await using var connection = new SqlConnection(ConnectionFor(database));
        await connection.OpenAsync();
        await using var command = new SqlCommand(sql, connection);
        return (T)Convert.ChangeType((await command.ExecuteScalarAsync())!, typeof(T));
    }

    private static string Python => Environment.GetEnvironmentVariable("SAVIA_PYTHON") ?? "python";

    private static string ResolveServer()
    {
        var fromEnv = Environment.GetEnvironmentVariable("SAVIA_TEST_SQL_SERVER");
        if (!string.IsNullOrWhiteSpace(fromEnv)) return fromEnv;
        // Local development: ask the dev container. The password never leaves this process.
        var password = RunAsync("docker", "exec savia-sqlserver-dev printenv MSSQL_SA_PASSWORD").GetAwaiter().GetResult().Trim();
        var port = RunAsync("docker", "port savia-sqlserver-dev 1433/tcp").GetAwaiter().GetResult().Trim().Split(':')[^1];
        return new SqlConnectionStringBuilder
        {
            DataSource = $"127.0.0.1,{port}", UserID = "sa", Password = password,
            Encrypt = true, TrustServerCertificate = true, ConnectTimeout = 15,
        }.ConnectionString;
    }

    private static string FindRoot()
    {
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir is not null; dir = dir.Parent)
            if (File.Exists(Path.Combine(dir.FullName, "tools", "db", "saviadb.py"))) return dir.FullName;
        throw new InvalidOperationException("savia root not found from " + AppContext.BaseDirectory);
    }

    private static async Task<string> RunAsync(string file, string arguments)
    {
        using var process = Process.Start(new ProcessStartInfo(file, arguments)
        {
            RedirectStandardOutput = true, RedirectStandardError = true, UseShellExecute = false, CreateNoWindow = true,
        }) ?? throw new InvalidOperationException($"Cannot start {file}.");
        var output = process.StandardOutput.ReadToEndAsync();
        var error = process.StandardError.ReadToEndAsync();
        await process.WaitForExitAsync();
        if (process.ExitCode != 0)
            throw new InvalidOperationException(
                $"'{file}' failed (exit {process.ExitCode}). Is the dev container running? Run: python savia/tools/db/saviadb.py up. {await error}");
        return await output;
    }
}

/// <summary>One SAVIA node hosted in memory over its own database: the same program the branch PC runs.</summary>
public sealed class SaviaNode(string database, NodeKind kind, Guid nodeId, Guid? branchId, Guid? locationId)
    : WebApplicationFactory<Program>
{
    public string Database => database;

    public static SaviaNode BranchA(string database) => new(database, NodeKind.Branch, Ids.NodeA, Ids.BranchA, Ids.LocA);
    public static SaviaNode BranchB(string database) => new(database, NodeKind.Branch, Ids.NodeB, Ids.BranchB, Ids.LocB);
    public static SaviaNode Cloud(string database) => new(database, NodeKind.Cloud, Ids.NodeCloud, null, null);

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Savia:Node:Kind"] = kind.ToString(),
            ["Savia:Node:NodeId"] = nodeId.ToString(),
            ["Savia:Node:BranchId"] = branchId?.ToString(),
            ["Savia:Node:LocationId"] = locationId?.ToString(),
            ["Savia:Sql:ConnectionString"] = TestSql.ConnectionFor(database),
        }));
    }

    /// <summary>Gives a fixture staff member the test password and returns a signed-in client.</summary>
    public async Task<HttpClient> SignInAsync(Guid staffId, string loginName)
    {
        await Services.GetRequiredService<AuthService>().SetPasswordUncheckedAsync(staffId, Ids.Password, CancellationToken.None);
        var client = CreateClient();
        var response = await client.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(loginName, Ids.Password));
        response.EnsureSuccessStatusCode();
        var login = await response.Content.ReadFromJsonAsync<LoginResponse>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", login!.Token);
        return client;
    }
}

public static class HttpAssert
{
    /// <summary>Asserts the status and the stable error code of a rejected call.</summary>
    public static async Task ProblemAsync(HttpResponseMessage response, System.Net.HttpStatusCode status, string code)
    {
        var body = await response.Content.ReadAsStringAsync();
        Assert.True(response.StatusCode == status, $"expected {(int)status} {code} but got {(int)response.StatusCode}: {body}");
        var problem = System.Text.Json.JsonSerializer.Deserialize<ProblemResponse>(body, new System.Text.Json.JsonSerializerOptions(System.Text.Json.JsonSerializerDefaults.Web));
        Assert.Equal(code, problem!.Code);
    }

    public static async Task<T> OkAsync<T>(HttpResponseMessage response)
    {
        var body = await response.Content.ReadAsStringAsync();
        Assert.True(response.IsSuccessStatusCode, $"expected success but got {(int)response.StatusCode}: {body}");
        return System.Text.Json.JsonSerializer.Deserialize<T>(body, new System.Text.Json.JsonSerializerOptions(System.Text.Json.JsonSerializerDefaults.Web))!;
    }

    public static async Task OkAsync(HttpResponseMessage response)
    {
        var body = await response.Content.ReadAsStringAsync();
        Assert.True(response.IsSuccessStatusCode, $"expected success but got {(int)response.StatusCode}: {body}");
    }
}
