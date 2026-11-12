using System.Net;
using System.Net.Http.Json;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Savia.Api;
using Savia.Application;
using Savia.Contracts;
using Microsoft.Extensions.DependencyInjection;

namespace Savia.Tests;

[CollectionDefinition("Pilot provisioning environment", DisableParallelization = true)]
public sealed class PilotProvisioningEnvironment;

[Collection("Pilot provisioning environment")]
public sealed class PilotProvisioningTests
{
    [Fact]
    public async Task Per_login_passwords_shared_opt_in_and_check_only_preserve_existing_hashes()
    {
        var db = await TestSql.CloneAsync("pilot_passwords");
        var keys = new[] { "SAVIA_PILOT_PASSWORD", "SAVIA_PILOT_ALLOW_SHARED", "SAVIA_PILOT_PASSWORD_CAJERA", "SAVIA_PILOT_PASSWORD_SUPERVISORA", "SAVIA_PILOT_PASSWORD_DUENA" };
        var saved = keys.ToDictionary(k => k, Environment.GetEnvironmentVariable);
        try
        {
            foreach (var key in keys) Environment.SetEnvironmentVariable(key, null);
            await using var c = new SqlConnection(TestSql.ConnectionFor(db)); await c.OpenAsync();
            await using var rename = new SqlCommand($"""
                UPDATE security.Staff SET LoginName=N'cajera.muestra',NormalizedLoginName=N'CAJERA.MUESTRA' WHERE Id='{Ids.CashierA}';
                UPDATE security.Staff SET LoginName=N'supervisora.muestra',NormalizedLoginName=N'SUPERVISORA.MUESTRA' WHERE Id='{Ids.SupervisorA}';
                UPDATE security.Staff SET LoginName=N'duena.muestra',NormalizedLoginName=N'DUENA.MUESTRA' WHERE Id='{Ids.Manager}';
                """, c);
            await rename.ExecuteNonQueryAsync();
            await using var node = SaviaNode.BranchA(db);
            var config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
            { ["Savia:Provision:Logins"] = "cajera.muestra,supervisora.muestra,duena.muestra", ["Savia:Provision:CheckOnly"] = "true" }).Build();
            Assert.Equal(1, await Provisioning.RunAsync(node.Services, config)); // no hashes yet
            config["Savia:Provision:CheckOnly"] = "false";
            var passwords = Enumerable.Range(0, 3).Select(_ => Guid.NewGuid().ToString("N")).ToArray();
            Environment.SetEnvironmentVariable("SAVIA_PILOT_PASSWORD", passwords[0]);
            Assert.Equal(2, await Provisioning.RunAsync(node.Services, config)); // shared fallback explicitly refused
            Environment.SetEnvironmentVariable("SAVIA_PILOT_PASSWORD", null);
            for (var i = 0; i < 3; i++) Environment.SetEnvironmentVariable(keys[i + 2], passwords[i]);
            Assert.Equal(0, await Provisioning.RunAsync(node.Services, config));
            var logins = new[] { "cajera.muestra", "supervisora.muestra", "duena.muestra" };
            for (var i = 0; i < 3; i++)
            {
                await HttpAssert.OkAsync(await node.CreateClient().PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(logins[i], passwords[i])));
                await HttpAssert.ProblemAsync(await node.CreateClient().PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(logins[i], passwords[(i + 1) % 3])), HttpStatusCode.Unauthorized, "auth.bad_credentials");
            }
            var store = node.Services.GetRequiredService<IAuthStore>();
            var before = await store.FindStaffAsync("CAJERA.MUESTRA", default);
            Assert.Equal(0, await Provisioning.RunAsync(node.Services, config));
            config["Savia:Provision:CheckOnly"] = "true";
            foreach (var key in keys) Environment.SetEnvironmentVariable(key, Guid.NewGuid().ToString("N"));
            Assert.Equal(0, await Provisioning.RunAsync(node.Services, config));
            var after = await store.FindStaffAsync("CAJERA.MUESTRA", default);
            Assert.True(before!.PasswordHash == after!.PasswordHash && before.SecurityVersion == after.SecurityVersion,
                "check-only and unchanged provisioning must preserve hash and security version");
            config["Savia:Provision:CheckOnly"] = "false";
            Environment.SetEnvironmentVariable("SAVIA_PILOT_ALLOW_SHARED", "1");
            foreach (var key in keys.Skip(2)) Environment.SetEnvironmentVariable(key, null);
            Assert.Equal(0, await Provisioning.RunAsync(node.Services, config));
        }
        finally
        {
            foreach (var (key, value) in saved) Environment.SetEnvironmentVariable(key, value);
            await TestSql.DropAsync(db);
        }
    }
}
