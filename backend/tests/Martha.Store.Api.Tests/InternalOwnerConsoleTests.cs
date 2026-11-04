using Martha.Store.Api.Internal;
using Xunit;

namespace Martha.Store.Api.Tests;

// Only fake terminal keys and callbacks. Never invokes the real bootstrap service or opens SQL.
public sealed class InternalOwnerConsoleTests
{
    private const string Secret = "SYNTHETIC-only-secret-marker";
    private const string Connection = "Server=console-test.invalid;Database=SaviaInternalTest_Console;Integrated Security=true;Encrypt=true";
    private const string Confirmation = "CREATE OWNER IN console-test.invalid/SaviaInternalTest_Console";
    private static readonly Guid CreatedId = Guid.Parse("12345678-1234-1234-1234-123456789abc");
    private static InternalOwnerConsoleSettings Settings() => new("Development", true, Connection);
    private static FakeConsole Ready() => new("PRIVATE", "synthetic-owner", "Synthetic Owner", Secret, Secret, Confirmation);

    [Fact]
    public void Normal_startup_and_migration_arguments_do_not_dispatch_bootstrap()
    {
        Assert.False(InternalOwnerConsole.IsInvocation([]));
        Assert.False(InternalOwnerConsole.IsInvocation(["--migrate"]));
        Assert.False(InternalOwnerConsole.IsInvocation(["--seed-synthetic", "--seed-savia-synthetic"]));
        Assert.True(InternalOwnerConsole.IsInvocation([InternalOwnerConsole.Argument]));
        Assert.True(InternalOwnerConsole.IsInvocation([InternalOwnerConsole.Argument + "=ignored"]));
        Assert.True(InternalOwnerConsole.IsInvocation(["--INTERNAL-BOOTSTRAP-OWNER"]));
    }

    [Theory]
    [InlineData("--migrate")]
    [InlineData("--password=SYNTHETIC-only-secret-marker")]
    [InlineData("--seed-synthetic")]
    [InlineData("--InternalSavia:Enabled=true")]
    public async Task Extra_arguments_are_refused_before_configuration_or_input(string extra)
    {
        var console = Ready();
        var calls = 0;
        var settingsReads = 0;
        var result = await InternalOwnerConsole.Run([InternalOwnerConsole.Argument, extra], console,
            () => { settingsReads++; return Settings(); },
            (_, _, _, _, _) => { calls++; return Task.FromResult(InternalResult<Guid>.Ok(CreatedId)); });
        Assert.Equal(InternalOwnerConsole.Refused, result);
        Assert.Equal(0, calls);
        Assert.Equal(0, settingsReads);
        Assert.Equal(0, console.ReadCount);
        Assert.DoesNotContain(Secret, console.Output + console.InputFeedback);
    }

    [Theory]
    [InlineData("--INTERNAL-BOOTSTRAP-OWNER")]
    [InlineData("--internal-bootstrap-owner=secret")]
    [InlineData("--internal-bootstrap-owner-typo")]
    [InlineData("--migrate")]
    public async Task Only_the_exact_command_is_accepted(string argument)
    {
        var console = Ready();
        Assert.Equal(InternalOwnerConsole.Refused, await Run(console, args: [argument]));
        Assert.Equal(0, console.ReadCount);
    }

    [Theory]
    [InlineData(true, false, false)]
    [InlineData(false, true, false)]
    [InlineData(false, false, true)]
    public async Task Any_redirected_stream_refuses_without_reading_configuration(bool input, bool output, bool error)
    {
        var console = Ready();
        var settingsReads = 0;
        console.IsInputRedirected = input; console.IsOutputRedirected = output; console.IsErrorRedirected = error;
        Assert.Equal(InternalOwnerConsole.Refused, await Run(console,
            readSettings: () => { settingsReads++; return Settings(); }));
        Assert.Equal(0, settingsReads);
        Assert.Contains("interactive private console", console.Output);
        Assert.Equal(0, console.ReadCount);
    }

    [Theory]
    [InlineData("Production", true)]
    [InlineData("Staging", true)]
    [InlineData("Development", false)]
    [InlineData("", true)]
    public async Task Environment_and_feature_gate_are_both_required(string environment, bool enabled)
    {
        var console = Ready();
        Assert.Equal(InternalOwnerConsole.Refused, await Run(console,
            readSettings: () => new(environment, enabled, Connection)));
        Assert.Equal(0, console.ReadCount);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("Not a connection string")]
    [InlineData("Server=console-test.invalid;Database=Production")]
    [InlineData("Server=console-test.invalid;Database=SaviaInternalTest_Console;MultipleActiveResultSets=true")]
    [InlineData("Database=SaviaInternalTest_Console")]
    [InlineData("Server=console-test.invalid;Database=SaviaInternalTest_Console;AttachDbFilename=/tmp/not-a-file.mdf")]
    [InlineData("Server=console-test.invalid;Database=SaviaInternalTest_Console;User Instance=true")]
    [InlineData("Server=console-test.invalid;Database=SaviaInternalTest_Console;Failover Partner=unconfirmed.invalid")]
    [InlineData("Server='console-test.invalid\nspoof';Database=SaviaInternalTest_Console")]
    public async Task Invalid_or_implicit_creation_targets_fail_closed_without_SQL(string? connection)
    {
        var console = Ready();
        Assert.Equal(InternalOwnerConsole.Refused, await Run(console,
            readSettings: () => Settings() with { Connection = connection }));
        Assert.Equal(0, console.ReadCount);
    }

    [Fact]
    public async Task Failover_partner_cannot_retarget_the_confirmed_database_or_expose_credentials()
    {
        var console = Ready();
        Assert.Equal(InternalOwnerConsole.Refused, await Run(console, readSettings: () => Settings() with
        { Connection = Connection + ";Failover Partner=unconfirmed.invalid;Password=" + Secret }));
        Assert.Equal(0, console.ReadCount);
        Assert.DoesNotContain(Secret, console.Output + console.InputFeedback);
        Assert.DoesNotContain("unconfirmed.invalid", console.Output);
    }

    [Fact]
    public async Task Configuration_failure_is_sanitized_and_not_an_attempt()
    {
        var console = Ready();
        Assert.Equal(InternalOwnerConsole.Refused, await Run(console,
            readSettings: () => throw new InvalidOperationException(Secret)));
        Assert.DoesNotContain(Secret, console.Output + console.InputFeedback);
        Assert.Contains("No database attempt", console.Output);
        Assert.DoesNotContain(Connection, Settings().ToString());
    }

    [Fact]
    public async Task Happy_path_is_one_call_after_both_confirmations_without_password_disclosure()
    {
        var console = Ready();
        var calls = 0;
        var result = await Run(console, callback: (settings, login, display, password, _) =>
        {
            calls++;
            Assert.Equal(Connection, settings.Connection);
            Assert.Equal("synthetic-owner", login);
            Assert.Equal("Synthetic Owner", display);
            Assert.Equal(Secret, password);
            Assert.Equal(0, console.RemainingKeys);
            return Task.FromResult(InternalResult<Guid>.Ok(CreatedId));
        });
        Assert.Equal(InternalOwnerConsole.Created, result);
        Assert.Equal(1, calls);
        Assert.All(console.Intercepts, Assert.True);
        Assert.DoesNotContain(Secret, console.Output + console.InputFeedback);
        Assert.DoesNotContain("synthetic-owner", console.Output);
        Assert.DoesNotContain(CreatedId.ToString(), console.Output);
        Assert.DoesNotContain(Connection, console.Output);
        Assert.Contains("creation committed", console.Output);
    }

    [Theory]
    [InlineData("NOT PRIVATE", "synthetic-owner", "Synthetic Owner", Secret, Secret, Confirmation)]
    [InlineData("PRIVATE", "invalid login", "Synthetic Owner", Secret, Secret, Confirmation)]
    [InlineData("PRIVATE", "synthetic-owner", " leading", Secret, Secret, Confirmation)]
    [InlineData("PRIVATE", "synthetic-owner", "Synthetic Owner", "short", "short", Confirmation)]
    [InlineData("PRIVATE", "synthetic-owner", "Synthetic Owner", Secret, "different synthetic secret", Confirmation)]
    [InlineData("PRIVATE", "synthetic-owner", "Synthetic Owner", Secret, Secret, "CREATE OWNER IN another-target")]
    public async Task Invalid_inputs_and_missing_confirmations_never_invoke_service(params string[] lines)
    {
        var console = new FakeConsole(lines);
        Assert.Equal(InternalOwnerConsole.Refused, await Run(console));
        Assert.DoesNotContain(Secret, console.Output + console.InputFeedback);
    }

    [Fact]
    public async Task Identity_and_confirmations_are_visible_while_both_passwords_are_masked()
    {
        var console = Ready();
        Assert.Equal(InternalOwnerConsole.Created, await Run(console,
            callback: (_, _, _, _, _) => Task.FromResult(InternalResult<Guid>.Ok(CreatedId))));
        Assert.Equal("PRIVATE" + "synthetic-owner" + "Synthetic Owner" + new string('*', Secret.Length * 2) + Confirmation, console.InputFeedback);
        Assert.DoesNotContain(Secret, console.Output + console.InputFeedback);
        Assert.Contains("synthetic-owner", console.Output + console.InputFeedback);
        Assert.All(console.Intercepts, Assert.True);
    }

    [Theory]
    [InlineData("private", "Expected exactly PRIVATE")]
    [InlineData("", "Expected exactly PRIVATE")]
    [InlineData("PRIVATEX\b", "Too many characters")]
    public async Task Public_confirmation_reports_safe_rejection_reason_without_calling_service(string input, string reason)
    {
        var console = new FakeConsole(input);
        Assert.Equal(InternalOwnerConsole.Refused, await Run(console));
        Assert.Equal(0, console.RemainingKeys);
        Assert.Contains(reason, console.Output);
        Assert.Contains("Cancelled before any database attempt", console.Output);
    }

    [Fact]
    public async Task Control_in_public_confirmation_reports_reason_and_drains_without_calling_service()
    {
        var console = new FakeConsole();
        console.AddKey(new ConsoleKeyInfo('v', ConsoleKey.V, false, false, true));
        foreach (var character in "PRIVATE")
            console.AddKey(new ConsoleKeyInfo(character, ConsoleKey.A, true, false, false));
        console.AddKey(new ConsoleKeyInfo('\r', ConsoleKey.Enter, false, false, false));
        Assert.Equal(InternalOwnerConsole.Refused, await Run(console));
        Assert.Equal(0, console.RemainingKeys);
        Assert.Contains("Control modifier received", console.Output);
        Assert.DoesNotContain("New owner login", console.Output);
        Assert.Equal("", console.InputFeedback);
    }

    [Fact]
    public async Task Empty_login_reports_no_characters_without_calling_service()
    {
        var console = new FakeConsole("PRIVATE", "");
        Assert.Equal(InternalOwnerConsole.Refused, await Run(console));
        Assert.Contains("Login input: No characters received", console.Output);
        Assert.DoesNotContain("New owner display name", console.Output);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Identity_control_rejection_names_field_but_never_prints_input(bool display)
    {
        var console = display ? new FakeConsole("PRIVATE", "savia-test-owner") : new FakeConsole("PRIVATE");
        console.AddKey(new ConsoleKeyInfo('v', ConsoleKey.V, false, false, true));
        foreach (var character in "SYNTHETIC-private-input-marker")
            console.AddKey(new ConsoleKeyInfo(character, ConsoleKey.A, false, false, false));
        console.AddKey(new ConsoleKeyInfo('\r', ConsoleKey.Enter, false, false, false));
        Assert.Equal(InternalOwnerConsole.Refused, await Run(console));
        Assert.Equal(0, console.RemainingKeys);
        Assert.Contains((display ? "Display name input: " : "Login input: ") + "Control modifier received", console.Output);
        Assert.DoesNotContain("SYNTHETIC-private-input-marker", console.Output);
        Assert.Equal("PRIVATE" + (display ? "savia-test-owner" : ""), console.InputFeedback);
    }

    [Fact]
    public async Task Recommended_synthetic_identity_is_visible_and_accepted()
    {
        var console = new FakeConsole("PRIVATE", "savia-test-owner", "Synthetic Owner", Secret, Secret, Confirmation);
        var calls = 0;
        Assert.Equal(InternalOwnerConsole.Created, await Run(console, callback: (_, login, display, _, _) =>
        {
            calls++;
            Assert.Equal("savia-test-owner", login);
            Assert.Equal("Synthetic Owner", display);
            return Task.FromResult(InternalResult<Guid>.Ok(CreatedId));
        }));
        Assert.Equal(1, calls);
        Assert.DoesNotContain("savia-test-owner", console.Output);
        Assert.Equal("PRIVATE" + "savia-test-owner" + "Synthetic Owner" + new string('*', Secret.Length * 2) + Confirmation, console.InputFeedback);
    }

    [Fact]
    public async Task Overlong_password_and_escape_cancel_before_any_service_call()
    {
        var overlong = new FakeConsole("PRIVATE", "synthetic-owner", "Synthetic Owner", new string('x', 160));
        Assert.Equal(InternalOwnerConsole.Refused, await Run(overlong));
        Assert.Equal(0, overlong.RemainingKeys);
        Assert.All(overlong.Intercepts, Assert.True);
        Assert.DoesNotContain(new string('x', 160), overlong.Output);
        var escaped = new FakeConsole("PRIVATE");
        escaped.AddKey(new ConsoleKeyInfo('\u001b', ConsoleKey.Escape, false, false, false));
        Assert.Equal(InternalOwnerConsole.Refused, await Run(escaped));
        Assert.Equal(0, escaped.RemainingKeys);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Rejected_control_input_drains_the_secret_line_before_returning(bool controlModifier)
    {
        var console = new FakeConsole("PRIVATE", "synthetic-owner", "Synthetic Owner");
        console.AddKey(new ConsoleKeyInfo('\t', ConsoleKey.Tab, false, false, controlModifier));
        foreach (var character in Secret)
            console.AddKey(new ConsoleKeyInfo(character, ConsoleKey.A, false, false, false));
        console.AddKey(new ConsoleKeyInfo('\n', ConsoleKey.Enter, false, false, false));
        Assert.Equal(InternalOwnerConsole.Refused, await Run(console));
        Assert.Equal(0, console.RemainingKeys);
        Assert.All(console.Intercepts, Assert.True);
        Assert.DoesNotContain(Secret, console.Output + console.InputFeedback);
        Assert.Contains(controlModifier ? "Control modifier received" : "Non-character key received", console.Output);
    }

    [Fact]
    public async Task Backspace_edits_the_secret_without_echo()
    {
        var console = new FakeConsole("PRIVATE", "synthetic-owner", "Synthetic Owner", Secret + "x\b", Secret, Confirmation);
        Assert.Equal(InternalOwnerConsole.Created, await Run(console, callback: (_, _, _, password, _) =>
        {
            Assert.Equal(Secret, password);
            return Task.FromResult(InternalResult<Guid>.Ok(CreatedId));
        }));
        Assert.All(console.Intercepts, Assert.True);
        Assert.DoesNotContain(Secret, console.Output + console.InputFeedback);
        Assert.Contains(new string('*', Secret.Length + 1) + "\b \b", console.InputFeedback);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Password_minimum_is_consistent_between_prompt_and_validation(bool belowMinimum)
    {
        var password = new string('x', InternalSecurityRules.MinimumPasswordLength - (belowMinimum ? 1 : 0));
        var console = new FakeConsole("PRIVATE", "synthetic-owner", "Synthetic Owner", password, password, Confirmation);
        var calls = 0;
        var result = await Run(console, callback: (_, _, _, actual, _) =>
        {
            calls++;
            Assert.Equal(password, actual);
            return Task.FromResult(InternalResult<Guid>.Ok(CreatedId));
        });
        Assert.Equal(belowMinimum ? InternalOwnerConsole.Refused : InternalOwnerConsole.Created, result);
        Assert.Equal(belowMinimum ? 0 : 1, calls);
        Assert.Contains($"New password ({InternalSecurityRules.MinimumPasswordLength}-128 characters; stars):", console.Output);
        Assert.DoesNotContain(password, console.Output + console.InputFeedback);
    }

    [Fact]
    public async Task Existing_staff_closes_bootstrap_without_retry_or_recovery()
    {
        var console = Ready();
        var calls = 0;
        Assert.Equal(InternalOwnerConsole.Closed, await Run(console, callback: (_, _, _, _, _) =>
        { calls++; return Task.FromResult(InternalResult<Guid>.Fail("bootstrap_closed")); }));
        Assert.Equal(1, calls);
        Assert.Contains("bootstrap is closed", console.Output);
        Assert.DoesNotContain("creation committed", console.Output);
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task Service_exceptions_and_cancellation_are_unknown_not_failed_and_never_retried(bool cancelled)
    {
        var console = Ready();
        var calls = 0;
        Assert.Equal(InternalOwnerConsole.OutcomeUnknown, await Run(console, callback: (_, _, _, _, _) =>
        {
            calls++;
            throw cancelled ? new OperationCanceledException(Secret) : new InvalidOperationException(Secret);
        }));
        Assert.Equal(1, calls);
        Assert.Contains("UNKNOWN. Do not retry", console.Output);
        Assert.DoesNotContain(Secret, console.Output + console.InputFeedback);
        Assert.DoesNotContain("failed", console.Output, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("creation committed", console.Output);
    }

    [Theory]
    [InlineData(null)]
    [InlineData(Secret)]
    public async Task Malformed_or_unknown_service_result_is_sanitized_and_uncertain(string? error)
    {
        var console = Ready();
        Assert.Equal(InternalOwnerConsole.OutcomeUnknown, await Run(console, callback: (_, _, _, _, _) =>
            Task.FromResult(new InternalResult<Guid>(Guid.Empty, error))));
        Assert.Contains("UNKNOWN. Do not retry", console.Output);
        Assert.DoesNotContain(Secret, console.Output + console.InputFeedback);
    }

    [Fact]
    public async Task Cancellation_before_any_attempt_is_a_refusal()
    {
        using var cancellation = new CancellationTokenSource();
        cancellation.Cancel();
        var console = Ready();
        Assert.Equal(InternalOwnerConsole.Refused, await Run(console, ct: cancellation.Token));
        Assert.Equal(0, console.ReadCount);
    }

    private static async Task<int> Run(FakeConsole console, string[]? args = null,
        Func<InternalOwnerConsoleSettings>? readSettings = null,
        Func<InternalOwnerConsoleSettings, string, string, string, CancellationToken, Task<InternalResult<Guid>>>? callback = null,
        CancellationToken ct = default)
    {
        var unexpectedCalls = 0;
        var result = await InternalOwnerConsole.Run(args ?? [InternalOwnerConsole.Argument], console, readSettings ?? Settings,
            callback ?? ((_, _, _, _, _) => { unexpectedCalls++; return Task.FromResult(InternalResult<Guid>.Ok(CreatedId)); }), ct);
        Assert.Equal(0, unexpectedCalls);
        return result;
    }

    private sealed class FakeConsole(params string[] lines) : IInternalOwnerConsole
    {
        private readonly Queue<ConsoleKeyInfo> keys = new(lines.SelectMany(line => (line + "\n").Select(character =>
            new ConsoleKeyInfo(character, character switch { '\n' => ConsoleKey.Enter, '\b' => ConsoleKey.Backspace, _ => ConsoleKey.A }, false, false, false))));
        private readonly List<string> output = [];
        private readonly List<string> inputFeedback = [];
        public bool IsInputRedirected { get; set; }
        public bool IsOutputRedirected { get; set; }
        public bool IsErrorRedirected { get; set; }
        public List<bool> Intercepts { get; } = [];
        public int ReadCount => Intercepts.Count;
        public int RemainingKeys => keys.Count;
        public string Output => string.Join('\n', output);
        public string InputFeedback => string.Concat(inputFeedback);
        public void AddKey(ConsoleKeyInfo key) => keys.Enqueue(key);
        public void WriteLine(string message) => output.Add(message);
        public void WriteInputFeedback(string message) => inputFeedback.Add(message);
        public ConsoleKeyInfo ReadKey(bool intercept)
        { Intercepts.Add(intercept); return keys.Dequeue(); }
    }
}
