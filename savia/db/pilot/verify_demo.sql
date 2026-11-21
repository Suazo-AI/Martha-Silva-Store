-- Read-only verification of the invented Masaya history, including conservation after browser runs.
SET NOCOUNT ON;
IF DB_NAME()<>N'SAVIA_DEV_pilot' THROW 52008,'Solo SAVIA_DEV_pilot.',1;
EXEC audit.usp_CheckConservation @Throw=1;
DECLARE @days int=(SELECT COUNT(DISTINCT CONVERT(date,DATEADD(hour,-6,CreatedAt))) FROM sales.Sales);
IF @days<>60 THROW 59001,'La muestra debe cubrir 60 dias de ventas.',1;
IF EXISTS(SELECT 1 FROM sales.SaleLines WHERE SellerId IS NULL) THROW 59001,'Venta de muestra sin vendedora.',1;
IF EXISTS(SELECT 1 FROM sales.Sales s WHERE s.CustomerId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM sales.SaleTenders t WHERE t.SaleId=s.Id AND t.TenderKind='credit')) THROW 59001,'Venta normal con datos de cliente.',1;
IF NOT EXISTS(SELECT 1 FROM sales.StockExceptions) THROW 59001,'Faltan excepciones de muestra.',1;
SELECT @days AS BusinessDays,(SELECT COUNT(*) FROM sales.Sales) AS Sales,
 (SELECT COUNT(*) FROM catalog.Products) AS Products,(SELECT COUNT(*) FROM catalog.Items) AS Variants,
 (SELECT COUNT(*) FROM sourcing.Suppliers) AS Suppliers,(SELECT COUNT(*) FROM security.Staff WHERE NormalizedLoginName LIKE '%.MUESTRA') AS Staff,
 (SELECT COUNT(*) FROM sales.SaleReversals) AS Returns,(SELECT COUNT(*) FROM sales.StockExceptions) AS StockExceptions,
 (SELECT SUM(Missing) FROM receiving.vw_CurrentQuality) AS MissingUnits,
 (SELECT SUM(Damaged+Stained+Odor) FROM receiving.vw_CurrentQuality) AS QuarantineUnits;
PRINT 'DEMO VERIFY PASS: conservation zero violations';
