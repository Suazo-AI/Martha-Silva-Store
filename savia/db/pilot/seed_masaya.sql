/* SAVIA pilot seed: branch "Masaya". DATOS DE MUESTRA (sample data), not real inventory, staff or customers.
   Idempotent: every row has a fixed id and is inserted only when missing. Run it as often as you like.
   Catalog rows go through catalog.usp_RegisterProduct / usp_RegisterItem with the cloud node as origin (ADR-001 D6).
   Passwords are NOT set here. savia/tools/pilot.py sets them through the API's password hasher
   (Savia.Api provision-passwords), from the SAVIA_PILOT_PASSWORD environment variable. */
SET NOCOUNT ON; SET XACT_ABORT ON;
GO
DECLARE
  @branch uniqueidentifier='5A000000-0000-0000-0000-000000000B01',
  @loc uniqueidentifier='5A000000-0000-0000-0000-000000000A01',
  @register uniqueidentifier='5A000000-0000-0000-0000-000000000C01',
  @cloud uniqueidentifier='5A000000-0000-0000-0000-000000000D00',
  @node uniqueidentifier='5A000000-0000-0000-0000-000000000D01',
  @owner uniqueidentifier='5A000000-0000-0000-0000-000000000E01',
  @super uniqueidentifier='5A000000-0000-0000-0000-000000000E02',
  @cashier uniqueidentifier='5A000000-0000-0000-0000-000000000E03',
  @supplier uniqueidentifier='5A000000-0000-0000-0000-000000000F01',
  @customer uniqueidentifier='5A000000-0000-0000-0000-000000000F02';

BEGIN TRANSACTION;
IF NOT EXISTS(SELECT 1 FROM core.Currencies WHERE Code='NIO')
  INSERT INTO core.Currencies(Code,Name,Exponent) VALUES('NIO',N'Córdoba nicaragüense',2);
IF NOT EXISTS(SELECT 1 FROM core.Branches WHERE Id=@branch)
  INSERT INTO core.Branches(Id,Code,Name,StoreDisplayName) VALUES(@branch,'MASAYA',N'Masaya',N'SAVIA Masaya (MUESTRA)');
IF NOT EXISTS(SELECT 1 FROM core.Locations WHERE Id=@loc)
  INSERT INTO core.Locations(Id,BranchId,Code,Name,Kind) VALUES(@loc,@branch,'MASAYA_TIENDA',N'Tienda Masaya','store');
IF NOT EXISTS(SELECT 1 FROM sales.CashRegisters WHERE Id=@register)
  INSERT INTO sales.CashRegisters(Id,BranchId,LocationId,Code,Name) VALUES(@register,@branch,@loc,N'CAJA1',N'Caja 1 Masaya');
-- The cloud node must exist: a branch event without a cloud destination is rejected (sync.usp_EnqueueEvent 51003).
IF NOT EXISTS(SELECT 1 FROM sync.Nodes WHERE Id=@cloud)
  INSERT INTO sync.Nodes(Id,BranchId,NodeCode,Kind) VALUES(@cloud,NULL,N'PILOT_CLOUD','azure');
IF NOT EXISTS(SELECT 1 FROM sync.Nodes WHERE Id=@node)
  INSERT INTO sync.Nodes(Id,BranchId,NodeCode,Kind) VALUES(@node,@branch,N'PILOT_MASAYA','branch');

IF NOT EXISTS(SELECT 1 FROM security.Staff WHERE Id=@owner)
  INSERT INTO security.Staff(Id,LoginName,NormalizedLoginName,DisplayName) VALUES(@owner,N'duena.muestra',N'DUENA.MUESTRA',N'Dueña (MUESTRA)');
IF NOT EXISTS(SELECT 1 FROM security.Staff WHERE Id=@super)
  INSERT INTO security.Staff(Id,LoginName,NormalizedLoginName,DisplayName) VALUES(@super,N'supervisora.muestra',N'SUPERVISORA.MUESTRA',N'Supervisora (MUESTRA)');
IF NOT EXISTS(SELECT 1 FROM security.Staff WHERE Id=@cashier)
  INSERT INTO security.Staff(Id,LoginName,NormalizedLoginName,DisplayName) VALUES(@cashier,N'cajera.muestra',N'CAJERA.MUESTRA',N'Cajera (MUESTRA)');
INSERT INTO security.StaffRoles(StaffId,RoleId)
  SELECT v.StaffId,r.Id FROM (VALUES(@owner,'OWNER'),(@super,'MANAGER'),(@cashier,'CASHIER')) v(StaffId,Code)
  JOIN security.Roles r ON r.Code=v.Code
  WHERE NOT EXISTS(SELECT 1 FROM security.StaffRoles x WHERE x.StaffId=v.StaffId AND x.RoleId=r.Id);
INSERT INTO security.StaffBranchAccess(StaffId,BranchId,CanApproveTransfers,CanApproveReturns)
  SELECT v.StaffId,@branch,v.Approves,v.Approves FROM (VALUES(@owner,1),(@super,1),(@cashier,0)) v(StaffId,Approves)
  WHERE NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess x WHERE x.StaffId=v.StaffId AND x.BranchId=@branch);

IF NOT EXISTS(SELECT 1 FROM sourcing.Suppliers WHERE Id=@supplier)
  INSERT INTO sourcing.Suppliers(Id,SupplierCode,DisplayName) VALUES(@supplier,N'PROV-MUESTRA',N'Proveedor MUESTRA');
IF NOT EXISTS(SELECT 1 FROM crm.Customers WHERE Id=@customer)
  INSERT INTO crm.Customers(Id,CustomerCode,DisplayName,Email) VALUES(@customer,N'CLI-MUESTRA',N'Clienta MUESTRA',N'clienta.muestra@example.test');

INSERT INTO catalog.Sizes(Id,Code,Name,SortOrder)
  SELECT v.Id,v.Code,v.Name,v.SortOrder FROM (VALUES
    (CONVERT(uniqueidentifier,'5A000000-0000-0000-0000-000000000501'),N'S',N'Small',1),
    ('5A000000-0000-0000-0000-000000000502',N'M',N'Medium',2),
    ('5A000000-0000-0000-0000-000000000503',N'L',N'Large',3)) v(Id,Code,Name,SortOrder)
  WHERE NOT EXISTS(SELECT 1 FROM catalog.Sizes x WHERE x.Id=v.Id OR x.Code=v.Code);
INSERT INTO catalog.Colors(Id,Code,Name)
  SELECT v.Id,v.Code,v.Name FROM (VALUES
    (CONVERT(uniqueidentifier,'5A000000-0000-0000-0000-000000000601'),N'BLA',N'Blanco'),
    ('5A000000-0000-0000-0000-000000000602',N'NEG',N'Negro'),
    ('5A000000-0000-0000-0000-000000000603',N'AZU',N'Azul'),
    ('5A000000-0000-0000-0000-000000000604',N'ROS',N'Rosado'),
    ('5A000000-0000-0000-0000-000000000605',N'BEI',N'Beige')) v(Id,Code,Name)
  WHERE NOT EXISTS(SELECT 1 FROM catalog.Colors x WHERE x.Id=v.Id OR x.Code=v.Code);
COMMIT;

-- The database is the Masaya branch node (V008). Idempotent for the same node.
EXEC sync.usp_SetLocalNode @NodeId=@node;
GO

/* Catalog: 7 products, 12 variants. Prices and costs in NIO centavos. Barcodes are sample EAN-13 starting 750. */
DECLARE @cloud uniqueidentifier='5A000000-0000-0000-0000-000000000D00',
  @actor uniqueidentifier='5A000000-0000-0000-0000-000000000E01',
  @supplier uniqueidentifier='5A000000-0000-0000-0000-000000000F01';
DECLARE @products TABLE(Id uniqueidentifier PRIMARY KEY, Name nvarchar(200));
INSERT INTO @products VALUES
 ('5A000000-0000-0000-0000-000000000101',N'Blusa de lino MUESTRA'),
 ('5A000000-0000-0000-0000-000000000102',N'Vestido midi floral MUESTRA'),
 ('5A000000-0000-0000-0000-000000000103',N'Falda plisada MUESTRA'),
 ('5A000000-0000-0000-0000-000000000104',N'Pantalón palazzo MUESTRA'),
 ('5A000000-0000-0000-0000-000000000105',N'Jeans skinny MUESTRA'),
 ('5A000000-0000-0000-0000-000000000106',N'Top básico MUESTRA'),
 ('5A000000-0000-0000-0000-000000000107',N'Cárdigan tejido MUESTRA');
DECLARE @items TABLE(RowNo int PRIMARY KEY, Id uniqueidentifier, ProductId uniqueidentifier, Sku nvarchar(100),
  VariantName nvarchar(200), SizeCode nvarchar(10), ColorCode nvarchar(10), PriceMinor bigint, CostMinor bigint, Barcode nvarchar(128));
INSERT INTO @items VALUES
 (1, '5A000000-0000-0000-0000-000000000201','5A000000-0000-0000-0000-000000000101',N'MAS-BLU-LIN-BLA-S',N'Blusa de lino blanca S',N'S',N'BLA',59900,28000,N'7500001000014'),
 (2, '5A000000-0000-0000-0000-000000000202','5A000000-0000-0000-0000-000000000101',N'MAS-BLU-LIN-BLA-M',N'Blusa de lino blanca M',N'M',N'BLA',59900,28000,N'7500001000021'),
 (3, '5A000000-0000-0000-0000-000000000203','5A000000-0000-0000-0000-000000000102',N'MAS-VES-MID-ROS-S',N'Vestido midi floral rosado S',N'S',N'ROS',129900,62000,N'7500001000038'),
 (4, '5A000000-0000-0000-0000-000000000204','5A000000-0000-0000-0000-000000000102',N'MAS-VES-MID-ROS-M',N'Vestido midi floral rosado M',N'M',N'ROS',129900,62000,N'7500001000045'),
 (5, '5A000000-0000-0000-0000-000000000205','5A000000-0000-0000-0000-000000000102',N'MAS-VES-MID-ROS-L',N'Vestido midi floral rosado L',N'L',N'ROS',129900,62000,N'7500001000052'),
 (6, '5A000000-0000-0000-0000-000000000206','5A000000-0000-0000-0000-000000000103',N'MAS-FAL-PLI-NEG-M',N'Falda plisada negra M',N'M',N'NEG',79900,35000,N'7500001000069'),
 (7, '5A000000-0000-0000-0000-000000000207','5A000000-0000-0000-0000-000000000104',N'MAS-PAN-PAL-BEI-S',N'Pantalón palazzo beige S',N'S',N'BEI',99900,45000,N'7500001000076'),
 (8, '5A000000-0000-0000-0000-000000000208','5A000000-0000-0000-0000-000000000104',N'MAS-PAN-PAL-BEI-M',N'Pantalón palazzo beige M',N'M',N'BEI',99900,45000,N'7500001000083'),
 (9, '5A000000-0000-0000-0000-000000000209','5A000000-0000-0000-0000-000000000105',N'MAS-JEA-SKI-AZU-M',N'Jeans skinny azul M',N'M',N'AZU',109900,50000,N'7500001000090'),
 (10,'5A000000-0000-0000-0000-000000000210','5A000000-0000-0000-0000-000000000105',N'MAS-JEA-SKI-AZU-L',N'Jeans skinny azul L',N'L',N'AZU',109900,50000,N'7500001000106'),
 (11,'5A000000-0000-0000-0000-000000000211','5A000000-0000-0000-0000-000000000106',N'MAS-TOP-BAS-NEG-S',N'Top básico negro S',N'S',N'NEG',34900,15000,N'7500001000113'),
 (12,'5A000000-0000-0000-0000-000000000212','5A000000-0000-0000-0000-000000000107',N'MAS-CAR-TEJ-BEI-M',N'Cárdigan tejido beige M',N'M',N'BEI',89900,40000,N'7500001000120');

DECLARE @id uniqueidentifier,@name nvarchar(200),@event uniqueidentifier,@n int=1,
  @product uniqueidentifier,@sku nvarchar(100),@variant nvarchar(200),@size uniqueidentifier,@color uniqueidentifier,
  @price bigint,@cost bigint,@barcode nvarchar(128);
DECLARE p CURSOR LOCAL FAST_FORWARD FOR SELECT Id,Name FROM @products ORDER BY Id;
OPEN p; FETCH NEXT FROM p INTO @id,@name;
WHILE @@FETCH_STATUS=0
BEGIN
  SET @event=NEWID();
  EXEC catalog.usp_RegisterProduct @ProductId=@id,@Name=@name,@OriginNodeId=@cloud,@EventId=@event,@ActorId=@actor;
  FETCH NEXT FROM p INTO @id,@name;
END;
CLOSE p; DEALLOCATE p;
WHILE @n<=12
BEGIN
  SELECT @id=i.Id,@product=i.ProductId,@sku=i.Sku,@variant=i.VariantName,@size=s.Id,@color=c.Id,
         @price=i.PriceMinor,@cost=i.CostMinor,@barcode=i.Barcode,@event=NEWID()
  FROM @items i JOIN catalog.Sizes s ON s.Code=i.SizeCode JOIN catalog.Colors c ON c.Code=i.ColorCode WHERE i.RowNo=@n;
  EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=@sku,@VariantName=@variant,@CurrencyCode='NIO',
    @UnitPriceMinor=@price,@UnitCostMinor=@cost,@Barcode=@barcode,@SizeId=@size,@ColorId=@color,
    @SupplierId=@supplier,@ActorId=@actor,@ItemId=@id,@OriginNodeId=@cloud,@EventId=@event;
  SET @n+=1;
END;
GO

SELECT 'seed_masaya' AS Seed,
  (SELECT COUNT(*) FROM core.Branches WHERE Code='MASAYA') AS Branches,
  (SELECT COUNT(*) FROM security.Staff WHERE NormalizedLoginName LIKE '%.MUESTRA') AS Staff,
  (SELECT COUNT(*) FROM catalog.Items WHERE Sku LIKE 'MAS-%') AS Items,
  (SELECT COUNT(*) FROM sync.LocalNode) AS LocalNode;
GO
