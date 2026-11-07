using Xunit;

namespace Martha.Store.Api.Tests;

// Shared only by acceptance tests: SQL remains independently enumerated and hashed by the fixture.
internal static class InternalAcceptanceFingerprint
{
    private static readonly string[] ExpectedTables =
    [
        "BranchAssignmentAudit", "Branches", "CashCloses", "CashEntries", "CashTills", "Items", "Locations", "Operations", "Parties",
        "PurchaseOrderLines", "PurchaseOrders", "PurchaseReceiptLines", "PurchaseReceipts",
        "SaleLines", "SaleReversalLines", "SaleReversals", "Sales", "Sessions", "Staff",
        "StockAdjustments", "StockBalances", "StockExceptionReviews", "StockMovements"
    ];
    private static readonly string[] ExcludedTables = ["Staff", "Sessions", "BranchAssignmentAudit"];

    // Explicit oracle: never derive the allowed names from the model under test.
    // Comparing sequences also rejects duplicates and same-count substitutions.
    internal static void AssertTables(IEnumerable<string> tables) =>
        Assert.Equal(ExpectedTables, tables.Order(StringComparer.Ordinal).ToArray());

    internal static SortedDictionary<string, string> Business(SortedDictionary<string, string> fingerprint)
    {
        AssertTables(fingerprint.Keys);
        var result = new SortedDictionary<string, string>(fingerprint, StringComparer.Ordinal);
        foreach (var table in ExcludedTables) Assert.True(result.Remove(table));
        Assert.Equal(ExpectedTables.Except(ExcludedTables, StringComparer.Ordinal).ToArray(), result.Keys.ToArray());
        return result;
    }
}
