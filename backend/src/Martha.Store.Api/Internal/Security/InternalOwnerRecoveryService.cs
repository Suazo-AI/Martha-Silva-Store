using System.Data;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using Microsoft.Extensions.Options;

namespace Martha.Store.Api.Internal;

public sealed record OwnerRecoveryManifest(string Server, string Catalog, int DatabaseId, Guid DatabaseGuid,
    string OperatorSid, string SqlSid, Guid TargetId, string Login, Guid SecurityVersion)
{
    public string Confirmation => $"RECOVER {Server} {Catalog} {DatabaseId} {DatabaseGuid:D} {TargetId:D} {Login} {SecurityVersion:D}";
    public string Connection()
    {
        if (!InternalOwnerConsole.SafeServer(Server) || DatabaseId <= 0 || DatabaseGuid == Guid.Empty
            || TargetId == Guid.Empty || SecurityVersion == Guid.Empty || !InternalSecurityRules.ValidLoginName(Login)
            || Login != InternalSecurityRules.NormalizeLoginName(Login) || string.IsNullOrWhiteSpace(OperatorSid)
            || string.IsNullOrWhiteSpace(SqlSid)) throw new InvalidOperationException();
        var b = new SqlConnectionStringBuilder { DataSource = Server, InitialCatalog = Catalog,
            IntegratedSecurity = true, Encrypt = SqlConnectionEncryptOption.Mandatory, TrustServerCertificate = false,
            Pooling = false, ConnectTimeout = 15, ConnectRetryCount = 0 };
        InternalDatabaseGuard.Validate(b.ConnectionString);
        return b.ConnectionString;
    }
}

// No credentials or raw errors cross this boundary.
public interface IOwnerRecoveryJournal { void Write(string result, Guid operation, Guid proposedVersion); }
public enum OwnerRecoveryOutcome { Committed = 0, Refused = 2, Unknown = 4 }

public sealed class InternalOwnerRecoveryService : IAsyncDisposable
{
    private readonly OwnerRecoveryManifest manifest;
    private readonly Action<string>? fault;
    private readonly SqlConnection connection;
    private readonly InternalDbContext db;
    private readonly IPasswordHasher<InternalStaff> hasher;
    public InternalOwnerRecoveryService(OwnerRecoveryManifest manifest, Action<string>? fault = null)
    {
        this.manifest = manifest;
        this.fault = fault;
        connection = new SqlConnection(manifest.Connection());
        db = new InternalDbContext(new DbContextOptionsBuilder<InternalDbContext>()
            .UseSqlServer(connection, sql => sql.CommandTimeout(30)).Options);
        hasher = new PasswordHasher<InternalStaff>(Options.Create(new PasswordHasherOptions { IterationCount = 210_000 }));
    }
    public async Task Inspect(CancellationToken ct)
    {
        await connection.OpenAsync(ct); // Exactly one open; no pooling/reconnect/retry strategy.
        await ValidateIdentity(null, ct);
        var staff = await db.InternalStaff.AsNoTracking().SingleOrDefaultAsync(x => x.Id == manifest.TargetId, ct);
        ValidateTarget(staff);
    }
    private void ValidateTarget(InternalStaff? staff)
    {
        if (staff is null || staff.Id != manifest.TargetId || staff.NormalizedLoginName != manifest.Login
            || staff.Role != "Owner" || !staff.Enabled || staff.SecurityVersion != manifest.SecurityVersion)
            throw new InvalidOperationException();
    }
    private async Task ValidateIdentity(SqlTransaction? transaction, CancellationToken ct)
    {
        using var command = connection.CreateCommand();
        command.Transaction = transaction;
        command.CommandTimeout = 30;
        command.CommandText = "SELECT CONVERT(nvarchar(256),SERVERPROPERTY('ServerName')), DB_NAME(), CONVERT(int, DB_ID()), database_guid, SUSER_SID() FROM sys.database_recovery_status WHERE database_id=DB_ID()";
        await using var reader = await command.ExecuteReaderAsync(ct);
        if (!await reader.ReadAsync(ct)) throw new InvalidOperationException();
        ValidateSqlIdentity(manifest, Enumerable.Range(0, reader.FieldCount).Select(reader.GetValue).ToArray());
        if (await reader.ReadAsync(ct)) throw new InvalidOperationException();
    }
    // This is the policy used by the live ADO.NET reader. Tests of it are platform-simulated only.
    public static void ValidateSqlIdentity(OwnerRecoveryManifest m, object[] values)
    {
        if (values.Length != 5 || values[0] is not string server || server != m.Server
            || values[1] is not string catalog || catalog != m.Catalog
            || values[2] is not int id || id <= 0 || id != m.DatabaseId
            || values[3] is not Guid guid || guid == Guid.Empty || guid != m.DatabaseGuid
            || values[4] is not byte[] sid || sid.Length == 0 || Convert.ToHexString(sid) != m.SqlSid)
            throw new InvalidOperationException();
    }
    public async Task<OwnerRecoveryOutcome> Recover(string password, IOwnerRecoveryJournal journal,
        Func<bool> privateTerminal, CancellationToken ct = default)
    {
        if (!InternalSecurityRules.ValidPassword(password) || !privateTerminal() || connection.State != ConnectionState.Open)
            return OwnerRecoveryOutcome.Refused;
        IDbContextTransaction? tx = null;
        var commitAttempted = false;
        var result = OwnerRecoveryOutcome.Unknown;
        var operation = Guid.NewGuid();
        var version = Guid.NewGuid();
        try
        {
            tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
            await ValidateIdentity((SqlTransaction)tx.GetDbTransaction(), ct);
            var staff = await db.InternalStaff.FromSqlInterpolated($"SELECT * FROM [savia_internal].[Staff] WITH (UPDLOCK,HOLDLOCK) WHERE [Id]={manifest.TargetId}").SingleOrDefaultAsync(ct);
            ValidateTarget(staff);
            fault?.Invoke("after-target-lock");
            // Validate the supported Identity format before verification; a malformed hash is never treated as a different password.
            ValidateStoredHash(staff!.PasswordHash);
            if (hasher.VerifyHashedPassword(staff, staff.PasswordHash, password) != PasswordVerificationResult.Failed)
                throw new InvalidOperationException();
            var replacement = hasher.HashPassword(staff, password);
            ct.ThrowIfCancellationRequested();
            if (!privateTerminal()) throw new InvalidOperationException();
            journal.Write("INTENT", operation, version); // Flushed before first write.
            var now = DateTimeOffset.UtcNow;
            staff.PasswordHash = replacement;
            staff.SecurityVersion = version;
            staff.UpdatedAt = now;
            staff.FailedSignIns = 0;
            staff.LockedUntil = null;
            await db.InternalSessions.Where(x => x.StaffId == staff.Id && x.RevokedAt == null)
                .ExecuteUpdateAsync(u => u.SetProperty(x => x.RevokedAt, now), ct);
            fault?.Invoke("after-revocation");
            await db.SaveChangesAsync(ct); // Retains EF rowversion concurrency predicate.
            fault?.Invoke("before-commit");
            commitAttempted = true;
            await tx.CommitAsync(ct);
            fault?.Invoke("after-commit");
            result = OwnerRecoveryOutcome.Committed;
        }
        catch (Exception)
        {
            if (!commitAttempted)
            {
                try
                {
                    fault?.Invoke("before-rollback");
                    if (tx is not null) await tx.RollbackAsync(CancellationToken.None);
                    result = OwnerRecoveryOutcome.Refused;
                }
                catch (Exception) { result = OwnerRecoveryOutcome.Unknown; }
            }
        }
        // Cleanup precedes the terminal receipt. A disposal exception cannot override a returned outcome
        // or leave a COMMITTED receipt paired with an UNKNOWN service result.
        try { fault?.Invoke("before-transaction-dispose"); }
        catch (Exception) { result = OwnerRecoveryOutcome.Unknown; }
        return await Complete(result, async () => { if (tx is not null) await tx.DisposeAsync(); }, journal, operation, version);
    }
    public static async Task<OwnerRecoveryOutcome> Complete(OwnerRecoveryOutcome result, Func<ValueTask> cleanup,
        IOwnerRecoveryJournal journal, Guid operation, Guid version)
    {
        try { await cleanup(); }
        catch (Exception) { result = OwnerRecoveryOutcome.Unknown; }
        if (result != OwnerRecoveryOutcome.Unknown)
        {
            try { journal.Write(result == OwnerRecoveryOutcome.Committed ? "COMMITTED" : "ABORTED", operation, version); }
            catch (Exception) { result = OwnerRecoveryOutcome.Unknown; }
        }
        return result;
    }
    public static void ValidateStoredHash(string encoded)
    {
        var b = Convert.FromBase64String(encoded);
        if (b.Length == 49 && b[0] == 0) return;
        if (b.Length < 13 || b[0] != 1) throw new FormatException();
        var prf = System.Buffers.Binary.BinaryPrimitives.ReadUInt32BigEndian(b.AsSpan(1,4));
        var iterations = System.Buffers.Binary.BinaryPrimitives.ReadUInt32BigEndian(b.AsSpan(5,4));
        var salt = System.Buffers.Binary.BinaryPrimitives.ReadUInt32BigEndian(b.AsSpan(9,4));
        if (prf > 2 || iterations == 0 || iterations > 10_000_000 || salt < 16 || salt > b.Length - 13 - 16)
            throw new FormatException();
    }
    public async ValueTask DisposeAsync() { try { await db.DisposeAsync(); } finally { await connection.DisposeAsync(); } }
}
