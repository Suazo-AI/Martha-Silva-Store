-- savia:transactional
-- V035: role savia_api_host holds the least-privilege permissions of the API host (savia/docs/deploy/AZURE.md P5).
-- Before, savia/deploy/migrator/Program.cs granted them; now every database gets them from the migrations and the
-- migrator only creates the API user and adds it to this role. Idempotent: the Azure database already has the role.
IF DATABASE_PRINCIPAL_ID(N'savia_api_host') IS NULL CREATE ROLE [savia_api_host] AUTHORIZATION [dbo];

-- The API reads views and tables, executes procedures, and writes sign-in state directly
-- (savia/src/Savia.Infrastructure/AuthStore.cs). It never runs DDL and never deletes.
GRANT SELECT TO [savia_api_host];
GRANT EXECUTE TO [savia_api_host];
GRANT INSERT, UPDATE ON OBJECT::[security].[Sessions] TO [savia_api_host];
GRANT UPDATE ON OBJECT::[security].[Staff] TO [savia_api_host];

-- sync.usp_ReadBatch and sync.usp_ApplyBatch (V032-V034) read CHANGETABLE and MERGE rows in dynamic SQL.
-- Dynamic SQL breaks ownership chaining, so those statements run with the caller's own permissions on each synced
-- table. A table added to sync.SyncTables later needs the same grant in its migration (test security/100).
DECLARE @grants nvarchar(max)=(
  SELECT STRING_AGG(CONVERT(nvarchar(max),
           N'GRANT INSERT, UPDATE, VIEW CHANGE TRACKING ON OBJECT::'+TableName+N' TO [savia_api_host];'),NCHAR(10))
         WITHIN GROUP (ORDER BY TableName)
  FROM sync.SyncTables);
EXEC sys.sp_executesql @grants;
