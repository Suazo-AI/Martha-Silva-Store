using System.Diagnostics;
using Savia.Contracts;
using Savia.Domain;

namespace Savia.Application;

/// <summary>One text line read from the photo. The box is axis-aligned in image pixels.</summary>
public sealed record OcrLine(string Text, double Score, double Left, double Top, double Right, double Bottom)
{
    public double CenterY => (Top + Bottom) / 2;
    public double Height => Math.Max(1, Bottom - Top);
}

public sealed record OcrResult(IReadOnlyList<OcrLine> Lines, string Engine);

/// <summary>
/// Reads the text of a tag photo. The pilot implementation runs on this PC only (RapidOCR sidecar, Infrastructure).
/// Tests use a fake. No cloud or paid implementation exists, by owner decision (docs/pilot/ETIQUETA.md).
/// </summary>
public interface ITagExtractor
{
    string Engine { get; }
    Task<OcrResult> ReadAsync(ReadOnlyMemory<byte> image, CancellationToken ct);
}

/// <summary>Fields parsed from the OCR lines with plain rules. Each value has a 0..1 confidence.</summary>
public sealed record TagFields(string? Barcode, string? Sku, string? Name, string? Brand, string? Size, string? Color,
    long? PriceMinor, string? Composition, IReadOnlyDictionary<string, double> Confidence, string RawText);

public sealed class TagExtractionOptions
{
    public const long MaxImageBytes = 6 * 1024 * 1024;
    public TimeSpan OcrTimeout { get; init; } = TimeSpan.FromSeconds(12);
}

public sealed class TagExtractionService(ITagExtractor extractor, ICatalogStore catalog, NodeContext node, TagExtractionOptions options)
{
    public async Task<TagExtractResponse> ExtractAsync(Actor actor, ReadOnlyMemory<byte> image, string? barcodeHint, CancellationToken ct)
    {
        if (node.Kind == NodeKind.Branch) Guard.Branch(actor, node);
        Guard.Role(actor, Roles.Receivers);
        if (image.Length == 0) throw Errors.Invalid("tag.image_missing", "Falta la foto de la etiqueta.");
        if (image.Length > TagExtractionOptions.MaxImageBytes)
            throw Errors.Invalid("tag.image_too_large", "La foto supera 6 MB. Tómela de nuevo.");
        if (!IsSupportedImage(image.Span))
            throw Errors.Invalid("tag.image_type", "La foto debe ser JPEG, PNG o WebP.");

        var clock = Stopwatch.StartNew();
        var hint = TagParser.ValidBarcode(barcodeHint);
        if (hint is not null && await FindAsync(hint, null, ct) is { } known)
            return Response(Empty(hint), known, "match", extractor.Engine, (int)clock.ElapsedMilliseconds, null);

        TagFields fields;
        var source = "ocr";
        string? warning = null;
        try
        {
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct);
            timeout.CancelAfter(options.OcrTimeout);
            var ocr = await extractor.ReadAsync(image, timeout.Token);
            fields = TagParser.Parse(ocr.Lines, hint);
        }
        catch (Exception ex) when (!ct.IsCancellationRequested && ex is not SaviaException { Error.Kind: ErrorKind.Forbidden })
        {
            // Slow or failed OCR never blocks the worker: the form opens with the barcode only.
            fields = Empty(hint);
            source = "none";
            warning = ex is OperationCanceledException
                ? "La lectura tardó demasiado. Complete los datos a mano."
                : "No se pudo leer la etiqueta. Complete los datos a mano.";
        }
        var match = await FindAsync(fields.Barcode, fields.Sku, ct);
        return Response(fields, match, source, extractor.Engine, (int)clock.ElapsedMilliseconds, warning);
    }

    private async Task<TagMatchedItem?> FindAsync(string? barcode, string? sku, CancellationToken ct)
    {
        if (barcode is not null)
        {
            var hits = await catalog.LookupAsync(barcode, null, ct);
            if (hits.Count == 1)
            {
                var i = hits[0];
                return new TagMatchedItem(i.ItemId, i.Sku, i.ProductName, i.VariantName, i.SizeCode, i.ColorCode, i.UnitPriceMinor, "barcode");
            }
        }
        if (sku is { Length: >= 2 })
        {
            var rows = (await catalog.SearchAsync(sku, node.LocationId, 10, ct))
                .Where(r => string.Equals(r.Sku, sku, StringComparison.OrdinalIgnoreCase)).ToList();
            if (rows.Count == 1)
            {
                var r = rows[0];
                return new TagMatchedItem(r.ItemId, r.Sku, r.ProductName, r.VariantName, r.SizeCode, r.ColorCode, r.UnitPriceMinor, "sku");
            }
        }
        return null;
    }

    private static TagFields Empty(string? barcode) => new(barcode, null, null, null, null, null, null, null,
        barcode is null ? new Dictionary<string, double>() : new Dictionary<string, double> { ["barcode"] = 1.0 }, "");

    private static TagExtractResponse Response(TagFields f, TagMatchedItem? match, string source, string engine, int ms, string? warning) =>
        new(f.Barcode, f.Sku, f.Name, f.Brand, f.Size, f.Color, f.PriceMinor, f.Composition, f.Confidence, f.RawText,
            match, source, engine, ms, warning);

    public static bool IsSupportedImage(ReadOnlySpan<byte> b) =>
        (b.Length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF)
        || (b.Length > 8 && b[..8].SequenceEqual(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }))
        || (b.Length > 12 && b[..4].SequenceEqual("RIFF"u8) && b[8..12].SequenceEqual("WEBP"u8));
}
