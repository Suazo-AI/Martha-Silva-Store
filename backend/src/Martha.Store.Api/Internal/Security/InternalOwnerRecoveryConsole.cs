using System.Runtime.Versioning;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Security.Cryptography;

namespace Martha.Store.Api.Internal;

public static class InternalOwnerRecoveryConsole
{
    public const string Argument = "--internal-recover-owner";
    public const string ManifestPath = @"C:\ProgramData\SAVIA\maintenance\owner-recovery.json";
    public static bool IsInvocation(string[] args) => args.Any(a => a.TrimStart('-', '/', ' ', '\t')
        .StartsWith("internal-recover-owner", StringComparison.OrdinalIgnoreCase));
    public static bool Private(IInternalOwnerConsole c) => !c.IsInputRedirected && !c.IsOutputRedirected && !c.IsErrorRedirected;
    public static async Task<int> Run(string[] args)
    {
        var console = new RecoveryTerminal();
        return await Run(args, console, async ct =>
        {
            if (!OperatingSystem.IsWindows()) throw new PlatformNotSupportedException();
            var environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT")
                ?? Environment.GetEnvironmentVariable("DOTNET_ENVIRONMENT");
            if (environment != "Development" || Environment.GetEnvironmentVariable("InternalSavia__Enabled") != "true")
                throw new InvalidOperationException();
            return await OpenWindows(ct);
        });
    }
    [SupportedOSPlatform("windows")]
    private static async Task<RecoverySession> OpenWindows(CancellationToken ct)
    {
        var sid = WindowsIdentity.GetCurrent().User?.Value ?? throw new InvalidOperationException();
        foreach (var directory in new[] { @"C:\ProgramData\SAVIA", @"C:\ProgramData\SAVIA\maintenance" })
            ValidateAcl(new DirectoryInfo(directory), sid, false);
        var info = new FileInfo(ManifestPath);
        ValidateAcl(info, sid, false);
        using var input = new FileStream(ManifestPath, FileMode.Open, FileAccess.Read, FileShare.Read);
        if (input.Length > 8192) throw new InvalidOperationException();
        using var document = await JsonDocument.ParseAsync(input, cancellationToken: ct);
        var names = document.RootElement.EnumerateObject().Select(p => p.Name).ToArray();
        if (names.Length != 10 || names.Distinct(StringComparer.Ordinal).Count() != 10) throw new InvalidOperationException();
        var manifest = document.RootElement.Deserialize<OwnerRecoveryManifest>(new JsonSerializerOptions
            { UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow }) ?? throw new InvalidOperationException();
        ValidateOperatorSid(manifest.OperatorSid, sid);
        _ = manifest.Connection();
        ValidateAcl(info, sid, false);
        var journalInfo = new FileInfo(@"C:\ProgramData\SAVIA\maintenance\owner-recovery.journal");
        ValidateAcl(journalInfo, sid, true);
        var journal = new RecoveryFileJournal(journalInfo.FullName, manifest);
        InternalOwnerRecoveryService? service = null;
        try
        {
            service = new InternalOwnerRecoveryService(manifest);
            await service.Inspect(ct);
            return new RecoverySession(manifest, journal, service.Recover, async () =>
            { try { await service.DisposeAsync(); } finally { journal.Dispose(); } });
        }
        catch { try { if (service is not null) await service.DisposeAsync(); } finally { journal.Dispose(); } throw; }
    }
    public static void ValidateOperatorSid(string expected, string? actual)
    {
        if (string.IsNullOrWhiteSpace(expected) || string.IsNullOrWhiteSpace(actual)
            || expected != actual) throw new InvalidOperationException();
    }
    [SupportedOSPlatform("windows")]
    private static void ValidateAcl(FileSystemInfo info, string sid, bool journal)
    {
        if (!info.Exists || (info.Attributes & FileAttributes.ReparsePoint) != 0) throw new InvalidOperationException();
        FileSystemSecurity acl = info is DirectoryInfo d ? d.GetAccessControl() : ((FileInfo)info).GetAccessControl();
        if (!acl.AreAccessRulesProtected) throw new InvalidOperationException();
        var owner = (acl.GetOwner(typeof(SecurityIdentifier)) ?? throw new InvalidOperationException()).Value;
        if (owner is not ("S-1-5-18" or "S-1-5-32-544")) throw new InvalidOperationException();
        foreach (FileSystemAccessRule rule in acl.GetAccessRules(true, true, typeof(SecurityIdentifier)))
        {
            var actor = rule.IdentityReference.Value;
            var privileged = actor is "S-1-5-18" or "S-1-5-32-544";
            var writes = FileSystemRights.Write | FileSystemRights.Delete | FileSystemRights.DeleteSubdirectoriesAndFiles
                | FileSystemRights.ChangePermissions | FileSystemRights.TakeOwnership;
            if (rule.AccessControlType == AccessControlType.Allow && (rule.FileSystemRights & writes) != 0
                && !privileged && !(journal && actor == sid && (rule.FileSystemRights &
                    (FileSystemRights.Delete | FileSystemRights.ChangePermissions | FileSystemRights.TakeOwnership)) == 0))
                throw new InvalidOperationException();
        }
    }
    public static async Task<int> Run(string[] args, IInternalOwnerConsole console,
        Func<CancellationToken, Task<RecoverySession>> open, CancellationToken ct = default)
    {
        var attempted = false;
        RecoverySession? session = null;
        OwnerRecoveryOutcome? acknowledged = null;
        var code = 2;
        async Task<int> Perform()
        {
            if (args.Length != 1 || args[0] != Argument || !Private(console)) return 2;
            ct.ThrowIfCancellationRequested();
            session = await open(ct);
            int Refuse() { session.Journal.Write("REFUSED", Guid.NewGuid(), Guid.Empty); return 2; }
            console.WriteLine("Private Owner maintenance. Type PRIVATE. Escape cancels.");
            if (InternalOwnerConsole.ReadValue(console, 7, out _) != "PRIVATE") return Refuse();
            console.WriteLine(session.Manifest.Confirmation);
            if (InternalOwnerConsole.ReadValue(console, 1024, out _) != session.Manifest.Confirmation) return Refuse();
            console.WriteLine("Replacement password (15-128 characters):");
            var password = InternalOwnerConsole.ReadValue(console, 128, out _, mask: true);
            if (!InternalSecurityRules.ValidPassword(password)) return Refuse();
            console.WriteLine("Repeat password:");
            var repeat = InternalOwnerConsole.ReadValue(console, 128, out _, mask: true);
            if (repeat != password || !Private(console)) return Refuse();
            ct.ThrowIfCancellationRequested();
            attempted = true;
            acknowledged = await session.Recover(password!, session.Journal, () => Private(console), ct);
            return (int)acknowledged.Value;
        }
        try { code = await Perform(); }
        catch (Exception) { code = attempted ? 4 : 2; }
        finally
        {
            if (session is not null)
            {
                try { await session.DisposeAsync(); }
                catch (Exception)
                {
                    // A known service result includes transaction cleanup and a durable terminal receipt.
                    // Later connection/handle cleanup cannot contradict that acknowledged result.
                    code = acknowledged is { } known ? (int)known : attempted ? 4 : 2;
                }
            }
        }
        try
        {
            if (attempted) console.WriteLine(code == 0 ? "Recovery committed; receipt flushed."
                : code == 4 ? "UNKNOWN. Do not retry. Reconcile recorded versions with authorization."
                : "Recovery refused or confirmed aborted.");
            else if (code != 0) console.WriteLine("Refused: private maintenance unavailable.");
        }
        catch (Exception)
        {
            // Loss of terminal output is not loss of a persisted acknowledgement.
            if (acknowledged is null) code = attempted ? 4 : 2;
        }
        return code;
    }
    private sealed class RecoveryTerminal : IInternalOwnerConsole
    {
        public bool IsInputRedirected => Console.IsInputRedirected;
        public bool IsOutputRedirected => Console.IsOutputRedirected;
        public bool IsErrorRedirected => Console.IsErrorRedirected;
        public void WriteLine(string value) => Console.WriteLine(value);
        public void WriteInputFeedback(string value) => Console.Write(value);
        public ConsoleKeyInfo ReadKey(bool intercept) => Console.ReadKey(intercept);
    }
}
public sealed class RecoverySession(OwnerRecoveryManifest manifest, IOwnerRecoveryJournal journal,
    Func<string, IOwnerRecoveryJournal, Func<bool>, CancellationToken, Task<OwnerRecoveryOutcome>> recover,
    Func<ValueTask> dispose) : IAsyncDisposable
{
    public OwnerRecoveryManifest Manifest => manifest;
    public IOwnerRecoveryJournal Journal => journal;
    public Func<string, IOwnerRecoveryJournal, Func<bool>, CancellationToken, Task<OwnerRecoveryOutcome>> Recover => recover;
    public ValueTask DisposeAsync() => dispose();
}
// Existing protected file only. No provisioning or directory creation. Exclusive writer, durable flush.
public sealed class RecoveryFileJournal : IOwnerRecoveryJournal, IDisposable
{
    private readonly FileStream file;
    private readonly OwnerRecoveryManifest manifest;
    private readonly string binary;
    public RecoveryFileJournal(string path, OwnerRecoveryManifest manifest)
    {
        this.manifest = manifest;
        binary = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(typeof(RecoveryFileJournal).Assembly.Location)));
        file = new FileStream(path, FileMode.Open, FileAccess.Write, FileShare.None, 4096, FileOptions.WriteThrough);
        file.Seek(0, SeekOrigin.End);
    }
    public void Write(string result, Guid operation, Guid proposedVersion)
    {
        if (result is not ("INTENT" or "COMMITTED" or "ABORTED" or "REFUSED")) throw new InvalidOperationException();
        if (file.Length > 16 * 1024 * 1024) throw new IOException();
        var row = JsonSerializer.SerializeToUtf8Bytes(new { operation, utc = DateTimeOffset.UtcNow, binary,
            manifest.OperatorSid, manifest.SqlSid, manifest.Server, manifest.Catalog, manifest.DatabaseId,
            manifest.DatabaseGuid, manifest.TargetId, manifest.Login, expected = manifest.SecurityVersion, proposedVersion, result });
        file.Write(row); file.WriteByte(10); file.Flush(flushToDisk: true);
    }
    public void Dispose() => file.Dispose();
}
