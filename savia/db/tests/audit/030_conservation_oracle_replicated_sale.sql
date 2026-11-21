-- TEST: a sale replicated from another node carries no local outbox event and is not a violation; a sale this node posted still needs exactly one event.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@register uniqueidentifier=test.Id('registerA'),
  @nodeA uniqueidentifier=test.Id('nodeA'),@nodeB uniqueidentifier=test.Id('nodeB'),
  @item uniqueidentifier=test.Id('item'),@till uniqueidentifier=NEWID(),
  @remote uniqueidentifier=NEWID(),@own uniqueidentifier=NEWID(),@n bigint;
DECLARE @found TABLE(CheckName varchar(60),KeyText nvarchar(200),Expected bigint,Actual bigint);

-- Two sales posted at node A. ADR-001 D5: the outbox is local and never synced.
EXEC test.SeedStock @item,@loc,5;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,@CurrencyCode='NIO',@OpeningMinor=50000,@OriginNodeId=@nodeA;
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,1,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',120000,120000,0);
EXEC sales.usp_PostSale @SaleId=@remote,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,@CurrencyCode='NIO',
     @TillId=@till,@OriginNodeId=@nodeA,@Lines=@lines,@Tenders=@tenders;

-- This database becomes node B's replica: the remote sale arrives without node A's outbox row.
EXEC sync.usp_SetLocalNode @NodeId=@nodeB;
DELETE d FROM sync.EventDeliveries d JOIN sync.Outbox o ON o.EventId=d.EventId WHERE o.AggregateId=@remote;
DELETE FROM sync.Outbox WHERE AggregateId=@remote;
DELETE FROM @found; INSERT INTO @found EXEC audit.usp_CheckConservation;
SET @n=(SELECT COUNT(*) FROM @found WHERE KeyText=CONVERT(nvarchar(36),@remote));
EXEC test.AssertEq N'replicated sale without a local event is clean',0,@n;

-- A sale whose origin is this node (B) still needs its event.
UPDATE sales.Sales SET OriginNodeId=@nodeB WHERE Id=@remote;
DELETE FROM @found; INSERT INTO @found EXEC audit.usp_CheckConservation;
SET @n=(SELECT COUNT(*) FROM @found WHERE CheckName='sale.outbox_event' AND KeyText=CONVERT(nvarchar(36),@remote) AND Expected=1 AND Actual=0);
EXEC test.AssertEq N'own sale without its event is a violation',1,@n;
