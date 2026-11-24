-- TEST: the hub imports the catalog with no branch and no location (D-039, S9): products, items, barcodes and prices,
-- never stock. Stock enters only through receiving at a store. The owner needs no branch access on the hub.
SET NOCOUNT ON;SET XACT_ABORT ON;
DECLARE @hub uniqueidentifier=test.Id('nodeCloud'),@owner uniqueidentifier=test.Id('manager'),@supervisor uniqueidentifier=test.Id('supervisorA'),
 @loc uniqueidentifier=test.Id('locA'),@batch uniqueidentifier=NEWID(),@n bigint,@json nvarchar(max);
DECLARE @out TABLE(Json nvarchar(max));
-- The hub's owner works for every store, so a branch grant is not what lets them import.
UPDATE security.StaffBranchAccess SET IsActive=0 WHERE StaffId=@owner;
DECLARE @stocked nvarchar(max)=N'[
 {"row":2,"code":"7501234567893","name":"Blusa lino","type":"Blusa","size":"M","color":"Azul","cost":"200","price":"450","stock":"3"},
 {"row":3,"code":"7501234567886","name":"Blusa lino","type":"Blusa","size":"L","color":"Azul","cost":"200","price":"450","stock":""}]';
BEGIN TRY INSERT @out EXEC catalog.usp_ImportCatalog @batch,NULL,NULL,@supervisor,N'hub.csv',@stocked,@hub,0;THROW 59002,'ASSERT FAIL: a supervisor imported on the hub',1;END TRY BEGIN CATCH IF ERROR_NUMBER()<>52001 THROW;END CATCH;
BEGIN TRY INSERT @out EXEC catalog.usp_ImportCatalog @batch,NULL,@loc,@owner,N'hub.csv',@stocked,@hub,0;THROW 59002,'ASSERT FAIL: a location without a branch',1;END TRY BEGIN CATCH IF ERROR_NUMBER()<>51527 THROW;END CATCH;
INSERT @out EXEC catalog.usp_ImportCatalog @batch,NULL,NULL,@owner,N'hub.csv',@stocked,@hub,0;
SET @json=(SELECT Json FROM @out);
SET @n=TRY_CONVERT(bigint,JSON_VALUE(@json,'$.errorCount'));EXEC test.AssertEq N'hub preview: one row with stock',1,@n;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@json,'$.errors') WHERE JSON_VALUE(value,'$.row')='2'
  AND JSON_VALUE(value,'$.message')=N'En la central la existencia entra por recepcion.');EXEC test.AssertEq N'hub preview names the stock rule',1,@n;
BEGIN TRY EXEC catalog.usp_ImportCatalog @batch,NULL,NULL,@owner,N'hub.csv',@stocked,@hub,1;THROW 59002,'ASSERT FAIL: hub imported stock',1;END TRY BEGIN CATCH IF ERROR_NUMBER()<>52031 THROW;END CATCH;
DECLARE @good nvarchar(max)=N'[
 {"row":2,"code":"7501234567893","name":"Blusa lino","type":"Blusa","size":"M","color":"Azul","cost":"200","price":"450","stock":"0"},
 {"row":3,"code":"7501234567886","name":"Blusa lino","type":"Blusa","size":"L","color":"Azul","cost":"200","price":"450"},
 {"row":4,"code":"PCG-0001","sku":"FAL-S-NEG","name":"Falda","type":"Falda","size":"S","color":"Negro","cost":"150","price":"1,250.00"}]';
DELETE @out;INSERT @out EXEC catalog.usp_ImportCatalog @batch,NULL,NULL,@owner,N'hub.csv',@good,@hub,1;
SET @n=TRY_CONVERT(bigint,(SELECT JSON_VALUE(Json,'$.itemsCreated') FROM @out));EXEC test.AssertEq N'hub: three items',3,@n;
SET @n=(SELECT COUNT(*) FROM catalog.ImportBatches WHERE Id=@batch AND BranchId IS NULL AND LocationId IS NULL AND UnitsAdded=0);EXEC test.AssertEq N'hub batch has no store',1,@n;
SET @n=(SELECT COUNT(*) FROM catalog.ImportBatchItems b JOIN catalog.ItemIdentifiers i ON i.ItemId=b.ItemId AND i.Kind='barcode' WHERE b.BatchId=@batch);EXEC test.AssertEq N'hub: three barcodes',3,@n;
SET @n=(SELECT UnitPriceMinor FROM catalog.Items WHERE Sku=N'FAL-S-NEG');EXEC test.AssertEq N'hub: price set',125000,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockBalances s JOIN catalog.ImportBatchItems b ON b.ItemId=s.ItemId WHERE b.BatchId=@batch);EXEC test.AssertEq N'hub: no balance',0,@n;
SET @n=(SELECT COUNT(*) FROM inventory.StockMovements WHERE SourceType='catalog_import' AND SourceId=@batch);EXEC test.AssertEq N'hub: no movement',0,@n;
SET @n=(SELECT COUNT(*) FROM sync.Outbox WHERE OriginNodeId=@hub AND EventType IN ('catalog.product_registered','catalog.item_registered','catalog.import_posted')
  AND AggregateId IN (SELECT ItemId FROM catalog.ImportBatchItems WHERE BatchId=@batch UNION SELECT ProductId FROM catalog.Items i JOIN catalog.ImportBatchItems b ON b.ItemId=i.Id WHERE b.BatchId=@batch UNION SELECT @batch));
EXEC test.AssertEq N'hub: two products, three items and the batch as events',6,@n;
DELETE @out;INSERT @out EXEC catalog.usp_ImportCatalog @batch,NULL,NULL,@owner,N'hub.csv',@good,@hub,1;
SET @n=(SELECT COUNT(*) FROM catalog.ImportBatchItems WHERE BatchId=@batch);EXEC test.AssertEq N'hub replay writes nothing',3,@n;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';
