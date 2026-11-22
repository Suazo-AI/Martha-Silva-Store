using System.Collections.Concurrent;
using System.Security.Cryptography;
using Microsoft.Data.SqlClient;

namespace Savia.Tests;

/// <summary>
/// A SQL login whose only database permission is membership of <c>savia_api_host</c> (migration V035), the role the
/// hub API runs with in Azure. Test setup and assertions keep using sa; with <see cref="Variable"/> set to
/// <see cref="Value"/>, every hosted node connects with this login, so the run proves the role is enough.
/// </summary>
public static class ApiHostLogin
{
    public const string Variable = "SAVIA_TEST_SQL_LOGIN";
    public const string Value = "api_host";
    public const string Role = "savia_api_host";

    private static readonly Lazy<(string Name, string Password)> Login = new(Create);
    private static readonly ConcurrentDictionary<string, bool> Users = new();

    /// <summary>True when this test run hosts every node with the restricted login.</summary>
    public static bool Selected
    {
        get
        {
            var value = Environment.GetEnvironmentVariable(Variable);
            if (string.IsNullOrEmpty(value)) return false;
            // A typo must not fall back to sa and pass silently.
            return value == Value ? true : throw new InvalidOperationException($"{Variable} accepts only '{Value}', not '{value}'.");
        }
    }

    public static string Name => Login.Value.Name;

    /// <summary>Connection to <paramref name="database"/> as the restricted login.</summary>
    public static string ConnectionFor(string database)
    {
        AddUser(database);
        var (name, password) = Login.Value;
        return new SqlConnectionStringBuilder(TestSql.ConnectionFor(database)) { UserID = name, Password = password }.ConnectionString;
    }

    /// <summary>Creates the login's user in <paramref name="database"/> as a member of the role; once per database.</summary>
    public static void AddUser(string database) => Users.GetOrAdd(database, db =>
    {
        var name = Login.Value.Name;
        Exec(db, $"CREATE USER [{name}] FOR LOGIN [{name}]; ALTER ROLE [{Role}] ADD MEMBER [{name}];");
        return true;
    });

    // One login per test process, so parallel runs never share a password. Dropped when the process ends.
    private static (string, string) Create()
    {
        var name = "savia_t_api_" + Guid.NewGuid().ToString("N")[..12];
        var password = "Aa1!" + Convert.ToHexString(RandomNumberGenerator.GetBytes(24));
        Exec("master", $"CREATE LOGIN [{name}] WITH PASSWORD = N'{password}', CHECK_POLICY = OFF, DEFAULT_DATABASE = [master];");
        AppDomain.CurrentDomain.ProcessExit += (_, _) => Drop(name);
        return (name, password);
    }

    private static void Drop(string name)
    {
        SqlConnection.ClearAllPools();
        Exec("master", $"IF SUSER_ID(N'{name}') IS NOT NULL DROP LOGIN [{name}];");
    }

    private static void Exec(string database, string sql)
    {
        using var connection = new SqlConnection(TestSql.ConnectionFor(database));
        connection.Open();
        using var command = new SqlCommand(sql, connection);
        command.ExecuteNonQuery();
    }
}
