using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using Savia.Contracts;

namespace Savia.Tests;

public sealed class OwnerPilotTests
{
    [Fact]
    public async Task Real_roles_two_sellers_return_price_and_quality_preserve_the_books()
    {
        var db = await TestSql.CloneAsync("owner_pilot");
        try
        {
            var seller1 = Guid.NewGuid(); var seller2 = Guid.NewGuid(); var stock = Guid.NewGuid();
            await using var sql = new SqlConnection(TestSql.ConnectionFor(db)); await sql.OpenAsync();
            async Task Execute(string text) { await using var cmd = new SqlCommand(text, sql); await cmd.ExecuteNonQueryAsync(); }
            foreach (var (id, login, role) in new[] { (seller1, "seller1", "SELLER"), (seller2, "seller2", "SELLER"), (stock, "stockworker", "INVENTORY") })
                await Execute($"INSERT security.Staff(Id,LoginName,NormalizedLoginName,DisplayName) VALUES('{id}','{login}','{login.ToUpperInvariant()}','{login}');INSERT security.StaffRoles(StaffId,RoleId) SELECT '{id}',Id FROM security.Roles WHERE Code='{role}';INSERT security.StaffBranchAccess(StaffId,BranchId) VALUES('{id}','{Ids.BranchA}');");
            await using var node = SaviaNode.BranchA(db);
            var owner = await node.SignInAsync(Ids.Manager, "t_manager");
            var manager = await node.SignInAsync(Ids.SupervisorA, "t_super_a");
            var seller = await node.SignInAsync(seller1, "seller1");
            var warehouse = await node.SignInAsync(stock, "stockworker");
            foreach (var path in new[] { "/api/v1/cash/registers", "/api/v1/cash/tills/current", "/api/v1/approvals", "/api/v1/catalog/values" })
                await HttpAssert.ProblemAsync(await seller.GetAsync(path), HttpStatusCode.Forbidden, "auth.role_required");
            var lookup = await HttpAssert.OkAsync<ItemLookup[]>(await warehouse.GetAsync($"/api/v1/catalog/lookup?code={Ids.ItemBarcode}"));
            Assert.Null(Assert.Single(lookup).UnitPriceMinor);
            var values = new ItemValuesRequest(Guid.NewGuid(), 125000, 62000, "Precio aprobado por dueña");
            await HttpAssert.ProblemAsync(await manager.PostAsJsonAsync($"/api/v1/catalog/items/{Ids.Item}/values", values), HttpStatusCode.Forbidden, "auth.role_required");
            await HttpAssert.OkAsync(await owner.PostAsJsonAsync($"/api/v1/catalog/items/{Ids.Item}/values", values));
            await HttpAssert.OkAsync(await owner.PostAsJsonAsync($"/api/v1/catalog/items/{Ids.Item}/values", values));
            Assert.Equal(1, await TestSql.ScalarAsync<int>(db, "SELECT COUNT(*) FROM catalog.ItemValueHistory"));
            await Execute($"EXEC test.SeedStock '{Ids.Item}','{Ids.LocA}',10;");
            var till = Guid.NewGuid(); await HttpAssert.OkAsync(await manager.PostAsJsonAsync("/api/v1/cash/tills", new OpenTillRequest(till, Ids.RegisterA, "NIO", 0, [new(100000, 0)])));
            var sale = new PostSaleRequest(Guid.NewGuid(), till, "NIO", [new(1, Ids.Item, 2, 125000, 25000, seller1), new(2, Ids.Item, 1, 125000, 0, seller2)], [new(1, "card", 350000)], DiscountReason: "Descuento gerente");
            await HttpAssert.OkAsync<SaleResponse>(await manager.PostAsJsonAsync("/api/v1/sales", sale));
            await HttpAssert.OkAsync<SaleResponse>(await manager.PostAsJsonAsync("/api/v1/sales", sale));
            var detail = await HttpAssert.OkAsync<SaleDetailResponse>(await manager.GetAsync($"/api/v1/sales/{sale.SaleId}"));
            Assert.Null(detail.CustomerId); Assert.Equal(new[] { seller1, seller2 }, detail.Lines.Select(l => l.SellerId!.Value));
            var bad = sale with { SaleId = Guid.NewGuid(), Lines = [new(1, Ids.Item, 1, 120000, 0, seller1)], Tenders = [new(1, "card", 120000)] };
            await HttpAssert.ProblemAsync(await manager.PostAsJsonAsync("/api/v1/sales", bad), HttpStatusCode.Conflict, "sale.price_changed");
            var missing = sale with { SaleId = Guid.NewGuid(), Lines = [new(1, Ids.Item, 1, 125000)], Tenders = [new(1, "card", 125000)] };
            await HttpAssert.ProblemAsync(await manager.PostAsJsonAsync("/api/v1/sales", missing), HttpStatusCode.UnprocessableEntity, "sale.seller_required");
            var customer = Guid.Parse("00000000-0000-0000-0000-00000000C051");
            var returned = new PostCreditReturnRequest(Guid.NewGuid(), Guid.NewGuid(), till, customer, "Talla", [new(detail.Lines[0].SaleLineId, 1, "store")]);
            await HttpAssert.OkAsync<SaleReversal>(await manager.PostAsJsonAsync($"/api/v1/sales/{sale.SaleId}/returns/credit", returned));
            var today = DateTime.UtcNow.AddHours(-6).ToString("yyyy-MM-dd");
            foreach (var period in new[] { "day", "week", "month", "year" })
            {
                var report = await HttpAssert.OkAsync<JsonElement>(await manager.GetAsync($"/api/v1/reports/commissions?period={period}&date={today}"));
                var one = Assert.Single(report.EnumerateArray(), row => row.GetProperty("sellerId").GetGuid() == seller1);
                Assert.Equal(6750, one.GetProperty("commissionEarnedMinor").GetInt64()); Assert.Equal(3375, one.GetProperty("commissionReversedMinor").GetInt64()); Assert.Equal(3375, one.GetProperty("commissionPayableMinor").GetInt64());
                var own = await HttpAssert.OkAsync<JsonElement>(await seller.GetAsync($"/api/v1/reports/commissions?period={period}&date={today}")); Assert.Single(own.EnumerateArray());
                Assert.Equal(HttpStatusCode.OK, (await manager.GetAsync($"/api/v1/reports/commissions.csv?period={period}&date={today}")).StatusCode);
            }
            var session = Guid.NewGuid(); await HttpAssert.OkAsync(await warehouse.PostAsJsonAsync("/api/v1/receiving/sessions", new OpenScanSessionRequest(Guid.NewGuid(), session, "CALIDAD", Ids.Supplier)));
            await HttpAssert.OkAsync<ScanResult>(await warehouse.PostAsJsonAsync($"/api/v1/receiving/sessions/{session}/scans", new RecordScanRequest(Guid.NewGuid(), Ids.ItemBarcode, 4)));
            var emptyQuality = await HttpAssert.OkAsync<JsonElement>(await warehouse.GetAsync($"/api/v1/receiving/sessions/{session}/quality"));
            Assert.Empty(emptyQuality.EnumerateArray());
            await HttpAssert.OkAsync(await warehouse.PostAsJsonAsync($"/api/v1/receiving/sessions/{session}/quality", new QualityRequest(Guid.NewGuid(), Ids.Item, 2, 1, 0, 0, 1, "Una dañada y una faltante")));
            await HttpAssert.OkAsync(await manager.PostAsync($"/api/v1/receiving/sessions/{session}/approve", null));
            await HttpAssert.OkAsync<PostScanSessionResponse>(await manager.PostAsync($"/api/v1/receiving/sessions/{session}/post", null));
            Assert.Equal(1, await TestSql.ScalarAsync<int>(db, $"SELECT OnHand FROM inventory.StockBalances WHERE ItemId='{Ids.Item}' AND Pool='quarantine'"));
            var approvals = await HttpAssert.OkAsync<JsonElement>(await owner.GetAsync("/api/v1/approvals")); Assert.Contains(approvals.EnumerateArray(), row => row.GetProperty("kind").GetString() == "descuento");
            await HttpAssert.ProblemAsync(await manager.GetAsync("/api/v1/approvals"), HttpStatusCode.Forbidden, "auth.role_required");
            await TestSql.AssertConservationAsync(db);
        }
        finally { await TestSql.DropAsync(db); }
    }
}
