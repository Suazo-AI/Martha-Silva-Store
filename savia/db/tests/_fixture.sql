/* SAVIA test fixture. Applied once to the template database that every test clones.
   One database stands for one node that knows the whole topology:
   1 cloud node and 3 branches (A, B, C), each with one store location and one register.
   Look up ids by name:  DECLARE @x uniqueidentifier = test.Id('branchA');
   EXEC arguments cannot be expressions, so always copy ids into variables first. */
SET NOCOUNT ON; SET XACT_ABORT ON;
GO
CREATE SCHEMA [test] AUTHORIZATION [dbo];
GO
CREATE TABLE test.Ids(Name varchar(40) NOT NULL PRIMARY KEY, Id uniqueidentifier NOT NULL UNIQUE);
GO
CREATE FUNCTION test.Id(@Name varchar(40)) RETURNS uniqueidentifier
AS BEGIN RETURN (SELECT Id FROM test.Ids WHERE Name=@Name); END;
GO
/* test.AssertEq: fail the test with a readable message when two numbers differ. */
CREATE PROCEDURE test.AssertEq @What nvarchar(200), @Expected bigint, @Actual bigint
AS BEGIN
  IF @Expected=@Actual OR (@Expected IS NULL AND @Actual IS NULL) RETURN;
  DECLARE @msg nvarchar(600)=CONCAT(N'ASSERT FAIL: ',@What,N' expected=',COALESCE(CONVERT(nvarchar(30),@Expected),N'NULL'),
      N' actual=',COALESCE(CONVERT(nvarchar(30),@Actual),N'NULL'));
  THROW 59001,@msg,1;
END;
GO
INSERT INTO test.Ids(Name,Id) VALUES
 ('branchA','A0000000-0000-0000-0000-00000000000A'),('branchB','B0000000-0000-0000-0000-00000000000B'),
 ('branchC','C0000000-0000-0000-0000-00000000000C'),
 ('locA','A0000000-0000-0000-0000-0000000000A1'),('locB','B0000000-0000-0000-0000-0000000000B1'),
 ('locC','C0000000-0000-0000-0000-0000000000C1'),
 ('nodeCloud','00000000-0000-0000-0000-0000000C10D0'),
 ('nodeA','A0000000-0000-0000-0000-0000000000A2'),('nodeB','B0000000-0000-0000-0000-0000000000B2'),
 ('nodeC','C0000000-0000-0000-0000-0000000000C2'),
 ('registerA','A0000000-0000-0000-0000-0000000000A3'),('registerB','B0000000-0000-0000-0000-0000000000B3'),
 ('registerC','C0000000-0000-0000-0000-0000000000C3'),
 ('cashierA','A0000000-0000-0000-0000-0000000000A4'),('cashierB','B0000000-0000-0000-0000-0000000000B4'),
 ('cashierC','C0000000-0000-0000-0000-0000000000C4'),
 ('supervisorA','A0000000-0000-0000-0000-0000000000A5'),('supervisorB','B0000000-0000-0000-0000-0000000000B5'),
 ('supervisorC','C0000000-0000-0000-0000-0000000000C5'),
 ('manager','00000000-0000-0000-0000-00000000AD01'),
 ('supplier','00000000-0000-0000-0000-0000000050A1'),('supplier2','00000000-0000-0000-0000-0000000050A2'),
 ('customer','00000000-0000-0000-0000-00000000C051'),('customer2','00000000-0000-0000-0000-00000000C052'),
 ('product','00000000-0000-0000-0000-00000000B001'),
 ('sizeS','00000000-0000-0000-0000-000000005121'),('sizeM','00000000-0000-0000-0000-000000005122'),
 ('sizeL','00000000-0000-0000-0000-000000005123'),
 ('colorBlack','00000000-0000-0000-0000-00000000C0B1'),('colorWhite','00000000-0000-0000-0000-00000000C0B2'),
 ('colorRed','00000000-0000-0000-0000-00000000C0B3'),
 ('item','00000000-0000-0000-0000-0000000017E1'),      -- active, price 120000, cost 60000, barcode 0000123456789
 ('item2','00000000-0000-0000-0000-0000000017E2'),     -- active, price 85000, cost 40000, tax 15%
 ('itemDraft','00000000-0000-0000-0000-0000000017E3'); -- draft: no cost approved yet
GO
INSERT INTO core.Branches(Id,Code,Name,StoreDisplayName) VALUES
 (test.Id('branchA'),'T_A',N'Sucursal A',N'SAVIA Test'),(test.Id('branchB'),'T_B',N'Sucursal B',N'SAVIA Test'),
 (test.Id('branchC'),'T_C',N'Sucursal C',N'SAVIA Test');
INSERT INTO core.Locations(Id,BranchId,Code,Name,Kind) VALUES
 (test.Id('locA'),test.Id('branchA'),'T_LOC_A',N'Tienda A','store'),
 (test.Id('locB'),test.Id('branchB'),'T_LOC_B',N'Tienda B','store'),
 (test.Id('locC'),test.Id('branchC'),'T_LOC_C',N'Tienda C','store');
INSERT INTO sync.Nodes(Id,BranchId,NodeCode,Kind) VALUES
 (test.Id('nodeCloud'),NULL,N'T_CLOUD','azure'),
 (test.Id('nodeA'),test.Id('branchA'),N'T_NODE_A','branch'),
 (test.Id('nodeB'),test.Id('branchB'),N'T_NODE_B','branch'),
 (test.Id('nodeC'),test.Id('branchC'),N'T_NODE_C','branch');
INSERT INTO security.Staff(Id,LoginName,NormalizedLoginName,DisplayName) VALUES
 (test.Id('cashierA'),N't_cashier_a',N'T_CASHIER_A',N'Cajera A'),
 (test.Id('cashierB'),N't_cashier_b',N'T_CASHIER_B',N'Cajera B'),
 (test.Id('cashierC'),N't_cashier_c',N'T_CASHIER_C',N'Cajera C'),
 (test.Id('supervisorA'),N't_super_a',N'T_SUPER_A',N'Supervisora A'),
 (test.Id('supervisorB'),N't_super_b',N'T_SUPER_B',N'Supervisora B'),
 (test.Id('supervisorC'),N't_super_c',N'T_SUPER_C',N'Supervisora C'),
 (test.Id('manager'),N't_manager',N'T_MANAGER',N'Gerente');
INSERT INTO security.StaffBranchAccess(StaffId,BranchId,CanApproveTransfers,CanApproveReturns) VALUES
 (test.Id('cashierA'),test.Id('branchA'),0,0),(test.Id('cashierB'),test.Id('branchB'),0,0),
 (test.Id('cashierC'),test.Id('branchC'),0,0),
 (test.Id('supervisorA'),test.Id('branchA'),1,1),(test.Id('supervisorB'),test.Id('branchB'),1,1),
 (test.Id('supervisorC'),test.Id('branchC'),1,1),
 (test.Id('manager'),test.Id('branchA'),1,1),(test.Id('manager'),test.Id('branchB'),1,1),
 (test.Id('manager'),test.Id('branchC'),1,1);
INSERT INTO sourcing.Suppliers(Id,DisplayName) VALUES
 (test.Id('supplier'),N'Proveedor Test'),(test.Id('supplier2'),N'Proveedor Test 2');
INSERT INTO crm.Customers(Id,DisplayName,Email) VALUES
 (test.Id('customer'),N'Clienta Test',N'clienta@example.test'),
 (test.Id('customer2'),N'Clienta Test 2',N'clienta2@example.test');
-- A product may hold only one variant per (size, color): UQ_Items_Product_Variant treats NULLs as equal.
INSERT INTO catalog.Sizes(Id,Code,Name,SortOrder) VALUES
 (test.Id('sizeS'),N'S',N'Small',1),(test.Id('sizeM'),N'M',N'Medium',2),(test.Id('sizeL'),N'L',N'Large',3);
INSERT INTO catalog.Colors(Id,Code,Name) VALUES
 (test.Id('colorBlack'),N'NEG',N'Negro'),(test.Id('colorWhite'),N'BLA',N'Blanco'),(test.Id('colorRed'),N'ROJ',N'Rojo');
INSERT INTO sales.CashRegisters(Id,BranchId,LocationId,Code,Name) VALUES
 (test.Id('registerA'),test.Id('branchA'),test.Id('locA'),N'CAJA1',N'Caja A'),
 (test.Id('registerB'),test.Id('branchB'),test.Id('locB'),N'CAJA1',N'Caja B'),
 (test.Id('registerC'),test.Id('branchC'),test.Id('locC'),N'CAJA1',N'Caja C');
GO
DECLARE @product uniqueidentifier=test.Id('product'),@item uniqueidentifier=test.Id('item'),
  @item2 uniqueidentifier=test.Id('item2'),@draft uniqueidentifier=test.Id('itemDraft'),
  @supplier uniqueidentifier=test.Id('supplier'),@actor uniqueidentifier=test.Id('manager'),
  @node uniqueidentifier=test.Id('nodeA'),@e1 uniqueidentifier=NEWID(),@e2 uniqueidentifier=NEWID(),
  @e3 uniqueidentifier=NEWID(),@e4 uniqueidentifier=NEWID(),
  @sS uniqueidentifier=test.Id('sizeS'),@sM uniqueidentifier=test.Id('sizeM'),@sL uniqueidentifier=test.Id('sizeL'),
  @cB uniqueidentifier=test.Id('colorBlack'),@cW uniqueidentifier=test.Id('colorWhite'),@cR uniqueidentifier=test.Id('colorRed');
EXEC catalog.usp_RegisterProduct @ProductId=@product,@Name=N'Blusa Test',@ActorId=@actor,@OriginNodeId=@node,@EventId=@e1;
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-SKU-0001',@VariantName=N'Blusa Negra M',
  @CurrencyCode='NIO',@UnitPriceMinor=120000,@UnitCostMinor=60000,@Barcode=N'0000123456789',@SizeId=@sM,@ColorId=@cB,
  @SupplierId=@supplier,@SupplierSku=N'PROV-0001',@ActorId=@actor,@ItemId=@item,@OriginNodeId=@node,@EventId=@e2;
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-SKU-0002',@VariantName=N'Blusa Blanca S',
  @CurrencyCode='NIO',@UnitPriceMinor=85000,@UnitCostMinor=40000,@Barcode=N'0000987654321',@SizeId=@sS,@ColorId=@cW,
  @ActorId=@actor,@ItemId=@item2,@OriginNodeId=@node,@EventId=@e3;
UPDATE catalog.Items SET TaxRateBps=1500 WHERE Id=@item2;
EXEC catalog.usp_RegisterItem @ProductId=@product,@Sku=N'T-SKU-0003',@VariantName=N'Blusa Roja L (sin costo)',
  @CurrencyCode='NIO',@UnitPriceMinor=90000,@Barcode=N'0000555000111',@SizeId=@sL,@ColorId=@cR,
  @ActorId=@actor,@ItemId=@draft,@OriginNodeId=@node,@EventId=@e4;
GO
/* test.SeedStock: put @Quantity units of an item into a location's store pool through the
   real reception flow (scan session -> approve -> post). Uses node A as the origin node. */
CREATE PROCEDURE test.SeedStock @ItemId uniqueidentifier,@LocationId uniqueidentifier,@Quantity int
AS BEGIN
  SET NOCOUNT ON;
  DECLARE @container uniqueidentifier=NEWID(),@session uniqueidentifier=NEWID(),@scan uniqueidentifier=NEWID(),
    @supplier uniqueidentifier=test.Id('supplier'),@actor uniqueidentifier=test.Id('manager'),
    @node uniqueidentifier=test.Id('nodeA'),@receipt uniqueidentifier,@code nvarchar(128);
  SELECT TOP(1) @code=RawCode FROM catalog.ItemIdentifiers WHERE ItemId=@ItemId AND Kind='barcode' AND IsActive=1;
  INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
    VALUES(@container,CONCAT(N'T-SEED-',CONVERT(nvarchar(36),@container)),@supplier,@LocationId,'counting',@actor);
  INSERT INTO receiving.ScanSessions(Id,ContainerId,Status,CreatedBy) VALUES(@session,@container,'counting',@actor);
  DECLARE @sink TABLE(a uniqueidentifier,b uniqueidentifier,c varchar(16),d int);
  INSERT INTO @sink EXEC receiving.usp_RecordScan @scan,@session,@code,@Quantity,NULL,@actor;
  EXEC receiving.usp_ApproveScanSession @session,@actor;
  EXEC receiving.usp_PostScanSession @ScanSessionId=@session,@ActorId=@actor,@OriginNodeId=@node,
       @CurrencyCode='NIO',@ReceiptId=@receipt OUTPUT;
END;
GO
/* Roles by code (ids are fixed since V002): cashiers sell, supervisors manage their branch, the manager owns. */
INSERT INTO security.StaffRoles(StaffId,RoleId,AssignedAt)
SELECT i.Id,r.Id,SYSUTCDATETIME() FROM test.Ids i JOIN security.Roles r ON r.Code=
  CASE WHEN i.Name LIKE 'cashier%' THEN 'CASHIER' WHEN i.Name LIKE 'supervisor%' THEN 'MANAGER' ELSE 'OWNER' END
WHERE i.Name LIKE 'cashier%' OR i.Name LIKE 'supervisor%' OR i.Name='manager';
GO
