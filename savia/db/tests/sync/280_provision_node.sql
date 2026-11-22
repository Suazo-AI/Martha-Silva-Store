-- TEST: D-040 node provisioning (V054). sync.usp_ProvisionNode registers a node once with fixed id, kind, branch and code;
-- a retry is a no-op; a different definition of an id or code, a second hub node or a second node on one branch is
-- refused. A credential exists only as a hash and a revoked node is no longer found by the hub's credential lookup.
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @a uniqueidentifier=test.Id('nodeA'),@cloud uniqueidentifier=test.Id('nodeCloud'),@branchA uniqueidentifier=test.Id('branchA'),
  @branchB uniqueidentifier=test.Id('branchB'),@branchD uniqueidentifier=NEWID(),@new uniqueidentifier=NEWID(),@n bigint,@err int;
DECLARE @found TABLE(h binary(32));

-- A store without a node yet (branches are provisioned on every database, like the fixture's three).
INSERT core.Branches(Id,Code,Name,StoreDisplayName) VALUES(@branchD,'T_D',N'Sucursal D',N'SAVIA Test');

EXEC sync.usp_ProvisionNode @NodeId=@a,@Kind='branch',@BranchId=@branchA,@NodeCode=N'T_NODE_A';
EXEC sync.usp_ProvisionNode @NodeId=@cloud,@Kind='azure',@BranchId=NULL,@NodeCode=N'T_CLOUD';
SET @n=(SELECT COUNT(*) FROM sync.Nodes WHERE Id IN (@a,@cloud)); EXEC test.AssertEq N'existing identical nodes are a no-op',2,@n;
SET @err=0;
BEGIN TRY EXEC sync.usp_ProvisionNode @NodeId=@a,@Kind='branch',@BranchId=@branchB,@NodeCode=N'T_NODE_A'; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'the same node id with another branch is refused',51865,@err;
SET @err=0;
BEGIN TRY EXEC sync.usp_ProvisionNode @NodeId=@new,@Kind='branch',@BranchId=@branchA,@NodeCode=N'T_NODE_A'; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'a second node with the same code is refused',51865,@err;
SET @err=0;
BEGIN TRY EXEC sync.usp_ProvisionNode @NodeId=@new,@Kind='azure',@BranchId=@branchD,@NodeCode=N'T_NEW'; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'a hub node has no branch',51865,@err;
SET @err=0;
BEGIN TRY EXEC sync.usp_ProvisionNode @NodeId=@new,@Kind='azure',@BranchId=NULL,@NodeCode=N'T_HUB2'; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'a second hub node is refused',51865,@err;
SET @err=0;
BEGIN TRY EXEC sync.usp_ProvisionNode @NodeId=@new,@Kind='branch',@BranchId=@branchA,@NodeCode=N'T_NODE_A2'; END TRY BEGIN CATCH SET @err=ERROR_NUMBER(); END CATCH;
EXEC test.AssertEq N'a second node on one branch is refused',51865,@err;

EXEC sync.usp_ProvisionNode @NodeId=@new,@Kind='branch',@BranchId=@branchD,@NodeCode=N'T_NODE_D';
EXEC sync.usp_ProvisionNode @NodeId=@new,@Kind='branch',@BranchId=@branchD,@NodeCode=N'T_NODE_D';
SET @n=(SELECT COUNT(*) FROM sync.Nodes WHERE Id=@new AND Kind='branch' AND BranchId=@branchD AND IsEnabled=1);
EXEC test.AssertEq N'a new node is created once and enabled',1,@n;

EXEC sync.usp_SetNodeCredential @NodeId=@new,@SecretHash=0x0101010101010101010101010101010101010101010101010101010101010101;
INSERT @found EXEC sync.usp_GetNodeCredential @NodeId=@new;
SET @n=(SELECT COUNT(*) FROM @found); EXEC test.AssertEq N'the hub finds the active hash',1,@n;
EXEC sync.usp_RevokeNodeCredential @NodeId=@new;
DELETE @found; INSERT @found EXEC sync.usp_GetNodeCredential @NodeId=@new;
SET @n=(SELECT COUNT(*) FROM @found); EXEC test.AssertEq N'a revoked credential is not found',0,@n;
PRINT 'PASS';
