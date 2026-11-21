using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Martha.Store.Api.Internal;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;
using System.Text.RegularExpressions;
using Xunit;

namespace Martha.Store.Api.Tests;

// Independent reviewed cash delta. The November 3 model-derived baseline stays historical and immutable.
internal static class InternalCashSchemaOracle
{
    internal const string Migration = "20261107221938_FirstCashRegister";
    internal static readonly string[] History = ["20261025085402_InitialInternalSavia", "20261027224500_InternalBranchScope", "20261106071201_PhysicalStockException", Migration];
    internal static readonly string[] Tables = ["CashCloses", "CashEntries", "CashTills"];
    internal static readonly string[] Checks = ["CK_CashClose_Amounts", "CK_CashEntry_Bounds", "CK_CashEntry_Kind", "CK_CashTill_Currency", "CK_CashTill_Time"];
    internal static readonly string[] ForeignKeys = ["FK_CashCloses_CashTills_TillId", "FK_CashCloses_Staff_ActorId", "FK_CashEntries_CashTills_TillId_CashierId_Currency_Exponent", "FK_CashEntries_SaleReversals_ReversalId", "FK_CashEntries_Sales_SaleId", "FK_CashEntries_Staff_ActorId", "FK_CashTills_Locations_LocationId", "FK_CashTills_Staff_CashierId"];
    internal static readonly string[] Indexes = ["AK_CashTills_Id_CashierId_Currency_Exponent", "IX_CashCloses_ActorId", "IX_CashCloses_TillId", "IX_CashEntries_ActorId", "IX_CashEntries_ReversalId", "IX_CashEntries_SaleId", "IX_CashEntries_TillId", "IX_CashEntries_TillId_CashierId_Currency_Exponent", "IX_CashTills_CashierId", "IX_CashTills_LocationId"];
    internal static IEnumerable<string?> Expected(IEnumerable<string?> baseline, string key) => InternalStockExceptionTests.Expected(baseline, key).Concat(key switch {
        "history" => [Migration], "tables" => Tables, "checks" => Checks, "foreign_keys" => ForeignKeys,
        "indexes" => Indexes, "primary_keys" => ["PK_CashCloses", "PK_CashEntries", "PK_CashTills"], _ => [] });

    internal static void AssertNames(SortedDictionary<string, string[]> facts, JsonElement baseline)
    {
        foreach (var key in new[] { "history", "tables", "checks", "foreign_keys", "indexes", "primary_keys" })
            Assert.Equal(Expected(baseline.GetProperty(key).EnumerateArray().Select(x => x.GetString()), key).OrderBy(x => x, StringComparer.Ordinal), facts[key].OrderBy(x => x, StringComparer.Ordinal));
        Assert.Equal(History, facts["history"]);
        Assert.Equal(23, facts["tables"].Length);
        Assert.Equal(20, facts["tables"].Count(x => x is not ("Staff" or "Sessions" or "BranchAssignmentAudit")));
        Assert.Equal(facts["tables"].Select(x => "savia_internal." + x).Append("dbo.__EFMigrationsHistory").OrderBy(x => x, StringComparer.Ordinal), facts["all_tables"].OrderBy(x => x, StringComparer.Ordinal));
        Assert.Equal(24, facts["all_tables"].Length);
    }

    // table|column|SQL type|max bytes|nullable|identity, independent of EF at runtime.
    internal static readonly string[] Columns = """
CashTills|Id|uniqueidentifier|16|False|False
CashTills|CashierId|uniqueidentifier|16|False|False
CashTills|LocationId|uniqueidentifier|16|False|False
CashTills|Currency|varchar|3|False|False
CashTills|Exponent|int|4|False|False
CashTills|OpenedAt|datetimeoffset|10|False|False
CashTills|ClosedAt|datetimeoffset|10|True|False
CashCloses|Id|uniqueidentifier|16|False|False
CashCloses|TillId|uniqueidentifier|16|False|False
CashCloses|ActorId|uniqueidentifier|16|False|False
CashCloses|ExpectedMinor|bigint|8|False|False
CashCloses|CountedMinor|bigint|8|False|False
CashCloses|DifferenceMinor|bigint|8|False|False
CashCloses|CreatedAt|datetimeoffset|10|False|False
CashEntries|Id|uniqueidentifier|16|False|False
CashEntries|TillId|uniqueidentifier|16|False|False
CashEntries|CashierId|uniqueidentifier|16|False|False
CashEntries|ActorId|uniqueidentifier|16|False|False
CashEntries|Currency|varchar|3|False|False
CashEntries|Exponent|int|4|False|False
CashEntries|Kind|varchar|16|False|False
CashEntries|DeltaMinor|bigint|8|False|False
CashEntries|ReceivedMinor|bigint|8|False|False
CashEntries|ChangeMinor|bigint|8|False|False
CashEntries|SaleId|uniqueidentifier|16|True|False
CashEntries|ReversalId|uniqueidentifier|16|True|False
CashEntries|CreatedAt|datetimeoffset|10|False|False
""".Split('\n', StringSplitOptions.TrimEntries);
    internal static void AssertColumns(IEnumerable<string> actual) => Assert.Equal(Columns.OrderBy(x => x, StringComparer.Ordinal), actual.Where(x => Tables.Contains(x.Split('|')[0])).OrderBy(x => x, StringComparer.Ordinal));

    // Exact cash index/key and FK column bindings. Names alone cannot detect a weakened constraint.
    internal static readonly string[] IndexShape = """
CashCloses|IX_CashCloses_ActorId|False|ActorId|1|False|
CashCloses|IX_CashCloses_TillId|True|TillId|1|False|
CashCloses|PK_CashCloses|True|Id|1|False|
CashEntries|IX_CashEntries_ActorId|False|ActorId|1|False|
CashEntries|IX_CashEntries_ReversalId|True|ReversalId|1|False|[ReversalId] IS NOT NULL
CashEntries|IX_CashEntries_SaleId|True|SaleId|1|False|[Kind]='sale'
CashEntries|IX_CashEntries_TillId|True|TillId|1|False|[Kind]='opening'
CashEntries|IX_CashEntries_TillId_CashierId_Currency_Exponent|False|TillId|1|False|
CashEntries|IX_CashEntries_TillId_CashierId_Currency_Exponent|False|CashierId|2|False|
CashEntries|IX_CashEntries_TillId_CashierId_Currency_Exponent|False|Currency|3|False|
CashEntries|IX_CashEntries_TillId_CashierId_Currency_Exponent|False|Exponent|4|False|
CashEntries|PK_CashEntries|True|Id|1|False|
CashTills|AK_CashTills_Id_CashierId_Currency_Exponent|True|Id|1|False|
CashTills|AK_CashTills_Id_CashierId_Currency_Exponent|True|CashierId|2|False|
CashTills|AK_CashTills_Id_CashierId_Currency_Exponent|True|Currency|3|False|
CashTills|AK_CashTills_Id_CashierId_Currency_Exponent|True|Exponent|4|False|
CashTills|IX_CashTills_CashierId|True|CashierId|1|False|[ClosedAt] IS NULL
CashTills|IX_CashTills_LocationId|False|LocationId|1|False|
CashTills|PK_CashTills|True|Id|1|False|
""".Split('\n', StringSplitOptions.TrimEntries);
    internal static readonly string[] ForeignKeyShape = """
FK_CashCloses_CashTills_TillId|TillId|savia_internal|CashTills|Id|1|0
FK_CashCloses_Staff_ActorId|ActorId|savia_internal|Staff|Id|1|0
FK_CashEntries_CashTills_TillId_CashierId_Currency_Exponent|TillId|savia_internal|CashTills|Id|1|0
FK_CashEntries_CashTills_TillId_CashierId_Currency_Exponent|CashierId|savia_internal|CashTills|CashierId|2|0
FK_CashEntries_CashTills_TillId_CashierId_Currency_Exponent|Currency|savia_internal|CashTills|Currency|3|0
FK_CashEntries_CashTills_TillId_CashierId_Currency_Exponent|Exponent|savia_internal|CashTills|Exponent|4|0
FK_CashEntries_SaleReversals_ReversalId|ReversalId|savia_internal|SaleReversals|Id|1|0
FK_CashEntries_Sales_SaleId|SaleId|savia_internal|Sales|Id|1|0
FK_CashEntries_Staff_ActorId|ActorId|savia_internal|Staff|Id|1|0
FK_CashTills_Locations_LocationId|LocationId|savia_internal|Locations|Id|1|0
FK_CashTills_Staff_CashierId|CashierId|savia_internal|Staff|Id|1|0
""".Split('\n', StringSplitOptions.TrimEntries);
    internal static readonly string[] CheckShape = """
CK_CashTill_Currency|LEN([Currency])=3 AND [Currency] COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^A-Z]%' AND [Exponent] BETWEEN 0 AND 6
CK_CashTill_Time|[ClosedAt] IS NULL OR [ClosedAt]>=[OpenedAt]
CK_CashEntry_Bounds|[DeltaMinor] BETWEEN -9000000000000 AND 9000000000000 AND [ReceivedMinor] BETWEEN 0 AND 9000000000000 AND [ChangeMinor] BETWEEN 0 AND 9000000000000
CK_CashEntry_Kind|([Kind]='opening' AND [DeltaMinor]>=0 AND [ReceivedMinor]=0 AND [ChangeMinor]=0 AND [SaleId] IS NULL AND [ReversalId] IS NULL) OR ([Kind]='sale' AND [DeltaMinor]>=0 AND [ReceivedMinor]-[ChangeMinor]=[DeltaMinor] AND [SaleId] IS NOT NULL AND [ReversalId] IS NULL) OR ([Kind]='refund' AND [DeltaMinor]<0 AND [ReceivedMinor]=0 AND [ChangeMinor]=0 AND [SaleId] IS NOT NULL AND [ReversalId] IS NOT NULL)
CK_CashClose_Amounts|[ExpectedMinor] BETWEEN 0 AND 9000000000000 AND [CountedMinor] BETWEEN 0 AND 9000000000000 AND [DifferenceMinor]=[CountedMinor]-[ExpectedMinor]
""".Split('\n', StringSplitOptions.TrimEntries);
    // SQL Server expands BETWEEN and adds redundant parentheses. Preserve expression meaning and quoted values.
    internal static string Canonical(string row)
    {
        var fields = row.Split('|');
        var expression = fields.Length == 2 && fields[0].StartsWith("CK_", StringComparison.Ordinal) ? 1
            : fields.Length == 7 && fields[1].StartsWith("IX_", StringComparison.Ordinal) && fields[6].Length > 0 ? 6 : -1;
        return string.Join('|', fields.Select((field, index) => index == expression
            ? new CheckExpression(field).Parse() : Regex.Replace(field, @"[\[\]\s]", "").ToLowerInvariant()));
    }

    // Deliberately limited to the reviewed constraint grammar; unknown SQL fails closed.
    private sealed class CheckExpression
    {
        private readonly string[] tokens;
        private int at;
        internal CheckExpression(string expression)
        {
            expression = Regex.Replace(expression, @"(\[[A-Za-z]+\]) BETWEEN (-?\d+) AND (-?\d+)", "$1 >= $2 AND $1 <= $3", RegexOptions.IgnoreCase);
            var matches = Regex.Matches(expression, @"\s+|\[[^\]]+\]|'(?:[^']|'')*'|\d+\.?|[A-Za-z_][A-Za-z_0-9]*|>=|<=|<>|!=|[=<>+\-(),]");
            if (string.Concat(matches.Select(x => x.Value)) != expression) throw new FormatException("Unsupported cash constraint token.");
            tokens = matches.Select(x => x.Value).Where(x => !string.IsNullOrWhiteSpace(x))
                .Select(x => x.StartsWith('\'') ? x : Regex.IsMatch(x, @"\A\d+\.\z")
                    ? x[..^1] : x.Trim('[', ']').ToLowerInvariant()).ToArray();
        }
        private string? Peek => at < tokens.Length ? tokens[at] : null;
        private string Take() => at < tokens.Length ? tokens[at++] : throw new FormatException("Incomplete cash constraint.");
        private void Require(string token)
        {
            if (Take() != token) throw new FormatException("Unexpected cash constraint token.");
        }
        internal string Parse()
        {
            var result = Expression(1);
            if (at != tokens.Length) throw new FormatException("Trailing cash constraint tokens.");
            return result.Render();
        }
        private sealed record Node(string Value, params Node[] Children)
        {
            internal string Render() => Children.Length == 0 ? Value
                : Value + "(" + string.Join(',', (Value is "and" or "or" ? Flatten(Value) : Children).Select(x => x.Render())) + ")";
            private IEnumerable<Node> Flatten(string op) => Children.SelectMany(x => x.Value == op ? x.Flatten(op) : [x]);
        }
        private Node Expression(int minimum)
        {
            var token = Take();
            Node left;
            if (token == "(") { left = Expression(1); Require(")"); }
            else if (token == "-") left = new("neg", Expression(6));
            else if (token == "not")
            {
                var operand = Expression(3);
                if (operand.Value != "like") throw new FormatException("Unsupported cash constraint negation.");
                left = new("notlike", operand.Children);
            }
            else if (token == "len") { Require("("); left = new("len", Expression(1)); Require(")"); }
            else if (token.StartsWith('\'') || Regex.IsMatch(token, @"\A(?:[a-z_][a-z_0-9]*|\d+)\z")) left = new(token);
            else throw new FormatException("Unsupported cash constraint operand.");
            while (true)
            {
                var precedence = Peek switch
                {
                    "or" => 1, "and" => 2,
                    "=" or ">=" or "<=" or "<>" or "!=" or ">" or "<" or "is" or "not" or "like" => 3,
                    "+" or "-" => 4, "collate" => 5, _ => 0
                };
                if (precedence < minimum) return left;
                var op = Take();
                if (op == "is")
                {
                    if (Peek == "not") { Take(); op = "isnotnull"; }
                    else op = "isnull";
                    Require("null"); left = new(op, left); continue;
                }
                if (op == "not") { Require("like"); op = "notlike"; }
                var right = Expression(precedence + 1);
                left = new(op, left, right);
            }
        }
    }
    internal static void AssertShape(IEnumerable<string> expected, IEnumerable<string> actual) =>
        Assert.Equal(expected.Select(Canonical).OrderBy(x => x, StringComparer.Ordinal), actual.Select(Canonical).OrderBy(x => x, StringComparer.Ordinal));
    internal static void AssertCash(SortedDictionary<string, string[]> facts)
    {
        AssertColumns(facts["columns"]);
        AssertShape(IndexShape, facts["cash_indexes"]);
        AssertShape(ForeignKeyShape, facts["cash_foreign_keys"]);
        AssertShape(CheckShape, facts["check_definitions"].Where(x => Checks.Contains(x.Split('|')[0])));
        Assert.Equal(new[] { "CashEntries|Currency|Latin1_General_100_BIN2", "CashTills|Currency|Latin1_General_100_BIN2" }, facts["cash_collations"]);
    }
}

// Removes only the independently identified cash insertion. Every other cash row stays in the fingerprint.
internal static class InternalCashWriteProjection
{
    internal static IReadOnlyDictionary<string, object>? Apply(string table, IReadOnlyDictionary<string, object> row, Guid entry) =>
        entry != Guid.Empty && table == "CashEntries" && (Guid)row["Id"] == entry ? null : row;
}

// Historical recorded-key fixture only. Never used for fresh cash sale success controls.
internal static class InternalLegacySaleFixture
{
    internal static async Task<InternalSaleReceipt> Seed(InternalDbContext db, Guid actor, Guid? branch, InternalSaleRequest request, string key)
    {
        var at = new DateTimeOffset(2026, 10, 27, 1, 0, 0, TimeSpan.Zero);
        var sale = new InternalSale { Id = Guid.NewGuid(), LocationId = request.LocationId, CustomerId = request.CustomerId,
            ActorId = actor, Currency = "USD", CreatedAt = at };
        var operation = Guid.NewGuid();
        foreach (var line in request.Lines!)
        {
            var item = await db.Set<InternalItem>().SingleAsync(x => x.Id == line.ItemId);
            var total = checked(item.UnitPriceMinor * line.Quantity);
            sale.Lines.Add(new() { Id = Guid.NewGuid(), SaleId = sale.Id, ItemId = item.Id, Sku = item.Sku, Name = item.Name,
                Quantity = line.Quantity, UnitPriceMinor = item.UnitPriceMinor, TotalMinor = total, ExceptionReason = line.ExceptionReason, Size = line.Size });
            sale.TotalMinor = checked(sale.TotalMinor + total);
            if (line.ExceptionReason is null)
            {
                var balance = await db.Set<InternalStockBalance>().SingleAsync(x => x.ItemId == item.Id && x.LocationId == request.LocationId);
                balance.OnHand -= line.Quantity; balance.UpdatedAt = at;
                db.Add(new InternalStockMovement { Id = Guid.NewGuid(), ItemId = item.Id, LocationId = request.LocationId,
                    ActorId = actor, OperationId = sale.Id, Kind = "sale", OnHandDelta = -line.Quantity,
                    OnHandAfter = balance.OnHand, ReservedAfter = balance.Reserved, CreatedAt = at });
            }
        }
        var receipt = new InternalSaleReceipt(sale.Id, sale.LocationId, sale.CustomerId, actor, sale.Currency, sale.TotalMinor,
            "recorded", "not_processed", at, sale.Lines.Select(x => new InternalSaleLineReceipt(x.Id,x.ItemId,x.Sku,x.Name,x.Quantity,0,x.UnitPriceMinor,x.TotalMinor,x.ExceptionReason,x.Size)).ToArray());
        db.Add(sale);
        db.Add(new InternalOperation { Id = operation, ActorId = actor, Scope = "commerce.sale.record", Key = key,
            Fingerprint = InternalRules.Fingerprint(request), LocationId = request.LocationId, OriginalBranchId = branch,
            ResultJson = JsonSerializer.Serialize(InternalResult<InternalSaleReceipt>.Ok(receipt), new JsonSerializerOptions(JsonSerializerDefaults.Web)), CreatedAt = at });
        await db.SaveChangesAsync(); return receipt;
    }
}

internal static class InternalCashFixture
{
    internal static async Task<T> Run<T>(InternalCommerceSqlDatabase f, Func<InternalCashService, Task<T>> action)
    {
        await using var db = f.Context();
        var commands = new InternalCommandRunner(db, new InternalSecurityService(db, new PasswordHasher<InternalStaff>(), TimeProvider.System),
            new HttpContextAccessor { HttpContext = new DefaultHttpContext { User = InternalSecurityRules.Principal(f.Staff, f.Session) } }, TimeProvider.System);
        return await action(new InternalCashService(db, commands, new InternalCommerceService(db, commands, new InternalStockLedger(db)), new("USD", 2), TimeProvider.System));
    }
    internal static async Task<Guid> Open(InternalCommerceSqlDatabase f)
    {
        var r = await Run(f, s => s.Open(new(f.Location, "USD", 0), f.Actor, "fixture-open-" + Guid.NewGuid().ToString("N"), default));
        Assert.True(r.Success, r.Error); Assert.Equal(2, r.Value!.Till.Exponent); return r.Value.Till.Id;
    }
    internal static async Task<InternalResult<InternalSaleReceipt>> Sell(InternalCommerceSqlDatabase f, Guid till, InternalSaleRequest request, string key)
    {
        var result = await Run(f, s => s.Sell(new(till, request.CustomerId, request.Lines, "USD", 10000), f.Actor, key, default));
        if (!result.Success) return InternalResult<InternalSaleReceipt>.Fail(result.Error!);
        var paid = result.Value!;
        Assert.Equal("paid", paid.PaymentStatus); Assert.Equal("USD", paid.Payment.Currency); Assert.Equal(2, paid.Exponent);
        Assert.Equal(10000L, paid.Payment.ReceivedMinor);
        Assert.Equal(paid.Sale.TotalMinor, checked(paid.Payment.ReceivedMinor - paid.Payment.ChangeMinor));
        return InternalResult<InternalSaleReceipt>.Ok(paid.Sale);
    }
    internal static async Task<InternalResult<InternalSaleReversalReceipt>> Refund(InternalCommerceSqlDatabase f, Guid till, Guid sale,
        InternalSaleReturnRequest request, string key)
    {
        var r = await Run(f, s => s.Refund(sale, new(till, "USD", request.Reason, request.Lines), f.Actor, key, default));
        return r.Success ? InternalResult<InternalSaleReversalReceipt>.Ok(r.Value!.Reversal) : InternalResult<InternalSaleReversalReceipt>.Fail(r.Error!);
    }
}
