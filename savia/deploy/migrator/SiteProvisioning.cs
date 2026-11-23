using System.Security.Cryptography;
using System.Data.Common;

// D0 day zero without SQL. Branches, their store location and cash registers, and staff are not synced (V053):
// the operator runs each command on the hub database and on every store database that needs the record, with the
// same ids. Both commands are retry-safe; a different definition of an id, code or login is refused (V062).
//   --provision-branch  one branch, its store location and one register; rerun with another register to add one
//   --provision-staff   one staff member, one role and an optional branch access (--approver lets them approve)
// --set-password gives the staff member a password on this database. It reads SAVIA_STAFF_PASSWORD when set, so the
// operator can give the same password on several databases; otherwise it prints a new one once, on a
// "staff-password: " line. The password never reaches SQL: only its PBKDF2 hash does.
internal sealed record BranchRequest(Guid BranchId, string Code, string Name, string StoreName, Guid LocationId,
    string LocationCode, string LocationName, Guid RegisterId, string RegisterCode, string RegisterName)
{
    private static readonly string[] Required = ["--branch-code", "--branch-name", "--store-name", "--location-code",
        "--location-name", "--register-code", "--register-name"];

    /// <summary>Returns the request, or an error message for exit code 2.</summary>
    internal static (BranchRequest? Request, string? Error) Parse(Func<string, string?> option)
    {
        if (!Guid.TryParse(option("--branch-id"), out var branch) || !Guid.TryParse(option("--location-id"), out var location) ||
            !Guid.TryParse(option("--register-id"), out var register))
            return (null, "--branch-id, --location-id and --register-id must be GUIDs.");
        if (Required.FirstOrDefault(name => string.IsNullOrWhiteSpace(option(name))) is { } missing)
            return (null, $"{missing} is required.");
        return (new BranchRequest(branch, option("--branch-code")!, option("--branch-name")!, option("--store-name")!, location,
            option("--location-code")!, option("--location-name")!, register, option("--register-code")!,
            option("--register-name")!), null);
    }

    internal Task RunAsync(DbConnection connection) =>
        NodeRequest.Exec(connection, "core.usp_ProvisionBranch", ("@BranchId", BranchId), ("@BranchCode", Code),
            ("@BranchName", Name), ("@StoreDisplayName", StoreName), ("@LocationId", LocationId),
            ("@LocationCode", LocationCode), ("@LocationName", LocationName), ("@RegisterId", RegisterId),
            ("@RegisterCode", RegisterCode), ("@RegisterName", RegisterName));
}

internal sealed record StaffRequest(Guid StaffId, string Login, string DisplayName, string Role, Guid? BranchId,
    bool Approver, bool SetPassword)
{
    internal const string PasswordPrefix = "staff-password: ";
    internal const string PasswordVariable = "SAVIA_STAFF_PASSWORD";
    // Same format and work factor as Savia.Infrastructure.Pbkdf2PasswordHasher, which verifies it at sign-in.
    private const int Iterations = 600_000;

    /// <summary>Returns the request, or an error message for exit code 2.</summary>
    internal static (StaffRequest? Request, string? Error) Parse(Func<string, string?> option, Func<string, bool> flag)
    {
        if (!Guid.TryParse(option("--staff-id"), out var staff))
            return (null, "--staff-id must be a GUID.");
        Guid? branch = null;
        if (option("--branch-id") is { } text)
        {
            if (!Guid.TryParse(text, out var b))
                return (null, "--branch-id must be a GUID.");
            branch = b;
        }
        var (login, name, role) = (option("--login"), option("--display-name"), option("--role"));
        if (string.IsNullOrWhiteSpace(login) || string.IsNullOrWhiteSpace(name) || string.IsNullOrWhiteSpace(role))
            return (null, "--login, --display-name and --role are required.");
        if (flag("--approver") && branch is null)
            return (null, "--approver needs --branch-id.");
        return (new StaffRequest(staff, login, name, role.ToUpperInvariant(), branch, flag("--approver"), flag("--set-password")), null);
    }

    /// <summary>96 random bits as 16 base64url characters: inside the 10-200 limit of sign-in.</summary>
    internal static string NewPassword() =>
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(12)).Replace('+', '-').Replace('/', '_');

    internal static string Hash(string password)
    {
        var salt = RandomNumberGenerator.GetBytes(16);
        var key = Rfc2898DeriveBytes.Pbkdf2(password, salt, Iterations, HashAlgorithmName.SHA256, 32);
        return $"pbkdf2-sha256${Iterations}${Convert.ToBase64String(salt)}${Convert.ToBase64String(key)}";
    }

    /// <summary>The password to set: the protected input when given, otherwise a new one. Null when none is set.</summary>
    internal (string? Password, bool Generated) ChoosePassword(string? given)
    {
        if (!SetPassword)
            return (null, false);
        if (string.IsNullOrEmpty(given))
            return (NewPassword(), true);
        if (given.Length is < 10 or > 200)
            throw new InvalidOperationException($"{PasswordVariable} must be 10 to 200 characters.");
        return (given, false);
    }

    internal Task RunAsync(DbConnection connection, string? password) =>
        NodeRequest.Exec(connection, "security.usp_ProvisionStaff", ("@StaffId", StaffId), ("@LoginName", Login),
            ("@DisplayName", DisplayName), ("@RoleCode", Role), ("@BranchId", (object?)BranchId ?? DBNull.Value),
            ("@CanApprove", Approver), ("@PasswordHash", password is null ? DBNull.Value : Hash(password)));
}
