using System.Security.Cryptography;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

public sealed record StaffCredential(Guid StaffId, string DisplayName, string? PasswordHash, Guid SecurityVersion,
    bool IsEnabled, DateTimeOffset? LockedUntil);

public interface IAuthStore
{
    Task<StaffCredential?> FindStaffAsync(string normalizedLogin, CancellationToken ct);
    /// <summary>Roles and active branch access of an enabled staff member; null when missing or disabled.</summary>
    Task<Actor?> LoadActorAsync(Guid staffId, CancellationToken ct);
    Task RecordSignInAsync(Guid staffId, bool success, DateTimeOffset? lockUntil, CancellationToken ct);
    Task CreateSessionAsync(Guid staffId, Guid securityVersion, byte[] tokenHash, DateTimeOffset expiresAt, CancellationToken ct);
    /// <summary>Staff id of a live session: not revoked, not expired, same security version, staff enabled.</summary>
    Task<Guid?> FindSessionStaffAsync(byte[] tokenHash, DateTimeOffset now, CancellationToken ct);
    Task RevokeSessionAsync(byte[] tokenHash, DateTimeOffset now, CancellationToken ct);
    Task SetPasswordAsync(Guid staffId, string passwordHash, CancellationToken ct);
}

public interface IPasswordHasher
{
    string Hash(string password);
    bool Verify(string password, string hash);
}

public sealed class AuthService(IAuthStore store, IPasswordHasher hasher, TimeProvider time)
{
    private const int MaxFailures = 5;
    private static readonly TimeSpan LockTime = TimeSpan.FromMinutes(15);
    private static readonly TimeSpan SessionLife = TimeSpan.FromHours(12);

    public async Task<LoginResponse> LoginAsync(LoginRequest request, CancellationToken ct)
    {
        var now = time.GetUtcNow();
        var login = (request.LoginName ?? "").Trim().ToUpperInvariant();
        var staff = login.Length == 0 ? null : await store.FindStaffAsync(login, ct);
        // Same answer for unknown user, wrong password, disabled and locked: no account probing.
        if (staff is null || !staff.IsEnabled || staff.PasswordHash is null || staff.LockedUntil > now)
            throw new SaviaException(Errors.BadCredentials);
        if (!hasher.Verify(request.Password ?? "", staff.PasswordHash))
        {
            await store.RecordSignInAsync(staff.StaffId, false, now + LockTime, ct);
            throw new SaviaException(Errors.BadCredentials);
        }
        var actor = await store.LoadActorAsync(staff.StaffId, ct) ?? throw new SaviaException(Errors.BadCredentials);
        await store.RecordSignInAsync(staff.StaffId, true, null, ct);
        var token = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32)).Replace('+', '-').Replace('/', '_').TrimEnd('=');
        var expires = now + SessionLife;
        await store.CreateSessionAsync(staff.StaffId, staff.SecurityVersion, HashToken(token), expires, ct);
        return new LoginResponse(token, expires, actor.StaffId, actor.DisplayName, [.. actor.Roles.Order()]);
    }

    public async Task<Actor> AuthenticateAsync(string token, CancellationToken ct)
    {
        if (token.Length is < 20 or > 100) throw new SaviaException(Errors.Unauthorized);
        var staffId = await store.FindSessionStaffAsync(HashToken(token), time.GetUtcNow(), ct)
            ?? throw new SaviaException(Errors.Unauthorized);
        return await store.LoadActorAsync(staffId, ct) ?? throw new SaviaException(Errors.Unauthorized);
    }

    public Task LogoutAsync(string token, CancellationToken ct) =>
        store.RevokeSessionAsync(HashToken(token), time.GetUtcNow(), ct);

    /// <summary>Owner or manager sets a staff password. A real deployment adds a reset flow on top.</summary>
    public Task SetPasswordAsync(Actor actor, Guid staffId, string password, CancellationToken ct)
    {
        Guard.Role(actor, Roles.Owner, Roles.Manager);
        return SetPasswordUncheckedAsync(staffId, password, ct);
    }

    /// <summary>Used by provisioning and tests. Never mapped to an endpoint without an actor.</summary>
    public Task SetPasswordUncheckedAsync(Guid staffId, string password, CancellationToken ct)
    {
        if (password is null || password.Length is < 10 or > 200)
            throw Errors.Invalid("auth.weak_password", "La contraseña necesita entre 10 y 200 caracteres.");
        return store.SetPasswordAsync(staffId, hasher.Hash(password), ct);
    }

    public static int MaxFailedSignIns => MaxFailures;

    private static byte[] HashToken(string token) => SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(token));
}
