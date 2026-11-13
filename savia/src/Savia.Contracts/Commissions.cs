namespace Savia.Contracts;

public sealed record SellerRateRequest(Guid ChangeId, int RateBps, string Reason);
