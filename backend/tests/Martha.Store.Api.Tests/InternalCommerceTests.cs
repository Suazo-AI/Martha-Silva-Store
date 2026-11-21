using System.Text.Json;
using Martha.Store.Api.Internal;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace Martha.Store.Api.Tests;

public sealed class InternalCommerceTests
{
    private static readonly Guid Item = Guid.Parse("11111111-1111-1111-1111-111111111111");
    private static readonly Guid Location = Guid.Parse("22222222-2222-2222-2222-222222222222");
    private static readonly Guid Actor = Guid.Parse("33333333-3333-3333-3333-333333333333");
    private const string Key = "commerce-unit-key-0001";

    [Theory]
    [InlineData(0, 0, false)]
    [InlineData(1, 0, true)]
    [InlineData(-1, 0, true)]
    [InlineData(0, 1, true)]
    [InlineData(0, -1, true)]
    [InlineData(1000000000, -1000000000, true)]
    [InlineData(-1000000000, 1000000000, true)]
    [InlineData(int.MaxValue, 0, false)]
    [InlineData(int.MinValue, 0, false)]
    [InlineData(0, int.MaxValue, false)]
    [InlineData(0, int.MinValue, false)]
    public void Ledger_delta_bounds_are_checked_without_SQL(int onHand, int reserved, bool valid) =>
        Assert.Equal(valid, InternalStockLedger.ValidChange(Item, Location, onHand, reserved, Actor, Actor, "purchase_receipt"));

    [Theory]
    [InlineData("")]
    [InlineData("sale!")]
    [InlineData("Sale")]
    [InlineData("sale change")]
    [InlineData("sále")]
    public void Ledger_rejects_uncontrolled_audit_kinds(string kind) =>
        Assert.False(InternalStockLedger.ValidChange(Item, Location, 1, 0, Actor, Actor, kind));

    [Fact]
    public void Ledger_requires_nonempty_server_actor_and_correlation()
    {
        Assert.False(InternalStockLedger.ValidChange(Item, Location, 1, 0, Guid.Empty, Actor, "sale"));
        Assert.False(InternalStockLedger.ValidChange(Item, Location, 1, 0, Actor, Guid.Empty, "sale"));
        Assert.False(InternalStockLedger.ValidChange(Guid.Empty, Location, 1, 0, Actor, Actor, "sale"));
        Assert.False(InternalStockLedger.ValidChange(Item, Guid.Empty, 1, 0, Actor, Actor, "sale"));
    }

    [Theory]
    [InlineData(0, false)]
    [InlineData(-1, false)]
    [InlineData(1, true)]
    [InlineData(1000000, true)]
    [InlineData(1000001, false)]
    [InlineData(int.MaxValue, false)]
    public void Sale_quantities_are_bounded_and_customer_is_optional(int quantity, bool valid) =>
        Assert.Equal(valid, InternalCommerceRules.ValidSale(new(Location, null, [new(Item, quantity)])));

    [Fact]
    public void Sale_rejects_empty_or_duplicate_lines_and_invalid_ids()
    {
        Assert.False(InternalCommerceRules.ValidSale(new(Location, null, null)));
        Assert.False(InternalCommerceRules.ValidSale(new(Location, null, [])));
        Assert.False(InternalCommerceRules.ValidSale(new(Location, Guid.Empty, [new(Item, 1)])));
        Assert.False(InternalCommerceRules.ValidSale(new(Guid.Empty, null, [new(Item, 1)])));
        Assert.False(InternalCommerceRules.ValidSale(new(Location, null, [new(Item, 1), new(Item, 1)])));
        Assert.False(InternalCommerceRules.ValidSale(new(Location, null, [null!])));
        Assert.False(InternalCommerceRules.ValidSale(new(Location, null, Enumerable.Range(0, 101).Select(_ => new InternalSaleLineRequest(Guid.NewGuid(), 1)).ToArray())));
    }

    [Fact]
    public void Return_requires_unique_line_ids_reason_and_positive_bounded_quantities()
    {
        Assert.True(InternalCommerceRules.ValidReturn(new("damaged package", [new(Item, 1)])));
        Assert.False(InternalCommerceRules.ValidReturn(new(" ", [new(Item, 1)])));
        Assert.False(InternalCommerceRules.ValidReturn(new("reason", [new(Item, 0)])));
        Assert.False(InternalCommerceRules.ValidReturn(new("reason", [new(Item, 1), new(Item, 1)])));
        Assert.False(InternalCommerceRules.ValidReturn(new("reason", [new(Guid.Empty, 1)])));
        Assert.False(InternalCommerceRules.ValidReturn(new("reason", [null!])));
    }

    [Fact]
    public void Audit_reason_has_a_raw_input_bound_and_no_control_characters()
    {
        Assert.True(InternalCommerceRules.ValidReason("  stock count correction  "));
        Assert.False(InternalCommerceRules.ValidReason(new string(' ', 501) + "reason"));
        Assert.False(InternalCommerceRules.ValidReason("reason\nforged audit line"));
        Assert.False(InternalCommerceRules.ValidReason(null));
    }

    [Theory]
    [InlineData(0L, 1000000, true, 0L)]
    [InlineData(9000000000000L, 1, true, 9000000000000L)]
    [InlineData(9000000000000L, 2, false, 0L)]
    [InlineData(9000000L, 1000000, true, 9000000000000L)]
    [InlineData(long.MaxValue, 2, false, 0L)]
    [InlineData(-1L, 1, false, 0L)]
    [InlineData(1L, int.MaxValue, false, 0L)]
    public void Integer_money_bounds_prevent_overflow_before_multiplication(long price, int quantity, bool valid, long expected)
    {
        Assert.Equal(valid, InternalCommerceRules.TryTotal([(price, quantity)], out var total));
        if (valid) Assert.Equal(expected, total);
    }

    [Fact]
    public void Multi_line_total_cannot_exceed_minor_unit_bound()
    {
        Assert.False(InternalCommerceRules.TryTotal([(InternalRules.MaxMinor, 1), (1, 1)], out _));
        Assert.True(InternalCommerceRules.TryTotal([(101, 2), (250, 3)], out var total));
        Assert.Equal(952, total);
    }

    [Theory]
    [InlineData("unitPriceMinor")]
    [InlineData("totalMinor")]
    [InlineData("currency")]
    [InlineData("actorId")]
    [InlineData("onHand")]
    public void Sale_does_not_accept_client_authoritative_fields(string property)
    {
        var json = $$"""{"locationId":"{{Location}}","lines":[{"itemId":"{{Item}}","quantity":1}],"{{property}}":0}""";
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<InternalSaleRequest>(json, new JsonSerializerOptions(JsonSerializerDefaults.Web)));
    }

    [Fact]
    public void Nested_sale_line_rejects_client_price()
    {
        var json = $$"""{"locationId":"{{Location}}","lines":[{"itemId":"{{Item}}","quantity":1,"unitPriceMinor":1}]}""";
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<InternalSaleRequest>(json, new JsonSerializerOptions(JsonSerializerDefaults.Web)));
    }

    [Fact]
    public async Task Malformed_commands_fail_before_runner_or_SQL()
    {
        await using var db = Context();
        var service = new InternalCommerceService(db, new NeverRunner(), new NeverLedger());
        Assert.Equal("invalid_request", (await service.RecordSale(new(Location, null, []), Actor, Key, default)).Error);
        Assert.Equal("invalid_request", (await service.RecordSale(new(Location, null, [new(Item, 1)]), Guid.Empty, Key, default)).Error);
        Assert.Equal("invalid_request", (await service.RecordSale(new(Location, null, [new(Item, 1)]), Actor, "short", default)).Error);
        Assert.Equal("invalid_request", (await service.Adjust(new(Item, Location, 0, "count"), Actor, Key, default)).Error);
        Assert.Equal("invalid_request", (await service.Adjust(new(Item, Location, 1, ""), Actor, Key, default)).Error);
        Assert.Equal("invalid_request", (await service.CancelSale(Item, new(null), Actor, Key, default)).Error);
        Assert.Equal("invalid_request", (await service.ReturnSale(Item, new("reason", []), Actor, Key, default)).Error);
    }

    [Fact]
    public async Task Ledger_refuses_to_create_an_independent_transaction()
    {
        await using var db = Context();
        var ledger = new InternalStockLedger(db);
        Assert.Equal("invalid_request", (await ledger.Change(Item, Location, 0, 0, Actor, Actor, "sale", default)).Error);
        var error = await Assert.ThrowsAsync<InvalidOperationException>(() => ledger.Change(Item, Location, 1, 0, Actor, Actor, "sale", default));
        Assert.Contains("same scoped context", error.Message);
        Assert.Null(db.Database.CurrentTransaction);
    }

    [Theory]
    [InlineData(0, 100, true)]
    [InlineData(1000, 100, true)]
    [InlineData(-1, 100, false)]
    [InlineData(0, 0, false)]
    [InlineData(0, 101, false)]
    public void Lists_expose_bounded_explicit_pagination(int skip, int take, bool valid) =>
        Assert.Equal(valid, InternalCommerceService.ValidPage(skip, take, 100));

    [Fact]
    public void Commerce_services_are_scoped_for_one_transaction_context()
    {
        var services = new ServiceCollection();
        services.AddInternalCommerce();
        Assert.Equal(ServiceLifetime.Scoped, Assert.Single(services, x => x.ServiceType == typeof(IInternalStockLedger)).Lifetime);
        Assert.Equal(ServiceLifetime.Scoped, Assert.Single(services, x => x.ServiceType == typeof(InternalCommerceService)).Lifetime);
    }

    [Fact]
    public void Model_has_separate_schema_composite_stock_identity_constraints_and_reference_protection()
    {
        using var db = Context();
        var balance = db.Model.FindEntityType(typeof(InternalStockBalance))!;
        Assert.Equal("savia_internal", balance.GetSchema());
        Assert.Equal(new[] { nameof(InternalStockBalance.ItemId), nameof(InternalStockBalance.LocationId) }, balance.FindPrimaryKey()!.Properties.Select(x => x.Name));
        Assert.All(balance.GetForeignKeys(), x => Assert.Equal(DeleteBehavior.Restrict, x.DeleteBehavior));
        var script = db.Database.GenerateCreateScript(); // Generates DDL only; does not open SQL.
        Assert.Contains("CREATE TABLE [savia_internal].[StockBalances]", script);
        Assert.Contains("CK_InternalBalance_Bounds", script);
        Assert.Contains("CK_InternalSale_Currency", script);
        Assert.Contains("CK_InternalSaleLine_Amounts", script);
        Assert.Contains("CK_InternalReversalLine_Bounds", script);
        Assert.DoesNotContain("MarthaSynthetic", script);
    }

    [Theory]
    [InlineData("movement", false)]
    [InlineData("movement", true)]
    [InlineData("adjustment", false)]
    [InlineData("adjustment", true)]
    [InlineData("reversal", false)]
    [InlineData("reversal", true)]
    [InlineData("reversal_line", false)]
    [InlineData("reversal_line", true)]
    public async Task Audit_entries_refuse_rewrites_and_deletes_before_SQL(string kind, bool delete)
    {
        await using var db = Context();
        object entity = kind switch
        {
            "movement" => new InternalStockMovement { Id = Guid.NewGuid() },
            "adjustment" => new InternalStockAdjustment { Id = Guid.NewGuid() },
            "reversal" => new InternalSaleReversal { Id = Guid.NewGuid() },
            _ => new InternalSaleReversalLine { Id = Guid.NewGuid() }
        };
        db.Attach(entity);
        db.Entry(entity).State = delete ? EntityState.Deleted : EntityState.Modified;
        Assert.Throws<InvalidOperationException>(() => db.SaveChanges());
        await Assert.ThrowsAsync<InvalidOperationException>(() => db.SaveChangesAsync());
    }

    private static InternalDbContext Context() => new(new DbContextOptionsBuilder<InternalDbContext>()
        .UseSqlServer("Server=127.0.0.1,1;Database=MarthaInternal_Unit;Integrated Security=true;Connect Timeout=1").Options);
    private sealed class NeverRunner : IInternalCommandRunner
    {
        public Task<InternalResult<T>> RunScoped<T>(Guid actorId, string scope, string key, string fingerprint, InternalCommandResource resource, Func<CancellationToken, Task<InternalResult<T>>> action, CancellationToken ct) =>
            throw new InvalidOperationException("Invalid input must not reach scoped runner.");
        public Task<InternalResult<T>> Run<T>(Guid actorId, string scope, string key, string fingerprint, Func<CancellationToken, Task<InternalResult<T>>> action, CancellationToken ct) =>
            throw new InvalidOperationException("Malformed commands must not reach the runner.");
    }
    private sealed class NeverLedger : IInternalStockLedger
    {
        public Task<InternalResult<bool>> Change(Guid itemId, Guid locationId, int onHandDelta, int reservedDelta, Guid actorId, Guid operationId, string kind, CancellationToken ct) =>
            throw new InvalidOperationException("Malformed commands must not reach the ledger.");
    }
}
