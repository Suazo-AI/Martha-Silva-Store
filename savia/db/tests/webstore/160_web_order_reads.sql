-- TEST: public reads: catalog shows capped single-location stock; an order reads only with its token; staff list and due list.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @item uniqueidentifier=test.Id('item'),@locA uniqueidentifier=test.Id('locA'),@manager uniqueidentifier=test.Id('manager'),
  @sku nvarchar(100),@n bigint,@consignment uniqueidentifier=NEWID(),@event uniqueidentifier=NEWID(),@o1 uniqueidentifier=NEWID(),
  @json nvarchar(max);
DECLARE @lines webstore.WebOrderLine;
DECLARE @r TABLE(j nvarchar(max));
SET @sku=(SELECT Sku FROM catalog.Items WHERE Id=@item);
EXEC sync.usp_SetLocalNode @NodeId=@a;
EXEC test.SeedStock @item,@locA,20;
EXEC inventory.usp_ConsignToWeb @ConsignmentId=@consignment,@ItemId=@item,@FromLocationId=@locA,@Quantity=12,@ActorId=@manager;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC inventory.usp_ApplyWebConsignments;
INSERT INTO @r EXEC webstore.usp_PublicCatalogJson; SET @json=(SELECT j FROM @r); DELETE @r;
SET @n=(SELECT CAST(JSON_VALUE(value,'$.available') AS int) FROM OPENJSON(@json) WHERE JSON_VALUE(value,'$.sku')=@sku);
EXEC test.AssertEq N'catalog caps available at 10',10,@n;
INSERT INTO @lines VALUES(1,@sku,4);
EXEC webstore.usp_CreateWebOrder @OrderId=@o1,@RequestHash=0x11,@AccessTokenHash=0x02,@ClientHash=NULL,@Lines=@lines,
  @Name=N'Compradora',@Email=N'uno@example.test',@Phone=NULL,@ZoneCode='managua',@Address=N'Calle 1',@City=N'Managua',
  @Notes=NULL,@Provider='manual',@OriginNodeId=@cloud,@EventId=@event;
INSERT INTO @r EXEC webstore.usp_PublicCatalogJson; SET @json=(SELECT j FROM @r); DELETE @r;
SET @n=(SELECT CAST(JSON_VALUE(value,'$.available') AS int) FROM OPENJSON(@json) WHERE JSON_VALUE(value,'$.sku')=@sku);
EXEC test.AssertEq N'catalog subtracts the reservation',8,@n;
INSERT INTO @r EXEC webstore.usp_WebOrderJson @OrderId=@o1,@AccessTokenHash=0x03; SET @json=(SELECT j FROM @r); DELETE @r;
SET @n=IIF(@json IS NULL,1,0); EXEC test.AssertEq N'wrong token reads nothing',1,@n;
INSERT INTO @r EXEC webstore.usp_WebOrderJson @OrderId=@o1,@AccessTokenHash=0x02; SET @json=(SELECT j FROM @r); DELETE @r;
SET @n=(SELECT COUNT(*) WHERE JSON_VALUE(@json,'$.status')='reserved' AND JSON_VALUE(@json,'$.lines[0].qty')='4'
  AND @json NOT LIKE N'%Calle%'); EXEC test.AssertEq N'right token reads status and lines, no address',1,@n;
INSERT INTO @r EXEC webstore.usp_WebOrdersJson @Status='reserved'; SET @json=(SELECT j FROM @r); DELETE @r;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@json) WHERE JSON_VALUE(value,'$.address')=N'Calle 1'
  AND JSON_VALUE(value,'$.sourceStore') IS NOT NULL); EXEC test.AssertEq N'staff list has address and source store',1,@n;
INSERT INTO @r EXEC webstore.usp_DueWebOrdersJson; SET @json=(SELECT j FROM @r); DELETE @r;
SET @n=(SELECT COUNT(*) FROM OPENJSON(ISNULL(@json,'[]'))); EXEC test.AssertEq N'nothing due before expiry',0,@n;
UPDATE webstore.Orders SET ExpiresAt=DATEADD(minute,-1,SYSUTCDATETIME()) WHERE Id=@o1;
INSERT INTO @r EXEC webstore.usp_DueWebOrdersJson; SET @json=(SELECT j FROM @r); DELETE @r;
SET @n=(SELECT COUNT(*) FROM OPENJSON(ISNULL(@json,'[]')) WHERE JSON_VALUE(value,'$.orderId')=CAST(@o1 AS nvarchar(36)));
EXEC test.AssertEq N'expired reservation is due',1,@n;
PRINT 'PASS';
