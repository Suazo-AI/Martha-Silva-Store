-- TEST: usp_QueueReceiptLabels queues one label job per receipt line with the original supplier code, the barcode with its leading zeros and the store name; a retry queues nothing twice.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @loc uniqueidentifier=test.Id('locA'),@branch uniqueidentifier=test.Id('branchA'),
  @supplier uniqueidentifier=test.Id('supplier'),@actor uniqueidentifier=test.Id('cashierA'),
  @reviewer uniqueidentifier=test.Id('supervisorA'),@node uniqueidentifier=test.Id('nodeA'),
  @item uniqueidentifier=test.Id('item'),
  @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),@scan uniqueidentifier=NEWID(),
  @container2 uniqueidentifier=NEWID(),@session2 uniqueidentifier=NEWID(),@scan2 uniqueidentifier=NEWID(),
  @receipt uniqueidentifier,@receipt2 uniqueidentifier,@n bigint;
DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);

INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container,N'T-CONT-L100',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',2,NULL,@actor;
EXEC receiving.usp_ApproveScanSession @session,@reviewer;
EXEC receiving.usp_PostScanSession @ScanSessionId=@session,@ActorId=@actor,@OriginNodeId=@node,
  @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;

SET @n=(SELECT COUNT(*) FROM labels.PrintJobs WHERE ItemId=@item AND BranchId=@branch
        AND CopiesRequested=2 AND SkuSnapshot=N'PROV-0001' AND BarcodeSnapshot=N'0000123456789'
        AND StoreNameSnapshot=N'SAVIA Test');
EXEC test.AssertEq N'label job with the original code and the leading zeros',1,@n;
SET @n=(SELECT COUNT(*) FROM labels.PrintJobs q JOIN purchasing.GoodsReceiptLines l
        ON l.Id=q.ReceiptLineId WHERE l.GoodsReceiptId=@receipt);
EXEC test.AssertEq N'one label job for the receipt line',1,@n;
SET @n=(SELECT COUNT(*) FROM labels.PrintJobs WHERE Status='waiting_config');
EXEC test.AssertEq N'label jobs waiting for a printer and a template',1,@n;

-- Retry with the same ids: the client never got the reply.
EXEC labels.usp_QueueReceiptLabels @ReceiptId=@receipt,@ActorId=@actor;

SET @n=(SELECT COUNT(*) FROM labels.PrintJobs);
EXEC test.AssertEq N'label jobs after the retry',1,@n;

-- Another reception of the same variant gets its own label job.
INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
  VALUES(@container2,N'T-CONT-L100B',@supplier,@loc,'counting',@actor);
INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session2,@container2,'counting',@actor);
INSERT INTO @sink EXEC receiving.usp_RecordScan @scan2,@session2,N'0000123456789',3,NULL,@actor;
EXEC receiving.usp_ApproveScanSession @session2,@reviewer;
EXEC receiving.usp_PostScanSession @ScanSessionId=@session2,@ActorId=@actor,@OriginNodeId=@node,
  @CurrencyCode='NIO',@ReceiptId=@receipt2 OUTPUT;
SET @n=(SELECT COUNT(*) FROM labels.PrintJobs WHERE ItemId=@item);
EXEC test.AssertEq N'label jobs of the two receptions',2,@n;
SET @n=(SELECT COUNT(*) FROM labels.PrintJobs WHERE ItemId=@item AND CopiesRequested=3);
EXEC test.AssertEq N'label job of the second reception',1,@n;
PRINT 'PASS';
