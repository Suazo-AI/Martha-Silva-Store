namespace Savia.Contracts;

public sealed record LoginRequest(string LoginName, string Password);
/// <param name="MustChangePassword">The password was a printed one-time password: only the password change, logout and
/// GET /me answer until it is replaced (V064).</param>
public sealed record LoginResponse(string Token, DateTimeOffset ExpiresAt, Guid StaffId, string DisplayName, string[] Roles,
    bool MustChangePassword = false);
public sealed record ChangePasswordRequest(string CurrentPassword, string NewPassword);
