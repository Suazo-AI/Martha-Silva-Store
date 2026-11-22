-- savia:transactional
-- V037: D-038 one writer for a credit's status (S3 and P9-SPEC question 6).
-- Before, credits.usp_RedeemCredit set Credits.Status='exhausted' on whichever branch spent the last money. The row
-- belongs to the issuing branch, so a redeeming branch wrote another node's row: the hub refused its push (51851)
-- or, on the issuer, a concurrent status change and the redeemer's write diverged.
-- Now the issuer alone writes Credits.Status (active, blocked, expired). The redeemer writes only its own movement.
-- credits.vw_CreditStatus derives 'exhausted' from the movements of every branch and the money still in transit.
-- Rows stored as 'exhausted' before this migration keep that status; no procedure writes it any more.

CREATE OR ALTER VIEW [credits].[vw_CreditStatus]
AS
SELECT c.Id AS CreditId,
  CONVERT(varchar(16),CASE
    WHEN c.Status<>'active' THEN c.Status
    -- Movements hold every branch's available and held money; dispatched money is out of both until received.
    WHEN m.TotalMinor=0 AND NOT EXISTS(SELECT 1 FROM credits.TransferDispatches d JOIN credits.TransferRequests q ON q.Id=d.TransferId
        WHERE q.CreditId=c.Id AND NOT EXISTS(SELECT 1 FROM credits.TransferReceipts x WHERE x.TransferId=d.TransferId))
      THEN 'exhausted'
    ELSE 'active' END) AS Status
FROM credits.Credits c
OUTER APPLY (SELECT SUM(mv.AvailableDeltaMinor+mv.HeldDeltaMinor) AS TotalMinor
             FROM credits.CreditMovements mv WHERE mv.CreditId=c.Id) m;
GO

CREATE OR ALTER PROCEDURE [credits].[usp_RedeemCredit]
 @RedemptionId uniqueidentifier,@CreditId uniqueidentifier,@BranchId uniqueidentifier,
 @SaleId uniqueidentifier,@AmountMinor bigint,@ActorId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @AmountMinor<=0 THROW 51604,'Importe de canje invalido.',1;
 DECLARE @ownTran bit=0;
 IF @@TRANCOUNT=0 BEGIN SET @ownTran=1; BEGIN TRANSACTION; END;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM credits.CreditRedemptions WHERE Id=@RedemptionId)
   BEGIN
     IF EXISTS(SELECT 1 FROM credits.CreditRedemptions WHERE Id=@RedemptionId AND
       (CreditId<>@CreditId OR SaleId<>@SaleId OR AmountMinor<>@AmountMinor))
       THROW 51605,'Canje duplicado con otro contenido.',1;
     IF @ownTran=1 COMMIT; RETURN;
   END;
   IF NOT EXISTS(SELECT 1 FROM sales.Sales s JOIN credits.Credits c ON c.Id=@CreditId
       WHERE s.Id=@SaleId AND s.BranchId=@BranchId AND s.CustomerId=c.CustomerId
         AND s.CurrencyCode=c.CurrencyCode AND c.Status='active')
     THROW 51606,'La venta no pertenece al cliente/moneda del anticipo.',1;
   UPDATE credits.CreditAllocations WITH(UPDLOCK,SERIALIZABLE)
      SET AvailableMinor=AvailableMinor-@AmountMinor,ModifiedBy=@ActorId,
          ModifiedAt=SYSUTCDATETIME()
      WHERE CreditId=@CreditId AND BranchId=@BranchId AND Status='active'
        AND AvailableMinor>=@AmountMinor;
   IF @@ROWCOUNT<>1 THROW 51607,'Saldo de anticipo insuficiente en esta sucursal.',1;
   INSERT INTO credits.CreditRedemptions(Id,CreditId,BranchId,SaleId,AmountMinor,ActorId,CreatedBy)
      VALUES(@RedemptionId,@CreditId,@BranchId,@SaleId,@AmountMinor,@ActorId,@ActorId);
   INSERT INTO credits.CreditMovements(Id,CreditId,BranchId,Kind,AvailableDeltaMinor,
     SourceType,SourceId,ActorId,CreatedBy)
      VALUES(NEWID(),@CreditId,@BranchId,'redeem',-@AmountMinor,'sale',@SaleId,@ActorId,@ActorId);
   IF @ownTran=1 COMMIT;
 END TRY
 BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
END;
GO
