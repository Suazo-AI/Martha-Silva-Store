using System.Data;
using System.Security.Claims;
using Microsoft.EntityFrameworkCore;

namespace Martha.Store.Api.Internal;

public sealed record InternalCashConfiguration(string Currency, int Exponent);
public sealed record InternalCashTillBalance(InternalCashTill Till, long BalanceMinor);
public sealed record InternalCashContext(InternalCashConfiguration? Configuration,
    InternalCashTillBalance? OwnTill, InternalCashCloseReceipt? LastClose);
public sealed record InternalCashTillPage(IReadOnlyList<InternalCashTillBalance> Items, int Skip, int Take, bool HasMore);
public sealed record InternalCashRefundContext(InternalSaleReceipt Sale, InternalCashEntry Payment,
    long RefundedMinor, long RefundableMinor, string PaymentStatus, InternalCashTillPage PayingTills);

// The transaction includes session validation, authorization, provenance and all monetary reads.
// No current configuration value reinterprets a persisted payment or close.
public sealed class InternalCashReadService(InternalDbContext db, InternalSecurityService security,
    InternalCashOptions options, InternalCommerceService commerce)
{
    public async Task<InternalResult<InternalCashContext>> Context(ClaimsPrincipal principal, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var current = await security.ValidateSession(principal, ct);
        if (current is null) return InternalResult<InternalCashContext>.Fail("unauthenticated");
        if (!InternalCommandAuthorization.Allowed(current, "cash.sale")) return InternalResult<InternalCashContext>.Fail("forbidden");
        var actor = InternalActor.Id(current);
        var access = new InternalBranchAccess(db);
        // Find before filtering access: an inaccessible own open till must deny, not look absent.
        var till = await db.Set<InternalCashTill>().AsNoTracking()
            .SingleOrDefaultAsync(x => x.CashierId == actor && x.ClosedAt == null, ct);
        InternalCashTillBalance? own = null;
        if (till is not null)
        {
            if (!await access.CanAccessLocation(actor, till.LocationId, ct)) return InternalResult<InternalCashContext>.Fail("forbidden");
            own = new(till, await Balance(till.Id, ct));
        }
        var locations = access.Locations(actor);
        var last = await (from close in db.Set<InternalCashClose>().AsNoTracking()
            join closed in db.Set<InternalCashTill>().AsNoTracking() on close.TillId equals closed.Id
            where closed.CashierId == actor && locations.Any(l => l.Id == closed.LocationId)
            orderby close.CreatedAt descending, close.Id
            select new InternalCashCloseReceipt(closed, close)).FirstOrDefaultAsync(ct);
        return InternalResult<InternalCashContext>.Ok(new(options.Valid ? new(options.Currency, options.Exponent) : null, own, last));
    }

    public async Task<InternalResult<InternalCashRefundContext>> RefundContext(Guid saleId, int skip, int take,
        ClaimsPrincipal principal, CancellationToken ct)
    {
        if (saleId == Guid.Empty || !InternalCommerceService.ValidPage(skip, take, 50))
            return InternalResult<InternalCashRefundContext>.Fail("invalid_request");
        await using var transaction = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable, ct);
        var current = await security.ValidateSession(principal, ct);
        if (current is null) return InternalResult<InternalCashRefundContext>.Fail("unauthenticated");
        if (!InternalCommandAuthorization.Allowed(current, "cash.refund")) return InternalResult<InternalCashRefundContext>.Fail("forbidden");
        var sale = await commerce.Sale(saleId, ct, InternalActor.Id(current));
        if (sale is null) return InternalResult<InternalCashRefundContext>.Fail("sale_not_found");
        var payment = await db.Set<InternalCashEntry>().AsNoTracking().SingleOrDefaultAsync(x => x.SaleId == saleId && x.Kind == "sale", ct);
        if (payment is null) return InternalResult<InternalCashRefundContext>.Fail("cash_payment_required");
        if (!InternalCashRules.Amount(payment.DeltaMinor) || payment.DeltaMinor != sale.TotalMinor
            || payment.Currency != sale.Currency || payment.Exponent is < 0 or > 6)
            throw new InvalidOperationException("Persisted cash payment is inconsistent.");
        var refunds = await db.Set<InternalCashEntry>().AsNoTracking().Where(x => x.SaleId == saleId && x.Kind == "refund")
            .Select(x => x.DeltaMinor).ToListAsync(ct);
        var refunded = 0L;
        foreach (var delta in refunds)
        {
            if (delta >= 0 || delta < -InternalRules.MaxMinor || refunded > payment.DeltaMinor + delta)
                throw new InvalidOperationException("Persisted cash refunds are out of range.");
            refunded -= delta;
        }
        var remaining = payment.DeltaMinor - refunded;
        if (!InternalCashRules.Amount(remaining))
            throw new InvalidOperationException("Persisted cash payment is inconsistent.");
        var candidates = await EligiblePayingTills(db.Set<InternalCashTill>().AsNoTracking(), db.InternalStaff.AsNoTracking(),
            db.InternalLocations.AsNoTracking(), db.Set<InternalBranch>().AsNoTracking(), sale.LocationId, payment.Currency, payment.Exponent)
            .OrderBy(x => x.OpenedAt).ThenBy(x => x.Id).Skip(skip).Take(take + 1).ToListAsync(ct);
        var items = new List<InternalCashTillBalance>();
        foreach (var candidate in candidates.Take(take)) items.Add(new(candidate, await Balance(candidate.Id, ct)));
        return InternalResult<InternalCashRefundContext>.Ok(new(sale, payment, refunded, remaining,
            refunded == 0 ? "paid" : remaining == 0 ? "refunded" : "partially_refunded",
            new(items, skip, take, candidates.Count > take)));
    }

    // Shared query is exercised with adversarial rows and with SQL translation, without connecting.
    public static IQueryable<InternalCashTill> EligiblePayingTills(IQueryable<InternalCashTill> tills,
        IQueryable<InternalStaff> staff, IQueryable<InternalLocation> locations, IQueryable<InternalBranch> branches,
        Guid locationId, string currency, int exponent) => tills.Where(t => t.ClosedAt == null
            && t.LocationId == locationId && t.Currency == currency && t.Exponent == exponent
            && staff.Any(s => s.Id == t.CashierId && s.Enabled && (s.Role == "Owner"
                || ((s.Role == "Manager" || s.Role == "Cashier") && s.BranchId != null
                    && branches.Any(b => b.Id == s.BranchId && b.Active)
                    && locations.Any(l => l.Id == t.LocationId && l.BranchId == s.BranchId)))));

    private async Task<long> Balance(Guid tillId, CancellationToken ct)
    {
        var deltas = await db.Set<InternalCashEntry>().AsNoTracking().Where(x => x.TillId == tillId).Select(x => x.DeltaMinor).ToListAsync(ct);
        if (!InternalCashRules.TryBalance(deltas, out var balance)) throw new InvalidOperationException("Persisted cash balance is out of range.");
        return balance;
    }
}
