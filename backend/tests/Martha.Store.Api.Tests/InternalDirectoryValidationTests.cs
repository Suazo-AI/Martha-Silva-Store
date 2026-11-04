using System.Text.Json;
using Martha.Store.Api.Internal;
using Xunit;

namespace Martha.Store.Api.Tests;

public sealed class InternalDirectoryValidationTests
{
    [Fact]
    public void Catalog_normalizes_sku_without_repricing_or_conversion()
    {
        var result = InternalDirectoryValidation.Item(new("  sku-1_a.b ", "  Artículo  ", 1250, " hnl ", false));
        Assert.True(result.Success);
        Assert.Equal(new InternalItemWrite("SKU-1_A.B", "Artículo", 1250, "HNL", false), result.Value);
    }

    [Theory]
    [InlineData(null)] [InlineData("")] [InlineData(" ")] [InlineData("bad sku")]
    [InlineData("../part/path")] [InlineData("SKU\n1")] [InlineData("sκu")] [InlineData("ſku")]
    public void Invalid_skus_are_rejected(string? sku) => Assert.False(InternalDirectoryValidation.Item(new(sku, "Item", 1, "USD")).Success);

    [Theory]
    [InlineData(null)] [InlineData("")] [InlineData("XXX")] [InlineData("xxx")] [InlineData("US")]
    [InlineData("USDD")] [InlineData("123")] [InlineData("U$D")] [InlineData("ÜSD")]
    public void Currency_is_explicit_three_ascii_letters_not_fixture_currency(string? currency) =>
        Assert.False(InternalDirectoryValidation.Item(new("ITEM-1", "Item", 1, currency)).Success);

    [Theory]
    [InlineData(-1L)] [InlineData(long.MaxValue)] [InlineData(9_000_000_000_001L)]
    public void Invalid_minor_prices_are_rejected(long price) => Assert.False(InternalDirectoryValidation.Item(new("ITEM-1", "Item", price, "USD")).Success);

    [Theory]
    [InlineData(0L)] [InlineData(9_000_000_000_000L)]
    public void Integer_price_bounds_are_inclusive(long price) => Assert.True(InternalDirectoryValidation.Item(new("ITEM-1", "Item", price, "USD")).Success);

    [Theory]
    [InlineData(null)] [InlineData("")] [InlineData(" ")] [InlineData("Line\r\nBreak")]
    [InlineData("Spoof\u202etext")] [InlineData("Line\u2028Break")]
    public void Invalid_names_are_rejected_in_each_domain(string? name)
    {
        Assert.False(InternalDirectoryValidation.Item(new("ITEM-1", name, 1, "USD")).Success);
        Assert.False(InternalDirectoryValidation.Location(new(name)).Success);
        Assert.False(InternalDirectoryValidation.Party(new("customer", name)).Success);
    }

    [Fact]
    public void Text_has_length_limits_and_normalizes_canonical_unicode_only()
    {
        Assert.False(InternalDirectoryValidation.Item(new(new string('S', 65), "Item", 1, "USD")).Success);
        Assert.False(InternalDirectoryValidation.Item(new("SKU-1", new string('x', 201), 1, "USD")).Success);
        Assert.False(InternalDirectoryValidation.Location(new(new string('x', 121))).Success);
        Assert.False(InternalDirectoryValidation.Party(new("customer", new string('x', 201))).Success);
        Assert.False(InternalDirectoryValidation.Location(new("\ud800" )).Success);
        Assert.Equal("Café  Norte", InternalDirectoryValidation.Location(new("  Cafe\u0301  Norte  ")).Value!.Name);
    }

    [Fact]
    public void Party_normalization_does_not_merge_people_or_rewrite_email_local_part()
    {
        var result = InternalDirectoryValidation.Party(new(" Supplier ", "  Example  Company  ", " A.B+label@EXAMPLE.TEST ", " +504 (0000) 0000 "));
        Assert.True(result.Success);
        Assert.Equal(new InternalPartyWrite("supplier", "Example  Company", "A.B+label@example.test", "+504 (0000) 0000"), result.Value);
        Assert.False(InternalDirectoryValidation.Party(new("customer", "Synthetic Person", "A.e\u0301+tag@EXAMPLE.TEST")).Success); // Reject rather than silently rewrite a local part.
    }

    [Fact]
    public void Optional_contacts_are_nullable_not_fabricated()
    {
        var party = InternalDirectoryValidation.Party(new("customer", "Synthetic Person", "  ", " ")).Value!;
        Assert.Null(party.Email);
        Assert.Null(party.Phone);
    }

    [Theory]
    [InlineData("staff", null, null)] [InlineData("", null, null)]
    [InlineData("customer", "not-an-email", null)] [InlineData("customer", "Display <person@example.test>", null)]
    [InlineData("customer", "person@example.test\r\nBCC:other@example.test", null)]
    [InlineData("customer", null, "abc")] [InlineData("customer", null, "123\n456")]
    public void Invalid_party_contact_and_kind_are_rejected(string kind, string? email, string? phone) =>
        Assert.False(InternalDirectoryValidation.Party(new(kind, "Synthetic Person", email, phone)).Success);

    [Theory]
    [InlineData(-1, 50)] [InlineData(100001, 50)] [InlineData(0, 0)] [InlineData(0, 101)]
    public void List_reads_are_bounded(int skip, int take) => Assert.False(InternalDirectoryValidation.Query(null, skip, take, out _));

    [Theory]
    [InlineData("{\"sku\":\"A\",\"name\":\"Item\",\"currency\":\"USD\"}")]
    [InlineData("{\"sku\":\"A\",\"name\":\"Item\",\"currency\":\"USD\",\"unitPriceMinor\":1.5}")]
    [InlineData("{\"sku\":\"A\",\"name\":\"Item\",\"currency\":\"USD\",\"unitPriceMinor\":1,\"actorId\":\"fake\"}")]
    [InlineData("{\"sku\":\"A\",\"name\":\"Item\",\"currency\":\"USD\",\"unitPriceMinor\":1,\"id\":\"fake\"}")]
    public void Missing_price_fractional_minor_units_and_overposting_are_rejected(string json) =>
        Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<InternalItemWrite>(json, new JsonSerializerOptions(JsonSerializerDefaults.Web)));
}
