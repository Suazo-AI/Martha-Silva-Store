using System.Text.Json;
using System.Text.Json.Serialization;
using Martha.Store.Api.Internal;
using Xunit;

namespace Martha.Store.Api.Tests;

// Operator pre-flight for the Windows emergency recovery console: proves that the protected
// manifest can actually be opened by the product before the operator types anything.
// It exercises the product's own document rules, connection rules and identity check.
public sealed class InternalOwnerRecoveryManifestTests
{
    private static bool Authorized => Environment.GetEnvironmentVariable("SAVIA_OWNER_RECOVERY_MANIFEST_CHECK") == "1";

    [Fact]
    public async Task F15_protected_manifest_opens_the_recovery_session_on_this_host()
    {
        if (!Authorized) return; // Host-specific pre-flight; never runs in CI.
        var path = InternalOwnerRecoveryConsole.ManifestPath;
        Assert.True(File.Exists(path), "The protected manifest is absent.");
        // A byte order mark makes System.Text.Json refuse the document before any check runs.
        var bytes = await File.ReadAllBytesAsync(path);
        Assert.False(bytes.Length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF, "The manifest must not start with a byte order mark.");
        using var document = await JsonDocument.ParseAsync(new MemoryStream(bytes));
        var names = document.RootElement.EnumerateObject().Select(property => property.Name).ToArray();
        Assert.Equal(10, names.Length);
        Assert.Equal(10, names.Distinct(StringComparer.Ordinal).Count());
        var manifest = document.RootElement.Deserialize<OwnerRecoveryManifest>(
            new JsonSerializerOptions { UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow })!;
        // The operator SID in the manifest must be the SID of the running account.
        var sid = System.Security.Principal.WindowsIdentity.GetCurrent().User?.Value;
        Assert.Equal(sid, manifest.OperatorSid);
        Assert.Equal(manifest.Confirmation,
            $"RECOVER {manifest.Server} {manifest.Catalog} {manifest.DatabaseId} {manifest.DatabaseGuid:D} {manifest.TargetId:D} {manifest.Login} {manifest.SecurityVersion:D}");
        // The guarded connection and the identity check are the product's own.
        await using var service = new InternalOwnerRecoveryService(manifest);
        await service.Inspect(default);
    }
}
