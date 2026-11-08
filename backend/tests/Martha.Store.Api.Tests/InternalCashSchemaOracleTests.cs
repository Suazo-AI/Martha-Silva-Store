using Martha.Store.Api.Internal;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using System.Text.Json;
using Xunit;

namespace Martha.Store.Api.Tests;
public sealed class InternalCashSchemaOracleTests
{
    private static SortedDictionary<string, string[]> Facts()
    {
        using var doc = JsonDocument.Parse(File.ReadAllText(InternalReleaseScriptTests.RepositoryFile("backend/tests/fixtures/expected-invariants.model-derived.json")));
        var result = new SortedDictionary<string, string[]>();
        foreach (var key in new[] { "history", "tables", "checks", "foreign_keys", "indexes", "primary_keys" })
            result[key] = InternalCashSchemaOracle.Expected(doc.RootElement.GetProperty(key).EnumerateArray().Select(x => x.GetString()), key).Select(x => x!).OrderBy(x => x, StringComparer.Ordinal).ToArray();
        result["all_tables"] = result["tables"].Select(x => "savia_internal." + x).Append("dbo.__EFMigrationsHistory").ToArray();
        return result;
    }
    private static void Check(SortedDictionary<string, string[]> facts)
    {
        using var doc = JsonDocument.Parse(File.ReadAllText(InternalReleaseScriptTests.RepositoryFile("backend/tests/fixtures/expected-invariants.model-derived.json")));
        InternalCashSchemaOracle.AssertNames(facts, doc.RootElement);
    }
    [Fact] public void Explicit_current_schema_composes_historical_baseline_and_stock_delta() => Check(Facts());
    [Theory]
    [InlineData("tables", "CashEntries")]
    [InlineData("history", "20261107221938_FirstCashRegister")]
    [InlineData("foreign_keys", "FK_CashEntries_Sales_SaleId")]
    [InlineData("indexes", "IX_CashEntries_SaleId")]
    [InlineData("checks", "CK_CashEntry_Kind")]
    [InlineData("primary_keys", "PK_CashTills")]
    public void Missing_schema_fact_is_rejected(string key, string value)
    {
        var facts = Facts(); facts[key] = facts[key].Where(x => x != value).ToArray();
        Assert.ThrowsAny<Exception>(() => Check(facts));
    }
    [Fact] public void Unexpected_table_is_rejected()
    {
        var facts = Facts(); facts["tables"] = [..facts["tables"], "UnreviewedCash"];
        Assert.ThrowsAny<Exception>(() => Check(facts));
    }
    [Theory] [InlineData("bigint|8", "int|4")] [InlineData("False|False", "True|False")]
    public void Wrong_cash_column_shape_is_rejected(string from, string to)
    {
        var columns = InternalCashSchemaOracle.Columns.ToArray();
        columns[10] = columns[10].Replace(from, to);
        Assert.ThrowsAny<Exception>(() => InternalCashSchemaOracle.AssertColumns(columns));
    }
    [Fact] public void Missing_and_unexpected_cash_columns_are_rejected()
    {
        Assert.ThrowsAny<Exception>(() => InternalCashSchemaOracle.AssertColumns(InternalCashSchemaOracle.Columns.Skip(1)));
        Assert.ThrowsAny<Exception>(() => InternalCashSchemaOracle.AssertColumns(InternalCashSchemaOracle.Columns.Append("CashEntries|Unreviewed|int|4|False|False")));
    }
    [Theory] [InlineData("filter")] [InlineData("unique")] [InlineData("fk")]
    public void Wrong_cash_key_or_index_binding_is_rejected(string mutation)
    {
        var expected = mutation == "fk" ? InternalCashSchemaOracle.ForeignKeyShape : InternalCashSchemaOracle.IndexShape;
        var actual = expected.ToArray();
        if (mutation == "fk") actual[0] = actual[0].Replace("|TillId|", "|ActorId|");
        if (mutation == "unique") actual[1] = actual[1].Replace("|True|", "|False|");
        if (mutation == "filter") actual[5] = actual[5].Replace("[Kind]='sale'", "[Kind]='refund'");
        Assert.ThrowsAny<Exception>(() => InternalCashSchemaOracle.AssertShape(expected, actual));
    }
    [Theory] [InlineData("grouping")] [InlineData("literal")]
    public void Changed_cash_check_meaning_is_rejected(string mutation)
    {
        var expected = InternalCashSchemaOracle.CheckShape;
        var actual = expected.ToArray();
        var index = Array.FindIndex(actual, x => x.StartsWith("CK_CashEntry_Kind|", StringComparison.Ordinal));
        if (mutation == "literal") actual[index] = actual[index].Replace("'sale'", "'s ale'");
        else
        {
            var parts = actual[index].Split('|', 2);
            var expression = parts[1].Replace("(", "").Replace(")", "");
            var boundary = expression.IndexOf(" AND ", expression.IndexOf(" OR ", StringComparison.Ordinal) + 4, StringComparison.Ordinal);
            actual[index] = parts[0] + "|(" + expression[..boundary] + ")" + expression[boundary..];
        }
        Assert.ThrowsAny<Exception>(() => InternalCashSchemaOracle.AssertShape(expected, actual));
    }

    [Fact] public void Sql_server_formatting_preserves_the_reviewed_expression()
    {
        string[] expected = ["CK_Test|[Amount] BETWEEN -10 AND 10 AND [Received]-[Change]=[Amount] AND [Kind]='s ale'"];
        string[] actual = ["CK_Test|(([Amount]>=(-10) AND [Amount]<=(10)) AND (([Received]-[Change])=[Amount]) AND [Kind]='s ale')"];
        InternalCashSchemaOracle.AssertShape(expected, actual);
        InternalCashSchemaOracle.AssertShape(expected, ["CK_Test|[Amount]>=-10 AND ([Amount]<=10 AND ([Received]-[Change]=[Amount] AND [Kind]='s ale'))"]);
        Assert.Throws<FormatException>(() => InternalCashSchemaOracle.Canonical("CK_Test|[Amount]*2=4"));
    }

    [Fact] public void Weakened_cash_check_is_rejected()
    {
        var actual = InternalCashSchemaOracle.CheckShape.ToArray(); actual[1] = "CK_CashTill_Time|1=1";
        Assert.ThrowsAny<Exception>(() => InternalCashSchemaOracle.AssertShape(InternalCashSchemaOracle.CheckShape, actual));
    }

    public static IEnumerable<object[]> CapturedCashChecks()
    {
        var path = InternalReleaseScriptTests.RepositoryFile("backend/tests/fixtures/cash-checks.sqlserver2022.json");
        return JsonSerializer.Deserialize<string[]>(File.ReadAllText(path))!.Select(x => new object[] { x });
    }

    [Theory] [MemberData(nameof(CapturedCashChecks))]
    public void Captured_sql_server_cash_check_matches_reviewed_meaning(string actual)
    {
        var name = actual.Split('|')[0];
        var expected = InternalCashSchemaOracle.CheckShape.Single(x => x.StartsWith(name + "|", StringComparison.Ordinal));
        InternalCashSchemaOracle.AssertShape([expected], [actual]);
    }

    [Theory]
    [InlineData("9000000000000.", "9000000000001.")]
    [InlineData("NOT ([Currency])", "([Currency])")]
    [InlineData("Latin1_General_100_BIN2", "Latin1_General_100_CI_AS")]
    [InlineData("'sale'", "'s ale'")]
    public void Changed_captured_sql_meaning_is_rejected(string from, string to)
    {
        var rows = CapturedCashChecks().Select(x => (string)x[0]).Where(x => x.Contains(from, StringComparison.Ordinal)).ToArray();
        Assert.NotEmpty(rows);
        foreach (var row in rows)
        {
            var name = row.Split('|')[0];
            var expected = InternalCashSchemaOracle.CheckShape.Single(x => x.StartsWith(name + "|", StringComparison.Ordinal));
            Assert.Throws<Xunit.Sdk.EqualException>(() => InternalCashSchemaOracle.AssertShape([expected], [row.Replace(from, to)]));
        }
    }

    [Theory] [InlineData("1.5")] [InlineData(".5")] [InlineData("1e2")] [InlineData("1..")]
    public void Unreviewed_numeric_forms_fail_closed(string number) =>
        Assert.Throws<FormatException>(() => InternalCashSchemaOracle.Canonical("CK_Test|[Amount]=" + number));
    [Fact] public void Cash_projection_removes_only_exact_payment_and_keeps_other_rows_and_tables()
    {
        var id = Guid.NewGuid(); var row = new Dictionary<string, object> { ["Id"] = id, ["DeltaMinor"] = 125L };
        Assert.Null(InternalCashWriteProjection.Apply("CashEntries", row, id));
        Assert.Same(row, InternalCashWriteProjection.Apply("CashEntries", row, Guid.NewGuid()));
        Assert.Same(row, InternalCashWriteProjection.Apply("CashEntries", row, Guid.Empty));
        Assert.Same(row, InternalCashWriteProjection.Apply("CashTills", row, id));
        Assert.Same(row, InternalCashWriteProjection.Apply("CashCloses", row, id));
    }
    [Fact] public void Actual_current_model_cash_shape_matches_independent_reviewed_contract()
    {
        using var db = new InternalDbContextFactory().CreateDbContext([]);
        var model = db.GetService<IDesignTimeModel>().Model;
        InternalAcceptanceFingerprint.AssertTables(model.GetEntityTypes().Select(x => x.GetTableName()!));
        var cash = model.GetEntityTypes().Where(x => InternalCashSchemaOracle.Tables.Contains(x.GetTableName())).ToArray();
        var columns = new List<string>(); var indexes = new List<string>(); var foreign = new List<string>(); var checks = new List<string>();
        foreach (var entity in cash)
        {
            var table = entity.GetTableName()!; var store = StoreObjectIdentifier.Table(table, "savia_internal");
            foreach (var col in entity.GetProperties())
            {
                var type = col.GetColumnType()!; var bare = type.Split('(')[0];
                var length = bare switch { "uniqueidentifier" => 16, "int" => 4, "bigint" => 8, "datetimeoffset" => 10, "varchar" => col.GetMaxLength()!.Value, _ => throw new InvalidOperationException(type) };
                columns.Add($"{table}|{col.GetColumnName(store)}|{bare}|{length}|{col.IsNullable}|{col.GetValueGenerationStrategy() == SqlServerValueGenerationStrategy.IdentityColumn}");
            }
            foreach (var index in entity.GetIndexes())
                for (var n = 0; n < index.Properties.Count; n++)
                    indexes.Add($"{table}|{index.GetDatabaseName()}|{index.IsUnique}|{index.Properties[n].GetColumnName(store)}|{n+1}|{(index.IsDescending?.ElementAt(n) ?? false)}|{index.GetFilter()}");
            foreach (var key in entity.GetKeys())
                for (var n = 0; n < key.Properties.Count; n++)
                    indexes.Add($"{table}|{key.GetName()}|True|{key.Properties[n].GetColumnName(store)}|{n+1}|False|");
            foreach (var fk in entity.GetForeignKeys())
                for (var n = 0; n < fk.Properties.Count; n++)
                    foreign.Add($"{fk.GetConstraintName()}|{fk.Properties[n].GetColumnName(store)}|{fk.PrincipalEntityType.GetSchema()}|{fk.PrincipalEntityType.GetTableName()}|{fk.PrincipalKey.Properties[n].GetColumnName()}|{n+1}|{(fk.DeleteBehavior == DeleteBehavior.Restrict ? 0 : -1)}");
            checks.AddRange(entity.GetCheckConstraints().Select(x => x.Name + "|" + x.Sql));
        }
        InternalCashSchemaOracle.AssertColumns(columns);
        InternalCashSchemaOracle.AssertShape(InternalCashSchemaOracle.IndexShape, indexes);
        InternalCashSchemaOracle.AssertShape(InternalCashSchemaOracle.ForeignKeyShape, foreign);
        InternalCashSchemaOracle.AssertShape(InternalCashSchemaOracle.CheckShape, checks);
    }
}
