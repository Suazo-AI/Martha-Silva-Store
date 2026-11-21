-- TEST: el efectivo esperado al cerrar es la suma de todos los movimientos del turno (fondo, ventas y manuales) y la diferencia es contado menos esperado.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @branch uniqueidentifier=test.Id('branchA'),@loc uniqueidentifier=test.Id('locA'),
  @cashier uniqueidentifier=test.Id('cashierA'),@super uniqueidentifier=test.Id('supervisorA'),
  @node uniqueidentifier=test.Id('nodeA'),@register uniqueidentifier=test.Id('registerA'),
  @item uniqueidentifier=test.Id('item'),@till uniqueidentifier=NEWID(),@sale uniqueidentifier=NEWID(),
  @deposit uniqueidentifier=NEWID(),@payout uniqueidentifier=NEWID(),@count uniqueidentifier=NEWID(),
  @close uniqueidentifier=NEWID(),@till2 uniqueidentifier=NEWID(),@count2 uniqueidentifier=NEWID(),
  @close2 uniqueidentifier=NEWID(),@n bigint;
EXEC test.SeedStock @item,@loc,5;
EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=100000,@OriginNodeId=@node;
DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor) VALUES(1,@item,2,120000,0);
INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor) VALUES(1,'cash',240000,240000,0);
EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branch,@LocationId=@loc,@CashierId=@cashier,
     @CurrencyCode='NIO',@TillId=@till,@OriginNodeId=@node,@Lines=@lines,@Tenders=@tenders;
EXEC sales.usp_RecordCashEntry @EntryId=@deposit,@TillId=@till,@ActorId=@cashier,
     @Kind='deposit',@DeltaMinor=30000,@Reason=N'fondo extra',@OriginNodeId=@node;
EXEC sales.usp_RecordCashEntry @EntryId=@payout,@TillId=@till,@ActorId=@cashier,
     @Kind='payout',@DeltaMinor=-20000,@Reason=N'gastos',@OriginNodeId=@node;

-- Esperado 100000+240000+30000-20000 = 350000; contado 3x100000 + 5x10000 = 350000.
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES(@count,@till,@cashier,'draft',@cashier);
INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity)
  VALUES(@count,100000,3),(@count,10000,5);
EXEC sales.usp_SubmitCashCount @CashCountId=@count,@ActorId=@cashier;
EXEC sales.usp_CloseTill @ClosureId=@close,@TillId=@till,@CashCountId=@count,@ActorId=@super,@OriginNodeId=@node;

SET @n=(SELECT COUNT(*) FROM sales.CashClosures WHERE Id=@close AND ExpectedMinor=350000
        AND CountedMinor=350000 AND DifferenceMinor=0 AND Status='closed' AND ClosedBy=@super);
EXEC test.AssertEq N'cierre con esperado y contado 350000',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashTills WHERE Id=@till AND Status='closed' AND ClosedAt IS NOT NULL);
EXEC test.AssertEq N'el turno quedo cerrado',1,@n;
SET @n=(SELECT CashExpectedMinor FROM accounting.CloseDocuments WHERE ClosureId=@close);
EXEC test.AssertEq N'efectivo esperado en el documento',350000,@n;
SET @n=(SELECT CashCountedMinor FROM accounting.CloseDocuments WHERE ClosureId=@close);
EXEC test.AssertEq N'efectivo contado en el documento',350000,@n;
SET @n=(SELECT COUNT(*) FROM accounting.CloseDocuments WHERE ClosureId=@close);
EXEC test.AssertEq N'documentos contables del cierre',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE AggregateId=@close AND EventType='cash.till_closed');
EXEC test.AssertEq N'evento de cierre',1,@n;

-- El turno cerrado libera la caja registradora: se abre otro y su esperado arranca en cero.
EXEC sales.usp_OpenTill @TillId=@till2,@RegisterId=@register,@CashierId=@cashier,
     @CurrencyCode='NIO',@OpeningMinor=0,@OriginNodeId=@node;
INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy) VALUES(@count2,@till2,@cashier,'draft',@cashier);
INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity) VALUES(@count2,10000,1);
EXEC sales.usp_SubmitCashCount @CashCountId=@count2,@ActorId=@cashier;
EXEC sales.usp_CloseTill @ClosureId=@close2,@TillId=@till2,@CashCountId=@count2,@ActorId=@super,@OriginNodeId=@node;
SET @n=(SELECT COUNT(*) FROM sales.CashClosures WHERE Id=@close2 AND ExpectedMinor=0
        AND CountedMinor=10000 AND DifferenceMinor=10000);
EXEC test.AssertEq N'segundo cierre con sobrante de 10000',1,@n;
SET @n=(SELECT COUNT(*) FROM sales.CashTills WHERE RegisterId=@register);
EXEC test.AssertEq N'dos turnos en la misma caja registradora a lo largo del dia',2,@n;
PRINT 'PASS';
