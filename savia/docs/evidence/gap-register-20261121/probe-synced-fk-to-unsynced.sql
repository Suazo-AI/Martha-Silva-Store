-- PROBE (gap register 2026-11-21): foreign keys from a synced table to a table that sync never moves.
SET NOCOUNT ON;
SELECT DISTINCT CAST(QUOTENAME(SCHEMA_NAME(p.schema_id))+'.'+QUOTENAME(p.name) AS varchar(40)) AS child,
       CAST(QUOTENAME(SCHEMA_NAME(r.schema_id))+'.'+QUOTENAME(r.name) AS varchar(40)) AS parent
FROM sys.foreign_keys fk
JOIN sys.tables p ON p.object_id=fk.parent_object_id
JOIN sys.tables r ON r.object_id=fk.referenced_object_id
WHERE QUOTENAME(SCHEMA_NAME(p.schema_id))+'.'+QUOTENAME(p.name) IN (SELECT TableName FROM sync.SyncTables)
  AND QUOTENAME(SCHEMA_NAME(r.schema_id))+'.'+QUOTENAME(r.name) NOT IN (SELECT TableName FROM sync.SyncTables)
ORDER BY parent, child;
