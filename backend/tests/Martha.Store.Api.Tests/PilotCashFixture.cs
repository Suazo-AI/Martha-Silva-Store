using System.Text.Json;
using Martha.Store.Api.Internal;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Martha.Store.Api.Tests;

internal static class PilotCashFixture
{
    private static readonly Guid Branch=Guid.Parse("11111111-1111-1111-1111-111111111111"), Location=Guid.Parse("33333333-3333-3333-3333-333333333333");
    private sealed class Clock : TimeProvider
    {
        private readonly DateTimeOffset now=DateTimeOffset.UtcNow;
        public override DateTimeOffset GetUtcNow()=>now;
    }
    internal static async Task<string> Populate(string database, string nonce)
    {
        var time=new Clock(); var now=time.GetUtcNow(); var item=Guid.NewGuid();
        InternalStaff Staff(string role)=>new() { Id=Guid.NewGuid(),LoginName=role+nonce[..16].ToUpperInvariant(),NormalizedLoginName=(role+nonce[..16]).ToUpperInvariant(),
            DisplayName="Synthetic recovery "+role,PasswordHash="fictitious-not-a-password-hash",Role=role,Enabled=true,BranchId=Branch,
            SecurityVersion=Guid.NewGuid(),CreatedAt=now,UpdatedAt=now };
        InternalSession Session(InternalStaff s)=>new() { Id=Guid.NewGuid(),StaffId=s.Id,SecurityVersion=s.SecurityVersion,CreatedAt=now,ExpiresAt=now.Add(InternalSecurityRules.SessionLifetime) };
        var cashier=Staff("Cashier"); var manager=Staff("Manager"); var cs=Session(cashier); var ms=Session(manager);
        await using(var db=PrivatePilotReleaseTests.Context(database))
        {
            db.Add(new InternalItem { Id=item,Sku="REC-"+nonce[..16].ToUpperInvariant(),Name="Synthetic recovery item",UnitPriceMinor=1250,Currency="USD",Active=true });
            db.AddRange(cashier,manager); db.AddRange(cs,ms); await db.SaveChangesAsync();
        }
        var operations=new List<object>();
        async Task<InternalResult<T>> Run<T>(InternalStaff actor,InternalSession session,string suffix,Func<InternalCashService,string,Task<InternalResult<T>>> action)
        {
            await using var db=PrivatePilotReleaseTests.Context(database);
            var security=new InternalSecurityService(db,new PasswordHasher<InternalStaff>(),time);
            var http=new HttpContextAccessor { HttpContext=new DefaultHttpContext { User=InternalSecurityRules.Principal(actor,session) } };
            var runner=new InternalCommandRunner(db,security,http,time);
            var commerce=new InternalCommerceService(db,runner,new InternalStockLedger(db));
            var key=nonce+"-"+suffix;
            var result=await action(new InternalCashService(db,runner,commerce,new("USD",2),time),key);
            Assert.True(result.Success,result.Error);
            operations.Add(new { actor=actor.Id,key,result=JsonSerializer.Serialize(result,new JsonSerializerOptions(JsonSerializerDefaults.Web)) });
            return result;
        }
        await using(var db=PrivatePilotReleaseTests.Context(database))
        {
            var security=new InternalSecurityService(db,new PasswordHasher<InternalStaff>(),time);
            var http=new HttpContextAccessor { HttpContext=new DefaultHttpContext { User=InternalSecurityRules.Principal(manager,ms) } };
            var runner=new InternalCommandRunner(db,security,http,time);
            var commerce=new InternalCommerceService(db,runner,new InternalStockLedger(db));
            var stock=await commerce.Adjust(new(item,Location,3,"Synthetic recovery stock"),manager.Id,nonce+"-stock",default);
            Assert.True(stock.Success,stock.Error);
        }
        var a=(await Run(cashier,cs,"open-a",(s,k)=>s.Open(new(Location,"USD",10000),cashier.Id,k,default))).Value!;
        var sale=(await Run(cashier,cs,"sale",(s,k)=>s.Sell(new(a.Till.Id,null,[new(item,2)],"USD",3000),cashier.Id,k,default))).Value!;
        var ca=(await Run(cashier,cs,"close-a",(s,k)=>s.Close(a.Till.Id,new(12400),cashier.Id,k,default))).Value!;
        // Freeze the actual persisted first close BEFORE the second shift and Manager refund.
        var prior=await PilotRecoveryProof.HashRows(database,$"SELECT * FROM savia_internal.CashCloses WHERE Id='{ca.Close.Id}'");
        Assert.Single(prior);
        var b=(await Run(cashier,cs,"open-b",(s,k)=>s.Open(new(Location,"USD",2000),cashier.Id,k,default))).Value!;
        var refund=(await Run(manager,ms,"refund",(s,k)=>s.Refund(sale.Sale.SaleId,new(b.Till.Id,"USD","Synthetic partial return",[new(sale.Sale.Lines.Single().SaleLineId,1)]),manager.Id,k,default))).Value!;
        var cb=(await Run(cashier,cs,"close-b",(s,k)=>s.Close(b.Till.Id,new(750),cashier.Id,k,default))).Value!;
        Assert.Equal(prior,await PilotRecoveryProof.HashRows(database,$"SELECT * FROM savia_internal.CashCloses WHERE Id='{ca.Close.Id}'"));
        var ids=JsonSerializer.Serialize(new { item,cashier=cashier.Id,manager=manager.Id,sessionA=cs.Id,sessionB=ms.Id,
            tillA=a.Till.Id,tillB=b.Till.Id,closeA=ca.Close.Id,closeB=cb.Close.Id,sale=sale.Sale.SaleId,
            saleLine=sale.Sale.Lines.Single().SaleLineId,reversal=refund.Reversal.ReversalId,
            openingA=a.Opening.Id,openingB=b.Opening.Id,payment=sale.Payment.Id,refund=refund.Refund.Id,now,prior,operations });
        await AssertMoney(database,ids);
        return ids;
    }
    internal static async Task AssertMoney(string database,string identities)
    {
        using var doc=JsonDocument.Parse(identities); var i=doc.RootElement;
        string Id(string name)=>i.GetProperty(name).GetGuid().ToString();
        async Task One(string sql,string expected)=>Assert.Equal(new[]{expected},await PrivatePilotReleaseTests.Rows(database,sql));
        await One("SELECT (SELECT COUNT(*) FROM savia_internal.CashTills),(SELECT COUNT(*) FROM savia_internal.CashEntries),(SELECT COUNT(*) FROM savia_internal.CashCloses),(SELECT COUNT(*) FROM savia_internal.Sales),(SELECT COUNT(*) FROM savia_internal.SaleLines),(SELECT COUNT(*) FROM savia_internal.SaleReversals),(SELECT COUNT(*) FROM savia_internal.SaleReversalLines),(SELECT COUNT(*) FROM savia_internal.Operations WHERE Scope LIKE 'cash.%')","2|4|2|1|1|1|1|6");
        await One($"SELECT OnHand,Reserved FROM savia_internal.StockBalances WHERE ItemId='{Id("item")}' AND LocationId='{Location}'","2|0");
        foreach(var shift in new[]{("A","12500|12400|-100"),("B","750|750|0")})
        {
            await One($"SELECT c.ExpectedMinor,c.CountedMinor,c.DifferenceMinor FROM savia_internal.CashCloses c JOIN savia_internal.CashTills t ON t.Id=c.TillId WHERE c.Id='{Id("close"+shift.Item1)}' AND t.Id='{Id("till"+shift.Item1)}' AND c.ActorId='{Id("cashier")}' AND t.CashierId=c.ActorId AND t.LocationId='{Location}' AND t.Currency='USD' AND t.Exponent=2 AND t.ClosedAt=c.CreatedAt",shift.Item2);
            await One($"SELECT SUM(DeltaMinor) FROM savia_internal.CashEntries WHERE TillId='{Id("till"+shift.Item1)}'",shift.Item1=="A"?"12500":"750");
        }
        // Literal independent oracle: exact identities, quantities, custody, actors, tender and commerce joins.
        await One($"""
          SELECT e.DeltaMinor,e.ReceivedMinor,e.ChangeMinor,s.TotalMinor,l.Quantity,l.UnitPriceMinor,l.TotalMinor,l.ReturnedQuantity
          FROM savia_internal.CashEntries e JOIN savia_internal.Sales s ON s.Id=e.SaleId JOIN savia_internal.SaleLines l ON l.SaleId=s.Id
          WHERE e.Id='{Id("payment")}' AND e.Kind='sale' AND e.TillId='{Id("tillA")}' AND e.CashierId='{Id("cashier")}' AND e.ActorId=e.CashierId
            AND s.Id='{Id("sale")}' AND s.ActorId=e.ActorId AND s.LocationId='{Location}' AND s.Currency COLLATE Latin1_General_100_BIN2=e.Currency AND e.Currency='USD' AND e.Exponent=2
            AND l.Id='{Id("saleLine")}' AND l.ItemId='{Id("item")}'
          ""","2500|3000|500|2500|2|1250|2500|1");
        await One($"""
          SELECT e.DeltaMinor,r.RecordedCreditMinor,l.Quantity,l.RecordedCreditMinor,r.Reason
          FROM savia_internal.CashEntries e JOIN savia_internal.SaleReversals r ON r.Id=e.ReversalId JOIN savia_internal.SaleReversalLines l ON l.ReversalId=r.Id
          WHERE e.Id='{Id("refund")}' AND e.Kind='refund' AND e.TillId='{Id("tillB")}' AND e.SaleId='{Id("sale")}' AND r.SaleId=e.SaleId
            AND e.CashierId='{Id("cashier")}' AND e.ActorId='{Id("manager")}' AND r.ActorId=e.ActorId AND r.Id='{Id("reversal")}'
            AND e.Currency='USD' AND e.Exponent=2 AND e.ReceivedMinor=0 AND e.ChangeMinor=0 AND l.SaleLineId='{Id("saleLine")}'
          ""","-1250|1250|1|1250|Synthetic partial return");
        foreach(var shift in new[]{("A","10000"),("B","2000")})
            await One($"SELECT DeltaMinor FROM savia_internal.CashEntries WHERE Id='{Id("opening"+shift.Item1)}' AND TillId='{Id("till"+shift.Item1)}' AND Kind='opening' AND CashierId='{Id("cashier")}' AND ActorId=CashierId AND Currency='USD' AND Exponent=2 AND ReceivedMinor=0 AND ChangeMinor=0 AND SaleId IS NULL AND ReversalId IS NULL",shift.Item2);
        Assert.Equal(i.GetProperty("prior").EnumerateArray().Select(x=>x.GetString()).ToArray(),await PilotRecoveryProof.HashRows(database,$"SELECT * FROM savia_internal.CashCloses WHERE Id='{Id("closeA")}'"));
        var scopes=new[]{"cash.till.open","cash.sale","cash.till.close","cash.till.open","cash.refund","cash.till.close"}; var n=0;
        foreach(var op in i.GetProperty("operations").EnumerateArray())
        {
            // Returned result is frozen before recovery; persisted JSON must contain the same effect IDs and timestamps.
            var rows=await PrivatePilotReleaseTests.Rows(database,$"SELECT ResultJson FROM savia_internal.Operations WHERE ActorId='{op.GetProperty("actor").GetGuid()}' AND [Key]='{op.GetProperty("key").GetString()}' AND Scope='{scopes[n++]}' AND LocationId='{Location}' AND OriginalBranchId='{Branch}'");
            Assert.Equal(new[]{op.GetProperty("result").GetString()},rows);
        }
        Assert.Equal(6,n);
        var now=i.GetProperty("now").GetDateTimeOffset().ToString("O");
        await One($"SELECT COUNT(*) FROM savia_internal.CashTills WHERE OpenedAt='{now}' AND ClosedAt='{now}'","2");
        await One($"SELECT COUNT(*) FROM savia_internal.CashEntries WHERE CreatedAt='{now}'","4");
        await One($"SELECT COUNT(*) FROM savia_internal.CashCloses WHERE CreatedAt='{now}'","2");
        await One($"SELECT COUNT(*) FROM savia_internal.Operations WHERE Scope LIKE 'cash.%' AND CreatedAt='{now}'","6");
        await One($"SELECT COUNT(*) FROM savia_internal.Staff WHERE Id='{Id("cashier")}' AND Role='Cashier' AND BranchId='{Branch}' AND Enabled=1","1");
        await One($"SELECT COUNT(*) FROM savia_internal.Staff WHERE Id='{Id("manager")}' AND Role='Manager' AND BranchId='{Branch}' AND Enabled=1","1");
        foreach(var session in new[]{("sessionA","cashier"),("sessionB","manager")})
            await One($"SELECT COUNT(*) FROM savia_internal.Sessions se JOIN savia_internal.Staff st ON st.Id=se.StaffId AND st.SecurityVersion=se.SecurityVersion WHERE se.Id='{Id(session.Item1)}' AND st.Id='{Id(session.Item2)}' AND se.RevokedAt IS NULL AND se.CreatedAt='{now}' AND se.ExpiresAt>'{now}'","1");
    }
}
