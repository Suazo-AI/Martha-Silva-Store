-- TEST: only sync.CurrentFork reads the engine's fork source. Azure SQL Database has no sys.database_recovery_status,
-- so any other module that names it compiles there and then fails on its first call (found on the hub, 2026-11-22).
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @n bigint,@names nvarchar(max);
SELECT @n=COUNT(*),@names=STRING_AGG(CONCAT(OBJECT_SCHEMA_NAME(m.object_id),N'.',OBJECT_NAME(m.object_id)),N', ')
FROM sys.sql_modules m
WHERE m.definition LIKE N'%database_recovery_status%' AND m.object_id<>OBJECT_ID(N'sync.CurrentFork');
IF @n<>0 BEGIN DECLARE @msg nvarchar(2000)=CONCAT(N'ASSERT FAIL: modules read the system view directly: ',@names); THROW 59001,@msg,1; END;
SET @n=(SELECT COUNT(*) FROM sync.CurrentFork WHERE ForkGuid IS NOT NULL);
EXEC test.AssertEq N'the view returns one fork',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.CurrentFork c JOIN sys.database_recovery_status s ON s.database_id=DB_ID() AND s.recovery_fork_guid=c.ForkGuid);
EXEC test.AssertEq N'on SQL Server the fork is the recovery fork',1,@n;
