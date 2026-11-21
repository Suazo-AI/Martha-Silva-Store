namespace Savia.Domain;

/// <summary>
/// Role codes of security.Roles and the named sets the guards use. A guard names one set, never a list of roles.
/// CASHIER is kept in every set that had it: no staff member holds it today, and removing it is a product decision.
/// </summary>
public static class Roles
{
    public const string Owner = "OWNER";
    public const string Seller = "SELLER";
    public const string Manager = "MANAGER";
    public const string Cashier = "CASHIER";
    public const string Inventory = "INVENTORY";
    public const string Accountant = "ACCOUNTANT";

    /// <summary>Decisions of the owner alone: prices and costs, commission rates, the return window, catalog import.</summary>
    public static readonly string[] OwnerOnly = [Owner];

    /// <summary>Supervisors: approve a count, a discount or a return, close a till, read the business reports.</summary>
    public static readonly string[] Approvers = [Manager, Owner];

    /// <summary>Work at a till: open it, sell, count cash, look up sales, customers and credits. SELLER is not one of them.</summary>
    public static readonly string[] TillOperators = [Cashier, Manager, Owner];

    /// <summary>Check the quality of received merchandise.</summary>
    public static readonly string[] StockWorkers = [Inventory, Manager, Owner];

    /// <summary>Count merchandise in a reception and read hanging tags.</summary>
    public static readonly string[] Receivers = [Inventory, Cashier, Manager, Owner];

    /// <summary>Read commissions and the team figures; a seller sees only their own (the procedure decides).</summary>
    public static readonly string[] CommissionReaders = [Seller, Manager, Owner];

    /// <summary>List the sellers of the branch, to credit a sale line to one of them.</summary>
    public static readonly string[] SalesStaff = [Seller, Cashier, Manager, Owner];

    /// <summary>Read catalog and stock on the cloud node, where no branch access applies.</summary>
    public static readonly string[] CloudReaders = [Owner, Manager, Accountant];
}
