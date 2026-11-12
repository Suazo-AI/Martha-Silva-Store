-- V010: Jason's decisions of 2026-11-12 on credit transfers.
-- 1. Dispatch wins: a cancel the cloud wrote before it saw branch A's offline dispatch is overridden. The money
--    continues to B. credits.vw_TransferStatus shows the result; usp_TransferReceive never looked at cancels.
-- 2. The customer may ask at either branch: staff of the origin or the destination request on their own node.
-- 3. credits.usp_FindCustomerCredits: find a customer's credit by name, phone, email or customer code.
-- Errors: 51733 search query shorter than 2 characters. A branch only finds what has already synced to it.

CREATE OR ALTER PROCEDURE [credits].[usp_TransferRequest]
 @TransferId uniqueidentifier,@CreditId uniqueidentifier,@FromBranchId uniqueidentifier,
 @ToBranchId uniqueidentifier,@AmountMinor bigint,@RequestedBy uniqueidentifier,
 @Reason nvarchar(400),@NodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @TransferId IS NULL OR @FromBranchId IS NULL OR @ToBranchId IS NULL OR @FromBranchId=@ToBranchId
    OR @AmountMinor IS NULL OR @AmountMinor<=0 OR LEN(LTRIM(RTRIM(COALESCE(@Reason,N''))))=0
   THROW 51720,'Solicitud de transferencia invalida.',1;
 DECLARE @ownTran bit=0;
 IF @@TRANCOUNT=0 BEGIN SET @ownTran=1; BEGIN TRANSACTION; END;
 BEGIN TRY
  IF EXISTS(SELECT 1 FROM credits.TransferRequests WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TransferId)
  BEGIN
    IF NOT EXISTS(SELECT 1 FROM credits.TransferRequests WHERE Id=@TransferId AND CreditId=@CreditId
        AND FromBranchId=@FromBranchId AND ToBranchId=@ToBranchId AND AmountMinor=@AmountMinor
        AND RequestedBy=@RequestedBy AND Reason=@Reason AND NodeId=@NodeId)
      THROW 51721,'TransferId repetido con distinto contenido.',1;
    IF @ownTran=1 COMMIT; RETURN;
  END;
  -- V010: the customer may ask at either branch. The request is written on that branch's node.
  DECLARE @nodeBranch uniqueidentifier=(SELECT BranchId FROM sync.Nodes WHERE Id=@NodeId AND Kind='branch'
                                        AND BranchId IN (@FromBranchId,@ToBranchId));
  IF @nodeBranch IS NULL
    THROW 51723,'La solicitud se registra en el nodo de la sucursal origen o destino.',1;
  IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a JOIN security.Staff s ON s.Id=a.StaffId
      WHERE a.StaffId=@RequestedBy AND a.BranchId=@nodeBranch AND a.IsActive=1 AND s.IsEnabled=1)
    THROW 51724,'Solicitante sin acceso a la sucursal del nodo.',1;
  IF NOT EXISTS(SELECT 1 FROM credits.Credits WHERE Id=@CreditId AND Status='active')
     OR NOT EXISTS(SELECT 1 FROM credits.CreditAllocations WHERE CreditId=@CreditId AND BranchId=@FromBranchId)
    THROW 51722,'Anticipo no activo o sin saldo en la sucursal origen.',1;
  INSERT INTO credits.TransferRequests(Id,CreditId,FromBranchId,ToBranchId,AmountMinor,RequestedBy,Reason,NodeId)
    VALUES(@TransferId,@CreditId,@FromBranchId,@ToBranchId,@AmountMinor,@RequestedBy,@Reason,@NodeId);
  IF @ownTran=1 COMMIT;
 END TRY
 BEGIN CATCH IF @ownTran=1 AND XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
END;
GO

CREATE OR ALTER VIEW [credits].[vw_TransferStatus]
AS
SELECT r.Id AS TransferId,r.CreditId,r.FromBranchId,r.ToBranchId,r.AmountMinor,
       CASE WHEN rc.TransferId IS NOT NULL THEN 'received'
            WHEN d.TransferId IS NOT NULL THEN 'in_transit'
            WHEN c.TransferId IS NOT NULL THEN 'cancelled'
            WHEN a.TransferId IS NOT NULL THEN 'approved'
            ELSE 'requested' END AS [Status],
       CAST(CASE WHEN c.TransferId IS NOT NULL AND d.TransferId IS NOT NULL THEN 1 ELSE 0 END AS bit) AS CancelOverridden
FROM credits.TransferRequests r
LEFT JOIN credits.TransferApprovals a ON a.TransferId=r.Id
LEFT JOIN credits.TransferDispatches d ON d.TransferId=r.Id
LEFT JOIN credits.TransferReceipts rc ON rc.TransferId=r.Id
LEFT JOIN credits.TransferCancellations c ON c.TransferId=r.Id;
GO

-- Staff search for a customer's credit. One row per branch balance of an active credit. Wildcards are literal.
CREATE OR ALTER PROCEDURE [credits].[usp_FindCustomerCredits]
 @Query nvarchar(100),@ActorId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @q nvarchar(100)=LTRIM(RTRIM(COALESCE(@Query,N'')));
 IF LEN(@q)<2 THROW 51733,'Escriba al menos 2 caracteres para buscar.',1;
 IF NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffBranchAccess a ON a.StaffId=s.Id
     WHERE s.Id=@ActorId AND s.IsEnabled=1 AND a.IsActive=1)
   THROW 51724,'Usuario sin acceso a ninguna sucursal.',1;
 DECLARE @like nvarchar(220)=N'%'+REPLACE(REPLACE(REPLACE(REPLACE(@q,N'!',N'!!'),N'%',N'!%'),N'_',N'!_'),N'[',N'![')+N'%';
 DECLARE @digits nvarchar(100)=N'';
 DECLARE @i int=1;
 WHILE @i<=LEN(@q) BEGIN IF SUBSTRING(@q,@i,1) LIKE N'[0-9]' SET @digits+=SUBSTRING(@q,@i,1); SET @i+=1; END;
 SELECT TOP (50) cu.Id AS CustomerId,cu.DisplayName,cu.Phone,cu.Email,cr.Id AS CreditId,cr.CurrencyCode,
        al.BranchId,b.Name AS BranchName,al.AvailableMinor
 FROM crm.Customers cu
 JOIN credits.Credits cr ON cr.CustomerId=cu.Id AND cr.Status='active'
 JOIN credits.CreditAllocations al ON al.CreditId=cr.Id AND al.Status='active' AND al.AvailableMinor>0
 JOIN core.Branches b ON b.Id=al.BranchId
 WHERE cu.IsActive=1
   AND (cu.DisplayName LIKE @like ESCAPE N'!' OR cu.Email LIKE @like ESCAPE N'!' OR cu.CustomerCode=@q
        OR (LEN(@digits)>=6 AND REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(COALESCE(cu.Phone,N''),N' ',N''),N'-',N''),N'+',N''),N'(',N''),N')',N'')
            LIKE N'%'+@digits+N'%'))
 ORDER BY cu.DisplayName,cr.CreatedAt,b.Name;
END;
GO
