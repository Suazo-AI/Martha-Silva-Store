using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Martha.Store.Api.Internal;

// All mutations, including receipt counters and Commerce ledger entries, run on
// the injected context inside the root runner's single serializable transaction.
public sealed class InternalSupplyService(InternalDbContext db, IInternalCommandRunner commands, IInternalStockLedger stock)
{
    public async Task<InternalSupplyPage<InternalPurchaseOrderView>> List(int skip, int take, CancellationToken ct)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(skip);
        if (take is < 1 or > 100) throw new ArgumentOutOfRangeException(nameof(take));
        var orders = await db.Set<InternalPurchaseOrder>().AsNoTracking().Include(x => x.Lines)
            .OrderByDescending(x => x.CreatedAt).ThenBy(x => x.Id).Skip(skip).Take(take + 1).ToListAsync(ct);
        return new(orders.Take(take).Select(InternalPurchaseOrderView.From).ToArray(), skip, take, orders.Count > take);
    }

    public async Task<InternalPurchaseOrderView?> Get(Guid id, CancellationToken ct)
    {
        var order = await db.Set<InternalPurchaseOrder>().AsNoTracking().Include(x => x.Lines)
            .SingleOrDefaultAsync(x => x.Id == id, ct);
        return order is null ? null : InternalPurchaseOrderView.From(order);
    }

    public async Task<InternalSupplyPage<InternalPurchaseReceiptView>?> Receipts(Guid orderId, int skip, int take, CancellationToken ct)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(skip);
        if (take is < 1 or > 100) throw new ArgumentOutOfRangeException(nameof(take));
        if (!await db.Set<InternalPurchaseOrder>().AnyAsync(x => x.Id == orderId, ct)) return null;
        var receipts = await db.Set<InternalPurchaseReceipt>().AsNoTracking().Include(x => x.Lines)
            .Where(x => x.PurchaseOrderId == orderId).OrderByDescending(x => x.ReceivedAt).ThenBy(x => x.Id)
            .Skip(skip).Take(take + 1).ToListAsync(ct);
        return new(receipts.Take(take).Select(InternalPurchaseReceiptView.From).ToArray(), skip, take, receipts.Count > take);
    }

    public Task<InternalResult<InternalPurchaseOrderView>> Create(Guid actorId, string key,
        InternalPurchaseOrderRequest request, CancellationToken ct)
    {
        var error = ValidateCommand(actorId, key) ?? InternalSupplyRules.Validate(request);
        if (error is not null) return Task.FromResult(InternalResult<InternalPurchaseOrderView>.Fail(error));
        return commands.Run(actorId, "supply.purchase.create", key, InternalSupplyRules.OrderFingerprint(request), async token =>
        {
            RequireTransaction();
            var supplier = await db.Set<InternalParty>().AsNoTracking()
                .SingleOrDefaultAsync(x => x.Id == request.SupplierId && x.Kind == "supplier" && x.Active, token);
            if (supplier is null) return InternalResult<InternalPurchaseOrderView>.Fail("supplier_unavailable");
            if (!await db.Set<InternalLocation>().AnyAsync(x => x.Id == request.LocationId && x.Active, token))
                return InternalResult<InternalPurchaseOrderView>.Fail("location_unavailable");
            var itemIds = request.Lines!.Select(x => x.ItemId).ToArray();
            var items = await db.Set<InternalItem>().AsNoTracking().Where(x => itemIds.Contains(x.Id) && x.Active).ToListAsync(token);
            if (items.Count != itemIds.Length) return InternalResult<InternalPurchaseOrderView>.Fail("item_unavailable");
            if (items.Any(x => x.Currency != request.Currency))
                return InternalResult<InternalPurchaseOrderView>.Fail("currency_mismatch");
            var now = DateTimeOffset.UtcNow;
            var order = new InternalPurchaseOrder
            {
                Id = Guid.NewGuid(), SupplierId = supplier.Id, SupplierName = supplier.Name, LocationId = request.LocationId,
                Currency = request.Currency, Reference = request.Reference?.Trim(), Status = InternalPurchaseStatus.Open,
                CreatedBy = actorId, CreatedAt = now, UpdatedBy = actorId, UpdatedAt = now
            };
            var itemMap = items.ToDictionary(x => x.Id);
            foreach (var line in request.Lines!.OrderBy(x => x.ItemId))
            {
                var item = itemMap[line.ItemId];
                order.Lines.Add(new InternalPurchaseOrderLine
                {
                    Id = Guid.NewGuid(), PurchaseOrderId = order.Id, ItemId = item.Id, ItemSku = item.Sku, ItemName = item.Name,
                    Quantity = line.Quantity, UnitCostMinor = line.UnitCostMinor
                });
                order.TotalMinor = checked(order.TotalMinor + checked(line.UnitCostMinor * line.Quantity));
            }
            db.Set<InternalPurchaseOrder>().Add(order);
            await db.SaveChangesAsync(token);
            return InternalResult<InternalPurchaseOrderView>.Ok(InternalPurchaseOrderView.From(order));
        }, ct);
    }

    public Task<InternalResult<InternalPurchaseReceiptView>> Receive(Guid actorId, string key, Guid orderId,
        InternalPurchaseReceiptRequest request, CancellationToken ct)
    {
        var error = ValidateCommand(actorId, key) ?? (orderId == Guid.Empty ? "invalid_purchase_order" : null) ??
            InternalSupplyRules.Validate(request);
        if (error is not null) return Task.FromResult(InternalResult<InternalPurchaseReceiptView>.Fail(error));
        var fingerprint = InternalSupplyRules.ReceiptFingerprint(orderId, request);
        return commands.Run(actorId, "supply.receipt.create", key, fingerprint, async token =>
        {
            RequireTransaction();
            // Also deduplicate the physical receipt under a different command key.
            var existing = await db.Set<InternalPurchaseReceipt>()
                .FromSqlInterpolated($"SELECT * FROM [savia_internal].[PurchaseReceipts] WITH (UPDLOCK,HOLDLOCK) WHERE [Id] = {request.ReceiptId}")
                .AsNoTracking().Include(x => x.Lines).SingleOrDefaultAsync(token);
            if (existing is not null)
                return existing.PurchaseOrderId == orderId && existing.Fingerprint == fingerprint && existing.ReceivedBy == actorId
                    ? InternalResult<InternalPurchaseReceiptView>.Ok(InternalPurchaseReceiptView.From(existing))
                    : InternalResult<InternalPurchaseReceiptView>.Fail("receipt_identity_conflict");

            var order = await db.Set<InternalPurchaseOrder>()
                .FromSqlInterpolated($"SELECT * FROM [savia_internal].[PurchaseOrders] WITH (UPDLOCK,HOLDLOCK) WHERE [Id] = {orderId}")
                .AsNoTracking().Include(x => x.Lines).SingleOrDefaultAsync(token);
            if (order is null) return InternalResult<InternalPurchaseReceiptView>.Fail("purchase_order_not_found");
            if (!InternalPurchaseStatus.Receivable(order.Status))
                return InternalResult<InternalPurchaseReceiptView>.Fail("purchase_order_closed");
            if (!await db.Set<InternalLocation>().AnyAsync(x => x.Id == order.LocationId && x.Active, token))
                return InternalResult<InternalPurchaseReceiptView>.Fail("location_unavailable");
            var lines = order.Lines.ToDictionary(x => x.Id);
            foreach (var requested in request.Lines!)
            {
                if (!lines.TryGetValue(requested.PurchaseOrderLineId, out var line))
                    return InternalResult<InternalPurchaseReceiptView>.Fail("purchase_line_not_found");
                if (!InternalSupplyRules.CanReceive(line.Quantity, line.ReceivedQuantity, requested.Quantity))
                    return InternalResult<InternalPurchaseReceiptView>.Fail("receipt_exceeds_remaining");
            }
            var itemIds = request.Lines.Select(x => lines[x.PurchaseOrderLineId].ItemId).ToArray();
            var items = await db.Set<InternalItem>().AsNoTracking().Where(x => itemIds.Contains(x.Id) && x.Active).ToListAsync(token);
            if (items.Count != itemIds.Length) return InternalResult<InternalPurchaseReceiptView>.Fail("item_unavailable");
            if (items.Any(x => x.Currency != order.Currency))
                return InternalResult<InternalPurchaseReceiptView>.Fail("currency_mismatch");

            var receipt = new InternalPurchaseReceipt
            {
                Id = request.ReceiptId, PurchaseOrderId = order.Id, LocationId = order.LocationId,
                Currency = order.Currency, Fingerprint = fingerprint, ReceivedBy = actorId, ReceivedAt = DateTimeOffset.UtcNow
            };
            // Same item/location ordering as Commerce reduces cross-module lock inversions.
            foreach (var requested in request.Lines.OrderBy(x => lines[x.PurchaseOrderLineId].ItemId))
            {
                var line = lines[requested.PurchaseOrderLineId];
                var before = line.ReceivedQuantity;
                var changed = await db.Set<InternalPurchaseOrderLine>()
                    .Where(x => x.Id == line.Id && x.PurchaseOrderId == orderId && x.ReceivedQuantity == before &&
                        x.ReceivedQuantity <= x.Quantity - requested.Quantity)
                    .ExecuteUpdateAsync(updates => updates.SetProperty(x => x.ReceivedQuantity, x => x.ReceivedQuantity + requested.Quantity), token);
                if (changed != 1) return InternalResult<InternalPurchaseReceiptView>.Fail("receipt_concurrency_conflict");
                var movement = await stock.Change(line.ItemId, order.LocationId, requested.Quantity, 0, actorId,
                    receipt.Id, "purchase_receipt", token);
                if (!movement.Success) return InternalResult<InternalPurchaseReceiptView>.Fail(movement.Error!);
                line.ReceivedQuantity += requested.Quantity;
                receipt.Lines.Add(new InternalPurchaseReceiptLine
                {
                    Id = Guid.NewGuid(), ReceiptId = receipt.Id, PurchaseOrderId = orderId, PurchaseOrderLineId = line.Id,
                    ItemId = line.ItemId, Quantity = requested.Quantity, UnitCostMinor = line.UnitCostMinor
                });
                receipt.TotalMinor = checked(receipt.TotalMinor + checked(line.UnitCostMinor * requested.Quantity));
            }
            receipt.OrderStatusAfter = order.Lines.All(x => x.ReceivedQuantity == x.Quantity)
                ? InternalPurchaseStatus.Received : InternalPurchaseStatus.Partial;
            var orderChanged = await db.Set<InternalPurchaseOrder>().Where(x => x.Id == orderId && x.Status == order.Status)
                .ExecuteUpdateAsync(updates => updates.SetProperty(x => x.Status, receipt.OrderStatusAfter)
                    .SetProperty(x => x.UpdatedBy, actorId).SetProperty(x => x.UpdatedAt, receipt.ReceivedAt), token);
            if (orderChanged != 1) return InternalResult<InternalPurchaseReceiptView>.Fail("receipt_concurrency_conflict");
            db.Set<InternalPurchaseReceipt>().Add(receipt);
            await db.SaveChangesAsync(token);
            return InternalResult<InternalPurchaseReceiptView>.Ok(InternalPurchaseReceiptView.From(receipt));
        }, ct);
    }

    // Cancelling the unreceived remainder is NOT a supplier return. Already
    // received goods and their immutable receipts/movements remain untouched.
    public Task<InternalResult<InternalPurchaseOrderView>> Cancel(Guid actorId, string key, Guid orderId,
        InternalPurchaseCancelRequest request, CancellationToken ct)
    {
        var error = ValidateCommand(actorId, key) ?? (orderId == Guid.Empty ? "invalid_purchase_order" : null) ??
            InternalSupplyRules.Validate(request);
        if (error is not null) return Task.FromResult(InternalResult<InternalPurchaseOrderView>.Fail(error));
        var reason = request.Reason.Trim();
        return commands.Run(actorId, "supply.purchase.cancel", key,
            InternalRules.Fingerprint(new { OrderId = orderId, Reason = reason }), async token =>
        {
            RequireTransaction();
            var order = await db.Set<InternalPurchaseOrder>()
                .FromSqlInterpolated($"SELECT * FROM [savia_internal].[PurchaseOrders] WITH (UPDLOCK,HOLDLOCK) WHERE [Id] = {orderId}")
                .AsNoTracking().Include(x => x.Lines).SingleOrDefaultAsync(token);
            if (order is null) return InternalResult<InternalPurchaseOrderView>.Fail("purchase_order_not_found");
            if (!InternalPurchaseStatus.Receivable(order.Status))
                return InternalResult<InternalPurchaseOrderView>.Fail("purchase_order_closed");
            var now = DateTimeOffset.UtcNow;
            var changed = await db.Set<InternalPurchaseOrder>().Where(x => x.Id == orderId && x.Status == order.Status)
                .ExecuteUpdateAsync(updates => updates.SetProperty(x => x.Status, InternalPurchaseStatus.Cancelled)
                    .SetProperty(x => x.CancelledBy, (Guid?)actorId).SetProperty(x => x.CancelledAt, (DateTimeOffset?)now)
                    .SetProperty(x => x.CancellationReason, reason).SetProperty(x => x.UpdatedBy, actorId)
                    .SetProperty(x => x.UpdatedAt, now), token);
            if (changed != 1) return InternalResult<InternalPurchaseOrderView>.Fail("purchase_concurrency_conflict");
            order.Status = InternalPurchaseStatus.Cancelled;
            order.CancelledBy = order.UpdatedBy = actorId;
            order.CancelledAt = order.UpdatedAt = now;
            order.CancellationReason = reason;
            return InternalResult<InternalPurchaseOrderView>.Ok(InternalPurchaseOrderView.From(order));
        }, ct);
    }

    private static string? ValidateCommand(Guid actorId, string key) => actorId == Guid.Empty
        ? "unauthenticated" : !InternalRules.ValidKey(key) ? "invalid_request" : null;

    private void RequireTransaction()
    {
        if (!db.Database.IsSqlServer() || db.Database.CurrentTransaction is not { } transaction ||
            transaction.GetDbTransaction().IsolationLevel != IsolationLevel.Serializable)
            throw new InvalidOperationException("Supply requires the command runner's shared SQL transaction.");
    }
}
