/* SAVIA V003: conservation oracle. Read-only.
   audit.usp_CheckConservation returns ZERO ROWS when the books of this node are consistent.
   Each row is one violation: which check, which key, what was expected and what was found.
   It is the acceptance oracle of the tests and of the seeded simulator (ADR-001 D9).
   It checks one database. Equality between a branch and the cloud is a separate check. */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
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

 /* ---- credits: money issued = money still held somewhere + money spent */
 INSERT INTO @v
 SELECT 'credit.conservation',CONVERT(nvarchar(36),c.Id),c.OriginalMinor,a.Total+r.Total
 FROM credits.Credits c
 CROSS APPLY (SELECT COALESCE(SUM(AvailableMinor+HeldMinor),0) AS Total FROM credits.CreditAllocations WHERE CreditId=c.Id) a
 CROSS APPLY (SELECT COALESCE(SUM(AmountMinor),0) AS Total FROM credits.CreditRedemptions WHERE CreditId=c.Id AND Status='posted') r
 WHERE c.OriginalMinor<>a.Total+r.Total;

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
