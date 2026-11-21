-- Reproduced: ScanLockOrderTests deadlocks with 1205 before this change.
-- All receiving mutations lock the session before touching child scan keys.
CREATE OR ALTER PROCEDURE [receiving].[usp_RecordScan]
 @ScanId uniqueidentifier,@ScanSessionId uniqueidentifier,@RawCode nvarchar(128),
 @Quantity int=1,@DeviceCode nvarchar(80)=NULL,@ActorId uniqueidentifier=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @Quantity NOT BETWEEN 1 AND 10000 OR LEN(LTRIM(RTRIM(@RawCode)))=0
   THROW 51301,'Lectura invalida.',1;
 DECLARE @ownTran bit=0;
 IF @@TRANCOUNT=0 BEGIN SET @ownTran=1; BEGIN TRANSACTION; END;
 BEGIN TRY
   DECLARE @supplier uniqueidentifier,@status varchar(16),@matched uniqueidentifier=NULL,@matches int;
   SELECT @supplier=c.SupplierId,@status=s.Status FROM receiving.ScanSessions s WITH(UPDLOCK,HOLDLOCK)
     JOIN receiving.ImportContainers c ON c.Id=s.ContainerId WHERE s.Id=@ScanSessionId;
   IF EXISTS(SELECT 1 FROM receiving.ScanEvents WITH(UPDLOCK,HOLDLOCK) WHERE Id=@ScanId)
   BEGIN
     IF EXISTS(SELECT 1 FROM receiving.ScanEvents WHERE Id=@ScanId AND
         (ScanSessionId<>@ScanSessionId OR RawCode<>@RawCode OR Quantity<>@Quantity))
       THROW 51302,'ScanId repetido con contenido distinto.',1;
     SELECT Id AS ScanId,ItemId,MatchStatus,Quantity FROM receiving.ScanEvents WHERE Id=@ScanId;
     IF @ownTran=1 COMMIT;
     RETURN;
   END;
   IF @status IS NULL OR @status<>'counting' THROW 51303,'Sesion de escaneo no abierta.',1;
   DECLARE @candidates TABLE(ItemId uniqueidentifier PRIMARY KEY);
   INSERT INTO @candidates(ItemId)
    SELECT DISTINCT ItemId FROM catalog.ItemIdentifiers
      WHERE RawCode=@RawCode AND IsActive=1 AND
         ((Kind='barcode' AND SupplierId IS NULL)
          OR (SupplierId=@supplier AND Kind IN ('supplier_sku','barcode','alias'))
          OR (Kind='alias' AND SupplierId IS NULL));
   SELECT @matches=COUNT(*),@matched=MIN(ItemId) FROM @candidates;
   SET @status=CASE WHEN @matches=0 THEN 'unknown' WHEN @matches=1 THEN 'matched' ELSE 'ambiguous' END;
   INSERT INTO receiving.ScanEvents(Id,ScanSessionId,ItemId,RawCode,Quantity,MatchStatus,DeviceCode,CreatedBy)
     VALUES(@ScanId,@ScanSessionId,CASE WHEN @matches=1 THEN @matched ELSE NULL END,
            @RawCode,@Quantity,@status,@DeviceCode,@ActorId);
   SELECT @ScanId AS ScanId,CASE WHEN @matches=1 THEN @matched ELSE NULL END AS ItemId,@status AS MatchStatus,@Quantity AS Quantity;
   IF @ownTran=1 COMMIT;
 END TRY
 BEGIN CATCH IF @ownTran=1 AND @@TRANCOUNT>0 ROLLBACK; THROW; END CATCH;
END;
GO
