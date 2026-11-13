namespace Savia.Contracts;

/// <summary>Who is signed in and where this node runs. Branch, location and names are null on the cloud node.</summary>
public sealed record MeResponse(Guid StaffId, string DisplayName, string[] Roles, string NodeKind, Guid NodeId, Guid? BranchId,
    Guid? LocationId = null, string? BranchName = null, string? StoreDisplayName = null, string? LocationName = null);
