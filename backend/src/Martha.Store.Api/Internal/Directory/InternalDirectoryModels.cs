using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;

namespace Martha.Store.Api.Internal;

public sealed class InternalItem
{
    public Guid Id { get; set; }
    // Stored in canonical ASCII upper case. Inactive SKUs remain reserved.
    public string Sku { get; set; } = "";
    public string Name { get; set; } = "";
    public long UnitPriceMinor { get; set; }
    public string Currency { get; set; } = "";
    public bool Active { get; set; } = true;
}

public sealed class InternalLocation
{
    public Guid Id { get; set; }
    public Guid? BranchId { get; set; }
    public string Name { get; set; } = "";
    public bool Active { get; set; } = true;
}

public sealed class InternalParty
{
    public Guid Id { get; set; }
    public string Kind { get; set; } = "";
    public string Name { get; set; } = "";
    public string? Email { get; set; }
    public string? Phone { get; set; }
    public bool Active { get; set; } = true;
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record InternalItemWrite(
    [property: JsonRequired] string? Sku,
    [property: JsonRequired] string? Name,
    [property: JsonRequired] long UnitPriceMinor,
    [property: JsonRequired] string? Currency,
    bool Active = true);

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record InternalLocationWrite
{
    [JsonRequired] public string? Name { get; init; }
    public bool Active { get; init; } = true;
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public InternalBranchIdUpdate BranchId { get; init; }

    [JsonConstructor] public InternalLocationWrite() { }
    public InternalLocationWrite(string? Name, bool Active = true)
    { this.Name = Name; this.Active = Active; }
    public InternalLocationWrite(string? Name, bool Active, Guid? BranchId) : this(Name, Active)
    { this.BranchId = InternalBranchIdUpdate.Specified(BranchId); }
    public InternalLocationWrite(string? Name, Guid? BranchId) : this(Name, true, BranchId) { }
}

[JsonUnmappedMemberHandling(JsonUnmappedMemberHandling.Disallow)]
public sealed record InternalPartyWrite(
    [property: JsonRequired] string? Kind,
    [property: JsonRequired] string? Name,
    string? Email = null, string? Phone = null, bool Active = true);

public sealed record InternalItemView(Guid Id, string Sku, string Name, long UnitPriceMinor, string Currency, bool Active);
public sealed record InternalLocationView(Guid Id, string Name, bool Active, Guid? BranchId = null);
public sealed record InternalPartyView(Guid Id, string Kind, string Name, string? Email, string? Phone, bool Active);
public sealed record InternalDirectoryPage<T>(IReadOnlyList<T> Items, int Total, int Skip, int Take);

public sealed partial class InternalDbContext
{
    public DbSet<InternalItem> InternalItems => Set<InternalItem>();
    public DbSet<InternalLocation> InternalLocations => Set<InternalLocation>();
    public DbSet<InternalParty> InternalParties => Set<InternalParty>();

    partial void ConfigureDirectory(ModelBuilder model)
    {
        var items = model.Entity<InternalItem>();
        items.ToTable("Items", table =>
        {
            table.HasCheckConstraint("CK_InternalItems_Price", $"[UnitPriceMinor] >= 0 AND [UnitPriceMinor] <= {InternalRules.MaxMinor}");
            table.HasCheckConstraint("CK_InternalItems_Currency", "DATALENGTH([Currency]) = 3 AND [Currency] COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^A-Z]%' AND [Currency] <> 'XXX'");
            table.HasCheckConstraint("CK_InternalItems_Sku", "LEN([Sku]) BETWEEN 1 AND 64 AND DATALENGTH([Sku]) = LEN([Sku]) AND [Sku] COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^A-Z0-9_.-]%'");
            table.HasCheckConstraint("CK_InternalItems_Name", "LEN(LTRIM(RTRIM([Name]))) > 0");
        });
        items.HasKey(x => x.Id);
        items.Property(x => x.Id).ValueGeneratedNever();
        items.Property(x => x.Sku).IsRequired().IsUnicode(false).HasMaxLength(64).UseCollation("Latin1_General_100_BIN2");
        items.HasIndex(x => x.Sku).IsUnique();
        items.Property(x => x.Name).IsRequired().HasMaxLength(200);
        items.Property(x => x.Currency).IsRequired().IsUnicode(false).HasMaxLength(3).UseCollation("Latin1_General_100_BIN2");
        items.HasIndex(x => new { x.Active, x.Name });

        var locations = model.Entity<InternalLocation>();
        locations.ToTable("Locations", table => table.HasCheckConstraint("CK_InternalLocations_Name", "LEN(LTRIM(RTRIM([Name]))) > 0"));
        locations.HasKey(x => x.Id);
        locations.Property(x => x.Id).ValueGeneratedNever();
        locations.Property(x => x.Name).IsRequired().HasMaxLength(120);
        locations.HasIndex(x => new { x.Active, x.Name });

        var parties = model.Entity<InternalParty>();
        parties.ToTable("Parties", table =>
        {
            table.HasCheckConstraint("CK_InternalParties_Kind", "[Kind] IN ('customer', 'supplier')");
            table.HasCheckConstraint("CK_InternalParties_Name", "LEN(LTRIM(RTRIM([Name]))) > 0");
        });
        parties.HasKey(x => x.Id);
        parties.Property(x => x.Id).ValueGeneratedNever();
        parties.Property(x => x.Kind).IsRequired().IsUnicode(false).HasMaxLength(8).UseCollation("Latin1_General_100_BIN2");
        parties.Property(x => x.Name).IsRequired().HasMaxLength(200);
        parties.Property(x => x.Email).HasMaxLength(254);
        parties.Property(x => x.Phone).HasMaxLength(32);
        // Names and contact details are NOT identities: households and different people
        // may share them. Never silently merge parties or impose email/name uniqueness.
        parties.HasIndex(x => new { x.Kind, x.Active, x.Name });
    }
}
