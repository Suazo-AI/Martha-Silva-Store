using Savia.Domain;

namespace Savia.Tests;

/// <summary>SQL errors reach the cashier as named codes; the message text is the only way to tell one unique index from another.</summary>
public sealed class DbErrorsTests
{
    [Fact]
    public void Second_open_till_on_a_register_has_its_own_code()
    {
        var error = DbErrors.FromSql(2601, "Cannot insert duplicate key row in object 'sales.CashTills' with unique index 'UX_OpenTill_Register'.");
        Assert.Equal(("cash.register_till_open", ErrorKind.Conflict), (error.Code, error.Kind));
    }

    [Fact]
    public void Other_duplicate_keys_stay_generic()
    {
        var error = DbErrors.FromSql(2601, "Cannot insert duplicate key row in object 'sales.Sales' with unique index 'UX_Sales_Number'.");
        Assert.Equal("db.duplicate", error.Code);
    }

    [Fact]
    public void Check_constraint_is_a_validation_error_and_foreign_key_stays_a_reference()
    {
        var check = DbErrors.FromSql(547, "The INSERT statement conflicted with the CHECK constraint \"CK_Items_Cost\".");
        var reference = DbErrors.FromSql(547, "The INSERT statement conflicted with the FOREIGN KEY constraint \"FK_Items_Product\".");
        Assert.Equal(("db.check", ErrorKind.Validation), (check.Code, check.Kind));
        Assert.Equal(("db.reference", ErrorKind.Conflict), (reference.Code, reference.Kind));
    }

    [Fact]
    public void Recovery_lock_has_a_named_code()
    {
        var error = DbErrors.FromSql(51864, "Sucursal restaurada: espere la reconstrucción.");
        Assert.Equal(("sync.recovery_pending", ErrorKind.Conflict), (error.Code, error.Kind));
    }
}
