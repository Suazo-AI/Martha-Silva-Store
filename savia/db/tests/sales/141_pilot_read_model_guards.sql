-- TEST: Pilot read models reject invalid pages, ranges, overflow dates and short customer queries.
SET NOCOUNT ON;
DECLARE @b uniqueidentifier=test.Id('branchA'),@ok bit=0;
BEGIN TRY EXEC sales.usp_SearchSales @BranchId=@b,@Page=0; END TRY
BEGIN CATCH IF ERROR_NUMBER()=51900 SET @ok=1; ELSE THROW; END CATCH;
IF @ok=0 THROW 59900,'Invalid page accepted.',1;
SET @ok=0;
BEGIN TRY EXEC sales.usp_SearchSales @BranchId=@b,@From='20261113',@To='20261112'; END TRY
BEGIN CATCH IF ERROR_NUMBER()=51900 SET @ok=1; ELSE THROW; END CATCH;
IF @ok=0 THROW 59900,'Invalid date range accepted.',1;
SET @ok=0;
BEGIN TRY EXEC crm.usp_SearchCustomers @Query=N'x'; END TRY
BEGIN CATCH IF ERROR_NUMBER()=51901 SET @ok=1; ELSE THROW; END CATCH;
IF @ok=0 THROW 59900,'Short customer search accepted.',1;
SET @ok=0;
BEGIN TRY EXEC sales.usp_GetDayReport @BranchId=@b,@Date='99990101'; END TRY
BEGIN CATCH IF ERROR_NUMBER()=51900 SET @ok=1; ELSE THROW; END CATCH;
IF @ok=0 THROW 59900,'Overflow date accepted.',1;
PRINT 'PASS';
