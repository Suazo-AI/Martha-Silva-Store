-- savia:transactional
-- V063: D1 in docs/production-20261122/README.md (credit transfers over HTTP instead of SQL).
-- The five transfer writes already exist (V009, V010, V052) and each refuses the wrong node. The screens also need the
-- open work: credits.usp_ListTransfers returns the latest transfers of one branch (a store) or of every branch (the
-- hub, @BranchId NULL), with the status of credits.vw_TransferStatus. A node lists only what has synced to it.

CREATE OR ALTER PROCEDURE [credits].[usp_ListTransfers]
 @BranchId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON;
 SELECT TOP (100) s.TransferId,s.CreditId,cu.DisplayName AS CustomerName,s.FromBranchId,bf.Name AS FromBranchName,
        s.ToBranchId,bt.Name AS ToBranchName,s.AmountMinor,cr.CurrencyCode,s.[Status],r.Reason,r.CreatedAt
 FROM credits.vw_TransferStatus s
 JOIN credits.TransferRequests r ON r.Id=s.TransferId
 JOIN credits.Credits cr ON cr.Id=s.CreditId
 JOIN crm.Customers cu ON cu.Id=cr.CustomerId
 JOIN core.Branches bf ON bf.Id=s.FromBranchId
 JOIN core.Branches bt ON bt.Id=s.ToBranchId
 WHERE @BranchId IS NULL OR @BranchId IN (s.FromBranchId,s.ToBranchId)
 ORDER BY r.CreatedAt DESC,s.TransferId;
END;
GO
