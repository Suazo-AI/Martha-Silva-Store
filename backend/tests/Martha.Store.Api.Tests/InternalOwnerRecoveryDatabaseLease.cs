using System.Text.Json;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Martha.Store.Api.Tests;

// Fixture-only ownership. CREATE acknowledgement loss never grants permission to delete an untagged database.
internal sealed class OwnerRecoveryDatabaseLease : IAsyncDisposable
{
    private readonly string admin, name, nonce=Guid.NewGuid().ToString("N"), intent;
    private Guid? databaseGuid;
    private string? sqlSid;
    private bool ownedRestoreIntent;
    private OwnerRecoveryDatabaseLease(string admin,string name,string directory)
    { this.admin=admin;this.name=name;intent=Path.Combine(directory,name+".ownership.jsonl"); }
    private void Record(string state)
    {
        using var file=new FileStream(intent,FileMode.Append,FileAccess.Write,FileShare.Read,4096,FileOptions.WriteThrough);
        var bytes=JsonSerializer.SerializeToUtf8Bytes(new {name,nonce,databaseGuid,sqlSid,state,utc=DateTimeOffset.UtcNow});
        file.Write(bytes);file.WriteByte(10);file.Flush(true);
    }
    public static async Task<OwnerRecoveryDatabaseLease> Create(string admin,string name)
    {
        if(!OperatingSystem.IsWindows())throw new PlatformNotSupportedException();
        var policy=new SqlConnectionStringBuilder(admin);
        if(!policy.IntegratedSecurity || policy.TrustServerCertificate || policy.MultipleActiveResultSets
            || (policy.Encrypt!=SqlConnectionEncryptOption.Mandatory && policy.Encrypt!=SqlConnectionEncryptOption.Strict))throw new InvalidOperationException();
        if(!System.Text.RegularExpressions.Regex.IsMatch(name,@"\ASaviaInternalTest_Recovery_[a-f0-9]{32}\z"))throw new InvalidOperationException();
        var directory=Environment.GetEnvironmentVariable("SAVIA_OWNER_RECOVERY_EVIDENCE_DIRECTORY")??throw new InvalidOperationException("Pre-existing private evidence directory required.");
        if(!Directory.Exists(directory))throw new InvalidOperationException();
        var lease=new OwnerRecoveryDatabaseLease(admin,name,directory);
        // CreateNew prevents replacing evidence belonging to a previous run.
        using(var file=new FileStream(lease.intent,FileMode.CreateNew,FileAccess.Write,FileShare.Read))file.Flush(true);
        await using var c=new SqlConnection(admin);await c.OpenAsync();
        await using(var cmd=c.CreateCommand())
        {cmd.CommandText="SELECT COUNT(*) FROM sys.databases WHERE name=@name";cmd.Parameters.AddWithValue("@name",name);Assert.Equal(0,Convert.ToInt32(await cmd.ExecuteScalarAsync()));}
        await using(var cmd=c.CreateCommand())
        {cmd.CommandText="SELECT SUSER_SID()";lease.sqlSid=Convert.ToHexString((byte[])(await cmd.ExecuteScalarAsync()??throw new InvalidOperationException()));}
        lease.Record("ABSENT_CREATE_INTENT");
        try
        {
            await using var cmd=c.CreateCommand();
            cmd.CommandText=$"CREATE DATABASE [{name}]; EXEC [{name}].sys.sp_addextendedproperty @name=N'SAVIA_RECOVERY_FIXTURE_OWNER',@value=@nonce;";
            cmd.Parameters.AddWithValue("@nonce",lease.nonce);await cmd.ExecuteNonQueryAsync();
            await lease.Reconcile(c);lease.Record("OWNED");return lease;
        }
        catch
        {
            try {lease.Record("CREATE_UNKNOWN");}catch { /* Preserve the original error and durable pre-CREATE intent. */ }
            // One readback, no CREATE retry. Only an exact nonce permits owned cleanup.
            try {await lease.Reconcile(c);await lease.DisposeAsync();}
            catch {try {lease.Record("RETAINED_UNKNOWN_REQUIRES_REVIEW");}catch { }}
            throw;
        }
    }
    private async Task Reconcile(SqlConnection c,bool afterOwnedRestore=false)
    {
        await using(var identity=c.CreateCommand())
        {identity.CommandText="SELECT SUSER_SID()";Assert.Equal(sqlSid,Convert.ToHexString((byte[])(await identity.ExecuteScalarAsync()??throw new InvalidOperationException())));}
        await using var cmd=c.CreateCommand();
        cmd.CommandText=$"SELECT CONVERT(nvarchar(32),value),(SELECT database_guid FROM sys.database_recovery_status WHERE database_id=DB_ID(@name)) FROM [{name}].sys.extended_properties WHERE class=0 AND name=N'SAVIA_RECOVERY_FIXTURE_OWNER'";
        cmd.Parameters.AddWithValue("@name",name);
        await using var r=await cmd.ExecuteReaderAsync();
        if(!await r.ReadAsync() || r.GetString(0)!=nonce || r.IsDBNull(1))throw new InvalidOperationException("Ownership unresolved; retain database.");
        var actual=r.GetGuid(1);if(databaseGuid is not null && actual!=databaseGuid && !afterOwnedRestore)throw new InvalidOperationException();
        databaseGuid=actual;if(await r.ReadAsync())throw new InvalidOperationException();
    }
    public async Task BeginOwnedRestore()
    {
        await using var c=new SqlConnection(admin);await c.OpenAsync();await Reconcile(c);
        Record("OWNED_RESTORE_INTENT");ownedRestoreIntent=true;
    }
    public async Task ReadOwnedRestore()
    {
        if(!ownedRestoreIntent)throw new InvalidOperationException();
        await using var c=new SqlConnection(admin);await c.OpenAsync();
        // RESTORE can replace the database GUID. The copied exact nonce must still be present.
        await Reconcile(c,true);Record("OWNED_RESTORE_READBACK");ownedRestoreIntent=false;
    }
    public async ValueTask DisposeAsync()
    {
        if(databaseGuid is null)return;
        await using var c=new SqlConnection(admin);await c.OpenAsync();await Reconcile(c);
        Record("OWNED_DROP_INTENT");
        await using var cmd=c.CreateCommand();
        cmd.CommandText=$"ALTER DATABASE [{name}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [{name}]; SELECT COUNT(*) FROM sys.databases WHERE name=@name";
        cmd.Parameters.AddWithValue("@name",name);Assert.Equal(0,Convert.ToInt32(await cmd.ExecuteScalarAsync()));
        Record("ABSENT");databaseGuid=null;
    }
}
