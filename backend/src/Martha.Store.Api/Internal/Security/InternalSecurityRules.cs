using System.Security.Claims;
using System.Text.Json.Serialization;

namespace Martha.Store.Api.Internal;

public static class InternalSecurityRules
{
    public const string Scheme = "InternalSavia";
    public const string SessionClaim = "savia:session";
    public const string VersionClaim = "savia:security-version";
    public static readonly TimeSpan SessionLifetime = TimeSpan.FromHours(8);
    public static readonly TimeSpan LockoutDuration = TimeSpan.FromMinutes(15);
    public const int MaxFailedSignIns = 5;

    public static bool ValidRole(string? value) => value is "Owner" or "Manager" or "Cashier" or "Inventory";
    public static bool ValidLoginName(string? value) => value is { Length: >= 3 and <= 64 }
        && value.All(c => char.IsAsciiLetterOrDigit(c) || c is '.' or '_' or '-');
    public static string NormalizeLoginName(string value) => value.ToUpperInvariant();
    public static bool ValidPassword(string? value) => value is { Length: >= 15 and <= 128 }
        && !string.IsNullOrWhiteSpace(value) && !value.Any(char.IsControl);
    public static bool ValidDisplayName(string? value) => value is { Length: >= 1 and <= 120 }
        && value == value.Trim() && !value.Any(char.IsControl);

    public static ClaimsPrincipal Principal(InternalStaff staff, InternalSession session) => new(new ClaimsIdentity(
    [
        new Claim(ClaimTypes.NameIdentifier, staff.Id.ToString("D")),
        new Claim(ClaimTypes.Name, staff.LoginName),
        new Claim(ClaimTypes.Role, staff.Role),
        new Claim(SessionClaim, session.Id.ToString("D")),
        new Claim(VersionClaim, staff.SecurityVersion.ToString("D"))
    ], Scheme));

    public static bool SessionIsValid(InternalStaff? staff, InternalSession? session, ClaimsPrincipal principal, DateTimeOffset now)
    {
        if (staff is null || session is null || !staff.Enabled || !ValidRole(staff.Role)
            || staff.Id == Guid.Empty || session.Id == Guid.Empty || staff.SecurityVersion == Guid.Empty
            || session.StaffId != staff.Id || session.SecurityVersion != staff.SecurityVersion
            || session.RevokedAt is not null || session.ExpiresAt <= now || session.CreatedAt > now
            || session.ExpiresAt - session.CreatedAt > SessionLifetime) return false;
        return principal.Identity?.IsAuthenticated == true
            && HasOnlyClaim(principal, ClaimTypes.NameIdentifier, staff.Id.ToString("D"))
            && HasOnlyClaim(principal, SessionClaim, session.Id.ToString("D"))
            && HasOnlyClaim(principal, VersionClaim, staff.SecurityVersion.ToString("D"))
            && HasOnlyClaim(principal, ClaimTypes.Role, staff.Role);
    }

    private static bool HasOnlyClaim(ClaimsPrincipal principal, string type, string value)
    {
        var claims = principal.FindAll(type).ToArray();
        return claims.Length == 1 && claims[0].Value == value;
    }

    public static void RecordFailure(InternalStaff staff, DateTimeOffset now)
    {
        if (staff.LockedUntil <= now) { staff.FailedSignIns = 0; staff.LockedUntil = null; }
        staff.FailedSignIns = Math.Min(MaxFailedSignIns, staff.FailedSignIns + 1);
        if (staff.FailedSignIns == MaxFailedSignIns) staff.LockedUntil = now.Add(LockoutDuration);
    }
}

public sealed record InternalStaffView(Guid Id, string LoginName, string DisplayName, string Role, bool Enabled, Guid Version, Guid? BranchId = null)
{
    public static InternalStaffView From(InternalStaff staff) => new(staff.Id, staff.LoginName, staff.DisplayName,
        staff.Role, staff.Enabled, staff.SecurityVersion, staff.BranchId);
}
public sealed record InternalLoginRequest(string? LoginName, string? Password)
{ public override string ToString() => "InternalLoginRequest { redacted }"; }
public sealed record InternalStaffCreateRequest(string? LoginName, string? DisplayName, string? Role, string? Password, Guid? BranchId = null)
{ public override string ToString() => "InternalStaffCreateRequest { redacted }"; }
public sealed record InternalStaffUpdateRequest(string? DisplayName, string? Role, [property: JsonRequired] bool Enabled, Guid Version, Guid? BranchId = null);
public sealed record InternalStaffPasswordRequest(string? Password, Guid Version)
{ public override string ToString() => "InternalStaffPasswordRequest { redacted }"; }
public sealed record InternalLoginResult(InternalStaff Staff, InternalSession Session);
