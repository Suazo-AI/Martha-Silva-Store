using System.Net;
using System.Net.Http.Json;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Tests;

/// <summary>D0 and D1: the hub owner creates a supplier and a till operator creates a customer over HTTP, without SQL.</summary>
public sealed class DayZeroRoutesTests : IAsyncLifetime
{
    private string _database = "";

    public async Task InitializeAsync() => _database = await TestSql.CloneAsync("dayzero");

    public async Task DisposeAsync() => await TestSql.DropAsync(_database);

    [Fact]
    public async Task Hub_creates_a_supplier_once_and_a_store_with_a_hub_refuses_by_name()
    {
        await using var hub = new SaviaNode(_database, NodeKind.Cloud, Ids.NodeCloud, null, null);
        var owner = await hub.SignInAsync(Ids.Manager, "t_manager");
        var supplier = new CreateSupplierRequest(Guid.NewGuid(), "Proveedor día cero");
        await HttpAssert.OkAsync(await owner.PostAsJsonAsync("/api/v1/suppliers", supplier));
        await HttpAssert.OkAsync(await owner.PostAsJsonAsync("/api/v1/suppliers", supplier));
        await HttpAssert.ProblemAsync(await owner.PostAsJsonAsync("/api/v1/suppliers", supplier with { Name = "Otro" }),
            HttpStatusCode.Conflict, "input.id_reused");
        await HttpAssert.ProblemAsync(await owner.PostAsJsonAsync("/api/v1/suppliers", supplier with { Name = " " }),
            HttpStatusCode.UnprocessableEntity, "input.text");
        Assert.Equal(1, await TestSql.ScalarAsync<int>(_database,
            $"SELECT COUNT(*) FROM sourcing.Suppliers WHERE Id='{supplier.SupplierId}' AND CreatedBy='{Ids.Manager}'"));

        await using var store = new SaviaNode(_database, NodeKind.Branch, Ids.NodeA, Ids.BranchA, Ids.LocA,
            new Dictionary<string, string?> { ["Savia:Sync:NodeSecret"] = "test-only" });
        var manager = await store.SignInAsync(Ids.Manager, "t_manager");
        await HttpAssert.ProblemAsync(await manager.PostAsJsonAsync("/api/v1/suppliers", supplier with { SupplierId = Guid.NewGuid() }),
            HttpStatusCode.Conflict, "catalog.managed_by_hub");
    }

    [Fact]
    public async Task A_cashier_creates_a_customer_once_and_finds_it()
    {
        await using var store = new SaviaNode(_database, NodeKind.Branch, Ids.NodeA, Ids.BranchA, Ids.LocA);
        var cashier = await store.SignInAsync(Ids.CashierA, "t_cashier_a");
        var customer = new CreateCustomerRequest(Guid.NewGuid(), "Clienta Día Cero", "001-010190-0001A", "8888-0000",
            "clienta.dz@example.test");
        await HttpAssert.OkAsync(await cashier.PostAsJsonAsync("/api/v1/customers", customer));
        await HttpAssert.OkAsync(await cashier.PostAsJsonAsync("/api/v1/customers", customer));
        await HttpAssert.ProblemAsync(await cashier.PostAsJsonAsync("/api/v1/customers", customer with { DisplayName = "Otra" }),
            HttpStatusCode.Conflict, "input.id_reused");
        var nameless = customer with { CustomerId = Guid.NewGuid(), DisplayName = "" };
        await HttpAssert.ProblemAsync(await cashier.PostAsJsonAsync("/api/v1/customers", nameless),
            HttpStatusCode.UnprocessableEntity, "input.text");

        var found = await HttpAssert.OkAsync<CustomerRow[]>(await cashier.GetAsync("/api/v1/customers?q=Clienta%20D%C3%ADa"));
        Assert.Equal(customer.CustomerId, Assert.Single(found).CustomerId);
        Assert.Equal(1, await TestSql.ScalarAsync<int>(_database,
            $"SELECT COUNT(*) FROM crm.Customers WHERE Id='{customer.CustomerId}' AND CreatedBy='{Ids.CashierA}'"));
    }

    [Fact]
    public async Task A_credit_moves_between_stores_over_http_and_each_step_runs_on_the_node_that_owns_it()
    {
        var credit = Guid.NewGuid();   // 120000 available at branch A (test.SeedCredit: sale and credit return)
        await TestSql.ScalarAsync<int>(_database, $"EXEC test.SeedCredit '{credit}'; SELECT 1;");
        await using var hub = new SaviaNode(_database, NodeKind.Cloud, Ids.NodeCloud, null, null);
        await using var storeA = SaviaNode.BranchA(_database);
        await using var storeB = new SaviaNode(_database, NodeKind.Branch, Ids.NodeB, Ids.BranchB, Ids.LocB);
        var manager = await hub.SignInAsync(Ids.Manager, "t_manager");
        var cashierA = await storeA.SignInAsync(Ids.CashierA, "t_cashier_a");
        var cashierB = await storeB.SignInAsync(Ids.CashierB, "t_cashier_b");

        // The customer asks at B for 50000 of the credit B does not hold.
        var request = new RequestCreditTransferRequest(Guid.NewGuid(), credit, Ids.BranchA, Ids.BranchB, 50000, "Canje en B");
        await HttpAssert.OkAsync(await cashierB.PostAsJsonAsync("/api/v1/credit-transfers", request));
        await HttpAssert.OkAsync(await cashierB.PostAsJsonAsync("/api/v1/credit-transfers", request));
        // The hub only lists transfers at this path: a request there is not a route (405), so it never reaches SQL.
        Assert.Equal(HttpStatusCode.MethodNotAllowed, (await manager.PostAsJsonAsync("/api/v1/credit-transfers", request)).StatusCode);
        var path = $"/api/v1/credit-transfers/{request.TransferId}";
        await HttpAssert.ProblemAsync(await cashierA.PostAsync($"{path}/dispatch", null), HttpStatusCode.Conflict,
            "credit.transfer_not_approved");
        Assert.Equal(HttpStatusCode.NotFound, (await cashierA.PostAsync($"{path}/approve", null)).StatusCode);

        await HttpAssert.OkAsync(await manager.PostAsync($"{path}/approve", null));
        await HttpAssert.OkAsync(await cashierA.PostAsync($"{path}/dispatch", null));
        var inTransit = await HttpAssert.OkAsync<CreditTransferRow[]>(await cashierB.GetAsync("/api/v1/credit-transfers"));
        Assert.Equal(("in_transit", "Clienta Test", 50000L), Single(inTransit, request.TransferId));
        await HttpAssert.OkAsync(await cashierB.PostAsync($"{path}/receive", null));
        await HttpAssert.OkAsync(await cashierB.PostAsync($"{path}/receive", null));
        Assert.Equal("A:70000 B:50000", await TestSql.ScalarAsync<string>(_database,
            $"SELECT STRING_AGG(CONCAT(b.Code,':',a.AvailableMinor),' ') WITHIN GROUP (ORDER BY b.Code) FROM credits.CreditAllocations a " +
            $"JOIN (VALUES('{Ids.BranchA}','A'),('{Ids.BranchB}','B')) b(Id,Code) ON b.Id=a.BranchId WHERE a.CreditId='{credit}'"));

        // A second request is cancelled on the hub before the dispatch: then A cannot dispatch it.
        var second = request with { TransferId = Guid.NewGuid(), AmountMinor = 10000 };
        await HttpAssert.OkAsync(await cashierB.PostAsJsonAsync("/api/v1/credit-transfers", second));
        var secondPath = $"/api/v1/credit-transfers/{second.TransferId}";
        await HttpAssert.ProblemAsync(await manager.PostAsJsonAsync($"{secondPath}/cancel", new CancelCreditTransferRequest(" ")),
            HttpStatusCode.UnprocessableEntity, "input.text");
        await HttpAssert.OkAsync(await manager.PostAsJsonAsync($"{secondPath}/cancel", new CancelCreditTransferRequest("Ya no se necesita")));
        await HttpAssert.ProblemAsync(await cashierA.PostAsync($"{secondPath}/dispatch", null), HttpStatusCode.Conflict,
            "credit.transfer_cancelled");
        var onHub = await HttpAssert.OkAsync<CreditTransferRow[]>(await manager.GetAsync("/api/v1/credit-transfers"));
        Assert.Equal("received cancelled", string.Join(' ', new[] { request.TransferId, second.TransferId }
            .Select(id => onHub.Single(row => row.TransferId == id).Status)));
    }

    private static (string, string, long) Single(CreditTransferRow[] rows, Guid id) =>
        rows.Where(row => row.TransferId == id).Select(row => (row.Status, row.CustomerName, row.AmountMinor)).Single();
}
