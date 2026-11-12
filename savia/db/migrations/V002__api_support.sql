/* SAVIA V002: objects the API needs. Additive; run after V001 on a database with no staff roles yet.
   - F-010: role ids were random per database (NEWID), so two nodes never agreed on a role id.
   - Sessions store only a hash of the bearer token.
   - Entity creation that had no procedure (scan session, cash count) gets one, so the API never
     writes operational tables directly (ADR-001 D2). */
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO
SET NOCOUNT ON; SET XACT_ABORT ON;
IF EXISTS(SELECT 1 FROM security.StaffRoles)
  THROW 54001,'V002: se esperaba una base sin roles asignados; migrar ids de rol con conciliacion.',1;
BEGIN TRANSACTION;
DELETE FROM security.Roles;
INSERT INTO security.Roles(Id,Code,Description) VALUES
 ('0A000000-0000-0000-0000-000000000001','OWNER',N'Propietario del negocio'),
 ('0A000000-0000-0000-0000-000000000002','MANAGER',N'Gerente autorizado'),
 ('0A000000-0000-0000-0000-000000000003','CASHIER',N'Cajero'),
 ('0A000000-0000-0000-0000-000000000004','INVENTORY',N'Inventario'),
 ('0A000000-0000-0000-0000-000000000005','ACCOUNTANT',N'Contador');
COMMIT;
GO
ALTER TABLE security.Sessions ADD TokenHash varbinary(32) NULL;
GO
CREATE UNIQUE INDEX UX_Sessions_TokenHash ON security.Sessions(TokenHash) WHERE TokenHash IS NOT NULL;
GO

/* Open a container count. Idempotent by ScanSessionId. The container is created on first use. */
CREATE OR ALTER PROCEDURE [receiving].[usp_OpenScanSession]
 @ContainerId uniqueidentifier,@ScanSessionId uniqueidentifier,@Reference nvarchar(100),
 @SupplierId uniqueidentifier,@LocationId uniqueidentifier,@ActorId uniqueidentifier,
 @DeviceCode nvarchar(80)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Reference IS NULL OR LEN(LTRIM(RTRIM(@Reference)))=0 THROW 51320,'Referencia de contenedor obligatoria.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM receiving.ScanSessions WITH(UPDLOCK,HOLDLOCK) WHERE Id=@ScanSessionId)
   BEGIN
     IF NOT EXISTS(SELECT 1 FROM receiving.ScanSessions WHERE Id=@ScanSessionId AND ContainerId=@ContainerId)
       THROW 51321,'ScanSessionId reutilizado con otro contenedor.',1;
     COMMIT; RETURN;
   END;
   IF NOT EXISTS(SELECT 1 FROM core.Locations WHERE Id=@LocationId AND IsActive=1)
     THROW 51322,'Ubicacion inexistente o inactiva.',1;
   IF NOT EXISTS(SELECT 1 FROM sourcing.Suppliers WHERE Id=@SupplierId AND IsActive=1)
     THROW 51323,'Proveedor inexistente o inactivo.',1;
   IF NOT EXISTS(SELECT 1 FROM receiving.ImportContainers WITH(UPDLOCK,HOLDLOCK) WHERE Id=@ContainerId)
     INSERT INTO receiving.ImportContainers(Id,Reference,SupplierId,LocationId,Status,CreatedBy)
       VALUES(@ContainerId,@Reference,@SupplierId,@LocationId,'counting',@ActorId);
   ELSE IF NOT EXISTS(SELECT 1 FROM receiving.ImportContainers WHERE Id=@ContainerId
        AND SupplierId=@SupplierId AND LocationId=@LocationId AND Status IN ('open','counting'))
     THROW 51324,'El contenedor no coincide o ya no admite conteo.',1;
   INSERT INTO receiving.ScanSessions(Id,ContainerId,DeviceCode,Status,CreatedBy)
     VALUES(@ScanSessionId,@ContainerId,@DeviceCode,'counting',@ActorId);
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO

/* Record and submit a cash count in one step. Idempotent by CashCountId.
   @LinesJson: [{"denominationMinor":100000,"quantity":3}, ...] */
CREATE OR ALTER PROCEDURE [sales].[usp_RecordCashCount]
 @CashCountId uniqueidentifier,@TillId uniqueidentifier,@ActorId uniqueidentifier,@LinesJson nvarchar(max)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF ISJSON(@LinesJson)<>1 THROW 51540,'Arqueo: lineas con formato invalido.',1;
 DECLARE @lines TABLE(DenominationMinor bigint NULL,Quantity int NULL);
 INSERT INTO @lines(DenominationMinor,Quantity)
   SELECT denominationMinor,quantity FROM OPENJSON(@LinesJson)
     WITH (denominationMinor bigint '$.denominationMinor', quantity int '$.quantity');
 IF NOT EXISTS(SELECT 1 FROM @lines) OR EXISTS(SELECT 1 FROM @lines
      WHERE DenominationMinor IS NULL OR Quantity IS NULL OR DenominationMinor<=0 OR Quantity<0)
   THROW 51541,'Arqueo: cada linea necesita denominacion mayor a cero y cantidad no negativa.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
   IF EXISTS(SELECT 1 FROM sales.CashCounts WITH(UPDLOCK,HOLDLOCK) WHERE Id=@CashCountId)
   BEGIN
     IF NOT EXISTS(SELECT 1 FROM sales.CashCounts WHERE Id=@CashCountId AND TillId=@TillId)
       THROW 51542,'CashCountId reutilizado con otro turno.',1;
     COMMIT; RETURN;
   END;
   IF NOT EXISTS(SELECT 1 FROM sales.CashTills WHERE Id=@TillId AND Status='open')
     THROW 51543,'Turno de caja inexistente o cerrado.',1;
   INSERT INTO sales.CashCounts(Id,TillId,CountedBy,Status,CreatedBy)
     VALUES(@CashCountId,@TillId,@ActorId,'draft',@ActorId);
   INSERT INTO sales.CashCountLines(CashCountId,DenominationMinor,Quantity)
     SELECT @CashCountId,DenominationMinor,SUM(Quantity) FROM @lines GROUP BY DenominationMinor;
   EXEC sales.usp_SubmitCashCount @CashCountId=@CashCountId,@ActorId=@ActorId;
   COMMIT;
 END TRY
 BEGIN CATCH IF @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO
GRANT EXECUTE ON OBJECT::[receiving].[usp_OpenScanSession] TO [savia_inventory_app];
GRANT EXECUTE ON OBJECT::[sales].[usp_RecordCashCount] TO [savia_pos_app];
GO
