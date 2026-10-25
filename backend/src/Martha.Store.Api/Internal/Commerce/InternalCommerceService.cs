using Microsoft.EntityFrameworkCore;

namespace Martha.Store.Api.Internal;

public sealed class InternalCommerceService(InternalDbContext db, IInternalCommandRunner commands, IInternalStockLedger ledger)
{
    public Task<InternalResult<InternalStockAdjustmentReceipt>> Adjust(InternalStockAdjustmentRequest request, Guid actorId, string key, CancellationToken ct)
    {
        if (!ValidActorKey(actorId, key) || !InternalCommerceRules.ValidReason(request.Reason)
            || !InternalStockLedger.ValidChange(request.ItemId, request.LocationId, request.OnHandDelta, 0, actorId, actorId, "adjustment"))
            return Task.FromResult(InternalResult<InternalStockAdjustmentReceipt>.Fail("invalid_request"));
        return commands.Run(actorId, "commerce.stock.adjust", key, InternalRules.Fingerprint(request), async token =>
        {
            if (!await db.Set<InternalItem>().AnyAsync(x => x.Id == request.ItemId && x.Active, token))
                return InternalResult<InternalStockAdjustmentReceipt>.Fail("item_not_found");
            if (!await db.Set<InternalLocation>().AnyAsync(x => x.Id == request.LocationId && x.Active, token))
                return InternalResult<InternalStockAdjustmentReceipt>.Fail("location_not_found");
            var adjustment = new InternalStockAdjustment
            {
                Id = Guid.NewGuid(), ItemId = request.ItemId, LocationId = request.LocationId, OnHandDelta = request.OnHandDelta,
                ActorId = actorId, Reason = request.Reason!.Trim(), CreatedAt = DateTimeOffset.UtcNow
            };
            var stock = await ledger.Change(request.ItemId, request.LocationId, request.OnHandDelta, 0, actorId, adjustment.Id, "adjustment", token);
            if (!stock.Success) return InternalResult<InternalStockAdjustmentReceipt>.Fail(stock.Error!);
            db.Set<InternalStockAdjustment>().Add(adjustment);
            await db.SaveChangesAsync(token);
            return InternalResult<InternalStockAdjustmentReceipt>.Ok(new(adjustment.Id, adjustment.ItemId, adjustment.LocationId,
                adjustment.OnHandDelta, adjustment.ActorId, adjustment.Reason, adjustment.CreatedAt));
        }, ct);
    }

    public Task<InternalResult<InternalSaleReceipt>> RecordSale(InternalSaleRequest request, Guid actorId, string key, CancellationToken ct)
    {
        if (!ValidActorKey(actorId, key) || !InternalCommerceRules.ValidSale(request))
            return Task.FromResult(InternalResult<InternalSaleReceipt>.Fail("invalid_request"));
        return commands.Run(actorId, "commerce.sale.record", key, InternalRules.Fingerprint(request), async token =>
        {
            if (!await db.Set<InternalLocation>().AnyAsync(x => x.Id == request.LocationId && x.Active, token))
                return InternalResult<InternalSaleReceipt>.Fail("location_not_found");
            if (request.CustomerId is { } customer && !await db.Set<InternalParty>().AnyAsync(x => x.Id == customer && x.Kind == "customer" && x.Active, token))
                return InternalResult<InternalSaleReceipt>.Fail("customer_not_found");
            var ordered = request.Lines!.OrderBy(x => x.ItemId).ToArray();
            var ids = ordered.Select(x => x.ItemId).ToArray();
            var items = await db.Set<InternalItem>().AsNoTracking().Where(x => ids.Contains(x.Id) && x.Active).OrderBy(x => x.Id).ToListAsync(token);
            if (items.Count != ordered.Length) return InternalResult<InternalSaleReceipt>.Fail("item_not_found");
            var byId = items.ToDictionary(x => x.Id);
            if (items.Any(x => !InternalRules.ValidCurrency(x.Currency)) || items.Select(x => x.Currency).Distinct(StringComparer.Ordinal).Count() != 1)
                return InternalResult<InternalSaleReceipt>.Fail("currency_mismatch");
            if (!InternalCommerceRules.TryTotal(ordered.Select(x => (byId[x.ItemId].UnitPriceMinor, x.Quantity)), out var total))
                return InternalResult<InternalSaleReceipt>.Fail("amount_out_of_range");
            var sale = new InternalSale
            {
                Id = Guid.NewGuid(), ActorId = actorId, LocationId = request.LocationId, CustomerId = request.CustomerId,
                Currency = items[0].Currency, TotalMinor = total, State = "recorded", CreatedAt = DateTimeOffset.UtcNow
            };
            foreach (var requested in ordered)
            {
                var item = byId[requested.ItemId];
                sale.Lines.Add(new()
                {
                    Id = Guid.NewGuid(), SaleId = sale.Id, ItemId = item.Id, Sku = item.Sku, Name = item.Name,
                    Quantity = requested.Quantity, UnitPriceMinor = item.UnitPriceMinor, TotalMinor = item.UnitPriceMinor * requested.Quantity
                });
                var change = await ledger.Change(item.Id, sale.LocationId, -requested.Quantity, 0, actorId, sale.Id, "sale", token);
                if (!change.Success) return InternalResult<InternalSaleReceipt>.Fail(change.Error!);
            }
            db.Set<InternalSale>().Add(sale);
            await db.SaveChangesAsync(token);
            return InternalResult<InternalSaleReceipt>.Ok(ToReceipt(sale));
        }, ct);
    }

    public Task<InternalResult<InternalSaleReversalReceipt>> CancelSale(Guid saleId, InternalSaleCancelRequest request, Guid actorId, string key, CancellationToken ct)
    {
        if (saleId == Guid.Empty || !ValidActorKey(actorId, key) || !InternalCommerceRules.ValidReason(request.Reason))
            return Task.FromResult(InternalResult<InternalSaleReversalReceipt>.Fail("invalid_request"));
        return commands.Run(actorId, "commerce.sale.cancel", key, InternalRules.Fingerprint(new { saleId, request }), async token =>
        {
            var sale = await LockSale(saleId, token);
            if (sale is null) return InternalResult<InternalSaleReversalReceipt>.Fail("sale_not_found");
            if (sale.State == "cancelled")
            {
                var original = await db.Set<InternalSaleReversal>().AsNoTracking().Include(x => x.Lines)
                    .SingleAsync(x => x.SaleId == saleId && x.Kind == "cancel", token);
                return InternalResult<InternalSaleReversalReceipt>.Ok(ToReceipt(original, sale));
            }
            // Cancellation is a complete reversal of an untouched record, never a second return.
            if (sale.State != "recorded" || sale.Lines.Any(x => x.ReturnedQuantity != 0))
                return InternalResult<InternalSaleReversalReceipt>.Fail("sale_state_conflict");
            var reversal = NewReversal(sale, actorId, "cancel", request.Reason!);
            foreach (var line in sale.Lines.OrderBy(x => x.ItemId))
            {
                var change = await ledger.Change(line.ItemId, sale.LocationId, line.Quantity, 0, actorId, reversal.Id, "sale_cancel", token);
                if (!change.Success) return InternalResult<InternalSaleReversalReceipt>.Fail(change.Error!);
                reversal.Lines.Add(NewReversalLine(reversal.Id, line, line.Quantity));
            }
            foreach (var line in sale.Lines) line.ReturnedQuantity = line.Quantity;
            sale.State = "cancelled";
            reversal.RecordedCreditMinor = sale.TotalMinor;
            db.Set<InternalSaleReversal>().Add(reversal);
            await db.SaveChangesAsync(token);
            return InternalResult<InternalSaleReversalReceipt>.Ok(ToReceipt(reversal, sale));
        }, ct);
    }

    public Task<InternalResult<InternalSaleReversalReceipt>> ReturnSale(Guid saleId, InternalSaleReturnRequest request, Guid actorId, string key, CancellationToken ct)
    {
        if (saleId == Guid.Empty || !ValidActorKey(actorId, key) || !InternalCommerceRules.ValidReturn(request))
            return Task.FromResult(InternalResult<InternalSaleReversalReceipt>.Fail("invalid_request"));
        return commands.Run(actorId, "commerce.sale.return", key, InternalRules.Fingerprint(new { saleId, request }), async token =>
        {
            var sale = await LockSale(saleId, token);
            if (sale is null) return InternalResult<InternalSaleReversalReceipt>.Fail("sale_not_found");
            if (sale.State is not ("recorded" or "partially_returned"))
                return InternalResult<InternalSaleReversalReceipt>.Fail("sale_state_conflict");
            var byId = sale.Lines.ToDictionary(x => x.Id);
            foreach (var requested in request.Lines!)
                if (!byId.TryGetValue(requested.SaleLineId, out var line) || requested.Quantity > line.Quantity - line.ReturnedQuantity)
                    return InternalResult<InternalSaleReversalReceipt>.Fail("return_quantity_exceeded");
            var ordered = request.Lines!.OrderBy(x => byId[x.SaleLineId].ItemId).ToArray();
            var reversal = NewReversal(sale, actorId, "return", request.Reason!);
            foreach (var requested in ordered)
            {
                var line = byId[requested.SaleLineId];
                var change = await ledger.Change(line.ItemId, sale.LocationId, requested.Quantity, 0, actorId, reversal.Id, "sale_return", token);
                if (!change.Success) return InternalResult<InternalSaleReversalReceipt>.Fail(change.Error!);
                var reversedLine = NewReversalLine(reversal.Id, line, requested.Quantity);
                reversal.Lines.Add(reversedLine);
                reversal.RecordedCreditMinor += reversedLine.RecordedCreditMinor;
            }
            foreach (var requested in ordered) byId[requested.SaleLineId].ReturnedQuantity += requested.Quantity;
            sale.State = sale.Lines.All(x => x.ReturnedQuantity == x.Quantity) ? "returned" : "partially_returned";
            db.Set<InternalSaleReversal>().Add(reversal);
            await db.SaveChangesAsync(token);
            return InternalResult<InternalSaleReversalReceipt>.Ok(ToReceipt(reversal, sale));
        }, ct);
    }

    public async Task<InternalCommercePage<InternalStockView>> Stock(Guid? locationId, int skip, int take, CancellationToken ct)
    {
        RequirePage(skip, take, 1000);
        var query = db.Set<InternalStockBalance>().AsNoTracking().Where(x => locationId == null || x.LocationId == locationId);
        var total = await query.CountAsync(ct);
        var items = await query.OrderBy(x => x.ItemId).ThenBy(x => x.LocationId).Skip(skip).Take(take)
            .Select(x => new InternalStockView(x.ItemId, x.LocationId, x.OnHand, x.Reserved, x.OnHand - x.Reserved, x.UpdatedAt)).ToListAsync(ct);
        return new(items, total, skip, take);
    }

    public async Task<InternalCommercePage<InternalStockMovement>> Movements(Guid? itemId, Guid? locationId, int skip, int take, CancellationToken ct)
    {
        RequirePage(skip, take, 200);
        var query = db.Set<InternalStockMovement>().AsNoTracking().Where(x => (itemId == null || x.ItemId == itemId) && (locationId == null || x.LocationId == locationId));
        var total = await query.CountAsync(ct);
        var items = await query.OrderByDescending(x => x.CreatedAt).ThenBy(x => x.Id).Skip(skip).Take(take).ToListAsync(ct);
        return new(items, total, skip, take);
    }

    public async Task<InternalCommercePage<InternalSaleReceipt>> Sales(int skip, int take, CancellationToken ct)
    {
        RequirePage(skip, take, 100);
        var query = db.Set<InternalSale>().AsNoTracking();
        var total = await query.CountAsync(ct);
        var items = await query.Include(x => x.Lines).OrderByDescending(x => x.CreatedAt).ThenBy(x => x.Id).Skip(skip).Take(take).ToListAsync(ct);
        return new(items.Select(ToReceipt).ToArray(), total, skip, take);
    }

    public static bool ValidPage(int skip, int take, int maximum) => skip >= 0 && take >= 1 && take <= maximum;
    private static void RequirePage(int skip, int take, int maximum)
    {
        if (!ValidPage(skip, take, maximum)) throw new ArgumentOutOfRangeException(nameof(take), "Invalid page bounds.");
    }

    public async Task<InternalSaleReceipt?> Sale(Guid id, CancellationToken ct)
    {
        var sale = await db.Set<InternalSale>().AsNoTracking().Include(x => x.Lines).SingleOrDefaultAsync(x => x.Id == id, ct);
        return sale is null ? null : ToReceipt(sale);
    }

    public async Task<IReadOnlyList<InternalSaleReversalReceipt>?> Reversals(Guid id, CancellationToken ct)
    {
        var sale = await db.Set<InternalSale>().AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, ct);
        if (sale is null) return null;
        return (await db.Set<InternalSaleReversal>().AsNoTracking().Include(x => x.Lines).Where(x => x.SaleId == id)
            .OrderBy(x => x.CreatedAt).ThenBy(x => x.Id).ToListAsync(ct)).Select(x => ToReceipt(x, sale)).ToArray();
    }

    private Task<InternalSale?> LockSale(Guid id, CancellationToken ct) => db.Set<InternalSale>()
        .FromSqlInterpolated($"SELECT * FROM [savia_internal].[Sales] WITH (UPDLOCK,HOLDLOCK) WHERE [Id]={id}")
        .Include(x => x.Lines).SingleOrDefaultAsync(ct);

    private static bool ValidActorKey(Guid actor, string key) => actor != Guid.Empty && InternalRules.ValidKey(key);
    private static InternalSaleReversal NewReversal(InternalSale sale, Guid actor, string kind, string reason) =>
        new() { Id = Guid.NewGuid(), SaleId = sale.Id, ActorId = actor, Kind = kind, Reason = reason.Trim(), CreatedAt = DateTimeOffset.UtcNow };
    private static InternalSaleReversalLine NewReversalLine(Guid reversalId, InternalSaleLine line, int quantity) =>
        new() { Id = Guid.NewGuid(), ReversalId = reversalId, SaleLineId = line.Id, Quantity = quantity, RecordedCreditMinor = checked(line.UnitPriceMinor * quantity) };
    private static InternalSaleReceipt ToReceipt(InternalSale sale) =>
        new(sale.Id, sale.LocationId, sale.CustomerId, sale.ActorId, sale.Currency, sale.TotalMinor, sale.State, "not_processed", sale.CreatedAt,
            sale.Lines.OrderBy(x => x.ItemId).Select(x => new InternalSaleLineReceipt(x.Id, x.ItemId, x.Sku, x.Name, x.Quantity, x.ReturnedQuantity, x.UnitPriceMinor, x.TotalMinor)).ToArray());
    private static InternalSaleReversalReceipt ToReceipt(InternalSaleReversal reversal, InternalSale sale) =>
        new(reversal.Id, sale.Id, reversal.ActorId, reversal.Kind, sale.State, sale.Currency, reversal.RecordedCreditMinor, "not_processed", reversal.Reason,
            reversal.CreatedAt, reversal.Lines.OrderBy(x => x.SaleLineId).Select(x => new InternalSaleReversalLineReceipt(x.SaleLineId, x.Quantity, x.RecordedCreditMinor)).ToArray());
}
