using System.Globalization;
using System.Text;
using Martha.Store.Api.Internal;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Xunit;
namespace Martha.Store.Api.Tests;
    internal sealed class OwnerRecoveryFixture : IAsyncDisposable
    {
        private readonly string admin;
        private readonly string name="SaviaInternalTest_Recovery_"+Guid.NewGuid().ToString("N");
        private string connection="";
        private OwnerRecoveryDatabaseLease? lease;
        public string Connection => connection;
        public Guid Other {get;}=Guid.NewGuid();
        public HashSet<Guid> Revocable {get;}=[];
        public string[] MigrationBefore {get;private set;}=[];
        private static readonly string[] Migrations=["20261025085402_InitialInternalSavia","20261027224500_InternalBranchScope","20261106071201_PhysicalStockException","20261107221938_FirstCashRegister"];
        internal const string Old="synthetic-old-input-only";
        public Guid Target {get;}=Guid.NewGuid();
        private OwnerRecoveryFixture(string admin)=>this.admin=admin;
        public InternalDbContext Context()=>new(new DbContextOptionsBuilder<InternalDbContext>().UseSqlServer(connection).Options);
        public static async Task<OwnerRecoveryFixture> Create()
        {
            var supplied=Environment.GetEnvironmentVariable("SAVIA_OWNER_RECOVERY_SQL_CONNECTION")??throw new InvalidOperationException();
            var b=new SqlConnectionStringBuilder(supplied);
            Assert.True(b.IntegratedSecurity); Assert.False(b.TrustServerCertificate); Assert.True(b.Encrypt==SqlConnectionEncryptOption.Mandatory || b.Encrypt==SqlConnectionEncryptOption.Strict);
            b.InitialCatalog="master"; b.Pooling=false;b.ConnectRetryCount=0;
            var f=new OwnerRecoveryFixture(b.ConnectionString);
            try
            {
                f.lease=await OwnerRecoveryDatabaseLease.Create(f.admin,f.name);
                b.InitialCatalog=f.name; f.connection=b.ConnectionString;
                await using var db=f.Context(); await db.Database.MigrateAsync();
                f.MigrationBefore=(await db.Database.GetAppliedMigrationsAsync()).ToArray(); Assert.Equal(Migrations,f.MigrationBefore);
                var now=DateTimeOffset.UtcNow;
                var staff=new InternalStaff {Id=f.Target,LoginName="owner",NormalizedLoginName="OWNER",Role="Owner",Enabled=true,DisplayName="Synthetic",SecurityVersion=Guid.NewGuid(),CreatedAt=now,UpdatedAt=now,FailedSignIns=5,LockedUntil=now.AddHours(1)};
                staff.PasswordHash=new PasswordHasher<InternalStaff>(Options.Create(new PasswordHasherOptions{IterationCount=210_000})).HashPassword(staff,Old);
                var other=new InternalStaff {Id=f.Other,LoginName="other",NormalizedLoginName="OTHER",Role="Owner",Enabled=true,DisplayName="Other",SecurityVersion=Guid.NewGuid(),CreatedAt=now,UpdatedAt=now,PasswordHash=staff.PasswordHash};
                db.Add(other); db.Add(new InternalSession {Id=Guid.NewGuid(),StaffId=other.Id,SecurityVersion=other.SecurityVersion,CreatedAt=now,ExpiresAt=now.AddHours(1)});
                db.Add(new InternalSession {Id=Guid.NewGuid(),StaffId=staff.Id,SecurityVersion=staff.SecurityVersion,CreatedAt=now,ExpiresAt=now.AddHours(1),RevokedAt=now});
                db.Add(staff); var active=Guid.NewGuid(); f.Revocable.Add(active);
                db.Add(new InternalSession {Id=active,StaffId=staff.Id,SecurityVersion=staff.SecurityVersion,CreatedAt=now,ExpiresAt=now.AddHours(1)});
                var secondActive=Guid.NewGuid();f.Revocable.Add(secondActive);
                db.Add(new InternalSession {Id=secondActive,StaffId=staff.Id,SecurityVersion=staff.SecurityVersion,CreatedAt=now,ExpiresAt=now.AddHours(1)});
                var branch=Guid.NewGuid();
                db.Add(new InternalBranch {Id=branch,Name="Business canary",Active=true});
                db.Add(new InternalItem {Id=Guid.NewGuid(),Sku="RECOVERY-CANARY",Name="Item canary",Currency="USD",UnitPriceMinor=123,Active=true});
                db.Add(new InternalBranchAssignmentAudit {Id=Guid.NewGuid(),ActorId=other.Id,StaffId=staff.Id,BranchId=branch,CreatedAt=now});
                await db.SaveChangesAsync(); return f;
            }
            catch {await f.DisposeAsync();throw;}
        }
        public async Task<OwnerRecoveryManifest> Manifest()
        {
            await using var c=new SqlConnection(connection);await c.OpenAsync();await using var cmd=c.CreateCommand();
            cmd.CommandText="SELECT CONVERT(nvarchar(256),SERVERPROPERTY('ServerName')),DB_ID(),database_guid,SUSER_SID() FROM sys.database_recovery_status WHERE database_id=DB_ID()";
            await using var r=await cmd.ExecuteReaderAsync();Assert.True(await r.ReadAsync());
            await using var db=Context();var staff=await db.InternalStaff.SingleAsync(x=>x.Id==Target);
            return new(r.GetString(0),name,r.GetInt32(1),r.GetGuid(2),"fixture-platform-policy-only",Convert.ToHexString((byte[])r[3]),Target,"OWNER",staff.SecurityVersion);
        }
        public Task<SortedDictionary<string,string>> Snapshot(bool preserved=false) =>
            OwnerRecoveryOracle.Capture(connection, preserved ? Target : Guid.Empty, Revocable);
        public async Task AssertMigrations()
        { await using var db=Context();Assert.Equal(MigrationBefore,(await db.Database.GetAppliedMigrationsAsync()).ToArray()); }
        public Task RecordBackup(string path)
        {
            var directory=Environment.GetEnvironmentVariable("SAVIA_OWNER_RECOVERY_EVIDENCE_DIRECTORY")??throw new InvalidOperationException();
            return File.WriteAllTextAsync(Path.Combine(directory,name+".backup-cleanup.json"),System.Text.Json.JsonSerializer.Serialize(new {database=name,backup=path,state="SQL_HOST_CUSTODIAN_CLEANUP_PENDING"}));
        }
        public Task BeginOwnedRestore()=>lease!.BeginOwnedRestore();
        public Task ReadOwnedRestore()=>lease!.ReadOwnedRestore();
        public async ValueTask DisposeAsync()
        { if(lease is not null) await lease.DisposeAsync(); }
    }

internal static class OwnerRecoveryOracle
{
        public static async Task<SortedDictionary<string,string>> Capture(string connection,Guid target=default,IReadOnlySet<Guid>? revocable=null)
        {
            await using var c=new SqlConnection(connection);await c.OpenAsync();
            return await Capture(c,null,target,revocable);
        }
        public static async Task<SortedDictionary<string,string>> Capture(SqlConnection c,SqlTransaction? tx,Guid target=default,IReadOnlySet<Guid>? revocable=null)
        {
            var tables=new List<string>();
            await using(var cmd=c.CreateCommand())
            {cmd.Transaction=tx;cmd.CommandText="SELECT t.name FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id WHERE s.name='savia_internal' ORDER BY t.name";await using var r=await cmd.ExecuteReaderAsync();while(await r.ReadAsync()) tables.Add(r.GetString(0));}
            InternalAcceptanceFingerprint.AssertTables(tables);
            var result=new SortedDictionary<string,string>(StringComparer.Ordinal);
            foreach(var table in tables)
            {
                await using var cmd=c.CreateCommand();cmd.Transaction=tx;cmd.CommandText=$"SELECT * FROM [savia_internal].[{table}]";
                await using var r=await cmd.ExecuteReaderAsync();var rows=new List<string>();
                while(await r.ReadAsync())
                {
                    using var stream=new MemoryStream();using var writer=new BinaryWriter(stream,Encoding.UTF8,true);
                    for(var i=0;i<r.FieldCount;i++)
                    {
                        if(target!=Guid.Empty && table=="Staff" && r.GetGuid(r.GetOrdinal("Id"))==target
                            && r.GetName(i) is "PasswordHash" or "SecurityVersion" or "UpdatedAt" or "FailedSignIns" or "LockedUntil" or "RowVersion") continue;
                        if(target!=Guid.Empty && table=="Sessions" && revocable is not null && revocable.Contains(r.GetGuid(r.GetOrdinal("Id"))) && r.GetName(i)=="RevokedAt") continue;
                        writer.Write(r.GetName(i));writer.Write(r.GetDataTypeName(i));writer.Write(r.IsDBNull(i));
                        if(r.IsDBNull(i))continue;
                        var value=r.GetValue(i);
                        if(value is byte[] bytes){writer.Write(bytes.Length);writer.Write(bytes);}
                        else if(value is DateTime dt)writer.Write(dt.ToBinary());
                        else if(value is DateTimeOffset dto){writer.Write(dto.Ticks);writer.Write(dto.Offset.Ticks);}
                        else writer.Write(Convert.ToString(value,CultureInfo.InvariantCulture)??throw new InvalidOperationException());
                    }
                    writer.Flush();rows.Add(Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(stream.ToArray())));
                }
                rows.Sort(StringComparer.Ordinal);result[table]=string.Join("\n",rows);
            }
            return result;
        }
}
