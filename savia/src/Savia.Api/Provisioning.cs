using Savia.Application;

namespace Savia.Api;

/// <summary>
/// One-shot command <c>provision-passwords</c>: sets the password of the logins in <c>Savia:Provision:Logins</c>
/// through the real hasher. The password comes from the environment variable <c>SAVIA_PILOT_PASSWORD</c>, never from
/// the command line or the repository. A login whose stored hash already matches is left alone, so its sessions survive.
/// </summary>
public static class Provisioning
{
    public const string Command = "provision-passwords";
    public const string PasswordVariable = "SAVIA_PILOT_PASSWORD";

    public static async Task<int> RunAsync(IServiceProvider services, IConfiguration config, CancellationToken ct = default)
    {
        var logins = (config["Savia:Provision:Logins"] ?? "")
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        if (logins.Length == 0)
        {
            Console.Error.WriteLine("provision: Savia:Provision:Logins is empty.");
            return 2;
        }
        var password = Environment.GetEnvironmentVariable(PasswordVariable);
        var store = services.GetRequiredService<IAuthStore>();
        var hasher = services.GetRequiredService<IPasswordHasher>();
        var auth = services.GetRequiredService<AuthService>();
        var failed = 0;
        foreach (var login in logins)
        {
            var staff = await store.FindStaffAsync(login.ToUpperInvariant(), ct);
            if (staff is null)
            {
                Console.Error.WriteLine($"provision: {login} not found.");
                failed++;
            }
            else if (string.IsNullOrEmpty(password))
            {
                if (staff.PasswordHash is null) { Console.Error.WriteLine($"provision: {login} has no password and {PasswordVariable} is empty."); failed++; }
                else Console.WriteLine($"provision: {login} kept");
            }
            else if (staff.PasswordHash is not null && hasher.Verify(password, staff.PasswordHash))
            {
                Console.WriteLine($"provision: {login} unchanged");
            }
            else
            {
                await auth.SetPasswordUncheckedAsync(staff.StaffId, password, ct);
                Console.WriteLine($"provision: {login} set");
            }
        }
        return failed == 0 ? 0 : 1;
    }
}
