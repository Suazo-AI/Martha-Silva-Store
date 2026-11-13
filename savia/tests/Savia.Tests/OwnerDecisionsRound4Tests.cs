using System.Net;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using Savia.Application;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Tests;

/// <summary>Owner decisions 2026-11-12: shared sale, return outcomes, KPIs and catalog import through the real API.</summary>
public sealed class OwnerDecisionsRound4Tests
{
    private static string Samples()
    {
        for (var dir = new DirectoryInfo(AppContext.BaseDirectory); dir is not null; dir = dir.Parent)
        {
            var path = Path.Combine(dir.FullName, "docs", "pilot", "import-samples");
            if (Directory.Exists(path) && File.Exists(Path.Combine(dir.FullName, "tools", "db", "saviadb.py"))) return path;
        }
        throw new InvalidOperationException("import samples not found");
    }

    [Fact]
    public void Parser_reads_the_csv_with_spanish_headers_and_the_xlsx_with_another_column_order()
    {
        var csv = CatalogFile.Parse("catalogo-ejemplo.csv", File.ReadAllBytes(Path.Combine(Samples(), "catalogo-ejemplo.csv")));
        Assert.Equal("Codigo de barras", csv.Headers[0]);
        Assert.Equal(9, csv.Headers.Length);
        Assert.Equal(4, csv.Rows.Length);
        Assert.Equal("1,150.00", csv.Rows[2][7]);
        Assert.Equal("", csv.Rows[3][1]);
        var xlsx = CatalogFile.Parse("inventario-ejemplo.xlsx", File.ReadAllBytes(Path.Combine(Samples(), "inventario-ejemplo.xlsx")));
        Assert.Equal(["Descripcion", "Precio venta", "Talla", "Color", "Existencias", "Codigo", "Costo unitario", "Categoria", "Referencia"], xlsx.Headers);
        Assert.Equal(3, xlsx.Rows.Length);
        Assert.Equal("7459990002014", xlsx.Rows[0][5]);
        Assert.Equal("780.5", xlsx.Rows[2][1]);
        var quoted = CatalogFile.Parse("q.csv", Encoding.UTF8.GetBytes("codigo,nombre\r\n\"1,2\",\"Blusa \"\"A\"\"\"\r\n"));
        Assert.Equal(["1,2", "Blusa \"A\""], quoted.Rows[0]);
        Assert.Equal("import.format", Assert.Throws<SaviaException>(() => CatalogFile.Parse("x.xlsx", [1, 2, 3])).Error.Code);
        Assert.Equal("import.format", Assert.Throws<SaviaException>(() => CatalogFile.Parse("x.pdf", [1])).Error.Code);
    }

    [Fact]
    public async Task Shared_sale_return_outcomes_kpis_and_import_follow_the_owner_decisions()
    {
        var db = await TestSql.CloneAsync("round4");
        try
        {
            var sellers = Enumerable.Range(1, 5).Select(_ => Guid.NewGuid()).ToArray();
            await using var sql = new SqlConnection(TestSql.ConnectionFor(db)); await sql.OpenAsync();
            async Task Execute(string text) { await using var cmd = new SqlCommand(text, sql); await cmd.ExecuteNonQueryAsync(); }
            for (var i = 0; i < sellers.Length; i++)
                await Execute($"INSERT security.Staff(Id,LoginName,NormalizedLoginName,DisplayName,IsEnabled) VALUES('{sellers[i]}','r4s{i}','R4S{i}','Vendedora {i}',{(i == 4 ? 0 : 1)});INSERT security.StaffRoles(StaffId,RoleId) SELECT '{sellers[i]}',Id FROM security.Roles WHERE Code='SELLER';INSERT security.StaffBranchAccess(StaffId,BranchId) VALUES('{sellers[i]}','{Ids.BranchA}');");
            await using var node = SaviaNode.BranchA(db);
            var owner = await node.SignInAsync(Ids.Manager, "t_manager");
            var manager = await node.SignInAsync(Ids.SupervisorA, "t_super_a");
            var seller = await node.SignInAsync(sellers[0], "r4s0");
            await HttpAssert.OkAsync(await owner.PostAsJsonAsync($"/api/v1/catalog/items/{Ids.Item}/values", new ItemValuesRequest(Guid.NewGuid(), 125000, 62000, "Precio de prueba")));
            await Execute($"EXEC test.SeedStock '{Ids.Item}','{Ids.LocA}',20;");
            var till = Guid.NewGuid();
            await HttpAssert.OkAsync(await manager.PostAsJsonAsync("/api/v1/cash/tills", new OpenTillRequest(till, Ids.RegisterA, "NIO", 0, [new(100000, 0)])));

            // 1. Shared sale: one receipt, one payment, a seller per line, at most three sellers, active sellers only.
            PostSaleRequest Sale(params Guid[] by) => new(Guid.NewGuid(), till, "NIO",
                by.Select((s, i) => new SaleLine(i + 1, Ids.Item, 1, 125000, 0, s)).ToArray(), [new(1, "cash", 125000L * by.Length, 125000L * by.Length, 0)]);
            await HttpAssert.ProblemAsync(await manager.PostAsJsonAsync("/api/v1/sales", Sale(sellers[0], sellers[1], sellers[2], sellers[3])), HttpStatusCode.UnprocessableEntity, "sale.too_many_sellers");
            await HttpAssert.ProblemAsync(await manager.PostAsJsonAsync("/api/v1/sales", Sale(sellers[4])), HttpStatusCode.UnprocessableEntity, "sale.seller_required");
            var mixed = Sale(sellers[0], sellers[1]);
            mixed = mixed with { Lines = [mixed.Lines[0], mixed.Lines[1] with { SellerId = null }] };
            await HttpAssert.ProblemAsync(await manager.PostAsJsonAsync("/api/v1/sales", mixed), HttpStatusCode.UnprocessableEntity, "sale.seller_required");
            var shared = Sale(sellers[0], sellers[1], sellers[0]);
            await HttpAssert.OkAsync<SaleResponse>(await manager.PostAsJsonAsync("/api/v1/sales", shared));
            var detail = await HttpAssert.OkAsync<SaleDetailResponse>(await manager.GetAsync($"/api/v1/sales/{shared.SaleId}"));
            Assert.Single(detail.Tenders);
            Assert.Equal(new[] { sellers[0], sellers[1], sellers[0] }, detail.Lines.Select(l => l.SellerId!.Value));
            Assert.All(detail.Lines, l => Assert.False(string.IsNullOrEmpty(l.SellerName)));

            // 2. Return outcomes: cash from the till, bank transfer with a reference, exchange in one operation; a seller cannot approve.
            ReturnLine[] Line(int i) => [new(detail.Lines[i].SaleLineId, 1, "store")];
            var cash = new PostReturnOutcomeRequest(Guid.NewGuid(), "cash", till, "Talla", Line(1));
            await HttpAssert.ProblemAsync(await seller.PostAsJsonAsync($"/api/v1/sales/{shared.SaleId}/returns/outcome", cash), HttpStatusCode.Forbidden, "auth.role_required");
            var cashReversal = await HttpAssert.OkAsync<SaleReversal>(await manager.PostAsJsonAsync($"/api/v1/sales/{shared.SaleId}/returns/outcome", cash));
            Assert.Equal("cash", cashReversal.SettlementKind);
            Assert.Equal(125000, cashReversal.CreditMinor);
            await HttpAssert.OkAsync<SaleReversal>(await manager.PostAsJsonAsync($"/api/v1/sales/{shared.SaleId}/returns/outcome", cash));
            var noReference = new PostReturnOutcomeRequest(Guid.NewGuid(), "transfer", till, "Defecto", Line(0));
            await HttpAssert.ProblemAsync(await manager.PostAsJsonAsync($"/api/v1/sales/{shared.SaleId}/returns/outcome", noReference), HttpStatusCode.UnprocessableEntity, "return.transfer_reference");
            var transfer = noReference with { Reference = "BAC 004512" };
            Assert.Equal("transfer", (await HttpAssert.OkAsync<SaleReversal>(await manager.PostAsJsonAsync($"/api/v1/sales/{shared.SaleId}/returns/outcome", transfer))).SettlementKind);
            var exchangeSale = Guid.NewGuid();
            var exchange = new PostReturnOutcomeRequest(Guid.NewGuid(), "exchange", till, "Cambio de talla", Line(2), ExchangeSaleId: exchangeSale,
                NewLines: [new(1, Ids.Item, 1, 125000, 0, sellers[2])], NewTenders: []);
            Assert.Equal("exchange", (await HttpAssert.OkAsync<SaleReversal>(await manager.PostAsJsonAsync($"/api/v1/sales/{shared.SaleId}/returns/outcome", exchange))).SettlementKind);
            var exchanged = await HttpAssert.OkAsync<SaleDetailResponse>(await manager.GetAsync($"/api/v1/sales/{exchangeSale}"));
            Assert.Equal(sellers[2], Assert.Single(exchanged.Lines).SellerId);
            // A card sale cannot be refunded in cash when the till holds less cash than the refund.
            var card = new PostSaleRequest(Guid.NewGuid(), till, "NIO", [new(1, Ids.Item, 3, 125000, 0, sellers[1])], [new(1, "card", 375000)]);
            await HttpAssert.OkAsync<SaleResponse>(await manager.PostAsJsonAsync("/api/v1/sales", card));
            var cardLine = (await HttpAssert.OkAsync<SaleDetailResponse>(await manager.GetAsync($"/api/v1/sales/{card.SaleId}"))).Lines[0];
            var tooMuch = new PostReturnOutcomeRequest(Guid.NewGuid(), "cash", till, "Talla", [new(cardLine.SaleLineId, 3, "store")]);
            await HttpAssert.ProblemAsync(await manager.PostAsJsonAsync($"/api/v1/sales/{card.SaleId}/returns/outcome", tooMuch), HttpStatusCode.Conflict, "return.till_cash_short");
            // The window is a server rule: the owner sets it, the manager cannot.
            var policy = await HttpAssert.OkAsync<JsonElement>(await manager.GetAsync("/api/v1/returns/policy"));
            Assert.Equal(30, policy.GetProperty("windowDays").GetInt32());
            var window = new ReturnWindowRequest(Guid.NewGuid(), 15, "Temporada");
            await HttpAssert.ProblemAsync(await manager.PostAsJsonAsync("/api/v1/returns/policy", window), HttpStatusCode.Forbidden, "auth.role_required");
            await HttpAssert.OkAsync(await owner.PostAsJsonAsync("/api/v1/returns/policy", window));
            Assert.Equal(15, (await HttpAssert.OkAsync<JsonElement>(await manager.GetAsync("/api/v1/returns/policy"))).GetProperty("windowDays").GetInt32());

            // Day report and KPIs show refunds by kind; team commission equals the commission report.
            var today = DateTime.UtcNow.AddHours(-6).ToString("yyyy-MM-dd");
            var day = await HttpAssert.OkAsync<DayReport>(await manager.GetAsync($"/api/v1/reports/day?date={today}"));
            Assert.Equal(125000, day.RefundsByKind!.Single(k => k.Kind == "cash").CashOutMinor);
            Assert.Equal(125000, day.RefundsByKind!.Single(k => k.Kind == "transfer").AmountMinor);
            Assert.Equal(125000, day.RefundsByKind!.Single(k => k.Kind == "exchange").AmountMinor);
            foreach (var period in new[] { "day", "week", "month", "year" })
            {
                var business = await HttpAssert.OkAsync<JsonElement>(await owner.GetAsync($"/api/v1/reports/kpi/business?period={period}&date={today}"));
                Assert.Equal(3, business.GetProperty("refundsByKind").GetArrayLength());
                var team = await HttpAssert.OkAsync<JsonElement>(await owner.GetAsync($"/api/v1/reports/kpi/team?period={period}&date={today}"));
                var commissions = await HttpAssert.OkAsync<JsonElement>(await owner.GetAsync($"/api/v1/reports/commissions?period={period}&date={today}"));
                foreach (var row in commissions.EnumerateArray())
                {
                    var match = team.GetProperty("sellers").EnumerateArray().Single(s => s.GetProperty("sellerId").GetGuid() == row.GetProperty("sellerId").GetGuid());
                    Assert.Equal(row.GetProperty("commissionPayableMinor").GetInt64(), match.GetProperty("commissionPayableMinor").GetInt64());
                }
                Assert.Equal(HttpStatusCode.OK, (await owner.GetAsync($"/api/v1/reports/kpi/business.csv?period={period}&date={today}")).StatusCode);
                Assert.Equal(HttpStatusCode.OK, (await owner.GetAsync($"/api/v1/reports/kpi/team.csv?period={period}&date={today}")).StatusCode);
            }
            // Seller 1 sold lines 1 and 3; line 1 went back by transfer, line 3 by exchange: 3 % commission is fully reversed.
            var own = await HttpAssert.OkAsync<JsonElement>(await seller.GetAsync($"/api/v1/reports/kpi/team?period=day&date={today}"));
            var mine = Assert.Single(own.GetProperty("sellers").EnumerateArray());
            Assert.Equal(sellers[0], mine.GetProperty("sellerId").GetGuid());
            Assert.Equal(0, mine.GetProperty("commissionPayableMinor").GetInt64());
            Assert.Empty(own.GetProperty("managers").EnumerateArray());
            await HttpAssert.ProblemAsync(await seller.GetAsync($"/api/v1/reports/kpi/business?period=day&date={today}"), HttpStatusCode.Forbidden, "auth.role_required");

            // 4. Import: owner only; both samples parse, preview clean, and import in one batch each.
            foreach (var (file, map) in new[] {
                ("catalogo-ejemplo.csv", new[] { 0, 1, 2, 3, 4, 5, 6, 7, 8 }),
                ("inventario-ejemplo.xlsx", new[] { 5, 8, 0, 7, 2, 3, 6, 1, 4 }) })
            {
                var upload = new ImportFileRequest(file, Convert.ToBase64String(File.ReadAllBytes(Path.Combine(Samples(), file))));
                await HttpAssert.ProblemAsync(await manager.PostAsJsonAsync("/api/v1/catalog/import/file", upload), HttpStatusCode.Forbidden, "auth.role_required");
                var parsed = await HttpAssert.OkAsync<ImportFile>(await owner.PostAsJsonAsync("/api/v1/catalog/import/file", upload));
                string? Cell(string[] row, int i) => row[map[i]];
                var rows = parsed.Rows.Select((r, i) => new ImportRow(i + 2, Cell(r, 0), Cell(r, 1), Cell(r, 2), Cell(r, 3), Cell(r, 4), Cell(r, 5), Cell(r, 6), Cell(r, 7), Cell(r, 8))).ToArray();
                var request = new ImportCatalogRequest(Guid.NewGuid(), file, rows);
                var preview = await HttpAssert.OkAsync<JsonElement>(await owner.PostAsJsonAsync("/api/v1/catalog/import/preview", request));
                Assert.Equal(0, preview.GetProperty("errorCount").GetInt32());
                var done = await HttpAssert.OkAsync<JsonElement>(await owner.PostAsJsonAsync("/api/v1/catalog/import", request));
                Assert.Equal(rows.Length, done.GetProperty("itemsCreated").GetInt32());
                var again = await HttpAssert.OkAsync<JsonElement>(await owner.PostAsJsonAsync("/api/v1/catalog/import/preview", request with { BatchId = Guid.NewGuid() }));
                Assert.Equal(rows.Length, again.GetProperty("errorCount").GetInt32());
                await HttpAssert.ProblemAsync(await owner.PostAsJsonAsync("/api/v1/catalog/import", request with { BatchId = Guid.NewGuid() }), HttpStatusCode.Conflict, "import.row_errors");
            }
            Assert.Equal(16, await TestSql.ScalarAsync<int>(db, "SELECT SUM(OnHandDelta) FROM inventory.StockMovements WHERE SourceType='catalog_import'"));
            Assert.Equal(78050, await TestSql.ScalarAsync<long>(db, "SELECT UnitPriceMinor FROM catalog.Items WHERE Sku='IMP-FAL-S-VER'"));
            await TestSql.AssertConservationAsync(db);
        }
        finally { await TestSql.DropAsync(db); }
    }
}
