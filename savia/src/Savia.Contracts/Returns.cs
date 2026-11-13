namespace Savia.Contracts;

public sealed record ReturnLine(Guid SaleLineId, int Quantity, string RestockPool);
public sealed record PostCreditReturnRequest(Guid ReversalId, Guid CreditId, Guid TillId, Guid CustomerId, string Reason, ReturnLine[] Lines);
/// <summary>Cash refund, bank transfer refund or exchange. Store credit keeps <see cref="PostCreditReturnRequest"/>.</summary>
public sealed record PostReturnOutcomeRequest(Guid ReversalId, string Outcome, Guid TillId, string Reason, ReturnLine[] Lines,
    string? Reference = null, Guid? ExchangeSaleId = null, SaleLine[]? NewLines = null, SaleTender[]? NewTenders = null,
    string? DifferenceKind = null, string? DifferenceReference = null);
public sealed record ReturnWindowRequest(Guid ChangeId, int WindowDays, string Reason);
