using System.Data;
using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Martha.Store.Api.Internal;

// The sale line is the durable allocation: non-null reason means physical delivery outside
// the recorded ledger. Sale supplies location, actor and time; line supplies item, size and quantity.
// No fabricated receipt, cost, balance or movement is written. Reversal reduces the outstanding
// delivered quantity only; any subsequent physical count/correction remains evidence-based inventory work.
public sealed class InternalStockExceptionReview
{
    public Guid Id { get; set; }
    public Guid SaleLineId { get; set; }
    public Guid ReviewerId { get; set; }
    public string Evidence { get; set; } = "";
    public string Outcome { get; set; } = "";
    public Guid ResponsibleActorId { get; set; }
    public DateTimeOffset NextReviewAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public string CauseState { get; set; } = "open";
}
[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record InternalStockExceptionReviewRequest(Guid SaleLineId, string? Evidence, string? Outcome,
    Guid ResponsibleActorId, DateTimeOffset NextReviewAt);

public static class InternalStockExceptionRules
{
    public static bool ValidSize(string? value) => value is { Length: >= 1 and <= 80 }
        && value.Trim().Length > 0 && !value.Any(char.IsControl);
    public static bool ValidReview(InternalStockExceptionReviewRequest request, DateTimeOffset now) =>
        request.SaleLineId != Guid.Empty && InternalCommerceRules.ValidReason(request.Evidence)
        && InternalCommerceRules.ValidReason(request.Outcome) && request.ResponsibleActorId != Guid.Empty
        && request.NextReviewAt > now;
}
public sealed partial class InternalDbContext
{
    private void ConfigureStockExceptions(ModelBuilder model)
    {
        var review = model.Entity<InternalStockExceptionReview>();
        review.ToTable("StockExceptionReviews", t => {
            t.HasCheckConstraint("CK_InternalStockReview_Open", "[CauseState] = 'open'");
            t.HasCheckConstraint("CK_InternalStockReview_Next", "[NextReviewAt] > [CreatedAt]");
        });
        review.HasKey(x => x.Id);
        review.Property(x => x.Evidence).HasMaxLength(500).IsRequired();
        review.Property(x => x.Outcome).HasMaxLength(500).IsRequired();
        review.Property(x => x.CauseState).HasMaxLength(16).IsRequired();
        review.HasOne<InternalSaleLine>().WithMany().HasForeignKey(x => x.SaleLineId).OnDelete(DeleteBehavior.Restrict);
        review.HasOne<InternalStaff>().WithMany().HasForeignKey(x => x.ReviewerId).OnDelete(DeleteBehavior.Restrict);
        review.HasOne<InternalStaff>().WithMany().HasForeignKey(x => x.ResponsibleActorId).OnDelete(DeleteBehavior.Restrict);
    }
}
public sealed partial class InternalCommerceService
{
    private async Task<InternalResult<bool>> RecordExceptionalAllocation(Guid item, Guid location, CancellationToken ct)
    {
        if (!db.Database.IsSqlServer() || db.Database.CurrentTransaction is not { } transaction
            || transaction.GetDbTransaction().IsolationLevel != IsolationLevel.Serializable)
            throw new InvalidOperationException("Exceptional allocation requires the same serializable SQL transaction.");
        // Same item/location order as ordinary sale and ledger, including missing-key range locks.
        var balance = await db.Set<InternalStockBalance>().FromSqlInterpolated($"SELECT * FROM [savia_internal].[StockBalances] WITH (UPDLOCK,HOLDLOCK) WHERE [ItemId]={item} AND [LocationId]={location}")
            .AsNoTracking().SingleOrDefaultAsync(ct);
        return balance is null || balance.OnHand - balance.Reserved == 0
            ? InternalResult<bool>.Ok(true) : InternalResult<bool>.Fail("exception_requires_zero_available");
    }

    public Task<InternalResult<InternalStockExceptionReview>> ReviewStockException(Guid saleId,
        InternalStockExceptionReviewRequest request, Guid actor, string key, CancellationToken ct)
    {
        if (saleId == Guid.Empty || !ValidActorKey(actor, key) || !InternalStockExceptionRules.ValidReview(request, DateTimeOffset.MinValue))
            return Task.FromResult(InternalResult<InternalStockExceptionReview>.Fail("invalid_request"));
        return commands.RunScoped(actor, "commerce.stock.review", key, InternalRules.Fingerprint(new { saleId, request }),
            new InternalCommandResource("sale", saleId), async token => {
                if (request.NextReviewAt <= DateTimeOffset.UtcNow) return InternalResult<InternalStockExceptionReview>.Fail("invalid_request");
                var sale = await LockSale(saleId, token);
                if (sale is null) return InternalResult<InternalStockExceptionReview>.Fail("sale_not_found");
                // Applies to Owner too. A substitute must have Manager/Owner role through runner + endpoint.
                if (sale.ActorId == actor) return InternalResult<InternalStockExceptionReview>.Fail("different_reviewer_required");
                if (!sale.Lines.Any(x => x.Id == request.SaleLineId && x.ExceptionReason != null))
                    return InternalResult<InternalStockExceptionReview>.Fail("exception_not_found");
                if (!await new InternalBranchAccess(db).CanAccessLocation(request.ResponsibleActorId, sale.LocationId, token))
                    return InternalResult<InternalStockExceptionReview>.Fail("responsible_actor_forbidden");
                var review = new InternalStockExceptionReview { Id = Guid.NewGuid(), SaleLineId = request.SaleLineId,
                    ReviewerId = actor, Evidence = request.Evidence!.Trim(), Outcome = request.Outcome!.Trim(),
                    ResponsibleActorId = request.ResponsibleActorId, NextReviewAt = request.NextReviewAt, CreatedAt = DateTimeOffset.UtcNow };
                db.Add(review); await db.SaveChangesAsync(token);
                return InternalResult<InternalStockExceptionReview>.Ok(review);
            }, ct);
    }

    public async Task<IReadOnlyList<InternalStockExceptionReview>?> StockReviews(Guid saleId, Guid actor, CancellationToken ct)
    {
        if (await Sale(saleId, ct, actor) is null) return null;
        return await db.Set<InternalStockExceptionReview>().AsNoTracking()
            .Where(x => db.Set<InternalSaleLine>().Any(l => l.Id == x.SaleLineId && l.SaleId == saleId))
            .OrderBy(x => x.CreatedAt).ThenBy(x => x.Id).ToListAsync(ct);
    }
}
