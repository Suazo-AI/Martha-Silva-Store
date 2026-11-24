using Savia.Domain;
using Savia.Infrastructure;

namespace Savia.Tests;

// D0: Savia.Migrator --provision-branch and --provision-staff argument rules and the password hash (no SQL needed).
public sealed class SiteProvisioningTests
{
    private static readonly string Id = Guid.NewGuid().ToString();

    private static Func<string, string?> Options(params string[] args) =>
        name => Array.IndexOf(args, name) is var i and >= 0 && i + 1 < args.Length ? args[i + 1] : null;

    private static (StaffRequest? Request, string? Error) Staff(params string[] args) =>
        StaffRequest.Parse(Options(args), args.Contains);

    [Fact]
    public void A_branch_needs_three_ids_and_every_code_and_name()
    {
        string[] full = ["--branch-id", Id, "--branch-code", "TIENDA1", "--branch-name", "Tienda 1", "--store-name", "SAVIA",
            "--location-id", Id, "--location-code", "TIENDA1_PISO", "--location-name", "Piso", "--register-id", Id,
            "--register-code", "CAJA1", "--register-name", "Caja 1"];
        Assert.NotNull(BranchRequest.Parse(Options(full)).Request);
        Assert.Equal("--register-name is required.", BranchRequest.Parse(Options(full[..^2])).Error);
        Assert.NotNull(BranchRequest.Parse(Options([.. full[..1], "not-a-guid", .. full[2..]])).Error);
    }

    [Fact]
    public void Staff_needs_an_id_a_login_a_name_and_a_role_and_an_approver_needs_a_branch()
    {
        var owner = Staff("--staff-id", Id, "--login", "duena", "--display-name", "Dueña", "--role", "owner", "--set-password").Request;
        Assert.Equal((Roles.Owner, (Guid?)null, true), (owner!.Role, owner.BranchId, owner.SetPassword));
        Assert.NotNull(Staff("--staff-id", Id, "--login", "duena", "--display-name", "Dueña").Error);
        Assert.NotNull(Staff("--staff-id", Id, "--login", "g", "--display-name", "G", "--role", "MANAGER", "--approver").Error);
        Assert.True(Staff("--staff-id", Id, "--login", "g", "--display-name", "G", "--role", "MANAGER", "--branch-id", Id,
            "--approver").Request!.Approver);
    }

    [Fact]
    public void A_generated_password_signs_in_with_the_api_hasher()
    {
        var request = Staff("--staff-id", Id, "--login", "c", "--display-name", "C", "--role", "CASHIER", "--set-password").Request!;
        var (password, generated) = request.ChoosePassword(null);
        Assert.True(generated);
        Assert.InRange(password!.Length, 10, 200);
        Assert.NotEqual(password, StaffRequest.NewPassword());
        var hasher = new Pbkdf2PasswordHasher();
        Assert.True(hasher.Verify(password, StaffRequest.Hash(password)));
        Assert.False(hasher.Verify(password + "x", StaffRequest.Hash(password)));
    }

    [Fact]
    public void A_given_password_is_used_as_is_and_no_password_is_set_without_the_flag()
    {
        var request = Staff("--staff-id", Id, "--login", "c", "--display-name", "C", "--role", "CASHIER", "--set-password").Request!;
        Assert.Equal(("una-clave-larga", false), request.ChoosePassword("una-clave-larga"));
        Assert.Throws<InvalidOperationException>(() => request.ChoosePassword("corta"));
        Assert.Equal((null, false), (request with { SetPassword = false }).ChoosePassword("una-clave-larga"));
    }

    [Theory]
    [InlineData(51866, "branch.provision_mismatch")]
    [InlineData(51867, "staff.provision_mismatch")]
    [InlineData(51903, "supplier.invalid")]
    public void Provisioning_and_supplier_errors_have_named_codes(int number, string code) =>
        Assert.Equal(code, DbErrors.FromSql(number, "x").Code);
}
