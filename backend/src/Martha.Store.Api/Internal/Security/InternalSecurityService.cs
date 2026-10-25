using System.Data;
using System.Security.Claims;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace Martha.Store.Api.Internal;

public sealed class InternalSecurityService(InternalDbContext db, IPasswordHasher<InternalStaff> passwords, TimeProvider time)
{
    public async Task<InternalResult<InternalLoginResult>> Login(InternalLoginRequest request, CancellationToken ct)
    {
        if (!InternalSecurityRules.ValidLoginName(request.LoginName) || request.Password is not { Length: >= 1 and <= 128 })
            return InternalResult<InternalLoginResult>.Fail("invalid_credentials");
        var normalized = InternalSecurityRules.NormalizeLoginName(request.LoginName!);
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        // Serialize account attempts before verifying the password so concurrent failures cannot bypass lockout.
        var staff = await db.InternalStaff.FromSqlInterpolated($"SELECT * FROM [savia_internal].[Staff] WITH (UPDLOCK, HOLDLOCK) WHERE [NormalizedLoginName] = {normalized}")
            .SingleOrDefaultAsync(ct);
        var now = time.GetUtcNow();
        if (staff is null || !staff.Enabled || !InternalSecurityRules.ValidRole(staff.Role) || staff.LockedUntil > now)
        {
            // Perform the same expensive primitive for absent/disabled/locked accounts. No dummy credential/account is stored.
            _ = passwords.HashPassword(new InternalStaff(), request.Password);
            return InternalResult<InternalLoginResult>.Fail("invalid_credentials");
        }
        PasswordVerificationResult verification;
        try { verification = passwords.VerifyHashedPassword(staff, staff.PasswordHash, request.Password); }
        catch (FormatException) { verification = PasswordVerificationResult.Failed; }
        if (verification == PasswordVerificationResult.Failed)
        {
            InternalSecurityRules.RecordFailure(staff, now);
            await db.SaveChangesAsync(ct);
            await transaction.CommitAsync(ct);
            return InternalResult<InternalLoginResult>.Fail("invalid_credentials");
        }
        if (verification == PasswordVerificationResult.SuccessRehashNeeded)
            staff.PasswordHash = passwords.HashPassword(staff, request.Password);
        staff.FailedSignIns = 0;
        staff.LockedUntil = null;
        // A fresh login replaces previous sessions. Absolute expiry is never extended by cookie renewal.
        await RevokeSessions(staff.Id, now, ct);
        var session = new InternalSession
        {
            Id = Guid.NewGuid(), StaffId = staff.Id, SecurityVersion = staff.SecurityVersion,
            CreatedAt = now, ExpiresAt = now.Add(InternalSecurityRules.SessionLifetime)
        };
        db.InternalSessions.Add(session);
        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return InternalResult<InternalLoginResult>.Ok(new(staff, session));
    }

    public async Task<ClaimsPrincipal?> ValidateSession(ClaimsPrincipal principal, CancellationToken ct)
    {
        if (!Guid.TryParse(principal.FindFirstValue(InternalSecurityRules.SessionClaim), out var sessionId)) return null;
        var session = await db.InternalSessions.AsNoTracking().SingleOrDefaultAsync(x => x.Id == sessionId, ct);
        if (session is null) return null;
        var staff = await db.InternalStaff.AsNoTracking().SingleOrDefaultAsync(x => x.Id == session.StaffId, ct);
        return InternalSecurityRules.SessionIsValid(staff, session, principal, time.GetUtcNow())
            ? InternalSecurityRules.Principal(staff!, session) : null;
    }

    public async Task Logout(ClaimsPrincipal principal, CancellationToken ct)
    {
        if (!Guid.TryParse(principal.FindFirstValue(InternalSecurityRules.SessionClaim), out var sessionId)) return;
        var staffId = InternalActor.Id(principal);
        var now = time.GetUtcNow();
        await db.InternalSessions.Where(x => x.Id == sessionId && x.StaffId == staffId && x.RevokedAt == null)
            .ExecuteUpdateAsync(update => update.SetProperty(x => x.RevokedAt, now), ct);
    }

    public async Task<InternalResult<InternalStaffView>> CreateStaff(ClaimsPrincipal actor, InternalStaffCreateRequest request, CancellationToken ct)
    {
        if (!ValidCreate(request)) return InternalResult<InternalStaffView>.Fail("invalid_request");
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        if (!await IsCurrentOwner(actor, ct)) return InternalResult<InternalStaffView>.Fail("forbidden");
        var normalized = InternalSecurityRules.NormalizeLoginName(request.LoginName!);
        if (await db.InternalStaff.AnyAsync(x => x.NormalizedLoginName == normalized, ct))
            return InternalResult<InternalStaffView>.Fail("login_unavailable");
        var staff = NewStaff(request, time.GetUtcNow());
        db.InternalStaff.Add(staff);
        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return InternalResult<InternalStaffView>.Ok(InternalStaffView.From(staff));
    }

    public async Task<InternalResult<InternalStaffView>> UpdateStaff(ClaimsPrincipal actor, Guid staffId, InternalStaffUpdateRequest request, CancellationToken ct)
    {
        if (staffId == Guid.Empty || request.Version == Guid.Empty || !InternalSecurityRules.ValidDisplayName(request.DisplayName)
            || !InternalSecurityRules.ValidRole(request.Role)) return InternalResult<InternalStaffView>.Fail("invalid_request");
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        if (!await IsCurrentOwner(actor, ct)) return InternalResult<InternalStaffView>.Fail("forbidden");
        var staff = await db.InternalStaff.SingleOrDefaultAsync(x => x.Id == staffId, ct);
        if (staff is null) return InternalResult<InternalStaffView>.Fail("staff_not_found");
        if (staff.SecurityVersion != request.Version) return InternalResult<InternalStaffView>.Fail("version_conflict");
        if (staff.Enabled && staff.Role == "Owner" && (!request.Enabled || request.Role != "Owner")
            && await db.InternalStaff.CountAsync(x => x.Enabled && x.Role == "Owner", ct) <= 1)
            return InternalResult<InternalStaffView>.Fail("last_owner_required");
        staff.DisplayName = request.DisplayName!;
        staff.Role = request.Role!;
        staff.Enabled = request.Enabled;
        await RotateSecurity(staff, ct);
        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return InternalResult<InternalStaffView>.Ok(InternalStaffView.From(staff));
    }

    public async Task<InternalResult<InternalStaffView>> ResetPassword(ClaimsPrincipal actor, Guid staffId, InternalStaffPasswordRequest request, CancellationToken ct)
    {
        if (staffId == Guid.Empty || request.Version == Guid.Empty || !InternalSecurityRules.ValidPassword(request.Password))
            return InternalResult<InternalStaffView>.Fail("invalid_request");
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        if (!await IsCurrentOwner(actor, ct)) return InternalResult<InternalStaffView>.Fail("forbidden");
        var staff = await db.InternalStaff.SingleOrDefaultAsync(x => x.Id == staffId, ct);
        if (staff is null) return InternalResult<InternalStaffView>.Fail("staff_not_found");
        if (staff.SecurityVersion != request.Version) return InternalResult<InternalStaffView>.Fail("version_conflict");
        staff.PasswordHash = passwords.HashPassword(staff, request.Password!);
        await RotateSecurity(staff, ct);
        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return InternalResult<InternalStaffView>.Ok(InternalStaffView.From(staff));
    }

    private async Task<bool> IsCurrentOwner(ClaimsPrincipal actor, CancellationToken ct)
    {
        // Revalidate inside the same serializable transaction; never use a client actor/role or only a stale cookie claim.
        var current = await ValidateSession(actor, ct);
        return current?.IsInRole("Owner") == true;
    }

    private async Task RotateSecurity(InternalStaff staff, CancellationToken ct)
    {
        staff.SecurityVersion = Guid.NewGuid();
        staff.UpdatedAt = time.GetUtcNow();
        staff.FailedSignIns = 0;
        staff.LockedUntil = null;
        await RevokeSessions(staff.Id, staff.UpdatedAt, ct);
    }

    private Task<int> RevokeSessions(Guid staffId, DateTimeOffset now, CancellationToken ct) => db.InternalSessions
        .Where(x => x.StaffId == staffId && x.RevokedAt == null)
        .ExecuteUpdateAsync(update => update.SetProperty(x => x.RevokedAt, now), ct);

    private static bool ValidCreate(InternalStaffCreateRequest request) => InternalSecurityRules.ValidLoginName(request.LoginName)
        && InternalSecurityRules.ValidDisplayName(request.DisplayName) && InternalSecurityRules.ValidRole(request.Role)
        && InternalSecurityRules.ValidPassword(request.Password);

    private InternalStaff NewStaff(InternalStaffCreateRequest request, DateTimeOffset now)
    {
        var staff = new InternalStaff
        {
            Id = Guid.NewGuid(), LoginName = request.LoginName!, NormalizedLoginName = InternalSecurityRules.NormalizeLoginName(request.LoginName!),
            DisplayName = request.DisplayName!, Role = request.Role!, Enabled = true, SecurityVersion = Guid.NewGuid(),
            CreatedAt = now, UpdatedAt = now
        };
        staff.PasswordHash = passwords.HashPassword(staff, request.Password!);
        return staff;
    }
}

// Explicit OFFLINE service only. No endpoint, hosted service, seed, startup hook, default account or embedded credential.
// The operator must supply credentials through a separately authorized private maintenance path, never command-line/log output.
public sealed class InternalOwnerBootstrap(InternalDbContext db, IPasswordHasher<InternalStaff> passwords, TimeProvider time)
{
    public async Task<InternalResult<Guid>> CreateInitialOwner(string loginName, string displayName, string password, CancellationToken ct)
    {
        if (!InternalSecurityRules.ValidLoginName(loginName) || !InternalSecurityRules.ValidDisplayName(displayName)
            || !InternalSecurityRules.ValidPassword(password)) return InternalResult<Guid>.Fail("invalid_request");
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        // Any identity ever created closes bootstrap. It cannot be used to recover/bypass disabled or lost accounts.
        if (await db.InternalStaff.AnyAsync(ct)) return InternalResult<Guid>.Fail("bootstrap_closed");
        var now = time.GetUtcNow();
        var staff = new InternalStaff
        {
            Id = Guid.NewGuid(), LoginName = loginName, NormalizedLoginName = InternalSecurityRules.NormalizeLoginName(loginName),
            DisplayName = displayName, Role = "Owner", Enabled = true, SecurityVersion = Guid.NewGuid(), CreatedAt = now, UpdatedAt = now
        };
        staff.PasswordHash = passwords.HashPassword(staff, password);
        db.InternalStaff.Add(staff);
        await db.SaveChangesAsync(ct);
        await transaction.CommitAsync(ct);
        return InternalResult<Guid>.Ok(staff.Id);
    }
}
