-- TEST: V064 own password change. A one-time password from the migrator marks the staff row; a given one does not; a retry
-- without a password keeps the mark. security.usp_ChangeOwnPassword writes the new hash, clears the mark and the lockout,
-- keeps the caller's session live under the new security version and revokes every other session. A dead or foreign
-- session is refused with 51868 and changes nothing. The API host role can run the change but still not the provisioning.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @s uniqueidentifier=NEWID(),@g uniqueidentifier=NEWID(),@v uniqueidentifier,@n int,@err int,
  @mine varbinary(32)=HASHBYTES('SHA2_256','t-310-mine'),@other varbinary(32)=HASHBYTES('SHA2_256','t-310-other'),
  @dead varbinary(32)=HASHBYTES('SHA2_256','t-310-dead'),@future datetime2(3)=DATEADD(HOUR,1,SYSUTCDATETIME()),
  @old nvarchar(512)=N'pbkdf2-sha256$1$AA==$AA==',@new nvarchar(512)=N'pbkdf2-sha256$1$AQ==$AQ==';

EXEC security.usp_ProvisionStaff @StaffId=@s,@LoginName=N't_cajera_310',@DisplayName=N'Cajera 310',@RoleCode='CASHIER',
  @BranchId=NULL,@CanApprove=0,@PasswordHash=@old,@MustChangePassword=1;
SET @n=(SELECT CAST(MustChangePassword AS int) FROM security.Staff WHERE Id=@s);
EXEC test.AssertEq N'a one-time password marks the staff row',1,@n;
EXEC security.usp_ProvisionStaff @StaffId=@s,@LoginName=N't_cajera_310',@DisplayName=N'Cajera 310',@RoleCode='CASHIER',
  @BranchId=NULL,@CanApprove=0,@PasswordHash=NULL;
SET @n=(SELECT CAST(MustChangePassword AS int) FROM security.Staff WHERE Id=@s);
EXEC test.AssertEq N'a retry without a password keeps the mark',1,@n;
EXEC security.usp_ProvisionStaff @StaffId=@g,@LoginName=N't_gerente_310',@DisplayName=N'Gerente 310',@RoleCode='MANAGER',
  @BranchId=NULL,@CanApprove=0,@PasswordHash=@old;
SET @n=(SELECT CAST(MustChangePassword AS int) FROM security.Staff WHERE Id=@g);
EXEC test.AssertEq N'a given password (old five-argument call) leaves no mark',0,@n;

-- Two live sessions and one expired-by-version session of the marked cashier, one session of the manager.
SET @v=(SELECT SecurityVersion FROM security.Staff WHERE Id=@s);
INSERT security.Sessions(Id,StaffId,SecurityVersion,ExpiresAt,TokenHash,CreatedBy) VALUES
  (NEWID(),@s,@v,@future,@mine,@s),(NEWID(),@s,@v,@future,@other,@s),(NEWID(),@s,NEWID(),@future,@dead,@s);
INSERT security.Sessions(Id,StaffId,SecurityVersion,ExpiresAt,TokenHash,CreatedBy)
SELECT NEWID(),@g,SecurityVersion,@future,HASHBYTES('SHA2_256','t-310-manager'),@g FROM security.Staff WHERE Id=@g;
UPDATE security.Staff SET FailedSignIns=3,LockedUntil=NULL WHERE Id=@s;

SET @err=0;
BEGIN TRY EXEC security.usp_ChangeOwnPassword @StaffId=@s,@TokenHash=@dead,@PasswordHash=@new; END TRY
BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'a session of an old security version cannot change the password',51868,@err;
SET @err=0;
BEGIN TRY EXEC security.usp_ChangeOwnPassword @StaffId=@g,@TokenHash=@mine,@PasswordHash=@new; END TRY
BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'a session of another staff member cannot change this password',51868,@err;
SET @n=(SELECT COUNT(*) FROM security.Staff WHERE Id IN (@s,@g) AND PasswordHash=@old);
EXEC test.AssertEq N'a refused change writes nothing',2,@n;

EXEC security.usp_ChangeOwnPassword @StaffId=@s,@TokenHash=@mine,@PasswordHash=@new;
SET @n=(SELECT COUNT(*) FROM security.Staff WHERE Id=@s AND PasswordHash=@new AND MustChangePassword=0 AND FailedSignIns=0
          AND LockedUntil IS NULL AND SecurityVersion<>@v);
EXEC test.AssertEq N'the change writes the hash, clears the mark and the failures, and issues a new security version',1,@n;
SET @n=(SELECT COUNT(*) FROM security.Sessions se JOIN security.Staff st ON st.Id=se.StaffId
        WHERE se.TokenHash=@mine AND se.RevokedAt IS NULL AND se.SecurityVersion=st.SecurityVersion);
EXEC test.AssertEq N'the caller''s session stays live',1,@n;
SET @n=(SELECT COUNT(*) FROM security.Sessions WHERE StaffId=@s AND TokenHash IN (@other,@dead) AND RevokedAt IS NOT NULL);
EXEC test.AssertEq N'every other session of that staff member is revoked',2,@n;
SET @n=(SELECT COUNT(*) FROM security.Sessions WHERE StaffId=@g AND RevokedAt IS NULL);
EXEC test.AssertEq N'another staff member''s session is untouched',1,@n;

SET @n=(SELECT COUNT(*) FROM sys.database_permissions p JOIN sys.database_principals d ON d.principal_id=p.grantee_principal_id
        WHERE d.name='savia_api_host' AND p.state='D' AND p.permission_name='EXECUTE'
          AND p.major_id=OBJECT_ID('security.usp_ProvisionStaff'));
EXEC test.AssertEq N'the redefined provisioning procedure is still denied to the API host role',1,@n;
SET @n=(SELECT COUNT(*) FROM sys.database_permissions p JOIN sys.database_principals d ON d.principal_id=p.grantee_principal_id
        WHERE d.name='savia_api_host' AND p.major_id=OBJECT_ID('security.usp_ChangeOwnPassword'));
EXEC test.AssertEq N'the change procedure needs no grant of its own (database-wide EXECUTE)',0,@n;
PRINT 'PASS';
