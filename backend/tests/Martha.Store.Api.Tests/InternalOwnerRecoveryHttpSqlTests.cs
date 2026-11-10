using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Martha.Store.Api.Internal;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Xunit;
using static Martha.Store.Api.Tests.InternalJudgeTests;

namespace Martha.Store.Api.Tests;

// P-OWNER items 1 and 6: two distinct enabled Owners, and recovery of the lost Owner through
// the existing authorized API path. Real Program, real cookie login, real antiforgery, a real
// database built with the real Internal migrations, and independent SQL reads before and after.
// Synthetic identities only; no credential is printed and no account outside the disposable
// fixture database is created.
public sealed class InternalOwnerRecoveryHttpSqlTests
{
    private const string SecondOwnerLogin = "owner.second";
    private const string ManagerLogin = "manager.negative";
    private const string NewPassword = "synthetic-replacement-input-only";

    [InternalJudgeHttpSqlFact]
    public async Task F14_second_owner_recovers_the_first_owner_through_the_authorized_api_path()
    {
        await using var database = await InternalCommerceSqlDatabase.Create(migrate: true);
        var connection = await PrepareHttpFixture(database);
        var now = DateTimeOffset.UtcNow;
        var targetId = database.Actor;
        Guid secondId;
        await using (var context = database.Context())
        {
            var second = new InternalStaff
            {
                Id = Guid.NewGuid(),
                LoginName = SecondOwnerLogin,
                NormalizedLoginName = SecondOwnerLogin.ToUpperInvariant(),
                DisplayName = "Synthetic second Owner",
                Role = "Owner",
                Enabled = true,
                SecurityVersion = Guid.NewGuid(),
                CreatedAt = now,
                UpdatedAt = now
            };
            second.PasswordHash = new PasswordHasher<InternalStaff>().HashPassword(second, HttpFixturePassword);
            context.Add(second);
            secondId = second.Id;
            var manager = new InternalStaff
            {
                Id = Guid.NewGuid(),
                LoginName = ManagerLogin,
                NormalizedLoginName = ManagerLogin.ToUpperInvariant(),
                DisplayName = "Synthetic Manager",
                Role = "Manager",
                Enabled = true,
                SecurityVersion = Guid.NewGuid(),
                CreatedAt = now,
                UpdatedAt = now
            };
            manager.PasswordHash = new PasswordHasher<InternalStaff>().HashPassword(manager, HttpFixturePassword);
            context.Add(manager);
            await context.SaveChangesAsync();
        }

        await using var factory = new JudgeFactory(connection: connection);
        using var custodian = new HttpSession(Client(factory));
        using var lost = new HttpSession(Client(factory));
        using var negative = new HttpSession(Client(factory));
        await SignIn(lost, "disposable.test.owner");
        await SignIn(custodian, SecondOwnerLogin);
        await SignIn(negative, ManagerLogin);
        var token = await Csrf(custodian);

        // Independent SQL state before the operation.
        var before = await OwnerRecoveryOracle.Capture(connection, targetId);
        var targetBefore = await TargetRow(connection, targetId);
        var secondBefore = await TargetRow(connection, secondId);
        Assert.NotEqual(Guid.Empty, targetBefore.SecurityVersion);

        using (var reset = await custodian.Send(HttpMethod.Post, $"/internal/api/security/staff/{targetId}/password",
            new { password = NewPassword, version = targetBefore.SecurityVersion }, token))
        {
            Assert.Equal(HttpStatusCode.OK, reset.StatusCode);
        }

        // The security change is exactly the reviewed one; business data is preserved.
        var targetAfter = await TargetRow(connection, targetId);
        var secondAfter = await TargetRow(connection, secondId);
        Assert.NotEqual(targetBefore.PasswordHash, targetAfter.PasswordHash);
        Assert.NotEqual(targetBefore.SecurityVersion, targetAfter.SecurityVersion);
        Assert.NotEqual(Guid.Empty, targetAfter.SecurityVersion);
        Assert.Equal(0, targetAfter.FailedSignIns);
        Assert.Null(targetAfter.LockedUntil);
        Assert.Equal("Owner", targetAfter.Role);
        Assert.True(targetAfter.Enabled);
        // The recovering Owner is untouched.
        Assert.Equal(secondBefore.PasswordHash, secondAfter.PasswordHash);
        Assert.Equal(secondBefore.SecurityVersion, secondAfter.SecurityVersion);
        // Only the excluded security columns of the lost Owner may differ.
        var after = await OwnerRecoveryOracle.Capture(connection, targetId);
        foreach (var table in before.Keys.Where(table => table is not "Sessions"))
            Assert.Equal(before[table], after[table]);
        // Every session of the lost Owner is revoked.
        Assert.Equal("0", await Scalar(connection, $"SELECT COUNT(*) FROM savia_internal.Sessions WHERE StaffId='{targetId}' AND RevokedAt IS NULL"));

        // The old password and the old session stop working; the new password works.
        using (var refused = await lost.Send(HttpMethod.Post, "/internal/api/security/login",
            new { loginName = "disposable.test.owner", password = HttpFixturePassword }, await Csrf(lost)))
            Assert.Equal(HttpStatusCode.Unauthorized, refused.StatusCode);
        using (var dead = await lost.Send(HttpMethod.Get, "/internal/api/security/me"))
            Assert.Equal(HttpStatusCode.Unauthorized, dead.StatusCode);
        using var fresh = new HttpSession(Client(factory));
        await SignIn(fresh, "disposable.test.owner", NewPassword);
        using (var me = await fresh.Send(HttpMethod.Get, "/internal/api/security/me"))
        {
            Assert.Equal(HttpStatusCode.OK, me.StatusCode);
            var body = await me.Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal(targetId, body.GetProperty("id").GetGuid());
        }
        // The recovering Owner keeps working.
        using (var custodianMe = await custodian.Send(HttpMethod.Get, "/internal/api/security/me"))
            Assert.Equal(HttpStatusCode.OK, custodianMe.StatusCode);
        // Normal permission checks still apply: a Manager may not reset an Owner password.
        using (var forbidden = await negative.Send(HttpMethod.Post, $"/internal/api/security/staff/{targetId}/password",
            new { password = "another-synthetic-input-only", version = targetAfter.SecurityVersion }, await Csrf(negative)))
            Assert.Equal(HttpStatusCode.Forbidden, forbidden.StatusCode);
        // That refusal wrote nothing.
        Assert.Equal(targetAfter.PasswordHash, (await TargetRow(connection, targetId)).PasswordHash);
    }

    private static HttpClient Client(WebApplicationFactory<Program> factory) => factory.CreateClient(new WebApplicationFactoryClientOptions
    { BaseAddress = new Uri("https://localhost"), AllowAutoRedirect = false, HandleCookies = false });

    private static async Task SignIn(HttpSession session, string loginName, string password = HttpFixturePassword)
    {
        var token = await Csrf(session);
        using var response = await session.Send(HttpMethod.Post, "/internal/api/security/login", new { loginName, password }, token);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    private static async Task<(string PasswordHash, Guid SecurityVersion, int FailedSignIns, DateTimeOffset? LockedUntil, string Role, bool Enabled)> TargetRow(string connection, Guid staffId)
    {
        await using var sql = new SqlConnection(connection);
        await sql.OpenAsync();
        await using var command = sql.CreateCommand();
        command.CommandText = "SELECT PasswordHash, SecurityVersion, FailedSignIns, LockedUntil, Role, Enabled FROM savia_internal.Staff WHERE Id=@id";
        command.Parameters.AddWithValue("@id", staffId);
        await using var reader = await command.ExecuteReaderAsync();
        Assert.True(await reader.ReadAsync());
        return (reader.GetString(0), reader.GetGuid(1), reader.GetInt32(2),
            reader.IsDBNull(3) ? null : reader.GetFieldValue<DateTimeOffset>(3), reader.GetString(4), reader.GetBoolean(5));
    }

    private static async Task<string> Scalar(string connection, string sql)
    {
        await using var text = new SqlConnection(connection);
        await text.OpenAsync();
        await using var command = text.CreateCommand();
        command.CommandText = sql;
        return Convert.ToString(await command.ExecuteScalarAsync())!;
    }
}
