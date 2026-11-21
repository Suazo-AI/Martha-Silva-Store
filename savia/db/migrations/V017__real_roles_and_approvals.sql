-- Local Masaya roles. Existing legacy role codes remain for historical records.
IF NOT EXISTS(SELECT 1 FROM security.Roles WHERE Code='SELLER')
 INSERT security.Roles(Code,Description) VALUES('SELLER',N'Atención y comisiones, sin caja');
GO
CREATE OR ALTER PROCEDURE security.usp_ListApprovals @BranchId uniqueidentifier,@ActorId uniqueidentifier
AS
BEGIN
 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM security.Staff s JOIN security.StaffRoles sr ON sr.StaffId=s.Id
 JOIN security.Roles r ON r.Id=sr.RoleId JOIN security.StaffBranchAccess a ON a.StaffId=s.Id
 WHERE s.Id=@ActorId AND s.IsEnabled=1 AND r.Code='OWNER' AND r.IsActive=1 AND a.BranchId=@BranchId AND a.IsActive=1)
 THROW 52001,'Solo la dueña puede consultar aprobaciones.',1;
 SELECT (SELECT x.kind,x.id,x.actorId,st.DisplayName AS actorName,x.what,x.amountMinor,x.reason,x.time
 FROM (
 SELECT 'descuento' AS kind,s.Id AS id,s.DiscountApprovedBy AS actorId,CONCAT(N'Venta ',s.ReceiptSequence) AS what,
 s.DiscountMinor AS amountMinor,s.DiscountReason AS reason,s.CreatedAt AS time FROM sales.Sales s WHERE s.BranchId=@BranchId AND s.DiscountMinor>0
 UNION ALL SELECT CASE WHEN r.Kind='void' THEN 'anulacion' ELSE 'devolucion' END,r.Id,r.ApprovedBy,CONVERT(nvarchar(200),r.SaleId),r.CreditMinor,r.Reason,r.CreatedAt
 FROM sales.SaleReversals r WHERE r.BranchId=@BranchId AND r.Status='approved'
 UNION ALL SELECT 'excepcion',e.Id,e.CashierId,l.NameSnapshot,CONVERT(bigint,e.QuantityShort)*l.UnitPriceMinor,e.Note,e.CreatedAt
 FROM sales.StockExceptions e JOIN sales.SaleLines l ON l.Id=e.SaleLineId JOIN sales.Sales s ON s.Id=l.SaleId WHERE s.BranchId=@BranchId
 UNION ALL SELECT 'precio',p.Id,p.CreatedBy,i.VariantName,p.NewPriceMinor-p.OldPriceMinor,p.Reason,p.EffectiveAt
 FROM catalog.PriceHistory p JOIN catalog.Items i ON i.Id=p.ItemId
 ) x LEFT JOIN security.Staff st ON st.Id=x.actorId ORDER BY x.time DESC,x.id FOR JSON PATH,INCLUDE_NULL_VALUES) AS Json;
END;
GO
