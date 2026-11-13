-- TEST: two good, one damaged and one missing are four expected, three physical units.
SET NOCOUNT ON;SET XACT_ABORT ON;
DECLARE @session uniqueidentifier=NEWID(),@container uniqueidentifier=NEWID(),@scan uniqueidentifier=NEWID(),@check uniqueidentifier=NEWID(),
 @supplier uniqueidentifier=test.Id('supplier'),@loc uniqueidentifier=test.Id('locA'),@owner uniqueidentifier=test.Id('manager'),
 @node uniqueidentifier=test.Id('nodeA'),@item uniqueidentifier=test.Id('item'),@receipt uniqueidentifier,@n bigint;
EXEC receiving.usp_OpenScanSession @container,@session,N'CALIDAD',@supplier,@loc,@owner;
DECLARE @sink TABLE(ScanId uniqueidentifier,ItemId uniqueidentifier,MatchStatus varchar(16),Quantity int);
INSERT @sink EXEC receiving.usp_RecordScan @scan,@session,N'0000123456789',4,NULL,@owner;
EXEC receiving.usp_RecordQuality @check,@session,@item,2,1,0,0,1,N'Dañada y faltante',@owner,@loc;
EXEC receiving.usp_RecordQuality @check,@session,@item,2,1,0,0,1,N'Dañada y faltante',@owner,@loc;
EXEC receiving.usp_ApproveScanSession @session,@owner;
EXEC receiving.usp_PostScanSession @session,@owner,@node,@receipt OUTPUT,'NIO';
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='store');EXEC test.AssertEq N'sellable',2,@n;
SET @n=(SELECT OnHand FROM inventory.StockBalances WHERE ItemId=@item AND LocationId=@loc AND Pool='quarantine');EXEC test.AssertEq N'non sellable',1,@n;
SET @n=(SELECT SUM(Quantity) FROM purchasing.GoodsReceiptLines WHERE GoodsReceiptId=@receipt);EXEC test.AssertEq N'physical receipt',3,@n;
EXEC audit.usp_CheckConservation @Throw=1;
PRINT 'PASS';
