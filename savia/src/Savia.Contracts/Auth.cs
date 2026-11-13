namespace Savia.Contracts;

public sealed record LoginRequest(string LoginName, string Password);
public sealed record LoginResponse(string Token, DateTimeOffset ExpiresAt, Guid StaffId, string DisplayName, string[] Roles);
