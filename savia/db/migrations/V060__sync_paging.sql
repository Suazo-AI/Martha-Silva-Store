-- savia:transactional
-- V060: S5 in docs/production-20261122/README.md (D-041). Sync moves in pages.
-- 1. A page holds at most @PageRows rows per table (default 5,000) and stops adding tables at @PageBytes of UTF-8 rows
--    (default 19,000,000, under the 20 MB response limit). A page ends after the first table that is not finished.
-- 2. The receiver stores the open pass (sync.PeerPasses, sync.PeerPassTables): sender fork, mode, version `to`, next page,
--    rebuild token and, per table, the resume key. usp_PlanJson continues it, so a new process resumes where the last one
--    stopped. A cursor moves only when its table is finished; a page out of order is a gap (51852), a repeated one is skipped.
-- 3. Pages after the first read the rows as they were at `to`: a row changed after `to` waits for the next round.
-- 4. A rebuild keeps the recovery lock until its final page. A newer rebuild served to the same fork restarts at page 1.
-- 5. A self-referencing row travels with its parent. A foreign-key failure (547) drops the pass; the next plan starts again.
-- A batch without page fields is a single page (previous API release). New errors: none.

CREATE TABLE [sync].[PeerPasses] (
  [PeerNodeId] uniqueidentifier NOT NULL,
  [ForkGuid] uniqueidentifier NOT NULL,          -- the sender's fork
  [Mode] varchar(10) NOT NULL,
  [ToVersion] bigint NOT NULL,
  [Token] uniqueidentifier NULL,                 -- rebuild token, mode rebuild only
  [NextPage] int NOT NULL,
  [StartedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sync_PeerPasses_StartedAt] DEFAULT (SYSUTCDATETIME()),
  [UpdatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sync_PeerPasses_UpdatedAt] DEFAULT (SYSUTCDATETIME()),
  CONSTRAINT [PK_SyncPeerPasses] PRIMARY KEY ([PeerNodeId]),
  CONSTRAINT [FK_SyncPeerPasses_Node] FOREIGN KEY ([PeerNodeId]) REFERENCES [sync].[Nodes]([Id]),
  CONSTRAINT [CK_SyncPeerPasses_Mode] CHECK ([Mode] IN ('normal','rebuild') AND ([Mode]='normal' OR [Token] IS NOT NULL)),
  CONSTRAINT [CK_SyncPeerPasses_NextPage] CHECK ([NextPage]>1)
);
GO

CREATE TABLE [sync].[PeerPassTables] (
  [PeerNodeId] uniqueidentifier NOT NULL,
  [TableName] sysname NOT NULL,
  [Action] varchar(20) NOT NULL,
  [FromVersion] bigint NULL,
  [ResumeKey] nvarchar(max) NULL,                -- JSON object: the key columns of the last row read
  [Done] bit NOT NULL,
  CONSTRAINT [PK_SyncPeerPassTables] PRIMARY KEY ([PeerNodeId],[TableName]),
  CONSTRAINT [FK_SyncPeerPassTables_Pass] FOREIGN KEY ([PeerNodeId]) REFERENCES [sync].[PeerPasses]([PeerNodeId]) ON DELETE CASCADE,
  CONSTRAINT [FK_SyncPeerPassTables_Table] FOREIGN KEY ([TableName]) REFERENCES [sync].[SyncTables]([TableName])
);
GO

-- "Row after the resume key @k" for a table's primary key, in key order: (a>@a) OR (a=@a AND (b>@b ...)).
CREATE OR ALTER FUNCTION [sync].[fn_KeyAfter](@TableName sysname)
RETURNS nvarchar(max)
AS
BEGIN
 DECLARE @p nvarchar(max),@v nvarchar(max);
 DECLARE @c TABLE(o int PRIMARY KEY,name sysname,ty nvarchar(128));
 INSERT @c
 SELECT ic.key_ordinal,col.name,
        CASE WHEN ty.name IN ('varchar','char','varbinary','binary') THEN ty.name+'('+CONVERT(varchar(10),col.max_length)+')'
             WHEN ty.name IN ('nvarchar','nchar') THEN ty.name+'('+CONVERT(varchar(10),col.max_length/2)+')'
             ELSE ty.name END
 FROM sys.indexes i
 JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
 JOIN sys.columns col ON col.object_id=ic.object_id AND col.column_id=ic.column_id
 JOIN sys.types ty ON ty.user_type_id=col.system_type_id
 WHERE i.object_id=OBJECT_ID(@TableName) AND i.is_primary_key=1;
 DECLARE @o int=(SELECT MAX(o) FROM @c);
 WHILE @o>=1
 BEGIN
   SELECT @v=N'CONVERT('+ty+N',JSON_VALUE(@k,''$."'+name+N'"''))' FROM @c WHERE o=@o;
   SELECT @p=CASE WHEN @p IS NULL THEN N't.'+QUOTENAME(name)+N'>'+@v
                  ELSE N'(t.'+QUOTENAME(name)+N'>'+@v+N' OR (t.'+QUOTENAME(name)+N'='+@v+N' AND '+@p+N'))' END
   FROM @c WHERE o=@o;
   SET @o-=1;
 END;
 RETURN @p;
END;
GO

-- Key lists of each synced table for paging, and its self-referencing foreign key (parent column, key column), if any.
CREATE OR ALTER FUNCTION [sync].[fn_TableKeys]()
RETURNS TABLE
AS RETURN
SELECT st.TableName,k.KeyList,k.KeyDesc,k.KeyJoin,sync.fn_KeyAfter(st.TableName) AS KeyAfter,sf.ParentCol,sf.KeyCol
FROM sync.SyncTables st
CROSS APPLY (
  SELECT STRING_AGG(CONVERT(nvarchar(max),N't.'+QUOTENAME(col.name)),N',') WITHIN GROUP (ORDER BY ic.key_ordinal) AS KeyList,
         STRING_AGG(CONVERT(nvarchar(max),QUOTENAME(col.name)+N' DESC'),N',') WITHIN GROUP (ORDER BY ic.key_ordinal) AS KeyDesc,
         STRING_AGG(CONVERT(nvarchar(max),N'k.'+QUOTENAME(col.name)+N'=t.'+QUOTENAME(col.name)),N' AND ')
           WITHIN GROUP (ORDER BY ic.key_ordinal) AS KeyJoin
  FROM sys.indexes i
  JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
  JOIN sys.columns col ON col.object_id=ic.object_id AND col.column_id=ic.column_id
  WHERE i.object_id=OBJECT_ID(st.TableName) AND i.is_primary_key=1) k
OUTER APPLY (
  SELECT pc.name AS ParentCol,rc.name AS KeyCol
  FROM sys.foreign_keys fk
  JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id=fk.object_id
  JOIN sys.columns pc ON pc.object_id=fkc.parent_object_id AND pc.column_id=fkc.parent_column_id
  JOIN sys.columns rc ON rc.object_id=fkc.referenced_object_id AND rc.column_id=fkc.referenced_column_id
  WHERE fk.parent_object_id=OBJECT_ID(st.TableName) AND fk.referenced_object_id=fk.parent_object_id) sf;
GO

-- Paging supports single-column self references to a single-column key only; refuse a schema this code was not written for.
IF EXISTS(SELECT 1 FROM sync.fn_TableKeys() k WHERE k.ParentCol IS NOT NULL
          AND (k.KeyList<>N't.'+QUOTENAME(k.KeyCol)
               OR (SELECT COUNT(*) FROM sys.foreign_keys fk WHERE fk.parent_object_id=OBJECT_ID(k.TableName)
                   AND fk.referenced_object_id=fk.parent_object_id)>1))
  THROW 52008,'Sync paging: unsupported self reference.',1;
GO

-- The receiver plans the next page. An open pass on the same sender fork continues (same `to`, next page, resume keys);
-- it is dropped when the sender went back in time, when a rebuild is asked for over a normal pass, or when the sender's
-- change tracking no longer covers it. @Mode 'rebuild': a restored branch asks the hub for every row, its own included.
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

 DECLARE @pass bit=0,@pFork uniqueidentifier,@pMode varchar(10),@pTo bigint,@pPage int,@pToken uniqueidentifier;
 SELECT @pFork=ForkGuid,@pMode=Mode,@pTo=ToVersion,@pPage=NextPage,@pToken=Token
 FROM sync.PeerPasses WHERE PeerNodeId=@PeerNodeId;
 IF @pFork=@fork AND @ver>=@pTo AND NOT (@Mode='rebuild' AND @pMode='normal')
    AND NOT EXISTS(SELECT 1 FROM sync.SyncTables st JOIN @s s ON s.t=st.TableName
                   LEFT JOIN sync.PeerPassTables pt ON pt.PeerNodeId=@PeerNodeId AND pt.TableName=st.TableName
                   WHERE ISNULL(pt.Done,0)=0
                     AND (s.[min] IS NULL OR s.[min]>@pTo OR (pt.[Action]='incremental' AND pt.FromVersion<s.[min])))
   SET @pass=1;
 DECLARE @m varchar(10)=CASE WHEN @pass=1 THEN @pMode ELSE @Mode END;

 SET @Json=(SELECT @PeerNodeId AS peer,@fork AS fork,@ver AS [version],@m AS mode,
   CASE WHEN @pass=1 THEN @pPage ELSE 1 END AS page,
   CASE WHEN @pass=1 THEN @pTo END AS [to],
   CASE WHEN @pass=1 THEN @pToken END AS rebuild,
   JSON_QUERY((SELECT st.TableName AS t,
      CASE WHEN pt.TableName IS NOT NULL THEN pt.[Action]
           WHEN @m='rebuild' THEN 'rebuild'
           WHEN c.ForkGuid IS NULL THEN 'initial'
           WHEN c.ForkGuid<>@fork THEN 'recover'
           WHEN @ver<c.[Version] THEN 'recover'
           WHEN s.[min] IS NULL OR c.[Version]<s.[min] THEN 'reinit'
           ELSE 'incremental' END AS a,
      CASE WHEN pt.TableName IS NOT NULL THEN pt.FromVersion
           WHEN @m='normal' AND c.ForkGuid=@fork AND c.[Version]<=@ver AND c.[Version]>=s.[min] THEN c.[Version] END AS f,
      JSON_QUERY(pt.ResumeKey) AS k,
      CONVERT(bit,ISNULL(pt.Done,0)) AS done
    FROM sync.SyncTables st JOIN @s s ON s.t=st.TableName
    LEFT JOIN sync.PeerCursors c ON c.PeerNodeId=@PeerNodeId AND c.TableName=st.TableName
    LEFT JOIN sync.PeerPassTables pt ON @pass=1 AND pt.PeerNodeId=@PeerNodeId AND pt.TableName=st.TableName
    ORDER BY st.ApplyOrder FOR JSON PATH, INCLUDE_NULL_VALUES)) AS tables
  FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
END;
GO

-- The sender reads one page of the plan, every table in one SNAPSHOT transaction (F5).
-- Hub, normal: every row the target does not own. Hub, rebuild: every row. Branch: only its own rows.
-- Page 1 fixes `to` (the current version); later pages read the rows as they were at `to`, from each table's resume key.
-- A rebuild's page 1 records which fork of the target was served and retires the target's other forks (V034).
CREATE OR ALTER PROCEDURE [sync].[usp_ReadBatch]
 @TargetNodeId uniqueidentifier,@PlanJson nvarchar(max),@TargetForkGuid uniqueidentifier=NULL,@Json nvarchar(max) OUTPUT,
 @PageRows int=5000,@PageBytes int=19000000
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @me uniqueidentifier=(SELECT NodeId FROM sync.LocalNode);
 IF @me IS NULL THROW 51855,'La base no sabe que nodo es (sync.LocalNode).',1;
 IF @@TRANCOUNT>0 THROW 51857,'La lectura de un lote abre su propia transaccion SNAPSHOT.',1;
 IF ISJSON(@PlanJson)<>1 OR ISNULL(@PageRows,0)<1 OR ISNULL(@PageBytes,0)<1 THROW 51861,'Plan de sincronizacion invalido.',1;
 DECLARE @planPeer uniqueidentifier=TRY_CONVERT(uniqueidentifier,JSON_VALUE(@PlanJson,'$.peer')),
   @planFork uniqueidentifier=TRY_CONVERT(uniqueidentifier,JSON_VALUE(@PlanJson,'$.fork')),
   @mode varchar(10)=JSON_VALUE(@PlanJson,'$.mode'),
   @page int=ISNULL(TRY_CONVERT(int,JSON_VALUE(@PlanJson,'$.page')),1),
   @planTo bigint=TRY_CONVERT(bigint,JSON_VALUE(@PlanJson,'$.to')),
   @planToken uniqueidentifier=TRY_CONVERT(uniqueidentifier,JSON_VALUE(@PlanJson,'$.rebuild')),
   @isHub bit=CASE WHEN (SELECT Kind FROM sync.Nodes WHERE Id=@me)='azure' THEN 1 ELSE 0 END;
 IF @planPeer IS NULL OR @planFork IS NULL OR ISNULL(@mode,'') NOT IN ('normal','rebuild') OR @page<1
    OR (@page>1 AND @planTo IS NULL)
   THROW 51861,'Plan de sincronizacion invalido.',1;
 IF @planPeer<>@me OR sync.fn_PeerAllowed(@me,@TargetNodeId)=0 THROW 51850,'Par de nodos no permitido.',1;
 IF @mode='rebuild' AND (@isHub=0 OR @TargetForkGuid IS NULL) THROW 51850,'Solo el hub sirve una reconstruccion.',1;
 DECLARE @p TABLE(t sysname PRIMARY KEY,a varchar(20),f bigint,k nvarchar(max),done bit);
 INSERT @p SELECT t,a,f,k,ISNULL(done,0) FROM OPENJSON(@PlanJson,'$.tables')
   WITH (t sysname,a varchar(20),f bigint,k nvarchar(max) AS JSON,done bit);
 IF (SELECT COUNT(*) FROM @p p JOIN sync.SyncTables st ON st.TableName=p.t)<>(SELECT COUNT(*) FROM sync.SyncTables)
    OR (SELECT COUNT(*) FROM @p)<>(SELECT COUNT(*) FROM sync.SyncTables)
   THROW 51856,'El plan no cubre exactamente las tablas sincronizadas.',1;
 IF EXISTS(SELECT 1 FROM @p WHERE a NOT IN ('initial','recover','reinit','incremental','rebuild')
           OR (a='incremental' AND f IS NULL) OR (a='rebuild' AND @mode<>'rebuild') OR ISJSON(ISNULL(k,N'{}'))<>1)
   THROW 51861,'Plan de sincronizacion invalido.',1;
 -- A newer rebuild was served to this fork since the pass began: only its token opens the hub, so start it again.
 IF @mode='rebuild' AND @page>1
    AND NOT EXISTS(SELECT 1 FROM sync.PeerRebuilds WHERE PeerNodeId=@TargetNodeId AND ForkGuid=@TargetForkGuid AND Token=@planToken)
   SET @page=1;
 IF @page=1 UPDATE @p SET k=NULL,done=0;

 DECLARE @out TABLE(o int PRIMARY KEY,t sysname,a varchar(20),f bigint,k nvarchar(max),done bit,[rows] nvarchar(max));
 DECLARE @fork uniqueidentifier,@to bigint,@cur bigint,@schema varchar(20)=(SELECT MAX([Version]) FROM dbo.SaviaMigrations),
   @token uniqueidentifier=CASE WHEN @mode='rebuild' AND @page=1 THEN NEWID() WHEN @mode='rebuild' THEN @planToken END;
 DECLARE @o int,@t sysname,@a varchar(20),@f bigint,@k nvarchar(max),@owner nvarchar(600),@sel nvarchar(max),
   @ctOn nvarchar(max),@keys nvarchar(max),@keyDesc nvarchar(max),@keyJoin nvarchar(max),@after nvarchar(max),
   @parentCol sysname,@keyCol sysname,@flt nvarchar(max),@where nvarchar(max),@sql nvarchar(max),@rows nvarchar(max),
   @next nvarchar(max),@n int,@cnt int,@bytes bigint,@used bigint=0,@hasRows bit=0,@stop bit=0;

 -- V034: a rebuild retires the target's other forks and records its token BEFORE the snapshot read, under the
 -- target's apply lock. A batch from an old fork that is being applied finishes first and is in the snapshot;
 -- a later one is refused (51853). Each rebuild served gets a new token; only the last one opens the hub to this fork.
 IF @mode='rebuild' AND @page=1
 BEGIN
   DECLARE @rc int,@lock nvarchar(255)=N'savia.sync.apply.'+CONVERT(nvarchar(36),@TargetNodeId);
   BEGIN TRANSACTION;
   BEGIN TRY
   EXEC @rc=sys.sp_getapplock @Resource=@lock,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=30000;
   IF @rc<0 THROW 51863,'Otro lote del mismo nodo se esta aplicando.',1;
   INSERT sync.RetiredForks(PeerNodeId,ForkGuid)
     SELECT DISTINCT @TargetNodeId,c.ForkGuid FROM sync.PeerCursors c
     WHERE c.PeerNodeId=@TargetNodeId AND c.ForkGuid<>@TargetForkGuid
       AND NOT EXISTS(SELECT 1 FROM sync.RetiredForks r WHERE r.PeerNodeId=@TargetNodeId AND r.ForkGuid=c.ForkGuid);
   UPDATE sync.PeerRebuilds SET Token=@token,ServedAt=SYSUTCDATETIME() WHERE PeerNodeId=@TargetNodeId AND ForkGuid=@TargetForkGuid;
   IF @@ROWCOUNT=0 INSERT sync.PeerRebuilds(PeerNodeId,ForkGuid,Token) VALUES(@TargetNodeId,@TargetForkGuid,@token);
   COMMIT;
   END TRY
   BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
 END;

 SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
 BEGIN TRANSACTION;
 BEGIN TRY
 SET @cur=CHANGE_TRACKING_CURRENT_VERSION();   -- V034: first statement of the snapshot, before any other read
 SET @to=CASE WHEN @page=1 THEN @cur ELSE @planTo END;
 SET @fork=(SELECT ForkGuid FROM sync.CurrentFork);
 IF @fork<>@planFork THROW 51858,'El fork del emisor cambio durante la sincronizacion.',1;
 IF @to>@cur THROW 51861,'Plan de sincronizacion invalido.',1;
 -- A branch shows the hub the rebuild it applied on its current fork; the hub needs it before it takes a new fork.
 IF @isHub=0 SET @token=(SELECT Token FROM sync.AppliedRebuilds WHERE PeerNodeId=@TargetNodeId AND ForkGuid=@fork);
 DECLARE c CURSOR LOCAL FAST_FORWARD FOR
   SELECT s.ApplyOrder,s.TableName,p.a,p.f,p.k,s.OwnerExpr,s.SelectList,s.CtOnList,
          k.KeyList,k.KeyDesc,k.KeyJoin,k.KeyAfter,k.ParentCol,k.KeyCol
   FROM sync.fn_TableShape() s JOIN sync.fn_TableKeys() k ON k.TableName=s.TableName JOIN @p p ON p.t=s.TableName
   WHERE p.done=0 ORDER BY s.ApplyOrder;
 OPEN c;
 FETCH NEXT FROM c INTO @o,@t,@a,@f,@k,@owner,@sel,@ctOn,@keys,@keyDesc,@keyJoin,@after,@parentCol,@keyCol;
 WHILE @@FETCH_STATUS=0 AND @stop=0
 BEGIN
   SET @flt=CASE WHEN @mode='rebuild' THEN N'1=1' WHEN @isHub=1 THEN N'('+@owner+N')<>@target' ELSE N'('+@owner+N')=@me' END;
   IF @a='incremental' AND CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID(@t))>@f
     THROW 51859,'Cambios ya depurados durante la sincronizacion.',1;
   IF @a<>'incremental' AND @to<@cur AND CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID(@t))>@to
     THROW 51859,'Cambios ya depurados durante la sincronizacion.',1;
   -- Rows as they were at `to`: a row changed after it is left out here and read by the next round.
   -- A branch never sends a change it applied from a peer (usp_ApplyBatch marks those with the sync context). The cheap
   -- context test runs before the per-row owner subquery, which after a large pull cost seconds per push.
   SET @where=CASE WHEN @isHub=0 AND @a='incremental' THEN N'ct.SYS_CHANGE_CONTEXT IS NULL AND ' ELSE N'' END+@flt
     +CASE WHEN @a='incremental' THEN N' AND ct.SYS_CHANGE_VERSION<=@to'
           WHEN @to<@cur THEN N' AND NOT EXISTS(SELECT 1 FROM CHANGETABLE(CHANGES '+@t+N',@to) ct WHERE '+@ctOn+N')'
           ELSE N'' END
     +CASE WHEN @k IS NULL THEN N'' ELSE N' AND '+@after END;
   SET @sql=CASE WHEN @a='incremental' AND @k IS NULL
                 THEN N'IF EXISTS(SELECT 1 FROM CHANGETABLE(CHANGES '+@t+N',@f) ct WHERE ct.SYS_CHANGE_OPERATION=''D'') '
                     +N'THROW 51860,''Borrado fisico en una tabla sincronizada.'',1; ' ELSE N'' END
     +N'SELECT TOP(0) '+@keys+N' INTO #k FROM '+@t+N' t; '
     +N'INSERT #k SELECT TOP(@n) '+@keys+N' FROM '
     +CASE WHEN @a='incremental' THEN N'CHANGETABLE(CHANGES '+@t+N',@f) ct JOIN '+@t+N' t ON '+@ctOn ELSE @t+N' t' END
     +N' WHERE '+@where+N' ORDER BY '+@keys+N'; SET @cnt=@@ROWCOUNT; '
     +N'SET @next=(SELECT TOP(1) * FROM #k ORDER BY '+@keyDesc+N' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER); '
     -- A child row whose parent is not in this page brings the parent, so the foreign key holds at the receiver.
     +CASE WHEN @parentCol IS NULL THEN N'' ELSE
        N'WHILE 1=1 BEGIN INSERT #k SELECT DISTINCT t.'+QUOTENAME(@keyCol)+N' FROM #k x JOIN '+@t+N' c ON c.'+QUOTENAME(@keyCol)
       +N'=x.'+QUOTENAME(@keyCol)+N' JOIN '+@t+N' t ON t.'+QUOTENAME(@keyCol)+N'=c.'+QUOTENAME(@parentCol)+N' WHERE '+@flt
       +N' AND NOT EXISTS(SELECT 1 FROM #k y WHERE y.'+QUOTENAME(@keyCol)+N'=t.'+QUOTENAME(@keyCol)+N'); IF @@ROWCOUNT=0 BREAK; END; ' END
     +N'SET @rows=(SELECT '+@sel+N' FROM #k k JOIN '+@t+N' t ON '+@keyJoin+N' FOR JSON PATH, INCLUDE_NULL_VALUES); DROP TABLE #k;';
   SET @n=@PageRows;
   WHILE 1=1
   BEGIN
     SELECT @rows=NULL,@next=NULL,@cnt=0;
     EXEC sys.sp_executesql @sql,
          N'@f bigint,@to bigint,@me uniqueidentifier,@target uniqueidentifier,@k nvarchar(max),@n int,@cnt int OUTPUT,@next nvarchar(max) OUTPUT,@rows nvarchar(max) OUTPUT',
          @f=@f,@to=@to,@me=@me,@target=@TargetNodeId,@k=@k,@n=@n,@cnt=@cnt OUTPUT,@next=@next OUTPUT,@rows=@rows OUTPUT;
     SET @rows=ISNULL(@rows,N'[]');
     SET @bytes=DATALENGTH(CAST(@rows COLLATE Latin1_General_100_CI_AS_SC_UTF8 AS varchar(max)));
     IF @hasRows=1 AND @used+@bytes>@PageBytes BEGIN SET @stop=1; BREAK; END;   -- this table starts the next page
     IF @hasRows=0 AND @bytes>@PageBytes AND @n>1 BEGIN SET @n/=2; CONTINUE; END;   -- one chunk alone is too large
     INSERT @out VALUES(@o,@t,@a,CASE WHEN @a='incremental' THEN @f END,ISNULL(@next,@k),CASE WHEN @cnt<@n THEN 1 ELSE 0 END,@rows);
     SET @used+=@bytes;
     IF @cnt>0 SET @hasRows=1;
     IF @cnt>=@n SET @stop=1;   -- a table that is not finished ends the page
     BREAK;
   END;
   FETCH NEXT FROM c INTO @o,@t,@a,@f,@k,@owner,@sel,@ctOn,@keys,@keyDesc,@keyJoin,@after,@parentCol,@keyCol;
 END;
 CLOSE c; DEALLOCATE c;
 COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;

 DECLARE @last bit=CASE WHEN EXISTS(SELECT 1 FROM @p p WHERE p.done=0
                                    AND NOT EXISTS(SELECT 1 FROM @out x WHERE x.t=p.t AND x.done=1)) THEN 0 ELSE 1 END;
 SET @Json=(SELECT @me AS node,@fork AS fork,@to AS [to],@schema AS [schema],@mode AS mode,@token AS rebuild,
   @page AS page,@last AS [last],
   JSON_QUERY((SELECT t,a,f,JSON_QUERY(k) AS k,done,JSON_QUERY([rows]) AS [rows] FROM @out ORDER BY o
               FOR JSON PATH, INCLUDE_NULL_VALUES)) AS tables
   FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES);
END;
GO

-- The receiver applies one page. Pass rules (V060): page 1 opens a pass, or replaces an open one when it comes from
-- a new fork, a new rebuild or a later version; a page of another pass, or one already applied, is skipped; a page
-- after a missing one is a gap (51852). A table's cursor moves only when the page finishes the table.
-- The final rebuild page records the token and lifts the recovery lock in the same transaction as its rows.
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
   @page int=ISNULL(TRY_CONVERT(int,JSON_VALUE(@BatchJson,'$.page')),1),
   @last bit=ISNULL(TRY_CONVERT(bit,JSON_VALUE(@BatchJson,'$.last')),1),
   @isHub bit=CASE WHEN (SELECT Kind FROM sync.Nodes WHERE Id=@me)='azure' THEN 1 ELSE 0 END;
 IF @node IS NULL OR @fork IS NULL OR @to IS NULL OR ISNULL(@mode,'') NOT IN ('normal','rebuild') OR @page<1
   THROW 51861,'Lote de sincronizacion invalido.',1;
 IF @node<>@PeerNodeId OR sync.fn_PeerAllowed(@me,@PeerNodeId)=0 THROW 51850,'Par de nodos no permitido.',1;
 IF @mode='rebuild' AND @isHub=1 THROW 51850,'El hub no acepta un lote de reconstruccion.',1;
 IF @mode='rebuild' AND @token IS NULL THROW 51861,'Lote de reconstruccion sin token.',1;
 IF ISNULL(JSON_VALUE(@BatchJson,'$.schema'),'')<>(SELECT MAX([Version]) FROM dbo.SaviaMigrations)
   THROW 51856,'Version de esquema distinta.',1;
 DECLARE @b TABLE(t sysname PRIMARY KEY,a varchar(20),f bigint,k nvarchar(max),done bit,[rows] nvarchar(max));
 INSERT @b SELECT t,a,f,k,ISNULL(done,1),[rows] FROM OPENJSON(@BatchJson,'$.tables')
   WITH (t sysname,a varchar(20),f bigint,k nvarchar(max) AS JSON,done bit,[rows] nvarchar(max) AS JSON);
 IF EXISTS(SELECT 1 FROM @b b WHERE NOT EXISTS(SELECT 1 FROM sync.SyncTables st WHERE st.TableName=b.t))
   THROW 51856,'El lote trae una tabla no sincronizada.',1;
 IF EXISTS(SELECT 1 FROM @b WHERE a NOT IN ('initial','recover','reinit','incremental','rebuild') OR (a='incremental' AND f IS NULL)
           OR (a='rebuild' AND @mode<>'rebuild') OR ISJSON(ISNULL([rows],N'x'))<>1 OR (@last=1 AND done=0))
   THROW 51861,'Lote de sincronizacion invalido.',1;

 DECLARE @tc int=@@TRANCOUNT,@lock nvarchar(255)=N'savia.sync.apply.'+CONVERT(nvarchar(36),@PeerNodeId),@rc int;
 DECLARE @changed int=0,@applied int=0,@skipped int=0,@n int,@bad int,@act varchar(10),@more bit,@done int,
   @total int=(SELECT COUNT(*) FROM sync.SyncTables);
 IF @tc=0 BEGIN TRANSACTION;
 BEGIN TRY
 EXEC @rc=sys.sp_getapplock @Resource=@lock,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=30000;
 IF @rc<0 THROW 51863,'Otro lote del mismo nodo se esta aplicando.',1;
 IF EXISTS(SELECT 1 FROM sync.RetiredForks WHERE PeerNodeId=@PeerNodeId AND ForkGuid=@fork)
   THROW 51853,'Lote de un fork retirado (anterior a una restauracion).',1;
 IF @isHub=1 AND EXISTS(SELECT 1 FROM sync.PeerCursors WHERE PeerNodeId=@PeerNodeId AND ForkGuid<>@fork)
    AND NOT EXISTS(SELECT 1 FROM sync.PeerRebuilds WHERE PeerNodeId=@PeerNodeId AND ForkGuid=@fork AND Token=@token)
   THROW 51854,'El nodo restaurado debe reconstruirse desde el hub antes de enviar.',1;

 DECLARE @pFork uniqueidentifier,@pMode varchar(10),@pTo bigint,@pToken uniqueidentifier,@pNext int;
 SELECT @pFork=ForkGuid,@pMode=Mode,@pTo=ToVersion,@pToken=Token,@pNext=NextPage
 FROM sync.PeerPasses WITH (UPDLOCK,HOLDLOCK) WHERE PeerNodeId=@PeerNodeId;
 -- A late copy of page 1 of a finished pass would open that pass again and resend rows already here.
 DECLARE @stale bit=CASE WHEN @page=1 AND @last=0 AND (
     (@mode='rebuild' AND EXISTS(SELECT 1 FROM sync.AppliedRebuilds WHERE PeerNodeId=@PeerNodeId AND Token=@token))
     OR (@mode='normal' AND NOT EXISTS(SELECT 1 FROM @b b WHERE NOT EXISTS(SELECT 1 FROM sync.PeerCursors pc
           WHERE pc.PeerNodeId=@PeerNodeId AND pc.TableName=b.t AND pc.ForkGuid=@fork AND pc.[Version]>=@to))))
   THEN 1 ELSE 0 END;
 SET @act=CASE
   WHEN @stale=1 THEN 'skip'
   WHEN @pNext IS NULL THEN CASE WHEN @page=1 THEN 'apply' ELSE 'skip' END   -- a late page of a closed pass
   WHEN @page=1 AND (@pFork<>@fork OR (@mode='rebuild' AND (@pMode='normal' OR @pToken<>@token))
                     OR (@mode='normal' AND @pMode='normal' AND @to>@pTo)) THEN 'replace'
   WHEN @pFork<>@fork OR @pMode<>@mode OR @pTo<>@to OR (@mode='rebuild' AND @pToken<>@token) THEN 'skip'
   WHEN @page<@pNext THEN 'skip'
   WHEN @page>@pNext THEN 'gap'
   ELSE 'apply' END;
 IF @act='gap' THROW 51852,'Pagina de sincronizacion fuera de orden.',1;
 IF @act='replace' BEGIN DELETE sync.PeerPasses WHERE PeerNodeId=@PeerNodeId; SELECT @pNext=NULL,@act='apply'; END;
 IF @act='skip' SET @skipped=(SELECT COUNT(*) FROM @b);

 -- D-037: own sales that only the rebuild brings back. Their events left with the lost fork; none is created again.
 DECLARE @recovered TABLE(SaleId uniqueidentifier PRIMARY KEY);
 IF @act='apply' AND @mode='rebuild'
   INSERT @recovered SELECT r.Id FROM @b b CROSS APPLY OPENJSON(b.[rows]) WITH (Id uniqueidentifier,OriginNodeId uniqueidentifier) r
   WHERE b.t=N'[sales].[Sales]' AND ISNULL(r.OriginNodeId,@me)=@me AND NOT EXISTS(SELECT 1 FROM sales.Sales s WHERE s.Id=r.Id);

 DECLARE @t sysname,@a varchar(20),@f bigint,@done1 bit,@rows nvarchar(max),@owner nvarchar(600),@with nvarchar(max),
   @ins nvarchar(max),@val nvarchar(max),@upd nvarchar(max),@diffS nvarchar(max),@diffT nvarchar(max),@on nvarchar(max),
   @sql nvarchar(max),@cf uniqueidentifier,@cv bigint;
 DECLARE c CURSOR LOCAL FAST_FORWARD FOR
   SELECT s.TableName,b.a,b.f,b.done,b.[rows],s.OwnerExpr,s.WithList,s.InsList,s.ValList,s.UpdList,s.DiffS,s.DiffT,s.OnList
   FROM sync.fn_TableShape() s JOIN @b b ON b.t=s.TableName WHERE @act='apply' ORDER BY s.ApplyOrder;
 OPEN c;
 FETCH NEXT FROM c INTO @t,@a,@f,@done1,@rows,@owner,@with,@ins,@val,@upd,@diffS,@diffT,@on;
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
     -- The sync context marks applied rows in change tracking; a branch read skips them (usp_ReadBatch).
     DECLARE @syncContext varbinary(128)=CONVERT(varbinary(128),'savia.sync');
     SET @sql=N'WITH CHANGE_TRACKING_CONTEXT(@ctx) MERGE '+@t+N' WITH (HOLDLOCK) AS t USING (SELECT * FROM OPENJSON(@rows) WITH ('+@with+N')) AS s ON '+@on
       +CASE WHEN @upd IS NULL THEN N'' ELSE N' WHEN MATCHED AND EXISTS(SELECT '+@diffS+N' EXCEPT SELECT '+@diffT
       +N') THEN UPDATE SET '+@upd END
       +N' WHEN NOT MATCHED BY TARGET THEN INSERT ('+@ins+N') VALUES ('+@val+N'); SET @n=@@ROWCOUNT;';
     SET @n=0;
     EXEC sys.sp_executesql @sql,N'@rows nvarchar(max),@ctx varbinary(128),@n int OUTPUT',@rows=@rows,
          @ctx=@syncContext,@n=@n OUTPUT;
     SET @changed+=@n;
     SET @applied+=1;
     IF @done1=1 AND @cf IS NULL
       INSERT sync.PeerCursors(PeerNodeId,TableName,ForkGuid,[Version]) VALUES(@PeerNodeId,@t,@fork,@to);
     ELSE IF @done1=1 AND (@cf<>@fork OR @to>@cv)
     BEGIN
       IF @cf<>@fork AND NOT EXISTS(SELECT 1 FROM sync.RetiredForks WHERE PeerNodeId=@PeerNodeId AND ForkGuid=@cf)
         INSERT sync.RetiredForks(PeerNodeId,ForkGuid) VALUES(@PeerNodeId,@cf);
       UPDATE sync.PeerCursors SET ForkGuid=@fork,[Version]=@to,UpdatedAt=SYSUTCDATETIME()
         WHERE PeerNodeId=@PeerNodeId AND TableName=@t;
     END;
   END;
   FETCH NEXT FROM c INTO @t,@a,@f,@done1,@rows,@owner,@with,@ins,@val,@upd,@diffS,@diffT,@on;
 END;
 CLOSE c; DEALLOCATE c;

 IF @act='apply' AND @last=0
 BEGIN
   IF @pNext IS NULL
     INSERT sync.PeerPasses(PeerNodeId,ForkGuid,Mode,ToVersion,Token,NextPage)
     VALUES(@PeerNodeId,@fork,@mode,@to,CASE WHEN @mode='rebuild' THEN @token END,@page+1);
   ELSE
     UPDATE sync.PeerPasses SET NextPage=@page+1,UpdatedAt=SYSUTCDATETIME() WHERE PeerNodeId=@PeerNodeId;
   MERGE sync.PeerPassTables AS pt
   USING (SELECT t,a,f,k,done FROM @b) AS s ON pt.PeerNodeId=@PeerNodeId AND pt.TableName=s.t
   WHEN MATCHED THEN UPDATE SET ResumeKey=s.k,Done=s.done
   WHEN NOT MATCHED THEN INSERT(PeerNodeId,TableName,[Action],FromVersion,ResumeKey,Done) VALUES(@PeerNodeId,s.t,s.a,s.f,s.k,s.done);
 END;
 IF @act='apply' AND @last=1
   DELETE sync.PeerPasses WHERE PeerNodeId=@PeerNodeId;
 IF @act='apply' AND @mode='rebuild'
 BEGIN
   DECLARE @ownFork uniqueidentifier=(SELECT ForkGuid FROM sync.CurrentFork);
   INSERT sync.RecoveredSales(SaleId,ForkGuid) SELECT SaleId,@ownFork FROM @recovered;
   IF @last=1
   BEGIN
     -- Same transaction as the final rows: the token exists on this branch only if the whole rebuild landed.
     UPDATE sync.AppliedRebuilds SET Token=@token,AppliedAt=SYSUTCDATETIME() WHERE PeerNodeId=@PeerNodeId AND ForkGuid=@ownFork;
     IF @@ROWCOUNT=0 INSERT sync.AppliedRebuilds(PeerNodeId,ForkGuid,Token) VALUES(@PeerNodeId,@ownFork,@token);
     -- D-036: the hub's copy has landed, so this fork may sell, open tills and receive again.
     UPDATE sync.LocalNode SET ForkGuid=@ownFork;
   END;
 END;
 SET @more=CASE WHEN EXISTS(SELECT 1 FROM sync.PeerPasses WHERE PeerNodeId=@PeerNodeId) THEN 1 ELSE 0 END;
 SET @done=CASE WHEN @act='apply' AND @last=1 THEN @total
                ELSE (SELECT COUNT(*) FROM sync.PeerPassTables WHERE PeerNodeId=@PeerNodeId AND Done=1) END;
 IF @tc=0 COMMIT;
 END TRY
 BEGIN CATCH
   IF @tc=0 AND @@TRANCOUNT>0 ROLLBACK;
   -- A row refers to a row the sender changed after `to`: this pass cannot finish, so the next plan starts a new one.
   IF @tc=0 AND ERROR_NUMBER()=547 DELETE sync.PeerPasses WHERE PeerNodeId=@PeerNodeId;
   THROW;
 END CATCH;
 SET @Json=(SELECT @changed AS changed,@applied AS applied,@skipped AS skipped,@page AS page,@more AS more,
                   @done AS done,@total AS total FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);
END;
GO
