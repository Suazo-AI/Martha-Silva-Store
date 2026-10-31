using System.Text.Json;
using Martha.Store.Api.Internal;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Martha.Store.Api.Tests;

// Actual production runner/security/EF ledger. These remain skipped until explicitly supplied
// an authorized disposable SQL endpoint; unit/model passes are not substituted as this proof.
public sealed class InternalCommerceCommandSqlTests
{
    [InternalCommerceSqlFact]
    public async Task Server_priced_multiline_sale_replays_immutable_receipt_after_price_change()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        await Seed(fixture, fixture.Item, 10);
        await Seed(fixture, fixture.SecondItem, 10);
        var request = new InternalSaleRequest(fixture.Location, null, [new(fixture.Item, 2), new(fixture.SecondItem, 3)]);
        var first = await fixture.Execute(s => s.RecordSale(request, fixture.Actor, "sale-multiline-key-0001", default));
        Assert.True(first.Success);
        Assert.Equal(1075, first.Value!.TotalMinor);
        Assert.Equal("USD", first.Value.Currency);
        Assert.Equal("not_processed", first.Value.PaymentStatus);
        await using (var db = fixture.Context())
            await db.Set<InternalItem>().Where(x => x.Id == fixture.Item).ExecuteUpdateAsync(set => set.SetProperty(x => x.UnitPriceMinor, 999));
        var replay = await fixture.Execute(s => s.RecordSale(request, fixture.Actor, "sale-multiline-key-0001", default));
        Assert.Equal(JsonSerializer.Serialize(first), JsonSerializer.Serialize(replay));
        await using var verify = fixture.Context();
        Assert.Equal(1, await verify.Set<InternalSale>().CountAsync());
        Assert.Equal(4, await verify.Set<InternalStockMovement>().CountAsync());
        Assert.Equal(8, (await verify.Set<InternalStockBalance>().SingleAsync(x => x.ItemId == fixture.Item)).OnHand);
        Assert.Equal(7, (await verify.Set<InternalStockBalance>().SingleAsync(x => x.ItemId == fixture.SecondItem)).OnHand);
    }

    [InternalCommerceSqlFact]
    public async Task Rejected_later_line_rolls_back_earlier_line_and_failure_replay_remains_immutable()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        await Seed(fixture, fixture.Item, 1);
        var request = new InternalSaleRequest(fixture.Location, null, [new(fixture.Item, 1), new(fixture.SecondItem, 1)]);
        var first = await fixture.Execute(s => s.RecordSale(request, fixture.Actor, "sale-rollback-key-0001", default));
        Assert.Equal("stock_unavailable", first.Error);
        await using (var verify = fixture.Context())
        {
            Assert.Equal(1, (await verify.Set<InternalStockBalance>().SingleAsync()).OnHand);
            Assert.Equal(1, await verify.Set<InternalStockMovement>().CountAsync());
            Assert.False(await verify.Set<InternalSale>().AnyAsync());
        }
        await Seed(fixture, fixture.SecondItem, 1);
        var replay = await fixture.Execute(s => s.RecordSale(request, fixture.Actor, "sale-rollback-key-0001", default));
        Assert.Equal("stock_unavailable", replay.Error);
        var fresh = await fixture.Execute(s => s.RecordSale(request, fixture.Actor, "sale-rollback-key-0002", default));
        Assert.True(fresh.Success);
        await using var final = fixture.Context();
        Assert.All(await final.Set<InternalStockBalance>().ToListAsync(), balance => Assert.Equal(0, balance.OnHand));
        Assert.Equal(1, await final.Set<InternalSale>().CountAsync());
        Assert.Equal(4, await final.Set<InternalStockMovement>().CountAsync());
    }

    [InternalCommerceSqlFact]
    public async Task Cancel_replays_and_different_key_cancel_cannot_restock_twice_or_refund_bank_money()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        var sale = await Sell(fixture, 2);
        var request = new InternalSaleCancelRequest("record entered in error");
        var first = await fixture.Execute(s => s.CancelSale(sale.SaleId, request, fixture.Actor, "sale-cancel-key-0001", default));
        Assert.True(first.Success);
        Assert.Equal("cancelled", first.Value!.SaleState);
        Assert.Equal("not_processed", first.Value.BankRefundStatus);
        Assert.Equal(250, first.Value.RecordedCreditMinor);
        var replay = await fixture.Execute(s => s.CancelSale(sale.SaleId, request, fixture.Actor, "sale-cancel-key-0001", default));
        Assert.Equal(JsonSerializer.Serialize(first), JsonSerializer.Serialize(replay));
        var again = await fixture.Execute(s => s.CancelSale(sale.SaleId, request, fixture.Actor, "sale-cancel-key-0002", default));
        Assert.Equal(first.Value.ReversalId, again.Value!.ReversalId);
        await using var verify = fixture.Context();
        Assert.Equal(5, (await verify.Set<InternalStockBalance>().SingleAsync()).OnHand);
        Assert.Equal(1, await verify.Set<InternalSaleReversal>().CountAsync());
        Assert.Equal(3, await verify.Set<InternalStockMovement>().CountAsync());
    }

    [InternalCommerceSqlFact]
    public async Task Partial_full_return_replay_and_excess_return_preserve_quantity_and_original_price()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        var sale = await Sell(fixture, 3);
        var line = Assert.Single(sale.Lines);
        var request = new InternalSaleReturnRequest("returned to stock", [new(line.SaleLineId, 1)]);
        var partial = await fixture.Execute(s => s.ReturnSale(sale.SaleId, request, fixture.Actor, "sale-return-key-0001", default));
        Assert.True(partial.Success);
        Assert.Equal("partially_returned", partial.Value!.SaleState);
        Assert.Equal(125, partial.Value.RecordedCreditMinor);
        Assert.Equal("not_processed", partial.Value.BankRefundStatus);
        var replay = await fixture.Execute(s => s.ReturnSale(sale.SaleId, request, fixture.Actor, "sale-return-key-0001", default));
        Assert.Equal(JsonSerializer.Serialize(partial), JsonSerializer.Serialize(replay));
        var excess = await fixture.Execute(s => s.ReturnSale(sale.SaleId, new("too many", [new(line.SaleLineId, 3)]), fixture.Actor, "sale-return-excess-01", default));
        Assert.Equal("return_quantity_exceeded", excess.Error);
        var full = await fixture.Execute(s => s.ReturnSale(sale.SaleId, new("remaining units", [new(line.SaleLineId, 2)]), fixture.Actor, "sale-return-key-0002", default));
        Assert.Equal("returned", full.Value!.SaleState);
        Assert.Equal(250, full.Value.RecordedCreditMinor);
        var after = await fixture.Execute(s => s.ReturnSale(sale.SaleId, request, fixture.Actor, "sale-return-after-001", default));
        Assert.Equal("sale_state_conflict", after.Error);
        await using var verify = fixture.Context();
        Assert.Equal(5, (await verify.Set<InternalStockBalance>().SingleAsync()).OnHand);
        Assert.Equal(3, (await verify.Set<InternalSaleLine>().SingleAsync()).ReturnedQuantity);
        Assert.Equal(2, await verify.Set<InternalSaleReversal>().CountAsync());
    }

    [InternalCommerceSqlFact]
    public async Task Concurrent_cancel_and_return_have_only_one_stock_reversal()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        var sale = await Sell(fixture, 2);
        var line = Assert.Single(sale.Lines);
        var actor = fixture.Actor;
        var cancelRequest = new InternalSaleCancelRequest("cancel test");
        var returnRequest = new InternalSaleReturnRequest("return test", [new(line.SaleLineId, 2)]);
        const string cancelKey = "concurrent-cancel-001";
        const string returnKey = "concurrent-return-001";
        var results = await Task.WhenAll(
            fixture.Execute(s => s.CancelSale(sale.SaleId, cancelRequest, actor, cancelKey, default)),
            fixture.Execute(s => s.ReturnSale(sale.SaleId, returnRequest, actor, returnKey, default)));
        var winner = Assert.Single(results, result => result.Success);
        var nonSuccess = Assert.Single(results, result => !result.Success);
        Assert.Contains(nonSuccess.Error, new[] { "sale_state_conflict", "unknown_outcome" });
        var losingIndex = Array.FindIndex(results, result => !result.Success);
        var losingScope = losingIndex == 0 ? "commerce.sale.cancel" : "commerce.sale.return";
        var losingKey = losingIndex == 0 ? cancelKey : returnKey;
        await using (var verify = fixture.Context())
        {
            Assert.Equal(5, (await verify.Set<InternalStockBalance>().SingleAsync()).OnHand);
            Assert.Equal(1, await verify.Set<InternalSaleReversal>().CountAsync());
            Assert.Equal(winner.Value!.ReversalId, (await verify.Set<InternalSaleReversal>().SingleAsync()).Id);
        }

        // Reconcile once with the exact losing actor, scope, key and payload.
        var recovered = losingIndex == 0
            ? await fixture.Execute(s => s.CancelSale(sale.SaleId, cancelRequest, actor, cancelKey, default))
            : await fixture.Execute(s => s.ReturnSale(sale.SaleId, returnRequest, actor, returnKey, default));
        Assert.False(recovered.Success);
        Assert.Equal("sale_state_conflict", recovered.Error);
        InternalOperation persisted;
        await using (var verify = fixture.Context())
        {
            persisted = await verify.Set<InternalOperation>().AsNoTracking()
                .SingleAsync(operation => operation.ActorId == actor && operation.Scope == losingScope && operation.Key == losingKey);
            var rejection = JsonSerializer.Deserialize<InternalResult<InternalSaleReversalReceipt>>(
                persisted.ResultJson, new JsonSerializerOptions(JsonSerializerDefaults.Web));
            Assert.NotNull(rejection);
            Assert.False(rejection.Success);
            Assert.Equal("sale_state_conflict", rejection.Error);
        }

        // A second explicit call must replay the same definitive rejection.
        var replay = losingIndex == 0
            ? await fixture.Execute(s => s.CancelSale(sale.SaleId, cancelRequest, actor, cancelKey, default))
            : await fixture.Execute(s => s.ReturnSale(sale.SaleId, returnRequest, actor, returnKey, default));
        Assert.Equal(JsonSerializer.Serialize(recovered), JsonSerializer.Serialize(replay));
        await using var final = fixture.Context();
        var replayedOperation = await final.Set<InternalOperation>().AsNoTracking()
            .SingleAsync(operation => operation.ActorId == actor && operation.Scope == losingScope && operation.Key == losingKey);
        Assert.Equal(persisted.Id, replayedOperation.Id);
        Assert.Equal(persisted.ResultJson, replayedOperation.ResultJson);
        Assert.Equal(5, (await final.Set<InternalStockBalance>().SingleAsync()).OnHand);
        Assert.Equal(1, await final.Set<InternalSaleReversal>().CountAsync());
        Assert.Equal(winner.Value!.ReversalId, (await final.Set<InternalSaleReversal>().SingleAsync()).Id);
    }

    [InternalCommerceSqlFact]
    public async Task Mixed_currency_sale_is_rejected_without_inventory_mutation()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        await Seed(fixture, fixture.Item, 1);
        await Seed(fixture, fixture.SecondItem, 1);
        await using (var db = fixture.Context())
            await db.Set<InternalItem>().Where(x => x.Id == fixture.SecondItem).ExecuteUpdateAsync(set => set.SetProperty(x => x.Currency, "EUR"));
        var result = await fixture.Execute(s => s.RecordSale(new(fixture.Location, null, [new(fixture.Item, 1), new(fixture.SecondItem, 1)]), fixture.Actor, "sale-mixed-currency-1", default));
        Assert.Equal("currency_mismatch", result.Error);
        await using var verify = fixture.Context();
        Assert.All(await verify.Set<InternalStockBalance>().ToListAsync(), balance => Assert.Equal(1, balance.OnHand));
        Assert.False(await verify.Set<InternalSale>().AnyAsync());
        Assert.Equal(2, await verify.Set<InternalStockMovement>().CountAsync());
    }

    [InternalCommerceSqlFact]
    public async Task Historical_cancellation_can_restore_inactive_item_and_location()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        var sale = await Sell(fixture, 2);
        await using (var db = fixture.Context())
        {
            await db.Set<InternalItem>().Where(x => x.Id == fixture.Item).ExecuteUpdateAsync(set => set.SetProperty(x => x.Active, false));
            await db.Set<InternalLocation>().Where(x => x.Id == fixture.Location).ExecuteUpdateAsync(set => set.SetProperty(x => x.Active, false));
        }
        var result = await fixture.Execute(s => s.CancelSale(sale.SaleId, new("historical cancellation"), fixture.Actor, "inactive-cancel-key01", default));
        Assert.True(result.Success);
        await using var verify = fixture.Context();
        Assert.Equal(5, (await verify.Set<InternalStockBalance>().SingleAsync()).OnHand);
    }

    [InternalCommerceSqlFact]
    public async Task Same_sale_key_with_different_payload_is_a_conflict_not_a_second_sale()
    {
        await using var fixture = await InternalCommerceSqlDatabase.Create();
        await Seed(fixture, fixture.Item, 5);
        var first = await fixture.Execute(s => s.RecordSale(new(fixture.Location, null, [new(fixture.Item, 1)]), fixture.Actor, "sale-key-conflict-001", default));
        Assert.True(first.Success);
        var conflict = await fixture.Execute(s => s.RecordSale(new(fixture.Location, null, [new(fixture.Item, 2)]), fixture.Actor, "sale-key-conflict-001", default));
        Assert.Equal("idempotency_conflict", conflict.Error);
        await using var verify = fixture.Context();
        Assert.Equal(4, (await verify.Set<InternalStockBalance>().SingleAsync()).OnHand);
        Assert.Equal(1, await verify.Set<InternalSale>().CountAsync());
    }

    private static async Task Seed(InternalCommerceSqlDatabase fixture, Guid item, int quantity)
    {
        var result = await fixture.Execute(s => s.Adjust(new(item, fixture.Location, quantity, "Disposable test opening count"), fixture.Actor, "seed-" + Guid.NewGuid().ToString("N"), default));
        Assert.True(result.Success, result.Error);
    }

    private static async Task<InternalSaleReceipt> Sell(InternalCommerceSqlDatabase fixture, int quantity)
    {
        await Seed(fixture, fixture.Item, 5);
        var result = await fixture.Execute(s => s.RecordSale(new(fixture.Location, null, [new(fixture.Item, quantity)]), fixture.Actor, "sale-" + Guid.NewGuid().ToString("N"), default));
        Assert.True(result.Success, result.Error);
        return result.Value!;
    }
}
