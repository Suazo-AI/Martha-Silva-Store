using Martha.Store.Api.Internal;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Martha.Store.Api.Tests;

public sealed class InternalAcceptanceFingerprintTests
{
    // Building SQL Server relational metadata does not open a connection or run the API.
    private static string[] ModelTables()
    {
        using var db = new InternalDbContext(new DbContextOptionsBuilder<InternalDbContext>()
            .UseSqlServer("Server=offline.invalid;Database=FingerprintMetadataOnly;Integrated Security=true").Options);
        return db.Model.GetRelationalModel().Tables.Where(t => t.Schema == "savia_internal")
            .Select(t => t.Name).Order(StringComparer.Ordinal).ToArray();
    }

    // Synthetic values exercise dictionary comparison; these are not database fingerprints.
    private static SortedDictionary<string, string> Fingerprint() => new(
        ModelTables().ToDictionary(t => t, _ => "0:synthetic-unchanged"), StringComparer.Ordinal);

    [Fact]
    public void Actual_fixture_guard_accepts_current_relational_model()
    {
        var tables = ModelTables();
        Assert.Equal(23, tables.Length);
        Assert.Contains("StockExceptionReviews", tables);
        InternalAcceptanceFingerprint.AssertTables(tables);
    }

    [Fact]
    public void Actual_business_subset_keeps_all_twenty_tables_and_review_hash()
    {
        var full = Fingerprint();
        var business = InternalAcceptanceFingerprint.Business(full);
        Assert.Equal(20, business.Count);
        Assert.Equal(new[] { "Branches", "CashCloses", "CashEntries", "CashTills", "Items", "Locations", "Operations", "Parties",
            "PurchaseOrderLines", "PurchaseOrders", "PurchaseReceiptLines", "PurchaseReceipts",
            "SaleLines", "SaleReversalLines", "SaleReversals", "Sales", "StockAdjustments",
            "StockBalances", "StockExceptionReviews", "StockMovements" }, business.Keys.ToArray());
        Assert.Equal(full["StockExceptionReviews"], business["StockExceptionReviews"]);
        Assert.Equal(23, full.Count); // Projection must not modify the captured full fingerprint.
    }

    [Theory]
    [InlineData("missing")]
    [InlineData("unexpected")]
    [InlineData("substituted")]
    public void Both_guards_reject_schema_drift_even_with_same_count(string drift)
    {
        var fingerprint = Fingerprint();
        if (drift != "unexpected") fingerprint.Remove("StockExceptionReviews");
        if (drift != "missing") fingerprint.Add("UnexpectedTable", "0:synthetic");
        Assert.ThrowsAny<Xunit.Sdk.XunitException>(() => InternalAcceptanceFingerprint.AssertTables(fingerprint.Keys));
        Assert.ThrowsAny<Xunit.Sdk.XunitException>(() => InternalAcceptanceFingerprint.Business(fingerprint));
    }

    [Fact]
    public void Review_table_change_fails_the_same_business_dictionary_comparison()
    {
        var before = Fingerprint();
        var after = Fingerprint();
        Assert.Equal(InternalAcceptanceFingerprint.Business(before), InternalAcceptanceFingerprint.Business(after));
        after["StockExceptionReviews"] = "1:synthetic-changed-review-row";
        Assert.ThrowsAny<Xunit.Sdk.XunitException>(() =>
            Assert.Equal(InternalAcceptanceFingerprint.Business(before), InternalAcceptanceFingerprint.Business(after)));
    }

    [Theory]
    [InlineData("CashTills")]
    [InlineData("CashEntries")]
    [InlineData("CashCloses")]
    public void Cash_table_change_fails_business_and_full_dictionary_comparison(string table)
    {
        var before = Fingerprint(); var after = Fingerprint();
        after[table] = "1:synthetic-unauthorized-cash-write";
        Assert.ThrowsAny<Xunit.Sdk.XunitException>(() => Assert.Equal(before, after));
        Assert.ThrowsAny<Xunit.Sdk.XunitException>(() =>
            Assert.Equal(InternalAcceptanceFingerprint.Business(before), InternalAcceptanceFingerprint.Business(after)));
    }

    [Theory]
    [InlineData("Staff")]
    [InlineData("Sessions")]
    [InlineData("BranchAssignmentAudit")]
    public void Only_intended_authentication_assignment_changes_are_excluded(string table)
    {
        var before = Fingerprint();
        var after = Fingerprint();
        after[table] = "1:synthetic-intended-change";
        Assert.Equal(InternalAcceptanceFingerprint.Business(before), InternalAcceptanceFingerprint.Business(after));
    }
}
