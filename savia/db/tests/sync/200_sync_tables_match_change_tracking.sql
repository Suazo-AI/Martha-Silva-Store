-- TEST: sync.SyncTables lists exactly the Change Tracking tables, and fn_TableShape builds every column list.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @n bigint;
SET @n=(SELECT COUNT(*) FROM sys.change_tracking_tables ct
        WHERE NOT EXISTS(SELECT 1 FROM sync.SyncTables st
                         WHERE st.TableName=QUOTENAME(OBJECT_SCHEMA_NAME(ct.object_id))+N'.'+QUOTENAME(OBJECT_NAME(ct.object_id))));
EXEC test.AssertEq N'every tracked table is synced',0,@n;
SET @n=(SELECT COUNT(*) FROM sync.SyncTables st
        WHERE NOT EXISTS(SELECT 1 FROM sys.change_tracking_tables ct WHERE ct.object_id=OBJECT_ID(st.TableName)));
EXEC test.AssertEq N'every synced table is tracked',0,@n;
SET @n=(SELECT COUNT(*) FROM sync.fn_TableShape()
        WHERE SelectList IS NULL OR WithList IS NULL OR InsList IS NULL OR ValList IS NULL OR OnList IS NULL OR CtOnList IS NULL);
EXEC test.AssertEq N'every table has its column lists',0,@n;
SET @n=(SELECT COUNT(*) FROM sync.fn_TableShape()); EXEC test.AssertEq N'18 synced tables',18,@n;
PRINT 'PASS';
