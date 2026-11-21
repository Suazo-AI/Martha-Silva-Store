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
  @seller2 uniqueidentifier='5A000000-0000-0000-0000-000000000E04',
  @stock uniqueidentifier='5A000000-0000-0000-0000-000000000E05',
  @supplier uniqueidentifier='5A000000-0000-0000-0000-000000000F01',
  @customer uniqueidentifier='5A000000-0000-0000-0000-000000000F02';

BEGIN TRANSACTION;
IF NOT EXISTS(SELECT 1 FROM core.Currencies WHERE Code='NIO')
  INSERT INTO core.Currencies(Code,Name,Exponent) VALUES('NIO',N'Córdoba nicaragüense',2);
IF NOT EXISTS(SELECT 1 FROM core.Branches WHERE Id=@branch)
  INSERT INTO core.Branches(Id,Code,Name,StoreDisplayName) VALUES(@branch,'MASAYA',N'Masaya',N'SAVIA Masaya');
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
  INSERT INTO security.Staff(Id,LoginName,NormalizedLoginName,DisplayName) VALUES(@owner,N'duena.muestra',N'DUENA.MUESTRA',N'María Elena López');
IF NOT EXISTS(SELECT 1 FROM security.Staff WHERE Id=@super)
  INSERT INTO security.Staff(Id,LoginName,NormalizedLoginName,DisplayName) VALUES(@super,N'gerente.muestra',N'GERENTE.MUESTRA',N'Claudia Reyes');
IF NOT EXISTS(SELECT 1 FROM security.Staff WHERE Id=@cashier)
  INSERT INTO security.Staff(Id,LoginName,NormalizedLoginName,DisplayName) VALUES(@cashier,N'vendedor1.muestra',N'VENDEDOR1.MUESTRA',N'Ana Lucía Pérez');
IF NOT EXISTS(SELECT 1 FROM security.Staff WHERE Id=@seller2)
 INSERT security.Staff(Id,LoginName,NormalizedLoginName,DisplayName) VALUES(@seller2,N'vendedor2.muestra',N'VENDEDOR2.MUESTRA',N'Rosa Isabel Gutiérrez');
IF NOT EXISTS(SELECT 1 FROM security.Staff WHERE Id=@stock)
 INSERT security.Staff(Id,LoginName,NormalizedLoginName,DisplayName) VALUES(@stock,N'bodega.muestra',N'BODEGA.MUESTRA',N'Marta Solís');
-- Upgrade existing pilot identities without deleting their history. Retire the former cashier grant.
UPDATE security.Staff SET DisplayName=N'María Elena López' WHERE Id=@owner;
UPDATE security.Staff SET LoginName=N'gerente.muestra',NormalizedLoginName=N'GERENTE.MUESTRA',DisplayName=N'Claudia Reyes' WHERE Id=@super;
UPDATE security.Staff SET LoginName=N'vendedor1.muestra',NormalizedLoginName=N'VENDEDOR1.MUESTRA',DisplayName=N'Ana Lucía Pérez' WHERE Id=@cashier;
UPDATE security.StaffRoles SET RoleId=(SELECT Id FROM security.Roles WHERE Code='SELLER') WHERE StaffId=@cashier AND RoleId=(SELECT Id FROM security.Roles WHERE Code='CASHIER');
INSERT INTO security.StaffRoles(StaffId,RoleId)
  SELECT v.StaffId,r.Id FROM (VALUES(@owner,'OWNER'),(@super,'MANAGER'),(@cashier,'SELLER'),(@seller2,'SELLER'),(@stock,'INVENTORY')) v(StaffId,Code)
  JOIN security.Roles r ON r.Code=v.Code
  WHERE NOT EXISTS(SELECT 1 FROM security.StaffRoles x WHERE x.StaffId=v.StaffId AND x.RoleId=r.Id);
INSERT INTO security.StaffBranchAccess(StaffId,BranchId,CanApproveTransfers,CanApproveReturns)
  SELECT v.StaffId,@branch,v.Approves,v.Approves FROM (VALUES(@owner,1),(@super,1),(@cashier,0),(@seller2,0),(@stock,0)) v(StaffId,Approves)
  WHERE NOT EXISTS(SELECT 1 FROM security.StaffBranchAccess x WHERE x.StaffId=v.StaffId AND x.BranchId=@branch);
INSERT sales.SellerRates(SellerId,RateBps)
 SELECT v.Id,300 FROM (VALUES(@cashier),(@seller2)) v(Id)
 WHERE NOT EXISTS(SELECT 1 FROM sales.SellerRates r WHERE r.SellerId=v.Id);

IF NOT EXISTS(SELECT 1 FROM sourcing.Suppliers WHERE Id=@supplier)
  INSERT INTO sourcing.Suppliers(Id,SupplierCode,DisplayName) VALUES(@supplier,N'PROV-PILOTO',N'Proveedor');
IF NOT EXISTS(SELECT 1 FROM crm.Customers WHERE Id=@customer)
  INSERT INTO crm.Customers(Id,CustomerCode,DisplayName,Email) VALUES(@customer,N'CLI-PILOTO',N'Clienta',N'clienta@example.test');

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
 ('5A000000-0000-0000-0000-000000000101',N'Blusa de lino'),
 ('5A000000-0000-0000-0000-000000000102',N'Vestido midi floral'),
 ('5A000000-0000-0000-0000-000000000103',N'Falda plisada'),
 ('5A000000-0000-0000-0000-000000000104',N'Pantalón palazzo'),
 ('5A000000-0000-0000-0000-000000000105',N'Jeans skinny'),
 ('5A000000-0000-0000-0000-000000000106',N'Top básico'),
 ('5A000000-0000-0000-0000-000000000107',N'Cárdigan tejido');
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

-- Additional invented catalog approved for this local demonstration: 15 products / 60 items total.
DECLARE @supplier2 uniqueidentifier='5A000000-0000-0000-0000-000000000F03';
IF NOT EXISTS(SELECT 1 FROM sourcing.Suppliers WHERE Id=@supplier2)
 INSERT sourcing.Suppliers(Id,SupplierCode,DisplayName) VALUES(@supplier2,N'TEXTIL-MASAYA',N'Textiles El Sacuanjoche');
UPDATE sourcing.Suppliers SET DisplayName=N'Confecciones La Marimba' WHERE Id='5A000000-0000-0000-0000-000000000F01';
DECLARE @owner uniqueidentifier='5A000000-0000-0000-0000-000000000E01',@node uniqueidentifier='5A000000-0000-0000-0000-000000000D00',@event uniqueidentifier,@product uniqueidentifier,@item uniqueidentifier;
SET @product='b8ddc8e5-0578-5276-b85d-014d3aa08871';SET @event=NEWID();
EXEC catalog.usp_RegisterProduct @ProductId=@product,@Name=N'Vestido camisero',@OriginNodeId=@node,@EventId=@event,@ActorId=@owner;
SET @item='08c48832-a50e-5616-82c7-d01fac5d869b';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-01-01',@VariantName=N'Vestido camisero S Blanco',@CurrencyCode='NIO',@UnitPriceMinor=45000,@UnitCostMinor=20250,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000015',@SizeId='5A000000-0000-0000-0000-000000000501',@ColorId='5A000000-0000-0000-0000-000000000601',@SupplierId=@supplier2;
SET @item='7374a200-87bd-573f-a353-7c04554fc74a';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-01-02',@VariantName=N'Vestido camisero M Negro',@CurrencyCode='NIO',@UnitPriceMinor=47000,@UnitCostMinor=21150,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000022',@SizeId='5A000000-0000-0000-0000-000000000502',@ColorId='5A000000-0000-0000-0000-000000000602',@SupplierId=@supplier2;
SET @item='1ae38652-f4b5-5919-b123-9dbdb74dc55e';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-01-03',@VariantName=N'Vestido camisero L Azul',@CurrencyCode='NIO',@UnitPriceMinor=49000,@UnitCostMinor=22050,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000039',@SizeId='5A000000-0000-0000-0000-000000000503',@ColorId='5A000000-0000-0000-0000-000000000603',@SupplierId=@supplier2;
SET @item='5b651e26-af50-5671-bfd1-ad76e6dd3f9c';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-01-04',@VariantName=N'Vestido camisero S Rosado',@CurrencyCode='NIO',@UnitPriceMinor=51000,@UnitCostMinor=22950,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000046',@SizeId='5A000000-0000-0000-0000-000000000501',@ColorId='5A000000-0000-0000-0000-000000000604',@SupplierId=@supplier2;
SET @item='32303a43-6f63-524c-927d-65afa49aafaa';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-01-05',@VariantName=N'Vestido camisero M Beige',@CurrencyCode='NIO',@UnitPriceMinor=53000,@UnitCostMinor=23850,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000053',@SizeId='5A000000-0000-0000-0000-000000000502',@ColorId='5A000000-0000-0000-0000-000000000605',@SupplierId=@supplier2;
SET @item='efdaea65-96dd-5d22-94ec-eb80945e8243';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-01-06',@VariantName=N'Vestido camisero L Blanco',@CurrencyCode='NIO',@UnitPriceMinor=55000,@UnitCostMinor=24750,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000060',@SizeId='5A000000-0000-0000-0000-000000000503',@ColorId='5A000000-0000-0000-0000-000000000601',@SupplierId=@supplier2;
SET @product='54bd4832-e874-511e-978b-d0c99ac98112';SET @event=NEWID();
EXEC catalog.usp_RegisterProduct @ProductId=@product,@Name=N'Blusa bordada',@OriginNodeId=@node,@EventId=@event,@ActorId=@owner;
SET @item='17f4e581-823b-55cb-a465-176cba79cdc1';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-02-01',@VariantName=N'Blusa bordada S Negro',@CurrencyCode='NIO',@UnitPriceMinor=55000,@UnitCostMinor=24750,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000077',@SizeId='5A000000-0000-0000-0000-000000000501',@ColorId='5A000000-0000-0000-0000-000000000602',@SupplierId=@supplier2;
SET @item='c0ed9afa-dc3a-56d0-a176-ef59995c9492';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-02-02',@VariantName=N'Blusa bordada M Azul',@CurrencyCode='NIO',@UnitPriceMinor=57000,@UnitCostMinor=25650,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000084',@SizeId='5A000000-0000-0000-0000-000000000502',@ColorId='5A000000-0000-0000-0000-000000000603',@SupplierId=@supplier2;
SET @item='9cc840bd-1a65-5e22-84fa-c8a5f883e785';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-02-03',@VariantName=N'Blusa bordada L Rosado',@CurrencyCode='NIO',@UnitPriceMinor=59000,@UnitCostMinor=26550,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000091',@SizeId='5A000000-0000-0000-0000-000000000503',@ColorId='5A000000-0000-0000-0000-000000000604',@SupplierId=@supplier2;
SET @item='c9fc36a9-2259-5051-9f3e-dffc133512b7';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-02-04',@VariantName=N'Blusa bordada S Beige',@CurrencyCode='NIO',@UnitPriceMinor=61000,@UnitCostMinor=27450,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000107',@SizeId='5A000000-0000-0000-0000-000000000501',@ColorId='5A000000-0000-0000-0000-000000000605',@SupplierId=@supplier2;
SET @item='1a60a29c-15d5-5681-ada3-e8996636f8f7';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-02-05',@VariantName=N'Blusa bordada M Blanco',@CurrencyCode='NIO',@UnitPriceMinor=63000,@UnitCostMinor=28350,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000114',@SizeId='5A000000-0000-0000-0000-000000000502',@ColorId='5A000000-0000-0000-0000-000000000601',@SupplierId=@supplier2;
SET @item='9ed75e99-4d82-545e-81a3-d4cfc7f04e81';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-02-06',@VariantName=N'Blusa bordada L Negro',@CurrencyCode='NIO',@UnitPriceMinor=65000,@UnitCostMinor=29250,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000121',@SizeId='5A000000-0000-0000-0000-000000000503',@ColorId='5A000000-0000-0000-0000-000000000602',@SupplierId=@supplier2;
SET @product='99b87712-969b-5b21-8113-a37b76059dda';SET @event=NEWID();
EXEC catalog.usp_RegisterProduct @ProductId=@product,@Name=N'Falda de mezclilla',@OriginNodeId=@node,@EventId=@event,@ActorId=@owner;
SET @item='1d7e0969-0831-5063-bff2-807c4f27b698';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-03-01',@VariantName=N'Falda de mezclilla S Azul',@CurrencyCode='NIO',@UnitPriceMinor=65000,@UnitCostMinor=29250,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000138',@SizeId='5A000000-0000-0000-0000-000000000501',@ColorId='5A000000-0000-0000-0000-000000000603',@SupplierId=@supplier2;
SET @item='0320dc3a-6b3e-57ec-b645-a4262a3dfb18';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-03-02',@VariantName=N'Falda de mezclilla M Rosado',@CurrencyCode='NIO',@UnitPriceMinor=67000,@UnitCostMinor=30150,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000145',@SizeId='5A000000-0000-0000-0000-000000000502',@ColorId='5A000000-0000-0000-0000-000000000604',@SupplierId=@supplier2;
SET @item='7d99785b-6302-5fed-a3d0-883b14a457d6';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-03-03',@VariantName=N'Falda de mezclilla L Beige',@CurrencyCode='NIO',@UnitPriceMinor=69000,@UnitCostMinor=31050,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000152',@SizeId='5A000000-0000-0000-0000-000000000503',@ColorId='5A000000-0000-0000-0000-000000000605',@SupplierId=@supplier2;
SET @item='eb8c4625-a58e-51ac-ab06-aa5f86e06b00';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-03-04',@VariantName=N'Falda de mezclilla S Blanco',@CurrencyCode='NIO',@UnitPriceMinor=71000,@UnitCostMinor=31950,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000169',@SizeId='5A000000-0000-0000-0000-000000000501',@ColorId='5A000000-0000-0000-0000-000000000601',@SupplierId=@supplier2;
SET @item='406a14f4-ba47-55ee-92fb-50f5bb661b69';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-03-05',@VariantName=N'Falda de mezclilla M Negro',@CurrencyCode='NIO',@UnitPriceMinor=73000,@UnitCostMinor=32850,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000176',@SizeId='5A000000-0000-0000-0000-000000000502',@ColorId='5A000000-0000-0000-0000-000000000602',@SupplierId=@supplier2;
SET @item='84370907-456e-5504-a825-038505f8286e';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-03-06',@VariantName=N'Falda de mezclilla L Azul',@CurrencyCode='NIO',@UnitPriceMinor=75000,@UnitCostMinor=33750,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000183',@SizeId='5A000000-0000-0000-0000-000000000503',@ColorId='5A000000-0000-0000-0000-000000000603',@SupplierId=@supplier2;
SET @product='ced799df-d0cf-5d60-9ae2-b6d76ee000c8';SET @event=NEWID();
EXEC catalog.usp_RegisterProduct @ProductId=@product,@Name=N'Pantalón recto',@OriginNodeId=@node,@EventId=@event,@ActorId=@owner;
SET @item='de3298d6-6f70-5d57-9128-2667b714a038';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-04-01',@VariantName=N'Pantalón recto S Rosado',@CurrencyCode='NIO',@UnitPriceMinor=75000,@UnitCostMinor=33750,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000190',@SizeId='5A000000-0000-0000-0000-000000000501',@ColorId='5A000000-0000-0000-0000-000000000604',@SupplierId=@supplier2;
SET @item='cfd7aa75-3ba1-59d9-bc47-346f5767721f';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-04-02',@VariantName=N'Pantalón recto M Beige',@CurrencyCode='NIO',@UnitPriceMinor=77000,@UnitCostMinor=34650,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000206',@SizeId='5A000000-0000-0000-0000-000000000502',@ColorId='5A000000-0000-0000-0000-000000000605',@SupplierId=@supplier2;
SET @item='e3982d52-bf93-5406-be69-f70a29a25037';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-04-03',@VariantName=N'Pantalón recto L Blanco',@CurrencyCode='NIO',@UnitPriceMinor=79000,@UnitCostMinor=35550,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000213',@SizeId='5A000000-0000-0000-0000-000000000503',@ColorId='5A000000-0000-0000-0000-000000000601',@SupplierId=@supplier2;
SET @item='fdf27a89-30dc-5aa1-8c6a-9f626e2179b2';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-04-04',@VariantName=N'Pantalón recto S Negro',@CurrencyCode='NIO',@UnitPriceMinor=81000,@UnitCostMinor=36450,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000220',@SizeId='5A000000-0000-0000-0000-000000000501',@ColorId='5A000000-0000-0000-0000-000000000602',@SupplierId=@supplier2;
SET @item='412d3620-f864-5aa9-b0ba-3595aa519e99';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-04-05',@VariantName=N'Pantalón recto M Azul',@CurrencyCode='NIO',@UnitPriceMinor=83000,@UnitCostMinor=37350,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000237',@SizeId='5A000000-0000-0000-0000-000000000502',@ColorId='5A000000-0000-0000-0000-000000000603',@SupplierId=@supplier2;
SET @item='3c1a9694-999f-5f15-a9e6-912c6c0544d6';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-04-06',@VariantName=N'Pantalón recto L Rosado',@CurrencyCode='NIO',@UnitPriceMinor=85000,@UnitCostMinor=38250,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000244',@SizeId='5A000000-0000-0000-0000-000000000503',@ColorId='5A000000-0000-0000-0000-000000000604',@SupplierId=@supplier2;
SET @product='ba7999d3-d493-5901-9163-2d551a3dd3de';SET @event=NEWID();
EXEC catalog.usp_RegisterProduct @ProductId=@product,@Name=N'Jeans clásico',@OriginNodeId=@node,@EventId=@event,@ActorId=@owner;
SET @item='d5b373cd-7337-5e1f-b184-d76259bea301';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-05-01',@VariantName=N'Jeans clásico S Beige',@CurrencyCode='NIO',@UnitPriceMinor=85000,@UnitCostMinor=38250,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000251',@SizeId='5A000000-0000-0000-0000-000000000501',@ColorId='5A000000-0000-0000-0000-000000000605',@SupplierId=@supplier2;
SET @item='e8c36fbf-3a84-5705-83c5-3b5bd61e4e63';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-05-02',@VariantName=N'Jeans clásico M Blanco',@CurrencyCode='NIO',@UnitPriceMinor=87000,@UnitCostMinor=39150,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000268',@SizeId='5A000000-0000-0000-0000-000000000502',@ColorId='5A000000-0000-0000-0000-000000000601',@SupplierId=@supplier2;
SET @item='41bf905d-c3f8-5a4b-8dd5-47050f5c1c39';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-05-03',@VariantName=N'Jeans clásico L Negro',@CurrencyCode='NIO',@UnitPriceMinor=89000,@UnitCostMinor=40050,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000275',@SizeId='5A000000-0000-0000-0000-000000000503',@ColorId='5A000000-0000-0000-0000-000000000602',@SupplierId=@supplier2;
SET @item='6ad4f7a6-3f6f-5806-bce3-60414703af7d';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-05-04',@VariantName=N'Jeans clásico S Azul',@CurrencyCode='NIO',@UnitPriceMinor=91000,@UnitCostMinor=40950,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000282',@SizeId='5A000000-0000-0000-0000-000000000501',@ColorId='5A000000-0000-0000-0000-000000000603',@SupplierId=@supplier2;
SET @item='a56a4606-c5a2-595f-a8dd-9989535af1e7';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-05-05',@VariantName=N'Jeans clásico M Rosado',@CurrencyCode='NIO',@UnitPriceMinor=93000,@UnitCostMinor=41850,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000299',@SizeId='5A000000-0000-0000-0000-000000000502',@ColorId='5A000000-0000-0000-0000-000000000604',@SupplierId=@supplier2;
SET @item='39f668a9-61ed-566f-ab41-ee1a98e85c04';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-05-06',@VariantName=N'Jeans clásico L Beige',@CurrencyCode='NIO',@UnitPriceMinor=95000,@UnitCostMinor=42750,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000305',@SizeId='5A000000-0000-0000-0000-000000000503',@ColorId='5A000000-0000-0000-0000-000000000605',@SupplierId=@supplier2;
SET @product='b7728e61-7b79-5588-b225-b2894d73b0d7';SET @event=NEWID();
EXEC catalog.usp_RegisterProduct @ProductId=@product,@Name=N'Top de tirantes',@OriginNodeId=@node,@EventId=@event,@ActorId=@owner;
SET @item='8ad5d5c1-ca6b-59f6-b3c5-049ffccdf375';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-06-01',@VariantName=N'Top de tirantes S Blanco',@CurrencyCode='NIO',@UnitPriceMinor=95000,@UnitCostMinor=42750,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000312',@SizeId='5A000000-0000-0000-0000-000000000501',@ColorId='5A000000-0000-0000-0000-000000000601',@SupplierId=@supplier2;
SET @item='ebf079c0-5ef3-5d47-af2a-0d5c33e83115';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-06-02',@VariantName=N'Top de tirantes M Negro',@CurrencyCode='NIO',@UnitPriceMinor=97000,@UnitCostMinor=43650,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000329',@SizeId='5A000000-0000-0000-0000-000000000502',@ColorId='5A000000-0000-0000-0000-000000000602',@SupplierId=@supplier2;
SET @item='3f45dcb4-82ee-549b-8b54-762e54655ee6';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-06-03',@VariantName=N'Top de tirantes L Azul',@CurrencyCode='NIO',@UnitPriceMinor=99000,@UnitCostMinor=44550,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000336',@SizeId='5A000000-0000-0000-0000-000000000503',@ColorId='5A000000-0000-0000-0000-000000000603',@SupplierId=@supplier2;
SET @item='4ebeb21c-9c94-5cfa-b255-dd804136a798';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-06-04',@VariantName=N'Top de tirantes S Rosado',@CurrencyCode='NIO',@UnitPriceMinor=101000,@UnitCostMinor=45450,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000343',@SizeId='5A000000-0000-0000-0000-000000000501',@ColorId='5A000000-0000-0000-0000-000000000604',@SupplierId=@supplier2;
SET @item='216a69b6-5ef9-5906-9ce3-5b77acbd3332';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-06-05',@VariantName=N'Top de tirantes M Beige',@CurrencyCode='NIO',@UnitPriceMinor=103000,@UnitCostMinor=46350,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000350',@SizeId='5A000000-0000-0000-0000-000000000502',@ColorId='5A000000-0000-0000-0000-000000000605',@SupplierId=@supplier2;
SET @item='ff487d95-6fff-5f30-95a5-eb7da6ba0c9c';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-06-06',@VariantName=N'Top de tirantes L Blanco',@CurrencyCode='NIO',@UnitPriceMinor=105000,@UnitCostMinor=47250,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000367',@SizeId='5A000000-0000-0000-0000-000000000503',@ColorId='5A000000-0000-0000-0000-000000000601',@SupplierId=@supplier2;
SET @product='9afc0d84-3850-56d9-94fe-f34ead97a764';SET @event=NEWID();
EXEC catalog.usp_RegisterProduct @ProductId=@product,@Name=N'Cárdigan ligero',@OriginNodeId=@node,@EventId=@event,@ActorId=@owner;
SET @item='fdfdfcf2-d115-504e-a626-b583d2a4f217';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-07-01',@VariantName=N'Cárdigan ligero S Negro',@CurrencyCode='NIO',@UnitPriceMinor=105000,@UnitCostMinor=47250,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000374',@SizeId='5A000000-0000-0000-0000-000000000501',@ColorId='5A000000-0000-0000-0000-000000000602',@SupplierId=@supplier2;
SET @item='acafe6e1-8654-5ba0-bc1b-9b33608d06e8';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-07-02',@VariantName=N'Cárdigan ligero M Azul',@CurrencyCode='NIO',@UnitPriceMinor=107000,@UnitCostMinor=48150,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000381',@SizeId='5A000000-0000-0000-0000-000000000502',@ColorId='5A000000-0000-0000-0000-000000000603',@SupplierId=@supplier2;
SET @item='e5a481ee-f01b-56a4-bb55-bb7ce2f0be2f';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-07-03',@VariantName=N'Cárdigan ligero L Rosado',@CurrencyCode='NIO',@UnitPriceMinor=109000,@UnitCostMinor=49050,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000398',@SizeId='5A000000-0000-0000-0000-000000000503',@ColorId='5A000000-0000-0000-0000-000000000604',@SupplierId=@supplier2;
SET @item='0aeb1a2f-67c7-56bf-a787-c4c66e60e4b3';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-07-04',@VariantName=N'Cárdigan ligero S Beige',@CurrencyCode='NIO',@UnitPriceMinor=111000,@UnitCostMinor=49950,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000404',@SizeId='5A000000-0000-0000-0000-000000000501',@ColorId='5A000000-0000-0000-0000-000000000605',@SupplierId=@supplier2;
SET @item='b8cd7fb4-a757-59b8-bb6a-105e7214820c';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-07-05',@VariantName=N'Cárdigan ligero M Blanco',@CurrencyCode='NIO',@UnitPriceMinor=113000,@UnitCostMinor=50850,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000411',@SizeId='5A000000-0000-0000-0000-000000000502',@ColorId='5A000000-0000-0000-0000-000000000601',@SupplierId=@supplier2;
SET @item='b0337196-2192-587d-ac1d-304a16c7e835';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-07-06',@VariantName=N'Cárdigan ligero L Negro',@CurrencyCode='NIO',@UnitPriceMinor=115000,@UnitCostMinor=51750,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000428',@SizeId='5A000000-0000-0000-0000-000000000503',@ColorId='5A000000-0000-0000-0000-000000000602',@SupplierId=@supplier2;
SET @product='08ef979f-3cdb-512e-aca0-45e0f9d7daf8';SET @event=NEWID();
EXEC catalog.usp_RegisterProduct @ProductId=@product,@Name=N'Accesorios de tela',@OriginNodeId=@node,@EventId=@event,@ActorId=@owner;
SET @item='7f3e723e-4ec9-5e34-a9fb-425bbbb8afc9';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-08-01',@VariantName=N'Accesorios de tela S Azul',@CurrencyCode='NIO',@UnitPriceMinor=115000,@UnitCostMinor=51750,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000435',@SizeId='5A000000-0000-0000-0000-000000000501',@ColorId='5A000000-0000-0000-0000-000000000603',@SupplierId=@supplier2;
SET @item='ed1b6642-4e69-5c86-bc10-f5e9b6bf0992';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-08-02',@VariantName=N'Accesorios de tela M Rosado',@CurrencyCode='NIO',@UnitPriceMinor=117000,@UnitCostMinor=52650,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000442',@SizeId='5A000000-0000-0000-0000-000000000502',@ColorId='5A000000-0000-0000-0000-000000000604',@SupplierId=@supplier2;
SET @item='cfb67e14-a23b-56e9-a26c-8e578370f556';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-08-03',@VariantName=N'Accesorios de tela L Beige',@CurrencyCode='NIO',@UnitPriceMinor=119000,@UnitCostMinor=53550,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000459',@SizeId='5A000000-0000-0000-0000-000000000503',@ColorId='5A000000-0000-0000-0000-000000000605',@SupplierId=@supplier2;
SET @item='9c7cfd92-daba-5e0a-8278-6b295ab90e7d';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-08-04',@VariantName=N'Accesorios de tela S Blanco',@CurrencyCode='NIO',@UnitPriceMinor=121000,@UnitCostMinor=54450,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000466',@SizeId='5A000000-0000-0000-0000-000000000501',@ColorId='5A000000-0000-0000-0000-000000000601',@SupplierId=@supplier2;
SET @item='7c7dc5a3-7e07-5b9e-b9ef-38d61b1b2add';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-08-05',@VariantName=N'Accesorios de tela M Negro',@CurrencyCode='NIO',@UnitPriceMinor=123000,@UnitCostMinor=55350,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000473',@SizeId='5A000000-0000-0000-0000-000000000502',@ColorId='5A000000-0000-0000-0000-000000000602',@SupplierId=@supplier2;
SET @item='9e7837a0-e1bb-59b7-aa23-8b0381a447d5';SET @event=NEWID();
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'MAS-EX-08-06',@VariantName=N'Accesorios de tela L Azul',@CurrencyCode='NIO',@UnitPriceMinor=125000,@UnitCostMinor=56250,@ItemId=@item,@OriginNodeId=@node,@EventId=@event,@ActorId=@owner,@Barcode=N'9901010000480',@SizeId='5A000000-0000-0000-0000-000000000503',@ColorId='5A000000-0000-0000-0000-000000000603',@SupplierId=@supplier2;
GO
