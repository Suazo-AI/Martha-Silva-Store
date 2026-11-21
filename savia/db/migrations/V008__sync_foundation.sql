-- V008: sync foundation (ADR-001 D5; critique F1, F5, F6, F7, F10).
-- 1. Change Tracking on the database and on the first six branch-owned tables.
-- 2. sync.LocalNode: the database knows which node it is (one row).
-- 3. sync.PeerCursors: the receiver keeps the cursor of each sender as (recovery fork, version).
-- 4. usp_GetSourceState, usp_ClassifyCursor, usp_AdvancePeerCursor.
-- Errors: 51806 local node already set to another node; 51807 node unknown or disabled;
--         51808 cursor would move backwards in the same fork; 51809 table is not tracked.
-- Retention is a provisional 30 days. The real value must exceed the longest accepted offline period (F7).

ALTER DATABASE CURRENT SET CHANGE_TRACKING = ON (CHANGE_RETENTION = 30 DAYS, AUTO_CLEANUP = ON);
GO

-- Branch-owned tables (ownership map, ADR-001-critica.md). The rest follow with the generated applier.
ALTER TABLE [sales].[Sales] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [sales].[SaleLines] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [sales].[SaleTenders] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [sales].[CashTills] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [sales].[CashEntries] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [inventory].[StockMovements] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
GO

CREATE TABLE [sync].[LocalNode] (
  [Singleton] tinyint NOT NULL CONSTRAINT [DF_sync_LocalNode_Singleton] DEFAULT (1),
  [NodeId] uniqueidentifier NOT NULL,
  [SetAt] datetime2(3) NOT NULL CONSTRAINT [DF_sync_LocalNode_SetAt] DEFAULT (SYSUTCDATETIME()),
  CONSTRAINT [PK_SyncLocalNode] PRIMARY KEY ([Singleton]),
  CONSTRAINT [CK_SyncLocalNode_One] CHECK ([Singleton] = 1),
  CONSTRAINT [FK_SyncLocalNode_Node] FOREIGN KEY ([NodeId]) REFERENCES [sync].[Nodes]([Id])
);
GO

CREATE TABLE [sync].[PeerCursors] (
  [PeerNodeId] uniqueidentifier NOT NULL,
  [TableName] sysname NOT NULL,
  [ForkGuid] uniqueidentifier NOT NULL,
  [Version] bigint NOT NULL,
  [UpdatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_sync_PeerCursors_UpdatedAt] DEFAULT (SYSUTCDATETIME()),
  CONSTRAINT [PK_SyncPeerCursors] PRIMARY KEY ([PeerNodeId],[TableName]),
  CONSTRAINT [FK_SyncPeerCursors_Node] FOREIGN KEY ([PeerNodeId]) REFERENCES [sync].[Nodes]([Id]),
  CONSTRAINT [CK_SyncPeerCursors_Version] CHECK ([Version] >= 0)
);
GO

CREATE OR ALTER PROCEDURE [sync].[usp_SetLocalNode]
 @NodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRANSACTION;
 BEGIN TRY
   DECLARE @current uniqueidentifier=(SELECT NodeId FROM sync.LocalNode WITH (UPDLOCK,HOLDLOCK));
   IF @current=@NodeId BEGIN COMMIT; RETURN; END;
   IF @current IS NOT NULL THROW 51806,'La base ya pertenece a otro nodo.',1;
   IF NOT EXISTS(SELECT 1 FROM sync.Nodes WHERE Id=@NodeId AND IsEnabled=1)
     THROW 51807,'Nodo inexistente o deshabilitado.',1;
   INSERT INTO sync.LocalNode(Singleton,NodeId) VALUES(1,@NodeId);
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

-- One row per tracked table: who I am, my recovery fork, my current version and the table's minimum valid version.
-- Read in one SNAPSHOT transaction so the versions are consistent with each other (F5).
CREATE OR ALTER PROCEDURE [sync].[usp_GetSourceState]
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 -- Own SNAPSHOT transaction when called alone. Inside a caller's transaction (INSERT-EXEC, or a C# caller that
 -- already began SNAPSHOT to read the changes too) it reads in that transaction; isolation cannot change there.
 DECLARE @ownTran bit=0;
 IF @@TRANCOUNT=0
 BEGIN
   SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
   BEGIN TRANSACTION; SET @ownTran=1;
 END;
   SELECT (SELECT NodeId FROM sync.LocalNode) AS NodeId,
          (SELECT recovery_fork_guid FROM sys.database_recovery_status WHERE database_id=DB_ID()) AS ForkGuid,
          CHANGE_TRACKING_CURRENT_VERSION() AS CurrentVersion,
          QUOTENAME(OBJECT_SCHEMA_NAME(t.object_id))+N'.'+QUOTENAME(OBJECT_NAME(t.object_id)) AS TableName,
          CHANGE_TRACKING_MIN_VALID_VERSION(t.object_id) AS MinValidVersion
   FROM sys.change_tracking_tables t
   ORDER BY TableName;
 IF @ownTran=1 COMMIT;
END;
GO

-- The receiver decides what to ask the sender for one table.
--   initial     no cursor yet: full state of the rows the sender owns
--   recover     the sender's fork changed (restore) or its version went backwards: versions are not comparable (F1)
--   reinit      the cursor is older than the minimum valid version: changes were cleaned up (F6, F7)
--   incremental changes since FromVersion
CREATE OR ALTER PROCEDURE [sync].[usp_ClassifyCursor]
 @PeerNodeId uniqueidentifier,@TableName sysname,@SourceForkGuid uniqueidentifier,
 @SourceCurrentVersion bigint,@SourceMinValidVersion bigint
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @curFork uniqueidentifier,@curVersion bigint;
 SELECT @curFork=ForkGuid,@curVersion=[Version] FROM sync.PeerCursors WHERE PeerNodeId=@PeerNodeId AND TableName=@TableName;
 SELECT CASE
          WHEN @curFork IS NULL THEN 'initial'
          WHEN @curFork<>@SourceForkGuid THEN 'recover'
          WHEN @SourceCurrentVersion<@curVersion THEN 'recover'
          WHEN @SourceMinValidVersion IS NULL OR @curVersion<@SourceMinValidVersion THEN 'reinit'
          ELSE 'incremental'
        END AS [Action],
        CASE WHEN @curFork=@SourceForkGuid AND @curVersion<=@SourceCurrentVersion
                  AND @curVersion>=@SourceMinValidVersion THEN @curVersion END AS FromVersion;
END;
GO

-- Called once, after every page of the table has been applied (F8).
CREATE OR ALTER PROCEDURE [sync].[usp_AdvancePeerCursor]
 @PeerNodeId uniqueidentifier,@TableName sysname,@ForkGuid uniqueidentifier,@Version bigint
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Version IS NULL OR @Version<0 OR @ForkGuid IS NULL THROW 51808,'Cursor invalido.',1;
 IF @TableName NOT IN (SELECT QUOTENAME(OBJECT_SCHEMA_NAME(object_id))+N'.'+QUOTENAME(OBJECT_NAME(object_id))
                       FROM sys.change_tracking_tables)
   THROW 51809,'Tabla sin Change Tracking.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   DECLARE @curFork uniqueidentifier,@curVersion bigint;
   SELECT @curFork=ForkGuid,@curVersion=[Version] FROM sync.PeerCursors WITH (UPDLOCK,HOLDLOCK)
     WHERE PeerNodeId=@PeerNodeId AND TableName=@TableName;
   IF @curFork IS NULL
     INSERT INTO sync.PeerCursors(PeerNodeId,TableName,ForkGuid,[Version]) VALUES(@PeerNodeId,@TableName,@ForkGuid,@Version);
   ELSE IF @curFork=@ForkGuid AND @Version<@curVersion
     THROW 51808,'El cursor no retrocede dentro del mismo fork.',1;
   ELSE IF @curFork<>@ForkGuid OR @Version>@curVersion
     UPDATE sync.PeerCursors SET ForkGuid=@ForkGuid,[Version]=@Version,UpdatedAt=SYSUTCDATETIME()
       WHERE PeerNodeId=@PeerNodeId AND TableName=@TableName;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO
