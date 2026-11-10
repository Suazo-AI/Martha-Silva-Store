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
    [System.Runtime.Versioning.SupportedOSPlatform("windows")]
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

    // Simulates the loss of access before the emergency recovery: the Owner's password is replaced
    // with a value the operator never sees, hashed with the product's own hasher so the stored
    // format is exactly what the recovery service can verify.
    [Fact]
    [System.Runtime.Versioning.SupportedOSPlatform("windows")]
    public async Task F16_owner_password_is_replaced_with_an_unreadable_verified_hash()
    {
        if (Environment.GetEnvironmentVariable("SAVIA_OWNER_RECOVERY_PASSWORD_ROTATION") != "1") return;
        var manifestPath = InternalOwnerRecoveryConsole.ManifestPath;
        using var document = await JsonDocument.ParseAsync(new MemoryStream(await File.ReadAllBytesAsync(manifestPath)));
        var manifest = document.RootElement.Deserialize<OwnerRecoveryManifest>(
            new JsonSerializerOptions { UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow })!;
        await using var connection = new Microsoft.Data.SqlClient.SqlConnection(manifest.Connection());
        await connection.OpenAsync();
        var lost = "L" + Guid.NewGuid().ToString("N") + "9" + Guid.NewGuid().ToString("N");
        var hasher = new Microsoft.AspNetCore.Identity.PasswordHasher<InternalStaff>(
            Microsoft.Extensions.Options.Options.Create(new Microsoft.AspNetCore.Identity.PasswordHasherOptions { IterationCount = 210_000 }));
        var staff = new InternalStaff { Id = manifest.TargetId, LoginName = manifest.Login, NormalizedLoginName = manifest.Login, DisplayName = "Synthetic", Role = "Owner", Enabled = true, SecurityVersion = manifest.SecurityVersion, CreatedAt = DateTimeOffset.UtcNow, UpdatedAt = DateTimeOffset.UtcNow };
        var hash = hasher.HashPassword(staff, lost);
        // The product's own validator must accept the stored format.
        InternalOwnerRecoveryService.ValidateStoredHash(hash);
        Assert.Equal(Microsoft.AspNetCore.Identity.PasswordVerificationResult.Success, hasher.VerifyHashedPassword(staff, hash, lost));
        Assert.Equal(Microsoft.AspNetCore.Identity.PasswordVerificationResult.Failed, hasher.VerifyHashedPassword(staff, hash, "not-the-password"));
        await using (var command = connection.CreateCommand())
        {
            command.CommandText = "UPDATE savia_internal.Staff SET PasswordHash=@hash WHERE Id=@id";
            command.Parameters.AddWithValue("@hash", hash);
            command.Parameters.AddWithValue("@id", manifest.TargetId);
            Assert.Equal(1, await command.ExecuteNonQueryAsync());
        }
        // Read back independently: the stored hash verifies the unknown password and nothing else.
        await using (var command = connection.CreateCommand())
        {
            command.CommandText = "SELECT PasswordHash FROM savia_internal.Staff WHERE Id=@id";
            command.Parameters.AddWithValue("@id", manifest.TargetId);
            var stored = (string)(await command.ExecuteScalarAsync())!;
            InternalOwnerRecoveryService.ValidateStoredHash(stored);
            Assert.Equal(Microsoft.AspNetCore.Identity.PasswordVerificationResult.Success, hasher.VerifyHashedPassword(staff, stored, lost));
        }
    }
}
