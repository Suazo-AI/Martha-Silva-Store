/*
 SAVIA — Smoke test transaccional (NO persiste datos de prueba).
 Ejecutar en SSMS sobre una BD SAVIA recién instalada.
 No sustituye pruebas de concurrencia, dispositivos, red ni integración fiscal.
 Incluye simulacion en una sola BD de ACK de Azure; NO es sync real.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO
BEGIN TRANSACTION;
BEGIN TRY
  DECLARE @branchA uniqueidentifier=NEWID(),@branchB uniqueidentifier=NEWID(),
    @locA uniqueidentifier=NEWID(),@locB uniqueidentifier=NEWID(),
    @staffA uniqueidentifier=NEWID(),@manager uniqueidentifier=NEWID(),
    @supplier uniqueidentifier=NEWID(),@customer uniqueidentifier=NEWID(),
    @nodeA uniqueidentifier=NEWID(),@nodeB uniqueidentifier=NEWID(),@azure uniqueidentifier=NEWID(),
    @product uniqueidentifier=NEWID(),@item uniqueidentifier=NEWID(),
    @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),
    @scan1 uniqueidentifier=NEWID(),@scan2 uniqueidentifier=NEWID(),@scan3 uniqueidentifier=NEWID(),
    @receipt uniqueidentifier,@register uniqueidentifier=NEWID(),@till uniqueidentifier=NEWID(),
    @sale uniqueidentifier=NEWID(),@return uniqueidentifier=NEWID(),@credit uniqueidentifier=NEWID(),
    @count uniqueidentifier=NEWID(),@close uniqueidentifier=NEWID(),
    @transfer uniqueidentifier=NEWID(),@lockEvent uniqueidentifier=NEWID(),@order uniqueidentifier=NEWID();

  INSERT INTO core.Branches(Id,Code,Name,StoreDisplayName)
    VALUES(@branchA,'QA_A',N'Tienda QA A',N'SAVIA QA'),(@branchB,'QA_B',N'Tienda QA B',N'SAVIA QA');
  INSERT INTO core.Locations(Id,BranchId,Code,Name,Kind)
    VALUES(@locA,@branchA,'QA_LOC_A',N'Local QA A','store'),
          (@locB,@branchB,'QA_LOC_B',N'Local QA B','store');
  INSERT INTO security.Staff(Id,LoginName,NormalizedLoginName,DisplayName)
    VALUES(@staffA,N'qa_cashier',N'QA_CASHIER',N'Operador QA'),
          (@manager,N'qa_manager',N'QA_MANAGER',N'Gerente QA');
  INSERT INTO security.StaffBranchAccess(StaffId,BranchId,CanApproveTransfers,CanApproveReturns)
    VALUES(@staffA,@branchA,0,0),(@manager,@branchA,1,1),(@manager,@branchB,1,1);
  INSERT INTO sourcing.Suppliers(Id,DisplayName) VALUES(@supplier,N'Proveedor QA');
  INSERT INTO crm.Customers(Id,DisplayName) VALUES(@customer,N'Cliente QA');
  INSERT INTO sync.Nodes(Id,BranchId,NodeCode,Kind)
    VALUES(@azure,NULL,N'AZURE_QA','azure'),(@nodeA,@branchA,N'QA_NODE_A','branch'),
          (@nodeB,@branchB,N'QA_NODE_B','branch');

  DECLARE @productEvent uniqueidentifier=NEWID(),@itemEvent uniqueidentifier=NEWID(),@payment uniqueidentifier=NEWID();
  EXEC catalog.usp_RegisterProduct @ProductId=@product,@Name=N'Blusa Prueba',
    @ActorId=@staffA,@OriginNodeId=@nodeA,@EventId=@productEvent;
  EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'SKU-EXTERNO-0001',
    @VariantName=N'Blusa Negra M',@CurrencyCode='NIO',@UnitPriceMinor=120000,
    @UnitCostMinor=60000,@Barcode=N'0000123456789',
    @SupplierId=@supplier,@SupplierSku=N'SKU-EXTERNO-0001',@ActorId=@staffA,
    @ItemId=@item,@OriginNodeId=@nodeA,@EventId=@itemEvent;

  INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
    VALUES(@container,N'QA-CONTAINER-1',@supplier,@locA,'counting',@staffA);
  INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy)
    VALUES(@session,@container,'counting',@staffA);
  EXEC receiving.usp_RecordScan @scan1,@session,N'0000123456789',1,NULL,@staffA;
  EXEC receiving.usp_RecordScan @scan1,@session,N'0000123456789',1,NULL,@staffA; -- retry, no duplica
  EXEC receiving.usp_RecordScan @scan2,@session,N'0000123456789',1,NULL,@staffA;
  EXEC receiving.usp_RecordScan @scan3,@session,N'0000123456789',1,NULL,@staffA;
  IF (SELECT COUNT(*) FROM receiving.ScanEvents WHERE ScanSessionId=@session)<>3
    THROW 52001,'QA FAIL: deduplicacion ScanId.',1;
  EXEC receiving.usp_ApproveScanSession @session,@manager;
  EXEC receiving.usp_PostScanSession @ScanSessionId=@session,@ActorId=@staffA,
     @OriginNodeId=@nodeA,@CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;
  EXEC receiving.usp_PostScanSession @ScanSessionId=@session,@ActorId=@staffA,
     @OriginNodeId=@nodeA,@CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;
  IF (SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='store')<>3
     THROW 52002,'QA FAIL: stock duplicado en recepcion.',1;
  IF (SELECT CopiesRequested FROM labels.PrintJobs WHERE ReceiptLineId IN
      (SELECT Id FROM purchasing.GoodsReceiptLines WHERE GoodsReceiptId=@receipt))<>3
     THROW 52003,'QA FAIL: cola de etiquetas.',1;
  IF NOT EXISTS(SELECT 1 FROM labels.PrintJobs WHERE ItemId=@item AND SkuSnapshot=N'SKU-EXTERNO-0001'
       AND BarcodeSnapshot=N'0000123456789' AND StoreNameSnapshot=N'SAVIA QA')
     THROW 52004,'QA FAIL: etiqueta no conserva SKU/barcode original.',1;

  INSERT INTO sales.CashRegisters(Id,BranchId,LocationId,Code,Name)
     VALUES(@register,@branchA,@locA,N'CAJA1',N'Caja QA');
  EXEC sales.usp_OpenTill @TillId=@till,@RegisterId=@register,@CashierId=@staffA,
     @CurrencyCode='NIO',@OpeningMinor=100000,@OriginNodeId=@nodeA;
  DECLARE @lines sales.SaleLineRequest,@tenders sales.SaleTenderRequest;
  INSERT INTO @lines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor)
    VALUES(1,@item,1,120000,0);
  INSERT INTO @tenders(TenderNumber,TenderKind,AmountMinor,ReceivedMinor,ChangeMinor)
    VALUES(1,'cash',120000,120000,0);
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branchA,@LocationId=@locA,
    @CashierId=@staffA,@CurrencyCode='NIO',@CustomerId=@customer,
    @TillId=@till,@OriginNodeId=@nodeA,@Lines=@lines,@Tenders=@tenders;
  EXEC sales.usp_PostSale @SaleId=@sale,@BranchId=@branchA,@LocationId=@locA,
    @CashierId=@staffA,@CurrencyCode='NIO',@CustomerId=@customer,
    @TillId=@till,@OriginNodeId=@nodeA,@Lines=@lines,@Tenders=@tenders;
  IF (SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='store')<>2
     THROW 52005,'QA FAIL: venta duplicada.',1;

  DECLARE @returnLineId uniqueidentifier=(SELECT TOP(1) Id FROM sales.SaleLines WHERE SaleId=@sale);
  DECLARE @ret sales.ReturnLineRequest;
  INSERT INTO @ret(SaleLineId,Quantity,RestockPool) VALUES(@returnLineId,1,'quarantine');
  EXEC sales.usp_PostCreditReturn @ReversalId=@return,@CreditId=@credit,@SaleId=@sale,
    @BranchId=@branchA,@ReturnLocationId=@locA,@TillId=@till,
    @ActorId=@staffA,@ApprovedBy=@manager,@CustomerId=@customer,
    @Reason=N'Talla incorrecta',@OriginNodeId=@nodeA,@Lines=@ret;
  IF (SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA)<>120000
    THROW 52006,'QA FAIL: anticipo no emitido.',1;
  IF (SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='quarantine')<>1
    THROW 52007,'QA FAIL: devolucion no puesta en cuarentena.',1;

  DECLARE @requestEvent uniqueidentifier=NEWID(),@approvalEvent uniqueidentifier=NEWID(),
     @commitEvent uniqueidentifier=NEWID(),@acceptEvent uniqueidentifier=NEWID();
  EXEC credits.usp_RequestTransfer @TransferId=@transfer,@CreditId=@credit,
    @FromBranchId=@branchA,@ToBranchId=@branchB,@AmountMinor=50000,
    @RequestedBy=@staffA,@Reason=N'Canje autorizado en otra sucursal',
    @OriginNodeId=@nodeA,@EventId=@requestEvent;
  EXEC credits.usp_ApproveTransfer @TransferId=@transfer,@ApproverId=@manager,
    @OriginNodeId=@nodeA,@EventId=@approvalEvent;
  EXEC credits.usp_LockTransferAtOrigin @TransferId=@transfer,
    @OriginLockEventId=@lockEvent,@OriginNodeId=@nodeA,@ActorId=@staffA;
  IF (SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchA)<>70000
    THROW 52008,'QA FAIL: monto no bloqueado en origen.',1;
  -- SOLO PRUEBA LOCAL: simula que Azure aplico el evento dentro de esta TX.
  DECLARE @lockPayload nvarchar(max)=(SELECT PayloadJson FROM sync.Outbox WHERE EventId=@lockEvent);
  EXEC sync.usp_RecordAppliedInbox @EventId=@lockEvent,@OriginNodeId=@nodeA,
    @AggregateType='credit_transfer',@AggregateId=@transfer,@PayloadJson=@lockPayload;
  EXEC credits.usp_CommitTransfer @TransferId=@transfer,@ActorId=@manager,
    @OriginNodeId=@azure,@EventId=@commitEvent;
  EXEC credits.usp_AcceptTransfer @TransferId=@transfer,@ActorId=@manager,
    @OriginNodeId=@nodeB,@EventId=@acceptEvent;
  IF (SELECT AvailableMinor FROM credits.CreditAllocations WHERE CreditId=@credit AND BranchId=@branchB)<>50000
    THROW 52009,'QA FAIL: saldo no instalado en destino.',1;

  DECLARE @allocation uniqueidentifier=NEWID();
  EXEC inventory.usp_AllocateToWeb @AllocationId=@allocation,@ItemId=@item,@LocationId=@locA,
    @Quantity=1,@ActorId=@manager,@OriginNodeId=@nodeA;
  IF (SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='web')<>1
    THROW 52010,'QA FAIL: asignacion a web.',1;

  DECLARE @orderEvent uniqueidentifier=NEWID(),@captureEvent uniqueidentifier=NEWID(),
    @fulfillEvent uniqueidentifier=NEWID();
  DECLARE @webLines webstore.OrderLineRequest;
  INSERT INTO @webLines(LineNumber,ItemId,Quantity,UnitPriceMinor,DiscountMinor)
    VALUES(1,@item,1,120000,0);
  EXEC webstore.usp_CreateReservedOrder @OrderId=@order,@CustomerId=@customer,
    @CurrencyCode='NIO',@LocationId=@locA,@BranchId=@branchA,@ShippingMinor=0,
    @OriginNodeId=@azure,@EventId=@orderEvent,@Lines=@webLines;
  IF (SELECT Reserved FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='web')<>1
    THROW 52011,'QA FAIL: ecommerce no reservo.',1;
  EXEC webstore.usp_RecordVerifiedPayment @PaymentId=@payment,@OrderId=@order,
    @Provider=N'QA_ONLY',@ExternalPaymentId=N'QA-TRANSACTION',
    @AmountMinor=120000,@CurrencyCode='NIO',@VerifiedByTrustedService=1,
    @OriginNodeId=@azure,@EventId=@captureEvent;
  EXEC webstore.usp_FulfillPaidOrder @OrderId=@order,@ActorId=@manager,
    @OriginNodeId=@nodeA,@EventId=@fulfillEvent;
  IF (SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@locA AND Pool='web')<>0
    THROW 52012,'QA FAIL: web no despacho stock.',1;

  INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy)
    VALUES(@count,@till,@staffA,'draft',@staffA);
  INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity)
    VALUES(@count,100000,2),(@count,10000,2);
  EXEC sales.usp_SubmitCashCount @CashCountId=@count,@ActorId=@staffA;
  EXEC sales.usp_CloseTill @ClosureId=@close,@TillId=@till,@CashCountId=@count,
      @ActorId=@manager,@OriginNodeId=@nodeA;
  IF NOT EXISTS(SELECT 1 FROM accounting.CloseDocuments d
     JOIN accounting.ExportJobs e ON e.CloseDocumentId=d.Id
     WHERE d.ClosureId=@close AND d.SaleGrossMinor=120000 AND d.ReturnGrossMinor=120000
       AND d.NetSalesMinor=0 AND d.SaleCOGSMinor=60000 AND d.ReturnedCOGSMinor=60000
       AND d.NetCOGSMinor=0 AND e.RecipientCode=N'ACCOUNTANT' AND e.Status='pending')
    THROW 52013,'QA FAIL: documento contable o entrega pendiente.',1;
  IF NOT EXISTS(SELECT 1 FROM sales.CashClosures WHERE Id=@close AND ExpectedMinor=220000
    AND CountedMinor=220000 AND DifferenceMinor=0)
    THROW 52014,'QA FAIL: arqueo incorrecto.',1;

  SELECT N'QA STATIC SMOKE CASES COMPLETED — ROLLBACK' AS Result,
    (SELECT COUNT(*) FROM receiving.ScanEvents WHERE ScanSessionId=@session) AS ScanEvents,
    (SELECT COUNT(*) FROM labels.PrintJobs WHERE ItemId=@item) AS LabelJobs,
    (SELECT COUNT(*) FROM sales.Sales WHERE Id=@sale) AS Sales,
    (SELECT COUNT(*) FROM credits.CreditTransfers WHERE Id=@transfer AND Status='accepted') AS AcceptedTransfers,
    (SELECT COUNT(*) FROM accounting.CloseDocuments WHERE ClosureId=@close) AS CloseReports;
  ROLLBACK TRANSACTION;
  PRINT 'SAVIA: prueba revertida sin persistir datos.';
END TRY
BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
  THROW;
END CATCH;
GO
