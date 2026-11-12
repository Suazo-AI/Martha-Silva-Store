using Savia.Domain;

namespace Savia.Application;

/// <summary>Who this process is. Set once from configuration at start-up.</summary>
/// <param name="BranchId">The only branch a Branch node may operate. Null on the cloud node.</param>
/// <param name="LocationId">Default stock location of a Branch node.</param>
/// <param name="LocalCatalog">Explicit single-branch pilot exception to cloud catalog ownership. Defaults to false.</param>
public sealed record NodeContext(NodeKind Kind, Guid NodeId, Guid? BranchId, Guid? LocationId, bool LocalCatalog = false)
{
    public Guid RequireBranch() => BranchId ?? throw new SaviaException(Errors.WrongNode);
    public Guid RequireLocation() => LocationId ?? throw new SaviaException(Errors.WrongNode);
}

/// <summary>The signed-in staff member, loaded from the database on every request.</summary>
public sealed record Actor(Guid StaffId, string DisplayName, IReadOnlySet<string> Roles, IReadOnlySet<Guid> BranchIds);

/// <summary>Authorization checks. They run before any procedure is called.</summary>
public static class Guard
{
    public static void Role(Actor actor, params string[] allowed)
    {
        if (!allowed.Any(actor.Roles.Contains)) throw new SaviaException(Errors.RoleRequired);
    }

    /// <summary>A branch node only serves staff who have access to its own branch.</summary>
    public static Guid Branch(Actor actor, NodeContext node)
    {
        var branch = node.RequireBranch();
        if (!actor.BranchIds.Contains(branch)) throw new SaviaException(Errors.BranchAccess);
        return branch;
    }

    public static void Kind(NodeContext node, NodeKind required)
    {
        if (node.Kind != required) throw new SaviaException(Errors.WrongNode);
    }

    public static string Text(string? value, string field, int max)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length > max)
            throw Errors.Invalid("input.text", $"'{field}' es obligatorio y admite hasta {max} caracteres.");
        return value;
    }
}
