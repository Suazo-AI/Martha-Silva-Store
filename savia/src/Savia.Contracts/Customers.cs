namespace Savia.Contracts;

public sealed record CustomerRow(Guid CustomerId, string? CustomerCode, string DisplayName, string? Phone, string? Email);
public sealed record CustomerCreditRow(Guid CustomerId, string DisplayName, string? Phone, string? Email, Guid CreditId,
    string CurrencyCode, Guid BranchId, string BranchName, long AvailableMinor);
