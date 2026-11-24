using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.Data.SqlClient;
using Savia.Contracts;

namespace Savia.Tests;

/// <summary>
/// V064, DAY-ZERO.md gap 2: staff change their own password over HTTP; a one-time password must be replaced before any
/// other route answers. Test passwords are fixture values, not credentials of any real system.
/// </summary>
public sealed class PasswordChangeTests : IAsyncLifetime
{
    private const string Next = "otra-clave-local-2026";
    private string _database = "";

    public async Task InitializeAsync() => _database = await TestSql.CloneAsync("password");

    public async Task DisposeAsync() => await TestSql.DropAsync(_database);

    private static async Task<(HttpClient Client, LoginResponse Login)> LoginAsync(SaviaNode node, string login, string password)
    {
        var client = node.CreateClient();
        var login1 = await HttpAssert.OkAsync<LoginResponse>(await client.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest(login, password)));
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", login1.Token);
        return (client, login1);
    }

    private Task<int> StaffAsync(string column) =>
        TestSql.ScalarAsync<int>(_database, $"SELECT CAST({column} AS int) FROM security.Staff WHERE Id='{Ids.CashierA}'");

    [Fact]
    public async Task A_change_keeps_this_session_ends_the_others_and_only_the_new_password_signs_in()
    {
        await using var store = SaviaNode.BranchA(_database);
        var mine = await store.SignInAsync(Ids.CashierA, "t_cashier_a");
        var (other, _) = await LoginAsync(store, "t_cashier_a", Ids.Password);

        Assert.Equal(HttpStatusCode.NoContent,
            (await mine.PostAsJsonAsync("/api/v1/auth/password", new ChangePasswordRequest(Ids.Password, Next))).StatusCode);

        await HttpAssert.OkAsync(await mine.GetAsync("/api/v1/me"));
        Assert.Equal(HttpStatusCode.Unauthorized, (await other.GetAsync("/api/v1/me")).StatusCode);
        var anonymous = store.CreateClient();
        await HttpAssert.ProblemAsync(await anonymous.PostAsJsonAsync("/api/v1/auth/login", new LoginRequest("t_cashier_a", Ids.Password)),
            HttpStatusCode.Unauthorized, "auth.bad_credentials");
        await LoginAsync(store, "t_cashier_a", Next);
    }

    [Fact]
    public async Task A_wrong_current_password_is_refused_and_counts_toward_the_lockout()
    {
        await using var store = SaviaNode.BranchA(_database);
        var mine = await store.SignInAsync(Ids.CashierA, "t_cashier_a");
        await HttpAssert.ProblemAsync(await mine.PostAsJsonAsync("/api/v1/auth/password", new ChangePasswordRequest(Ids.Password, "corta")),
            HttpStatusCode.UnprocessableEntity, "auth.weak_password");
        await HttpAssert.ProblemAsync(await mine.PostAsJsonAsync("/api/v1/auth/password", new ChangePasswordRequest(Ids.Password, Ids.Password)),
            HttpStatusCode.UnprocessableEntity, "auth.password_unchanged");
        Assert.Equal(0, await StaffAsync("FailedSignIns"));

        var wrong = new ChangePasswordRequest("no-es-la-clave", Next);
        for (var attempt = 1; attempt <= 5; attempt++)
        {
            await HttpAssert.ProblemAsync(await mine.PostAsJsonAsync("/api/v1/auth/password", wrong), HttpStatusCode.Forbidden,
                "auth.current_password_wrong");
            Assert.Equal(attempt, await StaffAsync("FailedSignIns"));
        }
        Assert.Equal(1, await TestSql.ScalarAsync<int>(_database,
            $"SELECT COUNT(*) FROM security.Staff WHERE Id='{Ids.CashierA}' AND LockedUntil>SYSUTCDATETIME()"));
        await HttpAssert.ProblemAsync(await mine.PostAsJsonAsync("/api/v1/auth/password", new ChangePasswordRequest(Ids.Password, Next)),
            HttpStatusCode.Forbidden, "auth.locked");
        await HttpAssert.ProblemAsync(await store.CreateClient().PostAsJsonAsync("/api/v1/auth/login", new LoginRequest("t_cashier_a", Ids.Password)),
            HttpStatusCode.Unauthorized, "auth.bad_credentials");
    }

    [Fact]
    public async Task A_marked_account_signs_in_but_reaches_only_the_change_logout_and_me_until_it_changes_the_password()
    {
        await using var store = SaviaNode.BranchA(_database);
        var mine = await store.SignInAsync(Ids.CashierA, "t_cashier_a");
        await TestSql.ScalarAsync<int>(_database, $"UPDATE security.Staff SET MustChangePassword=1 WHERE Id='{Ids.CashierA}'; SELECT 1;");

        var (other, login) = await LoginAsync(store, "t_cashier_a", Ids.Password);
        Assert.True(login.MustChangePassword);
        Assert.True((await HttpAssert.OkAsync<MeResponse>(await mine.GetAsync("/api/v1/me"))).MustChangePassword);
        await HttpAssert.ProblemAsync(await mine.GetAsync("/api/v1/catalog/items"), HttpStatusCode.Forbidden, "auth.password_change_required");
        await HttpAssert.ProblemAsync(await mine.GetAsync("/api/v1/sync/status"), HttpStatusCode.Forbidden, "auth.password_change_required");
        await HttpAssert.OkAsync(await other.PostAsync("/api/v1/auth/logout", null));

        Assert.Equal(HttpStatusCode.NoContent,
            (await mine.PostAsJsonAsync("/api/v1/auth/password", new ChangePasswordRequest(Ids.Password, Next))).StatusCode);
        Assert.Equal(0, await StaffAsync("MustChangePassword"));
        Assert.False((await HttpAssert.OkAsync<MeResponse>(await mine.GetAsync("/api/v1/me"))).MustChangePassword);
        await HttpAssert.OkAsync(await mine.GetAsync("/api/v1/catalog/items"));
        Assert.False((await LoginAsync(store, "t_cashier_a", Next)).Login.MustChangePassword);
    }
}

/// <summary>
/// Savia.Migrator provisioning output against SQL: what reaches stdout (Log Analytics on Azure) and what reaches the row.
/// Runs as the migrator does, with the administrative connection.
/// </summary>
public sealed class ProvisioningOutputTests : IAsyncLifetime
{
    private string _database = "";

    public async Task InitializeAsync() => _database = await TestSql.CloneAsync("provision_out");

    public async Task DisposeAsync() => await TestSql.DropAsync(_database);

    private async Task<string> RunAsync(Func<SqlConnection, TextWriter, Task> action)
    {
        await using var sql = new SqlConnection(TestSql.ConnectionFor(_database));
        await sql.OpenAsync();
        var output = new StringWriter();
        await action(sql, output);
        return output.ToString();
    }

    private Task<string> StoredHashAsync() =>
        TestSql.ScalarAsync<string>(_database,
            $"SELECT CONVERT(varchar(64),SecretHash,2) FROM sync.NodeCredentials WHERE NodeId='{Ids.NodeA}' AND RevokedAt IS NULL");

    [Fact]
    public async Task A_node_secret_from_the_variable_is_stored_as_its_hash_and_never_printed()
    {
        var rotate = new NodeRequest("rotate", Ids.NodeA, "branch", null, null);
        var secret = NodeRequest.NewSecret();
        var output = await RunAsync((sql, writer) => rotate.ReportAsync(sql, secret, writer));
        Assert.DoesNotContain(secret, output);
        Assert.DoesNotContain(NodeRequest.SecretPrefix, output);
        Assert.Contains($"credential from {NodeRequest.SecretVariable} (not printed)", output);
        Assert.Equal(Convert.ToHexString(NodeRequest.Hash(secret)), await StoredHashAsync());

        foreach (var weak in new[] { "corta", new string('a', 43), secret + ".x" })
        {
            var refused = await Assert.ThrowsAsync<InvalidOperationException>(() => RunAsync((sql, writer) => rotate.ReportAsync(sql, weak, writer)));
            Assert.DoesNotContain(weak, refused.Message);
        }
        Assert.Equal(Convert.ToHexString(NodeRequest.Hash(secret)), await StoredHashAsync());

        var generated = (await RunAsync((sql, writer) => rotate.ReportAsync(sql, null, writer)))
            .Split('\n').Select(line => line.TrimEnd('\r')).Single(line => line.StartsWith(NodeRequest.SecretPrefix));
        Assert.Equal(Convert.ToHexString(NodeRequest.Hash(generated[NodeRequest.SecretPrefix.Length..])), await StoredHashAsync());
    }

    [Fact]
    public async Task A_given_staff_password_is_not_printed_or_marked_and_a_generated_one_is_printed_once_and_marked()
    {
        const string given = "clave-dada-local-2026";
        var staff = new StaffRequest(Guid.NewGuid(), "t_dada_out", "Dada", "CASHIER", null, false, true);
        var output = await RunAsync((sql, writer) => staff.ReportAsync(sql, given, writer));
        Assert.DoesNotContain(given, output);
        Assert.DoesNotContain(StaffRequest.PasswordPrefix, output);
        Assert.Equal(0, await TestSql.ScalarAsync<int>(_database,
            $"SELECT CAST(MustChangePassword AS int) FROM security.Staff WHERE Id='{staff.StaffId}'"));

        var once = new StaffRequest(Guid.NewGuid(), "t_unica_out", "Unica", "CASHIER", null, false, true);
        output = await RunAsync((sql, writer) => once.ReportAsync(sql, null, writer));
        Assert.Single(output.Split('\n'), line => line.StartsWith(StaffRequest.PasswordPrefix));
        Assert.Equal(1, await TestSql.ScalarAsync<int>(_database,
            $"SELECT CAST(MustChangePassword AS int) FROM security.Staff WHERE Id='{once.StaffId}'"));
    }
}
