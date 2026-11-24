namespace Savia.Contracts;

public sealed record CustomerRow(Guid CustomerId, string? CustomerCode, string DisplayName, string? Phone, string? Email);
public sealed record CreateCustomerRequest(Guid CustomerId, string DisplayName, string? DocumentNumber, string? Phone, string? Email);
public sealed record CustomerCreditRow(Guid CustomerId, string DisplayName, string? Phone, string? Email, Guid CreditId,
    string CurrencyCode, Guid BranchId, string BranchName, long AvailableMinor);
public sealed record RequestCreditTransferRequest(Guid TransferId, Guid CreditId, Guid FromBranchId, Guid ToBranchId, long AmountMinor,
    string Reason);
public sealed record CancelCreditTransferRequest(string Reason);
public sealed record CreditTransferRow(Guid TransferId, Guid CreditId, string CustomerName, Guid FromBranchId, string FromBranchName,
    Guid ToBranchId, string ToBranchName, long AmountMinor, string CurrencyCode, string Status, string Reason, DateTimeOffset RequestedAt);
