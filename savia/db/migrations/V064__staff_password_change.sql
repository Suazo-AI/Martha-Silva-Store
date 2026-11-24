-- savia:transactional
-- V064: DAY-ZERO.md open gap 2. Staff change their own password; a printed one-time password must be replaced.
-- security.Staff.MustChangePassword marks a password the operator saw: Savia.Migrator --set-password without
-- SAVIA_STAFF_PASSWORD sets it. While it is set, the API answers 403 auth.password_change_required on every staff
-- route except the password change, logout and GET /me (ActorFilter).
-- security.usp_ChangeOwnPassword writes the new hash on this database only (staff are not synced, V053), clears the
-- mark, keeps the caller's session and revokes every other session of that staff member. The C# caller has already
-- checked the current password with the PBKDF2 hasher; SQL never sees a password.
-- security.usp_ProvisionStaff is redefined with an optional @MustChangePassword; its V062 DENY to savia_api_host stays.
-- New error: 51868 the caller's session is no longer live (auth.required).
-- Runs twice without error (REHEARSAL.md, schema_skew re-applies the newest migration): the column is added only once.

IF COL_LENGTH(N'security.Staff', N'MustChangePassword') IS NULL
  ALTER TABLE [security].[Staff] ADD [MustChangePassword] bit NOT NULL
    CONSTRAINT [DF_Staff_MustChangePassword] DEFAULT (0);
GO

CREATE OR ALTER PROCEDURE [security].[usp_ProvisionStaff]
 @StaffId uniqueidentifier,@LoginName nvarchar(64),@DisplayName nvarchar(120),@RoleCode varchar(30),
 @BranchId uniqueidentifier,@CanApprove bit,@PasswordHash nvarchar(512),@MustChangePassword bit=0
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @login nvarchar(64)=NULLIF(LTRIM(RTRIM(@LoginName)),N''),@name nvarchar(120)=NULLIF(LTRIM(RTRIM(@DisplayName)),N''),
   @role uniqueidentifier=(SELECT Id FROM security.Roles WHERE Code=@RoleCode AND IsActive=1);
 IF @StaffId IS NULL OR @login IS NULL OR @name IS NULL OR @role IS NULL OR @CanApprove IS NULL
    OR (@BranchId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM core.Branches WHERE Id=@BranchId))
   THROW 51867,'Personal invalido: falta id, usuario o nombre, o el rol o la sucursal no existen.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM security.Staff WITH (UPDLOCK,HOLDLOCK) WHERE (Id=@StaffId OR NormalizedLoginName=UPPER(@login))
               AND NOT (Id=@StaffId AND NormalizedLoginName=UPPER(@login)))
      OR EXISTS(SELECT 1 FROM security.StaffBranchAccess WITH (UPDLOCK,HOLDLOCK) WHERE StaffId=@StaffId AND BranchId=@BranchId
               AND (CanApproveTransfers<>@CanApprove OR CanApproveReturns<>@CanApprove))
     THROW 51867,'El usuario pertenece a otra persona o su acceso a la sucursal ya es distinto.',1;
   INSERT security.Staff(Id,LoginName,NormalizedLoginName,DisplayName)
   SELECT @StaffId,@login,UPPER(@login),@name WHERE NOT EXISTS(SELECT 1 FROM security.Staff WHERE Id=@StaffId);
   INSERT security.StaffRoles(StaffId,RoleId)
   SELECT @StaffId,@role WHERE NOT EXISTS(SELECT 1 FROM security.StaffRoles WHERE StaffId=@StaffId AND RoleId=@role);
   INSERT security.StaffBranchAccess(StaffId,BranchId,CanApproveTransfers,CanApproveReturns)
   SELECT @StaffId,@BranchId,@CanApprove,@CanApprove
   WHERE @BranchId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess WHERE StaffId=@StaffId AND BranchId=@BranchId);
   -- A new password ends every session of the old one. A retry without a password keeps the hash and the mark.
   UPDATE security.Staff SET PasswordHash=@PasswordHash,SecurityVersion=NEWID(),FailedSignIns=0,LockedUntil=NULL,
     MustChangePassword=ISNULL(@MustChangePassword,0),ModifiedAt=SYSUTCDATETIME()
   WHERE Id=@StaffId AND @PasswordHash IS NOT NULL;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [security].[usp_ChangeOwnPassword]
 @StaffId uniqueidentifier,@TokenHash varbinary(32),@PasswordHash nvarchar(512)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @now datetime2(3)=SYSUTCDATETIME(),@version uniqueidentifier=NEWID();
 IF @StaffId IS NULL OR @TokenHash IS NULL OR NULLIF(LTRIM(RTRIM(@PasswordHash)),N'') IS NULL
   THROW 51868,'La sesion ya no es valida.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   -- The caller's session moves to the new security version, so it survives the change; every other one ends.
   UPDATE s SET SecurityVersion=@version,ModifiedAt=@now,ModifiedBy=@StaffId
   FROM security.Sessions s WITH (UPDLOCK,HOLDLOCK) JOIN security.Staff st WITH (UPDLOCK,HOLDLOCK) ON st.Id=s.StaffId
   WHERE s.TokenHash=@TokenHash AND s.StaffId=@StaffId AND s.RevokedAt IS NULL AND s.ExpiresAt>@now
     AND st.IsEnabled=1 AND st.SecurityVersion=s.SecurityVersion;
   IF @@ROWCOUNT<>1 THROW 51868,'La sesion ya no es valida.',1;
   UPDATE security.Staff SET PasswordHash=@PasswordHash,SecurityVersion=@version,MustChangePassword=0,FailedSignIns=0,
     LockedUntil=NULL,ModifiedAt=@now,ModifiedBy=@StaffId
   WHERE Id=@StaffId;
   UPDATE security.Sessions SET RevokedAt=@now,ModifiedAt=@now,ModifiedBy=@StaffId
   WHERE StaffId=@StaffId AND RevokedAt IS NULL AND (TokenHash IS NULL OR TokenHash<>@TokenHash);
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO
