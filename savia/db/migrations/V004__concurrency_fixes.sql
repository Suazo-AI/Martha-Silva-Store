/* SAVIA V004: concurrency fixes found by tests/Savia.Tests/ConcurrencyTests (red run in docs/bugs/evidence).
   BUG-001: under READ COMMITTED with locks, a sale that builds its event payload reads sales.SaleLines and
            waits on the uncommitted lines of another sale, which waits on the stock row of the first one.
            SQL Server reported 82 deadlocks for 60 parallel sales. Row versioning removes reader/writer
            blocking and makes the local engine behave like Azure SQL Database, where it is the default.
   BUG-002: sales.usp_CloseTill looked for an existing closure before locking the till, so a simultaneous
            retry of the same close failed with 51522 instead of returning the closure.
   The ALTER DATABASE statements cannot run inside a transaction and need the database for themselves. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF (SELECT snapshot_isolation_state FROM sys.databases WHERE database_id=DB_ID())=0
  ALTER DATABASE CURRENT SET ALLOW_SNAPSHOT_ISOLATION ON;
GO
IF (SELECT is_read_committed_snapshot_on FROM sys.databases WHERE database_id=DB_ID())=0
  ALTER DATABASE CURRENT SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
GO
CREATE OR ALTER PROCEDURE [sales].[usp_CloseTill]
 @ClosureId uniqueidentifier,@TillId uniqueidentifier,@CashCountId uniqueidentifier,
 @ActorId uniqueidentifier,@OriginNodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
   -- BUG-002: lock the till BEFORE looking for a closure. Two simultaneous retries are then serialized
   -- and the second one finds the committed closure instead of failing with 51522.
   DECLARE @status varchar(16),@currency varchar(3),@opened datetime2(3);
   SELECT @status=Status,@currency=CurrencyCode,@opened=OpenedAt FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TillId;
   IF EXISTS(SELECT 1 FROM sales.CashClosures WHERE TillId=@TillId)
   BEGIN
     IF NOT EXISTS(SELECT 1 FROM sales.CashClosures WHERE Id=@ClosureId AND TillId=@TillId AND CashCountId=@CashCountId)
       THROW 51521,'Turno ya cerrado con otro comprobante.',1;
     COMMIT; RETURN;
   END;
   IF @status IS NULL OR @status<>'open' THROW 51522,'Turno no abierto.',1;
   IF NOT EXISTS(SELECT 1 FROM sales.CashCounts WITH(UPDLOCK,HOLDLOCK)
       WHERE Id=@CashCountId AND TillId=@TillId AND Status='submitted')
       THROW 51523,'Arqueo no presentado o no corresponde al turno.',1;
   DECLARE @expected bigint=(SELECT COALESCE(SUM(DeltaMinor),0) FROM sales.CashEntries WHERE TillId=@TillId);
   DECLARE @counted bigint=(SELECT COALESCE(SUM(CONVERT(bigint,DenominationMinor)*Quantity),0)
      FROM sales.CashCountLines WHERE CashCountId=@CashCountId);
   IF @expected<0 OR @counted<0 THROW 51524,'Arqueo negativo o caja sin fondos.',1;
   INSERT INTO sales.CashClosures(Id,TillId,CashCountId,ExpectedMinor,CountedMinor,
     DifferenceMinor,ClosedBy,CreatedBy)
      VALUES(@ClosureId,@TillId,@CashCountId,@expected,@counted,@counted-@expected,@ActorId,@ActorId);
   UPDATE sales.CashTills SET Status='closed',ClosedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId,
     ModifiedAt=SYSUTCDATETIME() WHERE Id=@TillId;
   DECLARE @doc uniqueidentifier=NEWID(),@gross bigint=0,@tax bigint=0,@discount bigint=0,
      @sales int=0,@returns bigint=0,@card bigint=0,@credit bigint=0,
      @saleCOGS bigint=0,@returnCOGS bigint=0;
   SELECT @gross=COALESCE(SUM(s.TotalMinor),0),@tax=COALESCE(SUM(s.TaxMinor),0),
        @discount=COALESCE(SUM(s.DiscountMinor),0),@sales=COUNT(*)
      FROM sales.Sales s WHERE s.TillId=@TillId;
   SELECT @returns=COALESCE(SUM(CreditMinor),0) FROM sales.SaleReversals
      WHERE TillId=@TillId AND Status='approved';
   SELECT @saleCOGS=COALESCE(SUM(l.COGSMinor),0) FROM sales.SaleLines l
     JOIN sales.Sales s ON s.Id=l.SaleId WHERE s.TillId=@TillId;
   SELECT @returnCOGS=COALESCE(SUM(l.COGSReversedMinor),0) FROM sales.SaleReversalLines l
     JOIN sales.SaleReversals r ON r.Id=l.ReversalId
     WHERE r.TillId=@TillId AND r.Status='approved';
   SELECT @card=COALESCE(SUM(st.AmountMinor),0) FROM sales.SaleTenders st
     JOIN sales.Sales s ON s.Id=st.SaleId
     WHERE s.TillId=@TillId AND st.TenderKind='card' AND st.Status='captured';
   SELECT @credit=COALESCE(SUM(st.AmountMinor),0) FROM sales.SaleTenders st
     JOIN sales.Sales s ON s.Id=st.SaleId
     WHERE s.TillId=@TillId AND st.TenderKind='credit' AND st.Status='captured';
   INSERT INTO accounting.CloseDocuments(Id,ClosureId,DocumentNumber,DocumentKind,Status,
      CurrencyCode,CashExpectedMinor,CashCountedMinor,CashDifferenceMinor,SaleGrossMinor,
      SaleTaxMinor,SaleDiscountMinor,SaleCount,ReturnGrossMinor,NetSalesMinor,
      SaleCOGSMinor,ReturnedCOGSMinor,NetCOGSMinor,CardCapturedMinor,CreditRedeemedMinor,
      PeriodStartAt,PeriodEndAt,CreatedBy)
     VALUES(@doc,@ClosureId,CONCAT(N'CIERRE-',CONVERT(nvarchar(36),@ClosureId)),
       'accounting_summary','prepared',@currency,@expected,@counted,@counted-@expected,
       @gross,@tax,@discount,@sales,@returns,@gross-@returns,
       @saleCOGS,@returnCOGS,@saleCOGS-@returnCOGS,@card,@credit,
       @opened,SYSUTCDATETIME(),@ActorId);
   INSERT INTO accounting.CloseDocumentLines(CloseDocumentId,[LineNo],ConceptCode,ConceptName,AmountMinor)
      VALUES(@doc,1,'EXPECTED_CASH',N'Efectivo esperado',@expected),
            (@doc,2,'COUNTED_CASH',N'Efectivo contado',@counted),
            (@doc,3,'CASH_DIFFERENCE',N'Diferencia de caja',@counted-@expected),
            (@doc,4,'SALE_GROSS',N'Ventas del turno (todos los medios)',@gross),
            (@doc,5,'RETURN_GROSS',N'Devoluciones del turno',-@returns),
            (@doc,6,'NET_SALES',N'Venta neta del turno',@gross-@returns),
            (@doc,7,'CARD_TENDERS',N'Pagos con tarjeta registrados',@card),
            (@doc,8,'CREDIT_REDEMPTIONS',N'Anticipos canjeados',@credit),
            (@doc,9,'COGS_GROSS',N'Costo de venta del turno (costo snapshot)',@saleCOGS),
            (@doc,10,'COGS_RETURNED',N'Costo revertido por devoluciones',-@returnCOGS),
            (@doc,11,'COGS_NET',N'Costo de venta neto',@saleCOGS-@returnCOGS);
   -- Se crea salida contable automatica; no se inventa una factura fiscal.
   INSERT INTO accounting.ExportJobs(Id,CloseDocumentId,RecipientCode,Format,Status,CreatedBy)
     VALUES(NEWID(),@doc,N'ACCOUNTANT','PDF','pending',@ActorId);
   DECLARE @evt uniqueidentifier=NEWID(),@payload nvarchar(max)=(
     SELECT @ClosureId AS closureId,@TillId AS tillId,@CashCountId AS cashCountId,
        @doc AS accountingDocumentId,@expected AS expectedMinor,@counted AS countedMinor,
        @currency AS currency FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   EXEC sync.usp_EnqueueEvent @evt,@OriginNodeId,'cash_closure',@ClosureId,'cash.till_closed',@payload;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO
