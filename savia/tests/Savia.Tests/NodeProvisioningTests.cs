namespace Savia.Tests;

// D-040: Savia.Migrator --provision-node argument rules and the secret format (no SQL needed).
public sealed class NodeProvisioningTests
{
    private static readonly string Node = Guid.NewGuid().ToString(), Branch = Guid.NewGuid().ToString();

    private static (NodeRequest? Request, string? Error) Parse(string action, params string[] args) =>
        NodeRequest.Parse(action, name => Array.IndexOf(args, name) is var i and >= 0 && i + 1 < args.Length ? args[i + 1] : null);

    [Fact]
    public void Create_needs_a_code_and_a_branch_for_a_branch_node()
    {
        Assert.NotNull(Parse("create", "--node-id", Node, "--branch-id", Branch, "--node-code", "STORE_1").Request);
        Assert.Null(Parse("create", "--node-id", Node, "--node-code", "STORE_1").Request);
        Assert.Null(Parse("create", "--node-id", Node, "--branch-id", Branch).Request);
    }

    [Fact]
    public void The_hub_node_is_registered_without_branch_and_has_no_credential()
    {
        Assert.NotNull(Parse("register", "--node-id", Node, "--node-kind", "azure", "--node-code", "HUB").Request);
        Assert.Null(Parse("register", "--node-id", Node, "--node-kind", "azure", "--branch-id", Branch, "--node-code", "HUB").Request);
        Assert.Null(Parse("rotate", "--node-id", Node, "--node-kind", "azure").Request);
    }

    [Theory]
    [InlineData("delete")]
    [InlineData("")]
    public void Unknown_actions_and_bad_ids_are_usage_errors(string action)
    {
        Assert.NotNull(Parse(action, "--node-id", Node).Error);
        Assert.NotNull(Parse("revoke", "--node-id", "not-a-guid").Error);
        Assert.NotNull(Parse("revoke", "--node-id", Node).Request);
    }

    [Fact]
    public void A_secret_is_256_random_bits_that_the_sync_header_can_carry()
    {
        var one = NodeRequest.NewSecret();
        Assert.Equal(43, one.Length);
        Assert.Matches("^[A-Za-z0-9_-]+$", one);
        Assert.NotEqual(one, NodeRequest.NewSecret());
        Assert.Equal(Savia.Application.NodeCredential.Hash(one), NodeRequest.Hash(one));
        Assert.Equal((Guid.Parse(Node), one), Savia.Application.NodeCredential.Parse($"SaviaNode {Node}.{one}"));
    }
}
