-- savia:transactional
-- V036: D-036 recovery lock and D-037 stable outbox events (S1 and S2 in docs/production-20261122/README.md).
-- 1. sync.LocalNode.ForkGuid records the recovery fork the node was bound or last rebuilt on. A restore starts a new
--    fork, so a restored branch differs from it until a rebuild from the hub lands (sync.usp_ApplyBatch, mode rebuild).
-- 2. While a branch differs, sale, till opening and receiving are refused in SQL (51864, sync.recovery_pending).
--    Selling on a restored copy would reuse documents and stock the hub already holds for this branch.
-- 3. The sale, till and receipt events get ids derived from their source row (sync.fn_EventId), so a retry or a
--    re-post can never create a second event for the same row.
-- 4. A sale the rebuild brings back is listed in sync.RecoveredSales. Its event was lost with the restore and is
--    not created again: the hub already received it (D-037). The conservation oracle reads this table (V038).

ALTER TABLE [sync].[LocalNode] ADD [ForkGuid] uniqueidentifier NULL;
GO
-- Existing nodes are bound to the fork they run on now; a backup restored after this migration differs from it.
UPDATE sync.LocalNode SET ForkGuid=(SELECT recovery_fork_guid FROM sys.database_recovery_status WHERE database_id=DB_ID());
GO

CREATE TABLE [sync].[RecoveredSales] (
  [SaleId] uniqueidentifier NOT NULL,
  [ForkGuid] uniqueidentifier NOT NULL,
  [RecoveredAt] datetime2(3) NOT NULL CONSTRAINT [DF_sync_RecoveredSales_RecoveredAt] DEFAULT (SYSUTCDATETIME()),
  CONSTRAINT [PK_SyncRecoveredSales] PRIMARY KEY ([SaleId]),
  CONSTRAINT [FK_SyncRecoveredSales_Sale] FOREIGN KEY ([SaleId]) REFERENCES [sales].[Sales]([Id])
);
GO

-- 1 when this database is a branch restored from a backup and not yet rebuilt from the hub. The hub never locks.
CREATE OR ALTER FUNCTION [sync].[fn_Recovering]()
RETURNS bit
AS
BEGIN
 RETURN CASE WHEN EXISTS(SELECT 1 FROM sync.LocalNode l JOIN sync.Nodes n ON n.Id=l.NodeId
   WHERE n.Kind='branch'
     AND l.ForkGuid<>(SELECT recovery_fork_guid FROM sys.database_recovery_status WHERE database_id=DB_ID()))
   THEN 1 ELSE 0 END;
END;
GO

CREATE OR ALTER PROCEDURE [sync].[usp_AssertNotRecovering]
AS
BEGIN
 SET NOCOUNT ON;
 IF sync.fn_Recovering()=1
   THROW 51864,'Sucursal restaurada: no se puede vender, abrir caja ni recibir hasta que termine la reconstruccion desde el hub.',1;
END;
GO

-- The same event type and source row always give the same event id (first 16 bytes of SHA-256).
CREATE OR ALTER FUNCTION [sync].[fn_EventId](@EventType varchar(80),@SourceId uniqueidentifier)
RETURNS uniqueidentifier
WITH SCHEMABINDING
AS
BEGIN
 RETURN CONVERT(uniqueidentifier,CONVERT(binary(16),
   HASHBYTES('SHA2_256',CONCAT(@EventType,'|',CONVERT(char(36),@SourceId)))));
END;
GO

CREATE OR ALTER PROCEDURE [sync].[usp_SetLocalNode]
 @NodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
   DECLARE @current uniqueidentifier=(SELECT NodeId FROM sync.LocalNode WITH (UPDLOCK,HOLDLOCK));
   -- A retry never moves ForkGuid: on a restored copy that would lift the recovery lock without a rebuild.
   IF @current=@NodeId BEGIN COMMIT; RETURN; END;
   IF @current IS NOT NULL THROW 51806,'La base ya pertenece a otro nodo.',1;
   IF NOT EXISTS(SELECT 1 FROM sync.Nodes WHERE Id=@NodeId AND IsEnabled=1)
     THROW 51807,'Nodo inexistente o deshabilitado.',1;
   INSERT INTO sync.LocalNode(Singleton,NodeId,ForkGuid)
     SELECT 1,@NodeId,recovery_fork_guid FROM sys.database_recovery_status WHERE database_id=DB_ID();
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [sync].[usp_SourceStateJson]
 @Json nvarchar(max) OUTPUT
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF NOT EXISTS(SELECT 1 FROM sync.LocalNode) THROW 51855,'La base no sabe que nodo es (sync.LocalNode).',1;
 DECLARE @ownTran bit=0;
 IF @@TRANCOUNT=0 BEGIN SET TRANSACTION ISOLATION LEVEL SNAPSHOT; BEGIN TRANSACTION; SET @ownTran=1; END;
 SET @Json=(SELECT (SELECT NodeId FROM sync.LocalNode) AS node,
                   (SELECT recovery_fork_guid FROM sys.database_recovery_status WHERE database_id=DB_ID()) AS fork,
                   CHANGE_TRACKING_CURRENT_VERSION() AS [version],
                   sync.fn_Recovering() AS recovering,
                   (SELECT MAX([Version]) FROM dbo.SaviaMigrations) AS [schema],
                   JSON_QUERY((SELECT st.TableName AS t,CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID(st.TableName)) AS [min]
                               FROM sync.SyncTables st ORDER BY st.ApplyOrder FOR JSON PATH, INCLUDE_NULL_VALUES)) AS tables
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
 IF @ownTran=1 COMMIT;
END;
GO

CREATE OR ALTER PROCEDURE [sync].[usp_ApplyBatch]
 @PeerNodeId uniqueidentifier,@BatchJson nvarchar(max),@Json nvarchar(max) OUTPUT
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @me uniqueidentifier=(SELECT NodeId FROM sync.LocalNode);
 IF @me IS NULL THROW 51855,'La base no sabe que nodo es (sync.LocalNode).',1;
 IF ISJSON(@BatchJson)<>1 THROW 51861,'Lote de sincronizacion invalido.',1;
 DECLARE @node uniqueidentifier=TRY_CONVERT(uniqueidentifier,JSON_VALUE(@BatchJson,'$.node')),
   @fork uniqueidentifier=TRY_CONVERT(uniqueidentifier,JSON_VALUE(@BatchJson,'$.fork')),
   @to bigint=TRY_CONVERT(bigint,JSON_VALUE(@BatchJson,'$.to')),
   @mode varchar(10)=JSON_VALUE(@BatchJson,'$.mode'),
   @token uniqueidentifier=TRY_CONVERT(uniqueidentifier,JSON_VALUE(@BatchJson,'$.rebuild')),
   @isHub bit=CASE WHEN (SELECT Kind FROM sync.Nodes WHERE Id=@me)='azure' THEN 1 ELSE 0 END;
 IF @node IS NULL OR @fork IS NULL OR @to IS NULL OR ISNULL(@mode,'') NOT IN ('normal','rebuild')
   THROW 51861,'Lote de sincronizacion invalido.',1;
 IF @node<>@PeerNodeId OR sync.fn_PeerAllowed(@me,@PeerNodeId)=0 THROW 51850,'Par de nodos no permitido.',1;
 IF @mode='rebuild' AND @isHub=1 THROW 51850,'El hub no acepta un lote de reconstruccion.',1;
 IF @mode='rebuild' AND @token IS NULL THROW 51861,'Lote de reconstruccion sin token.',1;
 IF ISNULL(JSON_VALUE(@BatchJson,'$.schema'),'')<>(SELECT MAX([Version]) FROM dbo.SaviaMigrations)
   THROW 51856,'Version de esquema distinta.',1;
 DECLARE @b TABLE(t sysname PRIMARY KEY,a varchar(20),f bigint,[rows] nvarchar(max));
 INSERT @b SELECT t,a,f,[rows] FROM OPENJSON(@BatchJson,'$.tables')
   WITH (t sysname,a varchar(20),f bigint,[rows] nvarchar(max) AS JSON);
 IF EXISTS(SELECT 1 FROM @b b WHERE NOT EXISTS(SELECT 1 FROM sync.SyncTables st WHERE st.TableName=b.t))
   THROW 51856,'El lote trae una tabla no sincronizada.',1;
 IF EXISTS(SELECT 1 FROM @b WHERE a NOT IN ('initial','recover','reinit','incremental','rebuild') OR (a='incremental' AND f IS NULL)
           OR (a='rebuild' AND @mode<>'rebuild') OR ISJSON(ISNULL([rows],N'x'))<>1)
   THROW 51861,'Lote de sincronizacion invalido.',1;

 DECLARE @tc int=@@TRANCOUNT,@lock nvarchar(255)=N'savia.sync.apply.'+CONVERT(nvarchar(36),@PeerNodeId),@rc int;
 IF @tc=0 BEGIN TRANSACTION;
 BEGIN TRY
 EXEC @rc=sys.sp_getapplock @Resource=@lock,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=30000;
 IF @rc<0 THROW 51863,'Otro lote del mismo nodo se esta aplicando.',1;
 IF EXISTS(SELECT 1 FROM sync.RetiredForks WHERE PeerNodeId=@PeerNodeId AND ForkGuid=@fork)
   THROW 51853,'Lote de un fork retirado (anterior a una restauracion).',1;
 IF @isHub=1 AND EXISTS(SELECT 1 FROM sync.PeerCursors WHERE PeerNodeId=@PeerNodeId AND ForkGuid<>@fork)
    AND NOT EXISTS(SELECT 1 FROM sync.PeerRebuilds WHERE PeerNodeId=@PeerNodeId AND ForkGuid=@fork AND Token=@token)
   THROW 51854,'El nodo restaurado debe reconstruirse desde el hub antes de enviar.',1;
 -- D-037: own sales that only the rebuild brings back. Their events left with the lost fork; none is created again.
 DECLARE @recovered TABLE(SaleId uniqueidentifier PRIMARY KEY);
 IF @mode='rebuild'
   INSERT @recovered SELECT r.Id FROM @b b CROSS APPLY OPENJSON(b.[rows]) WITH (Id uniqueidentifier,OriginNodeId uniqueidentifier) r
   WHERE b.t=N'[sales].[Sales]' AND ISNULL(r.OriginNodeId,@me)=@me AND NOT EXISTS(SELECT 1 FROM sales.Sales s WHERE s.Id=r.Id);

 DECLARE @changed int=0,@applied int=0,@skipped int=0,@n int,@bad int;
 DECLARE @t sysname,@a varchar(20),@f bigint,@rows nvarchar(max),@owner nvarchar(600),@with nvarchar(max),@ins nvarchar(max),
   @val nvarchar(max),@upd nvarchar(max),@diffS nvarchar(max),@diffT nvarchar(max),@on nvarchar(max),@sql nvarchar(max),
   @cf uniqueidentifier,@cv bigint;
 DECLARE c CURSOR LOCAL FAST_FORWARD FOR
   SELECT s.TableName,b.a,b.f,b.[rows],s.OwnerExpr,s.WithList,s.InsList,s.ValList,s.UpdList,s.DiffS,s.DiffT,s.OnList
   FROM sync.fn_TableShape() s JOIN @b b ON b.t=s.TableName ORDER BY s.ApplyOrder;
 OPEN c;
 FETCH NEXT FROM c INTO @t,@a,@f,@rows,@owner,@with,@ins,@val,@upd,@diffS,@diffT,@on;
 WHILE @@FETCH_STATUS=0
 BEGIN
   SELECT @cf=NULL,@cv=NULL;
   SELECT @cf=ForkGuid,@cv=[Version] FROM sync.PeerCursors WITH (UPDLOCK,HOLDLOCK) WHERE PeerNodeId=@PeerNodeId AND TableName=@t;
   IF @mode='normal' AND @cf=@fork AND @cv>=@to
     SET @skipped+=1;   -- duplicate or late batch: this state is already here
   ELSE
   BEGIN
     IF @a='incremental' AND (@cf IS NULL OR @cf<>@fork OR @f>@cv)
       THROW 51852,'Lote incremental con hueco o de otro fork.',1;
     IF @mode='rebuild'
       SET @sql=NULL;
     ELSE IF @isHub=1
       SET @sql=N'SELECT @bad=COUNT(*) FROM OPENJSON(@rows) WITH ('+@with+N') t WHERE ISNULL(('+@owner
         +N'),''00000000-0000-0000-0000-000000000000'')<>@peer;';
     ELSE
       SET @sql=N'SELECT @bad=COUNT(*) FROM OPENJSON(@rows) WITH ('+@with+N') t WHERE ('+@owner+N')=@me;';
     IF @sql IS NOT NULL
     BEGIN
       SET @bad=0;
       EXEC sys.sp_executesql @sql,N'@rows nvarchar(max),@peer uniqueidentifier,@me uniqueidentifier,@bad int OUTPUT',
            @rows=@rows,@peer=@PeerNodeId,@me=@me,@bad=@bad OUTPUT;
       IF @bad>0 THROW 51851,'El lote trae filas que pertenecen a otro nodo.',1;
     END;
     IF @mode='normal'
     BEGIN
       -- V034: a row already here keeps its owner. MERGE matches on the key alone, so without this check a sender
       -- could reuse another node's key with its own owner value and take the row over.
       SET @sql=N'SELECT @bad=COUNT(*) FROM OPENJSON(@rows) WITH ('+@with+N') s JOIN '+@t+N' t ON '+@on+N' WHERE '
         +CASE WHEN @isHub=1 THEN N'ISNULL(('+@owner+N'),''00000000-0000-0000-0000-000000000000'')<>@peer'
               ELSE N'('+@owner+N')=@me' END+N';';
       SET @bad=0;
       EXEC sys.sp_executesql @sql,N'@rows nvarchar(max),@peer uniqueidentifier,@me uniqueidentifier,@bad int OUTPUT',
            @rows=@rows,@peer=@PeerNodeId,@me=@me,@bad=@bad OUTPUT;
       IF @bad>0 THROW 51851,'El lote trae filas que pertenecen a otro nodo.',1;
     END;
     SET @sql=N'MERGE '+@t+N' WITH (HOLDLOCK) AS t USING (SELECT * FROM OPENJSON(@rows) WITH ('+@with+N')) AS s ON '+@on
       +CASE WHEN @upd IS NULL THEN N'' ELSE N' WHEN MATCHED AND EXISTS(SELECT '+@diffS+N' EXCEPT SELECT '+@diffT
       +N') THEN UPDATE SET '+@upd END
       +N' WHEN NOT MATCHED BY TARGET THEN INSERT ('+@ins+N') VALUES ('+@val+N'); SET @n=@@ROWCOUNT;';
     SET @n=0;
     EXEC sys.sp_executesql @sql,N'@rows nvarchar(max),@n int OUTPUT',@rows=@rows,@n=@n OUTPUT;
     SET @changed+=@n;
     SET @applied+=1;
     IF @cf IS NULL
       INSERT sync.PeerCursors(PeerNodeId,TableName,ForkGuid,[Version]) VALUES(@PeerNodeId,@t,@fork,@to);
     ELSE IF @cf<>@fork OR @to>@cv
     BEGIN
       IF @cf<>@fork AND NOT EXISTS(SELECT 1 FROM sync.RetiredForks WHERE PeerNodeId=@PeerNodeId AND ForkGuid=@cf)
         INSERT sync.RetiredForks(PeerNodeId,ForkGuid) VALUES(@PeerNodeId,@cf);
       UPDATE sync.PeerCursors SET ForkGuid=@fork,[Version]=@to,UpdatedAt=SYSUTCDATETIME()
         WHERE PeerNodeId=@PeerNodeId AND TableName=@t;
     END;
   END;
   FETCH NEXT FROM c INTO @t,@a,@f,@rows,@owner,@with,@ins,@val,@upd,@diffS,@diffT,@on;
 END;
 CLOSE c; DEALLOCATE c;
 IF @mode='rebuild'
 BEGIN
   -- Same transaction as the rows: the token exists on this branch only if the rebuild really landed.
   DECLARE @ownFork uniqueidentifier=(SELECT recovery_fork_guid FROM sys.database_recovery_status WHERE database_id=DB_ID());
   UPDATE sync.AppliedRebuilds SET Token=@token,AppliedAt=SYSUTCDATETIME() WHERE PeerNodeId=@PeerNodeId AND ForkGuid=@ownFork;
   IF @@ROWCOUNT=0 INSERT sync.AppliedRebuilds(PeerNodeId,ForkGuid,Token) VALUES(@PeerNodeId,@ownFork,@token);
   INSERT sync.RecoveredSales(SaleId,ForkGuid) SELECT SaleId,@ownFork FROM @recovered;
   -- D-036: the hub's copy has landed, so this fork may sell, open tills and receive again.
   UPDATE sync.LocalNode SET ForkGuid=@ownFork;
 END;
 IF @tc=0 COMMIT;
 END TRY
 BEGIN CATCH IF @tc=0 AND @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
 SET @Json=(SELECT @changed AS changed,@applied AS applied,@skipped AS skipped FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END;
GO

CREATE OR ALTER PROCEDURE [sales].[usp_PostSale]
 @SaleId uniqueidentifier,@BranchId uniqueidentifier,@LocationId uniqueidentifier,
 @CashierId uniqueidentifier,@CurrencyCode varchar(3),@OriginNodeId uniqueidentifier,
 @Lines [sales].[SaleLineRequest] READONLY,
 @Tenders [sales].[SaleTenderRequest] READONLY,
 @CustomerId uniqueidentifier=NULL,@TillId uniqueidentifier=NULL,
 @DiscountApproverId uniqueidentifier=NULL,@DiscountReason nvarchar(250)=NULL,@StockExceptionNote nvarchar(500)=NULL,@SellersJson nvarchar(max)=NULL,@FxJson nvarchar(max)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 EXEC sync.usp_AssertNotRecovering;
 IF @CustomerId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM @Tenders WHERE TenderKind='credit')
 AND NOT EXISTS(SELECT 1 FROM security.StaffRoles sr JOIN security.Roles r ON r.Id=sr.RoleId WHERE sr.StaffId=@CashierId AND r.Code='CASHIER')
 THROW 52005,'Una venta normal no lleva datos de cliente.',1;
 DECLARE @sellers TABLE(LineNumber int PRIMARY KEY,SellerId uniqueidentifier);
 IF @SellersJson IS NOT NULL
 BEGIN
  IF ISJSON(@SellersJson)<>1 THROW 52002,'Indique la vendedora de cada linea.',1;
  INSERT @sellers SELECT lineNumber,sellerId FROM OPENJSON(@SellersJson) WITH(lineNumber int,sellerId uniqueidentifier);
 END;
 -- Old CASHIER fixtures can replay historical API contracts. Real pilot roles always require attribution.
 IF @SellersJson IS NULL AND NOT EXISTS(SELECT 1 FROM security.StaffRoles sr JOIN security.Roles r ON r.Id=sr.RoleId WHERE sr.StaffId=@CashierId AND r.Code='CASHIER')
 THROW 52002,'Indique la vendedora de cada linea.',1;
 IF @SellersJson IS NOT NULL AND (EXISTS(SELECT 1 FROM @Lines l LEFT JOIN @sellers s ON s.LineNumber=l.LineNumber WHERE s.SellerId IS NULL)
 OR EXISTS(SELECT 1 FROM @sellers s WHERE NOT EXISTS(SELECT 1 FROM @Lines l WHERE l.LineNumber=s.LineNumber))
 OR EXISTS(SELECT 1 FROM @sellers x WHERE NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles r ON r.Id=sr.RoleId
 JOIN security.StaffBranchAccess a ON a.StaffId=s.Id WHERE s.Id=x.SellerId AND s.IsEnabled=1 AND r.Code='SELLER' AND r.IsActive=1 AND a.BranchId=@BranchId AND a.IsActive=1)))
 THROW 52002,'La vendedora debe estar activa en esta sucursal.',1;
 IF (SELECT COUNT(DISTINCT SellerId) FROM @sellers)>3 THROW 52009,'Una venta admite hasta tres vendedoras.',1;

 IF NOT EXISTS(SELECT 1 FROM @Lines) THROW 51507,'Venta sin articulos.',1;
 IF EXISTS(SELECT 1 FROM @Lines WHERE Quantity NOT BETWEEN 1 AND 1000000 OR
      UnitPriceMinor<0 OR DiscountMinor<0 OR
      CAST(UnitPriceMinor AS decimal(28,0))*Quantity<DiscountMinor)
   THROW 51508,'Linea de venta invalida.',1;
 IF EXISTS(SELECT 1 FROM @Tenders WHERE AmountMinor<=0 OR TenderKind NOT IN
   ('cash','card','transfer','credit','other') OR
   (TenderKind='credit' AND (CreditId IS NULL OR @CustomerId IS NULL)) OR
   (TenderKind<>'credit' AND CreditId IS NOT NULL) OR
   (TenderKind='cash' AND @FxJson IS NULL AND (ReceivedMinor IS NULL OR ChangeMinor IS NULL OR
      ReceivedMinor-ChangeMinor<>AmountMinor)) OR
   (TenderKind<>'cash' AND (ReceivedMinor IS NOT NULL OR ChangeMinor IS NOT NULL)) OR
   (TenderKind='transfer' AND (Reference IS NULL OR LEN(LTRIM(RTRIM(Reference)))=0)))
   THROW 51509,'Formas de pago invalidas o sin autorizacion de referencia.',1;
 DECLARE @input nvarchar(max)=(SELECT JSON_QUERY(@FxJson) AS fx, @BranchId AS branchId,@LocationId AS locationId,
   JSON_QUERY(@SellersJson) AS sellers,@CashierId AS cashierId,@DiscountReason AS discountReason,@StockExceptionNote AS stockExceptionNote,@CurrencyCode AS currency,@CustomerId AS customerId,@TillId AS tillId,
   JSON_QUERY((SELECT * FROM @Lines ORDER BY LineNumber FOR JSON PATH)) AS lines,
   JSON_QUERY((SELECT * FROM @Tenders ORDER BY TenderNumber FOR JSON PATH)) AS tenders
   FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
 DECLARE @fingerprint varbinary(32)=HASHBYTES('SHA2_256',CONVERT(varbinary(max),@input));
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM sales.Sales WITH(UPDLOCK,HOLDLOCK) WHERE Id=@SaleId)
   BEGIN
     IF EXISTS(SELECT 1 FROM sales.Sales WHERE Id=@SaleId AND RequestHash<>@fingerprint)
       THROW 51510,'SaleId reutilizado con datos distintos.',1;
     COMMIT; RETURN;
   END;
   -- Replay was resolved first. Lock drawers in the same order as pair close.
   DECLARE @parentStatus varchar(16),@child uniqueidentifier,@childStatus varchar(16);
   SELECT @parentStatus=Status FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TillId AND ParentTillId IS NULL AND CurrencyCode='NIO';
   IF @TillId IS NULL THROW 51514,'Indique el turno de caja.',1;
   IF EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@TillId AND ParentTillId IS NOT NULL) THROW 52106,'Use el turno padre NIO.',1;
   IF @parentStatus IS NULL OR @parentStatus<>'open' THROW 51515,'Turno padre no abierto.',1;
   SELECT @child=Id,@childStatus=Status FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE ParentTillId=@TillId;
   DECLARE @fx TABLE(TenderNumber int,ForeignCurrencyCode varchar(3),ForeignReceivedMinor bigint,ExchangeRateId uniqueidentifier,
     ExchangeRate decimal(9,4),RoundingMinor bigint,ReceivedMinor bigint,ChangeMinor bigint,ForeignChangeMinor bigint,ForeignChangeNioMinor bigint);
   IF @FxJson IS NOT NULL
   BEGIN
    IF ISJSON(@FxJson)<>1 THROW 52102,'Pago extranjero invalido.',1;
    INSERT @fx(TenderNumber,ForeignCurrencyCode,ForeignReceivedMinor,ExchangeRateId,RoundingMinor,ExchangeRate,ForeignChangeMinor)
     SELECT tenderNumber,foreignCurrencyCode,foreignReceivedMinor,exchangeRateId,roundingMinor,exchangeRate,COALESCE(foreignChangeMinor,0) FROM OPENJSON(@FxJson)
     WITH(tenderNumber int,foreignCurrencyCode varchar(3),foreignReceivedMinor bigint,exchangeRateId uniqueidentifier,roundingMinor bigint,exchangeRate decimal(9,4),foreignChangeMinor bigint);
    IF (SELECT COUNT(*) FROM @fx)<>1 OR @child IS NULL OR @childStatus<>'open' OR @CurrencyCode<>'NIO'
     OR EXISTS(SELECT 1 FROM @fx f LEFT JOIN @Tenders t ON t.TenderNumber=f.TenderNumber WHERE t.TenderNumber IS NULL OR t.TenderKind<>'cash'
       OR f.ForeignCurrencyCode IS NULL OR f.ForeignCurrencyCode<>'USD' OR f.ForeignReceivedMinor IS NULL OR f.ForeignReceivedMinor<=0 OR f.ExchangeRateId IS NULL OR f.ForeignChangeMinor<0 OR f.ForeignChangeMinor>=f.ForeignReceivedMinor)
     THROW 52102,'Pago extranjero invalido o gaveta USD no abierta.',1;
    DECLARE @rateId uniqueidentifier,@rate decimal(9,4);
    SELECT TOP(1) @rateId=Id,@rate=Rate FROM core.ExchangeRates WITH(HOLDLOCK)
      WHERE CurrencyCode='USD' AND EffectiveFrom<=CAST(DATEADD(hour,-6,core.ufn_BusinessNow()) AS date) ORDER BY EffectiveFrom DESC;
    IF @rateId IS NULL OR EXISTS(SELECT 1 FROM @fx WHERE ExchangeRateId<>@rateId OR (ExchangeRate IS NOT NULL AND ExchangeRate<>@rate))
      THROW 52103,'Tasa no vigente.',1;
    UPDATE @fx SET ReceivedMinor=CONVERT(bigint,ROUND(CONVERT(decimal(28,4),ForeignReceivedMinor)*@rate,0));
    UPDATE @fx SET ForeignChangeNioMinor=CONVERT(bigint,ROUND(CONVERT(decimal(28,4),ForeignChangeMinor)*@rate,0));
    IF EXISTS(SELECT 1 FROM @fx f JOIN @Tenders t ON t.TenderNumber=f.TenderNumber
     WHERE (f.ReceivedMinor<t.AmountMinor AND f.ForeignChangeMinor<>0)
     OR (f.ReceivedMinor>=t.AmountMinor AND f.ForeignChangeNioMinor>f.ReceivedMinor-t.AmountMinor))
     THROW 52104,'Vuelto USD invalido.',1;
    UPDATE f SET ChangeMinor=CASE WHEN f.ReceivedMinor>=t.AmountMinor THEN
     (f.ReceivedMinor-t.AmountMinor-f.ForeignChangeNioMinor)-(f.ReceivedMinor-t.AmountMinor-f.ForeignChangeNioMinor)%5 ELSE 0 END
     FROM @fx f JOIN @Tenders t ON t.TenderNumber=f.TenderNumber;
    UPDATE @fx SET ChangeMinor=ChangeMinor-5 WHERE ChangeMinor IN (5,15);
    IF EXISTS(SELECT 1 FROM @fx f JOIN @Tenders t ON t.TenderNumber=f.TenderNumber WHERE f.ReceivedMinor-t.AmountMinor<=-100
      OR (t.ReceivedMinor IS NOT NULL AND t.ReceivedMinor<>f.ReceivedMinor) OR (t.ChangeMinor IS NOT NULL AND t.ChangeMinor<>f.ChangeMinor)
      OR (f.RoundingMinor IS NOT NULL AND f.RoundingMinor<>f.ReceivedMinor-f.ChangeMinor-f.ForeignChangeNioMinor-t.AmountMinor))
      THROW 52104,'Conversion o redondeo invalido.',1;
    UPDATE f SET RoundingMinor=f.ReceivedMinor-f.ChangeMinor-f.ForeignChangeNioMinor-t.AmountMinor,ExchangeRate=@rate FROM @fx f JOIN @Tenders t ON t.TenderNumber=f.TenderNumber;
    IF (SELECT COALESCE(SUM(DeltaMinor),0) FROM sales.CashEntries WHERE TillId=@TillId)
     +(SELECT COALESCE(SUM(t.AmountMinor),0) FROM @Tenders t WHERE t.TenderKind='cash'
       AND NOT EXISTS(SELECT 1 FROM @fx f WHERE f.TenderNumber=t.TenderNumber))<(SELECT ChangeMinor FROM @fx)
      THROW 52105,'No hay cordobas para el vuelto.',1;
   END;
   IF EXISTS(SELECT 1 FROM @Tenders t WHERE t.TenderKind='cash' AND NOT EXISTS(SELECT 1 FROM @fx f WHERE f.TenderNumber=t.TenderNumber)
     AND (t.ReceivedMinor IS NULL OR t.ChangeMinor IS NULL OR t.ReceivedMinor-t.ChangeMinor<>t.AmountMinor)) THROW 51509,'Efectivo invalido.',1;
   IF EXISTS(SELECT 1 FROM @Lines WHERE DiscountMinor>0)
   BEGIN
     SET @DiscountApproverId=COALESCE(@DiscountApproverId,@CashierId);
     IF NOT EXISTS(SELECT 1 FROM security.Staff s
       JOIN security.StaffBranchAccess a ON a.StaffId=s.Id AND a.BranchId=@BranchId AND a.IsActive=1
       JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles r ON r.Id=sr.RoleId
       WHERE s.Id=@DiscountApproverId AND s.IsEnabled=1 AND r.Code IN ('MANAGER','OWNER'))
       THROW 51544,'Todo descuento requiere autorizacion de supervision.',1;
     IF NULLIF(LTRIM(RTRIM(@DiscountReason)),N'') IS NULL THROW 51547,'Indique el motivo del descuento.',1;
   END;
   ELSE BEGIN SET @DiscountApproverId=NULL; SET @DiscountReason=NULL; END;
   IF NOT EXISTS(SELECT 1 FROM core.Locations WHERE Id=@LocationId AND BranchId=@BranchId)
      THROW 51511,'Ubicacion no pertenece a sucursal.',1;
   IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a JOIN security.Staff s ON s.Id=a.StaffId
      WHERE a.StaffId=@CashierId AND a.BranchId=@BranchId AND a.IsActive=1 AND s.IsEnabled=1)
      THROW 51512,'Cajero sin acceso a sucursal.',1;
   IF EXISTS(SELECT 1 FROM @Lines l LEFT JOIN catalog.Items i ON i.Id=l.ItemId
       WHERE i.Id IS NULL OR i.Status<>'active' OR i.UnitCostMinor IS NULL OR i.CurrencyCode<>@CurrencyCode
        OR i.UnitPriceMinor<>l.UnitPriceMinor)
      THROW 51513,'Producto, moneda o precio desactualizado.',1;
   IF @TillId IS NULL THROW 51514,'Venta POS requiere turno de caja abierto, incluso con tarjeta.',1;
   BEGIN

     IF NOT EXISTS(SELECT 1 FROM sales.CashTills t JOIN sales.CashRegisters r ON r.Id=t.RegisterId
         WHERE t.Id=@TillId AND t.Status='open' AND t.CurrencyCode=@CurrencyCode
         AND r.BranchId=@BranchId AND r.LocationId=@LocationId AND t.CashierId=@CashierId)
        THROW 51515,'El turno de caja no coincide con la venta.',1;
   END;
   DECLARE @calc TABLE(LineNumber int PRIMARY KEY,ItemId uniqueidentifier,Quantity int,
      UnitPriceMinor bigint,DiscountMinor bigint,TaxMinor bigint,TotalMinor bigint);
   INSERT INTO @calc(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor,TaxMinor,TotalMinor)
   SELECT l.LineNumber,l.ItemId,l.Quantity,l.UnitPriceMinor,l.DiscountMinor,
      CAST(ROUND((CAST(l.UnitPriceMinor AS decimal(28,0))*l.Quantity-l.DiscountMinor)
          *i.TaxRateBps/10000.0,0) AS bigint),
      CAST(l.UnitPriceMinor AS bigint)*l.Quantity-l.DiscountMinor+
        CAST(ROUND((CAST(l.UnitPriceMinor AS decimal(28,0))*l.Quantity-l.DiscountMinor)
          *i.TaxRateBps/10000.0,0) AS bigint)
   FROM @Lines l JOIN catalog.Items i ON i.Id=l.ItemId;
   DECLARE @subtotal bigint=(SELECT SUM(CAST(UnitPriceMinor AS bigint)*Quantity) FROM @calc),
     @discount bigint=(SELECT SUM(DiscountMinor) FROM @calc),
     @tax bigint=(SELECT SUM(TaxMinor) FROM @calc),
     @total bigint=(SELECT SUM(TotalMinor) FROM @calc);
   IF @total IS NULL OR @total<0 OR @total>9000000000000
      THROW 51516,'Total de venta invalido.',1;
   IF (SELECT COALESCE(SUM(AmountMinor),0) FROM @Tenders)<>@total
      THROW 51517,'Pagos no coinciden con total.',1;
   -- The branch row serializes its receipt sequence. Rolled-back sales consume no number.
   DECLARE @sequence bigint;
   SELECT @sequence=1 FROM core.Branches WITH(UPDLOCK,HOLDLOCK) WHERE Id=@BranchId;
   SELECT @sequence=COALESCE(MAX(ReceiptSequence),0)+1 FROM sales.Sales WHERE BranchId=@BranchId;
   INSERT INTO sales.Sales(Id,BranchId,LocationId,CustomerId,CashierId,TillId,CurrencyCode,
     SubtotalMinor,DiscountMinor,TaxMinor,TotalMinor,Channel,OriginNodeId,RequestHash,CreatedBy,DiscountApprovedBy,DiscountReason,ReceiptSequence)
     VALUES(@SaleId,@BranchId,@LocationId,@CustomerId,@CashierId,@TillId,@CurrencyCode,
     @subtotal,@discount,@tax,@total,'pos',@OriginNodeId,@fingerprint,@CashierId,@DiscountApproverId,@DiscountReason,@sequence);
   INSERT INTO sales.SaleLines(SaleId,LineNumber,ItemId,SkuSnapshot,NameSnapshot,
     Quantity,UnitPriceMinor,CostUnitSnapshotMinor,COGSMinor,DiscountMinor,TaxMinor,TotalMinor,CreatedBy,SellerId,CommissionRateBps,CommissionMinor)
   SELECT @SaleId,c.LineNumber,c.ItemId,i.Sku,i.VariantName,c.Quantity,c.UnitPriceMinor,
     i.UnitCostMinor,i.UnitCostMinor*CONVERT(bigint,c.Quantity),
     c.DiscountMinor,c.TaxMinor,c.TotalMinor,@CashierId,x.SellerId,COALESCE(rate.RateBps,300),
     CONVERT(bigint,FLOOR(CONVERT(decimal(28,4),c.UnitPriceMinor*c.Quantity-c.DiscountMinor)*COALESCE(rate.RateBps,300)/10000))
   FROM @calc c JOIN catalog.Items i ON i.Id=c.ItemId LEFT JOIN @sellers x ON x.LineNumber=c.LineNumber
   LEFT JOIN sales.SellerRates rate ON rate.SellerId=x.SellerId;
   DECLARE @item uniqueidentifier,@qty int,@op uniqueidentifier,@mv uniqueidentifier,@negQty int,@lineNo int,@available int,@short int,@exception uniqueidentifier;
   DECLARE lineCursor CURSOR LOCAL FAST_FORWARD FOR SELECT LineNumber,ItemId,Quantity FROM @calc ORDER BY ItemId,LineNumber;
   OPEN lineCursor; FETCH NEXT FROM lineCursor INTO @lineNo,@item,@qty;
   WHILE @@FETCH_STATUS=0
   BEGIN
     SET @available=0;
     SELECT @available=OnHand-Reserved FROM inventory.StockBalances WITH(UPDLOCK,HOLDLOCK)
      WHERE ItemId=@item AND LocationId=@LocationId AND Pool='store';
     SET @short=@qty-COALESCE(@available,0);
     IF @short>0
     BEGIN
       IF NULLIF(LTRIM(RTRIM(@StockExceptionNote)),N'') IS NULL
        THROW 51102,'Confirme que la prenda esta en la tienda e indique una nota.',1;
       SET @exception=NEWID();
       INSERT INTO sales.StockExceptions(Id,SaleLineId,ItemId,QuantityShort,CashierId,Note)
        SELECT @exception,Id,@item,@short,@CashierId,@StockExceptionNote FROM sales.SaleLines WHERE SaleId=@SaleId AND LineNumber=@lineNo;
       SET @op=NEWID(); SET @mv=NULL;
       -- Recognize physical stock omitted by the system, then sell it normally.
       -- Source is the exception, so sale.stock_vs_lines still sees exactly -Quantity.
       EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@LocationId,
        @Pool='store',@Kind='adjust',@OnHandDelta=@short,@SourceType='stock_exception',@SourceId=@exception,
        @ActorId=@CashierId,@MovementId=@mv OUTPUT;
     END;
     SET @op=NEWID(); SET @mv=NULL; SET @negQty=-@qty;
     EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@LocationId,
       @Pool='store',@Kind='sale',@OnHandDelta=@negQty,
       @SourceType='sale',@SourceId=@SaleId,@ActorId=@CashierId,@MovementId=@mv OUTPUT;
     FETCH NEXT FROM lineCursor INTO @lineNo,@item,@qty;
   END;
   CLOSE lineCursor; DEALLOCATE lineCursor;
   DECLARE @tno int,@tkind varchar(20),@amt bigint,@credit uniqueidentifier,
      @received bigint,@change bigint,@ref nvarchar(120),@tenderId uniqueidentifier,@redeemId uniqueidentifier;
   DECLARE tenderCursor CURSOR LOCAL FAST_FORWARD FOR
      SELECT TenderNumber,TenderKind,AmountMinor,CreditId,ReceivedMinor,ChangeMinor,Reference
      FROM @Tenders ORDER BY TenderNumber;
   OPEN tenderCursor; FETCH NEXT FROM tenderCursor INTO @tno,@tkind,@amt,@credit,@received,@change,@ref;
   WHILE @@FETCH_STATUS=0
   BEGIN
     SET @tenderId=NEWID();
     INSERT INTO sales.SaleTenders(Id,SaleId,TenderKind,CurrencyCode,AmountMinor,Reference,
       CreditId,ReceivedMinor,ChangeMinor,CreatedBy,ForeignCurrencyCode,ForeignReceivedMinor,ExchangeRateId,ExchangeRate,RoundingMinor,ForeignChangeMinor)
       SELECT @tenderId,@SaleId,@tkind,@CurrencyCode,@amt,@ref,@credit,COALESCE(f.ReceivedMinor,@received),COALESCE(f.ChangeMinor,@change),@CashierId,
       f.ForeignCurrencyCode,f.ForeignReceivedMinor,f.ExchangeRateId,f.ExchangeRate,f.RoundingMinor,f.ForeignChangeMinor FROM (VALUES(1)) v(n) LEFT JOIN @fx f ON f.TenderNumber=@tno;
     IF @tkind='cash' AND NOT EXISTS(SELECT 1 FROM @fx WHERE TenderNumber=@tno)
       INSERT INTO sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,SaleTenderId,ActorId,CreatedBy)
         VALUES(NEWID(),@TillId,@CurrencyCode,'sale',@amt,@tenderId,@CashierId,@CashierId);
     IF EXISTS(SELECT 1 FROM @fx WHERE TenderNumber=@tno)
     BEGIN
      INSERT sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,SaleTenderId,ActorId,CreatedBy)
       SELECT NEWID(),@child,'USD','sale',ForeignReceivedMinor,@tenderId,@CashierId,@CashierId FROM @fx WHERE TenderNumber=@tno;
      INSERT sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,SaleTenderId,ActorId,CreatedBy)
       SELECT NEWID(),@TillId,'NIO','change',-ChangeMinor,@tenderId,@CashierId,@CashierId FROM @fx WHERE TenderNumber=@tno AND ChangeMinor>0;
      INSERT sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,SaleTenderId,ActorId,CreatedBy)
       SELECT NEWID(),@child,'USD','change',-ForeignChangeMinor,@tenderId,@CashierId,@CashierId FROM @fx WHERE TenderNumber=@tno AND ForeignChangeMinor>0;
     END;
     IF @tkind='credit'
     BEGIN
       SET @redeemId=NEWID();
       EXEC credits.usp_RedeemCredit @RedemptionId=@redeemId,@CreditId=@credit,@BranchId=@BranchId,
          @SaleId=@SaleId,@AmountMinor=@amt,@ActorId=@CashierId;
     END;
     FETCH NEXT FROM tenderCursor INTO @tno,@tkind,@amt,@credit,@received,@change,@ref;
   END;
   CLOSE tenderCursor; DEALLOCATE tenderCursor;
   DECLARE @event uniqueidentifier=sync.fn_EventId('sales.sale_posted',@SaleId),@payload nvarchar(max)=(
     SELECT @SaleId AS saleId,@BranchId AS branchId,@LocationId AS locationId,
        @CurrencyCode AS currency,@total AS totalMinor,@OriginNodeId AS originNodeId,
        JSON_QUERY((SELECT sl.ItemId,sl.Quantity,sl.UnitPriceMinor,sl.TaxMinor,sl.TotalMinor
          FROM sales.SaleLines sl WHERE sl.SaleId=@SaleId FOR JSON PATH)) AS lines,
        JSON_QUERY((SELECT st.TenderKind,st.AmountMinor,st.CreditId,st.ForeignCurrencyCode,st.ForeignReceivedMinor,st.ReceivedMinor,st.ChangeMinor,st.ForeignChangeMinor,st.ForeignChangeNioMinor,st.RoundingMinor,st.ExchangeRate,st.ExchangeRateId
          FROM sales.SaleTenders st WHERE st.SaleId=@SaleId FOR JSON PATH)) AS tenders
       FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   EXEC sync.usp_EnqueueEvent @event,@OriginNodeId,'sale',@SaleId,'sales.sale_posted',@payload;
   COMMIT;
 END TRY
 BEGIN CATCH
   IF CURSOR_STATUS('local','lineCursor')>=0 BEGIN CLOSE lineCursor; DEALLOCATE lineCursor; END;
   IF CURSOR_STATUS('local','tenderCursor')>=0 BEGIN CLOSE tenderCursor; DEALLOCATE tenderCursor; END;
   IF @@TRANCOUNT>0 ROLLBACK;
   THROW;
 END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [sales].[usp_OpenTill]
 @TillId uniqueidentifier,@RegisterId uniqueidentifier,@CashierId uniqueidentifier,
 @CurrencyCode varchar(3),@OpeningMinor bigint,@OriginNodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 EXEC sync.usp_AssertNotRecovering;
 IF EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@TillId AND ParentTillId IS NOT NULL)
 THROW 52106,'Use el turno padre NIO.',1;
 IF @OpeningMinor<0 THROW 51501,'Fondo inicial invalido.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@TillId)
   BEGIN
     IF EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@TillId AND
        (RegisterId<>@RegisterId OR CashierId<>@CashierId OR CurrencyCode<>@CurrencyCode))
        -- D-B-01: the opening amount is part of the request; a different amount is another till.
        OR NOT EXISTS(SELECT 1 FROM sales.CashEntries WHERE TillId=@TillId AND Kind='opening' AND DeltaMinor=@OpeningMinor)
       THROW 51502,'TillId reutilizado incorrectamente.',1;
     COMMIT; RETURN;
   END;
   IF @CurrencyCode IS NULL OR @CurrencyCode<>'NIO' THROW 52106,'Use el turno padre NIO.',1;
   DECLARE @branch uniqueidentifier;
   SELECT @branch=BranchId FROM sales.CashRegisters WHERE Id=@RegisterId AND IsActive=1;
   IF @branch IS NULL THROW 51503,'Caja registradora inexistente o inactiva.',1;
   IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a JOIN security.Staff s ON s.Id=a.StaffId
      WHERE a.StaffId=@CashierId AND a.BranchId=@branch AND a.IsActive=1 AND s.IsEnabled=1)
      THROW 51504,'Cajero no autorizado en sucursal.',1;
   INSERT INTO sales.CashTills(Id,RegisterId,CashierId,CurrencyCode,CreatedBy)
     VALUES(@TillId,@RegisterId,@CashierId,@CurrencyCode,@CashierId);
   INSERT INTO sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,ActorId,CreatedBy)
     VALUES(NEWID(),@TillId,@CurrencyCode,'opening',@OpeningMinor,@CashierId,@CashierId);
   DECLARE @evt uniqueidentifier=sync.fn_EventId('cash.till_opened',@TillId),@payload nvarchar(max)=(SELECT @TillId AS tillId,
      @RegisterId AS registerId,@OpeningMinor AS openingMinor,@CurrencyCode AS currency
      FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
   EXEC sync.usp_EnqueueEvent @evt,@OriginNodeId,'cash_till',@TillId,'cash.till_opened',@payload;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE sales.usp_OpenTillCounted
 @TillId uniqueidentifier,@RegisterId uniqueidentifier,@CashierId uniqueidentifier,
 @CurrencyCode varchar(3),@OpeningMinor bigint,@OriginNodeId uniqueidentifier,@LinesJson nvarchar(max),@UsdLinesJson nvarchar(max)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 EXEC sync.usp_AssertNotRecovering;
 SET @UsdLinesJson=COALESCE(@UsdLinesJson,N'[{"denominationMinor":100,"quantity":0}]');
 IF ISJSON(@LinesJson)<>1 OR @LinesJson IS NULL THROW 51545,'Cuente el efectivo inicial por denominacion.',1;
 DECLARE @lines TABLE(DenominationMinor bigint,Quantity int);
 INSERT INTO @lines SELECT denominationMinor,quantity FROM OPENJSON(@LinesJson)
 WITH(denominationMinor bigint,quantity int);
 IF NOT EXISTS(SELECT 1 FROM @lines) OR EXISTS(SELECT 1 FROM @lines l WHERE Quantity IS NULL OR Quantity NOT BETWEEN 0 AND 1000000 OR
 NOT EXISTS(SELECT 1 FROM sales.CashDenominations d WHERE d.DenominationMinor=l.DenominationMinor AND d.CurrencyCode='NIO')) OR
 EXISTS(SELECT DenominationMinor FROM @lines GROUP BY DenominationMinor HAVING COUNT(*)>1) OR
 @OpeningMinor<>(SELECT SUM(DenominationMinor*CONVERT(bigint,Quantity)) FROM @lines) OR @CurrencyCode<>'NIO'
 THROW 51545,'El fondo inicial debe coincidir con el desglose de billetes y monedas.',1;
 BEGIN TRAN;
 BEGIN TRY
  IF EXISTS(SELECT 1 FROM sales.CashTills WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TillId)
  BEGIN
   IF NOT EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@TillId AND ParentTillId IS NULL AND RegisterId=@RegisterId AND CashierId=@CashierId AND CurrencyCode=@CurrencyCode)
    OR EXISTS(SELECT DenominationMinor,Quantity FROM @lines EXCEPT SELECT l.DenominationMinor,l.Quantity FROM sales.CashCounts c JOIN sales.CashCountLines l ON l.CashCountId=c.Id WHERE c.TillId=@TillId AND c.CountKind='opening')
    OR EXISTS(SELECT l.DenominationMinor,l.Quantity FROM sales.CashCounts c JOIN sales.CashCountLines l ON l.CashCountId=c.Id WHERE c.TillId=@TillId AND c.CountKind='opening' EXCEPT SELECT DenominationMinor,Quantity FROM @lines)
    THROW 51502,'TillId reutilizado con otro desglose.',1;
   DECLARE @existingChild uniqueidentifier=(SELECT Id FROM sales.CashTills WHERE ParentTillId=@TillId);
   IF @UsdLinesJson IS NOT NULL
   BEGIN
    IF @existingChild IS NULL THROW 51502,'Apertura distinta.',1;
    EXEC sales.usp_RecordDrawerCount @existingChild,@existingChild,@CashierId,@UsdLinesJson;
   END;
   COMMIT; RETURN;
  END;
  EXEC sales.usp_OpenTill @TillId,@RegisterId,@CashierId,@CurrencyCode,@OpeningMinor,@OriginNodeId;
  EXEC sales.usp_RecordCashCount @TillId,@TillId,@CashierId,@LinesJson;
  UPDATE sales.CashCounts SET CountKind='opening' WHERE Id=@TillId;
  -- New counted openings always create a USD drawer; omitted dollars mean zero.
  DECLARE @child uniqueidentifier=NEWID(),@usd bigint;
  SET @UsdLinesJson=COALESCE(@UsdLinesJson,N'[{"denominationMinor":100,"quantity":0}]');
  SELECT @usd=SUM(CONVERT(bigint,denominationMinor)*quantity) FROM OPENJSON(@UsdLinesJson) WITH(denominationMinor bigint,quantity int);
  INSERT sales.CashTills(Id,RegisterId,CashierId,CurrencyCode,ParentTillId,CreatedBy)
    VALUES(@child,@RegisterId,@CashierId,'USD',@TillId,@CashierId);
  INSERT sales.CashEntries(Id,TillId,CurrencyCode,Kind,DeltaMinor,ActorId,CreatedBy)
    VALUES(NEWID(),@child,'USD','opening',@usd,@CashierId,@CashierId);
  EXEC sales.usp_RecordDrawerCount @child,@child,@CashierId,@UsdLinesJson;
  UPDATE sales.CashCounts SET CountKind='opening' WHERE Id=@child;
  COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [receiving].[usp_PostScanSession]
 @ScanSessionId uniqueidentifier,@ActorId uniqueidentifier,@OriginNodeId uniqueidentifier,
 @ReceiptId uniqueidentifier OUTPUT,@CurrencyCode varchar(3)='NIO'
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 EXEC sync.usp_AssertNotRecovering;
 BEGIN TRANSACTION;
 BEGIN TRY
  DECLARE @status varchar(16),@location uniqueidentifier,@container uniqueidentifier,@po uniqueidentifier;
  SELECT @status=s.Status,@location=c.LocationId,@container=c.Id,@po=c.PurchaseOrderId
    FROM receiving.ScanSessions s WITH(UPDLOCK,HOLDLOCK)
    JOIN receiving.ImportContainers c ON c.Id=s.ContainerId WHERE s.Id=@ScanSessionId;
  IF @status='posted'
  BEGIN
    SELECT @ReceiptId=Id FROM purchasing.GoodsReceipts WHERE ScanSessionId=@ScanSessionId;
    IF @ReceiptId IS NULL THROW 51311,'Sesion marcada posted sin comprobante.',1;
    COMMIT; RETURN;
  END;
  IF @status IS NULL OR @status<>'approved' THROW 51312,'Sesion requiere aprobacion previa.',1;
  IF NOT EXISTS(SELECT 1 FROM receiving.ScanEvents WHERE ScanSessionId=@ScanSessionId AND MatchStatus<>'rejected')
    THROW 51313,'No hay lecturas.',1;
  IF EXISTS(SELECT 1 FROM receiving.ScanEvents WHERE ScanSessionId=@ScanSessionId AND MatchStatus IN ('unknown','ambiguous'))
    THROW 51314,'Hay codigos no resueltos.',1;
  IF EXISTS(SELECT 1 FROM receiving.ScanEvents e JOIN catalog.Items i ON i.Id=e.ItemId
    WHERE e.ScanSessionId=@ScanSessionId AND (i.Status NOT IN ('active','draft') OR i.CurrencyCode<>@CurrencyCode))
    THROW 51315,'Variante no activa o moneda distinta a la recepcion.',1;
  DECLARE @rows TABLE(RowNo int IDENTITY(1,1) PRIMARY KEY, ItemId uniqueidentifier,Qty int,Cost bigint NULL,Pool varchar(12));
  IF EXISTS(SELECT 1 FROM receiving.vw_CurrentQuality q
   WHERE q.ScanSessionId=@ScanSessionId AND q.Good+q.Damaged+q.Stained+q.Odor+q.Missing <>
   (SELECT SUM(e.Quantity) FROM receiving.ScanEvents e WHERE e.ScanSessionId=@ScanSessionId AND e.ItemId=q.ItemId AND e.MatchStatus='matched'))
   THROW 52006,'La calidad no coincide con las unidades esperadas.',1;
  INSERT INTO @rows(ItemId,Qty,Cost,Pool)
   SELECT e.ItemId,COALESCE(q.Good,SUM(e.Quantity)),i.UnitCostMinor,
     CASE WHEN i.UnitCostMinor IS NULL OR i.Status<>'active' THEN 'quarantine' ELSE 'store' END
   FROM receiving.ScanEvents e JOIN catalog.Items i ON i.Id=e.ItemId
   LEFT JOIN receiving.vw_CurrentQuality q ON q.ScanSessionId=e.ScanSessionId AND q.ItemId=e.ItemId
   WHERE e.ScanSessionId=@ScanSessionId AND e.MatchStatus='matched'
   GROUP BY e.ItemId,i.UnitCostMinor,i.Status,q.Good HAVING COALESCE(q.Good,SUM(e.Quantity))>0;
  INSERT INTO @rows(ItemId,Qty,Cost,Pool)
   SELECT q.ItemId,q.Damaged+q.Stained+q.Odor,i.UnitCostMinor,'quarantine'
   FROM receiving.vw_CurrentQuality q JOIN catalog.Items i ON i.Id=q.ItemId
   WHERE q.ScanSessionId=@ScanSessionId AND q.Damaged+q.Stained+q.Odor>0;
  IF EXISTS(SELECT 1 FROM @rows WHERE Qty NOT BETWEEN 1 AND 1000000)
    THROW 51316,'Cantidad agrupada fuera de rango.',1;
  SET @ReceiptId=NEWID();
  INSERT INTO purchasing.GoodsReceipts(Id,ScanSessionId,PurchaseOrderId,ContainerId,LocationId,CurrencyCode,TotalCostMinor,CreatedBy)
     SELECT @ReceiptId,@ScanSessionId,@po,@container,@location,@CurrencyCode,
      CASE WHEN EXISTS(SELECT 1 FROM @rows WHERE Cost IS NULL) THEN NULL
      ELSE (SELECT SUM(CAST(Qty AS bigint)*Cost) FROM @rows) END,@ActorId;
  DECLARE @n int=1,@max int=(SELECT MAX(RowNo) FROM @rows),@item uniqueidentifier,
      @qty int,@cost bigint,@pool varchar(12),@line uniqueidentifier,@op uniqueidentifier,@movement uniqueidentifier;
  WHILE @n<=@max
  BEGIN
    SELECT @item=ItemId,@qty=Qty,@cost=Cost,@pool=Pool FROM @rows WHERE RowNo=@n;
    SET @line=NEWID(); SET @op=NEWID(); SET @movement=NULL;
    INSERT INTO purchasing.GoodsReceiptLines(Id,GoodsReceiptId,LineNumber,ItemId,Quantity,UnitCostMinor,Pool,CreatedBy)
      VALUES(@line,@ReceiptId,@n,@item,@qty,@cost,@pool,@ActorId);
    EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@location,@Pool=@pool,
      @Kind='receive',@OnHandDelta=@qty,@SourceType='goods_receipt_line',@SourceId=@line,
      @ActorId=@ActorId,@UnitCostMinor=@cost,@MovementId=@movement OUTPUT;
    SET @n+=1;
  END;
  UPDATE receiving.ScanSessions SET Status='posted',ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME()
    WHERE Id=@ScanSessionId;
  -- The container is done when none of its sessions is still in progress. usp_OpenScanSession
  -- then rejects a new session on it (51324), so the same container cannot be received twice.
  IF NOT EXISTS(SELECT 1 FROM receiving.ScanSessions WITH(UPDLOCK,HOLDLOCK)
      WHERE ContainerId=@container AND Status IN ('counting','review','approved'))
    UPDATE receiving.ImportContainers SET Status='closed',ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME()
      WHERE Id=@container AND Status<>'closed';
  EXEC labels.usp_QueueReceiptLabels @ReceiptId,@ActorId;
  DECLARE @event uniqueidentifier=sync.fn_EventId('inventory.receipt_posted',@ReceiptId),@payload nvarchar(max)=(
    SELECT @ReceiptId AS receiptId,@ScanSessionId AS scanSessionId,@container AS containerId,
       @location AS locationId,@OriginNodeId AS originNodeId,
       JSON_QUERY((SELECT ItemId,Quantity,Pool,UnitCostMinor FROM purchasing.GoodsReceiptLines
         WHERE GoodsReceiptId=@ReceiptId ORDER BY LineNumber FOR JSON PATH)) AS lines
       FOR JSON PATH,WITHOUT_ARRAY_WRAPPER);
  EXEC sync.usp_EnqueueEvent @event,@OriginNodeId,'goods_receipt',@ReceiptId,'inventory.receipt_posted',@payload;
  COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO
