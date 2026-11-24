-- savia:transactional
-- V062: D0 in docs/production-20261122/README.md (day zero without fixtures; D-039, D-042).
-- Branches, locations, cash registers and staff are not synced (V053): every database holds them with the same ids.
-- Savia.Migrator --provision-branch and --provision-staff run these procedures on the hub and on each store database,
-- with the same ids, so the operator never writes SQL. A retry is a no-op; a different definition of an id, code or
-- login is refused. The API host role cannot run them: staff and branches are an operator act, not an API write.
-- security.usp_ProvisionStaff sets a password hash only when one is given; a new hash ends the old sessions.
-- sourcing.usp_CreateSupplier is the supplier write behind POST /api/v1/suppliers (hub only; suppliers sync to stores).
-- New errors: 51866 branch definition conflict (branch.provision_mismatch), 51867 staff definition conflict
-- (staff.provision_mismatch), 51903 invalid supplier (supplier.invalid).

CREATE OR ALTER PROCEDURE [core].[usp_ProvisionBranch]
 @BranchId uniqueidentifier,@BranchCode varchar(20),@BranchName nvarchar(150),@StoreDisplayName nvarchar(150),
 @LocationId uniqueidentifier,@LocationCode varchar(30),@LocationName nvarchar(150),
 @RegisterId uniqueidentifier,@RegisterCode nvarchar(40),@RegisterName nvarchar(120)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @bcode varchar(20)=NULLIF(LTRIM(RTRIM(@BranchCode)),''),@bname nvarchar(150)=NULLIF(LTRIM(RTRIM(@BranchName)),N''),
   @store nvarchar(150)=NULLIF(LTRIM(RTRIM(@StoreDisplayName)),N''),@lcode varchar(30)=NULLIF(LTRIM(RTRIM(@LocationCode)),''),
   @lname nvarchar(150)=NULLIF(LTRIM(RTRIM(@LocationName)),N''),@rcode nvarchar(40)=NULLIF(LTRIM(RTRIM(@RegisterCode)),N''),
   @rname nvarchar(120)=NULLIF(LTRIM(RTRIM(@RegisterName)),N'');
 IF @BranchId IS NULL OR @LocationId IS NULL OR @RegisterId IS NULL OR @bcode IS NULL OR @bname IS NULL OR @store IS NULL
    OR @lcode IS NULL OR @lname IS NULL OR @rcode IS NULL OR @rname IS NULL
   THROW 51866,'Sucursal invalida: faltan ids, codigos o nombres.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   -- Codes are the operator's names; ids are what the other databases share. Both must agree everywhere.
   IF EXISTS(SELECT 1 FROM core.Branches WITH (UPDLOCK,HOLDLOCK) WHERE (Id=@BranchId OR Code=@bcode)
               AND NOT (Id=@BranchId AND Code=@bcode))
      OR EXISTS(SELECT 1 FROM core.Locations WITH (UPDLOCK,HOLDLOCK) WHERE (Id=@LocationId OR Code=@lcode)
               AND NOT (Id=@LocationId AND Code=@lcode AND BranchId=@BranchId AND Kind='store'))
      OR EXISTS(SELECT 1 FROM sales.CashRegisters WITH (UPDLOCK,HOLDLOCK)
               WHERE (Id=@RegisterId OR (BranchId=@BranchId AND Code=@rcode))
                 AND NOT (Id=@RegisterId AND Code=@rcode AND BranchId=@BranchId AND LocationId=@LocationId))
     THROW 51866,'El id o el codigo ya pertenecen a otra sucursal, ubicacion o caja.',1;
   INSERT core.Branches(Id,Code,Name,StoreDisplayName)
   SELECT @BranchId,@bcode,@bname,@store WHERE NOT EXISTS(SELECT 1 FROM core.Branches WHERE Id=@BranchId);
   INSERT core.Locations(Id,BranchId,Code,Name,Kind)
   SELECT @LocationId,@BranchId,@lcode,@lname,'store' WHERE NOT EXISTS(SELECT 1 FROM core.Locations WHERE Id=@LocationId);
   INSERT sales.CashRegisters(Id,BranchId,LocationId,Code,Name)
   SELECT @RegisterId,@BranchId,@LocationId,@rcode,@rname WHERE NOT EXISTS(SELECT 1 FROM sales.CashRegisters WHERE Id=@RegisterId);
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [security].[usp_ProvisionStaff]
 @StaffId uniqueidentifier,@LoginName nvarchar(64),@DisplayName nvarchar(120),@RoleCode varchar(30),
 @BranchId uniqueidentifier,@CanApprove bit,@PasswordHash nvarchar(512)
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
   -- Same effect as AuthStore.SetPasswordAsync: a new password ends every session of the old one.
   UPDATE security.Staff SET PasswordHash=@PasswordHash,SecurityVersion=NEWID(),FailedSignIns=0,LockedUntil=NULL,
     ModifiedAt=SYSUTCDATETIME()
   WHERE Id=@StaffId AND @PasswordHash IS NOT NULL;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [sourcing].[usp_CreateSupplier]
 @SupplierId uniqueidentifier,@DisplayName nvarchar(200),@ActorId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @name nvarchar(200)=NULLIF(LTRIM(RTRIM(@DisplayName)),N'');
 IF @SupplierId IS NULL OR @name IS NULL THROW 51903,'Proveedor invalido: falta el nombre.',1;
 INSERT sourcing.Suppliers(Id,DisplayName,CreatedBy)
 SELECT @SupplierId,@name,@ActorId WHERE NOT EXISTS(SELECT 1 FROM sourcing.Suppliers WITH (UPDLOCK,HOLDLOCK) WHERE Id=@SupplierId);
 -- A retry of the same request is a no-op; the same id for another supplier is a client error.
 IF @@ROWCOUNT=0 AND NOT EXISTS(SELECT 1 FROM sourcing.Suppliers WHERE Id=@SupplierId AND DisplayName=@name)
   THROW 52004,'El identificador ya pertenece a otro proveedor.',1;
END;
GO

DENY EXECUTE ON OBJECT::[core].[usp_ProvisionBranch] TO [savia_api_host];
DENY EXECUTE ON OBJECT::[security].[usp_ProvisionStaff] TO [savia_api_host];
GO
