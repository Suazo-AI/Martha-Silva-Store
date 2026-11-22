-- TEST: D-037 the sale, till-opened and receipt events take their id from the source row (sync.fn_EventId), so a source row can never have two such events.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @sale uniqueidentifier=NEWID(),@till uniqueidentifier,@n bigint;
EXEC test.SeedSale @sale,'A';
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@sale AND EventType='sales.sale_posted'
        AND EventId=sync.fn_EventId('sales.sale_posted',@sale));
EXEC test.AssertEq N'sale event id derived from the sale',1,@n;
SET @till=(SELECT TillId FROM sales.Sales WHERE Id=@sale);
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@till AND EventType='cash.till_opened'
        AND EventId=sync.fn_EventId('cash.till_opened',@till));
EXEC test.AssertEq N'till event id derived from the till',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventType='inventory.receipt_posted');
SET @n=IIF(@n>0,1,0); EXEC test.AssertEq N'the seed posted a receipt',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE EventType='inventory.receipt_posted'
        AND EventId<>sync.fn_EventId('inventory.receipt_posted',AggregateId));
EXEC test.AssertEq N'every receipt event id derived from its receipt',0,@n;
SET @n=IIF(sync.fn_EventId('sales.sale_posted',@sale)=sync.fn_EventId('cash.till_opened',@sale),1,0);
EXEC test.AssertEq N'another event type gives another id',0,@n;
PRINT 'PASS';
