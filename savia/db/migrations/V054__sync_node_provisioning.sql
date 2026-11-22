-- savia:transactional
-- V054: S7 in docs/production-20261122/README.md (D-040, GAPS G3). Node provisioning.
-- sync.usp_ProvisionNode registers a node with a fixed id, kind, branch and code. Savia.Migrator --provision-node
-- runs it on the hub (then sets a new credential) and on each store database (the hub's node and the store's own),
-- so every database holds the same node rows. A retry is a no-op; a different definition of an id or code is refused.
-- One hub node and one node per branch: the owner expressions in sync.SyncTables (V053) resolve a node by kind and
-- branch with a scalar subquery, which a second match would break.
-- The procedure never enables a disabled node: disabling is an operator decision this command does not undo.
-- New error: 51865 node definition conflicts with an existing node (sync.node_mismatch).

CREATE OR ALTER PROCEDURE [sync].[usp_ProvisionNode]
 @NodeId uniqueidentifier,@Kind varchar(16),@BranchId uniqueidentifier,@NodeCode nvarchar(70)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @code nvarchar(70)=NULLIF(LTRIM(RTRIM(@NodeCode)),N'');
 IF @NodeId IS NULL OR @code IS NULL OR NOT ((@Kind='azure' AND @BranchId IS NULL) OR (@Kind='branch' AND @BranchId IS NOT NULL))
   THROW 51865,'Nodo invalido: un nodo azure no tiene sucursal y una sucursal si.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM sync.Nodes WITH (UPDLOCK,HOLDLOCK)
             WHERE (Id=@NodeId OR NodeCode=@code OR (@Kind='azure' AND Kind='azure') OR BranchId=@BranchId)
               AND NOT (Id=@NodeId AND NodeCode=@code AND Kind=@Kind AND ISNULL(BranchId,0x0)=ISNULL(@BranchId,0x0)))
     THROW 51865,'El id, el codigo, el hub o la sucursal ya pertenecen a otro nodo.',1;
   INSERT sync.Nodes(Id,BranchId,NodeCode,Kind)
   SELECT @NodeId,@BranchId,@code,@Kind WHERE NOT EXISTS(SELECT 1 FROM sync.Nodes WHERE Id=@NodeId);
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO
