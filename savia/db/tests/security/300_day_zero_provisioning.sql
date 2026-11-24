-- TEST: D0 day-zero provisioning (V062). core.usp_ProvisionBranch writes a branch, its store location and a register with
-- fixed ids; security.usp_ProvisionStaff writes a staff row, one role, an optional branch access and an optional password
-- hash. Both are idempotent and refuse an id, code or login that another definition holds. The API host role cannot run
-- them. sourcing.usp_CreateSupplier is the hub owner's supplier write: a retry is a no-op, a reused id is refused.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @b uniqueidentifier=NEWID(),@l uniqueidentifier=NEWID(),@r uniqueidentifier=NEWID(),@r2 uniqueidentifier=NEWID(),
  @s uniqueidentifier=NEWID(),@o uniqueidentifier=NEWID(),@sup uniqueidentifier=NEWID(),@locA uniqueidentifier=test.Id('locA'),@x uniqueidentifier=NEWID(),@y uniqueidentifier=NEWID(),@z uniqueidentifier=NEWID(),@n int,@err int,@v1 uniqueidentifier,@v2 uniqueidentifier;

EXEC core.usp_ProvisionBranch @BranchId=@b,@BranchCode='T_DZ',@BranchName=N'Sucursal día cero',@StoreDisplayName=N'SAVIA',
  @LocationId=@l,@LocationCode='T_DZ_TIENDA',@LocationName=N'Tienda',@RegisterId=@r,@RegisterCode=N'CAJA1',@RegisterName=N'Caja 1';
EXEC core.usp_ProvisionBranch @BranchId=@b,@BranchCode='T_DZ',@BranchName=N'Sucursal día cero',@StoreDisplayName=N'SAVIA',
  @LocationId=@l,@LocationCode='T_DZ_TIENDA',@LocationName=N'Tienda',@RegisterId=@r,@RegisterCode=N'CAJA1',@RegisterName=N'Caja 1';
SET @n=(SELECT COUNT(*) FROM core.Branches b JOIN core.Locations l ON l.BranchId=b.Id AND l.Kind='store'
        JOIN sales.CashRegisters c ON c.LocationId=l.Id WHERE b.Id=@b AND l.Id=@l AND c.Id=@r);
EXEC test.AssertEq N'a branch, its store location and its register exist once after a retry',1,@n;
EXEC core.usp_ProvisionBranch @BranchId=@b,@BranchCode='T_DZ',@BranchName=N'Sucursal día cero',@StoreDisplayName=N'SAVIA',
  @LocationId=@l,@LocationCode='T_DZ_TIENDA',@LocationName=N'Tienda',@RegisterId=@r2,@RegisterCode=N'CAJA2',@RegisterName=N'Caja 2';
SET @n=(SELECT COUNT(*) FROM sales.CashRegisters WHERE BranchId=@b); EXEC test.AssertEq N'a second register joins the same branch',2,@n;
SET @err=0;
BEGIN TRY EXEC core.usp_ProvisionBranch @BranchId=@x,@BranchCode='T_DZ',@BranchName=N'Otra',@StoreDisplayName=N'SAVIA',
  @LocationId=@y,@LocationCode='T_DZ_OTRA',@LocationName=N'Tienda',@RegisterId=@z,@RegisterCode=N'CAJA1',@RegisterName=N'Caja 1';
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'a branch code held by another id is refused',51866,@err;
SET @err=0;
BEGIN TRY EXEC core.usp_ProvisionBranch @BranchId=@b,@BranchCode='T_DZ',@BranchName=N'Sucursal día cero',@StoreDisplayName=N'SAVIA',
  @LocationId=@locA,@LocationCode='T_LOC_A',@LocationName=N'Tienda A',@RegisterId=@z,@RegisterCode=N'CAJA9',@RegisterName=N'Caja 9';
END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'a location of another branch is refused',51866,@err;

EXEC security.usp_ProvisionStaff @StaffId=@o,@LoginName=N't_duena_dz',@DisplayName=N'Dueña',@RoleCode='OWNER',@BranchId=NULL,
  @CanApprove=0,@PasswordHash=N'pbkdf2-sha256$1$AA==$AA==';
SET @v1=(SELECT SecurityVersion FROM security.Staff WHERE Id=@o);
EXEC security.usp_ProvisionStaff @StaffId=@o,@LoginName=N't_duena_dz',@DisplayName=N'Dueña',@RoleCode='OWNER',@BranchId=NULL,
  @CanApprove=0,@PasswordHash=NULL;
SET @v2=(SELECT SecurityVersion FROM security.Staff WHERE Id=@o);
SET @n=(SELECT COUNT(*) FROM security.Staff s JOIN security.StaffRoles sr ON sr.StaffId=s.Id JOIN security.Roles ro ON ro.Id=sr.RoleId
        WHERE s.Id=@o AND ro.Code='OWNER' AND s.NormalizedLoginName=N'T_DUENA_DZ' AND s.PasswordHash IS NOT NULL);
EXEC test.AssertEq N'an owner exists once with a password hash',1,@n;
SET @n=IIF(@v1=@v2,1,0); EXEC test.AssertEq N'a retry without a password keeps the hash and the sessions',1,@n;
EXEC security.usp_ProvisionStaff @StaffId=@o,@LoginName=N't_duena_dz',@DisplayName=N'Dueña',@RoleCode='OWNER',@BranchId=NULL,
  @CanApprove=0,@PasswordHash=N'pbkdf2-sha256$1$AQ==$AQ==';
SET @n=IIF((SELECT SecurityVersion FROM security.Staff WHERE Id=@o)<>@v2,1,0);
EXEC test.AssertEq N'a new password ends the sessions of the old one',1,@n;

EXEC security.usp_ProvisionStaff @StaffId=@s,@LoginName=N't_gerente_dz',@DisplayName=N'Gerente',@RoleCode='MANAGER',@BranchId=@b,
  @CanApprove=1,@PasswordHash=NULL;
EXEC security.usp_ProvisionStaff @StaffId=@s,@LoginName=N't_gerente_dz',@DisplayName=N'Gerente',@RoleCode='MANAGER',@BranchId=@b,
  @CanApprove=1,@PasswordHash=NULL;
SET @n=(SELECT COUNT(*) FROM security.StaffBranchAccess WHERE StaffId=@s AND BranchId=@b AND CanApproveTransfers=1 AND CanApproveReturns=1 AND IsActive=1);
EXEC test.AssertEq N'a manager gets one approving access to the branch',1,@n;
SET @err=0;
BEGIN TRY EXEC security.usp_ProvisionStaff @StaffId=@x,@LoginName=N'T_Gerente_DZ',@DisplayName=N'Otro',@RoleCode='CASHIER',
  @BranchId=@b,@CanApprove=0,@PasswordHash=NULL; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'a login held by another id is refused, whatever its case',51867,@err;
SET @err=0;
BEGIN TRY EXEC security.usp_ProvisionStaff @StaffId=@s,@LoginName=N't_gerente_dz',@DisplayName=N'Gerente',@RoleCode='NOPE',
  @BranchId=@b,@CanApprove=1,@PasswordHash=NULL; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'an unknown role is refused',51867,@err;
SET @err=0;
BEGIN TRY EXEC security.usp_ProvisionStaff @StaffId=@s,@LoginName=N't_gerente_dz',@DisplayName=N'Gerente',@RoleCode='MANAGER',
  @BranchId=@b,@CanApprove=0,@PasswordHash=NULL; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'another approval right for an existing access is refused',51867,@err;

SET @n=(SELECT COUNT(*) FROM sys.database_permissions p JOIN sys.database_principals d ON d.principal_id=p.grantee_principal_id
        WHERE d.name='savia_api_host' AND p.state='D' AND p.permission_name='EXECUTE'
          AND p.major_id IN (OBJECT_ID('core.usp_ProvisionBranch'),OBJECT_ID('security.usp_ProvisionStaff')));
EXEC test.AssertEq N'the API host role cannot run the provisioning procedures',2,@n;

EXEC sourcing.usp_CreateSupplier @SupplierId=@sup,@DisplayName=N' Proveedor día cero ',@ActorId=@o;
EXEC sourcing.usp_CreateSupplier @SupplierId=@sup,@DisplayName=N'Proveedor día cero',@ActorId=@o;
SET @n=(SELECT COUNT(*) FROM sourcing.Suppliers WHERE Id=@sup AND DisplayName=N'Proveedor día cero' AND CreatedBy=@o);
EXEC test.AssertEq N'a supplier is created once, trimmed',1,@n;
SET @err=0;
BEGIN TRY EXEC sourcing.usp_CreateSupplier @SupplierId=@sup,@DisplayName=N'Otro proveedor',@ActorId=@o; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'a supplier id reused for another name is refused',52004,@err;
SET @err=0;
BEGIN TRY EXEC sourcing.usp_CreateSupplier @SupplierId=@y,@DisplayName=N'  ',@ActorId=@o; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'a supplier needs a name',51903,@err;
PRINT 'PASS';
