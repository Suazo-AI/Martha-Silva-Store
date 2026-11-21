using Martha.Store.Api.Internal;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Metadata;
using Xunit;

namespace Martha.Store.Api.Tests;

public sealed class InternalDirectoryModelTests
{
    internal static InternalDbContext Database() => new(new DbContextOptionsBuilder<InternalDbContext>()
        .UseSqlServer("Server=127.0.0.1,1;Database=SaviaInternal_UnitModel;Integrated Security=true;Connect Timeout=1").Options);

    [Fact]
    public void Catalog_has_schema_unique_canonical_sku_integer_money_and_sql_constraints()
    {
        using var db = Database(); // Metadata only: no connection is opened.
        var model = db.GetService<IDesignTimeModel>().Model;
        var item = model.FindEntityType(typeof(InternalItem))!;
        Assert.Equal("savia_internal", item.GetSchema());
        Assert.Equal(typeof(long), item.FindProperty(nameof(InternalItem.UnitPriceMinor))!.ClrType);
        Assert.Contains(item.GetIndexes(), x => x.IsUnique && x.Properties.Single().Name == nameof(InternalItem.Sku));
        Assert.Equal("Latin1_General_100_BIN2", item.FindProperty(nameof(InternalItem.Sku))!.GetCollation());
        Assert.Contains(item.GetCheckConstraints(), x => x.Name == "CK_InternalItems_Currency" && x.Sql.Contains("XXX"));
        Assert.Contains(item.GetCheckConstraints(), x => x.Name == "CK_InternalItems_Price" && x.Sql.Contains(InternalRules.MaxMinor.ToString()));
        Assert.Contains(item.GetCheckConstraints(), x => x.Name == "CK_InternalItems_Sku");
        Assert.Empty(item.GetDeclaredQueryFilters()); // Historical references still resolve inactive rows.
    }

    [Fact]
    public void Party_names_and_shared_contact_details_are_not_unique_identifiers()
    {
        using var db = Database();
        var party = db.Model.FindEntityType(typeof(InternalParty))!;
        Assert.Equal("savia_internal", party.GetSchema());
        Assert.DoesNotContain(party.GetIndexes(), x => x.IsUnique);
        Assert.True(party.FindProperty(nameof(InternalParty.Email))!.IsNullable);
        Assert.True(party.FindProperty(nameof(InternalParty.Phone))!.IsNullable);
        Assert.Equal(254, party.FindProperty(nameof(InternalParty.Email))!.GetMaxLength());
        Assert.Empty(party.GetDeclaredQueryFilters());
    }

    [Fact]
    public void No_directory_entity_has_real_or_synthetic_seed_data()
    {
        using var db = Database();
        foreach (var type in new[] { typeof(InternalItem), typeof(InternalParty), typeof(InternalLocation) })
        {
            var entity = db.GetService<IDesignTimeModel>().Model.FindEntityType(type)!;
            Assert.Empty(entity.GetSeedData());
            Assert.Equal(ValueGenerated.Never, entity.FindProperty("Id")!.ValueGenerated);
            Assert.NotNull(entity.FindProperty("Active"));
        }
    }
}
