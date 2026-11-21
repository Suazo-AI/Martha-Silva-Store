using System.Security.Claims;
using System.Text.Json;
using Martha.Store.Api.Internal;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using Xunit;

namespace Martha.Store.Api.Tests;

public sealed class InternalCashTests
{
    [Theory]
    [InlineData(2500, 3000, true, 500)]
    [InlineData(2500, 2500, true, 0)]
    [InlineData(2500, 2499, false, 0)]
    [InlineData(0, 0, true, 0)]
    [InlineData(-1, 1, false, 0)]
    [InlineData(1, -1, false, 0)]
    [InlineData(9000000000000, 9000000000000, true, 0)]
    [InlineData(1, 9000000000001, false, 0)]
    [InlineData(1, long.MaxValue, false, 0)]
    public void Tender_boundaries(long total, long received, bool valid, long expected)
    {
        Assert.Equal(valid, InternalCashRules.TryChange(total, received, out var change));
        Assert.Equal(expected, change);
    }
    [Fact]
    public void Opening_is_summed_once_and_refund_and_variance_remain_signed()
    {
        Assert.True(InternalCashRules.TryBalance([10000, 2500], out var first)); Assert.Equal(12500, first);
        Assert.Equal(-100, 12400 - first);
        Assert.True(InternalCashRules.TryBalance([10000, 2500, -1000], out var refund)); Assert.Equal(11500, refund);
        Assert.True(InternalCashRules.TryBalance([20000, -1000], out var later)); Assert.Equal(19000, later);
        Assert.False(InternalCashRules.TryBalance([1, -2], out _));
        Assert.False(InternalCashRules.TryBalance([InternalRules.MaxMinor, 1], out _));
        Assert.False(InternalCashRules.TryBalance([long.MaxValue, 1], out _));
    }
    [Theory]
    [InlineData("Owner", true)] [InlineData("Manager", true)]
    [InlineData("Cashier", false)] [InlineData("Inventory", false)]
    public void Refund_role_is_explicit(string role, bool allowed)
    {
        var actor = new ClaimsPrincipal(new ClaimsIdentity([new(ClaimTypes.Role, role)], "test"));
        Assert.Equal(allowed, InternalCommandAuthorization.Allowed(actor, "cash.refund"));
        Assert.Equal(role != "Inventory", InternalCommandAuthorization.Allowed(actor, "cash.sale"));
        Assert.Equal(role != "Inventory", InternalCommandAuthorization.Allowed(actor, "cash.till.open"));
        Assert.Equal(role != "Inventory", InternalCommandAuthorization.Allowed(actor, "cash.till.close"));
    }
    [Theory]
    [InlineData("{\"countedMinor\":0,\"expectedMinor\":0}")]
    [InlineData("{\"countedMinor\":0,\"actorId\":\"00000000-0000-0000-0000-000000000001\"}")]
    [InlineData("{\"countedMinor\":1.5}")]
    [InlineData("{\"countedMinor\":\"100\"}")]
    [InlineData("{\"countedMinor\":null}")]
    public void Close_rejects_unknown_and_noninteger_money(string json) =>
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<InternalCashCloseRequest>(json, new JsonSerializerOptions(JsonSerializerDefaults.Web)));

    [Fact]
    public void Model_has_exact_three_cash_tables_restrictive_links_and_unique_open_constraint()
    {
        using var db = Database();
        var cash = db.Model.GetEntityTypes().Where(x => x.GetTableName()!.StartsWith("Cash", StringComparison.Ordinal)).ToArray();
        Assert.Equal(new[] { "CashCloses", "CashEntries", "CashTills" }, cash.Select(x => x.GetTableName()).Order().ToArray());
        Assert.All(cash.SelectMany(x => x.GetForeignKeys()), x => Assert.Equal(DeleteBehavior.Restrict, x.DeleteBehavior));
        Assert.Contains(db.Model.FindEntityType(typeof(InternalCashTill))!.GetIndexes(), x => x.IsUnique && x.GetFilter() == "[ClosedAt] IS NULL");
        Assert.Contains(db.Model.FindEntityType(typeof(InternalCashEntry))!.GetIndexes(), x => x.IsUnique && x.GetFilter() == "[Kind]='sale'");
        Assert.Equal(System.Data.ConnectionState.Closed, db.Database.GetDbConnection().State);
    }
    [Fact]
    public void Entries_closes_and_till_provenance_are_guarded_before_SQL()
    {
        using var db = Database();
        var entry = new InternalCashEntry { Id = Guid.NewGuid() }; db.Attach(entry); entry.DeltaMinor = 1;
        Assert.Throws<InvalidOperationException>(() => db.SaveChanges()); db.ChangeTracker.Clear();
        var close = new InternalCashClose { Id = Guid.NewGuid() }; db.Attach(close); db.Remove(close);
        Assert.Throws<InvalidOperationException>(() => db.SaveChanges()); db.ChangeTracker.Clear();
        var till = new InternalCashTill { Id = Guid.NewGuid(), Currency = "USD", Exponent = 2 }; db.Attach(till); till.Currency = "EUR";
        Assert.Throws<InvalidOperationException>(() => db.SaveChanges()); db.ChangeTracker.Clear();
        till = new InternalCashTill { Id = Guid.NewGuid(), ClosedAt = DateTimeOffset.UtcNow }; db.Attach(till); till.ClosedAt = null;
        Assert.Throws<InvalidOperationException>(() => db.SaveChanges());
    }
    [Fact]
    public void Currency_configuration_has_no_inferred_default()
    {
        Assert.False(new InternalCashOptions("", -1).Valid);
        Assert.False(new InternalCashOptions("USD", -1).Valid);
        Assert.False(new InternalCashOptions("USD", 7).Valid);
        Assert.True(new InternalCashOptions("USD", 0).Valid);
        Assert.True(new InternalCashOptions("USD", 2).Valid);
    }
    private static InternalDbContext Database() => new(new DbContextOptionsBuilder<InternalDbContext>()
        .UseSqlServer("Server=offline.invalid;Database=CashMetadataOnly;Integrated Security=true").Options);
}
