-- V032: P9 sync transport (ADR-001 D5; critique F1, F5, F6, F8). Spec: savia/docs/sync/P9-SPEC.md.
-- Every sync rule runs here, so the CP4 simulator and the .NET transport execute the same code.
-- 1. sync.SyncTables: the synced tables, their apply order (parents first) and the owner of each row (ownership map).
-- 2. sync.NodeCredentials: one hashed credential per branch node. The secret itself never reaches SQL.
-- 3. sync.RetiredForks and sync.PeerRebuilds: what a receiver remembers about a sender's restores.
-- 4. usp_SourceStateJson, usp_PlanJson, usp_ReadBatch, usp_ApplyBatch: state, plan, read and apply.
-- A batch carries full row state. The receiver's cursor decides what is new, so a duplicate or late batch changes nothing.
-- Errors: 51850 wrong peer or pair; 51851 row owned by another node; 51852 gap or fork mismatch in an incremental batch;
--         51853 batch from a retired fork; 51854 recovery push before a rebuild; 51855 local node not set;
--         51856 schema or table mismatch; 51857 called inside a transaction; 51858 source fork changed;
--         51859 changes already cleaned up; 51860 physical delete in a synced table; 51861 malformed JSON;
--         51862 credential for a node that is not an enabled branch; 51863 apply lock timeout.

CREATE TABLE [sync].[SyncTables] (
  [TableName] sysname NOT NULL,
  [ApplyOrder] int NOT NULL,
  [OwnerExpr] nvarchar(600) NOT NULL,   -- SQL over alias t that returns the owner node id of the row
  CONSTRAINT [PK_SyncTables] PRIMARY KEY ([TableName]),
  CONSTRAINT [UQ_SyncTables_Order] UNIQUE ([ApplyOrder])
);
GO

DECLARE @branchOwner nvarchar(100)=N'(SELECT n.Id FROM sync.Nodes n WHERE n.Kind=''branch'' AND n.BranchId=';
INSERT INTO sync.SyncTables(TableName,ApplyOrder,OwnerExpr)
SELECT v.t,v.o,CASE WHEN v.b IS NULL THEN N't.NodeId' ELSE @branchOwner+v.b+N')' END
FROM (VALUES
 (N'[sales].[CashTills]',1,N'(SELECT r.BranchId FROM sales.CashRegisters r WHERE r.Id=t.RegisterId)'),
 (N'[sales].[Sales]',2,N't.BranchId'),
 (N'[sales].[SaleLines]',3,N'(SELECT s.BranchId FROM sales.Sales s WHERE s.Id=t.SaleId)'),
 (N'[sales].[SaleReversals]',4,N't.BranchId'),
 (N'[sales].[SaleReversalLines]',5,N'(SELECT r.BranchId FROM sales.SaleReversals r WHERE r.Id=t.ReversalId)'),
 (N'[credits].[Credits]',6,N't.IssuingBranchId'),
 (N'[credits].[CreditAllocations]',7,N't.BranchId'),
 (N'[credits].[CreditMovements]',8,N't.BranchId'),
 (N'[credits].[CreditRedemptions]',9,N't.BranchId'),
 (N'[sales].[SaleTenders]',10,N'(SELECT s.BranchId FROM sales.Sales s WHERE s.Id=t.SaleId)'),
 (N'[sales].[CashEntries]',11,N'(SELECT r.BranchId FROM sales.CashRegisters r JOIN sales.CashTills k ON k.RegisterId=r.Id WHERE k.Id=t.TillId)'),
 (N'[inventory].[StockBalances]',12,N'(SELECT l.BranchId FROM core.Locations l WHERE l.Id=t.LocationId)'),
 (N'[inventory].[StockMovements]',13,N'(SELECT l.BranchId FROM core.Locations l WHERE l.Id=t.LocationId)'),
 (N'[credits].[TransferRequests]',14,NULL),
 (N'[credits].[TransferApprovals]',15,NULL),
 (N'[credits].[TransferCancellations]',16,NULL),
 (N'[credits].[TransferDispatches]',17,NULL),
 (N'[credits].[TransferReceipts]',18,NULL)) v(t,o,b);
GO

CREATE TABLE [sync].[NodeCredentials] (
  [NodeId] uniqueidentifier NOT NULL,
  [SecretHash] binary(32) NOT NULL,   -- SHA-256 of a 256-bit random secret
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sync_NodeCredentials_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [RevokedAt] datetime2(3) NULL,
  CONSTRAINT [PK_SyncNodeCredentials] PRIMARY KEY ([NodeId]),
  CONSTRAINT [FK_SyncNodeCredentials_Node] FOREIGN KEY ([NodeId]) REFERENCES [sync].[Nodes]([Id])
);
GO

-- A fork the sender left behind (restore). A batch from it is refused forever.
CREATE TABLE [sync].[RetiredForks] (
  [PeerNodeId] uniqueidentifier NOT NULL,
  [ForkGuid] uniqueidentifier NOT NULL,
  [RetiredAt] datetime2(3) NOT NULL CONSTRAINT [DF_sync_RetiredForks_RetiredAt] DEFAULT (SYSUTCDATETIME()),
  CONSTRAINT [PK_SyncRetiredForks] PRIMARY KEY ([PeerNodeId],[ForkGuid]),
  CONSTRAINT [FK_SyncRetiredForks_Node] FOREIGN KEY ([PeerNodeId]) REFERENCES [sync].[Nodes]([Id])
);
GO

-- The hub served a full rebuild to a restored branch on this fork; only then it accepts that branch's recovery push.
CREATE TABLE [sync].[PeerRebuilds] (
  [PeerNodeId] uniqueidentifier NOT NULL,
  [ForkGuid] uniqueidentifier NOT NULL,
  [ServedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sync_PeerRebuilds_ServedAt] DEFAULT (SYSUTCDATETIME()),
  CONSTRAINT [PK_SyncPeerRebuilds] PRIMARY KEY ([PeerNodeId],[ForkGuid]),
  CONSTRAINT [FK_SyncPeerRebuilds_Node] FOREIGN KEY ([PeerNodeId]) REFERENCES [sync].[Nodes]([Id])
);
GO

-- Column lists of each synced table, built from the catalog: no hand-written column list can drift from the schema.
CREATE OR ALTER FUNCTION [sync].[fn_TableShape]()
RETURNS TABLE
AS RETURN
SELECT st.TableName,st.ApplyOrder,st.OwnerExpr,c.SelectList,c.WithList,c.InsList,c.ValList,c.UpdList,c.DiffS,c.DiffT,
       k.OnList,k.CtOnList
FROM sync.SyncTables st
CROSS APPLY (
  SELECT STRING_AGG(CONVERT(nvarchar(max),N't.'+QUOTENAME(d.name)),N',') WITHIN GROUP (ORDER BY d.column_ordinal) AS SelectList,
         STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(d.name)+N' '+d.system_type_name),N',')
           WITHIN GROUP (ORDER BY d.column_ordinal) AS WithList,
         STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(d.name)),N',') WITHIN GROUP (ORDER BY d.column_ordinal) AS InsList,
         STRING_AGG(CONVERT(nvarchar(max),N's.'+QUOTENAME(d.name)),N',') WITHIN GROUP (ORDER BY d.column_ordinal) AS ValList,
         STRING_AGG(CASE WHEN pk.name IS NULL THEN CONVERT(nvarchar(max),N't.'+QUOTENAME(d.name)+N'=s.'+QUOTENAME(d.name)) END,N',')
           WITHIN GROUP (ORDER BY d.column_ordinal) AS UpdList,
         STRING_AGG(CASE WHEN pk.name IS NULL THEN CONVERT(nvarchar(max),N's.'+QUOTENAME(d.name)) END,N',')
           WITHIN GROUP (ORDER BY d.column_ordinal) AS DiffS,
         STRING_AGG(CASE WHEN pk.name IS NULL THEN CONVERT(nvarchar(max),N't.'+QUOTENAME(d.name)) END,N',')
           WITHIN GROUP (ORDER BY d.column_ordinal) AS DiffT
  FROM sys.dm_exec_describe_first_result_set(N'SELECT * FROM '+st.TableName,NULL,0) d
  LEFT JOIN (SELECT col.name FROM sys.indexes i
             JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
             JOIN sys.columns col ON col.object_id=ic.object_id AND col.column_id=ic.column_id
             WHERE i.object_id=OBJECT_ID(st.TableName) AND i.is_primary_key=1) pk ON pk.name=d.name
  WHERE d.system_type_name NOT IN ('timestamp','rowversion') AND d.is_computed_column=0) c
CROSS APPLY (
  SELECT STRING_AGG(CONVERT(nvarchar(max),N't.'+QUOTENAME(col.name)+N'=s.'+QUOTENAME(col.name)),N' AND ')
           WITHIN GROUP (ORDER BY ic.key_ordinal) AS OnList,
         STRING_AGG(CONVERT(nvarchar(max),N'ct.'+QUOTENAME(col.name)+N'=t.'+QUOTENAME(col.name)),N' AND ')
           WITHIN GROUP (ORDER BY ic.key_ordinal) AS CtOnList
  FROM sys.indexes i
  JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
  JOIN sys.columns col ON col.object_id=ic.object_id AND col.column_id=ic.column_id
  WHERE i.object_id=OBJECT_ID(st.TableName) AND i.is_primary_key=1) k;
GO

-- This node's source state, read in one SNAPSHOT transaction (F5): who, fork, version, schema, minimum valid versions.
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
                   (SELECT MAX([Version]) FROM dbo.SaviaMigrations) AS [schema],
                   JSON_QUERY((SELECT st.TableName AS t,CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID(st.TableName)) AS [min]
                               FROM sync.SyncTables st ORDER BY st.ApplyOrder FOR JSON PATH, INCLUDE_NULL_VALUES)) AS tables
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
 IF @ownTran=1 COMMIT;
END;
GO

-- The receiver plans what to ask the sender for, table by table, with the rules of usp_ClassifyCursor (V008).
-- @Mode 'rebuild': a restored branch asks the hub for every row, its own included.
CREATE OR ALTER PROCEDURE [sync].[usp_PlanJson]
 @PeerNodeId uniqueidentifier,@StateJson nvarchar(max),@Mode varchar(10)='normal',@Json nvarchar(max) OUTPUT
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF ISJSON(@StateJson)<>1 OR @Mode NOT IN ('normal','rebuild') THROW 51861,'Estado de sincronizacion invalido.',1;
 DECLARE @node uniqueidentifier=TRY_CONVERT(uniqueidentifier,JSON_VALUE(@StateJson,'$.node')),
   @fork uniqueidentifier=TRY_CONVERT(uniqueidentifier,JSON_VALUE(@StateJson,'$.fork')),
   @ver bigint=TRY_CONVERT(bigint,JSON_VALUE(@StateJson,'$.version')),
   @schema varchar(20)=JSON_VALUE(@StateJson,'$.schema');
 IF @node IS NULL OR @fork IS NULL OR @ver IS NULL THROW 51861,'Estado de sincronizacion invalido.',1;
 IF @node<>@PeerNodeId THROW 51850,'El estado viene de otro nodo.',1;
 IF NOT EXISTS(SELECT 1 FROM sync.Nodes WHERE Id=@PeerNodeId AND IsEnabled=1) THROW 51807,'Nodo inexistente o deshabilitado.',1;
 IF ISNULL(@schema,'')<>(SELECT MAX([Version]) FROM dbo.SaviaMigrations) THROW 51856,'Version de esquema distinta.',1;
 DECLARE @s TABLE(t sysname PRIMARY KEY,[min] bigint);
 INSERT @s SELECT t,[min] FROM OPENJSON(@StateJson,'$.tables') WITH (t sysname,[min] bigint);
 IF EXISTS(SELECT 1 FROM sync.SyncTables st WHERE NOT EXISTS(SELECT 1 FROM @s s WHERE s.t=st.TableName))
   THROW 51856,'El emisor no rastrea todas las tablas sincronizadas.',1;
 SET @Json=(SELECT @PeerNodeId AS peer,@fork AS fork,@ver AS [version],@Mode AS mode,
   JSON_QUERY((SELECT st.TableName AS t,
      CASE WHEN @Mode='rebuild' THEN 'rebuild'
           WHEN c.ForkGuid IS NULL THEN 'initial'
           WHEN c.ForkGuid<>@fork THEN 'recover'
           WHEN @ver<c.[Version] THEN 'recover'
           WHEN s.[min] IS NULL OR c.[Version]<s.[min] THEN 'reinit'
           ELSE 'incremental' END AS a,
      CASE WHEN @Mode='normal' AND c.ForkGuid=@fork AND c.[Version]<=@ver AND c.[Version]>=s.[min] THEN c.[Version] END AS f
    FROM sync.SyncTables st JOIN @s s ON s.t=st.TableName
    LEFT JOIN sync.PeerCursors c ON c.PeerNodeId=@PeerNodeId AND c.TableName=st.TableName
    ORDER BY st.ApplyOrder FOR JSON PATH, INCLUDE_NULL_VALUES)) AS tables
  FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
END;
GO

-- Is @Peer allowed to talk to this node? The hub talks to enabled branches; a branch talks only to the hub.
CREATE OR ALTER FUNCTION [sync].[fn_PeerAllowed](@Me uniqueidentifier,@Peer uniqueidentifier)
RETURNS bit
AS
BEGIN
 DECLARE @meKind varchar(16)=(SELECT Kind FROM sync.Nodes WHERE Id=@Me),
         @peerKind varchar(16)=(SELECT Kind FROM sync.Nodes WHERE Id=@Peer AND IsEnabled=1);
 RETURN CASE WHEN @meKind='azure' AND @peerKind='branch' THEN 1
             WHEN @meKind='branch' AND @peerKind='azure' THEN 1 ELSE 0 END;
END;
GO

-- The sender reads the rows the receiver asked for, every table in one SNAPSHOT transaction (F5).
-- Hub, normal: every row the target does not own. Hub, rebuild: every row. Branch: only its own rows.
-- A rebuild also records which fork of the target was served, and retires the target's other forks:
-- from then on a batch the target read before its restore is refused (51853).
CREATE OR ALTER PROCEDURE [sync].[usp_ReadBatch]
 @TargetNodeId uniqueidentifier,@PlanJson nvarchar(max),@TargetForkGuid uniqueidentifier=NULL,@Json nvarchar(max) OUTPUT
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @me uniqueidentifier=(SELECT NodeId FROM sync.LocalNode);
 IF @me IS NULL THROW 51855,'La base no sabe que nodo es (sync.LocalNode).',1;
 IF @@TRANCOUNT>0 THROW 51857,'La lectura de un lote abre su propia transaccion SNAPSHOT.',1;
 IF ISJSON(@PlanJson)<>1 THROW 51861,'Plan de sincronizacion invalido.',1;
 DECLARE @planPeer uniqueidentifier=TRY_CONVERT(uniqueidentifier,JSON_VALUE(@PlanJson,'$.peer')),
   @planFork uniqueidentifier=TRY_CONVERT(uniqueidentifier,JSON_VALUE(@PlanJson,'$.fork')),
   @mode varchar(10)=JSON_VALUE(@PlanJson,'$.mode'),
   @isHub bit=CASE WHEN (SELECT Kind FROM sync.Nodes WHERE Id=@me)='azure' THEN 1 ELSE 0 END;
 IF @planPeer IS NULL OR @planFork IS NULL OR ISNULL(@mode,'') NOT IN ('normal','rebuild')
   THROW 51861,'Plan de sincronizacion invalido.',1;
 IF @planPeer<>@me OR sync.fn_PeerAllowed(@me,@TargetNodeId)=0 THROW 51850,'Par de nodos no permitido.',1;
 IF @mode='rebuild' AND (@isHub=0 OR @TargetForkGuid IS NULL) THROW 51850,'Solo el hub sirve una reconstruccion.',1;
 DECLARE @p TABLE(t sysname PRIMARY KEY,a varchar(20),f bigint);
 INSERT @p SELECT t,a,f FROM OPENJSON(@PlanJson,'$.tables') WITH (t sysname,a varchar(20),f bigint);
 IF (SELECT COUNT(*) FROM @p p JOIN sync.SyncTables st ON st.TableName=p.t)<>(SELECT COUNT(*) FROM sync.SyncTables)
    OR (SELECT COUNT(*) FROM @p)<>(SELECT COUNT(*) FROM sync.SyncTables)
   THROW 51856,'El plan no cubre exactamente las tablas sincronizadas.',1;
 IF EXISTS(SELECT 1 FROM @p WHERE a NOT IN ('initial','recover','reinit','incremental','rebuild')
           OR (a='incremental' AND f IS NULL) OR (a='rebuild' AND @mode<>'rebuild'))
   THROW 51861,'Plan de sincronizacion invalido.',1;

 DECLARE @out TABLE(o int PRIMARY KEY,t sysname,a varchar(20),f bigint,[rows] nvarchar(max));
 DECLARE @fork uniqueidentifier,@to bigint,@schema varchar(20)=(SELECT MAX([Version]) FROM dbo.SaviaMigrations);
 DECLARE @o int,@t sysname,@a varchar(20),@f bigint,@owner nvarchar(600),@sel nvarchar(max),@ctOn nvarchar(max),
         @flt nvarchar(max),@sql nvarchar(max),@rows nvarchar(max);

 SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
 BEGIN TRANSACTION;
 BEGIN TRY
 SET @fork=(SELECT recovery_fork_guid FROM sys.database_recovery_status WHERE database_id=DB_ID());
 SET @to=CHANGE_TRACKING_CURRENT_VERSION();
 IF @fork<>@planFork THROW 51858,'El fork del emisor cambio durante la sincronizacion.',1;
 DECLARE c CURSOR LOCAL FAST_FORWARD FOR
   SELECT s.ApplyOrder,s.TableName,p.a,p.f,s.OwnerExpr,s.SelectList,s.CtOnList
   FROM sync.fn_TableShape() s JOIN @p p ON p.t=s.TableName ORDER BY s.ApplyOrder;
 OPEN c;
 FETCH NEXT FROM c INTO @o,@t,@a,@f,@owner,@sel,@ctOn;
 WHILE @@FETCH_STATUS=0
 BEGIN
   SET @flt=CASE WHEN @mode='rebuild' THEN N'1=1' WHEN @isHub=1 THEN N'('+@owner+N')<>@target' ELSE N'('+@owner+N')=@me' END;
   IF @a='incremental'
   BEGIN
     IF CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID(@t))>@f THROW 51859,'Cambios ya depurados durante la sincronizacion.',1;
     SET @sql=N'IF EXISTS(SELECT 1 FROM CHANGETABLE(CHANGES '+@t+N',@f) ct WHERE ct.SYS_CHANGE_OPERATION=''D'') '
       +N'THROW 51860,''Borrado fisico en una tabla sincronizada.'',1; '
       +N'SET @rows=(SELECT '+@sel+N' FROM CHANGETABLE(CHANGES '+@t+N',@f) ct JOIN '+@t+N' t ON '+@ctOn
       +N' WHERE ct.SYS_CHANGE_VERSION<=@to AND '+@flt+N' FOR JSON PATH, INCLUDE_NULL_VALUES);';
   END
   ELSE
     SET @sql=N'SET @rows=(SELECT '+@sel+N' FROM '+@t+N' t WHERE '+@flt+N' FOR JSON PATH, INCLUDE_NULL_VALUES);';
   SET @rows=NULL;
   EXEC sys.sp_executesql @sql,N'@f bigint,@to bigint,@me uniqueidentifier,@target uniqueidentifier,@rows nvarchar(max) OUTPUT',
        @f=@f,@to=@to,@me=@me,@target=@TargetNodeId,@rows=@rows OUTPUT;
   INSERT @out VALUES(@o,@t,@a,CASE WHEN @a='incremental' THEN @f END,ISNULL(@rows,N'[]'));
   FETCH NEXT FROM c INTO @o,@t,@a,@f,@owner,@sel,@ctOn;
 END;
 CLOSE c; DEALLOCATE c;
 COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;

 IF @mode='rebuild'
 BEGIN
   BEGIN TRANSACTION;
   INSERT sync.RetiredForks(PeerNodeId,ForkGuid)
     SELECT DISTINCT @TargetNodeId,c.ForkGuid FROM sync.PeerCursors c
     WHERE c.PeerNodeId=@TargetNodeId AND c.ForkGuid<>@TargetForkGuid
       AND NOT EXISTS(SELECT 1 FROM sync.RetiredForks r WHERE r.PeerNodeId=@TargetNodeId AND r.ForkGuid=c.ForkGuid);
   IF NOT EXISTS(SELECT 1 FROM sync.PeerRebuilds WHERE PeerNodeId=@TargetNodeId AND ForkGuid=@TargetForkGuid)
     INSERT sync.PeerRebuilds(PeerNodeId,ForkGuid) VALUES(@TargetNodeId,@TargetForkGuid);
   COMMIT;
 END;

 SET @Json=(SELECT @me AS node,@fork AS fork,@to AS [to],@schema AS [schema],@mode AS mode,
   JSON_QUERY((SELECT t,a,f,JSON_QUERY([rows]) AS [rows] FROM @out ORDER BY o FOR JSON PATH, INCLUDE_NULL_VALUES)) AS tables
   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
END;
GO

-- The receiver applies a batch in one transaction: every table in apply order, then every cursor (F8).
-- The cursor makes this idempotent (A-04): a table whose cursor already reached the batch's version is skipped.
-- MERGE writes only rows whose columns differ, so the same state twice counts 0 changes.
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
   @isHub bit=CASE WHEN (SELECT Kind FROM sync.Nodes WHERE Id=@me)='azure' THEN 1 ELSE 0 END;
 IF @node IS NULL OR @fork IS NULL OR @to IS NULL OR ISNULL(@mode,'') NOT IN ('normal','rebuild')
   THROW 51861,'Lote de sincronizacion invalido.',1;
 IF @node<>@PeerNodeId OR sync.fn_PeerAllowed(@me,@PeerNodeId)=0 THROW 51850,'Par de nodos no permitido.',1;
 IF @mode='rebuild' AND @isHub=1 THROW 51850,'El hub no acepta un lote de reconstruccion.',1;
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
    AND NOT EXISTS(SELECT 1 FROM sync.PeerRebuilds WHERE PeerNodeId=@PeerNodeId AND ForkGuid=@fork)
   THROW 51854,'El nodo restaurado debe reconstruirse desde el hub antes de enviar.',1;

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
 IF @tc=0 COMMIT;
 END TRY
 BEGIN CATCH IF @tc=0 AND @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
 SET @Json=(SELECT @changed AS changed,@applied AS applied,@skipped AS skipped FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END;
GO

-- Node credentials. The caller hashes the secret; SQL stores and returns only the hash.
CREATE OR ALTER PROCEDURE [sync].[usp_SetNodeCredential]
 @NodeId uniqueidentifier,@SecretHash binary(32)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF NOT EXISTS(SELECT 1 FROM sync.Nodes WHERE Id=@NodeId AND Kind='branch' AND IsEnabled=1)
   THROW 51862,'Solo una sucursal habilitada recibe credencial de sincronizacion.',1;
 IF @SecretHash IS NULL OR @SecretHash=0x0000000000000000000000000000000000000000000000000000000000000000
   THROW 51862,'Credencial vacia.',1;
 MERGE sync.NodeCredentials WITH (HOLDLOCK) AS t USING (SELECT @NodeId AS NodeId) AS s ON t.NodeId=s.NodeId
 WHEN MATCHED THEN UPDATE SET SecretHash=@SecretHash,CreatedAt=SYSUTCDATETIME(),RevokedAt=NULL
 WHEN NOT MATCHED THEN INSERT(NodeId,SecretHash) VALUES(@NodeId,@SecretHash);
END;
GO

CREATE OR ALTER PROCEDURE [sync].[usp_RevokeNodeCredential]
 @NodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON;
 UPDATE sync.NodeCredentials SET RevokedAt=SYSUTCDATETIME() WHERE NodeId=@NodeId AND RevokedAt IS NULL;
END;
GO

-- Returns the active hash of an enabled branch node, or no row. The API compares hashes in fixed time.
CREATE OR ALTER PROCEDURE [sync].[usp_GetNodeCredential]
 @NodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON;
 SELECT c.SecretHash FROM sync.NodeCredentials c JOIN sync.Nodes n ON n.Id=c.NodeId
 WHERE c.NodeId=@NodeId AND c.RevokedAt IS NULL AND n.Kind='branch' AND n.IsEnabled=1;
END;
GO
