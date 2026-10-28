using System.Text.Json;
using Martha.Store.Api.Internal;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Xunit;

namespace Martha.Store.Api.Tests;

// Synthetic fixtures only. These tests do not connect to SQL and are NOT proof
// of SQL locking, persistence, idempotency, role enforcement or atomic rollback.
public sealed class InternalSupplyRulesTests
{
    private static readonly Guid Supplier = Guid.Parse("a1111111-1111-1111-1111-111111111111");
    private static readonly Guid Location = Guid.Parse("a2222222-2222-2222-2222-222222222222");
    private static readonly Guid Item = Guid.Parse("a3333333-3333-3333-3333-333333333333");
    private static readonly Guid OtherItem = Guid.Parse("a4444444-4444-4444-4444-444444444444");
    private static InternalPurchaseOrderRequest Order(int quantity = 5, long unitCost = 250, string currency = "HNL") =>
        new(Supplier, Location, currency, [new(Item, quantity, unitCost)], "SYNTHETIC-ONLY");

    [Fact]
    public void Explicit_real_currency_and_zero_or_positive_minor_unit_cost_are_valid()
    {
        Assert.Null(InternalSupplyRules.Validate(Order()));
        Assert.Null(InternalSupplyRules.Validate(Order(unitCost: 0)));
        Assert.Null(InternalSupplyRules.Validate(Order(quantity: 1, unitCost: InternalRules.MaxMinor)));
    }

    [Theory]
    [InlineData("XXX")]
    [InlineData("hnl")]
    [InlineData("")]
    [InlineData("USD ")]
    [InlineData("€UR")]
    public void Currency_is_explicit_without_fixture_currency_or_normalizing_conversion(string currency) =>
        Assert.Equal("invalid_purchase_order", InternalSupplyRules.Validate(Order(currency: currency)));

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    [InlineData(1000001)]
    [InlineData(int.MaxValue)]
    public void Invalid_order_quantities_are_rejected(int quantity) =>
        Assert.Equal("invalid_purchase_line", InternalSupplyRules.Validate(Order(quantity)));

    [Theory]
    [InlineData(-1L)]
    [InlineData(long.MaxValue)]
    public void Negative_and_overflow_costs_are_rejected_without_throwing(long cost) =>
        Assert.Equal("invalid_purchase_line", InternalSupplyRules.Validate(Order(unitCost: cost)));

    [Fact]
    public void Whole_order_total_is_bounded_not_only_individual_lines()
    {
        var request = Order() with { Lines = [new(Item, 1, InternalRules.MaxMinor), new(OtherItem, 1, 1)] };
        Assert.Equal("purchase_total_too_large", InternalSupplyRules.Validate(request));
    }

    [Fact]
    public void Empty_duplicate_null_and_oversized_order_lines_are_rejected()
    {
        Assert.NotNull(InternalSupplyRules.Validate(Order() with { Lines = null }));
        Assert.NotNull(InternalSupplyRules.Validate(Order() with { Lines = [] }));
        Assert.NotNull(InternalSupplyRules.Validate(Order() with { Lines = [null!] }));
        Assert.Equal("invalid_purchase_line", InternalSupplyRules.Validate(Order() with { Lines = [new(Item, 1, 1), new(Item, 2, 2)] }));
        Assert.NotNull(InternalSupplyRules.Validate(Order() with { Lines = Enumerable.Range(0, 101).Select(_ => new InternalPurchaseLineRequest(Guid.NewGuid(), 1, 1)).ToArray() }));
    }

    [Fact]
    public void Empty_supplier_location_and_control_character_reference_are_rejected()
    {
        Assert.NotNull(InternalSupplyRules.Validate(Order() with { SupplierId = Guid.Empty }));
        Assert.NotNull(InternalSupplyRules.Validate(Order() with { LocationId = Guid.Empty }));
        Assert.NotNull(InternalSupplyRules.Validate(Order() with { Reference = "bad\nreference" }));
        Assert.NotNull(InternalSupplyRules.Validate(Order() with { Reference = new string('r', 101) }));
    }

    [Theory]
    [InlineData(10, 0, 10, true)]
    [InlineData(10, 4, 6, true)]
    [InlineData(10, 4, 7, false)]
    [InlineData(10, 10, 1, false)]
    [InlineData(10, 11, 1, false)]
    [InlineData(10, -1, 1, false)]
    [InlineData(10, 1, 0, false)]
    [InlineData(10, 1, -1, false)]
    [InlineData(int.MaxValue, 1, int.MaxValue, false)]
    public void Cumulative_receipts_never_exceed_remaining(int ordered, int received, int quantity, bool expected) =>
        Assert.Equal(expected, InternalSupplyRules.CanReceive(ordered, received, quantity));

    [Fact]
    public void Receipts_require_stable_identity_and_distinct_positive_lines()
    {
        Assert.Null(InternalSupplyRules.Validate(new InternalPurchaseReceiptRequest(Supplier, [new(Item, 1)])));
        Assert.NotNull(InternalSupplyRules.Validate(new InternalPurchaseReceiptRequest(Guid.Empty, [new(Item, 1)])));
        Assert.NotNull(InternalSupplyRules.Validate(new InternalPurchaseReceiptRequest(Supplier, [new(Item, 1), new(Item, 2)])));
        Assert.NotNull(InternalSupplyRules.Validate(new InternalPurchaseReceiptRequest(Supplier, [new(Item, -1)])));
        Assert.NotNull(InternalSupplyRules.Validate(new InternalPurchaseReceiptRequest(Supplier, [new(Item, 0)])));
        Assert.NotNull(InternalSupplyRules.Validate(new InternalPurchaseReceiptRequest(Supplier, [new(Guid.Empty, 1)])));
        Assert.NotNull(InternalSupplyRules.Validate(new InternalPurchaseReceiptRequest(Supplier, [null!])));
        Assert.NotNull(InternalSupplyRules.Validate(new InternalPurchaseReceiptRequest(Supplier, null)));
    }

    [Fact]
    public void Receipt_fingerprint_includes_order_identity_receipt_identity_and_quantity_but_not_list_order()
    {
        var request = new InternalPurchaseReceiptRequest(Supplier, [new(Item, 2), new(OtherItem, 3)]);
        var fingerprint = InternalSupplyRules.ReceiptFingerprint(Location, request);
        Assert.Equal(fingerprint, InternalSupplyRules.ReceiptFingerprint(Location, request with { Lines = [new(OtherItem, 3), new(Item, 2)] }));
        Assert.NotEqual(fingerprint, InternalSupplyRules.ReceiptFingerprint(OtherItem, request));
        Assert.NotEqual(fingerprint, InternalSupplyRules.ReceiptFingerprint(Location, request with { ReceiptId = Item }));
        Assert.NotEqual(fingerprint, InternalSupplyRules.ReceiptFingerprint(Location, request with { Lines = [new(Item, 1), new(OtherItem, 3)] }));
    }

    [Fact]
    public void Order_fingerprint_is_canonical_and_captures_supplier_currency_price_and_location()
    {
        var request = Order() with { Lines = [new(Item, 1, 100), new(OtherItem, 2, 200)] };
        var fingerprint = InternalSupplyRules.OrderFingerprint(request);
        Assert.Equal(fingerprint, InternalSupplyRules.OrderFingerprint(request with { Lines = request.Lines!.Reverse().ToArray() }));
        Assert.NotEqual(fingerprint, InternalSupplyRules.OrderFingerprint(request with { SupplierId = OtherItem }));
        Assert.NotEqual(fingerprint, InternalSupplyRules.OrderFingerprint(request with { LocationId = OtherItem }));
        Assert.NotEqual(fingerprint, InternalSupplyRules.OrderFingerprint(request with { Currency = "USD" }));
        Assert.NotEqual(fingerprint, InternalSupplyRules.OrderFingerprint(request with { Lines = [new(Item, 1, 101), new(OtherItem, 2, 200)] }));
    }

    [Fact]
    public void Partial_cancellation_reports_received_and_cancelled_without_inventing_stock_reversal()
    {
        var order = new InternalPurchaseOrder { Id = Supplier, Status = InternalPurchaseStatus.Cancelled,
            Lines = [new() { Id = Item, ItemId = Item, Quantity = 10, ReceivedQuantity = 4, UnitCostMinor = 250 }] };
        var line = Assert.Single(InternalPurchaseOrderView.From(order).Lines);
        Assert.Equal(4, line.ReceivedQuantity);
        Assert.Equal(6, line.CancelledQuantity);
        Assert.Equal(0, line.RemainingReceivableQuantity);
        Assert.Equal(2500, line.TotalMinor);
        Assert.False(InternalPurchaseStatus.Receivable(order.Status));
        Assert.False(InternalPurchaseStatus.Receivable(InternalPurchaseStatus.Received));
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("bad\nreason")]
    public void Cancellation_requires_auditable_reason(string reason) =>
        Assert.Equal("invalid_cancellation_reason", InternalSupplyRules.Validate(new InternalPurchaseCancelRequest(reason)));

    [Fact]
    public void Server_owned_receipt_price_actor_and_state_are_not_accepted_in_requests()
    {
        foreach (var field in new[] { "UnitCostMinor", "ReceivedBy", "Status", "OnHand", "TotalMinor" })
            Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<InternalPurchaseReceiptRequest>(
                $$"""{"ReceiptId":"{{Supplier}}","Lines":[],"{{field}}":1}"""));
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<InternalReceiptLineRequest>(
            $$"""{"PurchaseOrderLineId":"{{Item}}","Quantity":1,"UnitCostMinor":5}"""));
    }

    [Fact]
    public void Purchase_cost_must_be_explicit_not_defaulted_to_zero_when_omitted()
    {
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<InternalPurchaseLineRequest>(
            $$"""{"ItemId":"{{Item}}","Quantity":1}"""));
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<InternalPurchaseOrderRequest>(
            $$"""{"SupplierId":"{{Supplier}}","LocationId":"{{Location}}","Lines":[]}"""));
    }

    [Fact]
    public async Task Invalid_command_is_rejected_before_any_sql_or_command_runner_call()
    {
        await using var db = Context();
        var service = new InternalSupplyService(db, new NeverRunCommands(), new NeverChangeStock());
        Assert.Equal("invalid_purchase_line", (await service.Create(Item, "synthetic-order-key-001", Order(0), default)).Error);
        Assert.Equal("invalid_request", (await service.Create(Item, "short", Order(), default)).Error);
        Assert.Equal("unauthenticated", (await service.Create(Guid.Empty, "synthetic-order-key-001", Order(), default)).Error);
        Assert.Equal("invalid_receipt_line", (await service.Receive(Item, "synthetic-receipt-001", Supplier,
            new(Supplier, [new(Item, -1)]), default)).Error);
        Assert.Equal("invalid_cancellation_reason", (await service.Cancel(Item, "synthetic-cancel-001", Supplier, new(""), default)).Error);
    }

    [Theory]
    [InlineData(false, false)]
    [InlineData(false, true)]
    [InlineData(true, false)]
    [InlineData(true, true)]
    public async Task Receipt_audit_records_refuse_updates_and_deletes_before_SQL(bool line, bool delete)
    {
        await using var db = Context();
        object entity = line ? new InternalPurchaseReceiptLine { Id = Guid.NewGuid(), ReceiptId = Guid.NewGuid(),
            PurchaseOrderId = Guid.NewGuid(), PurchaseOrderLineId = Guid.NewGuid(), ItemId = Guid.NewGuid() }
            : new InternalPurchaseReceipt { Id = Guid.NewGuid(), PurchaseOrderId = Guid.NewGuid() };
        db.Attach(entity);
        db.Entry(entity).State = delete ? EntityState.Deleted : EntityState.Modified;
        Assert.Throws<InvalidOperationException>(() => db.SaveChanges());
        await Assert.ThrowsAsync<InvalidOperationException>(() => db.SaveChangesAsync());
    }

    [Fact]
    public async Task Mutation_without_root_transaction_is_refused_before_SQL()
    {
        await using var db = Context();
        var service = new InternalSupplyService(db, new NoTransactionCommands(), new NeverChangeStock());
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.Create(Item, "synthetic-order-key-001", Order(), default));
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.Receive(Item, "synthetic-receipt-001", Supplier,
            new(Supplier, [new(Item, 1)]), default));
        await Assert.ThrowsAsync<InvalidOperationException>(() => service.Cancel(Item, "synthetic-cancel-001", Supplier, new("Synthetic reason"), default));
    }

    [Fact]
    public void Sql_model_has_private_schema_quantity_checks_unique_lines_and_cross_order_receipt_foreign_keys()
    {
        using var db = Context();
        var model = db.GetService<IDesignTimeModel>().Model;
        foreach (var type in new[] { typeof(InternalPurchaseOrder), typeof(InternalPurchaseOrderLine), typeof(InternalPurchaseReceipt), typeof(InternalPurchaseReceiptLine) })
            Assert.Equal("savia_internal", model.FindEntityType(type)!.GetSchema());
        var lines = model.FindEntityType(typeof(InternalPurchaseOrderLine))!;
        Assert.Contains(lines.GetCheckConstraints(), x => x.Sql.Contains("[ReceivedQuantity] BETWEEN 0 AND [Quantity]", StringComparison.Ordinal));
        Assert.Contains(lines.GetIndexes(), x => x.IsUnique && x.Properties.Select(p => p.Name).SequenceEqual(new[] { "PurchaseOrderId", "ItemId" }));
        var receiptLines = model.FindEntityType(typeof(InternalPurchaseReceiptLine))!;
        Assert.Contains(receiptLines.GetForeignKeys(), x => x.PrincipalEntityType.ClrType == typeof(InternalPurchaseOrderLine) &&
            x.Properties.Select(p => p.Name).SequenceEqual(new[] { "PurchaseOrderId", "PurchaseOrderLineId", "ItemId" }));
        Assert.All(receiptLines.GetForeignKeys(), x => Assert.Equal(DeleteBehavior.Restrict, x.DeleteBehavior));
        var sql = db.Database.GenerateCreateScript(); // SQL generation only; never opens a connection.
        Assert.Contains("[savia_internal].[PurchaseReceipts]", sql);
        Assert.Contains("CK_InternalPurchaseLine_Quantity", sql);
    }

    private static InternalDbContext Context() => new(new DbContextOptionsBuilder<InternalDbContext>()
        .UseSqlServer("Server=127.0.0.1,1;Database=MarthaSynthetic_InternalSupply_NotOpened;Integrated Security=true;Connect Timeout=1").Options);
    private sealed class NeverRunCommands : IInternalCommandRunner
    {
        public Task<InternalResult<T>> RunScoped<T>(Guid actorId, string scope, string key, string fingerprint,
            InternalCommandResource resource, Func<CancellationToken, Task<InternalResult<T>>> action, CancellationToken ct) =>
            throw new InvalidOperationException("Synthetic validation test must not run any command or open SQL.");
        public Task<InternalResult<T>> Run<T>(Guid actorId, string scope, string key, string fingerprint,
            Func<CancellationToken, Task<InternalResult<T>>> action, CancellationToken ct) =>
            throw new InvalidOperationException("Synthetic validation test must not run any command or open SQL.");
    }
    private sealed class NoTransactionCommands : IInternalCommandRunner
    {
        public Task<InternalResult<T>> RunScoped<T>(Guid actorId, string scope, string key, string fingerprint,
            InternalCommandResource resource, Func<CancellationToken, Task<InternalResult<T>>> action, CancellationToken ct) =>
            action(ct);
        public Task<InternalResult<T>> Run<T>(Guid actorId, string scope, string key, string fingerprint,
            Func<CancellationToken, Task<InternalResult<T>>> action, CancellationToken ct) => action(ct);
    }
    private sealed class NeverChangeStock : IInternalStockLedger
    {
        public Task<InternalResult<bool>> Change(Guid itemId, Guid locationId, int onHandDelta, int reservedDelta,
            Guid actorId, Guid operationId, string kind, CancellationToken ct) =>
            throw new InvalidOperationException("Synthetic validation test must not change stock.");
    }
}
