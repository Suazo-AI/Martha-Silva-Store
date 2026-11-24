-- TEST: savia_api_host (V035) holds exactly the API host permissions, including every synced table, and nothing more
-- than the V062 denies on the operator-only procedures.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @role int=DATABASE_PRINCIPAL_ID(N'savia_api_host'),@n bigint;
IF @role IS NULL THROW 59002,'ASSERT FAIL: role savia_api_host is missing',1;
DECLARE @g TABLE(class tinyint,major_id int,permission_name nvarchar(128),state char(1));
INSERT @g SELECT class,major_id,permission_name,state FROM sys.database_permissions WHERE grantee_principal_id=@role;

-- Database-wide: SELECT and EXECUTE, nothing else; no schema-wide grant.
SET @n=(SELECT COUNT(*) FROM @g WHERE class=0 AND state='G' AND permission_name IN ('SELECT','EXECUTE'));
EXEC test.AssertEq N'database-wide SELECT and EXECUTE',2,@n;
SET @n=(SELECT COUNT(*) FROM @g WHERE class IN (0,3)); EXEC test.AssertEq N'no other database or schema grant',2,@n;

-- Every synced table: INSERT, UPDATE and VIEW CHANGE TRACKING, needed by the dynamic SQL of the sync procedures.
-- A table added to sync.SyncTables without this grant fails here instead of failing the first hub sync.
SET @n=(SELECT COUNT(*) FROM sync.SyncTables st
        WHERE (SELECT COUNT(*) FROM @g p WHERE p.class=1 AND p.major_id=OBJECT_ID(st.TableName) AND p.state='G'
                 AND p.permission_name IN ('INSERT','UPDATE','VIEW CHANGE TRACKING'))<>3);
EXEC test.AssertEq N'synced tables missing a sync grant',0,@n;

-- Sign-in tables: Sessions INSERT and UPDATE, Staff UPDATE.
SET @n=(SELECT COUNT(*) FROM @g WHERE class=1 AND major_id=OBJECT_ID(N'security.Sessions') AND permission_name IN ('INSERT','UPDATE'));
EXEC test.AssertEq N'security.Sessions INSERT and UPDATE',2,@n;
SET @n=(SELECT COUNT(*) FROM @g WHERE class=1 AND major_id=OBJECT_ID(N'security.Staff') AND permission_name='UPDATE');
EXEC test.AssertEq N'security.Staff UPDATE',1,@n;
SET @n=(SELECT COUNT(*) FROM @g WHERE class=1 AND major_id=OBJECT_ID(N'security.Staff'));
EXEC test.AssertEq N'security.Staff: UPDATE only',1,@n;

-- Operator-only procedures (V062): EXECUTE is denied so the API host cannot create staff or branches.
DELETE @g WHERE class=1 AND state='D' AND permission_name='EXECUTE'
  AND major_id IN (OBJECT_ID(N'core.usp_ProvisionBranch'),OBJECT_ID(N'security.usp_ProvisionStaff'));

-- Nothing else: no other object, no DELETE, DDL, ownership or DENY, and no membership of another role.
SET @n=(SELECT COUNT(*) FROM @g p WHERE p.class=1
          AND NOT EXISTS(SELECT 1 FROM sync.SyncTables st WHERE OBJECT_ID(st.TableName)=p.major_id)
          AND p.major_id NOT IN (OBJECT_ID(N'security.Sessions'),OBJECT_ID(N'security.Staff')));
EXEC test.AssertEq N'object grants outside the synced and sign-in tables',0,@n;
SET @n=(SELECT COUNT(*) FROM @g WHERE class=1 AND major_id IN (OBJECT_ID(N'security.Sessions'),OBJECT_ID(N'security.Staff'))
        AND permission_name NOT IN ('INSERT','UPDATE'));
EXEC test.AssertEq N'sign-in tables: no extra grant',0,@n;
SET @n=(SELECT COUNT(*) FROM @g WHERE state<>'G' OR permission_name IN ('DELETE','ALTER','CONTROL','TAKE OWNERSHIP','IMPERSONATE','REFERENCES'));
EXEC test.AssertEq N'no DELETE, DDL, ownership or DENY',0,@n;
SET @n=(SELECT COUNT(*) FROM sys.database_role_members WHERE member_principal_id=@role);
EXEC test.AssertEq N'the role is not inside another role',0,@n;
PRINT 'PASS';
