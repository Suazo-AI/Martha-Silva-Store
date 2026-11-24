-- savia:transactional
-- V052: the open points of S1 and S3 in docs/production-20261122/README.md.
-- 1. D-036: a restored branch also refuses returns, credit transfer dispatch, transfer receipt and web consignment
--    (51864, sync.recovery_pending). Each writes money or stock the hub may already hold for this branch.
--    The check is inserted as the first statement of each procedure's current body, as V023 edits a body:
--    the bodies stay exactly as their last migration left them.
-- 2. D-038: the issuer alone writes a credit's stored status. credits.usp_BlockCredit and credits.usp_ExpireCredit
--    are those writes; they run only on the issuing branch's node, for a supervisor of that branch.
-- New errors: 51631 not the issuing node; 51632 credit not due; 51633 actor may not change credits of this branch;
--             51634 the credit's status is final (expired or exhausted).

DECLARE @lock nvarchar(100)=N'SET XACT_ABORT ON;',@name sysname,@definition nvarchar(max);
DECLARE p CURSOR LOCAL FAST_FORWARD FOR
  SELECT n FROM (VALUES(N'sales.usp_PostCreditReturn'),(N'sales.usp_PostReturnOutcome'),(N'credits.usp_TransferDispatch'),
                       (N'credits.usp_TransferReceive'),(N'inventory.usp_ConsignToWeb')) v(n);
OPEN p;
FETCH NEXT FROM p INTO @name;
WHILE @@FETCH_STATUS=0
BEGIN
  SET @definition=OBJECT_DEFINITION(OBJECT_ID(@name));
  -- One anchor exactly, and the check not yet there: otherwise the body is not the one this migration was written for.
  IF (LEN(@definition)-LEN(REPLACE(@definition,@lock,N'')))/LEN(@lock)<>1 OR CHARINDEX(N'usp_AssertNotRecovering',@definition)>0
    THROW 52007,'Recovery lock: procedure body incompatible.',1;
  SET @definition=REPLACE(REPLACE(@definition,N'CREATE   PROCEDURE',N'CREATE OR ALTER PROCEDURE'),N'CREATE PROCEDURE',N'CREATE OR ALTER PROCEDURE');
  SET @definition=REPLACE(@definition,@lock,@lock+NCHAR(13)+NCHAR(10)+N' EXEC sync.usp_AssertNotRecovering;');
  EXEC sys.sp_executesql @definition;
  FETCH NEXT FROM p INTO @name;
END;
CLOSE p; DEALLOCATE p;
GO

-- Inside the caller's transaction: locks the credit row and checks that this node and actor may write its status.
CREATE OR ALTER PROCEDURE [credits].[usp_LockIssuedCredit]
 @CreditId uniqueidentifier,@ActorId uniqueidentifier,@Status varchar(16) OUTPUT,@ExpiresAt datetime2(3) OUTPUT
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT=0 THROW 51857,'credits.usp_LockIssuedCredit corre dentro de una transaccion.',1;
 DECLARE @branch uniqueidentifier;
 SELECT @branch=IssuingBranchId,@Status=Status,@ExpiresAt=ExpiresAt FROM credits.Credits WITH (UPDLOCK,HOLDLOCK) WHERE Id=@CreditId;
 IF @branch IS NULL THROW 51601,'Anticipo inexistente.',1;
 IF NOT EXISTS(SELECT 1 FROM sync.LocalNode l JOIN sync.Nodes n ON n.Id=l.NodeId WHERE n.Kind='branch' AND n.BranchId=@branch)
   THROW 51631,'Solo la sucursal que emitio el anticipo cambia su estado.',1;
 IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess WHERE StaffId=@ActorId AND BranchId=@branch AND CanApproveReturns=1)
   THROW 51633,'Solo un supervisor de la sucursal emisora cambia el estado del anticipo.',1;
END;
GO

CREATE OR ALTER PROCEDURE [credits].[usp_BlockCredit]
 @CreditId uniqueidentifier,@ActorId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 EXEC sync.usp_AssertNotRecovering;
 DECLARE @status varchar(16),@expiresAt datetime2(3);
 BEGIN TRANSACTION;
 BEGIN TRY
   EXEC credits.usp_LockIssuedCredit @CreditId,@ActorId,@status OUTPUT,@expiresAt OUTPUT;
   IF @status IN ('expired','exhausted') THROW 51634,'El anticipo ya esta vencido o agotado.',1;
   IF @status='active'
     UPDATE credits.Credits SET Status='blocked',ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME() WHERE Id=@CreditId;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE [credits].[usp_ExpireCredit]
 @CreditId uniqueidentifier,@ActorId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 EXEC sync.usp_AssertNotRecovering;
 DECLARE @status varchar(16),@expiresAt datetime2(3);
 BEGIN TRANSACTION;
 BEGIN TRY
   EXEC credits.usp_LockIssuedCredit @CreditId,@ActorId,@status OUTPUT,@expiresAt OUTPUT;
   IF @status='exhausted' THROW 51634,'El anticipo ya esta vencido o agotado.',1;
   IF @status<>'expired'
   BEGIN
     IF @expiresAt IS NULL OR @expiresAt>SYSUTCDATETIME() THROW 51632,'El anticipo aun no vence.',1;
     UPDATE credits.Credits SET Status='expired',ModifiedBy=@ActorId,ModifiedAt=SYSUTCDATETIME() WHERE Id=@CreditId;
   END;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO
