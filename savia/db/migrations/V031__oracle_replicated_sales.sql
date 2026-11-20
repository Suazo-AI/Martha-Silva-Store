-- savia:transactional
-- V031: the conservation oracle expects a local sale_posted event only for sales this node originated.
-- ADR-001 D5: the outbox is local and never synced, so a replicated sale has no event on the receiving node.
-- A database without sync.LocalNode, or a sale without OriginNodeId, keeps the previous rule (one event).
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
 SELECT 'receipt.vs_scans',CONVERT(nvarchar(36),r.Id),s.Quantity-COALESCE((SELECT SUM(CONVERT(bigint,q.Missing)) FROM receiving.vw_CurrentQuality q WHERE q.ScanSessionId=r.ScanSessionId),0),l.Quantity
 FROM purchasing.GoodsReceipts r
 CROSS APPLY (SELECT COALESCE(SUM(CONVERT(bigint,Quantity)),0) AS Quantity FROM receiving.ScanEvents
              WHERE ScanSessionId=r.ScanSessionId AND MatchStatus='matched') s
 CROSS APPLY (SELECT COALESCE(SUM(CONVERT(bigint,Quantity)),0) AS Quantity FROM purchasing.GoodsReceiptLines
              WHERE GoodsReceiptId=r.Id) l
 WHERE r.ScanSessionId IS NOT NULL AND s.Quantity-COALESCE((SELECT SUM(CONVERT(bigint,q.Missing)) FROM receiving.vw_CurrentQuality q WHERE q.ScanSessionId=r.ScanSessionId),0)<>l.Quantity;

 INSERT INTO @v
 SELECT 'receipt.unmatched_scan_in_posted_session',CONVERT(nvarchar(36),e.Id),0,1
 FROM receiving.ScanEvents e JOIN receiving.ScanSessions s ON s.Id=e.ScanSessionId
 WHERE s.Status='posted' AND e.MatchStatus IN ('unknown','ambiguous');

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
 CROSS APPLY (SELECT CONVERT(bigint,CASE WHEN s.OriginNodeId IS NOT NULL AND s.OriginNodeId<>ln.NodeId THEN 0 ELSE 1 END) AS Events
              FROM (SELECT (SELECT NodeId FROM sync.LocalNode) AS NodeId) ln) e
 CROSS APPLY (VALUES ('sale.lines_vs_total',s.TotalMinor,COALESCE(l.Total,0)),
                     ('sale.tenders_vs_total',s.TotalMinor,COALESCE(t.Total,0)),
                     ('sale.stock_vs_lines',-COALESCE(l.Quantity,0),COALESCE(m.Quantity,0)),
                     ('sale.outbox_event',e.Events,CONVERT(bigint,COALESCE(o.Events,0)))) x(CheckName,Expected,Actual)
 WHERE s.Channel='pos' AND x.Expected<>x.Actual;

 INSERT INTO @v
 SELECT 'sale.cash_tender_vs_cash_entry',CONVERT(nvarchar(36),t.Id),COALESCE(t.ForeignReceivedMinor,t.AmountMinor),COALESCE(e.Total,0)
 FROM sales.SaleTenders t JOIN sales.Sales s ON s.Id=t.SaleId
 OUTER APPLY(SELECT SUM(e.DeltaMinor) AS Total,COUNT(*) AS Entries FROM sales.CashEntries e
 WHERE e.SaleTenderId=t.Id AND e.Kind='sale' AND e.CurrencyCode=COALESCE(t.ForeignCurrencyCode,t.CurrencyCode)
 AND e.TillId=CASE WHEN t.ForeignCurrencyCode IS NULL THEN s.TillId ELSE (SELECT Id FROM sales.CashTills WHERE ParentTillId=s.TillId) END) e
 WHERE t.TenderKind='cash' AND (COALESCE(e.Total,0)<>COALESCE(t.ForeignReceivedMinor,t.AmountMinor) OR e.Entries<>1 OR (SELECT COUNT(*) FROM sales.CashEntries x WHERE x.SaleTenderId=t.Id AND x.Kind='sale')<>1);
 INSERT INTO @v
 SELECT 'sale.fx_change',CONVERT(nvarchar(36),t.Id),-t.ChangeMinor,COALESCE(e.Total,0)
 FROM sales.SaleTenders t JOIN sales.Sales s ON s.Id=t.SaleId
 OUTER APPLY(SELECT SUM(DeltaMinor) AS Total,COUNT(*) AS Entries FROM sales.CashEntries WHERE SaleTenderId=t.Id AND Kind='change' AND TillId=s.TillId AND CurrencyCode='NIO') e
 WHERE t.ForeignCurrencyCode IS NOT NULL AND (COALESCE(e.Total,0)<>-t.ChangeMinor OR e.Entries<>CASE WHEN t.ChangeMinor=0 THEN 0 ELSE 1 END
 OR (SELECT COUNT(*) FROM sales.CashEntries x WHERE x.SaleTenderId=t.Id AND x.Kind='change')<>CASE WHEN t.ChangeMinor=0 THEN 0 ELSE 1 END+CASE WHEN COALESCE(t.ForeignChangeMinor,0)=0 THEN 0 ELSE 1 END);
 INSERT INTO @v
 SELECT 'sale.fx_usd_change',CONVERT(nvarchar(36),t.Id),-COALESCE(t.ForeignChangeMinor,0),COALESCE(e.Total,0)
 FROM sales.SaleTenders t JOIN sales.Sales s ON s.Id=t.SaleId
 OUTER APPLY(SELECT SUM(e.DeltaMinor) AS Total,COUNT(*) AS Entries FROM sales.CashEntries e
 JOIN sales.CashTills c ON c.Id=e.TillId WHERE e.SaleTenderId=t.Id AND e.Kind='change'
 AND e.CurrencyCode='USD' AND c.ParentTillId=s.TillId) e
 WHERE t.ForeignCurrencyCode IS NOT NULL AND (COALESCE(e.Total,0)<>-COALESCE(t.ForeignChangeMinor,0)
 OR e.Entries<>CASE WHEN COALESCE(t.ForeignChangeMinor,0)=0 THEN 0 ELSE 1 END
 OR EXISTS(SELECT 1 FROM sales.CashEntries x WHERE x.SaleTenderId=t.Id AND x.Kind NOT IN ('sale','change')));
 INSERT INTO @v
 SELECT 'sale.fx_conversion',CONVERT(nvarchar(36),t.Id),t.ReceivedMinor,CONVERT(bigint,ROUND(t.ForeignReceivedMinor*r.Rate,0))
 FROM sales.SaleTenders t LEFT JOIN core.ExchangeRates r ON r.Id=t.ExchangeRateId
 WHERE t.ForeignCurrencyCode IS NOT NULL AND (r.Id IS NULL OR r.Rate<>t.ExchangeRate OR t.ReceivedMinor<>ROUND(t.ForeignReceivedMinor*t.ExchangeRate,0)
 OR t.ReceivedMinor-t.ChangeMinor-COALESCE(t.ForeignChangeNioMinor,0)-t.RoundingMinor<>t.AmountMinor
 OR (t.ForeignChangeMinor IS NULL AND (t.RoundingMinor NOT BETWEEN -99 AND 99 OR t.ChangeMinor%100<>0))
 OR (t.ForeignChangeMinor IS NOT NULL AND NOT (t.ForeignChangeMinor IS NOT NULL AND t.ForeignChangeMinor>=0 AND t.ForeignChangeMinor<t.ForeignReceivedMinor
 AND ((t.ChangeMinor%5=0 AND t.ChangeMinor NOT IN (5,15) AND t.RoundingMinor BETWEEN 0 AND 9
 AND (t.RoundingMinor<=4 OR t.ChangeMinor IN (0,10)))
 OR (t.ForeignChangeMinor=0 AND t.ChangeMinor=0 AND t.RoundingMinor BETWEEN -99 AND -1)))));
 INSERT INTO @v
 SELECT 'cash.drawer_pair',CONVERT(nvarchar(36),c.Id),0,1 FROM sales.CashTills c LEFT JOIN sales.CashTills p ON p.Id=c.ParentTillId
 WHERE c.ParentTillId IS NOT NULL AND (p.Id IS NULL OR p.ParentTillId IS NOT NULL OR p.CurrencyCode<>'NIO' OR c.CurrencyCode<>'USD'
 OR p.RegisterId<>c.RegisterId OR p.CashierId<>c.CashierId OR p.Status<>c.Status);

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


 /* ---- returns (V024): settlements equal the returned value; cash leaves the till once; exchanges pay their sale */
 INSERT INTO @v
 SELECT x.CheckName,CONVERT(nvarchar(36),r.Id),x.Expected,x.Actual
 FROM sales.SaleReversals r
 OUTER APPLY (SELECT COALESCE(SUM(AmountMinor),0) AS Total,COALESCE(SUM(CASE WHEN Kind='cash' THEN AmountMinor END),0) AS Cash FROM sales.ReturnSettlements WHERE ReversalId=r.Id) s
 OUTER APPLY (SELECT COALESCE(SUM(DeltaMinor),0) AS Total FROM sales.CashEntries WHERE ReversalId=r.Id AND Kind='refund') e
 CROSS APPLY (VALUES ('return.settlements_vs_value',r.CreditMinor,s.Total),('return.cash_refund_vs_till',-s.Cash,e.Total)) x(CheckName,Expected,Actual)
 WHERE r.SettlementKind IN ('cash','transfer','exchange') AND x.Expected<>x.Actual;

 INSERT INTO @v
 SELECT 'return.exchange_tender',CONVERT(nvarchar(36),s.Id),s.AmountMinor,COALESCE(t.Total,0)
 FROM sales.ReturnSettlements s
 OUTER APPLY (SELECT SUM(AmountMinor) AS Total FROM sales.SaleTenders WHERE SaleId=s.ExchangeSaleId AND TenderKind='other'
              AND Reference=CONCAT(N'CAMBIO ',CONVERT(nvarchar(36),s.ReversalId))) t
 WHERE s.Kind='exchange' AND COALESCE(t.Total,0)<>s.AmountMinor;
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
