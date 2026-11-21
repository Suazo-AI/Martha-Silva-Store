namespace Martha.Store.Api.Tests;

// ADO.NET-only successful-write oracle. Exclude identified inserts, never whole tables.
// Only the sold balance's timestamp and the expected OnHand decrement may differ.
internal sealed class InternalAcceptanceWriteProjection
{
    private readonly Dictionary<string, Guid> inserted;
    private readonly Guid item, location;
    private readonly bool restoreOnHand;

    private InternalAcceptanceWriteProjection(Dictionary<string, Guid> inserted, Guid item = default,
        Guid location = default, bool restoreOnHand = false)
    {
        if (inserted.Values.Any(id => id == Guid.Empty)) throw new ArgumentException("Insert identities must be nonempty.");
        this.inserted = inserted; this.item = item; this.location = location; this.restoreOnHand = restoreOnHand;
    }

    internal static InternalAcceptanceWriteProjection BeforeSale(Guid item, Guid location) =>
        new([], item, location);

    internal static InternalAcceptanceWriteProjection AfterSale(Guid item, Guid location, Guid sale,
        Guid line, Guid movement, Guid operation) => new(new()
        {
            ["Sales"] = sale, ["SaleLines"] = line, ["StockMovements"] = movement, ["Operations"] = operation
        }, item, location, restoreOnHand: true);

    internal static InternalAcceptanceWriteProjection AfterItem(Guid item, Guid operation) =>
        new(new() { ["Items"] = item, ["Operations"] = operation });

    internal IReadOnlyDictionary<string, object>? Apply(string table, IReadOnlyDictionary<string, object> row)
    {
        if (inserted.TryGetValue(table, out var id) && (Guid)row["Id"] == id) return null;
        if (table != "StockBalances" || item == Guid.Empty || (Guid)row["ItemId"] != item || (Guid)row["LocationId"] != location)
            return row;
        var result = new Dictionary<string, object>(row, StringComparer.Ordinal) { ["UpdatedAt"] = "<expected stock timestamp>" };
        if (restoreOnHand) result["OnHand"] = checked((int)row["OnHand"] + 1);
        return result;
    }
}
