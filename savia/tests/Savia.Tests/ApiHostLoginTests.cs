using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace Savia.Tests;

/// <summary>
/// The restricted login behind <see cref="ApiHostLogin"/> really is restricted, and it sees the same sync metadata as sa.
/// Catalog views and metadata functions return nothing instead of failing when a permission is missing, so a
/// passing sync run alone would not prove this.
/// </summary>
public sealed class ApiHostLoginTests
{
    [Fact]
    public async Task Login_is_only_a_member_of_the_api_host_role()
    {
        var database = await TestSql.CloneAsync("apihost");
        try
        {
            await using var connection = new SqlConnection(ApiHostLogin.ConnectionFor(database));
            await connection.OpenAsync();
            await using var command = new SqlCommand(
                "SELECT CONCAT(IS_SRVROLEMEMBER('sysadmin'),IS_MEMBER('db_owner'),IS_MEMBER('db_datawriter'),IS_MEMBER('db_ddladmin'),"
                + "IS_MEMBER('savia_api_host'),HAS_PERMS_BY_NAME(DB_NAME(),'DATABASE','ALTER'),"
                + "HAS_PERMS_BY_NAME('sales.Sales','OBJECT','DELETE'));", connection);
            Assert.Equal("0000100", (string)(await command.ExecuteScalarAsync())!);
        }
        finally
        {
            SqlConnection.ClearAllPools();
            await TestSql.DropAsync(database);
        }
    }

    [Fact]
    public async Task Login_sees_the_same_sync_metadata_as_sa()
    {
        var database = await TestSql.CloneAsync("apihostmeta");
        try
        {
            const string shape = "SELECT CONCAT(COUNT(*),':',SUM(CASE WHEN SelectList IS NULL OR WithList IS NULL OR InsList IS NULL "
                                 + "OR ValList IS NULL OR OnList IS NULL OR CtOnList IS NULL THEN 1 ELSE 0 END)) FROM sync.fn_TableShape();";
            var asSa = TestSql.ConnectionFor(database);
            var asRole = ApiHostLogin.ConnectionFor(database);
            await SyncFixture.ExecAsync(database, $"EXEC sync.usp_SetLocalNode @NodeId='{Ids.NodeA}';");

            Assert.Equal("20:0", await ScalarAsync(asSa, shape));
            Assert.Equal(await ScalarAsync(asSa, shape), await ScalarAsync(asRole, shape));
            Assert.Equal(await SourceStateAsync(asSa), await SourceStateAsync(asRole));
        }
        finally
        {
            SqlConnection.ClearAllPools();
            await TestSql.DropAsync(database);
        }
    }

    [Fact]
    public async Task Hosted_node_connects_with_the_login_the_run_selected()
    {
        var database = await TestSql.CloneAsync("apihostnode");
        try
        {
            await using (var node = SaviaNode.BranchA(database))
            {
                var configured = node.Services.GetRequiredService<IConfiguration>()["Savia:Sql:ConnectionString"];
                Assert.Equal(ApiHostLogin.Selected ? ApiHostLogin.Name : "sa", new SqlConnectionStringBuilder(configured).UserID);
            }
        }
        finally
        {
            SqlConnection.ClearAllPools();
            await TestSql.DropAsync(database);
        }
    }

    private static async Task<string> ScalarAsync(string connectionString, string sql)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = new SqlCommand(sql, connection);
        return Convert.ToString(await command.ExecuteScalarAsync())!;
    }

    private static async Task<string> SourceStateAsync(string connectionString)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync();
        await using var command = new SqlCommand("sync.usp_SourceStateJson", connection) { CommandType = CommandType.StoredProcedure };
        var json = command.Parameters.Add("@Json", SqlDbType.NVarChar, -1);
        json.Direction = ParameterDirection.Output;
        await command.ExecuteNonQueryAsync();
        return (string)json.Value;
    }
}
