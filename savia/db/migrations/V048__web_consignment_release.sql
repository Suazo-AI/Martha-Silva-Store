-- savia:transactional
-- V048: stock enters a web location only by consignment and leaves it to a store only by release (ORDER-PATH-SPEC 3.3).
--   Consignment: the branch lowers its store pool and writes a branch-owned WebConsignments row; sync carries it to the
--   hub; the hub credits the web pool once per consignment id.
--   Release: the hub lowers the web pool and writes a hub-owned WebReleases row; sync carries it to every branch; the
--   target branch credits its store pool once per release id.
-- Each stock step uses a movement OperationId derived from the row id and the step name (inventory.ufn_StepId), so a
-- replay applies once (usp_ApplyMovement is idempotent by OperationId) and the branch and hub steps never share an id.
-- Errors: 51740 wrong node for this step, 51741 id reused with other content, 51742 invalid consignment or release.

CREATE TABLE [inventory].[WebConsignments] (
  [Id] uniqueidentifier NOT NULL,
  [SourceBranchId] uniqueidentifier NOT NULL,
  [SourceLocationId] uniqueidentifier NOT NULL,
  [ItemId] uniqueidentifier NOT NULL,
  [Quantity] int NOT NULL,
  [RequestedBy] uniqueidentifier NOT NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_inventory_WebConsignments_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_WebConsignments] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_WebConsignments_Location] FOREIGN KEY ([SourceLocationId],[SourceBranchId])
    REFERENCES [core].[Locations]([Id],[BranchId]),
  CONSTRAINT [FK_WebConsignments_Item] FOREIGN KEY ([ItemId]) REFERENCES [catalog].[Items]([Id]),
  CONSTRAINT [FK_WebConsignments_Staff] FOREIGN KEY ([RequestedBy]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [CK_WebConsignments_Quantity] CHECK ([Quantity] BETWEEN 1 AND 1000)
);
GO

-- No foreign key to the web location: a branch receives every release, and its web locations may lag the hub's.
CREATE TABLE [inventory].[WebReleases] (
  [Id] uniqueidentifier NOT NULL,
  [TargetBranchId] uniqueidentifier NOT NULL,
  [TargetLocationId] uniqueidentifier NOT NULL,
  [ItemId] uniqueidentifier NOT NULL,
  [Quantity] int NOT NULL,
  [RequestedBy] uniqueidentifier NOT NULL,
  [Reason] nvarchar(300) NOT NULL,
  [NodeId] uniqueidentifier NOT NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_inventory_WebReleases_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_WebReleases] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_WebReleases_Location] FOREIGN KEY ([TargetLocationId],[TargetBranchId])
    REFERENCES [core].[Locations]([Id],[BranchId]),
  CONSTRAINT [FK_WebReleases_Item] FOREIGN KEY ([ItemId]) REFERENCES [catalog].[Items]([Id]),
  CONSTRAINT [FK_WebReleases_Staff] FOREIGN KEY ([RequestedBy]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [FK_WebReleases_Node] FOREIGN KEY ([NodeId]) REFERENCES [sync].[Nodes]([Id]),
  CONSTRAINT [CK_WebReleases_Quantity] CHECK ([Quantity] BETWEEN 1 AND 1000),
  CONSTRAINT [CK_WebReleases_Reason] CHECK (LEN(LTRIM(RTRIM([Reason])))>0)
);
GO

ALTER TABLE [inventory].[WebConsignments] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
ALTER TABLE [inventory].[WebReleases] ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = OFF);
GO

-- Owners: a consignment belongs to the branch node of its store; a release to the hub node that wrote it.
INSERT INTO sync.SyncTables(TableName,ApplyOrder,OwnerExpr) VALUES
 (N'[inventory].[WebConsignments]',19,
  N'(SELECT n.Id FROM sync.Nodes n WHERE n.Kind=''branch'' AND n.BranchId=t.SourceBranchId)'),
 (N'[inventory].[WebReleases]',20,N't.NodeId');
-- V035: sync applies rows in dynamic SQL, which runs with the API host's own table permissions (test security/100).
GRANT INSERT, UPDATE, VIEW CHANGE TRACKING ON OBJECT::[inventory].[WebConsignments] TO [savia_api_host];
GRANT INSERT, UPDATE, VIEW CHANGE TRACKING ON OBJECT::[inventory].[WebReleases] TO [savia_api_host];
GO

-- Branch node: moves @Quantity from its store pool to the web. The hub credits the web pool when the row arrives.
CREATE OR ALTER PROCEDURE [inventory].[usp_ConsignToWeb]
  @ConsignmentId uniqueidentifier,@ItemId uniqueidentifier,@FromLocationId uniqueidentifier,@Quantity int,
  @ActorId uniqueidentifier
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  DECLARE @branch uniqueidentifier=(SELECT n.BranchId FROM sync.LocalNode ln JOIN sync.Nodes n ON n.Id=ln.NodeId
                                    WHERE n.Kind='branch');
  IF @branch IS NULL THROW 51740,'Solo una sucursal entrega stock a la web.',1;
  IF @Quantity NOT BETWEEN 1 AND 1000
     OR NOT EXISTS(SELECT 1 FROM core.Locations WHERE Id=@FromLocationId AND BranchId=@branch AND Kind='store' AND IsActive=1)
     OR NOT EXISTS(SELECT 1 FROM catalog.Items WHERE Id=@ItemId AND Status='active')
    THROW 51742,'Entrega a la web invalida: cantidad, tienda o articulo.',1;
  BEGIN TRANSACTION;
  BEGIN TRY
    IF EXISTS(SELECT 1 FROM inventory.WebConsignments WITH (UPDLOCK,HOLDLOCK) WHERE Id=@ConsignmentId)
    BEGIN
      IF NOT EXISTS(SELECT 1 FROM inventory.WebConsignments WHERE Id=@ConsignmentId AND ItemId=@ItemId
                    AND SourceLocationId=@FromLocationId AND Quantity=@Quantity)
        THROW 51741,'Id de entrega reutilizado con otro contenido.',1;
      COMMIT; RETURN;
    END;
    DECLARE @op uniqueidentifier=inventory.ufn_StepId(@ConsignmentId,'consign_out'),@out int=-@Quantity;
    EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@ItemId,@LocationId=@FromLocationId,@Pool='store',
      @Kind='transfer_out',@OnHandDelta=@out,@SourceType='web_consignment',@SourceId=@ConsignmentId,@ActorId=@ActorId;
    INSERT INTO inventory.WebConsignments(Id,SourceBranchId,SourceLocationId,ItemId,Quantity,RequestedBy)
      VALUES(@ConsignmentId,@branch,@FromLocationId,@ItemId,@Quantity,@ActorId);
    COMMIT;
  END TRY
  BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

-- Hub: credits the web pool for every consignment not applied yet. Returns the number applied. Safe to run often.
CREATE OR ALTER PROCEDURE [inventory].[usp_ApplyWebConsignments]
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  IF NOT EXISTS(SELECT 1 FROM sync.LocalNode ln JOIN sync.Nodes n ON n.Id=ln.NodeId WHERE n.Kind='azure')
    THROW 51740,'Solo el hub acredita stock web.',1;
  EXEC inventory.usp_EnsureWebLocations;
  DECLARE @pending TABLE(Id uniqueidentifier PRIMARY KEY,ItemId uniqueidentifier,WebLocationId uniqueidentifier,Quantity int);
  INSERT INTO @pending
  SELECT c.Id,c.ItemId,inventory.ufn_StepId(c.SourceLocationId,'web_location'),c.Quantity
  FROM inventory.WebConsignments c
  WHERE NOT EXISTS(SELECT 1 FROM inventory.StockMovements m WHERE m.OperationId=inventory.ufn_StepId(c.Id,'consign_in'));
  DECLARE @id uniqueidentifier,@item uniqueidentifier,@location uniqueidentifier,@qty int,@op uniqueidentifier,@applied int=0;
  DECLARE consignCursor CURSOR LOCAL FAST_FORWARD FOR SELECT Id,ItemId,WebLocationId,Quantity FROM @pending ORDER BY Id;
  OPEN consignCursor; FETCH NEXT FROM consignCursor INTO @id,@item,@location,@qty;
  WHILE @@FETCH_STATUS=0
  BEGIN
    SET @op=inventory.ufn_StepId(@id,'consign_in');
    EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@location,@Pool='web',
      @Kind='transfer_in',@OnHandDelta=@qty,@SourceType='web_consignment',@SourceId=@id;
    SET @applied+=1;
    FETCH NEXT FROM consignCursor INTO @id,@item,@location,@qty;
  END;
  CLOSE consignCursor; DEALLOCATE consignCursor;
  SELECT @applied AS Applied;
END;
GO

-- Hub: returns available web stock of one store's web location to that store.
CREATE OR ALTER PROCEDURE [inventory].[usp_ReleaseFromWeb]
  @ReleaseId uniqueidentifier,@ItemId uniqueidentifier,@TargetLocationId uniqueidentifier,@Quantity int,
  @Reason nvarchar(300),@ActorId uniqueidentifier
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  DECLARE @hub uniqueidentifier=(SELECT n.Id FROM sync.LocalNode ln JOIN sync.Nodes n ON n.Id=ln.NodeId WHERE n.Kind='azure');
  IF @hub IS NULL THROW 51740,'Solo el hub devuelve stock web a una tienda.',1;
  DECLARE @branch uniqueidentifier=(SELECT SourceBranchId FROM webstore.WebLocationSources WHERE SourceLocationId=@TargetLocationId);
  IF @branch IS NULL OR @Quantity NOT BETWEEN 1 AND 1000 OR LEN(LTRIM(RTRIM(ISNULL(@Reason,N''))))=0
    THROW 51742,'Devolucion de la web invalida: tienda, cantidad o motivo.',1;
  BEGIN TRANSACTION;
  BEGIN TRY
    IF EXISTS(SELECT 1 FROM inventory.WebReleases WITH (UPDLOCK,HOLDLOCK) WHERE Id=@ReleaseId)
    BEGIN
      IF NOT EXISTS(SELECT 1 FROM inventory.WebReleases WHERE Id=@ReleaseId AND ItemId=@ItemId
                    AND TargetLocationId=@TargetLocationId AND Quantity=@Quantity)
        THROW 51741,'Id de devolucion reutilizado con otro contenido.',1;
      COMMIT; RETURN;
    END;
    DECLARE @op uniqueidentifier=inventory.ufn_StepId(@ReleaseId,'release_out'),@out int=-@Quantity,
      @web uniqueidentifier=inventory.ufn_StepId(@TargetLocationId,'web_location');
    EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@ItemId,@LocationId=@web,@Pool='web',
      @Kind='transfer_out',@OnHandDelta=@out,@SourceType='web_release',@SourceId=@ReleaseId,@ActorId=@ActorId;
    INSERT INTO inventory.WebReleases(Id,TargetBranchId,TargetLocationId,ItemId,Quantity,RequestedBy,Reason,NodeId)
      VALUES(@ReleaseId,@branch,@TargetLocationId,@ItemId,@Quantity,@ActorId,LTRIM(RTRIM(@Reason)),@hub);
    COMMIT;
  END TRY
  BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

-- Branch node: credits its store pool for every release to this branch not applied yet. Returns the number applied.
-- Also creates missing web locations, so a later rebuild that carries web stock rows finds them here.
CREATE OR ALTER PROCEDURE [inventory].[usp_ApplyWebReleases]
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  DECLARE @branch uniqueidentifier=(SELECT n.BranchId FROM sync.LocalNode ln JOIN sync.Nodes n ON n.Id=ln.NodeId
                                    WHERE n.Kind='branch');
  IF @branch IS NULL THROW 51740,'Solo una sucursal recibe stock devuelto por la web.',1;
  EXEC inventory.usp_EnsureWebLocations;
  DECLARE @pending TABLE(Id uniqueidentifier PRIMARY KEY,ItemId uniqueidentifier,LocationId uniqueidentifier,Quantity int);
  INSERT INTO @pending
  SELECT r.Id,r.ItemId,r.TargetLocationId,r.Quantity
  FROM inventory.WebReleases r
  WHERE r.TargetBranchId=@branch
    AND NOT EXISTS(SELECT 1 FROM inventory.StockMovements m WHERE m.OperationId=inventory.ufn_StepId(r.Id,'release_in'));
  DECLARE @id uniqueidentifier,@item uniqueidentifier,@location uniqueidentifier,@qty int,@op uniqueidentifier,@applied int=0;
  DECLARE releaseCursor CURSOR LOCAL FAST_FORWARD FOR SELECT Id,ItemId,LocationId,Quantity FROM @pending ORDER BY Id;
  OPEN releaseCursor; FETCH NEXT FROM releaseCursor INTO @id,@item,@location,@qty;
  WHILE @@FETCH_STATUS=0
  BEGIN
    SET @op=inventory.ufn_StepId(@id,'release_in');
    EXEC inventory.usp_ApplyMovement @OperationId=@op,@ItemId=@item,@LocationId=@location,@Pool='store',
      @Kind='transfer_in',@OnHandDelta=@qty,@SourceType='web_release',@SourceId=@id;
    SET @applied+=1;
    FETCH NEXT FROM releaseCursor INTO @id,@item,@location,@qty;
  END;
  CLOSE releaseCursor; DEALLOCATE releaseCursor;
  SELECT @applied AS Applied;
END;
GO
