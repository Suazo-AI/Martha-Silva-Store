-- Owner decisions 2026-11-12: shared sales (max 3 sellers), returns window and four outcomes, KPI reports.
-- Earlier migrations stay unchanged. Procedures patched by text replacement refuse an unexpected definition.

-- 1. At most three distinct sellers on one ticket.
DECLARE @definition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'sales.usp_PostSale'));
DECLARE @anchor nvarchar(200)=N'THROW 52002,''La vendedora debe estar activa en esta sucursal.'',1;';
IF (LEN(@definition)-LEN(REPLACE(@definition,@anchor,N'')))/LEN(@anchor)<>1 THROW 52007,'Sale contract incompatible.',1;
SET @definition=REPLACE(REPLACE(@definition,N'CREATE   PROCEDURE',N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE',N'CREATE OR ALTER PROCEDURE');
SET @definition=REPLACE(@definition,@anchor,@anchor+NCHAR(10)+N' IF (SELECT COUNT(DISTINCT SellerId) FROM @sellers)>3 THROW 52009,''Una venta admite hasta tres vendedoras.'',1;');
EXEC sys.sp_executesql @definition;
GO

-- 2. Return window per branch. The owner changes it; every return outcome enforces it.
CREATE TABLE sales.ReturnPolicies(BranchId uniqueidentifier NOT NULL PRIMARY KEY REFERENCES core.Branches(Id),
 WindowDays int NOT NULL CHECK(WindowDays BETWEEN 1 AND 365),UpdatedBy uniqueidentifier NOT NULL REFERENCES security.Staff(Id),
 UpdatedAt datetime2(3) NOT NULL DEFAULT(core.ufn_BusinessNow()));
CREATE TABLE sales.ReturnPolicyHistory(Id uniqueidentifier NOT NULL PRIMARY KEY,BranchId uniqueidentifier NOT NULL REFERENCES core.Branches(Id),
 OldWindowDays int NOT NULL,NewWindowDays int NOT NULL,ActorId uniqueidentifier NOT NULL REFERENCES security.Staff(Id),
 Reason nvarchar(250) NOT NULL,CreatedAt datetime2(3) NOT NULL DEFAULT(SYSUTCDATETIME()));
-- Cash, transfer and exchange settlements of a return. Credit returns keep credits.Credits as their settlement.
CREATE TABLE sales.ReturnSettlements(Id uniqueidentifier NOT NULL DEFAULT(NEWID()) PRIMARY KEY,
 ReversalId uniqueidentifier NOT NULL REFERENCES sales.SaleReversals(Id),
 Kind varchar(16) NOT NULL CHECK(Kind IN ('cash','transfer','exchange')),AmountMinor bigint NOT NULL CHECK(AmountMinor>0),
 Reference nvarchar(120) NULL,ExchangeSaleId uniqueidentifier NULL REFERENCES sales.Sales(Id),
 CreatedAt datetime2(3) NOT NULL DEFAULT(SYSUTCDATETIME()),
 CHECK(Kind<>'transfer' OR LEN(LTRIM(RTRIM(Reference)))>0),CHECK((Kind='exchange' AND ExchangeSaleId IS NOT NULL) OR (Kind<>'exchange' AND ExchangeSaleId IS NULL)));
CREATE INDEX IX_ReturnSettlements_Reversal ON sales.ReturnSettlements(ReversalId);
ALTER TABLE sales.SaleReversals DROP CONSTRAINT CK_Reversals_Settlement;
ALTER TABLE sales.SaleReversals ADD CONSTRAINT CK_Reversals_Settlement CHECK(SettlementKind IN ('credit','cash','mixed','none','transfer','exchange'));
GO
CREATE OR ALTER FUNCTION sales.ufn_ReturnWindowDays(@BranchId uniqueidentifier) RETURNS int
AS BEGIN RETURN COALESCE((SELECT WindowDays FROM sales.ReturnPolicies WHERE BranchId=@BranchId),30); END;
GO
CREATE OR ALTER PROCEDURE sales.usp_GetReturnPolicy @BranchId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON;
 SELECT (SELECT sales.ufn_ReturnWindowDays(@BranchId) AS windowDays,
  JSON_QUERY(COALESCE((SELECT TOP(20) h.OldWindowDays AS oldWindowDays,h.NewWindowDays AS newWindowDays,st.DisplayName AS actorName,h.Reason AS reason,h.CreatedAt AS createdAt
  FROM sales.ReturnPolicyHistory h JOIN security.Staff st ON st.Id=h.ActorId WHERE h.BranchId=@BranchId ORDER BY h.CreatedAt DESC,h.Id FOR JSON PATH),N'[]')) AS history
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS Json;
END;
GO
CREATE OR ALTER PROCEDURE sales.usp_SetReturnWindow @ChangeId uniqueidentifier,@BranchId uniqueidentifier,@WindowDays int,@ActorId uniqueidentifier,@Reason nvarchar(250)
AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;
 IF NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles r ON r.Id=sr.RoleId
  JOIN security.StaffBranchAccess a ON a.StaffId=s.Id AND a.BranchId=@BranchId AND a.IsActive=1
  WHERE s.Id=@ActorId AND s.IsEnabled=1 AND r.Code='OWNER' AND r.IsActive=1) THROW 52001,'Solo la duena cambia el plazo de devolucion.',1;
 IF @WindowDays IS NULL OR @WindowDays NOT BETWEEN 1 AND 365 OR NULLIF(LTRIM(RTRIM(@Reason)),N'') IS NULL THROW 52003,'Plazo o motivo invalido.',1;
 BEGIN TRAN;BEGIN TRY
  DECLARE @old int=30;
  SELECT @old=WindowDays FROM sales.ReturnPolicies WITH(UPDLOCK,HOLDLOCK) WHERE BranchId=@BranchId;
  IF EXISTS(SELECT 1 FROM sales.ReturnPolicyHistory WHERE Id=@ChangeId)
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM sales.ReturnPolicyHistory WHERE Id=@ChangeId AND BranchId=@BranchId AND NewWindowDays=@WindowDays AND ActorId=@ActorId AND Reason=@Reason)
    THROW 52004,'Identificador reutilizado.',1;
   COMMIT;RETURN;
  END;
  INSERT sales.ReturnPolicyHistory(Id,BranchId,OldWindowDays,NewWindowDays,ActorId,Reason,CreatedAt) VALUES(@ChangeId,@BranchId,@old,@WindowDays,@ActorId,@Reason,core.ufn_BusinessNow());
  IF EXISTS(SELECT 1 FROM sales.ReturnPolicies WHERE BranchId=@BranchId)
   UPDATE sales.ReturnPolicies SET WindowDays=@WindowDays,UpdatedBy=@ActorId,UpdatedAt=core.ufn_BusinessNow() WHERE BranchId=@BranchId;
  ELSE INSERT sales.ReturnPolicies(BranchId,WindowDays,UpdatedBy,UpdatedAt) VALUES(@BranchId,@WindowDays,@ActorId,core.ufn_BusinessNow());
  COMMIT;
 END TRY BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK;THROW;END CATCH;
END;
GO
-- The existing credit return also enforces the window.
DECLARE @definition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'sales.usp_PostCreditReturn'));
DECLARE @anchor nvarchar(200)=N'THROW 51535,''La venta pertenece a otra sucursal.'',1;';
IF (LEN(@definition)-LEN(REPLACE(@definition,@anchor,N'')))/LEN(@anchor)<>1 THROW 52007,'Return contract incompatible.',1;
SET @definition=REPLACE(REPLACE(@definition,N'CREATE   PROCEDURE',N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE',N'CREATE OR ALTER PROCEDURE');
SET @definition=REPLACE(@definition,@anchor,@anchor+NCHAR(10)+N'  IF EXISTS(SELECT 1 FROM sales.Sales WHERE Id=@SaleId AND CreatedAt<DATEADD(day,-sales.ufn_ReturnWindowDays(@BranchId),core.ufn_BusinessNow())) THROW 52023,''La venta supera el plazo de devolucion.'',1;');
EXEC sys.sp_executesql @definition;
GO

-- 3. Cash refund, bank transfer refund and exchange. Same line rules as the credit return.
CREATE OR ALTER PROCEDURE sales.usp_PostReturnOutcome
 @ReversalId uniqueidentifier,@SaleId uniqueidentifier,@BranchId uniqueidentifier,@LocationId uniqueidentifier,@TillId uniqueidentifier,
 @ActorId uniqueidentifier,@Outcome varchar(16),@Reason nvarchar(500),@Reference nvarchar(120)=NULL,@OriginNodeId uniqueidentifier,
 @Lines sales.ReturnLineRequest READONLY,
 @ExchangeSaleId uniqueidentifier=NULL,@NewLines sales.SaleLineRequest READONLY,@NewTenders sales.SaleTenderRequest READONLY,
 @SellersJson nvarchar(max)=NULL,@DifferenceKind varchar(16)=NULL,@DifferenceReference nvarchar(120)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Outcome IS NULL OR @Outcome NOT IN ('cash','transfer','exchange') THROW 52020,'Elija cambio, efectivo o transferencia.',1;
 IF NOT EXISTS(SELECT 1 FROM @Lines) OR NULLIF(LTRIM(RTRIM(@Reason)),N'') IS NULL THROW 51525,'Devolucion sin prendas o motivo.',1;
 IF @Outcome='transfer' AND NULLIF(LTRIM(RTRIM(@Reference)),N'') IS NULL THROW 52021,'Indique la referencia de la transferencia.',1;
 IF @Outcome='exchange' AND (@ExchangeSaleId IS NULL OR NOT EXISTS(SELECT 1 FROM @NewLines)) THROW 52022,'Indique las prendas del cambio.',1;
 IF @Outcome<>'exchange' AND (@ExchangeSaleId IS NOT NULL OR EXISTS(SELECT 1 FROM @NewLines) OR EXISTS(SELECT 1 FROM @NewTenders) OR @DifferenceKind IS NOT NULL)
  THROW 52022,'Solo un cambio lleva prendas nuevas.',1;
 IF @DifferenceKind IS NOT NULL AND @DifferenceKind NOT IN ('cash','transfer') THROW 52020,'La diferencia se devuelve en efectivo o transferencia.',1;
 IF @DifferenceKind='transfer' AND NULLIF(LTRIM(RTRIM(@DifferenceReference)),N'') IS NULL THROW 52021,'Indique la referencia de la transferencia.',1;
 IF EXISTS(SELECT 1 FROM @Lines WHERE Quantity<=0 OR RestockPool NOT IN ('store','quarantine')) THROW 51531,'Cantidad o condicion no valida.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
  IF EXISTS(SELECT 1 FROM sales.SaleReversals WITH(UPDLOCK,HOLDLOCK) WHERE Id=@ReversalId)
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM sales.SaleReversals WHERE Id=@ReversalId AND SaleId=@SaleId AND SettlementKind=@Outcome)
    OR EXISTS(SELECT SaleLineId,Quantity FROM @Lines EXCEPT SELECT SaleLineId,Quantity FROM sales.SaleReversalLines WHERE ReversalId=@ReversalId)
    OR EXISTS(SELECT SaleLineId,Quantity FROM sales.SaleReversalLines WHERE ReversalId=@ReversalId EXCEPT SELECT SaleLineId,Quantity FROM @Lines)
    THROW 51538,'ReversalId reutilizado con otro contenido.',1;
   COMMIT; RETURN;
  END;
  IF NOT EXISTS(SELECT 1 FROM core.Locations WHERE Id=@LocationId AND BranchId=@BranchId) THROW 51527,'Ubicacion de devolucion no pertenece a sucursal.',1;
  IF NOT EXISTS(SELECT 1 FROM sales.CashTills t JOIN sales.CashRegisters r ON r.Id=t.RegisterId
   WHERE t.Id=@TillId AND t.Status='open' AND r.BranchId=@BranchId AND r.LocationId=@LocationId) THROW 51528,'Turno de devolucion no abierto.',1;
  IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a JOIN security.Staff s ON s.Id=a.StaffId WHERE a.StaffId=@ActorId AND s.IsEnabled=1
   AND a.BranchId=@BranchId AND a.CanApproveReturns=1 AND a.IsActive=1) THROW 51529,'Supervisor sin permiso para devoluciones.',1;
  DECLARE @currency varchar(3),@saleStatus varchar(24),@saleBranch uniqueidentifier,@saleCreated datetime2(3);
  SELECT @currency=CurrencyCode,@saleStatus=Status,@saleBranch=BranchId,@saleCreated=CreatedAt FROM sales.Sales WITH(UPDLOCK,HOLDLOCK) WHERE Id=@SaleId;
  IF @saleBranch IS NOT NULL AND @saleBranch<>@BranchId THROW 51535,'La venta pertenece a otra sucursal.',1;
  IF @saleStatus IS NULL OR @saleStatus IN ('cancelled','returned') THROW 51530,'Venta original no valida para devolucion.',1;
  IF @saleCreated<DATEADD(day,-sales.ufn_ReturnWindowDays(@BranchId),core.ufn_BusinessNow()) THROW 52023,'La venta supera el plazo de devolucion.',1;
  INSERT INTO sales.SaleReversals(Id,SaleId,BranchId,LocationId,TillId,ActorId,Kind,SettlementKind,Reason,CreditMinor,CurrencyCode,Status,ApprovedBy,CreatedBy)
   VALUES(@ReversalId,@SaleId,@BranchId,@LocationId,@TillId,@ActorId,'return',@Outcome,@Reason,0,@currency,'approved',@ActorId,@ActorId);
  DECLARE @line uniqueidentifier,@qty int,@pool varchar(12),@item uniqueidentifier,@oldReturned int,@originalQty int,@lineTotal bigint,
   @unitCost bigint,@priorCredit bigint,@part bigint,@total bigint=0,@op uniqueidentifier,@mv uniqueidentifier;
  DECLARE outcomeCursor CURSOR LOCAL FAST_FORWARD FOR SELECT SaleLineId,Quantity,RestockPool FROM @Lines ORDER BY SaleLineId;
  OPEN outcomeCursor; FETCH NEXT FROM outcomeCursor INTO @line,@qty,@pool;
  WHILE @@FETCH_STATUS=0
  BEGIN
   SET @item=NULL; SET @priorCredit=0;
   SELECT @item=ItemId,@oldReturned=ReturnedQuantity,@originalQty=Quantity,@lineTotal=TotalMinor,@unitCost=CostUnitSnapshotMinor
    FROM sales.SaleLines WITH(UPDLOCK,HOLDLOCK) WHERE Id=@line AND SaleId=@SaleId;
   IF @item IS NULL OR @oldReturned+@qty>@originalQty THROW 51532,'Intento de devolver unidades ya devueltas.',1;
   SELECT @priorCredit=COALESCE(SUM(rl.CreditMinor),0) FROM sales.SaleReversalLines rl JOIN sales.SaleReversals r ON r.Id=rl.ReversalId
    WHERE rl.SaleLineId=@line AND r.Status='approved';
   SET @part=CASE WHEN @oldReturned+@qty=@originalQty THEN @lineTotal-@priorCredit
    ELSE CONVERT(bigint,ROUND(CONVERT(decimal(28,4),@lineTotal)*@qty/@originalQty,0)) END;
   IF @part<0 OR @priorCredit+@part>@lineTotal THROW 51533,'Reembolso supera importe original.',1;
   UPDATE sales.SaleLines SET ReturnedQuantity=ReturnedQuantity+@qty,ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME() WHERE Id=@line;
   INSERT INTO sales.SaleReversalLines(ReversalId,SaleLineId,Quantity,CreditMinor,COGSReversedMinor,RestockPool,CreatedBy)
    VALUES(@ReversalId,@line,@qty,@part,CASE WHEN @unitCost IS NULL THEN NULL ELSE @unitCost*CONVERT(bigint,@qty) END,@pool,@ActorId);
   SET @op=NEWID(); SET @mv=NULL;
   EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@LocationId,@Pool=@pool,@Kind='return',@OnHandDelta=@qty,
    @SourceType='sale_reversal',@SourceId=@ReversalId,@ActorId=@ActorId,@MovementId=@mv OUTPUT;
   SET @total+=@part;
   FETCH NEXT FROM outcomeCursor INTO @line,@qty,@pool;
  END;
  CLOSE outcomeCursor; DEALLOCATE outcomeCursor;
  IF @total<=0 THROW 51534,'La devolucion debe tener valor mayor a cero.',1;
  UPDATE sales.SaleReversals SET CreditMinor=@total WHERE Id=@ReversalId;
  UPDATE sales.Sales SET Status=CASE WHEN NOT EXISTS(SELECT 1 FROM sales.SaleLines WHERE SaleId=@SaleId AND ReturnedQuantity<Quantity)
   THEN 'returned' ELSE 'partially_returned' END,ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME() WHERE Id=@SaleId;
  DECLARE @cashOut bigint=0,@transferOut bigint=0,@transferRef nvarchar(120)=NULL,@applied bigint=0;
  IF @Outcome='cash' SET @cashOut=@total;
  IF @Outcome='transfer' BEGIN SET @transferOut=@total; SET @transferRef=@Reference; END;
  IF @Outcome='exchange'
  BEGIN
   DECLARE @newTotal bigint=(SELECT SUM(CAST(l.UnitPriceMinor AS bigint)*l.Quantity-l.DiscountMinor+
    CAST(ROUND((CAST(l.UnitPriceMinor AS decimal(28,0))*l.Quantity-l.DiscountMinor)*i.TaxRateBps/10000.0,0) AS bigint))
    FROM @NewLines l JOIN catalog.Items i ON i.Id=l.ItemId);
   IF @newTotal IS NULL OR (SELECT COUNT(*) FROM @NewLines)<>(SELECT COUNT(*) FROM @NewLines l JOIN catalog.Items i ON i.Id=l.ItemId)
    THROW 51513,'Producto, moneda o precio desactualizado.',1;
   SET @applied=CASE WHEN @newTotal<@total THEN @newTotal ELSE @total END;
   DECLARE @extra bigint=(SELECT COALESCE(SUM(AmountMinor),0) FROM @NewTenders);
   IF @extra<>CASE WHEN @newTotal>@total THEN @newTotal-@total ELSE 0 END THROW 51517,'Pagos de la diferencia no coinciden.',1;
   IF @newTotal<@total
   BEGIN
    IF @DifferenceKind IS NULL THROW 52025,'Indique como se devuelve la diferencia.',1;
    IF @DifferenceKind='cash' SET @cashOut=@total-@newTotal;
    ELSE BEGIN SET @transferOut=@total-@newTotal; SET @transferRef=@DifferenceReference; END;
   END;
   DECLARE @tenders sales.SaleTenderRequest;
   IF @applied>0 INSERT @tenders(TenderNumber,TenderKind,AmountMinor,CreditId,ReceivedMinor,ChangeMinor,Reference)
    VALUES(1,'other',@applied,NULL,NULL,NULL,CONCAT(N'CAMBIO ',CONVERT(nvarchar(36),@ReversalId)));
   INSERT @tenders(TenderNumber,TenderKind,AmountMinor,CreditId,ReceivedMinor,ChangeMinor,Reference)
    SELECT 1+ROW_NUMBER() OVER(ORDER BY TenderNumber),TenderKind,AmountMinor,CreditId,ReceivedMinor,ChangeMinor,Reference FROM @NewTenders;
   DECLARE @tillCashier uniqueidentifier=(SELECT CashierId FROM sales.CashTills WHERE Id=@TillId);
   EXEC sales.usp_PostSale @SaleId=@ExchangeSaleId,@BranchId=@BranchId,@LocationId=@LocationId,@CashierId=@tillCashier,@CurrencyCode=@currency,
    @OriginNodeId=@OriginNodeId,@Lines=@NewLines,@Tenders=@tenders,@TillId=@TillId,@SellersJson=@SellersJson;
   IF @applied>0 INSERT sales.ReturnSettlements(ReversalId,Kind,AmountMinor,ExchangeSaleId,CreatedAt) VALUES(@ReversalId,'exchange',@applied,@ExchangeSaleId,core.ufn_BusinessNow());
  END;
  IF @cashOut>0
  BEGIN
   DECLARE @cashAvailable bigint;
   SELECT @cashAvailable=COALESCE(SUM(e.DeltaMinor),0) FROM sales.CashTills t WITH(UPDLOCK,HOLDLOCK) LEFT JOIN sales.CashEntries e ON e.TillId=t.Id WHERE t.Id=@TillId;
   IF @cashAvailable<@cashOut THROW 52024,'La caja no tiene efectivo suficiente para el reembolso.',1;
   INSERT INTO sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,ReversalId,ActorId,Reason,CreatedBy)
    VALUES(NEWID(),@TillId,@currency,'refund',-@cashOut,@ReversalId,@ActorId,@Reason,@ActorId);
   INSERT sales.ReturnSettlements(ReversalId,Kind,AmountMinor,CreatedAt) VALUES(@ReversalId,'cash',@cashOut,core.ufn_BusinessNow());
  END;
  IF @transferOut>0 INSERT sales.ReturnSettlements(ReversalId,Kind,AmountMinor,Reference,CreatedAt) VALUES(@ReversalId,'transfer',@transferOut,@transferRef,core.ufn_BusinessNow());
  DECLARE @evt uniqueidentifier=NEWID(),@payload nvarchar(max)=(SELECT @ReversalId AS returnId,@SaleId AS saleId,@BranchId AS branchId,@Outcome AS outcome,
   @total AS valueMinor,@ExchangeSaleId AS exchangeSaleId,
   JSON_QUERY((SELECT Kind AS kind,AmountMinor AS amountMinor,Reference AS reference FROM sales.ReturnSettlements WHERE ReversalId=@ReversalId FOR JSON PATH)) AS settlements,
   JSON_QUERY((SELECT SaleLineId,Quantity,CreditMinor,RestockPool FROM sales.SaleReversalLines WHERE ReversalId=@ReversalId FOR JSON PATH)) AS lines
   FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
  EXEC sync.usp_EnqueueEvent @evt,@OriginNodeId,'sale_return',@ReversalId,'sales.return_posted',@payload;
  COMMIT;
 END TRY
 BEGIN CATCH
  IF CURSOR_STATUS('local','outcomeCursor')>=0 BEGIN CLOSE outcomeCursor; DEALLOCATE outcomeCursor; END;
  IF @@TRANCOUNT>0 ROLLBACK; THROW;
 END CATCH;
END;
GO

-- 4. Conservation: a settled return equals its settlements; cash refunds equal till entries; exchanges pay the new sale.
DECLARE @definition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'audit.usp_CheckConservation'));
DECLARE @anchor nvarchar(200)=N' SELECT CheckName,KeyText,Expected,Actual FROM @v ORDER BY CheckName,KeyText;';
IF (LEN(@definition)-LEN(REPLACE(@definition,@anchor,N'')))/LEN(@anchor)<>1 THROW 52007,'Oracle contract incompatible.',1;
SET @definition=REPLACE(REPLACE(@definition,N'CREATE   PROCEDURE',N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE',N'CREATE OR ALTER PROCEDURE');
SET @definition=REPLACE(@definition,@anchor,N'
 /* ---- returns (V024): settlements equal the returned value; cash leaves the till once; exchanges pay their sale */
 INSERT INTO @v
 SELECT x.CheckName,CONVERT(nvarchar(36),r.Id),x.Expected,x.Actual
 FROM sales.SaleReversals r
 OUTER APPLY (SELECT COALESCE(SUM(AmountMinor),0) AS Total,COALESCE(SUM(CASE WHEN Kind=''cash'' THEN AmountMinor END),0) AS Cash FROM sales.ReturnSettlements WHERE ReversalId=r.Id) s
 OUTER APPLY (SELECT COALESCE(SUM(DeltaMinor),0) AS Total FROM sales.CashEntries WHERE ReversalId=r.Id AND Kind=''refund'') e
 CROSS APPLY (VALUES (''return.settlements_vs_value'',r.CreditMinor,s.Total),(''return.cash_refund_vs_till'',-s.Cash,e.Total)) x(CheckName,Expected,Actual)
 WHERE r.SettlementKind IN (''cash'',''transfer'',''exchange'') AND x.Expected<>x.Actual;

 INSERT INTO @v
 SELECT ''return.exchange_tender'',CONVERT(nvarchar(36),s.Id),s.AmountMinor,COALESCE(t.Total,0)
 FROM sales.ReturnSettlements s
 OUTER APPLY (SELECT SUM(AmountMinor) AS Total FROM sales.SaleTenders WHERE SaleId=s.ExchangeSaleId AND TenderKind=''other''
              AND Reference=CONCAT(N''CAMBIO '',CONVERT(nvarchar(36),s.ReversalId))) t
 WHERE s.Kind=''exchange'' AND COALESCE(t.Total,0)<>s.AmountMinor;
'+@anchor);
EXEC sys.sp_executesql @definition;
GO

-- 5. Till close document lists returns by kind.
DECLARE @definition nvarchar(max)=OBJECT_DEFINITION(OBJECT_ID(N'sales.usp_CloseTill'));
DECLARE @anchor nvarchar(200)=N'(@doc,11,''COGS_NET'',N''Costo de venta neto'',@saleCOGS-@returnCOGS);';
IF (LEN(@definition)-LEN(REPLACE(@definition,@anchor,N'')))/LEN(@anchor)<>1 THROW 52007,'Close contract incompatible.',1;
SET @definition=REPLACE(REPLACE(@definition,N'CREATE   PROCEDURE',N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE',N'CREATE OR ALTER PROCEDURE');
SET @definition=REPLACE(@definition,@anchor,@anchor+N'
   INSERT INTO accounting.CloseDocumentLines(CloseDocumentId,[LineNo],ConceptCode,ConceptName,AmountMinor)
     SELECT @doc,11+ROW_NUMBER() OVER(ORDER BY SettlementKind),CONCAT(''REFUND_'',UPPER(SettlementKind)),
       CONCAT(N''Devoluciones: '',CASE SettlementKind WHEN ''credit'' THEN N''anticipo'' WHEN ''cash'' THEN N''efectivo'' WHEN ''transfer'' THEN N''transferencia'' WHEN ''exchange'' THEN N''cambio'' ELSE SettlementKind END),
       -SUM(CreditMinor)
     FROM sales.SaleReversals WHERE TillId=@TillId AND Status=''approved'' GROUP BY SettlementKind;');
EXEC sys.sp_executesql @definition;
GO

-- 6. Day report: returns by kind for the day and for each till.
CREATE OR ALTER PROCEDURE sales.usp_GetReturnsByKind @BranchId uniqueidentifier,@Date date
AS
BEGIN
 SET NOCOUNT ON;
 IF @Date IS NULL OR @Date>='9999-01-01' THROW 51900,'Fecha invalida.',1;
 DECLARE @start datetime2=DATEADD(hour,6,CONVERT(datetime2,@Date)),@end datetime2=DATEADD(day,1,DATEADD(hour,6,CONVERT(datetime2,@Date)));
 SELECT (SELECT r.TillId AS tillId,r.SettlementKind AS kind,COUNT(*) AS returnsCount,SUM(r.CreditMinor) AS amountMinor,
  -COALESCE(SUM(ce.Delta),0) AS cashOutMinor
  FROM sales.SaleReversals r OUTER APPLY(SELECT SUM(e.DeltaMinor) AS Delta FROM sales.CashEntries e WHERE e.ReversalId=r.Id AND e.Kind='refund') ce WHERE r.BranchId=@BranchId AND r.Status='approved' AND r.CreatedAt>=@start AND r.CreatedAt<@end
  GROUP BY r.TillId,r.SettlementKind ORDER BY r.TillId,r.SettlementKind FOR JSON PATH) AS Json;
END;
GO

-- 7. KPI reports. Same Nicaragua periods as the commission report (UTC-6, Monday weeks).
CREATE OR ALTER PROCEDURE sales.usp_KpiBusiness @BranchId uniqueidentifier,@ActorId uniqueidentifier,@Period varchar(8),@Date date
AS
BEGIN
 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffBranchAccess a ON a.StaffId=s.Id JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles r ON r.Id=sr.RoleId
  WHERE s.Id=@ActorId AND s.IsEnabled=1 AND a.BranchId=@BranchId AND a.IsActive=1 AND r.IsActive=1 AND r.Code IN ('MANAGER','OWNER')) THROW 52001,'Sin acceso a indicadores del negocio.',1;
 IF @Period NOT IN ('day','week','month','year') OR @Date IS NULL OR @Date<'19000101' OR @Date>='99990101' THROW 51900,'Periodo o fecha invalida.',1;
 DECLARE @from date=CASE @Period WHEN 'week' THEN DATEADD(day,-DATEDIFF(day,'19000101',@Date)%7,@Date) WHEN 'month' THEN DATEFROMPARTS(YEAR(@Date),MONTH(@Date),1) WHEN 'year' THEN DATEFROMPARTS(YEAR(@Date),1,1) ELSE @Date END;
 DECLARE @until date=CASE @Period WHEN 'week' THEN DATEADD(day,7,@from) WHEN 'month' THEN DATEADD(month,1,@from) WHEN 'year' THEN DATEADD(year,1,@from) ELSE DATEADD(day,1,@from) END;
 DECLARE @start datetime2=DATEADD(hour,6,CONVERT(datetime2,@from)),@end datetime2=DATEADD(hour,6,CONVERT(datetime2,@until)),@now datetime2=core.ufn_BusinessNow();
 DECLARE @days int=DATEDIFF(day,@from,@until);
 SELECT s.Id,s.CreatedAt,s.SubtotalMinor,s.DiscountMinor,s.TotalMinor INTO #s FROM sales.Sales s
  WHERE s.BranchId=@BranchId AND s.CurrencyCode='NIO' AND s.Status<>'cancelled' AND s.CreatedAt>=@start AND s.CreatedAt<@end;
 SELECT r.Id,r.SettlementKind,r.CreditMinor INTO #r FROM sales.SaleReversals r
  WHERE r.BranchId=@BranchId AND r.CurrencyCode='NIO' AND r.Status='approved' AND r.CreatedAt>=@start AND r.CreatedAt<@end;
 DECLARE @count bigint=(SELECT COUNT(*) FROM #s),@sold bigint=(SELECT COALESCE(SUM(TotalMinor),0) FROM #s),
  @subtotal bigint=(SELECT COALESCE(SUM(SubtotalMinor),0) FROM #s),@discount bigint=(SELECT COALESCE(SUM(DiscountMinor),0) FROM #s),
  @returns bigint=(SELECT COALESCE(SUM(CreditMinor),0) FROM #r),
  @units bigint=(SELECT COALESCE(SUM(CONVERT(bigint,l.Quantity)),0) FROM #s s JOIN sales.SaleLines l ON l.SaleId=s.Id),
  @cogs bigint=(SELECT COALESCE(SUM(l.COGSMinor),0) FROM #s s JOIN sales.SaleLines l ON l.SaleId=s.Id)
   -(SELECT COALESCE(SUM(l.COGSReversedMinor),0) FROM #r r JOIN sales.SaleReversalLines l ON l.ReversalId=r.Id);
 DECLARE @revenue bigint=@subtotal-@discount-@returns;
 DECLARE @margin bigint=@revenue-@cogs;
 SELECT i.Id AS ItemId,i.ProductId,i.Sku,i.VariantName,i.UnitCostMinor,SUM(CONVERT(bigint,b.OnHand)) AS OnHand INTO #stock
  FROM inventory.StockBalances b JOIN core.Locations loc ON loc.Id=b.LocationId JOIN catalog.Items i ON i.Id=b.ItemId
  WHERE loc.BranchId=@BranchId AND b.Pool='store' GROUP BY i.Id,i.ProductId,i.Sku,i.VariantName,i.UnitCostMinor;
 DECLARE @stockUnits bigint=(SELECT COALESCE(SUM(OnHand),0) FROM #stock),@stockValue bigint=(SELECT COALESCE(SUM(OnHand*COALESCE(UnitCostMinor,0)),0) FROM #stock);
 SELECT (SELECT @Period AS period,@Date AS date,@from AS startDate,DATEADD(day,-1,@until) AS endDate,'NIO' AS currencyCode,
  @sold-@returns AS netSalesMinor,@count AS salesCount,
  CASE WHEN @count=0 THEN 0 ELSE @sold/@count END AS averageTicketMinor,
  @units AS unitsSold,CASE WHEN @count=0 THEN 0 ELSE @units*100/@count END AS unitsPerTicketX100,
  @revenue AS revenueMinor,@cogs AS costOfGoodsMinor,@margin AS grossMarginMinor,
  CASE WHEN @revenue<=0 THEN 0 ELSE @margin*10000/@revenue END AS grossMarginBps,
  @discount AS discountsMinor,CASE WHEN @subtotal=0 THEN 0 ELSE @discount*10000/@subtotal END AS discountsBps,
  @returns AS returnsMinor,(SELECT COUNT(*) FROM #r) AS returnsCount,CASE WHEN @sold=0 THEN 0 ELSE @returns*10000/@sold END AS returnsBps,
  JSON_QUERY(COALESCE((SELECT SettlementKind AS kind,COUNT(*) AS returnsCount,SUM(CreditMinor) AS amountMinor FROM #r GROUP BY SettlementKind ORDER BY SettlementKind FOR JSON PATH),N'[]')) AS refundsByKind,
  @stockUnits AS stockUnits,@stockValue AS stockValueAtCostMinor,
  CASE WHEN @units=0 THEN NULL ELSE @stockUnits*@days/@units END AS daysOfInventory,
  JSON_QUERY(COALESCE((SELECT TOP(50) p.Id AS productId,p.Name AS name,x.received AS unitsReceived,x.sold AS unitsSold,
    CASE WHEN x.received=0 THEN 0 ELSE x.sold*10000/x.received END AS sellThroughBps
   FROM catalog.Products p CROSS APPLY(SELECT
    (SELECT COALESCE(SUM(CONVERT(bigint,m.OnHandDelta)),0) FROM inventory.StockMovements m JOIN catalog.Items i ON i.Id=m.ItemId JOIN core.Locations loc ON loc.Id=m.LocationId
      WHERE i.ProductId=p.Id AND loc.BranchId=@BranchId AND m.CreatedAt<@end AND (m.Kind='receive' OR (m.Kind='adjust' AND m.SourceType='catalog_import'))) AS received,
    (SELECT COALESCE(SUM(CONVERT(bigint,l.Quantity-l.ReturnedQuantity)),0) FROM sales.SaleLines l JOIN sales.Sales s ON s.Id=l.SaleId JOIN catalog.Items i ON i.Id=l.ItemId
      WHERE i.ProductId=p.Id AND s.BranchId=@BranchId AND s.Status<>'cancelled' AND s.CreatedAt<@end) AS sold) x
   WHERE x.received>0 ORDER BY sellThroughBps DESC,p.Name,p.Id FOR JSON PATH),N'[]')) AS sellThrough,
  JSON_QUERY(COALESCE((SELECT TOP(100) st.ItemId AS itemId,st.Sku AS sku,st.VariantName AS name,st.OnHand AS onHand,lm.LastAt AS lastMovementAt
   FROM #stock st OUTER APPLY(SELECT MAX(m.CreatedAt) AS LastAt FROM inventory.StockMovements m JOIN core.Locations loc ON loc.Id=m.LocationId WHERE m.ItemId=st.ItemId AND loc.BranchId=@BranchId) lm
   WHERE st.OnHand>0 AND (lm.LastAt IS NULL OR lm.LastAt<DATEADD(day,-60,@now)) ORDER BY lm.LastAt,st.Sku FOR JSON PATH),N'[]')) AS staleItems,
  (SELECT COUNT(*) FROM sales.StockExceptions e JOIN sales.SaleLines l ON l.Id=e.SaleLineId JOIN #s s ON s.Id=l.SaleId) AS stockExceptionsCount,
  (SELECT COALESCE(SUM(CONVERT(bigint,q.Damaged+q.Stained+q.Odor+q.Missing)),0) FROM receiving.vw_CurrentQuality q
    JOIN receiving.ScanSessions ss ON ss.Id=q.ScanSessionId JOIN receiving.ImportContainers c ON c.Id=ss.ContainerId JOIN core.Locations loc ON loc.Id=c.LocationId
    WHERE loc.BranchId=@BranchId AND q.CreatedAt>=@start AND q.CreatedAt<@end) AS qualityRejects,
  (SELECT COUNT(*) FROM sales.CashClosures cl JOIN sales.CashTills t ON t.Id=cl.TillId JOIN sales.CashRegisters reg ON reg.Id=t.RegisterId
    WHERE reg.BranchId=@BranchId AND cl.ClosedAt>=@start AND cl.ClosedAt<@end) AS tillClosures,
  (SELECT COUNT(*) FROM sales.CashClosures cl JOIN sales.CashTills t ON t.Id=cl.TillId JOIN sales.CashRegisters reg ON reg.Id=t.RegisterId
    WHERE reg.BranchId=@BranchId AND cl.ClosedAt>=@start AND cl.ClosedAt<@end AND cl.DifferenceMinor<>0) AS tillClosuresWithDifference,
  (SELECT COALESCE(SUM(cl.DifferenceMinor),0) FROM sales.CashClosures cl JOIN sales.CashTills t ON t.Id=cl.TillId JOIN sales.CashRegisters reg ON reg.Id=t.RegisterId
    WHERE reg.BranchId=@BranchId AND cl.ClosedAt>=@start AND cl.ClosedAt<@end) AS tillDifferenceMinor,
  JSON_QUERY(COALESCE((SELECT DATEPART(hour,DATEADD(hour,-6,CreatedAt)) AS hour,COUNT(*) AS salesCount,SUM(TotalMinor) AS totalMinor
   FROM #s GROUP BY DATEPART(hour,DATEADD(hour,-6,CreatedAt)) ORDER BY hour FOR JSON PATH),N'[]')) AS salesByHour
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS Json;
END;
GO
CREATE OR ALTER PROCEDURE sales.usp_KpiTeam @BranchId uniqueidentifier,@ActorId uniqueidentifier,@Period varchar(8),@Date date
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @all bit=0;
 IF NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffBranchAccess a ON a.StaffId=s.Id JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles r ON r.Id=sr.RoleId
  WHERE s.Id=@ActorId AND s.IsEnabled=1 AND a.BranchId=@BranchId AND a.IsActive=1 AND r.IsActive=1 AND r.Code IN ('SELLER','MANAGER','OWNER')) THROW 52001,'Sin acceso a indicadores del equipo.',1;
 IF EXISTS(SELECT 1 FROM security.StaffRoles sr JOIN security.Roles r ON r.Id=sr.RoleId WHERE sr.StaffId=@ActorId AND r.Code IN ('MANAGER','OWNER') AND r.IsActive=1) SET @all=1;
 IF @Period NOT IN ('day','week','month','year') OR @Date IS NULL OR @Date<'19000101' OR @Date>='99990101' THROW 51900,'Periodo o fecha invalida.',1;
 DECLARE @from date=CASE @Period WHEN 'week' THEN DATEADD(day,-DATEDIFF(day,'19000101',@Date)%7,@Date) WHEN 'month' THEN DATEFROMPARTS(YEAR(@Date),MONTH(@Date),1) WHEN 'year' THEN DATEFROMPARTS(YEAR(@Date),1,1) ELSE @Date END;
 DECLARE @until date=CASE @Period WHEN 'week' THEN DATEADD(day,7,@from) WHEN 'month' THEN DATEADD(month,1,@from) WHEN 'year' THEN DATEADD(year,1,@from) ELSE DATEADD(day,1,@from) END;
 DECLARE @start datetime2=DATEADD(hour,6,CONVERT(datetime2,@from)),@end datetime2=DATEADD(hour,6,CONVERT(datetime2,@until));
 SELECT st.Id,st.DisplayName INTO #staff FROM security.Staff st WHERE EXISTS(SELECT 1 FROM security.StaffBranchAccess a WHERE a.StaffId=st.Id AND a.BranchId=@BranchId AND a.IsActive=1);
 SELECT (SELECT @Period AS period,@Date AS date,@from AS startDate,DATEADD(day,-1,@until) AS endDate,'NIO' AS currencyCode,
  JSON_QUERY(COALESCE((SELECT st.Id AS sellerId,st.DisplayName AS name,COALESCE(s.net,0) AS netSalesMinor,COALESCE(s.units,0) AS units,COALESCE(s.tickets,0) AS tickets,
    CASE WHEN COALESCE(s.tickets,0)=0 THEN 0 ELSE s.net/s.tickets END AS averageTicketMinor,
    CASE WHEN COALESCE(s.tickets,0)=0 THEN 0 ELSE s.units*100/s.tickets END AS unitsPerTicketX100,
    COALESCE(ret.net,0) AS returnsMinor,CASE WHEN COALESCE(s.net,0)<=0 THEN 0 ELSE COALESCE(ret.net,0)*10000/s.net END AS returnsBps,
    COALESCE(s.discount,0) AS discountsMinor,
    COALESCE(s.earned,0)-COALESCE(ret.reversed,0) AS commissionPayableMinor
   FROM #staff st
   OUTER APPLY(SELECT SUM(CONVERT(bigint,l.Quantity)) AS units,SUM(l.UnitPriceMinor*l.Quantity-l.DiscountMinor) AS net,SUM(l.DiscountMinor) AS discount,
     COUNT(DISTINCT l.SaleId) AS tickets,SUM(l.CommissionMinor) AS earned
    FROM sales.SaleLines l JOIN sales.Sales v ON v.Id=l.SaleId WHERE l.SellerId=st.Id AND v.BranchId=@BranchId AND v.CreatedAt>=@start AND v.CreatedAt<@end) s
   OUTER APPLY(SELECT SUM(q.CreditMinor) AS net,
     SUM(CONVERT(bigint,FLOOR(CONVERT(decimal(28,4),q.CommissionMinor)*q.cumulative/q.sold))-CONVERT(bigint,FLOOR(CONVERT(decimal(28,4),q.CommissionMinor)*(q.cumulative-q.Quantity)/q.sold))) AS reversed
    FROM (SELECT rl.Quantity,rl.CreditMinor,l.CommissionMinor,l.Quantity AS sold,r.CreatedAt,r.BranchId,
     SUM(rl.Quantity) OVER(PARTITION BY l.Id ORDER BY r.CreatedAt,r.Id ROWS UNBOUNDED PRECEDING) AS cumulative
     FROM sales.SaleReversalLines rl JOIN sales.SaleReversals r ON r.Id=rl.ReversalId JOIN sales.SaleLines l ON l.Id=rl.SaleLineId
     WHERE l.SellerId=st.Id AND r.Status='approved') q WHERE q.BranchId=@BranchId AND q.CreatedAt>=@start AND q.CreatedAt<@end) ret
   WHERE (@all=1 OR st.Id=@ActorId) AND EXISTS(SELECT 1 FROM security.StaffRoles sr JOIN security.Roles r ON r.Id=sr.RoleId WHERE sr.StaffId=st.Id AND r.Code='SELLER')
   ORDER BY st.DisplayName,st.Id FOR JSON PATH),N'[]')) AS sellers,
  JSON_QUERY(COALESCE((SELECT st.Id AS staffId,st.DisplayName AS name,
    (SELECT COUNT(*) FROM sales.CashClosures cl WHERE cl.ClosedBy=st.Id AND cl.ClosedAt>=@start AND cl.ClosedAt<@end) AS tillClosures,
    (SELECT COALESCE(SUM(cl.DifferenceMinor),0) FROM sales.CashClosures cl WHERE cl.ClosedBy=st.Id AND cl.ClosedAt>=@start AND cl.ClosedAt<@end) AS tillDifferenceMinor,
    (SELECT COUNT(*) FROM sales.Sales v WHERE v.BranchId=@BranchId AND v.DiscountApprovedBy=st.Id AND v.CreatedAt>=@start AND v.CreatedAt<@end)
     +(SELECT COUNT(*) FROM sales.SaleReversals r WHERE r.BranchId=@BranchId AND r.ApprovedBy=st.Id AND r.Status='approved' AND r.CreatedAt>=@start AND r.CreatedAt<@end) AS approvalsCount,
    (SELECT COALESCE(SUM(v.DiscountMinor),0) FROM sales.Sales v WHERE v.BranchId=@BranchId AND v.DiscountApprovedBy=st.Id AND v.CreatedAt>=@start AND v.CreatedAt<@end)
     +(SELECT COALESCE(SUM(r.CreditMinor),0) FROM sales.SaleReversals r WHERE r.BranchId=@BranchId AND r.ApprovedBy=st.Id AND r.Status='approved' AND r.CreatedAt>=@start AND r.CreatedAt<@end) AS approvalsMinor
   FROM #staff st WHERE @all=1 AND EXISTS(SELECT 1 FROM security.StaffRoles sr JOIN security.Roles r ON r.Id=sr.RoleId WHERE sr.StaffId=st.Id AND r.Code IN ('MANAGER','OWNER'))
   ORDER BY st.DisplayName,st.Id FOR JSON PATH),N'[]')) AS managers,
  JSON_QUERY(COALESCE((SELECT st.Id AS staffId,st.DisplayName AS name,
    (SELECT COALESCE(SUM(CONVERT(bigint,e.Quantity)),0) FROM receiving.ScanEvents e WHERE e.CreatedBy=st.Id AND e.MatchStatus='matched' AND e.CreatedAt>=@start AND e.CreatedAt<@end) AS garmentsReceived,
    (SELECT COALESCE(SUM(CONVERT(bigint,q.Damaged+q.Stained+q.Odor+q.Missing)),0) FROM receiving.vw_CurrentQuality q WHERE q.ActorId=st.Id AND q.CreatedAt>=@start AND q.CreatedAt<@end) AS qualityRejects,
    (SELECT AVG(CONVERT(bigint,DATEDIFF(minute,ss.CreatedAt,ss.ClosedAt))) FROM receiving.ScanSessions ss WHERE ss.CreatedBy=st.Id AND ss.ClosedAt IS NOT NULL AND ss.ClosedAt>=@start AND ss.ClosedAt<@end) AS receptionMinutesAverage
   FROM #staff st WHERE @all=1 AND EXISTS(SELECT 1 FROM security.StaffRoles sr JOIN security.Roles r ON r.Id=sr.RoleId WHERE sr.StaffId=st.Id AND r.Code='INVENTORY')
   ORDER BY st.DisplayName,st.Id FOR JSON PATH,INCLUDE_NULL_VALUES),N'[]')) AS stockWorkers
  FOR JSON PATH,WITHOUT_ARRAY_WRAPPER) AS Json;
END;
GO
