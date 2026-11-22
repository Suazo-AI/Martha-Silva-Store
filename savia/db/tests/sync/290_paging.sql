-- TEST: D-041 sync paging. A page holds at most @PageRows rows per table, ends at the first table that is not finished,
-- and is cut by bytes. The receiver keeps the pass (to, next page, resume keys) in its database, so a new process
-- continues it. A duplicate page is skipped, a skipped page is a gap (51852), a cursor moves only when its table is done.
-- A rebuild in pages keeps the recovery lock until its final page. A self-referencing row travels with its parent.
-- A foreign-key failure drops the pass, so the next plan starts again from a new version.
-- One database plays both nodes: sync.LocalNode is switched between A and the cloud.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@cloud uniqueidentifier=test.Id('nodeCloud'),
  @fork uniqueidentifier=(SELECT ForkGuid FROM sync.CurrentFork),
  @state nvarchar(max),@plan nvarchar(max),@b nvarchar(max),@b1 nvarchar(max),@rb1 nvarchar(max),@r nvarchar(max),@n bigint,@err int,@i int=0,
  @to bigint,@pages int,@more bit=1,@bad int=0,@id uniqueidentifier,@token uniqueidentifier,
  @child uniqueidentifier='00000000-0000-0000-0000-000000000001',@parent uniqueidentifier='00000000-0000-0000-0000-000000000002';
EXEC sync.usp_SetLocalNode @NodeId=@a;
WHILE @i<3 BEGIN SET @id=NEWID(); EXEC test.SeedSale @id,'A'; SET @i+=1; END;

-- Page 1 of A's push, 2 rows per table.
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_PlanJson @PeerNodeId=@a,@StateJson=@state,@Json=@plan OUTPUT;
SET @n=JSON_VALUE(@plan,'$.page'); EXEC test.AssertEq N'a fresh plan asks for page 1',1,@n;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_ReadBatch @TargetNodeId=@cloud,@PlanJson=@plan,@PageRows=2,@Json=@b1 OUTPUT;
SET @to=JSON_VALUE(@b1,'$.to');
SET @n=(SELECT MAX(x.n) FROM OPENJSON(@b1,'$.tables') t CROSS APPLY (SELECT COUNT(*) n FROM OPENJSON(t.value,'$.rows')) x);
EXEC test.AssertEq N'page 1: at most 2 rows per table',2,@n;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@b1,'$.tables') WITH (done bit) WHERE done=0);
EXEC test.AssertEq N'page 1: one table is not finished',1,@n;
SET @n=(SELECT COUNT(*) FROM OPENJSON(@b1,'$.tables') WITH (t sysname,done bit) x JOIN sync.SyncTables st ON st.TableName=x.t
        WHERE st.ApplyOrder>(SELECT s2.ApplyOrder FROM OPENJSON(@b1,'$.tables') WITH (t sysname,done bit) y
                             JOIN sync.SyncTables s2 ON s2.TableName=y.t WHERE y.done=0));
EXEC test.AssertEq N'page 1: no table after the unfinished one',0,@n;
SET @n=IIF(JSON_VALUE(@b1,'$.last')='false',1,0); EXEC test.AssertEq N'page 1 is not the last',1,@n;

UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@b1,@Json=@r OUTPUT;
SET @n=IIF(JSON_VALUE(@r,'$.more')='true',1,0); EXEC test.AssertEq N'page 1 applied: the pass stays open',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.PeerPasses WHERE PeerNodeId=@a AND NextPage=2 AND ToVersion=@to);
EXEC test.AssertEq N'the pass is stored with the next page',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.PeerCursors c JOIN OPENJSON(@b1,'$.tables') WITH (t sysname,done bit) x ON x.t=c.TableName
        WHERE c.PeerNodeId=@a AND x.done=0);
EXEC test.AssertEq N'the unfinished table has no cursor yet',0,@n;
SET @n=(SELECT COUNT(*) FROM sync.PeerCursors c JOIN OPENJSON(@b1,'$.tables') WITH (t sysname,done bit) x ON x.t=c.TableName
        WHERE c.PeerNodeId=@a AND x.done=1 AND c.[Version]=@to);
SET @i=(SELECT COUNT(*) FROM OPENJSON(@b1,'$.tables') WITH (done bit) WHERE done=1);
EXEC test.AssertEq N'every finished table has its cursor at the page version',@i,@n;

-- Duplicate page: nothing changes. A page after a missing one: gap.
SET @err=0;
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@b1,@Json=@r OUTPUT; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'duplicate page: no error',0,@err;
SET @n=JSON_VALUE(@r,'$.changed'); EXEC test.AssertEq N'duplicate page: 0 changes',0,@n;
SET @err=0; SET @b=JSON_MODIFY(@b1,'$.page',3);
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@b,@Json=@r OUTPUT; END TRY
BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'page 3 before page 2: gap',51852,@err;

-- A new process (nothing in memory) plans from the stored pass and finishes it.
SET @pages=1;
WHILE @more=1 AND @pages<100
BEGIN
  UPDATE sync.LocalNode SET NodeId=@a;
  EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
  UPDATE sync.LocalNode SET NodeId=@cloud;
  EXEC sync.usp_PlanJson @PeerNodeId=@a,@StateJson=@state,@Json=@plan OUTPUT;
  IF JSON_VALUE(@plan,'$.to')<>@to OR JSON_VALUE(@plan,'$.page')<>@pages+1 SET @bad+=1;
  UPDATE sync.LocalNode SET NodeId=@a;
  EXEC sync.usp_ReadBatch @TargetNodeId=@cloud,@PlanJson=@plan,@PageRows=2,@Json=@b OUTPUT;
  IF (SELECT MAX(x.n) FROM OPENJSON(@b,'$.tables') t CROSS APPLY (SELECT COUNT(*) n FROM OPENJSON(t.value,'$.rows')) x)>2
     OR (SELECT COUNT(*) FROM OPENJSON(@b,'$.tables') WITH (done bit) WHERE done=0)>1 SET @bad+=1;
  UPDATE sync.LocalNode SET NodeId=@cloud;
  EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@b,@Json=@r OUTPUT;
  SET @more=IIF(JSON_VALUE(@r,'$.more')='true',1,0);
  SET @pages+=1;
END;
EXEC test.AssertEq N'every continued page kept the version, the page order and the caps',0,@bad;
SET @n=IIF(@pages>2,1,0); EXEC test.AssertEq N'the push needed more than two pages',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.PeerCursors WHERE PeerNodeId=@a AND ForkGuid=@fork AND [Version]=@to);
EXEC test.AssertEq N'after the last page every cursor is at the pass version',39,@n;
SET @n=(SELECT COUNT(*) FROM sync.PeerPasses WHERE PeerNodeId=@a); EXEC test.AssertEq N'the finished pass is gone',0,@n;

-- Late page of a finished pass: skipped, no error.
SET @err=0;
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@b,@Json=@r OUTPUT; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'late page: no error',0,@err;
SET @n=JSON_VALUE(@r,'$.changed'); EXEC test.AssertEq N'late page: 0 changes',0,@n;
-- A late copy of page 1 must not open a pass again: its tables are already at its version.
EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@b1,@Json=@r OUTPUT;
SET @n=(SELECT COUNT(*) FROM sync.PeerPasses WHERE PeerNodeId=@a); EXEC test.AssertEq N'late page 1: no pass reopened',0,@n;
SET @n=IIF(JSON_VALUE(@r,'$.more')='true',1,0); EXEC test.AssertEq N'late page 1: nothing more to read',0,@n;

-- Bytes: a page stops adding tables at @PageBytes; one chunk that is too large is halved.
UPDATE sync.LocalNode SET NodeId=@a;
SET @i=0; WHILE @i<3 BEGIN SET @id=NEWID(); EXEC test.SeedSale @id,'A'; SET @i+=1; END;
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_PlanJson @PeerNodeId=@a,@StateJson=@state,@Json=@plan OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a;
EXEC sync.usp_ReadBatch @TargetNodeId=@cloud,@PlanJson=@plan,@PageBytes=1500,@Json=@b OUTPUT;
SET @n=(SELECT SUM(DATALENGTH(CAST(t.[rows] COLLATE Latin1_General_100_CI_AS_SC_UTF8 AS varchar(max))))
        FROM OPENJSON(@b,'$.tables') WITH ([rows] nvarchar(max) AS JSON) t WHERE t.[rows]<>N'[]');
SET @i=(SELECT COUNT(*) FROM OPENJSON(@b,'$.tables') WITH ([rows] nvarchar(max) AS JSON) t WHERE t.[rows]<>N'[]');
SET @n=IIF(@n<=1500 OR @i=1,1,0); EXEC test.AssertEq N'bytes: the page stays under the cap, or holds one chunk',1,@n;
SET @n=IIF(JSON_VALUE(@b,'$.last')='false',1,0); EXEC test.AssertEq N'bytes: the cut page is not the last',1,@n;
-- Finish that pass without caps.
SET @more=1;
WHILE @more=1
BEGIN
  UPDATE sync.LocalNode SET NodeId=@a; EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
  UPDATE sync.LocalNode SET NodeId=@cloud; EXEC sync.usp_PlanJson @PeerNodeId=@a,@StateJson=@state,@Json=@plan OUTPUT;
  UPDATE sync.LocalNode SET NodeId=@a; EXEC sync.usp_ReadBatch @TargetNodeId=@cloud,@PlanJson=@plan,@Json=@b OUTPUT;
  UPDATE sync.LocalNode SET NodeId=@cloud; EXEC sync.usp_ApplyBatch @PeerNodeId=@a,@BatchJson=@b,@Json=@r OUTPUT;
  SET @more=IIF(JSON_VALUE(@r,'$.more')='true',1,0);
END;

-- A child category whose key sorts before its parent's travels in the page of the parent.
UPDATE sync.LocalNode SET NodeId=@cloud;
INSERT catalog.Categories(Id,Name) VALUES(@parent,N'Padre paginado');
INSERT catalog.Categories(Id,ParentId,Name) VALUES(@child,@parent,N'Hija paginada');
SET @more=1; SET @pages=0; SET @bad=0; SET @i=0;
WHILE @more=1 AND @pages<300
BEGIN
  UPDATE sync.LocalNode SET NodeId=@cloud; EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
  UPDATE sync.LocalNode SET NodeId=@a; EXEC sync.usp_PlanJson @PeerNodeId=@cloud,@StateJson=@state,@Json=@plan OUTPUT;
  UPDATE sync.LocalNode SET NodeId=@cloud; EXEC sync.usp_ReadBatch @TargetNodeId=@a,@PlanJson=@plan,@PageRows=1,@Json=@b OUTPUT;
  SET @n=(SELECT SUM(IIF(r.Id=@child,1,2)) FROM OPENJSON(@b,'$.tables') WITH (t sysname,[rows] nvarchar(max) AS JSON) t
          CROSS APPLY OPENJSON(t.[rows]) WITH (Id uniqueidentifier) r WHERE t.t=N'[catalog].[Categories]' AND r.Id IN (@child,@parent));
  IF @n=1 SET @bad+=1;   -- the child alone
  IF @n=3 SET @i=1;
  UPDATE sync.LocalNode SET NodeId=@a; EXEC sync.usp_ApplyBatch @PeerNodeId=@cloud,@BatchJson=@b,@Json=@r OUTPUT;
  SET @more=IIF(JSON_VALUE(@r,'$.more')='true',1,0);
  SET @pages+=1;
END;
EXEC test.AssertEq N'the child category travels in the page of its parent',1,@i;
EXEC test.AssertEq N'no page holds the child without its parent',0,@bad;

-- A foreign-key failure drops the pass: the next plan starts at page 1 from a new version.
UPDATE sync.LocalNode SET NodeId=@cloud;
INSERT catalog.Categories(Name) VALUES(N'Otra 1'),(N'Otra 2');
EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a; EXEC sync.usp_PlanJson @PeerNodeId=@cloud,@StateJson=@state,@Json=@plan OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud; EXEC sync.usp_ReadBatch @TargetNodeId=@a,@PlanJson=@plan,@PageRows=1,@Json=@b OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a; EXEC sync.usp_ApplyBatch @PeerNodeId=@cloud,@BatchJson=@b,@Json=@r OUTPUT;
SET @n=(SELECT COUNT(*) FROM sync.PeerPasses WHERE PeerNodeId=@cloud); EXEC test.AssertEq N'the pull pass is open',1,@n;
SET @b=JSON_MODIFY(JSON_MODIFY(@b,'$.page',2),'$.tables',JSON_QUERY(N'[{"t":"[catalog].[Categories]","a":"incremental","f":'
  +(SELECT CONVERT(nvarchar(20),[Version]) FROM sync.PeerCursors WHERE PeerNodeId=@cloud AND TableName=N'[catalog].[Categories]')
  +N',"k":null,"done":true,"rows":[{"Id":"'+CONVERT(nvarchar(36),NEWID())+N'","ParentId":"'+CONVERT(nvarchar(36),NEWID())
  +N'","Name":"Huerfana","IsActive":true,"CreatedAt":"2026-11-22T00:00:00"}]}]'));
SET @err=0;
BEGIN TRY EXEC sync.usp_ApplyBatch @PeerNodeId=@cloud,@BatchJson=@b,@Json=@r OUTPUT; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'a row whose parent is missing is refused',547,@err;
SET @n=(SELECT COUNT(*) FROM sync.PeerPasses WHERE PeerNodeId=@cloud); EXEC test.AssertEq N'the refused page dropped the pass',0,@n;
UPDATE sync.LocalNode SET NodeId=@cloud; EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a; EXEC sync.usp_PlanJson @PeerNodeId=@cloud,@StateJson=@state,@Json=@plan OUTPUT;
SET @n=JSON_VALUE(@plan,'$.page'); EXEC test.AssertEq N'the next plan starts at page 1',1,@n;

-- A row the branch applies carries the sync context in change tracking, so the branch push skips it without the owner
-- subquery (S5: after a large pull the push read paid that subquery on every pulled change).
DECLARE @synced uniqueidentifier=NEWID();
UPDATE sync.LocalNode SET NodeId=@cloud; EXEC sync.usp_ReadBatch @TargetNodeId=@a,@PlanJson=@plan,@Json=@b OUTPUT;
SET @b=JSON_MODIFY(JSON_MODIFY(@b,'$.last',CAST(1 AS bit)),'$.tables',JSON_QUERY(N'[{"t":"[catalog].[Categories]","a":"incremental","f":'
  +(SELECT CONVERT(nvarchar(20),[Version]) FROM sync.PeerCursors WHERE PeerNodeId=@cloud AND TableName=N'[catalog].[Categories]')
  +N',"k":null,"done":true,"rows":[{"Id":"'+CONVERT(nvarchar(36),@synced)+N'","ParentId":"'+CONVERT(nvarchar(36),@parent)
  +N'","Name":"Aplicada","IsActive":true,"CreatedAt":"2026-11-22T00:00:00"}]}]'));
UPDATE sync.LocalNode SET NodeId=@a; EXEC sync.usp_ApplyBatch @PeerNodeId=@cloud,@BatchJson=@b,@Json=@r OUTPUT;
SET @n=(SELECT COUNT(*) FROM catalog.Categories WHERE Id=@synced); EXEC test.AssertEq N'the crafted pull row is applied',1,@n;
SET @n=(SELECT COUNT(*) FROM CHANGETABLE(CHANGES catalog.Categories,0) ct
        WHERE ct.Id=@synced AND ct.SYS_CHANGE_CONTEXT=CONVERT(varbinary(128),'savia.sync'));
EXEC test.AssertEq N'an applied row carries the sync context',1,@n;

-- Rebuild in pages: the lock holds until the final page, and a new process continues the rebuild.
UPDATE sync.LocalNode SET NodeId=@a;
UPDATE sync.LocalNode SET ForkGuid=NEWID();   -- the state a restore leaves (test 250)
SET @n=sync.fn_Recovering(); EXEC test.AssertEq N'A is recovering',1,@n;
UPDATE sync.LocalNode SET NodeId=@cloud; EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a; EXEC sync.usp_PlanJson @PeerNodeId=@cloud,@StateJson=@state,@Mode='rebuild',@Json=@plan OUTPUT;
UPDATE sync.LocalNode SET NodeId=@cloud;
EXEC sync.usp_ReadBatch @TargetNodeId=@a,@PlanJson=@plan,@TargetForkGuid=@fork,@PageRows=2,@Json=@b OUTPUT;
SET @token=JSON_VALUE(@b,'$.rebuild'); SET @rb1=@b;
UPDATE sync.LocalNode SET NodeId=@a; EXEC sync.usp_ApplyBatch @PeerNodeId=@cloud,@BatchJson=@b,@Json=@r OUTPUT;
SET @n=sync.fn_Recovering(); EXEC test.AssertEq N'rebuild page 1: still recovering',1,@n;
SET @n=(SELECT COUNT(*) FROM sync.AppliedRebuilds WHERE PeerNodeId=@cloud AND ForkGuid=@fork AND Token=@token);
EXEC test.AssertEq N'rebuild page 1: no applied rebuild yet',0,@n;
SET @n=JSON_VALUE(@r,'$.total'); EXEC test.AssertEq N'progress: total tables',39,@n;
SET @more=1; SET @pages=1; SET @bad=0;
WHILE @more=1 AND @pages<400
BEGIN
  UPDATE sync.LocalNode SET NodeId=@cloud; EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
  UPDATE sync.LocalNode SET NodeId=@a; EXEC sync.usp_PlanJson @PeerNodeId=@cloud,@StateJson=@state,@Json=@plan OUTPUT;
  IF ISNULL(JSON_VALUE(@plan,'$.mode'),'')<>'rebuild' OR JSON_VALUE(@plan,'$.rebuild')<>@token SET @bad+=1;
  IF @more=1 AND sync.fn_Recovering()=0 SET @bad+=1;
  UPDATE sync.LocalNode SET NodeId=@cloud;
  EXEC sync.usp_ReadBatch @TargetNodeId=@a,@PlanJson=@plan,@TargetForkGuid=@fork,@PageRows=2,@Json=@b OUTPUT;
  UPDATE sync.LocalNode SET NodeId=@a; EXEC sync.usp_ApplyBatch @PeerNodeId=@cloud,@BatchJson=@b,@Json=@r OUTPUT;
  SET @more=IIF(JSON_VALUE(@r,'$.more')='true',1,0);
  SET @pages+=1;
END;
EXEC test.AssertEq N'a normal plan continues the open rebuild with its token, locked until the end',0,@bad;
SET @n=sync.fn_Recovering(); EXEC test.AssertEq N'the final rebuild page lifts the lock',0,@n;
SET @n=(SELECT COUNT(*) FROM sync.AppliedRebuilds WHERE PeerNodeId=@cloud AND ForkGuid=@fork AND Token=@token);
EXEC test.AssertEq N'the final page records the rebuild',1,@n;
SET @n=JSON_VALUE(@r,'$.done'); EXEC test.AssertEq N'progress: every table done',39,@n;
-- A late copy of rebuild page 1 must not reopen the finished rebuild.
UPDATE sync.LocalNode SET NodeId=@a; EXEC sync.usp_ApplyBatch @PeerNodeId=@cloud,@BatchJson=@rb1,@Json=@r OUTPUT;
SET @n=(SELECT COUNT(*) FROM sync.PeerPasses WHERE PeerNodeId=@cloud); EXEC test.AssertEq N'late rebuild page 1: no pass reopened',0,@n;
SET @n=JSON_VALUE(@r,'$.changed'); EXEC test.AssertEq N'late rebuild page 1: 0 changes',0,@n;
UPDATE sync.LocalNode SET NodeId=@cloud; EXEC sync.usp_SourceStateJson @Json=@state OUTPUT;
UPDATE sync.LocalNode SET NodeId=@a; EXEC sync.usp_PlanJson @PeerNodeId=@cloud,@StateJson=@state,@Json=@plan OUTPUT;
SET @n=IIF(JSON_VALUE(@plan,'$.mode')='normal' AND JSON_VALUE(@plan,'$.page')='1',1,0);
EXEC test.AssertEq N'after the late rebuild page the next plan is a fresh normal one',1,@n;
PRINT 'PASS';
