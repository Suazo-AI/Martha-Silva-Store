using System.Net;
using System.Net.Http.Json;
using Savia.Contracts;

namespace Savia.Tests;

/// <summary>
/// LOGIN-06, LOGIN-07 and LOGIN-08 (docs/public-software/LOGIN-RULES.md): five wrong passwords lock an account for 15 minutes.
/// When a lock has ended, counting starts again, so one more wrong password does not lock again, and repeated lock
/// cycles never push the counter past the CK_Staff_Failed limit (0 to 20). Test passwords are fixture values.
/// </summary>
public sealed class SignInLockoutTests : IAsyncLifetime
{
    private string _database = "";

    public async Task InitializeAsync() => _database = await TestSql.CloneAsync("lockout");

    public async Task DisposeAsync() => await TestSql.DropAsync(_database);

    private Task<int> FailuresAsync() =>
        TestSql.ScalarAsync<int>(_database, $"SELECT FailedSignIns FROM security.Staff WHERE Id='{Ids.CashierA}'");

    private Task<int> LockedAsync() => TestSql.ScalarAsync<int>(_database,
        $"SELECT COUNT(*) FROM security.Staff WHERE Id='{Ids.CashierA}' AND LockedUntil>SYSUTCDATETIME()");

    // The lock ends as if 15 minutes had passed.
    private Task EndLockAsync() => TestSql.ScalarAsync<int>(_database,
        $"UPDATE security.Staff SET LockedUntil=DATEADD(minute,-1,SYSUTCDATETIME()) WHERE Id='{Ids.CashierA}'; SELECT 1;");

    [Fact]
    public async Task An_ended_lock_starts_a_fresh_count_and_repeated_cycles_never_break_the_counter_limit()
    {
        await using var store = SaviaNode.BranchA(_database);
        await store.SignInAsync(Ids.CashierA, "t_cashier_a");   // gives the fixture account its password
        var client = store.CreateClient();
        var wrong = new LoginRequest("t_cashier_a", "no-es-la-clave");

        // 25 wrong passwords; every lock is ended at once, as if 15 minutes had passed. Before the fix the counter kept
        // climbing, so the 21st counted failure broke CK_Staff_Failed and the sign-in answered 409 db.reference.
        var locks = 0;
        for (var attempt = 1; attempt <= 25; attempt++)
        {
            await HttpAssert.ProblemAsync(await client.PostAsJsonAsync("/api/v1/auth/login", wrong),
                HttpStatusCode.Unauthorized, "auth.bad_credentials");
            Assert.InRange(await FailuresAsync(), 1, 5);
            if (await LockedAsync() == 1) { locks++; await EndLockAsync(); }
        }
        Assert.Equal(5, locks);

        // After an ended lock, one wrong password counts 1 and does not lock again.
        await HttpAssert.ProblemAsync(await client.PostAsJsonAsync("/api/v1/auth/login", wrong),
            HttpStatusCode.Unauthorized, "auth.bad_credentials");
        Assert.Equal(1, await FailuresAsync());
        Assert.Equal(0, await LockedAsync());

        await HttpAssert.OkAsync<LoginResponse>(await client.PostAsJsonAsync("/api/v1/auth/login",
            new LoginRequest("t_cashier_a", Ids.Password)));
        Assert.Equal(0, await FailuresAsync());
    }
}
