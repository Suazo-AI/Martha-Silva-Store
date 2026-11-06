using System.Security.Claims;
using Martha.Store.Api.Internal;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Martha.Store.Api.Tests;
public sealed class InternalStockExceptionTests
{
    internal const string Migration = "20261106071201_PhysicalStockException";
    internal static IEnumerable<string?> Expected(IEnumerable<string?> original, string key) => original.Concat(key switch {
        "history" => [Migration], "tables" => ["StockExceptionReviews"],
        "checks" => ["CK_InternalSaleLine_Exception", "CK_InternalStockReview_Open", "CK_InternalStockReview_Next"],
        "foreign_keys" => ["FK_StockExceptionReviews_SaleLines_SaleLineId", "FK_StockExceptionReviews_Staff_ResponsibleActorId", "FK_StockExceptionReviews_Staff_ReviewerId"],
        "indexes" => ["IX_StockExceptionReviews_SaleLineId", "IX_StockExceptionReviews_ResponsibleActorId", "IX_StockExceptionReviews_ReviewerId"],
        "primary_keys" => ["PK_StockExceptionReviews"], _ => Array.Empty<string>() });
    [Theory]
    [InlineData(null,null,true)] [InlineData("physical garment", "S",true)]
    [InlineData("", "S",false)] [InlineData(" ","S",false)] [InlineData("physical garment",null,false)]
    [InlineData(null,"S",false)] [InlineData("physical garment"," ",false)] [InlineData("reason\nforged","S",false)]
    public void Exceptional_sale_requires_reason_and_size(string? reason,string? size,bool expected) =>
        Assert.Equal(expected,InternalCommerceRules.ValidSale(new(Guid.NewGuid(),null,[new(Guid.NewGuid(),1,reason,size)])));
    [Theory]
    [InlineData("Owner",true)] [InlineData("Manager",true)] [InlineData("Cashier",false)] [InlineData("Inventory",false)]
    public void Review_scope_requires_authorized_manager_or_substitute(string role,bool expected)
    {
        var p=new ClaimsPrincipal(new ClaimsIdentity([new(ClaimTypes.Role,role)],"offline"));
        Assert.Equal(expected,InternalCommandAuthorization.Allowed(p,"commerce.stock.review"));
        if(role=="Cashier") Assert.False(InternalCommandAuthorization.Allowed(p,"commerce.stock.adjust"));
    }
    [Fact]
    public void Review_requires_evidence_outcome_responsible_actor_and_next_review()
    {
        var now=DateTimeOffset.UtcNow;var r=new InternalStockExceptionReviewRequest(Guid.NewGuid(),"examined", "unproven cause",Guid.NewGuid(),now.AddDays(1));
        Assert.True(InternalStockExceptionRules.ValidReview(r,now));
        Assert.False(InternalStockExceptionRules.ValidReview(r with {Evidence=" "},now));
        Assert.False(InternalStockExceptionRules.ValidReview(r with {Outcome=null},now));
        Assert.False(InternalStockExceptionRules.ValidReview(r with {ResponsibleActorId=Guid.Empty},now));
        Assert.False(InternalStockExceptionRules.ValidReview(r with {NextReviewAt=now},now));
    }
    [Fact]
    public void Replay_fingerprint_binds_exception_reason_size_and_follow_up()
    {
        var line=new InternalSaleLineRequest(Guid.NewGuid(),1,"physical","S");
        Assert.NotEqual(InternalRules.Fingerprint(line),InternalRules.Fingerprint(line with {Size="M"}));
        Assert.NotEqual(InternalRules.Fingerprint(line),InternalRules.Fingerprint(line with {ExceptionReason="other"}));
    }
    [Fact]
    public void Ordinary_sale_keeps_pre_exception_replay_fingerprint()
    {
        var item = Guid.Parse("11111111-1111-4111-8111-111111111111");
        var location = Guid.Parse("22222222-2222-4222-8222-222222222222");
        var legacy = new { LocationId = location, CustomerId = (Guid?)null,
            Lines = new[] { new { ItemId = item, Quantity = 1 } } };
        var current = new InternalSaleRequest(location, null, [new(item, 1)]);
        Assert.Equal(InternalRules.Fingerprint(legacy), InternalRules.Fingerprint(current));
    }
    [Fact]
    public async Task Reviews_are_append_only_before_any_SQL()
    {
        using var db=new InternalDbContextFactory().CreateDbContext([]);
        var r=new InternalStockExceptionReview {Id=Guid.NewGuid()};db.Attach(r);
        db.Entry(r).State=EntityState.Modified;
        await Assert.ThrowsAsync<InvalidOperationException>(()=>db.SaveChangesAsync());
        db.Entry(r).State=EntityState.Deleted;
        Assert.Throws<InvalidOperationException>(()=>db.SaveChanges());
    }
    [Fact]
    public void Generated_migration_and_model_match_without_opening_SQL()
    {
        using var db=new InternalDbContextFactory().CreateDbContext([]);
        Assert.False(db.Database.HasPendingModelChanges());
        Assert.Contains(Migration,db.Database.GetMigrations());
        var ddl=db.Database.GenerateCreateScript();
        Assert.Contains("StockExceptionReviews",ddl);Assert.Contains("CK_InternalSaleLine_Exception",ddl);
        Assert.Contains("[ExceptionReason] IS NOT NULL AND [Size] IS NOT NULL",ddl);
        Assert.Contains("CK_InternalBalance_Bounds",ddl);
    }
}
