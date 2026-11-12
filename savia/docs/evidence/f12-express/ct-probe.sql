-- F14 probe: Change Tracking and SNAPSHOT reads on the current database (run on Express).
SET NOCOUNT ON;
DECLARE @db sysname=DB_NAME(), @sql nvarchar(max);
SET @sql=N'ALTER DATABASE '+QUOTENAME(@db)+N' SET ALLOW_SNAPSHOT_ISOLATION ON;';
EXEC(@sql);
SET @sql=N'ALTER DATABASE '+QUOTENAME(@db)+N' SET CHANGE_TRACKING=ON (CHANGE_RETENTION=7 DAYS, AUTO_CLEANUP=ON);';
EXEC(@sql);
CREATE TABLE dbo.Probe(Id int NOT NULL PRIMARY KEY, V int NOT NULL);
ALTER TABLE dbo.Probe ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED=OFF);
DECLARE @v0 bigint=CHANGE_TRACKING_CURRENT_VERSION();
INSERT dbo.Probe VALUES(1,10),(2,20); UPDATE dbo.Probe SET V=11 WHERE Id=1;
SET TRANSACTION ISOLATION LEVEL SNAPSHOT;
BEGIN TRANSACTION;
  DECLARE @cur bigint=CHANGE_TRACKING_CURRENT_VERSION(),
          @min bigint=CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID('dbo.Probe')),
          @rows int=(SELECT COUNT(*) FROM CHANGETABLE(CHANGES dbo.Probe,@v0) c);
COMMIT;
SELECT CAST(SERVERPROPERTY('Edition') AS nvarchar(40)) AS edition, CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(32)) AS version,
  (SELECT is_read_committed_snapshot_on FROM sys.databases WHERE name=@db) AS rcsi,
  (SELECT COUNT(*) FROM sys.change_tracking_databases WHERE database_id=DB_ID()) AS ct_db,
  (SELECT COUNT(*) FROM sys.change_tracking_tables) AS ct_tables, @v0 AS v0, @cur AS cur, @min AS min_valid, @rows AS changed_rows;
IF @rows<>2 OR @cur<=@v0 THROW 59002,'ASSERT FAIL: change tracking did not report 2 changed rows',1;
PRINT 'PASS';
