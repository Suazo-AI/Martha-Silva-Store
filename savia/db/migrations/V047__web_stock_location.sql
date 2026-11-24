-- savia:transactional
-- V047: web stock locations (docs/production-20261122/ORDER-PATH-SPEC.md 3.3 and 4.1).
-- The web sells only from locations of the WEB branch. That branch has no sync node, so the owner expression of
-- StockBalances and StockMovements rows at a web location is NULL: the hub never sends them in a normal batch and
-- refuses them from every branch (51851). Only the hub writes web stock, so a branch push can never overwrite a web
-- reservation (the oversell described in spec 3.2).
-- One web location per store location. Its id is derived from the store location id, so every node creates the
-- same row without syncing core.Locations, and a rebuild that carries web stock rows finds the location on a branch.

-- A fixed, derived id for one step of one operation. Callers name the step; the same pair always gives the same id.
CREATE OR ALTER FUNCTION [inventory].[ufn_StepId](@Id uniqueidentifier,@Step varchar(30)) RETURNS uniqueidentifier
WITH SCHEMABINDING
AS
BEGIN
  RETURN CONVERT(uniqueidentifier,HASHBYTES('MD5',CONVERT(varbinary(16),@Id)+CONVERT(varbinary(30),@Step)));
END;
GO

INSERT INTO core.Branches(Id,Code,Name,StoreDisplayName)
SELECT '7E1B0000-0000-4000-8000-000000000001','WEB',N'Tienda web',N'Tienda web'
WHERE NOT EXISTS(SELECT 1 FROM core.Branches WHERE Code='WEB');
GO

-- Which store holds the garments of each web location. Fulfillment ships from the source store.
-- PriorityRank: the order procedure tries the lowest rank first.
CREATE TABLE [webstore].[WebLocationSources] (
  [WebLocationId] uniqueidentifier NOT NULL,
  [SourceBranchId] uniqueidentifier NOT NULL,
  [SourceLocationId] uniqueidentifier NOT NULL,
  [PriorityRank] int NOT NULL CONSTRAINT [DF_WebLocationSources_Rank] DEFAULT(100),
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_webstore_WebLocationSources_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_WebLocationSources] PRIMARY KEY ([WebLocationId]),
  CONSTRAINT [UQ_WebLocationSources_Source] UNIQUE ([SourceLocationId]),
  CONSTRAINT [FK_WebLocationSources_Web] FOREIGN KEY ([WebLocationId]) REFERENCES [core].[Locations]([Id]),
  CONSTRAINT [FK_WebLocationSources_Source] FOREIGN KEY ([SourceLocationId],[SourceBranchId])
    REFERENCES [core].[Locations]([Id],[BranchId])
);
GO

-- Creates the web location of every store location that has none yet. Idempotent and safe on every node.
-- Kind 'warehouse': a web location holds consigned stock and never sells at a till.
CREATE OR ALTER PROCEDURE [inventory].[usp_EnsureWebLocations]
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;
  DECLARE @web uniqueidentifier=(SELECT Id FROM core.Branches WHERE Code='WEB');
  BEGIN TRANSACTION;
  BEGIN TRY
    DECLARE @missing TABLE(WebId uniqueidentifier PRIMARY KEY,SourceId uniqueidentifier,SourceBranchId uniqueidentifier,
      Code varchar(30),Name nvarchar(150));
    INSERT INTO @missing
    SELECT inventory.ufn_StepId(l.Id,'web_location'),l.Id,l.BranchId,
      CASE WHEN LEN(l.Code)<=26 THEN 'WEB-'+l.Code
           ELSE 'WEB-'+LEFT(REPLACE(CONVERT(varchar(36),inventory.ufn_StepId(l.Id,'web_location')),'-',''),26) END,
      N'Web · '+LEFT(l.Name,144)
    FROM core.Locations l WITH (UPDLOCK,HOLDLOCK)
    WHERE l.Kind='store' AND l.BranchId<>@web
      AND NOT EXISTS(SELECT 1 FROM webstore.WebLocationSources s WITH (UPDLOCK,HOLDLOCK) WHERE s.SourceLocationId=l.Id);
    INSERT INTO core.Locations(Id,BranchId,Code,Name,Kind)
    SELECT m.WebId,@web,m.Code,m.Name,'warehouse' FROM @missing m
    WHERE NOT EXISTS(SELECT 1 FROM core.Locations x WHERE x.Id=m.WebId);
    INSERT INTO webstore.WebLocationSources(WebLocationId,SourceBranchId,SourceLocationId)
    SELECT WebId,SourceBranchId,SourceId FROM @missing;
    COMMIT;
  END TRY
  BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

EXEC inventory.usp_EnsureWebLocations;
GO
