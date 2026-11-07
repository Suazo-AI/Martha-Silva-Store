using System.Globalization;
using Xunit;

namespace Martha.Store.Api.Tests;

public sealed class InternalAcceptanceWriteProjectionTests
{
    private static readonly Guid Item = Guid.Parse("10000000-0000-0000-0000-000000000001");
    private static readonly Guid Location = Guid.Parse("20000000-0000-0000-0000-000000000001");
    private static readonly Guid Insert = Guid.Parse("30000000-0000-0000-0000-000000000001");
    private static readonly Guid Existing = Guid.Parse("40000000-0000-0000-0000-000000000001");
    private static readonly string[] Tables = ["Sales", "SaleLines", "StockMovements", "Operations", "Items", "StockBalances"];
    private sealed record Row(string Table, Dictionary<string, object> Cells);

    private static List<Row> Before() => Tables.Where(t => t != "StockBalances")
        .Select(t => new Row(t, new() { ["Id"] = Existing, ["Value"] = "unchanged" })).Append(new("StockBalances", new()
        {
            ["ItemId"] = Item, ["LocationId"] = Location, ["OnHand"] = 10, ["Reserved"] = 2, ["UpdatedAt"] = "before"
        })).Append(new("StockBalances", new()
        {
            ["ItemId"] = Existing, ["LocationId"] = Location, ["OnHand"] = 20, ["Reserved"] = 3, ["UpdatedAt"] = "before"
        })).ToList();

    private static List<Row> SaleAfter()
    {
        var rows = Before();
        foreach (var table in new[] { "Sales", "SaleLines", "StockMovements", "Operations" })
            rows.Add(new(table, new() { ["Id"] = Insert, ["Value"] = "new" }));
        var balance = rows.Single(r => r.Table == "StockBalances" && (Guid)r.Cells["ItemId"] == Item).Cells;
        balance["OnHand"] = 9; balance["UpdatedAt"] = "after";
        return rows;
    }

    // Synthetic rows exercise the exact projection used by the SQL reader. No database is contacted.
    private static string[] Project(IEnumerable<Row> rows, InternalAcceptanceWriteProjection? projection) => rows
        .Select(r => (r.Table, Cells: projection is null ? r.Cells : projection.Apply(r.Table, r.Cells)))
        .Where(r => r.Cells is not null).Select(r => r.Table + ":" + string.Join("|", r.Cells!
            .OrderBy(c => c.Key, StringComparer.Ordinal).Select(c => c.Key + "=" + Convert.ToString(c.Value, CultureInfo.InvariantCulture))))
        .Order(StringComparer.Ordinal).ToArray();

    private static void AssertSale(List<Row> after) => Assert.Equal(
        Project(Before(), InternalAcceptanceWriteProjection.BeforeSale(Item, Location)),
        Project(after, InternalAcceptanceWriteProjection.AfterSale(Item, Location, Insert, Insert, Insert, Insert)));

    [Fact]
    public void Exactly_four_inserts_and_one_stock_decrement_preserve_the_remainder() => AssertSale(SaleAfter());

    [Theory]
    [InlineData("Sales")]
    [InlineData("SaleLines")]
    [InlineData("StockMovements")]
    [InlineData("Operations")]
    [InlineData("Items")]
    [InlineData("StockBalances")]
    public void Unrelated_existing_row_change_is_detected_inside_each_previously_excluded_table(string table)
    {
        var rows = SaleAfter();
        var row = rows.First(r => r.Table == table && (table != "StockBalances" || (Guid)r.Cells["ItemId"] == Existing));
        row.Cells[table == "StockBalances" ? "OnHand" : "Value"] = table == "StockBalances" ? 19 : "corrupt";
        if (table != "Items")
        {
            // Reproduce P2: the old whole-table exclusions accept this unrelated mutation.
            static bool WasExcluded(Row r) => r.Table is "Sales" or "SaleLines" or "StockMovements" or "Operations" or "StockBalances";
            Assert.Equal(Project(Before().Where(r => !WasExcluded(r)), null), Project(rows.Where(r => !WasExcluded(r)), null));
        }
        Assert.ThrowsAny<Xunit.Sdk.XunitException>(() => AssertSale(rows));
    }

    [Theory]
    [InlineData("Reserved", 1)]
    [InlineData("OnHand", 8)]
    public void Wrong_target_balance_or_reservation_change_is_detected(string column, int value)
    {
        var rows = SaleAfter();
        rows.Single(r => r.Table == "StockBalances" && (Guid)r.Cells["ItemId"] == Item).Cells[column] = value;
        Assert.ThrowsAny<Xunit.Sdk.XunitException>(() => AssertSale(rows));
    }

    [Theory]
    [InlineData("Sales")]
    [InlineData("SaleLines")]
    [InlineData("StockMovements")]
    [InlineData("Operations")]
    [InlineData("Items")]
    [InlineData("StockBalances")]
    public void Deletion_of_an_existing_row_is_detected(string table)
    {
        var rows = SaleAfter(); rows.Remove(rows.First(r => r.Table == table));
        Assert.ThrowsAny<Xunit.Sdk.XunitException>(() => AssertSale(rows));
    }

    [Theory]
    [InlineData("Sales")]
    [InlineData("SaleLines")]
    [InlineData("StockMovements")]
    [InlineData("Operations")]
    [InlineData("Items")]
    public void An_additional_unidentified_insert_is_detected(string table)
    {
        var rows = SaleAfter(); rows.Add(new(table, new() { ["Id"] = Guid.NewGuid(), ["Value"] = "unexpected" }));
        Assert.ThrowsAny<Xunit.Sdk.XunitException>(() => AssertSale(rows));
    }

    [Theory]
    [InlineData("none")]
    [InlineData("Items")]
    [InlineData("Operations")]
    public void Directory_excludes_only_the_identified_new_rows(string corruption)
    {
        var before = Before(); var after = Before();
        foreach (var table in new[] { "Items", "Operations" }) after.Add(new(table, new() { ["Id"] = Insert, ["Value"] = "new" }));
        if (corruption != "none") after.First(r => r.Table == corruption).Cells["Value"] = "corrupt";
        var equal = Project(before, null).SequenceEqual(Project(after, InternalAcceptanceWriteProjection.AfterItem(Insert, Insert)));
        Assert.Equal(corruption == "none", equal);
    }

    [Fact]
    public void Empty_insert_identity_is_rejected() => Assert.Throws<ArgumentException>(() =>
        InternalAcceptanceWriteProjection.AfterItem(Guid.Empty, Insert));
}
