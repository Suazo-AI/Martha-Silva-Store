using System.Net;
using System.Net.Http.Headers;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Savia.Application;
using Savia.Contracts;
using Savia.Domain;
using Savia.Infrastructure;

namespace Savia.Tests;

/// <summary>Tag photo -> product fields: sidecar JSON mapping, parsing rules and the endpoint with a fake extractor (no SQL).</summary>
public sealed class TagExtractTests
{
    private static OcrLine L(string text, double left, double top, double right, double bottom, double score = 0.99) =>
        new(text, score, left, top, right, bottom);

    [Fact]
    public void Sidecar_json_maps_to_lines_with_boxes()
    {
        var json = """{"id":"a1","lines":[{"text":"SKU","score":0.98,"box":[[10,20],[60,22],[60,50],[10,48]]},{"text":"BL-2041-AZ","score":0.9,"box":[[200,18],[380,18],[380,52],[200,52]]}],"ms":812}""";
        var result = RapidOcrSidecarExtractor.ParseAnswer(json, "a1", "rapid");
        Assert.Equal("rapid", result.Engine);
        Assert.Equal(2, result.Lines.Count);
        Assert.Equal(new OcrLine("SKU", 0.98, 10, 20, 60, 50), result.Lines[0]);
        Assert.Equal(("BL-2041-AZ", 200d, 52d), (result.Lines[1].Text, result.Lines[1].Left, result.Lines[1].Bottom));
        Assert.Throws<InvalidOperationException>(() => RapidOcrSidecarExtractor.ParseAnswer("""{"id":"a1","error":"ValueError: imagen ilegible"}""", "a1", "rapid"));
        Assert.Throws<InvalidOperationException>(() => RapidOcrSidecarExtractor.ParseAnswer("""{"id":"old","lines":[]}""", "a1", "rapid"));
        // A late "ready" line (startup cut by a photo timeout) must never pass as an empty OCR answer.
        Assert.Throws<InvalidOperationException>(() => RapidOcrSidecarExtractor.ParseAnswer("""{"ready": true, "engine": "rapidocr-onnxruntime 1.4.4"}""", "a1", "rapid"));
    }

    [Theory]
    [InlineData("C$ 1,250.00", 125000L)]
    [InlineData("c$1,250.00", 125000L)]
    [InlineData("C$ 1.250,00", 125000L)]
    [InlineData("890.00", 89000L)]
    [InlineData("890", 89000L)]
    [InlineData("1,250", 125000L)]
    [InlineData("NIO 12,5", 1250L)]
    [InlineData("Algodón", null)]
    [InlineData("", null)]
    public void Prices_become_minor_units(string text, long? minor) => Assert.Equal(minor, TagParser.ParseMoneyMinor(text));

    [Theory]
    [InlineData("S", "S")]
    [InlineData("m", "M")]
    [InlineData("L", "L")]
    [InlineData("XL", "XL")]
    [InlineData("2XL", "XXL")]
    [InlineData("XXL", "XXL")]
    [InlineData("32", "32")]
    [InlineData("10", "10")]
    [InlineData("Verde", null)]
    [InlineData("123", null)]
    public void Sizes_are_letters_or_numbers(string text, string? size) => Assert.Equal(size, TagParser.SizeValue(text));

    [Theory]
    [InlineData("7501234567893", "7501234567893")]
    [InlineData("7501234567890", null)]   // wrong check digit
    [InlineData("036000291452", "036000291452")]   // UPC-A
    [InlineData("75012345", null)]
    [InlineData("ABC", null)]
    public void Barcodes_need_a_valid_check_digit(string code, string? valid) => Assert.Equal(valid, TagParser.ValidBarcode(code));

    [Fact]
    public void Parser_pairs_labels_with_values_beside_or_below()
    {
        var lines = new[]
        {
            L("ALMA TEXTIL", 100, 40, 400, 90),
            L("Blusa manga corta", 120, 110, 380, 145),
            L("BL-2041-AZ", 300, 160, 460, 195), L("SKU", 40, 165, 100, 195),
            L("Color", 40, 210, 120, 240), L("Azul", 390, 208, 460, 240),
            L("Talla", 40, 255, 120, 285), L("M", 230, 300, 270, 360),
            L("c$ 1,250.00", 120, 380, 400, 430),
            L("750１２3456７8９3", 120, 560, 420, 590, 0.76),   // full-width digits as RapidOCR returns them
            L("95% Algodon 5% Elastano", 90, 610, 430, 640),
        };
        var f = TagParser.Parse(lines);
        Assert.Equal(("7501234567893", "BL-2041-AZ", "M", "Azul", 125000L), (f.Barcode, f.Sku, f.Size, f.Color, f.PriceMinor!.Value));
        Assert.Equal(("ALMA TEXTIL", "Blusa manga corta", "95% Algodón 5% Elastano"), (f.Brand, f.Name, f.Composition));
        Assert.True(f.Confidence["sku"] > 0.9);
        Assert.True(f.Confidence["brand"] < 0.8);            // found without a label: shown as "revisar"
    }

    [Fact]
    public void Parser_uses_the_phone_barcode_and_inline_labels()
    {
        var f = TagParser.Parse([L("Ref: PJ-3310-NG", 0, 0, 200, 30), L("Talla: 32", 0, 40, 200, 70), L("98% Algodón 2%", 0, 80, 200, 110),
            L("Elastano", 10, 115, 120, 140), L("1234", 0, 150, 100, 170)], "7894561230128");
        Assert.Equal(("7894561230128", 1.0), (f.Barcode, f.Confidence["barcode"]));
        Assert.Equal(("PJ-3310-NG", "32", "98% Algodón 2% Elastano"), (f.Sku, f.Size, f.Composition));
        Assert.Null(f.PriceMinor);
    }

    [Fact]
    public async Task Endpoint_returns_fields_from_the_fake_extractor_and_a_known_item_without_ocr()
    {
        await using var host = new TagHost();
        var client = host.Client(TagHost.Inventory);

        var fields = await HttpAssert.OkAsync<TagExtractResponse>(await client.PostAsync("/api/v1/inventory/tag-extract", Photo()));
        Assert.Equal(("ocr", "7501234567893", "BL-2041-AZ", "M", 125000L), (fields.Source, fields.Barcode, fields.Sku, fields.Size, fields.PriceMinor!.Value));
        Assert.Null(fields.MatchedItem);
        Assert.Equal(1, host.Fake.Calls);

        var known = await HttpAssert.OkAsync<TagExtractResponse>(await client.PostAsync("/api/v1/inventory/tag-extract", Photo(TagHost.KnownBarcode)));
        Assert.Equal(("match", "barcode", TagHost.KnownItem), (known.Source, known.MatchedItem!.MatchedBy, known.MatchedItem.ItemId));
        Assert.Equal(1, host.Fake.Calls);                    // the barcode hint matched: OCR skipped

        host.Fake.Fail = true;
        var failed = await HttpAssert.OkAsync<TagExtractResponse>(await client.PostAsync("/api/v1/inventory/tag-extract", Photo("7894561230128")));
        Assert.Equal(("none", "7894561230128"), (failed.Source, failed.Barcode));   // OCR failed: the form keeps the barcode
        Assert.NotNull(failed.Warning);
    }

    [Fact]
    public async Task Endpoint_rejects_other_roles_missing_sign_in_and_non_images()
    {
        await using var host = new TagHost();
        await HttpAssert.ProblemAsync(await host.Client(TagHost.Accountant).PostAsync("/api/v1/inventory/tag-extract", Photo()),
            HttpStatusCode.Forbidden, "auth.role_required");
        await HttpAssert.ProblemAsync(await host.CreateClient().PostAsync("/api/v1/inventory/tag-extract", Photo()),
            HttpStatusCode.Unauthorized, "auth.required");
        var text = new MultipartFormDataContent { { new ByteArrayContent("hola"u8.ToArray()), "image", "x.jpg" } };
        await HttpAssert.ProblemAsync(await host.Client(TagHost.Inventory).PostAsync("/api/v1/inventory/tag-extract", text),
            (HttpStatusCode)422, "tag.image_type");
        Assert.Equal(0, host.Fake.Calls);
    }

    private static MultipartFormDataContent Photo(string? barcode = null)
    {
        var jpeg = new byte[] { 0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46, 0x49, 0x46, 0, 1 };
        var form = new MultipartFormDataContent { { new ByteArrayContent(jpeg) { Headers = { ContentType = new MediaTypeHeaderValue("image/jpeg") } }, "image", "etiqueta.jpg" } };
        if (barcode is not null) form.Add(new StringContent(barcode), "barcode");
        return form;
    }
}

public sealed class FakeTagExtractor : ITagExtractor
{
    public int Calls;
    public bool Fail;
    public string Engine => "fake";

    public Task<OcrResult> ReadAsync(ReadOnlyMemory<byte> image, CancellationToken ct)
    {
        Interlocked.Increment(ref Calls);
        if (Fail) throw new InvalidOperationException("OCR: fake failure");
        return Task.FromResult(new OcrResult(
        [
            new("SKU BL-2041-AZ", 0.98, 0, 0, 300, 30), new("Talla M", 0.97, 0, 40, 300, 70),
            new("C$ 1,250.00", 0.96, 0, 80, 300, 110), new("7501234567893", 0.9, 0, 120, 300, 150),
        ], Engine));
    }
}

/// <summary>The real API program with in-memory sign-in and catalog: no SQL Server needed for the tag endpoint.</summary>
internal sealed class TagHost : WebApplicationFactory<Program>
{
    public static readonly Guid Inventory = Guid.NewGuid(), Accountant = Guid.NewGuid(), KnownItem = Guid.NewGuid();
    public const string KnownBarcode = "7460012345675";
    public FakeTagExtractor Fake { get; } = new();

    public HttpClient Client(Guid staff)
    {
        var client = CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", "token-" + staff.ToString("N"));
        return client;
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_, config) => config.AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Savia:Node:Kind"] = "Branch", ["Savia:Node:NodeId"] = Ids.NodeA.ToString(),
            ["Savia:Node:BranchId"] = Ids.BranchA.ToString(), ["Savia:Node:LocationId"] = Ids.LocA.ToString(),
            ["Savia:Sql:ConnectionString"] = "Server=127.0.0.1,1;Database=none;Connect Timeout=1",   // never opened here
        }));
        builder.ConfigureTestServices(services =>
        {
            services.AddSingleton<ITagExtractor>(Fake);
            services.AddSingleton<IAuthStore>(new TokenAuth());
            services.AddSingleton<ICatalogStore>(new OneItemCatalog());
        });
    }

    private sealed class TokenAuth : IAuthStore
    {
        private static readonly Dictionary<string, Guid> Tokens = new[] { Inventory, Accountant }
            .ToDictionary(id => Convert.ToHexString(System.Security.Cryptography.SHA256.HashData(System.Text.Encoding.UTF8.GetBytes("token-" + id.ToString("N")))), id => id);

        public Task<Guid?> FindSessionStaffAsync(byte[] tokenHash, DateTimeOffset now, CancellationToken ct) =>
            Task.FromResult(Tokens.TryGetValue(Convert.ToHexString(tokenHash), out var id) ? id : (Guid?)null);
        public Task<Actor?> LoadActorAsync(Guid staffId, CancellationToken ct) => Task.FromResult<Actor?>(new Actor(staffId, "Prueba",
            new HashSet<string> { staffId == Inventory ? Roles.Inventory : Roles.Accountant }, new HashSet<Guid> { Ids.BranchA }));
        public Task<StaffCredential?> FindStaffAsync(string normalizedLogin, CancellationToken ct) => Task.FromResult<StaffCredential?>(null);
        public Task RecordSignInAsync(Guid staffId, bool success, DateTimeOffset? lockUntil, CancellationToken ct) => Task.CompletedTask;
        public Task CreateSessionAsync(Guid staffId, Guid securityVersion, byte[] tokenHash, DateTimeOffset expiresAt, CancellationToken ct) => Task.CompletedTask;
        public Task RevokeSessionAsync(byte[] tokenHash, DateTimeOffset now, CancellationToken ct) => Task.CompletedTask;
        public Task SetPasswordAsync(Guid staffId, string passwordHash, CancellationToken ct) => Task.CompletedTask;
    }

    private sealed class OneItemCatalog : ICatalogStore
    {
        public Task<IReadOnlyList<ItemLookup>> LookupAsync(string rawCode, Guid? supplierId, CancellationToken ct) =>
            Task.FromResult<IReadOnlyList<ItemLookup>>(rawCode == KnownBarcode
                ? [new ItemLookup(KnownItem, "SW-7702-GR", "Suéter de punto · XXL", 210000, "NIO", "active", "Suéter de punto", "XXL", "GRIS")]
                : []);
        public Task<IReadOnlyList<ProductSearchRow>> SearchAsync(string text, Guid? locationId, int limit, CancellationToken ct) =>
            Task.FromResult<IReadOnlyList<ProductSearchRow>>([]);
        public Task<IReadOnlyList<CatalogProduct>> ListAsync(Guid locationId, CancellationToken ct) => throw new NotSupportedException();
        public Task RegisterProductAsync(RegisterProductRequest request, Guid actorId, Guid nodeId, CancellationToken ct) => throw new NotSupportedException();
        public Task RegisterItemAsync(RegisterItemRequest request, Guid actorId, Guid nodeId, CancellationToken ct) => throw new NotSupportedException();
    }
}
