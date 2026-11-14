using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using Savia.Contracts;

namespace Savia.Tests;

public sealed partial class PilotSalesTests
{
    [Fact]
    public async Task All_tenders_customer_credit_search_redemption_and_day_accounting_are_real_sql()
    {
        var till = await OpenTill();
        var customers = await HttpAssert.OkAsync<CustomerRow[]>(await _cashier.GetAsync("/api/v1/customers?q=Cli%C3%A9nta"));
        Assert.Contains(customers, c => c.CustomerId == Customer);
        await HttpAssert.ProblemAsync(await _cashier.GetAsync("/api/v1/customers?q=x"), HttpStatusCode.UnprocessableEntity, "customer.search_too_short");
        await HttpAssert.ProblemAsync(await _cashier.GetAsync("/api/v1/credits/search?q=x"), HttpStatusCode.UnprocessableEntity, "credit.search_too_short");
        var sale = await Sale(till);
        var detail = await HttpAssert.OkAsync<SaleDetailResponse>(await _cashier.GetAsync($"/api/v1/sales/{sale}"));
        var ret = new PostCreditReturnRequest(Guid.NewGuid(), Guid.NewGuid(), till, Customer, "MUESTRA", [new(detail.Lines[0].SaleLineId, 1, "store")]);
        await HttpAssert.OkAsync(await _supervisor.PostAsJsonAsync($"/api/v1/sales/{sale}/returns/credit", ret));
        var credits = await HttpAssert.OkAsync<CustomerCreditRow[]>(await _cashier.GetAsync("/api/v1/credits/search?q=Clienta"));
        Assert.Equal(120000L, Assert.Single(credits, c => c.CreditId == ret.CreditId).AvailableMinor);
        var mixedId = await Sale(till, 1, [new(1, "card", 30000, Reference: "AUTH-MUESTRA"),
            new(2, "transfer", 30000, Reference: "TRANSFER-MUESTRA"), new(3, "other", 30000, Reference: "OTRO-MUESTRA"), new(4, "credit", 30000,
                CreditId: ret.CreditId)]);
        var mixed = await HttpAssert.OkAsync<SaleDetailResponse>(await _cashier.GetAsync($"/api/v1/sales/{mixedId}"));
        Assert.Equal(4, mixed.Tenders.Length); Assert.Contains(mixed.Tenders, t => t.Reference == "AUTH-MUESTRA");
        Assert.Equal(90000L, Assert.Single(await HttpAssert.OkAsync<CustomerCreditRow[]>(await _cashier.GetAsync("/api/v1/credits/search?q=Clienta")),
            c => c.CreditId == ret.CreditId).AvailableMinor);
        var insufficient = new PostSaleRequest(Guid.NewGuid(), till, "NIO", [new(1, Ids.Item, 1, 120000)], [new(1, "credit", 120000,
            CreditId: ret.CreditId)], Customer);
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync("/api/v1/sales", insufficient), HttpStatusCode.Conflict, "credit.insufficient");
        await HttpAssert.ProblemAsync(await _node.CreateClient().PostAsJsonAsync("/api/v1/sales", insufficient), HttpStatusCode.Unauthorized, "auth.required");
        // A transfer needs a reference. The external card POS voucher is optional by owner decision.
        foreach (var kind in new[] { "transfer" })
            await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync("/api/v1/sales", insufficient with
            { SaleId = Guid.NewGuid(), Tenders = [new(1, kind, 120000)] }), HttpStatusCode.UnprocessableEntity, "rule.51509");
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync("/api/v1/sales", insufficient with
        {
            SaleId = Guid.NewGuid(),
            CustomerId = new Guid("00000000-0000-0000-0000-00000000C052"),
            Tenders = [new(1, "credit", 120000,
            CreditId: ret.CreditId)]
        }),
            HttpStatusCode.Conflict, "credit.customer_or_currency");
        await HttpAssert.ProblemAsync(await _cashier.PostAsJsonAsync("/api/v1/sales", insufficient with
        { SaleId = Guid.NewGuid(), Tenders = [new(1, "card", 120000, Reference: new string('x', 121))] }), HttpStatusCode.UnprocessableEntity, "input.text");
        await HttpAssert.ProblemAsync(await _cashier.GetAsync($"/api/v1/reports/day?date={Today}"), HttpStatusCode.Forbidden, "auth.role_required");
        var report = await HttpAssert.OkAsync<DayReport>(await _supervisor.GetAsync($"/api/v1/reports/day?date={Today}"));
        Assert.Equal((2, 3L, 360000L), (report.SalesCount, report.UnitsSold, Assert.Single(report.Totals).TotalMinor));
        Assert.Equal(5, report.Tenders.Length); Assert.Equal(120000L, Assert.Single(report.Returns).CreditMinor);
        Assert.Equal(3L, Assert.Single(report.TopItems).UnitsSold); Assert.Null(Assert.Single(report.Tills).CountedMinor);
        var count = new RecordCashCountRequest(Guid.NewGuid(), [new(10000, 34)], UsdCashCountId: Guid.NewGuid(), UsdLines: [new(100, 0)]);
        await HttpAssert.OkAsync(await _cashier.PostAsJsonAsync($"/api/v1/cash/tills/{till}/counts", count));
        await HttpAssert.OkAsync(await _supervisor.PostAsJsonAsync($"/api/v1/cash/tills/{till}/close", new CloseTillRequest(Guid.NewGuid(),
            count.CashCountId, count.UsdCashCountId)));
        report = await HttpAssert.OkAsync<DayReport>(await _supervisor.GetAsync($"/api/v1/reports/day?date={Today}"));
        var closed = Assert.Single(report.Tills);
        Assert.Equal(("closed", 340000L, 340000L, 0L, 360000L, 120000L, 240000L), (closed.Status, closed.ExpectedMinor, closed.CountedMinor,
            closed.DifferenceMinor, closed.SaleGrossMinor, closed.ReturnGrossMinor, closed.NetSalesMinor));
        Assert.NotNull(closed.AccountingDocumentId);
        var empty = await HttpAssert.OkAsync<DayReport>(await _supervisor.GetAsync("/api/v1/reports/day?date=2000-01-01"));
        Assert.Equal(0, empty.SalesCount); Assert.Empty(empty.Tills); Assert.Empty(empty.Totals);
        await TestSql.AssertConservationAsync(_db);
    }
}
