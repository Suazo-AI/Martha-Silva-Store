-- V009: cross-branch credit transfer as immutable transition rows, one writer per row (ADR-001 D5, critique F2).
-- request (B node), approve (cloud), dispatch -amount at A (A node), receive +amount at B (B node),
-- cancel before dispatch (cloud). Each balance row is written only by its own branch.
-- Conservation per credit: Original = sum(available+held) + sum(posted redemptions) + sum(dispatched, not received).
-- The legacy procedures (V001) wrote one CreditTransfers row from four nodes and the cloud commit moved
-- A's and B's balances in one transaction. They are retired: each now throws 51719.
-- New errors 51719-51732 (51713-51718 are left to V008):
--   51719 retired procedure        51720 invalid request            51721 id reused with other content
--   51722 credit not active / no balance at origin                    51723 wrong node for this transition
--   51724 actor without access to the branch the transition writes    51725 unknown transfer
--   51726 transfer cancelled       51727 approver not allowed       51728 dispatch without approval
--   51729 origin balance too low   51730 receipt without dispatch   51731 cancel after dispatch
--   51732 destination balance row not active
-- Additive only: new tables, one filtered unique index, procedures. No DELETE/TRUNCATE.

IF EXISTS(SELECT 1 FROM credits.CreditTransfers WHERE Status IN ('origin_locked','in_transit'))
  THROW 51719,'V009: hay transferencias legadas bloqueadas o en transito; cerrarlas antes de migrar.',1;
GO

CREATE TABLE [credits].[TransferRequests] (
  [Id] uniqueidentifier NOT NULL,
  [CreditId] uniqueidentifier NOT NULL,
  [FromBranchId] uniqueidentifier NOT NULL,
  [ToBranchId] uniqueidentifier NOT NULL,
  [AmountMinor] bigint NOT NULL,
  [RequestedBy] uniqueidentifier NOT NULL,
  [Reason] nvarchar(400) NOT NULL,
  [NodeId] uniqueidentifier NOT NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_credits_TransferRequests_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_TransferRequests] PRIMARY KEY ([Id]),
  CONSTRAINT [FK_TransferRequest_Credit] FOREIGN KEY ([CreditId]) REFERENCES [credits].[Credits]([Id]),
  CONSTRAINT [FK_TransferRequest_From] FOREIGN KEY ([FromBranchId]) REFERENCES [core].[Branches]([Id]),
  CONSTRAINT [FK_TransferRequest_To] FOREIGN KEY ([ToBranchId]) REFERENCES [core].[Branches]([Id]),
  CONSTRAINT [FK_TransferRequest_Requester] FOREIGN KEY ([RequestedBy]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [FK_TransferRequest_Node] FOREIGN KEY ([NodeId]) REFERENCES [sync].[Nodes]([Id]),
  CONSTRAINT [CK_TransferRequest_Branches] CHECK ([FromBranchId]<>[ToBranchId]),
  CONSTRAINT [CK_TransferRequest_Amount] CHECK ([AmountMinor]>0)
);
GO
CREATE TABLE [credits].[TransferApprovals] (
  [TransferId] uniqueidentifier NOT NULL,
  [ApprovedBy] uniqueidentifier NOT NULL,
  [NodeId] uniqueidentifier NOT NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_credits_TransferApprovals_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_TransferApprovals] PRIMARY KEY ([TransferId]),
  CONSTRAINT [FK_TransferApproval_Request] FOREIGN KEY ([TransferId]) REFERENCES [credits].[TransferRequests]([Id]),
  CONSTRAINT [FK_TransferApproval_Approver] FOREIGN KEY ([ApprovedBy]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [FK_TransferApproval_Node] FOREIGN KEY ([NodeId]) REFERENCES [sync].[Nodes]([Id])
);
GO
-- The FK to the approval enforces "A dispatches only after it sees the approval", also for a sync applier.
CREATE TABLE [credits].[TransferDispatches] (
  [TransferId] uniqueidentifier NOT NULL,
  [ActorId] uniqueidentifier NOT NULL,
  [NodeId] uniqueidentifier NOT NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_credits_TransferDispatches_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_TransferDispatches] PRIMARY KEY ([TransferId]),
  CONSTRAINT [FK_TransferDispatch_Approval] FOREIGN KEY ([TransferId]) REFERENCES [credits].[TransferApprovals]([TransferId]),
  CONSTRAINT [FK_TransferDispatch_Actor] FOREIGN KEY ([ActorId]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [FK_TransferDispatch_Node] FOREIGN KEY ([NodeId]) REFERENCES [sync].[Nodes]([Id])
);
GO
CREATE TABLE [credits].[TransferReceipts] (
  [TransferId] uniqueidentifier NOT NULL,
  [ActorId] uniqueidentifier NOT NULL,
  [NodeId] uniqueidentifier NOT NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_credits_TransferReceipts_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_TransferReceipts] PRIMARY KEY ([TransferId]),
  CONSTRAINT [FK_TransferReceipt_Dispatch] FOREIGN KEY ([TransferId]) REFERENCES [credits].[TransferDispatches]([TransferId]),
  CONSTRAINT [FK_TransferReceipt_Actor] FOREIGN KEY ([ActorId]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [FK_TransferReceipt_Node] FOREIGN KEY ([NodeId]) REFERENCES [sync].[Nodes]([Id])
);
GO
CREATE TABLE [credits].[TransferCancellations] (
  [TransferId] uniqueidentifier NOT NULL,
  [CancelledBy] uniqueidentifier NOT NULL,
  [Reason] nvarchar(400) NOT NULL,
  [NodeId] uniqueidentifier NOT NULL,
  [CreatedAt] datetime2(3) NOT NULL CONSTRAINT [DF_credits_TransferCancellations_CreatedAt] DEFAULT (SYSUTCDATETIME()),
  [RowVersion] rowversion NOT NULL,
  CONSTRAINT [PK_TransferCancellations] PRIMARY KEY ([TransferId]),
  CONSTRAINT [FK_TransferCancellation_Request] FOREIGN KEY ([TransferId]) REFERENCES [credits].[TransferRequests]([Id]),
  CONSTRAINT [FK_TransferCancellation_Actor] FOREIGN KEY ([CancelledBy]) REFERENCES [security].[Staff]([Id]),
  CONSTRAINT [FK_TransferCancellation_Node] FOREIGN KEY ([NodeId]) REFERENCES [sync].[Nodes]([Id])
);
GO
-- One transfer_out and one transfer_in per transfer, ever (lost-ACK or duplicate delivery cannot double a leg).
CREATE UNIQUE INDEX [UX_CreditMovements_TransferLeg] ON [credits].[CreditMovements] ([SourceId],[Kind])
  WHERE [SourceType]='credit_transfer' AND [Kind] IN ('transfer_out','transfer_in');
GO

/* 1 Request. Written by the destination branch B. No balance effect. */
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
  IF NOT EXISTS(SELECT 1 FROM sync.Nodes WHERE Id=@NodeId AND Kind='branch' AND BranchId=@ToBranchId)
    THROW 51723,'La solicitud se registra en el nodo de la sucursal destino.',1;
  IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a JOIN security.Staff s ON s.Id=a.StaffId
      WHERE a.StaffId=@RequestedBy AND a.BranchId=@ToBranchId AND a.IsActive=1 AND s.IsEnabled=1)
    THROW 51724,'Solicitante sin acceso a la sucursal destino.',1;
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

/* 2 Approve. Written by the cloud. The approver holds CanApproveTransfers in the origin branch. */
CREATE OR ALTER PROCEDURE [credits].[usp_TransferApprove]
 @TransferId uniqueidentifier,@ApproverId uniqueidentifier,@NodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @ownTran bit=0;
 IF @@TRANCOUNT=0 BEGIN SET @ownTran=1; BEGIN TRANSACTION; END;
 BEGIN TRY
  DECLARE @from uniqueidentifier,@requester uniqueidentifier;
  SELECT @from=FromBranchId,@requester=RequestedBy
    FROM credits.TransferRequests WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TransferId;
  IF @from IS NULL THROW 51725,'Transferencia inexistente.',1;
  IF EXISTS(SELECT 1 FROM credits.TransferApprovals WHERE TransferId=@TransferId)
  BEGIN
    IF NOT EXISTS(SELECT 1 FROM credits.TransferApprovals WHERE TransferId=@TransferId
        AND ApprovedBy=@ApproverId AND NodeId=@NodeId)
      THROW 51721,'Transferencia ya aprobada con otro contenido.',1;
    IF @ownTran=1 COMMIT; RETURN;
  END;
  IF NOT EXISTS(SELECT 1 FROM sync.Nodes WHERE Id=@NodeId AND Kind='azure')
    THROW 51723,'La aprobacion se registra en la nube.',1;
  IF EXISTS(SELECT 1 FROM credits.TransferCancellations WHERE TransferId=@TransferId)
    THROW 51726,'Transferencia cancelada.',1;
  IF @ApproverId=@requester OR NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a
      JOIN security.Staff s ON s.Id=a.StaffId
      WHERE a.StaffId=@ApproverId AND a.BranchId=@from AND a.CanApproveTransfers=1 AND a.IsActive=1 AND s.IsEnabled=1)
    THROW 51727,'Aprobador sin permiso en la sucursal origen o igual al solicitante.',1;
  INSERT INTO credits.TransferApprovals(TransferId,ApprovedBy,NodeId) VALUES(@TransferId,@ApproverId,@NodeId);
  IF @ownTran=1 COMMIT;
 END TRY
 BEGIN CATCH IF @ownTran=1 AND XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* 3 Dispatch. Written by the origin branch A: -amount from A's own balance, in one transaction. */
CREATE OR ALTER PROCEDURE [credits].[usp_TransferDispatch]
 @TransferId uniqueidentifier,@ActorId uniqueidentifier,@NodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @ownTran bit=0;
 IF @@TRANCOUNT=0 BEGIN SET @ownTran=1; BEGIN TRANSACTION; END;
 BEGIN TRY
  DECLARE @credit uniqueidentifier,@from uniqueidentifier,@amt bigint;
  SELECT @credit=CreditId,@from=FromBranchId,@amt=AmountMinor
    FROM credits.TransferRequests WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TransferId;
  IF @from IS NULL THROW 51725,'Transferencia inexistente.',1;
  IF EXISTS(SELECT 1 FROM credits.TransferDispatches WHERE TransferId=@TransferId)
  BEGIN
    IF NOT EXISTS(SELECT 1 FROM credits.TransferDispatches WHERE TransferId=@TransferId
        AND ActorId=@ActorId AND NodeId=@NodeId)
      THROW 51721,'Transferencia ya despachada con otro contenido.',1;
    IF @ownTran=1 COMMIT; RETURN;
  END;
  IF NOT EXISTS(SELECT 1 FROM sync.Nodes WHERE Id=@NodeId AND Kind='branch' AND BranchId=@from)
    THROW 51723,'El despacho se registra en el nodo de la sucursal origen.',1;
  IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a JOIN security.Staff s ON s.Id=a.StaffId
      WHERE a.StaffId=@ActorId AND a.BranchId=@from AND a.IsActive=1 AND s.IsEnabled=1)
    THROW 51724,'Usuario sin acceso a la sucursal origen.',1;
  IF EXISTS(SELECT 1 FROM credits.TransferCancellations WHERE TransferId=@TransferId)
    THROW 51726,'Transferencia cancelada.',1;
  IF NOT EXISTS(SELECT 1 FROM credits.TransferApprovals WHERE TransferId=@TransferId)
    THROW 51728,'Transferencia sin aprobacion.',1;
  UPDATE credits.CreditAllocations WITH(UPDLOCK,SERIALIZABLE)
     SET AvailableMinor=AvailableMinor-@amt,ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId
   WHERE CreditId=@credit AND BranchId=@from AND AvailableMinor>=@amt AND Status='active';
  IF @@ROWCOUNT<>1 THROW 51729,'Saldo disponible insuficiente en la sucursal origen.',1;
  INSERT INTO credits.CreditMovements(Id,CreditId,BranchId,Kind,AvailableDeltaMinor,
     SourceType,SourceId,ActorId,CreatedBy)
   VALUES(NEWID(),@credit,@from,'transfer_out',-@amt,'credit_transfer',@TransferId,@ActorId,@ActorId);
  INSERT INTO credits.TransferDispatches(TransferId,ActorId,NodeId) VALUES(@TransferId,@ActorId,@NodeId);
  IF @ownTran=1 COMMIT;
 END TRY
 BEGIN CATCH IF @ownTran=1 AND XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* 4 Receive. Written by the destination branch B: +amount into B's own balance, only after the dispatch. */
CREATE OR ALTER PROCEDURE [credits].[usp_TransferReceive]
 @TransferId uniqueidentifier,@ActorId uniqueidentifier,@NodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 DECLARE @ownTran bit=0;
 IF @@TRANCOUNT=0 BEGIN SET @ownTran=1; BEGIN TRANSACTION; END;
 BEGIN TRY
  DECLARE @credit uniqueidentifier,@to uniqueidentifier,@amt bigint;
  SELECT @credit=CreditId,@to=ToBranchId,@amt=AmountMinor
    FROM credits.TransferRequests WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TransferId;
  IF @to IS NULL THROW 51725,'Transferencia inexistente.',1;
  IF EXISTS(SELECT 1 FROM credits.TransferReceipts WHERE TransferId=@TransferId)
  BEGIN
    IF NOT EXISTS(SELECT 1 FROM credits.TransferReceipts WHERE TransferId=@TransferId
        AND ActorId=@ActorId AND NodeId=@NodeId)
      THROW 51721,'Transferencia ya recibida con otro contenido.',1;
    IF @ownTran=1 COMMIT; RETURN;
  END;
  IF NOT EXISTS(SELECT 1 FROM sync.Nodes WHERE Id=@NodeId AND Kind='branch' AND BranchId=@to)
    THROW 51723,'La recepcion se registra en el nodo de la sucursal destino.',1;
  IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a JOIN security.Staff s ON s.Id=a.StaffId
      WHERE a.StaffId=@ActorId AND a.BranchId=@to AND a.IsActive=1 AND s.IsEnabled=1)
    THROW 51724,'Usuario sin acceso a la sucursal destino.',1;
  IF NOT EXISTS(SELECT 1 FROM credits.TransferDispatches WHERE TransferId=@TransferId)
    THROW 51730,'Transferencia sin despacho del origen.',1;
  IF EXISTS(SELECT 1 FROM credits.CreditAllocations WITH(UPDLOCK,HOLDLOCK) WHERE CreditId=@credit AND BranchId=@to)
  BEGIN
    UPDATE credits.CreditAllocations SET AvailableMinor=AvailableMinor+@amt,
       ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId
     WHERE CreditId=@credit AND BranchId=@to AND Status='active';
    IF @@ROWCOUNT<>1 THROW 51732,'Saldo del anticipo en destino no esta activo.',1;
  END
  ELSE
    INSERT INTO credits.CreditAllocations(CreditId,BranchId,AvailableMinor,HeldMinor,CreatedBy)
      VALUES(@credit,@to,@amt,0,@ActorId);
  INSERT INTO credits.CreditMovements(Id,CreditId,BranchId,Kind,AvailableDeltaMinor,
     SourceType,SourceId,ActorId,CreatedBy)
   VALUES(NEWID(),@credit,@to,'transfer_in',@amt,'credit_transfer',@TransferId,@ActorId,@ActorId);
  INSERT INTO credits.TransferReceipts(TransferId,ActorId,NodeId) VALUES(@TransferId,@ActorId,@NodeId);
  IF @ownTran=1 COMMIT;
 END TRY
 BEGIN CATCH IF @ownTran=1 AND XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* Cancel. Written by the cloud, only while no dispatch exists. No balance effect. */
CREATE OR ALTER PROCEDURE [credits].[usp_TransferCancel]
 @TransferId uniqueidentifier,@ActorId uniqueidentifier,@Reason nvarchar(400),@NodeId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF LEN(LTRIM(RTRIM(COALESCE(@Reason,N''))))=0 THROW 51720,'Motivo de cancelacion obligatorio.',1;
 DECLARE @ownTran bit=0;
 IF @@TRANCOUNT=0 BEGIN SET @ownTran=1; BEGIN TRANSACTION; END;
 BEGIN TRY
  DECLARE @from uniqueidentifier,@to uniqueidentifier;
  SELECT @from=FromBranchId,@to=ToBranchId
    FROM credits.TransferRequests WITH(UPDLOCK,HOLDLOCK) WHERE Id=@TransferId;
  IF @from IS NULL THROW 51725,'Transferencia inexistente.',1;
  IF EXISTS(SELECT 1 FROM credits.TransferCancellations WHERE TransferId=@TransferId)
  BEGIN
    IF NOT EXISTS(SELECT 1 FROM credits.TransferCancellations WHERE TransferId=@TransferId
        AND CancelledBy=@ActorId AND Reason=@Reason AND NodeId=@NodeId)
      THROW 51721,'Transferencia ya cancelada con otro contenido.',1;
    IF @ownTran=1 COMMIT; RETURN;
  END;
  IF NOT EXISTS(SELECT 1 FROM sync.Nodes WHERE Id=@NodeId AND Kind='azure')
    THROW 51723,'La cancelacion se registra en la nube.',1;
  IF NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess a JOIN security.Staff s ON s.Id=a.StaffId
      WHERE a.StaffId=@ActorId AND a.BranchId IN (@from,@to) AND a.CanApproveTransfers=1 AND a.IsActive=1 AND s.IsEnabled=1)
    THROW 51727,'Usuario sin permiso para cancelar la transferencia.',1;
  IF EXISTS(SELECT 1 FROM credits.TransferDispatches WHERE TransferId=@TransferId)
    THROW 51731,'Transferencia ya despachada; no se puede cancelar.',1;
  INSERT INTO credits.TransferCancellations(TransferId,CancelledBy,Reason,NodeId)
    VALUES(@TransferId,@ActorId,@Reason,@NodeId);
  IF @ownTran=1 COMMIT;
 END TRY
 BEGIN CATCH IF @ownTran=1 AND XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* Legacy procedures: same signatures, no effect. */
CREATE OR ALTER PROCEDURE [credits].[usp_RequestTransfer]
 @TransferId uniqueidentifier,@CreditId uniqueidentifier,@FromBranchId uniqueidentifier,
 @ToBranchId uniqueidentifier,@AmountMinor bigint,@RequestedBy uniqueidentifier,
 @Reason nvarchar(400),@OriginNodeId uniqueidentifier,@EventId uniqueidentifier
AS THROW 51719,'Retirado en V009: usar credits.usp_TransferRequest.',1;
GO
CREATE OR ALTER PROCEDURE [credits].[usp_ApproveTransfer]
 @TransferId uniqueidentifier,@ApproverId uniqueidentifier,
 @OriginNodeId uniqueidentifier,@EventId uniqueidentifier
AS THROW 51719,'Retirado en V009: usar credits.usp_TransferApprove.',1;
GO
CREATE OR ALTER PROCEDURE [credits].[usp_LockTransferAtOrigin]
 @TransferId uniqueidentifier,@OriginLockEventId uniqueidentifier,
 @OriginNodeId uniqueidentifier,@ActorId uniqueidentifier,@EmitEvent bit=1
AS THROW 51719,'Retirado en V009: usar credits.usp_TransferDispatch.',1;
GO
CREATE OR ALTER PROCEDURE [credits].[usp_CommitTransfer]
 @TransferId uniqueidentifier,@ActorId uniqueidentifier=NULL,
 @OriginNodeId uniqueidentifier=NULL,@EventId uniqueidentifier=NULL,@EmitEvent bit=1
AS THROW 51719,'Retirado en V009: movia saldos de dos sucursales en un nodo. Usar usp_TransferDispatch y usp_TransferReceive.',1;
GO
CREATE OR ALTER PROCEDURE [credits].[usp_AcceptTransfer]
 @TransferId uniqueidentifier,@ActorId uniqueidentifier,
 @OriginNodeId uniqueidentifier=NULL,@EventId uniqueidentifier=NULL,@EmitEvent bit=1
AS THROW 51719,'Retirado en V009: usar credits.usp_TransferReceive.',1;
GO
CREATE OR ALTER PROCEDURE [credits].[usp_CancelUnblockedTransfer]
 @TransferId uniqueidentifier,@ActorId uniqueidentifier
AS THROW 51719,'Retirado en V009: usar credits.usp_TransferCancel.',1;
GO

/* Conservation oracle: V003 body plus in-transit money and the transfer-leg check (V009). */
CREATE OR ALTER PROCEDURE [audit].[usp_CheckConservation] @Throw bit = 0
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @v TABLE(CheckName varchar(60) NOT NULL, KeyText nvarchar(200) NOT NULL, Expected bigint NULL, Actual bigint NULL);

 /* ---- stock: a balance is the sum of its movements, and stays inside its bounds */
 WITH m AS (SELECT ItemId,LocationId,Pool,SUM(CONVERT(bigint,OnHandDelta)) AS OnHand,
                   SUM(CONVERT(bigint,ReservedDelta)) AS Reserved
            FROM inventory.StockMovements GROUP BY ItemId,LocationId,Pool)
 INSERT INTO @v
 SELECT x.CheckName,CONCAT(COALESCE(b.ItemId,m.ItemId),N'/',COALESCE(b.LocationId,m.LocationId),N'/',COALESCE(b.Pool,m.Pool)),
        x.Expected,x.Actual
 FROM inventory.StockBalances b
 FULL JOIN m ON m.ItemId=b.ItemId AND m.LocationId=b.LocationId AND m.Pool=b.Pool
 CROSS APPLY (VALUES ('stock.onhand_vs_movements',COALESCE(m.OnHand,0),CONVERT(bigint,COALESCE(b.OnHand,0))),
                     ('stock.reserved_vs_movements',COALESCE(m.Reserved,0),CONVERT(bigint,COALESCE(b.Reserved,0)))) x(CheckName,Expected,Actual)
 WHERE x.Expected<>x.Actual;

 INSERT INTO @v
 SELECT 'stock.bounds',CONCAT(ItemId,N'/',LocationId,N'/',Pool),0,OnHand
 FROM inventory.StockBalances WHERE OnHand<0 OR Reserved<0 OR Reserved>OnHand;

 INSERT INTO @v
 SELECT 'stock.reserved_vs_reservations',CONCAT(b.ItemId,N'/',b.LocationId,N'/',b.Pool),COALESCE(r.Quantity,0),b.Reserved
 FROM inventory.StockBalances b
 OUTER APPLY (SELECT SUM(CONVERT(bigint,Quantity)) AS Quantity FROM inventory.StockReservations
              WHERE ItemId=b.ItemId AND LocationId=b.LocationId AND Pool=b.Pool AND Status='active') r
 WHERE COALESCE(r.Quantity,0)<>b.Reserved;

 /* ---- receiving: what was counted is what was received, moved once and labelled once */
 INSERT INTO @v
 SELECT 'receipt.line_vs_movement',CONVERT(nvarchar(36),l.Id),l.Quantity,COALESCE(m.Quantity,0)
 FROM purchasing.GoodsReceiptLines l
 OUTER APPLY (SELECT SUM(CONVERT(bigint,OnHandDelta)) AS Quantity,COUNT(*) AS Movements FROM inventory.StockMovements
              WHERE SourceType='goods_receipt_line' AND SourceId=l.Id AND Kind='receive') m
 WHERE COALESCE(m.Quantity,0)<>l.Quantity OR COALESCE(m.Movements,0)<>1;

 INSERT INTO @v
 SELECT 'receipt.vs_scans',CONVERT(nvarchar(36),r.Id),s.Quantity,l.Quantity
 FROM purchasing.GoodsReceipts r
 CROSS APPLY (SELECT COALESCE(SUM(CONVERT(bigint,Quantity)),0) AS Quantity FROM receiving.ScanEvents
              WHERE ScanSessionId=r.ScanSessionId AND MatchStatus='matched') s
 CROSS APPLY (SELECT COALESCE(SUM(CONVERT(bigint,Quantity)),0) AS Quantity FROM purchasing.GoodsReceiptLines
              WHERE GoodsReceiptId=r.Id) l
 WHERE r.ScanSessionId IS NOT NULL AND s.Quantity<>l.Quantity;

 INSERT INTO @v
 SELECT 'receipt.unmatched_scan_in_posted_session',CONVERT(nvarchar(36),e.Id),0,1
 FROM receiving.ScanEvents e JOIN receiving.ScanSessions s ON s.Id=e.ScanSessionId
 WHERE s.Status='posted' AND e.MatchStatus<>'matched';

 INSERT INTO @v
 SELECT 'receipt.label_job',CONVERT(nvarchar(36),l.Id),l.Quantity,COALESCE(j.Copies,0)
 FROM purchasing.GoodsReceiptLines l
 OUTER APPLY (SELECT SUM(CONVERT(bigint,CopiesRequested)) AS Copies,COUNT(*) AS Jobs FROM labels.PrintJobs
              WHERE ReceiptLineId=l.Id) j
 WHERE COALESCE(j.Copies,0)<>l.Quantity OR COALESCE(j.Jobs,0)<>1;

 /* ---- sales: lines, payments, stock and cash agree with the sale; one event per sale */
 INSERT INTO @v
 SELECT x.CheckName,CONVERT(nvarchar(36),s.Id),x.Expected,x.Actual
 FROM sales.Sales s
 OUTER APPLY (SELECT SUM(TotalMinor) AS Total,SUM(CONVERT(bigint,Quantity)) AS Quantity FROM sales.SaleLines WHERE SaleId=s.Id) l
 OUTER APPLY (SELECT SUM(AmountMinor) AS Total FROM sales.SaleTenders WHERE SaleId=s.Id) t
 OUTER APPLY (SELECT SUM(CONVERT(bigint,OnHandDelta)) AS Quantity FROM inventory.StockMovements
              WHERE SourceType='sale' AND SourceId=s.Id) m
 OUTER APPLY (SELECT COUNT(*) AS Events FROM sync.Outbox WHERE AggregateId=s.Id AND EventType='sales.sale_posted') o
 CROSS APPLY (VALUES ('sale.lines_vs_total',s.TotalMinor,COALESCE(l.Total,0)),
                     ('sale.tenders_vs_total',s.TotalMinor,COALESCE(t.Total,0)),
                     ('sale.stock_vs_lines',-COALESCE(l.Quantity,0),COALESCE(m.Quantity,0)),
                     ('sale.outbox_event',CONVERT(bigint,1),CONVERT(bigint,COALESCE(o.Events,0)))) x(CheckName,Expected,Actual)
 WHERE s.Channel='pos' AND x.Expected<>x.Actual;

 INSERT INTO @v
 SELECT 'sale.cash_tender_vs_cash_entry',CONVERT(nvarchar(36),t.Id),t.AmountMinor,COALESCE(e.Total,0)
 FROM sales.SaleTenders t
 OUTER APPLY (SELECT SUM(DeltaMinor) AS Total,COUNT(*) AS Entries FROM sales.CashEntries WHERE SaleTenderId=t.Id) e
 WHERE t.TenderKind='cash' AND (COALESCE(e.Total,0)<>t.AmountMinor OR COALESCE(e.Entries,0)<>1);

 /* ---- cash: a closure matches the entries and the count, and has one accounting document */
 INSERT INTO @v
 SELECT x.CheckName,CONVERT(nvarchar(36),c.Id),x.Expected,x.Actual
 FROM sales.CashClosures c
 OUTER APPLY (SELECT COALESCE(SUM(DeltaMinor),0) AS Total FROM sales.CashEntries WHERE TillId=c.TillId) e
 OUTER APPLY (SELECT COALESCE(SUM(CONVERT(bigint,DenominationMinor)*Quantity),0) AS Total FROM sales.CashCountLines WHERE CashCountId=c.CashCountId) n
 OUTER APPLY (SELECT COUNT(*) AS Documents FROM accounting.CloseDocuments WHERE ClosureId=c.Id) d
 OUTER APPLY (SELECT COUNT(*) AS Jobs FROM accounting.ExportJobs j JOIN accounting.CloseDocuments cd ON cd.Id=j.CloseDocumentId
              WHERE cd.ClosureId=c.Id AND j.RecipientCode=N'ACCOUNTANT') j
 CROSS APPLY (VALUES ('cash.closure_expected_vs_entries',e.Total,c.ExpectedMinor),
                     ('cash.closure_counted_vs_count',n.Total,c.CountedMinor),
                     ('cash.closure_difference',c.CountedMinor-c.ExpectedMinor,c.DifferenceMinor),
                     ('cash.closure_document',CONVERT(bigint,1),CONVERT(bigint,d.Documents)),
                     ('cash.closure_export_job',CONVERT(bigint,1),CONVERT(bigint,j.Jobs))) x(CheckName,Expected,Actual)
 WHERE x.Expected<>x.Actual;

 INSERT INTO @v
 SELECT 'cash.till_status_vs_closure',CONVERT(nvarchar(36),t.Id),CASE WHEN t.Status='closed' THEN 1 ELSE 0 END,c.Closures
 FROM sales.CashTills t
 CROSS APPLY (SELECT COUNT(*) AS Closures FROM sales.CashClosures WHERE TillId=t.Id) c
 WHERE c.Closures<>CASE WHEN t.Status='closed' THEN 1 ELSE 0 END;

 /* ---- credits: money issued = money still held somewhere + money spent + money in transit (V009) */
 INSERT INTO @v
 SELECT 'credit.conservation',CONVERT(nvarchar(36),c.Id),c.OriginalMinor,a.Total+r.Total+t.Total
 FROM credits.Credits c
 CROSS APPLY (SELECT COALESCE(SUM(AvailableMinor+HeldMinor),0) AS Total FROM credits.CreditAllocations WHERE CreditId=c.Id) a
 CROSS APPLY (SELECT COALESCE(SUM(AmountMinor),0) AS Total FROM credits.CreditRedemptions WHERE CreditId=c.Id AND Status='posted') r
 CROSS APPLY (SELECT COALESCE(SUM(q.AmountMinor),0) AS Total FROM credits.TransferDispatches d
              JOIN credits.TransferRequests q ON q.Id=d.TransferId
              WHERE q.CreditId=c.Id AND NOT EXISTS(SELECT 1 FROM credits.TransferReceipts x WHERE x.TransferId=d.TransferId)) t
 WHERE c.OriginalMinor<>a.Total+r.Total+t.Total;

 /* ---- credits (V009): each dispatch has exactly one -amount leg at the origin, each receipt one +amount leg at the destination */
 INSERT INTO @v
 SELECT 'credit.transfer_leg',CONCAT(q.Id,N'/',x.Kind),x.Expected,x.Legs
 FROM credits.TransferRequests q
 CROSS APPLY (SELECT 'transfer_out' AS Kind,
                (SELECT COUNT(*) FROM credits.CreditMovements m WHERE m.SourceType='credit_transfer' AND m.SourceId=q.Id
                   AND m.Kind='transfer_out' AND m.BranchId=q.FromBranchId AND m.AvailableDeltaMinor=-q.AmountMinor) AS Legs,
                CASE WHEN EXISTS(SELECT 1 FROM credits.TransferDispatches WHERE TransferId=q.Id) THEN 1 ELSE 0 END AS Expected
              UNION ALL
              SELECT 'transfer_in',
                (SELECT COUNT(*) FROM credits.CreditMovements m WHERE m.SourceType='credit_transfer' AND m.SourceId=q.Id
                   AND m.Kind='transfer_in' AND m.BranchId=q.ToBranchId AND m.AvailableDeltaMinor=q.AmountMinor),
                CASE WHEN EXISTS(SELECT 1 FROM credits.TransferReceipts WHERE TransferId=q.Id) THEN 1 ELSE 0 END) x
 WHERE x.Legs<>x.Expected;

 INSERT INTO @v
 SELECT 'credit.bounds',CONCAT(CreditId,N'/',BranchId),0,CASE WHEN AvailableMinor<0 THEN AvailableMinor ELSE HeldMinor END
 FROM credits.CreditAllocations WHERE AvailableMinor<0 OR HeldMinor<0;

 WITH m AS (SELECT CreditId,BranchId,SUM(AvailableDeltaMinor) AS Available,SUM(HeldDeltaMinor) AS Held
            FROM credits.CreditMovements GROUP BY CreditId,BranchId)
 INSERT INTO @v
 SELECT x.CheckName,CONCAT(COALESCE(a.CreditId,m.CreditId),N'/',COALESCE(a.BranchId,m.BranchId)),x.Expected,x.Actual
 FROM credits.CreditAllocations a
 FULL JOIN m ON m.CreditId=a.CreditId AND m.BranchId=a.BranchId
 CROSS APPLY (VALUES ('credit.available_vs_movements',COALESCE(m.Available,0),COALESCE(a.AvailableMinor,0)),
                     ('credit.held_vs_movements',COALESCE(m.Held,0),COALESCE(a.HeldMinor,0))) x(CheckName,Expected,Actual)
 WHERE x.Expected<>x.Actual;

 SELECT CheckName,KeyText,Expected,Actual FROM @v ORDER BY CheckName,KeyText;
 IF @Throw=1 AND EXISTS(SELECT 1 FROM @v)
 BEGIN
   DECLARE @msg nvarchar(900)=(SELECT TOP(1) CONCAT(N'CONSERVATION FAIL: ',CheckName,N' key=',KeyText,
       N' expected=',Expected,N' actual=',Actual,N' (',(SELECT COUNT(*) FROM @v),N' violations)')
     FROM @v ORDER BY CheckName,KeyText);
   THROW 59100,@msg,1;
 END;
END;
GO

/* Redeem: V001 body; the credit is exhausted only when no money is in transit either (V009). */
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
   -- V009: money dispatched to another branch and not yet received is still the customer's.
   IF NOT EXISTS(SELECT 1 FROM credits.CreditAllocations WHERE CreditId=@CreditId AND
       (AvailableMinor<>0 OR HeldMinor<>0))
      AND NOT EXISTS(SELECT 1 FROM credits.TransferDispatches d JOIN credits.TransferRequests q ON q.Id=d.TransferId
       WHERE q.CreditId=@CreditId AND NOT EXISTS(SELECT 1 FROM credits.TransferReceipts x WHERE x.TransferId=d.TransferId))
      UPDATE credits.Credits SET Status='exhausted',ModifiedAt=SYSUTCDATETIME(),ModifiedBy=@ActorId
       WHERE Id=@CreditId;
   IF @ownTran=1 COMMIT;
 END TRY
 BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK; THROW; END CATCH;
END;
GO
