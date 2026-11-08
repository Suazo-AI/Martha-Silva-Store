using Microsoft.Data.SqlClient;

namespace Martha.Store.Api.Internal;

// This interface keeps synthetic tests away from the real terminal and SQL service.
public interface IInternalOwnerConsole
{
    bool IsInputRedirected { get; }
    bool IsOutputRedirected { get; }
    bool IsErrorRedirected { get; }
    void WriteLine(string message);
    void WriteInputFeedback(string message) { }
    ConsoleKeyInfo ReadKey(bool intercept);
}

public sealed record InternalOwnerConsoleSettings(string EnvironmentName, bool Enabled, string? Connection)
{
    public override string ToString() => "InternalOwnerConsoleSettings { redacted }";
}

public static class InternalOwnerConsole
{
    public const string Argument = "--internal-bootstrap-owner";
    public const int Created = 0;
    public const int Refused = 2;
    public const int Closed = 3;
    public const int OutcomeUnknown = 4;
    private const string UnknownMessage = "Owner creation outcome UNKNOWN. Do not retry. An authorized operator must inspect safe staff state on this same database first; do not delete identities or switch targets.";

    // Malformed/case-changed variants are dispatched only to a refusal, never to normal startup.
    public static bool IsInvocation(string[] args) => args.Any(argument =>
        argument.StartsWith(Argument, StringComparison.OrdinalIgnoreCase));

    public static Task<int> Run(string[] args) => Run(args, new SystemOwnerConsole(), () =>
    {
        // Use the same environment/configuration conventions as Program, but no CLI overrides,
        // application Build/Run, hosted services, endpoints, migrations or seeding.
        var builder = WebApplication.CreateBuilder(new WebApplicationOptions { Args = [] });
        builder.Logging.ClearProviders();
        return new InternalOwnerConsoleSettings(builder.Environment.EnvironmentName,
            builder.Configuration.GetValue<bool>("InternalSavia:Enabled"),
            builder.Configuration.GetConnectionString("InternalSavia"));
    }, CreateOwner);

    public static async Task<int> Run(string[] args, IInternalOwnerConsole console,
        Func<InternalOwnerConsoleSettings> readSettings,
        Func<InternalOwnerConsoleSettings, string, string, string, CancellationToken, Task<InternalResult<Guid>>> createOwner,
        CancellationToken ct = default)
    {
        var attempted = false;
        try
        {
            if (args.Length != 1 || args[0] != Argument)
                return Refuse(console, "Refused: use only --internal-bootstrap-owner. No other arguments or credential arguments are accepted.");
            if (console.IsInputRedirected || console.IsOutputRedirected || console.IsErrorRedirected)
                return Refuse(console, "Refused: an interactive private console with no redirected input, output or error is required.");
            ct.ThrowIfCancellationRequested();
            var settings = readSettings();
            if (!string.Equals(settings.EnvironmentName, "Development", StringComparison.OrdinalIgnoreCase) || !settings.Enabled)
                return Refuse(console, "Refused: Development and InternalSavia:Enabled=true are both required.");
            if (string.IsNullOrWhiteSpace(settings.Connection))
                return Refuse(console, "Refused: an explicit guarded InternalSavia database connection is required.");
            InternalDatabaseGuard.Validate(settings.Connection);
            var target = new SqlConnectionStringBuilder(settings.Connection);
            // The shared name guard does not validate the server or prohibit implicit file attachment.
            if (!SafeServer(target.DataSource) || !string.IsNullOrEmpty(target.AttachDBFilename)
                || target.UserInstance || !string.IsNullOrEmpty(target.FailoverPartner))
                return Refuse(console, "Refused: invalid database target, failover partner or implicit database attachment.");

            console.WriteLine($"OFFLINE initial-owner maintenance. Server: {target.DataSource}; database: {target.InitialCatalog}.");
            console.WriteLine("No database/schema is created or migrated. Any existing staff row closes bootstrap.");
            console.WriteLine("Confirm separate authorization for this exact target and a private, unrecorded terminal.");
            console.WriteLine("Type PRIVATE in uppercase, then Enter. Your text is visible. Escape cancels. Do not paste.");
            var privacy = ReadValue(console, 7, out var publicRejection);
            if (privacy != "PRIVATE")
                return Refuse(console, "Cancelled before any database attempt. "
                    + (publicRejection ?? "Expected exactly PRIVATE in uppercase, without spaces."));
            console.WriteLine("PRIVATE accepted. Login, name and confirmations are visible. Passwords show stars. Press Enter once after each field.");
            console.WriteLine("New owner login (3-64 ASCII letters, digits, dot, underscore or hyphen):");
            var login = ReadValue(console, 64, out var loginRejection);
            if (!InternalSecurityRules.ValidLoginName(login))
                return Refuse(console, "Refused: invalid owner identity. Login input: "
                    + (loginRejection ?? (string.IsNullOrEmpty(login)
                        ? "No characters received. Type manually and press Enter once."
                        : "Use 3-64 ASCII letters, digits, dot, underscore or hyphen; no spaces."))
                    + " No database attempt was made.");
            console.WriteLine("New owner display name (1-120 characters):");
            var display = ReadValue(console, 120, out var displayRejection);
            if (!InternalSecurityRules.ValidDisplayName(display))
                return Refuse(console, "Refused: invalid owner identity. Display name input: "
                    + (displayRejection ?? (string.IsNullOrEmpty(display)
                        ? "No characters received. Type manually and press Enter once."
                        : "Use 1-120 characters without leading/trailing spaces or control characters."))
                    + " No database attempt was made.");
            console.WriteLine($"New password ({InternalSecurityRules.MinimumPasswordLength}-128 characters; stars):");
            var password = ReadValue(console, 128, out var passwordRejection, mask: true);
            if (!InternalSecurityRules.ValidPassword(password))
                return Refuse(console, "Refused: invalid password. Password input: "
                    + (passwordRejection ?? $"Use {InternalSecurityRules.MinimumPasswordLength}-128 characters, not only spaces; no control characters.")
                    + " No database attempt was made.");
            console.WriteLine("Repeat new password (stars):");
            if (!string.Equals(password, ReadValue(console, 128, out var repeatRejection, mask: true), StringComparison.Ordinal))
                return Refuse(console, "Refused: passwords do not match. "
                    + (repeatRejection is null ? "" : "Repeated password input: " + repeatRejection + " ")
                    + "No database attempt was made.");
            var confirmation = $"CREATE OWNER IN {target.DataSource}/{target.InitialCatalog}";
            console.WriteLine($"Final authorization: type exactly {confirmation}");
            if (ReadValue(console, confirmation.Length, out var finalRejection) != confirmation)
                return Refuse(console, "Cancelled before any database attempt. Final confirmation: "
                    + (finalRejection ?? "Type the exact authorization phrase manually."));
            ct.ThrowIfCancellationRequested();
            // Recheck redirection immediately before any effect. Never silently retry this callback.
            if (console.IsInputRedirected || console.IsOutputRedirected || console.IsErrorRedirected)
                return Refuse(console, "Refused: console is no longer private/interactive. No database attempt was made.");
            attempted = true;
            var result = await createOwner(settings, login!, display!, password!, ct);
            if (result.Success && result.Value != Guid.Empty)
            {
                WriteSafely(console, "Initial owner creation committed. No password was printed. Bootstrap is now closed.");
                return Created;
            }
            if (result.Error == "bootstrap_closed")
            {
                WriteSafely(console, "Refused: bootstrap is closed because staff already exists. No account was created by this attempt; this is not an account recovery path.");
                return Closed;
            }
            if (result.Error == "invalid_request")
                return Refuse(console, "Refused: the service rejected the identity/password before writing.");
            WriteSafely(console, UnknownMessage);
            return OutcomeUnknown;
        }
        catch (Exception)
        {
            // Exception messages, connection strings, request values and secrets must never reach output/logs.
            // After entering the service, even a cancellation/commit acknowledgement failure is uncertain.
            WriteSafely(console, attempted ? UnknownMessage : "Refused: configuration or private console input is unavailable/invalid. No database attempt was made.");
            return attempted ? OutcomeUnknown : Refused;
        }
    }

    private static async Task<InternalResult<Guid>> CreateOwner(InternalOwnerConsoleSettings settings,
        string login, string display, string password, CancellationToken ct)
    {
        // Freeze the validated target: configuration reloads cannot silently retarget this invocation.
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        { ["ConnectionStrings:InternalSavia"] = settings.Connection }).Build();
        var services = new ServiceCollection();
        services.AddLogging(logging => logging.ClearProviders());
        services.AddPrivateSavia(configuration);
        await using var provider = services.BuildServiceProvider();
        await using var scope = provider.CreateAsyncScope();
        return await scope.ServiceProvider.GetRequiredService<InternalOwnerBootstrap>()
            .CreateInitialOwner(login, display, password, ct);
    }

    public static bool SafeServer(string value) => value is { Length: >= 1 and <= 256 }
        && value.All(c => char.IsAsciiLetterOrDigit(c) || c is '.' or '_' or '-' or '\\' or ',' or ':' or '(' or ')' or '[' or ']');

    private static string? ReadValue(IInternalOwnerConsole console, int maximum)
        => ReadValue(console, maximum, out _);

    public static string? ReadValue(IInternalOwnerConsole console, int maximum,
        out string? rejection, bool mask = false)
    {
        var buffer = new char[maximum];
        var length = 0;
        rejection = null;
        try
        {
            while (true)
            {
                var key = console.ReadKey(intercept: true);
                if (key.Key == ConsoleKey.Escape) { rejection = "Escape received."; return null; }
                if (key.Key == ConsoleKey.Enter)
                {
                    if (key.Modifiers.HasFlag(ConsoleModifiers.Control))
                        rejection ??= "Control modifier received. Release Ctrl and type manually.";
                    console.WriteLine("");
                    return rejection is not null ? null : new string(buffer, 0, length);
                }
                // Drain a rejected line through Enter instead of returning queued secret characters
                // to the operator's shell. A rejected line can never be repaired into a truncated password.
                if (rejection is not null) continue;
                if (key.Modifiers.HasFlag(ConsoleModifiers.Control))
                { rejection = "Control modifier received. Release Ctrl and type manually."; continue; }
                if (key.Key == ConsoleKey.Backspace)
                {
                    if (length > 0)
                    {
                        buffer[--length] = '\0';
                        console.WriteInputFeedback("\b \b");
                    }
                    continue;
                }
                if (char.IsControl(key.KeyChar))
                { rejection = "Non-character key received. Type only the requested text."; continue; }
                if (length == maximum) { rejection = "Too many characters. Type only the requested text."; continue; }
                buffer[length++] = key.KeyChar;
                console.WriteInputFeedback(mask ? "*" : key.KeyChar.ToString());
            }
        }
        finally { Array.Clear(buffer); }
    }

    private static int Refuse(IInternalOwnerConsole console, string message)
    { WriteSafely(console, message); return Refused; }

    private static void WriteSafely(IInternalOwnerConsole console, string message)
    { try { console.WriteLine(message); } catch (Exception) { /* Never dump an exception into another output channel. */ } }

    private sealed class SystemOwnerConsole : IInternalOwnerConsole
    {
        public bool IsInputRedirected => Console.IsInputRedirected;
        public bool IsOutputRedirected => Console.IsOutputRedirected;
        public bool IsErrorRedirected => Console.IsErrorRedirected;
        public void WriteLine(string message) => Console.WriteLine(message);
        public void WriteInputFeedback(string message) => Console.Write(message);
        public ConsoleKeyInfo ReadKey(bool intercept) => Console.ReadKey(intercept);
    }
}
