using System.Globalization;
using System.Net;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Martha.Store.Api.Internal;
using Microsoft.AspNetCore.Identity;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Xunit;
using static Martha.Store.Api.Tests.InternalJudgeTests;

namespace Martha.Store.Api.Tests;

// C7: N1, N3, N4, N8 and N9 of docs/delivery-20261031/NEXT-INCREMENT.md as API tests.
// Real Program, real cookie login, real antiforgery and a database built with the real Internal migrations.
// Every rejection is judged by an independent SQL read of ALL savia_internal tables before and after:
// a 403 alone does not prove the absence of effects. Synthetic identities only; nothing is printed.
public sealed class InternalAcceptanceHttpSqlTests
{
    private static readonly HttpMethod Get = HttpMethod.Get, Post = HttpMethod.Post, Put = HttpMethod.Put;

    [InternalJudgeHttpSqlFact]
    public async Task N1_each_role_reads_only_its_server_scope_and_unassigned_user_has_no_global_access()
    {
        await using var f = await AcceptanceFixture.Create();
        // Expected values are fixed by the fixture and cross-checked with a SQL predicate written independently of InternalBranchAccess.
        var expected = new Dictionary<string, (int Locations, int Sales, int Stock, int Movements)>
        {
            ["owner"] = (2, 2, 3, 2), ["manager"] = (1, 1, 2, 1), ["cashier"] = (1, 1, 2, 1),
            ["inventory"] = (1, 1, 2, 1), ["unassigned"] = (0, 0, 0, 0)
        };
        foreach (var (role, scope) in expected)
        {
            var staff = f.Staff[role];
            using var session = await f.Login(role);
            using (var me = await session.Send(Get, "/internal/api/security/me"))
            {
                var body = await Json(me, HttpStatusCode.OK);
                Assert.Equal(staff.Id, body.GetProperty("id").GetGuid());
                Assert.Equal(await f.Scalar($"SELECT Role FROM savia_internal.Staff WHERE Id='{staff.Id}'"), body.GetProperty("role").GetString());
            }
            Assert.Equal(scope.Locations, int.Parse(await f.Scalar(VisibleSql(staff.Id, "SELECT COUNT(*) FROM savia_internal.Locations x"))));
            Assert.Equal(scope.Sales, int.Parse(await f.Scalar(VisibleSql(staff.Id, "SELECT COUNT(*) FROM savia_internal.Sales x"))));
            Assert.Equal(scope.Stock, int.Parse(await f.Scalar(VisibleSql(staff.Id, "SELECT COUNT(*) FROM savia_internal.StockBalances x"))));
            Assert.Equal(scope.Movements, int.Parse(await f.Scalar(VisibleSql(staff.Id, "SELECT COUNT(*) FROM savia_internal.StockMovements x"))));

            var locations = await Page(session, "/internal/api/directory/locations?take=1", scope.Locations);
            var stock = await Page(session, "/internal/api/commerce/inventory?take=1", scope.Stock);
            var movements = await Page(session, "/internal/api/commerce/movements?take=1", scope.Movements);
            // Paginated totals: every page reports the authorized total, and walking the pages yields exactly the authorized rows.
            var sales = new List<Guid>();
            for (var skip = 0; skip <= scope.Sales; skip++)
            {
                var page = await Page(session, $"/internal/api/commerce/sales?skip={skip}&take=1", scope.Sales);
                Assert.Equal(skip < scope.Sales ? 1 : 0, page.GetProperty("items").GetArrayLength());
                sales.AddRange(page.GetProperty("items").EnumerateArray().Select(x => x.GetProperty("saleId").GetGuid()));
            }
            Assert.Equal((await f.Rows(VisibleSql(staff.Id, "SELECT CONVERT(varchar(36),x.Id) FROM savia_internal.Sales x"))).Select(Guid.Parse).Order(), sales.Order());
            if (role != "owner")
                foreach (var body in new[] { locations, stock, movements }.Select(x => x.GetRawText()))
                    AssertNoLeak(body, f.LocationB, f.SaleB, f.PurchaseB);
            if (role == "unassigned") Assert.Empty(sales);
        }

        // The server role, not a client header, decides authority.
        using (var cashier = await f.Login("cashier"))
        {
            cashier.Header("X-Role", "Owner"); cashier.Header("X-Actor-Id", f.Database.Actor.ToString());
            using var staff = await cashier.Send(Get, "/internal/api/security/staff");
            Assert.Equal(HttpStatusCode.Forbidden, staff.StatusCode);
        }

        // A non-Owner without assignment cannot operate anywhere, even with Manager permissions.
        using var unassigned = await f.Login("unassigned");
        var before = await f.Fingerprint();
        await Rejected(unassigned, HttpStatusCode.Forbidden, Post, "/internal/api/commerce/sales", f.SaleBody(f.LocationA));
        await Rejected(unassigned, HttpStatusCode.Forbidden, Post, "/internal/api/commerce/adjustments", f.AdjustBody(f.LocationA, "Synthetic unassigned adjustment"));
        await Rejected(unassigned, HttpStatusCode.Forbidden, Post, $"/internal/api/commerce/sales/{f.SaleA}/cancel", new { reason = "Synthetic unassigned cancel" });
        await Rejected(unassigned, HttpStatusCode.Forbidden, Post, "/internal/api/supply/purchase-orders", f.PurchaseBody(f.LocationA));
        await Rejected(unassigned, HttpStatusCode.NotFound, Get, $"/internal/api/commerce/sales/{f.SaleA}");
        await Rejected(unassigned, HttpStatusCode.NotFound, Get, $"/internal/api/supply/purchase-orders/{f.PurchaseA}");
        using (var orders = await unassigned.Send(Get, "/internal/api/supply/purchase-orders"))
            Assert.Equal(0, (await Json(orders, HttpStatusCode.OK)).GetProperty("items").GetArrayLength());
        Assert.Equal(before, await f.Fingerprint());
    }

    [InternalJudgeHttpSqlFact]
    public async Task N3_cashier_direct_commands_and_cost_reads_are_rejected_without_writes_or_cost_leaks()
    {
        await using var f = await AcceptanceFixture.Create();
        using var cashier = await f.Login("cashier");
        using var inventory = await f.Login("inventory");
        var cashierStaff = f.Staff["cashier"];
        var before = await f.Fingerprint();

        var adjustment = f.AdjustBody(f.LocationA, "Synthetic cashier adjustment");
        var returned = new { reason = "Synthetic cashier return", lines = new[] { new { saleLineId = f.SaleALine, quantity = 1 } } };
        var forbidden = new (HttpMethod Method, string Path, object? Body)[]
        {
            (Post, "/internal/api/commerce/adjustments", adjustment),
            (Post, $"/internal/api/commerce/sales/{f.SaleA}/returns", returned),
            (Post, $"/internal/api/commerce/sales/{f.SaleA}/cancel", new { reason = "Synthetic cashier cancel" }),
            (Post, "/internal/api/supply/purchase-orders", f.PurchaseBody(f.LocationA)),
            (Post, $"/internal/api/supply/purchase-orders/{f.PurchaseA}/receipts", new { receiptId = Guid.NewGuid(), lines = new[] { new { purchaseOrderLineId = f.PurchaseALine, quantity = 1 } } }),
            (Post, $"/internal/api/supply/purchase-orders/{f.PurchaseA}/cancel", new { reason = "Synthetic cashier purchase cancel" }),
            (Post, "/internal/api/security/staff", new { loginName = "n3.created.staff", displayName = "Synthetic N3", role = "Cashier", password = "synthetic-n3-input-only" }),
            (Put, $"/internal/api/security/staff/{cashierStaff.Id}", new { displayName = cashierStaff.DisplayName, role = "Owner", enabled = true, version = cashierStaff.SecurityVersion }),
            (Post, $"/internal/api/security/staff/{f.Database.Actor}/password", new { password = "synthetic-n3-input-only", version = f.Database.Staff.SecurityVersion }),
            (Post, "/internal/api/directory/items", new { sku = "N3-SYNTHETIC", name = "Synthetic N3 item", unitPriceMinor = 100, currency = "USD" }),
            (Put, $"/internal/api/directory/locations/{f.LocationA}", new { name = "Synthetic N3 rename", active = true }),
            // Cost and personnel reads.
            (Get, "/internal/api/supply/purchase-orders", null),
            (Get, $"/internal/api/supply/purchase-orders/{f.PurchaseA}", null),
            (Get, $"/internal/api/supply/purchase-orders/{f.PurchaseA}/receipts", null),
            (Get, "/internal/api/directory/parties", null),
            (Get, $"/internal/api/directory/parties/{f.Supplier}", null),
            (Get, "/internal/api/security/staff", null),
        };
        foreach (var (method, path, body) in forbidden)
            await Rejected(cashier, HttpStatusCode.Forbidden, method, path, body);
        // Inventory may adjust and receive, but never sell or reverse a sale.
        await Rejected(inventory, HttpStatusCode.Forbidden, Post, "/internal/api/commerce/sales", f.SaleBody(f.LocationA));
        await Rejected(inventory, HttpStatusCode.Forbidden, Post, $"/internal/api/commerce/sales/{f.SaleA}/cancel", new { reason = "Synthetic inventory cancel" });
        Assert.Equal(before, await f.Fingerprint());

        // Cashier-visible reads never carry purchase costs.
        foreach (var path in new[] { "/internal/api/commerce/sales", $"/internal/api/commerce/sales/{f.SaleA}", "/internal/api/commerce/inventory",
            "/internal/api/commerce/movements", "/internal/api/directory/items", "/internal/api/directory/locations" })
        {
            using var response = await cashier.Send(Get, path);
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            AssertNoLeak(await response.Content.ReadAsStringAsync(), f.LocationB, f.SaleB, f.PurchaseA, f.PurchaseB);
        }

        // Positive controls: the same bodies are valid for an authorized role, so the rejections above are authorization, not shape.
        using var manager = await f.Login("manager");
        using (var response = await manager.Send(Post, $"/internal/api/commerce/sales/{f.SaleA}/returns", returned, await Csrf(manager), Key()))
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        using (var response = await inventory.Send(Post, "/internal/api/commerce/adjustments", adjustment, await Csrf(inventory), Key()))
            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        using (var response = await cashier.Send(Post, "/internal/api/commerce/sales", f.SaleBody(f.LocationA), await Csrf(cashier), Key()))
            Assert.Equal(cashierStaff.Id, (await Json(response, HttpStatusCode.OK)).GetProperty("actorId").GetGuid());
    }

    [InternalJudgeHttpSqlFact]
    public async Task N4_foreign_location_ids_paging_and_operation_identity_are_denied_without_writes_or_leaks()
    {
        await using var f = await AcceptanceFixture.Create();
        using var manager = await f.Login("manager");
        using var cashier = await f.Login("cashier");
        using var inventory = await f.Login("inventory");
        var before = await f.Fingerprint();

        // Foreign IDs: absent, never another branch's data.
        foreach (var path in new[] { $"/internal/api/commerce/sales/{f.SaleB}", $"/internal/api/commerce/sales/{f.SaleB}/reversals",
            $"/internal/api/directory/locations/{f.LocationB}", $"/internal/api/supply/purchase-orders/{f.PurchaseB}",
            $"/internal/api/supply/purchase-orders/{f.PurchaseB}/receipts" })
            await Rejected(manager, HttpStatusCode.NotFound, Get, path);
        // Foreign location filters return an empty authorized page, not the foreign rows.
        foreach (var path in new[] { $"/internal/api/commerce/inventory?locationId={f.LocationB}", $"/internal/api/commerce/movements?locationId={f.LocationB}" })
            await Page(manager, path, 0);
        // Skip/take cannot widen the scope or bypass bounds.
        Assert.Empty((await Page(manager, "/internal/api/commerce/sales?skip=1&take=100", 1)).GetProperty("items").EnumerateArray());
        foreach (var path in new[] { "/internal/api/commerce/sales?skip=-1", "/internal/api/commerce/sales?take=0", "/internal/api/commerce/sales?take=101",
            "/internal/api/commerce/inventory?take=1001", "/internal/api/commerce/movements?take=201", "/internal/api/supply/purchase-orders?take=101",
            "/internal/api/directory/locations?take=0" })
            await Rejected(manager, HttpStatusCode.BadRequest, Get, path);
        // Foreign writes by ID or location.
        await Rejected(cashier, HttpStatusCode.Forbidden, Post, "/internal/api/commerce/sales", f.SaleBody(f.LocationB));
        await Rejected(manager, HttpStatusCode.Forbidden, Post, $"/internal/api/commerce/sales/{f.SaleB}/cancel", new { reason = "Synthetic foreign cancel" });
        await Rejected(manager, HttpStatusCode.Forbidden, Post, $"/internal/api/commerce/sales/{f.SaleB}/returns",
            new { reason = "Synthetic foreign return", lines = new[] { new { saleLineId = f.SaleBLine, quantity = 1 } } });
        await Rejected(manager, HttpStatusCode.Forbidden, Post, "/internal/api/commerce/adjustments", f.AdjustBody(f.LocationB, "Synthetic foreign adjustment"));
        await Rejected(manager, HttpStatusCode.Forbidden, Post, "/internal/api/supply/purchase-orders", f.PurchaseBody(f.LocationB));
        await Rejected(inventory, HttpStatusCode.Forbidden, Post, $"/internal/api/supply/purchase-orders/{f.PurchaseB}/receipts",
            new { receiptId = Guid.NewGuid(), lines = new[] { new { purchaseOrderLineId = f.PurchaseBLine, quantity = 1 } } });
        // Foreign operation identity: another actor's key is neither readable nor replayable.
        await Rejected(manager, HttpStatusCode.NotFound, Get, "/internal/api/operations/commerce.sale.record", key: AcceptanceFixture.OwnerSaleBKey);
        await Rejected(cashier, HttpStatusCode.Forbidden, Post, "/internal/api/commerce/sales", f.SaleBody(f.LocationB), AcceptanceFixture.OwnerSaleBKey);
        Assert.Equal(before, await f.Fingerprint());
        // The same key in the cashier's own scope is the cashier's own new operation, never the Owner's receipt.
        using (var own = await cashier.Send(Post, "/internal/api/commerce/sales", f.SaleBody(f.LocationA), await Csrf(cashier), AcceptanceFixture.OwnerSaleBKey))
        {
            var receipt = await Json(own, HttpStatusCode.OK);
            Assert.NotEqual(f.SaleB, receipt.GetProperty("saleId").GetGuid());
            Assert.Equal(f.Staff["cashier"].Id, receipt.GetProperty("actorId").GetGuid());
            Assert.Equal(f.LocationA, receipt.GetProperty("locationId").GetGuid());
        }

        // Owner cannot remap a location that already has stock, sales and movements into another branch.
        using var owner = await f.Login("owner");
        var historySql = $"""
            SELECT 'location|'+CONVERT(varchar(36),Id)+'|'+CONVERT(varchar(36),BranchId) FROM savia_internal.Locations WHERE Id='{f.LocationA}'
            UNION ALL SELECT 'sale|'+CONVERT(varchar(36),Id)+'|'+CONVERT(varchar(36),LocationId) FROM savia_internal.Sales WHERE LocationId='{f.LocationA}'
            UNION ALL SELECT 'movement|'+CONVERT(varchar(36),Id)+'|'+CONVERT(varchar(36),LocationId) FROM savia_internal.StockMovements WHERE LocationId='{f.LocationA}'
            UNION ALL SELECT 'operation|'+[Key] COLLATE DATABASE_DEFAULT+'|'+CONVERT(varchar(36),LocationId)+'|'+CONVERT(varchar(36),OriginalBranchId) FROM savia_internal.Operations WHERE LocationId='{f.LocationA}'
            """;
        var history = await f.Rows(historySql);
        Assert.Contains($"location|{f.LocationA}|{f.BranchA}".ToUpperInvariant(), history.Select(x => x.ToUpperInvariant()));
        Assert.Contains(history, x => x.StartsWith("operation|" + AcceptanceFixture.OwnerSaleAKey + "|", StringComparison.Ordinal)
            && x.EndsWith("|" + f.BranchA.ToString().ToUpperInvariant(), StringComparison.OrdinalIgnoreCase));
        var beforeRemap = await f.Fingerprint();
        var remapKey = Key();
        var remap = new { name = "Disposable test location", active = true, branchId = f.BranchB };
        for (var attempt = 0; attempt < 2; attempt++) // The second send replays the durable rejection.
        {
            using var response = await owner.Send(Put, $"/internal/api/directory/locations/{f.LocationA}", remap, await Csrf(owner), remapKey);
            Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
            Assert.Contains("\"conflict\"", await response.Content.ReadAsStringAsync());
        }
        Assert.Equal(history.Order(), (await f.Rows(historySql)).Order());
        // By design the runner stores ONE durable rejection record (no LocationId) so a retry replays the same conflict;
        // every business table is byte-for-byte unchanged.
        var afterRemap = await f.Fingerprint();
        Assert.Equal(beforeRemap.Where(x => x.Key != "Operations"), afterRemap.Where(x => x.Key != "Operations"));
        Assert.Equal(Count(beforeRemap, "Operations") + 1, Count(afterRemap, "Operations"));
        Assert.Equal(new[] { "directory.locations.update|NULL|NULL|conflict" }, await f.Rows($"""
            SELECT Scope COLLATE DATABASE_DEFAULT+'|'+ISNULL(CONVERT(varchar(36),LocationId),'NULL')+'|'+ISNULL(CONVERT(varchar(36),OriginalBranchId),'NULL')+'|'+JSON_VALUE(ResultJson,'$.error')
            FROM savia_internal.Operations WHERE [Key]='{remapKey}' AND ActorId='{f.Database.Actor}'
            """));
        // The original branch still sees its history.
        using (var sale = await manager.Send(Get, $"/internal/api/commerce/sales/{f.SaleA}"))
            Assert.Equal(f.LocationA, (await Json(sale, HttpStatusCode.OK)).GetProperty("locationId").GetGuid());
    }

    [InternalJudgeHttpSqlFact]
    public async Task N5_owner_branch_reassignment_rejects_original_cashier_cookie_and_preserves_sales_before_new_scope_login()
    {
        await using var f = await AcceptanceFixture.Create();
        using var cashier = await f.Login("cashier");
        using var owner = await f.Login("owner");
        var staff = f.Staff["cashier"];
        var originalCsrf = await Csrf(cashier);
        var originalCookie = cashier.CookieHeader;
        var originalVersion = staff.SecurityVersion;
        var saleKey = Key();
        Guid saleA;
        var beforeSale = await f.Fingerprint();
        using (var response = await cashier.Send(Post, "/internal/api/commerce/sales", f.SaleBody(f.LocationA), originalCsrf, saleKey))
        {
            var receipt = await Json(response, HttpStatusCode.OK);
            saleA = receipt.GetProperty("saleId").GetGuid();
            Assert.Equal(staff.Id, receipt.GetProperty("actorId").GetGuid());
            Assert.Equal(f.LocationA, receipt.GetProperty("locationId").GetGuid());
            Assert.Equal(1, Assert.Single(receipt.GetProperty("lines").EnumerateArray()).GetProperty("quantity").GetInt32());
        }
        var afterSale = await f.Fingerprint();
        foreach (var table in new[] { "Sales", "SaleLines", "StockMovements", "Operations" })
            Assert.Equal(Count(beforeSale, table) + 1, Count(afterSale, table));
        Assert.Equal("18", await f.Scalar($"SELECT OnHand FROM savia_internal.StockBalances WHERE ItemId='{f.Database.Item}' AND LocationId='{f.LocationA}'"));

        // No cookie container: every request explicitly reuses the captured cookie AND CSRF, including after a 401 Set-Cookie.
        using var replayClient = Client(f.Factory);
        async Task<HttpResponseMessage> SendOriginal(HttpMethod method, string path, object? body = null, string? key = null)
        {
            using var request = new HttpRequestMessage(method, path);
            request.Headers.Add("Cookie", originalCookie);
            request.Headers.Add("X-CSRF-TOKEN", originalCsrf);
            if (key is not null) request.Headers.Add("Idempotency-Key", key);
            if (body is not null) request.Content = JsonContent.Create(body);
            return await replayClient.SendAsync(request);
        }
        // Positive control uses exactly the same transport/header mechanism as the rejected requests below.
        using (var response = await SendOriginal(Get, "/internal/api/security/me"))
        {
            var me = await Json(response, HttpStatusCode.OK);
            Assert.Equal(staff.Id, me.GetProperty("id").GetGuid());
            Assert.Equal(f.BranchA, me.GetProperty("branchId").GetGuid());
            Assert.Equal(originalVersion, me.GetProperty("version").GetGuid());
        }
        using (var response = await SendOriginal(Get, $"/internal/api/commerce/sales/{saleA}"))
            Assert.Equal(saleA, (await Json(response, HttpStatusCode.OK)).GetProperty("saleId").GetGuid());

        // Exclude only authentication/assignment tables; retain every business table's full-row hash.
        async Task<SortedDictionary<string, string>> BusinessFingerprint()
        {
            return InternalAcceptanceFingerprint.Business(await f.Fingerprint());
        }
        var historySql = $"""
            SELECT (SELECT * FROM savia_internal.Sales WHERE LocationId='{f.LocationA}' ORDER BY Id FOR JSON PATH)
            UNION ALL SELECT (SELECT l.* FROM savia_internal.SaleLines l JOIN savia_internal.Sales s ON s.Id=l.SaleId WHERE s.LocationId='{f.LocationA}' ORDER BY l.Id FOR JSON PATH)
            UNION ALL SELECT (SELECT * FROM savia_internal.StockMovements WHERE LocationId='{f.LocationA}' ORDER BY Id FOR JSON PATH)
            UNION ALL SELECT (SELECT * FROM savia_internal.Operations WHERE LocationId='{f.LocationA}' ORDER BY Id FOR JSON PATH)
            UNION ALL SELECT (SELECT * FROM savia_internal.StockBalances WHERE LocationId='{f.LocationA}' ORDER BY ItemId FOR JSON PATH)
            UNION ALL SELECT (SELECT * FROM savia_internal.Locations WHERE Id='{f.LocationA}' FOR JSON PATH)
            """;
        var historyA = await f.Rows(historySql);
        var business = await BusinessFingerprint();
        var auditCount = int.Parse(await f.Scalar("SELECT COUNT(*) FROM savia_internal.BranchAssignmentAudit"), CultureInfo.InvariantCulture);
        Guid newVersion;
        using (var response = await owner.Send(Put, $"/internal/api/security/staff/{staff.Id}",
            new { displayName = staff.DisplayName, role = "Cashier", enabled = true, version = originalVersion, branchId = f.BranchB }, await Csrf(owner)))
        {
            var changed = await Json(response, HttpStatusCode.OK);
            Assert.Equal(staff.Id, changed.GetProperty("id").GetGuid());
            Assert.Equal("Cashier", changed.GetProperty("role").GetString());
            Assert.True(changed.GetProperty("enabled").GetBoolean());
            Assert.Equal(f.BranchB, changed.GetProperty("branchId").GetGuid());
            newVersion = changed.GetProperty("version").GetGuid();
            Assert.NotEqual(originalVersion, newVersion);
        }
        Assert.Equal("1", await f.Scalar($"SELECT COUNT(*) FROM savia_internal.Staff WHERE Id='{staff.Id}' AND BranchId='{f.BranchB}' AND Role='Cashier' AND Enabled=1 AND SecurityVersion='{newVersion}'"));
        Assert.Equal("1", await f.Scalar($"SELECT COUNT(*) FROM savia_internal.Sessions WHERE StaffId='{staff.Id}' AND SecurityVersion='{originalVersion}' AND RevokedAt IS NOT NULL"));
        Assert.Equal("0", await f.Scalar($"SELECT COUNT(*) FROM savia_internal.Sessions WHERE StaffId='{staff.Id}' AND RevokedAt IS NULL"));
        Assert.Equal((auditCount + 1).ToString(CultureInfo.InvariantCulture), await f.Scalar("SELECT COUNT(*) FROM savia_internal.BranchAssignmentAudit"));
        Assert.Equal("1", await f.Scalar($"SELECT COUNT(*) FROM savia_internal.BranchAssignmentAudit WHERE ActorId='{f.Database.Actor}' AND StaffId='{staff.Id}' AND PreviousBranchId='{f.BranchA}' AND BranchId='{f.BranchB}'"));
        Assert.Equal(business, await BusinessFingerprint());
        var afterReassignment = await f.Fingerprint();

        foreach (var (method, path, body, key) in new (HttpMethod, string, object?, string?)[]
        {
            (Get, "/internal/api/security/me", null, null),
            (Post, "/internal/api/commerce/sales", f.SaleBody(f.LocationA), saleKey),
            (Post, "/internal/api/commerce/sales", f.SaleBody(f.LocationA), Key())
        })
        {
            using var response = await SendOriginal(method, path, body, key);
            Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
            AssertNoLeak(await response.Content.ReadAsStringAsync(), saleA, f.LocationA, f.LocationB);
            Assert.Equal(afterReassignment, await f.Fingerprint());
        }

        using var fresh = await f.Login("cashier");
        Assert.Equal(business, await BusinessFingerprint());
        var afterFreshLogin = await f.Fingerprint();
        using (var response = await fresh.Send(Get, "/internal/api/security/me"))
        {
            var me = await Json(response, HttpStatusCode.OK);
            Assert.Equal(staff.Id, me.GetProperty("id").GetGuid());
            Assert.Equal("Cashier", me.GetProperty("role").GetString());
            Assert.Equal(f.BranchB, me.GetProperty("branchId").GetGuid());
            Assert.Equal(newVersion, me.GetProperty("version").GetGuid());
        }
        Assert.Equal(afterFreshLogin, await f.Fingerprint());
        await Rejected(fresh, HttpStatusCode.NotFound, Get, $"/internal/api/commerce/sales/{saleA}");
        Assert.Equal(afterFreshLogin, await f.Fingerprint());
        await Rejected(fresh, HttpStatusCode.Forbidden, Post, "/internal/api/commerce/sales", f.SaleBody(f.LocationA), key: saleKey);
        Assert.Equal(afterFreshLogin, await f.Fingerprint());
        var locations = await Page(fresh, "/internal/api/directory/locations", 1);
        Assert.Equal(afterFreshLogin, await f.Fingerprint());
        var stock = await Page(fresh, "/internal/api/commerce/inventory", 1);
        Assert.Equal(afterFreshLogin, await f.Fingerprint());
        var sales = await Page(fresh, "/internal/api/commerce/sales", 1);
        Assert.Equal(afterFreshLogin, await f.Fingerprint());
        Assert.Equal(f.LocationB, Assert.Single(locations.GetProperty("items").EnumerateArray()).GetProperty("id").GetGuid());
        var stockB = Assert.Single(stock.GetProperty("items").EnumerateArray());
        Assert.Equal(f.LocationB, stockB.GetProperty("locationId").GetGuid());
        Assert.Equal(8, stockB.GetProperty("onHand").GetInt32());
        Assert.Equal(f.SaleB, Assert.Single(sales.GetProperty("items").EnumerateArray()).GetProperty("saleId").GetGuid());
        foreach (var page in new[] { locations, stock, sales }) AssertNoLeak(page.GetRawText(), f.LocationA, f.SaleA, saleA, f.PurchaseA);

        // Positive B control: one new sale/debit. Every original A row, including its operation and stock, remains identical.
        using (var response = await fresh.Send(Post, "/internal/api/commerce/sales", f.SaleBody(f.LocationB), await Csrf(fresh), Key()))
        {
            var receipt = await Json(response, HttpStatusCode.OK);
            Assert.NotEqual(saleA, receipt.GetProperty("saleId").GetGuid());
            Assert.Equal(staff.Id, receipt.GetProperty("actorId").GetGuid());
            Assert.Equal(f.LocationB, receipt.GetProperty("locationId").GetGuid());
            Assert.Equal(1, Assert.Single(receipt.GetProperty("lines").EnumerateArray()).GetProperty("quantity").GetInt32());
        }
        var afterB = await BusinessFingerprint();
        foreach (var table in new[] { "Sales", "SaleLines", "StockMovements", "Operations" })
            Assert.Equal(Count(business, table) + 1, Count(afterB, table));
        Assert.Equal(business.Where(x => x.Key is not ("Sales" or "SaleLines" or "StockMovements" or "Operations" or "StockBalances")),
            afterB.Where(x => x.Key is not ("Sales" or "SaleLines" or "StockMovements" or "Operations" or "StockBalances")));
        Assert.Equal("7", await f.Scalar($"SELECT OnHand FROM savia_internal.StockBalances WHERE ItemId='{f.Database.Item}' AND LocationId='{f.LocationB}'"));
        Assert.Equal("1", await f.Scalar($"SELECT COUNT(*) FROM savia_internal.Operations WHERE ActorId='{staff.Id}' AND [Key]='{saleKey}' AND LocationId='{f.LocationA}' AND OriginalBranchId='{f.BranchA}'"));
        Assert.Equal(historyA, await f.Rows(historySql));
    }

    [InternalJudgeHttpSqlFact]
    public async Task N8_missing_wrong_or_stale_csrf_is_rejected_without_writes_and_a_valid_pair_still_works()
    {
        await using var f = await AcceptanceFixture.Create();
        using var session = new HttpSession(Client(f.Factory));
        var anonymous = await Csrf(session);
        using (var login = await session.Send(Post, "/internal/api/security/login",
            new { loginName = f.Staff["cashier"].LoginName, password = HttpFixturePassword }, anonymous))
            Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        var cashierToken = await Csrf(session);
        var before = await f.Fingerprint();
        await Rejected(session, HttpStatusCode.BadRequest, Post, "/internal/api/commerce/sales", f.SaleBody(f.LocationA), csrf: "", code: "csrf_invalid");
        await Rejected(session, HttpStatusCode.BadRequest, Post, "/internal/api/commerce/sales", f.SaleBody(f.LocationA), csrf: "not-a-real-antiforgery-token", code: "csrf_invalid");
        // A token minted before login belongs to the anonymous identity.
        await Rejected(session, HttpStatusCode.BadRequest, Post, "/internal/api/commerce/sales", f.SaleBody(f.LocationA), csrf: anonymous, code: "csrf_invalid");
        // Logout is a mutation too: without CSRF the session is NOT revoked.
        await Rejected(session, HttpStatusCode.BadRequest, Post, "/internal/api/security/logout", csrf: "", code: "csrf_invalid");
        using (var me = await session.Send(Get, "/internal/api/security/me")) Assert.Equal(HttpStatusCode.OK, me.StatusCode);
        Assert.Equal(before, await f.Fingerprint());

        // Same account, real logout/login, same antiforgery cookie: a role or auth failure is not CSRF proof.
        var cashier = f.Staff["cashier"];
        var oldSession = await f.Scalar($"SELECT Id FROM savia_internal.Sessions WHERE StaffId='{cashier.Id}' AND RevokedAt IS NULL");
        var originalCsrfCookie = session.CookieHeader.Split("; ").Single(x => x.StartsWith("__Host-Savia.Csrf=", StringComparison.Ordinal));
        using (var logout = await session.Send(Post, "/internal/api/security/logout", csrf: cashierToken)) Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);
        await Login(session, cashier.LoginName);
        var newSession = await f.Scalar($"SELECT Id FROM savia_internal.Sessions WHERE StaffId='{cashier.Id}' AND RevokedAt IS NULL");
        Assert.NotEqual(oldSession, newSession);
        Assert.Equal("1", await f.Scalar($"SELECT COUNT(*) FROM savia_internal.Sessions WHERE Id='{oldSession}' AND RevokedAt IS NOT NULL"));
        Assert.Equal("1", await f.Scalar($"SELECT COUNT(*) FROM savia_internal.Sessions WHERE Id='{newSession}' AND SecurityVersion='{cashier.SecurityVersion}' AND RevokedAt IS NULL AND ExpiresAt>SYSUTCDATETIME()"));
        Assert.Contains(originalCsrfCookie, session.CookieHeader.Split("; "));
        using (var me = await session.Send(Get, "/internal/api/security/me"))
            Assert.Equal(cashier.Id, (await Json(me, HttpStatusCode.OK)).GetProperty("id").GetGuid());
        var sameBody = f.SaleBody(f.LocationA);
        var sameKey = Key();
        var stockBefore = int.Parse(await f.Scalar($"SELECT OnHand FROM savia_internal.StockBalances WHERE ItemId='{f.Database.Item}' AND LocationId='{f.LocationA}'"), CultureInfo.InvariantCulture);
        var sameBefore = await f.Fingerprint();
        await Rejected(session, HttpStatusCode.BadRequest, Post, "/internal/api/commerce/sales", sameBody, key: sameKey, csrf: cashierToken, code: "csrf_invalid");
        Assert.Equal(sameBefore, await f.Fingerprint());
        cashierToken = await Csrf(session);
        Guid sameSale;
        using (var sale = await session.Send(Post, "/internal/api/commerce/sales", sameBody, cashierToken, sameKey))
        {
            var receipt = await Json(sale, HttpStatusCode.OK);
            sameSale = receipt.GetProperty("saleId").GetGuid();
            Assert.Equal(cashier.Id, receipt.GetProperty("actorId").GetGuid());
            Assert.Equal(f.LocationA, receipt.GetProperty("locationId").GetGuid());
            var line = Assert.Single(receipt.GetProperty("lines").EnumerateArray());
            Assert.Equal(1, line.GetProperty("quantity").GetInt32());
        }
        Assert.Equal("1", await f.Scalar($"SELECT COUNT(*) FROM savia_internal.Sales WHERE Id='{sameSale}' AND ActorId='{cashier.Id}' AND LocationId='{f.LocationA}' AND EXISTS (SELECT 1 FROM savia_internal.Locations WHERE Id=Sales.LocationId AND BranchId='{f.BranchA}')"));
        Assert.Equal("1", await f.Scalar($"SELECT COUNT(*) FROM savia_internal.SaleLines WHERE SaleId='{sameSale}' AND ItemId='{f.Database.Item}' AND Quantity=1 AND UnitPriceMinor=(SELECT UnitPriceMinor FROM savia_internal.Items WHERE Id='{f.Database.Item}') AND TotalMinor=UnitPriceMinor"));
        Assert.Equal("1", await f.Scalar($"SELECT COUNT(*) FROM savia_internal.StockMovements m JOIN savia_internal.Operations o ON o.Id=m.OperationId WHERE o.[Key]='{sameKey}' AND o.ActorId='{cashier.Id}' AND o.LocationId='{f.LocationA}' AND o.OriginalBranchId='{f.BranchA}' AND m.ItemId='{f.Database.Item}' AND m.LocationId='{f.LocationA}' AND m.ActorId='{cashier.Id}' AND m.OnHandDelta=-1 AND m.ReservedDelta=0 AND m.OnHandAfter={stockBefore - 1}"));
        var sameAfter = await f.Fingerprint();
        foreach (var table in new[] { "Sales", "SaleLines", "StockMovements", "Operations" })
            Assert.Equal(Count(sameBefore, table) + 1, Count(sameAfter, table));
        Assert.Equal(sameBefore.Where(x => x.Key is not ("Sales" or "SaleLines" or "StockMovements" or "Operations" or "StockBalances")),
            sameAfter.Where(x => x.Key is not ("Sales" or "SaleLines" or "StockMovements" or "Operations" or "StockBalances")));
        Assert.Equal((stockBefore - 1).ToString(CultureInfo.InvariantCulture), await f.Scalar($"SELECT OnHand FROM savia_internal.StockBalances WHERE ItemId='{f.Database.Item}' AND LocationId='{f.LocationA}'"));
        using (var replay = await session.Send(Post, "/internal/api/commerce/sales", sameBody, cashierToken, sameKey))
            Assert.Equal(sameSale, (await Json(replay, HttpStatusCode.OK)).GetProperty("saleId").GetGuid());
        Assert.Equal(sameAfter, await f.Fingerprint());

        using (var directoryOwner = await f.Login("owner"))
        {
            var oldOwnerToken = await Csrf(directoryOwner);
            var ownerId = f.Staff["owner"].Id;
            var ownerS1 = await f.Scalar($"SELECT Id FROM savia_internal.Sessions WHERE StaffId='{ownerId}' AND RevokedAt IS NULL");
            var ownerCookie = directoryOwner.CookieHeader.Split("; ").Single(x => x.StartsWith("__Host-Savia.Csrf=", StringComparison.Ordinal));
            using (var logout = await directoryOwner.Send(Post, "/internal/api/security/logout", csrf: oldOwnerToken)) Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);
            await Login(directoryOwner, f.Staff["owner"].LoginName);
            var ownerS2 = await f.Scalar($"SELECT Id FROM savia_internal.Sessions WHERE StaffId='{ownerId}' AND RevokedAt IS NULL");
            Assert.NotEqual(ownerS1, ownerS2);
            Assert.Equal("1", await f.Scalar($"SELECT COUNT(*) FROM savia_internal.Sessions WHERE Id='{ownerS2}' AND SecurityVersion='{f.Staff["owner"].SecurityVersion}' AND RevokedAt IS NULL AND ExpiresAt>SYSUTCDATETIME()"));
            Assert.Equal("1", await f.Scalar($"SELECT COUNT(*) FROM savia_internal.Sessions WHERE Id='{ownerS1}' AND RevokedAt IS NOT NULL"));
            Assert.Contains(ownerCookie, directoryOwner.CookieHeader.Split("; "));
            var itemBody = new { sku = "N8-SESSION-BOUND", name = "Synthetic session item", unitPriceMinor = 100, currency = "USD" };
            var itemKey = Key();
            var directoryBefore = await f.Fingerprint();
            await Rejected(directoryOwner, HttpStatusCode.BadRequest, Post, "/internal/api/directory/items", itemBody, key: itemKey, csrf: oldOwnerToken, code: "invalid_csrf");
            Assert.Equal(directoryBefore, await f.Fingerprint());
            var fresh = await Csrf(directoryOwner);
            Guid itemId;
            using (var created = await directoryOwner.Send(Post, "/internal/api/directory/items", itemBody, fresh, itemKey))
                itemId = (await Json(created, HttpStatusCode.Created)).GetProperty("id").GetGuid();
            Assert.Equal("1", await f.Scalar($"SELECT COUNT(*) FROM savia_internal.Items WHERE Id='{itemId}' AND Sku='N8-SESSION-BOUND' AND Name='Synthetic session item' AND UnitPriceMinor=100 AND Currency='USD' AND Active=1"));
            Assert.Equal("1", await f.Scalar($"SELECT COUNT(*) FROM savia_internal.Operations WHERE [Key]='{itemKey}' AND ActorId='{ownerId}' AND Scope='directory.items.create'"));
            var directoryAfter = await f.Fingerprint();
            Assert.Equal(Count(directoryBefore, "Items") + 1, Count(directoryAfter, "Items"));
            Assert.Equal(Count(directoryBefore, "Operations") + 1, Count(directoryAfter, "Operations"));
            Assert.Equal(directoryBefore.Where(x => x.Key is not ("Items" or "Operations")), directoryAfter.Where(x => x.Key is not ("Items" or "Operations")));
            using (var replay = await directoryOwner.Send(Post, "/internal/api/directory/items", itemBody, fresh, itemKey))
                Assert.Equal(itemId, (await Json(replay, HttpStatusCode.Created)).GetProperty("id").GetGuid());
            Assert.Equal(directoryAfter, await f.Fingerprint());
        }

        // Identity change on the same browser: the previous user's token must not authorize the new user.
        using (var logout = await session.Send(Post, "/internal/api/security/logout", csrf: cashierToken)) Assert.Equal(HttpStatusCode.NoContent, logout.StatusCode);
        await Login(session, f.Staff["manager"].LoginName);
        using var owner = await f.Login("owner");
        var ownerToken = await Csrf(owner);
        var changed = await f.Fingerprint();
        await Rejected(session, HttpStatusCode.BadRequest, Post, "/internal/api/commerce/sales", f.SaleBody(f.LocationA), csrf: cashierToken, code: "csrf_invalid");
        await Rejected(session, HttpStatusCode.BadRequest, Post, "/internal/api/commerce/sales", f.SaleBody(f.LocationA), csrf: ownerToken, code: "csrf_invalid");
        await Rejected(owner, HttpStatusCode.BadRequest, Post, "/internal/api/security/staff",
            new { loginName = "n8.created.staff", displayName = "Synthetic N8", role = "Cashier", password = "synthetic-n8-input-only" }, csrf: "", code: "csrf_invalid");
        await Rejected(owner, HttpStatusCode.BadRequest, Post, "/internal/api/directory/items",
            new { sku = "N8-SYNTHETIC", name = "Synthetic N8 item", unitPriceMinor = 100, currency = "USD" }, csrf: cashierToken, code: "invalid_csrf");
        await Rejected(owner, HttpStatusCode.BadRequest, Post, "/internal/api/supply/purchase-orders", f.PurchaseBody(f.LocationA), csrf: "", code: "csrf_invalid");
        Assert.Equal(changed, await f.Fingerprint());

        // A valid pair still works: exactly one sale, one line, one movement and one operation by the CURRENT user.
        using (var sale = await session.Send(Post, "/internal/api/commerce/sales", f.SaleBody(f.LocationA), await Csrf(session), Key()))
        {
            var receipt = await Json(sale, HttpStatusCode.OK);
            Assert.Equal(f.Staff["manager"].Id, receipt.GetProperty("actorId").GetGuid());
            Assert.Equal(new[] { $"{f.Staff["manager"].Id}|{f.LocationA}".ToUpperInvariant() }, await f.Rows(
                $"SELECT CONVERT(varchar(36),ActorId)+'|'+CONVERT(varchar(36),LocationId) FROM savia_internal.Sales WHERE Id='{receipt.GetProperty("saleId").GetGuid()}'"));
        }
        var after = await f.Fingerprint();
        foreach (var table in new[] { "Sales", "SaleLines", "StockMovements", "Operations" })
            Assert.Equal(Count(changed, table) + 1, Count(after, table));
        Assert.Equal(changed.Where(x => x.Key is not ("Sales" or "SaleLines" or "StockMovements" or "Operations" or "StockBalances")),
            after.Where(x => x.Key is not ("Sales" or "SaleLines" or "StockMovements" or "Operations" or "StockBalances")));
    }

    [InternalJudgeHttpSqlFact]
    public async Task N9_owner_adjustment_keeps_reason_actor_and_movement_while_cashier_same_action_changes_nothing()
    {
        await using var f = await AcceptanceFixture.Create();
        using var cashier = await f.Login("cashier");
        using var owner = await f.Login("owner");
        const string reason = "Synthetic N9 count correction";
        var body = f.AdjustBody(f.LocationA, reason);
        var before = await f.Fingerprint();
        await Rejected(cashier, HttpStatusCode.Forbidden, Post, "/internal/api/commerce/adjustments", body);
        Assert.Equal(before, await f.Fingerprint());

        var onHand = int.Parse(await f.Scalar($"SELECT OnHand FROM savia_internal.StockBalances WHERE ItemId='{f.Database.Item}' AND LocationId='{f.LocationA}'"));
        var key = Key();
        Guid adjustmentId;
        using (var response = await owner.Send(Post, "/internal/api/commerce/adjustments", body, await Csrf(owner), key))
        {
            var receipt = await Json(response, HttpStatusCode.OK);
            adjustmentId = receipt.GetProperty("adjustmentId").GetGuid();
            Assert.Equal(reason, receipt.GetProperty("reason").GetString());
            Assert.Equal(f.Database.Actor, receipt.GetProperty("actorId").GetGuid());
        }
        // Independent SQL readback of the ledger: adjustment, its movement, the balance and the operation identity.
        Assert.Equal(new[] { $"{reason}|{f.Database.Actor}|{f.LocationA}|3".ToUpperInvariant() }, (await f.Rows(
            $"SELECT Reason+'|'+CONVERT(varchar(36),ActorId)+'|'+CONVERT(varchar(36),LocationId)+'|'+CONVERT(varchar(10),OnHandDelta) FROM savia_internal.StockAdjustments WHERE Id='{adjustmentId}'"))
            .Select(x => x.ToUpperInvariant()));
        Assert.Equal(new[] { $"adjustment|{f.Database.Actor}|{f.LocationA}|3|{onHand + 3}".ToUpperInvariant() }, (await f.Rows(
            $"SELECT Kind+'|'+CONVERT(varchar(36),ActorId)+'|'+CONVERT(varchar(36),LocationId)+'|'+CONVERT(varchar(10),OnHandDelta)+'|'+CONVERT(varchar(10),OnHandAfter) FROM savia_internal.StockMovements WHERE OperationId='{adjustmentId}'"))
            .Select(x => x.ToUpperInvariant()));
        Assert.Equal((onHand + 3).ToString(CultureInfo.InvariantCulture),
            await f.Scalar($"SELECT OnHand FROM savia_internal.StockBalances WHERE ItemId='{f.Database.Item}' AND LocationId='{f.LocationA}'"));
        Assert.Equal(new[] { $"commerce.stock.adjust|{f.LocationA}|{f.BranchA}".ToUpperInvariant() }, (await f.Rows(
            $"SELECT Scope+'|'+CONVERT(varchar(36),LocationId)+'|'+CONVERT(varchar(36),OriginalBranchId) FROM savia_internal.Operations WHERE ActorId='{f.Database.Actor}' AND [Key]='{key}'"))
            .Select(x => x.ToUpperInvariant()));
        var after = await f.Fingerprint();
        foreach (var table in new[] { "StockAdjustments", "StockMovements", "Operations" })
            Assert.Equal(Count(before, table) + 1, Count(after, table));

        // Replay returns the same adjustment without a second effect; the cashier still cannot do it after the Owner did.
        using (var replay = await owner.Send(Post, "/internal/api/commerce/adjustments", body, await Csrf(owner), key))
            Assert.Equal(adjustmentId, (await Json(replay, HttpStatusCode.OK)).GetProperty("adjustmentId").GetGuid());
        await Rejected(cashier, HttpStatusCode.Forbidden, Post, "/internal/api/commerce/adjustments", body, key: key);
        Assert.Equal(after, await f.Fingerprint());
    }

    // ---- helpers ----

    private static string Key() => "acc-" + Guid.NewGuid().ToString("N");

    // Sends with a VALID CSRF pair and a fresh idempotency key unless told otherwise, so the rejection is the guard under test.
    private static async Task Rejected(HttpSession session, HttpStatusCode status, HttpMethod method, string path, object? body = null,
        string? key = null, string? csrf = null, string? code = null)
    {
        var token = csrf ?? (method == Get ? null : await Csrf(session));
        using var response = await session.Send(method, path, body, token == "" ? null : token, key ?? (method == Get ? null : Key()));
        var text = await response.Content.ReadAsStringAsync();
        Assert.True(status == response.StatusCode, $"{method} {path}: expected {(int)status}, received {(int)response.StatusCode}.");
        if (code is not null) Assert.Contains($"\"{code}\"", text);
        Assert.DoesNotContain("unitCost", text, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("saleId", text, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("passwordHash", text, StringComparison.OrdinalIgnoreCase);
    }

    private static void AssertNoLeak(string body, params Guid[] foreign)
    {
        Assert.DoesNotContain("unitCost", body, StringComparison.OrdinalIgnoreCase);
        foreach (var id in foreign) Assert.DoesNotContain(id.ToString(), body, StringComparison.OrdinalIgnoreCase);
    }

    private static async Task<JsonElement> Json(HttpResponseMessage response, HttpStatusCode status)
    {
        Assert.Equal(status, response.StatusCode);
        return await response.Content.ReadFromJsonAsync<JsonElement>();
    }

    private static async Task<JsonElement> Page(HttpSession session, string path, int total)
    {
        using var response = await session.Send(Get, path);
        var page = await Json(response, HttpStatusCode.OK);
        Assert.True(total == page.GetProperty("total").GetInt32(), $"{path}: expected total {total}, received {page.GetProperty("total").GetInt32()}.");
        return page;
    }

    private static int Count(IEnumerable<KeyValuePair<string, string>> fingerprint, string table) =>
        int.Parse(fingerprint.Single(x => x.Key == table).Value.Split(':')[0], CultureInfo.InvariantCulture);

    // Scope oracle in plain SQL: Owner sees all; others only rows whose location belongs to their own active branch.
    private static string VisibleSql(Guid actor, string select) => select + $"""
         JOIN savia_internal.Staff s ON s.Id='{actor}' AND s.Enabled=1
         WHERE s.Role='Owner' OR (s.BranchId IS NOT NULL AND EXISTS (SELECT 1 FROM savia_internal.Branches b WHERE b.Id=s.BranchId AND b.Active=1)
            AND EXISTS (SELECT 1 FROM savia_internal.Locations l WHERE l.Id={(select.Contains("Locations x") ? "x.Id" : "x.LocationId")} AND l.BranchId=s.BranchId))
        """;

    internal sealed class AcceptanceFixture : IAsyncDisposable
    {
        public const string OwnerSaleAKey = "acc-owner-sale-a-0001", OwnerSaleBKey = "acc-owner-sale-b-0001";
        public InternalCommerceSqlDatabase Database { get; }
        public JudgeFactory Factory { get; private set; } = null!;
        public Guid BranchA { get; } = Guid.NewGuid();
        public Guid BranchB { get; } = Guid.NewGuid();
        public Guid LocationA => Database.Location;
        public Guid LocationB { get; } = Guid.NewGuid();
        public Guid Supplier { get; } = Guid.NewGuid();
        public Guid SaleA { get; private set; }
        public Guid SaleB { get; private set; }
        public Guid SaleALine { get; private set; }
        public Guid SaleBLine { get; private set; }
        public Guid PurchaseA { get; private set; }
        public Guid PurchaseB { get; private set; }
        public Guid PurchaseALine { get; private set; }
        public Guid PurchaseBLine { get; private set; }
        public Dictionary<string, InternalStaff> Staff { get; } = new(StringComparer.Ordinal);
        private string connection = "";

        private AcceptanceFixture(InternalCommerceSqlDatabase database) => Database = database;

        public static async Task<AcceptanceFixture> Create()
        {
            var f = new AcceptanceFixture(await InternalCommerceSqlDatabase.Create(migrate: true));
            try
            {
                f.connection = await PrepareHttpFixture(f.Database);
                await using (var db = f.Database.Context())
                {
                    db.Set<InternalBranch>().AddRange(new InternalBranch { Id = f.BranchA, Name = "Synthetic branch A", Active = true },
                        new InternalBranch { Id = f.BranchB, Name = "Synthetic branch B", Active = true });
                    await db.SaveChangesAsync();
                    (await db.Set<InternalLocation>().SingleAsync(x => x.Id == f.LocationA)).BranchId = f.BranchA;
                    db.Set<InternalLocation>().Add(new() { Id = f.LocationB, Name = "Synthetic location B", Active = true, BranchId = f.BranchB });
                    var now = DateTimeOffset.UtcNow;
                    var hasher = new PasswordHasher<InternalStaff>();
                    foreach (var (key, role, branch) in new[] { ("manager", "Manager", (Guid?)f.BranchA), ("cashier", "Cashier", f.BranchA),
                        ("inventory", "Inventory", f.BranchA), ("unassigned", "Manager", null) })
                    {
                        var staff = new InternalStaff { Id = Guid.NewGuid(), LoginName = "acceptance." + key, NormalizedLoginName = ("acceptance." + key).ToUpperInvariant(),
                            DisplayName = "Synthetic " + key, Role = role, BranchId = branch, Enabled = true, SecurityVersion = Guid.NewGuid(), CreatedAt = now, UpdatedAt = now };
                        staff.PasswordHash = hasher.HashPassword(staff, HttpFixturePassword);
                        db.InternalStaff.Add(staff); f.Staff[key] = staff;
                    }
                    db.Set<InternalStockBalance>().AddRange(
                        new InternalStockBalance { ItemId = f.Database.Item, LocationId = f.LocationA, OnHand = 20, UpdatedAt = now },
                        new InternalStockBalance { ItemId = f.Database.SecondItem, LocationId = f.LocationA, OnHand = 5, UpdatedAt = now },
                        new InternalStockBalance { ItemId = f.Database.Item, LocationId = f.LocationB, OnHand = 9, UpdatedAt = now });
                    db.Set<InternalParty>().Add(new() { Id = f.Supplier, Kind = "supplier", Name = "Synthetic supplier", Active = true });
                    await db.SaveChangesAsync();
                    f.Staff["owner"] = await db.InternalStaff.AsNoTracking().SingleAsync(x => x.Id == f.Database.Actor);
                }
                f.Factory = new JudgeFactory(connection: f.connection);
                using var owner = await f.Login("owner");
                (f.SaleA, f.SaleALine) = await Sell(owner, f.SaleBody(f.LocationA), OwnerSaleAKey);
                (f.SaleB, f.SaleBLine) = await Sell(owner, f.SaleBody(f.LocationB), OwnerSaleBKey);
                (f.PurchaseA, f.PurchaseALine) = await Purchase(owner, f.PurchaseBody(f.LocationA));
                (f.PurchaseB, f.PurchaseBLine) = await Purchase(owner, f.PurchaseBody(f.LocationB));
                return f;
            }
            catch { await f.DisposeAsync(); throw; }
        }

        private static async Task<(Guid, Guid)> Sell(HttpSession owner, object body, string key)
        {
            using var response = await owner.Send(Post, "/internal/api/commerce/sales", body, await Csrf(owner), key);
            var receipt = await Json(response, HttpStatusCode.OK);
            return (receipt.GetProperty("saleId").GetGuid(), receipt.GetProperty("lines")[0].GetProperty("saleLineId").GetGuid());
        }

        private static async Task<(Guid, Guid)> Purchase(HttpSession owner, object body)
        {
            using var response = await owner.Send(Post, "/internal/api/supply/purchase-orders", body, await Csrf(owner), Key());
            var order = await Json(response, HttpStatusCode.OK);
            return (order.GetProperty("id").GetGuid(), order.GetProperty("lines")[0].GetProperty("id").GetGuid());
        }

        public object SaleBody(Guid location) => new { locationId = location, lines = new[] { new { itemId = Database.Item, quantity = 1 } } };
        public object AdjustBody(Guid location, string reason) => new { itemId = Database.Item, locationId = location, onHandDelta = 3, reason };
        public object PurchaseBody(Guid location) => new { supplierId = Supplier, locationId = location, currency = "USD",
            lines = new[] { new { itemId = Database.Item, quantity = 2, unitCostMinor = 7919L } } };

        public async Task<HttpSession> Login(string role)
        {
            var session = new HttpSession(Client(Factory));
            await InternalJudgeTests.Login(session, Staff[role].LoginName);
            return session;
        }

        public async Task<string[]> Rows(string sql)
        {
            await using var c = new SqlConnection(connection); await c.OpenAsync();
            await using var cmd = c.CreateCommand(); cmd.CommandText = sql;
            await using var reader = await cmd.ExecuteReaderAsync(); var rows = new List<string>();
            while (await reader.ReadAsync()) rows.Add(Format(reader.GetValue(0)));
            return rows.ToArray();
        }

        public async Task<string> Scalar(string sql) => Assert.Single(await Rows(sql));

        // count:SHA-256 of every row of every savia_internal table, read with plain ADO.NET (not EF, not the API).
        public async Task<SortedDictionary<string, string>> Fingerprint()
        {
            var result = new SortedDictionary<string, string>(StringComparer.Ordinal);
            await using var c = new SqlConnection(connection); await c.OpenAsync();
            var tables = new List<string>();
            await using (var cmd = c.CreateCommand())
            {
                cmd.CommandText = "SELECT name FROM sys.tables WHERE schema_id=SCHEMA_ID('savia_internal') ORDER BY name";
                await using var reader = await cmd.ExecuteReaderAsync();
                while (await reader.ReadAsync()) tables.Add(reader.GetString(0));
            }
            InternalAcceptanceFingerprint.AssertTables(tables);
            foreach (var table in tables)
            {
                await using var cmd = c.CreateCommand();
                cmd.CommandText = $"SELECT * FROM [savia_internal].[{table}]";
                await using var reader = await cmd.ExecuteReaderAsync();
                var rows = new List<string>();
                while (await reader.ReadAsync())
                    rows.Add(string.Join("|", Enumerable.Range(0, reader.FieldCount).Select(i => reader.GetName(i) + "=" + Format(reader.GetValue(i)))));
                rows.Sort(StringComparer.Ordinal);
                result[table] = rows.Count.ToString(CultureInfo.InvariantCulture) + ":" +
                    Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(string.Join("\n", rows))));
            }
            return result;
        }

        private static string Format(object value) => value switch
        {
            DBNull => "NULL",
            byte[] bytes => "0x" + Convert.ToHexString(bytes),
            DateTimeOffset at => at.ToString("O", CultureInfo.InvariantCulture),
            _ => Convert.ToString(value, CultureInfo.InvariantCulture) ?? ""
        };

        public async ValueTask DisposeAsync()
        {
            if (Factory is not null) await Factory.DisposeAsync();
            await Database.DisposeAsync();
        }
    }
}
