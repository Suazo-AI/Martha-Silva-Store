using Savia.Application;

namespace Savia.Api;

/// <summary>
/// One-shot command <c>provision-passwords</c>: sets the password of the logins in <c>Savia:Provision:Logins</c>
/// through the real hasher, using one environment password per login. Shared fallback requires explicit opt-in.
/// CheckOnly verifies existing hashes without changing them. Passwords never come from the command line or repository.
/// A login whose stored hash already matches is left alone, so its sessions survive.
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
        var checkOnly = config.GetValue<bool>("Savia:Provision:CheckOnly");
        var shared = Environment.GetEnvironmentVariable(PasswordVariable);
        if (!checkOnly && !string.IsNullOrEmpty(shared) && Environment.GetEnvironmentVariable("SAVIA_PILOT_ALLOW_SHARED") != "1")
        {
            Console.Error.WriteLine("provision: shared password refused; SAVIA_PILOT_ALLOW_SHARED=1 is required.");
            return 2;
        }
        var store = services.GetRequiredService<IAuthStore>();
        var hasher = services.GetRequiredService<IPasswordHasher>();
        var auth = services.GetRequiredService<AuthService>();
        var failed = 0;
        foreach (var login in logins)
        {
            var variable = login.ToLowerInvariant() switch
            {
                "cajera.muestra" => "SAVIA_PILOT_PASSWORD_CAJERA",
                "supervisora.muestra" => "SAVIA_PILOT_PASSWORD_SUPERVISORA",
                "duena.muestra" => "SAVIA_PILOT_PASSWORD_DUENA",
                _ => "SAVIA_PILOT_PASSWORD_" + login.ToUpperInvariant().Replace('.', '_'),
            };
            var password = checkOnly ? null : Environment.GetEnvironmentVariable(variable) ?? shared;
            var staff = await store.FindStaffAsync(login.ToUpperInvariant(), ct);
            if (staff is null)
            {
                Console.Error.WriteLine($"provision: {login} not found.");
                failed++;
            }
            else if (string.IsNullOrEmpty(password))
            {
                if (!checkOnly || string.IsNullOrWhiteSpace(staff.PasswordHash))
                { Console.Error.WriteLine($"provision: {login} needs {variable} or an existing hash in check-only mode."); failed++; }
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
