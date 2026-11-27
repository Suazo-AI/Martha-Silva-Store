using Microsoft.Data.SqlClient;
using Savia.Application;
using Savia.Domain;
using static Savia.Infrastructure.SqlGateway;

namespace Savia.Infrastructure;

public sealed class AuthStore(SqlGateway sql) : IAuthStore
{
    private const string CredentialColumns = "SELECT Id,DisplayName,PasswordHash,SecurityVersion,IsEnabled,LockedUntil FROM security.Staff ";

    public Task<StaffCredential?> FindStaffAsync(string normalizedLogin, CancellationToken ct) =>
        sql.FirstAsync(CredentialColumns + "WHERE NormalizedLoginName=@login", Credential, ct, P("@login", normalizedLogin));

    public Task<StaffCredential?> FindStaffByIdAsync(Guid staffId, CancellationToken ct) =>
        sql.FirstAsync(CredentialColumns + "WHERE Id=@id", Credential, ct, P("@id", staffId));

    private static StaffCredential Credential(SqlDataReader r) => new(r.GetGuid(0), r.GetString(1), r.StringOrNull(2), r.GetGuid(3),
        r.GetBoolean(4), r.IsDBNull(5) ? null : new DateTimeOffset(DateTime.SpecifyKind(r.GetDateTime(5), DateTimeKind.Utc)));

    public async Task<Actor?> LoadActorAsync(Guid staffId, CancellationToken ct)
    {
        const string query = """
            SELECT DisplayName,MustChangePassword FROM security.Staff WHERE Id=@id AND IsEnabled=1;
            SELECT r.Code FROM security.StaffRoles sr JOIN security.Roles r ON r.Id=sr.RoleId WHERE sr.StaffId=@id AND r.IsActive=1;
            SELECT BranchId FROM security.StaffBranchAccess WHERE StaffId=@id AND IsActive=1;
            """;
        return await sql.RunAsync(query, System.Data.CommandType.Text, [P("@id", staffId)], async cmd =>
        {
            await using var reader = await cmd.ExecuteReaderAsync(ct);
            if (!await reader.ReadAsync(ct)) return null;
            var name = reader.GetString(0);
            var mustChange = reader.GetBoolean(1);
            var roles = new HashSet<string>(StringComparer.Ordinal);
            var branches = new HashSet<Guid>();
            await reader.NextResultAsync(ct);
            while (await reader.ReadAsync(ct)) roles.Add(reader.GetString(0));
            await reader.NextResultAsync(ct);
            while (await reader.ReadAsync(ct)) branches.Add(reader.GetGuid(0));
            return new Actor(staffId, name, roles, branches, mustChange);
        }, ct);
    }

    // A failure after an ended lock starts a fresh count, so one more wrong password does not lock again and repeated
    // lock cycles never push the count past CK_Staff_Failed (0 to 20); the count stops at the lock limit.
    public Task RecordSignInAsync(Guid staffId, bool success, DateTimeOffset now, DateTimeOffset? lockUntil, CancellationToken ct) => success
        ? sql.ExecAsync("UPDATE security.Staff SET FailedSignIns=0,LockedUntil=NULL WHERE Id=@id", ct, P("@id", staffId))
        : sql.ExecAsync("""
            UPDATE security.Staff SET
              FailedSignIns=CASE WHEN LockedUntil<=@now THEN 1 WHEN FailedSignIns<@max THEN FailedSignIns+1 ELSE @max END,
              LockedUntil=CASE WHEN (CASE WHEN LockedUntil<=@now THEN 1 ELSE FailedSignIns+1 END)>=@max THEN @until
                               WHEN LockedUntil<=@now THEN NULL ELSE LockedUntil END
            WHERE Id=@id
            """, ct, P("@id", staffId), P("@now", now.UtcDateTime), P("@max", AuthService.MaxFailedSignIns),
            P("@until", lockUntil?.UtcDateTime));

    public Task CreateSessionAsync(Guid staffId, Guid securityVersion, byte[] tokenHash, DateTimeOffset expiresAt, CancellationToken ct) =>
        sql.ExecAsync("INSERT INTO security.Sessions(Id,StaffId,SecurityVersion,ExpiresAt,TokenHash,CreatedBy) "
            + "VALUES(NEWID(),@staff,@version,@expires,@hash,@staff)",
            ct, P("@staff", staffId), P("@version", securityVersion), P("@expires", expiresAt.UtcDateTime), Hash(tokenHash));

    public async Task<Guid?> FindSessionStaffAsync(byte[] tokenHash, DateTimeOffset now, CancellationToken ct)
    {
        var rows = await sql.QueryAsync("""
            SELECT s.StaffId FROM security.Sessions s JOIN security.Staff st ON st.Id=s.StaffId
            WHERE s.TokenHash=@hash AND s.RevokedAt IS NULL AND s.ExpiresAt>@now
              AND st.IsEnabled=1 AND st.SecurityVersion=s.SecurityVersion
            """, r => r.GetGuid(0), ct, Hash(tokenHash), P("@now", now.UtcDateTime));
        return rows.Count == 1 ? rows[0] : null;
    }

    public Task RevokeSessionAsync(byte[] tokenHash, DateTimeOffset now, CancellationToken ct) =>
        sql.ExecAsync("UPDATE security.Sessions SET RevokedAt=@now,ModifiedAt=@now WHERE TokenHash=@hash AND RevokedAt IS NULL",
            ct, Hash(tokenHash), P("@now", now.UtcDateTime));

    // A new security version ends every session opened with the old password. A password set through the API
    // (pilot provisioning, tests) is not a printed one-time password, so it clears the mark.
    public async Task SetPasswordAsync(Guid staffId, string passwordHash, CancellationToken ct)
    {
        var changed = await sql.ExecAsync(
            "UPDATE security.Staff SET PasswordHash=@hash,SecurityVersion=NEWID(),FailedSignIns=0,LockedUntil=NULL,MustChangePassword=0,"
            + "ModifiedAt=SYSUTCDATETIME() WHERE Id=@id",
            ct, P("@id", staffId), P("@hash", passwordHash));
        if (changed != 1) throw Errors.NotFound("auth.staff_not_found", "El usuario no existe.");
    }

    public Task ChangeOwnPasswordAsync(Guid staffId, byte[] tokenHash, string passwordHash, CancellationToken ct) =>
        sql.ExecProcAsync("security.usp_ChangeOwnPassword", ct, P("@StaffId", staffId),
            new SqlParameter("@TokenHash", System.Data.SqlDbType.VarBinary, 32) { Value = tokenHash }, P("@PasswordHash", passwordHash));

    private static SqlParameter Hash(byte[] value) => new("@hash", System.Data.SqlDbType.VarBinary, 32) { Value = value };
}
