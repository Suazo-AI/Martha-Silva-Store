-- savia:transactional
-- V033: P9 fix. The hub accepted a push from a restored fork once it had SERVED a rebuild, even when the branch never
-- applied it (answer lost, or the apply failed): the restore_naive path over HTTP. Reproduced red by the .NET test
-- SyncWorkerTests.Lost_rebuild_answer_does_not_open_the_hub_to_the_restored_fork (savia/docs/sync/P9-SPEC.md).
-- Fix: every rebuild the hub serves carries a new token. The branch stores it in the same transaction as the rebuilt rows
-- (sync.AppliedRebuilds) and echoes it in every batch it reads for the hub. A new fork is accepted only with the token
-- of the last rebuild served to it. Errors are unchanged (51854; 51861 for a rebuild batch without a token).

ALTER TABLE [sync].[PeerRebuilds] ADD [Token] uniqueidentifier NULL;   -- hub: token of the last rebuild served to this fork
GO

-- Branch: the rebuild it applied while its own database was on fork ForkGuid. A restore changes the fork, so a token
-- restored from a backup never matches the new fork.
CREATE TABLE [sync].[AppliedRebuilds] (
  [PeerNodeId] uniqueidentifier NOT NULL,
  [ForkGuid] uniqueidentifier NOT NULL,
  [Token] uniqueidentifier NOT NULL,
  [AppliedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sync_AppliedRebuilds_AppliedAt] DEFAULT (SYSUTCDATETIME()),
  CONSTRAINT [PK_SyncAppliedRebuilds] PRIMARY KEY ([PeerNodeId],[ForkGuid]),
  CONSTRAINT [FK_SyncAppliedRebuilds_Node] FOREIGN KEY ([PeerNodeId]) REFERENCES [sync].[Nodes]([Id])
);
GO

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
 DECLARE @fork uniqueidentifier,@to bigint,@schema varchar(20)=(SELECT MAX([Version]) FROM dbo.SaviaMigrations),
   @token uniqueidentifier=CASE WHEN @mode='rebuild' THEN NEWID() END;
 DECLARE @o int,@t sysname,@a varchar(20),@f bigint,@owner nvarchar(600),@sel nvarchar(max),@ctOn nvarchar(max),
         @flt nvarchar(max),@sql nvarchar(max),@rows nvarchar(max);

 SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
 BEGIN TRANSACTION;
 BEGIN TRY
 SET @fork=(SELECT recovery_fork_guid FROM sys.database_recovery_status WHERE database_id=DB_ID());
 SET @to=CHANGE_TRACKING_CURRENT_VERSION();
 IF @fork<>@planFork THROW 51858,'El fork del emisor cambio durante la sincronizacion.',1;
 -- A branch shows the hub the rebuild it applied on its current fork; the hub needs it before it takes a new fork.
 IF @isHub=0 SET @token=(SELECT Token FROM sync.AppliedRebuilds WHERE PeerNodeId=@TargetNodeId AND ForkGuid=@fork);
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
   -- Each rebuild served gets a new token; only the last one served opens the hub to this fork.
   UPDATE sync.PeerRebuilds SET Token=@token,ServedAt=SYSUTCDATETIME() WHERE PeerNodeId=@TargetNodeId AND ForkGuid=@TargetForkGuid;
   IF @@ROWCOUNT=0 INSERT sync.PeerRebuilds(PeerNodeId,ForkGuid,Token) VALUES(@TargetNodeId,@TargetForkGuid,@token);
   COMMIT;
 END;

 SET @Json=(SELECT @me AS node,@fork AS fork,@to AS [to],@schema AS [schema],@mode AS mode,@token AS rebuild,
   JSON_QUERY((SELECT t,a,f,JSON_QUERY([rows]) AS [rows] FROM @out ORDER BY o FOR JSON PATH, INCLUDE_NULL_VALUES)) AS tables
   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
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
 IF @mode='rebuild'
 BEGIN
   -- Same transaction as the rows: the token exists on this branch only if the rebuild really landed.
   DECLARE @ownFork uniqueidentifier=(SELECT recovery_fork_guid FROM sys.database_recovery_status WHERE database_id=DB_ID());
   UPDATE sync.AppliedRebuilds SET Token=@token,AppliedAt=SYSUTCDATETIME() WHERE PeerNodeId=@PeerNodeId AND ForkGuid=@ownFork;
   IF @@ROWCOUNT=0 INSERT sync.AppliedRebuilds(PeerNodeId,ForkGuid,Token) VALUES(@PeerNodeId,@ownFork,@token);
 END;
 IF @tc=0 COMMIT;
 END TRY
 BEGIN CATCH IF @tc=0 AND @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
 SET @Json=(SELECT @changed AS changed,@applied AS applied,@skipped AS skipped FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END;
GO
