using System.Text.Json;
using Martha.Store.Api.Internal;
using Microsoft.EntityFrameworkCore;
using Xunit;
namespace Martha.Store.Api.Tests;
// Prepared real persistence checks. Never enabled by an offline unit pass.
public sealed class InternalStockExceptionSqlTests
{
    static InternalSaleRequest Request(InternalCommerceSqlDatabase f, int quantity = 2) => new(f.Location, null, [new(f.Item, quantity, "physical garment present", "S")]);
    [InternalCommerceSqlFact]
    public async Task Concurrent_retry_conflict_return_and_cancel_do_not_invent_inventory()
    {
        await using var f = await InternalCommerceSqlDatabase.Create(true);
        var request = Request(f);
        var results = await Task.WhenAll(f.Execute(s=>s.RecordSale(request,f.Actor,"exception-replay-0001",default)),f.Execute(s=>s.RecordSale(request,f.Actor,"exception-replay-0001",default)));
        Assert.All(results,r=>Assert.True(r.Success));
        Assert.Equal(JsonSerializer.Serialize(results[0]),JsonSerializer.Serialize(results[1]));
        var sale=results[0].Value!;var line=Assert.Single(sale.Lines);
        var conflict=await f.Execute(s=>s.RecordSale(Request(f,1),f.Actor,"exception-replay-0001",default));
        Assert.Equal("idempotency_conflict",conflict.Error);
        var ret=await f.Execute(s=>s.ReturnSale(sale.SaleId,new("physical return recorded",[new(line.SaleLineId,1)]),f.Actor,"exception-return-0001",default));
        Assert.True(ret.Success);Assert.Equal(125,ret.Value!.RecordedCreditMinor);
        var second=await f.Execute(s=>s.RecordSale(Request(f,1),f.Actor,"exception-sale-000002",default));
        var cancel=await f.Execute(s=>s.CancelSale(second.Value!.SaleId,new("entry cancelled"),f.Actor,"exception-cancel-0001",default));
        Assert.True(cancel.Success);
        await using var db=f.Context();
        Assert.Equal(2,await db.Set<InternalSale>().CountAsync());
        Assert.Equal(2,await db.Set<InternalSaleReversal>().CountAsync());
        Assert.False(await db.Set<InternalStockBalance>().AnyAsync());
        Assert.False(await db.Set<InternalStockMovement>().AnyAsync());
        Assert.False(await db.Set<InternalPurchaseReceipt>().AnyAsync());
    }
    [InternalCommerceSqlFact]
    public async Task Failed_later_ordinary_line_rolls_back_exception_and_self_review_rejected_for_owner()
    {
        await using var f=await InternalCommerceSqlDatabase.Create(true);
        var mixed=new InternalSaleRequest(f.Location,null,[new(f.Item,1,"physical garment present","S"),new(f.SecondItem,1)]);
        Assert.Equal("stock_unavailable",(await f.Execute(s=>s.RecordSale(mixed,f.Actor,"exception-rollback-01",default))).Error);
        await using(var db=f.Context()){Assert.False(await db.Set<InternalSaleLine>().AnyAsync());Assert.False(await db.Set<InternalStockMovement>().AnyAsync());}
        var sale=(await f.Execute(s=>s.RecordSale(Request(f),f.Actor,"exception-sale-000001",default))).Value!;
        var request=new InternalStockExceptionReviewRequest(sale.Lines.Single().SaleLineId,"count examined","cause unproven",f.Actor,DateTimeOffset.UtcNow.AddDays(1));
        Assert.Equal("different_reviewer_required",(await f.Execute(s=>s.ReviewStockException(sale.SaleId,request,f.Actor,"exception-review-001",default))).Error);
        await using var verify=f.Context();Assert.False(await verify.Set<InternalStockExceptionReview>().AnyAsync());
    }
    [InternalCommerceSqlFact]
    public async Task Substitute_reviewer_persists_open_evidence_and_response_loss_replay_is_single()
    {
        await using var f=await InternalCommerceSqlDatabase.Create(true);
        var sale=(await f.Execute(s=>s.RecordSale(Request(f),f.Actor,"exception-sale-000001",default))).Value!;
        var now=DateTimeOffset.UtcNow;
        var reviewer=new InternalStaff{Id=Guid.NewGuid(),LoginName="substitute",NormalizedLoginName="SUBSTITUTE",DisplayName="Synthetic substitute",PasswordHash="not-a-password-hash",Role="Owner",Enabled=true,SecurityVersion=Guid.NewGuid(),CreatedAt=now,UpdatedAt=now};
        var session=new InternalSession{Id=Guid.NewGuid(),StaffId=reviewer.Id,SecurityVersion=reviewer.SecurityVersion,CreatedAt=now,ExpiresAt=now.AddHours(1)};
        await using(var db=f.Context()){db.Add(reviewer);db.Add(session);await db.SaveChangesAsync();}
        var request=new InternalStockExceptionReviewRequest(sale.Lines.Single().SaleLineId,"sale and count examined","cause unproven",reviewer.Id,now.AddDays(1));
        var first=await f.Execute(s=>s.ReviewStockException(sale.SaleId,request,reviewer.Id,"exception-review-001",default),reviewer,session);
        Assert.True(first.Success);Assert.Equal("open",first.Value!.CauseState);
        var replay=await f.Execute(s=>s.ReviewStockException(sale.SaleId,request,reviewer.Id,"exception-review-001",default),reviewer,session);
        Assert.Equal(JsonSerializer.Serialize(first),JsonSerializer.Serialize(replay));
        var conflict=await f.Execute(s=>s.ReviewStockException(sale.SaleId,request with {Outcome="changed"},reviewer.Id,"exception-review-001",default),reviewer,session);
        Assert.Equal("idempotency_conflict",conflict.Error);
        await using var verify=f.Context();Assert.Single(await verify.Set<InternalStockExceptionReview>().ToListAsync());
        Assert.False(await verify.Set<InternalStockMovement>().AnyAsync());
    }
}
