namespace Savia.Contracts;

public sealed record OpenTillRequest(Guid TillId, Guid RegisterId, string CurrencyCode, long OpeningMinor, CashCountLine[]? Lines = null,
    CashCountLine[]? UsdLines = null);
public sealed record CashCountLine(long DenominationMinor, int Quantity);
public sealed record RecordCashCountRequest(Guid CashCountId, CashCountLine[] Lines,
    Guid? UsdCashCountId = null, CashCountLine[]? UsdLines = null);
public sealed record CloseTillRequest(Guid ClosureId, Guid CashCountId, Guid? UsdCashCountId = null);
public sealed record CloseTillResponse(Guid ClosureId, long ExpectedMinor, long CountedMinor, long DifferenceMinor,
    long? UsdExpectedMinor = null, long? UsdCountedMinor = null, long? UsdDifferenceMinor = null);
public sealed record RegisterRow(Guid RegisterId, string Code, string Name, Guid LocationId, Guid? OpenTillId, Guid? OpenTillCashierId);
/// <summary>Cash of one till. ExpectedCashMinor is the sum of its cash entries, the same figure the close uses.</summary>
public sealed record TillSummary(Guid TillId, Guid RegisterId, string RegisterName, Guid CashierId, string CashierName, string Status,
    string CurrencyCode, DateTimeOffset OpenedAt, long OpeningMinor, long CashSalesMinor, long CashRefundsMinor, long OtherCashMinor,
    long ExpectedCashMinor, int SaleCount, long SalesTotalMinor, Guid? ClosureId, CashCountLine[]? OpeningLines = null, long? UsdExpectedMinor = null);
