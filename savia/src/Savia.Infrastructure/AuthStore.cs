using Microsoft.Data.SqlClient;
using Savia.Application;
using Savia.Domain;
using static Savia.Infrastructure.SqlGateway;

namespace Savia.Infrastructure;

public sealed class AuthStore(SqlGateway sql) : IAuthStore
{
    public Task<StaffCredential?> FindStaffAsync(string normalizedLogin, CancellationToken ct) => sql.FirstAsync(
        "SELECT Id,DisplayName,PasswordHash,SecurityVersion,IsEnabled,LockedUntil FROM security.Staff WHERE NormalizedLoginName=@login",
        r => new StaffCredential(r.GetGuid(0), r.GetString(1), r.StringOrNull(2), r.GetGuid(3), r.GetBoolean(4),
            r.IsDBNull(5) ? null : new DateTimeOffset(DateTime.SpecifyKind(r.GetDateTime(5), DateTimeKind.Utc))),
        ct, P("@login", normalizedLogin));

    public async Task<Actor?> LoadActorAsync(Guid staffId, CancellationToken ct)
    {
        const string query = """
            SELECT DisplayName FROM security.Staff WHERE Id=@id AND IsEnabled=1;
            SELECT r.Code FROM security.StaffRoles sr JOIN security.Roles r ON r.Id=sr.RoleId WHERE sr.StaffId=@id AND r.IsActive=1;
            SELECT BranchId FROM security.StaffBranchAccess WHERE StaffId=@id AND IsActive=1;
            """;
        return await sql.RunAsync(query, System.Data.CommandType.Text, [P("@id", staffId)], async cmd =>
        {
            await using var reader = await cmd.ExecuteReaderAsync(ct);
            if (!await reader.ReadAsync(ct)) return null;
            var name = reader.GetString(0);
            var roles = new HashSet<string>(StringComparer.Ordinal);
            var branches = new HashSet<Guid>();
            await reader.NextResultAsync(ct);
            while (await reader.ReadAsync(ct)) roles.Add(reader.GetString(0));
            await reader.NextResultAsync(ct);
            while (await reader.ReadAsync(ct)) branches.Add(reader.GetGuid(0));
            return new Actor(staffId, name, roles, branches);
        }, ct);
    }

    public Task RecordSignInAsync(Guid staffId, bool success, DateTimeOffset? lockUntil, CancellationToken ct) => success
        ? sql.ExecAsync("UPDATE security.Staff SET FailedSignIns=0,LockedUntil=NULL WHERE Id=@id", ct, P("@id", staffId))
        : sql.ExecAsync("""
            UPDATE security.Staff SET
              FailedSignIns=CASE WHEN FailedSignIns<1000 THEN FailedSignIns+1 ELSE FailedSignIns END,
              LockedUntil=CASE WHEN FailedSignIns+1>=@max THEN @until ELSE LockedUntil END
            WHERE Id=@id
            """, ct, P("@id", staffId), P("@max", AuthService.MaxFailedSignIns), P("@until", lockUntil?.UtcDateTime));

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

    // A new security version ends every session opened with the old password.
    public async Task SetPasswordAsync(Guid staffId, string passwordHash, CancellationToken ct)
    {
        var changed = await sql.ExecAsync(
            "UPDATE security.Staff SET PasswordHash=@hash,SecurityVersion=NEWID(),FailedSignIns=0,LockedUntil=NULL,ModifiedAt=SYSUTCDATETIME() WHERE Id=@id",
            ct, P("@id", staffId), P("@hash", passwordHash));
        if (changed != 1) throw Errors.NotFound("auth.staff_not_found", "El usuario no existe.");
    }

    private static SqlParameter Hash(byte[] value) => new("@hash", System.Data.SqlDbType.VarBinary, 32) { Value = value };
}
